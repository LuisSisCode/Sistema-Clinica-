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
        WHERE v.Fecha >= ? AND v.Fecha <= ?
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
        """Compras: CORREGIDO - Usando Lote.Id_Compra para relacionar con los productos"""
        fecha_desde_sql = self._convertir_fecha_sql(fecha_desde, es_fecha_final=False)
        fecha_hasta_sql = self._convertir_fecha_sql(fecha_hasta, es_fecha_final=True)
        
        query = """
        SELECT 
            FORMAT(c.Fecha, 'dd/MM/yyyy') as fecha,
            
            -- ✅ PRODUCTO - Nombre del producto desde Lote
            p.Nombre as descripcion,
            
            -- ✅ MARCA - Nombre de marca 
            COALESCE(m.Nombre, 'Sin marca') as marca,
            
            -- ✅ CANTIDAD - Cantidad del lote creado en esta compra
            l.Cantidad_Unitario as cantidad,
            
            -- ✅ PROVEEDOR - Nombre del proveedor
            COALESCE(pr.Nombre, 'Sin proveedor') as proveedor,
            
            -- ✅ FECHA VENCIMIENTO - Del lote
            CASE 
                WHEN l.Fecha_Vencimiento IS NOT NULL 
                THEN FORMAT(l.Fecha_Vencimiento, 'dd/MM/yyyy')
                ELSE 'Sin vencimiento'
            END as fecha_vencimiento,
            
            -- ✅ USUARIO - Nombre completo
            COALESCE(u.Nombre + ' ' + u.Apellido_Paterno, 'Sin usuario') as usuario,
            
            -- ✅ PRECIO - Precio de compra del lote
            l.Precio_Compra as valor,
            
            -- Campos adicionales
            'C' + RIGHT('000' + CAST(c.id AS VARCHAR), 3) as numeroCompra
            
        FROM Compra c
        INNER JOIN Lote l ON c.id = l.Id_Compra
        INNER JOIN Productos p ON l.Id_Producto = p.id
        LEFT JOIN Marca m ON p.ID_Marca = m.id
        LEFT JOIN Proveedor pr ON c.Id_Proveedor = pr.id
        LEFT JOIN Usuario u ON c.Id_Usuario = u.id
        WHERE c.Fecha >= ? AND c.Fecha <= ?
        ORDER BY c.Fecha DESC, c.id DESC, p.Nombre ASC
        """
        
        return self._execute_query(query, (fecha_desde_sql, fecha_hasta_sql))
    
    # ===============================
    # REPORTES DE CONSULTAS (TIPO 4)
    # ===============================
    
    @cached_query('reporte_consultas', ttl=300)
    def get_reporte_consultas(self, fecha_desde: str, fecha_hasta: str) -> List[Dict[str, Any]]:
        """Consultas: CORREGIDO según estructura real de la tabla"""
        fecha_desde_sql = self._convertir_fecha_sql(fecha_desde, es_fecha_final=False)
        fecha_hasta_sql = self._convertir_fecha_sql(fecha_desde, es_fecha_final=True)
        
        query = """
        SELECT 
            FORMAT(c.Fecha, 'dd/MM/yyyy') as fecha,
            'C' + RIGHT('000' + CAST(c.id AS VARCHAR), 3) as numeroConsulta,
            COALESCE(p.Nombre + ' ' + p.Apellido_Paterno, 'Paciente sin nombre') as paciente,
            COALESCE(c.Detalles, 'Consulta médica') as descripcion,
            COALESCE(c.Tipo_Consulta, 'General') as tipo_consulta,
            0.00 as valor,
            COALESCE(u.Nombre + ' ' + u.Apellido_Paterno, 'Sin usuario') as usuario
        FROM Consultas c
        LEFT JOIN Pacientes p ON c.Id_Paciente = p.id
        LEFT JOIN Usuario u ON c.Id_Usuario = u.id
        WHERE c.Fecha >= ? AND c.Fecha <= ?
        ORDER BY c.Fecha DESC, c.id DESC
        """
        
        return self._execute_query(query, (fecha_desde_sql, fecha_hasta_sql))
    
    # ===============================
    # REPORTES DE LABORATORIO (TIPO 5)
    # ===============================
    
    @cached_query('reporte_laboratorio', ttl=300)
    def get_reporte_laboratorio(self, fecha_desde: str, fecha_hasta: str) -> List[Dict[str, Any]]:
        """Laboratorio: CORREGIDO según estructura real de la tabla"""
        fecha_desde_sql = self._convertir_fecha_sql(fecha_desde, es_fecha_final=False)
        fecha_hasta_sql = self._convertir_fecha_sql(fecha_hasta, es_fecha_final=True)
        
        query = """
        SELECT 
            FORMAT(l.Fecha, 'dd/MM/yyyy') as fecha,
            'L' + RIGHT('000' + CAST(l.id AS VARCHAR), 3) as numeroAnalisis,
            COALESCE(p.Nombre + ' ' + p.Apellido_Paterno, 'Paciente sin nombre') as paciente,
            COALESCE(ta.Nombre, 'Análisis') as analisis,
            COALESCE(l.Tipo, 'Normal') as tipo,
            COALESCE(l.Detalles, 'Sin detalles') as detalles,
            0.00 as valor,
            COALESCE(u.Nombre + ' ' + u.Apellido_Paterno, 'Sin usuario') as usuario
        FROM Laboratorio l
        LEFT JOIN Tipos_Analisis ta ON l.Id_Tipo_Analisis = ta.id
        LEFT JOIN Pacientes p ON l.Id_Paciente = p.id
        LEFT JOIN Usuario u ON l.Id_RegistradoPor = u.id
        WHERE l.Fecha >= ? AND l.Fecha <= ?
        ORDER BY l.Fecha DESC, l.id DESC
        """
        
        return self._execute_query(query, (fecha_desde_sql, fecha_hasta_sql))
    
    # ===============================
    # REPORTES DE ENFERMERÍA (TIPO 6)
    # ===============================
    
    @cached_query('reporte_enfermeria', ttl=300)
    def get_reporte_enfermeria(self, fecha_desde: str, fecha_hasta: str) -> List[Dict[str, Any]]:
        """Enfermería: CORREGIDO según estructura real de la tabla"""
        fecha_desde_sql = self._convertir_fecha_sql(fecha_desde, es_fecha_final=False)
        fecha_hasta_sql = self._convertir_fecha_sql(fecha_hasta, es_fecha_final=True)
        
        query = """
        SELECT 
            FORMAT(e.Fecha, 'dd/MM/yyyy') as fecha,
            'E' + RIGHT('000' + CAST(e.id AS VARCHAR), 3) as numeroProcedimiento,
            COALESCE(p.Nombre + ' ' + p.Apellido_Paterno, 'Paciente sin nombre') as paciente,
            CAST(e.Id_Procedimiento AS VARCHAR) as procedimiento,
            COALESCE(e.Tipo, 'Normal') as tipo,
            CAST(e.Cantidad AS VARCHAR) + ' unidad(es)' as cantidad_detalle,
            0.00 as valor,
            COALESCE(u.Nombre + ' ' + u.Apellido_Paterno, 'Sin usuario') as usuario
        FROM Enfermeria e
        LEFT JOIN Pacientes p ON e.Id_Paciente = p.id
        LEFT JOIN Usuario u ON e.Id_RegistradoPor = u.id
        WHERE e.Fecha >= ? AND e.Fecha <= ?
        ORDER BY e.Fecha DESC, e.id DESC
        """
        
        return self._execute_query(query, (fecha_desde_sql, fecha_hasta_sql))
    
    # ===============================
    # REPORTES DE GASTOS (TIPO 7)
    # ===============================
    
    @cached_query('reporte_gastos', ttl=300)
    def get_reporte_gastos(self, fecha_desde: str, fecha_hasta: str) -> List[Dict[str, Any]]:
        """Gastos: CORREGIDO según estructura real de la tabla"""
        fecha_desde_sql = self._convertir_fecha_sql(fecha_desde, es_fecha_final=False)
        fecha_hasta_sql = self._convertir_fecha_sql(fecha_hasta, es_fecha_final=True)
        
        query = """
        SELECT 
            FORMAT(g.Fecha, 'dd/MM/yyyy') as fecha,
            'G' + RIGHT('000' + CAST(g.ID_Tipo AS VARCHAR), 3) as numeroGasto,
            g.Descripcion as descripcion,
            g.Monto as valor,
            COALESCE(u.Nombre + ' ' + u.Apellido_Paterno, 'Sin usuario') as usuario,
            CASE 
                WHEN g.ID_Proveedor IS NOT NULL 
                THEN COALESCE(pr.Nombre, 'Proveedor')
                ELSE 'Sin proveedor'
            END as proveedor
        FROM Gastos g
        LEFT JOIN Usuario u ON g.Id_RegistradoPor = u.id
        LEFT JOIN Proveedor pr ON g.ID_Proveedor = pr.id
        WHERE g.Fecha >= ? AND g.Fecha <= ?
        ORDER BY g.Fecha DESC, g.ID_Tipo DESC
        """
        
        return self._execute_query(query, (fecha_desde_sql, fecha_hasta_sql))
    
    # ===============================
    # ✅ NUEVO REPORTE: INGRESOS Y EGRESOS (TIPO 8)
    # ===============================
    
    @cached_query('reporte_ingresos_egresos', ttl=300)
    def get_reporte_ingresos_egresos(self, fecha_desde: str, fecha_hasta: str) -> List[Dict[str, Any]]:
        """
        ✅ REPORTE: Ingresos y Egresos - CORREGIDO según estructura real
        """
        fecha_desde_sql = self._convertir_fecha_sql(fecha_desde, es_fecha_final=False)
        fecha_hasta_sql = self._convertir_fecha_sql(fecha_hasta, es_fecha_final=True)
        
        query = """
        -- ✅ INGRESOS: Ventas de Farmacia
        SELECT 
            FORMAT(v.Fecha, 'dd/MM/yyyy') as fecha,
            v.Fecha as fecha_ordenar,
            'INGRESO' as tipo,
            'Venta de Farmacia' as categoria,
            'V' + RIGHT('000' + CAST(v.id AS VARCHAR), 3) as numero,
            'Venta de productos farmacéuticos' as descripcion,
            v.Total as monto,
            COALESCE(u.Nombre + ' ' + u.Apellido_Paterno, 'Sin usuario') as usuario
        FROM Ventas v
        LEFT JOIN Usuario u ON v.Id_Usuario = u.id
        WHERE v.Fecha >= ? AND v.Fecha <= ?
        
        UNION ALL
        
        -- ✅ INGRESOS EXTRAS (de tabla IngresosExtras)
        SELECT 
            FORMAT(ie.fecha, 'dd/MM/yyyy') as fecha,
            ie.fecha as fecha_ordenar,
            'INGRESO' as tipo,
            'Ingreso Extra' as categoria,
            'IE' + RIGHT('000' + CAST(ie.id AS VARCHAR), 3) as numero,
            COALESCE(ie.descripcion, 'Ingreso adicional') as descripcion,
            ie.monto as monto,
            COALESCE(u.Nombre + ' ' + u.Apellido_Paterno, 'Sin usuario') as usuario
        FROM IngresosExtras ie
        LEFT JOIN Usuario u ON ie.id_registradoPor = u.id
        WHERE ie.fecha >= ? AND ie.fecha <= ?
        
        UNION ALL
        
        -- ✅ EGRESOS: Compras de Farmacia
        SELECT 
            FORMAT(c.Fecha, 'dd/MM/yyyy') as fecha,
            c.Fecha as fecha_ordenar,
            'EGRESO' as tipo,
            'Compra de Farmacia' as categoria,
            'C' + RIGHT('000' + CAST(c.id AS VARCHAR), 3) as numero,
            'Compra a ' + COALESCE(pr.Nombre, 'Proveedor') as descripcion,
            c.Total as monto,
            COALESCE(u.Nombre + ' ' + u.Apellido_Paterno, 'Sin usuario') as usuario
        FROM Compra c
        LEFT JOIN Proveedor pr ON c.Id_Proveedor = pr.id
        LEFT JOIN Usuario u ON c.Id_Usuario = u.id
        WHERE c.Fecha >= ? AND c.Fecha <= ?
        
        UNION ALL
        
        -- ✅ EGRESOS: Gastos Operativos
        SELECT 
            FORMAT(g.Fecha, 'dd/MM/yyyy') as fecha,
            g.Fecha as fecha_ordenar,
            'EGRESO' as tipo,
            'Gasto Operativo' as categoria,
            'G' + RIGHT('000' + CAST(g.ID_Tipo AS VARCHAR), 3) as numero,
            COALESCE(g.Descripcion, 'Gasto operativo') as descripcion,
            g.Monto as monto,
            COALESCE(u.Nombre + ' ' + u.Apellido_Paterno, 'Sin usuario') as usuario
        FROM Gastos g
        LEFT JOIN Usuario u ON g.Id_RegistradoPor = u.id
        WHERE g.Fecha >= ? AND g.Fecha <= ?
        
        
        UNION ALL
        
        -- ✅ EGRESOS: Tabla Egresos (adicional)
        SELECT 
            FORMAT(e.Fecha, 'dd/MM/yyyy') as fecha,
            e.Fecha as fecha_ordenar,
            'EGRESO' as tipo,
            'Egreso' as categoria,
            'E' + RIGHT('000' + CAST(e.Id_Tipo_Gasto AS VARCHAR), 3) as numero,
            COALESCE(e.Descripcion, 'Egreso') as descripcion,
            e.Monto as monto,
            COALESCE(u.Nombre + ' ' + u.Apellido_Paterno, 'Sin usuario') as usuario
        FROM Egresos e
        LEFT JOIN Usuario u ON e.Id_Usuario = u.id
        WHERE e.Fecha >= ? AND e.Fecha <= ?
        
        -- ✅ ORDENAR POR FECHA (más reciente primero)
        ORDER BY fecha_ordenar DESC, tipo ASC, categoria ASC
        """
        
        # ✅ 4 pares de parámetros (fecha_desde, fecha_hasta) para cada UNION
        # ✅ 5 pares de parámetros (fecha_desde, fecha_hasta) para 5 UNION
        params = (fecha_desde_sql, fecha_hasta_sql) * 5
        
        return self._execute_query(query, params)
    
    # ===============================
    # ✅ ANÁLISIS FINANCIERO AVANZADO
    # ===============================
    
    def get_analisis_financiero_avanzado(self, fecha_desde: str, fecha_hasta: str) -> Dict[str, Any]:
        """
        ✅ Análisis financiero detallado - CORREGIDO según estructura real
        """
        try:
            fecha_desde_sql = self._convertir_fecha_sql(fecha_desde, es_fecha_final=False)
            fecha_hasta_sql = self._convertir_fecha_sql(fecha_hasta, es_fecha_final=True)
            
            query = """
            SELECT 
                -- ✅ INGRESOS POR CATEGORÍA
                COALESCE(SUM(CASE WHEN origen = 'ventas' THEN monto ELSE 0 END), 0) as ingresos_ventas,
                COALESCE(SUM(CASE WHEN origen = 'ingresos_extras' THEN monto ELSE 0 END), 0) as ingresos_extras,
                
                -- ✅ EGRESOS POR CATEGORÍA
                COALESCE(SUM(CASE WHEN origen = 'compras' THEN monto ELSE 0 END), 0) as egresos_compras,
                COALESCE(SUM(CASE WHEN origen = 'gastos' THEN monto ELSE 0 END), 0) as egresos_gastos,
                COALESCE(SUM(CASE WHEN origen = 'egresos' THEN monto ELSE 0 END), 0) as egresos_otros,
                
                -- ✅ TOTALES
                COALESCE(SUM(CASE WHEN tipo = 'INGRESO' THEN monto ELSE 0 END), 0) as total_ingresos,
                COALESCE(SUM(CASE WHEN tipo = 'EGRESO' THEN monto ELSE 0 END), 0) as total_egresos,
                
                -- ✅ CONTADORES
                COUNT(CASE WHEN tipo = 'INGRESO' THEN 1 END) as transacciones_ingreso,
                COUNT(CASE WHEN tipo = 'EGRESO' THEN 1 END) as transacciones_egreso
                
            FROM (
                -- Ventas
                SELECT 'INGRESO' as tipo, 'ventas' as origen, Total as monto FROM Ventas 
                WHERE Fecha >= ? AND Fecha <= ?
                
                UNION ALL
                -- Ingresos Extras
                SELECT 'INGRESO' as tipo, 'ingresos_extras' as origen, monto as monto FROM IngresosExtras 
                WHERE fecha >= ? AND fecha <= ?
                
                UNION ALL
                -- Compras
                SELECT 'EGRESO' as tipo, 'compras' as origen, Total as monto FROM Compra 
                WHERE Fecha >= ? AND Fecha <= ?
                
                UNION ALL
                -- Gastos
                SELECT 'EGRESO' as tipo, 'gastos' as origen, Monto as monto FROM Gastos 
                WHERE Fecha >= ? AND Fecha <= ?
            ) consolidado
            """
            
            
            params = (fecha_desde_sql, fecha_hasta_sql) * 5  # 5 tablas
            resultado = self._execute_query(query, params, fetch_one=True)
            
            if resultado:
                total_ingresos = float(resultado.get('total_ingresos', 0))
                total_egresos = float(resultado.get('total_egresos', 0))
                utilidad_neta = total_ingresos - total_egresos
                
                return {
                    # Ingresos desglosados
                    'ingresos_ventas': float(resultado.get('ingresos_ventas', 0)),
                    'ingresos_extras': float(resultado.get('ingresos_extras', 0)),
                    
                    # Egresos desglosados
                    'egresos_compras': float(resultado.get('egresos_compras', 0)),
                    'egresos_gastos': float(resultado.get('egresos_gastos', 0)),
                    'egresos_otros': float(resultado.get('egresos_otros', 0)),
                    
                    # Totales
                    'total_ingresos': total_ingresos,
                    'total_egresos': total_egresos,
                    'utilidad_neta': utilidad_neta,
                    
                    # Métricas
                    'margen_utilidad': (utilidad_neta / total_ingresos * 100) if total_ingresos > 0 else 0,
                    'estado_financiero': 'SUPERÁVIT' if utilidad_neta > 0 else 'DÉFICIT' if utilidad_neta < 0 else 'EQUILIBRIO',
                    
                    # Contadores
                    'transacciones_ingreso': int(resultado.get('transacciones_ingreso', 0)),
                    'transacciones_egreso': int(resultado.get('transacciones_egreso', 0)),
                    'total_transacciones': int(resultado.get('transacciones_ingreso', 0)) + int(resultado.get('transacciones_egreso', 0))
                }
            else:
                return self._analisis_vacio()
                
        except Exception as e:
            print(f"⚠️ Error en análisis financiero avanzado: {e}")
            import traceback
            traceback.print_exc()
            return self._analisis_vacio()
    
    def _analisis_vacio(self) -> Dict[str, Any]:
        """Retorna estructura vacía para análisis financiero"""
        return {
            'ingresos_ventas': 0.0,
            'ingresos_extras': 0.0,
            'egresos_compras': 0.0,
            'egresos_gastos': 0.0,
            'egresos_otros': 0.0,
            'total_ingresos': 0.0,
            'total_egresos': 0.0,
            'utilidad_neta': 0.0,
            'margen_utilidad': 0.0,
            'estado_financiero': 'N/A',
            'transacciones_ingreso': 0,
            'transacciones_egreso': 0,
            'total_transacciones': 0
        }
    
    # ===============================
    # CÁLCULO DE RESÚMENES
    # ===============================
    
    def _calcular_resumen(self, datos: List[Dict[str, Any]], tipo_reporte: int) -> Dict[str, Any]:
        """Calcula resumen estadístico del reporte - ✅ ACTUALIZADO"""
        try:
            if not datos:
                return {'totalRegistros': 0, 'totalValor': 0.0}
            
            total_registros = len(datos)
            
            # Campo de valor según tipo de reporte
            campo_valor_map = {
                1: 'valor',           # Ventas
                2: 'valor',           # Inventario  
                3: 'valor',           # Compras
                4: 'valor',           # Consultas
                5: 'valor',           # Laboratorio
                6: 'valor',           # Enfermería
                7: 'valor',           # Gastos
                8: 'monto'            # ✅ Ingresos y Egresos usa 'monto'
            }
            
            campo_valor = campo_valor_map.get(tipo_reporte, 'valor')
            
            # Calcular total
            total_valor = sum(
                float(item.get(campo_valor, 0)) 
                for item in datos
            )
            
            resumen = {
                'totalRegistros': total_registros,
                'totalValor': round(total_valor, 2)
            }
            
            # ✅ RESUMEN ESPECIAL PARA REPORTE FINANCIERO (TIPO 8)
            if tipo_reporte == 8:
                # Calcular totales por tipo
                total_ingresos = sum(
                    float(item.get('monto', 0)) 
                    for item in datos 
                    if item.get('tipo') == 'INGRESO'
                )
                
                total_egresos = sum(
                    float(item.get('monto', 0)) 
                    for item in datos 
                    if item.get('tipo') == 'EGRESO'
                )
                
                utilidad_neta = total_ingresos - total_egresos
                
                # Desglose por categoría
                categorias_ingreso = {}
                categorias_egreso = {}
                
                for item in datos:
                    categoria = item.get('categoria', 'Sin categoría')
                    monto = float(item.get('monto', 0))
                    
                    if item.get('tipo') == 'INGRESO':
                        categorias_ingreso[categoria] = categorias_ingreso.get(categoria, 0) + monto
                    else:
                        categorias_egreso[categoria] = categorias_egreso.get(categoria, 0) + monto
                
                resumen.update({
                    'totalIngresos': round(total_ingresos, 2),
                    'totalEgresos': round(total_egresos, 2),
                    'utilidadNeta': round(utilidad_neta, 2),
                    'estadoFinanciero': 'SUPERÁVIT' if utilidad_neta > 0 else 'DÉFICIT' if utilidad_neta < 0 else 'EQUILIBRIO',
                    'margenUtilidad': round((utilidad_neta / total_ingresos * 100), 2) if total_ingresos > 0 else 0,
                    'categoriasIngreso': categorias_ingreso,
                    'categoriasEgreso': categorias_egreso,
                    'transaccionesIngreso': sum(1 for item in datos if item.get('tipo') == 'INGRESO'),
                    'transaccionesEgreso': sum(1 for item in datos if item.get('tipo') == 'EGRESO')
                })
            
            # Calcular promedio si aplica
            if total_registros > 0:
                resumen['promedioValor'] = round(total_valor / total_registros, 2)
            
            return resumen
            
        except Exception as e:
            print(f"⚠️ Error calculando resumen: {e}")
            return {'totalRegistros': 0, 'totalValor': 0.0}
    
    # ===============================
    # UTILIDADES
    # ===============================
    
    def _convertir_fecha_sql(self, fecha_str: str, es_fecha_final: bool = False) -> str:
        """
        Convierte fecha DD/MM/YYYY a formato SQL Server (YYYY-MM-DD HH:MM:SS)
        ✅ CORREGIDO: Para fecha final, usa 23:59:59 del mismo día
        """
        try:
            if not fecha_str:
                # Si no hay fecha, usar fecha actual
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
                
            elif tipo_reporte == 8:  # Ingresos y Egresos - verificar tablas relevantes
                # ✅ Verificar SOLO las tablas involucradas en Ingresos y Egresos
                query = """
                SELECT 
                    (SELECT COUNT(*) FROM Ventas WHERE Fecha >= ? AND Fecha <= ?) +
                    (SELECT COUNT(*) FROM IngresosExtras WHERE fecha >= ? AND fecha <= ?) +
                    (SELECT COUNT(*) FROM Compra WHERE Fecha >= ? AND Fecha <= ?) +
                    (SELECT COUNT(*) FROM Gastos WHERE Fecha >= ? AND Fecha <= ?)
                    as total
                """
                params = (fecha_desde_sql, fecha_hasta_sql) * 4
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
                WHERE {alias}.Fecha >= ? AND {alias}.Fecha <= ?
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