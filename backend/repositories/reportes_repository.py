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
    
    @cached_query('reporte_ventas', ttl=300)
    def get_reporte_ventas(self, fecha_desde: str, fecha_hasta: str) -> List[Dict[str, Any]]:
        """
        Genera reporte de ventas de farmacia
        
        Args:
            fecha_desde: Fecha inicio en formato DD/MM/YYYY
            fecha_hasta: Fecha fin en formato DD/MM/YYYY
        """
        # Convertir fechas del formato DD/MM/YYYY a YYYY-MM-DD
        fecha_desde_sql = self._convertir_fecha_sql(fecha_desde, es_fecha_final=False)
        fecha_hasta_sql = self._convertir_fecha_sql(fecha_hasta, es_fecha_final=True)
        
        query = """
        SELECT 
            FORMAT(v.Fecha, 'dd/MM/yyyy') as fecha,
            'V' + RIGHT('000' + CAST(v.id AS VARCHAR), 3) as numeroVenta,
            STRING_AGG(p.Nombre + ' x' + CAST(dv.Cantidad_Unitario AS VARCHAR), ', ') as descripcion,
            SUM(dv.Cantidad_Unitario) as cantidad,
            v.Total as valor,
            u.Nombre + ' ' + u.Apellido_Paterno as usuario
        FROM Ventas v
        INNER JOIN DetallesVentas dv ON v.id = dv.Id_Venta
        INNER JOIN Lote l ON dv.Id_Lote = l.id
        INNER JOIN Productos p ON l.Id_Producto = p.id
        INNER JOIN Usuario u ON v.Id_Usuario = u.id
        WHERE v.Fecha >= ? AND v.Fecha <= ?
        GROUP BY v.id, v.Fecha, v.Total, u.Nombre, u.Apellido_Paterno
        ORDER BY v.Fecha DESC, v.id DESC
        """
        
        return self._execute_query(query, (fecha_desde_sql, fecha_hasta_sql))
    
    # ===============================
    # REPORTES DE INVENTARIO (TIPO 2)
    # ===============================
        
    @cached_query('reporte_inventario', ttl=600)
    def get_reporte_inventario(self, fecha_desde: str = "", fecha_hasta: str = "") -> List[Dict[str, Any]]:
        """Genera reporte de inventario con PRECIOS REALES - NO más "---" """
        query = """
        SELECT 
            FORMAT(GETDATE(), 'dd/MM/yyyy') as fecha,
            p.Nombre as descripcion,
            m.Nombre as marca,
            
            -- ✅ STOCK REAL - Suma de todos los lotes
            (SELECT ISNULL(SUM(l.Cantidad_Unitario), 0) 
            FROM Lote l 
            WHERE l.Id_Producto = p.id) as cantidad,
            
            -- ✅ LOTES ACTIVOS - Solo lotes con stock
            (SELECT COUNT(*) 
            FROM Lote l 
            WHERE l.Id_Producto = p.id AND l.Cantidad_Unitario > 0) as lotes,
            
            -- ✅ PRECIO UNITARIO REAL - Nunca NULL, siempre un valor
            CASE 
                WHEN p.Precio_venta IS NULL OR p.Precio_venta = 0 
                THEN COALESCE(p.Precio_compra, 0)  -- Usar precio de compra si no hay precio de venta
                ELSE p.Precio_venta
            END as precioUnitario,
            
            -- ✅ FECHA VENCIMIENTO MÁS PRÓXIMA - Formato correcto
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
            
            -- ✅ VALOR TOTAL REAL - Stock × Precio de venta
            ((SELECT ISNULL(SUM(l.Cantidad_Unitario), 0) 
            FROM Lote l 
            WHERE l.Id_Producto = p.id) * 
            CASE 
                WHEN p.Precio_venta IS NULL OR p.Precio_venta = 0 
                THEN COALESCE(p.Precio_compra, 0)
                ELSE p.Precio_venta
            END) as valor,
            
            -- Campos adicionales
            p.Codigo as codigo,
            p.Unidad_Medida as unidad,
            
            -- ✅ ESTADO BASADO EN VENCIMIENTO REAL
            CASE 
                WHEN EXISTS (SELECT 1 FROM Lote l WHERE l.Id_Producto = p.id 
                            AND l.Cantidad_Unitario > 0 
                            AND l.Fecha_Vencimiento IS NOT NULL
                            AND l.Fecha_Vencimiento <= DATEADD(MONTH, 3, GETDATE()))
                THEN 'Próximo a vencer'
                WHEN NOT EXISTS (SELECT 1 FROM Lote l WHERE l.Id_Producto = p.id AND l.Cantidad_Unitario > 0)
                THEN 'Sin stock'
                ELSE 'Normal'
            END as estado
            
        FROM Productos p
        INNER JOIN Marca m ON p.ID_Marca = m.id
        WHERE EXISTS (SELECT 1 FROM Lote l WHERE l.Id_Producto = p.id)  -- Solo productos que tienen lotes
        ORDER BY 
            CASE WHEN EXISTS (SELECT 1 FROM Lote l WHERE l.Id_Producto = p.id AND l.Cantidad_Unitario > 0) 
                THEN 0 ELSE 1 END,  -- Productos con stock primero
            valor DESC, p.Nombre
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
        """Laboratorio: fecha, tipoAnalisis, descripción, paciente, técnico, precio"""
        fecha_desde_sql = self._convertir_fecha_sql(fecha_desde, es_fecha_final=False)
        fecha_hasta_sql = self._convertir_fecha_sql(fecha_hasta, es_fecha_final=True)
        
        query = """
        SELECT 
            FORMAT(l.Fecha, 'dd/MM/yyyy') as fecha,
            COALESCE(ta.Nombre, 'Análisis General') as tipoAnalisis,
            COALESCE(ta.Descripcion, COALESCE(ta.Nombre, 'Análisis de laboratorio')) as descripcion,
            CONCAT(p.Nombre, ' ', p.Apellido_Paterno, 
                CASE WHEN p.Apellido_Materno IS NOT NULL AND p.Apellido_Materno != '' 
                        THEN ' ' + p.Apellido_Materno 
                        ELSE '' END) as paciente,
            CASE 
                WHEN t.id IS NOT NULL THEN CONCAT(t.Nombre, ' ', t.Apellido_Paterno,
                    CASE WHEN t.Apellido_Materno IS NOT NULL AND t.Apellido_Materno != '' 
                        THEN ' ' + t.Apellido_Materno 
                        ELSE '' END)
                ELSE 'Sin asignar'
            END as tecnico,
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
    
    @cached_query('reporte_enfermeria', ttl=300)
    def get_reporte_enfermeria(self, fecha_desde: str, fecha_hasta: str) -> List[Dict[str, Any]]:
        """Enfermería: CONSULTA SIMPLIFICADA con campos que SÍ EXISTEN"""
        fecha_desde_sql = self._convertir_fecha_sql(fecha_desde, es_fecha_final=False)
        fecha_hasta_sql = self._convertir_fecha_sql(fecha_hasta, es_fecha_final=True)
        
        # ✅ CONSULTA CORREGIDA - Solo campos que existen realmente
        query = """
        SELECT 
            FORMAT(e.Fecha, 'dd/MM/yyyy') as fecha,
            
            -- ✅ PROCEDIMIENTO - Solo de tabla Tipos_Procedimientos
            COALESCE(tp.Nombre, 'Procedimiento General') as tipoProcedimiento,
            
            -- ✅ DESCRIPCIÓN - Solo de tabla Tipos_Procedimientos  
            COALESCE(tp.Descripcion, tp.Nombre, 'Procedimiento de enfermería') as descripcion,
            
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
        """Gastos: fecha, tipo de gasto, descripción, monto, proveedor - EXACTO"""
        fecha_desde_sql = self._convertir_fecha_sql(fecha_desde, es_fecha_final=False)
        fecha_hasta_sql = self._convertir_fecha_sql(fecha_hasta, es_fecha_final=True)
        
        query = """
        SELECT 
            FORMAT(g.Fecha, 'dd/MM/yyyy') as fecha,
            tg.Nombre as categoria,
            g.Descripcion as descripcion,
            g.Monto as valor,
            COALESCE(g.Proveedor, 'Sin proveedor') as proveedor,
            CONCAT(u.Nombre, ' ', u.Apellido_Paterno) as registrado_por,
            1 as cantidad
        FROM Gastos g
        INNER JOIN Tipo_Gastos tg ON g.ID_Tipo = tg.id
        INNER JOIN Usuario u ON g.Id_RegistradoPor = u.id
        WHERE g.Fecha >= ? AND g.Fecha <= ?
        ORDER BY g.Fecha DESC, g.id DESC
        """
        return self._execute_query(query, (fecha_desde_sql, fecha_hasta_sql))
    
    # ===============================
    # REPORTE CONSOLIDADO (TIPO 8)
    # ===============================
    
    @cached_query('reporte_consolidado', ttl=600)
    def get_reporte_consolidado(self, fecha_desde: str, fecha_hasta: str) -> List[Dict[str, Any]]:
        """Genera reporte financiero consolidado"""

        fecha_desde_sql = self._convertir_fecha_sql(fecha_desde, es_fecha_final=False)
        fecha_hasta_sql = self._convertir_fecha_sql(fecha_hasta, es_fecha_final=True)
        
        # Consulta UNION para consolidar todos los ingresos y egresos
        query = """
        -- VENTAS (INGRESOS)
        SELECT 
            FORMAT(GETDATE(), 'dd/MM/yyyy') as fecha,
            'INGRESO' as tipo,
            'Ventas de Farmacia' as descripcion,
            COUNT(*) as cantidad,
            SUM(Total) as valor
        FROM Ventas 
        WHERE Fecha >= ? AND Fecha <= ?
        
        UNION ALL
        
        -- CONSULTAS (INGRESOS)
        SELECT 
            FORMAT(GETDATE(), 'dd/MM/yyyy') as fecha,
            'INGRESO' as tipo,
            'Consultas Médicas' as descripcion,
            COUNT(*) as cantidad,
            SUM(CASE WHEN c.Tipo_Consulta = 'Emergencia' THEN e.Precio_Emergencia 
                     ELSE e.Precio_Normal END) as valor
        FROM Consultas c
        INNER JOIN Especialidad e ON c.Id_Especialidad = e.id
        WHERE c.Fecha >= ? AND c.Fecha <= ?
        
        UNION ALL
        
        -- LABORATORIO (INGRESOS)
        SELECT 
            FORMAT(GETDATE(), 'dd/MM/yyyy') as fecha,
            'INGRESO' as tipo,
            'Análisis de Laboratorio' as descripcion,
            COUNT(*) as cantidad,
            SUM(CASE WHEN l.Tipo = 'Emergencia' THEN COALESCE(ta.Precio_Emergencia, 25.00)
                     ELSE COALESCE(ta.Precio_Normal, 20.00) END) as valor
        FROM Laboratorio l
        LEFT JOIN Tipos_Analisis ta ON l.Id_Tipo_Analisis = ta.id
        WHERE l.Fecha >= ? AND l.Fecha <= ?
        
        UNION ALL
        
        -- ENFERMERÍA (INGRESOS)
        SELECT 
            FORMAT(GETDATE(), 'dd/MM/yyyy') as fecha,
            'INGRESO' as tipo,
            'Procedimientos de Enfermería' as descripcion,
            COUNT(*) as cantidad,
            SUM((CASE WHEN e.Tipo = 'Emergencia' THEN tp.Precio_Emergencia 
                      ELSE tp.Precio_Normal END) * e.Cantidad) as valor
        FROM Enfermeria e
        INNER JOIN Tipos_Procedimientos tp ON e.Id_Procedimiento = tp.id
        WHERE e.Fecha >= ? AND e.Fecha <= ?
        
        UNION ALL
        
        -- COMPRAS (EGRESOS)
        SELECT 
            FORMAT(GETDATE(), 'dd/MM/yyyy') as fecha,
            'EGRESO' as tipo,
            'Compras de Farmacia' as descripcion,
            COUNT(*) as cantidad,
            -SUM(Total) as valor
        FROM Compra
        WHERE Fecha >= ? AND Fecha <= ?
        
        UNION ALL
        
        -- GASTOS (EGRESOS)
        SELECT 
            FORMAT(GETDATE(), 'dd/MM/yyyy') as fecha,
            'EGRESO' as tipo,
            'Gastos Operativos' as descripcion,
            COUNT(*) as cantidad,
            -SUM(Monto) as valor
        FROM Gastos
        WHERE Fecha >= ? AND Fecha <= ?
        
        ORDER BY tipo DESC, valor DESC
        """
        
        params = (fecha_desde_sql, fecha_hasta_sql) * 6  # 6 consultas x 2 parámetros cada una
        return self._execute_query(query, params)
    
    # ===============================
    # MÉTODOS DE UTILIDAD
    # ===============================
    
    def _convertir_fecha_sql(self, fecha_str: str, es_fecha_final: bool = False) -> str:
        """
        Convierte fecha de DD/MM/YYYY a YYYY-MM-DD para SQL Server
        
        Args:
            fecha_str: Fecha en formato DD/MM/YYYY
            es_fecha_final: Si True, agrega 23:59:59 para incluir todo el día
            
        Returns:
            Fecha en formato YYYY-MM-DD [HH:MM:SS]
        """
        try:
            if not fecha_str or fecha_str.strip() == "":
                return datetime.now().strftime("%Y-%m-%d")
            
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
            
            # ✅ CORRECCIÓN: Agregar hora según si es fecha final
            if es_fecha_final:
                return f"{anio:04d}-{mes:02d}-{dia:02d} 23:59:59"
            else:
                return f"{anio:04d}-{mes:02d}-{dia:02d} 00:00:00"
            
        except Exception as e:
            print(f"⚠️ Error convirtiendo fecha '{fecha_str}': {e}")
            # Fallback: fecha actual
            if es_fecha_final:
                return datetime.now().strftime("%Y-%m-%d 23:59:59")
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
        """Verifica si hay datos disponibles para el reporte solicitado"""
        try:
            fecha_desde_sql = self._convertir_fecha_sql(fecha_desde)
            fecha_hasta_sql = self._convertir_fecha_sql(fecha_hasta)
            
            tablas_por_tipo = {
                1: "Ventas",
                2: "Productos", 
                3: "Compra",
                4: "Consultas",
                5: "Laboratorio",
                6: "Enfermeria",
                7: "Gastos",
                8: "Ventas"  # Para consolidado, verificamos al menos una tabla
            }
            
            tabla = tablas_por_tipo.get(tipo_reporte, "Ventas")
            
            if tipo_reporte == 2:  # Inventario no depende de fechas
                query = f"SELECT COUNT(*) as total FROM {tabla} WHERE Stock_Caja + Stock_Unitario > 0"
                resultado = self._execute_query(query, fetch_one=True)
            else:
                query = f"SELECT COUNT(*) as total FROM {tabla} WHERE Fecha >= ? AND Fecha <= ?"
                resultado = self._execute_query(query, (fecha_desde_sql, fecha_hasta_sql), fetch_one=True)
            
            return resultado.get('total', 0) > 0 if resultado else False
            
        except Exception as e:
            print(f"⚠️ Error verificando datos disponibles: {e}")
            return False
    
    # ===============================
    # INVALIDACIÓN DE CACHÉ
    # ===============================
    
    def _invalidate_cache_after_modification(self):
        """Invalida cachés de reportes después de modificaciones"""
        cache_types = [
            'reporte_ventas', 'reporte_inventario', 'reporte_compras',
            'reporte_consultas', 'reporte_laboratorio', 'reporte_enfermeria',
            'reporte_gastos', 'reporte_consolidado'
        ]
        invalidate_after_update(cache_types)
        print("🗑️ Cachés de reportes invalidados")