from typing import List, Dict, Any, Optional
from datetime import datetime
from ..core.base_repository import BaseRepository
from ..core.excepciones import ValidationError, DatabaseQueryError

class CierreCajaRepository(BaseRepository):
    """
    Repository INDEPENDIENTE para cierre de caja
    Consulta directa a BD sin dependencias de otros modelos
    """
    
    def __init__(self):
        super().__init__('CierreCaja', 'cierre_caja')
        print("ðŸ’° CierreCajaRepository inicializado - Modo independiente")
    
    # ===============================
    # IMPLEMENTACIÃ“N ABSTRACTA REQUERIDA
    # ===============================
    
    def get_active(self) -> List[Dict[str, Any]]:
        """Obtiene cierres activos"""
        return self.get_cierres_por_fecha(datetime.now().strftime("%Y-%m-%d"))
    
    # ===============================
    # CONSULTAS PRINCIPALES POR FECHA Y HORA
    # ===============================
    
    def get_datos_cierre_completo(self, fecha: str, hora_inicio: str, hora_fin: str) -> Dict[str, Any]:
        """
        Obtiene TODOS los datos para el cierre de caja en el rango especificado
        
        Args:
            fecha: Fecha en formato DD/MM/YYYY
            hora_inicio: Hora de inicio (HH:MM)
            hora_fin: Hora de fin (HH:MM)
            
        Returns:
            Dict con ingresos, egresos, resumen y detalles para PDF
        """
        try:
            if not fecha or not hora_inicio or not hora_fin:
                print("âŒ ParÃ¡metros incompletos en get_datos_cierre_completo")
                return self._estructura_vacia_cierre()
            
            if fecha.strip() == "" or hora_inicio.strip() == "" or hora_fin.strip() == "":
                print("âŒ ParÃ¡metros vacÃ­os en get_datos_cierre_completo")
                return self._estructura_vacia_cierre()
            
            fecha_sql = self._convertir_fecha_sql(fecha)
            
            # Construir timestamps completos
            timestamp_inicio = f"{fecha_sql} {hora_inicio}:00.000"
            timestamp_fin = f"{fecha_sql} {hora_fin}:59.999"
            
            print(f"ðŸ” Consultando datos de cierre: {timestamp_inicio} a {timestamp_fin}")
            
            # Obtener todos los datos
            ingresos_farmacia = self._get_ingresos_farmacia(timestamp_inicio, timestamp_fin)
            ingresos_consultas = self._get_ingresos_consultas(timestamp_inicio, timestamp_fin)
            ingresos_laboratorio = self._get_ingresos_laboratorio(timestamp_inicio, timestamp_fin)
            ingresos_enfermeria = self._get_ingresos_enfermeria(timestamp_inicio, timestamp_fin)
            ingresos_extras = self._get_ingresos_extras(timestamp_inicio, timestamp_fin) 
            egresos_gastos = self._get_egresos_gastos(timestamp_inicio, timestamp_fin)
            
            # Procesar y estructurar datos
            datos_procesados = self._procesar_datos_cierre(
                ingresos_farmacia, ingresos_consultas, ingresos_laboratorio,
                ingresos_enfermeria, ingresos_extras, egresos_gastos  # âœ… ORDEN CORRECTO
            )
            
            print(f"âœ… Datos procesados - Ingresos: Bs {datos_procesados['resumen']['total_ingresos']:,.2f}")
            return datos_procesados
            
        except Exception as e:
            print(f"âŒ Error obteniendo datos de cierre: {e}")
            import traceback
            traceback.print_exc()
            # âœ… RETORNAR ESTRUCTURA VÃLIDA EN LUGAR DE LANZAR EXCEPCIÃ“N
            return self._estructura_vacia_cierre()
    
    def _get_ingresos_farmacia(self, inicio: str, fin: str) -> List[Dict[str, Any]]:
        """Obtiene ingresos por ventas de farmacia"""
        query = """
        SELECT 
            v.id,
            v.Fecha,
            v.Total,
            0 as Descuento,
            v.Id_Usuario,
            CONCAT(u.Nombre, ' ', u.Apellido_Paterno) as NombreUsuario,
            'FARMACIA' as TipoIngreso,
            'Venta de medicamentos y productos' as Descripcion
        FROM Ventas v
        LEFT JOIN Usuario u ON v.Id_Usuario = u.id
        WHERE v.Fecha >= ? AND v.Fecha <= ?
        ORDER BY v.Fecha
        """
        return self._execute_query(query, (inicio, fin), use_cache=False)

    def _get_ingresos_consultas(self, inicio: str, fin: str) -> List[Dict[str, Any]]:
        """Obtiene ingresos por consultas mÃ©dicas"""
        query = """
        SELECT 
            c.id,
            c.Fecha,
            COALESCE(CASE WHEN c.Tipo_Consulta = 'Emergencia' THEN e.Precio_Emergencia ELSE e.Precio_Normal END, 0) as Total,
            0 as Descuento,
            c.Id_Usuario,
            CONCAT(u.Nombre, ' ', u.Apellido_Paterno) as NombreUsuario,
            'CONSULTA' as TipoIngreso,
            CONCAT('Consulta - ', e.Nombre) as Descripcion,
            CONCAT(p.Nombre, ' ', p.Apellido_Paterno) as NombrePaciente
        FROM Consultas c
        LEFT JOIN Usuario u ON c.Id_Usuario = u.id
        LEFT JOIN Especialidad e ON c.Id_Especialidad = e.id
        LEFT JOIN Pacientes p ON c.Id_Paciente = p.id
        WHERE c.Fecha >= ? AND c.Fecha <= ?
        ORDER BY c.Fecha
        """
        return self._execute_query(query, (inicio, fin), use_cache=False)

    def _get_ingresos_laboratorio(self, inicio: str, fin: str) -> List[Dict[str, Any]]:
        """Obtiene ingresos por anÃ¡lisis de laboratorio"""
        query = """
        SELECT 
            l.id,
            l.Fecha,
            COALESCE(CASE WHEN l.Tipo = 'Emergencia' THEN ta.Precio_Emergencia ELSE ta.Precio_Normal END, 0) as Total,
            0 as Descuento,
            l.Id_RegistradoPor as Id_Usuario,
            CONCAT(u.Nombre, ' ', u.Apellido_Paterno) as NombreUsuario,
            'LABORATORIO' as TipoIngreso,
            CONCAT('AnÃ¡lisis - ', ta.Nombre) as Descripcion,
            CONCAT(p.Nombre, ' ', p.Apellido_Paterno) as NombrePaciente
        FROM Laboratorio l
        LEFT JOIN Usuario u ON l.Id_RegistradoPor = u.id
        LEFT JOIN Tipos_Analisis ta ON l.Id_Tipo_Analisis = ta.id
        LEFT JOIN Pacientes p ON l.Id_Paciente = p.id
        WHERE l.Fecha >= ? AND l.Fecha <= ?
        ORDER BY l.Fecha
        """
        return self._execute_query(query, (inicio, fin), use_cache=False)

    def _get_egresos_gastos(self, inicio: str, fin: str) -> List[Dict[str, Any]]:
        """Obtiene egresos por gastos - FILTRADO POR HORA"""
        
        # ✅ USAR LOS TIMESTAMPS COMPLETOS (no extraer solo la fecha)
        query = """
        SELECT 
            g.id,
            g.Fecha,
            g.Monto as Total,
            0 as Descuento,
            g.Id_RegistradoPor as Id_Usuario,
            CONCAT(u.Nombre, ' ', u.Apellido_Paterno) as NombreUsuario,
            'GASTO' as TipoEgreso,
            CONCAT(tg.Nombre, ' - ', g.Descripcion) as Descripcion
        FROM Gastos g
        LEFT JOIN Usuario u ON g.Id_RegistradoPor = u.id
        LEFT JOIN Tipo_Gastos tg ON g.ID_Tipo = tg.id
        WHERE g.Fecha >= ? AND g.Fecha <= ?
        ORDER BY g.Fecha
        """
        # ✅ Pasar los timestamps completos (inicio, fin) sin modificar
        return self._execute_query(query, (inicio, fin), use_cache=False)
    
    def _get_ingresos_enfermeria(self, inicio: str, fin: str) -> List[Dict[str, Any]]:
        """Obtiene ingresos por procedimientos de enfermerÃ­a"""
        query = """
        SELECT 
            e.id,
            e.Fecha,
            (e.Cantidad * COALESCE(CASE WHEN e.Tipo = 'Emergencia' THEN tp.Precio_Emergencia ELSE tp.Precio_Normal END, 0)) as Total,
            0 as Descuento,
            e.Id_RegistradoPor as Id_Usuario,
            CONCAT(u.Nombre, ' ', u.Apellido_Paterno) as NombreUsuario,
            'ENFERMERIA' as TipoIngreso,
            CONCAT('Procedimiento - ', tp.Nombre, ' (Cant: ', e.Cantidad, ')') as Descripcion,
            CONCAT(p.Nombre, ' ', p.Apellido_Paterno) as NombrePaciente
        FROM Enfermeria e
        LEFT JOIN Usuario u ON e.Id_RegistradoPor = u.id
        LEFT JOIN Tipos_Procedimientos tp ON e.Id_Procedimiento = tp.id
        LEFT JOIN Pacientes p ON e.Id_Paciente = p.id
        WHERE e.Fecha >= ? AND e.Fecha <= ?
        ORDER BY e.Fecha
        """
        return self._execute_query(query, (inicio, fin), use_cache=False)
    
    def _get_ingresos_extras(self, inicio: str, fin: str) -> List[Dict[str, Any]]:
        """Obtiene ingresos extras"""
        # Extraer solo la fecha del timestamp inicio
        fecha_sql = inicio.split(' ')[0]  # "2025-10-07 08:00:00.000" â†’ "2025-10-07"
        
        query = """
        SELECT 
            ie.id,
            ie.fecha as Fecha,
            ie.monto as Total,
            0 as Descuento,
            ie.id_registradoPor as Id_Usuario,
            CONCAT(u.Nombre, ' ', u.Apellido_Paterno) as NombreUsuario,
            'INGRESO EXTRA' as TipoIngreso,
            ie.descripcion as Descripcion
        FROM IngresosExtras ie
        LEFT JOIN Usuario u ON ie.id_registradoPor = u.id
        WHERE CAST(ie.fecha AS DATE) = ?
        ORDER BY ie.fecha
        """
        return self._execute_query(query, (fecha_sql,), use_cache=False)
    
    def _procesar_datos_cierre(self, farmacia: List, consultas: List, laboratorio: List, 
                            enfermeria: List, ingresos_extras: List, gastos: List) -> Dict[str, Any]: 
        
        # Combinar todos los ingresos (AGREGAR INGRESOS EXTRAS)
        ingresos = []
        ingresos.extend(farmacia)
        ingresos.extend(consultas)
        ingresos.extend(laboratorio)
        ingresos.extend(enfermeria)
        ingresos.extend(ingresos_extras)  # NUEVO
        
        # Calcular totales (AGREGAR TOTAL INGRESOS EXTRAS)
        total_farmacia = sum(float(item.get('Total', 0)) for item in farmacia)
        total_consultas = sum(float(item.get('Total', 0)) for item in consultas)
        total_laboratorio = sum(float(item.get('Total', 0)) for item in laboratorio)
        total_enfermeria = sum(float(item.get('Total', 0)) for item in enfermeria)
        total_ingresos_extras = sum(float(item.get('Total', 0)) for item in ingresos_extras)  # NUEVO
        total_gastos = sum(float(item.get('Total', 0)) for item in gastos)
        
        total_ingresos = total_farmacia + total_consultas + total_laboratorio + total_enfermeria + total_ingresos_extras  
        total_egresos = total_gastos
        saldo_teorico = total_ingresos - total_egresos
        
        # Estructura de datos completa
        return {
            'ingresos': {
                'farmacia': farmacia,
                'consultas': consultas,
                'laboratorio': laboratorio,
                'enfermeria': enfermeria,
                'ingresos_extras': ingresos_extras,  # NUEVO
                'todos': ingresos
            },
            'egresos': {
                'gastos': gastos,
                'todos': gastos
            },
            'resumen': {
                'total_farmacia': round(total_farmacia, 2),
                'total_consultas': round(total_consultas, 2),
                'total_laboratorio': round(total_laboratorio, 2),
                'total_enfermeria': round(total_enfermeria, 2),
                'total_ingresos_extras': round(total_ingresos_extras, 2),  
                'total_ingresos': round(total_ingresos, 2),
                'total_egresos': round(total_egresos, 2),
                'saldo_teorico': round(saldo_teorico, 2),
                'transacciones_ingresos': len(ingresos),
                'transacciones_egresos': len(gastos),
                'transacciones_farmacia': len(farmacia),
                'transacciones_consultas': len(consultas),
                'transacciones_laboratorio': len(laboratorio),
                'transacciones_enfermeria': len(enfermeria),
                'transacciones_ingresos_extras': len(ingresos_extras)  
            },
            'timestamp': datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        }
        
    # ===============================
    # GESTIÃ“N DE CIERRES GUARDADOS
    # ===============================
    
    def verificar_cierre_previo(self, fecha: str, hora_inicio: str = None, hora_fin: str = None) -> bool:
        """Verifica si ya existe un cierre para la fecha y horario especÃ­fico"""
        try:
            fecha_sql = self._convertir_fecha_sql(fecha)
            
            if hora_inicio and hora_fin:
                # Verificar por horario especÃ­fico - permite mÃºltiples cierres por dÃ­a
                query = """
                SELECT COUNT(*) as count FROM CierreCaja 
                WHERE CAST(Fecha AS DATE) = ? 
                AND HoraInicio = ? AND HoraFin = ?
                """
                result = self._execute_query(query, (fecha_sql, hora_inicio, hora_fin), fetch_one=True, use_cache=False)
                print(f"ðŸ” Verificando cierre previo para {fecha} {hora_inicio}-{hora_fin}: {result['count'] if result else 0}")
            else:
                # Fallback: verificar solo por fecha (para compatibilidad)
                query = "SELECT COUNT(*) as count FROM CierreCaja WHERE CAST(Fecha AS DATE) = ?"
                result = self._execute_query(query, (fecha_sql,), fetch_one=True, use_cache=False)
                
            return result['count'] > 0 if result else False
        except Exception as e:
            print(f"âŒ Error verificando cierre previo: {e}")
            return False
    
    def guardar_cierre_caja(self, datos_cierre: Dict[str, Any]) -> bool:
        """Guarda el cierre de caja en la base de datos"""
        try:
            query = """
            INSERT INTO CierreCaja (
                Fecha, HoraInicio, HoraFin, EfectivoReal, SaldoTeorico, 
                Diferencia, IdUsuario, FechaCierre, Observaciones
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            """
            
            params = (
                datos_cierre['Fecha'],
                datos_cierre['HoraInicio'],
                datos_cierre['HoraFin'],
                datos_cierre['EfectivoReal'],
                datos_cierre['SaldoTeorico'],
                datos_cierre['Diferencia'],
                datos_cierre['IdUsuario'],
                datos_cierre['FechaCierre'],
                datos_cierre['Observaciones']
            )
            
            affected_rows = self._execute_query(query, params, fetch_all=False, use_cache=False)
            success = affected_rows > 0
            
            if success:
                print(f"âœ… Cierre guardado en BD - Efectivo: Bs {datos_cierre['EfectivoReal']:,.2f}")
            
            return success
            
        except Exception as e:
            print(f"âŒ Error guardando cierre: {e}")
            return False
    
    def get_cierres_por_fecha(self, fecha: str) -> List[Dict[str, Any]]:
        """Obtiene cierres realizados en una fecha"""
        try:
            fecha_sql = self._convertir_fecha_sql(fecha)
            query = """
            SELECT 
                cc.id,
                cc.Fecha,
                cc.HoraInicio,
                cc.HoraFin,
                cc.EfectivoReal,
                cc.SaldoTeorico,
                cc.Diferencia,
                cc.FechaCierre,
                cc.Observaciones,
                CONCAT(u.Nombre, ' ', u.Apellido_Paterno) as NombreUsuario
            FROM CierreCaja cc
            LEFT JOIN Usuario u ON cc.IdUsuario = u.id
            WHERE CAST(cc.Fecha AS DATE) = ?
            ORDER BY cc.FechaCierre DESC
            """
            return self._execute_query(query, (fecha_sql,), use_cache=False)
        except Exception as e:
            print(f"âŒ Error obteniendo cierres: {e}")
            return []
        
    def get_ultimo_cierre_del_dia(self, fecha: str) -> Optional[Dict[str, Any]]:
        """
        âœ… NUEVO: Obtiene el Ãºltimo cierre registrado para una fecha especÃ­fica
        Usado para auto-gestiÃ³n inteligente de horarios
        
        Args:
            fecha: Fecha en formato DD/MM/YYYY
            
        Returns:
            Dict con el Ãºltimo cierre del dÃ­a o None si no existe
        """
        try:
            fecha_sql = self._convertir_fecha_sql(fecha)
            
            query = """
            SELECT TOP 1
                cc.id,
                cc.Fecha,
                cc.HoraInicio,
                cc.HoraFin,
                cc.EfectivoReal,
                cc.SaldoTeorico,
                cc.Diferencia,
                cc.FechaCierre,
                cc.Observaciones,
                CONCAT(u.Nombre, ' ', u.Apellido_Paterno) as NombreUsuario
            FROM CierreCaja cc
            LEFT JOIN Usuario u ON cc.IdUsuario = u.id
            WHERE CAST(cc.Fecha AS DATE) = ?
            ORDER BY cc.HoraFin DESC, cc.FechaCierre DESC
            """
            
            resultado = self._execute_query(query, (fecha_sql,), fetch_one=True, use_cache=False)
            
            if resultado:
                print(f"âœ… Ãšltimo cierre encontrado: {resultado['HoraInicio']} - {resultado['HoraFin']}")
                return resultado
            else:
                print(f"â„¹ï¸ No hay cierres previos para {fecha}")
                return None
                
        except Exception as e:
            print(f"âŒ Error obteniendo Ãºltimo cierre del dÃ­a: {e}")
            return None
    
    def _estructura_vacia_cierre(self) -> Dict[str, Any]:
        """âœ… NUEVO: Retorna estructura vacÃ­a pero vÃ¡lida para cierre"""
        return {
            'ingresos': {
                'farmacia': [],
                'consultas': [],
                'laboratorio': [],
                'enfermeria': [],
                'ingresos_extras': [],
                'todos': []
            },
            'egresos': {
                'gastos': [],
                'todos': []
            },
            'resumen': {
                'total_farmacia': 0.0,
                'total_consultas': 0.0,
                'total_laboratorio': 0.0,
                'total_enfermeria': 0.0,
                'total_ingresos_extras': 0.0,
                'total_ingresos': 0.0,
                'total_egresos': 0.0,
                'saldo_teorico': 0.0,
                'transacciones_ingresos': 0,
                'transacciones_egresos': 0,
                'transacciones_farmacia': 0,
                'transacciones_consultas': 0,
                'transacciones_laboratorio': 0,
                'transacciones_enfermeria': 0,
                'transacciones_ingresos_extras': 0
            },
            'timestamp': datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        }
    # ===============================
    # VALIDACIONES
    # ===============================
    
    def validar_diferencia_permitida(self, efectivo_real: float, saldo_teorico: float, 
                                   limite: float = 50.0) -> Dict[str, Any]:
        """Valida si la diferencia estÃ¡ dentro del lÃ­mite permitido"""
        diferencia = efectivo_real - saldo_teorico
        diferencia_absoluta = abs(diferencia)
        
        if diferencia_absoluta <= 1.0:
            tipo = "NEUTRO"
        elif diferencia > 0:
            tipo = "SOBRANTE"
        else:
            tipo = "FALTANTE"
        
        return {
            'diferencia': round(diferencia, 2),
            'diferencia_absoluta': round(diferencia_absoluta, 2),
            'tipo': tipo,
            'dentro_limite': diferencia_absoluta <= limite,
            'requiere_autorizacion': diferencia_absoluta > limite,
            'limite_configurado': limite
        }
    
    # ===============================
    # GENERACIÃ“N DE DATOS PARA PDF
    # ===============================
    
    def generar_datos_pdf_arqueo(self, fecha: str, hora_inicio: str, hora_fin: str,
                                efectivo_real: float, observaciones: str = "") -> Dict[str, Any]:
        """Genera datos estructurados para el PDF del arqueo"""
        try:
            # Obtener datos completos
            datos_cierre = self.get_datos_cierre_completo(fecha, hora_inicio, hora_fin)
            
            # Estructura especÃ­fica para PDF
            datos_pdf = {
                'encabezado': {
                    'titulo': 'ARQUEO DE CAJA DIARIO',
                    'fecha': fecha,
                    'hora_inicio': hora_inicio,
                    'hora_fin': hora_fin,
                    'timestamp': datetime.now().strftime("%d/%m/%Y %H:%M:%S")
                },
                'movimientos': {
                    'ingresos': self._formatear_movimientos_pdf(datos_cierre['ingresos']['todos'], 'INGRESO'),
                    'egresos': self._formatear_movimientos_pdf(datos_cierre['egresos']['todos'], 'EGRESO')
                },
                'resumen_por_concepto': {
                    'farmacia': {
                        'total': datos_cierre['resumen']['total_farmacia'],
                        'transacciones': datos_cierre['resumen']['transacciones_farmacia']
                    },
                    'consultas': {
                        'total': datos_cierre['resumen']['total_consultas'],
                        'transacciones': datos_cierre['resumen']['transacciones_consultas']
                    },
                    'laboratorio': {
                        'total': datos_cierre['resumen']['total_laboratorio'],
                        'transacciones': datos_cierre['resumen']['transacciones_laboratorio']
                    },
                    'enfermeria': {
                        'total': datos_cierre['resumen']['total_enfermeria'],
                        'transacciones': datos_cierre['resumen']['transacciones_enfermeria']
                    },
                    'gastos': {
                        'total': datos_cierre['resumen']['total_egresos'],
                        'transacciones': datos_cierre['resumen']['transacciones_egresos']
                    }
                },
                'arqueo': {
                    'saldo_teorico': datos_cierre['resumen']['saldo_teorico'],
                    'efectivo_real': efectivo_real,
                    'diferencia': efectivo_real - datos_cierre['resumen']['saldo_teorico'],
                    'observaciones': observaciones
                }
            }
            
            return datos_pdf
            
        except Exception as e:
            print(f"âŒ Error generando datos PDF: {e}")
            return {}
        
    def get_ultimo_cierre_general(self) -> Optional[Dict[str, Any]]:
        """
        ✅ NUEVO: Obtiene el ÚLTIMO cierre registrado en el sistema (de cualquier fecha)
        """
        try:
            query = """
            SELECT TOP 1
                cc.id,
                cc.Fecha,
                cc.HoraInicio,
                cc.HoraFin,
                cc.EfectivoReal,
                cc.SaldoTeorico,
                cc.Diferencia,
                cc.FechaCierre,
                cc.Observaciones,
                CONCAT(u.Nombre, ' ', u.Apellido_Paterno) as NombreUsuario
            FROM CierreCaja cc
            LEFT JOIN Usuario u ON cc.IdUsuario = u.id
            ORDER BY cc.Fecha DESC, cc.HoraFin DESC, cc.FechaCierre DESC
            """
            
            resultado = self._execute_query(query, (), fetch_one=True, use_cache=False)
            
            if resultado:
                print(f"✅ Último cierre general encontrado")
                return resultado
            else:
                print(f"ℹ️ No hay cierres previos en el sistema")
                return None
                
        except Exception as e:
            print(f"❌ Error obteniendo último cierre general: {e}")
            return None
    def get_cierres_semana_actual(self, fecha_referencia: str) -> List[Dict[str, Any]]:
        """Obtiene cierres de toda la semana actual - VERSIÓN ROBUSTA"""
        try:
            print(f"📋 Iniciando consulta de cierres semana para: {fecha_referencia}")
            
            # ✅ VALIDAR FECHA DE ENTRADA
            if not fecha_referencia or fecha_referencia.strip() == "":
                print("❌ Fecha de referencia vacía")
                return []
            
            fecha_sql = self._convertir_fecha_sql(fecha_referencia)
            
            # Calcular inicio y fin de semana
            from datetime import datetime, timedelta
            
            try:
                fecha_obj = datetime.strptime(fecha_sql, "%Y-%m-%d")
            except ValueError as e:
                print(f"❌ Error parseando fecha: {e}")
                return []
            
            inicio_semana = fecha_obj - timedelta(days=fecha_obj.weekday())
            fin_semana = inicio_semana + timedelta(days=6)
            
            # SQL COMPATIBLE con todas las bases de datos
            query = """
            SELECT 
                cc.id,
                cc.Fecha,
                cc.HoraInicio,
                cc.HoraFin,
                cc.EfectivoReal,
                cc.SaldoTeorico,
                cc.Diferencia,
                cc.FechaCierre,
                cc.Observaciones,
                u.Nombre as NombreUsuario,
                u.Apellido_Paterno as ApellidoUsuario,
                cc.IdUsuario
            FROM CierreCaja cc
            LEFT JOIN Usuario u ON cc.IdUsuario = u.id
            WHERE CAST(cc.Fecha AS DATE) BETWEEN ? AND ?
            ORDER BY cc.Fecha DESC, cc.FechaCierre DESC
            """
            
            print(f"📋 Consultando desde {inicio_semana.strftime('%Y-%m-%d')} hasta {fin_semana.strftime('%Y-%m-%d')}")
            
            # ✅ EJECUTAR QUERY CON MANEJO DE ERRORES
            try:
                resultados = self._execute_query(
                    query, 
                    (inicio_semana.strftime("%Y-%m-%d"), fin_semana.strftime("%Y-%m-%d")), 
                    use_cache=False
                )
            except Exception as query_error:
                print(f"❌ Error ejecutando query: {query_error}")
                return []  # ✅ RETORNAR LISTA VACÍA, NO None
            
            # ✅ VALIDAR RESULTADOS
            if not resultados:
                print("ℹ️ No se encontraron cierres para esta semana")
                return []
            
            if not isinstance(resultados, list):
                print(f"❌ Resultados no son una lista: {type(resultados)}")
                return []
            
            # Procesar resultados en Python (más seguro)
            cierres_procesados = []
            
            for cierre in resultados:
                if not isinstance(cierre, dict):
                    continue
                
                try:
                    # ✅ CONVERTIR objetos datetime a strings
                    fecha = cierre.get('Fecha')
                    if hasattr(fecha, 'strftime'):
                        fecha_str = fecha.strftime("%d/%m/%Y")
                    else:
                        fecha_str = str(fecha) if fecha else "--/--/----"
                    
                    hora_inicio = cierre.get('HoraInicio')
                    if hasattr(hora_inicio, 'strftime'):
                        hora_inicio_str = hora_inicio.strftime("%H:%M")
                    else:
                        hora_inicio_str = str(hora_inicio) if hora_inicio else "--:--"
                    
                    hora_fin = cierre.get('HoraFin') 
                    if hasattr(hora_fin, 'strftime'):
                        hora_fin_str = hora_fin.strftime("%H:%M")
                    else:
                        hora_fin_str = str(hora_fin) if hora_fin else "--:--"
                    
                    cierre_procesado = {
                        'id': cierre.get('id'),
                        'Fecha': fecha_str,  # ✅ Ya formateado como string
                        'HoraInicio': hora_inicio_str,  # ✅ Ya formateado como string
                        'HoraFin': hora_fin_str,  # ✅ Ya formateado como string
                        'EfectivoReal': cierre.get('EfectivoReal'),
                        'SaldoTeorico': cierre.get('SaldoTeorico'),
                        'Diferencia': cierre.get('Diferencia'),
                        'FechaCierre': cierre.get('FechaCierre'),
                        'Observaciones': cierre.get('Observaciones'),
                        'NombreUsuario': f"{cierre.get('NombreUsuario', '')} {cierre.get('ApellidoUsuario', '')}".strip(),
                        'HoraCierre': self._extraer_hora_cierre(cierre.get('FechaCierre'))
                    }
                    cierres_procesados.append(cierre_procesado)
                except Exception as proc_error:
                    print(f"❌ Error procesando cierre: {proc_error}")
                    continue
            
            print(f"✅ Cierres procesados correctamente: {len(cierres_procesados)}")
            return cierres_procesados
            
        except Exception as e:
            print(f"❌ ERROR CRÍTICO en get_cierres_semana_actual: {e}")
            print(f"❌ Tipo de error: {type(e).__name__}")
            import traceback
            traceback.print_exc()
            return []   # ✅ Asegúrate de que esta línea esté correcta
    def _extraer_hora_cierre(self, fecha_cierre):
        """Extrae la hora de cierre de forma segura - VERSIÓN MEJORADA"""
        try:
            if not fecha_cierre:
                return "--:--"
            
            fecha_str = str(fecha_cierre)
            
            # Manejar diferentes formatos de fecha/hora
            if ' ' in fecha_str and ':' in fecha_str:
                # Formato: "2025-01-15 14:30:25.123"
                partes = fecha_str.split(' ')
                if len(partes) >= 2:
                    hora_parte = partes[1]
                    hora_minutos = hora_parte.split(':')[:2]  # Tomar solo HH:MM
                    return ':'.join(hora_minutos)
            
            # Si es solo hora (HH:MM:SS)
            if ':' in fecha_str:
                partes = fecha_str.split(':')[:2]  # Tomar solo HH:MM
                return ':'.join(partes)
                
            return "--:--"
        except Exception as e:
            print(f"❌ Error extrayendo hora de cierre: {e}")
            return "--:--"

    def get_tipos_gastos(self) -> List[Dict[str, Any]]:
        """Obtiene todos los tipos de gastos para clasificaciÃ³n"""
        query = """
        SELECT 
            id,
            Nombre,
            descripcion
        FROM Tipo_Gastos
        WHERE id IS NOT NULL
        ORDER BY Nombre
        """
        return self._execute_query(query, (), use_cache=False)

    def get_gastos_detallados(self, inicio: str, fin: str) -> List[Dict[str, Any]]:
        """Obtiene gastos con detalles completos por tipo"""
        # ✅ CORRECCIÓN: Extraer solo la fecha del timestamp para comparación correcta
        fecha_inicio_sql = inicio.split(' ')[0] if ' ' in inicio else inicio
        fecha_fin_sql = fin.split(' ')[0] if ' ' in fin else fin
        
        query = """
        SELECT 
            g.id,
            g.Fecha,
            g.Monto,
            g.Descripcion as DescripcionGasto,
            g.Proveedor,
            tg.Nombre as TipoGasto,
            tg.descripcion as DescripcionTipo,
            CONCAT(u.Nombre, ' ', u.Apellido_Paterno) as RegistradoPor,
            g.Id_RegistradoPor
        FROM Gastos g
        LEFT JOIN Usuario u ON g.Id_RegistradoPor = u.id
        LEFT JOIN Tipo_Gastos tg ON g.ID_Tipo = tg.id
        WHERE CAST(g.Fecha AS DATE) >= CAST(? AS DATE) 
          AND CAST(g.Fecha AS DATE) <= CAST(? AS DATE)
        ORDER BY tg.Nombre, g.Fecha DESC
        """
        return self._execute_query(query, (fecha_inicio_sql, fecha_fin_sql), use_cache=False)

    def get_resumen_gastos_por_tipo(self, inicio: str, fin: str) -> List[Dict[str, Any]]:
        """Obtiene resumen de gastos agrupados por tipo"""
        # ✅ CORRECCIÓN: Extraer solo la fecha del timestamp para comparación correcta
        fecha_inicio_sql = inicio.split(' ')[0] if ' ' in inicio else inicio
        fecha_fin_sql = fin.split(' ')[0] if ' ' in fin else fin
        
        query = """
        SELECT 
            tg.Nombre as TipoGasto,
            COUNT(g.id) as CantidadGastos,
            SUM(g.Monto) as TotalGastos,
            AVG(g.Monto) as PromedioGasto
        FROM Gastos g
        LEFT JOIN Tipo_Gastos tg ON g.ID_Tipo = tg.id
        WHERE CAST(g.Fecha AS DATE) >= CAST(? AS DATE) 
          AND CAST(g.Fecha AS DATE) <= CAST(? AS DATE)
        GROUP BY tg.id, tg.Nombre
        ORDER BY SUM(g.Monto) DESC
        """
        return self._execute_query(query, (fecha_inicio_sql, fecha_fin_sql), use_cache=False)

    def get_resumen_por_categorias(self, fecha: str, hora_inicio: str, hora_fin: str) -> Dict[str, Any]:
        """Obtiene resumen organizado por categorÃ­as para el QML"""
        try:
            datos_completos = self.get_datos_cierre_completo(fecha, hora_inicio, hora_fin)
            
            # Organizar ingresos por categorÃ­a
            ingresos_por_categoria = [
                {
                    'concepto': 'FARMACIA',
                    'transacciones': datos_completos['resumen']['transacciones_farmacia'],
                    'importe': datos_completos['resumen']['total_farmacia']
                },
                {
                    'concepto': 'CONSULTAS MEDICAS',
                    'transacciones': datos_completos['resumen']['transacciones_consultas'],
                    'importe': datos_completos['resumen']['total_consultas']
                },
                {
                    'concepto': 'LABORATORIO',
                    'transacciones': datos_completos['resumen']['transacciones_laboratorio'],
                    'importe': datos_completos['resumen']['total_laboratorio']
                },
                {
                    'concepto': 'ENFERMERIA',
                    'transacciones': datos_completos['resumen']['transacciones_enfermeria'],
                    'importe': datos_completos['resumen']['total_enfermeria']
                },
                {
                    'concepto': 'INGRESOS EXTRAS',
                    'transacciones': datos_completos['resumen']['transacciones_ingresos_extras'],
                    'importe': datos_completos['resumen']['total_ingresos_extras']
                }
            ]
            
            # Organizar egresos - TODOS LOS GASTOS JUNTOS
            egresos_por_categoria = [
                {
                    'concepto': 'GASTOS DEL DIA',
                    'detalle': f'{datos_completos["resumen"]["transacciones_egresos"]} transacciones de gastos',
                    'importe': datos_completos['resumen']['total_egresos']
                }
            ]
            
            return {
                'ingresos_por_categoria': ingresos_por_categoria,
                'egresos_por_categoria': egresos_por_categoria,
                'transacciones_ingresos': datos_completos['resumen']['transacciones_ingresos'],
                'transacciones_egresos': datos_completos['resumen']['transacciones_egresos'],
                'total_ingresos': datos_completos['resumen']['total_ingresos'],
                'total_egresos': datos_completos['resumen']['total_egresos'],
                'saldo_teorico': datos_completos['resumen']['saldo_teorico']
            }
            
        except Exception as e:
            print(f"âŒ Error generando resumen por categorÃ­as: {e}")
            import traceback
            traceback.print_exc()
            # âœ… RETORNAR ESTRUCTURA VÃLIDA EN LUGAR DE DATOS VACÃOS INCORRECTOS
            return {
                'ingresos_por_categoria': [],
                'egresos_por_categoria': [],
                'transacciones_ingresos': 0,
                'transacciones_egresos': 0,
                'total_ingresos': 0.0,
                'total_egresos': 0.0,
                'saldo_teorico': 0.0
            }
    def _formatear_movimientos_pdf(self, movimientos: List[Dict], tipo: str) -> List[Dict]:
        """Formatea movimientos para el PDF"""
        movimientos_formateados = []
        
        for mov in movimientos:
            movimiento_pdf = {
                'fecha': self._formatear_fecha_hora(mov.get('Fecha', '')),
                'descripcion': mov.get('Descripcion', ''),
                'tipo': mov.get('TipoIngreso', mov.get('TipoEgreso', tipo)),
                'monto': float(mov.get('Total', 0)),
                'usuario': mov.get('NombreUsuario', ''),
                'paciente': mov.get('NombrePaciente', '') if 'NombrePaciente' in mov else ''
            }
            movimientos_formateados.append(movimiento_pdf)
        
        return movimientos_formateados
    
    # ===============================
    # MÃ‰TODOS DE UTILIDAD
    # ===============================
    
    def _convertir_fecha_sql(self, fecha: str) -> str:
        """Convierte fecha DD/MM/YYYY a YYYY-MM-DD - VERSIÃ“N VALIDADA"""
        try:
            # âœ… VALIDAR ENTRADA
            if not fecha or fecha.strip() == "":
                print("âš ï¸ Fecha vacÃ­a, usando fecha actual")
                return datetime.now().strftime("%Y-%m-%d")
            
            fecha = fecha.strip()
            
            # Si ya estÃ¡ en formato YYYY-MM-DD, retornarla
            if '-' in fecha and len(fecha.split('-')[0]) == 4:
                return fecha
            
            # Convertir de DD/MM/YYYY a YYYY-MM-DD
            if '/' in fecha:
                partes = fecha.split('/')
                
                # âœ… VALIDAR QUE TENGA 3 PARTES
                if len(partes) != 3:
                    print(f"âš ï¸ Formato de fecha invÃ¡lido: {fecha}")
                    return datetime.now().strftime("%Y-%m-%d")
                
                dia, mes, anio = partes
                
                # âœ… VALIDAR QUE SEAN NÃšMEROS
                try:
                    dia = int(dia)
                    mes = int(mes)
                    anio = int(anio)
                except ValueError:
                    print(f"âš ï¸ Fecha con valores no numÃ©ricos: {fecha}")
                    return datetime.now().strftime("%Y-%m-%d")
                
                # âœ… VALIDAR RANGOS
                if not (1 <= dia <= 31 and 1 <= mes <= 12 and 2020 <= anio <= 2030):
                    print(f"âš ï¸ Fecha fuera de rango vÃ¡lido: {fecha}")
                    return datetime.now().strftime("%Y-%m-%d")
                
                return f"{anio:04d}-{mes:02d}-{dia:02d}"
            
            # Si no tiene formato reconocible, usar fecha actual
            print(f"âš ï¸ Formato de fecha no reconocido: {fecha}")
            return datetime.now().strftime("%Y-%m-%d")
            
        except Exception as e:
            print(f"âŒ Error convirtiendo fecha: {e}")
            return datetime.now().strftime("%Y-%m-%d")
    
    def _formatear_fecha_hora(self, fecha_str: str) -> str:
        """Formatea fecha para mostrar"""
        try:
            if isinstance(fecha_str, str):
                fecha_obj = datetime.fromisoformat(fecha_str.replace('Z', '+00:00'))
                return fecha_obj.strftime("%d/%m/%Y %H:%M")
            return str(fecha_str)
        except:
            return str(fecha_str)
    
    # SIN CACHÃ‰ - todas las consultas son directas a BD
    def invalidar_cache_transaccion(self):
        """MÃ©todo vacÃ­o - no usa cachÃ©"""
        pass
    
    def refresh_cache_immediately(self):
        """MÃ©todo vacÃ­o - no usa cachÃ©"""
        pass
    
    def invalidar_cache_completo(self):
        """MÃ©todo vacÃ­o - no usa cachÃ©"""
        pass