from typing import List, Dict, Any, Optional
from datetime import datetime, timedelta

from ..core.base_repository import BaseRepository
from ..core.excepciones import (
    ValidationError, DatabaseQueryError,
    ExceptionHandler, validate_required
)
from ..core.cache_system import cached_query, invalidate_after_update

class CierreCajaRepository(BaseRepository):
    """Repository para operaciones de cierre de caja"""
    
    def __init__(self):
        super().__init__('cierre_temp', 'cierre_caja')  # Tabla temporal para cachés
        print("💰 CierreCajaRepository inicializado")
    
    # ===============================
    # IMPLEMENTACIÓN ABSTRACTA
    # ===============================
    
    def get_active(self) -> List[Dict[str, Any]]:
        """No aplica para cierre de caja"""
        return []
    
    # ===============================
    # CONSOLIDADO DEL DÍA ACTUAL
    # ===============================
    
    @cached_query('cierre_datos_dia', ttl=2)  # 🔥 CAMBIO: TTL reducido a 2 segundos
    def get_datos_dia_actual(self, fecha: str = None) -> Dict[str, Any]:
        """
        Obtiene todos los datos financieros del día actual
        Reutiliza la lógica existente de reportes
        """
        try:
            if not fecha:
                fecha = datetime.now().strftime("%d/%m/%Y")
            
            print(f"💰 Obteniendo datos de caja para: {fecha}")
            
            # Convertir fecha para SQL
            fecha_sql_inicio = self._convertir_fecha_sql(fecha, es_fecha_final=False)
            fecha_sql_fin = self._convertir_fecha_sql(fecha, es_fecha_final=True)
            
            datos_consolidados = {
                'fecha': fecha,
                'ingresos': self._obtener_ingresos_dia(fecha_sql_inicio, fecha_sql_fin),
                'egresos': self._obtener_egresos_dia(fecha_sql_inicio, fecha_sql_fin),
                'resumen': {}
            }
            
            # Calcular totales
            total_ingresos = sum(item.get('importe', 0) for item in datos_consolidados['ingresos'])
            total_egresos = sum(item.get('importe', 0) for item in datos_consolidados['egresos'])
            saldo_teorico = total_ingresos - total_egresos
            
            datos_consolidados['resumen'] = {
                'total_ingresos': round(total_ingresos, 2),
                'total_egresos': round(total_egresos, 2),
                'saldo_teorico': round(saldo_teorico, 2),
                'transacciones_ingresos': len(datos_consolidados['ingresos']),
                'transacciones_egresos': len(datos_consolidados['egresos']),
                'fecha_calculo': datetime.now().strftime("%d/%m/%Y %H:%M")
            }
            
            print(f"✅ Datos consolidados - Ingresos: Bs {total_ingresos:,.2f}, Egresos: Bs {total_egresos:,.2f}")
            
            return datos_consolidados
            
        except Exception as e:
            print(f"❌ Error obteniendo datos del día: {e}")
            return {
                'fecha': fecha or datetime.now().strftime("%d/%m/%Y"),
                'ingresos': [],
                'egresos': [],
                'resumen': {
                    'total_ingresos': 0.0,
                    'total_egresos': 0.0,
                    'saldo_teorico': 0.0,
                    'transacciones_ingresos': 0,
                    'transacciones_egresos': 0,
                    'fecha_calculo': datetime.now().strftime("%d/%m/%Y %H:%M")
                }
            }
    
    # ===============================
    # 🔥 CAMBIO 2: MÉTODO PARA INVALIDAR CACHÉ INMEDIATAMENTE
    # ===============================
    
    def invalidar_cache_transaccion(self):
        """Invalida el caché inmediatamente cuando ocurre una transacción"""
        try:
            invalidate_after_update(['cierre_datos_dia'])
            print("🔄 Caché de cierre invalidado por transacción")
        except Exception as e:
            print(f"⚠️ Error invalidando caché: {e}")
    
    def refresh_cache_immediately(self):
        """Refresca caché inmediatamente (forzado)"""
        try:
            # Invalidar caché actual
            self.invalidar_cache_transaccion()
            
            # Forzar recarga de datos (esto regenerará el caché)
            fecha_actual = datetime.now().strftime("%d/%m/%Y")
            self.get_datos_dia_actual(fecha_actual)
            
            print("⚡ Caché de cierre refrescado inmediatamente")
        except Exception as e:
            print(f"❌ Error refrescando caché: {e}")
    
    # ===============================
    # 🔥 CAMBIO 3: MÉTODO ESPECÍFICO PARA TRANSACCIONES
    # ===============================
    
    def notificar_transaccion_nueva(self, tipo_transaccion: str, monto: float = 0.0):
        """
        Método que debe ser llamado cuando ocurre una nueva transacción
        Invalida el caché y fuerza actualización
        """
        try:
            print(f"💰 Nueva transacción registrada: {tipo_transaccion} - Bs {monto:,.2f}")
            
            # Invalidar caché inmediatamente
            self.invalidar_cache_transaccion()
            
            # Opcional: log de transacción
            timestamp = datetime.now().strftime("%H:%M:%S")
            print(f"   ⏰ Timestamp: {timestamp}")
            print(f"   🔄 Caché invalidado para próxima consulta")
            
        except Exception as e:
            print(f"❌ Error notificando transacción: {e}")
    
    def _obtener_ingresos_dia(self, fecha_inicio: str, fecha_fin: str) -> List[Dict[str, Any]]:
        """Obtiene todos los ingresos del día agrupados por concepto"""
        try:
            ingresos = []
            
            # 1. VENTAS DE FARMACIA
            query_ventas = """
            SELECT 
                'Farmacia - Ventas' as concepto,
                COUNT(*) as transacciones,
                SUM(dv.Cantidad_Unitario * dv.Precio_Unitario) as importe
            FROM Ventas v
            INNER JOIN DetallesVentas dv ON v.id = dv.Id_Venta
            WHERE v.Fecha >= ? AND v.Fecha <= ?
            """
            
            try:
                resultado_ventas = self._execute_query(query_ventas, (fecha_inicio, fecha_fin), fetch_one=True)
                if resultado_ventas:
                    importe = resultado_ventas.get('importe')
                    transacciones = resultado_ventas.get('transacciones')
                    if importe is not None and float(importe) > 0:
                        ingresos.append({
                            'concepto': 'Farmacia - Ventas',
                            'transacciones': int(transacciones or 0),
                            'importe': float(importe)
                        })
            except Exception as e:
                print(f"Error en ventas de farmacia: {e}")
            
            # 2. CONSULTAS MÉDICAS
            query_consultas = """
            SELECT 
                'Consultas Médicas' as concepto,
                COUNT(*) as transacciones,
                SUM(CASE 
                    WHEN c.Tipo_Consulta = 'Emergencia' THEN COALESCE(e.Precio_Emergencia, 50.00)
                    ELSE COALESCE(e.Precio_Normal, 30.00) 
                END) as importe
            FROM Consultas c
            INNER JOIN Especialidad e ON c.Id_Especialidad = e.id
            WHERE c.Fecha >= ? AND c.Fecha <= ?
            """
            
            try:
                resultado_consultas = self._execute_query(query_consultas, (fecha_inicio, fecha_fin), fetch_one=True)
                if resultado_consultas:
                    importe = resultado_consultas.get('importe')
                    transacciones = resultado_consultas.get('transacciones')
                    if importe is not None and float(importe) > 0:
                        ingresos.append({
                            'concepto': 'Consultas Médicas',
                            'transacciones': int(transacciones or 0),
                            'importe': float(importe)
                        })
            except Exception as e:
                print(f"Error en consultas médicas: {e}")
            
            # 3. ANÁLISIS DE LABORATORIO
            query_laboratorio = """
            SELECT 
                'Análisis de Laboratorio' as concepto,
                COUNT(*) as transacciones,
                SUM(CASE 
                    WHEN l.Tipo = 'Emergencia' THEN COALESCE(ta.Precio_Emergencia, 25.00)
                    ELSE COALESCE(ta.Precio_Normal, 20.00) 
                END) as importe
            FROM Laboratorio l
            LEFT JOIN Tipos_Analisis ta ON l.Id_Tipo_Analisis = ta.id
            WHERE l.Fecha >= ? AND l.Fecha <= ?
            """
            
            try:
                resultado_laboratorio = self._execute_query(query_laboratorio, (fecha_inicio, fecha_fin), fetch_one=True)
                if resultado_laboratorio:
                    importe = resultado_laboratorio.get('importe')
                    transacciones = resultado_laboratorio.get('transacciones')
                    if importe is not None and float(importe) > 0:
                        ingresos.append({
                            'concepto': 'Análisis de Laboratorio',
                            'transacciones': int(transacciones or 0),
                            'importe': float(importe)
                        })
            except Exception as e:
                print(f"Error en laboratorio: {e}")
            
            # 4. PROCEDIMIENTOS ENFERMERÍA
            query_enfermeria = """
            SELECT 
                'Procedimientos Enfermería' as concepto,
                COUNT(*) as transacciones,
                SUM(COALESCE(e.Cantidad, 1) * 
                CASE 
                    WHEN COALESCE(e.Tipo, 'Normal') = 'Emergencia' 
                    THEN COALESCE(tp.Precio_Emergencia, 25.00)
                    ELSE COALESCE(tp.Precio_Normal, 20.00) 
                END) as importe
            FROM Enfermeria e
            LEFT JOIN Tipos_Procedimientos tp ON e.Id_Procedimiento = tp.id
            WHERE e.Fecha >= ? AND e.Fecha <= ?
            """
            
            try:
                resultado_enfermeria = self._execute_query(query_enfermeria, (fecha_inicio, fecha_fin), fetch_one=True)
                if resultado_enfermeria:
                    importe = resultado_enfermeria.get('importe')
                    transacciones = resultado_enfermeria.get('transacciones')
                    if importe is not None and float(importe) > 0:
                        ingresos.append({
                            'concepto': 'Procedimientos Enfermería',
                            'transacciones': int(transacciones or 0),
                            'importe': float(importe)
                        })
            except Exception as e:
                print(f"Error en enfermería: {e}")
            
            return ingresos
            
        except Exception as e:
            print(f"Error obteniendo ingresos del día: {e}")
            return []
    
    def _obtener_egresos_dia(self, fecha_inicio: str, fecha_fin: str) -> List[Dict[str, Any]]:
        """Obtiene todos los egresos del día agrupados por concepto - SIN secciones vacías"""
        try:
            egresos = []
            
            # 1. SERVICIOS BÁSICOS (solo si hay datos reales)
            try:
                query_servicios = """
                SELECT 
                    'Servicios Básicos' as concepto,
                    COUNT(*) as transacciones,
                    SUM(g.Monto) as importe
                FROM Gastos g
                INNER JOIN Tipo_Gastos tg ON g.ID_Tipo = tg.id
                WHERE g.Fecha >= ? AND g.Fecha <= ?
                AND (tg.Nombre LIKE '%servicio%' OR tg.Nombre LIKE '%básico%' 
                    OR tg.Nombre LIKE '%luz%' OR tg.Nombre LIKE '%agua%'
                    OR tg.Nombre LIKE '%internet%' OR tg.Nombre LIKE '%gas%')
                """
                
                resultado_servicios = self._execute_query(query_servicios, (fecha_inicio, fecha_fin), fetch_one=True)
                if resultado_servicios and resultado_servicios.get('importe', 0) > 0:
                    egresos.append({
                        'concepto': '🧾 Servicios Básicos',
                        'detalle': 'Electricidad, agua, gas, internet',
                        'transacciones': int(resultado_servicios.get('transacciones', 0)),
                        'importe': float(resultado_servicios.get('importe', 0))
                    })
                
            except Exception as e:
                print(f"⚠️ Error en servicios básicos: {e}")
            
            # 2. COMPRAS DE FARMACIA (solo si hay datos reales)
            try:
                query_compras = """
                SELECT 
                    'Compras de Farmacia' as concepto,
                    COUNT(*) as transacciones,
                    SUM(dc.Precio_Unitario) as importe
                FROM Compra c
                INNER JOIN DetalleCompra dc ON c.id = dc.Id_Compra
                WHERE c.Fecha >= ? AND c.Fecha <= ?
                """
                
                resultado_compras = self._execute_query(query_compras, (fecha_inicio, fecha_fin), fetch_one=True)
                if resultado_compras and resultado_compras.get('importe', 0) > 0:
                    egresos.append({
                        'concepto': '📦 Compras de Farmacia',
                        'detalle': 'Medicamentos y productos médicos',
                        'transacciones': int(resultado_compras.get('transacciones', 0)),
                        'importe': float(resultado_compras.get('importe', 0))
                    })
                
            except Exception as e:
                print(f"⚠️ Error en compras: {e}")
            
            # 3. GASTOS OPERATIVOS GENERALES (solo si hay datos reales)
            try:
                query_gastos_otros = """
                SELECT 
                    'Gastos Operativos' as concepto,
                    COUNT(*) as transacciones,
                    SUM(g.Monto) as importe
                FROM Gastos g
                INNER JOIN Tipo_Gastos tg ON g.ID_Tipo = tg.id
                WHERE g.Fecha >= ? AND g.Fecha <= ?
                AND NOT (tg.Nombre LIKE '%servicio%' OR tg.Nombre LIKE '%básico%' 
                        OR tg.Nombre LIKE '%luz%' OR tg.Nombre LIKE '%agua%'
                        OR tg.Nombre LIKE '%internet%' OR tg.Nombre LIKE '%gas%')
                """
                
                resultado_gastos = self._execute_query(query_gastos_otros, (fecha_inicio, fecha_fin), fetch_one=True)
                if resultado_gastos and resultado_gastos.get('importe', 0) > 0:
                    egresos.append({
                        'concepto': '🏥 Gastos Operativos',
                        'detalle': 'Gastos administrativos y operacionales',
                        'transacciones': int(resultado_gastos.get('transacciones', 0)),
                        'importe': float(resultado_gastos.get('importe', 0))
                    })
                
            except Exception as e:
                print(f"⚠️ Error en gastos operativos: {e}")
            
            # ✅ ELIMINADO: Ya no agregamos secciones vacías de "Mantenimiento" y "Otros gastos"
            
            # Si no hay egresos reales, agregar mensaje informativo
            if not egresos:
                egresos.append({
                    'concepto': '📋 Sin egresos registrados',
                    'detalle': 'No se registraron gastos en este día',
                    'transacciones': 0,
                    'importe': 0.0
                })
            
            return egresos
            
        except Exception as e:
            print(f"⛌ Error obteniendo egresos del día: {e}")
            return []
    
    # ===============================
    # MOVIMIENTOS DETALLADOS PARA PDF
    # ===============================
   
    def _obtener_ventas_individuales(self, fecha_inicio: str, fecha_fin: str) -> List[Dict[str, Any]]:
        """Obtiene ventas individuales con detalles completos"""
        try:
            query = """
            SELECT 
                v.id as id_venta,
                v.Fecha as fecha,
                p.Nombre as descripcion,
                dv.Cantidad_Unitario as cantidad,
                dv.Precio_Unitario as precio_unitario,
                (dv.Cantidad_Unitario * dv.Precio_Unitario) as valor,
                u.Nombre + ' ' + u.Apellido_Paterno as usuario,
                'farmacia' as categoria,
                'INGRESO' as tipo
            FROM Ventas v
            INNER JOIN DetallesVentas dv ON v.id = dv.Id_Venta
            INNER JOIN Lote l ON dv.Id_Lote = l.id
            INNER JOIN Productos p ON l.Id_Producto = p.id
            INNER JOIN Usuario u ON v.Id_Usuario = u.id
            WHERE v.Fecha >= ? AND v.Fecha <= ?
            ORDER BY v.Fecha, v.id
            """
            
            resultados = self._execute_query(query, (fecha_inicio, fecha_fin))
            
            ventas = []
            for row in resultados:
                ventas.append({
                    'id_venta': row.get('id_venta'),
                    'fecha': row.get('fecha', '').strftime('%d/%m/%Y %H:%M') if row.get('fecha') else '',
                    'descripcion': row.get('descripcion', 'Producto'),
                    'cantidad': int(row.get('cantidad', 1)),
                    'precio_unitario': float(row.get('precio_unitario', 0)),
                    'valor': float(row.get('valor', 0)),
                    'usuario': row.get('usuario', 'Sin usuario'),
                    'categoria': 'farmacia',
                    'tipo': 'INGRESO'
                })
            
            print(f"🏪 Ventas individuales: {len(ventas)}")
            return ventas
            
        except Exception as e:
            print(f"❌ Error obteniendo ventas individuales: {e}")
            return []
        
    def _obtener_consultas_individuales(self, fecha_inicio: str, fecha_fin: str) -> List[Dict[str, Any]]:
        """Obtiene consultas individuales con pacientes y tipos reales"""
        try:
            query = """
            SELECT 
                c.id as id_consulta,
                c.Fecha as fecha,
                c.Tipo_Consulta as tipo_consulta,
                e.Nombre as especialidad,
                (p.Nombre + ' ' + p.Apellido_Paterno + ' ' + p.Apellido_Materno) as paciente_nombre,
                d.Nombre + ' ' + d.Apellido_Paterno as doctor_nombre,
                CASE 
                    WHEN c.Tipo_Consulta = 'Emergencia' THEN COALESCE(e.Precio_Emergencia, 50.00)
                    ELSE COALESCE(e.Precio_Normal, 30.00) 
                END as valor,
                'consultas' as categoria,
                'INGRESO' as tipo
            FROM Consultas c
            INNER JOIN Pacientes p ON c.Id_Paciente = p.id
            INNER JOIN Especialidad e ON c.Id_Especialidad = e.id
            INNER JOIN Doctores d ON e.Id_Doctor = d.id
            WHERE c.Fecha >= ? AND c.Fecha <= ?
            ORDER BY c.Fecha, c.id
            """
            
            resultados = self._execute_query(query, (fecha_inicio, fecha_fin))
            
            consultas = []
            for row in resultados:
                consultas.append({
                    'id_consulta': row.get('id_consulta'),
                    'fecha': row.get('fecha', '').strftime('%d/%m/%Y %H:%M') if row.get('fecha') else '',
                    'tipo_consulta': row.get('tipo_consulta', 'Normal'),
                    'especialidad': row.get('especialidad', 'Medicina General'),
                    'paciente_nombre': row.get('paciente_nombre', 'Sin nombre'),
                    'doctor_nombre': row.get('doctor_nombre', 'Sin médico'),
                    'valor': float(row.get('valor', 0)),
                    'categoria': 'consultas',
                    'tipo': 'INGRESO',
                    'descripcion': f"Consulta {row.get('tipo_consulta', 'Normal')} - {row.get('especialidad', 'General')}"
                })
            
            print(f"🩺 Consultas individuales: {len(consultas)}")
            return consultas
            
        except Exception as e:
            print(f"❌ Error obteniendo consultas individuales: {e}")
            return []
        
    def _obtener_laboratorio_individual(self, fecha_inicio: str, fecha_fin: str) -> List[Dict[str, Any]]:
        """Obtiene análisis de laboratorio individuales"""
        try:
            query = """
            SELECT 
                l.id as id_laboratorio,
                l.Fecha as fecha,
                l.Tipo as tipo,
                ta.Nombre as analisis,
                (p.Nombre + ' ' + p.Apellido_Paterno + ' ' + p.Apellido_Materno) as paciente_nombre,
                t.Nombre + ' ' + t.Apellido_Paterno as laboratorista,
                CASE 
                    WHEN l.Tipo = 'Emergencia' THEN COALESCE(ta.Precio_Emergencia, 25.00)
                    ELSE COALESCE(ta.Precio_Normal, 20.00) 
                END as valor,
                'laboratorio' as categoria,
                'INGRESO' as tipo_mov
            FROM Laboratorio l
            INNER JOIN Pacientes p ON l.Id_Paciente = p.id
            INNER JOIN Tipos_Analisis ta ON l.Id_Tipo_Analisis = ta.id
            INNER JOIN Trabajadores t ON l.Id_Trabajador = t.id
            WHERE l.Fecha >= ? AND l.Fecha <= ?
            ORDER BY l.Fecha, l.id
            """
            
            resultados = self._execute_query(query, (fecha_inicio, fecha_fin))
            
            laboratorio = []
            for row in resultados:
                laboratorio.append({
                    'id_laboratorio': row.get('id_laboratorio'),
                    'fecha': row.get('fecha', '').strftime('%d/%m/%Y %H:%M') if row.get('fecha') else '',
                    'tipo': row.get('tipo', 'Normal'),
                    'analisis': row.get('analisis', 'Análisis General'),
                    'paciente_nombre': row.get('paciente_nombre', 'Sin nombre'),
                    'laboratorista': row.get('laboratorista', 'Sin técnico'),
                    'valor': float(row.get('valor', 0)),
                    'categoria': 'laboratorio',
                    'tipo_mov': 'INGRESO',
                    'descripcion': f"Análisis {row.get('tipo', 'Normal')} - {row.get('analisis', 'General')}"
                })
            
            print(f"🧪 Análisis individuales: {len(laboratorio)}")
            return laboratorio
            
        except Exception as e:
            print(f"❌ Error obteniendo laboratorio individual: {e}")
            return []

    def _obtener_enfermeria_individual(self, fecha_inicio: str, fecha_fin: str) -> List[Dict[str, Any]]:
        """Obtiene procedimientos de enfermería individuales"""
        try:
            query = """
            SELECT 
                e.id as id_enfermeria,
                e.Fecha as fecha,
                e.Tipo as tipo,
                e.Cantidad as cantidad,
                tp.Nombre as procedimiento,
                (p.Nombre + ' ' + p.Apellido_Paterno + ' ' + p.Apellido_Materno) as paciente_nombre,
                t.Nombre + ' ' + t.Apellido_Paterno as enfermero,
                (COALESCE(e.Cantidad, 1) * 
                CASE 
                    WHEN COALESCE(e.Tipo, 'Normal') = 'Emergencia' 
                    THEN COALESCE(tp.Precio_Emergencia, 25.00)
                    ELSE COALESCE(tp.Precio_Normal, 20.00) 
                END) as valor,
                'enfermeria' as categoria,
                'INGRESO' as tipo_mov
            FROM Enfermeria e
            INNER JOIN Pacientes p ON e.Id_Paciente = p.id
            INNER JOIN Tipos_Procedimientos tp ON e.Id_Procedimiento = tp.id
            INNER JOIN Trabajadores t ON e.Id_Trabajador = t.id
            WHERE e.Fecha >= ? AND e.Fecha <= ?
            ORDER BY e.Fecha, e.id
            """
            
            resultados = self._execute_query(query, (fecha_inicio, fecha_fin))
            
            enfermeria = []
            for row in resultados:
                enfermeria.append({
                    'id_enfermeria': row.get('id_enfermeria'),
                    'fecha': row.get('fecha', '').strftime('%d/%m/%Y %H:%M') if row.get('fecha') else '',
                    'tipo': row.get('tipo', 'Normal'),
                    'cantidad': int(row.get('cantidad', 1)),
                    'procedimiento': row.get('procedimiento', 'Procedimiento General'),
                    'paciente_nombre': row.get('paciente_nombre', 'Sin nombre'),
                    'enfermero': row.get('enfermero', 'Sin enfermero'),
                    'valor': float(row.get('valor', 0)),
                    'categoria': 'enfermeria',
                    'tipo_mov': 'INGRESO',
                    'descripcion': f"Procedimiento {row.get('tipo', 'Normal')} - {row.get('procedimiento', 'General')}"
                })
            
            print(f"💉 Procedimientos individuales: {len(enfermeria)}")
            return enfermeria
            
        except Exception as e:
            print(f"❌ Error obteniendo enfermería individual: {e}")
            return []
        
    def _obtener_egresos_individuales(self, fecha_inicio: str, fecha_fin: str) -> List[Dict[str, Any]]:
        """Obtiene egresos individuales (compras + gastos) con proveedores"""
        try:
            egresos = []
            
            # 1. COMPRAS DE FARMACIA - INDIVIDUALES
            query_compras = """
            SELECT 
                c.id as id_compra,
                c.Fecha as fecha,
                p.Nombre as descripcion,
                dc.Cantidad_Unitario as cantidad,
                dc.Precio_Unitario as precio_unitario,
                dc.Precio_Unitario as valor,
                pr.Nombre as proveedor,
                u.Nombre + ' ' + u.Apellido_Paterno as usuario,
                'Compras de Farmacia' as categoria,
                'EGRESO' as tipo
            FROM Compra c
            INNER JOIN DetalleCompra dc ON c.id = dc.Id_Compra
            INNER JOIN Lote l ON dc.Id_Lote = l.id
            INNER JOIN Productos p ON l.Id_Producto = p.id
            INNER JOIN Proveedor pr ON c.Id_Proveedor = pr.id
            INNER JOIN Usuario u ON c.Id_Usuario = u.id
            WHERE c.Fecha >= ? AND c.Fecha <= ?
            ORDER BY c.Fecha, c.id
            """
            
            compras = self._execute_query(query_compras, (fecha_inicio, fecha_fin))
            
            for row in compras:
                egresos.append({
                    'id_compra': row.get('id_compra'),
                    'fecha': row.get('fecha', '').strftime('%d/%m/%Y %H:%M') if row.get('fecha') else '',
                    'descripcion': row.get('descripcion', 'Producto'),
                    'cantidad': int(row.get('cantidad', 1)),
                    'precio_unitario': float(row.get('precio_unitario', 0)),
                    'valor': float(row.get('valor', 0)),
                    'proveedor': row.get('proveedor', 'Sin proveedor'),
                    'usuario': row.get('usuario', 'Sin usuario'),
                    'categoria': 'Compras de Farmacia',
                    'tipo': 'EGRESO'
                })
            
            # 2. GASTOS OPERATIVOS - INDIVIDUALES  
            query_gastos = """
            SELECT 
                g.id as id_gasto,
                g.Fecha as fecha,
                g.Descripcion as descripcion,
                g.Monto as valor,
                COALESCE(g.Proveedor, 'N/A') as proveedor,
                tg.Nombre as tipo_gasto,
                u.Nombre + ' ' + u.Apellido_Paterno as usuario,
                'Gastos Operativos' as categoria,
                'EGRESO' as tipo
            FROM Gastos g
            INNER JOIN Tipo_Gastos tg ON g.ID_Tipo = tg.id
            INNER JOIN Usuario u ON g.Id_RegistradoPor = u.id
            WHERE g.Fecha >= ? AND g.Fecha <= ?
            ORDER BY g.Fecha, g.id
            """
            
            gastos = self._execute_query(query_gastos, (fecha_inicio, fecha_fin))
            
            for row in gastos:
                egresos.append({
                    'id_gasto': row.get('id_gasto'),
                    'fecha': row.get('fecha', '').strftime('%d/%m/%Y %H:%M') if row.get('fecha') else '',
                    'descripcion': row.get('descripcion', 'Gasto'),
                    'valor': float(row.get('valor', 0)),
                    'proveedor': row.get('proveedor', 'N/A'),
                    'tipo_gasto': row.get('tipo_gasto', 'General'),
                    'usuario': row.get('usuario', 'Sin usuario'),
                    'categoria': 'Gastos Operativos',
                    'tipo': 'EGRESO'
                })
            
            print(f"💸 Egresos individuales: {len(egresos)} (Compras: {len(compras)}, Gastos: {len(gastos)})")
            return egresos
            
        except Exception as e:
            print(f"❌ Error obteniendo egresos individuales: {e}")
            return []
    def verificar_cierre_previo(self, fecha: str = None) -> bool:
        """Verifica si ya existe un cierre para la fecha (sin tabla BD)"""
        # Por ahora siempre permite cierre ya que no usamos tabla BD
        # En futuro podría verificar en archivo temporal o log
        return False 
    def get_movimientos_individuales_para_pdf(self, fecha: str = None) -> Dict[str, List[Dict[str, Any]]]:
        """
        Obtiene TODOS los movimientos individuales del día para PDF de arqueo
        Retorna datos organizados por categorías con DETALLES COMPLETOS
        """
        try:
            if not fecha:
                fecha = datetime.now().strftime("%d/%m/%Y")
            
            print(f"📋 Obteniendo movimientos individuales para PDF: {fecha}")
            
            # Convertir fecha para SQL
            fecha_sql_inicio = self._convertir_fecha_sql(fecha, es_fecha_final=False)
            fecha_sql_fin = self._convertir_fecha_sql(fecha, es_fecha_final=True)
            
            movimientos_organizados = {
                'farmacia': self._obtener_ventas_individuales(fecha_sql_inicio, fecha_sql_fin),
                'consultas': self._obtener_consultas_individuales(fecha_sql_inicio, fecha_sql_fin),
                'laboratorio': self._obtener_laboratorio_individual(fecha_sql_inicio, fecha_sql_fin),
                'enfermeria': self._obtener_enfermeria_individual(fecha_sql_inicio, fecha_sql_fin),
                'egresos': self._obtener_egresos_individuales(fecha_sql_inicio, fecha_sql_fin)
            }
            
            # Contar totales
            total_movimientos = sum(len(cat) for cat in movimientos_organizados.values())
            print(f"✅ Movimientos individuales obtenidos: {total_movimientos}")
            
            return movimientos_organizados
            
        except Exception as e:
            print(f"❌ Error obteniendo movimientos individuales: {e}")
            return {'farmacia': [], 'consultas': [], 'laboratorio': [], 'enfermeria': [], 'egresos': []}

    
    # ===============================
    # VALIDACIONES DE CIERRE
    # ===============================
    
    def validar_diferencia_permitida(self, efectivo_real: float, saldo_teorico: float, limite: float = 100.0) -> Dict[str, Any]:
        """Valida si la diferencia está dentro del límite permitido"""
        try:
            diferencia = efectivo_real - saldo_teorico
            diferencia_abs = abs(diferencia)
            
            return {
                'diferencia': round(diferencia, 2),
                'diferencia_absoluta': round(diferencia_abs, 2),
                'dentro_limite': diferencia_abs <= limite,
                'tipo': 'SOBRANTE' if diferencia >= 0 else 'FALTANTE',
                'porcentaje': round((diferencia_abs / max(abs(saldo_teorico), 1)) * 100, 2),
                'requiere_autorizacion': diferencia_abs > limite,
                'limite_configurado': limite
            }
            
        except Exception as e:
            print(f"❌ Error validando diferencia: {e}")
            return {
                'diferencia': 0.0,
                'diferencia_absoluta': 0.0,
                'dentro_limite': True,
                'tipo': 'NEUTRO',
                'porcentaje': 0.0,
                'requiere_autorizacion': False,
                'limite_configurado': limite
            }

    # ===============================
    # GENERACIÓN DE DATOS PARA PDF
    # ===============================
    
    def generar_datos_pdf_arqueo_corregido(self, fecha: str, efectivo_real: float, observaciones: str = "") -> Dict[str, Any]:
        """Genera estructura de datos CORREGIDA para PDF de arqueo con movimientos individuales"""
        try:
            # Obtener datos del día (agregados para resumen)
            datos_dia = self.get_datos_dia_actual(fecha)
            
            # 🔥 CAMBIO CLAVE: Usar nuevo método para movimientos individuales
            movimientos_organizados = self.get_movimientos_individuales_para_pdf(fecha)
            
            # Validar diferencia
            saldo_teorico = datos_dia['resumen'].get('saldo_teorico', 0.0)
            validacion = self.validar_diferencia_permitida(efectivo_real, saldo_teorico)
            
            datos_pdf = {
                'fecha': fecha,
                'hora_generacion': datetime.now().strftime("%H:%M"),
                'responsable': 'Sistema de Gestión Médica',
                'numero_arqueo': f"ARQ-{datetime.now().strftime('%Y-%j')}",
                'estado': 'COMPLETADO',
                
                # Resumen financiero
                'total_ingresos': datos_dia['resumen'].get('total_ingresos', 0.0),
                'total_egresos': datos_dia['resumen'].get('total_egresos', 0.0),
                'saldo_teorico': saldo_teorico,
                'efectivo_real': efectivo_real,
                'diferencia': validacion['diferencia'],
                'tipo_diferencia': validacion['tipo'],
                
                # 🔥 CAMBIO CLAVE: Usar movimientos organizados por categorías
                'movimientos_completos': movimientos_organizados,
                
                # Detalles agregados para resumen
                'ingresos_detalle': datos_dia['ingresos'],
                'egresos_detalle': datos_dia['egresos'],
                
                # Conteos
                'transacciones_ingresos': len(movimientos_organizados.get('farmacia', [])) + 
                                        len(movimientos_organizados.get('consultas', [])) + 
                                        len(movimientos_organizados.get('laboratorio', [])) + 
                                        len(movimientos_organizados.get('enfermeria', [])),
                'transacciones_egresos': len(movimientos_organizados.get('egresos', [])),
                
                # Validaciones
                'diferencia_absoluta': validacion['diferencia_absoluta'],
                'dentro_limite': validacion['dentro_limite'],
                'requiere_autorizacion': validacion['requiere_autorizacion'],
                
                # Observaciones
                'observaciones': observaciones or self._generar_observaciones_automaticas(validacion),
                'fecha_hora_completa': datetime.now().strftime("%d/%m/%Y %H:%M:%S")
            }
            
            print(f"✅ Datos PDF CORREGIDOS generados - Movimientos detallados incluidos")
            return datos_pdf
            
        except Exception as e:
            print(f"❌ Error generando datos PDF corregidos: {e}")
            return {}
    
    def _generar_observaciones_automaticas(self, validacion: Dict[str, Any]) -> str:
        """Genera observaciones automáticas basadas en la validación"""
        try:
            if validacion['dentro_limite']:
                return f"Arqueo realizado correctamente. Se registra {validacion['tipo'].lower()}. Diferencia dentro del límite permitido."
            else:
                return f"Arqueo con diferencia significativa. Se registra {validacion['tipo'].lower()} de Bs {validacion['diferencia_absoluta']:,.2f}. Requiere revisión de movimientos del día."
        except:
            return "Arqueo completado."
    
    # ===============================
    # UTILIDADES
    # ===============================
    
    def _convertir_fecha_sql(self, fecha_str: str, es_fecha_final: bool = False) -> str:
        """Convierte fecha DD/MM/YYYY a formato SQL Server"""
        try:
            if not fecha_str or fecha_str.strip() == "":
                fecha_str = datetime.now().strftime("%d/%m/%Y")
            
            dia, mes, anio = fecha_str.split('/')
            dia, mes, anio = int(dia), int(mes), int(anio)
            
            if es_fecha_final:
                return f"{anio:04d}-{mes:02d}-{dia:02d} 23:59:59"
            else:
                return f"{anio:04d}-{mes:02d}-{dia:02d} 00:00:00"
                
        except Exception as e:
            print(f"⚠️ Error convirtiendo fecha '{fecha_str}': {e}")
            if es_fecha_final:
                return datetime.now().strftime("%Y-%m-%d 23:59:59")
            else:
                return datetime.now().strftime("%Y-%m-%d 00:00:00")
    
    def refresh_cache(self):
        """Refresca caché de cierre de caja"""
        try:
            invalidate_after_update(['cierre_datos_dia'])
            print("🔄 Caché de cierre de caja refrescado")
        except Exception as e:
            print(f"❌ Error refrescando caché: {e}")