"""
Modelo QObject para Gestión de Laboratorio - ACTUALIZADO con búsqueda por cédula
Expone funcionalidad de laboratorio a QML con Signals/Slots/Properties
"""

from PySide6.QtCore import QObject, Signal, Slot, Property, QTimer
from PySide6.QtQml import qmlRegisterType
from typing import List, Dict, Any, Optional
import json
from datetime import datetime, timedelta

from ..core.excepciones import ExceptionHandler, ClinicaBaseException
from ..repositories.laboratorio_repository import LaboratorioRepository

class LaboratorioModel(QObject):
    """
    Modelo QObject para gestión completa de análisis de laboratorio - ACTUALIZADO
    Conecta la lógica de negocio con la interfaz QML
    """
    
    # ===============================
    # SIGNALS PARA QML
    # ===============================
    
    # Operaciones CRUD
    examenCreado = Signal(str, arguments=['datos'])  # JSON con datos del examen
    examenActualizado = Signal(str, arguments=['datos'])
    examenEliminado = Signal(int, arguments=['examenId'])
    
    # Asignación de trabajadores
    trabajadorAsignado = Signal(int, int, arguments=['examenId', 'trabajadorId'])
    trabajadorDesasignado = Signal(int, arguments=['examenId'])
    
    # Búsquedas y filtros
    resultadosBusqueda = Signal(str, arguments=['resultados'])  # JSON
    filtrosAplicados = Signal(str, arguments=['criterios'])
    
    # NUEVAS SEÑALES para búsqueda por cédula
    pacienteEncontradoPorCedula = Signal('QVariantMap', arguments=['pacienteData'])
    pacienteNoEncontrado = Signal(str, arguments=['cedula'])
    
    # Dashboard y estadísticas
    dashboardActualizado = Signal(str, arguments=['datos'])
    estadisticasCalculadas = Signal(str, arguments=['estadisticas'])
    
    # Estados y notificaciones
    estadoCambiado = Signal(str, arguments=['nuevoEstado'])
    errorOcurrido = Signal(str, str, arguments=['mensaje', 'codigo'])
    operacionExitosa = Signal(str, arguments=['mensaje'])
    
    # Datos actualizados
    examenesActualizados = Signal()
    tiposAnalisisActualizados = Signal()
    trabajadoresActualizados = Signal()
    
    def __init__(self, parent=None):
        super().__init__(parent)
        
        # Repository en lugar de service
        self.repository = LaboratorioRepository()
        
        # Estados internos
        self._examenesData = []
        self._tiposAnalisisData = []
        self._trabajadoresData = []
        self._dashboardData = {}
        self._estadisticasData = {}
        self._estadoActual = "listo"  # listo, cargando, error
        
        # Configuración
        self._autoRefreshInterval = 30000  # 30 segundos
        self._setupAutoRefresh()
        
        print("🔬 LaboratorioModel inicializado")
    
    # ===============================
    # PROPERTIES PARA QML
    # ===============================
    
    def _get_examenes_json(self) -> str:
        """Getter para exámenes en formato JSON"""
        return json.dumps(self._examenesData, default=str, ensure_ascii=False)
    
    def _get_tipos_analisis_json(self) -> str:
        """Getter para tipos de análisis en formato JSON"""
        return json.dumps(self._tiposAnalisisData, default=str, ensure_ascii=False)
    
    def _get_trabajadores_json(self) -> str:
        """Getter para trabajadores en formato JSON"""
        return json.dumps(self._trabajadoresData, default=str, ensure_ascii=False)
    
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
    examenesJson = Property(str, _get_examenes_json, notify=examenesActualizados)
    tiposAnalisisJson = Property(str, _get_tipos_analisis_json, notify=tiposAnalisisActualizados)
    trabajadoresJson = Property(str, _get_trabajadores_json, notify=trabajadoresActualizados)
    dashboardJson = Property(str, _get_dashboard_json, notify=dashboardActualizado)
    estadoActual = Property(str, _get_estado_actual, notify=estadoCambiado)
    
    # ===============================
    # SLOTS PARA BÚSQUEDA POR CÉDULA - NUEVOS
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
                print(f"❌ No se encontró paciente con cédula: {cedula}")
                
                # Emitir señal de no encontrado
                self.pacienteNoEncontrado.emit(cedula)
                
                return {}
                
        except Exception as e:
            error_msg = f"Error buscando paciente por cédula: {str(e)}"
            print(f"❌ {error_msg}")
            self.errorOcurrido.emit(error_msg, 'CEDULA_SEARCH_ERROR')
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
            print(f"❌ {error_msg}")
            self.errorOcurrido.emit(error_msg, 'PATIENT_SEARCH_ERROR')
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
                self.errorOcurrido.emit("Cédula es obligatoria (mínimo 5 dígitos)", 'VALIDATION_ERROR')
                return -1
            
            if not nombre or len(nombre.strip()) < 2:
                self.errorOcurrido.emit("Nombre es obligatorio", 'VALIDATION_ERROR')
                return -1
            
            if not apellido_paterno or len(apellido_paterno.strip()) < 2:
                self.errorOcurrido.emit("Apellido paterno es obligatorio", 'VALIDATION_ERROR')
                return -1
            
            print(f"🔄 Gestionando paciente: {nombre} {apellido_paterno} - Cédula: {cedula}")
            
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
                self.errorOcurrido.emit("Error gestionando paciente", 'PATIENT_MANAGEMENT_ERROR')
                return -1
                
        except Exception as e:
            error_msg = f"Error gestionando paciente: {str(e)}"
            print(f"❌ {error_msg}")
            self.errorOcurrido.emit(error_msg, 'PATIENT_MANAGEMENT_EXCEPTION')
            return -1
    
    # ===============================
    # SLOTS PARA OPERACIONES CRUD - ACTUALIZADOS
    # ===============================
    
    @Slot(int, int, str, int, str, result=str)
    def crearExamen(self, paciente_id: int, tipo_analisis_id: int, tipo_servicio: str, 
                    trabajador_id: int = 0, detalles: str = "") -> str:
        """
        Crea nuevo examen de laboratorio
        """
        try:
            self._set_estado_actual("cargando")
            
            # Usar usuario por defecto (ID 10)
            usuario_id = 10
            
            examen_id = self.repository.create_lab_exam(
                paciente_id=paciente_id,
                tipo_analisis_id=tipo_analisis_id,
                tipo=tipo_servicio,
                trabajador_id=trabajador_id if trabajador_id > 0 else None,
                usuario_id=usuario_id,
                detalles=detalles
            )
            
            if examen_id:
                self.operacionExitosa.emit(f"Examen creado exitosamente: ID {examen_id}")
                self._actualizarExamenes()
                self._set_estado_actual("listo")
                return json.dumps({'exito': True, 'examen_id': examen_id})
            else:
                error_msg = "Error creando examen"
                self.errorOcurrido.emit(error_msg, 'CREATE_ERROR')
                self._set_estado_actual("error")
                return json.dumps({'exito': False, 'error': error_msg})
                
        except Exception as e:
            error_msg = f"Error creando examen: {str(e)}"
            self.errorOcurrido.emit(error_msg, 'CREATE_EXCEPTION')
            self._set_estado_actual("error")
            return json.dumps({'exito': False, 'error': error_msg})
    
    @Slot(int, int, str, int, str, result=str)
    def actualizarExamen(self, examen_id: int, tipo_analisis_id: int, tipo_servicio: str, 
                        trabajador_id: int = 0, detalles: str = "") -> str:
        """
        Actualiza examen existente
        """
        try:
            self._set_estado_actual("cargando")
            
            success = self.repository.update_lab_exam(
                examen_id, 
                tipo_analisis_id=tipo_analisis_id,
                tipo_servicio=tipo_servicio,
                trabajador_id=trabajador_id,
                detalles=detalles
            )
            
            if success:
                # Obtener examen actualizado
                examen_actualizado = self.repository.get_lab_exam_by_id_complete(examen_id)
                
                # Emitir signals
                self.examenActualizado.emit(json.dumps(examen_actualizado, default=str))
                self.operacionExitosa.emit(f"Examen {examen_id} actualizado correctamente")
                
                # Actualizar datos
                self._actualizarExamenes()
                
                self._set_estado_actual("listo")
                return json.dumps({'exito': True, 'datos': examen_actualizado}, default=str)
            else:
                error_msg = "Error actualizando examen"
                self.errorOcurrido.emit(error_msg, 'UPDATE_ERROR')
                self._set_estado_actual("error")
                return json.dumps({'exito': False, 'error': error_msg})
                
        except Exception as e:
            error_msg = f"Error actualizando examen: {str(e)}"
            self.errorOcurrido.emit(error_msg, 'UPDATE_EXCEPTION')
            self._set_estado_actual("error")
            return json.dumps({'exito': False, 'error': error_msg})
    
    @Slot(int, result=bool)
    def eliminarExamen(self, examen_id: int) -> bool:
        """
        Elimina examen de laboratorio
        """
        try:
            self._set_estado_actual("cargando")
            
            exito = self.repository.delete(examen_id)
            
            if exito:
                # Emitir signals
                self.examenEliminado.emit(examen_id)
                self.operacionExitosa.emit(f"Examen {examen_id} eliminado correctamente")
                
                # Actualizar datos
                self._actualizarExamenes()
                
                self._set_estado_actual("listo")
                return True
            else:
                self.errorOcurrido.emit(f"No se pudo eliminar el examen {examen_id}", 'DELETE_ERROR')
                self._set_estado_actual("error")
                return False
                
        except Exception as e:
            error_msg = f"Error eliminando examen: {str(e)}"
            self.errorOcurrido.emit(error_msg, 'DELETE_EXCEPTION')
            self._set_estado_actual("error")
            return False
    
    # ===============================
    # SLOTS PARA GESTIÓN DE TRABAJADORES
    # ===============================
    
    @Slot(int, int, result=bool)
    def asignarTrabajador(self, examen_id: int, trabajador_id: int) -> bool:
        """
        Asigna trabajador a examen
        """
        try:
            exito = self.repository.assign_worker_to_exam(examen_id, trabajador_id)
            
            if exito:
                self.trabajadorAsignado.emit(examen_id, trabajador_id)
                self.operacionExitosa.emit(f"Trabajador asignado al examen {examen_id}")
                self._actualizarExamenes()
                return True
            else:
                self.errorOcurrido.emit(f"Error asignando trabajador", 'ASSIGN_ERROR')
                return False
                
        except Exception as e:
            self.errorOcurrido.emit(f"Error: {str(e)}", 'ASSIGN_EXCEPTION')
            return False
    
    @Slot(int, result=bool)
    def desasignarTrabajador(self, examen_id: int) -> bool:
        """
        Desasigna trabajador de examen
        """
        try:
            exito = self.repository.unassign_worker_from_exam(examen_id)
            
            if exito:
                self.trabajadorDesasignado.emit(examen_id)
                self.operacionExitosa.emit(f"Trabajador desasignado del examen {examen_id}")
                self._actualizarExamenes()
                return True
            else:
                self.errorOcurrido.emit(f"Error desasignando trabajador", 'UNASSIGN_ERROR')
                return False
                
        except Exception as e:
            self.errorOcurrido.emit(f"Error: {str(e)}", 'UNASSIGN_EXCEPTION')
            return False
    
    # ===============================
    # SLOTS PARA BÚSQUEDAS Y FILTROS
    # ===============================
    
    @Slot(str, result=str)
    def buscarExamenesAvanzado(self, termino_busqueda: str) -> str:
        """
        Realiza búsqueda avanzada de exámenes
        """
        try:
            resultado = self.repository.search_exams(termino_busqueda, limit=100)
            
            # Emitir signal con resultados
            self.resultadosBusqueda.emit(json.dumps(resultado, default=str))
            
            return json.dumps({
                'exito': True,
                'examenes': resultado,
                'total': len(resultado)
            }, default=str)
            
        except Exception as e:
            error_msg = f"Error en búsqueda: {str(e)}"
            self.errorOcurrido.emit(error_msg, 'SEARCH_ERROR')
            return json.dumps({'exito': False, 'error': error_msg})
    
    @Slot(int, result=str)
    def obtenerExamenesDelPaciente(self, paciente_id: int) -> str:
        """
        Obtiene exámenes de un paciente específico
        """
        try:
            examenes = self.repository.get_exams_by_patient(paciente_id)
            
            return json.dumps({
                'exito': True,
                'examenes': examenes,
                'total': len(examenes)
            }, default=str)
            
        except Exception as e:
            error_msg = f"Error obteniendo exámenes del paciente: {str(e)}"
            self.errorOcurrido.emit(error_msg, 'PATIENT_EXAMS_ERROR')
            return json.dumps({'exito': False, 'error': error_msg})
    
    @Slot(int, result=str)
    def obtenerExamenesDelTrabajador(self, trabajador_id: int) -> str:
        """
        Obtiene exámenes asignados a un trabajador
        """
        try:
            examenes = self.repository.get_exams_by_worker(trabajador_id)
            
            return json.dumps({
                'exito': True,
                'examenes': examenes,
                'total': len(examenes)
            }, default=str)
            
        except Exception as e:
            error_msg = f"Error obteniendo exámenes del trabajador: {str(e)}"
            self.errorOcurrido.emit(error_msg, 'WORKER_EXAMS_ERROR')
            return json.dumps({'exito': False, 'error': error_msg})
    
    @Slot(int, result=str)
    def obtenerExamenCompleto(self, examen_id: int) -> str:
        """
        Obtiene examen con información completa
        """
        try:
            examen = self.repository.get_lab_exam_by_id_complete(examen_id)
            
            if examen:
                return json.dumps({'exito': True, 'examen': examen}, default=str)
            else:
                return json.dumps({'exito': False, 'error': 'Examen no encontrado'})
                
        except Exception as e:
            error_msg = f"Error obteniendo examen: {str(e)}"
            self.errorOcurrido.emit(error_msg, 'GET_ERROR')
            return json.dumps({'exito': False, 'error': error_msg})
    
    # ===============================
    # SLOTS PARA ESTADÍSTICAS Y REPORTES
    # ===============================
    
    @Slot(result=str)
    def obtenerDashboard(self) -> str:
        """
        Obtiene datos para dashboard de laboratorio
        """
        try:
            self._set_estado_actual("cargando")
            
            dashboard = self.repository.get_laboratory_statistics()
            
            # Agregar datos adicionales
            dashboard['examenes_sin_asignar'] = len(self.repository.get_unassigned_exams())
            dashboard['examenes_asignados'] = len(self.repository.get_assigned_exams())
            dashboard['tipos_examenes_comunes'] = self.repository.get_exam_types_list()[:10]
            
            # Actualizar datos internos
            self._dashboardData = dashboard
            
            # Emitir signal
            self.dashboardActualizado.emit(json.dumps(dashboard, default=str))
            
            self._set_estado_actual("listo")
            return json.dumps({'exito': True, 'dashboard': dashboard}, default=str)
            
        except Exception as e:
            error_msg = f"Error generando dashboard: {str(e)}"
            self.errorOcurrido.emit(error_msg, 'DASHBOARD_ERROR')
            self._set_estado_actual("error")
            return json.dumps({'exito': False, 'error': error_msg})
    
    @Slot(result=str)
    def obtenerEstadisticas(self) -> str:
        """
        Obtiene estadísticas completas de laboratorio
        """
        try:
            estadisticas = self.repository.get_laboratory_statistics()
            
            # Actualizar datos internos
            self._estadisticasData = estadisticas
            
            # Emitir signal
            self.estadisticasCalculadas.emit(json.dumps(estadisticas, default=str))
            
            return json.dumps({'exito': True, 'estadisticas': estadisticas}, default=str)
            
        except Exception as e:
            error_msg = f"Error generando estadísticas: {str(e)}"
            self.errorOcurrido.emit(error_msg, 'STATS_ERROR')
            return json.dumps({'exito': False, 'error': error_msg})
    
    @Slot(int, result=str)
    def obtenerResumenPaciente(self, paciente_id: int) -> str:
        """
        Obtiene resumen de laboratorio de un paciente
        """
        try:
            examenes = self.repository.get_exams_by_patient(paciente_id)
            
            resumen = {
                'total_examenes': len(examenes),
                'examenes_recientes': examenes[:5] if examenes else [],
                'tipos_realizados': list(set([e['tipo_analisis'] for e in examenes if e.get('tipo_analisis')])),
                'ultimo_examen': examenes[0]['Fecha'] if examenes else None
            }
            
            return json.dumps({'exito': True, 'resumen': resumen}, default=str)
            
        except Exception as e:
            error_msg = f"Error obteniendo resumen: {str(e)}"
            self.errorOcurrido.emit(error_msg, 'SUMMARY_ERROR')
            return json.dumps({'exito': False, 'error': error_msg})
    
    # ===============================
    # SLOTS PARA GESTIÓN DE DATOS
    # ===============================
    
    @Slot()
    def cargarExamenes(self):
        """Carga todos los exámenes de laboratorio"""
        try:
            self._set_estado_actual("cargando")
            self._actualizarExamenes()
            self._set_estado_actual("listo")
        except Exception as e:
            self.errorOcurrido.emit(f"Error cargando exámenes: {str(e)}", 'LOAD_ERROR')
            self._set_estado_actual("error")
    
    @Slot()
    def cargarTiposAnalisis(self):
        """Carga tipos de análisis disponibles"""
        try:
            tipos = self.repository.get_analysis_types()
            self._tiposAnalisisData = tipos
            self.tiposAnalisisActualizados.emit()
        except Exception as e:
            self.errorOcurrido.emit(f"Error cargando tipos: {str(e)}", 'LOAD_TYPES_ERROR')
    
    @Slot()
    def cargarTrabajadores(self):
        """Carga trabajadores de laboratorio disponibles"""
        try:
            trabajadores = self.repository.get_available_lab_workers()
            self._trabajadoresData = trabajadores
            self.trabajadoresActualizados.emit()
        except Exception as e:
            self.errorOcurrido.emit(f"Error cargando trabajadores: {str(e)}", 'LOAD_WORKERS_ERROR')
    
    @Slot()
    def refrescarDatos(self):
        """Refresca todos los datos del modelo"""
        try:
            self._set_estado_actual("cargando")
            
            # Cargar datos principales
            self._actualizarExamenes()
            self.cargarTiposAnalisis()
            self.cargarTrabajadores()
            
            # Actualizar dashboard
            self.obtenerDashboard()
            
            self._set_estado_actual("listo")
            self.operacionExitosa.emit("Datos actualizados correctamente")
            
        except Exception as e:
            error_msg = f"Error refrescando datos: {str(e)}"
            self.errorOcurrido.emit(error_msg, 'REFRESH_ERROR')
            self._set_estado_actual("error")
    
    # ===============================
    # SLOTS PARA CONSULTAS ESPECÍFICAS
    # ===============================
    
    @Slot(result=str)
    def obtenerExamenesSinAsignar(self) -> str:
        """Obtiene exámenes sin trabajador asignado"""
        try:
            examenes = self.repository.get_unassigned_exams()
            return json.dumps({
                'exito': True,
                'examenes': examenes,
                'total': len(examenes)
            }, default=str)
        except Exception as e:
            return json.dumps({'exito': False, 'error': str(e)})
    
    @Slot(result=str)
    def obtenerTiposAnalisisDisponibles(self) -> str:
        """Obtiene tipos de análisis disponibles"""
        try:
            tipos = self.repository.get_analysis_types()
            return json.dumps({
                'exito': True,
                'tipos': tipos
            }, default=str)
        except Exception as e:
            return json.dumps({'exito': False, 'error': str(e)})
    
    @Slot(result=str)
    def obtenerDistribucionCarga(self) -> str:
        """Obtiene distribución de carga de trabajo"""
        try:
            trabajadores = self.repository.get_available_lab_workers()
            return json.dumps({
                'exito': True,
                'distribucion': trabajadores
            }, default=str)
        except Exception as e:
            return json.dumps({'exito': False, 'error': str(e)})
    
    # ===============================
    # MÉTODOS INTERNOS
    # ===============================
    
    def _actualizarExamenes(self):
        """Actualiza lista interna de exámenes"""
        try:
            examenes_raw = self.repository.get_all_with_details()
            
            # Procesar datos para QML - ACTUALIZADO sin edad
            self._examenesData = []
            for examen in examenes_raw:
                examen_procesado = {
                    # IDs
                    'analisisId': str(examen.get('id', 0)),
                    'pacienteId': examen.get('Id_Paciente', 0),
                    
                    # Información del paciente (SIN EDAD)
                    'paciente': examen.get('paciente_completo', 'Paciente Desconocido'),
                    'pacienteCedula': examen.get('paciente_cedula', ''),
                    'pacienteNombre': examen.get('paciente_nombre', ''),
                    'pacienteApellidoP': examen.get('paciente_apellido_p', ''),
                    'pacienteApellidoM': examen.get('paciente_apellido_m', ''),
                    
                    # Información del análisis
                    'tipoAnalisis': examen.get('tipo_analisis', 'Análisis General'),
                    'detalles': examen.get('Detalles', 'Sin detalles'),
                    'detallesExamen': examen.get('detalles_examen', ''),
                    'tipo': examen.get('tipo', 'Normal'),
                    
                    # Precio
                    'precio': f"{float(examen.get('precio', 0)):.2f}",
                    
                    # Trabajador
                    'trabajadorAsignado': examen.get('trabajador_completo', 'Sin asignar'),
                    
                    # Fecha y usuario
                    'fecha': examen.get('Fecha', datetime.now()).strftime('%Y-%m-%d') if examen.get('Fecha') else '',
                    'registradoPor': examen.get('registrado_por', 'Sistema')
                }
                
                self._examenesData.append(examen_procesado)
            
            self.examenesActualizados.emit()
            print(f"🔬 Exámenes actualizados: {len(self._examenesData)} registros")
            
        except Exception as e:
            error_msg = f"Error actualizando exámenes: {str(e)}"
            print(f"❌ {error_msg}")
            raise ClinicaBaseException(error_msg)
    
    def _setupAutoRefresh(self):
        """Configura actualización automática de datos"""
        self._autoRefreshTimer = QTimer(self)
        self._autoRefreshTimer.timeout.connect(self.refrescarDatos)
        # Comentado por defecto - se puede activar si es necesario
        # self._autoRefreshTimer.start(self._autoRefreshInterval)
    
    @Slot(int)
    def setAutoRefreshInterval(self, intervalMs: int):
        """
        Configura intervalo de actualización automática
        """
        if intervalMs > 0:
            self._autoRefreshInterval = intervalMs
            if hasattr(self, '_autoRefreshTimer'):
                self._autoRefreshTimer.start(intervalMs)
        else:
            if hasattr(self, '_autoRefreshTimer'):
                self._autoRefreshTimer.stop()

# ===============================
# REGISTRO PARA QML
# ===============================

def register_laboratorio_model():
    """Registra el modelo para uso en QML"""
    qmlRegisterType(LaboratorioModel, "Clinica.Models", 1, 0, "LaboratorioModel")
    print("✅ LaboratorioModel registrado para QML")