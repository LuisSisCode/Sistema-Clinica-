from typing import List, Dict, Any, Optional
from PySide6.QtCore import QObject, Signal, Slot, Property
from PySide6.QtQml import qmlRegisterType

from ..repositories.paciente_repository import PacienteRepository
from ..core.excepciones import ExceptionHandler, ValidationError

class PacienteModel(QObject):
    """Model QObject para gestión integral de pacientes en QML - SIN campo Edad"""
    
    # ===============================
    # SIGNALS PARA QML
    # ===============================
    
    # Señales para cambios en datos
    pacientesChanged = Signal()
    pacienteSeleccionadoChanged = Signal()
    estadisticasChanged = Signal()
    historialChanged = Signal()
    
    # Señales para operaciones CRUD
    pacienteCreado = Signal(bool, str, 'QVariantMap')
    pacienteActualizado = Signal(bool, str, 'QVariantMap')
    pacienteEliminado = Signal(bool, str)
    
    # Señales para búsquedas y filtros
    busquedaCompletada = Signal(int, str)
    filtrosAplicados = Signal('QVariantMap')
    
    # Señales para autocompletado - CORREGIDAS
    sugerenciasPacientesDisponibles = Signal('QVariantList', arguments=['sugerencias'])
    autocompletadoSeleccionado = Signal('QVariantMap', arguments=['pacienteSeleccionado'])
    
    # Señales de estado
    loadingChanged = Signal()
    errorOccurred = Signal(str, str)
    successMessage = Signal(str)
    warningMessage = Signal(str)
    
    def __init__(self, parent=None):
        super().__init__(parent)
        
        # Repository
        self.repository = PacienteRepository()
        
        # Estado interno
        self._pacientes: List[Dict[str, Any]] = []
        self._pacientes_filtrados: List[Dict[str, Any]] = []
        self._paciente_seleccionado: Optional[Dict[str, Any]] = None
        self._estadisticas: Dict[str, Any] = {}
        self._historial_medico: Dict[str, Any] = {}
        self._loading: bool = False
        
        # Filtros activos - SIN filtros por edad
        self._filtro_busqueda: str = ""
        self._filtro_apellido: str = ""
        self._filtro_cedula: str = ""
        
        # Configuración inicial
        self._cargar_datos_iniciales()
        
        print("👥 PacienteModel inicializado - SIN campo Edad")
    
    # ===============================
    # PROPERTIES PARA QML
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
    
    @Property(bool, notify=loadingChanged)
    def loading(self) -> bool:
        """Estado de carga"""
        return self._loading
    
    @Property(int, notify=pacientesChanged)
    def totalPacientes(self) -> int:
        """Total de pacientes filtrados"""
        return len(self._pacientes_filtrados)
    
    # ===============================
    # SLOTS PARA OPERACIONES CRUD - SIN EDAD
    # ===============================
    
    @Slot(str, str, str, str, result=bool)
    def crearPaciente(self, nombre: str, apellido_paterno: str, apellido_materno: str,
                     cedula: str) -> bool:
        """Crea nuevo paciente - SIN edad, cédula obligatoria"""
        try:
            self._set_loading(True)
            
            if not cedula or len(cedula.strip()) < 5:
                self.pacienteCreado.emit(False, "Cédula es obligatoria (mínimo 5 dígitos)", {})
                return False
            
            cedula_clean = cedula.strip()
            
            # Crear usando repository
            paciente_id = self.repository.create_patient(
                nombre=nombre.strip(),
                apellido_paterno=apellido_paterno.strip(),
                apellido_materno=apellido_materno.strip(),
                cedula=cedula_clean
            )
            
            if paciente_id:
                # Recargar datos
                self._cargar_pacientes()
                self._cargar_estadisticas()
                
                mensaje = f"Paciente {nombre} {apellido_paterno} creado exitosamente"
                self.pacienteCreado.emit(True, mensaje, {})
                self.successMessage.emit(mensaje)
                
                return True
            else:
                self.pacienteCreado.emit(False, "Error creando paciente", {})
                return False
                    
        except ValidationError as ve:
            error_msg = ve.message
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
    
    @Slot(int, str, str, str, str, result=bool)
    def actualizarPaciente(self, paciente_id: int, nombre: str = "", apellido_paterno: str = "", 
                          apellido_materno: str = "", cedula: str = "") -> bool:
        """Actualiza paciente existente - SIN edad"""
        try:
            self._set_loading(True)
            
            # Solo actualizar campos que no están vacíos
            update_params = {}
            if nombre.strip():
                update_params['nombre'] = nombre.strip()
            if apellido_paterno.strip():
                update_params['apellido_paterno'] = apellido_paterno.strip()
            if apellido_materno.strip():
                update_params['apellido_materno'] = apellido_materno.strip()
            if cedula.strip():
                update_params['cedula'] = cedula.strip()
            
            success = self.repository.update_patient(paciente_id, **update_params)
            
            if success:
                # Recargar datos
                self._cargar_pacientes()
                self._cargar_estadisticas()
                
                mensaje = f"Paciente actualizado exitosamente"
                self.pacienteActualizado.emit(True, mensaje, {})
                self.successMessage.emit(mensaje)
                return True
            else:
                self.pacienteActualizado.emit(False, "Error actualizando paciente", {})
                return False
                
        except ValidationError as ve:
            self.pacienteActualizado.emit(False, ve.message, {})
            self.errorOccurred.emit("Error", ve.message)
            return False
        except Exception as e:
            error_msg = f"Error actualizando paciente: {str(e)}"
            self.pacienteActualizado.emit(False, error_msg, {})
            self.errorOccurred.emit("Error", error_msg)
            return False
        finally:
            self._set_loading(False)
    
    # ===============================
    # SLOTS PARA BÚSQUEDA - MEJORADOS SIN EDAD
    # ===============================
    
    @Slot(str, result='QVariantList')
    def buscarSugerenciasPacientes(self, termino: str) -> List[Dict[str, Any]]:
        """Búsqueda de sugerencias de pacientes - SIN edad"""
        try:
            if not termino or len(termino.strip()) < 2:
                return []
            
            sugerencias = self.repository.search_patients_incremental(termino.strip(), limit=8)
            
            sugerencias_formateadas = []
            for paciente in sugerencias:
                sugerencia = {
                    'id': paciente.get('id'),
                    'nombre': paciente.get('Nombre', ''),
                    'apellido_paterno': paciente.get('Apellido_Paterno', ''),
                    'apellido_materno': paciente.get('Apellido_Materno', ''),
                    'cedula': paciente.get('Cedula', ''),
                    'nombre_completo': f"{paciente.get('Nombre', '')} {paciente.get('Apellido_Paterno', '')} {paciente.get('Apellido_Materno', '')}".strip()
                }
                
                # Agregar información de búsqueda por cédula
                if termino.strip().isdigit():
                    sugerencia['busqueda_por_cedula'] = True
                    sugerencia['cedula_coincide'] = paciente.get('Cedula', '').startswith(termino.strip())
                
                sugerencias_formateadas.append(sugerencia)
            
            # Emitir signal para QML
            self.sugerenciasPacientesDisponibles.emit(sugerencias_formateadas)
            
            return sugerencias_formateadas
            
        except Exception as e:
            print(f"⚠️ Error en búsqueda de sugerencias: {e}")
            return []
    
    @Slot(str, result='QVariantList')
    def buscarPacientesPorCedula(self, cedula: str) -> List[Dict[str, Any]]:
        """Búsqueda específica por cédula"""
        try:
            if not cedula or len(cedula.strip()) < 5:
                return []
            
            resultados = self.repository.search_by_cedula(cedula.strip())
            
            sugerencias_formateadas = []
            for paciente in resultados:
                sugerencias_formateadas.append({
                    'id': paciente.get('id'),
                    'nombre': paciente.get('Nombre', ''),
                    'apellido_paterno': paciente.get('Apellido_Paterno', ''),
                    'apellido_materno': paciente.get('Apellido_Materno', ''),
                    'cedula': paciente.get('Cedula', ''),
                    'nombre_completo': f"{paciente.get('Nombre', '')} {paciente.get('Apellido_Paterno', '')} {paciente.get('Apellido_Materno', '')}".strip(),
                    'busqueda_exacta': True
                })
            
            return sugerencias_formateadas
            
        except Exception as e:
            print(f"⚠️ Error búsqueda por cédula: {e}")
            return []
    
    @Slot('QVariantMap')
    def seleccionarSugerenciaPaciente(self, paciente_data: Dict[str, Any]):
        """Procesa la selección de una sugerencia de paciente"""
        try:
            # Emitir signal con los datos del paciente seleccionado
            self.autocompletadoSeleccionado.emit(paciente_data)
            
            print(f"👤 Sugerencia seleccionada: {paciente_data.get('nombre_completo', 'Desconocido')}")
            
        except Exception as e:
            self.errorOccurred.emit("Error", f"Error seleccionando sugerencia: {str(e)}")
    
    @Slot(str)
    def buscarPacientesRapido(self, termino: str):
        """Búsqueda rápida por nombre o cédula"""
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
    
    # ===============================
    # SLOTS PARA GESTIÓN INTELIGENTE - SIN EDAD
    # ===============================
    
    @Slot(str, str, str, str, result=int)
    def buscarOCrearPacienteSimple(self, nombre: str, apellido_paterno: str, 
                                  apellido_materno: str = "", cedula: str = "") -> int:
        """Busca paciente por cédula o crea nuevo - cédula obligatoria"""
        try:
            self._set_loading(True)
            
            if not cedula or len(cedula.strip()) < 5:
                self.errorOccurred.emit("Datos inválidos", "Cédula es obligatoria (mínimo 5 dígitos)")
                return -1
            
            cedula_clean = cedula.strip()
            
            return self.repository.buscar_o_crear_paciente_simple(
                nombre, apellido_paterno, apellido_materno, cedula_clean
            )
        except ValidationError as ve:
            self.errorOccurred.emit("Datos inválidos", ve.message)
            return -1
        except Exception as e:
            self.errorOccurred.emit("Error", f"Error gestionando paciente: {str(e)}")
            return -1
        finally:
            self._set_loading(False)
    
    @Slot(int, result='QVariantMap')
    def obtenerPacienteCompleto(self, paciente_id: int) -> Dict[str, Any]:
        """Obtiene información completa de un paciente"""
        try:
            paciente = self.repository.get_complete_patient_record(paciente_id)
            return paciente or {}
        except Exception as e:
            self.errorOccurred.emit("Error", f"Error obteniendo paciente: {str(e)}")
            return {}
    
    @Slot(str, result='QVariantMap')
    def obtenerPacientePorCedula(self, cedula: str) -> Dict[str, Any]:
        """Obtiene paciente por cédula exacta - NUEVO MÉTODO"""
        try:
            if not cedula or len(cedula.strip()) < 5:
                return {}
            
            paciente = self.repository.search_by_cedula_exact(cedula.strip())
            
            if paciente:
                # Agregar nombre completo
                paciente['nombre_completo'] = f"{paciente.get('Nombre', '')} {paciente.get('Apellido_Paterno', '')} {paciente.get('Apellido_Materno', '')}".strip()
                return paciente
            
            return {}
            
        except Exception as e:
            self.errorOccurred.emit("Error", f"Error obteniendo paciente por cédula: {str(e)}")
            return {}
    
    @Slot(str, result=bool)
    def validarCedulaUnica(self, cedula: str, excluir_id: int = 0) -> bool:
        """Valida que la cédula sea única - NUEVO MÉTODO"""
        try:
            if not cedula or len(cedula.strip()) < 5:
                return False
            
            return self.repository.validate_cedula_unique(cedula.strip(), excluir_id if excluir_id > 0 else None)
            
        except Exception as e:
            print(f"Error validando cédula única: {e}")
            return False
    
    # ===============================
    # SLOTS DE UTILIDAD
    # ===============================
    
    @Slot(int, result=str)
    def obtenerNombreCompleto(self, paciente_id: int) -> str:
        """Obtiene nombre completo del paciente"""
        try:
            return self.repository.get_patient_full_name(paciente_id)
        except Exception:
            return ""
    
    @Slot(int, result=bool)
    def validarPacienteExiste(self, paciente_id: int) -> bool:
        """Valida que el paciente existe"""
        try:
            return self.repository.validate_patient_exists(paciente_id)
        except Exception:
            return False
    
    @Slot()
    def limpiarFiltros(self):
        """Limpia todos los filtros aplicados"""
        self._filtro_busqueda = ""
        self._filtro_apellido = ""
        self._filtro_cedula = ""
        
        self._pacientes_filtrados = self._pacientes.copy()
        self.pacientesChanged.emit()
        self.busquedaCompletada.emit(len(self._pacientes_filtrados), "Filtros limpiados")
        print("🧹 Filtros de pacientes limpiados")
    
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
    
    # NUEVO: Filtros específicos
    @Slot(str)
    def filtrarPorApellido(self, apellido: str):
        """Filtra pacientes por apellido"""
        if not apellido.strip():
            self._pacientes_filtrados = self._pacientes.copy()
        else:
            self._filtro_apellido = apellido.strip().lower()
            self._pacientes_filtrados = [
                p for p in self._pacientes 
                if self._filtro_apellido in p.get('Apellido_Paterno', '').lower()
                or self._filtro_apellido in p.get('Apellido_Materno', '').lower()
            ]
        
        self.pacientesChanged.emit()
    
    @Slot(str)
    def filtrarPorCedula(self, cedula_parcial: str):
        """Filtra pacientes por cédula parcial"""
        if not cedula_parcial.strip():
            self._pacientes_filtrados = self._pacientes.copy()
        else:
            self._filtro_cedula = cedula_parcial.strip()
            self._pacientes_filtrados = [
                p for p in self._pacientes 
                if self._filtro_cedula in p.get('Cedula', '')
            ]
        
        self.pacientesChanged.emit()
    
    # ===============================
    # MÉTODOS PRIVADOS - SIN EDAD
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
            
            # Agregar nombre completo - SIN edad ni grupo etario
            for paciente in pacientes:
                paciente['nombre_completo'] = f"{paciente.get('Nombre', '')} {paciente.get('Apellido_Paterno', '')} {paciente.get('Apellido_Materno', '')}"
            
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
    
    def _set_loading(self, loading: bool):
        """Actualiza estado de carga"""
        if self._loading != loading:
            self._loading = loading
            self.loadingChanged.emit()

    def generic_emergency_disconnect(self, model_name: str):
        """Desconexión genérica para modelos sin timers complejos"""
        try:
            print(f"🚨 {model_name}: Iniciando desconexión de emergencia...")
            
            # Buscar y detener cualquier timer
            for attr_name in dir(self):
                if 'timer' in attr_name.lower() and not attr_name.startswith('__'):
                    try:
                        timer = getattr(self, attr_name)
                        if hasattr(timer, 'isActive') and hasattr(timer, 'stop') and timer.isActive():
                            timer.stop()
                            print(f"   ⏹️ {attr_name} detenido")
                    except:
                        pass
            
            # Establecer estado shutdown si existe
            if hasattr(self, '_loading'):
                self._loading = False
            if hasattr(self, '_estadoActual'):
                self._estadoActual = "shutdown"
            
            # Desconectar todas las señales posibles
            for attr_name in dir(self):
                if (not attr_name.startswith('__') and 
                    hasattr(getattr(self, attr_name), 'disconnect')):
                    try:
                        getattr(self, attr_name).disconnect()
                    except:
                        pass
            
            # Limpiar listas y diccionarios de datos
            for attr_name in dir(self):
                if not attr_name.startswith('__'):
                    try:
                        attr_value = getattr(self, attr_name)
                        if isinstance(attr_value, list) and attr_name.startswith('_'):
                            setattr(self, attr_name, [])
                        elif isinstance(attr_value, dict) and attr_name.startswith('_'):
                            setattr(self, attr_name, {})
                    except:
                        pass
            
            print(f"✅ {model_name}: Desconexión de emergencia completada")
            
        except Exception as e:
            print(f"❌ Error en desconexión {model_name}: {e}")
    def emergency_disconnect(self):
        """Desconexión de emergencia"""
        generic_emergency_disconnect(self, self.__class__.__name__)
# ===============================
# REGISTRO PARA QML
# ===============================

def register_paciente_model():
    """Registra el PacienteModel para uso en QML"""
    qmlRegisterType(PacienteModel, "ClinicaModels", 1, 0, "PacienteModel")
    print("🔗 PacienteModel registrado para QML - SIN campo Edad")

# Para facilitar la importación
__all__ = ['PacienteModel', 'register_paciente_model']