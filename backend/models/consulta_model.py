from PySide6.QtCore import QObject, Signal, Slot, Property, QTimer
from PySide6.QtQml import qmlRegisterType
from typing import List, Dict, Any, Optional
from datetime import datetime, timedelta

from ..repositories.consulta_repository import ConsultaRepository
from ..repositories.paciente_repository import PacienteRepository
from ..repositories.doctor_repository import DoctorRepository
from ..repositories.usuario_repository import UsuarioRepository
from ..core.excepciones import (
    ValidationError, ExceptionHandler, safe_execute
)
from ..core.utils import (
    formatear_fecha, formatear_precio, preparar_para_qml,
    formatear_nombre_completo, safe_int, safe_float
)

class ConsultaModel(QObject):
    """
    Model QObject para gestión de consultas médicas
    Conecta directamente con QML mediante Signals/Slots/Properties
    """
    
    # ===============================
    # SIGNALS PARA QML
    # ===============================
    
    # Signals de datos
    consultasRecientesChanged = Signal()
    consultaActualChanged = Signal()
    estadisticasDashboardChanged = Signal()
    doctoresDisponiblesChanged = Signal()
    especialidadesChanged = Signal()
    pacientesRecientesChanged = Signal()
    historialConsultasChanged = Signal()
    
    # Signals de operaciones
    consultaCreada = Signal(int, str)      # consulta_id, paciente_nombre
    consultaActualizada = Signal(int)      # consulta_id
    operacionExitosa = Signal(str)         # mensaje
    operacionError = Signal(str)           # mensaje_error
    
    # Signals de estados
    loadingChanged = Signal()
    procesandoConsultaChanged = Signal()
    buscandoChanged = Signal()
    
    def __init__(self):
        super().__init__()

        QTimer.singleShot(100, self._cargar_consultas_recientes)
        
        # Repositories
        self.consulta_repo = ConsultaRepository()
        self.paciente_repo = PacienteRepository()
        self.doctor_repo = DoctorRepository()
        self.usuario_repo = UsuarioRepository()
        
        # Datos internos
        self._consultas_recientes = []
        self._consulta_actual = {}
        self._estadisticas_dashboard = {}
        self._doctores_disponibles = []
        self._especialidades = []
        self._pacientes_recientes = []
        self._historial_consultas = []
        
        # Estados
        self._loading = False
        self._procesando_consulta = False
        self._buscando = False
        
        # Configuración
        self._usuario_actual = 0
        self._filtros_activos = {}
        
        # Timer para actualización automática
        self.update_timer = QTimer()
        self.update_timer.timeout.connect(self._auto_update_consultas)
        self.update_timer.start(180000)  # 3 minutos
        
        # Cargar datos iniciales
        self._cargar_datos_iniciales()
        
        print("🩺 ConsultaModel inicializado")
    
    # ===============================
    # PROPERTIES PARA QML
    # ===============================
    
    @Property(list, notify=consultasRecientesChanged)
    def consultas_recientes(self):
        """Lista de consultas recientes"""
        return self._consultas_recientes
    
    @Property('QVariant', notify=consultaActualChanged)
    def consulta_actual(self):
        """Consulta actualmente seleccionada"""
        return self._consulta_actual
    
    @Property('QVariant', notify=estadisticasDashboardChanged)
    def estadisticas_dashboard(self):
        """Estadísticas para dashboard"""
        return self._estadisticas_dashboard
    
    @Property(list, notify=doctoresDisponiblesChanged)
    def doctores_disponibles(self):
        """Lista de doctores disponibles"""
        return self._doctores_disponibles
    
    @Property(list, notify=especialidadesChanged)
    def especialidades(self):
        """Lista de especialidades disponibles"""
        return self._especialidades
    
    @Property(list, notify=pacientesRecientesChanged)
    def pacientes_recientes(self):
        """Lista de pacientes recientes"""
        return self._pacientes_recientes
    
    @Property(list, notify=historialConsultasChanged)
    def historial_consultas(self):
        """Historial de consultas filtrado"""
        return self._historial_consultas
    
    @Property(bool, notify=loadingChanged)
    def loading(self):
        """Estado de carga general"""
        return self._loading
    
    @Property(bool, notify=procesandoConsultaChanged)
    def procesando_consulta(self):
        """Estado de procesamiento de consulta"""
        return self._procesando_consulta
    
    @Property(bool, notify=buscandoChanged)
    def buscando(self):
        """Estado de búsqueda"""
        return self._buscando
    
    # Properties de estadísticas rápidas
    @Property(int, notify=consultasRecientesChanged)
    def total_consultas_hoy(self):
        """Total consultas de hoy"""
        hoy = datetime.now().strftime('%Y-%m-%d')
        return len([c for c in self._consultas_recientes 
                   if c.get('Fecha', '').startswith(hoy)])
    
    @Property(int, notify=estadisticasDashboardChanged)
    def pacientes_atendidos_hoy(self):
        """Pacientes únicos atendidos hoy"""
        return self._estadisticas_dashboard.get('metricas_hoy', {}).get('pacientes_hoy', 0)
    
    @Property(int, notify=doctoresDisponiblesChanged)
    def doctores_activos(self):
        """Total doctores activos"""
        return len(self._doctores_disponibles)
    
    @Property(float, notify=estadisticasDashboardChanged)
    def ingresos_estimados_mes(self):
        """Ingresos estimados del mes"""
        return float(self._estadisticas_dashboard.get('metricas_generales', {}).get('ingresos_mes', 0))
    
    # ===============================
    # SLOTS PARA QML - CONFIGURACIÓN
    # ===============================
    
    @Slot(int)
    def set_usuario_actual(self, usuario_id: int):
        """Establece el usuario actual"""
        if usuario_id > 0:
            self._usuario_actual = usuario_id
            print(f"👤 Usuario establecido para consultas: {usuario_id}")
    
    @Slot()
    def refresh_consultas(self):
        """Refresca las consultas recientes"""
        self._cargar_consultas_recientes()
    
    @Slot()
    def refresh_dashboard(self):
        """Refresca estadísticas del dashboard"""
        self._cargar_estadisticas_dashboard()
    
    @Slot()
    def refresh_doctores(self):
        """Refresca lista de doctores"""
        self._cargar_doctores_disponibles()
    
    @Slot()
    def refresh_especialidades(self):
        """Refresca especialidades"""
        self._cargar_especialidades()
    
    # ===============================
    # SLOTS PARA QML - GESTIÓN CONSULTAS
    # ===============================
    
    @Slot('QVariant', result=int)
    def crear_consulta(self, datos_consulta):
        """
        Crea nueva consulta
        datos_consulta: {
            'paciente_id': int,
            'especialidad_id': int,
            'detalles': str,
            'tipo_consulta': 'normal|emergencia',
            'fecha': str (opcional)
        }
        """
        if not datos_consulta:
            self.operacionError.emit("Datos de consulta requeridos")
            return 0
        
        if self._usuario_actual <= 0:
            self.operacionError.emit("Usuario no establecido")
            return 0
        
        self._set_procesando_consulta(True)
        
        try:
            # Convertir QJSValue a diccionario de Python
            if hasattr(datos_consulta, 'toVariant'):
                datos = datos_consulta.toVariant()
            else:
                datos = datos_consulta
            
            # Validaciones básicas
            paciente_id = safe_int(datos.get('paciente_id', 0))
            especialidad_id = safe_int(datos.get('especialidad_id', 0))
            detalles = str(datos.get('detalles', '')).strip()
            tipo_consulta = str(datos.get('tipo_consulta', 'normal')).lower()
            
            if paciente_id <= 0:
                raise ValidationError("paciente_id", paciente_id, "Paciente requerido")
            
            if especialidad_id <= 0:
                raise ValidationError("especialidad_id", especialidad_id, "Especialidad requerida")
            
            if len(detalles) < 10:
                raise ValidationError("detalles", detalles, "Detalles muy cortos (mínimo 10 caracteres)")
            
            # Crear consulta
            consulta_id = safe_execute(
                self.consulta_repo.create_consultation,
                usuario_id=self._usuario_actual,
                paciente_id=paciente_id,
                especialidad_id=especialidad_id,
                detalles=detalles,
                tipo_consulta=tipo_consulta,  # ← AGREGAR ESTA LÍNEA
                fecha=datos.get('fecha')
            )
            
            if consulta_id:
                # Actualizar datos
                self._cargar_consultas_recientes()
                self._cargar_estadisticas_dashboard()
                
                # Obtener nombre del paciente para el signal
                paciente_nombre = "Paciente"
                for p in self._pacientes_recientes:
                    if p.get('id') == paciente_id:
                        paciente_nombre = p.get('nombre_completo', 'Paciente')
                        break
                
                self.consultaCreada.emit(consulta_id, paciente_nombre)
                self.operacionExitosa.emit(f"Consulta creada: {paciente_nombre}")
                
                print(f"✅ Consulta creada - ID: {consulta_id}")
                return consulta_id
            else:
                raise ValidationError("consulta", None, "Error creando consulta")
                
        except Exception as e:
            self.operacionError.emit(f"Error creando consulta: {str(e)}")
            return 0
        finally:
            self._set_procesando_consulta(False)
    
    @Slot(int, 'QVariant', result=bool)
    def actualizar_consulta(self, consulta_id: int, nuevos_datos):
        """Actualiza consulta existente"""
        if consulta_id <= 0 or not nuevos_datos:
            self.operacionError.emit("ID de consulta y datos requeridos")
            return False
        
        self._set_procesando_consulta(True)
        
        try:
            # Actualizar consulta
            success = safe_execute(
                self.consulta_repo.update_consultation,
                consulta_id=consulta_id,
                detalles=nuevos_datos.get('detalles'),
                fecha=nuevos_datos.get('fecha')
            )
            
            if success:
                # Actualizar datos
                self._cargar_consultas_recientes()
                if self._consulta_actual.get('id') == consulta_id:
                    self._cargar_consulta_detalle(consulta_id)
                
                self.consultaActualizada.emit(consulta_id)
                self.operacionExitosa.emit("Consulta actualizada correctamente")
                
                return True
            else:
                raise ValidationError("update", None, "Error actualizando consulta")
                
        except Exception as e:
            self.operacionError.emit(f"Error actualizando consulta: {str(e)}")
            return False
        finally:
            self._set_procesando_consulta(False)
    
    @Slot(int)
    def cargar_consulta_detalle(self, consulta_id: int):
        """Carga detalle completo de una consulta"""
        if consulta_id <= 0:
            return
        
        self._set_loading(True)
        self._cargar_consulta_detalle(consulta_id)
        self._set_loading(False)
    
    # ===============================
    # SLOTS PARA QML - BÚSQUEDAS
    # ===============================
    
    @Slot(str)
    def buscar_consultas(self, termino: str):
        """Búsqueda simple de consultas"""
        if not termino or len(termino.strip()) < 2:
            self._historial_consultas = self._consultas_recientes.copy()
            self.historialConsultasChanged.emit()
            return
        
        self._set_buscando(True)
        
        try:
            resultados = safe_execute(
                self.consulta_repo.search_consultations,
                search_term=termino.strip(),
                limit=50
            )
            
            self._historial_consultas = resultados or []
            self.historialConsultasChanged.emit()
            
            print(f"🔍 Búsqueda consultas: {len(self._historial_consultas)} resultados")
            
        except Exception as e:
            self.operacionError.emit(f"Error en búsqueda: {str(e)}")
        finally:
            self._set_buscando(False)
    
    @Slot('QVariant')
    def buscar_consultas_avanzado(self, criterios):
        """
        Búsqueda avanzada con criterios
        criterios: {
            'texto': str,
            'fecha_inicio': str,
            'fecha_fin': str,
            'doctor_id': int,
            'especialidad_id': int,
            'paciente_id': int
        }
        """
        if not criterios:
            return
        
        self._set_buscando(True)
        
        try:
            # Buscar por texto si existe
            if criterios.get('texto'):
                resultados = safe_execute(
                    self.consulta_repo.search_consultations,
                    search_term=criterios['texto'],
                    start_date=criterios.get('fecha_inicio'),
                    end_date=criterios.get('fecha_fin'),
                    limit=100
                )
            elif criterios.get('fecha_inicio') and criterios.get('fecha_fin'):
                resultados = safe_execute(
                    self.consulta_repo.get_consultations_by_date_range,
                    criterios['fecha_inicio'],
                    criterios['fecha_fin']
                )
            else:
                resultados = self._consultas_recientes.copy()
            
            # Aplicar filtros adicionales
            if criterios.get('doctor_id'):
                doctor_id = safe_int(criterios['doctor_id'])
                resultados = [c for c in resultados if c.get('Id_Doctor') == doctor_id]
            
            if criterios.get('especialidad_id'):
                esp_id = safe_int(criterios['especialidad_id'])
                resultados = [c for c in resultados if c.get('Id_Especialidad') == esp_id]
            
            if criterios.get('paciente_id'):
                pac_id = safe_int(criterios['paciente_id'])
                resultados = [c for c in resultados if c.get('Id_Paciente') == pac_id]
            
            self._historial_consultas = resultados or []
            self._filtros_activos = criterios.copy()
            self.historialConsultasChanged.emit()
            
            print(f"🔍 Búsqueda avanzada: {len(self._historial_consultas)} resultados")
            
        except Exception as e:
            self.operacionError.emit(f"Error en búsqueda avanzada: {str(e)}")
        finally:
            self._set_buscando(False)
    
    @Slot()
    def limpiar_filtros(self):
        """Limpia filtros y muestra todas las consultas recientes"""
        self._filtros_activos = {}
        self._historial_consultas = self._consultas_recientes.copy()
        self.historialConsultasChanged.emit()
        self.operacionExitosa.emit("Filtros limpiados")
    
    # ===============================
    # SLOTS PARA QML - REPORTES
    # ===============================
    
    @Slot(int, str, str, result='QVariant')
    def generar_reporte_doctor(self, doctor_id: int, fecha_inicio: str, fecha_fin: str):
        """Genera reporte de actividad de un doctor"""
        if doctor_id <= 0:
            self.operacionError.emit("Doctor no seleccionado")
            return {}
        
        self._set_loading(True)
        
        try:
            # Obtener consultas del doctor
            consultas = safe_execute(
                self.consulta_repo.get_consultations_by_doctor,
                doctor_id, limit=1000
            )
            
            if not consultas:
                return {'consultas': [], 'estadisticas': {}}
            
            # Filtrar por fechas si se proporcionan
            if fecha_inicio and fecha_fin:
                from ..core.utils import parsear_fecha
                fecha_ini = parsear_fecha(fecha_inicio)
                fecha_fin_parsed = parsear_fecha(fecha_fin)
                
                if fecha_ini and fecha_fin_parsed:
                    consultas_filtradas = []
                    for c in consultas:
                        fecha_consulta = parsear_fecha(str(c.get('Fecha', '')))
                        if fecha_consulta and fecha_ini <= fecha_consulta <= fecha_fin_parsed:
                            consultas_filtradas.append(c)
                    consultas = consultas_filtradas
            
            # Calcular estadísticas
            estadisticas = {
                'total_consultas': len(consultas),
                'pacientes_unicos': len(set(c.get('Id_Paciente') for c in consultas)),
                'ingresos_estimados': sum(safe_float(c.get('Precio_Normal', 0)) for c in consultas),
                'promedio_por_consulta': 0
            }
            
            if estadisticas['total_consultas'] > 0:
                estadisticas['promedio_por_consulta'] = (
                    estadisticas['ingresos_estimados'] / estadisticas['total_consultas']
                )
            
            reporte = {
                'consultas': preparar_para_qml(consultas),
                'estadisticas': estadisticas,
                'periodo': {
                    'fecha_inicio': fecha_inicio,
                    'fecha_fin': fecha_fin
                }
            }
            
            print(f"📊 Reporte doctor generado: {estadisticas['total_consultas']} consultas")
            
            return reporte
            
        except Exception as e:
            self.operacionError.emit(f"Error generando reporte: {str(e)}")
            return {}
        finally:
            self._set_loading(False)
    
    @Slot(str, str, result='QVariant')
    def get_consultas_periodo(self, fecha_inicio: str, fecha_fin: str):
        """Obtiene consultas de un período específico"""
        if not fecha_inicio or not fecha_fin:
            self.operacionError.emit("Fechas de período requeridas")
            return []
        
        try:
            consultas = safe_execute(
                self.consulta_repo.get_consultations_by_date_range,
                fecha_inicio, fecha_fin
            )
            return preparar_para_qml(consultas or [])
        except Exception as e:
            self.operacionError.emit(f"Error obteniendo consultas del período: {str(e)}")
            return []
    
    # ===============================
    # SLOTS PARA QML - PACIENTES Y DOCTORES
    # ===============================
    
    @Slot(str, result=list)
    def buscar_pacientes(self, termino: str):
        """Busca pacientes por nombre"""
        if not termino or len(termino.strip()) < 2:
            return []
        
        try:
            pacientes = safe_execute(
                self.paciente_repo.search_patients,
                termino.strip()
            )
            
            # Formatear para ComboBox
            pacientes_formateados = []
            for p in pacientes or []:
                pacientes_formateados.append({
                    'id': p['id'],
                    'text': formatear_nombre_completo(
                        p['Nombre'], p['Apellido_Paterno'], p['Apellido_Materno']
                    ),
                    'edad': p['Edad'],
                    'data': p
                })
            
            return pacientes_formateados
            
        except Exception as e:
            self.operacionError.emit(f"Error buscando pacientes: {str(e)}")
            return []
    
    @Slot(int, result='QVariant')
    def get_especialidades_doctor(self, doctor_id: int):
        """Obtiene especialidades de un doctor específico"""
        if doctor_id <= 0:
            return []
        
        try:
            doctor = safe_execute(
                self.doctor_repo.get_doctor_with_services,
                doctor_id
            )
            
            if doctor and doctor.get('servicios'):
                especialidades = []
                for servicio in doctor['servicios']:
                    especialidades.append({
                        'id': servicio['id'],
                        'text': servicio['Nombre'],
                        'precio_normal': servicio['Precio_Normal'],
                        'precio_emergencia': servicio['Precio_Emergencia'],
                        'detalles': servicio.get('Detalles', ''),
                        'data': servicio
                    })
                return especialidades
            
            return []
            
        except Exception as e:
            self.operacionError.emit(f"Error obteniendo especialidades: {str(e)}")
            return []
        
    @Slot(str, str, str, int, result=int)
    @Slot(str, str, str, int, result=int)
    def buscarOCrearPacienteInteligente(self, nombre, apellido_p, apellido_m, edad):
        """Busca o crea paciente de forma inteligente"""
        try:
            return self.paciente_repo.buscar_o_crear_paciente(
                nombre, apellido_p, apellido_m, edad
            )
        except Exception as e:
            self.operacionError.emit(f"Error gestionando paciente: {str(e)}")
            return -1
        
    # Agregar este método al ConsultaModel
    @Slot(str, result='QVariantList')
    def buscar_pacientes_completo(self, termino: str):
        """Búsqueda completa de pacientes con todos los campos"""
        if not termino or len(termino.strip()) < 2:
            return []
        
        try:
            pacientes = safe_execute(
                self.paciente_repo.search_patients_with_names,  # Nueva función
                termino.strip(),
                20
            )
            
            # Formatear resultados con toda la información
            resultados_completos = []
            for p in pacientes or []:
                resultados_completos.append({
                    'id': p['id'],
                    'nombre': p['Nombre'],
                    'apellido_paterno': p['Apellido_Paterno'],
                    'apellido_materno': p['Apellido_Materno'],
                    'edad': p['Edad'],
                    'nombre_completo': f"{p['Nombre']} {p['Apellido_Paterno']} {p['Apellido_Materno']}"
                })
            
            return resultados_completos
            
        except Exception as e:
            self.operacionError.emit(f"Error buscando pacientes: {str(e)}")
            return []
    
    # ===============================
    # MÉTODOS PRIVADOS
    # ===============================
    
    def _cargar_datos_iniciales(self):
        """Carga datos iniciales"""
        self._set_loading(True)
        try:
            self._cargar_consultas_recientes()
            self._cargar_estadisticas_dashboard()
            self._cargar_doctores_disponibles()
            self._cargar_especialidades()
            self._cargar_pacientes_recientes()
        finally:
            self._set_loading(False)
    
    def _cargar_estadisticas_dashboard(self):
        """Carga estadísticas para dashboard"""
        try:
            # Estadísticas generales
            stats_generales = safe_execute(self.consulta_repo.get_consultation_statistics)
            stats_hoy = safe_execute(self.consulta_repo.get_today_statistics)
            
            # CORRECCIÓN: Verificar que stats_generales es un diccionario antes de usar .get()
            if stats_generales and isinstance(stats_generales, dict):
                metricas_generales = stats_generales.get('general', {})
                por_especialidad = stats_generales.get('por_especialidad', [])
                por_doctor = stats_generales.get('por_doctor', [])
            else:
                metricas_generales = {}
                por_especialidad = []
                por_doctor = []
            
            self._estadisticas_dashboard = {
                'metricas_hoy': stats_hoy or {},
                'metricas_generales': metricas_generales,
                'por_especialidad': por_especialidad,
                'por_doctor': por_doctor
            }
            
            self.estadisticasDashboardChanged.emit()
            
        except Exception as e:
            print(f"⚠️ Error cargando estadísticas dashboard: {e}")
    
    def _cargar_doctores_disponibles(self):
        """Carga lista de doctores disponibles"""
        try:
            doctores = safe_execute(self.doctor_repo.get_all)
            
            doctores_formateados = []
            for d in doctores or []:
                doctores_formateados.append({
                    'id': d['id'],
                    'text': formatear_nombre_completo(
                        d['Nombre'], d['Apellido_Paterno'], d['Apellido_Materno']
                    ),
                    'especialidad': d['Especialidad'],
                    'matricula': d['Matricula'],
                    'data': d
                })
            
            self._doctores_disponibles = doctores_formateados
            self.doctoresDisponiblesChanged.emit()
            
        except Exception as e:
            print(f"⚠️ Error cargando doctores: {e}")
    
    def _cargar_especialidades(self):
        """Carga especialidades disponibles desde el repository"""
        try:
            print("🏥 Cargando especialidades desde DoctorRepository...")
            
            # Usar repository (correcto)
            especialidades = safe_execute(self.doctor_repo.get_all_specialty_services)
            
            print(f"🔍 Especialidades obtenidas del repository: {len(especialidades or [])}")
            
            if especialidades and len(especialidades) > 0:
                print(f"🔍 Primera especialidad: {especialidades[0]}")
            
            especialidades_formateadas = []
            for e in especialidades or []:
                especialidades_formateadas.append({
                    'id': e['id'],
                    'text': e['Nombre'],
                    'precio_normal': e['Precio_Normal'],
                    'precio_emergencia': e['Precio_Emergencia'],
                    'doctor_nombre': e.get('doctor_completo', e.get('doctor_nombre', '')),
                    'doctor_especialidad': e.get('doctor_especialidad', ''),
                    'data': e
                })
            
            self._especialidades = especialidades_formateadas
            print(f"✅ Especialidades formateadas para QML: {len(especialidades_formateadas)}")
            
            self.especialidadesChanged.emit()
            
        except Exception as e:
            print(f"❌ Error cargando especialidades: {e}")
            self._especialidades = []
            self.especialidadesChanged.emit()
            
    def _cargar_pacientes_recientes(self):
        """Carga pacientes con consultas recientes"""
        try:
            pacientes = safe_execute(
                self.consulta_repo.get_most_frequent_patients,
                limit=20
            )
            
            pacientes_formateados = []
            for p in pacientes or []:
                pacientes_formateados.append({
                    'id': p.get('Id_Paciente'),
                    'nombre_completo': p.get('paciente_completo', ''),
                    'total_consultas': p.get('total_consultas', 0),
                    'ultima_consulta': p.get('ultima_consulta', ''),
                    'data': p
                })
            
            self._pacientes_recientes = pacientes_formateados
            self.pacientesRecientesChanged.emit()
            
        except Exception as e:
            print(f"⚠️ Error cargando pacientes recientes: {e}")
    
    def _cargar_consulta_detalle(self, consulta_id: int):
        """Carga detalle completo de una consulta"""
        try:
            consulta = safe_execute(
                self.consulta_repo.get_consultation_by_id_complete,
                consulta_id
            )
            
            if consulta:
                # Enriquecer datos para QML
                consulta_enriquecida = consulta.copy()
                
                # Formatear fecha
                if 'Fecha' in consulta:
                    consulta_enriquecida['fecha_formateada'] = formatear_fecha(consulta['Fecha'])
                
                # Formatear precios
                for campo in ['Precio_Normal', 'Precio_Emergencia']:
                    if campo in consulta:
                        consulta_enriquecida[f'{campo.lower()}_formateado'] = formatear_precio(
                            consulta[campo]
                        )
                
                self._consulta_actual = preparar_para_qml(consulta_enriquecida)
            else:
                self._consulta_actual = {}
            
            self.consultaActualChanged.emit()
            
        except Exception as e:
            print(f"⚠️ Error cargando consulta detalle: {e}")
            self._consulta_actual = {}
            self.consultaActualChanged.emit()
    
    def _auto_update_consultas(self):
        """Actualización automática de consultas"""
        if not self._loading and not self._procesando_consulta:
            try:
                self._cargar_consultas_recientes()
                self._cargar_estadisticas_dashboard()
            except Exception as e:
                print(f"⚠️ Error en auto-update consultas: {e}")
    
    def _set_loading(self, loading: bool):
        """Actualiza estado de carga"""
        if self._loading != loading:
            self._loading = loading
            self.loadingChanged.emit()
    
    def _set_procesando_consulta(self, procesando: bool):
        """Actualiza estado de procesamiento"""
        if self._procesando_consulta != procesando:
            self._procesando_consulta = procesando
            self.procesandoConsultaChanged.emit()
    
    def _set_buscando(self, buscando: bool):
        """Actualiza estado de búsqueda"""
        if self._buscando != buscando:
            self._buscando = buscando
            self.buscandoChanged.emit()

    def _cargar_consultas_recientes(self):
        """Carga consultas recientes"""
        try:
            print("🔄 Cargando consultas recientes...")
            consultas = safe_execute(
                self.consulta_repo.get_all_with_details,
                limit=50
            )
            # Crear una nueva lista para forzar la actualización
            self._consultas_recientes = list(consultas) if consultas else []
            print(f"✅ Consultas cargadas: {len(self._consultas_recientes)}")
            
            # Forzar la emisión de la señal
            self.consultasRecientesChanged.emit()
            
        except Exception as e:
            print(f"❌ Error cargando consultas recientes: {e}")
            self._consultas_recientes = []
            self.consultasRecientesChanged.emit()

    def _cargar_datos_iniciales(self):
        self._set_loading(True)
        try:
            self._cargar_consultas_recientes()
            self._cargar_estadisticas_dashboard()
            self._cargar_doctores_disponibles()
            self._cargar_especialidades()  # ← Ya existe
            self._cargar_pacientes_recientes()
            # AGREGAR ESTA LÍNEA:
            self._cargar_especialidades()  # Forzar carga
        finally:
            self._set_loading(False)

    def search_patients_with_names(self, search_term: str, limit: int = 50) -> List[Dict[str, Any]]:
        """Busca solo pacientes con nombres reales"""
        search_term = f"%{search_term.strip()}%"
        
        query = """
        SELECT * FROM Pacientes 
        WHERE (Nombre != 'Sin nombre' AND Nombre IS NOT NULL AND Nombre != '')
        AND (Nombre LIKE ? OR Apellido_Paterno LIKE ? OR Apellido_Materno LIKE ?)
        ORDER BY Nombre, Apellido_Paterno
        OFFSET 0 ROWS FETCH NEXT ? ROWS ONLY
        """
        
        return self._execute_query(query, (search_term, search_term, search_term, limit))

# Registrar el tipo para QML
def register_consulta_model():
    qmlRegisterType(ConsultaModel, "ClinicaModels", 1, 0, "ConsultaModel")