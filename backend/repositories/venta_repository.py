from typing import List, Dict, Any, Optional, Tuple
from datetime import datetime, timedelta
from decimal import Decimal

from ..core.base_repository import BaseRepository
from ..core.excepciones import (
    VentaError, StockInsuficienteError, ProductoNotFoundError,
    ValidationError, ExceptionHandler, validate_required, validate_positive_number
)
from .producto_repository import ProductoRepository

class VentaRepository(BaseRepository):
    """Repository para ventas con integración FIFO automática"""
    
    def __init__(self):
        super().__init__('Ventas', 'ventas')
        self.producto_repo = ProductoRepository()
        print("💰 VentaRepository inicializado con FIFO automático")
    
    def get_active(self) -> List[Dict[str, Any]]:
        """Obtiene ventas del día actual"""
        query = """
        SELECT v.*, u.Nombre + ' ' + u.Apellido_Paterno as Vendedor
        FROM Ventas v
        INNER JOIN Usuario u ON v.Id_Usuario = u.id
        WHERE CAST(v.Fecha AS DATE) = CAST(GETDATE() AS DATE)
        ORDER BY v.Fecha DESC
        """
        return self._execute_query(query)
    
    def get_ventas_con_detalles(self, fecha_desde: str = None, fecha_hasta: str = None) -> List[Dict[str, Any]]:
        """Obtiene ventas con sus detalles en período específico"""
        where_clause = ""
        params = []
        
        if fecha_desde and fecha_hasta:
            where_clause = "WHERE v.Fecha BETWEEN ? AND ?"
            params = [fecha_desde, fecha_hasta]
        elif fecha_desde:
            where_clause = "WHERE v.Fecha >= ?"
            params = [fecha_desde]
        elif fecha_hasta:
            where_clause = "WHERE v.Fecha <= ?"
            params = [fecha_hasta]
        
        query = f"""
        SELECT 
            v.id as Venta_ID,
            v.Fecha,
            v.Total as Venta_Total,
            u.Nombre + ' ' + u.Apellido_Paterno as Vendedor,
            COUNT(dv.id) as Items_Vendidos,
            SUM(dv.Cantidad_Unitario) as Unidades_Totales
        FROM Ventas v
        INNER JOIN Usuario u ON v.Id_Usuario = u.id
        LEFT JOIN DetallesVentas dv ON v.id = dv.Id_Venta
        {where_clause}
        GROUP BY v.id, v.Fecha, v.Total, u.Nombre, u.Apellido_Paterno
        ORDER BY v.Fecha DESC
        """
        return self._execute_query(query, tuple(params))
    
    def get_venta_completa(self, venta_id: int) -> Dict[str, Any]:
        """Obtiene venta con todos sus detalles"""
        validate_required(venta_id, "venta_id")
        
        # Obtener datos principales de la venta
        venta_query = """
        SELECT v.*, u.Nombre + ' ' + u.Apellido_Paterno as Vendedor,
               u.correo as Vendedor_Email
        FROM Ventas v
        INNER JOIN Usuario u ON v.Id_Usuario = u.id
        WHERE v.id = ?
        """
        venta = self._execute_query(venta_query, (venta_id,), fetch_one=True)
        
        if not venta:
            raise VentaError(f"Venta no encontrada: {venta_id}", venta_id)
        
        # Obtener detalles de la venta
        detalles_query = """
        SELECT 
            dv.*,
            p.Codigo as Producto_Codigo,
            p.Nombre as Producto_Nombre,
            m.Nombre as Marca_Nombre,
            l.Fecha_Vencimiento,
            (dv.Cantidad_Unitario * dv.Precio_Unitario) as Subtotal
        FROM DetallesVentas dv
        INNER JOIN Lote l ON dv.Id_Lote = l.id
        INNER JOIN Productos p ON l.Id_Producto = p.id
        INNER JOIN Marca m ON p.ID_Marca = m.id
        WHERE dv.Id_Venta = ?
        ORDER BY dv.id
        """
        detalles = self._execute_query(detalles_query, (venta_id,))
        
        venta['detalles'] = detalles
        venta['total_items'] = len(detalles)
        venta['total_unidades'] = sum(detalle['Cantidad_Unitario'] for detalle in detalles)
        
        return venta
    
    def get_ventas_por_periodo(self, periodo: str = 'hoy') -> List[Dict[str, Any]]:
        """Obtiene ventas por período (hoy, semana, mes)"""
        if periodo == 'hoy':
            where_clause = "WHERE CAST(v.Fecha AS DATE) = CAST(GETDATE() AS DATE)"
        elif periodo == 'semana':
            where_clause = "WHERE v.Fecha >= DATEADD(WEEK, -1, GETDATE())"
        elif periodo == 'mes':
            where_clause = "WHERE v.Fecha >= DATEADD(MONTH, -1, GETDATE())"
        else:
            where_clause = ""
        
        query = f"""
        SELECT v.*, u.Nombre + ' ' + u.Apellido_Paterno as Vendedor
        FROM Ventas v
        INNER JOIN Usuario u ON v.Id_Usuario = u.id
        {where_clause}
        ORDER BY v.Fecha DESC
        """
        return self._execute_query(query, use_cache=False)
    
    # ===============================
    # CREACIÓN DE VENTAS CON FIFO
    # ===============================
    
    @ExceptionHandler.handle_exception
    def crear_venta(self, usuario_id: int, items_venta: List[Dict[str, Any]]) -> Dict[str, Any]:
        """
        Crea una nueva venta con validación y aplicación automática de FIFO
        
        Args:
            usuario_id: ID del usuario vendedor
            items_venta: Lista de items [{'codigo': str, 'cantidad': int, 'precio': float}]
            
        Returns:
            Información completa de la venta creada
        """
        validate_required(usuario_id, "usuario_id")
        validate_required(items_venta, "items_venta")
        
        if not items_venta:
            raise VentaError("No se proporcionaron items para la venta")
        
        print(f"🛒 Iniciando venta - Usuario: {usuario_id}, Items: {len(items_venta)}")
        
        # 1. Validar y preparar items
        items_preparados = []
        total_venta = Decimal('0.00')
        
        for item in items_venta:
            item_preparado = self._validar_y_preparar_item(item)
            items_preparados.append(item_preparado)
            total_venta += item_preparado['subtotal']
        
        # 2. Crear venta principal
        venta_data = {
            'Id_Usuario': usuario_id,
            'Fecha': datetime.now(),
            'Total': float(total_venta)
        }
        
        venta_id = self.insert(venta_data)
        if not venta_id:
            raise VentaError("Error creando venta principal")
        
        print(f"💰 Venta creada - ID: {venta_id}, Total: ${total_venta}")
        
        # 3. Procesar items con FIFO y crear detalles
        detalles_creados = []
        operaciones_stock = []
        
        for item in items_preparados:
            detalles_item = self._procesar_item_con_fifo(venta_id, item)
            detalles_creados.extend(detalles_item)
        
        # 4. Verificar que se crearon detalles
        if not detalles_creados:
            # Eliminar venta si no se pudieron crear detalles
            self.delete(venta_id)
            raise VentaError("No se pudieron procesar los items de la venta")
        
        # 5. Retornar venta completa
        venta_completa = self.get_venta_completa(venta_id)
        
        print(f"✅ Venta completada - ID: {venta_id}, Detalles: {len(detalles_creados)}")
        
        return venta_completa
    
    def _validar_y_preparar_item(self, item: Dict[str, Any]) -> Dict[str, Any]:
        """Valida y prepara un item para la venta"""
        # Validaciones básicas
        codigo = item.get('codigo', '').strip()
        cantidad = item.get('cantidad', 0)
        precio = item.get('precio')
        
        validate_required(codigo, "codigo")
        validate_positive_number(cantidad, "cantidad")
        
        # Obtener producto
        producto = self.producto_repo.get_by_codigo(codigo)
        if not producto:
            raise ProductoNotFoundError(codigo=codigo)
        
        # Verificar disponibilidad FIFO
        disponibilidad = self.producto_repo.verificar_disponibilidad_fifo(
            producto['id'], cantidad
        )
        
        if not disponibilidad['disponible']:
            raise StockInsuficienteError(
                codigo, 
                disponibilidad['cantidad_total_disponible'], 
                cantidad
            )
        
        # Usar precio del producto si no se especifica
        if precio is None:
            precio = float(producto['Precio_venta'])
        else:
            validate_positive_number(precio, "precio")
        
        subtotal = Decimal(str(cantidad)) * Decimal(str(precio))
        
        return {
            'codigo': codigo,
            'producto_id': producto['id'],
            'producto_nombre': producto['Nombre'],
            'cantidad': cantidad,
            'precio': precio,
            'subtotal': subtotal,
            'disponibilidad': disponibilidad
        }
    
    def _procesar_item_con_fifo(self, venta_id: int, item: Dict[str, Any]) -> List[Dict[str, Any]]:
        """Procesa un item aplicando FIFO y creando detalles de venta"""
        detalles_creados = []
        
        # Reducir stock usando FIFO
        lotes_afectados = self.producto_repo.reducir_stock_fifo(
            item['producto_id'], 
            item['cantidad']
        )
        
        # Crear detalle de venta por cada lote usado
        for lote_info in lotes_afectados:
            detalle_data = {
                'Id_Venta': venta_id,
                'Id_Lote': lote_info['lote_id'],
                'Cantidad_Unitario': lote_info['cantidad_reducida'],
                'Precio_Unitario': item['precio'],
                'Detalles': f"Venta automática FIFO - {item['producto_nombre']}"
            }
            
            # Insertar detalle
            detalle_query = """
            INSERT INTO DetallesVentas (Id_Venta, Id_Lote, Cantidad_Unitario, Precio_Unitario, Detalles)
            OUTPUT INSERTED.id
            VALUES (?, ?, ?, ?, ?)
            """
            
            detalle_result = self._execute_query(
                detalle_query, 
                (venta_id, lote_info['lote_id'], lote_info['cantidad_reducida'], 
                 item['precio'], detalle_data['Detalles']),
                fetch_one=True
            )
            
            if detalle_result:
                detalle_id = detalle_result['id']
                detalles_creados.append({
                    'detalle_id': detalle_id,
                    'lote_id': lote_info['lote_id'],
                    'cantidad': lote_info['cantidad_reducida'],
                    'precio': item['precio']
                })
                print(f"📝 Detalle creado - ID: {detalle_id}, Lote: {lote_info['lote_id']}")
        
        return detalles_creados
    
    # ===============================
    # ANULACIÓN DE VENTAS
    # ===============================
    
    @ExceptionHandler.handle_exception
    def anular_venta(self, venta_id: int, motivo: str = "Anulación manual") -> bool:
        """
        Anula una venta y restaura el stock usando FIFO inverso
        
        Args:
            venta_id: ID de la venta a anular
            motivo: Motivo de la anulación
            
        Returns:
            True si se anuló correctamente
        """
        validate_required(venta_id, "venta_id")
        
        print(f"❌ Iniciando anulación - Venta ID: {venta_id}")
        
        # Obtener venta completa
        venta = self.get_venta_completa(venta_id)
        if not venta:
            raise VentaError(f"Venta no encontrada: {venta_id}", venta_id)
        
        # Restaurar stock por cada detalle
        operaciones = []
        
        for detalle in venta['detalles']:
            # Restaurar en el lote original
            restore_lote_query = """
            UPDATE Lote 
            SET Cantidad_Unitario = Cantidad_Unitario + ?
            WHERE id = ?
            """
            operaciones.append((restore_lote_query, (detalle['Cantidad_Unitario'], detalle['Id_Lote'])))
            
            # Restaurar stock total del producto
            restore_producto_query = """
            UPDATE Productos 
            SET Stock_Unitario = Stock_Unitario + ?
            WHERE id = (SELECT Id_Producto FROM Lote WHERE id = ?)
            """
            operaciones.append((restore_producto_query, (detalle['Cantidad_Unitario'], detalle['Id_Lote'])))
        
        # Eliminar detalles de venta
        delete_detalles_query = "DELETE FROM DetallesVentas WHERE Id_Venta = ?"
        operaciones.append((delete_detalles_query, (venta_id,)))
        
        # Eliminar venta
        delete_venta_query = "DELETE FROM Ventas WHERE id = ?"
        operaciones.append((delete_venta_query, (venta_id,)))
        
        # Ejecutar todas las operaciones en transacción
        success = self.execute_transaction(operaciones)
        
        if success:
            print(f"✅ Venta anulada - ID: {venta_id}, Items restaurados: {len(venta['detalles'])}")
        
        return success
    
    # ===============================
    # REPORTES Y ESTADÍSTICAS
    # ===============================
    
    def get_ventas_del_dia(self, fecha: str = None) -> Dict[str, Any]:
        """Obtiene resumen de ventas del día"""
        if not fecha:
            fecha = datetime.now().strftime('%Y-%m-%d')
        
        query = """
        SELECT 
            COUNT(v.id) as Total_Ventas,
            ISNULL(SUM(v.Total), 0) as Ingresos_Total,
            ISNULL(AVG(v.Total), 0) as Ticket_Promedio,
            SUM(dv.Cantidad_Unitario) as Unidades_Vendidas,
            COUNT(DISTINCT p.id) as Productos_Diferentes
        FROM Ventas v
        LEFT JOIN DetallesVentas dv ON v.id = dv.Id_Venta
        LEFT JOIN Lote l ON dv.Id_Lote = l.id
        LEFT JOIN Productos p ON l.Id_Producto = p.id
        WHERE CAST(v.Fecha AS DATE) = ?
        """
        
        resumen = self._execute_query(query, (fecha,), fetch_one=True)
        
        # Obtener ventas detalladas del día
        ventas_query = """
        SELECT v.*, u.Nombre + ' ' + u.Apellido_Paterno as Vendedor
        FROM Ventas v
        INNER JOIN Usuario u ON v.Id_Usuario = u.id
        WHERE CAST(v.Fecha AS DATE) = ?
        ORDER BY v.Fecha DESC
        """
        
        ventas = self._execute_query(ventas_query, (fecha,))
        
        return {
            'fecha': fecha,
            'resumen': resumen,
            'ventas': ventas
        }
    
    def get_top_productos_vendidos(self, dias: int = 30, limit: int = 10) -> List[Dict[str, Any]]:
        """Top productos más vendidos en período"""
        query = f"""
        SELECT TOP {limit}
            p.Codigo,
            p.Nombre as Producto_Nombre,
            m.Nombre as Marca_Nombre,
            SUM(dv.Cantidad_Unitario) as Cantidad_Vendida,
            COUNT(DISTINCT v.id) as Num_Ventas,
            SUM(dv.Cantidad_Unitario * dv.Precio_Unitario) as Ingresos_Total,
            AVG(dv.Precio_Unitario) as Precio_Promedio
        FROM Ventas v
        INNER JOIN DetallesVentas dv ON v.id = dv.Id_Venta
        INNER JOIN Lote l ON dv.Id_Lote = l.id
        INNER JOIN Productos p ON l.Id_Producto = p.id
        INNER JOIN Marca m ON p.ID_Marca = m.id
        WHERE v.Fecha >= DATEADD(DAY, -?, GETDATE())
        GROUP BY p.id, p.Codigo, p.Nombre, m.Nombre
        ORDER BY Cantidad_Vendida DESC
        """
        return self._execute_query(query, (dias,))
    
    def get_ventas_por_vendedor(self, fecha_desde: str = None, fecha_hasta: str = None) -> List[Dict[str, Any]]:
        """Estadísticas de ventas por vendedor"""
        where_clause = ""
        params = []
        
        if fecha_desde and fecha_hasta:
            where_clause = "WHERE v.Fecha BETWEEN ? AND ?"
            params = [fecha_desde, fecha_hasta]
        
        query = f"""
        SELECT 
            u.id as Usuario_ID,
            u.Nombre + ' ' + u.Apellido_Paterno as Vendedor,
            COUNT(v.id) as Total_Ventas,
            SUM(v.Total) as Ingresos_Total,
            AVG(v.Total) as Ticket_Promedio,
            MAX(v.Total) as Venta_Mayor,
            MIN(v.Total) as Venta_Menor
        FROM Usuario u
        LEFT JOIN Ventas v ON u.id = v.Id_Usuario
        {where_clause}
        GROUP BY u.id, u.Nombre, u.Apellido_Paterno
        HAVING COUNT(v.id) > 0
        ORDER BY Ingresos_Total DESC
        """
        return self._execute_query(query, tuple(params))
    
    def get_reporte_ingresos(self, periodo: int = 30) -> Dict[str, Any]:
        """Reporte de ingresos por período"""
        # Ingresos totales
        ingresos_query = """
        SELECT 
            SUM(Total) as Ingresos_Total,
            COUNT(*) as Total_Ventas,
            AVG(Total) as Ticket_Promedio
        FROM Ventas 
        WHERE Fecha >= DATEADD(DAY, -?, GETDATE())
        """
        
        ingresos = self._execute_query(ingresos_query, (periodo,), fetch_one=True)
        
        # Ingresos por día
        ingresos_diarios_query = """
        SELECT 
            CAST(Fecha AS DATE) as Fecha,
            SUM(Total) as Ingresos_Dia,
            COUNT(*) as Ventas_Dia
        FROM Ventas 
        WHERE Fecha >= DATEADD(DAY, -?, GETDATE())
        GROUP BY CAST(Fecha AS DATE)
        ORDER BY Fecha DESC
        """
        
        ingresos_diarios = self._execute_query(ingresos_diarios_query, (periodo,))
        
        return {
            'periodo_dias': periodo,
            'resumen': ingresos,
            'por_dia': ingresos_diarios
        }
    
    def verificar_integridad_venta(self, venta_id: int) -> Dict[str, Any]:
        """Verifica la integridad de una venta"""
        venta = self.get_venta_completa(venta_id)
        
        if not venta:
            return {'valida': False, 'errores': ['Venta no encontrada']}
        
        errores = []
        
        # Verificar que el total coincide con la suma de detalles
        total_calculado = sum(
            detalle['Cantidad_Unitario'] * detalle['Precio_Unitario'] 
            for detalle in venta['detalles']
        )
        
        if abs(total_calculado - venta['Total']) > 0.01:
            errores.append(f"Total inconsistente: DB={venta['Total']}, Calculado={total_calculado}")
        
        # Verificar que todos los lotes existen
        for detalle in venta['detalles']:
            lote_query = "SELECT id FROM Lote WHERE id = ?"
            lote = self._execute_query(lote_query, (detalle['Id_Lote'],), fetch_one=True)
            if not lote:
                errores.append(f"Lote {detalle['Id_Lote']} no existe")
        
        return {
            'valida': len(errores) == 0,
            'errores': errores,
            'total_db': venta['Total'],
            'total_calculado': total_calculado
        }