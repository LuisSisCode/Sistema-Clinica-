from typing import List, Dict, Any, Optional, Tuple
from datetime import datetime, timedelta
from decimal import Decimal
import pyodbc

from ..core.base_repository import BaseRepository
from ..core.excepciones import (
    VentaError, StockInsuficienteError, ProductoNotFoundError,
    ValidationError, ExceptionHandler, validate_required, validate_positive_number,
    DatabaseTransactionError
)
from .producto_repository import ProductoRepository

class VentaRepository(BaseRepository):
    """Repository para ventas con integración FIFO automática"""
    
    def __init__(self):
        super().__init__('Ventas', 'ventas')
        self.producto_repo = ProductoRepository()
        print("💰 VentaRepository inicializado con FIFO automático")
    
    def get_active(self) -> List[Dict[str, Any]]:
        """Obtiene ventas del día actual - SIN CACHÉ para datos frescos"""
        query = """
        SELECT v.*, u.Nombre + ' ' + u.Apellido_Paterno as Vendedor
        FROM Ventas v
        INNER JOIN Usuario u ON v.Id_Usuario = u.id
        WHERE CAST(v.Fecha AS DATE) = CAST(GETDATE() AS DATE)
        ORDER BY v.Fecha DESC
        """
        resultado = self._execute_query(query, use_cache=False)
        return resultado
    
    def buscar_productos_para_venta(self, termino: str) -> List[Dict[str, Any]]:
        """
        ✅ CORREGIDO: Busca productos SIEMPRE sin cache
        Calcula stock desde tabla Lote
        """
        if not termino:
            return []
        
        query = """
        SELECT 
            p.id,
            p.Codigo,
            p.Nombre,
            p.Precio_venta,
            m.Nombre as Marca_Nombre,
            -- ✅ STOCK TOTAL CALCULADO DESDE LOTES
            ISNULL((
                SELECT SUM(l.Cantidad_Unitario) 
                FROM Lote l 
                WHERE l.Id_Producto = p.id 
                  AND l.Estado = 'ACTIVO'
            ), 0) as Stock_Total,
            -- Estado en tiempo real
            CASE 
                WHEN ISNULL((
                    SELECT SUM(l.Cantidad_Unitario) 
                    FROM Lote l 
                    WHERE l.Id_Producto = p.id 
                      AND l.Estado = 'ACTIVO'
                ), 0) > 0 
                THEN 'DISPONIBLE'
                ELSE 'AGOTADO'
            END as Estado,
            -- Timestamp para debug
            GETDATE() as Consulta_Timestamp
        FROM Productos p
        INNER JOIN Marca m ON p.ID_Marca = m.id
        WHERE p.Activo = 1
          AND (p.Nombre LIKE ? OR p.Codigo LIKE ?)
        ORDER BY p.Nombre
        """
        
        termino_like = f"%{termino}%"
        resultado = self._execute_query(query, (termino_like, termino_like), use_cache=False) or []
        
        print(f"🔍 Búsqueda de productos SIN CACHE: {len(resultado)} resultados para '{termino}'")
        return resultado
    
    def buscar_productos_para_venta_sin_cache(self, termino: str) -> List[Dict[str, Any]]:
        """
        ✅ CORREGIDO: Búsqueda garantizada SIN cache
        """
        if not termino:
            return []
        
        print(f"🚫 BÚSQUEDA FORZADA SIN CACHE para: '{termino}'")
        
        query = """
        SELECT 
            p.id,
            p.Codigo,
            p.Nombre,
            p.Precio_venta,
            m.Nombre as Marca_Nombre,
            -- ✅ RECALCULAR STOCK DESDE LOTES
            ISNULL((
                SELECT SUM(l.Cantidad_Unitario) 
                FROM Lote l 
                WHERE l.Id_Producto = p.id 
                  AND l.Estado = 'ACTIVO'
            ), 0) as Stock_Total,
            -- Información adicional para debug
            (SELECT COUNT(*) 
             FROM Lote l 
             WHERE l.Id_Producto = p.id 
               AND l.Cantidad_Unitario > 0 
               AND l.Estado = 'ACTIVO') as Lotes_Activos,
            GETDATE() as Timestamp_Consulta
        FROM Productos p
        INNER JOIN Marca m ON p.ID_Marca = m.id
        WHERE p.Activo = 1
          AND (p.Nombre LIKE ? OR p.Codigo LIKE ?)
        ORDER BY p.Nombre
        """
        
        termino_like = f"%{termino}%"
        
        # ✅ CONEXIÓN DIRECTA sin ningún tipo de cache
        conn = None
        try:
            conn = self._get_connection()
            cursor = conn.cursor()
            cursor.execute(query, (termino_like, termino_like))
            
            columns = [desc[0] for desc in cursor.description]
            results = []
            
            for row in cursor.fetchall():
                row_dict = dict(zip(columns, row))
                results.append(row_dict)
            
            print(f"✅ Consulta directa sin cache completada: {len(results)} productos")
            
            # Debug: mostrar stock de productos encontrados
            for producto in results:
                print(f"   📦 {producto['Codigo']}: Stock={producto['Stock_Total']}, Lotes={producto.get('Lotes_Activos', 0)}")
            
            return results
            
        except Exception as e:
            print(f"❌ Error en búsqueda sin cache: {e}")
            return []
        finally:
            if conn:
                conn.close()

    def get_producto_por_codigo(self, codigo: str) -> Optional[Dict[str, Any]]:
        """
        ✅ CORREGIDO: SIEMPRE sin cache para datos frescos
        Calcula stock desde lotes
        """
        validate_required(codigo, "codigo")
        
        query = """
        SELECT 
            p.id,
            p.Codigo,
            p.Nombre,
            p.Detalles,
            p.Precio_compra,
            p.Precio_venta,
            p.Unidad_Medida,
            p.Stock_Minimo,
            p.ID_Marca,
            m.Nombre as Marca_Nombre,
            m.Detalles as Marca_Detalles,
            -- ✅ STOCK REAL CALCULADO DESDE LOTES
            ISNULL((
                SELECT SUM(l.Cantidad_Unitario) 
                FROM Lote l 
                WHERE l.Id_Producto = p.id 
                  AND l.Estado = 'ACTIVO'
            ), 0) as Stock_Total,
            -- Alias para compatibilidad
            ISNULL((
                SELECT SUM(l.Cantidad_Unitario) 
                FROM Lote l 
                WHERE l.Id_Producto = p.id 
                  AND l.Estado = 'ACTIVO'
            ), 0) as Stock_Unitario,
            -- Información FIFO
            (SELECT TOP 1 l.id 
             FROM Lote l 
             WHERE l.Id_Producto = p.id 
               AND l.Cantidad_Unitario > 0 
               AND l.Estado = 'ACTIVO'
             ORDER BY 
               CASE WHEN l.Fecha_Vencimiento IS NOT NULL 
                    THEN l.Fecha_Vencimiento 
                    ELSE '9999-12-31' 
               END ASC,
               l.Fecha_Compra ASC,
               l.id ASC
            ) as Lote_FIFO_ID,
            (SELECT TOP 1 l.Cantidad_Unitario 
             FROM Lote l 
             WHERE l.Id_Producto = p.id 
               AND l.Cantidad_Unitario > 0 
               AND l.Estado = 'ACTIVO'
             ORDER BY 
               CASE WHEN l.Fecha_Vencimiento IS NOT NULL 
                    THEN l.Fecha_Vencimiento 
                    ELSE '9999-12-31' 
               END ASC,
               l.Fecha_Compra ASC,
               l.id ASC
            ) as Lote_FIFO_Stock,
            (SELECT COUNT(*) 
             FROM Lote l 
             WHERE l.Id_Producto = p.id 
               AND l.Cantidad_Unitario > 0 
               AND l.Estado = 'ACTIVO') as Lotes_Activos,
            GETDATE() as Timestamp_Consulta
        FROM Productos p
        INNER JOIN Marca m ON p.ID_Marca = m.id
        WHERE p.Codigo = ? AND p.Activo = 1
        """
        
        resultado = self._execute_query(query, (codigo,), fetch_one=True, use_cache=False)
        
        if resultado:
            print(f"📦 Producto {codigo}: Stock desde lotes = {resultado['Stock_Total']}")
        else:
            print(f"❌ Producto {codigo} no encontrado")
        
        return resultado

    def get_producto_por_codigo_sin_cache(self, codigo: str) -> Optional[Dict[str, Any]]:
        """
        ✅ CORREGIDO: Garantiza consulta directa sin ningún cache
        """
        validate_required(codigo, "codigo")
        
        print(f"🚫 CONSULTA FORZADA SIN CACHE para producto: '{codigo}'")
        
        query = """
        SELECT 
            p.id,
            p.Codigo,
            p.Nombre,
            p.Precio_venta,
            m.Nombre as Marca_Nombre,
            -- ✅ RECALCULAR STOCK DESDE LOTES
            ISNULL((
                SELECT SUM(l.Cantidad_Unitario) 
                FROM Lote l 
                WHERE l.Id_Producto = p.id 
                  AND l.Estado = 'ACTIVO'
            ), 0) as Stock_Total,
            -- Alias para compatibilidad
            ISNULL((
                SELECT SUM(l.Cantidad_Unitario) 
                FROM Lote l 
                WHERE l.Id_Producto = p.id 
                  AND l.Estado = 'ACTIVO'
            ), 0) as Stock_Unitario,
            -- Información de lotes para debug
            (SELECT COUNT(*) 
             FROM Lote l 
             WHERE l.Id_Producto = p.id 
               AND l.Cantidad_Unitario > 0 
               AND l.Estado = 'ACTIVO') as Lotes_Activos,
            (SELECT COUNT(*) 
             FROM Lote l 
             WHERE l.Id_Producto = p.id) as Total_Lotes,
            GETDATE() as Timestamp_Consulta
        FROM Productos p
        INNER JOIN Marca m ON p.ID_Marca = m.id
        WHERE p.Codigo = ? AND p.Activo = 1
        """
        
        # ✅ CONEXIÓN DIRECTA
        conn = None
        try:
            conn = self._get_connection()
            cursor = conn.cursor()
            cursor.execute(query, (codigo,))
            
            row = cursor.fetchone()
            if row:
                columns = [desc[0] for desc in cursor.description]
                resultado = dict(zip(columns, row))
                
                print(f"✅ Producto {codigo}: Stock_Total={resultado['Stock_Total']}, Lotes_Activos={resultado['Lotes_Activos']}")
                return resultado
            else:
                print(f"❌ Producto {codigo} no encontrado")
                return None
                
        except Exception as e:
            print(f"❌ Error en consulta directa: {e}")
            return None
        finally:
            if conn:
                conn.close()

    def get_producto_por_codigo_completo(self, codigo: str) -> Dict[str, Any]:
        """
        ✅ CORREGIDO: Obtiene producto con información completa
        """
        if not codigo:
            return None
            
        query = """
        SELECT 
            p.id,
            p.Codigo,
            p.Nombre,
            p.Detalles,
            p.Precio_compra,
            p.Precio_venta,
            p.Unidad_Medida,
            p.Stock_Minimo,
            p.ID_Marca,
            m.Nombre as Marca_Nombre,
            -- ✅ STOCK CALCULADO DESDE LOTES
            ISNULL((
                SELECT SUM(l.Cantidad_Unitario) 
                FROM Lote l 
                WHERE l.Id_Producto = p.id 
                  AND l.Estado = 'ACTIVO'
            ), 0) as Stock_Actual,
            ISNULL((
                SELECT SUM(l.Cantidad_Unitario) 
                FROM Lote l 
                WHERE l.Id_Producto = p.id 
                  AND l.Estado = 'ACTIVO'
            ), 0) as Stock_Unitario
        FROM Productos p
        LEFT JOIN Marca m ON p.ID_Marca = m.id
        WHERE p.Codigo = ? AND p.Activo = 1
        """
        
        resultado = self._execute_query(query, (codigo.strip(),), fetch_one=True, use_cache=False)
        
        if resultado:
            print(f"📋 Producto encontrado: {resultado['Codigo']} - Stock: {resultado['Stock_Actual']}")
        
        return resultado

    def verificar_disponibilidad_producto_sin_cache(self, codigo: str) -> Dict[str, Any]:
        """
        ✅ CORREGIDO: Verifica disponibilidad SIN usar cache
        """
        if not codigo:
            return {"cantidad_disponible": 0, "disponible": False}
        
        try:
            query = """
            SELECT 
                p.id,
                p.Codigo,
                p.Nombre,
                -- ✅ STOCK CALCULADO DESDE LOTES
                ISNULL((
                    SELECT SUM(l.Cantidad_Unitario) 
                    FROM Lote l 
                    WHERE l.Id_Producto = p.id 
                      AND l.Estado = 'ACTIVO'
                ), 0) as Stock_Disponible
            FROM Productos p
            WHERE p.Codigo = ? AND p.Activo = 1
            """
            
            resultado = self._execute_query(query, (codigo.strip(),), fetch_one=True, use_cache=False)
            
            if resultado:
                stock_disponible = resultado['Stock_Disponible'] or 0
                return {
                    "cantidad_disponible": stock_disponible,
                    "disponible": stock_disponible > 0,
                    "producto_id": resultado['id'],
                    "nombre": resultado['Nombre']
                }
            else:
                return {"cantidad_disponible": 0, "disponible": False}
                
        except Exception as e:
            print(f"❌ Error verificando disponibilidad sin cache para {codigo}: {e}")
            return {"cantidad_disponible": 0, "disponible": False}

    # ===== RESTO DE MÉTODOS SIN CAMBIOS =====
    # (crear_venta, actualizar_venta_completa, eliminar_venta, etc.)
    # Ya están correctos porque usan el sistema FIFO del ProductoRepository
    
    @ExceptionHandler.handle_exception
    def crear_venta(self, usuario_id: int, items: List[Dict[str, Any]]) -> Optional[Dict[str, Any]]:
        """
        ✅ Crea venta usando sistema FIFO de lotes
        """
        validate_required(usuario_id, "usuario_id")
        validate_required(items, "items")
        
        if not items:
            raise VentaError("No hay items para vender")
        
        conn = None
        venta_id = None
        lotes_afectados = []
        
        try:
            conn = self._get_connection()
            cursor = conn.cursor()
            
            # Validar items
            items_validados = []
            total_venta = 0
            
            for i, item in enumerate(items):
                codigo = str(item.get('codigo', '')).strip()
                cantidad = int(item.get('cantidad', 0))
                precio = float(item.get('precio', 0))
                
                if not codigo:
                    raise VentaError(f"Item {i}: Código requerido")
                if cantidad <= 0:
                    raise VentaError(f"Item {i}: Cantidad debe ser mayor a 0")
                if precio <= 0:
                    raise VentaError(f"Item {i}: Precio debe ser mayor a 0")
                
                # Obtener producto
                producto = self.get_producto_por_codigo(codigo)
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
                
                subtotal = cantidad * precio
                total_venta += subtotal
                
                items_validados.append({
                    'producto_id': producto['id'],
                    'codigo': codigo,
                    'nombre': producto['Nombre'],
                    'cantidad': cantidad,
                    'precio': precio,
                    'subtotal': subtotal,
                    'lotes_necesarios': disponibilidad['lotes_necesarios']
                })
            
            print(f"📋 Items validados: {len(items_validados)}, Total: ${total_venta:.2f}")
            
            # Crear venta
            cursor.execute("""
                INSERT INTO Ventas (Id_Usuario, Fecha, Total)
                OUTPUT INSERTED.id
                VALUES (?, GETDATE(), ?)
            """, (usuario_id, total_venta))
            
            resultado = cursor.fetchone()
            if not resultado:
                raise VentaError("Error creando venta")
            
            venta_id = resultado[0]
            print(f"✅ Venta creada - ID: {venta_id}")
            
            # Procesar cada item usando FIFO
            for item in items_validados:
                try:
                    lotes_utilizados = self.producto_repo.reducir_stock_fifo(
                        item['producto_id'], item['cantidad']
                    )
                    lotes_afectados.extend(lotes_utilizados)
                    
                    print(f"📦 FIFO aplicado para {item['codigo']}: {len(lotes_utilizados)} lotes")
                    
                    # Crear DetallesVentas
                    for lote_usado in lotes_utilizados:
                        cursor.execute("""
                            INSERT INTO DetallesVentas 
                            (Id_Venta, Id_Lote, Cantidad_Unitario, Precio_Unitario)
                            VALUES (?, ?, ?, ?)
                        """, (
                            venta_id,
                            lote_usado['lote_id'],
                            lote_usado['cantidad_reducida'],
                            item['precio']
                        ))
                        
                except Exception as fifo_error:
                    print(f"❌ Error en FIFO para {item['codigo']}: {fifo_error}")
                    raise StockInsuficienteError(
                        item['codigo'], 0, item['cantidad']
                    )
            
            conn.commit()
            
            # Limpiar cache
            self._invalidate_cache_after_modification()
            if hasattr(self.producto_repo, '_invalidate_cache_after_modification'):
                self.producto_repo._invalidate_cache_after_modification()
            
            venta_completa = {
                'id': venta_id,
                'Id_Usuario': usuario_id,
                'Fecha': datetime.now(),
                'Total': total_venta,
                'items_procesados': len(items_validados),
                'lotes_afectados': len(lotes_afectados)
            }
            
            print(f"🎉 Venta {venta_id} completada - FIFO aplicado")
            return venta_completa
            
        except Exception as e:
            print(f"❌ Error en crear_venta: {e}")
            
            if conn:
                conn.rollback()
                print("🔄 Rollback ejecutado")
            
            if isinstance(e, (VentaError, ProductoNotFoundError, StockInsuficienteError)):
                raise e
            else:
                raise VentaError(f"Error procesando venta: {str(e)}")
            
        finally:
            if conn:
                conn.close()

    # ===== MÉTODOS DE CONSULTA (ya correctos) =====
    
    def get_venta_completa(self, venta_id: int) -> Dict[str, Any]:
        """Obtiene venta con detalles ORIGINALES"""
        validate_required(venta_id, "venta_id")
        
        venta_query = """
            SELECT v.*, u.Nombre + ' ' + u.Apellido_Paterno as Vendedor,
            u.nombre_usuario as Vendedor_Email
            FROM Ventas v
            INNER JOIN Usuario u ON v.Id_Usuario = u.id
            WHERE v.id = ?
        """
        venta = self._execute_query(venta_query, (venta_id,), fetch_one=True, use_cache=False)
        
        if not venta:
            raise VentaError(f"Venta no encontrada: {venta_id}", venta_id)
        
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
        detalles = self._execute_query(detalles_query, (venta_id,), use_cache=False)
        
        venta['detalles'] = detalles
        venta['total_items'] = len(detalles)
        venta['total_unidades'] = sum(detalle['Cantidad_Unitario'] for detalle in detalles)
        
        return venta

    def get_venta_completa_consolidada(self, venta_id: int) -> Dict[str, Any]:
        """Obtiene venta con detalles CONSOLIDADOS por producto"""
        validate_required(venta_id, "venta_id")
        
        venta_query = """
            SELECT v.*, u.Nombre + ' ' + u.Apellido_Paterno as Vendedor,
            u.nombre_usuario as Vendedor_Email
            FROM Ventas v
            INNER JOIN Usuario u ON v.Id_Usuario = u.id
            WHERE v.id = ?
        """
        venta = self._execute_query(venta_query, (venta_id,), fetch_one=True, use_cache=False)
        
        if not venta:
            raise VentaError(f"Venta no encontrada: {venta_id}", venta_id)
        
        detalles_query = """
        SELECT 
            p.Codigo as Producto_Codigo,
            p.Nombre as Producto_Nombre,
            ISNULL(m.Nombre, 'Sin marca') as Marca_Nombre,
            SUM(dv.Cantidad_Unitario) as Cantidad_Unitario,
            MAX(dv.Precio_Unitario) as Precio_Unitario,
            SUM(dv.Cantidad_Unitario * dv.Precio_Unitario) as Subtotal,
            MIN(l.Fecha_Vencimiento) as Fecha_Vencimiento,
            COUNT(dv.id) as Numero_Registros
        FROM DetallesVentas dv
        INNER JOIN Lote l ON dv.Id_Lote = l.id
        INNER JOIN Productos p ON l.Id_Producto = p.id
        LEFT JOIN Marca m ON p.ID_Marca = m.id
        WHERE dv.Id_Venta = ?
        GROUP BY p.id, p.Codigo, p.Nombre, m.Nombre
        ORDER BY p.Nombre ASC
        """
        
        detalles = self._execute_query(detalles_query, (venta_id,), use_cache=False)
        
        venta['detalles'] = detalles
        venta['total_items'] = len(detalles)
        venta['total_unidades'] = sum(float(d.get('Cantidad_Unitario', 0)) for d in detalles)
        
        return venta

    # ===== MÉTODOS DE ACTUALIZACIÓN Y ELIMINACIÓN =====
    
    @ExceptionHandler.handle_exception
    def actualizar_venta_completa(self, venta_id: int, nuevos_productos: List[Dict[str, Any]]) -> bool:
        """Actualiza venta evitando deadlocks"""
        validate_required(venta_id, "venta_id")
        validate_required(nuevos_productos, "nuevos_productos")
        
        if not nuevos_productos:
            raise VentaError("No hay productos para actualizar")
        
        conn = None
        
        try:
            conn = self._get_connection()
            cursor = conn.cursor()
            
            print(f"🔄 Iniciando actualización de venta {venta_id}")
            
            # Restaurar stock
            detalles_originales = self.get_detalles_venta_para_restauracion(venta_id)
            if not detalles_originales:
                raise VentaError(f"Venta {venta_id} no encontrada")
            
            for detalle in detalles_originales:
                cursor.execute("""
                    UPDATE Lote 
                    SET Cantidad_Unitario = Cantidad_Unitario + ?
                    WHERE id = ?
                """, (detalle['Cantidad_Unitario'], detalle['Id_Lote']))
            
            print(f"✅ Stock restaurado")
            
            # Eliminar detalles originales
            cursor.execute("DELETE FROM DetallesVentas WHERE Id_Venta = ?", (venta_id,))
            
            # Validar nuevos productos
            total_nueva_venta = 0
            items_para_procesar = []
            
            for i, producto in enumerate(nuevos_productos):
                codigo = str(producto.get('codigo', '')).strip()
                cantidad = int(producto.get('cantidad', 0))
                precio = float(producto.get('precio', 0))
                
                if not codigo or cantidad <= 0 or precio <= 0:
                    raise VentaError(f"Producto {i}: Datos inválidos")
                
                # ✅ Verificar stock desde lotes
                cursor.execute("""
                    SELECT p.id, 
                        ISNULL((
                            SELECT SUM(l.Cantidad_Unitario) 
                            FROM Lote l 
                            WHERE l.Id_Producto = p.id 
                              AND l.Estado = 'ACTIVO'
                        ), 0) as Stock_Disponible
                    FROM Productos p
                    WHERE p.Codigo = ? AND p.Activo = 1
                """, (codigo,))
                
                producto_result = cursor.fetchone()
                if not producto_result:
                    raise ProductoNotFoundError(codigo=codigo)
                
                producto_id, stock_disponible = producto_result[0], producto_result[1]
                
                if stock_disponible < cantidad:
                    raise StockInsuficienteError(codigo, stock_disponible, cantidad)
                
                subtotal = cantidad * precio
                total_nueva_venta += subtotal
                
                items_para_procesar.append({
                    'producto_id': producto_id,
                    'codigo': codigo,
                    'cantidad': cantidad,
                    'precio': precio
                })
            
            print(f"✅ Productos validados: {len(items_para_procesar)}")
            
            # Aplicar nueva venta usando FIFO
            for item in items_para_procesar:
                cantidad_restante = item['cantidad']
                
                cursor.execute("""
                    SELECT id, Cantidad_Unitario 
                    FROM Lote 
                    WHERE Id_Producto = ? 
                      AND Cantidad_Unitario > 0 
                      AND Estado = 'ACTIVO'
                    ORDER BY 
                        CASE WHEN Fecha_Vencimiento IS NOT NULL 
                             THEN Fecha_Vencimiento 
                             ELSE '9999-12-31' 
                        END ASC,
                        Fecha_Compra ASC,
                        id ASC
                """, (item['producto_id'],))
                
                lotes_disponibles = cursor.fetchall()
                
                for lote_id, cantidad_lote in lotes_disponibles:
                    if cantidad_restante <= 0:
                        break
                    
                    cantidad_a_usar = min(cantidad_restante, cantidad_lote)
                    
                    cursor.execute("""
                        UPDATE Lote 
                        SET Cantidad_Unitario = Cantidad_Unitario - ?
                        WHERE id = ?
                    """, (cantidad_a_usar, lote_id))
                    
                    cursor.execute("""
                        INSERT INTO DetallesVentas 
                        (Id_Venta, Id_Lote, Cantidad_Unitario, Precio_Unitario)
                        VALUES (?, ?, ?, ?)
                    """, (venta_id, lote_id, cantidad_a_usar, item['precio']))
                    
                    cantidad_restante -= cantidad_a_usar
                
                if cantidad_restante > 0:
                    raise StockInsuficienteError(
                        item['codigo'], 
                        item['cantidad'] - cantidad_restante, 
                        item['cantidad']
                    )
            
            # Actualizar total
            cursor.execute(
                "UPDATE Ventas SET Total = ? WHERE id = ?", 
                (total_nueva_venta, venta_id)
            )
            
            conn.commit()
            
            self._invalidate_cache_after_modification()
            
            print(f"🎉 Venta {venta_id} actualizada exitosamente")
            return True
            
        except Exception as e:
            print(f"❌ Error actualizando venta: {e}")
            if conn:
                conn.rollback()
            raise VentaError(f"Error actualizando venta: {str(e)}")
        
        finally:
            if conn:
                conn.close()

    @ExceptionHandler.handle_exception
    def eliminar_venta(self, venta_id: int) -> bool:
        """Elimina venta y RESTAURA stock a lotes"""
        validate_required(venta_id, "venta_id")
        
        conn = None
        
        try:
            conn = self._get_connection()
            cursor = conn.cursor()
            
            print(f"🗑️ Eliminando venta {venta_id}")
            
            # Obtener detalles para restaurar
            detalles_venta = self.get_detalles_venta_para_restauracion(venta_id)
            if not detalles_venta:
                raise VentaError(f"Venta {venta_id} no encontrada")
            
            # Restaurar stock a lotes
            for detalle in detalles_venta:
                cursor.execute("""
                    UPDATE Lote 
                    SET Cantidad_Unitario = Cantidad_Unitario + ?
                    WHERE id = ?
                """, (detalle['Cantidad_Unitario'], detalle['Id_Lote']))
            
            print(f"✅ Stock restaurado a {len(detalles_venta)} lotes")
            
            # Eliminar detalles
            cursor.execute("DELETE FROM DetallesVentas WHERE Id_Venta = ?", (venta_id,))
            
            # Eliminar venta
            cursor.execute("DELETE FROM Ventas WHERE id = ?", (venta_id,))
            
            if cursor.rowcount == 0:
                raise VentaError(f"Venta {venta_id} no encontrada")
            
            conn.commit()
            
            self._invalidate_cache_after_modification()
            
            print(f"🎉 Venta {venta_id} eliminada - Stock restaurado")
            return True
            
        except Exception as e:
            print(f"❌ Error eliminando venta: {e}")
            
            if conn:
                conn.rollback()
            
            raise VentaError(f"Error eliminando venta: {str(e)}")
        
        finally:
            if conn:
                conn.close()

    def get_detalles_venta_para_restauracion(self, venta_id: int) -> List[Dict[str, Any]]:
        """Obtiene detalles de venta para restauración"""
        query = """
        SELECT 
            dv.Id_Lote,
            dv.Cantidad_Unitario,
            dv.Precio_Unitario,
            (dv.Cantidad_Unitario * dv.Precio_Unitario) as Subtotal,
            l.Id_Producto,
            p.Codigo as Producto_Codigo,
            p.Nombre as Producto_Nombre
        FROM DetallesVentas dv
        INNER JOIN Lote l ON dv.Id_Lote = l.id
        INNER JOIN Productos p ON l.Id_Producto = p.id
        WHERE dv.Id_Venta = ?
        ORDER BY dv.id
        """
        
        try:
            detalles = self._execute_query(query, (venta_id,)) or []
            print(f"📋 Detalles obtenidos para restauración: {len(detalles)} registros")
            return detalles
        except Exception as e:
            print(f"❌ Error obteniendo detalles: {e}")
            return []

    # ===== MÉTODOS DE INVALIDACIÓN DE CACHE =====
    
    def _invalidate_cache_after_modification(self):
        """Invalidación completa de cache"""
        try:
            print("🧹 INVALIDACIÓN COMPLETA DE CACHE...")
            
            caches_to_clear = [
                '_cache', '_query_cache', '_result_cache', '_data_cache', 
                '_product_cache', '_stock_cache', '_search_cache'
            ]
            
            for cache_name in caches_to_clear:
                if hasattr(self, cache_name):
                    cache_obj = getattr(self, cache_name)
                    if hasattr(cache_obj, 'clear'):
                        cache_obj.clear()
            
            # Resetear timestamps
            timestamp_attrs = [
                '_last_cache_time', '_cache_timestamp', '_last_update',
                '_last_product_cache', '_last_stock_update'
            ]
            
            for attr_name in timestamp_attrs:
                if hasattr(self, attr_name):
                    setattr(self, attr_name, None)
            
            # Forzar recarga
            self._force_reload = True
            self._force_reload_productos = True
            self._bypass_all_cache = True
            
            # Invalidar ProductoRepository
            if hasattr(self, 'producto_repo') and self.producto_repo:
                if hasattr(self.producto_repo, '_invalidate_cache_after_modification'):
                    self.producto_repo._invalidate_cache_after_modification()
            
        except Exception as e:
            print(f"⚠️ Error en invalidación: {e}")

    # ===== MÉTODOS DE REPORTES (sin cambios necesarios) =====
    
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
        
        resumen = self._execute_query(query, (fecha,), fetch_one=True, use_cache=False)
        
        ventas_query = """
        SELECT v.*, u.Nombre + ' ' + u.Apellido_Paterno as Vendedor
        FROM Ventas v
        INNER JOIN Usuario u ON v.Id_Usuario = u.id
        WHERE CAST(v.Fecha AS DATE) = ?
        ORDER BY v.Fecha DESC
        """
        
        ventas = self._execute_query(ventas_query, (fecha,), use_cache=False)
        
        return {
            'fecha': fecha,
            'resumen': resumen,
            'ventas': ventas
        }
    
    def get_ventas_by_date_range(self, fecha_inicio: datetime, fecha_fin: datetime) -> List[Dict[str, Any]]:
        """
        Obtiene todas las ventas en un rango de fechas
        Compatible con dashboard_model.py
        
        Args:
            fecha_inicio: Fecha y hora de inicio del rango (inclusive)
            fecha_fin: Fecha y hora de fin del rango (exclusivo)
        
        Returns:
            Lista de ventas con sus totales y vendedor
        """
        try:
            # Convertir datetime a strings para SQL
            fecha_inicio_str = fecha_inicio.strftime('%Y-%m-%d %H:%M:%S')
            fecha_fin_str = fecha_fin.strftime('%Y-%m-%d %H:%M:%S')
            
            print(f"🔍 VentaRepository - Buscando ventas entre {fecha_inicio_str} y {fecha_fin_str}")
            
            query = """
            SELECT 
                v.id,
                v.Fecha,
                v.Total,
                v.Id_Usuario,
                u.Nombre + ' ' + u.Apellido_Paterno as Vendedor,
                -- Compatibilidad con múltiples nombres de campo
                v.Total as Venta_Total
            FROM Ventas v
            INNER JOIN Usuario u ON v.Id_Usuario = u.id
            WHERE v.Fecha >= ? AND v.Fecha < ?
            ORDER BY v.Fecha DESC
            """
            
            # Ejecutar sin caché para datos frescos
            ventas = self._execute_query(query, (fecha_inicio_str, fecha_fin_str), use_cache=False) or []
            
            print(f"💰 VentaRepository - {len(ventas)} ventas encontradas en el rango")
            
            # Log de debug: mostrar total sumado
            if ventas:
                total_sum = sum(float(v.get('Total', 0)) for v in ventas)
                print(f"   💵 Total sumado: Bs {total_sum:.2f}")
            
            return ventas
            
        except Exception as e:
            print(f"❌ Error obteniendo ventas por rango: {e}")
            return []