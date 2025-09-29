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
        print("💰 CierreCajaRepository inicializado - Modo independiente")
    
    # ===============================
    # IMPLEMENTACIÓN ABSTRACTA REQUERIDA
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
            fecha_sql = self._convertir_fecha_sql(fecha)
            
            # Construir timestamps completos
            timestamp_inicio = f"{fecha_sql} {hora_inicio}:00.000"
            timestamp_fin = f"{fecha_sql} {hora_fin}:59.999"
            
            print(f"🔍 Consultando datos de cierre: {timestamp_inicio} a {timestamp_fin}")
            
            # Obtener todos los datos
            ingresos_farmacia = self._get_ingresos_farmacia(timestamp_inicio, timestamp_fin)
            ingresos_consultas = self._get_ingresos_consultas(timestamp_inicio, timestamp_fin)
            ingresos_laboratorio = self._get_ingresos_laboratorio(timestamp_inicio, timestamp_fin)
            ingresos_enfermeria = self._get_ingresos_enfermeria(timestamp_inicio, timestamp_fin)
            egresos_gastos = self._get_egresos_gastos(timestamp_inicio, timestamp_fin)
            
            # Procesar y estructurar datos
            datos_procesados = self._procesar_datos_cierre(
                ingresos_farmacia, ingresos_consultas, ingresos_laboratorio,
                ingresos_enfermeria, egresos_gastos
            )
            
            print(f"✅ Datos procesados - Ingresos: Bs {datos_procesados['resumen']['total_ingresos']:,.2f}")
            return datos_procesados
            
        except Exception as e:
            print(f"❌ Error obteniendo datos de cierre: {e}")
            raise DatabaseQueryError(f"Error consultando datos de cierre: {str(e)}")
    
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
        """Obtiene ingresos por consultas médicas"""
        query = """
        SELECT 
            c.id,
            c.Fecha,
            COALESCE(e.Precio_Normal, 0) as Total,
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
        """Obtiene ingresos por análisis de laboratorio"""
        query = """
        SELECT 
            l.id,
            l.Fecha,
            COALESCE(ta.Precio_Normal, 0) as Total,
            0 as Descuento,
            l.Id_RegistradoPor as Id_Usuario,
            CONCAT(u.Nombre, ' ', u.Apellido_Paterno) as NombreUsuario,
            'LABORATORIO' as TipoIngreso,
            CONCAT('Análisis - ', ta.Nombre) as Descripcion,
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
        """Obtiene egresos por gastos"""
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
        return self._execute_query(query, (inicio, fin), use_cache=False)
    
    def _get_ingresos_enfermeria(self, inicio: str, fin: str) -> List[Dict[str, Any]]:
        """Obtiene ingresos por procedimientos de enfermería"""
        query = """
        SELECT 
            e.id,
            e.Fecha,
            (e.Cantidad * COALESCE(tp.Precio_Normal, 0)) as Total,
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
    def _procesar_datos_cierre(self, farmacia: List, consultas: List, laboratorio: List, 
                              enfermeria: List, gastos: List) -> Dict[str, Any]:
        """Procesa y estructura todos los datos para el cierre"""
        
        # Combinar todos los ingresos
        ingresos = []
        ingresos.extend(farmacia)
        ingresos.extend(consultas)
        ingresos.extend(laboratorio)
        ingresos.extend(enfermeria)
        
        # Calcular totales
        total_farmacia = sum(float(item.get('Total', 0)) for item in farmacia)
        total_consultas = sum(float(item.get('Total', 0)) for item in consultas)
        total_laboratorio = sum(float(item.get('Total', 0)) for item in laboratorio)
        total_enfermeria = sum(float(item.get('Total', 0)) for item in enfermeria)
        total_gastos = sum(float(item.get('Total', 0)) for item in gastos)
        
        total_ingresos = total_farmacia + total_consultas + total_laboratorio + total_enfermeria
        total_egresos = total_gastos
        saldo_teorico = total_ingresos - total_egresos
        
        # Estructura de datos completa
        return {
            'ingresos': {
                'farmacia': farmacia,
                'consultas': consultas,
                'laboratorio': laboratorio,
                'enfermeria': enfermeria,
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
                'total_ingresos': round(total_ingresos, 2),
                'total_egresos': round(total_egresos, 2),
                'saldo_teorico': round(saldo_teorico, 2),
                'transacciones_ingresos': len(ingresos),
                'transacciones_egresos': len(gastos),
                'transacciones_farmacia': len(farmacia),
                'transacciones_consultas': len(consultas),
                'transacciones_laboratorio': len(laboratorio),
                'transacciones_enfermeria': len(enfermeria)
            },
            'timestamp': datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        }
    
    # ===============================
    # GESTIÓN DE CIERRES GUARDADOS
    # ===============================
    
    def verificar_cierre_previo(self, fecha: str, hora_inicio: str = None, hora_fin: str = None) -> bool:
        """Verifica si ya existe un cierre para la fecha y horario específico"""
        try:
            fecha_sql = self._convertir_fecha_sql(fecha)
            
            if hora_inicio and hora_fin:
                # Verificar por horario específico - permite múltiples cierres por día
                query = """
                SELECT COUNT(*) as count FROM CierreCaja 
                WHERE CAST(Fecha AS DATE) = ? 
                AND HoraInicio = ? AND HoraFin = ?
                """
                result = self._execute_query(query, (fecha_sql, hora_inicio, hora_fin), fetch_one=True, use_cache=False)
                print(f"🔍 Verificando cierre previo para {fecha} {hora_inicio}-{hora_fin}: {result['count'] if result else 0}")
            else:
                # Fallback: verificar solo por fecha (para compatibilidad)
                query = "SELECT COUNT(*) as count FROM CierreCaja WHERE CAST(Fecha AS DATE) = ?"
                result = self._execute_query(query, (fecha_sql,), fetch_one=True, use_cache=False)
                
            return result['count'] > 0 if result else False
        except Exception as e:
            print(f"❌ Error verificando cierre previo: {e}")
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
                print(f"✅ Cierre guardado en BD - Efectivo: Bs {datos_cierre['EfectivoReal']:,.2f}")
            
            return success
            
        except Exception as e:
            print(f"❌ Error guardando cierre: {e}")
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
            print(f"❌ Error obteniendo cierres: {e}")
            return []
    
    # ===============================
    # VALIDACIONES
    # ===============================
    
    def validar_diferencia_permitida(self, efectivo_real: float, saldo_teorico: float, 
                                   limite: float = 50.0) -> Dict[str, Any]:
        """Valida si la diferencia está dentro del límite permitido"""
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
    # GENERACIÓN DE DATOS PARA PDF
    # ===============================
    
    def generar_datos_pdf_arqueo(self, fecha: str, hora_inicio: str, hora_fin: str,
                                efectivo_real: float, observaciones: str = "") -> Dict[str, Any]:
        """Genera datos estructurados para el PDF del arqueo"""
        try:
            # Obtener datos completos
            datos_cierre = self.get_datos_cierre_completo(fecha, hora_inicio, hora_fin)
            
            # Estructura específica para PDF
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
            print(f"❌ Error generando datos PDF: {e}")
            return {}
    
    def get_cierres_semana_actual(self, fecha_referencia: str) -> List[Dict[str, Any]]:
        """Obtiene cierres de toda la semana actual"""
        try:
            print(f"📅 Iniciando consulta de cierres semana para: {fecha_referencia}")
            
            fecha_sql = self._convertir_fecha_sql(fecha_referencia)
            
            # Calcular inicio y fin de semana
            from datetime import datetime, timedelta
            fecha_obj = datetime.strptime(fecha_sql, "%Y-%m-%d")
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
            
            print(f"📅 Consultando desde {inicio_semana.strftime('%Y-%m-%d')} hasta {fin_semana.strftime('%Y-%m-%d')}")
            
            resultados = self._execute_query(query, (inicio_semana.strftime("%Y-%m-%d"), fin_semana.strftime("%Y-%m-%d")), use_cache=False)
            
            # Procesar resultados en Python (más seguro)
            cierres_procesados = []
            for cierre in resultados:
                cierre_procesado = {
                    'id': cierre.get('id'),
                    'Fecha': cierre.get('Fecha'),
                    'HoraInicio': cierre.get('HoraInicio'),
                    'HoraFin': cierre.get('HoraFin'),
                    'EfectivoReal': cierre.get('EfectivoReal'),
                    'SaldoTeorico': cierre.get('SaldoTeorico'),
                    'Diferencia': cierre.get('Diferencia'),
                    'FechaCierre': cierre.get('FechaCierre'),
                    'Observaciones': cierre.get('Observaciones'),
                    'NombreUsuario': f"{cierre.get('NombreUsuario', '')} {cierre.get('ApellidoUsuario', '')}".strip(),
                    'HoraCierre': self._extraer_hora_cierre(cierre.get('FechaCierre'))
                }
                cierres_procesados.append(cierre_procesado)
            
            print(f"✅ Cierres procesados correctamente: {len(cierres_procesados)}")
            return cierres_procesados
            
        except Exception as e:
            print(f"❌ ERROR CRÍTICO en get_cierres_semana_actual: {e}")
            print(f"❌ Tipo de error: {type(e).__name__}")
            return []

    def _extraer_hora_cierre(self, fecha_cierre):
        """Extrae la hora de cierre de forma segura"""
        try:
            if isinstance(fecha_cierre, str):
                # Intentar parsear la fecha
                fecha_obj = datetime.fromisoformat(fecha_cierre.replace('Z', '+00:00'))
                return fecha_obj.strftime("%H:%M")
            elif hasattr(fecha_cierre, 'strftime'):
                return fecha_cierre.strftime("%H:%M")
            else:
                return "--:--"
        except:
            return "--:--"

    def get_tipos_gastos(self) -> List[Dict[str, Any]]:
        """Obtiene todos los tipos de gastos para clasificación"""
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
        WHERE g.Fecha >= ? AND g.Fecha <= ?
        ORDER BY tg.Nombre, g.Fecha DESC
        """
        return self._execute_query(query, (inicio, fin), use_cache=False)

    def get_resumen_gastos_por_tipo(self, inicio: str, fin: str) -> List[Dict[str, Any]]:
        """Obtiene resumen de gastos agrupados por tipo"""
        query = """
        SELECT 
            tg.Nombre as TipoGasto,
            COUNT(g.id) as CantidadGastos,
            SUM(g.Monto) as TotalGastos,
            AVG(g.Monto) as PromedioGasto
        FROM Gastos g
        LEFT JOIN Tipo_Gastos tg ON g.ID_Tipo = tg.id
        WHERE g.Fecha >= ? AND g.Fecha <= ?
        GROUP BY tg.id, tg.Nombre
        ORDER BY SUM(g.Monto) DESC
        """
        return self._execute_query(query, (inicio, fin), use_cache=False)

    def get_resumen_por_categorias(self, fecha: str, hora_inicio: str, hora_fin: str) -> Dict[str, Any]:
        """Obtiene resumen organizado por categorías para el QML"""
        try:
            datos_completos = self.get_datos_cierre_completo(fecha, hora_inicio, hora_fin)
            
            # Organizar ingresos por categoría
            ingresos_por_categoria = [
                {
                    'concepto': 'FARMACIA',
                    'transacciones': datos_completos['resumen']['transacciones_farmacia'],
                    'importe': datos_completos['resumen']['total_farmacia']
                },
                {
                    'concepto': 'CONSULTAS MÉDICAS',
                    'transacciones': datos_completos['resumen']['transacciones_consultas'],
                    'importe': datos_completos['resumen']['total_consultas']
                },
                {
                    'concepto': 'LABORATORIO',
                    'transacciones': datos_completos['resumen']['transacciones_laboratorio'],
                    'importe': datos_completos['resumen']['total_laboratorio']
                },
                {
                    'concepto': 'ENFERMERÍA',
                    'transacciones': datos_completos['resumen']['transacciones_enfermeria'],
                    'importe': datos_completos['resumen']['total_enfermeria']
                }
            ]
            
            # Organizar egresos - TODOS LOS GASTOS JUNTOS
            egresos_por_categoria = [
                {
                    'concepto': 'GASTOS DEL DÍA',
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
            print(f"❌ Error generando resumen por categorías: {e}")
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
    # MÉTODOS DE UTILIDAD
    # ===============================
    
    def _convertir_fecha_sql(self, fecha: str) -> str:
        """Convierte fecha DD/MM/YYYY a YYYY-MM-DD"""
        try:
            if '/' in fecha:
                partes = fecha.split('/')
                return f"{partes[2]}-{partes[1]:0>2}-{partes[0]:0>2}"
            return fecha
        except:
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
    
    # SIN CACHÉ - todas las consultas son directas a BD
    def invalidar_cache_transaccion(self):
        """Método vacío - no usa caché"""
        pass
    
    def refresh_cache_immediately(self):
        """Método vacío - no usa caché"""
        pass
    
    def invalidar_cache_completo(self):
        """Método vacío - no usa caché"""
        pass