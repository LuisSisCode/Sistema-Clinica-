"""
Servicio de lógica de negocio para compras
Maneja validaciones complejas, reglas de negocio y coordinación entre repositories
"""

from typing import List, Dict, Any, Optional, Tuple
from datetime import datetime, timedelta, date
from decimal import Decimal, ROUND_HALF_UP
import json

from ..repositories.compra_repository import CompraRepository
from ..repositories.producto_repository import ProductoRepository
from ..core.excepciones import (
    CompraError, ProductoNotFoundError, ValidationError, StockInsuficienteError,
    ExceptionHandler, safe_execute, validate_required, validate_positive_number
)
from ..core.config import Config
from ..core.utils import (
    formatear_precio, parsear_fecha, formatear_fecha, es_fecha_valida,
    dias_hasta_vencimiento, calcular_estado_vencimiento, preparar_para_qml,
    crear_respuesta_qml, validar_codigo_producto, limpiar_texto,
    generar_codigo_producto, safe_float, safe_int, is_empty,
    medir_tiempo_ejecucion
)

class CompraService:
    """
    Servicio de lógica de negocio para compras
    Coordina entre CompraRepository y ProductoRepository
    Implementa validaciones complejas y reglas de negocio
    """
    
    def __init__(self):
        self.compra_repo = CompraRepository()
        self.producto_repo = ProductoRepository()
        
        # Configuraciones de negocio
        self.margen_minimo = 0.15  # 15% margen mínimo
        self.margen_recomendado = 0.25  # 25% margen recomendado
        self.dias_vencimiento_minimo = 30  # Mínimo días para aceptar producto
        self.cantidad_maxima_por_item = 1000  # Límite por ítem en compra
        self.monto_maximo_compra = 50000.0  # Límite total compra
        
        print("🛒 CompraService inicializado con validaciones de negocio")
    
    # ===============================
    # VALIDACIONES DE NEGOCIO
    # ===============================
    
    def validar_item_compra(self, item_data: Dict[str, Any]) -> Dict[str, Any]:
        """
        Valida un item de compra con reglas de negocio
        
        Returns:
            {
                'valido': bool,
                'errores': List[str],
                'advertencias': List[str],
                'item_validado': Dict
            }
        """
        errores = []
        advertencias = []
        item_validado = {}
        
        # Extraer y validar campos básicos
        codigo = item_data.get('codigo', '').strip()
        cantidad_caja = safe_int(item_data.get('cantidad_caja', 0))
        cantidad_unitario = safe_int(item_data.get('cantidad_unitario', 0))
        precio_unitario = safe_float(item_data.get('precio_unitario', 0))
        fecha_vencimiento_str = item_data.get('fecha_vencimiento', '').strip()
        
        # Validación de código
        if not codigo:
            errores.append("Código de producto requerido")
        elif not validar_codigo_producto(codigo):
            errores.append("Formato de código inválido")
        else:
            item_validado['codigo'] = codigo.upper()
        
        # Validación de cantidades
        if cantidad_caja < 0 or cantidad_unitario < 0:
            errores.append("Cantidades no pueden ser negativas")
        elif cantidad_caja == 0 and cantidad_unitario == 0:
            errores.append("Debe especificar al menos una cantidad (caja o unitario)")
        else:
            cantidad_total = cantidad_caja + cantidad_unitario
            
            if cantidad_total > self.cantidad_maxima_por_item:
                errores.append(f"Cantidad excede límite máximo ({self.cantidad_maxima_por_item})")
            else:
                item_validado['cantidad_caja'] = cantidad_caja
                item_validado['cantidad_unitario'] = cantidad_unitario
                item_validado['cantidad_total'] = cantidad_total
        
        # Validación de precio
        if precio_unitario <= 0:
            errores.append("Precio unitario debe ser mayor a 0")
        elif precio_unitario > 10000:  # Precio muy alto sospechoso
            advertencias.append(f"Precio muy alto: {formatear_precio(precio_unitario)}")
            item_validado['precio_unitario'] = precio_unitario
        else:
            item_validado['precio_unitario'] = precio_unitario
        
        # Validación de fecha de vencimiento
        if not fecha_vencimiento_str:
            errores.append("Fecha de vencimiento requerida")
        elif not es_fecha_valida(fecha_vencimiento_str):
            errores.append("Formato de fecha de vencimiento inválido")
        else:
            fecha_vencimiento = parsear_fecha(fecha_vencimiento_str)
            dias_restantes = dias_hasta_vencimiento(fecha_vencimiento)
            
            if dias_restantes < 0:
                errores.append("Producto ya está vencido")
            elif dias_restantes < self.dias_vencimiento_minimo:
                advertencias.append(f"Producto vence pronto ({dias_restantes} días)")
                item_validado['fecha_vencimiento'] = fecha_vencimiento_str
            else:
                item_validado['fecha_vencimiento'] = fecha_vencimiento_str
        
        # Calcular subtotal si no hay errores críticos
        if 'cantidad_total' in item_validado and 'precio_unitario' in item_validado:
            subtotal = item_validado['cantidad_total'] * item_validado['precio_unitario']
            item_validado['subtotal'] = subtotal
        
        return {
            'valido': len(errores) == 0,
            'errores': errores,
            'advertencias': advertencias,
            'item_validado': item_validado
        }
    
    def validar_compra_completa(self, proveedor_id: int, items: List[Dict[str, Any]], 
                              usuario_id: int) -> Dict[str, Any]:
        """
        Valida una compra completa antes de procesarla
        
        Returns:
            {
                'valida': bool,
                'errores_generales': List[str],
                'items_validados': List[Dict],
                'total_compra': float,
                'resumen': Dict
            }
        """
        errores_generales = []
        items_validados = []
        advertencias_generales = []
        
        # Validar proveedor
        if proveedor_id <= 0:
            errores_generales.append("Proveedor no seleccionado")
        else:
            try:
                # Verificar que el proveedor existe (se puede mejorar con un método específico)
                proveedores = safe_execute(self.compra_repo.get_proveedores_activos)
                proveedor_existe = any(p.get('id') == proveedor_id for p in proveedores)
                if not proveedor_existe:
                    errores_generales.append("Proveedor no válido")
            except Exception:
                errores_generales.append("Error validando proveedor")
        
        # Validar usuario
        if usuario_id <= 0:
            errores_generales.append("Usuario no especificado")
        
        # Validar items
        if not items:
            errores_generales.append("No hay items para comprar")
        else:
            codigos_unicos = set()
            total_compra = 0.0
            items_con_advertencias = 0
            
            for i, item in enumerate(items):
                validacion_item = self.validar_item_compra(item)
                
                if validacion_item['valido']:
                    item_validado = validacion_item['item_validado']
                    
                    # Verificar códigos duplicados
                    codigo = item_validado['codigo']
                    if codigo in codigos_unicos:
                        errores_generales.append(f"Código duplicado: {codigo}")
                    else:
                        codigos_unicos.add(codigo)
                    
                    # Acumular total
                    if 'subtotal' in item_validado:
                        total_compra += item_validado['subtotal']
                    
                    # Contar advertencias
                    if validacion_item['advertencias']:
                        items_con_advertencias += 1
                    
                    items_validados.append({
                        'indice': i,
                        'item': item_validado,
                        'advertencias': validacion_item['advertencias']
                    })
                else:
                    # Agregar errores de item con contexto
                    for error in validacion_item['errores']:
                        errores_generales.append(f"Item {i+1}: {error}")
            
            # Validar total de compra
            if total_compra > self.monto_maximo_compra:
                errores_generales.append(f"Total excede límite máximo ({formatear_precio(self.monto_maximo_compra)})")
            elif total_compra == 0:
                errores_generales.append("Total de compra es 0")
            
            # Advertencias generales
            if items_con_advertencias > 0:
                advertencias_generales.append(f"{items_con_advertencias} items tienen advertencias")
        
        return {
            'valida': len(errores_generales) == 0,
            'errores_generales': errores_generales,
            'advertencias_generales': advertencias_generales,
            'items_validados': items_validados,
            'total_compra': total_compra,
            'resumen': {
                'total_items': len(items_validados),
                'total_unidades': sum(item['item']['cantidad_total'] for item in items_validados),
                'productos_unicos': len(codigos_unicos),
                'total_formateado': formatear_precio(total_compra)
            }
        }
    
    # ===============================
    # PROCESAMIENTO DE COMPRAS
    # ===============================
    
    @ExceptionHandler.handle_exception
    @medir_tiempo_ejecucion
    def procesar_compra(self, proveedor_id: int, usuario_id: int, items: List[Dict[str, Any]], 
                       validar_precios: bool = True) -> Dict[str, Any]:
        """
        Procesa compra completa con validaciones de negocio
        
        Args:
            proveedor_id: ID del proveedor
            usuario_id: ID del usuario que hace la compra
            items: Lista de items a comprar
            validar_precios: Si validar márgenes de precio
        
        Returns:
            Información completa de la compra procesada
        """
        print(f"🛒 Iniciando procesamiento de compra - Proveedor: {proveedor_id}, Items: {len(items)}")
        
        # 1. Validación completa
        validacion = self.validar_compra_completa(proveedor_id, items, usuario_id)
        
        if not validacion['valida']:
            raise CompraError(
                f"Compra inválida: {'; '.join(validacion['errores_generales'])}",
                proveedor_id=proveedor_id,
                total=validacion['total_compra']
            )
        
        # 2. Preparar items para repository
        items_preparados = []
        for item_validado in validacion['items_validados']:
            item_data = item_validado['item']
            
            # Validaciones adicionales por producto
            if validar_precios:
                precio_validado = self._validar_precio_compra(
                    item_data['codigo'], 
                    item_data['precio_unitario']
                )
                if precio_validado['advertencias']:
                    print(f"⚠️ Precio {item_data['codigo']}: {'; '.join(precio_validado['advertencias'])}")
            
            items_preparados.append({
                'codigo': item_data['codigo'],
                'cantidad_caja': item_data['cantidad_caja'],
                'cantidad_unitario': item_data['cantidad_unitario'],
                'precio_unitario': item_data['precio_unitario'],
                'fecha_vencimiento': item_data['fecha_vencimiento']
            })
        
        # 3. Procesar en repository
        compra_completa = safe_execute(
            self.compra_repo.crear_compra,
            proveedor_id,
            usuario_id,
            items_preparados
        )
        
        if not compra_completa:
            raise CompraError("Error creando compra en repository")
        
        # 4. Post-procesamiento
        resultado_post = self._post_procesar_compra(compra_completa)
        
        print(f"✅ Compra procesada exitosamente - ID: {compra_completa['id']}, Total: {formatear_precio(compra_completa['Total'])}")
        
        # 5. Preparar respuesta completa
        return {
            'compra': compra_completa,
            'validacion': validacion,
            'post_procesamiento': resultado_post,
            'estadisticas': self._calcular_estadisticas_compra(compra_completa)
        }
    
    def _validar_precio_compra(self, codigo_producto: str, precio_compra: float) -> Dict[str, Any]:
        """Valida precio de compra contra histórico y márgenes"""
        advertencias = []
        
        try:
            # Obtener producto para comparar con precio base
            producto = safe_execute(self.producto_repo.get_by_codigo, codigo_producto)
            
            if producto:
                precio_compra_actual = safe_float(producto.get('Precio_compra', 0))
                precio_venta_actual = safe_float(producto.get('Precio_venta', 0))
                
                # Comparar con precio de compra actual
                if precio_compra_actual > 0:
                    diferencia_porcentual = ((precio_compra - precio_compra_actual) / precio_compra_actual) * 100
                    
                    if diferencia_porcentual > 50:
                        advertencias.append(f"Precio {diferencia_porcentual:.1f}% mayor al actual")
                    elif diferencia_porcentual < -20:
                        advertencias.append(f"Precio {abs(diferencia_porcentual):.1f}% menor al actual")
                
                # Verificar margen con precio de venta actual
                if precio_venta_actual > 0:
                    margen_actual = ((precio_venta_actual - precio_compra) / precio_compra) * 100
                    
                    if margen_actual < self.margen_minimo * 100:
                        advertencias.append(f"Margen muy bajo ({margen_actual:.1f}%)")
                    elif margen_actual > 100:
                        advertencias.append(f"Margen muy alto ({margen_actual:.1f}%)")
        
        except Exception as e:
            advertencias.append(f"Error validando precio: {str(e)}")
        
        return {
            'valido': len(advertencias) == 0,
            'advertencias': advertencias
        }
    
    def _post_procesar_compra(self, compra: Dict[str, Any]) -> Dict[str, Any]:
        """Procesamiento posterior a la compra"""
        alertas = []
        recomendaciones = []
        
        try:
            # Verificar productos con stock bajo después de la compra
            productos_stock_bajo = safe_execute(
                self.producto_repo.get_productos_bajo_stock,
                Config.STOCK_MINIMO_DEFAULT
            )
            
            if productos_stock_bajo:
                alertas.append(f"{len(productos_stock_bajo)} productos con stock bajo")
                recomendaciones.append("Considerar reabastecer productos con stock bajo")
            
            # Verificar productos próximos a vencer
            productos_por_vencer = safe_execute(
                self.producto_repo.get_lotes_por_vencer,
                Config.DIAS_VENCIMIENTO_ALERTA
            )
            
            if productos_por_vencer:
                alertas.append(f"{len(productos_por_vencer)} lotes próximos a vencer")
                recomendaciones.append("Revisar fechas de vencimiento y planificar ventas")
            
            # Calcular valor total de inventario después de la compra
            valor_inventario = safe_execute(self.producto_repo.get_valor_inventario)
            
        except Exception as e:
            alertas.append(f"Error en post-procesamiento: {str(e)}")
        
        return {
            'alertas': alertas,
            'recomendaciones': recomendaciones,
            'valor_inventario': valor_inventario or {}
        }
    
    def _calcular_estadisticas_compra(self, compra: Dict[str, Any]) -> Dict[str, Any]:
        """Calcula estadísticas de la compra procesada"""
        try:
            detalles = compra.get('detalles', [])
            
            return {
                'total_items': len(detalles),
                'total_unidades': sum(
                    safe_int(detalle.get('Cantidad_Total', 0)) 
                    for detalle in detalles
                ),
                'precio_promedio': (
                    compra['Total'] / sum(safe_int(d.get('Cantidad_Total', 0)) for d in detalles)
                    if detalles else 0
                ),
                'productos_nuevos': len([
                    d for d in detalles 
                    if safe_int(d.get('Stock_Anterior', 1)) == 0
                ]),
                'valor_total_formateado': formatear_precio(compra['Total'])
            }
        except Exception:
            return {}
    
    # ===============================
    # GESTIÓN DE PROVEEDORES
    # ===============================
    
    @ExceptionHandler.handle_exception
    def crear_proveedor_completo(self, nombre: str, direccion: str = "", 
                               telefono: str = "", email: str = "") -> Dict[str, Any]:
        """
        Crea proveedor con validaciones completas
        
        Returns:
            Información del proveedor creado
        """
        # Validaciones
        if not nombre or len(nombre.strip()) < 3:
            raise ValidationError("nombre", nombre, "Mínimo 3 caracteres")
        
        nombre_limpio = limpiar_texto(nombre)
        direccion_limpia = limpiar_texto(direccion) if direccion else "No especificada"
        
        # Validar email si se proporciona
        if email:
            from ..core.utils import validar_email
            if not validar_email(email):
                raise ValidationError("email", email, "Formato de email inválido")
        
        # Validar teléfono si se proporciona
        if telefono:
            from ..core.utils import validar_telefono
            if not validar_telefono(telefono):
                raise ValidationError("telefono", telefono, "Formato de teléfono inválido")
        
        # Crear en repository
        proveedor_id = safe_execute(
            self.compra_repo.crear_proveedor,
            nombre_limpio,
            direccion_limpia
        )
        
        if not proveedor_id:
            raise CompraError(f"Error creando proveedor: {nombre_limpio}")
        
        # Preparar respuesta
        proveedor_creado = {
            'id': proveedor_id,
            'nombre': nombre_limpio,
            'direccion': direccion_limpia,
            'telefono': telefono.strip() if telefono else "",
            'email': email.strip() if email else "",
            'fecha_creacion': datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
            'activo': True
        }
        
        print(f"🏢 Proveedor creado - ID: {proveedor_id}, Nombre: {nombre_limpio}")
        
        return proveedor_creado
    
    def buscar_proveedores_avanzado(self, termino: str, incluir_estadisticas: bool = False) -> List[Dict[str, Any]]:
        """
        Búsqueda avanzada de proveedores con estadísticas opcionales
        """
        if not termino or len(termino.strip()) < 2:
            return []
        
        try:
            # Búsqueda básica
            proveedores = safe_execute(
                self.compra_repo.buscar_proveedores,
                termino.strip()
            )
            
            if incluir_estadisticas and proveedores:
                # Agregar estadísticas a cada proveedor
                for proveedor in proveedores:
                    estadisticas = self._obtener_estadisticas_proveedor(proveedor['id'])
                    proveedor.update(estadisticas)
            
            return preparar_para_qml(proveedores)
            
        except Exception as e:
            print(f"❌ Error en búsqueda avanzada de proveedores: {e}")
            return []
    
    def _obtener_estadisticas_proveedor(self, proveedor_id: int) -> Dict[str, Any]:
        """Obtiene estadísticas de un proveedor"""
        try:
            compras = safe_execute(
                self.compra_repo.get_compras_por_proveedor,
                proveedor_id
            )
            
            if compras:
                compra = compras[0]  # get_compras_por_proveedor retorna estadísticas agregadas
                return {
                    'total_compras': safe_int(compra.get('Total_Compras', 0)),
                    'monto_total': safe_float(compra.get('Monto_Total', 0)),
                    'compra_promedio': safe_float(compra.get('Compra_Promedio', 0)),
                    'ultima_compra': compra.get('Ultima_Compra', ''),
                    'monto_total_formateado': formatear_precio(compra.get('Monto_Total', 0))
                }
            else:
                return {
                    'total_compras': 0,
                    'monto_total': 0.0,
                    'compra_promedio': 0.0,
                    'ultima_compra': '',
                    'monto_total_formateado': formatear_precio(0)
                }
        except Exception:
            return {}
    
    # ===============================
    # REPORTES Y ESTADÍSTICAS
    # ===============================
    
    @medir_tiempo_ejecucion
    def generar_reporte_compras_periodo(self, fecha_desde: str, fecha_hasta: str) -> Dict[str, Any]:
        """
        Genera reporte completo de compras por período
        
        Args:
            fecha_desde: Fecha inicio (YYYY-MM-DD)
            fecha_hasta: Fecha fin (YYYY-MM-DD)
        
        Returns:
            Reporte completo con estadísticas y análisis
        """
        try:
            # Obtener compras del período
            compras = safe_execute(
                self.compra_repo.get_compras_con_detalles,
                fecha_desde, fecha_hasta
            )
            
            if not compras:
                return crear_respuesta_qml(
                    True, 
                    "No hay compras en el período seleccionado",
                    {'compras': [], 'resumen': {}}
                )
            
            # Calcular estadísticas
            total_compras = len(compras)
            monto_total = sum(safe_float(c.get('Compra_Total', 0)) for c in compras)
            compra_promedio = monto_total / total_compras if total_compras > 0 else 0
            
            # Agrupar por proveedor
            compras_por_proveedor = {}
            for compra in compras:
                proveedor = compra.get('Proveedor', 'Sin proveedor')
                if proveedor not in compras_por_proveedor:
                    compras_por_proveedor[proveedor] = {
                        'compras': 0,
                        'monto': 0.0,
                        'items': 0
                    }
                
                compras_por_proveedor[proveedor]['compras'] += 1
                compras_por_proveedor[proveedor]['monto'] += safe_float(compra.get('Compra_Total', 0))
                compras_por_proveedor[proveedor]['items'] += safe_int(compra.get('Items_Comprados', 0))
            
            # Top proveedores
            top_proveedores = sorted(
                compras_por_proveedor.items(),
                key=lambda x: x[1]['monto'],
                reverse=True
            )[:5]
            
            # Productos más comprados en el período
            productos_mas_comprados = safe_execute(
                self.compra_repo.get_productos_mas_comprados,
                30,  # Últimos 30 días
                10   # Top 10
            ) or []
            
            # Preparar resumen
            resumen = {
                'periodo': {
                    'fecha_desde': formatear_fecha(fecha_desde),
                    'fecha_hasta': formatear_fecha(fecha_hasta)
                },
                'totales': {
                    'compras': total_compras,
                    'monto_total': monto_total,
                    'compra_promedio': compra_promedio,
                    'proveedores_utilizados': len(compras_por_proveedor),
                    'monto_total_formateado': formatear_precio(monto_total),
                    'compra_promedio_formateada': formatear_precio(compra_promedio)
                },
                'top_proveedores': [
                    {
                        'proveedor': prov[0],
                        'compras': prov[1]['compras'],
                        'monto': prov[1]['monto'],
                        'items': prov[1]['items'],
                        'monto_formateado': formatear_precio(prov[1]['monto'])
                    }
                    for prov in top_proveedores
                ],
                'productos_mas_comprados': productos_mas_comprados
            }
            
            return crear_respuesta_qml(
                True,
                f"Reporte generado: {total_compras} compras, {formatear_precio(monto_total)}",
                {
                    'compras': preparar_para_qml(compras),
                    'resumen': resumen,
                    'generado_en': datetime.now().strftime('%Y-%m-%d %H:%M:%S')
                }
            )
            
        except Exception as e:
            return crear_respuesta_qml(
                False,
                f"Error generando reporte: {str(e)}",
                codigo_error="REPORTE_ERROR"
            )
    
    def obtener_estadisticas_dashboard(self) -> Dict[str, Any]:
        """
        Obtiene estadísticas para el dashboard de compras
        
        Returns:
            Estadísticas preparadas para QML
        """
        try:
            # Estadísticas del mes actual
            estadisticas_mes = safe_execute(
                self.compra_repo.get_compras_del_mes
            )
            
            # Gastos del mes vs mes anterior
            fecha_mes_anterior = (datetime.now() - timedelta(days=30)).strftime('%Y-%m-%d')
            reporte_gastos = safe_execute(
                self.compra_repo.get_reporte_gastos_compras,
                30
            )
            
            # Productos más comprados
            top_productos = safe_execute(
                self.compra_repo.get_productos_mas_comprados,
                30,
                5
            ) or []
            
            # Proveedores más utilizados
            top_proveedores = safe_execute(
                self.compra_repo.get_proveedores_activos
            ) or []
            
            # Preparar respuesta
            dashboard = {
                'mes_actual': estadisticas_mes.get('resumen', {}) if estadisticas_mes else {},
                'gastos_periodo': reporte_gastos.get('resumen', {}) if reporte_gastos else {},
                'top_productos': top_productos[:5],
                'top_proveedores': top_proveedores[:5],
                'alertas': self._generar_alertas_dashboard(),
                'ultima_actualizacion': datetime.now().strftime('%H:%M:%S')
            }
            
            return preparar_para_qml(dashboard)
            
        except Exception as e:
            print(f"❌ Error obteniendo estadísticas dashboard: {e}")
            return {}
    
    def _generar_alertas_dashboard(self) -> List[Dict[str, Any]]:
        """Genera alertas para el dashboard"""
        alertas = []
        
        try:
            # Stock bajo
            productos_stock_bajo = safe_execute(
                self.producto_repo.get_productos_bajo_stock,
                Config.STOCK_MINIMO_DEFAULT
            )
            
            if productos_stock_bajo:
                alertas.append({
                    'tipo': 'stock_bajo',
                    'prioridad': 'alta',
                    'mensaje': f"{len(productos_stock_bajo)} productos con stock bajo",
                    'icono': '⚠️'
                })
            
            # Productos próximos a vencer
            productos_por_vencer = safe_execute(
                self.producto_repo.get_lotes_por_vencer,
                30  # Próximos 30 días
            )
            
            if productos_por_vencer:
                alertas.append({
                    'tipo': 'vencimiento',
                    'prioridad': 'media',
                    'mensaje': f"{len(productos_por_vencer)} lotes próximos a vencer",
                    'icono': '📅'
                })
            
            # Productos vencidos
            productos_vencidos = safe_execute(
                self.producto_repo.get_lotes_vencidos
            )
            
            if productos_vencidos:
                alertas.append({
                    'tipo': 'vencido',
                    'prioridad': 'critica',
                    'mensaje': f"{len(productos_vencidos)} lotes vencidos",
                    'icono': '🚫'
                })
        
        except Exception as e:
            alertas.append({
                'tipo': 'error',
                'prioridad': 'media',
                'mensaje': f"Error generando alertas: {str(e)}",
                'icono': '❌'
            })
        
        return alertas
    
    # ===============================
    # UTILIDADES PARA QML
    # ===============================
    
    def preparar_compra_para_qml(self, compra_id: int) -> Dict[str, Any]:
        """
        Prepara datos de compra completa para consumo en QML
        """
        try:
            compra = safe_execute(self.compra_repo.get_compra_completa, compra_id)
            
            if not compra:
                return crear_respuesta_qml(
                    False,
                    "Compra no encontrada",
                    codigo_error="COMPRA_NOT_FOUND"
                )
            
            # Preparar datos
            compra_qml = preparar_para_qml(compra)
            
            # Agregar campos calculados para QML
            if 'detalles' in compra_qml:
                for detalle in compra_qml['detalles']:
                    # Estado de vencimiento
                    if 'Fecha_Vencimiento' in detalle:
                        detalle['estado_vencimiento'] = calcular_estado_vencimiento(
                            detalle['Fecha_Vencimiento']
                        )
                        detalle['dias_vencimiento'] = dias_hasta_vencimiento(
                            detalle['Fecha_Vencimiento']
                        )
                    
                    # Formateo de precios
                    if 'Precio_Unitario' in detalle:
                        detalle['precio_unitario_formateado'] = formatear_precio(
                            detalle['Precio_Unitario']
                        )
                    
                    if 'Subtotal' in detalle:
                        detalle['subtotal_formateado'] = formatear_precio(
                            detalle['Subtotal']
                        )
            
            # Formatear total
            compra_qml['total_formateado'] = formatear_precio(compra_qml.get('Total', 0))
            compra_qml['fecha_formateada'] = formatear_fecha(compra_qml.get('Fecha'))
            
            return crear_respuesta_qml(
                True,
                "Compra obtenida correctamente",
                compra_qml
            )
            
        except Exception as e:
            return crear_respuesta_qml(
                False,
                f"Error obteniendo compra: {str(e)}",
                codigo_error="COMPRA_ERROR"
            )
    
    def formatear_lista_proveedores_para_combobox(self) -> List[Dict[str, Any]]:
        """
        Formatea lista de proveedores para ComboBox en QML
        """
        try:
            proveedores = safe_execute(self.compra_repo.get_proveedores_activos)
            
            if not proveedores:
                return []
            
            # Formatear para ComboBox
            proveedores_combobox = []
            
            for proveedor in proveedores:
                item = {
                    'id': proveedor.get('id', 0),
                    'text': proveedor.get('Nombre', 'Sin nombre'),
                    'descripcion': proveedor.get('Direccion', 'Sin dirección'),
                    'total_compras': proveedor.get('Total_Compras', 0),
                    'monto_total': formatear_precio(proveedor.get('Monto_Total', 0)),
                    'data': proveedor  # Datos completos
                }
                proveedores_combobox.append(item)
            
            # Ordenar por nombre
            proveedores_combobox.sort(key=lambda x: x['text'])
            
            return proveedores_combobox
            
        except Exception as e:
            print(f"❌ Error formateando proveedores para ComboBox: {e}")
            return []
    
    # ===============================
    # VALIDACIONES ESPECÍFICAS
    # ===============================
    
    def validar_integridad_compra(self, compra_id: int) -> Dict[str, Any]:
        """
        Valida la integridad completa de una compra
        Útil para auditorías y verificaciones
        """
        try:
            resultado = safe_execute(
                self.compra_repo.verificar_integridad_compra,
                compra_id
            )
            
            if not resultado:
                return crear_respuesta_qml(
                    False,
                    "Error verificando integridad",
                    codigo_error="INTEGRITY_ERROR"
                )
            
            # Agregar validaciones adicionales de negocio
            validaciones_adicionales = self._validar_reglas_negocio_compra(compra_id)
            resultado.update(validaciones_adicionales)
            
            return crear_respuesta_qml(
                resultado.get('valida', False),
                "Integridad verificada" if resultado.get('valida') else "Compra con inconsistencias",
                resultado
            )
            
        except Exception as e:
            return crear_respuesta_qml(
                False,
                f"Error en validación de integridad: {str(e)}",
                codigo_error="VALIDATION_ERROR"
            )
    
    def _validar_reglas_negocio_compra(self, compra_id: int) -> Dict[str, Any]:
        """Validaciones adicionales de reglas de negocio"""
        errores_negocio = []
        advertencias_negocio = []
        
        try:
            compra = safe_execute(self.compra_repo.get_compra_completa, compra_id)
            
            if compra and 'detalles' in compra:
                # Validar fechas de vencimiento
                for detalle in compra['detalles']:
                    if 'Fecha_Vencimiento' in detalle:
                        dias = dias_hasta_vencimiento(detalle['Fecha_Vencimiento'])
                        if dias < 0:
                            errores_negocio.append(
                                f"Lote {detalle.get('Id_Lote')} comprado vencido"
                            )
                        elif dias < self.dias_vencimiento_minimo:
                            advertencias_negocio.append(
                                f"Lote {detalle.get('Id_Lote')} con vencimiento próximo ({dias} días)"
                            )
                
                # Validar márgenes si hay precios de venta
                for detalle in compra['detalles']:
                    precio_compra = safe_float(detalle.get('Precio_Unitario', 0))
                    if precio_compra > 0:
                        # Obtener precio de venta actual del producto
                        producto = safe_execute(
                            self.producto_repo.get_by_id,
                            detalle.get('Id_Producto')
                        )
                        if producto:
                            precio_venta = safe_float(producto.get('Precio_venta', 0))
                            if precio_venta > 0:
                                margen = ((precio_venta - precio_compra) / precio_compra) * 100
                                if margen < self.margen_minimo * 100:
                                    advertencias_negocio.append(
                                        f"Producto {producto.get('Codigo')} con margen bajo ({margen:.1f}%)"
                                    )
        
        except Exception as e:
            errores_negocio.append(f"Error validando reglas de negocio: {str(e)}")
        
        return {
            'errores_negocio': errores_negocio,
            'advertencias_negocio': advertencias_negocio,
            'cumple_reglas_negocio': len(errores_negocio) == 0
        }