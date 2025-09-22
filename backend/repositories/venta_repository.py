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
        print("🛠 DEBUG: get_active() llamado para ventas del día")
        query = """
        SELECT v.*, u.Nombre + ' ' + u.Apellido_Paterno as Vendedor
        FROM Ventas v
        INNER JOIN Usuario u ON v.Id_Usuario = u.id
        WHERE CAST(v.Fecha AS DATE) = CAST(GETDATE() AS DATE)
        ORDER BY v.Fecha DESC
        """
        # ✅ CORREGIDO: Usar use_cache=False para obtener datos frescos
        resultado = self._execute_query(query, use_cache=False)
        print(f"🛠 DEBUG: get_active() encontró {len(resultado) if resultado else 0} ventas del día")
        
        if resultado:
            print(f"🛠 DEBUG: Primera venta: {resultado[0]}")
        
        return resultado
    
    # ✅ NUEVO: Método para buscar productos directamente de tabla Productos
    def buscar_productos_para_venta(self, termino: str) -> List[Dict[str, Any]]:
        """
        ✅ CORREGIDO: Busca productos SIEMPRE sin cache
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
            -- STOCK TOTAL CALCULADO EN TIEMPO REAL
            ISNULL((SELECT SUM(l.Cantidad_Unitario) 
                    FROM Lote l 
                    WHERE l.Id_Producto = p.id), 0) as Stock_Total,
            -- Estado en tiempo real
            CASE 
                WHEN (SELECT SUM(l.Cantidad_Unitario) FROM Lote l WHERE l.Id_Producto = p.id) > 0 
                THEN 'DISPONIBLE'
                ELSE 'AGOTADO'
            END as Estado,
            -- Timestamp para debug
            GETDATE() as Consulta_Timestamp
        FROM Productos p
        INNER JOIN Marca m ON p.ID_Marca = m.id
        WHERE (p.Nombre LIKE ? OR p.Codigo LIKE ?)
        ORDER BY p.Nombre
        """
        
        termino_like = f"%{termino}%"
        # ✅ FORZAR use_cache=False SIEMPRE
        resultado = self._execute_query(query, (termino_like, termino_like), use_cache=False) or []
        
        print(f"🔍 Búsqueda de productos SIN CACHE: {len(resultado)} resultados para '{termino}'")
        return resultado
    
    def buscar_productos_para_venta_sin_cache(self, termino: str) -> List[Dict[str, Any]]:
        """
        ✅ NUEVO: Búsqueda garantizada SIN cache para después de ventas
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
            p.Stock_Unitario,
            m.Nombre as Marca_Nombre,
            -- RECALCULAR STOCK DESDE LOTES EN TIEMPO REAL
            ISNULL((SELECT SUM(l.Cantidad_Unitario) 
                    FROM Lote l 
                    WHERE l.Id_Producto = p.id), 0) as Stock_Total,
            -- Información adicional para debug
            (SELECT COUNT(*) FROM Lote l WHERE l.Id_Producto = p.id AND l.Cantidad_Unitario > 0) as Lotes_Activos,
            GETDATE() as Timestamp_Consulta
        FROM Productos p
        INNER JOIN Marca m ON p.ID_Marca = m.id
        WHERE (p.Nombre LIKE ? OR p.Codigo LIKE ?)
        ORDER BY p.Nombre
        """
        
        termino_like = f"%{termino}%"
        
        # ✅ FORZAR conexión directa sin ningún tipo de cache
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

    # ✅ NUEVO: Método para obtener producto por código desde tabla Productos
    def get_producto_por_codigo_completo(self, codigo: str) -> Dict[str, Any]:
        """
        MEJORADO: Obtiene producto con información completa para edición
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
            p.Stock_Unitario,
            p.Unidad_Medida,
            p.ID_Marca,
            m.Nombre as Marca_Nombre,
            ISNULL(p.Stock_Unitario, 0) as Stock_Actual
        FROM Productos p
        LEFT JOIN Marca m ON p.ID_Marca = m.id
        WHERE p.Codigo = ?
        """
        
        resultado = self._execute_query(query, (codigo.strip(),), fetch_one=True, use_cache=False)
        
        if resultado:
            print(f"🔍 Producto encontrado para edición: {resultado['Codigo']} - Stock: {resultado['Stock_Actual']}")
        
        return resultado
    
    def get_producto_por_codigo(self, codigo: str) -> Optional[Dict[str, Any]]:
        """
        ✅ CORREGIDO: SIEMPRE sin cache para datos frescos
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
            p.Stock_Unitario,
            p.ID_Marca,
            m.Nombre as Marca_Nombre,
            m.Detalles as Marca_Detalles,
            -- ✅ STOCK REAL CALCULADO EN TIEMPO REAL DESDE LOTES
            ISNULL((SELECT SUM(l.Cantidad_Unitario) 
                    FROM Lote l 
                    WHERE l.Id_Producto = p.id), 0) as Stock_Total,
            -- Para compatibilidad, pero usar Stock_Total como real
            ISNULL((SELECT SUM(l.Cantidad_Unitario) 
                    FROM Lote l 
                    WHERE l.Id_Producto = p.id), 0) as Stock_Unitario_Calculado,
            -- Información FIFO
            (SELECT TOP 1 l.id 
            FROM Lote l 
            WHERE l.Id_Producto = p.id 
            AND l.Cantidad_Unitario > 0 
            ORDER BY l.Fecha_Vencimiento ASC, l.id ASC) as Lote_FIFO_ID,
            (SELECT TOP 1 l.Cantidad_Unitario 
            FROM Lote l 
            WHERE l.Id_Producto = p.id 
            AND l.Cantidad_Unitario > 0 
            ORDER BY l.Fecha_Vencimiento ASC, l.id ASC) as Lote_FIFO_Stock,
            (SELECT COUNT(*) FROM Lote l WHERE l.Id_Producto = p.id AND l.Cantidad_Unitario > 0) as Lotes_Activos,
            GETDATE() as Timestamp_Consulta
        FROM Productos p
        INNER JOIN Marca m ON p.ID_Marca = m.id
        WHERE p.Codigo = ?
        """
        
        # ✅ SIEMPRE sin cache
        resultado = self._execute_query(query, (codigo,), fetch_one=True, use_cache=False)
        
        if resultado:
            # Usar el stock calculado como el real
            resultado['Stock_Unitario'] = resultado['Stock_Total']
            print(f"📦 Producto {codigo}: Stock FRESCO desde lotes = {resultado['Stock_Total']}")
        else:
            print(f"❌ Producto {codigo} no encontrado")
        
        return resultado
    def get_producto_por_codigo_sin_cache(self, codigo: str) -> Optional[Dict[str, Any]]:
        """
        ✅ NUEVO: Garantiza consulta directa sin ningún cache
        """
        validate_required(codigo, "codigo")
        
        print(f"🚫 CONSULTA FORZADA SIN CACHE para producto: '{codigo}'")
        
        query = """
        SELECT 
            p.id,
            p.Codigo,
            p.Nombre,
            p.Precio_venta,
            p.Stock_Unitario as Stock_Original,
            m.Nombre as Marca_Nombre,
            -- RECALCULAR STOCK COMPLETO DESDE LOTES
            ISNULL((SELECT SUM(l.Cantidad_Unitario) 
                    FROM Lote l 
                    WHERE l.Id_Producto = p.id), 0) as Stock_Total,
            -- Información de lotes para debug
            (SELECT COUNT(*) FROM Lote l WHERE l.Id_Producto = p.id AND l.Cantidad_Unitario > 0) as Lotes_Activos,
            (SELECT COUNT(*) FROM Lote l WHERE l.Id_Producto = p.id) as Total_Lotes,
            GETDATE() as Timestamp_Consulta
        FROM Productos p
        INNER JOIN Marca m ON p.ID_Marca = m.id
        WHERE p.Codigo = ?
        """
        
        # ✅ CONEXIÓN DIRECTA BYPASS COMPLETE
        conn = None
        try:
            conn = self._get_connection()
            cursor = conn.cursor()
            cursor.execute(query, (codigo,))
            
            row = cursor.fetchone()
            if row:
                columns = [desc[0] for desc in cursor.description]
                resultado = dict(zip(columns, row))
                
                # Usar stock calculado como el real
                resultado['Stock_Unitario'] = resultado['Stock_Total']
                
                print(f"✅ Consulta directa producto {codigo}: Stock_Total={resultado['Stock_Total']}, Lotes_Activos={resultado['Lotes_Activos']}")
                return resultado
            else:
                print(f"❌ Producto {codigo} no encontrado en consulta directa")
                return None
                
        except Exception as e:
            print(f"❌ Error en consulta directa: {e}")
            return None
        finally:
            if conn:
                conn.close()
        
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
        return self._execute_query(query, tuple(params), use_cache=False)
    
    def get_venta_completa(self, venta_id: int) -> Dict[str, Any]:
        """Obtiene venta con detalles CONSOLIDADOS por producto"""
        
        print(f"🛠 DEBUG: get_venta_completa llamado con venta_id: {venta_id} (tipo: {type(venta_id)})")

        validate_required(venta_id, "venta_id")
        
        # Obtener datos principales de la venta
        venta_query = """
            SELECT v.*, u.Nombre + ' ' + u.Apellido_Paterno as Vendedor,
            u.nombre_usuario as Vendedor_Email
            FROM Ventas v
            INNER JOIN Usuario u ON v.Id_Usuario = u.id
            WHERE v.id = ?
        """
        print(f"🛠 DEBUG: Ejecutando query con parámetro: {venta_id}")
        venta = self._execute_query(venta_query, (venta_id,), fetch_one=True, use_cache=False)
        print(f"🛠 DEBUG: Resultado de query venta: {venta} (tipo: {type(venta)})")
        
        if not venta:
            print(f"❌ DEBUG: Venta no encontrada para ID: {venta_id}")
            raise VentaError(f"Venta no encontrada: {venta_id}", venta_id)
        
        # ✅ CONSULTA CONSOLIDADA: Agrupa productos iguales
        detalles_query = """
        SELECT 
            p.Codigo as Producto_Codigo,
            p.Nombre as Producto_Nombre,
            m.Nombre as Marca_Nombre,
            -- Consolidar cantidades y precios por producto
            SUM(dv.Cantidad_Unitario) as Cantidad_Unitario,
            -- Usar el precio unitario (debería ser igual para el mismo producto)
            MAX(dv.Precio_Unitario) as Precio_Unitario,
            -- Calcular subtotal consolidado
            SUM(dv.Cantidad_Unitario * dv.Precio_Unitario) as Subtotal,
            -- Para compatibilidad, mantener algunos campos adicionales
            MIN(l.Fecha_Vencimiento) as Fecha_Vencimiento
        FROM DetallesVentas dv
        INNER JOIN Lote l ON dv.Id_Lote = l.id
        INNER JOIN Productos p ON l.Id_Producto = p.id
        INNER JOIN Marca m ON p.ID_Marca = m.id
        WHERE dv.Id_Venta = ?
        GROUP BY p.id, p.Codigo, p.Nombre, m.Nombre
        ORDER BY p.Nombre ASC
        """
        
        print(f"🛠 DEBUG: Ejecutando consulta consolidada para venta {venta_id}")
        detalles = self._execute_query(detalles_query, (venta_id,), use_cache=False)
        print(f"🛠 DEBUG: Detalles consolidados obtenidos: {len(detalles) if detalles else 0}")
        
        if detalles:
            for i, detalle in enumerate(detalles):
                print(f"   Producto {i+1}: {detalle['Producto_Codigo']} - {detalle['Cantidad_Unitario']} unidades")
        
        venta['detalles'] = detalles
        venta['total_items'] = len(detalles)
        venta['total_unidades'] = sum(detalle['Cantidad_Unitario'] for detalle in detalles)
        
        print(f"✅ Venta completa consolidada: {len(detalles)} productos únicos")
        return venta
    
    def get_venta_completa_consolidada(self, venta_id: int) -> Dict[str, Any]:
        """Obtiene venta con detalles CONSOLIDADOS por producto (solo para UI)"""
        
        validate_required(venta_id, "venta_id")
        
        # Obtener datos principales de la venta
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
        
        # CORREGIDO: Consulta CONSOLIDADA con subtotal calculado correctamente
        detalles_query = """
        SELECT 
            p.Codigo as Producto_Codigo,
            p.Nombre as Producto_Nombre,
            ISNULL(m.Nombre, 'Sin marca') as Marca_Nombre,
            -- Consolidar cantidades por producto
            SUM(dv.Cantidad_Unitario) as Cantidad_Unitario,
            -- Usar el precio unitario más reciente (debería ser igual para el mismo producto)
            MAX(dv.Precio_Unitario) as Precio_Unitario,
            -- CORREGIDO: Calcular subtotal consolidado correctamente
            SUM(dv.Cantidad_Unitario * dv.Precio_Unitario) as Subtotal,
            -- Para compatibilidad, mantener algunos campos adicionales
            MIN(l.Fecha_Vencimiento) as Fecha_Vencimiento,
            -- Para debug: mostrar cálculo individual
            COUNT(dv.id) as Numero_Registros
        FROM DetallesVentas dv
        INNER JOIN Lote l ON dv.Id_Lote = l.id
        INNER JOIN Productos p ON l.Id_Producto = p.id
        LEFT JOIN Marca m ON p.ID_Marca = m.id
        WHERE dv.Id_Venta = ?
        GROUP BY p.id, p.Codigo, p.Nombre, m.Nombre
        ORDER BY p.Nombre ASC
        """
        
        print(f"🛠 DEBUG: Ejecutando consulta consolidada para venta {venta_id}")
        detalles = self._execute_query(detalles_query, (venta_id,), use_cache=False)
        
        if detalles:
            print(f"🛠 DEBUG: Detalles consolidados obtenidos: {len(detalles)}")
            
            # CORREGIDO: Verificar y corregir subtotales
            total_verificacion = 0
            for i, detalle in enumerate(detalles):
                cantidad = float(detalle.get('Cantidad_Unitario', 0))
                precio = float(detalle.get('Precio_Unitario', 0))
                subtotal_bd = float(detalle.get('Subtotal', 0))
                subtotal_calculado = cantidad * precio
                
                # Verificar discrepancias
                if abs(subtotal_bd - subtotal_calculado) > 0.01:
                    print(f"⚠️ Discrepancia en {detalle['Producto_Codigo']}: BD={subtotal_bd}, Calc={subtotal_calculado}")
                    # Usar el calculado como más confiable
                    detalle['Subtotal'] = subtotal_calculado
                
                total_verificacion += float(detalle['Subtotal'])
                
                print(f"   Producto {i+1}: {detalle['Producto_Codigo']} - "
                    f"Cant: {cantidad}, Precio: {precio}, Subtotal: {detalle['Subtotal']}")
            
            # Verificar total general
            total_venta = float(venta['Total'])
            if abs(total_verificacion - total_venta) > 0.01:
                print(f"⚠️ Total venta BD: {total_venta}, Total calculado: {total_verificacion}")
        else:
            print(f"⚠️ No se encontraron detalles para venta {venta_id}")
            detalles = []
        
        venta['detalles'] = detalles
        venta['total_items'] = len(detalles)
        venta['total_unidades'] = sum(float(detalle.get('Cantidad_Unitario', 0)) for detalle in detalles)
        
        print(f"✅ Venta completa consolidada: {len(detalles)} productos únicos")
        return venta

    def get_venta_completa(self, venta_id: int) -> Dict[str, Any]:
        """Obtiene venta con detalles ORIGINALES (para operaciones que requieren Id_Lote)"""
        
        validate_required(venta_id, "venta_id")
        
        # Obtener datos principales de la venta
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
        
        # Consulta ORIGINAL con Id_Lote para operaciones
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
    
    @ExceptionHandler.handle_exception
    def crear_venta(self, usuario_id: int, items: List[Dict[str, Any]]) -> Optional[Dict[str, Any]]:
        """
        ✅ CORREGIDO: Crea venta usando sistema FIFO de lotes
        Reduce stock de lotes automáticamente y actualiza Stock_Unitario en Productos
        """
        validate_required(usuario_id, "usuario_id")
        validate_required(items, "items")
        
        if not items:
            raise VentaError("No hay items para vender")
        
        conn = None
        venta_id = None
        lotes_afectados = []  # Para rollback en caso de error
        
        try:
            conn = self._get_connection()
            cursor = conn.cursor()
            
            # PASO 1: Validar y preparar items
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
                
                # Obtener producto desde tabla Productos
                producto = self.get_producto_por_codigo(codigo)
                if not producto:
                    raise ProductoNotFoundError(codigo=codigo)
                
                # PASO 2: Verificar disponibilidad FIFO ANTES de procesar
                from ..repositories.producto_repository import ProductoRepository
                producto_repo = ProductoRepository()
                
                disponibilidad = producto_repo.verificar_disponibilidad_fifo(
                    producto['id'], cantidad
                )
                
                if not disponibilidad['disponible']:
                    raise StockInsuficienteError(
                        codigo, 
                        disponibilidad['cantidad_total_disponible'], 
                        cantidad
                    )
                
                # Calcular subtotal
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
            
            print(f"🔍 Items validados: {len(items_validados)}, Total: ${total_venta:.2f}")
            
            # PASO 3: Crear venta en tabla Ventas
            cursor.execute("""
                INSERT INTO Ventas (Id_Usuario, Fecha, Total)
                OUTPUT INSERTED.id
                VALUES (?, GETDATE(), ?)
            """, (usuario_id, total_venta))
            
            resultado = cursor.fetchone()
            if not resultado:
                raise VentaError("Error creando venta en base de datos")
            
            venta_id = resultado[0]
            print(f"✅ Venta creada - ID: {venta_id}")
            
            # PASO 4: Procesar cada item usando FIFO
            for item in items_validados:
                producto_id = item['producto_id']
                cantidad_total = item['cantidad']
                precio_unitario = item['precio']
                
                # USAR SISTEMA FIFO PARA REDUCIR STOCK DE LOTES
                try:
                    lotes_utilizados = producto_repo.reducir_stock_fifo(
                        producto_id, cantidad_total
                    )
                    lotes_afectados.extend(lotes_utilizados)
                    
                    print(f"📦 FIFO aplicado para {item['codigo']}: {len(lotes_utilizados)} lotes afectados")
                    
                except Exception as fifo_error:
                    print(f"❌ Error en FIFO para {item['codigo']}: {fifo_error}")
                    raise StockInsuficienteError(
                        item['codigo'], 
                        0,  # No sabemos stock exacto después del error
                        cantidad_total
                    )
                
                # PASO 5: Crear registros en DetallesVentas
                # Un registro por cada lote utilizado
                for lote_usado in lotes_utilizados:
                    cursor.execute("""
                        INSERT INTO DetallesVentas 
                        (Id_Venta, Id_Lote, Cantidad_Unitario, Precio_Unitario)
                        VALUES (?, ?, ?, ?)
                    """, (
                        venta_id,
                        lote_usado['lote_id'],
                        lote_usado['cantidad_reducida'],
                        precio_unitario
                    ))
            
            # PASO 6: Commit de toda la transacción
            conn.commit()
            
            # PASO 7: Limpiar cache después de éxito
            self._invalidate_cache_after_modification()
            if hasattr(producto_repo, '_invalidate_cache_after_modification'):
                producto_repo._invalidate_cache_after_modification()
            
            # PASO 8: Retornar información de la venta creada
            venta_completa = {
                'id': venta_id,
                'Id_Usuario': usuario_id,
                'Fecha': datetime.now(),
                'Total': total_venta,
                'items_procesados': len(items_validados),
                'lotes_afectados': len(lotes_afectados)
            }
            
            print(f"🎉 Venta {venta_id} completada exitosamente - FIFO aplicado correctamente")
            return venta_completa
            
        except Exception as e:
            print(f"❌ Error en crear_venta: {e}")
            
            # ROLLBACK en caso de error
            if conn:
                conn.rollback()
                print("🔄 Rollback ejecutado")
            
            # Intentar restaurar lotes afectados (opcional)
            if lotes_afectados:
                try:
                    self._intentar_rollback_lotes(lotes_afectados)
                except:
                    print("⚠️ No se pudo restaurar lotes automáticamente")
            
            # Re-lanzar excepción apropiada
            if isinstance(e, (VentaError, ProductoNotFoundError, StockInsuficienteError)):
                raise e
            else:
                raise VentaError(f"Error procesando venta: {str(e)}")
            
        finally:
            if conn:
                conn.close()
    def _intentar_rollback_lotes(self, lotes_afectados: List[Dict[str, Any]]):
        """
        ✅ NUEVO: Intenta restaurar lotes en caso de rollback
        """
        try:
            conn = self._get_connection()
            cursor = conn.cursor()
            
            for lote in lotes_afectados:
                # Restaurar cantidad original
                cantidad_restaurar = lote['cantidad_reducida']
                cantidad_final_original = lote['cantidad_final']
                cantidad_original = cantidad_final_original + cantidad_restaurar
                
                cursor.execute("""
                    UPDATE Lote 
                    SET Cantidad_Unitario = ?
                    WHERE id = ?
                """, (cantidad_original, lote['lote_id']))
            
            conn.commit()
            print(f"🔄 Rollback de lotes completado: {len(lotes_afectados)} lotes restaurados")
            
        except Exception as rollback_error:
            print(f"❌ Error en rollback de lotes: {rollback_error}")
        finally:
            if conn:
                conn.close()
    
    def _validar_y_preparar_item_desde_productos(self, item: Dict[str, Any]) -> Dict[str, Any]:
        """
        ✅ NUEVO: Valida y prepara un item usando datos directos de tabla Productos
        """
        print(f"🔍 DEBUG: _validar_y_preparar_item_desde_productos recibió: {item} (tipo: {type(item)})")
        
        try:
            # Validaciones básicas
            codigo = item.get('codigo', '').strip()
            cantidad = item.get('cantidad', 0)
            precio = item.get('precio')
            
            print(f"🔍 DEBUG: Valores extraídos - codigo: {codigo}, cantidad: {cantidad}, precio: {precio}")
            
            validate_required(codigo, "codigo")
            validate_positive_number(cantidad, "cantidad")
            
            # ✅ OBTENER PRODUCTO DIRECTAMENTE DE TABLA PRODUCTOS
            producto = self.get_producto_por_codigo(codigo)
            if not producto:
                raise ProductoNotFoundError(codigo=codigo)
            
            print(f"🔍 DEBUG: Producto encontrado: {producto['id']} - {producto['Nombre']}")
            
            # ✅ VERIFICAR STOCK DIRECTAMENTE DE PRODUCTO
            stock_disponible = producto['Stock_Unitario'] or 0
            if stock_disponible < cantidad:
                raise StockInsuficienteError(
                    f"Producto {codigo}", 
                    stock_disponible, 
                    cantidad
                )
            
            print(f"🔍 DEBUG: Stock disponible: {stock_disponible}, solicitado: {cantidad}")
            
            # Usar precio del producto si no se especifica
            if precio is None:
                precio = float(producto['Precio_venta'])
            else:
                validate_positive_number(precio, "precio")
            
            subtotal = Decimal(str(cantidad)) * Decimal(str(precio))
            
            item_preparado = {
                'codigo': codigo,
                'producto_id': producto['id'],
                'producto_nombre': producto['Nombre'],
                'cantidad': cantidad,
                'precio': precio,
                'subtotal': subtotal,
                'stock_disponible': stock_disponible
            }
            
            print(f"🔍 DEBUG: Item preparado exitosamente: {item_preparado}")
            return item_preparado
            
        except Exception as e:
            print(f"❌ ERROR en _validar_y_preparar_item_desde_productos: {e}")
            raise e
    
    def _crear_venta_con_transaccion(self, usuario_id: int, items_preparados: List[Dict], total_venta: Decimal) -> Dict[str, Any]:
        """
        ✅ MODIFICADO: Crea venta actualizando stock directamente en tabla Productos
        """
        conn = None
        venta_id = None
        
        try:
            # Obtener conexión única para toda la transacción
            conn = self._get_connection()
            cursor = conn.cursor()
            
            print("📄 Iniciando transacción completa de venta...")
            
            # ✅ Invalidar caché ANTES de procesar venta
            self._invalidate_cache_before_transaction()
            
            # PASO 1: Insertar venta principal
            venta_query = """
            INSERT INTO Ventas (Id_Usuario, Fecha, Total) 
            OUTPUT INSERTED.id 
            VALUES (?, ?, ?)
            """
            
            cursor.execute(venta_query, (usuario_id, datetime.now(), float(total_venta)))
            venta_result = cursor.fetchone()
            
            if not venta_result:
                raise VentaError("Error creando venta principal")
            
            venta_id = venta_result[0]
            print(f"💰 Venta creada en transacción - ID: {venta_id}, Total: ${total_venta}")
            
            # PASO 2: Procesar todos los items
            todos_los_detalles = []
            
            for i, item in enumerate(items_preparados):
                print(f"📄 Procesando item {i} en transacción...")
                
                # ✅ REDUCIR STOCK DIRECTAMENTE EN TABLA PRODUCTOS
                update_stock_query = """
                UPDATE Productos 
                SET Stock_Unitario = Stock_Unitario - ?
                WHERE id = ? AND Stock_Unitario >= ?
                """
                
                cursor.execute(update_stock_query, (
                    item['cantidad'],
                    item['producto_id'],
                    item['cantidad']
                ))
                
                if cursor.rowcount == 0:
                    raise StockInsuficienteError(
                        item['codigo'], 
                        item['stock_disponible'], 
                        item['cantidad']
                    )
                
                print(f"📦 Stock actualizado para producto {item['codigo']}")
                
                # CREAR DETALLE DE VENTA (usando lote ficticio o predeterminado)
                lote_query = """
                SELECT TOP 1 id, Cantidad_Unitario FROM Lote 
                WHERE Id_Producto = ? AND Cantidad_Unitario > 0
                ORDER BY Fecha_Vencimiento ASC
                """
                cursor.execute(lote_query, (item['producto_id'],))
                lote_result = cursor.fetchone()

                if lote_result:
                    lote_id, cantidad_lote = lote_result[0], lote_result[1]
                    
                    # NUEVA LÓGICA: Usar múltiples lotes si es necesario
                    cantidad_restante = item['cantidad']
                    
                    # Obtener todos los lotes disponibles para este producto
                    lotes_query = """
                    SELECT id, Cantidad_Unitario FROM Lote 
                    WHERE Id_Producto = ? AND Cantidad_Unitario > 0
                    ORDER BY Fecha_Vencimiento ASC
                    """
                    cursor.execute(lotes_query, (item['producto_id'],))
                    lotes_disponibles = cursor.fetchall()
                    
                    lotes_a_usar = []
                    
                    for lote_id, cantidad_lote in lotes_disponibles:
                        if cantidad_restante <= 0:
                            break
                            
                        cantidad_a_usar = min(cantidad_restante, cantidad_lote)
                        lotes_a_usar.append((lote_id, cantidad_a_usar))
                        cantidad_restante -= cantidad_a_usar
                    
                    # Si no hay suficientes lotes, crear lote temporal
                    if cantidad_restante > 0:
                        insert_lote_query = """
                        INSERT INTO Lote (Id_Producto, Cantidad_Unitario, Fecha_Vencimiento)
                        OUTPUT INSERTED.id
                        VALUES (?, ?, GETDATE())
                        """
                        cursor.execute(insert_lote_query, (item['producto_id'], cantidad_restante))
                        lote_temporal = cursor.fetchone()
                        if lote_temporal:
                            lotes_a_usar.append((lote_temporal[0], cantidad_restante))
                    
                    # Actualizar cada lote usado y crear detalles
                    for lote_id, cantidad_usada in lotes_a_usar:
                        # Actualizar lote (solo si no es temporal)
                        if cantidad_usada <= cantidad_lote:  # Validar antes de actualizar
                            update_lote_query = """
                            UPDATE Lote 
                            SET Cantidad_Unitario = Cantidad_Unitario - ?
                            WHERE id = ? AND Cantidad_Unitario >= ?
                            """
                            cursor.execute(update_lote_query, (cantidad_usada, lote_id, cantidad_usada))
                        
                        # Crear detalle de venta
                        detalle_query = """
                        INSERT INTO DetallesVentas (Id_Venta, Id_Lote, Cantidad_Unitario, Precio_Unitario, Detalles)
                        OUTPUT INSERTED.id
                        VALUES (?, ?, ?, ?, ?)
                        """
                        
                        detalle_data = f"Venta - {item['producto_nombre']} (Lote: {lote_id})"
                        
                        cursor.execute(detalle_query, (
                            venta_id,
                            lote_id,
                            cantidad_usada,
                            item['precio'],
                            detalle_data
                        ))
            
            # PASO 3: Commit de toda la transacción
            conn.commit()
            print(f"✅ Transacción completada - Venta: {venta_id}, Detalles: {len(todos_los_detalles)}")
            
            # ✅ Invalidar caché DESPUÉS de commit exitoso
            self._invalidate_cache_after_modification()
            
            # PASO 4: Retornar venta completa SIN CACHÉ
            return self.get_venta_completa(venta_id)
            
        except Exception as e:
            print(f"❌ ERROR en transacción de venta: {e}")
            if conn:
                conn.rollback()
                print("📄 Rollback realizado")
            
            # Si se creó la venta pero falló después, intentar limpiar
            if venta_id:
                try:
                    self._limpiar_venta_fallida(venta_id)
                except:
                    pass
            
            raise VentaError(f"Error creando venta: {str(e)}")
        
        finally:
            if conn:
                conn.close()
    
    # ✅ NUEVO: Método para actualizar venta
    def actualizar_venta(self, venta_id: int, nuevo_total: float = None) -> bool:
        """
        Actualiza una venta existente
        """
        try:
            if nuevo_total is not None:
                query = "UPDATE Ventas SET Total = ? WHERE id = ?"
                params = (nuevo_total, venta_id)
            else:
                return False
            
            result = self.execute_transaction([(query, params)])
            
            if result:
                self._invalidate_cache_after_modification()
                print(f"✅ Venta {venta_id} actualizada exitosamente")
                return True
            
            return False
            
        except Exception as e:
            print(f"❌ Error actualizando venta {venta_id}: {e}")
            return False
    
    # ✅ NUEVO: Método para eliminar venta
    @ExceptionHandler.handle_exception
    def eliminar_venta(self, venta_id: int) -> bool:
        """
        ✅ CORREGIDO: Elimina venta y RESTAURA stock a lotes usando información de DetallesVentas
        """
        validate_required(venta_id, "venta_id")
        
        conn = None
        productos_restaurados = []
        
        try:
            conn = self._get_connection()
            cursor = conn.cursor()
            
            print(f"🗑️ Iniciando eliminación de venta {venta_id}")
            
            # PASO 1: Obtener detalles de la venta para restaurar stock
            detalles_venta = self.get_detalles_venta_para_restauracion(venta_id)
            if not detalles_venta:
                raise VentaError(f"Venta {venta_id} no encontrada")
            
            # PASO 2: RESTAURAR stock a los lotes originales
            for detalle in detalles_venta:
                lote_id = detalle['Id_Lote']
                cantidad_a_restaurar = detalle['Cantidad_Unitario']
                producto_id = detalle['Id_Producto']
                
                # Restaurar cantidad al lote específico
                cursor.execute("""
                    UPDATE Lote 
                    SET Cantidad_Unitario = Cantidad_Unitario + ?
                    WHERE id = ?
                """, (cantidad_a_restaurar, lote_id))
                
                productos_restaurados.append({
                    'lote_id': lote_id,
                    'cantidad_restaurada': cantidad_a_restaurar,
                    'producto_id': producto_id
                })
            
            # PASO 3: Actualizar Stock_Unitario en tabla Productos
            productos_afectados = set()
            for restaurado in productos_restaurados:
                productos_afectados.add(restaurado['producto_id'])
            
            for producto_id in productos_afectados:
                cursor.execute("""
                    UPDATE Productos 
                    SET Stock_Unitario = (
                        SELECT ISNULL(SUM(l.Cantidad_Unitario), 0) 
                        FROM Lote l 
                        WHERE l.Id_Producto = ?
                    )
                    WHERE id = ?
                """, (producto_id, producto_id))
            
            print(f"✅ Stock restaurado a {len(productos_restaurados)} lotes")
            
            # PASO 4: ELIMINAR detalles de venta
            cursor.execute("DELETE FROM DetallesVentas WHERE Id_Venta = ?", (venta_id,))
            detalles_eliminados = cursor.rowcount
            
            # PASO 5: ELIMINAR la venta
            cursor.execute("DELETE FROM Ventas WHERE id = ?", (venta_id,))
            ventas_eliminadas = cursor.rowcount
            
            if ventas_eliminadas == 0:
                raise VentaError(f"Venta {venta_id} no encontrada para eliminar")
            
            # PASO 6: Commit de toda la operación
            conn.commit()
            
            # Limpiar cache
            self._invalidate_cache_after_modification()
            
            print(f"🎉 Venta {venta_id} eliminada exitosamente - Stock restaurado a lotes")
            return True
            
        except Exception as e:
            print(f"❌ Error eliminando venta {venta_id}: {e}")
            
            if conn:
                conn.rollback()
                print("🔄 Rollback ejecutado")
            
            raise VentaError(f"Error eliminando venta: {str(e)}")
        
        finally:
            if conn:
                conn.close()

    def get_detalles_venta_para_restauracion(self, venta_id: int) -> List[Dict[str, Any]]:
        """
        ✅ CORREGIDO: Obtiene detalles de venta sin columna Subtotal inexistente
        """
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
            print(f"❌ Error obteniendo detalles para restauración: {e}")
            return []
        
    def _invalidate_cache_before_transaction(self):
        """Invalida caché antes de iniciar transacciones"""
        try:
            # Invalidar caché del producto repository
            if hasattr(self.producto_repo, '_invalidate_cache_after_modification'):
                self.producto_repo._invalidate_cache_after_modification()
                print("🔄 Caché ProductoRepository invalidado antes de transacción")
                
            # Invalidar caché propio
            self._invalidate_cache_after_modification()
            print("🔄 Caché VentaRepository invalidado antes de transacción")
            
        except Exception as e:
            print(f"⚠️ Error invalidando caché antes de transacción: {e}")
    
    def _invalidate_cache_after_modification(self):
        """
        ✅ MEJORADO: Invalidación completa y forzada
        """
        try:
            print("🧹 INICIANDO INVALIDACIÓN COMPLETA DE CACHE...")
            
            # Limpiar todos los tipos de caché posibles
            caches_to_clear = [
                '_cache', '_query_cache', '_result_cache', '_data_cache', 
                '_product_cache', '_stock_cache', '_search_cache'
            ]
            
            cache_cleared_count = 0
            for cache_name in caches_to_clear:
                if hasattr(self, cache_name):
                    cache_obj = getattr(self, cache_name)
                    if hasattr(cache_obj, 'clear'):
                        cache_obj.clear()
                        cache_cleared_count += 1
                        print(f"   🗑️ {cache_name} limpiado")
            
            # Resetear timestamps de caché
            timestamp_attrs = [
                '_last_cache_time', '_cache_timestamp', '_last_update',
                '_last_product_cache', '_last_stock_update'
            ]
            
            for attr_name in timestamp_attrs:
                if hasattr(self, attr_name):
                    setattr(self, attr_name, None)
            
            # Forzar recarga en próximas consultas
            self._force_reload = True
            self._force_reload_productos = True
            self._bypass_all_cache = True
            
            print(f"✅ INVALIDACIÓN COMPLETA: {cache_cleared_count} caches limpiados, flags de bypass activados")
            
            # También invalidar ProductoRepository si está disponible
            if hasattr(self, 'producto_repo') and self.producto_repo:
                if hasattr(self.producto_repo, '_invalidate_cache_after_modification'):
                    self.producto_repo._invalidate_cache_after_modification()
                    print("   🔄 ProductoRepository cache también invalidado")
            
        except Exception as e:
            print(f"⚠️ Error en invalidación completa: {e}")
    
    def _limpiar_venta_fallida(self, venta_id: int):
        """Limpia una venta que falló durante la creación"""
        try:
            operaciones = [
                ("DELETE FROM DetallesVentas WHERE Id_Venta = ?", (venta_id,)),
                ("DELETE FROM Ventas WHERE id = ?", (venta_id,))
            ]
            
            success = self.execute_transaction(operaciones)
            if success:
                print(f"🗑️ Venta fallida limpiada: {venta_id}")
        except Exception as e:
            print(f"⚠️ Error limpiando venta fallida {venta_id}: {e}")
    
    @ExceptionHandler.handle_exception
    def anular_venta(self, venta_id: int, motivo: str = "Anulación manual") -> bool:
        """
        Anula una venta y restaura el stock usando datos directos de Productos
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
            # Obtener ID del producto desde el lote
            producto_query = """
            SELECT l.Id_Producto FROM Lote l WHERE l.id = ?
            """
            
            conn = self._get_connection()
            cursor = conn.cursor()
            cursor.execute(producto_query, (detalle['Id_Lote'],))
            producto_result = cursor.fetchone()
            conn.close()
            
            if producto_result:
                producto_id = producto_result[0]
                
                # Restaurar en tabla Productos
                restore_producto_query = """
                UPDATE Productos 
                SET Stock_Unitario = Stock_Unitario + ?
                WHERE id = ?
                """
                operaciones.append((restore_producto_query, (detalle['Cantidad_Unitario'], producto_id)))
                
                # Restaurar en el lote original
                restore_lote_query = """
                UPDATE Lote 
                SET Cantidad_Unitario = Cantidad_Unitario + ?
                WHERE id = ?
                """
                operaciones.append((restore_lote_query, (detalle['Cantidad_Unitario'], detalle['Id_Lote'])))
        
        # Eliminar detalles de venta
        delete_detalles_query = "DELETE FROM DetallesVentas WHERE Id_Venta = ?"
        operaciones.append((delete_detalles_query, (venta_id,)))
        
        # Eliminar venta
        delete_venta_query = "DELETE FROM Ventas WHERE id = ?"
        operaciones.append((delete_venta_query, (venta_id,)))
        
        # Ejecutar todas las operaciones en transacción
        success = self.execute_transaction(operaciones)
        
        if success:
            # Invalidar caché después de anulación
            self._invalidate_cache_after_modification()
            print(f"✅ Venta anulada - ID: {venta_id}, Items restaurados: {len(venta['detalles'])}")
        
        return success
    
    @ExceptionHandler.handle_exception
    def actualizar_venta_completa(self, venta_id: int, nuevos_productos: List[Dict[str, Any]]) -> bool:
        """
        ✅ CORREGIDO: Actualiza venta evitando deadlocks y loops infinitos
        """
        validate_required(venta_id, "venta_id")
        validate_required(nuevos_productos, "nuevos_productos")
        
        if not nuevos_productos:
            raise VentaError("No hay productos para actualizar")
        
        conn = None
        
        try:
            conn = self._get_connection()
            cursor = conn.cursor()
            
            print(f"🔄 Iniciando actualización de venta {venta_id}")
            
            # PASO 1: Obtener y RESTAURAR stock de la venta original
            detalles_originales = self.get_detalles_venta_para_restauracion(venta_id)
            if not detalles_originales:
                raise VentaError(f"Venta {venta_id} no encontrada")
            
            # Restaurar stock
            for detalle in detalles_originales:
                cursor.execute("""
                    UPDATE Lote 
                    SET Cantidad_Unitario = Cantidad_Unitario + ?
                    WHERE id = ?
                """, (detalle['Cantidad_Unitario'], detalle['Id_Lote']))
            
            # Actualizar Stock_Unitario en tabla Productos
            productos_afectados = set(detalle['Id_Producto'] for detalle in detalles_originales)
            for producto_id in productos_afectados:
                cursor.execute("""
                    UPDATE Productos 
                    SET Stock_Unitario = (
                        SELECT ISNULL(SUM(l.Cantidad_Unitario), 0) 
                        FROM Lote l 
                        WHERE l.Id_Producto = ?
                    )
                    WHERE id = ?
                """, (producto_id, producto_id))
            
            print(f"✅ Stock restaurado para {len(detalles_originales)} detalles")
            
            # PASO 2: ELIMINAR detalles de venta originales
            cursor.execute("DELETE FROM DetallesVentas WHERE Id_Venta = ?", (venta_id,))
            
            # PASO 3: VALIDAR productos SIN usar verificación FIFO compleja
            total_nueva_venta = 0
            items_para_procesar = []
            
            for i, producto in enumerate(nuevos_productos):
                codigo = str(producto.get('codigo', '')).strip()
                cantidad = int(producto.get('cantidad', 0))
                precio = float(producto.get('precio', 0))
                
                if not codigo or cantidad <= 0 or precio <= 0:
                    raise VentaError(f"Producto {i}: Datos inválidos")
                
                # Verificación simple de stock disponible
                cursor.execute("""
                    SELECT p.id, 
                        ISNULL((SELECT SUM(l.Cantidad_Unitario) FROM Lote l WHERE l.Id_Producto = p.id), 0) as Stock_Disponible
                    FROM Productos p
                    WHERE p.Codigo = ?
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
            
            # PASO 4: APLICAR nueva venta usando FIFO simple
            for item in items_para_procesar:
                cantidad_restante = item['cantidad']
                
                # Obtener lotes disponibles ordenados por FIFO
                cursor.execute("""
                    SELECT id, Cantidad_Unitario 
                    FROM Lote 
                    WHERE Id_Producto = ? AND Cantidad_Unitario > 0
                    ORDER BY Fecha_Vencimiento ASC, id ASC
                """, (item['producto_id'],))
                
                lotes_disponibles = cursor.fetchall()
                
                # Reducir stock de lotes y crear detalles
                for lote_id, cantidad_lote in lotes_disponibles:
                    if cantidad_restante <= 0:
                        break
                    
                    cantidad_a_usar = min(cantidad_restante, cantidad_lote)
                    
                    # Reducir stock del lote
                    cursor.execute("""
                        UPDATE Lote 
                        SET Cantidad_Unitario = Cantidad_Unitario - ?
                        WHERE id = ?
                    """, (cantidad_a_usar, lote_id))
                    
                    # Crear detalle de venta
                    cursor.execute("""
                        INSERT INTO DetallesVentas 
                        (Id_Venta, Id_Lote, Cantidad_Unitario, Precio_Unitario)
                        VALUES (?, ?, ?, ?)
                    """, (venta_id, lote_id, cantidad_a_usar, item['precio']))
                    
                    cantidad_restante -= cantidad_a_usar
                
                if cantidad_restante > 0:
                    raise StockInsuficienteError(item['codigo'], 
                                            item['cantidad'] - cantidad_restante, 
                                            item['cantidad'])
            
            # PASO 5: Actualizar total de la venta
            cursor.execute("UPDATE Ventas SET Total = ? WHERE id = ?", 
                        (total_nueva_venta, venta_id))
            
            # PASO 6: Commit
            conn.commit()
            
            # Limpiar cache
            self._invalidate_cache_after_modification()
            
            print(f"🎉 Venta {venta_id} actualizada exitosamente")
            return True
            
        except Exception as e:
            print(f"❌ Error actualizando venta {venta_id}: {e}")
            if conn:
                conn.rollback()
            raise VentaError(f"Error actualizando venta: {str(e)}")
        
        finally:
            if conn:
                conn.close()
    def verificar_disponibilidad_producto_sin_cache(self, codigo: str) -> Dict[str, Any]:
        """
        NUEVO: Verifica disponibilidad SIN usar cache - para operaciones críticas
        """
        if not codigo:
            return {"cantidad_disponible": 0, "disponible": False}
        
        try:
            query = """
            SELECT 
                p.id,
                p.Codigo,
                p.Nombre,
                p.Stock_Unitario as Stock_Disponible
            FROM Productos p
            WHERE p.Codigo = ?
            """
            
            # ✅ FORZAR consulta directa sin cache
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
        
        # Obtener ventas detalladas del día
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
        return self._execute_query(query, (dias,), use_cache=False)
    
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
        return self._execute_query(query, tuple(params), use_cache=False)
    
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
        
        ingresos = self._execute_query(ingresos_query, (periodo,), fetch_one=True, use_cache=False)
        
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
        
        ingresos_diarios = self._execute_query(ingresos_diarios_query, (periodo,), use_cache=False)
        
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
            lote = self._execute_query(lote_query, (detalle['Id_Lote'],), fetch_one=True, use_cache=False)
            if not lote:
                errores.append(f"Lote {detalle['Id_Lote']} no existe")
        
        return {
            'valida': len(errores) == 0,
            'errores': errores,
            'total_db': venta['Total'],
            'total_calculado': total_calculado
        }