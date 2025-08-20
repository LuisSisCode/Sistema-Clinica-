# backend/models/paciente_model.py

from typing import List, Dict, Any, Optional
from PySide6.QtCore import QObject, Signal, Slot, Property
from PySide6.QtQml import qmlRegisterType

from ..repositories.paciente_repository import PacienteRepository
from ..core.excepciones import ExceptionHandler, ValidationError

class PacienteModel(QObject):
    """
    Model QObject para gestión integral de pacientes en QML
    Conecta la interfaz QML con el PacienteRepository
    """
    
    # ===============================
    # SIGNALS - Notificaciones a QML
    # ===============================
    
    # Señales para cambios en datos
    pacientesChanged = Signal()
    pacienteSeleccionadoChanged = Signal()
    estadisticasChanged = Signal()
    historialChanged = Signal()
    
    # Señales para operaciones CRUD
    pacienteCreado = Signal(bool, str, 'QVariantMap')  # success, message, pacienteData
    pacienteActualizado = Signal(bool, str, 'QVariantMap')
    pacienteEliminado = Signal(bool, str)
    
    # Señales para búsquedas y filtros
    busquedaCompletada = Signal(int, str)  # totalEncontrados, mensaje
    filtrosAplicados = Signal('QVariantMap')  # criteriosAplicados
    
    # Señales médicas específicas
    alertaMedicaGenerada = Signal(str, str, str)  # tipo, prioridad, mensaje
    duplicadosDetectados = Signal('QVariantList')  # listaDuplicados
    historialActualizado = Signal('QVariantMap')  # datosHistorial
    
    # Señales de estado
    loadingChanged = Signal()
    errorOccurred = Signal(str, str)  # title, message
    successMessage = Signal(str)
    warningMessage = Signal(str)
    
    def __init__(self, parent=None):
        super().__init__(parent)
        
        # Repository en lugar de service
        self.repository = PacienteRepository()
        
        # Estado interno
        self._pacientes: List[Dict[str, Any]] = []
        self._pacientes_filtrados: List[Dict[str, Any]] = []
        self._paciente_seleccionado: Optional[Dict[str, Any]] = None
        self._estadisticas: Dict[str, Any] = {}
        self._historial_medico: Dict[str, Any] = {}
        self._loading: bool = False
        
        # Filtros activos
        self._filtro_edad_min: int = 0
        self._filtro_edad_max: int = 120
        self._filtro_grupo_etario: str = "Todos"
        self._filtro_busqueda: str = ""
        self._filtro_estado_seguimiento: str = "Todos"
        
        # Configuración inicial
        self._cargar_datos_iniciales()
        
        print("👥 PacienteModel inicializado")
    
    # ===============================
    # PROPERTIES - Datos para QML
    # ===============================
    
    @Property(list, notify=pacientesChanged)
    def pacientes(self) -> List[Dict[str, Any]]:
        """Lista de pacientes para mostrar en QML"""
        return self._pacientes_filtrados
    
    @Property('QVariantMap', notify=pacienteSeleccionadoChanged)
    def pacienteSeleccionado(self) -> Dict[str, Any]:
        """Paciente actualmente seleccionado"""
        return self._paciente_seleccionado or {}
    
    @Property('QVariantMap', notify=estadisticasChanged)
    def estadisticas(self) -> Dict[str, Any]:
        """Estadísticas poblacionales de pacientes"""
        return self._estadisticas
    
    @Property('QVariantMap', notify=historialChanged)
    def historialMedico(self) -> Dict[str, Any]:
        """Historial médico del paciente seleccionado"""
        return self._historial_medico
    
    @Property(bool, notify=loadingChanged)
    def loading(self) -> bool:
        """Estado de carga"""
        return self._loading
    
    @Property(int, notify=pacientesChanged)
    def totalPacientes(self) -> int:
        """Total de pacientes filtrados"""
        return len(self._pacientes_filtrados)
    
    @Property(int)
    def totalPacientesPediatricos(self) -> int:
        """Total de pacientes pediátricos (≤17 años)"""
        return len([p for p in self._pacientes if p.get('Edad', 0) <= 17])
    
    @Property(int)
    def totalPacientesAdultos(self) -> int:
        """Total de pacientes adultos (18-64 años)"""
        return len([p for p in self._pacientes if 18 <= p.get('Edad', 0) <= 64])
    
    @Property(int)
    def totalPacientesAdultosMayores(self) -> int:
        """Total de pacientes adultos mayores (≥65 años)"""
        return len([p for p in self._pacientes if p.get('Edad', 0) >= 65])
    
    @Property(str)
    def filtroGrupoEtario(self) -> str:
        """Filtro actual por grupo etario"""
        return self._filtro_grupo_etario
    
    @Property(str)
    def filtroBusqueda(self) -> str:
        """Texto de búsqueda actual"""
        return self._filtro_busqueda
    
    # ===============================
    # SLOTS - Métodos llamables desde QML
    # ===============================
    
    # --- OPERACIONES CRUD ---
    
    @Slot(str, str, str, int, result=bool)
    def crearPaciente(self, nombre: str, apellido_paterno: str, apellido_materno: str,
                     edad: int) -> bool:
        """
        Crea nuevo paciente desde QML
        """
        try:
            self._set_loading(True)
            
            # Verificar duplicados potenciales
            duplicados = self.detectarDuplicadosPotenciales(nombre, apellido_paterno, apellido_materno, edad)
            if duplicados:
                self.duplicadosDetectados.emit(duplicados)
                self.warningMessage.emit(f"Se encontraron {len(duplicados)} posibles duplicados")
                return False
            
            # Crear usando repository
            paciente_id = self.repository.create_patient(
                nombre=nombre.strip(),
                apellido_paterno=apellido_paterno.strip(),
                apellido_materno=apellido_materno.strip(),
                edad=edad
            )
            
            if paciente_id:
                # Obtener paciente creado
                paciente_creado = self.repository.get_by_id(paciente_id)
                if paciente_creado:
                    # Agregar nombre completo
                    paciente_creado['nombre_completo'] = f"{nombre} {apellido_paterno} {apellido_materno}"
                
                # Recargar datos
                self._cargar_pacientes()
                self._cargar_estadisticas()
                
                # Generar alertas médicas según grupo etario
                self._generar_alertas_grupo_etario(paciente_creado)
                
                # Emitir señal de éxito
                mensaje = f"Paciente {nombre} {apellido_paterno} creado exitosamente"
                self.pacienteCreado.emit(True, mensaje, paciente_creado or {})
                self.successMessage.emit(mensaje)
                
                print(f"✅ Paciente creado: {nombre} {apellido_paterno}")
                return True
            else:
                error_msg = "Error creando paciente"
                self.pacienteCreado.emit(False, error_msg, {})
                self.errorOccurred.emit("Error", error_msg)
                return False
                
        except Exception as e:
            error_msg = f"Error inesperado: {str(e)}"
            self.pacienteCreado.emit(False, error_msg, {})
            self.errorOccurred.emit("Error crítico", error_msg)
            return False
        finally:
            self._set_loading(False)
    
    @Slot(int, str, str, str, int, result=bool)
    def actualizarPaciente(self, paciente_id: int, nombre: str = "", 
                          apellido_paterno: str = "", apellido_materno: str = "",
                          edad: int = -1) -> bool:
        """Actualiza paciente existente"""
        try:
            self._set_loading(True)
            
            # Preparar datos para actualización (solo campos no vacíos)
            kwargs = {}
            if nombre.strip():
                kwargs['nombre'] = nombre.strip()
            if apellido_paterno.strip():
                kwargs['apellido_paterno'] = apellido_paterno.strip()
            if apellido_materno.strip():
                kwargs['apellido_materno'] = apellido_materno.strip()
            if edad >= 0:
                kwargs['edad'] = edad
            
            if not kwargs:
                self.warningMessage.emit("No hay datos para actualizar")
                return False
            
            success = self.repository.update_patient(paciente_id, **kwargs)
            
            if success:
                # Obtener paciente actualizado
                paciente_actualizado = self.repository.get_by_id(paciente_id)
                
                # Recargar datos
                self._cargar_pacientes()
                
                # Emitir señal de éxito
                mensaje = "Paciente actualizado exitosamente"
                self.pacienteActualizado.emit(True, mensaje, paciente_actualizado or {})
                self.successMessage.emit(mensaje)
                
                print(f"✅ Paciente actualizado: ID {paciente_id}")
                return True
            else:
                self.pacienteActualizado.emit(False, "Error actualizando paciente", {})
                return False
                
        except Exception as e:
            error_msg = f"Error actualizando paciente: {str(e)}"
            self.pacienteActualizado.emit(False, error_msg, {})
            self.errorOccurred.emit("Error", error_msg)
            return False
        finally:
            self._set_loading(False)
    
    @Slot(int, result=bool)
    def eliminarPaciente(self, paciente_id: int) -> bool:
        """
        Elimina paciente (soft delete - cambiar estado)
        """
        try:
            self._set_loading(True)
            
            # Verificar que el paciente no tenga consultas recientes
            # Por simplicidad, permitir eliminación directa
            
            success = self.repository.delete(paciente_id)
            
            if success:
                # Recargar datos
                self._cargar_pacientes()
                self._cargar_estadisticas()
                
                # Emitir señal de éxito
                mensaje = "Paciente eliminado exitosamente"
                self.pacienteEliminado.emit(True, mensaje)
                self.successMessage.emit(mensaje)
                
                print(f"🗑️ Paciente eliminado: ID {paciente_id}")
                return True
            else:
                self.pacienteEliminado.emit(False, "Error eliminando paciente")
                return False
                
        except Exception as e:
            error_msg = f"Error eliminando paciente: {str(e)}"
            self.pacienteEliminado.emit(False, error_msg)
            self.errorOccurred.emit("Error", error_msg)
            return False
        finally:
            self._set_loading(False)
    
    # --- BÚSQUEDA Y FILTROS ---
    
    @Slot(str, str, int, int, str, bool)
    def buscarPacientesAvanzado(self, texto: str, grupo_etario: str, edad_min: int, 
                               edad_max: int, estado_seguimiento: str, 
                               con_consultas_recientes: bool):
        """
        Búsqueda avanzada de pacientes con múltiples criterios
        """
        try:
            self._set_loading(True)
            
            # Filtrar datos locales
            pacientes_encontrados = self._pacientes.copy()
            
            # Filtro por texto
            if texto.strip():
                texto_lower = texto.lower()
                pacientes_encontrados = [
                    p for p in pacientes_encontrados
                    if (texto_lower in p.get('Nombre', '').lower() or
                        texto_lower in p.get('Apellido_Paterno', '').lower() or
                        texto_lower in p.get('Apellido_Materno', '').lower())
                ]
            
            # Filtro por grupo etario
            if grupo_etario != "Todos":
                if grupo_etario == "PEDIÁTRICO":
                    pacientes_encontrados = [p for p in pacientes_encontrados if p.get('Edad', 0) <= 17]
                elif grupo_etario == "ADULTO":
                    pacientes_encontrados = [p for p in pacientes_encontrados if 18 <= p.get('Edad', 0) <= 64]
                elif grupo_etario == "ADULTO_MAYOR":
                    pacientes_encontrados = [p for p in pacientes_encontrados if p.get('Edad', 0) >= 65]
            
            # Filtro por edad
            if edad_min > 0:
                pacientes_encontrados = [p for p in pacientes_encontrados if p.get('Edad', 0) >= edad_min]
            if edad_max < 120:
                pacientes_encontrados = [p for p in pacientes_encontrados if p.get('Edad', 0) <= edad_max]
            
            # Actualizar lista filtrada
            self._pacientes_filtrados = pacientes_encontrados
            
            # Actualizar filtros activos
            self._filtro_busqueda = texto
            self._filtro_grupo_etario = grupo_etario
            self._filtro_edad_min = edad_min
            self._filtro_edad_max = edad_max
            self._filtro_estado_seguimiento = estado_seguimiento
            
            # Emitir señales
            self.pacientesChanged.emit()
            mensaje = f"Encontrados {len(pacientes_encontrados)} pacientes"
            self.busquedaCompletada.emit(len(pacientes_encontrados), mensaje)
            
            criterios = {
                'texto': texto,
                'grupo_etario': grupo_etario,
                'edad_min': edad_min,
                'edad_max': edad_max
            }
            self.filtrosAplicados.emit(criterios)
            
            print(f"🔍 Búsqueda completada: {len(pacientes_encontrados)} pacientes")
                
        except Exception as e:
            self.errorOccurred.emit("Error en búsqueda", f"Error: {str(e)}")
        finally:
            self._set_loading(False)
    
    @Slot(str)
    def buscarPacientesRapido(self, termino: str):
        """Búsqueda rápida por nombre"""
        if len(termino.strip()) < 2:
            self._pacientes_filtrados = self._pacientes.copy()
            self.pacientesChanged.emit()
            return
        
        try:
            pacientes = self.repository.search_patients(termino, limit=100)
            self._pacientes_filtrados = pacientes
            
            self._filtro_busqueda = termino
            self.pacientesChanged.emit()
            self.busquedaCompletada.emit(len(pacientes), 
                                        f"Encontrados {len(pacientes)} pacientes")
        except Exception as e:
            self.errorOccurred.emit("Error", f"Error en búsqueda: {str(e)}")
    
    @Slot()
    def limpiarFiltros(self):
        """Limpia todos los filtros aplicados"""
        self._filtro_busqueda = ""
        self._filtro_grupo_etario = "Todos"
        self._filtro_edad_min = 0
        self._filtro_edad_max = 120
        self._filtro_estado_seguimiento = "Todos"
        
        self._pacientes_filtrados = self._pacientes.copy()
        self.pacientesChanged.emit()
        self.busquedaCompletada.emit(len(self._pacientes_filtrados), "Filtros limpiados")
        print("🧹 Filtros de pacientes limpiados")
    
    # --- GESTIÓN DE PACIENTE SELECCIONADO ---
    
    @Slot(int)
    def seleccionarPaciente(self, paciente_id: int):
        """Selecciona un paciente y carga su dashboard"""
        try:
            self._set_loading(True)
            
            # Obtener paciente con consultas y laboratorio
            paciente = self.repository.get_complete_patient_record(paciente_id)
            
            if paciente:
                self._paciente_seleccionado = paciente
                self.pacienteSeleccionadoChanged.emit()
                
                # Cargar historial médico
                self._cargar_historial_medico(paciente_id)
                
                print(f"👤 Paciente seleccionado: ID {paciente_id}")
            else:
                self.errorOccurred.emit("Error", "Paciente no encontrado")
                
        except Exception as e:
            self.errorOccurred.emit("Error", f"Error seleccionando paciente: {str(e)}")
        finally:
            self._set_loading(False)
    
    @Slot()
    def deseleccionarPaciente(self):
        """Deselecciona el paciente actual"""
        self._paciente_seleccionado = None
        self._historial_medico = {}
        self.pacienteSeleccionadoChanged.emit()
        self.historialChanged.emit()
        print("👤 Paciente deseleccionado")
    
    @Slot(int, result='QVariantMap')
    def obtenerDashboardPaciente(self, paciente_id: int) -> Dict[str, Any]:
        """Obtiene dashboard médico completo de un paciente"""
        try:
            return self.repository.get_complete_patient_record(paciente_id) or {}
        except Exception:
            return {}
    
    # --- HISTORIAL MÉDICO ---
    
    @Slot(int, bool)
    def cargarHistorialCompleto(self, paciente_id: int, incluir_detalles: bool = True):
        """Carga historial médico completo del paciente"""
        try:
            self._set_loading(True)
            
            historial = self.repository.get_complete_patient_record(paciente_id)
            
            if historial:
                self._historial_medico = historial
                self.historialChanged.emit()
                self.historialActualizado.emit(self._historial_medico)
                print(f"📋 Historial cargado para paciente {paciente_id}")
            else:
                self.errorOccurred.emit("Error", "Historial no encontrado")
                
        except Exception as e:
            self.errorOccurred.emit("Error", f"Error cargando historial: {str(e)}")
        finally:
            self._set_loading(False)
    
    # --- VALIDACIONES MÉDICAS ---
    
    @Slot(int, str, result='QVariantMap')
    def validarEdadApropiada(self, edad: int, tipo_consulta: str = "general") -> Dict[str, Any]:
        """Valida si la edad es apropiada para el tipo de consulta"""
        try:
            grupo_etario = self.repository.get_age_group(edad)
            edad_valida = 0 <= edad <= 120
            
            return {
                'edad_valida': edad_valida,
                'grupo_etario': grupo_etario,
                'recomendaciones': self._get_age_recommendations(edad, grupo_etario)
            }
        except Exception:
            return {'edad_valida': False, 'grupo_etario': 'Desconocido'}
    
    @Slot(str, str, str, int, result='QVariantList')
    def detectarDuplicadosPotenciales(self, nombre: str, apellido_paterno: str, 
                                     apellido_materno: str, edad: int) -> List[Dict[str, Any]]:
        """Detecta pacientes que podrían ser duplicados"""
        try:
            nombre_completo = f"{nombre} {apellido_paterno} {apellido_materno}".lower()
            
            duplicados_potenciales = []
            for paciente in self._pacientes:
                nombre_existente = f"{paciente.get('Nombre', '')} {paciente.get('Apellido_Paterno', '')} {paciente.get('Apellido_Materno', '')}".lower()
                edad_existente = paciente.get('Edad', 0)
                
                # Similitud de nombre y edad cercana
                if (nombre.lower() in nombre_existente and 
                    abs(edad - edad_existente) <= 2):
                    duplicados_potenciales.append({
                        'paciente': paciente,
                        'similitud': 0.8,
                        'diferencias': [f"Edad: {edad_existente} vs {edad}"]
                    })
            
            if duplicados_potenciales:
                self.duplicadosDetectados.emit(duplicados_potenciales)
            
            return duplicados_potenciales
        except Exception:
            return []
    
    # --- ESTADÍSTICAS Y REPORTES ---
    
    @Slot()
    def cargarEstadisticasGenerales(self):
        """Carga estadísticas poblacionales generales"""
        try:
            self._set_loading(True)
            
            estadisticas = self.repository.get_patient_statistics()
            
            if estadisticas:
                self._estadisticas = estadisticas
                self.estadisticasChanged.emit()
                print("📊 Estadísticas de pacientes cargadas")
            else:
                self.errorOccurred.emit("Error", "No se pudieron cargar estadísticas")
                
        except Exception as e:
            self.errorOccurred.emit("Error", f"Error cargando estadísticas: {str(e)}")
        finally:
            self._set_loading(False)
    
    # --- UTILIDADES ---
    
    @Slot(result=list)
    def obtenerGruposEtariosDisponibles(self) -> List[str]:
        """Obtiene lista de grupos etarios para filtros"""
        return ["Todos", "PEDIÁTRICO", "ADULTO", "ADULTO_MAYOR"]
    
    @Slot(result=list)
    def obtenerEstadosSeguimientoDisponibles(self) -> List[str]:
        """Obtiene lista de estados de seguimiento"""
        return ["Todos", "Activo", "Inactivo", "Sin seguimiento", "Seguimiento regular"]
    
    @Slot(result='QVariantList')
    def obtenerPacientesFrecuentes(self, limite: int = 10) -> List[Dict[str, Any]]:
        """Obtiene pacientes con más consultas"""
        try:
            return self.repository.get_most_frequent_patients(limite)
        except Exception:
            return []
    
    @Slot()
    def recargarDatos(self):
        """Recarga todos los datos de pacientes"""
        try:
            self._set_loading(True)
            self._cargar_datos_iniciales()
            self.successMessage.emit("Datos de pacientes recargados")
            print("🔄 Datos de pacientes recargados")
        except Exception as e:
            self.errorOccurred.emit("Error", f"Error recargando datos: {str(e)}")
        finally:
            self._set_loading(False)
    
    # ===============================
    # MÉTODOS PRIVADOS
    # ===============================
    
    def _cargar_datos_iniciales(self):
        """Carga todos los datos necesarios al inicializar"""
        try:
            self._cargar_pacientes()
            self._cargar_estadisticas()
            print("📊 Datos iniciales de pacientes cargados")
        except Exception as e:
            print(f"❌ Error cargando datos iniciales: {e}")
            self.errorOccurred.emit("Error inicial", f"Error cargando datos: {str(e)}")
    
    def _cargar_pacientes(self):
        """Carga lista de pacientes desde el repository"""
        try:
            pacientes = self.repository.get_active()
            
            # Agregar nombre completo
            for paciente in pacientes:
                paciente['nombre_completo'] = f"{paciente.get('Nombre', '')} {paciente.get('Apellido_Paterno', '')} {paciente.get('Apellido_Materno', '')}"
                paciente['grupo_etario'] = self.repository.get_age_group(paciente.get('Edad', 0))
            
            self._pacientes = pacientes
            self._pacientes_filtrados = pacientes.copy()
            self.pacientesChanged.emit()
            print(f"👥 Pacientes cargados: {len(pacientes)}")
                
        except Exception as e:
            print(f"❌ Error cargando pacientes: {e}")
            self._pacientes = []
            self._pacientes_filtrados = []
    
    def _cargar_estadisticas(self):
        """Carga estadísticas desde el repository"""
        try:
            estadisticas = self.repository.get_patient_statistics()
            if estadisticas:
                self._estadisticas = estadisticas
                self.estadisticasChanged.emit()
                print("📈 Estadísticas de pacientes cargadas")
        except Exception as e:
            print(f"❌ Error cargando estadísticas: {e}")
            self._estadisticas = {}
    
    def _cargar_historial_medico(self, paciente_id: int):
        """Carga historial médico del paciente"""
        try:
            historial = self.repository.get_complete_patient_record(paciente_id)
            if historial:
                self._historial_medico = historial
                self.historialChanged.emit()
        except Exception as e:
            print(f"❌ Error cargando historial: {e}")
            self._historial_medico = {}
    
    def _set_loading(self, loading: bool):
        """Actualiza estado de carga"""
        if self._loading != loading:
            self._loading = loading
            self.loadingChanged.emit()
    
    def _generar_alertas_grupo_etario(self, paciente: Dict[str, Any]):
        """Genera alertas médicas según grupo etario"""
        try:
            edad = paciente.get('Edad', 0)
            nombre = paciente.get('nombre_completo', '')
            
            if edad <= 17:
                self.alertaMedicaGenerada.emit(
                    "pediatrico",
                    "info",
                    f"Paciente pediátrico registrado: {nombre} ({edad} años)"
                )
            elif edad >= 65:
                self.alertaMedicaGenerada.emit(
                    "geriatrico", 
                    "info",
                    f"Adulto mayor registrado: {nombre} ({edad} años) - Considerar evaluación geriátrica"
                )
        except Exception as e:
            print(f"⚠️ Error generando alertas: {e}")
    
    def _get_age_recommendations(self, edad: int, grupo_etario: str) -> List[str]:
        """Genera recomendaciones según edad"""
        recommendations = []
        
        if grupo_etario == "PEDIÁTRICO":
            recommendations.append("Consulta pediátrica especializada")
            recommendations.append("Verificar esquema de vacunación")
        elif grupo_etario == "ADULTO_MAYOR":
            recommendations.append("Evaluación geriátrica integral")
            recommendations.append("Chequeo cardiovascular")
            recommendations.append("Evaluación cognitiva")
        
        return recommendations

# ===============================
# REGISTRO PARA QML
# ===============================

def register_paciente_model():
    """Registra el PacienteModel para uso en QML"""
    qmlRegisterType(PacienteModel, "ClinicaModels", 1, 0, "PacienteModel")
    print("🔗 PacienteModel registrado para QML")

# Para facilitar la importación
__all__ = ['PacienteModel', 'register_paciente_model']