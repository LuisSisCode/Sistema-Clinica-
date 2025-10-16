from typing import List, Dict, Any, Optional
from datetime import datetime, timedelta

from ..core.base_repository import BaseRepository
from ..core.excepciones import (
    ValidationError, DatabaseQueryError,
    ExceptionHandler, validate_required
)
from ..core.cache_system import cached_query, invalidate_after_update

class ReportesRepository(BaseRepository):
    """Repository para generación de reportes del sistema"""
    
    def __init__(self):
        super().__init__('reportes_temp', 'reportes')  # Tabla temporal para cachés
        print("📊 ReportesRepository inicializado")
    
    # ===============================
    # IMPLEMENTACIÓN ABSTRACTA
    # ===============================
    
    def get_active(self) -> List[Dict[str, Any]]:
        """No aplica para reportes"""
        return []
    
    # ===============================
    # REPORTES DE VENTAS (TIPO 1)
    # ===============================
    
    @cached_query('reporte_ventas', ttl=30)
    def get_reporte_ventas(self, fecha_desde: str, fecha_hasta: str) -> List[Dict[str, Any]]:
        """CORREGIDO: Números de venta y campos validados"""
        fecha_desde_sql = self._convertir_fecha_sql(fecha_desde, es_fecha_final=False)
        fecha_hasta_sql = self._convertir_fecha_sql(fecha_hasta, es_fecha_final=True)
                
        query = """
        SELECT 
            FORMAT(v.Fecha, 'dd/MM/yyyy') as fecha,
            -- ✅ NÚMERO DE VENTA CORREGIDO
            CASE 
                WHEN v.id IS NOT NULL THEN 'V' + RIGHT('000' + CAST(v.id AS VARCHAR(10)), 3)
                ELSE 'V000'
            END as numeroVenta,
            COALESCE(p.Nombre, 'Producto sin nombre') as descripcion,
            COALESCE(dv.Cantidad_Unitario, 0) as cantidad,
            COALESCE(dv.Precio_Unitario, 0) as precio_unitario,
            COALESCE((dv.Cantidad_Unitario * dv.Precio_Unitario), 0) as valor,
            COALESCE(u.Nombre + ' ' + u.Apellido_Paterno, 'Sin usuario') as usuario
        FROM Ventas v
        INNER JOIN DetallesVentas dv ON v.id = dv.Id_Venta
        INNER JOIN Lote l ON dv.Id_Lote = l.id
        INNER JOIN Productos p ON l.Id_Producto = p.id
        LEFT JOIN Usuario u ON v.Id_Usuario = u.id
        WHERE v.Fecha >= ? AND v.Fecha < ?
        ORDER BY v.Fecha DESC, v.id DESC, p.Nombre ASC
        """
        
        return self._execute_query(query, (fecha_desde_sql, fecha_hasta_sql))
    
    # ===============================
    # REPORTES DE INVENTARIO (TIPO 2)
    # ===============================
        
    @cached_query('reporte_inventario', ttl=600)
    def get_reporte_inventario(self, fecha_desde: str = "", fecha_hasta: str = "") -> List[Dict[str, Any]]:
        """Reporte de inventario con identificación de lotes CORREGIDO"""
        query = """
        SELECT 
            FORMAT(GETDATE(), 'dd/MM/yyyy') as fecha,
            p.Nombre as descripcion,
            m.Nombre as marca,
            
            -- ✅ STOCK REAL
            (SELECT ISNULL(SUM(l.Cantidad_Unitario), 0) 
            FROM Lote l 
            WHERE l.Id_Producto = p.id) as cantidad,
            
            -- ✅ IDENTIFICADOR DE LOTE PRINCIPAL (el más antiguo con stock)
            COALESCE(
                (SELECT TOP 1 'L' + RIGHT('000' + CAST(l.id AS VARCHAR(10)), 3)
                FROM Lote l 
                WHERE l.Id_Producto = p.id AND l.Cantidad_Unitario > 0
                ORDER BY l.Fecha_Vencimiento ASC, l.id ASC),
                '---'
            ) as lote,
            
            -- ✅ CANTIDAD DE LOTES ACTIVOS
            (SELECT COUNT(*) 
            FROM Lote l 
            WHERE l.Id_Producto = p.id AND l.Cantidad_Unitario > 0) as lotes,
            
            -- ✅ PRECIO UNITARIO
            CASE 
                WHEN p.Precio_venta IS NULL OR p.Precio_venta = 0 
                THEN COALESCE(p.Precio_compra, 0)
                ELSE p.Precio_venta
            END as precioUnitario,
            
            -- ✅ FECHA VENCIMIENTO MÁS PRÓXIMA
            CASE 
                WHEN EXISTS (SELECT 1 FROM Lote l WHERE l.Id_Producto = p.id 
                            AND l.Cantidad_Unitario > 0 AND l.Fecha_Vencimiento IS NOT NULL)
                THEN (SELECT MIN(FORMAT(l.Fecha_Vencimiento, 'dd/MM/yyyy'))
                    FROM Lote l 
                    WHERE l.Id_Producto = p.id 
                    AND l.Cantidad_Unitario > 0 
                    AND l.Fecha_Vencimiento IS NOT NULL)
                ELSE 'Sin vencimiento'
            END as fecha_vencimiento,
            
            -- ✅ VALOR TOTAL
            ((SELECT ISNULL(SUM(l.Cantidad_Unitario), 0) 
            FROM Lote l 
            WHERE l.Id_Producto = p.id) * 
            CASE 
                WHEN p.Precio_venta IS NULL OR p.Precio_venta = 0 
                THEN COALESCE(p.Precio_compra, 0)
                ELSE p.Precio_venta
            END) as valor,
            
            p.Codigo as codigo,
            p.Unidad_Medida as unidad
            
        FROM Productos p
        INNER JOIN Marca m ON p.ID_Marca = m.id
        WHERE EXISTS (SELECT 1 FROM Lote l WHERE l.Id_Producto = p.id)
        ORDER BY valor DESC, p.Nombre
        """
        
        return self._execute_query(query)
    
    # ===============================
    # REPORTES DE COMPRAS (TIPO 3)
    # ===============================
    
    @cached_query('reporte_compras', ttl=300)
    def get_reporte_compras(self, fecha_desde: str, fecha_hasta: str) -> List[Dict[str, Any]]:
        """Compras: CONSULTA SIMPLIFICADA - Solo campos que existen"""
        fecha_desde_sql = self._convertir_fecha_sql(fecha_desde, es_fecha_final=False)
        fecha_hasta_sql = self._convertir_fecha_sql(fecha_hasta, es_fecha_final=True)
        
        query = """
        SELECT 
            FORMAT(c.Fecha, 'dd/MM/yyyy') as fecha,
            
            -- ✅ PRODUCTO - Solo nombre del producto
            p.Nombre as descripcion,
            
            -- ✅ MARCA - Solo nombre de marca 
            COALESCE(m.Nombre, 'Sin marca') as marca,
            
            -- ✅ CANTIDAD - Unidades compradas
            dc.Cantidad_Unitario as cantidad,
            
            -- ✅ PROVEEDOR - Solo nombre
            pr.Nombre as proveedor,
            
            -- ✅ FECHA VENCIMIENTO - Formato correcto
            CASE 
                WHEN l.Fecha_Vencimiento IS NOT NULL 
                THEN FORMAT(l.Fecha_Vencimiento, 'dd/MM/yyyy')
                ELSE 'Sin vencimiento'
            END as fecha_vencimiento,
            
            -- ✅ USUARIO - Nombre completo
            CONCAT(u.Nombre, ' ', u.Apellido_Paterno) as usuario,
            
            -- ✅ TOTAL - Precio unitario (no el total de la compra)
            dc.Precio_Unitario as valor,
            
            -- Campos adicionales
            'C' + RIGHT('000' + CAST(c.id AS VARCHAR), 3) as numeroCompra
            
        FROM Compra c
        INNER JOIN DetalleCompra dc ON c.id = dc.Id_Compra
        INNER JOIN Lote l ON dc.Id_Lote = l.id
        INNER JOIN Productos p ON l.Id_Producto = p.id
        LEFT JOIN Marca m ON p.ID_Marca = m.id
        INNER JOIN Proveedor pr ON c.Id_Proveedor = pr.id
        INNER JOIN Usuario u ON c.Id_Usuario = u.id
        WHERE c.Fecha >= ? AND c.Fecha <= ?
        ORDER BY c.Fecha DESC, c.id DESC, p.Nombre ASC
        """
        
        return self._execute_query(query, (fecha_desde_sql, fecha_hasta_sql))

    # ===============================
    # REPORTES DE CONSULTAS (TIPO 4)
    # ===============================
    
    @cached_query('reporte_consultas', ttl=300)
    def get_reporte_consultas(self, fecha_desde: str, fecha_hasta: str) -> List[Dict[str, Any]]:
        """Consultas: fecha, especialidad, descripción, paciente, médico, precio"""
        fecha_desde_sql = self._convertir_fecha_sql(fecha_desde, es_fecha_final=False)
        fecha_hasta_sql = self._convertir_fecha_sql(fecha_hasta, es_fecha_final=True)
        
        query = """
        SELECT 
            FORMAT(c.Fecha, 'dd/MM/yyyy') as fecha,
            e.Nombre as especialidad,
            COALESCE(c.Detalles, 'Consulta médica') as descripcion,
            CONCAT(p.Nombre, ' ', p.Apellido_Paterno, 
                CASE WHEN p.Apellido_Materno IS NOT NULL AND p.Apellido_Materno != '' 
                        THEN ' ' + p.Apellido_Materno 
                        ELSE '' END) as paciente,
            CONCAT('Dr. ', d.Nombre, ' ', d.Apellido_Paterno, 
                CASE WHEN d.Apellido_Materno IS NOT NULL AND d.Apellido_Materno != '' 
                        THEN ' ' + d.Apellido_Materno 
                        ELSE '' END) as doctor_nombre,
            CASE 
                WHEN c.Tipo_Consulta = 'Emergencia' THEN COALESCE(e.Precio_Emergencia, 0)
                ELSE COALESCE(e.Precio_Normal, 0) 
            END as valor,
            1 as cantidad
        FROM Consultas c
        INNER JOIN Especialidad e ON c.Id_Especialidad = e.id
        INNER JOIN Doctores d ON e.Id_Doctor = d.id
        INNER JOIN Pacientes p ON c.Id_Paciente = p.id
        WHERE c.Fecha >= ? AND c.Fecha <= ?
        ORDER BY c.Fecha DESC, c.id DESC
        """    
        return self._execute_query(query, (fecha_desde_sql, fecha_hasta_sql))
    
    # ===============================
    # REPORTES DE LABORATORIO (TIPO 5)
    # ===============================
    
    @cached_query('reporte_laboratorio', ttl=300)
    def get_reporte_laboratorio(self, fecha_desde: str, fecha_hasta: str) -> List[Dict[str, Any]]:
        """Laboratorio: fecha, análisis, tipo, paciente, laboratorista, precio"""
        fecha_desde_sql = self._convertir_fecha_sql(fecha_desde, es_fecha_final=False)
        fecha_hasta_sql = self._convertir_fecha_sql(fecha_hasta, es_fecha_final=True)
        
        query = """
        SELECT 
            FORMAT(l.Fecha, 'dd/MM/yyyy') as fecha,
            
            -- ✅ ANÁLISIS - Nombre del tipo de análisis
            COALESCE(ta.Nombre, 'Análisis General') as analisis,
            
            -- ✅ TIPO - Normal o Emergencia  
            COALESCE(l.Tipo, 'Normal') as tipo,
            
            -- ✅ PACIENTE - Nombre completo
            CONCAT(p.Nombre, ' ', p.Apellido_Paterno, 
                CASE WHEN p.Apellido_Materno IS NOT NULL AND p.Apellido_Materno != '' 
                        THEN ' ' + p.Apellido_Materno 
                        ELSE '' END) as paciente,
            
            -- ✅ LABORATORISTA - Técnico encargado
            CASE 
                WHEN t.id IS NOT NULL THEN CONCAT(t.Nombre, ' ', t.Apellido_Paterno,
                    CASE WHEN t.Apellido_Materno IS NOT NULL AND t.Apellido_Materno != '' 
                        THEN ' ' + t.Apellido_Materno 
                        ELSE '' END)
                ELSE 'Sin asignar'
            END as laboratorista,
            
            -- ✅ PRECIO - Según tipo de servicio
            CASE 
                WHEN l.Tipo = 'Emergencia' THEN COALESCE(ta.Precio_Emergencia, 25.00)
                ELSE COALESCE(ta.Precio_Normal, 20.00) 
            END as valor,
            
            1 as cantidad
            
        FROM Laboratorio l
        INNER JOIN Pacientes p ON l.Id_Paciente = p.id
        LEFT JOIN Tipos_Analisis ta ON l.Id_Tipo_Analisis = ta.id
        INNER JOIN Usuario u ON l.Id_RegistradoPor = u.id
        LEFT JOIN Trabajadores t ON l.Id_Trabajador = t.id
        WHERE l.Fecha >= ? AND l.Fecha <= ?
        ORDER BY l.Fecha DESC, l.id DESC
        """
        return self._execute_query(query, (fecha_desde_sql, fecha_hasta_sql))

    # ✅ OPCIONAL: Método adicional para obtener estadísticas de laboratorio para el PDF
    def get_estadisticas_laboratorio(self, fecha_desde: str, fecha_hasta: str) -> Dict[str, Any]:
        """Obtiene estadísticas adicionales para el pie del reporte"""
        try:
            fecha_desde_sql = self._convertir_fecha_sql(fecha_desde, es_fecha_final=False)
            fecha_hasta_sql = self._convertir_fecha_sql(fecha_hasta, es_fecha_final=True)
            
            query = """
            SELECT 
                COUNT(*) as total_analisis,
                COUNT(DISTINCT Id_Paciente) as pacientes_unicos,
                COUNT(DISTINCT Id_Tipo_Analisis) as tipos_analisis_diferentes,
                COUNT(CASE WHEN Id_Trabajador IS NOT NULL THEN 1 END) as con_tecnico_asignado,
                COUNT(CASE WHEN Tipo = 'Normal' THEN 1 END) as servicios_normales,
                COUNT(CASE WHEN Tipo = 'Emergencia' THEN 1 END) as servicios_emergencia,
                SUM(CASE 
                    WHEN l.Tipo = 'Emergencia' THEN COALESCE(ta.Precio_Emergencia, 25.00)
                    ELSE COALESCE(ta.Precio_Normal, 20.00) 
                END) as valor_total
            FROM Laboratorio l
            LEFT JOIN Tipos_Analisis ta ON l.Id_Tipo_Analisis = ta.id
            WHERE l.Fecha >= ? AND l.Fecha <= ?
            """
            
            result = self._execute_query(query, (fecha_desde_sql, fecha_hasta_sql), fetch_one=True)
            
            if result:
                return {
                    'total_analisis': result.get('total_analisis', 0),
                    'pacientes_unicos': result.get('pacientes_unicos', 0),
                    'tipos_analisis_diferentes': result.get('tipos_analisis_diferentes', 0),
                    'con_tecnico_asignado': result.get('con_tecnico_asignado', 0),
                    'servicios_normales': result.get('servicios_normales', 0),
                    'servicios_emergencia': result.get('servicios_emergencia', 0),
                    'valor_total': float(result.get('valor_total', 0)),
                    'porcentaje_con_tecnico': round(
                        (result.get('con_tecnico_asignado', 0) / max(result.get('total_analisis', 1), 1)) * 100, 2
                    ),
                    'valor_promedio': round(
                        float(result.get('valor_total', 0)) / max(result.get('total_analisis', 1), 1), 2
                    )
                }
            
            return {}
            
        except Exception as e:
            print(f"⚠️ Error obteniendo estadísticas de laboratorio: {e}")
            return {}
    
    # ===============================
    # REPORTES DE ENFERMERÍA (TIPO 6)
    # ===============================
    
    def get_reporte_enfermeria(self, fecha_desde: str, fecha_hasta: str) -> List[Dict[str, Any]]:
        """Enfermería: fecha, procedimiento, tipo, paciente, enfermero/a, precio"""
        fecha_desde_sql = self._convertir_fecha_sql(fecha_desde, es_fecha_final=False)
        fecha_hasta_sql = self._convertir_fecha_sql(fecha_hasta, es_fecha_final=True)
        
        query = """
        SELECT 
            FORMAT(e.Fecha, 'dd/MM/yyyy') as fecha,
            
            -- ✅ PROCEDIMIENTO - Detalles del procedimiento
            COALESCE(tp.Descripcion, tp.Nombre, 'Procedimiento de enfermería') as procedimiento,
            
            -- ✅ TIPO - Normal o Emergencia
            COALESCE(e.Tipo, 'Normal') as tipo,
            
            -- ✅ PACIENTE - Nombre completo
            CONCAT(
                p.Nombre, ' ', 
                p.Apellido_Paterno,
                CASE 
                    WHEN p.Apellido_Materno IS NOT NULL AND p.Apellido_Materno != '' 
                    THEN ' ' + p.Apellido_Materno 
                    ELSE '' 
                END
            ) as paciente,
            
            -- ✅ ENFERMERO/A - Preferir Trabajador, fallback a Usuario
            CASE 
                WHEN t.id IS NOT NULL THEN 
                    CONCAT(
                        t.Nombre, ' ', 
                        t.Apellido_Paterno,
                        CASE 
                            WHEN t.Apellido_Materno IS NOT NULL AND t.Apellido_Materno != '' 
                            THEN ' ' + t.Apellido_Materno 
                            ELSE '' 
                        END
                    )
                ELSE CONCAT(u.Nombre, ' ', u.Apellido_Paterno)
            END as enfermero,
            
            -- ✅ PRECIO - Cálculo basado en cantidad y tipo
            (COALESCE(e.Cantidad, 1) * 
            CASE 
                WHEN COALESCE(e.Tipo, 'Normal') = 'Emergencia' 
                THEN COALESCE(tp.Precio_Emergencia, 25.00)
                ELSE COALESCE(tp.Precio_Normal, 20.00) 
            END) as valor,
            
            COALESCE(e.Cantidad, 1) as cantidad
            
        FROM Enfermeria e
        INNER JOIN Pacientes p ON e.Id_Paciente = p.id
        LEFT JOIN Tipos_Procedimientos tp ON e.Id_Procedimiento = tp.id
        INNER JOIN Usuario u ON e.Id_RegistradoPor = u.id
        LEFT JOIN Trabajadores t ON e.Id_Trabajador = t.id
        WHERE e.Fecha >= ? AND e.Fecha <= ?
        ORDER BY e.Fecha DESC, e.id DESC
        """
        return self._execute_query(query, (fecha_desde_sql, fecha_hasta_sql))
    
    # ===============================
    # REPORTES DE GASTOS (TIPO 7)
    # ===============================
    
    @cached_query('reporte_gastos', ttl=300)
    def get_reporte_gastos(self, fecha_desde: str, fecha_hasta: str) -> List[Dict[str, Any]]:
        """Gastos: fecha, tipo de gasto, descripción, proveedor, monto - CORREGIDO"""
        fecha_desde_sql = self._convertir_fecha_sql(fecha_desde, es_fecha_final=False)
        fecha_hasta_sql = self._convertir_fecha_sql(fecha_hasta, es_fecha_final=True)
        
        query = """
        SELECT 
            FORMAT(g.Fecha, 'dd/MM/yyyy') as fecha,
            
            -- ✅ TIPO DE GASTO
            tg.Nombre as tipo_gasto,
            
            -- ✅ DESCRIPCIÓN
            COALESCE(g.Descripcion, 'Gasto operativo') as descripcion,
            
            -- ✅ PROVEEDOR - CORREGIDO: Ahora usa JOIN con Proveedor_Gastos
            COALESCE(pg.Nombre, 'Sin proveedor') as proveedor,
            
            -- ✅ MONTO
            g.Monto as valor,
            
            CONCAT(u.Nombre, ' ', u.Apellido_Paterno) as registrado_por,
            1 as cantidad
            
        FROM Gastos g
        INNER JOIN Tipo_Gastos tg ON g.ID_Tipo = tg.id
        LEFT JOIN Proveedor_Gastos pg ON g.ID_Proveedor = pg.id  -- ✅ JOIN CORREGIDO
        INNER JOIN Usuario u ON g.Id_RegistradoPor = u.id
        WHERE g.Fecha >= ? AND g.Fecha < ?
        ORDER BY g.Fecha DESC, g.id DESC
        """
        return self._execute_query(query, (fecha_desde_sql, fecha_hasta_sql))
    
    # ===============================
    # REPORTE CONSOLIDADO (TIPO 8)
    # ===============================

    @cached_query('reporte_ingresos_egresos', ttl=600)
    def get_reporte_consolidado(self, fecha_desde: str, fecha_hasta: str) -> List[Dict[str, Any]]:
        """
        ✅ MEJORADO: Genera reporte con manejo individual de errores por módulo
        """
        
        fecha_desde_sql = self._convertir_fecha_sql(fecha_desde, es_fecha_final=False)
        fecha_hasta_sql = self._convertir_fecha_sql(fecha_hasta, es_fecha_final=True)  # ✅ Ahora suma 1 día
        
        movimientos_financieros = []
        
        try:
            print(f"💰 Generando Reporte de Ingresos y Egresos para período: {fecha_desde} - {fecha_hasta}")
            print(f"   SQL desde: {fecha_desde_sql}")
            print(f"   SQL hasta: {fecha_hasta_sql}")
            
            # ===== MÓDULO 1: VENTAS DE FARMACIA =====
            try:
                print("📊 [1/6] Obteniendo ventas de farmacia...")
                query_ventas = """
                SELECT 
                    FORMAT(v.Fecha, 'dd/MM/yyyy') as fecha,
                    'INGRESO' as tipo,
                    'Ventas de Farmacia - ' + p.Nombre as descripcion,
                    dv.Cantidad_Unitario as cantidad,
                    (dv.Cantidad_Unitario * dv.Precio_Unitario) as valor,
                    'farmacia' as categoria,
                    'Venta #' + CAST(v.id AS VARCHAR) as referencia
                FROM Ventas v
                INNER JOIN DetallesVentas dv ON v.id = dv.Id_Venta
                INNER JOIN Lote l ON dv.Id_Lote = l.id
                INNER JOIN Productos p ON l.Id_Producto = p.id
                WHERE v.Fecha >= ? AND v.Fecha < ?  -- ✅ Cambio: < en lugar de <=
                """
                
                ventas_detalle = self._execute_query(query_ventas, (fecha_desde_sql, fecha_hasta_sql))
                if ventas_detalle:
                    movimientos_financieros.extend(ventas_detalle)
                    print(f"   ✅ Ventas: {len(ventas_detalle)} movimientos")
                else:
                    print("   ℹ️ Sin ventas en el período")
                    
            except Exception as e:
                print(f"   ⚠️ ERROR en ventas: {e}")
                # ✅ Continuar con el siguiente módulo
            
            # ===== MÓDULO 2: CONSULTAS MÉDICAS =====
            try:
                print("📊 [2/6] Obteniendo consultas médicas...")
                query_consultas = """
                SELECT 
                    FORMAT(c.Fecha, 'dd/MM/yyyy') as fecha,
                    'INGRESO' as tipo,
                    'Consulta Médica - ' + e.Nombre as descripcion,
                    1 as cantidad,
                    CASE 
                        WHEN c.Tipo_Consulta = 'Emergencia' THEN COALESCE(e.Precio_Emergencia, 50.00)
                        ELSE COALESCE(e.Precio_Normal, 30.00) 
                    END as valor,
                    'consultas' as categoria,
                    'Consulta #' + CAST(c.id AS VARCHAR) as referencia
                FROM Consultas c
                INNER JOIN Especialidad e ON c.Id_Especialidad = e.id
                WHERE c.Fecha >= ? AND c.Fecha < ?  -- ✅ Cambio: < en lugar de <=
                """
                
                consultas_detalle = self._execute_query(query_consultas, (fecha_desde_sql, fecha_hasta_sql))
                if consultas_detalle:
                    movimientos_financieros.extend(consultas_detalle)
                    print(f"   ✅ Consultas: {len(consultas_detalle)} movimientos")
                else:
                    print("   ℹ️ Sin consultas en el período")
                    
            except Exception as e:
                print(f"   ⚠️ ERROR en consultas: {e}")
            
            # ===== MÓDULO 3: ANÁLISIS DE LABORATORIO =====
            try:
                print("📊 [3/6] Obteniendo análisis de laboratorio...")
                query_laboratorio = """
                SELECT 
                    FORMAT(l.Fecha, 'dd/MM/yyyy') as fecha,
                    'INGRESO' as tipo,
                    'Análisis de Laboratorio - ' + COALESCE(ta.Nombre, 'Análisis General') as descripcion,
                    1 as cantidad,
                    CASE 
                        WHEN l.Tipo = 'Emergencia' THEN COALESCE(ta.Precio_Emergencia, 25.00)
                        ELSE COALESCE(ta.Precio_Normal, 20.00) 
                    END as valor,
                    'laboratorio' as categoria,
                    'Lab #' + CAST(l.id AS VARCHAR) as referencia
                FROM Laboratorio l
                LEFT JOIN Tipos_Analisis ta ON l.Id_Tipo_Analisis = ta.id
                WHERE l.Fecha >= ? AND l.Fecha < ?  -- ✅ Cambio: < en lugar de <=
                """
                
                laboratorio_detalle = self._execute_query(query_laboratorio, (fecha_desde_sql, fecha_hasta_sql))
                if laboratorio_detalle:
                    movimientos_financieros.extend(laboratorio_detalle)
                    print(f"   ✅ Laboratorio: {len(laboratorio_detalle)} movimientos")
                else:
                    print("   ℹ️ Sin análisis de laboratorio en el período")
                    
            except Exception as e:
                print(f"   ⚠️ ERROR en laboratorio: {e}")
            
            # ===== MÓDULO 4: PROCEDIMIENTOS DE ENFERMERÍA =====
            try:
                print("📊 [4/6] Obteniendo procedimientos de enfermería...")
                query_enfermeria = """
                SELECT 
                    FORMAT(e.Fecha, 'dd/MM/yyyy') as fecha,
                    'INGRESO' as tipo,
                    'Enfermería - ' + COALESCE(tp.Nombre, 'Procedimiento General') as descripcion,
                    COALESCE(e.Cantidad, 1) as cantidad,
                    (COALESCE(e.Cantidad, 1) * 
                    CASE 
                        WHEN COALESCE(e.Tipo, 'Normal') = 'Emergencia' 
                        THEN COALESCE(tp.Precio_Emergencia, 25.00)
                        ELSE COALESCE(tp.Precio_Normal, 20.00) 
                    END) as valor,
                    'enfermeria' as categoria,
                    'Proc #' + CAST(e.id AS VARCHAR) as referencia
                FROM Enfermeria e
                LEFT JOIN Tipos_Procedimientos tp ON e.Id_Procedimiento = tp.id
                WHERE e.Fecha >= ? AND e.Fecha < ?  -- ✅ Cambio: < en lugar de <=
                """
                
                enfermeria_detalle = self._execute_query(query_enfermeria, (fecha_desde_sql, fecha_hasta_sql))
                if enfermeria_detalle:
                    movimientos_financieros.extend(enfermeria_detalle)
                    print(f"   ✅ Enfermería: {len(enfermeria_detalle)} movimientos")
                else:
                    print("   ℹ️ Sin procedimientos de enfermería en el período")
                    
            except Exception as e:
                print(f"   ⚠️ ERROR en enfermería: {e}")
            
            # ===== MÓDULO 5: COMPRAS DE FARMACIA =====
            try:
                print("📊 [5/6] Obteniendo compras de farmacia...")
                query_compras = """
                SELECT 
                    FORMAT(c.Fecha, 'dd/MM/yyyy') as fecha,
                    'EGRESO' as tipo,
                    'Compra Farmacia - ' + p.Nombre as descripcion,
                    dc.Cantidad_Unitario as cantidad,
                    dc.Precio_Unitario as valor,  -- ✅ Valor positivo, se convierte a negativo después
                    'compras_farmacia' as categoria,
                    'Compra #' + CAST(c.id AS VARCHAR) as referencia
                FROM Compra c
                INNER JOIN DetalleCompra dc ON c.id = dc.Id_Compra
                INNER JOIN Lote l ON dc.Id_Lote = l.id
                INNER JOIN Productos p ON l.Id_Producto = p.id
                WHERE c.Fecha >= ? AND c.Fecha < ?  -- ✅ Cambio: < en lugar de <=
                """
                
                compras_detalle = self._execute_query(query_compras, (fecha_desde_sql, fecha_hasta_sql))
                if compras_detalle:
                    # ✅ Convertir valores a negativos para egresos
                    for compra in compras_detalle:
                        compra['valor'] = -abs(float(compra['valor']))
                    
                    movimientos_financieros.extend(compras_detalle)
                    print(f"   ✅ Compras: {len(compras_detalle)} movimientos")
                else:
                    print("   ℹ️ Sin compras en el período")
                    
            except Exception as e:
                print(f"   ⚠️ ERROR en compras: {e}")
            
            # ===== MÓDULO 6: GASTOS OPERATIVOS =====
            try:
                print("📊 [6/6] Obteniendo gastos operativos...")
                query_gastos = """
                SELECT 
                    FORMAT(g.Fecha, 'dd/MM/yyyy') as fecha,
                    'EGRESO' as tipo,
                    tg.Nombre + ' - ' + g.Descripcion as descripcion,
                    1 as cantidad,
                    g.Monto as valor,
                    'gastos_operativos' as categoria,
                    'Gasto #' + CAST(g.id AS VARCHAR) as referencia
                FROM Gastos g
                INNER JOIN Tipo_Gastos tg ON g.ID_Tipo = tg.id
                WHERE g.Fecha >= ? AND g.Fecha < ?
                """
                
                gastos_detalle = self._execute_query(query_gastos, (fecha_desde_sql, fecha_hasta_sql))
                if gastos_detalle:
                    # ✅ Convertir valores a negativos para egresos
                    for gasto in gastos_detalle:
                        gasto['valor'] = -abs(float(gasto['valor']))
                    
                    movimientos_financieros.extend(gastos_detalle)
                    print(f"   ✅ Gastos: {len(gastos_detalle)} movimientos")
                else:
                    print("   ℹ️ Sin gastos en el período")
                    
            except Exception as e:
                print(f"   ⚠️ ERROR en gastos: {e}")
            
            # ===== ORDENAR Y RETORNAR MOVIMIENTOS =====
            if movimientos_financieros:
                # Ordenar por fecha descendente
                movimientos_financieros.sort(
                    key=lambda x: self._parse_fecha_dd_mm_yyyy(x.get('fecha', '01/01/2024')), 
                    reverse=True
                )
                
                # Calcular totales para logging
                total_ingresos = sum(float(m.get('valor', 0)) for m in movimientos_financieros if m.get('tipo') == 'INGRESO')
                total_egresos = sum(abs(float(m.get('valor', 0))) for m in movimientos_financieros if m.get('tipo') == 'EGRESO')
                saldo_neto = total_ingresos - total_egresos
                
                print(f"\n💹 RESUMEN FINANCIERO:")
                print(f"   📈 Total Ingresos: Bs {total_ingresos:,.2f}")
                print(f"   📉 Total Egresos: Bs {total_egresos:,.2f}")
                print(f"   💰 Saldo Neto: Bs {saldo_neto:,.2f}")
                print(f"   📊 Total Movimientos: {len(movimientos_financieros)}\n")
                
                return movimientos_financieros
            else:
                print("ℹ️ No se encontraron movimientos financieros para el período")
                return []
            
        except Exception as e:
            print(f"❌ Error crítico en get_reporte_consolidado: {e}")
            import traceback
            traceback.print_exc()
            return []
    
    def _parse_fecha_dd_mm_yyyy(self, fecha_str: str) -> datetime:
        """Convierte fecha DD/MM/YYYY a objeto datetime para ordenamiento"""
        try:
            return datetime.strptime(fecha_str, "%d/%m/%Y")
        except:
            return datetime(2024, 1, 1)  # Fecha por defecto
    
    def get_analisis_financiero_avanzado(self, fecha_desde: str, fecha_hasta: str) -> Dict[str, Any]:
        """
        ✅ NUEVO: Genera análisis financiero avanzado para complementar el reporte
        """
        try:
            fecha_desde_sql = self._convertir_fecha_sql(fecha_desde, es_fecha_final=False)
            fecha_hasta_sql = self._convertir_fecha_sql(fecha_hasta, es_fecha_final=True)
            
            # Análisis de ingresos por categoría
            query_ingresos_categoria = """
            SELECT 
                'Ventas Farmacia' as categoria,
                COUNT(*) as transacciones,
                SUM(dv.Cantidad_Unitario * dv.Precio_Unitario) as valor_total,
                AVG(dv.Cantidad_Unitario * dv.Precio_Unitario) as valor_promedio
            FROM Ventas v
            INNER JOIN DetallesVentas dv ON v.id = dv.Id_Venta
            WHERE v.Fecha >= ? AND v.Fecha <= ?
            
            UNION ALL
            
            SELECT 
                'Consultas Médicas' as categoria,
                COUNT(*) as transacciones,
                SUM(CASE 
                    WHEN c.Tipo_Consulta = 'Emergencia' THEN COALESCE(e.Precio_Emergencia, 50.00)
                    ELSE COALESCE(e.Precio_Normal, 30.00) 
                END) as valor_total,
                AVG(CASE 
                    WHEN c.Tipo_Consulta = 'Emergencia' THEN COALESCE(e.Precio_Emergencia, 50.00)
                    ELSE COALESCE(e.Precio_Normal, 30.00) 
                END) as valor_promedio
            FROM Consultas c
            INNER JOIN Especialidad e ON c.Id_Especialidad = e.id
            WHERE c.Fecha >= ? AND c.Fecha <= ?
            """
            
            params_ingresos = (fecha_desde_sql, fecha_hasta_sql) * 2
            analisis_ingresos = self._execute_query(query_ingresos_categoria, params_ingresos)
            
            # Análisis de egresos por categoría
            query_egresos_categoria = """
            SELECT 
                'Compras Farmacia' as categoria,
                COUNT(*) as transacciones,
                SUM(dc.Precio_Unitario) as valor_total,
                AVG(dc.Precio_Unitario) as valor_promedio
            FROM Compra c
            INNER JOIN DetalleCompra dc ON c.id = dc.Id_Compra
            WHERE c.Fecha >= ? AND c.Fecha <= ?
            
            UNION ALL
            
            SELECT 
                'Gastos Operativos' as categoria,
                COUNT(*) as transacciones,
                SUM(g.Monto) as valor_total,
                AVG(g.Monto) as valor_promedio
            FROM Gastos g
            WHERE g.Fecha >= ? AND g.Fecha <= ?
            """
            
            params_egresos = (fecha_desde_sql, fecha_hasta_sql) * 2
            analisis_egresos = self._execute_query(query_egresos_categoria, params_egresos)
            
            return {
                'ingresos_por_categoria': analisis_ingresos or [],
                'egresos_por_categoria': analisis_egresos or [],
                'fecha_analisis': datetime.now().strftime("%d/%m/%Y %H:%M"),
                'periodo_desde': fecha_desde,
                'periodo_hasta': fecha_hasta
            }
            
        except Exception as e:
            print(f"⚠️ Error en análisis financiero avanzado: {e}")
            return {
                'ingresos_por_categoria': [],
                'egresos_por_categoria': [],
                'fecha_analisis': datetime.now().strftime("%d/%m/%Y %H:%M"),
                'periodo_desde': fecha_desde,
                'periodo_hasta': fecha_hasta
            }
    
    # ===============================
    # MÉTODOS DE UTILIDAD
    # ===============================
    
    def _convertir_fecha_sql(self, fecha_str: str, es_fecha_final: bool = False) -> str:
        """
        Convierte fecha de DD/MM/YYYY a YYYY-MM-DD para SQL Server
        ✅ CORREGIDO: Ahora incluye correctamente el día final
        
        Args:
            fecha_str: Fecha en formato DD/MM/YYYY
            es_fecha_final: Si True, agrega 23:59:59 para incluir TODO el día
            
        Returns:
            Fecha en formato YYYY-MM-DD [HH:MM:SS]
        """
        try:
            if not fecha_str or fecha_str.strip() == "":
                if es_fecha_final:
                    return datetime.now().strftime("%Y-%m-%d 23:59:59")
                else:
                    return datetime.now().strftime("%Y-%m-%d 00:00:00")
            
            # Parsear DD/MM/YYYY
            dia, mes, anio = fecha_str.split('/')
            
            # Validar componentes
            dia = int(dia)
            mes = int(mes)
            anio = int(anio)
            
            if dia < 1 or dia > 31:
                raise ValueError("Día inválido")
            if mes < 1 or mes > 12:
                raise ValueError("Mes inválido")
            if anio < 2020 or anio > 2030:
                raise ValueError("Año inválido")
            
            # ✅ CORRECCIÓN CRÍTICA: Para fecha final, sumar 1 día y usar 00:00:00
            if es_fecha_final:
                # Convertir a datetime para sumar 1 día correctamente
                fecha_obj = datetime(anio, mes, dia)
                fecha_obj = fecha_obj + timedelta(days=1)  # ✅ Sumar 1 día
                return fecha_obj.strftime("%Y-%m-%d 00:00:00")
            else:
                return f"{anio:04d}-{mes:02d}-{dia:02d} 00:00:00"
            
        except Exception as e:
            print(f"⚠️ Error convirtiendo fecha '{fecha_str}': {e}")
            # Fallback: fecha actual
            if es_fecha_final:
                fecha_obj = datetime.now() + timedelta(days=1)
                return fecha_obj.strftime("%Y-%m-%d 00:00:00")
            else:
                return datetime.now().strftime("%Y-%m-%d 00:00:00")
    
    def get_resumen_periodo(self, fecha_desde: str, fecha_hasta: str) -> Dict[str, Any]:
        """Obtiene resumen general del período"""
        try:
            fecha_desde_sql = self._convertir_fecha_sql(fecha_desde)
            fecha_hasta_sql = self._convertir_fecha_sql(fecha_hasta)
            
            query = """
            SELECT 
                -- INGRESOS
                COALESCE(SUM(CASE WHEN tipo_operacion = 'INGRESO' THEN monto ELSE 0 END), 0) as total_ingresos,
                -- EGRESOS  
                COALESCE(SUM(CASE WHEN tipo_operacion = 'EGRESO' THEN monto ELSE 0 END), 0) as total_egresos,
                -- TRANSACCIONES
                COUNT(*) as total_transacciones
            FROM (
                SELECT 'INGRESO' as tipo_operacion, Total as monto FROM Ventas WHERE Fecha >= ? AND Fecha <= ?
                UNION ALL
                SELECT 'EGRESO' as tipo_operacion, Total as monto FROM Compra WHERE Fecha >= ? AND Fecha <= ?
                UNION ALL
                SELECT 'EGRESO' as tipo_operacion, Monto as monto FROM Gastos WHERE Fecha >= ? AND Fecha <= ?
            ) consolidado
            """
            
            params = (fecha_desde_sql, fecha_hasta_sql) * 3
            resultado = self._execute_query(query, params, fetch_one=True)
            
            if resultado:
                return {
                    'total_ingresos': float(resultado.get('total_ingresos', 0)),
                    'total_egresos': float(resultado.get('total_egresos', 0)),
                    'utilidad_neta': float(resultado.get('total_ingresos', 0)) - float(resultado.get('total_egresos', 0)),
                    'total_transacciones': int(resultado.get('total_transacciones', 0))
                }
            else:
                return {
                    'total_ingresos': 0.0,
                    'total_egresos': 0.0,
                    'utilidad_neta': 0.0,
                    'total_transacciones': 0
                }
                
        except Exception as e:
            print(f"⚠️ Error obteniendo resumen del período: {e}")
            return {
                'total_ingresos': 0.0,
                'total_egresos': 0.0,
                'utilidad_neta': 0.0,
                'total_transacciones': 0
            }
    
    def verificar_datos_disponibles(self, tipo_reporte: int, fecha_desde: str, fecha_hasta: str) -> bool:
        """Verifica si hay datos disponibles para el reporte solicitado - ✅ CORREGIDO"""
        try:
            fecha_desde_sql = self._convertir_fecha_sql(fecha_desde, es_fecha_final=False)
            fecha_hasta_sql = self._convertir_fecha_sql(fecha_hasta, es_fecha_final=True)  # ✅ Suma 1 día
            
            print(f"🔍 Verificando datos disponibles para tipo {tipo_reporte}")
            print(f"   Período SQL: {fecha_desde_sql} a {fecha_hasta_sql}")
            
            tablas_por_tipo = {
                1: ("Ventas", "v.Fecha"),
                2: ("Productos", None),  # Inventario no depende de fechas
                3: ("Compra", "c.Fecha"),
                4: ("Consultas", "c.Fecha"),
                5: ("Laboratorio", "l.Fecha"),
                6: ("Enfermeria", "e.Fecha"),
                7: ("Gastos", "g.Fecha"),
                8: ("Ventas", "v.Fecha")  # Para consolidado, verificamos al menos ventas
            }
            
            if tipo_reporte not in tablas_por_tipo:
                print(f"⚠️ Tipo de reporte inválido: {tipo_reporte}")
                return False
            
            tabla_info = tablas_por_tipo[tipo_reporte]
            tabla = tabla_info[0]
            campo_fecha = tabla_info[1]
            
            if tipo_reporte == 2:  # Inventario - sin filtro de fechas
                # ✅ CORRECCIÓN: Ya no buscar Stock_Caja
                query = """
                SELECT COUNT(*) as total 
                FROM Productos p
                WHERE EXISTS (
                    SELECT 1 FROM Lote l 
                    WHERE l.Id_Producto = p.id 
                    AND l.Cantidad_Unitario > 0
                )
                """
                resultado = self._execute_query(query, fetch_one=True)
                
            elif tipo_reporte == 8:  # Consolidado - verificar múltiples tablas
                # ✅ Verificar si hay al menos UN movimiento en CUALQUIER tabla
                query = """
                SELECT 
                    (SELECT COUNT(*) FROM Ventas WHERE Fecha >= ? AND Fecha < ?) +
                    (SELECT COUNT(*) FROM Consultas WHERE Fecha >= ? AND Fecha < ?) +
                    (SELECT COUNT(*) FROM Laboratorio WHERE Fecha >= ? AND Fecha < ?) +
                    (SELECT COUNT(*) FROM Enfermeria WHERE Fecha >= ? AND Fecha < ?) +
                    (SELECT COUNT(*) FROM Compra WHERE Fecha >= ? AND Fecha < ?) +
                    (SELECT COUNT(*) FROM Gastos WHERE Fecha >= ? AND Fecha < ?)
                    as total
                """
                params = (fecha_desde_sql, fecha_hasta_sql) * 6
                resultado = self._execute_query(query, params, fetch_one=True)
                
            else:  # Otros reportes con filtro de fecha
                # Obtener el alias correcto según la tabla
                alias_map = {
                    "Ventas": "v",
                    "Compra": "c",
                    "Consultas": "c",
                    "Laboratorio": "l",
                    "Enfermeria": "e",
                    "Gastos": "g"
                }
                alias = alias_map.get(tabla, "t")
                
                query = f"""
                SELECT COUNT(*) as total 
                FROM {tabla} {alias}
                WHERE {alias}.Fecha >= ? AND {alias}.Fecha < ?
                """
                resultado = self._execute_query(query, (fecha_desde_sql, fecha_hasta_sql), fetch_one=True)
            
            total = resultado.get('total', 0) if resultado else 0
            tiene_datos = total > 0
            
            print(f"   {'✅' if tiene_datos else '❌'} Registros encontrados: {total}")
            
            return tiene_datos
            
        except Exception as e:
            print(f"⚠️ Error verificando datos disponibles: {e}")
            import traceback
            traceback.print_exc()
            return False
    
    # ===============================
    # INVALIDACIÓN DE CACHÉ
    # ===============================
    
    def _invalidate_cache_after_modification(self):
        """Invalida cachés de reportes después de modificaciones"""
        cache_types = [
            'reporte_ventas', 'reporte_inventario', 'reporte_compras',
            'reporte_consultas', 'reporte_laboratorio', 'reporte_enfermeria',
            'reporte_gastos', 'reporte_ingresos_egresos'  # ✅ Actualizado el nombre del caché
        ]
        invalidate_after_update(cache_types)
        print("🗑️ Cachés de reportes invalidados")