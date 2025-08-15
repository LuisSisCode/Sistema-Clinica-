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
        """Obtiene ventas del día actual"""
        print("🐛 DEBUG: get_active() llamado para ventas del día")
        query = """
        SELECT v.*, u.Nombre + ' ' + u.Apellido_Paterno as Vendedor
        FROM Ventas v
        INNER JOIN Usuario u ON v.Id_Usuario = u.id
        WHERE CAST(v.Fecha AS DATE) = CAST(GETDATE() AS DATE)
        ORDER BY v.Fecha DESC
        """
        resultado = self._execute_query(query)
        print(f"🐛 DEBUG: get_active() encontró {len(resultado) if resultado else 0} ventas del día")
        
        if resultado:
            print(f"🐛 DEBUG: Primera venta: {resultado[0]}")
        
        return resultado
    
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
        print(f"🐛 DEBUG: get_venta_completa llamado con venta_id: {venta_id} (tipo: {type(venta_id)})")

        validate_required(venta_id, "venta_id")
        
        # Obtener datos principales de la venta
        venta_query = """
        SELECT v.*, u.Nombre + ' ' + u.Apellido_Paterno as Vendedor,
               u.correo as Vendedor_Email
        FROM Ventas v
        INNER JOIN Usuario u ON v.Id_Usuario = u.id
        WHERE v.id = ?
        """
        print(f"🐛 DEBUG: Ejecutando query con parámetro: {venta_id}")
        venta = self._execute_query(venta_query, (venta_id,), fetch_one=True)
        print(f"🐛 DEBUG: Resultado de query venta: {venta} (tipo: {type(venta)})")
        
        if not venta:
            print(f"❌ DEBUG: Venta no encontrada para ID: {venta_id}")
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
    # CREACIÓN DE VENTAS CON FIFO - VERSIÓN CORREGIDA
    # ===============================
    
    @ExceptionHandler.handle_exception
    def crear_venta(self, usuario_id: int, items_venta: List[Dict[str, Any]]) -> Dict[str, Any]:
        """
        Crea una venta completa usando transacciones para evitar problemas de FK
        """
        print(f"🐛 DEBUG: Iniciando crear_venta - usuario_id: {usuario_id}")
        print(f"🐛 DEBUG: items_venta recibidos: {items_venta}")
        
        if not items_venta:
            raise VentaError("No se proporcionaron items para la venta")
        
        print(f"🛒 Iniciando venta - Usuario: {usuario_id}, Items: {len(items_venta)}")
        
        # 1. Validar y preparar items
        items_preparados = []
        total_venta = Decimal('0.00')
        
        try:
            for i, item in enumerate(items_venta):
                print(f"🔍 DEBUG: Procesando item {i}: {item}")
                item_preparado = self._validar_y_preparar_item(item)
                items_preparados.append(item_preparado)
                total_venta += item_preparado['subtotal']
            
            print(f"🔍 DEBUG: Items preparados exitosamente: {len(items_preparados)}")
            
        except Exception as e:
            print(f"❌ ERROR en preparación de items: {e}")
            raise e
        
        # 2. USAR TRANSACCIÓN COMPLETA para crear venta + detalles
        return self._crear_venta_con_transaccion(usuario_id, items_preparados, total_venta)
    
    def _crear_venta_con_transaccion(self, usuario_id: int, items_preparados: List[Dict], total_venta: Decimal) -> Dict[str, Any]:
        """
        Crea venta usando una sola transacción para venta principal + todos los detalles
        """
        conn = None
        venta_id = None
        
        try:
            # Obtener conexión única para toda la transacción
            conn = self._get_connection()
            cursor = conn.cursor()
            
            print("🔄 Iniciando transacción completa de venta...")
            
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
            
            # PASO 2: Procesar todos los items y crear detalles
            todos_los_detalles = []
            
            for i, item in enumerate(items_preparados):
                print(f"🔄 Procesando item {i} en transacción...")
                
                # Reducir stock FIFO (esto usa su propia transacción)
                lotes_afectados = self.producto_repo.reducir_stock_fifo(
                    item['producto_id'], 
                    item['cantidad']
                )
                print(f"📦 Stock reducido - Lotes afectados: {len(lotes_afectados)}")
                
                # Crear detalles para cada lote
                for lote_info in lotes_afectados:
                    detalle_query = """
                    INSERT INTO DetallesVentas (Id_Venta, Id_Lote, Cantidad_Unitario, Precio_Unitario, Detalles)
                    OUTPUT INSERTED.id
                    VALUES (?, ?, ?, ?, ?)
                    """
                    
                    detalle_data = f"Venta automática FIFO - {item['producto_nombre']}"
                    
                    cursor.execute(detalle_query, (
                        venta_id,
                        lote_info['lote_id'],
                        lote_info['cantidad_reducida'],
                        item['precio'],
                        detalle_data
                    ))
                    
                    detalle_result = cursor.fetchone()
                    if detalle_result:
                        detalle_id = detalle_result[0]
                        todos_los_detalles.append({
                            'detalle_id': detalle_id,
                            'lote_id': lote_info['lote_id'],
                            'cantidad': lote_info['cantidad_reducida'],
                            'precio': item['precio']
                        })
                        print(f"✅ Detalle creado - ID: {detalle_id}")
                    else:
                        raise VentaError(f"Error creando detalle para lote {lote_info['lote_id']}")
            
            # PASO 3: Commit de toda la transacción
            conn.commit()
            print(f"✅ Transacción completada - Venta: {venta_id}, Detalles: {len(todos_los_detalles)}")
            
            # Invalidar cache después de commit exitoso
            self._invalidate_cache_after_modification()
            
            # PASO 4: Retornar venta completa
            return self.get_venta_completa(venta_id)
            
        except Exception as e:
            print(f"❌ ERROR en transacción de venta: {e}")
            if conn:
                conn.rollback()
                print("🔄 Rollback realizado")
            
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
    
    def _validar_y_preparar_item(self, item: Dict[str, Any]) -> Dict[str, Any]:
        """Valida y prepara un item para la venta"""
        print(f"🔍 DEBUG: _validar_y_preparar_item recibió: {item} (tipo: {type(item)})")
        
        try:
            # Validaciones básicas
            codigo = item.get('codigo', '').strip()
            cantidad = item.get('cantidad', 0)
            precio = item.get('precio')
            
            print(f"🔍 DEBUG: Valores extraídos - codigo: {codigo}, cantidad: {cantidad}, precio: {precio}")
            
            validate_required(codigo, "codigo")
            validate_positive_number(cantidad, "cantidad")
            
            # Obtener producto
            producto = self.producto_repo.get_by_codigo(codigo)
            if not producto:
                raise ProductoNotFoundError(codigo=codigo)
            
            print(f"🔍 DEBUG: Producto encontrado: {producto['id']} - {producto['Nombre']}")
            
            # Verificar disponibilidad FIFO
            disponibilidad = self.producto_repo.verificar_disponibilidad_fifo(
                producto['id'], cantidad
            )
            
            print(f"🔍 DEBUG: Disponibilidad: {disponibilidad}")
            
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
            
            item_preparado = {
                'codigo': codigo,
                'producto_id': producto['id'],
                'producto_nombre': producto['Nombre'],
                'cantidad': cantidad,
                'precio': precio,
                'subtotal': subtotal,
                'disponibilidad': disponibilidad
            }
            
            print(f"🔍 DEBUG: Item preparado exitosamente: {item_preparado}")
            return item_preparado
            
        except Exception as e:
            print(f"❌ ERROR en _validar_y_preparar_item: {e}")
            raise e
    
    # ===============================
    # ANULACIÓN DE VENTAS
    # ===============================
    
    @ExceptionHandler.handle_exception
    def anular_venta(self, venta_id: int, motivo: str = "Anulación manual") -> bool:
        """
        Anula una venta y restaura el stock usando FIFO inverso
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
    # REPORTES Y ESTADÍSTICAS (sin cambios)
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