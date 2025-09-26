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
        """INVALIDACIÓN con COMMIT FORZADO"""
        try:
            print("🔥 INVALIDACIÓN CON COMMIT FORZADO")
            
            # 1. FORZAR COMMIT PRIMERO
            self.forzar_commit_bd()
            
            # 2. Invalidar cache
            from ..core.cache_system import invalidate_after_update
            invalidate_after_update(['cierre_datos_dia'])
            
            # 3. Limpiar cache manager
            if hasattr(self, '_cache_manager') and self._cache_manager:
                self._cache_manager.clear()
            
            # 4. Invalidar caches relacionados
            invalidate_after_update([
                'ventas', 'ventas_today', 'consultas', 'laboratorio', 
                'enfermeria', 'gastos', 'compras', 'ingresos', 'egresos',
                'productos', 'stock_producto', 'lotes_activos'
            ])
            
            print("✅ INVALIDACIÓN CON COMMIT COMPLETADA")
            
        except Exception as e:
            print(f"❌ Error en invalidación con commit: {e}")

    def forzar_commit_bd(self):
        """Fuerza commit REAL en todas las conexiones"""
        try:
            print("🔄 FORZANDO COMMIT REAL EN TODAS LAS CONEXIONES...")
            
            # 1. Forzar commit en la conexión actual
            if hasattr(self, '_connection') and self._connection:
                self._connection.commit()
                print("   ✅ Commit en conexión principal")
            
            # 2. Forzar commit en el connection pool del BaseRepository
            if hasattr(self, 'db_manager') and self.db_manager:
                try:
                    # Ejecutar un commit explícito
                    self.db_manager.execute_query("COMMIT", ())
                    print("   ✅ Commit explícito ejecutado")
                except:
                    pass
            
            # 3. Forzar flush de cache de SQL Server
            try:
                self._execute_query("CHECKPOINT", ())
                print("   ✅ Checkpoint ejecutado")
            except:
                pass
                
            print("✅ COMMIT REAL COMPLETADO")
            
        except Exception as e:
            print(f"⚠️ Error forzando commit real: {e}")
    
    def refresh_cache_immediately(self):
        """
        Refresca caché inmediatamente (forzado)
        ✅ MÉTODO SIMPLIFICADO que funciona consistentemente
        """
        try:
            # 1. Invalidar caché actual
            self.invalidar_cache_transaccion()
            
            # 2. Forzar recarga de datos (esto regenerará el caché)
            fecha_actual = datetime.now().strftime("%d/%m/%Y")
            self.get_datos_dia_actual(fecha_actual)
            
            print("⚡ Caché de cierre refrescado inmediatamente")
            
        except Exception as e:
            print(f"❌ Error refrescando caché: {e}")
    
    # ===============================
    # 🔥 CAMBIO 3: MÉTODO ESPECÍFICO PARA TRANSACCIONES
    # ===============================
    
    # REEMPLAZAR el método _obtener_ingresos_dia en cierre_caja_repository.py con esta versión DEBUG:

    def _obtener_ingresos_dia(self, fecha_inicio: str, fecha_fin: str) -> List[Dict[str, Any]]:
        """Obtiene todos los ingresos del día - CON NIVEL DE AISLAMIENTO CORREGIDO"""
        try:
            # AGREGAR al inicio del método:
            # Forzar nivel de aislamiento READ COMMITTED
            try:
                self._execute_query("SET TRANSACTION ISOLATION LEVEL READ COMMITTED", ())
                print("🔧 Nivel de aislamiento establecido: READ COMMITTED")
            except:
                pass
            
            ingresos = []
            
            # 🔍 DEBUG: Mostrar fechas que se están usando
            print(f"🔍 DEBUG CIERRE: Buscando ingresos entre {fecha_inicio} y {fecha_fin}")
            
            # 1. VENTAS DE FARMACIA - CONSULTA CORREGIDA
            query_ventas = """
                SELECT 
                    COUNT(DISTINCT v.id) as transacciones,
                    COALESCE(SUM(dv.Cantidad_Unitario * dv.Precio_Unitario), 0.0) as importe
                FROM Ventas v 
                INNER JOIN DetallesVentas dv ON v.id = dv.Id_Venta
                WHERE v.Fecha >= ? AND v.Fecha <= ?
                """
            print(f"🔍 DEBUG: Ejecutando consulta ventas SIN NOLOCK con parámetros: {fecha_inicio}, {fecha_fin}")
            
            try:
                print(f"🔍 DEBUG: Ejecutando consulta ventas CORREGIDA con parámetros: {fecha_inicio}, {fecha_fin}")
                resultado_ventas = self._execute_query_fresh_connection(query_ventas, (fecha_inicio, fecha_fin), fetch_one=True)
                print(f"🔍 DEBUG: Resultado ventas CORREGIDO: {resultado_ventas}")
                    
            except Exception as e:
                print(f"❌ DEBUG: Error en consulta ventas: {e}")
            
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
                    # ✅ FIX: Manejar None correctamente
                    importe_consultas = resultado_consultas.get('importe') or 0
                    transacciones_consultas = resultado_consultas.get('transacciones') or 0
                    
                    if float(importe_consultas) > 0:
                        ingresos.append({
                            'concepto': 'Consultas Médicas',
                            'transacciones': int(transacciones_consultas),
                            'importe': float(importe_consultas)
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
                    # ✅ FIX: Manejar None correctamente
                    importe_laboratorio = resultado_laboratorio.get('importe') or 0
                    transacciones_laboratorio = resultado_laboratorio.get('transacciones') or 0
                    
                    if float(importe_laboratorio) > 0:
                        ingresos.append({
                            'concepto': 'Análisis de Laboratorio',
                            'transacciones': int(transacciones_laboratorio),
                            'importe': float(importe_laboratorio)
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
                    # ✅ FIX: Manejar None correctamente
                    importe_enfermeria = resultado_enfermeria.get('importe') or 0
                    transacciones_enfermeria = resultado_enfermeria.get('transacciones') or 0
                    
                    if float(importe_enfermeria) > 0:
                        ingresos.append({
                            'concepto': 'Procedimientos Enfermería',
                            'transacciones': int(transacciones_enfermeria),
                            'importe': float(importe_enfermeria)
                        })
            except Exception as e:
                print(f"Error en enfermería: {e}")
            
            # 🔍 DEBUG FINAL
            total_ingresos = sum(item.get('importe', 0) for item in ingresos)
            print(f"🔍 DEBUG FINAL: {len(ingresos)} conceptos, Total: Bs {total_ingresos}")
            for ingreso in ingresos:
                print(f"   📊 {ingreso['concepto']}: Bs {ingreso['importe']} ({ingreso['transacciones']} trans)")
            
            return ingresos
            
        except Exception as e:
            print(f"❌ Error obteniendo ingresos del día: {e}")
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
                if resultado_servicios:
                    # ✅ FIX: Manejar None correctamente antes de la comparación
                    importe_servicios = resultado_servicios.get('importe') or 0
                    transacciones_servicios = resultado_servicios.get('transacciones') or 0
                    
                    if float(importe_servicios) > 0:
                        egresos.append({
                            'concepto': '🧾 Servicios Básicos',
                            'detalle': 'Electricidad, agua, gas, internet',
                            'transacciones': int(transacciones_servicios),
                            'importe': float(importe_servicios)
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
                if resultado_compras:
                    # ✅ FIX: Manejar None correctamente antes de la comparación
                    importe_compras = resultado_compras.get('importe') or 0
                    transacciones_compras = resultado_compras.get('transacciones') or 0
                    
                    if float(importe_compras) > 0:
                        egresos.append({
                            'concepto': '📦 Compras de Farmacia',
                            'detalle': 'Medicamentos y productos médicos',
                            'transacciones': int(transacciones_compras),
                            'importe': float(importe_compras)
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
                if resultado_gastos:
                    # ✅ FIX: Manejar None correctamente antes de la comparación
                    importe_gastos = resultado_gastos.get('importe') or 0
                    transacciones_gastos = resultado_gastos.get('transacciones') or 0
                    
                    if float(importe_gastos) > 0:
                        egresos.append({
                            'concepto': '🏥 Gastos Operativos',
                            'detalle': 'Gastos administrativos y operacionales',
                            'transacciones': int(transacciones_gastos),
                            'importe': float(importe_gastos)
                        })
                    
            except Exception as e:
                print(f"⚠️ Error en gastos operativos: {e}")
            
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
        """Convierte fecha DD/MM/YYYY a formato SQL Server - VERSIÓN CORREGIDA"""
        try:
            if not fecha_str or fecha_str.strip() == "":
                fecha_str = datetime.now().strftime("%d/%m/%Y")
            
            # AGREGAR validación de formato
            if '/' not in fecha_str:
                fecha_str = datetime.now().strftime("%d/%m/%Y")
            
            partes = fecha_str.split('/')
            if len(partes) != 3:
                fecha_str = datetime.now().strftime("%d/%m/%Y")
                partes = fecha_str.split('/')
            
            dia, mes, anio = int(partes[0]), int(partes[1]), int(partes[2])
            
            if es_fecha_final:
                resultado = f"{anio:04d}-{mes:02d}-{dia:02d} 23:59:59.999"
            else:
                resultado = f"{anio:04d}-{mes:02d}-{dia:02d} 00:00:00.000"
            
            print(f"🗓️ Fecha convertida: {fecha_str} → {resultado}")
            return resultado
            
        except Exception as e:
            print(f"❌ Error convirtiendo fecha '{fecha_str}': {e}")
            if es_fecha_final:
                return datetime.now().strftime("%Y-%m-%d 23:59:59.999")
            else:
                return datetime.now().strftime("%Y-%m-%d 00:00:00.000")
    
    def refresh_cache(self):
        """Refresca caché de cierre de caja"""
        try:
            invalidate_after_update(['cierre_datos_dia'])
            #print("🔄 Caché de cierre de caja refrescado")
        except Exception as e:
            print(f"❌ Error refrescando caché: {e}")

    # Agregar estos métodos utilitarios al CierreCajaRepository

    def _safe_float(self, value, default: float = 0.0) -> float:
        """Convierte de forma segura un valor a float, manejando None"""
        try:
            if value is None:
                return default
            return float(value)
        except (ValueError, TypeError):
            return default

    def _safe_int(self, value, default: int = 0) -> int:
        """Convierte de forma segura un valor a int, manejando None"""
        try:
            if value is None:
                return default
            return int(value)
        except (ValueError, TypeError):
            return default

    def _extract_safe_values(self, resultado: Dict[str, Any]) -> tuple:
        """Extrae valores seguros de un resultado de consulta SQL"""
        if not resultado:
            return 0.0, 0
        
        importe = self._safe_float(resultado.get('importe'))
        transacciones = self._safe_int(resultado.get('transacciones'))
        
        return importe, transacciones
    
    # CAMBIOS EN cierre_caja_repository.py

    def verificar_venta_incluida_en_cierre(self, venta_id: int, fecha: str) -> bool:
        """
        Verifica si una venta específica está incluida en los datos del cierre del día
        Usado por el polling inteligente para confirmar sincronización
        """
        try:
            print(f"🔍 Verificando si venta {venta_id} está en cierre de {fecha}")
            
            # Convertir fecha para SQL
            fecha_sql_inicio = self._convertir_fecha_sql(fecha, es_fecha_final=False)
            fecha_sql_fin = self._convertir_fecha_sql(fecha, es_fecha_final=True)
            
            # Consulta DIRECTA (sin cache) para verificar venta específica
            query_verificacion = """
            SELECT 
                v.id as venta_id,
                v.Fecha as fecha_venta,
                SUM(dv.Cantidad_Unitario * dv.Precio_Unitario) as total_venta
            FROM Ventas v
            INNER JOIN DetallesVentas dv ON v.id = dv.Id_Venta
            WHERE v.id = ? 
            AND v.Fecha >= ? AND v.Fecha <= ?
            GROUP BY v.id, v.Fecha
            """
            
            resultado = self._execute_query(
                query_verificacion, 
                (venta_id, fecha_sql_inicio, fecha_sql_fin), 
                fetch_one=True
            )
            
            if resultado:
                total_encontrado = self._safe_float(resultado.get('total_venta', 0))
                print(f"✅ Venta {venta_id} ENCONTRADA en cierre: Bs {total_encontrado:.2f}")
                return True
            else:
                print(f"❌ Venta {venta_id} NO ENCONTRADA en cierre")
                return False
                
        except Exception as e:
            print(f"❌ Error verificando venta {venta_id} en cierre: {e}")
            return False

    def get_conteo_ventas_actual(self, fecha: str) -> Dict[str, Any]:
        """
        Obtiene conteo rápido de ventas para comparación en polling
        Sin cache para resultados en tiempo real
        """
        try:
            fecha_sql_inicio = self._convertir_fecha_sql(fecha, es_fecha_final=False)
            fecha_sql_fin = self._convertir_fecha_sql(fecha, es_fecha_final=True)
            
            query_conteo = """
            SELECT 
                COUNT(DISTINCT v.id) as total_ventas,
                COUNT(dv.id) as total_detalles,
                SUM(dv.Cantidad_Unitario * dv.Precio_Unitario) as total_importe,
                MAX(v.id) as ultima_venta_id
            FROM Ventas v
            INNER JOIN DetallesVentas dv ON v.id = dv.Id_Venta
            WHERE v.Fecha >= ? AND v.Fecha <= ?
            """
            
            resultado = self._execute_query(query_conteo, (fecha_sql_inicio, fecha_sql_fin), fetch_one=True)
            
            if resultado:
                return {
                    'total_ventas': self._safe_int(resultado.get('total_ventas', 0)),
                    'total_detalles': self._safe_int(resultado.get('total_detalles', 0)),
                    'total_importe': self._safe_float(resultado.get('total_importe', 0)),
                    'ultima_venta_id': self._safe_int(resultado.get('ultima_venta_id', 0)),
                    'timestamp_consulta': datetime.now().isoformat()
                }
            else:
                return {
                    'total_ventas': 0,
                    'total_detalles': 0,
                    'total_importe': 0.0,
                    'ultima_venta_id': 0,
                    'timestamp_consulta': datetime.now().isoformat()
                }
                
        except Exception as e:
            print(f"❌ Error obteniendo conteo de ventas: {e}")
            return {
                'total_ventas': 0,
                'total_detalles': 0,
                'total_importe': 0.0,
                'ultima_venta_id': 0,
                'error': str(e)
            }

    def verificar_consistencia_datos_cierre(self, fecha: str) -> Dict[str, Any]:
        """
        Verifica la consistencia de los datos del cierre
        Útil para diagnóstico de problemas de sincronización
        """
        try:
            # Obtener datos con diferentes métodos para comparar
            datos_consolidados = self.get_datos_dia_actual(fecha)
            conteo_directo = self.get_conteo_ventas_actual(fecha)
            
            # Comparar resultados
            total_consolidado = datos_consolidados['resumen'].get('total_ingresos', 0)
            total_directo = conteo_directo.get('total_importe', 0)
            
            diferencia = abs(total_consolidado - total_directo)
            es_consistente = diferencia < 0.01  # Tolerancia de 1 centavo
            
            return {
                'es_consistente': es_consistente,
                'total_consolidado': total_consolidado,
                'total_directo': total_directo,
                'diferencia': diferencia,
                'ventas_consolidadas': datos_consolidados['resumen'].get('transacciones_ingresos', 0),
                'ventas_directas': conteo_directo.get('total_ventas', 0),
                'ultima_venta_id': conteo_directo.get('ultima_venta_id', 0),
                'timestamp_verificacion': datetime.now().isoformat()
            }
            
        except Exception as e:
            print(f"❌ Error verificando consistencia: {e}")
            return {
                'es_consistente': False,
                'error': str(e),
                'timestamp_verificacion': datetime.now().isoformat()
            }
        
    def verificar_consistencia_simple(self, fecha: str) -> Dict[str, Any]:
        """
        Verificación de consistencia SIMPLIFICADA
        """
        try:
            # Datos con cache
            datos_cache = self.get_datos_dia_actual(fecha)
            
            # Datos sin cache
            datos_directo = self.get_datos_dia_actual_sin_cache(fecha)
            
            total_cache = datos_cache['resumen'].get('total_ingresos', 0)
            total_directo = datos_directo['resumen'].get('total_ingresos', 0)
            
            diferencia = abs(total_cache - total_directo)
            
            return {
                'es_consistente': diferencia < 0.01,
                'total_cache': total_cache,
                'total_directo': total_directo,
                'diferencia': diferencia,
                'timestamp': datetime.now().isoformat()
            }
            
        except Exception as e:
            return {
                'es_consistente': False,
                'error': str(e),
                'timestamp': datetime.now().isoformat()
            }

    # ✅ MEJORAR MÉTODO EXISTENTE
    def notificar_transaccion_nueva(self, tipo_transaccion: str, monto: float = 0.0, id_transaccion: int = None):
        """
        Método SIMPLIFICADO que solo hace logging y invalidación básica
        ✅ REMUEVE la lógica compleja de polling que causaba problemas
        """
        try:
            id_info = f" (ID: {id_transaccion})" if id_transaccion else ""
            print(f"💰 Nueva transacción registrada: {tipo_transaccion}{id_info} - Bs {monto:,.2f}")
            
            # Solo invalidar caché - SIN polling complejo
            self.invalidar_cache_transaccion()
            
            # Log simple para diagnóstico
            timestamp = datetime.now().strftime("%H:%M:%S")
            print(f"   ⏰ Timestamp: {timestamp}")
            if id_transaccion:
                print(f"   🆔 ID: {id_transaccion}")
            print(f"   💵 Monto: Bs {monto:,.2f}")
            print(f"   🔄 Caché invalidado para próxima consulta")
            
        except Exception as e:
            print(f"❌ Error notificando transacción: {e}")

    

    # ✅ MÉTODO DE DIAGNÓSTICO AVANZADO
    def diagnosticar_estado_ventas_tiempo_real(self, fecha: str, venta_id_esperada: int = None) -> Dict[str, Any]:
        """
        Diagnóstico completo del estado de ventas en tiempo real
        """
        try:
            print("=" * 60)
            print(f"🔍 DIAGNÓSTICO COMPLETO - VENTAS DEL DÍA {fecha}")
            print("=" * 60)
            
            # 1. Datos consolidados (con cache)
            datos_consolidados = self.get_datos_dia_actual(fecha)
            
            # 2. Conteo directo (sin cache)
            conteo_directo = self.get_conteo_ventas_actual(fecha)
            
            # 3. Verificación de consistencia
            consistencia = self.verificar_consistencia_datos_cierre(fecha)
            
            # 4. Verificación de venta específica si se proporciona
            venta_encontrada = None
            if venta_id_esperada:
                venta_encontrada = self.verificar_venta_incluida_en_cierre(venta_id_esperada, fecha)
            
            diagnostico = {
                'fecha_diagnostico': fecha,
                'timestamp': datetime.now().isoformat(),
                
                # Datos consolidados
                'consolidado': {
                    'total_ingresos': datos_consolidados['resumen'].get('total_ingresos', 0),
                    'transacciones': datos_consolidados['resumen'].get('transacciones_ingresos', 0),
                    'fuente': 'cache + agregación'
                },
                
                # Conteo directo
                'directo': {
                    'total_importe': conteo_directo.get('total_importe', 0),
                    'total_ventas': conteo_directo.get('total_ventas', 0),
                    'ultima_venta_id': conteo_directo.get('ultima_venta_id', 0),
                    'fuente': 'consulta directa sin cache'
                },
                
                # Consistencia
                'consistencia': consistencia,
                
                # Venta específica
                'venta_especifica': {
                    'venta_id': venta_id_esperada,
                    'encontrada': venta_encontrada
                } if venta_id_esperada else None
            }
            
            # Log detallado
            print(f"📊 CONSOLIDADO: Bs {diagnostico['consolidado']['total_ingresos']:,.2f} ({diagnostico['consolidado']['transacciones']} trans)")
            print(f"📊 DIRECTO: Bs {diagnostico['directo']['total_importe']:,.2f} ({diagnostico['directo']['total_ventas']} ventas)")
            print(f"📊 CONSISTENTE: {'✅ SÍ' if consistencia['es_consistente'] else '❌ NO'}")
            
            if venta_id_esperada:
                print(f"📊 VENTA {venta_id_esperada}: {'✅ ENCONTRADA' if venta_encontrada else '❌ NO ENCONTRADA'}")
            
            print("=" * 60)
            
            return diagnostico
            
        except Exception as e:
            print(f"❌ Error en diagnóstico completo: {e}")
            return {
                'error': str(e),
                'timestamp': datetime.now().isoformat()
            }
        
    # AGREGAR ESTE MÉTODO A cierre_caja_repository.py

    def get_datos_dia_actual_sin_cache(self, fecha: str = None) -> Dict[str, Any]:
        """
        Obtiene datos del día SIN usar cache - VERSIÓN OPTIMIZADA
        ✅ CRÍTICO: Consulta directa sin cache para verificar totales reales
        """
        try:
            if not fecha:
                fecha = datetime.now().strftime("%d/%m/%Y")
            
            print(f"🔍 CONSULTA DIRECTA SIN CACHE: Datos de caja para {fecha}")
            
            # Convertir fecha para SQL
            fecha_sql_inicio = self._convertir_fecha_sql(fecha, es_fecha_final=False)
            fecha_sql_fin = self._convertir_fecha_sql(fecha, es_fecha_final=True)
            
            # ✅ CONSULTAS DIRECTAS OPTIMIZADAS (sin usar métodos con cache)
            ingresos_directos = self._obtener_todos_ingresos_directo(fecha_sql_inicio, fecha_sql_fin)
            egresos_directos = self._obtener_todos_egresos_directo(fecha_sql_inicio, fecha_sql_fin)
            
            # Calcular totales directamente
            total_ingresos = sum(item.get('importe', 0) for item in ingresos_directos)
            total_egresos = sum(item.get('importe', 0) for item in egresos_directos)
            total_transacciones_ingresos = sum(item.get('transacciones', 0) for item in ingresos_directos)
            total_transacciones_egresos = sum(item.get('transacciones', 0) for item in egresos_directos)
            
            datos_sin_cache = {
                'fecha': fecha,
                'ingresos': ingresos_directos,
                'egresos': egresos_directos,
                'resumen': {
                    'total_ingresos': round(total_ingresos, 2),
                    'total_egresos': round(total_egresos, 2),
                    'saldo_teorico': round(total_ingresos - total_egresos, 2),
                    'transacciones_ingresos': total_transacciones_ingresos,
                    'transacciones_egresos': total_transacciones_egresos,
                    'fecha_calculo': datetime.now().strftime("%d/%m/%Y %H:%M"),
                    'consulta_tipo': 'DIRECTA_SIN_CACHE'
                }
            }
            
            print(f"✅ CONSULTA DIRECTA COMPLETADA:")
            print(f"   💰 Total ingresos: Bs {total_ingresos:.2f}")
            print(f"   💸 Total egresos: Bs {total_egresos:.2f}")
            print(f"   📊 Trans ingresos: {total_transacciones_ingresos}")
            print(f"   📊 Trans egresos: {total_transacciones_egresos}")
            print(f"   🕒 Timestamp: {datos_sin_cache['resumen']['fecha_calculo']}")
            
            return datos_sin_cache
            
        except Exception as e:
            print(f"❌ Error en consulta directa sin cache: {e}")
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
                    'fecha_calculo': datetime.now().strftime("%d/%m/%Y %H:%M"),
                    'consulta_tipo': 'ERROR_SIN_CACHE',
                    'error': str(e)
                }
            }
        
    def _obtener_todos_ingresos_directo(self, fecha_inicio: str, fecha_fin: str) -> List[Dict[str, Any]]:
        """
        Obtiene TODOS los ingresos con consulta directa sin cache
        ✅ OPTIMIZADO: Una sola consulta por tipo
        """
        try:
            ingresos = []
            
            # 1. VENTAS DE FARMACIA
            query_ventas = """
                SELECT 
                    COUNT(DISTINCT v.id) as transacciones,
                    COALESCE(SUM(dv.Cantidad_Unitario * dv.Precio_Unitario), 0.0) as importe
                FROM Ventas v 
                INNER JOIN DetallesVentas dv ON v.id = dv.Id_Venta
                WHERE v.Fecha >= ? AND v.Fecha <= ?
                """
            
            resultado_ventas = self._execute_query(query_ventas, (fecha_inicio, fecha_fin), fetch_one=True)
            if resultado_ventas:
                importe_ventas = self._safe_float(resultado_ventas.get('importe', 0))
                transacciones_ventas = self._safe_int(resultado_ventas.get('transacciones', 0))
                
                if importe_ventas > 0:
                    ingresos.append({
                        'concepto': 'Farmacia - Ventas',
                        'transacciones': transacciones_ventas,
                        'importe': importe_ventas
                    })
            
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
            
            resultado_consultas = self._execute_query(query_consultas, (fecha_inicio, fecha_fin), fetch_one=True)
            if resultado_consultas:
                importe_consultas = self._safe_float(resultado_consultas.get('importe', 0))
                transacciones_consultas = self._safe_int(resultado_consultas.get('transacciones', 0))
                
                if importe_consultas > 0:
                    ingresos.append({
                        'concepto': 'Consultas Médicas',
                        'transacciones': transacciones_consultas,
                        'importe': importe_consultas
                    })
            
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
            
            resultado_laboratorio = self._execute_query(query_laboratorio, (fecha_inicio, fecha_fin), fetch_one=True)
            if resultado_laboratorio:
                importe_laboratorio = self._safe_float(resultado_laboratorio.get('importe', 0))
                transacciones_laboratorio = self._safe_int(resultado_laboratorio.get('transacciones', 0))
                
                if importe_laboratorio > 0:
                    ingresos.append({
                        'concepto': 'Análisis de Laboratorio',
                        'transacciones': transacciones_laboratorio,
                        'importe': importe_laboratorio
                    })
            
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
            
            resultado_enfermeria = self._execute_query(query_enfermeria, (fecha_inicio, fecha_fin), fetch_one=True)
            if resultado_enfermeria:
                importe_enfermeria = self._safe_float(resultado_enfermeria.get('importe', 0))
                transacciones_enfermeria = self._safe_int(resultado_enfermeria.get('transacciones', 0))
                
                if importe_enfermeria > 0:
                    ingresos.append({
                        'concepto': 'Procedimientos Enfermería',
                        'transacciones': transacciones_enfermeria,
                        'importe': importe_enfermeria
                    })
            
            total_ingresos = sum(item.get('importe', 0) for item in ingresos)
            print(f"🔍 INGRESOS DIRECTOS: {len(ingresos)} conceptos, Total: Bs {total_ingresos:.2f}")
            
            return ingresos
            
        except Exception as e:
            print(f"❌ Error obteniendo ingresos directos: {e}")
            return []
        
    def _obtener_todos_egresos_directo(self, fecha_inicio: str, fecha_fin: str) -> List[Dict[str, Any]]:
        """
        Obtiene TODOS los egresos con consulta directa sin cache
        ✅ SIMPLIFICADO: Solo gastos reales
        """
        try:
            egresos = []
            
            # GASTOS OPERATIVOS GENERALES (todos los tipos)
            query_gastos = """
            SELECT 
                'Gastos Operativos' as concepto,
                COUNT(*) as transacciones,
                SUM(g.Monto) as importe
            FROM Gastos g
            INNER JOIN Tipo_Gastos tg ON g.ID_Tipo = tg.id
            WHERE g.Fecha >= ? AND g.Fecha <= ?
            """
            
            resultado_gastos = self._execute_query(query_gastos, (fecha_inicio, fecha_fin), fetch_one=True)
            if resultado_gastos:
                importe_gastos = self._safe_float(resultado_gastos.get('importe', 0))
                transacciones_gastos = self._safe_int(resultado_gastos.get('transacciones', 0))
                
                if importe_gastos > 0:
                    egresos.append({
                        'concepto': 'Gastos Operativos',
                        'detalle': 'Gastos administrativos y operacionales',
                        'transacciones': transacciones_gastos,
                        'importe': importe_gastos
                    })
            
            # COMPRAS DE FARMACIA
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
            if resultado_compras:
                importe_compras = self._safe_float(resultado_compras.get('importe', 0))
                transacciones_compras = self._safe_int(resultado_compras.get('transacciones', 0))
                
                if importe_compras > 0:
                    egresos.append({
                        'concepto': 'Compras de Farmacia',
                        'detalle': 'Medicamentos y productos médicos',
                        'transacciones': transacciones_compras,
                        'importe': importe_compras
                    })
            
            total_egresos = sum(item.get('importe', 0) for item in egresos)
            print(f"🔍 EGRESOS DIRECTOS: {len(egresos)} conceptos, Total: Bs {total_egresos:.2f}")
            
            return egresos
            
        except Exception as e:
            print(f"❌ Error obteniendo egresos directos: {e}")
            return []

    def invalidar_cache_completo(self):
        """
        Invalida TODOS los caches relacionados con cierre de caja
        ✅ MÉTODO DE EMERGENCIA que siempre funciona
        """
        try:
            print("🧹 INVALIDACIÓN COMPLETA DE CACHE - CIERRE DE CAJA")
            
            # 1. Invalidar cache específico de cierre
            invalidate_after_update(['cierre_datos_dia'])
            
            # 2. Invalidar todos los caches relacionados
            invalidate_after_update([
                'ventas', 'ventas_today', 'consultas', 'laboratorio', 
                'enfermeria', 'gastos', 'compras', 'ingresos', 'egresos'
            ])
            
            # 3. Si hay cache manager, limpiar todo
            if hasattr(self, '_cache_manager'):
                self._cache_manager.clear()
            
            print("✅ Cache completo invalidado")
            
        except Exception as e:
            print(f"❌ Error invalidando cache completo: {e}")

    def verificar_y_diagnosticar_venta(self, venta_id: int, fecha: str):
        """Diagnóstico específico para verificar venta"""
        try:
            print(f"🔍 DIAGNÓSTICO ESPECÍFICO - Venta {venta_id} en {fecha}")
            
            # Convertir fecha
            fecha_sql_inicio = self._convertir_fecha_sql(fecha, es_fecha_final=False)
            fecha_sql_fin = self._convertir_fecha_sql(fecha, es_fecha_final=True)
            
            # 1. Verificar que la venta existe
            query_venta = """
            SELECT v.id, v.Fecha, v.Total, COUNT(dv.id) as detalles
            FROM Ventas v WITH (NOLOCK)
            LEFT JOIN DetallesVentas dv WITH (NOLOCK) ON v.id = dv.Id_Venta
            WHERE v.id = ?
            GROUP BY v.id, v.Fecha, v.Total
            """
            
            venta_info = self._execute_query(query_venta, (venta_id,), fetch_one=True)
            
            if venta_info:
                print(f"✅ Venta {venta_id} EXISTE: {venta_info}")
            else:
                print(f"❌ Venta {venta_id} NO EXISTE en tabla Ventas")
                return False
            
            # 2. Verificar que está en el rango de fecha
            query_fecha = """
            SELECT v.id, v.Fecha 
            FROM Ventas v WITH (NOLOCK)
            WHERE v.id = ? AND v.Fecha >= ? AND v.Fecha <= ?
            """
            
            venta_fecha = self._execute_query(query_fecha, (venta_id, fecha_sql_inicio, fecha_sql_fin), fetch_one=True)
            
            if venta_fecha:
                print(f"✅ Venta {venta_id} está en rango de fecha: {venta_fecha}")
                return True
            else:
                print(f"❌ Venta {venta_id} NO está en rango {fecha_sql_inicio} - {fecha_sql_fin}")
                return False
                
        except Exception as e:
            print(f"❌ Error en diagnóstico: {e}")
            return False
        
    def _execute_query_fresh_connection(self, query: str, params: tuple, fetch_one: bool = False):
        """Ejecuta consulta con una nueva conexión limpia"""
        try:
            # Crear nueva conexión temporal
            if hasattr(self, 'db_manager'):
                # Forzar nueva conexión
                fresh_connection = self.db_manager._create_new_connection()
                
                if fresh_connection:
                    cursor = fresh_connection.cursor()
                    cursor.execute(query, params)
                    
                    if fetch_one:
                        result = cursor.fetchone()
                        if result:
                            # Convertir a diccionario
                            columns = [column[0] for column in cursor.description]
                            return dict(zip(columns, result))
                    else:
                        results = cursor.fetchall()
                        columns = [column[0] for column in cursor.description]
                        return [dict(zip(columns, row)) for row in results]
                    
                    cursor.close()
                    fresh_connection.close()
                    print("✅ Consulta ejecutada con conexión fresca")
                    
            return None
            
        except Exception as e:
            print(f"❌ Error en conexión fresca: {e}")
            raise e