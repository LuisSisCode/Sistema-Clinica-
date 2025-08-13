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
from ..services.laboratorio_service import LaboratorioService

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
        
        # Servicio de laboratorio
        self.laboratorio_service = LaboratorioService()
        
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
    
    @Slot(str, int, result=str)
    def crearExamen(self, datosJson: str, usuarioId: int) -> str:
        """
        Crea nuevo examen de laboratorio
        
        Args:
            datosJson: JSON con datos del examen
            usuarioId: ID del usuario que crea
            
        Returns:
            JSON con resultado de la operación
        """
        try:
            self._set_estado_actual("cargando")
            
            # Parsear datos
            datos = json.loads(datosJson)
            
            # Llamar al servicio
            resultado = self.laboratorio_service.crear_examen_completo(datos, usuarioId)
            
            if resultado.get('exito', False):
                # Emitir signal de éxito
                self.examenCreado.emit(json.dumps(resultado['examen_completo'], default=str))
                self.operacionExitosa.emit(f"Examen creado exitosamente: ID {resultado['examen_id']}")
                
                # Actualizar datos locales
                self._actualizarExamenes()
                
                self._set_estado_actual("listo")
                return json.dumps(resultado, default=str)
            else:
                error_msg = resultado.get('error', 'Error desconocido')
                self.errorOcurrido.emit(error_msg, 'CREATE_ERROR')
                self._set_estado_actual("error")
                return json.dumps({'exito': False, 'error': error_msg})
                
        except Exception as e:
            error_msg = f"Error creando examen: {str(e)}"
            self.errorOcurrido.emit(error_msg, 'CREATE_EXCEPTION')
            self._set_estado_actual("error")
            return json.dumps({'exito': False, 'error': error_msg})
    
    @Slot(int, str, int, result=str)
    def actualizarExamen(self, examenId: int, datosJson: str, usuarioId: int) -> str:
        """
        Actualiza examen existente
        
        Args:
            examenId: ID del examen a actualizar
            datosJson: JSON con nuevos datos
            usuarioId: ID del usuario que actualiza
            
        Returns:
            JSON con resultado de la operación
        """
        try:
            self._set_estado_actual("cargando")
            
            datos = json.loads(datosJson)
            resultado = self.laboratorio_service.actualizar_examen_con_validaciones(
                examenId, datos, usuarioId
            )
            
            if resultado.get('exito', False):
                # Emitir signals
                self.examenActualizado.emit(json.dumps(resultado.get('datos', {}), default=str))
                self.operacionExitosa.emit(f"Examen {examenId} actualizado correctamente")
                
                # Actualizar datos
                self._actualizarExamenes()
                
                self._set_estado_actual("listo")
                return json.dumps(resultado, default=str)
            else:
                error_msg = resultado.get('mensaje', 'Error actualizando')
                self.errorOcurrido.emit(error_msg, 'UPDATE_ERROR')
                self._set_estado_actual("error")
                return json.dumps(resultado)
                
        except Exception as e:
            error_msg = f"Error actualizando examen: {str(e)}"
            self.errorOcurrido.emit(error_msg, 'UPDATE_EXCEPTION')
            self._set_estado_actual("error")
            return json.dumps({'exito': False, 'error': error_msg})
    
    @Slot(int, result=bool)
    def eliminarExamen(self, examenId: int) -> bool:
        """
        Elimina examen de laboratorio
        
        Args:
            examenId: ID del examen a eliminar
            
        Returns:
            True si se eliminó correctamente
        """
        try:
            self._set_estado_actual("cargando")
            
            exito = self.laboratorio_service.eliminar_examen_seguro(examenId)
            
            if exito:
                # Emitir signals
                self.examenEliminado.emit(examenId)
                self.operacionExitosa.emit(f"Examen {examenId} eliminado correctamente")
                
                # Actualizar datos
                self._actualizarExamenes()
                
                self._set_estado_actual("listo")
                return True
            else:
                self.errorOcurrido.emit(f"No se pudo eliminar el examen {examenId}", 'DELETE_ERROR')
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
    def asignarTrabajador(self, examenId: int, trabajadorId: int) -> bool:
        """
        Asigna trabajador a examen
        
        Args:
            examenId: ID del examen
            trabajadorId: ID del trabajador
            
        Returns:
            True si se asignó correctamente
        """
        try:
            exito = self.laboratorio_service.asignar_trabajador_optimizado(examenId, trabajadorId)
            
            if exito:
                self.trabajadorAsignado.emit(examenId, trabajadorId)
                self.operacionExitosa.emit(f"Trabajador asignado al examen {examenId}")
                self._actualizarExamenes()
                return True
            else:
                self.errorOcurrido.emit(f"Error asignando trabajador", 'ASSIGN_ERROR')
                return False
                
        except Exception as e:
            self.errorOcurrido.emit(f"Error: {str(e)}", 'ASSIGN_EXCEPTION')
            return False
    
    @Slot(int, result=bool)
    def desasignarTrabajador(self, examenId: int) -> bool:
        """
        Desasigna trabajador de examen
        
        Args:
            examenId: ID del examen
            
        Returns:
            True si se desasignó correctamente
        """
        try:
            exito = self.laboratorio_service.desasignar_trabajador(examenId)
            
            if exito:
                self.trabajadorDesasignado.emit(examenId)
                self.operacionExitosa.emit(f"Trabajador desasignado del examen {examenId}")
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
    def buscarExamenesAvanzado(self, criteriosJson: str) -> str:
        """
        Realiza búsqueda avanzada de exámenes
        
        Args:
            criteriosJson: JSON con criterios de búsqueda
            
        Returns:
            JSON con resultados de búsqueda
        """
        try:
            criterios = json.loads(criteriosJson)
            resultado = self.laboratorio_service.buscar_examenes_avanzado(criterios)
            
            # Emitir signal con resultados
            self.resultadosBusqueda.emit(json.dumps(resultado, default=str))
            
            return json.dumps(resultado, default=str)
            
        except Exception as e:
            error_msg = f"Error en búsqueda: {str(e)}"
            self.errorOcurrido.emit(error_msg, 'SEARCH_ERROR')
            return json.dumps({'exito': False, 'error': error_msg})
    
    @Slot(str, result=str)
    def filtrarExamenes(self, filtrosJson: str) -> str:
        """
        Aplica filtros a la lista de exámenes
        
        Args:
            filtrosJson: JSON con filtros a aplicar
            
        Returns:
            JSON con exámenes filtrados
        """
        try:
            filtros = json.loads(filtrosJson)
            
            # Aplicar filtros usando el servicio
            examenes_filtrados = self.laboratorio_service.aplicar_filtros_examenes(
                self._examenesData, filtros
            )
            
            # Emitir signal
            self.filtrosAplicados.emit(filtrosJson)
            
            return json.dumps({
                'exito': True,
                'examenes': examenes_filtrados,
                'total': len(examenes_filtrados),
                'filtros_aplicados': filtros
            }, default=str)
            
        except Exception as e:
            error_msg = f"Error aplicando filtros: {str(e)}"
            self.errorOcurrido.emit(error_msg, 'FILTER_ERROR')
            return json.dumps({'exito': False, 'error': error_msg})
    
    @Slot(int, result=str)
    def obtenerExamenCompleto(self, examenId: int) -> str:
        """
        Obtiene examen con información completa
        
        Args:
            examenId: ID del examen
            
        Returns:
            JSON con examen completo
        """
        try:
            examen = self.laboratorio_service.obtener_examen_completo(examenId)
            
            if examen:
                return json.dumps(examen, default=str)
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
        
        Returns:
            JSON con datos de dashboard
        """
        try:
            self._set_estado_actual("cargando")
            
            dashboard = self.laboratorio_service.obtener_dashboard_laboratorio()
            
            # Actualizar datos internos
            self._dashboardData = dashboard
            
            # Emitir signal
            self.dashboardActualizado.emit(json.dumps(dashboard, default=str))
            
            self._set_estado_actual("listo")
            return json.dumps(dashboard, default=str)
            
        except Exception as e:
            error_msg = f"Error generando dashboard: {str(e)}"
            self.errorOcurrido.emit(error_msg, 'DASHBOARD_ERROR')
            self._set_estado_actual("error")
            return json.dumps({'exito': False, 'error': error_msg})
    
    @Slot(result=str)
    def obtenerEstadisticas(self) -> str:
        """
        Obtiene estadísticas completas de laboratorio
        
        Returns:
            JSON con estadísticas
        """
        try:
            estadisticas = self.laboratorio_service.generar_estadisticas_completas()
            
            # Actualizar datos internos
            self._estadisticasData = estadisticas
            
            # Emitir signal
            self.estadisticasCalculadas.emit(json.dumps(estadisticas, default=str))
            
            return json.dumps(estadisticas, default=str)
            
        except Exception as e:
            error_msg = f"Error generando estadísticas: {str(e)}"
            self.errorOcurrido.emit(error_msg, 'STATS_ERROR')
            return json.dumps({'exito': False, 'error': error_msg})
    
    @Slot(int, str, str, result=str)
    def generarReporteTrabajador(self, trabajadorId: int, fechaInicio: str, fechaFin: str) -> str:
        """
        Genera reporte de actividad de trabajador
        
        Args:
            trabajadorId: ID del trabajador
            fechaInicio: Fecha inicio en formato ISO
            fechaFin: Fecha fin en formato ISO
            
        Returns:
            JSON con reporte
        """
        try:
            reporte = self.laboratorio_service.generar_reporte_trabajador_completo(
                trabajadorId, fechaInicio, fechaFin
            )
            
            return json.dumps(reporte, default=str)
            
        except Exception as e:
            error_msg = f"Error generando reporte: {str(e)}"
            self.errorOcurrido.emit(error_msg, 'REPORT_ERROR')
            return json.dumps({'exito': False, 'error': error_msg})
    
    @Slot(int, result=str)
    def obtenerResumenPaciente(self, pacienteId: int) -> str:
        """
        Obtiene resumen de laboratorio de un paciente
        
        Args:
            pacienteId: ID del paciente
            
        Returns:
            JSON con resumen
        """
        try:
            resumen = self.laboratorio_service.obtener_resumen_paciente_laboratorio(pacienteId)
            
            return json.dumps(resumen, default=str)
            
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
            tipos = self.laboratorio_service.obtener_tipos_analisis_disponibles()
            self._tiposAnalisisData = tipos
            self.tiposAnalisisActualizados.emit()
        except Exception as e:
            self.errorOcurrido.emit(f"Error cargando tipos: {str(e)}", 'LOAD_TYPES_ERROR')
    
    @Slot()
    def cargarTrabajadores(self):
        """Carga trabajadores de laboratorio disponibles"""
        try:
            trabajadores = self.laboratorio_service.obtener_trabajadores_laboratorio()
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
    # SLOTS PARA VALIDACIONES
    # ===============================
    
    @Slot(str, result=str)
    def validarDatosExamen(self, datosJson: str) -> str:
        """
        Valida datos de examen antes de guardar
        
        Args:
            datosJson: JSON con datos a validar
            
        Returns:
            JSON con resultado de validación
        """
        try:
            datos = json.loads(datosJson)
            resultado = self.laboratorio_service.validar_datos_examen_completo(datos)
            
            return json.dumps(resultado, default=str)
            
        except Exception as e:
            return json.dumps({
                'valido': False,
                'errores': [f"Error en validación: {str(e)}"]
            })
    
    @Slot(int, int, result=bool)
    def validarAsignacionTrabajador(self, examenId: int, trabajadorId: int) -> bool:
        """
        Valida si se puede asignar trabajador a examen
        
        Args:
            examenId: ID del examen
            trabajadorId: ID del trabajador
            
        Returns:
            True si la asignación es válida
        """
        try:
            return self.laboratorio_service.validar_asignacion_trabajador(examenId, trabajadorId)
        except Exception as e:
            self.errorOcurrido.emit(f"Error validando asignación: {str(e)}", 'VALIDATION_ERROR')
            return False
    
    # ===============================
    # MÉTODOS INTERNOS
    # ===============================
    
    def _actualizarExamenes(self):
        """Actualiza lista interna de exámenes"""
        try:
            self._examenesData = self.laboratorio_service.obtener_examenes_completos()
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
        
        Args:
            intervalMs: Intervalo en milisegundos (0 para desactivar)
        """
        if intervalMs > 0:
            self._autoRefreshInterval = intervalMs
            if hasattr(self, '_autoRefreshTimer'):
                self._autoRefreshTimer.start(intervalMs)
        else:
            if hasattr(self, '_autoRefreshTimer'):
                self._autoRefreshTimer.stop()
    
    # ===============================
    # SLOTS PARA CONFIGURACIÓN
    # ===============================
    
    @Slot(str, result=str)
    def configurarTipoAnalisis(self, configJson: str) -> str:
        """
        Configura un nuevo tipo de análisis
        
        Args:
            configJson: JSON con configuración del tipo
            
        Returns:
            JSON con resultado de la operación
        """
        try:
            config = json.loads(configJson)
            resultado = self.laboratorio_service.configurar_tipo_analisis(config)
            
            if resultado.get('exito', False):
                self.cargarTiposAnalisis()  # Recargar tipos
                self.operacionExitosa.emit("Tipo de análisis configurado correctamente")
            
            return json.dumps(resultado, default=str)
            
        except Exception as e:
            error_msg = f"Error configurando tipo: {str(e)}"
            self.errorOcurrido.emit(error_msg, 'CONFIG_ERROR')
            return json.dumps({'exito': False, 'error': error_msg})

# ===============================
# REGISTRO PARA QML
# ===============================

def register_laboratorio_model():
    """Registra el modelo para uso en QML"""
    qmlRegisterType(LaboratorioModel, "Clinica.Models", 1, 0, "LaboratorioModel")
    print("✅ LaboratorioModel registrado para QML")