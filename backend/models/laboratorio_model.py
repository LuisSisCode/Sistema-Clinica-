"""
Modelo QObject para Gestión de Laboratorio
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
    Modelo QObject para gestión completa de análisis de laboratorio
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
    # SLOTS PARA OPERACIONES CRUD
    # ===============================
    
    @Slot(str, int, float, float, str, int, result=str)
    def crearExamen(self, nombre: str, paciente_id: int, precio_normal: float, 
                   precio_emergencia: float, detalles: str = "", trabajador_id: int = 0) -> str:
        """
        Crea nuevo examen de laboratorio
        """
        try:
            self._set_estado_actual("cargando")
            
            # Llamar al repository
            examen_id = self.repository.create_lab_exam(
                nombre=nombre,
                paciente_id=paciente_id,
                precio_normal=precio_normal,
                precio_emergencia=precio_emergencia,
                detalles=detalles if detalles else None,
                trabajador_id=trabajador_id if trabajador_id > 0 else None
            )
            
            if examen_id:
                # Obtener examen completo
                examen_completo = self.repository.get_lab_exam_by_id_complete(examen_id)
                
                # Emitir signal de éxito
                self.examenCreado.emit(json.dumps(examen_completo, default=str))
                self.operacionExitosa.emit(f"Examen creado exitosamente: ID {examen_id}")
                
                # Actualizar datos locales
                self._actualizarExamenes()
                
                self._set_estado_actual("listo")
                return json.dumps({'exito': True, 'examen_id': examen_id, 'examen': examen_completo}, default=str)
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
    
    @Slot(int, str, float, float, str, int, result=str)
    def actualizarExamen(self, examen_id: int, nombre: str = "", precio_normal: float = 0,
                        precio_emergencia: float = 0, detalles: str = "", trabajador_id: int = -1) -> str:
        """
        Actualiza examen existente
        """
        try:
            self._set_estado_actual("cargando")
            
            kwargs = {}
            if nombre:
                kwargs['nombre'] = nombre
            if precio_normal > 0:
                kwargs['precio_normal'] = precio_normal
            if precio_emergencia > 0:
                kwargs['precio_emergencia'] = precio_emergencia
            if detalles:
                kwargs['detalles'] = detalles
            if trabajador_id >= 0:
                kwargs['trabajador_id'] = trabajador_id if trabajador_id > 0 else None
            
            success = self.repository.update_lab_exam(examen_id, **kwargs)
            
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
            dashboard['tipos_examenes_comunes'] = self.repository.get_common_exam_types(10)
            
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
            resumen = self.repository.get_patient_lab_summary(paciente_id)
            
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
            tipos = self.repository.get_exam_types_list()
            self._tiposAnalisisData = [{'nombre': tipo} for tipo in tipos]
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
    def obtenerTiposExamenesComunes(self) -> str:
        """Obtiene tipos de exámenes más comunes"""
        try:
            tipos = self.repository.get_common_exam_types(15)
            return json.dumps({
                'exito': True,
                'tipos': tipos,
                'total': len(tipos)
            }, default=str)
        except Exception as e:
            return json.dumps({'exito': False, 'error': str(e)})
    
    @Slot(result=str)
    def obtenerDistribucionCarga(self) -> str:
        """Obtiene distribución de carga de trabajo"""
        try:
            distribucion = self.repository.get_workload_distribution()
            return json.dumps({
                'exito': True,
                'distribucion': distribucion
            }, default=str)
        except Exception as e:
            return json.dumps({'exito': False, 'error': str(e)})
    
    # ===============================
    # MÉTODOS INTERNOS
    # ===============================
    
    def _actualizarExamenes(self):
        """Actualiza lista interna de exámenes"""
        try:
            self._examenesData = self.repository.get_all_with_details()
            self.examenesActualizados.emit()
        except Exception as e:
            raise ClinicaBaseException(f"Error actualizando exámenes: {str(e)}")
    
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