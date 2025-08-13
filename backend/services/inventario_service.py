from typing import List, Dict, Any, Optional, Tuple
from datetime import datetime, timedelta
from decimal import Decimal

from ..core.config import Config
from ..core.excepciones import (
    ProductoNotFoundError, StockInsuficienteError, ProductoVencidoError,
    ValidationError, CompraError, VentaError, ExceptionHandler,
    validate_required, validate_positive_number, validate_stock_operation
)
from ..core.cache_system import get_cache, invalidate_after_update, cached_query
from ..repositories.producto_repository import ProductoRepository

class InventarioService:
    """
    Servicio principal para gestión de inventario con lógica FIFO
    
    Funcionalidades:
    - ✅ Gestión completa de productos y marcas
    - ✅ Control de stock con sistema FIFO
    - ✅ Alertas de vencimiento y stock bajo
    - ✅ Operaciones de compra y venta
    - ✅ Reportes y estadísticas
    - ✅ Validaciones y caché automático
    """
    
    def __init__(self):
        self.repository = ProductoRepository()
        self.cache = get_cache()
        self.stock_minimo = Config.STOCK_MINIMO_DEFAULT
        self.dias_alerta_vencimiento = Config.DIAS_VENCIMIENTO_ALERTA
        self.fifo_enabled = Config.FIFO_ENABLED
        
        print("🏪 InventarioService inicializado")
        print(f"📦 Stock mínimo: {self.stock_minimo}")
        print(f"⏰ Alerta vencimiento: {self.dias_alerta_vencimiento} días")
        print(f"🔄 FIFO habilitado: {self.fifo_enabled}")
    
    # ===============================
    # GESTIÓN DE PRODUCTOS
    # ===============================
    
    @ExceptionHandler.handle_exception
    @cached_query('productos', ttl=180)
    def get_all_productos(self, incluir_sin_stock: bool = False) -> List[Dict[str, Any]]:
        """
        Obtiene todos los productos con información de marca
        
        Args:
            incluir_sin_stock: Si incluir productos sin stock
        """
        if incluir_sin_stock:
            productos = self.repository.get_productos_con_marca()
        else:
            productos = self.repository.get_active()
        
        # Enriquecer con información adicional
        for producto in productos:
            producto['Stock_Total'] = (producto.get('Stock_Caja', 0) + 
                                     producto.get('Stock_Unitario', 0))
            producto['Valor_Inventario'] = (producto['Stock_Total'] * 
                                          producto.get('Precio_compra', 0))
            producto['Estado_Stock'] = self._clasificar_estado_stock(producto['Stock_Total'])
        
        print(f"📋 Productos obtenidos: {len(productos)}")
        return productos
    
    @ExceptionHandler.handle_exception
    def get_producto_by_codigo(self, codigo: str) -> Optional[Dict[str, Any]]:
        """Obtiene producto por código con información completa"""
        validate_required(codigo, "codigo")
        
        producto = self.repository.get_by_codigo(codigo)
        if not producto:
            raise ProductoNotFoundError(codigo=codigo)
        
        # Enriquecer con lotes y alertas
        producto['Stock_Total'] = (producto.get('Stock_Caja', 0) + 
                                 producto.get('Stock_Unitario', 0))
        producto['Lotes'] = self.repository.get_lotes_producto(producto['id'])
        producto['Alertas'] = self._generar_alertas_producto(producto)
        
        return producto
    
    @ExceptionHandler.handle_exception
    def get_producto_by_id(self, producto_id: int) -> Optional[Dict[str, Any]]:
        """Obtiene producto por ID con información completa"""
        validate_required(producto_id, "producto_id")
        
        producto = self.repository.get_by_id(producto_id)
        if not producto:
            raise ProductoNotFoundError(producto_id=producto_id)
        
        # Enriquecer con información adicional
        producto['Stock_Total'] = (producto.get('Stock_Caja', 0) + 
                                 producto.get('Stock_Unitario', 0))
        producto['Lotes'] = self.repository.get_lotes_producto(producto_id)
        producto['Alertas'] = self._generar_alertas_producto(producto)
        
        return producto
    
    @ExceptionHandler.handle_exception
    def buscar_productos(self, termino: str, incluir_sin_stock: bool = False) -> List[Dict[str, Any]]:
        """
        Búsqueda inteligente de productos
        
        Args:
            termino: Término de búsqueda (nombre o código)
            incluir_sin_stock: Si incluir productos sin stock
        """
        if not termino or len(termino.strip()) < 2:
            return []
        
        productos = self.repository.buscar_productos(termino, incluir_sin_stock)
        
        # Enriquecer resultados
        for producto in productos:
            producto['Stock_Total'] = (producto.get('Stock_Caja', 0) + 
                                     producto.get('Stock_Unitario', 0))
            producto['Estado_Stock'] = self._clasificar_estado_stock(producto['Stock_Total'])
            producto['Coincidencia'] = self._calcular_relevancia(producto, termino)
        
        # Ordenar por relevancia
        productos.sort(key=lambda x: x['Coincidencia'], reverse=True)
        
        print(f"🔍 Búsqueda '{termino}': {len(productos)} resultados")
        return productos
    
    @ExceptionHandler.handle_exception
    def crear_producto(self, data: Dict[str, Any]) -> int:
        """
        Crea nuevo producto con validaciones
        
        Args:
            data: Diccionario con datos del producto
            
        Returns:
            ID del producto creado
        """
        # Validaciones obligatorias
        validate_required(data.get('Codigo'), 'Codigo')
        validate_required(data.get('Nombre'), 'Nombre')
        validate_required(data.get('ID_Marca'), 'ID_Marca')
        validate_positive_number(data.get('Precio_compra', 0), 'Precio_compra')
        validate_positive_number(data.get('Precio_venta', 0), 'Precio_venta')
        
        # Validar que el código no exista
        existing = self.repository.get_by_codigo(data['Codigo'])
        if existing:
            raise ValidationError('Codigo', data['Codigo'], 'Código ya existe')
        
        # Validar precios lógicos
        if data.get('Precio_venta', 0) < data.get('Precio_compra', 0):
            raise ValidationError('Precio_venta', data['Precio_venta'], 
                                'Precio de venta debe ser mayor al de compra')
        
        # Crear producto
        producto_id = self.repository.create(data)
        
        # Invalidar caché
        invalidate_after_update(['productos', 'stock_producto'])
        
        print(f"✅ Producto creado: {data['Codigo']} - ID: {producto_id}")
        return producto_id
    
    @ExceptionHandler.handle_exception
    def actualizar_producto(self, producto_id: int, data: Dict[str, Any]) -> bool:
        """Actualiza producto existente"""
        validate_required(producto_id, "producto_id")
        
        # Verificar que existe
        producto_actual = self.repository.get_by_id(producto_id)
        if not producto_actual:
            raise ProductoNotFoundError(producto_id=producto_id)
        
        # Validar código único si se está cambiando
        if 'Codigo' in data and data['Codigo'] != producto_actual['Codigo']:
            existing = self.repository.get_by_codigo(data['Codigo'])
            if existing and existing['id'] != producto_id:
                raise ValidationError('Codigo', data['Codigo'], 'Código ya existe')
        
        # Validar precios si se proporcionan
        precio_compra = data.get('Precio_compra', producto_actual.get('Precio_compra', 0))
        precio_venta = data.get('Precio_venta', producto_actual.get('Precio_venta', 0))
        
        if precio_venta < precio_compra:
            raise ValidationError('Precio_venta', precio_venta, 
                                'Precio de venta debe ser mayor al de compra')
        
        # Actualizar
        success = self.repository.update(producto_id, data)
        
        if success:
            # Invalidar caché
            invalidate_after_update(['productos', 'stock_producto', 'precios'])
            print(f"✅ Producto actualizado: ID {producto_id}")
        
        return success
    
    @ExceptionHandler.handle_exception
    def eliminar_producto(self, producto_id: int, forzar: bool = False) -> bool:
        """
        Elimina producto con validaciones de seguridad
        
        Args:
            producto_id: ID del producto
            forzar: Si forzar eliminación aunque tenga stock o ventas
        """
        validate_required(producto_id, "producto_id")
        
        producto = self.repository.get_by_id(producto_id)
        if not producto:
            raise ProductoNotFoundError(producto_id=producto_id)
        
        if not forzar:
            # Verificar que no tenga stock
            stock_total = (producto.get('Stock_Caja', 0) + 
                          producto.get('Stock_Unitario', 0))
            if stock_total > 0:
                raise ValidationError('stock', stock_total, 
                                    'No se puede eliminar producto con stock. Use forzar=True')
            
            # Verificar que no tenga ventas recientes (último mes)
            # TODO: Implementar verificación de ventas recientes
        
        success = self.repository.delete(producto_id)
        
        if success:
            # Invalidar caché
            invalidate_after_update(['productos', 'stock_producto'])
            print(f"🗑️ Producto eliminado: ID {producto_id}")
        
        return success
    
    # ===============================
    # GESTIÓN DE STOCK Y LOTES
    # ===============================
    
    @ExceptionHandler.handle_exception
    def verificar_disponibilidad(self, producto_codigo: str, cantidad: int) -> Dict[str, Any]:
        """
        Verifica disponibilidad de stock para venta
        
        Returns:
            {
                'disponible': bool,
                'stock_actual': int,
                'cantidad_solicitada': int,
                'lotes_necesarios': List[Dict],
                'alertas': List[str]
            }
        """
        validate_required(producto_codigo, "producto_codigo")
        validate_positive_number(cantidad, "cantidad")
        
        producto = self.repository.get_by_codigo(producto_codigo)
        if not producto:
            raise ProductoNotFoundError(codigo=producto_codigo)
        
        # Verificar disponibilidad con FIFO
        disponibilidad = self.repository.verificar_disponibilidad_fifo(producto['id'], cantidad)
        
        stock_actual = (producto.get('Stock_Caja', 0) + 
                       producto.get('Stock_Unitario', 0))
        
        alertas = []
        
        # Generar alertas
        if not disponibilidad['disponible']:
            alertas.append(f"Stock insuficiente. Disponible: {stock_actual}, Solicitado: {cantidad}")
        
        if disponibilidad['tiene_vencidos']:
            alertas.append("⚠️ Existen lotes vencidos en el producto")
        
        # Verificar lotes próximos a vencer
        for lote in disponibilidad['lotes_necesarios']:
            if lote['estado'] == 'POR_VENCER':
                alertas.append(f"⏰ Lote próximo a vencer: {lote['fecha_vencimiento']}")
        
        return {
            'disponible': disponibilidad['disponible'],
            'stock_actual': stock_actual,
            'cantidad_solicitada': cantidad,
            'cantidad_faltante': disponibilidad.get('cantidad_faltante', 0),
            'lotes_necesarios': disponibilidad['lotes_necesarios'],
            'alertas': alertas
        }
    
    @ExceptionHandler.handle_exception
    def procesar_venta(self, items_venta: List[Dict[str, Any]], 
                      permitir_vencidos: bool = False) -> Dict[str, Any]:
        """
        Procesa venta reduciendo stock con FIFO
        
        Args:
            items_venta: Lista de items [{'codigo': str, 'cantidad': int, 'precio': float}]
            permitir_vencidos: Si permitir venta de productos próximos a vencer
            
        Returns:
            Resumen de la operación con lotes afectados
        """
        if not items_venta:
            raise VentaError("Lista de items vacía")
        
        total_venta = 0
        items_procesados = []
        lotes_afectados_total = []
        
        try:
            for item in items_venta:
                codigo = item.get('codigo')
                cantidad = item.get('cantidad', 0)
                precio_unitario = item.get('precio', 0)
                
                validate_required(codigo, f"codigo del item")
                validate_positive_number(cantidad, f"cantidad del item {codigo}")
                validate_positive_number(precio_unitario, f"precio del item {codigo}")
                
                # Obtener producto
                producto = self.repository.get_by_codigo(codigo)
                if not producto:
                    raise ProductoNotFoundError(codigo=codigo)
                
                # Verificar disponibilidad
                disponibilidad = self.verificar_disponibilidad(codigo, cantidad)
                if not disponibilidad['disponible']:
                    raise StockInsuficienteError(codigo, disponibilidad['stock_actual'], cantidad)
                
                # Procesar reducción de stock
                lotes_afectados = self.repository.reducir_stock_fifo(
                    producto['id'], cantidad, permitir_vencidos
                )
                
                subtotal = cantidad * precio_unitario
                total_venta += subtotal
                
                items_procesados.append({
                    'codigo': codigo,
                    'nombre': producto['Nombre'],
                    'cantidad': cantidad,
                    'precio_unitario': precio_unitario,
                    'subtotal': subtotal,
                    'lotes_afectados': lotes_afectados
                })
                
                lotes_afectados_total.extend(lotes_afectados)
            
            # Invalidar caché después de la venta
            invalidate_after_update(['productos', 'stock_producto', 'ventas_today'])
            
            resultado = {
                'success': True,
                'items_procesados': items_procesados,
                'total_items': len(items_procesados),
                'total_venta': total_venta,
                'lotes_afectados': lotes_afectados_total,
                'fecha_procesamiento': datetime.now().isoformat()
            }
            
            print(f"💰 Venta procesada: {len(items_procesados)} items, Total: ${total_venta:.2f}")
            return resultado
            
        except Exception as e:
            # Si hay error, toda la venta falla (podríamos implementar rollback)
            raise VentaError(f"Error procesando venta: {str(e)}", items=items_venta)
    
    @ExceptionHandler.handle_exception
    def procesar_compra(self, items_compra: List[Dict[str, Any]], 
                       proveedor_id: int = None) -> Dict[str, Any]:
        """
        Procesa compra aumentando stock con nuevos lotes
        
        Args:
            items_compra: Lista de items con datos de compra
            proveedor_id: ID del proveedor (opcional)
            
        Returns:
            Resumen de la operación
        """
        if not items_compra:
            raise CompraError("Lista de items de compra vacía")
        
        total_compra = 0
        items_procesados = []
        lotes_creados = []
        
        try:
            for item in items_compra:
                producto_id = item.get('producto_id')
                codigo = item.get('codigo')
                cantidad_caja = item.get('cantidad_caja', 0)
                cantidad_unitario = item.get('cantidad_unitario', 0)
                precio_compra = item.get('precio_compra', 0)
                fecha_vencimiento = item.get('fecha_vencimiento')
                
                # Validaciones
                if not producto_id and not codigo:
                    raise ValidationError('producto', None, 'Debe proporcionar producto_id o codigo')
                
                validate_positive_number(precio_compra, f"precio_compra")
                validate_required(fecha_vencimiento, f"fecha_vencimiento")
                
                if cantidad_caja <= 0 and cantidad_unitario <= 0:
                    raise ValidationError('cantidad', 0, 'Debe proporcionar cantidad_caja o cantidad_unitario')
                
                # Obtener producto si se proporciona código
                if codigo and not producto_id:
                    producto = self.repository.get_by_codigo(codigo)
                    if not producto:
                        raise ProductoNotFoundError(codigo=codigo)
                    producto_id = producto['id']
                
                # Procesar aumento de stock
                lote_id = self.repository.aumentar_stock_compra(
                    producto_id, cantidad_caja, cantidad_unitario, 
                    fecha_vencimiento, precio_compra
                )
                
                cantidad_total = cantidad_caja + cantidad_unitario
                subtotal = cantidad_total * precio_compra
                total_compra += subtotal
                
                items_procesados.append({
                    'producto_id': producto_id,
                    'codigo': codigo,
                    'cantidad_caja': cantidad_caja,
                    'cantidad_unitario': cantidad_unitario,
                    'cantidad_total': cantidad_total,
                    'precio_compra': precio_compra,
                    'subtotal': subtotal,
                    'lote_id': lote_id,
                    'fecha_vencimiento': fecha_vencimiento
                })
                
                if lote_id:
                    lotes_creados.append(lote_id)
            
            # Invalidar caché después de la compra
            invalidate_after_update(['productos', 'stock_producto', 'lotes_activos'])
            
            resultado = {
                'success': True,
                'items_procesados': items_procesados,
                'total_items': len(items_procesados),
                'total_compra': total_compra,
                'lotes_creados': lotes_creados,
                'proveedor_id': proveedor_id,
                'fecha_procesamiento': datetime.now().isoformat()
            }
            
            print(f"🛒 Compra procesada: {len(items_procesados)} items, Total: ${total_compra:.2f}")
            return resultado
            
        except Exception as e:
            raise CompraError(f"Error procesando compra: {str(e)}", proveedor_id=proveedor_id, total=total_compra)
    
    # ===============================
    # ALERTAS Y REPORTES
    # ===============================
    
    @ExceptionHandler.handle_exception
    def get_productos_stock_bajo(self, stock_minimo: int = None) -> List[Dict[str, Any]]:
        """Obtiene productos con stock bajo"""
        if stock_minimo is None:
            stock_minimo = self.stock_minimo
        
        productos = self.repository.get_productos_bajo_stock(stock_minimo)
        
        # Enriquecer con información adicional
        for producto in productos:
            producto['Dias_Sin_Stock'] = self._estimar_dias_sin_stock(producto)
            producto['Sugerencia_Compra'] = self._calcular_sugerencia_compra(producto)
        
        print(f"⚠️ Productos con stock bajo: {len(productos)}")
        return productos
    
    @ExceptionHandler.handle_exception
    def get_productos_vencimiento(self, dias_adelante: int = None) -> Dict[str, Any]:
        """Obtiene reporte completo de vencimientos"""
        if dias_adelante is None:
            dias_adelante = self.dias_alerta_vencimiento
        
        reporte = self.repository.get_reporte_vencimientos(dias_adelante)
        
        # Agregar estadísticas adicionales
        reporte['resumen'] = {
            'total_productos_afectados': len(set(
                [item['Id_Producto'] for item in reporte['vencidos']] +
                [item['Id_Producto'] for item in reporte['por_vencer']]
            )),
            'valor_en_riesgo': self._calcular_valor_en_riesgo(reporte),
            'recomendaciones': self._generar_recomendaciones_vencimiento(reporte)
        }
        
        print(f"📅 Reporte vencimientos: {reporte['total_vencidos']} vencidos, {reporte['total_por_vencer']} por vencer")
        return reporte
    
    @ExceptionHandler.handle_exception
    @cached_query('productos_vendidos', ttl=3600)
    def get_productos_mas_vendidos(self, dias: int = 30, limit: int = 20) -> List[Dict[str, Any]]:
        """Obtiene productos más vendidos con análisis"""
        productos = self.repository.get_productos_mas_vendidos(dias)
        
        # Análisis adicional
        for producto in productos[:limit]:
            producto['Tendencia'] = self._analizar_tendencia_venta(producto, dias)
            producto['Rotacion'] = self._calcular_rotacion_inventario(producto)
        
        print(f"📈 Top {len(productos)} productos más vendidos ({dias} días)")
        return productos[:limit]
    
    @ExceptionHandler.handle_exception
    @cached_query('valor_inventario', ttl=1800)
    def get_resumen_inventario(self) -> Dict[str, Any]:
        """Resumen completo del inventario"""
        valor_inventario = self.repository.get_valor_inventario()
        stock_bajo = len(self.get_productos_stock_bajo())
        vencimientos = self.get_productos_vencimiento()
        
        # Análisis de categorías
        productos = self.get_all_productos(incluir_sin_stock=True)
        categorias_stock = self._analizar_categorias_stock(productos)
        
        resumen = {
            **valor_inventario,
            'productos_stock_bajo': stock_bajo,
            'productos_vencidos': vencimientos['total_vencidos'],
            'productos_por_vencer': vencimientos['total_por_vencer'],
            'categorias_stock': categorias_stock,
            'eficiencia_inventario': self._calcular_eficiencia_inventario(valor_inventario),
            'fecha_reporte': datetime.now().isoformat()
        }
        
        print("📊 Resumen de inventario generado")
        return resumen
    
    # ===============================
    # MÉTODOS AUXILIARES PRIVADOS
    # ===============================
    
    def _clasificar_estado_stock(self, stock: int) -> str:
        """Clasifica el estado del stock"""
        if stock <= 0:
            return "SIN_STOCK"
        elif stock <= self.stock_minimo:
            return "STOCK_BAJO"
        elif stock <= self.stock_minimo * 2:
            return "STOCK_MEDIO"
        else:
            return "STOCK_ALTO"
    
    def _calcular_relevancia(self, producto: Dict, termino: str) -> float:
        """Calcula relevancia de búsqueda"""
        relevancia = 0
        termino_lower = termino.lower()
        
        # Coincidencia exacta en código (máxima prioridad)
        if producto.get('Codigo', '').lower() == termino_lower:
            relevancia += 100
        elif termino_lower in producto.get('Codigo', '').lower():
            relevancia += 50
        
        # Coincidencia en nombre
        nombre = producto.get('Nombre', '').lower()
        if termino_lower in nombre:
            if nombre.startswith(termino_lower):
                relevancia += 30
            else:
                relevancia += 20
        
        return relevancia
    
    def _generar_alertas_producto(self, producto: Dict) -> List[str]:
        """Genera alertas específicas para un producto"""
        alertas = []
        stock_total = producto.get('Stock_Total', 0)
        
        if stock_total <= 0:
            alertas.append("❌ Producto sin stock")
        elif stock_total <= self.stock_minimo:
            alertas.append(f"⚠️ Stock bajo: {stock_total} unidades")
        
        # Verificar lotes próximos a vencer si existen
        lotes = producto.get('Lotes', [])
        for lote in lotes:
            if lote.get('Estado_Vencimiento') == 'VENCIDO':
                alertas.append(f"❌ Lote vencido: {lote['Fecha_Vencimiento']}")
            elif lote.get('Estado_Vencimiento') == 'POR_VENCER':
                alertas.append(f"⏰ Lote próximo a vencer: {lote['Fecha_Vencimiento']}")
        
        return alertas
    
    def _estimar_dias_sin_stock(self, producto: Dict) -> int:
        """Estima días hasta quedarse sin stock basado en ventas"""
        # Implementación simplificada - podría usar datos históricos reales
        stock_actual = producto.get('Stock_Total', 0)
        if stock_actual <= 0:
            return 0
        
        # Asumir venta promedio diaria (podría calcularse desde ventas reales)
        venta_diaria_estimada = max(1, stock_actual // 30)  # Aproximación
        return stock_actual // venta_diaria_estimada
    
    def _calcular_sugerencia_compra(self, producto: Dict) -> int:
        """Calcula sugerencia de cantidad a comprar"""
        stock_actual = producto.get('Stock_Total', 0)
        # Sugerencia: cubrir para 60 días
        return max(self.stock_minimo * 2, self.stock_minimo * 4 - stock_actual)
    
    def _calcular_valor_en_riesgo(self, reporte_vencimientos: Dict) -> float:
        """Calcula valor monetario en riesgo por vencimientos"""
        valor_riesgo = 0
        for lote in reporte_vencimientos.get('vencidos', []) + reporte_vencimientos.get('por_vencer', []):
            # Aproximación del valor (tendríamos que obtener precios)
            valor_riesgo += lote.get('Stock_Lote', 0) * 10  # Precio promedio estimado
        return valor_riesgo
    
    def _generar_recomendaciones_vencimiento(self, reporte: Dict) -> List[str]:
        """Genera recomendaciones basadas en vencimientos"""
        recomendaciones = []
        
        if reporte['total_vencidos'] > 0:
            recomendaciones.append(f"🗑️ Revisar {reporte['total_vencidos']} lotes vencidos para descarte")
        
        if reporte['total_por_vencer'] > 0:
            recomendaciones.append(f"⚡ Promocionar {reporte['total_por_vencer']} productos próximos a vencer")
        
        if reporte['total_vencidos'] + reporte['total_por_vencer'] > 10:
            recomendaciones.append("📋 Revisar políticas de compra para reducir vencimientos")
        
        return recomendaciones
    
    def _analizar_tendencia_venta(self, producto: Dict, dias: int) -> str:
        """Analiza tendencia de venta de un producto"""
        # Implementación simplificada
        total_vendido = producto.get('Total_Vendido', 0)
        promedio_diario = total_vendido / dias
        
        if promedio_diario >= 5:
            return "ALTA"
        elif promedio_diario >= 2:
            return "MEDIA"
        else:
            return "BAJA"
    
    def _calcular_rotacion_inventario(self, producto: Dict) -> float:
        """Calcula rotación de inventario"""
        # Simplificado: ventas / stock promedio
        total_vendido = producto.get('Total_Vendido', 0)
        stock_actual = producto.get('Stock_Actual', 1)
        return round(total_vendido / max(stock_actual, 1), 2)
    
    def _analizar_categorias_stock(self, productos: List[Dict]) -> Dict[str, int]:
        """Analiza distribución por categorías de stock"""
        categorias = {"SIN_STOCK": 0, "STOCK_BAJO": 0, "STOCK_MEDIO": 0, "STOCK_ALTO": 0}
        
        for producto in productos:
            estado = self._clasificar_estado_stock(producto.get('Stock_Total', 0))
            categorias[estado] += 1
        
        return categorias
    
    def _calcular_eficiencia_inventario(self, valor_inventario: Dict) -> Dict[str, Any]:
        """Calcula métricas de eficiencia del inventario"""
        valor_compra = valor_inventario.get('Valor_Compra', 0)
        valor_venta = valor_inventario.get('Valor_Venta', 0)
        
        margen_potencial = valor_venta - valor_compra if valor_compra > 0 else 0
        margen_porcentaje = (margen_potencial / valor_compra * 100) if valor_compra > 0 else 0
        
        return {
            'margen_potencial': round(margen_potencial, 2),
            'margen_porcentaje': round(margen_porcentaje, 2),
            'rotacion_estimada': 'Media'  # Podría calcularse con datos históricos
        }
    
    # ===============================
    # UTILIDADES PÚBLICAS
    # ===============================
    
    def generar_codigo_producto(self, prefijo: str = "PROD") -> str:
        """Genera código único para nuevo producto"""
        import random
        timestamp = int(datetime.now().timestamp())
        random_num = random.randint(100, 999)
        return f"{prefijo}{timestamp}{random_num}"
    
    def validar_fecha_vencimiento(self, fecha_vencimiento: str, dias_minimos: int = 30) -> bool:
        """Valida que la fecha de vencimiento sea apropiada"""
        try:
            fecha = datetime.strptime(fecha_vencimiento, '%Y-%m-%d')
            fecha_minima = datetime.now() + timedelta(days=dias_minimos)
            return fecha >= fecha_minima
        except:
            return False
    
    def get_estadisticas_cache(self) -> Dict[str, Any]:
        """Obtiene estadísticas del caché para debugging"""
        return self.cache.get_stats()
    
    def limpiar_cache_inventario(self) -> int:
        """Limpia caché relacionado con inventario"""
        cache_types = ['productos', 'stock_producto', 'lotes_activos', 'precios']
        total_removed = 0
        for cache_type in cache_types:
            total_removed += self.cache.invalidate_by_type(cache_type)
        return total_removed
    
    def __del__(self):
        """Destructor para logging"""
        print("🏪 InventarioService destruido")