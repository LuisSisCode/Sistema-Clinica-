"""
CompraRepository - VERSIÓN 2.0 FIFO SIMPLIFICADA
✅ Precio TOTAL en lugar de unitario
✅ Sin cálculos de márgenes
✅ Soporte para actualizar precio_venta
"""

from typing import List, Dict, Any, Optional, Tuple
from datetime import datetime, timedelta
from decimal import Decimal
import hashlib
import json

from ..core.base_repository import BaseRepository
from ..core.excepciones import (
    CompraError, ProductoNotFoundError, ValidationError,
    ExceptionHandler, validate_required, validate_positive_number
)
from .producto_repository import ProductoRepository
from ..core.config_fifo import config_fifo

class CompraRepository(BaseRepository):
    """Repository para compras con creación automática de lotes - VERSIÓN 2.0"""
    
    def __init__(self):
        super().__init__('Compra', 'compras')
        self.producto_repo = ProductoRepository()
        print("🛒 CompraRepository v2.0 inicializado - Sin márgenes, con precio total")
    
    def get_active(self) -> List[Dict[str, Any]]:
        """Obtiene compras del mes actual CON TODOS LOS CAMPOS para QML"""
        query = """
        SELECT 
            c.id,
            p.Nombre as proveedor,
            u.Nombre + ' ' + u.Apellido_Paterno as usuario,
            FORMAT(c.Fecha, 'dd/MM/yyyy') as fecha,
            FORMAT(c.Fecha, 'HH:mm') as hora,
            c.Total as total,
            
            -- Campos para información de productos (SIN Id_Lote)
            ISNULL((
                SELECT STRING_AGG(p2.Nombre, ', ') WITHIN GROUP (ORDER BY dc2.id)
                FROM DetalleCompra dc2
                INNER JOIN Productos p2 ON dc2.Id_Producto = p2.id
                WHERE dc2.Id_Compra = c.id
            ), 'Sin productos') as productos_texto,
            
            ISNULL((
                SELECT SUM(dc2.Cantidad_Unitario)
                FROM DetalleCompra dc2
                WHERE dc2.Id_Compra = c.id
            ), 0) as total_productos,
            
            -- Campos adicionales para compatibilidad
            p.Nombre as Proveedor_Nombre,
            u.Nombre + ' ' + u.Apellido_Paterno as Usuario,
            c.Total as Total,
            c.Id_Proveedor,
            c.Id_Usuario
            
        FROM Compra c
        INNER JOIN Proveedor p ON c.Id_Proveedor = p.id
        INNER JOIN Usuario u ON c.Id_Usuario = u.id
        WHERE MONTH(c.Fecha) = MONTH(GETDATE()) 
          AND YEAR(c.Fecha) = YEAR(GETDATE())
        ORDER BY c.Fecha DESC
        """
        return self._execute_query(query)
    
    def get_compras_con_detalles(self, fecha_desde: str = None, fecha_hasta: str = None) -> List[Dict[str, Any]]:
        """Obtiene compras con filtro de fechas preciso"""
        where_clause = ""
        params = []
        
        if fecha_desde and fecha_hasta:
            where_clause = """
            WHERE CAST(c.Fecha AS DATE) >= CAST(? AS DATE)
              AND CAST(c.Fecha AS DATE) < CAST(? AS DATE)
            """
            params = [fecha_desde, fecha_hasta]
            print(f"📅 Filtro de compras: {fecha_desde} a {fecha_hasta} (exclusivo)")
        elif fecha_desde:
            where_clause = "WHERE CAST(c.Fecha AS DATE) >= CAST(? AS DATE)"
            params = [fecha_desde]
        elif fecha_hasta:
            where_clause = "WHERE CAST(c.Fecha AS DATE) < CAST(? AS DATE)"
            params = [fecha_hasta]
        
        query = f"""
        SELECT 
            c.id as Compra_ID,
            c.Fecha,
            c.Total as Compra_Total,
            p.Nombre as Proveedor,
            p.Direccion as Proveedor_Direccion,
            u.Nombre + ' ' + u.Apellido_Paterno as Usuario,
            COUNT(dc.id) as Items_Comprados,
            SUM(dc.Cantidad_Unitario) as Unidades_Totales
        FROM Compra c
        INNER JOIN Proveedor p ON c.Id_Proveedor = p.id
        INNER JOIN Usuario u ON c.Id_Usuario = u.id
        LEFT JOIN DetalleCompra dc ON c.id = dc.Id_Compra
        {where_clause}
        GROUP BY c.id, c.Fecha, c.Total, p.Nombre, p.Direccion, u.Nombre, u.Apellido_Paterno
        ORDER BY c.Fecha DESC
        """
        
        resultado = self._execute_query(query, tuple(params))
        
        if resultado:
            print(f"✅ Compras filtradas: {len(resultado)} compras encontradas")
            if len(resultado) > 0:
                primera_fecha = resultado[0].get('Fecha', '')
                ultima_fecha = resultado[-1].get('Fecha', '')
                print(f"   📅 Rango real: {ultima_fecha} a {primera_fecha}")
        
        return resultado
    
    def get_compra_completa(self, compra_id: int) -> Dict[str, Any]:
        """Obtiene compra con todos sus detalles (SIN Id_Lote)"""
        validate_required(compra_id, "compra_id")
        
        # Datos principales de la compra
        compra_query = """
        SELECT c.*, p.Nombre as Proveedor_Nombre, p.Direccion as Proveedor_Direccion,
            u.Nombre + ' ' + u.Apellido_Paterno as Usuario
        FROM Compra c
        INNER JOIN Proveedor p ON c.Id_Proveedor = p.id
        INNER JOIN Usuario u ON c.Id_Usuario = u.id
        WHERE c.id = ?
        """
        compra = self._execute_query(compra_query, (compra_id,), fetch_one=True)
        
        if not compra:
            return None
        
        # Detalles de la compra (DIRECTO con Productos, sin Lote)
        detalles_query = """
        SELECT 
            dc.*,
            p.Codigo as Producto_Codigo,
            p.Nombre as Producto_Nombre,
            m.Nombre as Marca_Nombre,
            dc.Cantidad_Unitario as Cantidad_Total,
            dc.Precio_Unitario as Precio_Unitario_Compra,
            (dc.Cantidad_Unitario * dc.Precio_Unitario) as Costo_Total,
            p.Precio_venta as Precio_Venta_Actual,
            
            -- Obtener vencimiento del Lote asociado
            (SELECT TOP 1 l.Fecha_Vencimiento 
             FROM Lote l 
             WHERE l.Id_Compra = dc.Id_Compra 
               AND l.Id_Producto = dc.Id_Producto
             ORDER BY l.id DESC) as Fecha_Vencimiento
        FROM DetalleCompra dc
        INNER JOIN Productos p ON dc.Id_Producto = p.id
        LEFT JOIN Marca m ON p.ID_Marca = m.id
        WHERE dc.Id_Compra = ?
        ORDER BY dc.id
        """
        detalles = self._execute_query(detalles_query, (compra_id,))
        
        compra['detalles'] = detalles
        compra['total_items'] = len(detalles)
        compra['total_unidades'] = sum(detalle.get('Cantidad_Total', 0) for detalle in detalles)
        
        return compra
    
    def get_compras_por_proveedor(self, proveedor_id: int = None) -> List[Dict[str, Any]]:
        """Obtiene compras por proveedor"""
        if proveedor_id:
            where_clause = "WHERE c.Id_Proveedor = ?"
            params = (proveedor_id,)
        else:
            where_clause = ""
            params = ()
        
        query = f"""
        SELECT 
            p.Nombre as Proveedor,
            p.Estado,
            COUNT(c.id) as Total_Compras,
            SUM(c.Total) as Monto_Total,
            AVG(c.Total) as Compra_Promedio,
            MAX(c.Fecha) as Ultima_Compra
        FROM Proveedor p
        LEFT JOIN Compra c ON p.id = c.Id_Proveedor
        {where_clause}
        GROUP BY p.id, p.Nombre, p.Estado
        HAVING COUNT(c.id) > 0
        ORDER BY Monto_Total DESC
        """
        return self._execute_query(query, params)
    
    def crear_compra(self, proveedor_id: int, usuario_id: int, items: List[Dict], fecha: datetime = None) -> int:
        """
        Crea una compra completa con sus lotes
        
        Args:
            proveedor_id: ID del proveedor
            usuario_id: ID del usuario
            items: Lista de items [{"producto_codigo", "cantidad", "precio_total", "vencimiento", "precio_venta"}]
            fecha: Fecha de la compra (opcional)
        """
        try:
            validate_required(proveedor_id, "proveedor_id")
            validate_required(usuario_id, "usuario_id")
            validate_required(items, "items")
            
            if not items:
                raise ValidationError("La compra debe tener al menos un item")
            
            fecha = fecha or datetime.now()
            total_compra = 0.0
            
            # 1. CREAR COMPRA
            compra_id = self._insert_compra(proveedor_id, usuario_id, fecha)
            print(f"📦 Compra creada: ID {compra_id}")
            
            # 2. PROCESAR CADA ITEM
            for item in items:
                producto_codigo = item.get('producto_codigo')
                cantidad = item.get('cantidad', 0)
                precio_total = float(item.get('precio_total', 0))
                vencimiento = item.get('vencimiento')
                precio_venta = item.get('precio_venta')
                
                # Calcular precio unitario
                precio_unitario = precio_total / cantidad if cantidad > 0 else 0
                
                # Obtener producto
                producto = self.producto_repo.get_by_codigo(producto_codigo)
                if not producto:
                    raise ProductoNotFoundError(f"Producto no encontrado: {producto_codigo}")
                
                producto_id = producto['id']
                
                # CREAR DETALLE DE COMPRA (directo con Id_Producto)
                self._crear_detalle_compra(
                    compra_id=compra_id,
                    producto_id=producto_id,
                    cantidad=cantidad,
                    precio_unitario=precio_unitario
                )
                
                # CREAR LOTE (separado, también con Id_Producto)
                self._crear_lote(
                    producto_id=producto_id,
                    cantidad=cantidad,
                    precio_unitario=precio_unitario,
                    vencimiento=vencimiento,
                    compra_id=compra_id,
                    fecha_compra=fecha
                )
                
                # Actualizar precio de venta si es primera compra
                if precio_venta and precio_venta > 0:
                    self._actualizar_precio_venta_producto(producto_id, precio_venta)
                
                total_compra += precio_total
            
            # 3. ACTUALIZAR TOTAL DE COMPRA
            self._actualizar_total_compra(compra_id, total_compra)
            
            print(f"✅ Compra completada: {len(items)} items, Total: Bs {total_compra:.2f}")
            return compra_id
            
        except Exception as e:
            print(f"❌ Error creando compra: {e}")
            raise CompraError(f"Error creando compra: {str(e)}")
    
    def _insert_compra(self, proveedor_id: int, usuario_id: int, fecha: datetime) -> int:
        """Inserta registro de compra"""
        query = """
        INSERT INTO Compra (Id_Proveedor, Id_Usuario, Fecha, Total)
        VALUES (?, ?, ?, 0.0)
        """
        return self._execute_non_query(query, (proveedor_id, usuario_id, fecha), return_id=True)
    
    def _crear_lote(self, producto_id: int, cantidad: int, precio_unitario: float, 
                     vencimiento: str, compra_id: int, fecha_compra: datetime) -> int:
        """Crea un lote para el producto con nombres correctos de columnas"""
        query = """
        INSERT INTO Lote (
            Id_Producto, Cantidad_Unitario, Precio_Compra, Fecha_Vencimiento, 
            Fecha_Compra, Id_Compra, Estado, Fecha_Creacion
        )
        VALUES (?, ?, ?, ?, ?, ?, 'Activo', GETDATE())
        """
        fecha_venc = vencimiento if vencimiento else None
        fecha_comp = fecha_compra.date() if fecha_compra else datetime.now().date()
        
        return self._execute_non_query(
            query, 
            (producto_id, cantidad, precio_unitario, fecha_venc, fecha_comp, compra_id),
            return_id=True
        )
    
    def _crear_detalle_compra(self, compra_id: int, producto_id: int, cantidad: int, precio_unitario: float):
        """Crea detalle de compra (con Id_Producto, NO Id_Lote)"""
        query = """
        INSERT INTO DetalleCompra (Id_Compra, Id_Producto, Cantidad_Unitario, Precio_Unitario)
        VALUES (?, ?, ?, ?)
        """
        self._execute_non_query(query, (compra_id, producto_id, cantidad, precio_unitario))
    
    def _actualizar_total_compra(self, compra_id: int, total: float):
        """Actualiza el total de la compra"""
        query = "UPDATE Compra SET Total = ? WHERE id = ?"
        self._execute_non_query(query, (total, compra_id))
    
    def _actualizar_precio_venta_producto(self, producto_id: int, precio_venta: float):
        """Actualiza precio de venta del producto"""
        query = "UPDATE Productos SET Precio_venta = ? WHERE id = ?"
        self._execute_non_query(query, (precio_venta, producto_id))
        print(f"💰 Precio venta actualizado: Producto {producto_id} = Bs {precio_venta:.2f}")
    
    def get_estadisticas(self) -> Dict[str, Any]:
        """Obtiene estadísticas de compras del mes"""
        query = """
        SELECT 
            COUNT(*) as Total_Compras,
            ISNULL(SUM(Total), 0) as Gastos_Total,
            ISNULL(AVG(Total), 0) as Compra_Promedio,
            ISNULL(MAX(Total), 0) as Compra_Mayor
        FROM Compra
        WHERE MONTH(Fecha) = MONTH(GETDATE()) 
          AND YEAR(Fecha) = YEAR(GETDATE())
        """
        resultado = self._execute_query(query, fetch_one=True)
        return resultado if resultado else {
            'Total_Compras': 0,
            'Gastos_Total': 0.0,
            'Compra_Promedio': 0.0,
            'Compra_Mayor': 0.0
        }
    
    def eliminar_compra(self, compra_id: int) -> bool:
        """Elimina una compra si no tiene ventas asociadas"""
        try:
            # Verificar si hay ventas de los lotes de esta compra (SIN Id_Lote en DetalleCompra)
            query_check = """
            SELECT COUNT(*) as ventas
            FROM DetalleVenta dv
            INNER JOIN Lote l ON dv.Id_Lote = l.id
            WHERE l.Id_Compra = ?
            """
            resultado = self._execute_query(query_check, (compra_id,), fetch_one=True)
            
            if resultado and resultado['ventas'] > 0:
                raise ValidationError("No se puede eliminar: tiene ventas asociadas")
            
            # Eliminar detalles y lotes
            query_delete_detalles = "DELETE FROM DetalleCompra WHERE Id_Compra = ?"
            self._execute_non_query(query_delete_detalles, (compra_id,))
            
            query_delete_lotes = """
            DELETE FROM Lote 
            WHERE Id_Compra = ?
            """
            self._execute_non_query(query_delete_lotes, (compra_id,))
            
            # Eliminar compra
            query_delete_compra = "DELETE FROM Compra WHERE id = ?"
            self._execute_non_query(query_delete_compra, (compra_id,))
            
            print(f"🗑️ Compra {compra_id} eliminada correctamente")
            return True
            
        except Exception as e:
            print(f"❌ Error eliminando compra: {e}")
            raise CompraError(f"Error eliminando compra: {str(e)}")