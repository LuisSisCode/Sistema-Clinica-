from typing import List, Dict, Any, Optional, Tuple
from datetime import datetime, timedelta
from decimal import Decimal

from ..core.base_repository import BaseRepository
from ..core.excepciones import (
    ProductoNotFoundError, StockInsuficienteError, ProductoVencidoError,
    ValidationError, ExceptionHandler, validate_required, validate_positive_number
)

class ProductoRepository(BaseRepository):
    """Repository para productos con lógica FIFO de lotes y control de vencimientos"""
    
    def __init__(self):
        super().__init__('Productos', 'productos')
        print("🏪 ProductoRepository inicializado con FIFO")
    
    def get_active(self) -> List[Dict[str, Any]]:
        """Obtiene productos activos (con stock > 0)"""
        query = """
        SELECT p.*, m.Nombre as Marca_Nombre 
        FROM Productos p
        INNER JOIN Marca m ON p.ID_Marca = m.id
        WHERE (p.Stock_Caja + p.Stock_Unitario) > 0
        ORDER BY p.Nombre
        """
        return self._execute_query(query)
    
    def get_by_codigo(self, codigo: str) -> Optional[Dict[str, Any]]:
        """Obtiene producto por código único"""
        validate_required(codigo, "codigo")
        
        query = """
        SELECT p.*, m.Nombre as Marca_Nombre, m.Detalles as Marca_Detalles
        FROM Productos p
        INNER JOIN Marca m ON p.ID_Marca = m.id
        WHERE p.Codigo = ?
        """
        return self._execute_query(query, (codigo,), fetch_one=True)
    
    def get_productos_con_marca(self) -> List[Dict[str, Any]]:
        """Obtiene todos los productos con información de marca"""
        query = """
        SELECT 
            p.id, p.Codigo, p.Nombre, p.Detalles as Producto_Detalles,
            p.Precio_compra, p.Precio_venta, p.Stock_Caja, p.Stock_Unitario,
            p.Unidad_Medida, p.Fecha_Venc,
            m.id as Marca_ID, m.Nombre as Marca_Nombre, m.Detalles as Marca_Detalles,
            (p.Stock_Caja + p.Stock_Unitario) as Stock_Total
        FROM Productos p
        INNER JOIN Marca m ON p.ID_Marca = m.id
        ORDER BY p.Nombre
        """
        # DEBUG: Agregar logging detallado
        result = self._execute_query(query)
        
        return result
    
    def buscar_productos(self, termino: str, incluir_sin_stock: bool = False) -> List[Dict[str, Any]]:
        """Busca productos por nombre o código"""
        if not termino:
            return []
        
        stock_condition = "" if incluir_sin_stock else "AND (p.Stock_Caja + p.Stock_Unitario) > 0"
        
        query = f"""
        SELECT p.*, m.Nombre as Marca_Nombre,
               (p.Stock_Caja + p.Stock_Unitario) as Stock_Total
        FROM Productos p
        INNER JOIN Marca m ON p.ID_Marca = m.id
        WHERE (p.Nombre LIKE ? OR p.Codigo LIKE ?) {stock_condition}
        ORDER BY p.Nombre
        """
        termino_like = f"%{termino}%"
        return self._execute_query(query, (termino_like, termino_like))
    
    def get_productos_bajo_stock(self, stock_minimo: int = 10) -> List[Dict[str, Any]]:
        """Obtiene productos con stock bajo"""
        query = """
        SELECT p.*, m.Nombre as Marca_Nombre,
               (p.Stock_Caja + p.Stock_Unitario) as Stock_Total
        FROM Productos p
        INNER JOIN Marca m ON p.ID_Marca = m.id
        WHERE (p.Stock_Caja + p.Stock_Unitario) <= ?
        ORDER BY (p.Stock_Caja + p.Stock_Unitario) ASC
        """
        return self._execute_query(query, (stock_minimo,), use_cache=False)
    
    # ===============================
    # GESTIÓN DE LOTES FIFO
    # ===============================
    
    def get_lotes_producto(self, producto_id: int, solo_activos: bool = True) -> List[Dict[str, Any]]:
        """Obtiene lotes de un producto ordenados por FIFO"""
        validate_required(producto_id, "producto_id")
        
        where_condition = "AND (l.Cantidad_Caja + l.Cantidad_Unitario) > 0" if solo_activos else ""
        
        query = f"""
        SELECT l.*, p.Codigo, p.Nombre as Producto_Nombre,
               (l.Cantidad_Caja + l.Cantidad_Unitario) as Stock_Lote,
               CASE 
                   WHEN l.Fecha_Vencimiento < GETDATE() THEN 'VENCIDO'
                   WHEN l.Fecha_Vencimiento < DATEADD(MONTH, 3, GETDATE()) THEN 'POR_VENCER'
                   ELSE 'VIGENTE'
               END as Estado_Vencimiento
        FROM Lote l
        INNER JOIN Productos p ON l.Id_Producto = p.id
        WHERE l.Id_Producto = ? {where_condition}
        ORDER BY l.Fecha_Vencimiento ASC, l.id ASC
        """
        return self._execute_query(query, (producto_id,))
    
    def get_lotes_por_vencer(self, dias_adelante: int = 90) -> List[Dict[str, Any]]:
        """Obtiene lotes que vencen en X días"""
        query = """
        SELECT l.*, p.Codigo, p.Nombre as Producto_Nombre, m.Nombre as Marca_Nombre,
               (l.Cantidad_Caja + l.Cantidad_Unitario) as Stock_Lote,
               DATEDIFF(DAY, GETDATE(), l.Fecha_Vencimiento) as Dias_Para_Vencer
        FROM Lote l
        INNER JOIN Productos p ON l.Id_Producto = p.id
        INNER JOIN Marca m ON p.ID_Marca = m.id
        WHERE l.Fecha_Vencimiento <= DATEADD(DAY, ?, GETDATE())
          AND l.Fecha_Vencimiento >= GETDATE()
          AND (l.Cantidad_Caja + l.Cantidad_Unitario) > 0
        ORDER BY l.Fecha_Vencimiento ASC
        """
        return self._execute_query(query, (dias_adelante,), use_cache=False)
    
    def get_lotes_vencidos(self) -> List[Dict[str, Any]]:
        """Obtiene lotes vencidos con stock"""
        query = """
        SELECT l.*, p.Codigo, p.Nombre as Producto_Nombre, m.Nombre as Marca_Nombre,
               (l.Cantidad_Caja + l.Cantidad_Unitario) as Stock_Lote,
               DATEDIFF(DAY, l.Fecha_Vencimiento, GETDATE()) as Dias_Vencido
        FROM Lote l
        INNER JOIN Productos p ON l.Id_Producto = p.id
        INNER JOIN Marca m ON p.ID_Marca = m.id
        WHERE l.Fecha_Vencimiento < GETDATE()
          AND (l.Cantidad_Caja + l.Cantidad_Unitario) > 0
        ORDER BY l.Fecha_Vencimiento ASC
        """
        return self._execute_query(query, use_cache=False)
    
    def verificar_disponibilidad_fifo(self, producto_id: int, cantidad_necesaria: int) -> Dict[str, Any]:
        """
        Verifica disponibilidad de stock usando FIFO
        
        Returns:
            {
                'disponible': bool,
                'lotes_necesarios': [{'lote_id': int, 'cantidad': int}],
                'cantidad_total_disponible': int,
                'tiene_vencidos': bool
            }
        """
        lotes = self.get_lotes_producto(producto_id, solo_activos=True)
        
        cantidad_restante = cantidad_necesaria
        lotes_a_usar = []
        cantidad_total = 0
        tiene_vencidos = False
        
        for lote in lotes:
            if cantidad_restante <= 0:
                break
            
            stock_lote = lote['Stock_Lote']
            cantidad_total += stock_lote
            
            # Verificar si está vencido
            if lote['Estado_Vencimiento'] == 'VENCIDO':
                tiene_vencidos = True
                continue
            
            cantidad_a_tomar = min(cantidad_restante, stock_lote)
            lotes_a_usar.append({
                'lote_id': lote['id'],
                'cantidad': cantidad_a_tomar,
                'fecha_vencimiento': lote['Fecha_Vencimiento'],
                'estado': lote['Estado_Vencimiento']
            })
            
            cantidad_restante -= cantidad_a_tomar
        
        return {
            'disponible': cantidad_restante <= 0,
            'lotes_necesarios': lotes_a_usar,
            'cantidad_total_disponible': cantidad_total,
            'tiene_vencidos': tiene_vencidos,
            'cantidad_faltante': max(0, cantidad_restante)
        }
    
    # ===============================
    # OPERACIONES DE STOCK
    # ===============================
    
    @ExceptionHandler.handle_exception
    def reducir_stock_fifo(self, producto_id: int, cantidad: int, permitir_vencidos: bool = False) -> List[Dict[str, Any]]:
        """
        Reduce stock usando lógica FIFO
        
        Returns:
            Lista de lotes afectados con las cantidades reducidas
        """
        validate_required(producto_id, "producto_id")
        validate_positive_number(cantidad, "cantidad")
        
        # Verificar disponibilidad
        disponibilidad = self.verificar_disponibilidad_fifo(producto_id, cantidad)
        
        if not disponibilidad['disponible']:
            producto = self.get_by_id(producto_id)
            codigo = producto['Codigo'] if producto else str(producto_id)
            raise StockInsuficienteError(codigo, disponibilidad['cantidad_total_disponible'], cantidad)
        
        # Ejecutar reducción en transacción
        operaciones = []
        lotes_afectados = []
        
        for lote_info in disponibilidad['lotes_necesarios']:
            lote_id = lote_info['lote_id']
            cantidad_reducir = lote_info['cantidad']
            
            # Obtener lote actual
            lote = self._execute_query("SELECT * FROM Lote WHERE id = ?", (lote_id,), fetch_one=True)
            
            if not lote:
                continue
            
            # Calcular nuevas cantidades
            nueva_cantidad_caja = lote['Cantidad_Caja']
            nueva_cantidad_unitario = lote['Cantidad_Unitario']
            
            cantidad_restante = cantidad_reducir
            
            # Reducir primero de unitarios
            if cantidad_restante > 0 and nueva_cantidad_unitario > 0:
                reducir_unitario = min(cantidad_restante, nueva_cantidad_unitario)
                nueva_cantidad_unitario -= reducir_unitario
                cantidad_restante -= reducir_unitario
            
            # Luego reducir de cajas
            if cantidad_restante > 0 and nueva_cantidad_caja > 0:
                reducir_caja = min(cantidad_restante, nueva_cantidad_caja)
                nueva_cantidad_caja -= reducir_caja
                cantidad_restante -= reducir_caja
            
            # Preparar operación de actualización
            update_query = """
            UPDATE Lote 
            SET Cantidad_Caja = ?, Cantidad_Unitario = ?
            WHERE id = ?
            """
            operaciones.append((update_query, (nueva_cantidad_caja, nueva_cantidad_unitario, lote_id)))
            
            lotes_afectados.append({
                'lote_id': lote_id,
                'cantidad_reducida': cantidad_reducir,
                'fecha_vencimiento': lote['Fecha_Vencimiento'],
                'stock_anterior': lote['Cantidad_Caja'] + lote['Cantidad_Unitario'],
                'stock_nuevo': nueva_cantidad_caja + nueva_cantidad_unitario
            })
        
        # Actualizar también el stock total del producto
        producto = self.get_by_id(producto_id)
        nuevo_stock_total = (producto['Stock_Caja'] + producto['Stock_Unitario']) - cantidad
        
        # Distribuir la reducción proporcionalmente
        if producto['Stock_Unitario'] >= cantidad:
            nuevo_stock_unitario = producto['Stock_Unitario'] - cantidad
            nuevo_stock_caja = producto['Stock_Caja']
        else:
            cantidad_restante_prod = cantidad - producto['Stock_Unitario']
            nuevo_stock_unitario = 0
            nuevo_stock_caja = producto['Stock_Caja'] - cantidad_restante_prod
        
        update_producto_query = """
        UPDATE Productos 
        SET Stock_Caja = ?, Stock_Unitario = ?
        WHERE id = ?
        """
        operaciones.append((update_producto_query, (nuevo_stock_caja, nuevo_stock_unitario, producto_id)))
        
        # Ejecutar todas las operaciones en transacción
        success = self.execute_transaction(operaciones)
        
        if success:
            print(f"📦 Stock reducido FIFO - Producto ID: {producto_id}, Cantidad: {cantidad}")
            print(f"🔢 Lotes afectados: {len(lotes_afectados)}")
        
        return lotes_afectados
    
    @ExceptionHandler.handle_exception
    def aumentar_stock_compra(self, producto_id: int, cantidad_caja: int, cantidad_unitario: int, 
                            fecha_vencimiento: str, precio_compra: float = None) -> int:
        """
        Aumenta stock creando nuevo lote por compra
        
        Returns:
            ID del lote creado
        """
        validate_required(producto_id, "producto_id")
        
        # Crear nuevo lote
        lote_data = {
            'Id_Producto': producto_id,
            'Cantidad_Caja': cantidad_caja,
            'Cantidad_Unitario': cantidad_unitario,
            'Fecha_Vencimiento': fecha_vencimiento
        }
        
        lote_query = """
        INSERT INTO Lote (Id_Producto, Cantidad_Caja, Cantidad_Unitario, Fecha_Vencimiento)
        OUTPUT INSERTED.id
        VALUES (?, ?, ?, ?)
        """
        
        # Actualizar stock total del producto
        producto = self.get_by_id(producto_id)
        nuevo_stock_caja = producto['Stock_Caja'] + cantidad_caja
        nuevo_stock_unitario = producto['Stock_Unitario'] + cantidad_unitario
        
        producto_query = """
        UPDATE Productos 
        SET Stock_Caja = ?, Stock_Unitario = ?
        WHERE id = ?
        """
        
        # Actualizar precio de compra si se proporciona
        if precio_compra:
            producto_query = """
            UPDATE Productos 
            SET Stock_Caja = ?, Stock_Unitario = ?, Precio_compra = ?
            WHERE id = ?
            """
            producto_params = (nuevo_stock_caja, nuevo_stock_unitario, precio_compra, producto_id)
        else:
            producto_params = (nuevo_stock_caja, nuevo_stock_unitario, producto_id)
        
        operaciones = [
            (lote_query, (producto_id, cantidad_caja, cantidad_unitario, fecha_vencimiento)),
            (producto_query, producto_params)
        ]
        
        # Ejecutar transacción
        # Crear el lote primero para obtener su ID
        lote_result = self._execute_query(lote_query, (producto_id, cantidad_caja, cantidad_unitario, fecha_vencimiento), fetch_one=True)

        if lote_result and isinstance(lote_result, dict) and 'id' in lote_result:
            lote_id = lote_result['id']
            
            # Ahora actualizar el producto
            producto_query_params = (nuevo_stock_caja, nuevo_stock_unitario, precio_compra, producto_id) if precio_compra else (nuevo_stock_caja, nuevo_stock_unitario, producto_id)
            success = self._execute_query(producto_query, producto_query_params, fetch_all=False, use_cache=False)
            
            if success:
                print(f"📈 Stock aumentado - Producto ID: {producto_id}, Lote ID: {lote_id}")
                print(f"📦 Cajas: +{cantidad_caja}, Unitarios: +{cantidad_unitario}")
                return lote_id
            else:
                print(f"❌ ERROR: No se pudo actualizar stock del producto {producto_id}")
                return None
        else:
            print(f"❌ ERROR: No se pudo crear lote para producto {producto_id}")
            return None
    
    # ===============================
    # REPORTES Y ESTADÍSTICAS
    # ===============================
    
    def get_reporte_vencimientos(self, dias_adelante: int = 180) -> Dict[str, Any]:
        """Reporte completo de vencimientos"""
        vencidos = self.get_lotes_vencidos()
        por_vencer = self.get_lotes_por_vencer(dias_adelante)
        
        return {
            'vencidos': vencidos,
            'por_vencer': por_vencer,
            'total_vencidos': len(vencidos),
            'total_por_vencer': len(por_vencer),
            'valor_perdido': sum(lote.get('Stock_Lote', 0) for lote in vencidos)
        }
    
    def get_productos_mas_vendidos(self, dias: int = 30) -> List[Dict[str, Any]]:
        """Productos más vendidos en X días"""
        query = """
        SELECT TOP 20
            p.id, p.Codigo, p.Nombre, m.Nombre as Marca_Nombre,
            SUM(dv.Cantidad_Unitario) as Total_Vendido,
            COUNT(dv.id) as Num_Ventas,
            AVG(dv.Precio_Unitario) as Precio_Promedio,
            (p.Stock_Caja + p.Stock_Unitario) as Stock_Actual
        FROM Productos p
        INNER JOIN Marca m ON p.ID_Marca = m.id
        INNER JOIN Lote l ON p.id = l.Id_Producto
        INNER JOIN DetallesVentas dv ON l.id = dv.Id_Lote
        INNER JOIN Ventas v ON dv.Id_Venta = v.id
        WHERE v.Fecha >= DATEADD(DAY, -?, GETDATE())
        GROUP BY p.id, p.Codigo, p.Nombre, m.Nombre, p.Stock_Caja, p.Stock_Unitario
        ORDER BY Total_Vendido DESC
        """
        return self._execute_query(query, (dias,))
    
    def get_valor_inventario(self) -> Dict[str, Any]:
        """Valor total del inventario"""
        query = """
        SELECT 
            SUM((p.Stock_Caja + p.Stock_Unitario) * p.Precio_compra) as Valor_Compra,
            SUM((p.Stock_Caja + p.Stock_Unitario) * p.Precio_venta) as Valor_Venta,
            COUNT(*) as Total_Productos,
            SUM(p.Stock_Caja + p.Stock_Unitario) as Total_Unidades
        FROM Productos p
        WHERE (p.Stock_Caja + p.Stock_Unitario) > 0
        """
        return self._execute_query(query, fetch_one=True) or {}