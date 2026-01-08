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
            
            -- Contar productos en lugar de STRING_AGG
            ISNULL((
                SELECT COUNT(DISTINCT dc2.Id_Producto)
                FROM DetalleCompra dc2
                WHERE dc2.Id_Compra = c.id
            ), 0) as total_productos,
            
            -- Texto de productos (con COALESCE para evitar NULL)
            COALESCE((
                SELECT STRING_AGG(p2.Nombre, ', ') WITHIN GROUP (ORDER BY dc2.id)
                FROM DetalleCompra dc2
                INNER JOIN Productos p2 ON dc2.Id_Producto = p2.id
                WHERE dc2.Id_Compra = c.id
            ), 'Sin productos') as productos_texto,
            
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
        resultado = self._execute_query(query)
        print(f"📦 Compras recientes cargadas: {len(resultado)}")
        return resultado
    
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
        
        # ✅ CONVERTIR FECHAS A STRINGS ISO PARA QML (COMO EN PRODUCTO_REPOSITORY)
        # Convertir fecha de la compra
        if compra.get('Fecha'):
            if hasattr(compra['Fecha'], 'isoformat'):
                compra['Fecha'] = compra['Fecha'].isoformat()
        
        # Convertir fechas de vencimiento de los detalles
        for detalle in detalles:
            # Convertir Fecha_Vencimiento si existe
            if detalle.get('Fecha_Vencimiento'):
                fecha_venc = detalle['Fecha_Vencimiento']
                if hasattr(fecha_venc, 'isoformat'):
                    detalle['Fecha_Vencimiento'] = fecha_venc.isoformat()  # "2027-05-07"
                elif hasattr(fecha_venc, 'strftime'):
                    detalle['Fecha_Vencimiento'] = fecha_venc.strftime('%Y-%m-%d')
        
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
        Crea una compra completa con sus lotes - VERSIÓN CORREGIDA PARA TRIGGERS
        
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
            
            print(f"🛒 INICIANDO CREACIÓN DE COMPRA - Proveedor: {proveedor_id}, Usuario: {usuario_id}")
            print(f"📦 Items a procesar: {len(items)}")
            
            # 1. CREAR COMPRA (también corregir para triggers si es necesario)
            compra_id = self._insert_compra(proveedor_id, usuario_id, fecha)
            if not compra_id:
                raise CompraError("No se pudo crear la compra principal")
            
            print(f"✅ Compra creada: ID {compra_id}")
            
            # 2. PROCESAR CADA ITEM
            for i, item in enumerate(items):
                producto_codigo = item.get('producto_codigo')
                cantidad = item.get('cantidad', 0)
                precio_total = float(item.get('precio_total', 0))
                vencimiento = item.get('vencimiento')
                precio_venta = item.get('precio_venta')
                
                print(f"🔄 Procesando item {i+1}/{len(items)}: {producto_codigo}")
                print(f"   Cantidad: {cantidad}, Precio total: {precio_total}")
                
                if cantidad <= 0:
                    raise ValidationError(f"Cantidad inválida para {producto_codigo}")
                
                if precio_total <= 0:
                    raise ValidationError(f"Precio total inválido para {producto_codigo}")
                
                # Calcular precio unitario
                precio_unitario = precio_total / cantidad if cantidad > 0 else 0
                
                # Obtener producto
                producto = self.producto_repo.get_by_codigo(producto_codigo)
                if not producto:
                    raise ProductoNotFoundError(f"Producto no encontrado: {producto_codigo}")
                
                producto_id = producto['id']
                
                print(f"   Producto encontrado: ID {producto_id}, Nombre: {producto.get('Nombre', '')}")
                
                # CREAR DETALLE DE COMPRA
                self._crear_detalle_compra(
                    compra_id=compra_id,
                    producto_id=producto_id,
                    cantidad=cantidad,
                    precio_unitario=precio_unitario
                )
                print(f"   ✅ DetalleCompra creado")
                
                # CREAR LOTE (método corregido para triggers)
                lote_id = self._crear_lote(
                    producto_id=producto_id,
                    cantidad=cantidad,
                    precio_unitario=precio_unitario,
                    vencimiento=vencimiento,
                    compra_id=compra_id,
                    fecha_compra=fecha
                )
                
                if not lote_id:
                    print(f"⚠️ No se pudo obtener ID del lote, pero continuando...")
                
                # NOTA: No actualizamos stock aquí porque el trigger trg_ActualizarStockProducto_Lote ya lo hace
                print(f"   ⚡ Trigger 'trg_ActualizarStockProducto_Lote' actualizará el stock automáticamente")
                
                # Actualizar precio de venta si es primera compra
                if precio_venta and precio_venta > 0:
                    self._actualizar_precio_venta_producto(producto_id, precio_venta)
                    print(f"   💰 Precio venta actualizado: Bs {precio_venta:.2f}")
                
                total_compra += precio_total
                print(f"   ✅ Item procesado - Subtotal: Bs {precio_total:.2f}")
            
            # 3. ACTUALIZAR TOTAL DE COMPRA
            self._actualizar_total_compra(compra_id, total_compra)
            
            print(f"🎉 COMPRA COMPLETADA EXITOSAMENTE")
            print(f"   ID Compra: {compra_id}")
            print(f"   Total: Bs {total_compra:.2f}")
            print(f"   Items: {len(items)}")
            print(f"   Triggers activados: trg_Kardex_Entrada_Lote, trg_ActualizarStockProducto_Lote")
            
            return compra_id
            
        except Exception as e:
            print(f"❌ ERROR CRÍTICO creando compra: {e}")
            import traceback
            traceback.print_exc()
            raise CompraError(f"Error creando compra: {str(e)}")
    
    def _insert_compra(self, proveedor_id: int, usuario_id: int, fecha: datetime) -> int:
        """Inserta registro de compra (VERSIÓN COMPATIBLE CON TRIGGERS)"""
        try:
            # Usar tabla temporal para capturar el ID (por si hay triggers)
            query = """
            -- Crear tabla temporal para capturar el ID
            DECLARE @InsertedCompra TABLE (id INT);
            
            -- Insertar con OUTPUT INTO
            INSERT INTO Compra (Id_Proveedor, Id_Usuario, Fecha, Total)
            OUTPUT INSERTED.id INTO @InsertedCompra
            VALUES (?, ?, ?, 0.0);
            
            -- Obtener el ID desde la tabla temporal
            SELECT id FROM @InsertedCompra;
            """
            
            result = self._execute_query(query, (proveedor_id, usuario_id, fecha), fetch_one=True, use_cache=False)
            
            if result and 'id' in result:
                return result['id']
            
            # Método alternativo si falla
            return self._insert_compra_alternativo(proveedor_id, usuario_id, fecha)
            
        except Exception as e:
            print(f"❌ Error en _insert_compra: {e}")
            return self._insert_compra_alternativo(proveedor_id, usuario_id, fecha)
        
    def _insert_compra_alternativo(self, proveedor_id: int, usuario_id: int, fecha: datetime) -> int:
        """Método alternativo para insertar compra"""
        try:
            # Insertar sin OUTPUT
            query = """
            INSERT INTO Compra (Id_Proveedor, Id_Usuario, Fecha, Total)
            VALUES (?, ?, ?, 0.0)
            """
            self._execute_query(query, (proveedor_id, usuario_id, fecha), fetch_all=False, use_cache=False)
            
            # Obtener el último ID insertado
            select_query = """
            SELECT TOP 1 id 
            FROM Compra 
            WHERE Id_Proveedor = ? AND Id_Usuario = ?
            ORDER BY Fecha DESC
            """
            result = self._execute_query(select_query, (proveedor_id, usuario_id), fetch_one=True, use_cache=False)
            
            if result and 'id' in result:
                return result['id']
            
            return None
        except Exception as e:
            print(f"❌ Error en método alternativo _insert_compra: {e}")
            return None
    
    def _crear_lote(self, producto_id: int, cantidad: int, precio_unitario: float, 
                 vencimiento: str, compra_id: int, fecha_compra: datetime) -> int:
        """Crea un lote para el producto (VERSIÓN CORREGIDA para trabajar con triggers)"""
        try:
            # SOLUCIÓN PARA TRIGGERS: Usar tabla temporal para capturar el OUTPUT
            query = """
            -- Crear tabla temporal para capturar el ID
            DECLARE @InsertedLote TABLE (id INT);
            
            -- Insertar con OUTPUT INTO (compatible con triggers)
            INSERT INTO Lote (
                Id_Producto, Cantidad_Unitario, Precio_Compra, Fecha_Vencimiento, 
                Fecha_Compra, Id_Compra, Estado, Fecha_Creacion
            )
            OUTPUT INSERTED.id INTO @InsertedLote
            VALUES (?, ?, ?, ?, ?, ?, 'Activo', GETDATE());
            
            -- Obtener el ID desde la tabla temporal
            SELECT id FROM @InsertedLote;
            """
            
            fecha_venc = vencimiento if vencimiento else None
            fecha_comp = fecha_compra.date() if fecha_compra else datetime.now().date()
            
            result = self._execute_query(
                query, 
                (producto_id, cantidad, precio_unitario, fecha_venc, fecha_comp, compra_id),
                fetch_one=True, 
                use_cache=False
            )
            
            if result and 'id' in result:
                lote_id = int(result['id'])
                print(f"📦 Lote creado (con triggers): ID {lote_id} para producto {producto_id}")
                return lote_id
            
            return None
            
        except Exception as e:
            print(f"❌ Error creando lote con triggers: {e}")
            # Si falla, intentar método alternativo
            return self._crear_lote_alternativo(producto_id, cantidad, precio_unitario, 
                                            vencimiento, compra_id, fecha_compra)
    
    def _crear_detalle_compra(self, compra_id: int, producto_id: int, cantidad: int, precio_unitario: float):
        """Crea detalle de compra"""
        query = """
        INSERT INTO DetalleCompra (Id_Compra, Id_Producto, Cantidad_Unitario, Precio_Unitario)
        VALUES (?, ?, ?, ?)
        """
        self._execute_query(query, (compra_id, producto_id, cantidad, precio_unitario), fetch_all=False, use_cache=False)
    
    def _actualizar_total_compra(self, compra_id: int, total: float):
        """Actualiza el total de la compra"""
        query = "UPDATE Compra SET Total = ? WHERE id = ?"
        self._execute_query(query, (total, compra_id), fetch_all=False, use_cache=False)
    
    def _actualizar_precio_venta_producto(self, producto_id: int, precio_venta: float):
        """Actualiza precio de venta del producto"""
        query = "UPDATE Productos SET Precio_venta = ? WHERE id = ?"
        self._execute_query(query, (precio_venta, producto_id), fetch_all=False, use_cache=False)
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
        
    def search_by_name(self, termino: str) -> List[Dict]:
        """Busca productos por nombre"""
        query = """
        SELECT id, Codigo, Nombre, Precio_venta, Stock_Unitario, Unidad_Medida
        FROM Productos
        WHERE LOWER(Nombre) LIKE ? AND Activo = 1
        ORDER BY Nombre
        LIMIT 20
        """
        return self._execute_query(query, (f'%{termino}%',))
        
    def tiene_vencimiento_conocido(self, codigo: str) -> Optional[bool]:
        """
        Verifica si un producto típicamente tiene vencimiento basado en lotes anteriores.
        
        Args:
            codigo: Código del producto
            
        Returns:
            True: Si se encontró al menos un lote con fecha de vencimiento
            False: Si se encontró al menos un lote SIN fecha de vencimiento
            None: Si no hay lotes anteriores (no sabemos)
        """
        try:
            # Primero obtener el producto por código
            producto = self.get_by_codigo(codigo)
            if not producto:
                print(f"❌ Producto no encontrado: {codigo}")
                return None
            
            producto_id = producto.get('id')
            if not producto_id:
                return None
            
            # Consultar los lotes anteriores de este producto
            query = """
            SELECT TOP 5 Fecha_Vencimiento
            FROM Lote
            WHERE Id_Producto = ?
            ORDER BY Fecha_Creacion DESC
            """
            
            resultados = self._execute_query(query, (producto_id,))
            
            if not resultados:
                # No hay lotes anteriores, no sabemos
                return None
            
            # Analizar los últimos lotes
            tiene_vencimiento = False
            sin_vencimiento = False
            
            for lote in resultados:
                fecha_venc = lote.get('Fecha_Vencimiento')
                if fecha_venc:
                    tiene_vencimiento = True
                else:
                    sin_vencimiento = True
            
            # Lógica de decisión:
            if tiene_vencimiento and not sin_vencimiento:
                # Todos los lotes anteriores tienen vencimiento
                return True
            elif sin_vencimiento and not tiene_vencimiento:
                # Todos los lotes anteriores NO tienen vencimiento
                return False
            else:
                # Mixto o no sabemos claramente
                # Por defecto, si alguno tiene vencimiento, asumimos que sí
                return tiene_vencimiento
            
        except Exception as e:
            print(f"❌ Error en tiene_vencimiento_conocido para {codigo}: {e}")
            return None
        
    def _crear_lote_alternativo(self, producto_id: int, cantidad: int, precio_unitario: float, 
                           vencimiento: str, compra_id: int, fecha_compra: datetime) -> int:
        """Método alternativo para crear lote sin usar OUTPUT (para triggers problemáticos)"""
        try:
            # Insertar sin OUTPUT (manera tradicional)
            insert_query = """
            INSERT INTO Lote (
                Id_Producto, Cantidad_Unitario, Precio_Compra, Fecha_Vencimiento, 
                Fecha_Compra, Id_Compra, Estado, Fecha_Creacion
            )
            VALUES (?, ?, ?, ?, ?, ?, 'Activo', GETDATE())
            """
            
            fecha_venc = vencimiento if vencimiento else None
            fecha_comp = fecha_compra.date() if fecha_compra else datetime.now().date()
            
            # Ejecutar INSERT
            self._execute_query(
                insert_query, 
                (producto_id, cantidad, precio_unitario, fecha_venc, fecha_comp, compra_id),
                fetch_all=False, 
                use_cache=False
            )
            
            # Obtener el último ID insertado para este producto
            select_query = """
            SELECT TOP 1 id 
            FROM Lote 
            WHERE Id_Producto = ? AND Id_Compra = ?
            ORDER BY Fecha_Creacion DESC
            """
            
            result = self._execute_query(select_query, (producto_id, compra_id), fetch_one=True, use_cache=False)
            
            if result and 'id' in result:
                lote_id = int(result['id'])
                print(f"📦 Lote creado (alternativo): ID {lote_id} para producto {producto_id}")
                return lote_id
            
            return None
            
        except Exception as e:
            print(f"❌ Error en método alternativo de lote: {e}")
            return None