"""
Modelo QObject para Gestión de Consultas Médicas - CORREGIDO con set_usuario_actual
Expone funcionalidad de consultas a QML con Signals/Slots/Properties
"""

from PySide6.QtCore import QObject, Signal, Slot, Property, QTimer
from PySide6.QtQml import qmlRegisterType
from typing import List, Dict, Any, Optional
import json
from datetime import datetime, timedelta

from ..core.excepciones import ExceptionHandler, ClinicaBaseException
from ..repositories.consulta_repository import ConsultaRepository
from ..repositories.doctor_repository import DoctorRepository
from ..core.Signals_manager import get_global_signals

class ConsultaModel(QObject):
    """
    Modelo QObject para gestión completa de consultas médicas - CORREGIDO con usuario
    Conecta la lógica de negocio con la interfaz QML
    """
    
    # ===============================
    # SIGNALS PARA QML
    # ===============================
    
    # Operaciones CRUD
    consultaCreada = Signal(str, arguments=['datos'])  # JSON con datos de la consulta
    consultaActualizada = Signal(str, arguments=['datos'])
    consultaEliminada = Signal(int, arguments=['consultaId'])
    
    # NUEVAS SEÑALES para búsqueda por cédula
    pacienteEncontradoPorCedula = Signal('QVariantMap', arguments=['pacienteData'])
    pacienteNoEncontrado = Signal(str, arguments=['cedula'])
    
    # Búsquedas y filtros
    resultadosBusqueda = Signal(str, arguments=['resultados'])  # JSON
    filtrosAplicados = Signal(str, arguments=['criterios'])
    
    # Dashboard y estadísticas
    dashboardActualizado = Signal(str, arguments=['datos'])
    estadisticasCalculadas = Signal(str, arguments=['estadisticas'])
    
    # Estados y notificaciones
    estadoCambiado = Signal(str, arguments=['nuevoEstado'])
    operacionError = Signal(str, arguments=['mensaje'])  # AÑADIDO para compatibilidad
    operacionExitosa = Signal(str, arguments=['mensaje'])
    
    # Datos actualizados
    consultasRecientesChanged = Signal()
    especialidadesChanged = Signal()
    doctoresDisponiblesChanged = Signal()
    
    def __init__(self, parent=None):
        super().__init__(parent)
        self._is_initializing = False
        
        # Repositories
        self.repository = ConsultaRepository()
        self.doctor_repo = DoctorRepository()
        self.global_signals = get_global_signals()
        self._conectar_senales_globales()
        # Estados internos
        self._consultasData = []
        self._especialidadesData = []
        self._doctoresData = []
        self._dashboardData = {}
        self._estadisticasData = {}
        self._estadoActual = "listo"  # listo, cargando, error
        
        # ✅ AGREGAR: Usuario actual para compatibilidad con AppController
        self._usuario_actual_id = 0  # Cambio de 10 a 0
        print("🩺 ConsultaModel inicializado - Esperando autenticación")
        
        # Configuración
        self._autoRefreshInterval = 30000  # 30 segundos
        self._setupAutoRefresh()
        
        print("🩺 ConsultaModel inicializado con gestión de pacientes por cédula")
    
    # ===============================
    # ✅ MÉTODO FALTANTE PARA APPCONTROLLER
    # ===============================
    def _conectar_senales_globales(self):
        """Conecta con las señales globales para recibir actualizaciones"""
        try:
            # Conectar señales de especialidades
            self.global_signals.especialidadesModificadas.connect(self._actualizar_especialidades_desde_signal)
            self.global_signals.consultasNecesitaActualizacion.connect(self._manejar_actualizacion_global)
            
            print("🔗 Señales globales conectadas en ConsultaModel")
        except Exception as e:
            print(f"❌ Error conectando señales globales en ConsultaModel: {e}")
    @Slot(int)
    def set_usuario_actual(self, usuario_id: int):
        """
        Establece el usuario actual para las operaciones - MÉTODO REQUERIDO por AppController
        """
        try:
            if usuario_id > 0:
                self._usuario_actual_id = usuario_id
                print(f"👤 Usuario autenticado establecido en ConsultaModel: {usuario_id}")
                self.operacionExitosa.emit(f"Usuario {usuario_id} establecido en módulo de consultas")
            else:
                print(f"⚠️ ID de usuario inválido en ConsultaModel: {usuario_id}")
                self.operacionError.emit("ID de usuario inválido")
        except Exception as e:
            print(f"❌ Error estableciendo usuario en ConsultaModel: {e}")
            self.operacionError.emit(f"Error estableciendo usuario: {str(e)}")
    
    @Property(int, notify=operacionExitosa)
    def usuario_actual_id(self):
        """Property para obtener el usuario actual"""
        return self._usuario_actual_id
    
    # ===============================
    # PROPERTIES PARA QML
    # ===============================
    
    def _get_consultas_json(self) -> str:
        """Getter para consultas en formato JSON"""
        return json.dumps(self._consultasData, default=str, ensure_ascii=False)
    
    def _get_especialidades_json(self) -> str:
        """Getter para especialidades en formato JSON"""
        return json.dumps(self._especialidadesData, default=str, ensure_ascii=False)
    
    def _get_doctores_json(self) -> str:
        """Getter para doctores en formato JSON"""
        return json.dumps(self._doctoresData, default=str, ensure_ascii=False)
    
    def _get_dashboard_json(self) -> str:
        """Getter para datos de dashboard en formato JSON"""
        return json.dumps(self._dashboardData, default=str, ensure_ascii=False)
    
    def _get_estado_actual(self) -> str:
        """Getter para estado actual"""
        return self._estadoActual
    
    def _set_estado_actual(self, nuevo_estado: str):
        """Setter para estado actual"""
        if self._estadoActual != nuevo_estado:
            self._estadoActual = nuevo_estado
            self.estadoCambiado.emit(nuevo_estado)
    
    # Properties expuestas a QML
    consultasJson = Property(str, _get_consultas_json, notify=consultasRecientesChanged)
    especialidadesJson = Property(str, _get_especialidades_json, notify=especialidadesChanged)
    doctoresJson = Property(str, _get_doctores_json, notify=doctoresDisponiblesChanged)
    dashboardJson = Property(str, _get_dashboard_json, notify=dashboardActualizado)
    estadoActual = Property(str, _get_estado_actual, notify=estadoCambiado)
    
    # Properties adicionales para compatibilidad con QML existente
    @Property(list, notify=consultasRecientesChanged)
    def consultas_recientes(self):
        """Lista de consultas recientes para compatibilidad"""
        return self._consultasData
    
    @Property(list, notify=especialidadesChanged)
    def especialidades(self):
        """Lista de especialidades para compatibilidad"""
        return self._especialidadesData
    
    @Property(list, notify=doctoresDisponiblesChanged)
    def doctores_disponibles(self):
        """Lista de doctores disponibles para compatibilidad"""
        return self._doctoresData
    
    # ===============================
    # SLOTS PARA BÚSQUEDA POR CÉDULA - CORREGIDOS
    # ===============================
    
    @Slot(str, result='QVariantMap')
    def buscar_paciente_por_cedula(self, cedula: str):
        """
        Busca un paciente específico por su cédula
        
        Args:
            cedula (str): Cédula del paciente
            
        Returns:
            Dict: Datos del paciente encontrado o diccionario vacío
        """
        try:
            if len(cedula.strip()) < 5:
                return {}
            
            print(f"🔍 Buscando paciente por cédula: {cedula}")
            
            # Buscar en el repository
            paciente = self.repository.search_patient_by_cedula_exact(cedula.strip())
            
            if paciente:
                print(f"👤 Paciente encontrado: {paciente.get('nombre_completo', 'N/A')}")
                
                # Emitir señal de éxito
                self.pacienteEncontradoPorCedula.emit(paciente)
                
                return paciente
            else:
                print(f"⚠️ No se encontró paciente con cédula: {cedula}")
                
                # Emitir señal de no encontrado
                self.pacienteNoEncontrado.emit(cedula)
                
                return {}
                
        except Exception as e:
            error_msg = f"Error buscando paciente por cédula: {str(e)}"
            print(f"⚠️ {error_msg}")
            self.operacionError.emit(error_msg)
            return {}
    
    @Slot(str, int, result='QVariantList')
    def buscar_pacientes(self, termino_busqueda: str, limite: int = 5):
        """
        Busca pacientes por cédula parcial (para sugerencias)
        
        Args:
            termino_busqueda (str): Término a buscar (generalmente cédula parcial)
            limite (int): Límite de resultados
            
        Returns:
            List[Dict]: Lista de pacientes encontrados
        """
        try:
            if len(termino_busqueda.strip()) < 3:
                return []
            
            print(f"🔍 Buscando pacientes con término: {termino_busqueda}")
            
            resultados = self.repository.search_patients_by_cedula_partial(
                termino_busqueda.strip(), limite
            )
            
            print(f"📋 Encontrados {len(resultados)} pacientes")
            return resultados
            
        except Exception as e:
            error_msg = f"Error en búsqueda de pacientes: {str(e)}"
            print(f"⚠️ {error_msg}")
            self.operacionError.emit(error_msg)
            return []
    
    @Slot(str, str, str, str, result=int)
    def buscar_o_crear_paciente_inteligente(self, nombre: str, apellido_paterno: str, 
                                          apellido_materno: str = "", cedula: str = "") -> int:
        """
        Busca paciente por cédula o crea uno nuevo si no existe
        
        Args:
            nombre (str): Nombre del paciente
            apellido_paterno (str): Apellido paterno
            apellido_materno (str): Apellido materno (opcional)
            cedula (str): Cédula de identidad
            
        Returns:
            int: ID del paciente (existente o nuevo creado)
        """
        try:
            if not cedula or len(cedula.strip()) < 5:
                self.operacionError.emit("Cédula es obligatoria (mínimo 5 dígitos)")
                return -1
            
            if not nombre or len(nombre.strip()) < 2:
                self.operacionError.emit("Nombre es obligatorio")
                return -1
            
            if not apellido_paterno or len(apellido_paterno.strip()) < 2:
                self.operacionError.emit("Apellido paterno es obligatorio")
                return -1
            
            print(f"📄 Gestionando paciente: {nombre} {apellido_paterno} - Cédula: {cedula}")
            
            paciente_id = self.repository.buscar_o_crear_paciente_simple(
                nombre.strip(), 
                apellido_paterno.strip(), 
                apellido_materno.strip(), 
                cedula.strip()
            )
            
            if paciente_id > 0:
                self.operacionExitosa.emit(f"Paciente gestionado correctamente: ID {paciente_id}")
                return paciente_id
            else:
                self.operacionError.emit("Error gestionando paciente")
                return -1
                
        except Exception as e:
            error_msg = f"Error gestionando paciente: {str(e)}"
            print(f"⚠️ {error_msg}")
            self.operacionError.emit(error_msg)
            return -1
    
    # ===============================
    # SLOTS PARA OPERACIONES CRUD - CORREGIDOS CON USUARIO
    # ===============================
    
    @Slot('QVariant', result=str)
    def crear_consulta(self, datos_consulta):
        """Crea nueva consulta médica - CORREGIDO con verificación de autenticación"""
        try:
            # ✅ VERIFICACIÓN DE AUTENTICACIÓN PRIMERO
            if self._usuario_actual_id <= 0:
                self.operacionError.emit("Usuario no autenticado. Por favor inicie sesión.")
                return json.dumps({'exito': False, 'error': 'Usuario no autenticado'})
            
            self._set_estado_actual("cargando")
            
            # Convertir QJSValue to diccionario de Python
            if hasattr(datos_consulta, 'toVariant'):
                datos = datos_consulta.toVariant()
            else:
                datos = datos_consulta
            
            # Validaciones básicas
            paciente_id = int(datos.get('paciente_id', 0))
            especialidad_id = int(datos.get('especialidad_id', 0))
            detalles = str(datos.get('detalles', '')).strip()
            tipo_consulta = str(datos.get('tipo_consulta', 'normal')).lower()
            
            if paciente_id <= 0:
                raise ValueError("Paciente requerido")
            
            if especialidad_id <= 0:
                raise ValueError("Especialidad requerida")
            
            if len(detalles) < 10:
                raise ValueError("Detalles muy cortos (mínimo 10 caracteres)")
            
            # ✅ USAR usuario actual autenticado
            consulta_id = self.repository.create_consultation(
                usuario_id=self._usuario_actual_id,  # Usar usuario autenticado
                paciente_id=paciente_id,
                especialidad_id=especialidad_id,
                detalles=detalles,
                tipo_consulta=tipo_consulta
            )
            
            if consulta_id:
                # Forzar refresh inmediato
                self._cargar_consultas_recientes()
                self._cargar_estadisticas_dashboard()
                
                # Invalidar cache manualmente
                self.repository.invalidate_consultation_caches()
                print("🔄 Cache forzosamente invalidado desde modelo")
                
                # Obtener datos de la consulta creada
                consulta_creada = self.repository.get_consultation_by_id_complete(consulta_id)
                
                self.consultaCreada.emit(json.dumps(consulta_creada, default=str))
                self.operacionExitosa.emit(f"Consulta creada exitosamente: ID {consulta_id}")
                
                self._set_estado_actual("listo")
                return json.dumps({'exito': True, 'consulta_id': consulta_id})
            else:
                raise ValueError("Error creando consulta")
                
        except Exception as e:
            error_msg = f"Error creando consulta: {str(e)}"
            self.operacionError.emit(error_msg)
            self._set_estado_actual("error")
            return json.dumps({'exito': False, 'error': error_msg})
    
    @Slot(int, 'QVariant', result=str)
    def actualizar_consulta(self, consulta_id: int, nuevos_datos):
        """Actualiza consulta existente - CORREGIDO con verificación de autenticación"""
        try:
            # ✅ VERIFICACIÓN DE AUTENTICACIÓN
            if self._usuario_actual_id <= 0:
                self.operacionError.emit("Usuario no autenticado. Por favor inicie sesión.")
                return json.dumps({'exito': False, 'error': 'Usuario no autenticado'})
            
            self._set_estado_actual("cargando")
            
            # Convertir QJSValue a diccionario
            if hasattr(nuevos_datos, 'toVariant'):
                datos = nuevos_datos.toVariant()
            else:
                datos = nuevos_datos
            
            success = self.repository.update_consultation(
                consulta_id=consulta_id,
                detalles=datos.get('detalles'),
                tipo_consulta=datos.get('tipo_consulta'),
                especialidad_id=datos.get('especialidad_id'),
                fecha=datos.get('fecha')
            )
            
            if success:
                # Obtener consulta actualizada
                consulta_actualizada = self.repository.get_consultation_by_id_complete(consulta_id)
                
                # Emitir signals
                self.consultaActualizada.emit(json.dumps(consulta_actualizada, default=str))
                self.operacionExitosa.emit(f"Consulta {consulta_id} actualizada correctamente")
                
                # Actualizar datos
                self._cargar_consultas_recientes()
                
                self._set_estado_actual("listo")
                return json.dumps({'exito': True, 'datos': consulta_actualizada}, default=str)
            else:
                error_msg = "Error actualizando consulta"
                self.operacionError.emit(error_msg)
                self._set_estado_actual("error")
                return json.dumps({'exito': False, 'error': error_msg})
                
        except Exception as e:
            error_msg = f"Error actualizando consulta: {str(e)}"
            self.operacionError.emit(error_msg)
            self._set_estado_actual("error")
            return json.dumps({'exito': False, 'error': error_msg})
    
    @Slot(int, result=bool)
    def eliminar_consulta(self, consulta_id: int) -> bool:
        """Elimina consulta médica - CORREGIDO con verificación de autenticación"""
        try:
            # ✅ VERIFICACIÓN DE AUTENTICACIÓN
            if self._usuario_actual_id <= 0:
                self.operacionError.emit("Usuario no autenticado. Por favor inicie sesión.")
                return False
            
            self._set_estado_actual("cargando")
            
            exito = self.repository.delete(consulta_id)
            
            if exito:
                # Emitir signals
                self.consultaEliminada.emit(consulta_id)
                self.operacionExitosa.emit(f"Consulta {consulta_id} eliminada correctamente")
                
                # Actualizar datos
                self._cargar_consultas_recientes()
                
                self._set_estado_actual("listo")
                return True
            else:
                self.operacionError.emit(f"No se pudo eliminar la consulta {consulta_id}")
                self._set_estado_actual("error")
                return False
                
        except Exception as e:
            error_msg = f"Error eliminando consulta: {str(e)}"
            self.operacionError.emit(error_msg)
            self._set_estado_actual("error")
            return False
    
    # ===============================
    # SLOTS PARA BÚSQUEDAS Y FILTROS - CORREGIDOS
    # ===============================
    
    @Slot(str, result=str)
    def buscar_consultas_avanzado(self, termino_busqueda: str) -> str:
        """Realiza búsqueda avanzada de consultas"""
        try:
            resultado = self.repository.search_consultations(termino_busqueda, limit=100)
            
            # Emitir signal con resultados
            self.resultadosBusqueda.emit(json.dumps(resultado, default=str))
            
            return json.dumps({
                'exito': True,
                'consultas': resultado,
                'total': len(resultado)
            }, default=str)
            
        except Exception as e:
            error_msg = f"Error en búsqueda: {str(e)}"
            self.operacionError.emit(error_msg)
            return json.dumps({'exito': False, 'error': error_msg})
    
    @Slot(int, result=str)
    def obtener_consultas_del_paciente(self, paciente_id: int) -> str:
        """Obtiene consultas de un paciente específico"""
        try:
            consultas = self.repository.get_consultations_by_patient(paciente_id)
            
            return json.dumps({
                'exito': True,
                'consultas': consultas,
                'total': len(consultas)
            }, default=str)
            
        except Exception as e:
            error_msg = f"Error obteniendo consultas del paciente: {str(e)}"
            self.operacionError.emit(error_msg)
            return json.dumps({'exito': False, 'error': error_msg})
    
    @Slot(int, result=str)
    def obtener_consultas_del_doctor(self, doctor_id: int) -> str:
        """Obtiene consultas atendidas por un doctor"""
        try:
            consultas = self.repository.get_consultations_by_doctor(doctor_id)
            
            return json.dumps({
                'exito': True,
                'consultas': consultas,
                'total': len(consultas)
            }, default=str)
            
        except Exception as e:
            error_msg = f"Error obteniendo consultas del doctor: {str(e)}"
            self.operacionError.emit(error_msg)
            return json.dumps({'exito': False, 'error': error_msg})
    
    @Slot(int, result=str)
    def obtener_consulta_completa(self, consulta_id: int) -> str:
        """Obtiene consulta con información completa"""
        try:
            consulta = self.repository.get_consultation_by_id_complete(consulta_id)
            
            if consulta:
                return json.dumps({'exito': True, 'consulta': consulta}, default=str)
            else:
                return json.dumps({'exito': False, 'error': 'Consulta no encontrada'})
                
        except Exception as e:
            error_msg = f"Error obteniendo consulta: {str(e)}"
            self.operacionError.emit(error_msg)
            return json.dumps({'exito': False, 'error': error_msg})
    
    # ===============================
    # SLOTS PARA ESTADÍSTICAS Y REPORTES
    # ===============================
    
    @Slot(result=str)
    def obtener_dashboard(self) -> str:
        """Obtiene datos para dashboard de consultas"""
        try:
            self._set_estado_actual("cargando")
            
            dashboard = self.repository.get_consultation_statistics()
            
            # Agregar datos adicionales
            dashboard['consultas_hoy'] = len(self.repository.get_today_consultations())
            dashboard['consultas_mes'] = len(self.repository.get_consultations_this_month())
            dashboard['pacientes_frecuentes'] = self.repository.get_most_frequent_patients(limit=5)
            
            # Actualizar datos internos
            self._dashboardData = dashboard
            
            # Emitir signal
            self.dashboardActualizado.emit(json.dumps(dashboard, default=str))
            
            self._set_estado_actual("listo")
            return json.dumps({'exito': True, 'dashboard': dashboard}, default=str)
            
        except Exception as e:
            error_msg = f"Error generando dashboard: {str(e)}"
            self.operacionError.emit(error_msg)
            self._set_estado_actual("error")
            return json.dumps({'exito': False, 'error': error_msg})
    
    @Slot(result=str)
    def obtener_estadisticas(self) -> str:
        """Obtiene estadísticas completas de consultas"""
        try:
            estadisticas = self.repository.get_consultation_statistics()
            
            # Actualizar datos internos
            self._estadisticasData = estadisticas
            
            # Emitir signal
            self.estadisticasCalculadas.emit(json.dumps(estadisticas, default=str))
            
            return json.dumps({'exito': True, 'estadisticas': estadisticas}, default=str)
            
        except Exception as e:
            error_msg = f"Error generando estadísticas: {str(e)}"
            self.operacionError.emit(error_msg)
            return json.dumps({'exito': False, 'error': error_msg})
    
    @Slot(int, result=str)
    def obtener_resumen_paciente(self, paciente_id: int) -> str:
        """Obtiene resumen de consultas de un paciente"""
        try:
            consultas = self.repository.get_consultations_by_patient(paciente_id)
            
            resumen = {
                'total_consultas': len(consultas),
                'consultas_recientes': consultas[:5] if consultas else [],
                'especialidades_visitadas': list(set([c['especialidad_nombre'] for c in consultas if c.get('especialidad_nombre')])),
                'ultima_consulta': consultas[0]['Fecha'] if consultas else None
            }
            
            return json.dumps({'exito': True, 'resumen': resumen}, default=str)
            
        except Exception as e:
            error_msg = f"Error obteniendo resumen: {str(e)}"
            self.operacionError.emit(error_msg)
            return json.dumps({'exito': False, 'error': error_msg})
    
    # ===============================
    # SLOTS PARA GESTIÓN DE DATOS
    # ===============================
    
    @Slot()
    def cargar_consultas(self):
        """Carga todas las consultas médicas"""
        try:
            self._set_estado_actual("cargando")
            self._cargar_consultas_recientes()
            self._set_estado_actual("listo")
        except Exception as e:
            self.operacionError.emit(f"Error cargando consultas: {str(e)}")
            self._set_estado_actual("error")
    
    @Slot()
    def cargar_especialidades(self):
        """Carga especialidades disponibles"""
        try:
            especialidades = self.doctor_repo.get_all_specialty_services()
            self._especialidadesData = []
            
            for esp in especialidades or []:
                self._especialidadesData.append({
                    'id': esp['id'],
                    'text': esp['Nombre'],
                    'precio_normal': float(esp.get('Precio_Normal', 0)),
                    'precio_emergencia': float(esp.get('Precio_Emergencia', 0)),
                    'doctor_nombre': esp.get('doctor_completo', ''),
                    'doctor_especialidad': esp.get('doctor_especialidad', ''),
                    'data': esp
                })
            
            self.especialidadesChanged.emit()
            print(f"🏥 Especialidades cargadas: {len(self._especialidadesData)}")
            
        except Exception as e:
            error_msg = f"Error cargando especialidades: {str(e)}"
            print(f"⚠️ {error_msg}")
            self.operacionError.emit(error_msg)
            
    @Slot()
    def cargar_doctores(self):
        """Carga doctores disponibles"""
        try:
            doctores = self.doctor_repo.get_all()
            self._doctoresData = []
            
            for d in doctores or []:
                self._doctoresData.append({
                    'id': d['id'],
                    'text': f"{d['Nombre']} {d['Apellido_Paterno']} {d['Apellido_Materno']}",
                    'especialidad': d['Especialidad'],
                    'matricula': d['Matricula'],
                    'data': d
                })
            
            self.doctoresDisponiblesChanged.emit()
            
        except Exception as e:
            self.operacionError.emit(f"Error cargando doctores: {str(e)}")
    
    @Slot()
    def refresh_consultas(self):
        """Refresca las consultas recientes"""
        self._cargar_consultas_recientes()
    
    @Slot()
    def refresh_especialidades(self):
        """Refresca especialidades"""
        self.cargar_especialidades()
    
    @Slot()
    def refresh_doctores(self):
        """Refresca lista de doctores"""
        self.cargar_doctores()
    
    @Slot()
    def refrescar_datos(self):
        """Refresca todos los datos del modelo"""
        if self._is_initializing:
                return
        try:
            self._is_initializing = True
            self._set_estado_actual("cargando")
            
            # Cargar datos principales
            self._cargar_consultas_recientes()
            self.cargar_especialidades()
            self.cargar_doctores()
            
            # Actualizar dashboard
            self.obtener_dashboard()
            
            self._set_estado_actual("listo")
            self.operacionExitosa.emit("Datos actualizados correctamente")
          
            
        except Exception as e:
            error_msg = f"Error refrescando datos: {str(e)}"
            self.operacionError.emit(error_msg)
            self._set_estado_actual("error")
        finally:
            self._is_initializing = False
    
    # ===============================
    # SLOTS PARA CONSULTAS ESPECÍFICAS
    # ===============================
    
    @Slot(result=str)
    def obtener_consultas_hoy(self) -> str:
        """Obtiene consultas del día actual"""
        try:
            consultas = self.repository.get_today_consultations()
            return json.dumps({
                'exito': True,
                'consultas': consultas,
                'total': len(consultas)
            }, default=str)
        except Exception as e:
            return json.dumps({'exito': False, 'error': str(e)})
    
    @Slot(result=str)
    def obtener_especialidades_disponibles(self) -> str:
        """Obtiene especialidades disponibles"""
        try:
            return json.dumps({
                'exito': True,
                'especialidades': self._especialidadesData
            }, default=str)
        except Exception as e:
            return json.dumps({'exito': False, 'error': str(e)})
    
    @Slot(result=str)
    def obtener_doctores_activos(self) -> str:
        """Obtiene doctores activos"""
        try:
            return json.dumps({
                'exito': True,
                'doctores': self._doctoresData
            }, default=str)
        except Exception as e:
            return json.dumps({'exito': False, 'error': str(e)})
    
    @Slot()
    def limpiar_cache_consultas(self):
        """Limpia el cache de consultas para forzar recarga"""
        try:
            self.repository.invalidate_consultation_caches()
            print("🧹 Cache de consultas limpiado")
        except Exception as e:
            print(f"⚠️ Error limpiando cache: {e}")
    
    @Slot(int, int, 'QVariant', result='QVariant')
    def obtener_consultas_paginadas(self, page: int, limit: int = 5, filters=None):
        """Obtiene página específica de consultas - CORREGIDO CON FORMATEO DE FECHAS"""
        try:
            filtros_dict = filters.toVariant() if hasattr(filters, 'toVariant') else filters or {}
            resultado = self.repository.get_consultas_paginadas(page, limit, filtros_dict)
            
            # ✅ PROCESAR FECHAS EN LAS CONSULTAS PAGINADAS
            if 'consultas' in resultado and resultado['consultas']:
                for consulta in resultado['consultas']:
                    # Formatear fecha usando el mismo método que _cargar_consultas_recientes
                    fecha_raw = consulta.get('Fecha') or consulta.get('fecha')
                    fecha_formateada = self._formatear_fecha_python(fecha_raw)
                    consulta['fecha'] = fecha_formateada
                    
                    # Asegurar que otros campos estén en el formato correcto
                    consulta['id'] = str(consulta.get('id', 'N/A'))
                    consulta['paciente_completo'] = consulta.get('paciente_completo') or 'Sin nombre'
                    consulta['paciente_cedula'] = consulta.get('paciente_cedula') or 'Sin cédula'
                    consulta['Detalles'] = consulta.get('Detalles') or 'Sin detalles'
                    consulta['especialidad_doctor'] = consulta.get('especialidad_doctor') or 'Sin especialidad/doctor'
                    consulta['tipo_consulta'] = consulta.get('tipo_consulta') or 'Normal'
                    consulta['precio'] = float(consulta.get('precio') or 0)
            
            return resultado
            
        except Exception as e:
            self.operacionError.emit(f"Error paginación: {str(e)}")
            return {'consultas': [], 'total': 0, 'page': 0, 'total_pages': 0}

    # ===============================
    # MÉTODOS INTERNOS - CORREGIDOS CON NOMBRES REALES
    # ===============================
    def _formatear_fecha_python(self, fecha) -> str:
        """Formatea fecha en Python manejando QVariant datetime - CORREGIDO"""
        if not fecha:
            return "Sin fecha"
        
        try:
            # ✅ SOLUCIÓN: Manejar QVariant sin importación problemática
            # Si es QVariant, extraer el valor usando .value() si existe el método
            if hasattr(fecha, 'value') and callable(getattr(fecha, 'value')):
                fecha = fecha.value()
            
            # Si es datetime, formatear directamente
            if isinstance(fecha, datetime):
                return fecha.strftime('%d/%m/%Y')
            
            # Si es string, intentar parsearlo
            if isinstance(fecha, str):
                if fecha == "Sin fecha":
                    return fecha
                # Intentar formato ISO
                try:
                    dt = datetime.fromisoformat(fecha.replace('Z', ''))
                    return dt.strftime('%d/%m/%Y')
                except:
                    pass
                # Si ya está formateado DD/MM/YYYY
                if '/' in fecha and len(fecha) == 10:
                    return fecha
            
            print(f"🔍 DEBUG: Tipo de fecha no reconocido: {type(fecha)} - Valor: {fecha}")
            return "Sin fecha"
            
        except Exception as e:
            print(f"❌ Error formateando fecha: {e} - Tipo: {type(fecha)} - Valor: {fecha}")
            return "Sin fecha"
        
    def _cargar_consultas_recientes(self):
        """Actualiza lista interna de consultas - FECHA FORMATEADA EN PYTHON"""
        try:
            consultas_raw = self.repository.get_all_with_details()
            
            # Procesar datos para QML
            self._consultasData = []
            for consulta in consultas_raw:
                # ✅ FORMATEAR FECHA EN PYTHON SIEMPRE
                fecha_raw = consulta.get('Fecha') or consulta.get('fecha_original')
                fecha_formateada = self._formatear_fecha_python(fecha_raw)
                
                consulta_procesada = {
                    'id': str(consulta.get('id', 'N/A')),
                    'paciente_completo': consulta.get('paciente_completo') or 'Sin nombre',
                    'paciente_cedula': consulta.get('paciente_cedula') or 'Sin cédula',
                    'Detalles': consulta.get('Detalles') or 'Sin detalles',
                    'especialidad_doctor': consulta.get('especialidad_doctor') or 'Sin especialidad/doctor',
                    'tipo_consulta': consulta.get('tipo_consulta') or 'Normal',
                    'precio': float(consulta.get('precio') or 0),
                    'fecha': fecha_formateada  # ✅ USAR FECHA FORMATEADA EN PYTHON
                }
                
                self._consultasData.append(consulta_procesada)
            
            self.consultasRecientesChanged.emit()
            print(f"📋 Consultas cargadas: {len(self._consultasData)}")
            
        except Exception as e:
            error_msg = f"Error actualizando consultas: {str(e)}"
            print(f"⚠️ {error_msg}")
            self._consultasData = []
            
    def _formatear_fecha_simple(self, fecha) -> str:
        """Formatea fecha de manera simple y segura"""
        if not fecha:
            return "Sin fecha"
        
        try:
            if isinstance(fecha, str):
                fecha_obj = datetime.fromisoformat(fecha.replace('Z', '+00:00'))
            elif isinstance(fecha, datetime):
                fecha_obj = fecha
            else:
                return "Fecha inválida"
            
            return fecha_obj.strftime('%d/%m/%Y')
        except Exception as e:
            print(f"Error formateando fecha: {e}")
            return "Fecha inválida"

    def _cargar_estadisticas_dashboard(self):
        """Carga estadísticas para el dashboard"""
        try:
            self._dashboardData = self.repository.get_consultation_statistics()
            self.dashboardActualizado.emit(json.dumps(self._dashboardData, default=str))
            print("📊 Estadísticas de consultas cargadas")
        except Exception as e:
            print(f"Error cargando estadísticas dashboard: {e}")
            self._dashboardData = {}
    
    def _setupAutoRefresh(self):
        """Configura actualización automática de datos"""
        self._autoRefreshTimer = QTimer(self)
        self._autoRefreshTimer.timeout.connect(self.refrescar_datos)
        # Comentado por defecto - se puede activar si es necesario
        # self._autoRefreshTimer.start(self._autoRefreshInterval)
    
    @Slot(int)
    def setAutoRefreshInterval(self, intervalMs: int):
        """Configura intervalo de actualización automática"""
        if intervalMs > 0:
            self._autoRefreshInterval = intervalMs
            if hasattr(self, '_autoRefreshTimer'):
                self._autoRefreshTimer.start(intervalMs)
        else:
            if hasattr(self, '_autoRefreshTimer'):
                self._autoRefreshTimer.stop()
    @Slot()
    def _actualizar_especialidades_desde_signal(self):
        """Actualiza especialidades cuando recibe señal global"""
        try:
            print("📡 ConsultaModel: Recibida señal de actualización de especialidades")
            
            # Invalidar cache del repository principal
            if hasattr(self.repository, 'invalidate_consultation_caches'):
                self.repository.invalidate_consultation_caches()
                print("🗑️ Cache invalidado en ConsultaModel")
            
            # ✅ FORZAR INVALIDACIÓN COMPLETA DEL DOCTOR REPOSITORY
            if hasattr(self.doctor_repo, 'invalidate_cache'):
                self.doctor_repo.invalidate_cache()
                print("🗑️ Cache de doctor_repo invalidado")
            
            # ✅ INVALIDAR CACHE MANUALMENTE SI ES NECESARIO
            from ..core.cache_system import invalidate_after_update
            invalidate_after_update(['doctores', 'especialidades'])
            print("🗑️ Cache doctores/especialidades invalidado manualmente")
            
            self.cargar_especialidades()
            print("✅ Especialidades actualizadas desde señal global en ConsultaModel")
        except Exception as e:
            print(f"❌ Error actualizando especialidades desde señal: {e}")
    @Slot(str)
    def _manejar_actualizacion_global(self, mensaje: str):
        """Maneja actualizaciones globales de consultas"""
        try:
            print(f"📡 ConsultaModel: {mensaje}")
            # Emitir señal para notificar a QML que hay cambios
            self.especialidadesChanged.emit()
        except Exception as e:
            print(f"❌ Error manejando actualización global: {e}")

    def cleanup(self):
        """
        Limpia completamente todos los recursos del ConsultaModel
        Detiene timers, desconecta señales y libera memoria
        """
        try:
            print("🧹 Iniciando limpieza completa de ConsultaModel...")
            
            # 1. DETENER TODOS LOS TIMERS ACTIVOS
            if hasattr(self, '_autoRefreshTimer'):
                try:
                    if self._autoRefreshTimer.isActive():
                        self._autoRefreshTimer.stop()
                        print("⏹️ Timer de auto-refresh detenido")
                    self._autoRefreshTimer.deleteLater()
                except Exception as e:
                    print(f"⚠️ Error deteniendo auto-refresh timer: {e}")
            
            # 2. DESCONECTAR SEÑALES GLOBALES
            try:
                if hasattr(self, 'global_signals'):
                    # Desconectar todas las señales globales
                    try:
                        self.global_signals.especialidadesModificadas.disconnect(self._actualizar_especialidades_desde_signal)
                    except:
                        pass
                    
                    try:
                        self.global_signals.consultasNecesitaActualizacion.disconnect(self._manejar_actualizacion_global)
                    except:
                        pass
                    
                    print("🔌 Señales globales desconectadas")
            except Exception as e:
                print(f"⚠️ Error desconectando señales globales: {e}")
            
            # 3. LIMPIAR REPOSITORIOS Y DATOS
            try:
                # Invalidar caches de repositorios
                if hasattr(self, 'repository') and hasattr(self.repository, 'invalidate_consultation_caches'):
                    self.repository.invalidate_consultation_caches()
                    print("🗑️ Cache de consultas invalidado")
                
                if hasattr(self, 'doctor_repo') and hasattr(self.doctor_repo, 'invalidate_cache'):
                    self.doctor_repo.invalidate_cache()
                    print("🗑️ Cache de doctores invalidado")
                
                # Limpiar datos en memoria
                self._consultasData = []
                self._especialidadesData = []
                self._doctoresData = []
                self._dashboardData = {}
                self._estadisticasData = {}
                
                print("📊 Datos en memoria liberados")
            except Exception as e:
                print(f"⚠️ Error limpiando datos: {e}")
            
            # 4. DESCONECTAR SEÑALES PROPIAS (opcional, para liberación completa)
            try:
                # Desconectar todas las señales propias
                self.consultaCreada.disconnect()
                self.consultaActualizada.disconnect()
                self.consultaEliminada.disconnect()
                self.pacienteEncontradoPorCedula.disconnect()
                self.pacienteNoEncontrado.disconnect()
                self.resultadosBusqueda.disconnect()
                self.filtrosAplicados.disconnect()
                self.dashboardActualizado.disconnect()
                self.estadisticasCalculadas.disconnect()
                self.estadoCambiado.disconnect()
                self.operacionError.disconnect()
                self.operacionExitosa.disconnect()
                self.consultasRecientesChanged.disconnect()
                self.especialidadesChanged.disconnect()
                self.doctoresDisponiblesChanged.disconnect()
                
                print("🔌 Señales propias desconectadas")
            except Exception as e:
                print(f"⚠️ Error desconectando señales propias: {e}")
            
            # 5. RESETEAR ESTADOS
            self._estadoActual = "inactivo"
            self._usuario_actual_id = 0
            self._is_initializing = False
            
            print("✅ Limpieza completa de ConsultaModel finalizada")
            
        except Exception as e:
            print(f"❌ Error crítico durante cleanup de ConsultaModel: {e}")
            # Asegurarse de que al menos los timers se detengan
            try:
                if hasattr(self, '_autoRefreshTimer') and self._autoRefreshTimer.isActive():
                    self._autoRefreshTimer.stop()
            except:
                pass

    def emergency_disconnect(self):
        """Desconexión de emergencia para ConsultaModel"""
        try:
            print("🚨 ConsultaModel: Iniciando desconexión de emergencia...")
            
            # Detener timer
            if hasattr(self, '_autoRefreshTimer') and self._autoRefreshTimer.isActive():
                self._autoRefreshTimer.stop()
                print("   ⏹️ Auto-refresh timer detenido")
            
            # Forzar estado shutdown
            self._estadoActual = "shutdown"
            self._is_initializing = False
            
            # Usar el cleanup existente que es bastante completo
            self.cleanup()
            
            print("✅ ConsultaModel: Desconexión de emergencia completada")
            
        except Exception as e:
            print(f"❌ Error en desconexión ConsultaModel: {e}")

# ===============================
# REGISTRO PARA QML
# ===============================

def register_consulta_model():
    """Registra el modelo para uso en QML"""
    qmlRegisterType(ConsultaModel, "Clinica.Models", 1, 0, "ConsultaModel")
    print("✅ ConsultaModel registrado para QML con gestión de pacientes por cédula")