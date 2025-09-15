from typing import List, Dict, Any, Optional
from datetime import datetime, timedelta
from decimal import Decimal

from ..core.base_repository import BaseRepository
from ..core.cache_system import cached_query
from ..core.utils import (
    get_current_datetime, calculate_percentage, safe_float
)

class EstadisticaRepository(BaseRepository):
    """Repository para estadísticas complejas y reportes del sistema"""
    
    def __init__(self):
        super().__init__('', 'estadisticas')  # No tiene tabla principal
        print("📊 EstadisticaRepository inicializado")
    
    # ===============================
    # IMPLEMENTACIÓN ABSTRACTA (N/A)
    # ===============================
    
    def get_active(self) -> List[Dict[str, Any]]:
        """No aplica para estadísticas"""
        return []
    
    # ===============================
    # DASHBOARD PRINCIPAL
    # ===============================
    
    @cached_query('dashboard_general', ttl=300)
    def get_dashboard_summary(self) -> Dict[str, Any]:
        """Resumen completo para dashboard principal"""
        
        # Totales generales
        totales_query = """
        SELECT 
            (SELECT COUNT(*) FROM Pacientes) as total_pacientes,
            (SELECT COUNT(*) FROM Doctores) as total_doctores,
            (SELECT COUNT(*) FROM Trabajadores) as total_trabajadores,
            (SELECT COUNT(*) FROM Usuario WHERE Estado = 1) as total_usuarios_activos,
            (SELECT COUNT(*) FROM Productos WHERE (Stock_Caja + Stock_Unitario) > 0) as productos_stock
        """
        
        # Actividad del día
        hoy = datetime.now().replace(hour=0, minute=0, second=0, microsecond=0)
        manana = hoy + timedelta(days=1)
        
        hoy_query = """
        SELECT 
            (SELECT COUNT(*) FROM Consultas WHERE Fecha BETWEEN ? AND ?) as consultas_hoy,
            (SELECT COUNT(*) FROM Ventas WHERE Fecha BETWEEN ? AND ?) as ventas_hoy,
            (SELECT COALESCE(SUM(Total), 0) FROM Ventas WHERE Fecha BETWEEN ? AND ?) as ingresos_hoy,
            (SELECT COALESCE(SUM(Monto), 0) FROM Gastos WHERE Fecha BETWEEN ? AND ?) as gastos_hoy,
            (SELECT COUNT(*) FROM Laboratorio l 
             INNER JOIN Pacientes p ON l.Id_Paciente = p.id) as examenes_pendientes
        """
        
        # Alertas críticas
        alertas_query = """
        SELECT 
            (SELECT COUNT(*) FROM Productos WHERE (Stock_Caja + Stock_Unitario) <= 10) as productos_bajo_stock,
            (SELECT COUNT(*) FROM Lote WHERE Fecha_Vencimiento <= DATEADD(MONTH, 3, GETDATE()) 
             AND (Cantidad_Caja + Cantidad_Unitario) > 0) as productos_por_vencer,
            (SELECT COUNT(*) FROM Lote WHERE Fecha_Vencimiento < GETDATE() 
             AND (Cantidad_Caja + Cantidad_Unitario) > 0) as productos_vencidos,
            (SELECT COUNT(*) FROM Laboratorio WHERE Id_Trabajador IS NULL) as examenes_sin_asignar
        """
        
        totales = self._execute_query(totales_query, fetch_one=True)
        actividad_hoy = self._execute_query(hoy_query, (hoy, manana) * 4, fetch_one=True)
        alertas = self._execute_query(alertas_query, fetch_one=True)
        
        return {
            'fecha_actualizacion': datetime.now(),
            'totales_sistema': totales,
            'actividad_hoy': actividad_hoy,
            'alertas_criticas': alertas,
            'balance_hoy': safe_float(actividad_hoy.get('ingresos_hoy', 0)) - safe_float(actividad_hoy.get('gastos_hoy', 0))
        }
    
    # ===============================
    # ESTADÍSTICAS FINANCIERAS
    # ===============================
    
    @cached_query('finanzas_resumen', ttl=600)
    def get_financial_summary(self, months: int = 12) -> Dict[str, Any]:
        """Resumen financiero completo"""
        
        fecha_inicio = datetime.now() - timedelta(days=months*30)
        
        # Ingresos por ventas
        ingresos_query = """
        SELECT 
            SUM(Total) as total_ingresos,
            COUNT(*) as total_ventas,
            AVG(Total) as venta_promedio
        FROM Ventas 
        WHERE Fecha >= ?
        """
        
        # Gastos totales
        gastos_query = """
        SELECT 
            SUM(Monto) as total_gastos,
            COUNT(*) as total_transacciones,
            AVG(Monto) as gasto_promedio
        FROM Gastos 
        WHERE Fecha >= ?
        """
        
        # Gastos en compras
        compras_query = """
        SELECT 
            SUM(Total) as total_compras,
            COUNT(*) as numero_compras,
            AVG(Total) as compra_promedio
        FROM Compra 
        WHERE Fecha >= ?
        """
        
        # Ingresos por consultas (estimado)
        consultas_query = """
        SELECT 
            SUM(e.Precio_Normal) as ingresos_consultas_estimados,
            COUNT(c.id) as total_consultas
        FROM Consultas c
        INNER JOIN Especialidad e ON c.Id_Especialidad = e.id
        WHERE c.Fecha >= ?
        """
        
        # Tendencia mensual
        tendencia_query = """
        SELECT 
            FORMAT(fecha_mes, 'yyyy-MM') as mes,
            COALESCE(ingresos, 0) as ingresos_mes,
            COALESCE(gastos, 0) as gastos_mes,
            COALESCE(ingresos, 0) - COALESCE(gastos, 0) as balance_mes
        FROM (
            SELECT DATEFROMPARTS(YEAR(Fecha), MONTH(Fecha), 1) as fecha_mes,
                   SUM(Total) as ingresos,
                   0 as gastos
            FROM Ventas 
            WHERE Fecha >= ?
            GROUP BY YEAR(Fecha), MONTH(Fecha)
            
            UNION ALL
            
            SELECT DATEFROMPARTS(YEAR(Fecha), MONTH(Fecha), 1) as fecha_mes,
                   0 as ingresos,
                   SUM(Monto) as gastos
            FROM Gastos 
            WHERE Fecha >= ?
            GROUP BY YEAR(Fecha), MONTH(Fecha)
        ) movimientos
        GROUP BY fecha_mes
        ORDER BY fecha_mes DESC
        """
        
        ingresos = self._execute_query(ingresos_query, (fecha_inicio,), fetch_one=True)
        gastos = self._execute_query(gastos_query, (fecha_inicio,), fetch_one=True)
        compras = self._execute_query(compras_query, (fecha_inicio,), fetch_one=True)
        consultas = self._execute_query(consultas_query, (fecha_inicio,), fetch_one=True)
        tendencia = self._execute_query(tendencia_query, (fecha_inicio, fecha_inicio))
        
        # Calcular métricas
        total_ingresos = safe_float(ingresos.get('total_ingresos', 0))
        total_gastos = safe_float(gastos.get('total_gastos', 0))
        total_compras = safe_float(compras.get('total_compras', 0))
        
        balance_neto = total_ingresos - total_gastos
        margen_beneficio = calculate_percentage(balance_neto, total_ingresos) if total_ingresos > 0 else 0
        
        return {
            'periodo_meses': months,
            'ingresos': ingresos,
            'gastos_operativos': gastos,
            'gastos_compras': compras,
            'ingresos_consultas': consultas,
            'resumen': {
                'total_ingresos': total_ingresos,
                'total_gastos': total_gastos,
                'total_compras': total_compras,
                'balance_neto': balance_neto,
                'margen_beneficio': margen_beneficio
            },
            'tendencia_mensual': tendencia
        }
    
    def get_income_breakdown(self, months: int = 3) -> Dict[str, Any]:
        """Desglose detallado de ingresos"""
        fecha_inicio = datetime.now() - timedelta(days=months*30)
        
        # Ingresos por ventas farmacia
        ventas_farmacia_query = """
        SELECT 
            SUM(v.Total) as ingresos_farmacia,
            COUNT(v.id) as numero_ventas,
            AVG(v.Total) as venta_promedio
        FROM Ventas v
        WHERE v.Fecha >= ?
        """
        
        # Ingresos por consultas por especialidad
        consultas_especialidad_query = """
        SELECT 
            e.Nombre as especialidad,
            COUNT(c.id) as numero_consultas,
            SUM(e.Precio_Normal) as ingresos_estimados,
            AVG(e.Precio_Normal) as precio_promedio,
            CONCAT('Dr. ', d.Nombre, ' ', d.Apellido_Paterno) as doctor_principal
        FROM Consultas c
        INNER JOIN Especialidad e ON c.Id_Especialidad = e.id
        INNER JOIN Doctores d ON e.Id_Doctor = d.id
        WHERE c.Fecha >= ?
        GROUP BY e.id, e.Nombre, e.Precio_Normal, d.Nombre, d.Apellido_Paterno
        ORDER BY ingresos_estimados DESC
        """
        
        # Ingresos por laboratorio
        laboratorio_ingresos_query = """
        SELECT 
            SUM(Precio_Normal) as ingresos_lab_estimados,
            COUNT(*) as examenes_realizados,
            AVG(Precio_Normal) as precio_promedio_examen
        FROM Laboratorio
        WHERE id IN (SELECT DISTINCT Id_Laboratorio FROM Laboratorio)
        """
        
        ventas = self._execute_query(ventas_farmacia_query, (fecha_inicio,), fetch_one=True)
        consultas = self._execute_query(consultas_especialidad_query, (fecha_inicio,))
        laboratorio = self._execute_query(laboratorio_ingresos_query, fetch_one=True)
        
        return {
            'periodo_meses': months,
            'ventas_farmacia': ventas,
            'consultas_por_especialidad': consultas,
            'ingresos_laboratorio': laboratorio
        }
    
    # ===============================
    # ESTADÍSTICAS DE PACIENTES
    # ===============================
    
    @cached_query('stats_pacientes_completas', ttl=900)
    def get_patient_analytics(self) -> Dict[str, Any]:
        """Análisis completo de pacientes"""
        
        # Distribución por edad
        edad_query = """
        SELECT 
            CASE 
                WHEN Edad BETWEEN 0 AND 17 THEN 'Pediátrico (0-17)'
                WHEN Edad BETWEEN 18 AND 64 THEN 'Adulto (18-64)'
                WHEN Edad >= 65 THEN 'Adulto Mayor (65+)'
            END as grupo_edad,
            COUNT(*) as cantidad,
            ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM Pacientes), 2) as porcentaje
        FROM Pacientes
        GROUP BY CASE 
                    WHEN Edad BETWEEN 0 AND 17 THEN 'Pediátrico (0-17)'
                    WHEN Edad BETWEEN 18 AND 64 THEN 'Adulto (18-64)'
                    WHEN Edad >= 65 THEN 'Adulto Mayor (65+)'
                 END
        """
        
        # Pacientes más activos
        pacientes_activos_query = """
        SELECT TOP 10
            CONCAT(p.Nombre, ' ', p.Apellido_Paterno, ' ', p.Apellido_Materno) as paciente_completo,
            p.Edad,
            COUNT(c.id) as total_consultas,
            COUNT(l.id) as total_laboratorio,
            MAX(c.Fecha) as ultima_consulta,
            COUNT(DISTINCT c.Id_Especialidad) as especialidades_diferentes
        FROM Pacientes p
        LEFT JOIN Consultas c ON p.id = c.Id_Paciente
        LEFT JOIN Laboratorio l ON p.id = l.Id_Paciente
        GROUP BY p.id, p.Nombre, p.Apellido_Paterno, p.Apellido_Materno, p.Edad
        HAVING COUNT(c.id) > 0
        ORDER BY total_consultas DESC
        """
        
        # Nuevos pacientes por mes
        nuevos_pacientes_query = """
        SELECT 
            FORMAT(MIN(c.Fecha), 'yyyy-MM') as mes_primera_consulta,
            COUNT(DISTINCT c.Id_Paciente) as pacientes_nuevos
        FROM Consultas c
        WHERE c.Fecha >= DATEADD(MONTH, -12, GETDATE())
        GROUP BY c.Id_Paciente
        HAVING MIN(c.Fecha) >= DATEADD(MONTH, -12, GETDATE())
        """
        
        distribucion_edad = self._execute_query(edad_query)
        pacientes_activos = self._execute_query(pacientes_activos_query)
        nuevos_pacientes = self._execute_query(nuevos_pacientes_query)
        
        return {
            'distribucion_por_edad': distribucion_edad,
            'pacientes_mas_activos': pacientes_activos,
            'crecimiento_pacientes': nuevos_pacientes
        }
    
    # ===============================
    # ESTADÍSTICAS DE PRODUCTOS/FARMACIA
    # ===============================
    
    @cached_query('stats_farmacia', ttl=600)
    def get_pharmacy_analytics(self) -> Dict[str, Any]:
        """Análisis completo de farmacia e inventario"""
        
        # Estado general del inventario
        inventario_query = """
        SELECT 
            COUNT(*) as total_productos,
            SUM(CASE WHEN (Stock_Caja + Stock_Unitario) > 0 THEN 1 ELSE 0 END) as productos_con_stock,
            SUM(CASE WHEN (Stock_Caja + Stock_Unitario) <= 10 THEN 1 ELSE 0 END) as productos_bajo_stock,
            SUM((Stock_Caja + Stock_Unitario) * Precio_compra) as valor_inventario_compra,
            SUM((Stock_Caja + Stock_Unitario) * Precio_venta) as valor_inventario_venta
        FROM Productos
        """
        
        # Productos más vendidos (últimos 30 días)
        mas_vendidos_query = """
        SELECT TOP 15
            p.Codigo,
            p.Nombre as producto_nombre,
            m.Nombre as marca_nombre,
            SUM(dv.Cantidad_Unitario) as unidades_vendidas,
            SUM(dv.Cantidad_Unitario * dv.Precio_Unitario) as ingresos_producto,
            COUNT(DISTINCT v.id) as numero_ventas,
            AVG(dv.Precio_Unitario) as precio_promedio,
            (p.Stock_Caja + p.Stock_Unitario) as stock_actual
        FROM Productos p
        INNER JOIN Marca m ON p.ID_Marca = m.id
        INNER JOIN Lote l ON p.id = l.Id_Producto
        INNER JOIN DetallesVentas dv ON l.id = dv.Id_Lote
        INNER JOIN Ventas v ON dv.Id_Venta = v.id
        WHERE v.Fecha >= DATEADD(DAY, -30, GETDATE())
        GROUP BY p.id, p.Codigo, p.Nombre, m.Nombre, p.Stock_Caja, p.Stock_Unitario
        ORDER BY unidades_vendidas DESC
        """
        
        # Análisis de vencimientos
        vencimientos_query = """
        SELECT 
            COUNT(CASE WHEN l.Fecha_Vencimiento < GETDATE() THEN 1 END) as lotes_vencidos,
            COUNT(CASE WHEN l.Fecha_Vencimiento BETWEEN GETDATE() AND DATEADD(MONTH, 1, GETDATE()) THEN 1 END) as vencen_1_mes,
            COUNT(CASE WHEN l.Fecha_Vencimiento BETWEEN DATEADD(MONTH, 1, GETDATE()) AND DATEADD(MONTH, 3, GETDATE()) THEN 1 END) as vencen_3_meses,
            SUM(CASE WHEN l.Fecha_Vencimiento < GETDATE() THEN (l.Cantidad_Caja + l.Cantidad_Unitario) ELSE 0 END) as unidades_perdidas
        FROM Lote l
        WHERE (l.Cantidad_Caja + l.Cantidad_Unitario) > 0
        """
        
        # Marcas más populares
        marcas_query = """
        SELECT 
            m.Nombre as marca,
            COUNT(p.id) as productos_marca,
            SUM(p.Stock_Caja * p.Stock_Unitario) as stock_total_marca,
            AVG(p.Precio_venta) as precio_promedio_marca
        FROM Marca m
        LEFT JOIN Productos p ON m.id = p.ID_Marca
        WHERE (p.Stock_Caja + p.Stock_Unitario) > 0
        GROUP BY m.id, m.Nombre
        ORDER BY productos_marca DESC
        """
        
        inventario = self._execute_query(inventario_query, fetch_one=True)
        mas_vendidos = self._execute_query(mas_vendidos_query)
        vencimientos = self._execute_query(vencimientos_query, fetch_one=True)
        marcas = self._execute_query(marcas_query)
        
        return {
            'estado_inventario': inventario,
            'productos_mas_vendidos': mas_vendidos,
            'analisis_vencimientos': vencimientos,
            'marcas_populares': marcas
        }
    
    # ===============================
    # ESTADÍSTICAS DE CONSULTAS Y DOCTORES
    # ===============================
    
    @cached_query('stats_consultas_medicas', ttl=600)
    def get_medical_analytics(self) -> Dict[str, Any]:
        """Análisis de actividad médica"""
        
        # Especialidades más demandadas
        especialidades_query = """
        SELECT 
            e.Nombre as especialidad,
            COUNT(c.id) as total_consultas,
            COUNT(DISTINCT c.Id_Paciente) as pacientes_unicos,
            AVG(e.Precio_Normal) as precio_promedio,
            SUM(e.Precio_Normal) as ingresos_estimados,
            CONCAT('Dr. ', d.Nombre, ' ', d.Apellido_Paterno) as doctor_principal
        FROM Especialidad e
        LEFT JOIN Consultas c ON e.id = c.Id_Especialidad
        LEFT JOIN Doctores d ON e.Id_Doctor = d.id
        WHERE c.Fecha >= DATEADD(MONTH, -6, GETDATE())
        GROUP BY e.id, e.Nombre, e.Precio_Normal, d.Nombre, d.Apellido_Paterno
        ORDER BY total_consultas DESC
        """
        
        # Doctores más activos
        doctores_activos_query = """
        SELECT TOP 10
            CONCAT('Dr. ', d.Nombre, ' ', d.Apellido_Paterno, ' ', d.Apellido_Materno) as doctor_completo,
            d.Especialidad as especialidad_principal,
            COUNT(c.id) as consultas_realizadas,
            COUNT(DISTINCT c.Id_Paciente) as pacientes_atendidos,
            COUNT(DISTINCT c.Id_Especialidad) as servicios_ofrecidos,
            MAX(c.Fecha) as ultima_consulta
        FROM Doctores d
        INNER JOIN Especialidad e ON d.id = e.Id_Doctor
        LEFT JOIN Consultas c ON e.id = c.Id_Especialidad
        WHERE c.Fecha >= DATEADD(MONTH, -3, GETDATE())
        GROUP BY d.id, d.Nombre, d.Apellido_Paterno, d.Apellido_Materno, d.Especialidad
        ORDER BY consultas_realizadas DESC
        """
        
        # Horarios más concurridos
        horarios_query = """
        SELECT 
            DATEPART(HOUR, Fecha) as hora,
            COUNT(*) as consultas_hora,
            ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM Consultas WHERE Fecha >= DATEADD(MONTH, -1, GETDATE())), 2) as porcentaje
        FROM Consultas
        WHERE Fecha >= DATEADD(MONTH, -1, GETDATE())
        GROUP BY DATEPART(HOUR, Fecha)
        ORDER BY consultas_hora DESC
        """
        
        # Consultas por día de la semana
        dias_semana_query = """
        SELECT 
            DATENAME(WEEKDAY, Fecha) as dia_semana,
            COUNT(*) as consultas_dia,
            AVG(CAST(COUNT(*) AS FLOAT)) OVER() as promedio_dia
        FROM Consultas
        WHERE Fecha >= DATEADD(MONTH, -2, GETDATE())
        GROUP BY DATENAME(WEEKDAY, Fecha), DATEPART(WEEKDAY, Fecha)
        ORDER BY DATEPART(WEEKDAY, Fecha)
        """
        
        especialidades = self._execute_query(especialidades_query)
        doctores_activos = self._execute_query(doctores_activos_query)
        horarios = self._execute_query(horarios_query)
        dias_semana = self._execute_query(dias_semana_query)
        
        return {
            'especialidades_demandadas': especialidades,
            'doctores_mas_activos': doctores_activos,
            'horarios_concurridos': horarios,
            'distribucion_semanal': dias_semana
        }
    
    # ===============================
    # ESTADÍSTICAS DE LABORATORIO
    # ===============================
    
    @cached_query('stats_laboratorio_completo', ttl=600)
    def get_laboratory_analytics(self) -> Dict[str, Any]:
        """Análisis completo de laboratorio"""
        
        # Exámenes más solicitados
        examenes_populares_query = """
        SELECT 
            Nombre as examen,
            COUNT(*) as veces_solicitado,
            AVG(Precio_Normal) as precio_promedio,
            SUM(Precio_Normal) as ingresos_estimados,
            COUNT(DISTINCT Id_Paciente) as pacientes_unicos
        FROM Laboratorio
        WHERE id IS NOT NULL
        GROUP BY Nombre, Precio_Normal
        ORDER BY veces_solicitado DESC
        """
        
        # Carga de trabajo por técnico
        carga_trabajo_query = """
        SELECT 
            CONCAT(t.Nombre, ' ', t.Apellido_Paterno) as trabajador,
            tt.Tipo as tipo_trabajador,
            COUNT(l.id) as examenes_asignados,
            COUNT(DISTINCT l.Id_Paciente) as pacientes_atendidos,
            AVG(l.Precio_Normal) as valor_promedio_examen
        FROM Trabajadores t
        INNER JOIN Tipo_Trabajadores tt ON t.Id_Tipo_Trabajador = tt.id
        LEFT JOIN Laboratorio l ON t.id = l.Id_Trabajador
        WHERE tt.Tipo LIKE '%Laboratorio%' OR tt.Tipo LIKE '%Técnico%'
        GROUP BY t.id, t.Nombre, t.Apellido_Paterno, tt.Tipo
        ORDER BY examenes_asignados DESC
        """
        
        # Exámenes sin asignar
        sin_asignar_query = """
        SELECT 
            COUNT(*) as examenes_pendientes,
            SUM(Precio_Normal) as valor_pendiente
        FROM Laboratorio
        WHERE Id_Trabajador IS NULL
        """
        
        examenes_populares = self._execute_query(examenes_populares_query)
        carga_trabajo = self._execute_query(carga_trabajo_query)
        sin_asignar = self._execute_query(sin_asignar_query, fetch_one=True)
        
        return {
            'examenes_mas_solicitados': examenes_populares,
            'carga_trabajo_tecnicos': carga_trabajo,
            'examenes_sin_asignar': sin_asignar
        }
    
    # ===============================
    # COMPARATIVAS Y TENDENCIAS
    # ===============================
    
    def get_comparative_analysis(self, current_months: int = 3, compare_months: int = 3) -> Dict[str, Any]:
        """Análisis comparativo entre períodos"""
        
        # Período actual
        fecha_actual_fin = datetime.now()
        fecha_actual_inicio = fecha_actual_fin - timedelta(days=current_months*30)
        
        # Período anterior (para comparar)
        fecha_anterior_fin = fecha_actual_inicio
        fecha_anterior_inicio = fecha_anterior_fin - timedelta(days=compare_months*30)
        
        # Métricas período actual
        actual_query = """
        SELECT 
            'ACTUAL' as periodo,
            (SELECT COUNT(*) FROM Consultas WHERE Fecha BETWEEN ? AND ?) as consultas,
            (SELECT COALESCE(SUM(Total), 0) FROM Ventas WHERE Fecha BETWEEN ? AND ?) as ingresos_ventas,
            (SELECT COALESCE(SUM(Monto), 0) FROM Gastos WHERE Fecha BETWEEN ? AND ?) as gastos_totales,
            (SELECT COUNT(*) FROM Laboratorio WHERE id IS NOT NULL) as examenes_lab,
            (SELECT COUNT(DISTINCT Id_Paciente) FROM Consultas WHERE Fecha BETWEEN ? AND ?) as pacientes_activos
        """
        
        # Métricas período anterior
        anterior_query = """
        SELECT 
            'ANTERIOR' as periodo,
            (SELECT COUNT(*) FROM Consultas WHERE Fecha BETWEEN ? AND ?) as consultas,
            (SELECT COALESCE(SUM(Total), 0) FROM Ventas WHERE Fecha BETWEEN ? AND ?) as ingresos_ventas,
            (SELECT COALESCE(SUM(Monto), 0) FROM Gastos WHERE Fecha BETWEEN ? AND ?) as gastos_totales,
            (SELECT COUNT(*) FROM Laboratorio WHERE id IS NOT NULL) as examenes_lab,
            (SELECT COUNT(DISTINCT Id_Paciente) FROM Consultas WHERE Fecha BETWEEN ? AND ?) as pacientes_activos
        """
        
        actual = self._execute_query(actual_query, 
                                   (fecha_actual_inicio, fecha_actual_fin) * 4, 
                                   fetch_one=True)
        
        anterior = self._execute_query(anterior_query, 
                                     (fecha_anterior_inicio, fecha_anterior_fin) * 4,
                                     fetch_one=True)
        
        # Calcular variaciones
        variaciones = {}
        for key in ['consultas', 'ingresos_ventas', 'gastos_totales', 'examenes_lab', 'pacientes_activos']:
            actual_val = safe_float(actual.get(key, 0))
            anterior_val = safe_float(anterior.get(key, 0))
            
            if anterior_val > 0:
                variacion_pct = ((actual_val - anterior_val) / anterior_val) * 100
            else:
                variacion_pct = 100 if actual_val > 0 else 0
                
            variaciones[key] = {
                'actual': actual_val,
                'anterior': anterior_val,
                'diferencia': actual_val - anterior_val,
                'variacion_porcentaje': round(variacion_pct, 2)
            }
        
        return {
            'periodo_actual_meses': current_months,
            'periodo_anterior_meses': compare_months,
            'fecha_actual_inicio': fecha_actual_inicio,
            'fecha_actual_fin': fecha_actual_fin,
            'fecha_anterior_inicio': fecha_anterior_inicio,
            'fecha_anterior_fin': fecha_anterior_fin,
            'metricas_comparativas': variaciones
        }
    
    # ===============================
    # KPIs DEL NEGOCIO
    # ===============================
    
    @cached_query('kpis_negocio', ttl=300)
    def get_business_kpis(self) -> Dict[str, Any]:
        """Indicadores clave de rendimiento del negocio"""
        
        # KPIs financieros (últimos 30 días)
        hace_30_dias = datetime.now() - timedelta(days=30)
        
        financieros_query = """
        SELECT 
            (SELECT COALESCE(SUM(Total), 0) FROM Ventas WHERE Fecha >= ?) as ingresos_30d,
            (SELECT COALESCE(SUM(Monto), 0) FROM Gastos WHERE Fecha >= ?) as gastos_30d,
            (SELECT COUNT(*) FROM Ventas WHERE Fecha >= ?) as numero_ventas_30d,
            (SELECT AVG(Total) FROM Ventas WHERE Fecha >= ?) as ticket_promedio_30d,
            (SELECT COUNT(DISTINCT Id_Paciente) FROM Consultas WHERE Fecha >= ?) as pacientes_activos_30d
        """
        
        # KPIs operacionales
        operacionales_query = """
        SELECT 
            (SELECT COUNT(*) FROM Productos WHERE (Stock_Caja + Stock_Unitario) <= 10) as productos_stock_critico,
            (SELECT COUNT(*) FROM Laboratorio WHERE Id_Trabajador IS NULL) as examenes_sin_asignar,
            (SELECT AVG(DATEDIFF(day, fecha_primera, fecha_ultima)) 
             FROM (
                SELECT Id_Paciente, MIN(Fecha) as fecha_primera, MAX(Fecha) as fecha_ultima
                FROM Consultas 
                GROUP BY Id_Paciente
                HAVING COUNT(*) > 1
             ) frecuencia) as dias_promedio_entre_consultas,
            (SELECT COUNT(DISTINCT Id_Doctor) FROM Especialidad e 
             INNER JOIN Consultas c ON e.id = c.Id_Especialidad 
             WHERE c.Fecha >= ?) as doctores_activos_30d
        """
        
        # Eficiencia del sistema
        eficiencia_query = """
        SELECT 
            (SELECT COUNT(*) FROM Usuario WHERE Estado = 1) as usuarios_activos,
            (SELECT COUNT(*) FROM Trabajadores) as total_trabajadores,
            (SELECT ROUND(AVG(CAST(numero_servicios AS FLOAT)), 2) FROM (
                SELECT COUNT(*) as numero_servicios FROM Especialidad GROUP BY Id_Doctor
            ) servicios_por_doctor) as servicios_promedio_por_doctor
        """
        
        financieros = self._execute_query(financieros_query, (hace_30_dias,) * 5, fetch_one=True)
        operacionales = self._execute_query(operacionales_query, (hace_30_dias,), fetch_one=True)
        eficiencia = self._execute_query(eficiencia_query, fetch_one=True)
        
        # Calcular KPIs derivados
        ingresos_30d = safe_float(financieros.get('ingresos_30d', 0))
        gastos_30d = safe_float(financieros.get('gastos_30d', 0))
        
        kpis_calculados = {
            'margen_beneficio_30d': calculate_percentage(ingresos_30d - gastos_30d, ingresos_30d) if ingresos_30d > 0 else 0,
            'roi_30d': calculate_percentage(ingresos_30d - gastos_30d, gastos_30d) if gastos_30d > 0 else 0,
            'ingresos_por_paciente_30d': ingresos_30d / financieros.get('pacientes_activos_30d', 1) if financieros.get('pacientes_activos_30d', 0) > 0 else 0,
            'consultas_por_doctor_30d': 0  # Se calcularía con más información
        }
        
        return {
            'fecha_calculo': datetime.now(),
            'periodo_dias': 30,
            'kpis_financieros': financieros,
            'kpis_operacionales': operacionales,
            'kpis_eficiencia': eficiencia,
            'kpis_calculados': kpis_calculados
        }
    
    # ===============================
    # UTILIDADES
    # ===============================
    
    def get_system_health_check(self) -> Dict[str, Any]:
        """Chequeo de salud del sistema"""
        
        checks_query = """
        SELECT 
            'database_integrity' as check_type,
            CASE WHEN EXISTS(SELECT 1 FROM Pacientes) THEN 'OK' ELSE 'ERROR' END as status,
            (SELECT COUNT(*) FROM Pacientes) as detail_count
        
        UNION ALL
        
        SELECT 
            'stock_levels',
            CASE WHEN (SELECT COUNT(*) FROM Productos WHERE (Stock_Caja + Stock_Unitario) <= 5) > 0 
                 THEN 'WARNING' ELSE 'OK' END,
            (SELECT COUNT(*) FROM Productos WHERE (Stock_Caja + Stock_Unitario) <= 5)
        
        UNION ALL
        
        SELECT 
            'expired_products',
            CASE WHEN (SELECT COUNT(*) FROM Lote WHERE Fecha_Vencimiento < GETDATE() AND (Cantidad_Caja + Cantidad_Unitario) > 0) > 0 
                 THEN 'ERROR' ELSE 'OK' END,
            (SELECT COUNT(*) FROM Lote WHERE Fecha_Vencimiento < GETDATE() AND (Cantidad_Caja + Cantidad_Unitario) > 0)
        """
        
        health_checks = self._execute_query(checks_query)
        
        # Determinar estado general
        estados = [check['status'] for check in health_checks]
        if 'ERROR' in estados:
            estado_general = 'ERROR'
        elif 'WARNING' in estados:
            estado_general = 'WARNING'  
        else:
            estado_general = 'OK'
        
        return {
            'estado_general': estado_general,
            'fecha_revision': datetime.now(),
            'checks_individuales': health_checks
        }
    
    # ===============================
    # CACHÉ
    # ===============================
    
    def invalidate_statistics_caches(self):
        """Invalida todos los cachés de estadísticas"""
        cache_types = [
            'dashboard_general', 'finanzas_resumen', 'stats_pacientes_completas',
            'stats_farmacia', 'stats_consultas_medicas', 'stats_laboratorio_completo',
            'kpis_negocio'
        ]
        from ..core.cache_system import invalidate_after_update
        invalidate_after_update(cache_types)
        print("🗑️ Cachés de estadísticas invalidados")
    
    def _invalidate_cache_after_modification(self):
        """Override para invalidación específica"""
        # Las estadísticas se regeneran, no se modifican directamente
        self.invalidate_statistics_caches()