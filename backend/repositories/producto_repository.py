from typing import List, Dict, Any, Optional, Tuple
from datetime import datetime, timedelta
from decimal import Decimal
import traceback

from ..core.config_fifo import config_fifo

from ..core.base_repository import BaseRepository
from ..core.excepciones import (
    ProductoNotFoundError, StockInsuficienteError, ProductoVencidoError,
    ValidationError, ExceptionHandler, validate_required, validate_positive_number
)

class ProductoRepository(BaseRepository):
    """Repository para productos con lógica FIFO de lotes y control de vencimientos"""
    
    def __init__(self):
        super().__init__('Productos', 'productos')
    
    def get_active(self) -> List[Dict[str, Any]]:
        """Obtiene productos activos (con stock > 0)"""
        query = """
        SELECT p.*, m.Nombre as Marca_Nombre,
            ISNULL((SELECT SUM(l.Cantidad_Unitario) FROM Lote l WHERE l.Id_Producto = p.id), 0) as Stock_Calculado
        FROM Productos p
        INNER JOIN Marca m ON p.ID_Marca = m.id
        WHERE (SELECT ISNULL(SUM(l.Cantidad_Unitario), 0) FROM Lote l WHERE l.Id_Producto = p.id) > 0
        ORDER BY p.id DESC
        """
        return self._execute_query(query)
    
    def get_by_codigo(self, codigo: str) -> Optional[Dict[str, Any]]:
        """Obtiene producto por código único"""
        validate_required(codigo, "codigo")
        
        query = """
        SELECT p.*, m.Nombre as Marca_Nombre, m.Detalles as Marca_Detalles,
            ISNULL((SELECT SUM(l.Cantidad_Unitario) FROM Lote l WHERE l.Id_Producto = p.id), 0) as Stock_Total
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
            p.Precio_compra, p.Precio_venta, p.Unidad_Medida,
            m.id as Marca_ID, m.Nombre as Marca_Nombre, m.Detalles as Marca_Detalles,
            ISNULL((SELECT SUM(l.Cantidad_Unitario) FROM Lote l WHERE l.Id_Producto = p.id), 0) as Stock_Total,
            ISNULL((SELECT SUM(l.Cantidad_Unitario) FROM Lote l WHERE l.Id_Producto = p.id), 0) as Stock_Unitario
        FROM Productos p
        INNER JOIN Marca m ON p.ID_Marca = m.id
        ORDER BY p.id DESC
        """
        return self._execute_query(query)
    
    def buscar_productos(self, termino: str, incluir_sin_stock: bool = False) -> List[Dict[str, Any]]:
        """
        ✅ CORREGIDO: Busca productos por nombre o código - STOCK CALCULADO DESDE LOTES
        """
        if not termino:
            return []
        
        # Condición de stock basada en lotes (no en tabla Productos)
        stock_condition = "" if incluir_sin_stock else """
            AND (SELECT ISNULL(SUM(l.Cantidad_Unitario), 0) 
                FROM Lote l 
                WHERE l.Id_Producto = p.id) > 0
        """
        
        query = f"""
        SELECT 
            p.id,
            p.Codigo,
            p.Nombre,
            p.Detalles,
            p.Precio_compra,
            p.Precio_venta,
            p.Unidad_Medida,
            p.ID_Marca,
            m.Nombre as Marca_Nombre,
            m.Detalles as Marca_Detalles,
            ISNULL((SELECT SUM(l.Cantidad_Unitario) 
                    FROM Lote l 
                    WHERE l.Id_Producto = p.id), 0) as Stock_Total,
            ISNULL((SELECT SUM(l.Cantidad_Unitario) 
                    FROM Lote l 
                    WHERE l.Id_Producto = p.id), 0) as Stock_Unitario,
            (SELECT COUNT(*) 
            FROM Lote l 
            WHERE l.Id_Producto = p.id AND l.Cantidad_Unitario > 0) as Lotes_Activos,
            (SELECT MIN(l.Fecha_Vencimiento) 
            FROM Lote l 
            WHERE l.Id_Producto = p.id 
            AND l.Cantidad_Unitario > 0 
            AND l.Fecha_Vencimiento IS NOT NULL) as Proxima_Vencimiento,
            CASE 
                WHEN (SELECT SUM(l.Cantidad_Unitario) FROM Lote l WHERE l.Id_Producto = p.id) = 0 
                THEN 'AGOTADO'
                WHEN (SELECT SUM(l.Cantidad_Unitario) FROM Lote l WHERE l.Id_Producto = p.id) <= 5 
                THEN 'BAJO'
                ELSE 'DISPONIBLE'
            END as Estado_Stock
        FROM Productos p
        INNER JOIN Marca m ON p.ID_Marca = m.id
        WHERE (p.Nombre LIKE ? OR p.Codigo LIKE ?) {stock_condition}
        ORDER BY 
            -- Priorizar productos con más stock
            (SELECT ISNULL(SUM(l.Cantidad_Unitario), 0) FROM Lote l WHERE l.Id_Producto = p.id) DESC,
            p.Nombre ASC
        """
        
        termino_like = f"%{termino}%"
        resultados = self._execute_query(query, (termino_like, termino_like))
        
        print(f"🔍 Búsqueda '{termino}': {len(resultados)} productos encontrados (stock desde lotes)")
        
        return resultados or []
    
    def get_productos_bajo_stock(self, stock_minimo: int = 10) -> List[Dict[str, Any]]:
        """Obtiene productos con stock bajo"""
        query = """
        SELECT 
            p.*, m.Nombre as Marca_Nombre,
            ISNULL((SELECT SUM(l.Cantidad_Unitario) FROM Lote l WHERE l.Id_Producto = p.id), 0) as Stock_Total
        FROM Productos p
        INNER JOIN Marca m ON p.ID_Marca = m.id
        WHERE (SELECT ISNULL(SUM(l.Cantidad_Unitario), 0) 
            FROM Lote l WHERE l.Id_Producto = p.id) <= ?
        ORDER BY (SELECT ISNULL(SUM(l.Cantidad_Unitario), 0) 
                FROM Lote l WHERE l.Id_Producto = p.id)
        """
        return self._execute_query(query, (stock_minimo,), use_cache=False)
    
    def get_lotes_producto(self, producto_id: int, solo_activos: bool = True) -> List[Dict[str, Any]]:
        """Obtiene lotes de un producto ordenados por FIFO"""
        validate_required(producto_id, "producto_id")
        
        where_condition = "AND l.Cantidad_Unitario > 0" if solo_activos else ""
        
        query = f"""
        SELECT l.*, p.Codigo, p.Nombre as Producto_Nombre,
               l.Cantidad_Unitario as Stock_Lote,
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
    
    def get_lotes_producto_completo_fifo(self, producto_id: int) -> List[Dict[str, Any]]:
        """
        🚀 FIFO 2.0: Obtiene TODOS los lotes de un producto
        Incluye: activos (stock>0), agotados (stock=0), vencidos
        
        Args:
            producto_id: ID del producto
            
        Returns:
            Lista de lotes ordenados por fecha de vencimiento (FIFO)
        """
        validate_required(producto_id, "producto_id")
        
        query = """
        SELECT 
            l.id as Id_Lote,
            l.Id_Producto,
            l.Id_Compra,
            l.Cantidad_Unitario as Stock_Lote,
            l.Cantidad_Unitario as Cantidad_Inicial,
            l.Precio_Compra,
            l.Fecha_Compra,
            l.Fecha_Vencimiento,
            p.Codigo as Producto_Codigo,
            p.Nombre as Producto_Nombre,
            m.Nombre as Marca,
            prov.Nombre as Proveedor,
            DATEDIFF(DAY, GETDATE(), l.Fecha_Vencimiento) as Dias_para_Vencer,
            CASE 
                WHEN l.Cantidad_Unitario = 0 THEN 'AGOTADO'
                WHEN l.Fecha_Vencimiento < GETDATE() THEN 'VENCIDO'
                ELSE 'ACTIVO'
            END as Estado_Lote,
            CASE 
                WHEN l.Fecha_Vencimiento < GETDATE() THEN 'VENCIDO'
                WHEN l.Fecha_Vencimiento <= DATEADD(DAY, 30, GETDATE()) THEN 'PRÓXIMO A VENCER'
                ELSE 'VIGENTE'
            END as Estado_Vencimiento
        FROM Lote l
        INNER JOIN Productos p ON l.Id_Producto = p.id
        INNER JOIN Marca m ON p.ID_Marca = m.id
        LEFT JOIN Compra c ON l.Id_Compra = c.id
        LEFT JOIN Proveedor prov ON c.Id_Proveedor = prov.id
        WHERE l.Id_Producto = ?
        ORDER BY 
            CASE WHEN l.Cantidad_Unitario > 0 THEN 0 ELSE 1 END,
            l.Fecha_Vencimiento ASC,
            l.id ASC
        """
        
        try:
            resultado = self._execute_query(query, (producto_id,), use_cache=False) or []
            
            if resultado:
                print(f"📦 Lotes del producto {producto_id}: {len(resultado)} lotes")
                for lote in resultado[:3]:  # Mostrar primeros 3
                    print(f"   - Lote #{lote.get('Id_Lote')} | Stock: {lote.get('Stock_Lote')} | Estado: {lote.get('Estado_Lote')}")
            else:
                print(f"⚠️ Producto {producto_id} sin lotes registrados")
            
            return resultado
        except Exception as e:
            print(f"❌ Error obteniendo lotes completos del producto {producto_id}: {e}")
            import traceback
            traceback.print_exc()
            return []
    
    def get_ultima_venta_producto(self, producto_id: int) -> Optional[Dict[str, Any]]:
        """
        🚀 FIFO 2.0: Obtiene información de la última venta de un producto
        
        Args:
            producto_id: ID del producto
            
        Returns:
            Dict con fecha, cantidad y precio de la última venta, o None si nunca se vendió
        """
        validate_required(producto_id, "producto_id")
        
        query = """
        SELECT TOP 1
            v.Fecha as Fecha_Venta,
            v.id as Id_Venta,
            SUM(dv.Cantidad_Unitario) as Cantidad_Total,
            AVG(dv.Precio_Unitario) as Precio_Promedio,
            u.Nombre + ' ' + u.Apellido_Paterno as Vendedor
        FROM DetallesVentas dv
        INNER JOIN Ventas v ON dv.Id_Venta = v.id
        INNER JOIN Lote l ON dv.Id_Lote = l.id
        INNER JOIN Usuario u ON v.Id_Usuario = u.id
        WHERE l.Id_Producto = ?
        GROUP BY v.id, v.Fecha, u.Nombre, u.Apellido_Paterno
        ORDER BY v.Fecha DESC
        """
        
        try:
            resultado = self._execute_query(query, (producto_id,), fetch_one=True, use_cache=False)
            
            if resultado:
                # Formatear fecha para mostrar
                fecha_venta = resultado.get('Fecha_Venta')
                if isinstance(fecha_venta, datetime):
                    resultado['Fecha_Venta'] = fecha_venta.strftime('%d/%m/%Y %H:%M')
            
            return resultado
        except Exception as e:
            print(f"❌ Error obteniendo última venta del producto {producto_id}: {e}")
            return None
    
    def get_lotes_por_vencer(self, dias_adelante: int = 90) -> List[Dict[str, Any]]:
        """Obtiene lotes que vencen en X días"""
        query = """
        SELECT l.*, p.Codigo, p.Nombre as Producto_Nombre, m.Nombre as Marca_Nombre,
            l.Cantidad_Unitario as Stock_Lote,
            DATEDIFF(DAY, GETDATE(), l.Fecha_Vencimiento) as Dias_Para_Vencer
        FROM Lote l
        INNER JOIN Productos p ON l.Id_Producto = p.id
        INNER JOIN Marca m ON p.ID_Marca = m.id
        WHERE l.Fecha_Vencimiento <= DATEADD(DAY, ?, GETDATE())
        AND l.Fecha_Vencimiento >= GETDATE()
        AND l.Cantidad_Unitario > 0
        ORDER BY l.Fecha_Vencimiento ASC
        """
        
        try:
            return self._execute_query(query, (dias_adelante,), use_cache=False) or []
        except Exception:
            return []
        
    def get_lotes_vencidos(self) -> List[Dict[str, Any]]:
        """Obtiene lotes vencidos con stock"""
        query = """
        SELECT l.*, p.Codigo, p.Nombre as Producto_Nombre, m.Nombre as Marca_Nombre,
            l.Cantidad_Unitario as Stock_Lote,
            DATEDIFF(DAY, l.Fecha_Vencimiento, GETDATE()) as Dias_Vencido
        FROM Lote l
        INNER JOIN Productos p ON l.Id_Producto = p.id
        INNER JOIN Marca m ON p.ID_Marca = m.id
        WHERE l.Fecha_Vencimiento < GETDATE()
        AND l.Cantidad_Unitario > 0
        ORDER BY l.Fecha_Vencimiento ASC
        """
        
        try:
            return self._execute_query(query, use_cache=False) or []
        except Exception:
            return []
    
    def verificar_disponibilidad_fifo(self, producto_id: int, cantidad_necesaria: int) -> Dict[str, Any]:
        """Verifica disponibilidad de stock usando FIFO"""
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
    
    @ExceptionHandler.handle_exception
    def reducir_stock_fifo(self, producto_id: int, cantidad: int) -> List[Dict[str, Any]]:
        """Reduce stock usando método FIFO"""
        validate_required(producto_id, "producto_id")
        validate_positive_number(cantidad, "cantidad")
        
        disponibilidad = self.verificar_disponibilidad_fifo(producto_id, cantidad)
        if not disponibilidad['disponible']:
            raise StockInsuficienteError(
                f"Producto ID {producto_id}", 
                disponibilidad['cantidad_total_disponible'], 
                cantidad
            )
        
        conn = None
        lotes_afectados = []
        
        try:
            conn = self._get_connection()
            cursor = conn.cursor()
            
            query_lotes = """
            SELECT l.id, l.Cantidad_Unitario, l.Fecha_Vencimiento
            FROM Lote l
            WHERE l.Id_Producto = ? AND l.Cantidad_Unitario > 0
            ORDER BY l.Fecha_Vencimiento ASC, l.id ASC
            """
            
            cursor.execute(query_lotes, (producto_id,))
            lotes_disponibles = cursor.fetchall()
            
            if not lotes_disponibles:
                raise StockInsuficienteError(f"Producto ID {producto_id}", 0, cantidad)
            
            cantidad_restante = cantidad
            
            for lote in lotes_disponibles:
                if cantidad_restante <= 0:
                    break
                
                lote_id = lote[0]
                stock_lote = lote[1]
                fecha_vencimiento = lote[2]
                
                cantidad_a_reducir = min(cantidad_restante, stock_lote)
                nuevo_stock_lote = stock_lote - cantidad_a_reducir
                
                cursor.execute("UPDATE Lote SET Cantidad_Unitario = ? WHERE id = ?", 
                             (nuevo_stock_lote, lote_id))
                
                lotes_afectados.append({
                    'lote_id': lote_id,
                    'cantidad_original': stock_lote,
                    'cantidad_reducida': cantidad_a_reducir,
                    'cantidad_final': nuevo_stock_lote,
                    'fecha_vencimiento': fecha_vencimiento
                })
                
                cantidad_restante -= cantidad_a_reducir
            
            if cantidad_restante > 0:
                raise StockInsuficienteError(
                    f"Producto ID {producto_id}", 
                    cantidad - cantidad_restante, 
                    cantidad
                )
            
            # Actualizar Stock_Unitario en tabla Productos
            cursor.execute("""
                UPDATE Productos 
                SET Stock_Unitario = (
                    SELECT ISNULL(SUM(l.Cantidad_Unitario), 0) 
                    FROM Lote l 
                    WHERE l.Id_Producto = ?
                )
                WHERE id = ?
            """, (producto_id, producto_id))
            
            conn.commit()
            self._invalidate_cache_after_modification()
            
            return lotes_afectados
            
        except Exception as e:
            if conn:
                conn.rollback()
            raise StockInsuficienteError(
                f"Producto ID {producto_id}", 
                cantidad - cantidad_restante, 
                cantidad
            )
        finally:
            if conn:
                conn.close()

    @ExceptionHandler.handle_exception
    def crear_producto_con_lote_inicial(self, datos_producto: dict, datos_lote: dict) -> int:
        """Crea producto con su primer lote - CON VALIDACIÓN DE MARCA"""
        
        # Validar que tenemos ID_Marca
        if 'ID_Marca' not in datos_producto or not datos_producto['ID_Marca']:
            raise ValueError("ID de marca es requerido")
        
        id_marca = datos_producto['ID_Marca']
        print(f"🏷️ Creando producto con marca ID: {id_marca}")
        
        # Verificar que la marca existe
        marca_existente = self._execute_query(
            "SELECT id FROM Marca WHERE id = ?", 
            (id_marca,), 
            fetch_one=True
        )
        
        if not marca_existente:
            print(f"⚠️ Marca ID {id_marca} no existe, usando marca por defecto")
            datos_producto['ID_Marca'] = 1  # Marca por defecto
        
        conn = None
        producto_id = None
        
        try:
            conn = self._get_connection()
            cursor = conn.cursor()
            
            # Crear producto sin OUTPUT (evita conflictos con triggers)
            insert_producto_query = """
            INSERT INTO Productos (Codigo, Nombre, Detalles, Precio_compra, Precio_venta, 
                                Stock_Unitario, Unidad_Medida, ID_Marca)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """

            cursor.execute(insert_producto_query, (
                datos_producto['Codigo'],
                datos_producto['Nombre'],
                datos_producto.get('Detalles', ''),
                datos_producto['Precio_compra'],
                datos_producto['Precio_venta'],
                0,  # Stock inicial en 0
                datos_producto.get('Unidad_Medida', 'Tabletas'),
                datos_producto.get('ID_Marca', 1)
            ))
            
            # Obtener ID del producto insertado
            cursor.execute("SELECT @@IDENTITY as id")
            resultado = cursor.fetchone()
            if not resultado:
                raise Exception("No se pudo crear el producto")
            
            producto_id = resultado[0]
            
            # Crear lote inicial
            cantidad_inicial = datos_lote.get('cantidad_unitario', 0)
            fecha_vencimiento = datos_lote.get('fecha_vencimiento')

            if cantidad_inicial > 0:
                cursor.execute("""
                    INSERT INTO Lote (Id_Producto, Cantidad_Unitario, Fecha_Vencimiento)
                    VALUES (?, ?, ?)
                """, (producto_id, cantidad_inicial, fecha_vencimiento))
                
                # Actualizar Stock_Unitario en Productos
                cursor.execute("""
                    UPDATE Productos 
                    SET Stock_Unitario = ?
                    WHERE id = ?
                """, (cantidad_inicial, producto_id))

            conn.commit()
            self._invalidate_cache_after_modification()
            
            return producto_id
            
        except Exception as e:
            if conn:
                conn.rollback()
            raise Exception(f"Error creando producto: {str(e)}")
        finally:
            if conn:
                conn.close()
    
    @ExceptionHandler.handle_exception
    def aumentar_stock_compra(self, producto_id: int, cantidad_unitario: int, 
                        fecha_vencimiento: str = None, precio_compra: float = None) -> int:
        """Aumenta stock de producto creando nuevo lote"""
        validate_required(producto_id, "producto_id")
        
        if cantidad_unitario <= 0:
            raise ValueError("Debe especificar cantidad unitaria mayor a 0")
        
        # Manejar fecha de vencimiento
        fecha_venc_final = None
        if fecha_vencimiento is not None and isinstance(fecha_vencimiento, str):
            fecha_clean = fecha_vencimiento.strip()
            if fecha_clean and fecha_clean.lower() not in ["sin vencimiento", "", "none", "null"]:
                try:
                    datetime.strptime(fecha_clean, '%Y-%m-%d')
                    fecha_venc_final = fecha_clean
                except ValueError:
                    raise ValueError(f"Formato de fecha inválido: {fecha_clean}. Use YYYY-MM-DD")
        
        # Verificar que el producto existe
        producto = self.get_by_id(producto_id)
        if not producto:
            raise Exception(f"Producto {producto_id} no encontrado")
        
        # Usar una sola conexión para toda la transacción
        conn = None
        lote_id = None
        
        try:
            conn = self._get_connection()
            cursor = conn.cursor()
            
            # Crear nuevo lote
            if fecha_venc_final is not None:
                cursor.execute("""
                    INSERT INTO Lote (Id_Producto, Cantidad_Unitario, Fecha_Vencimiento) 
                    VALUES (?, ?, ?)
                """, (producto_id, cantidad_unitario, fecha_venc_final))
            else:
                cursor.execute("""
                    INSERT INTO Lote (Id_Producto, Cantidad_Unitario, Fecha_Vencimiento) 
                    VALUES (?, ?, NULL)
                """, (producto_id, cantidad_unitario))

            # Obtener el ID del lote insertado
            cursor.execute("SELECT @@IDENTITY as id")
            result = cursor.fetchone()
            if not result:
                raise Exception("No se pudo obtener el ID del lote creado")
            
            lote_id = result[0]
            
            # Actualizar Stock_Unitario en tabla Productos
            cursor.execute("""
                UPDATE Productos 
                SET Stock_Unitario = (
                    SELECT ISNULL(SUM(l.Cantidad_Unitario), 0) 
                    FROM Lote l 
                    WHERE l.Id_Producto = ?
                )
                WHERE id = ?
            """, (producto_id, producto_id))
            
            # Actualizar precio de compra si se proporciona
            if precio_compra and precio_compra > 0:
                cursor.execute("UPDATE Productos SET Precio_compra = ? WHERE id = ?", 
                            (precio_compra, producto_id))
            
            # Commit de toda la transacción
            conn.commit()
            
            # Limpiar cache
            try:
                if hasattr(self, '_clear_cache'):
                    self._clear_cache()
            except:
                pass
            
            return lote_id
            
        except Exception as e:
            if conn:
                conn.rollback()
            raise Exception(f"Error creando lote: {str(e)}")
        finally:
            if conn:
                conn.close()

    def _rollback_lote(self, lote_id: int):
        """Método auxiliar para eliminar lote en caso de rollback"""
        try:
            self._execute_query("DELETE FROM Lote WHERE id = ?", (lote_id,), fetch_all=False, use_cache=False)
        except Exception:
            pass
    
    @ExceptionHandler.handle_exception
    def actualizar_producto(self, producto_id: int, datos: dict) -> bool:
        """Actualiza un producto existente"""
        validate_required(producto_id, "producto_id")
        
        if not datos:
            raise ValueError("No hay datos para actualizar")
        
        try:
            campos_permitidos = ['Nombre', 'Detalles', 'Precio_compra', 'Precio_venta', 
                               'Unidad_Medida', 'ID_Marca']
            
            campos_update = []
            valores = []
            
            for campo in campos_permitidos:
                if campo in datos:
                    campos_update.append(f"{campo} = ?")
                    valores.append(datos[campo])
            
            if not campos_update:
                raise ValueError("No hay campos válidos para actualizar")
            
            valores.append(producto_id)
            
            query = f"UPDATE Productos SET {', '.join(campos_update)} WHERE id = ?"
            filas_afectadas = self._execute_query(query, valores, fetch_all=False, use_cache=False)
            
            if filas_afectadas > 0:
                self._invalidate_cache_after_modification()
                return True
            else:
                return False
                
        except Exception as e:
            raise Exception(f"Error actualizando producto: {str(e)}")
    
    @ExceptionHandler.handle_exception
    def eliminar_producto(self, producto_id: int) -> bool:
        """Elimina un producto y todos sus lotes (solo si no tiene stock)"""
        validate_required(producto_id, "producto_id")
        
        conn = None
        try:
            conn = self._get_connection()
            cursor = conn.cursor()
            
            # Verificar que no tenga stock
            cursor.execute("SELECT SUM(Cantidad_Unitario) as Stock_Total FROM Lote WHERE Id_Producto = ?", (producto_id,))
            resultado = cursor.fetchone()
            stock_total = resultado[0] if resultado and resultado[0] else 0
            # por ahora se quitara la restriccion de eliminar porducto bajo en stock
            """""
            if stock_total > 0:
                raise ValueError(f"No se puede eliminar: el producto tiene {stock_total} unidades en stock")
            """""
            # Eliminar lotes vacíos y producto
            cursor.execute("DELETE FROM Lote WHERE Id_Producto = ?", (producto_id,))
            cursor.execute("DELETE FROM Productos WHERE id = ?", (producto_id,))
            productos_eliminados = cursor.rowcount
            
            if productos_eliminados > 0:
                conn.commit()
                self._invalidate_cache_after_modification()
                return True
            else:
                raise Exception("Producto no encontrado")
                
        except Exception as e:
            if conn:
                conn.rollback()
            raise Exception(f"Error eliminando producto: {str(e)}")
        finally:
            if conn:
                conn.close()
    
    @ExceptionHandler.handle_exception
    def eliminar_lote(self, lote_id: int) -> bool:
        """Elimina un lote específico"""
        validate_required(lote_id, "lote_id")
        
        try:
            # Obtener producto_id antes de eliminar
            lote_info = self._execute_query("SELECT Id_Producto FROM Lote WHERE id = ?", (lote_id,), fetch_one=True)
            if not lote_info:
                return False
            
            producto_id = lote_info['Id_Producto']
            
            # Eliminar lote
            filas_afectadas = self._execute_query("DELETE FROM Lote WHERE id = ?", (lote_id,), fetch_all=False, use_cache=False)
            
            if filas_afectadas > 0:
                # Actualizar Stock_Unitario en Productos
                self._execute_query("""
                    UPDATE Productos 
                    SET Stock_Unitario = (
                        SELECT ISNULL(SUM(l.Cantidad_Unitario), 0) 
                        FROM Lote l 
                        WHERE l.Id_Producto = ?
                    )
                    WHERE id = ?
                """, (producto_id, producto_id), fetch_all=False, use_cache=False)
                
                self._invalidate_cache_after_modification()
                return True
            else:
                return False
                
        except Exception as e:
            raise Exception(f"Error eliminando lote: {str(e)}")
    
    def actualizar_lote(self, lote_id: int, datos: dict) -> bool:
        """Actualiza un lote específico"""
        validate_required(lote_id, "lote_id")
        
        if not datos:
            raise ValueError("No hay datos para actualizar")
        
        try:
            # Obtener producto_id antes de actualizar
            lote_info = self._execute_query("SELECT Id_Producto FROM Lote WHERE id = ?", (lote_id,), fetch_one=True)
            if not lote_info:
                return False
            
            producto_id = lote_info['Id_Producto']
            
            # ✅ AGREGAR Precio_Compra A CAMPOS PERMITIDOS
            campos_permitidos = ['Cantidad_Unitario', 'Fecha_Vencimiento', 'Precio_Compra']
            campos_update = []
            valores = []
            
            for campo in campos_permitidos:
                if campo in datos:
                    campos_update.append(f"{campo} = ?")
                    valores.append(datos[campo])
            
            if not campos_update:
                raise ValueError("No hay campos válidos para actualizar")
            
            valores.append(lote_id)
            
            query = f"UPDATE Lote SET {', '.join(campos_update)} WHERE id = ?"
            filas_afectadas = self._execute_query(query, valores, fetch_all=False, use_cache=False)
            
            if filas_afectadas > 0:
                # Actualizar Stock_Unitario en Productos si se cambió la cantidad
                if 'Cantidad_Unitario' in datos:
                    self._execute_query("""
                        UPDATE Productos 
                        SET Stock_Unitario = (
                            SELECT ISNULL(SUM(l.Cantidad_Unitario), 0) 
                            FROM Lote l 
                            WHERE l.Id_Producto = ?
                        )
                        WHERE id = ?
                    """, (producto_id, producto_id), fetch_all=False, use_cache=False)
                
                self._invalidate_cache_after_modification()
                return True
            else:
                return False
                
        except Exception as e:
            raise Exception(f"Error actualizando lote: {str(e)}")
    
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
            (SELECT ISNULL(SUM(l2.Cantidad_Unitario), 0) FROM Lote l2 WHERE l2.Id_Producto = p.id) as Stock_Actual
        FROM Productos p
        INNER JOIN Marca m ON p.ID_Marca = m.id
        INNER JOIN Lote l ON p.id = l.Id_Producto
        INNER JOIN DetallesVentas dv ON l.id = dv.Id_Lote
        INNER JOIN Ventas v ON dv.Id_Venta = v.id
        WHERE v.Fecha >= DATEADD(DAY, -?, GETDATE())
        GROUP BY p.id, p.Codigo, p.Nombre, m.Nombre
        ORDER BY Total_Vendido DESC
        """
        return self._execute_query(query, (dias,))
    
    def get_valor_inventario(self) -> Dict[str, Any]:
        """Valor total del inventario"""
        query = """
        SELECT 
            SUM(stock_calculado.Stock_Real * p.Precio_compra) as Valor_Compra,
            SUM(stock_calculado.Stock_Real * p.Precio_venta) as Valor_Venta,
            COUNT(*) as Total_Productos,
            SUM(stock_calculado.Stock_Real) as Total_Unidades
        FROM Productos p
        INNER JOIN (
            SELECT l.Id_Producto, 
                SUM(l.Cantidad_Unitario) as Stock_Real
            FROM Lote l
            GROUP BY l.Id_Producto
            HAVING SUM(l.Cantidad_Unitario) > 0
        ) stock_calculado ON p.id = stock_calculado.Id_Producto
        """
        return self._execute_query(query, fetch_one=True) or {}
    
    @ExceptionHandler.handle_exception
    def crear_producto(self, datos_producto: dict) -> int:
        """Crea un producto sin lote inicial (para productos con stock 0)"""
        validate_required(datos_producto.get('Codigo'), "Codigo")
        validate_required(datos_producto.get('Nombre'), "Nombre")
        
        conn = None
        try:
            conn = self._get_connection()
            cursor = conn.cursor()
            
            # Insertar producto sin lote
            cursor.execute("""
                INSERT INTO Productos (Codigo, Nombre, Detalles, Precio_compra, Precio_venta, 
                                    Stock_Unitario, Unidad_Medida, ID_Marca)
                VALUES (?, ?, ?, ?, ?, 0, ?, ?)
            """, (
                datos_producto['Codigo'],
                datos_producto['Nombre'],
                datos_producto.get('Detalles', ''),
                datos_producto['Precio_compra'],
                datos_producto['Precio_venta'],
                datos_producto.get('Unidad_Medida', 'Tabletas'),
                datos_producto.get('ID_Marca', 1)
            ))
            
            # Obtener ID del producto insertado
            cursor.execute("SELECT @@IDENTITY as id")
            resultado = cursor.fetchone()
            if not resultado:
                raise Exception("No se pudo crear el producto")
            
            producto_id = resultado[0]
            conn.commit()
            self._invalidate_cache_after_modification()
            
            return producto_id
            
        except Exception as e:
            if conn:
                conn.rollback()
            raise Exception(f"Error creando producto: {str(e)}")
        finally:
            if conn:
                conn.close()

    def crear_marca(self, nombre_marca: str) -> int:
        """
        Crea una nueva marca en la base de datos - VERSIÓN MEJORADA
        """
        try:
            print(f"🏷️ Creando marca: '{nombre_marca}'")
            
            # Validar nombre
            if not nombre_marca or len(nombre_marca.strip()) < 2:
                print("❌ Nombre de marca inválido")
                return -1
            
            nombre_limpio = nombre_marca.strip()
            
            # Verificar si ya existe (case-insensitive)
            marca_existente = self._execute_query(
                "SELECT id FROM Marca WHERE LOWER(Nombre) = LOWER(?)", 
                (nombre_limpio,), 
                fetch_one=True,
                use_cache=False
            )
            
            if marca_existente:
                print(f"⚠️ Marca '{nombre_limpio}' ya existe con ID: {marca_existente['id']}")
                return 0  # Ya existe
            
            # Crear nueva marca
            conn = None
            try:
                conn = self._get_connection()
                cursor = conn.cursor()
                
                # SQL Server: Usar OUTPUT INSERTED.id
                query = """
                INSERT INTO Marca (Nombre, Detalles) 
                OUTPUT INSERTED.id
                VALUES (?, ?)
                """
                
                cursor.execute(query, (nombre_limpio, f"Marca creada automáticamente"))
                
                resultado = cursor.fetchone()
                if not resultado:
                    raise Exception("No se pudo obtener el ID de la marca creada")
                
                nueva_marca_id = resultado[0]
                conn.commit()
                
                # Invalidar caché de marcas
                self._invalidate_cache_after_modification()
                
                print(f"✅ Marca '{nombre_limpio}' creada con ID: {nueva_marca_id}")
                return nueva_marca_id
                
            except Exception as e:
                if conn:
                    conn.rollback()
                print(f"❌ Error en transacción crear marca: {e}")
                return -1
            finally:
                if conn:
                    conn.close()
                    
        except Exception as e:
            print(f"❌ Error creando marca: {e}")
            traceback.print_exc()
            return -1
    # ===============================
    # 🚀 SISTEMA FIFO 2.0 - MÉTODOS NUEVOS
    # Usan vistas y procedimientos almacenados de SQL Server
    # ===============================
    
    def obtener_stock_actual(self) -> List[Dict[str, Any]]:
        """
        🚀 FIFO 2.0: Obtiene stock REAL calculado desde lotes
        """
        try:
            query = """
            SELECT 
                p.id, 
                p.Codigo, 
                p.Nombre,
                m.Nombre as Marca,
                p.Unidad_Medida,
                -- ✅ CALCULAR STOCK DESDE LOTES (no usar Stock_Unitario)
                ISNULL((SELECT SUM(l.Cantidad_Unitario) 
                        FROM Lote l 
                        WHERE l.Id_Producto = p.id), 0) as Stock_Real,
                p.Stock_Minimo, 
                p.Stock_Maximo,
                p.Activo,
                -- Calcular Estado_Stock basado en stock real de lotes
                CASE 
                    WHEN ISNULL((SELECT SUM(l.Cantidad_Unitario) FROM Lote l WHERE l.Id_Producto = p.id), 0) <= 0 THEN 'CRÍTICO'
                    WHEN ISNULL((SELECT SUM(l.Cantidad_Unitario) FROM Lote l WHERE l.Id_Producto = p.id), 0) <= p.Stock_Minimo THEN 'CRÍTICO'
                    WHEN ISNULL((SELECT SUM(l.Cantidad_Unitario) FROM Lote l WHERE l.Id_Producto = p.id), 0) <= (p.Stock_Minimo + (p.Stock_Maximo - p.Stock_Minimo) * 0.3) THEN 'BAJO'
                    ELSE 'NORMAL'
                END as Estado_Stock,
                -- Información de vencimiento
                (SELECT MIN(l.Fecha_Vencimiento) 
                FROM Lote l 
                WHERE l.Id_Producto = p.id 
                AND l.Cantidad_Unitario > 0) as Proximo_Vencimiento
            FROM Productos p
            LEFT JOIN Marca m ON p.ID_Marca = m.id
            WHERE p.Activo = 1
            ORDER BY 
                CASE 
                    WHEN ISNULL((SELECT SUM(l.Cantidad_Unitario) FROM Lote l WHERE l.Id_Producto = p.id), 0) <= 0 THEN 1
                    WHEN ISNULL((SELECT SUM(l.Cantidad_Unitario) FROM Lote l WHERE l.Id_Producto = p.id), 0) <= p.Stock_Minimo THEN 1
                    ELSE 3
                END,
                p.Nombre
            """
            
            resultados = self._execute_query(query, use_cache=False)
            print(f"📊 Stock actual obtenido: {len(resultados)} productos - Sistema FIFO 2.0")
            
            return resultados
            
        except Exception as e:
            print(f"❌ Error obteniendo stock actual: {e}")
            import traceback
            traceback.print_exc()
            return []
    
    def obtener_alertas_inventario(self) -> List[Dict[str, Any]]:
        """
        🚀 FIFO 2.0: Obtiene todas las alertas activas usando vista vw_Alertas_Inventario
        ✅ COLUMNAS EXACTAS: Tipo_Alerta, id, Codigo, Nombre, Stock_Minimo, Stock_Real, Detalle
        ✅ INCLUYE: Productos activos + lotes vencidos + lotes bajo stock (sin filtro de cantidad)
        """
        try:
            query = """
            SELECT 
                Tipo_Alerta,
                Codigo,
                Nombre AS Producto,              -- ✅ Existe como "Nombre"
                Stock_Minimo,
                Stock_Real AS Stock_Actual,      -- ✅ Existe como "Stock_Real"
                Detalle,
                -- ✅ Campos que NO existen en la vista, se calculan:
                CASE 
                    WHEN Tipo_Alerta = 'STOCK BAJO' THEN 2
                    WHEN Tipo_Alerta = 'PRODUCTO PRÓXIMO A VENCER' THEN 2
                    WHEN Tipo_Alerta = 'PRODUCTO VENCIDO' THEN 3
                    ELSE 1
                END AS Prioridad
            FROM vw_Alertas_Inventario
            UNION ALL
            SELECT 
                'PRODUCTO VENCIDO' AS Tipo_Alerta,
                p.Codigo,
                p.Nombre AS Producto,
                p.Stock_Minimo,
                l.Cantidad_Unitario AS Stock_Actual,
                CONCAT('Lote vencido desde: ', FORMAT(l.Fecha_Vencimiento, 'yyyy-MM-dd')) AS Detalle,
                3 AS Prioridad
            FROM Lote l
            INNER JOIN Productos p ON l.Id_Producto = p.id
            WHERE l.Fecha_Vencimiento < GETDATE()
            AND l.Cantidad_Unitario > 0
            UNION ALL
            SELECT 
                'STOCK BAJO' AS Tipo_Alerta,
                p.Codigo,
                p.Nombre AS Producto,
                p.Stock_Minimo,
                l.Cantidad_Unitario AS Stock_Actual,
                CONCAT('Lote con stock bajo: ', l.Cantidad_Unitario, ' unidades') AS Detalle,
                2 AS Prioridad
            FROM Lote l
            INNER JOIN Productos p ON l.Id_Producto = p.id
            WHERE l.Cantidad_Unitario > 0 
            AND l.Cantidad_Unitario <= p.Stock_Minimo
            AND l.Fecha_Vencimiento >= GETDATE()
            ORDER BY 
                Prioridad DESC, 
                Tipo_Alerta
            """
            
            alertas = self._execute_query(query, use_cache=False)
            
            if alertas:
                print(f"⚠️  {len(alertas)} alertas de inventario detectadas")
                # Agrupar por tipo para logging
                tipos = {}
                for alerta in alertas:
                    tipo = alerta['Tipo_Alerta']
                    tipos[tipo] = tipos.get(tipo, 0) + 1
                
                for tipo, cantidad in tipos.items():
                    print(f"   - {tipo}: {cantidad}")
            else:
                print("✅ No hay alertas de inventario")
            
            return alertas
            
        except Exception as e:
            print(f"❌ Error obteniendo alertas: {e}")
            traceback.print_exc()
            return []
    
    def obtener_lotes_activos_vista(self, producto_id: int = None) -> List[Dict[str, Any]]:
        """
        🚀 FIFO 2.0: Obtiene detalle de lotes activos, vencidos y bajo stock usando vista vw_Lotes_Activos
        ✅ COLUMNAS EXACTAS: id, Id_Producto, Codigo, Producto, Marca, Cantidad_Inicial, 
                            Stock_Actual, Precio_Compra, Fecha_Compra, Fecha_Vencimiento,
                            Dias_para_Vencer, Estado_Vencimiento, Estado_Lote, etc.
        ✅ AHORA INCLUYE: Lotes activos + lotes vencidos + lotes bajo stock + lotes con stock 0
        """
        try:
            if producto_id:
                query = """
                SELECT 
                    id AS Id_Lote,                    
                    Id_Producto,
                    Codigo AS Producto_Codigo,        
                    Producto AS Producto_Nombre,      
                    Marca,                            
                    Cantidad_Inicial,
                    Stock_Actual AS Stock_Lote,       
                    Precio_Compra,
                    Fecha_Compra,
                    Fecha_Vencimiento,
                    Dias_para_Vencer,
                    Estado_Vencimiento,
                    Estado_Lote,
                    Id_Compra,
                    Proveedor
                FROM vw_Lotes_Activos
                WHERE Id_Producto = ?
                UNION ALL
                SELECT 
                    l.id AS Id_Lote,
                    l.Id_Producto,
                    p.Codigo AS Producto_Codigo,
                    p.Nombre AS Producto_Nombre,
                    m.Nombre AS Marca,
                    l.Cantidad_Unitario AS Cantidad_Inicial,
                    l.Cantidad_Unitario AS Stock_Lote,
                    l.Precio_Compra,
                    l.Fecha_Compra,
                    l.Fecha_Vencimiento,
                    DATEDIFF(DAY, GETDATE(), l.Fecha_Vencimiento) AS Dias_para_Vencer,
                    'VENCIDO' AS Estado_Vencimiento,
                    'VENCIDO' AS Estado_Lote,
                    NULL AS Id_Compra,
                    NULL AS Proveedor
                FROM Lote l
                INNER JOIN Productos p ON l.Id_Producto = p.id
                LEFT JOIN Marca m ON p.ID_Marca = m.id
                WHERE l.Id_Producto = ?
                AND l.Fecha_Vencimiento < GETDATE()
                UNION ALL
                SELECT 
                    l.id AS Id_Lote,
                    l.Id_Producto,
                    p.Codigo AS Producto_Codigo,
                    p.Nombre AS Producto_Nombre,
                    m.Nombre AS Marca,
                    l.Cantidad_Unitario AS Cantidad_Inicial,
                    l.Cantidad_Unitario AS Stock_Lote,
                    l.Precio_Compra,
                    l.Fecha_Compra,
                    l.Fecha_Vencimiento,
                    DATEDIFF(DAY, GETDATE(), l.Fecha_Vencimiento) AS Dias_para_Vencer,
                    'BAJO STOCK' AS Estado_Vencimiento,
                    'BAJO STOCK' AS Estado_Lote,
                    NULL AS Id_Compra,
                    NULL AS Proveedor
                FROM Lote l
                INNER JOIN Productos p ON l.Id_Producto = p.id
                LEFT JOIN Marca m ON p.ID_Marca = m.id
                WHERE l.Id_Producto = ?
                AND l.Cantidad_Unitario < p.Stock_Minimo
                AND l.Cantidad_Unitario > 0
                UNION ALL
                SELECT 
                    l.id AS Id_Lote,
                    l.Id_Producto,
                    p.Codigo AS Producto_Codigo,
                    p.Nombre AS Producto_Nombre,
                    m.Nombre AS Marca,
                    l.Cantidad_Unitario AS Cantidad_Inicial,
                    l.Cantidad_Unitario AS Stock_Lote,
                    l.Precio_Compra,
                    l.Fecha_Compra,
                    l.Fecha_Vencimiento,
                    DATEDIFF(DAY, GETDATE(), l.Fecha_Vencimiento) AS Dias_para_Vencer,
                    'AGOTADO' AS Estado_Vencimiento,
                    'AGOTADO' AS Estado_Lote,
                    NULL AS Id_Compra,
                    NULL AS Proveedor
                FROM Lote l
                INNER JOIN Productos p ON l.Id_Producto = p.id
                LEFT JOIN Marca m ON p.ID_Marca = m.id
                WHERE l.Id_Producto = ?
                AND l.Cantidad_Unitario = 0
                ORDER BY Dias_para_Vencer, Estado_Lote DESC
                """
                params = (producto_id, producto_id, producto_id, producto_id)
            else:
                query = """
                SELECT 
                    id AS Id_Lote,                    
                    Id_Producto,
                    Codigo AS Producto_Codigo,        
                    Producto AS Producto_Nombre,      
                    Marca,                            
                    Cantidad_Inicial,
                    Stock_Actual AS Stock_Lote,       
                    Precio_Compra,
                    Fecha_Compra,
                    Fecha_Vencimiento,
                    Dias_para_Vencer,
                    Estado_Vencimiento,
                    Estado_Lote,
                    Id_Compra,
                    Proveedor
                FROM vw_Lotes_Activos
                UNION ALL
                SELECT 
                    l.id AS Id_Lote,
                    l.Id_Producto,
                    p.Codigo AS Producto_Codigo,
                    p.Nombre AS Producto_Nombre,
                    m.Nombre AS Marca,
                    l.Cantidad_Unitario AS Cantidad_Inicial,
                    l.Cantidad_Unitario AS Stock_Lote,
                    l.Precio_Compra,
                    l.Fecha_Compra,
                    l.Fecha_Vencimiento,
                    DATEDIFF(DAY, GETDATE(), l.Fecha_Vencimiento) AS Dias_para_Vencer,
                    'VENCIDO' AS Estado_Vencimiento,
                    'VENCIDO' AS Estado_Lote,
                    NULL AS Id_Compra,
                    NULL AS Proveedor
                FROM Lote l
                INNER JOIN Productos p ON l.Id_Producto = p.id
                LEFT JOIN Marca m ON p.ID_Marca = m.id
                WHERE l.Fecha_Vencimiento < GETDATE()
                UNION ALL
                SELECT 
                    l.id AS Id_Lote,
                    l.Id_Producto,
                    p.Codigo AS Producto_Codigo,
                    p.Nombre AS Producto_Nombre,
                    m.Nombre AS Marca,
                    l.Cantidad_Unitario AS Cantidad_Inicial,
                    l.Cantidad_Unitario AS Stock_Lote,
                    l.Precio_Compra,
                    l.Fecha_Compra,
                    l.Fecha_Vencimiento,
                    DATEDIFF(DAY, GETDATE(), l.Fecha_Vencimiento) AS Dias_para_Vencer,
                    'BAJO STOCK' AS Estado_Vencimiento,
                    'BAJO STOCK' AS Estado_Lote,
                    NULL AS Id_Compra,
                    NULL AS Proveedor
                FROM Lote l
                INNER JOIN Productos p ON l.Id_Producto = p.id
                LEFT JOIN Marca m ON p.ID_Marca = m.id
                WHERE l.Cantidad_Unitario < p.Stock_Minimo
                AND l.Cantidad_Unitario > 0
                UNION ALL
                SELECT 
                    l.id AS Id_Lote,
                    l.Id_Producto,
                    p.Codigo AS Producto_Codigo,
                    p.Nombre AS Producto_Nombre,
                    m.Nombre AS Marca,
                    l.Cantidad_Unitario AS Cantidad_Inicial,
                    l.Cantidad_Unitario AS Stock_Lote,
                    l.Precio_Compra,
                    l.Fecha_Compra,
                    l.Fecha_Vencimiento,
                    DATEDIFF(DAY, GETDATE(), l.Fecha_Vencimiento) AS Dias_para_Vencer,
                    'AGOTADO' AS Estado_Vencimiento,
                    'AGOTADO' AS Estado_Lote,
                    NULL AS Id_Compra,
                    NULL AS Proveedor
                FROM Lote l
                INNER JOIN Productos p ON l.Id_Producto = p.id
                LEFT JOIN Marca m ON p.ID_Marca = m.id
                WHERE l.Cantidad_Unitario = 0
                ORDER BY Dias_para_Vencer, Estado_Lote DESC
                """
                params = ()
            
            lotes = self._execute_query(query, params, use_cache=False)
            
            # ✅ CONVERTIR FECHAS A STRING PARA QML
            for lote in lotes:
                # Convertir Fecha_Vencimiento
                if lote.get('Fecha_Vencimiento'):
                    try:
                        fecha = lote['Fecha_Vencimiento']
                        if hasattr(fecha, 'strftime'):
                            lote['Fecha_Vencimiento'] = fecha.strftime('%Y-%m-%d')
                        else:
                            lote['Fecha_Vencimiento'] = str(fecha)
                    except:
                        lote['Fecha_Vencimiento'] = ""
                else:
                    lote['Fecha_Vencimiento'] = ""
                
                # Convertir Fecha_Compra
                if lote.get('Fecha_Compra'):
                    try:
                        fecha = lote['Fecha_Compra']
                        if hasattr(fecha, 'strftime'):
                            lote['Fecha_Compra'] = fecha.strftime('%Y-%m-%d')
                        else:
                            lote['Fecha_Compra'] = str(fecha)
                    except:
                        lote['Fecha_Compra'] = ""
                else:
                    lote['Fecha_Compra'] = ""
            
            print(f"📦 Lotes obtenidos: {len(lotes)} lotes (activos + vencidos + bajo stock + agotados) - Sistema FIFO 2.0")
            return lotes
            
        except Exception as e:
            print(f"❌ Error obteniendo lotes (vista): {e}")
            # Fallback a método antiguo si está configurado
            try:
                from ..core.config_fifo import config_fifo
                if config_fifo.AUTO_FALLBACK_TO_LEGACY and producto_id:
                    print("🔙 Usando método legacy como fallback...")
                    return self.get_lotes_producto(producto_id, solo_activos=False)
            except:
                pass
            return []
    def obtener_costo_inventario(self) -> List[Dict[str, Any]]:
        """
        🚀 FIFO 2.0: Obtiene valorización del inventario usando vista vw_Costo_Inventario
        ✅ COLUMNAS EXACTAS: id, Codigo, Nombre, Unidad_Medida, Lotes_Activos, Stock_Total,
                            Costo_Promedio_Real, Valor_Inventario_Costo, Valor_Inventario_Venta,
                            Ganancia_Potencial
        """
        try:
            query = """
            SELECT 
                id AS Id_Producto,                          -- ✅ Existe como "id"
                Codigo,                                     -- ✅ Existe
                Nombre AS Producto,                         -- ✅ Existe como "Nombre"
                Unidad_Medida,                              -- ✅ Existe
                Stock_Total,                                -- ✅ Existe
                Costo_Promedio_Real AS Costo_Promedio,      -- ✅ Existe
                Valor_Inventario_Costo,                     -- ✅ Existe
                Valor_Inventario_Venta,                     -- ✅ Existe
                Ganancia_Potencial AS Margen_Potencial,     -- ✅ Existe
                -- ✅ Porcentaje_Margen NO existe, se calcula:
                CASE 
                    WHEN Valor_Inventario_Costo > 0 
                    THEN (Ganancia_Potencial / Valor_Inventario_Costo * 100)
                    ELSE 0
                END AS Porcentaje_Margen
            FROM vw_Costo_Inventario
            ORDER BY Valor_Inventario_Costo DESC
            """
            
            valoracion = self._execute_query(query, use_cache=False)
            
            if valoracion:
                total_costo = sum(item['Valor_Inventario_Costo'] or 0 for item in valoracion)
                total_venta = sum(item['Valor_Inventario_Venta'] or 0 for item in valoracion)
                print(f"💰 Valorización de inventario:")
                print(f"   - Valor en costo: ${total_costo:,.2f}")
                print(f"   - Valor en venta: ${total_venta:,.2f}")
                print(f"   - Margen potencial: ${total_venta - total_costo:,.2f}")
            
            return valoracion
            
        except Exception as e:
            print(f"❌ Error obteniendo valorización inventario: {e}")
            import traceback
            traceback.print_exc()
            return []
    
    def obtener_rotacion_inventario(self, dias: int = 30) -> List[Dict[str, Any]]:
        """
        🚀 FIFO 2.0: Obtiene análisis de rotación de inventario usando vista vw_Rotacion_Inventario
        ✅ COLUMNAS EXACTAS: id, Codigo, Nombre, Unidad_Medida, Unidades_Vendidas_30_Dias,
                            Stock_Promedio, Indice_Rotacion, Dias_Inventario
        """
        try:
            query = """
            SELECT 
                id AS Id_Producto,                                  -- ✅ Existe como "id"
                Codigo,                                             -- ✅ Existe
                Nombre AS Producto,                                 -- ✅ Existe como "Nombre"
                Unidad_Medida,                                      -- ✅ Existe
                Stock_Promedio AS Stock_Actual,                     -- ✅ Existe
                Unidades_Vendidas_30_Dias AS Ventas_Periodo,        -- ✅ Existe
                0 AS Compras_Periodo,                               -- ✅ NO EXISTE, poner 0
                Dias_Inventario AS Dias_Stock,                      -- ✅ Existe
                Indice_Rotacion,                                    -- ✅ Existe
                -- ✅ Clasificacion NO existe, se calcula:
                CASE 
                    WHEN Indice_Rotacion >= 12 THEN 'A'
                    WHEN Indice_Rotacion >= 6 THEN 'B'
                    ELSE 'C'
                END AS Clasificacion
            FROM vw_Rotacion_Inventario
            ORDER BY Indice_Rotacion DESC
            """
            
            rotacion = self._execute_query(query, use_cache=False)
            
            if rotacion:
                print(f"📈 Análisis de rotación (últimos {dias} días):")
                clasificaciones = {}
                for item in rotacion:
                    clasif = item['Clasificacion']
                    clasificaciones[clasif] = clasificaciones.get(clasif, 0) + 1
                
                for clasif, count in clasificaciones.items():
                    print(f"   - {clasif}: {count} productos")
            
            return rotacion
            
        except Exception as e:
            print(f"❌ Error obteniendo rotación de inventario: {e}")
            import traceback
            traceback.print_exc()
            return []