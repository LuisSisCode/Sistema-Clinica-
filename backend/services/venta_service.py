from typing import List, Dict, Any, Optional, Tuple
from datetime import datetime, timedelta
from decimal import Decimal, ROUND_HALF_UP
import json

from ..repositories.venta_repository import VentaRepository
from ..repositories.producto_repository import ProductoRepository
from ..core.excepciones import (
    VentaError, ProductoNotFoundError, StockInsuficienteError, ValidationError,
    ExceptionHandler, safe_execute, validate_required, validate_positive_number
)

class VentaService:
    """
    Servicio de lógica de negocio para ventas con reglas clínicas específicas
    Maneja orchestración entre VentaRepository y ProductoRepository
    """
    
    def __init__(self):
        self.venta_repo = VentaRepository()
        self.producto_repo = ProductoRepository()
        
        # Configuración de reglas de negocio
        self.config = {
            # Horarios de venta permitidos
            'horario_venta': {
                'apertura': 7,  # 7:00 AM
                'cierre': 22,   # 10:00 PM
                'permitir_fuera_horario': True  # Para emergencias
            },
            
            # Límites de venta
            'limites': {
                'max_items_por_venta': 50,
                'max_cantidad_por_item': 100,
                'max_valor_venta': 10000.00,
                'descuento_max_porcentaje': 20.0
            },
            
            # Descuentos automáticos
            'descuentos': {
                'empleados_clinica': 10.0,  # 10% descuento
                'adultos_mayores': 5.0,     # 5% descuento
                'compra_mayorista': 15.0,   # 15% descuento por volumen
                'umbral_mayorista': 1000.00 # Monto mínimo para descuento mayorista
            },
            
            # Productos controlados
            'productos_controlados': {
                'requiere_receta': ['ANTIBIOTICO', 'CONTROLADO'],
                'limite_mensual': 30,  # días de supply
                'verificar_duplicados': True
            }
        }
        
        print("💰 VentaService inicializado con reglas de negocio clínicas")
    
    # ===============================
    # PROCESAMIENTO DE CARRITO
    # ===============================
    
    @ExceptionHandler.handle_exception
    def validar_carrito(self, items_carrito: List[Dict[str, Any]], usuario_id: int) -> Dict[str, Any]:
        """
        Valida carrito completo antes de procesar venta
        
        Returns:
            {
                'valido': bool,
                'errores': [str],
                'advertencias': [str],
                'total_calculado': float,
                'items_procesados': [dict]
            }
        """
        validate_required(items_carrito, "items_carrito")
        validate_required(usuario_id, "usuario_id")
        
        if not items_carrito:
            return {
                'valido': False,
                'errores': ['Carrito vacío'],
                'advertencias': [],
                'total_calculado': 0.0,
                'items_procesados': []
            }
        
        errores = []
        advertencias = []
        items_procesados = []
        total_calculado = Decimal('0.00')
        
        # 1. Validar límites generales
        if len(items_carrito) > self.config['limites']['max_items_por_venta']:
            errores.append(f"Máximo {self.config['limites']['max_items_por_venta']} items por venta")
        
        # 2. Validar cada item
        for item in items_carrito:
            item_resultado = self._validar_item_carrito(item)
            
            if item_resultado['valido']:
                items_procesados.append(item_resultado['item_procesado'])
                total_calculado += Decimal(str(item_resultado['subtotal']))
            else:
                errores.extend(item_resultado['errores'])
            
            if item_resultado['advertencias']:
                advertencias.extend(item_resultado['advertencias'])
        
        # 3. Validar total de venta
        if float(total_calculado) > self.config['limites']['max_valor_venta']:
            errores.append(f"Valor máximo por venta: ${self.config['limites']['max_valor_venta']}")
        
        # 4. Validar horario de venta
        horario_resultado = self._validar_horario_venta()
        if not horario_resultado['permitido']:
            if self.config['horario_venta']['permitir_fuera_horario']:
                advertencias.append(horario_resultado['mensaje'])
            else:
                errores.append(horario_resultado['mensaje'])
        
        # 5. Aplicar descuentos automáticos si corresponde
        if total_calculado >= Decimal(str(self.config['descuentos']['umbral_mayorista'])):
            advertencias.append("Eligible para descuento mayorista")
        
        return {
            'valido': len(errores) == 0,
            'errores': errores,
            'advertencias': advertencias,
            'total_calculado': float(total_calculado),
            'items_procesados': items_procesados
        }
    
    def _validar_item_carrito(self, item: Dict[str, Any]) -> Dict[str, Any]:
        """Valida un item individual del carrito"""
        errores = []
        advertencias = []
        
        try:
            # Extraer datos del item
            codigo = item.get('codigo', '').strip()
            cantidad = item.get('cantidad', 0)
            precio_custom = item.get('precio', 0)
            
            if not codigo:
                return {'valido': False, 'errores': ['Código de producto requerido'], 'advertencias': []}
            
            if cantidad <= 0:
                return {'valido': False, 'errores': [f'Cantidad inválida para {codigo}'], 'advertencias': []}
            
            if cantidad > self.config['limites']['max_cantidad_por_item']:
                return {'valido': False, 'errores': [f'Cantidad máxima por item: {self.config["limites"]["max_cantidad_por_item"]}'], 'advertencias': []}
            
            # Obtener producto
            producto = safe_execute(self.producto_repo.get_by_codigo, codigo)
            if not producto:
                return {'valido': False, 'errores': [f'Producto no encontrado: {codigo}'], 'advertencias': []}
            
            # Verificar disponibilidad FIFO
            disponibilidad = safe_execute(
                self.producto_repo.verificar_disponibilidad_fifo,
                producto['id'], cantidad
            )
            
            if not disponibilidad['disponible']:
                return {
                    'valido': False, 
                    'errores': [f'Stock insuficiente para {codigo}. Disponible: {disponibilidad["cantidad_total_disponible"]}, Solicitado: {cantidad}'],
                    'advertencias': []
                }
            
            # Verificar productos por vencer
            if disponibilidad.get('tiene_vencidos'):
                advertencias.append(f'{codigo}: Contiene lotes vencidos (se omitirán automáticamente)')
            
            # Verificar si hay lotes próximos a vencer
            lotes_por_vencer = [
                lote for lote in disponibilidad.get('lotes_necesarios', [])
                if lote.get('estado') == 'POR_VENCER'
            ]
            
            if lotes_por_vencer:
                advertencias.append(f'{codigo}: {len(lotes_por_vencer)} lotes próximos a vencer')
            
            # Determinar precio final
            precio_producto = float(producto['Precio_venta'])
            precio_final = precio_custom if precio_custom > 0 else precio_producto
            
            # Verificar variación de precio
            if precio_custom > 0 and abs(precio_custom - precio_producto) > (precio_producto * 0.1):
                advertencias.append(f'{codigo}: Precio modificado en más del 10%')
            
            # Calcular subtotal
            subtotal = Decimal(str(cantidad)) * Decimal(str(precio_final))
            
            # Item procesado exitosamente
            item_procesado = {
                'codigo': codigo,
                'producto_id': producto['id'],
                'nombre': producto['Nombre'],
                'marca': producto.get('Marca_Nombre', ''),
                'cantidad': cantidad,
                'precio_original': precio_producto,
                'precio_final': precio_final,
                'subtotal': float(subtotal),
                'stock_disponible': disponibilidad['cantidad_total_disponible'],
                'lotes_a_usar': disponibilidad['lotes_necesarios'],
                'unidad_medida': producto.get('Unidad_Medida', 'unidad')
            }
            
            return {
                'valido': True,
                'errores': [],
                'advertencias': advertencias,
                'item_procesado': item_procesado,
                'subtotal': float(subtotal)
            }
            
        except Exception as e:
            return {
                'valido': False,
                'errores': [f'Error validando {codigo}: {str(e)}'],
                'advertencias': []
            }
    
    def _validar_horario_venta(self) -> Dict[str, Any]:
        """Valida si está dentro del horario de ventas permitido"""
        ahora = datetime.now()
        hora_actual = ahora.hour
        
        apertura = self.config['horario_venta']['apertura']
        cierre = self.config['horario_venta']['cierre']
        
        if apertura <= hora_actual <= cierre:
            return {'permitido': True, 'mensaje': 'Horario normal de ventas'}
        else:
            return {
                'permitido': False,
                'mensaje': f'Fuera de horario de ventas ({apertura}:00 - {cierre}:00)'
            }
    
    # ===============================
    # PROCESAMIENTO DE VENTAS
    # ===============================
    
    @ExceptionHandler.handle_exception
    def procesar_venta_completa(self, items_carrito: List[Dict[str, Any]], usuario_id: int,
                              opciones: Dict[str, Any] = None) -> Dict[str, Any]:
        """
        Procesa una venta completa con todas las validaciones y reglas de negocio
        
        Args:
            items_carrito: Lista de items del carrito
            usuario_id: ID del usuario vendedor
            opciones: Opciones adicionales (descuentos, notas, etc.)
            
        Returns:
            Información completa de la venta procesada con estadísticas
        """
        opciones = opciones or {}
        
        print(f"🛒 Iniciando procesamiento de venta completa - Usuario: {usuario_id}")
        
        # 1. Validar carrito completo
        validacion = self.validar_carrito(items_carrito, usuario_id)
        
        if not validacion['valido']:
            raise VentaError(
                f"Validación de carrito falló: {', '.join(validacion['errores'])}",
                items=items_carrito
            )
        
        # 2. Aplicar descuentos si corresponde
        items_con_descuento = self._aplicar_descuentos(
            validacion['items_procesados'],
            opciones.get('tipo_cliente'),
            opciones.get('descuento_manual', 0)
        )
        
        # 3. Preparar items para el repository
        items_para_venta = []
        total_final = Decimal('0.00')
        
        for item in items_con_descuento:
            item_venta = {
                'codigo': item['codigo'],
                'cantidad': item['cantidad'],
                'precio': item['precio_con_descuento']
            }
            items_para_venta.append(item_venta)
            total_final += Decimal(str(item['subtotal_con_descuento']))
        
        # 4. Crear la venta usando el repository
        venta = safe_execute(
            self.venta_repo.crear_venta,
            usuario_id,
            items_para_venta
        )
        
        if not venta:
            raise VentaError("Error creando venta en repository")
        
        # 5. Calcular estadísticas de la venta
        estadisticas = self._calcular_estadisticas_venta(venta, items_con_descuento)
        
        # 6. Generar resumen completo
        resumen_venta = {
            'venta_id': venta['id'],
            'numero_venta': f"V{str(venta['id']).zfill(6)}",
            'fecha_hora': venta['Fecha'],
            'usuario_id': usuario_id,
            'vendedor_nombre': venta.get('Vendedor', 'Usuario'),
            
            # Totales
            'subtotal': float(validacion['total_calculado']),
            'descuento_aplicado': float(estadisticas['descuento_total']),
            'total_final': float(total_final),
            'total_repository': venta['Total'],  # Para verificación
            
            # Items
            'items_vendidos': len(items_con_descuento),
            'unidades_totales': sum(item['cantidad'] for item in items_con_descuento),
            'items_detallados': items_con_descuento,
            
            # Estadísticas
            'estadisticas': estadisticas,
            'advertencias': validacion['advertencias'],
            
            # Información adicional
            'metodo_pago': opciones.get('metodo_pago', 'efectivo'),
            'notas': opciones.get('notas', ''),
            'requiere_factura': opciones.get('requiere_factura', False)
        }
        
        print(f"✅ Venta procesada exitosamente - ID: {venta['id']}, Total: ${total_final}")
        
        return resumen_venta
    
    def _aplicar_descuentos(self, items: List[Dict[str, Any]], tipo_cliente: str = None, 
                          descuento_manual: float = 0) -> List[Dict[str, Any]]:
        """Aplica descuentos según reglas de negocio"""
        items_con_descuento = []
        
        # Calcular total para verificar descuento mayorista
        total_venta = sum(Decimal(str(item['subtotal'])) for item in items)
        descuento_mayorista = total_venta >= Decimal(str(self.config['descuentos']['umbral_mayorista']))
        
        for item in items:
            item_copia = item.copy()
            descuento_porcentaje = 0
            
            # 1. Descuento por tipo de cliente
            if tipo_cliente == 'empleado':
                descuento_porcentaje = self.config['descuentos']['empleados_clinica']
            elif tipo_cliente == 'adulto_mayor':
                descuento_porcentaje = self.config['descuentos']['adultos_mayores']
            
            # 2. Descuento mayorista
            if descuento_mayorista:
                descuento_porcentaje = max(descuento_porcentaje, self.config['descuentos']['compra_mayorista'])
            
            # 3. Descuento manual (con límite)
            if descuento_manual > 0:
                descuento_manual_limitado = min(descuento_manual, self.config['limites']['descuento_max_porcentaje'])
                descuento_porcentaje = max(descuento_porcentaje, descuento_manual_limitado)
            
            # Aplicar descuento
            if descuento_porcentaje > 0:
                precio_original = Decimal(str(item['precio_final']))
                descuento_monto = precio_original * Decimal(str(descuento_porcentaje / 100))
                precio_con_descuento = precio_original - descuento_monto
                subtotal_con_descuento = precio_con_descuento * Decimal(str(item['cantidad']))
                
                item_copia.update({
                    'descuento_porcentaje': descuento_porcentaje,
                    'descuento_monto': float(descuento_monto),
                    'precio_con_descuento': float(precio_con_descuento),
                    'subtotal_con_descuento': float(subtotal_con_descuento)
                })
            else:
                item_copia.update({
                    'descuento_porcentaje': 0,
                    'descuento_monto': 0,
                    'precio_con_descuento': item['precio_final'],
                    'subtotal_con_descuento': item['subtotal']
                })
            
            items_con_descuento.append(item_copia)
        
        return items_con_descuento
    
    def _calcular_estadisticas_venta(self, venta: Dict[str, Any], items: List[Dict[str, Any]]) -> Dict[str, Any]:
        """Calcula estadísticas detalladas de la venta"""
        total_items = len(items)
        total_unidades = sum(item['cantidad'] for item in items)
        
        # Calcular descuentos
        descuento_total = sum(item.get('descuento_monto', 0) * item['cantidad'] for item in items)
        
        # Calcular márgenes (si tenemos precio de compra)
        margen_total = 0
        productos_con_margen = 0
        
        for item in items:
            # Aquí podríamos obtener el precio de compra para calcular margen real
            # Por ahora usamos estimación del 40% como margen promedio farmacéutico
            precio_estimado_compra = item['precio_con_descuento'] * 0.6
            margen_item = (item['precio_con_descuento'] - precio_estimado_compra) * item['cantidad']
            margen_total += margen_item
            productos_con_margen += 1
        
        # Estadísticas de lotes
        lotes_usados = set()
        lotes_por_vencer = 0
        
        for item in items:
            for lote in item.get('lotes_a_usar', []):
                lotes_usados.add(lote['lote_id'])
                if lote.get('estado') == 'POR_VENCER':
                    lotes_por_vencer += 1
        
        return {
            'total_items': total_items,
            'total_unidades': total_unidades,
            'descuento_total': descuento_total,
            'margen_estimado': margen_total,
            'margen_porcentaje': (margen_total / float(venta['Total']) * 100) if venta['Total'] > 0 else 0,
            'precio_promedio_item': float(venta['Total']) / total_items if total_items > 0 else 0,
            'lotes_usados': len(lotes_usados),
            'lotes_por_vencer_usados': lotes_por_vencer,
            'venta_mayorista': descuento_total > 0
        }
    
    # ===============================
    # VENTA RÁPIDA
    # ===============================
    
    @ExceptionHandler.handle_exception
    def venta_rapida_optimizada(self, codigo: str, cantidad: int, usuario_id: int,
                              precio_custom: float = None) -> Dict[str, Any]:
        """
        Venta rápida de un solo producto con validaciones mínimas pero completas
        """
        validate_required(codigo, "codigo")
        validate_positive_number(cantidad, "cantidad")
        validate_required(usuario_id, "usuario_id")
        
        print(f"⚡ Venta rápida - {codigo} x{cantidad}")
        
        # 1. Obtener y validar producto
        producto = safe_execute(self.producto_repo.get_by_codigo, codigo.strip())
        if not producto:
            raise ProductoNotFoundError(codigo=codigo)
        
        # 2. Verificar disponibilidad
        disponibilidad = safe_execute(
            self.producto_repo.verificar_disponibilidad_fifo,
            producto['id'], cantidad
        )
        
        if not disponibilidad['disponible']:
            raise StockInsuficienteError(codigo, disponibilidad['cantidad_total_disponible'], cantidad)
        
        # 3. Validar horario (advertencia solamente)
        horario = self._validar_horario_venta()
        advertencias = [] if horario['permitido'] else [horario['mensaje']]
        
        # 4. Preparar precio
        precio_final = precio_custom if precio_custom and precio_custom > 0 else float(producto['Precio_venta'])
        
        # 5. Crear venta simple
        item_venta = {
            'codigo': codigo.strip(),
            'cantidad': cantidad,
            'precio': precio_final
        }
        
        venta = safe_execute(self.venta_repo.crear_venta, usuario_id, [item_venta])
        
        if not venta:
            raise VentaError("Error en venta rápida")
        
        # 6. Generar resumen simple
        subtotal = cantidad * precio_final
        
        return {
            'venta_id': venta['id'],
            'numero_venta': f"VR{str(venta['id']).zfill(6)}",  # VR = Venta Rápida
            'codigo_producto': codigo,
            'nombre_producto': producto['Nombre'],
            'cantidad': cantidad,
            'precio_unitario': precio_final,
            'subtotal': subtotal,
            'total': venta['Total'],
            'fecha_hora': venta['Fecha'],
            'advertencias': advertencias,
            'stock_restante': disponibilidad['cantidad_total_disponible'] - cantidad
        }
    
    # ===============================
    # ANULACIÓN DE VENTAS
    # ===============================
    
    @ExceptionHandler.handle_exception
    def anular_venta_con_validaciones(self, venta_id: int, motivo: str, usuario_anulacion: int) -> Dict[str, Any]:
        """
        Anula venta con validaciones de reglas de negocio
        """
        validate_required(venta_id, "venta_id")
        validate_required(motivo, "motivo")
        validate_required(usuario_anulacion, "usuario_anulacion")
        
        print(f"❌ Anulando venta - ID: {venta_id}, Motivo: {motivo}")
        
        # 1. Obtener venta completa para validaciones
        venta = safe_execute(self.venta_repo.get_venta_completa, venta_id)
        if not venta:
            raise VentaError(f"Venta no encontrada: {venta_id}", venta_id)
        
        # 2. Validar que la venta se puede anular
        fecha_venta = venta['Fecha']
        if isinstance(fecha_venta, str):
            fecha_venta = datetime.fromisoformat(fecha_venta.replace('Z', '+00:00'))
        
        horas_transcurridas = (datetime.now() - fecha_venta).total_seconds() / 3600
        
        # Validar tiempo límite para anulación (24 horas)
        if horas_transcurridas > 24:
            raise VentaError(
                f"No se puede anular venta después de 24 horas. Transcurridas: {horas_transcurridas:.1f}h",
                venta_id
            )
        
        # 3. Verificar integridad antes de anular
        integridad = safe_execute(self.venta_repo.verificar_integridad_venta, venta_id)
        if not integridad['valida']:
            raise VentaError(
                f"Venta con problemas de integridad, no se puede anular: {', '.join(integridad['errores'])}",
                venta_id
            )
        
        # 4. Ejecutar anulación
        exito = safe_execute(
            self.venta_repo.anular_venta,
            venta_id,
            f"{motivo} - Anulado por usuario {usuario_anulacion}"
        )
        
        if not exito:
            raise VentaError("Error ejecutando anulación", venta_id)
        
        # 5. Calcular impacto de la anulación
        impacto = {
            'monto_devuelto': venta['Total'],
            'items_devueltos': len(venta['detalles']),
            'unidades_devueltas': sum(detalle['Cantidad_Unitario'] for detalle in venta['detalles']),
            'stock_restaurado': True,
            'fecha_anulacion': datetime.now(),
            'horas_transcurridas': horas_transcurridas
        }
        
        return {
            'venta_anulada': {
                'id': venta_id,
                'numero_original': f"V{str(venta_id).zfill(6)}",
                'fecha_original': fecha_venta,
                'total_original': venta['Total']
            },
            'anulacion': {
                'motivo': motivo,
                'usuario_anulacion': usuario_anulacion,
                'fecha_anulacion': datetime.now(),
                'exito': True
            },
            'impacto': impacto
        }
    
    # ===============================
    # CONSULTAS Y REPORTES ESPECIALIZADOS
    # ===============================
    
    def get_resumen_ventas_periodo(self, fecha_desde: str, fecha_hasta: str) -> Dict[str, Any]:
        """Resumen completo de ventas por período con métricas de negocio"""
        try:
            # Obtener datos base del repository
            ventas_periodo = safe_execute(
                self.venta_repo.get_ventas_con_detalles,
                fecha_desde, fecha_hasta
            )
            
            if not ventas_periodo:
                return self._resumen_vacio(fecha_desde, fecha_hasta)
            
            # Calcular métricas agregadas
            total_ventas = len(ventas_periodo)
            total_ingresos = sum(venta['Venta_Total'] for venta in ventas_periodo)
            total_items = sum(venta['Items_Vendidos'] for venta in ventas_periodo)
            total_unidades = sum(venta['Unidades_Totales'] for venta in ventas_periodo)
            
            # Métricas avanzadas
            ticket_promedio = total_ingresos / total_ventas if total_ventas > 0 else 0
            items_promedio = total_items / total_ventas if total_ventas > 0 else 0
            
            # Top vendedores
            vendedores = {}
            for venta in ventas_periodo:
                vendedor = venta['Vendedor']
                if vendedor not in vendedores:
                    vendedores[vendedor] = {'ventas': 0, 'ingresos': 0}
                vendedores[vendedor]['ventas'] += 1
                vendedores[vendedor]['ingresos'] += venta['Venta_Total']
            
            top_vendedores = sorted(
                [{'nombre': k, **v} for k, v in vendedores.items()],
                key=lambda x: x['ingresos'],
                reverse=True
            )[:5]
            
            # Ventas por día
            ventas_por_dia = {}
            for venta in ventas_periodo:
                fecha = venta['Fecha'].date() if hasattr(venta['Fecha'], 'date') else venta['Fecha'][:10]
                if fecha not in ventas_por_dia:
                    ventas_por_dia[fecha] = {'cantidad': 0, 'ingresos': 0}
                ventas_por_dia[fecha]['cantidad'] += 1
                ventas_por_dia[fecha]['ingresos'] += venta['Venta_Total']
            
            return {
                'periodo': {
                    'fecha_desde': fecha_desde,
                    'fecha_hasta': fecha_hasta,
                    'dias_periodo': len(ventas_por_dia)
                },
                'resumen_general': {
                    'total_ventas': total_ventas,
                    'total_ingresos': round(total_ingresos, 2),
                    'total_items': total_items,
                    'total_unidades': total_unidades,
                    'ticket_promedio': round(ticket_promedio, 2),
                    'items_promedio_venta': round(items_promedio, 2),
                    'ingresos_promedio_dia': round(total_ingresos / len(ventas_por_dia), 2) if ventas_por_dia else 0
                },
                'top_vendedores': top_vendedores,
                'ventas_por_dia': [
                    {'fecha': str(fecha), **datos} 
                    for fecha, datos in sorted(ventas_por_dia.items())
                ],
                'tendencia': self._calcular_tendencia(ventas_por_dia)
            }
            
        except Exception as e:
            raise VentaError(f"Error generando resumen de período: {str(e)}")
    
    def get_productos_mas_vendidos_periodo(self, dias: int = 30, limite: int = 20) -> List[Dict[str, Any]]:
        """Top productos con métricas de negocio adicionales"""
        try:
            productos_raw = safe_execute(
                self.venta_repo.get_top_productos_vendidos,
                dias, limite
            )
            
            # Enriquecer con información adicional
            productos_enriquecidos = []
            
            for producto in productos_raw:
                # Calcular métricas adicionales
                rotacion_diaria = producto['Cantidad_Vendida'] / dias if dias > 0 else 0
                ingreso_promedio_venta = producto['Ingresos_Total'] / producto['Num_Ventas'] if producto['Num_Ventas'] > 0 else 0
                
                # Obtener información de stock actual
                producto_info = safe_execute(self.producto_repo.get_by_codigo, producto['Codigo'])
                stock_actual = 0
                dias_inventario = 0
                
                if producto_info:
                    stock_actual = producto_info.get('Stock_Caja', 0) + producto_info.get('Stock_Unitario', 0)
                    dias_inventario = stock_actual / rotacion_diaria if rotacion_diaria > 0 else float('inf')
                
                productos_enriquecidos.append({
                    **producto,
                    'rotacion_diaria': round(rotacion_diaria, 2),
                    'ingreso_promedio_venta': round(ingreso_promedio_venta, 2),
                    'stock_actual': stock_actual,
                    'dias_inventario': round(dias_inventario, 1) if dias_inventario != float('inf') else 'N/A',
                    'categoria_rotacion': self._categorizar_rotacion(rotacion_diaria)
                })
            
            return productos_enriquecidos
            
        except Exception as e:
            raise VentaError(f"Error obteniendo productos más vendidos: {str(e)}")
    
    # ===============================
    # MÉTODOS AUXILIARES
    # ===============================
    
    def _resumen_vacio(self, fecha_desde: str, fecha_hasta: str) -> Dict[str, Any]:
        """Retorna estructura de resumen vacía"""
        return {
            'periodo': {'fecha_desde': fecha_desde, 'fecha_hasta': fecha_hasta, 'dias_periodo': 0},
            'resumen_general': {
                'total_ventas': 0, 'total_ingresos': 0.0, 'total_items': 0,
                'total_unidades': 0, 'ticket_promedio': 0.0, 'items_promedio_venta': 0.0,
                'ingresos_promedio_dia': 0.0
            },
            'top_vendedores': [],
            'ventas_por_dia': [],
            'tendencia': {'direccion': 'estable', 'cambio_porcentaje': 0}
        }
    
    def _calcular_tendencia(self, ventas_por_dia: Dict) -> Dict[str, Any]:
        """Calcula tendencia de ventas"""
        if len(ventas_por_dia) < 2:
            return {'direccion': 'estable', 'cambio_porcentaje': 0}
        
        dias_ordenados = sorted(ventas_por_dia.keys())
        primera_mitad = dias_ordenados[:len(dias_ordenados)//2]
        segunda_mitad = dias_ordenados[len(dias_ordenados)//2:]
        
        ingresos_primera = sum(ventas_por_dia[dia]['ingresos'] for dia in primera_mitad)
        ingresos_segunda = sum(ventas_por_dia[dia]['ingresos'] for dia in segunda_mitad)
        
        if ingresos_primera == 0:
            return {'direccion': 'estable', 'cambio_porcentaje': 0}
        
        cambio_porcentaje = ((ingresos_segunda - ingresos_primera) / ingresos_primera) * 100
        
        if cambio_porcentaje > 5:
            direccion = 'creciente'
        elif cambio_porcentaje < -5:
            direccion = 'decreciente'
        else:
            direccion = 'estable'
        
        return {
            'direccion': direccion,
            'cambio_porcentaje': round(cambio_porcentaje, 2)
        }
    
    def _categorizar_rotacion(self, rotacion_diaria: float) -> str:
        """Categoriza la rotación de productos"""
        if rotacion_diaria >= 5:
            return 'Alta'
        elif rotacion_diaria >= 1:
            return 'Media'
        elif rotacion_diaria >= 0.2:
            return 'Baja'
        else:
            return 'Muy Baja'
    
    # ===============================
    # CONFIGURACIÓN
    # ===============================
    
    def actualizar_configuracion(self, nueva_config: Dict[str, Any]):
        """Actualiza configuración de reglas de negocio"""
        for seccion, valores in nueva_config.items():
            if seccion in self.config:
                self.config[seccion].update(valores)
                print(f"📝 Configuración actualizada - {seccion}")
    
    def get_configuracion(self) -> Dict[str, Any]:
        """Obtiene configuración actual"""
        return self.config.copy()