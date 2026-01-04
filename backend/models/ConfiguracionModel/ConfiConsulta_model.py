from typing import List, Dict, Any, Optional
from PySide6.QtCore import QObject, Signal, Slot, Property
from PySide6.QtQml import qmlRegisterType

from ...repositories.ConfiguracionRepositor import ConfiConsultaRepository
from ...core.excepciones import ExceptionHandler, ValidationError
from ...core.Signals_manager import get_global_signals

class ConfiConsultaModel(QObject):
    """
    Model QObject para gestión de configuración de especialidades/consultas en QML
    Conecta la interfaz QML con el ConfiConsultaRepository
    """
    
    # ===============================
    # SIGNALS - Notificaciones a QML
    # ===============================
    
    # Señales para cambios en datos
    especialidadesChanged = Signal()
    estadisticasChanged = Signal()
    
    # Señales para operaciones
    especialidadCreada = Signal(bool, str)  # success, message
    especialidadActualizada = Signal(bool, str)
    especialidadEliminada = Signal(bool, str)
    
    # Señales para búsquedas
    busquedaCompleta = Signal(bool, str, int)  # success, message, total
    
    # Señales para UI
    loadingChanged = Signal()
    errorOccurred = Signal(str, str)  # title, message
    successMessage = Signal(str)
    warningMessage = Signal(str)
    
    def __init__(self, parent=None):
        super().__init__(parent)
        self.global_signals = get_global_signals()
        # Repository
        self.repository = ConfiConsultaRepository()
        
        # Estado interno
        self._especialidades: List[Dict[str, Any]] = []
        self._especialidades_filtradas: List[Dict[str, Any]] = []
        self._estadisticas: Dict[str, Any] = {}
        self._loading: bool = False
        
        # Filtros activos
        self._filtro_busqueda: str = ""
        
        # Configuración inicial
        self._cargar_datos_iniciales()
        
        print("🏥 ConfiConsultaModel inicializado")
    
    # ===============================
    # PROPERTIES - Datos para QML
    # ===============================
    
    @Property(list, notify=especialidadesChanged)
    def especialidades(self) -> List[Dict[str, Any]]:
        """Lista de especialidades para mostrar en QML"""
        return self._especialidades_filtradas
    
    @Property('QVariantMap', notify=estadisticasChanged)
    def estadisticas(self) -> Dict[str, Any]:
        """Estadísticas de especialidades"""
        return self._estadisticas
    
    @Property(bool, notify=loadingChanged)
    def loading(self) -> bool:
        """Estado de carga"""
        return self._loading
    
    @Property(int, notify=especialidadesChanged)
    def totalEspecialidades(self) -> int:
        """Total de especialidades filtradas"""
        return len(self._especialidades_filtradas)
    
    @Property(str)
    def filtroBusqueda(self) -> str:
        """Texto de búsqueda actual"""
        return self._filtro_busqueda
    
    # ===============================
    # SLOTS - Métodos llamables desde QML
    # ===============================
    
    # --- OPERACIONES CRUD ESPECIALIDADES ---
    
    @Slot(str, str, float, float, result=bool)
    def crearEspecialidad(self, nombre: str, detalles: str = "", 
                         precio_normal: float = 0.0, precio_emergencia: float = 0.0) -> bool:
        """Crea nueva especialidad desde QML (SIN asignación de médico)"""
        try:
            self._set_loading(True)
            
            especialidad_id = self.repository.create_especialidad(
                nombre=nombre.strip(),
                detalles=detalles.strip() if detalles.strip() else None,
                precio_normal=precio_normal,
                precio_emergencia=precio_emergencia
            )
            
            if especialidad_id:
                # Carga inmediata y forzada de datos
                self._cargar_especialidades()
                self._cargar_estadisticas()
                
                # Forzar aplicación de filtros actuales
                self.aplicarFiltros(self._filtro_busqueda)
                
                mensaje = f"Especialidad creada exitosamente - ID: {especialidad_id}"
                self.especialidadCreada.emit(True, mensaje)
                self.successMessage.emit(mensaje)
                self.global_signals.notificar_cambio_especialidades("creado", especialidad_id, nombre.strip())
                print(f"✅ Especialidad creada desde QML: {nombre}")
                print(f"📄 Datos actualizados automáticamente - Total: {len(self._especialidades)}")
                return True
            else:
                error_msg = "Error creando especialidad"
                self.especialidadCreada.emit(False, error_msg)
                self.errorOccurred.emit("Error de validación", error_msg)
                return False
                
        except Exception as e:
            error_msg = f"Error inesperado: {str(e)}"
            self.especialidadCreada.emit(False, error_msg)
            self.errorOccurred.emit("Error crítico", error_msg)
            print(f"❌ Error creando especialidad: {e}")
            return False
        finally:
            self._set_loading(False)

    @Slot()
    def refrescarDatosInmediato(self):
        """Método para refrescar datos inmediatamente desde QML"""
        try:
            print("🔄 Refrescando datos inmediatamente...")
            self._cargar_especialidades()
            
            # Aplicar filtros actuales
            self.aplicarFiltros(self._filtro_busqueda)
            
            print(f"✅ Datos refrescados: {len(self._especialidades)} especialidades")
            
        except Exception as e:
            print(f"❌ Error refrescando datos: {e}")
            self.errorOccurred.emit("Error Consultas", f"Error refrescando datos: {str(e)}")
    
    @Slot(int, str, str, float, float, result=bool)
    def actualizarEspecialidad(self, especialidad_id: int, nombre: str = "", 
                              detalles: str = "", precio_normal: float = -1,
                              precio_emergencia: float = -1) -> bool:
        """Actualiza especialidad existente desde QML (SIN asignación de médico)"""
        try:
            self._set_loading(True)
            
            # Preparar argumentos solo con valores válidos
            kwargs = {}
            if nombre.strip():
                kwargs['nombre'] = nombre.strip()
            if detalles.strip():
                kwargs['detalles'] = detalles.strip()
            elif detalles == "":  # Si es cadena vacía explícita, establecer None
                kwargs['detalles'] = None
            if precio_normal >= 0:
                kwargs['precio_normal'] = precio_normal
            if precio_emergencia >= 0:
                kwargs['precio_emergencia'] = precio_emergencia
            
            success = self.repository.update_especialidad(especialidad_id, **kwargs)
            
            if success:
                self._cargar_especialidades()
                
                mensaje = "Especialidad actualizada exitosamente"
                self.especialidadActualizada.emit(True, mensaje)
                self.successMessage.emit(mensaje)
                self.global_signals.notificar_cambio_especialidades("actualizado", especialidad_id, nombre.strip() if nombre.strip() else "")
                print(f"✅ Especialidad actualizada desde QML: ID {especialidad_id}")
                return True
            else:
                error_msg = "Error actualizando especialidad"
                self.especialidadActualizada.emit(False, error_msg)
                self.errorOccurred.emit("Error de actualización", error_msg)
                return False
                
        except Exception as e:
            error_msg = f"Error inesperado: {str(e)}"
            self.especialidadActualizada.emit(False, error_msg)
            self.errorOccurred.emit("Error crítico", error_msg)
            print(f"❌ Error actualizando especialidad: {e}")
            return False
        finally:
            self._set_loading(False)
    
    @Slot(int, result=bool)
    def eliminarEspecialidad(self, especialidad_id: int) -> bool:
        """Elimina especialidad desde QML"""
        try:
            self._set_loading(True)
            
            success = self.repository.delete_especialidad(especialidad_id)
            
            if success:
                self._cargar_especialidades()
                self._cargar_estadisticas()
                
                mensaje = "Especialidad eliminada exitosamente"
                self.especialidadEliminada.emit(True, mensaje)
                self.successMessage.emit(mensaje)
                self.global_signals.notificar_cambio_especialidades("eliminado", especialidad_id, "")
                print(f"🗑️ Especialidad eliminada desde QML: ID {especialidad_id}")
                return True
            else:
                error_msg = "Error eliminando especialidad"
                self.especialidadEliminada.emit(False, error_msg)
                self.errorOccurred.emit("Error de eliminación", error_msg)
                return False
                
        except Exception as e:
            error_msg = f"Error inesperado: {str(e)}"
            self.especialidadEliminada.emit(False, error_msg)
            self.errorOccurred.emit("Error crítico", error_msg)
            print(f"❌ Error eliminando especialidad: {e}")
            return False
        finally:
            self._set_loading(False)
    
    # --- BÚSQUEDA Y FILTROS ---
    
    @Slot(str)
    def aplicarFiltros(self, buscar: str):
        """Aplica filtros a la lista de especialidades"""
        try:
            self._filtro_busqueda = buscar.strip()
            
            # Filtrar datos locales
            especialidades_filtradas = self._especialidades.copy()
            
            # Filtro por búsqueda
            if buscar.strip():
                buscar_lower = buscar.lower()
                especialidades_filtradas = [
                    e for e in especialidades_filtradas
                    if (buscar_lower in e.get('Nombre', '').lower() or
                        buscar_lower in str(e.get('Detalles', '')).lower())
                ]
            
            self._especialidades_filtradas = especialidades_filtradas
            self.especialidadesChanged.emit()
            
            total = len(especialidades_filtradas)
            self.busquedaCompleta.emit(True, f"Encontradas {total} especialidades", total)
            print(f"🔍 Filtros aplicados: {total} especialidades")
                
        except Exception as e:
            self.errorOccurred.emit("Error en filtros", f"Error aplicando filtros: {str(e)}")
    
    @Slot(str, int, result=list)
    def buscarEspecialidades(self, termino: str, limite: int = 50) -> List[Dict[str, Any]]:
        """Búsqueda rápida de especialidades"""
        try:
            if not termino.strip():
                return self._especialidades
            
            especialidades = self.repository.search_especialidades(termino.strip(), limite)
            print(f"🔍 Búsqueda '{termino}': {len(especialidades)} resultados")
            return especialidades
            
        except Exception as e:
            self.errorOccurred.emit("Error en búsqueda", f"Error buscando especialidades: {str(e)}")
            return []
    
    @Slot()
    def limpiarFiltros(self):
        """Limpia todos los filtros aplicados"""
        self._filtro_busqueda = ""
        self._especialidades_filtradas = self._especialidades.copy()
        self.especialidadesChanged.emit()
        print("🧹 Filtros limpiados")
    
    # --- CONSULTAS ESPECÍFICAS ---
    
    @Slot(int, result='QVariantMap')
    def obtenerEspecialidadPorId(self, especialidad_id: int) -> Dict[str, Any]:
        """Obtiene especialidad específica por ID"""
        try:
            especialidad = self.repository.get_especialidad_by_id(especialidad_id)
            return especialidad if especialidad else {}
        except Exception as e:
            self.errorOccurred.emit("Error Consultas", f"Error obteniendo especialidad: {str(e)}")
            return {}
    
    @Slot(float, float, result=list)
    def obtenerEspecialidadesPorRangoPrecios(self, precio_min: float, precio_max: float) -> List[Dict[str, Any]]:
        """Obtiene especialidades por rango de precios"""
        try:
            return self.repository.get_especialidades_por_rango_precios(precio_min, precio_max)
        except Exception as e:
            self.errorOccurred.emit("Error Consultas", f"Error obteniendo especialidades por precio: {str(e)}")
            return []
    
    # --- RECARGA DE DATOS ---
    
    @Slot()
    def recargarDatos(self):
        """Recarga todos los datos desde la base de datos"""
        try:
            self._set_loading(True)
            self._cargar_datos_iniciales()
            self.successMessage.emit("Datos recargados exitosamente")
            print("🔄 Datos de especialidades recargados desde QML")
        except Exception as e:
            self.errorOccurred.emit("Error Consultas", f"Error recargando datos: {str(e)}")
        finally:
            self._set_loading(False)
    
    @Slot()
    def recargarEspecialidades(self):
        """Recarga solo la lista de especialidades"""
        try:
            self._cargar_especialidades()
            print("🔄 Especialidades recargadas")
        except Exception as e:
            self.errorOccurred.emit("Error Consultas", f"Error recargando especialidades: {str(e)}")
    
    # --- UTILIDADES ---
    
    @Slot(result=list)
    def obtenerEspecialidadesParaComboBox(self) -> List[Dict[str, Any]]:
        """Obtiene especialidades formateadas para ComboBox"""
        try:
            especialidades_formateadas = []
            
            # Agregar opción "Todas"
            especialidades_formateadas.append({
                'id': 0,
                'text': 'Todas las especialidades',
                'data': {}
            })
            
            # Agregar especialidades existentes
            for especialidad in self._especialidades:
                especialidades_formateadas.append({
                    'id': especialidad.get('id', 0),
                    'text': especialidad.get('Nombre', 'Sin nombre'),
                    'data': especialidad
                })
            
            return especialidades_formateadas
            
        except Exception as e:
            self.errorOccurred.emit("Error Consultas", f"Error obteniendo especialidades: {str(e)}")
            return [{'id': 0, 'text': 'Todas las especialidades', 'data': {}}]
    
    @Slot(str, int, result=bool)
    def validarNombreUnico(self, nombre: str, especialidad_id: int = 0) -> bool:
        """Valida que el nombre sea único"""
        try:
            if not nombre.strip():
                return False
            return not self.repository.especialidad_name_exists(nombre.strip(), exclude_id=especialidad_id if especialidad_id > 0 else None)
        except Exception as e:
            return False
    
    @Slot(result='QVariantMap')
    def obtenerEstadisticasCompletas(self) -> Dict[str, Any]:
        """Obtiene estadísticas completas del sistema"""
        try:
            return self.repository.get_especialidades_statistics()
        except Exception as e:
            self.errorOccurred.emit("Error Consultas", f"Error obteniendo estadísticas: {str(e)}")
            return {}
    
    @Slot(result='QVariantMap')
    def obtenerResumenUso(self) -> Dict[str, Any]:
        """Obtiene resumen de uso de especialidades"""
        try:
            return self.repository.get_especialidades_summary()
        except Exception as e:
            self.errorOccurred.emit("Error Consultas", f"Error obteniendo resumen: {str(e)}")
            return {}
        
    @Slot(int, result=int)
    def obtenerConsultasAsociadas(self, especialidad_id: int) -> int:
        """Obtiene cantidad de consultas asociadas a una especialidad"""
        try:
            return self.repository.count_consultas_asociadas(especialidad_id)
        except Exception as e:
            self.errorOccurred.emit("Error Consultas", f"Error obteniendo consultas asociadas: {str(e)}")
            return 0
    
    # ===============================
    # MÉTODOS PRIVADOS
    # ===============================
    
    def _cargar_datos_iniciales(self):
        """Carga todos los datos necesarios al inicializar"""
        try:
            self._cargar_especialidades()
            self._cargar_estadisticas()
            print("📊 Datos iniciales de especialidades cargados")
        except Exception as e:
            print(f"❌ Error cargando datos iniciales de especialidades: {e}")
            self.errorOccurred.emit("Error inicial", f"Error cargando datos: {str(e)}")
    
    def _cargar_especialidades(self):
        """Carga lista de especialidades desde el repository"""
        try:
            especialidades = self.repository.get_all_especialidades()
            
            # Procesar datos adicionales
            for especialidad in especialidades:
                if not especialidad.get('Detalles'):
                    especialidad['Detalles'] = 'Sin detalles'
            
            self._especialidades = especialidades
            self._especialidades_filtradas = especialidades.copy()
            self.especialidadesChanged.emit()
            print(f"🏥 Especialidades cargadas: {len(especialidades)}")
                
        except Exception as e:
            print(f"❌ Error cargando especialidades: {e}")
            self._especialidades = []
            self._especialidades_filtradas = []
            raise e
    
    def _cargar_estadisticas(self):
        """Carga estadísticas desde el repository"""
        try:
            estadisticas = self.repository.get_especialidades_statistics()
            self._estadisticas = estadisticas
            self.estadisticasChanged.emit()
            print("📈 Estadísticas de especialidades cargadas")
        except Exception as e:
            print(f"❌ Error cargando estadísticas: {e}")
            # No es crítico, continuar sin estadísticas
            self._estadisticas = {}
    
    def _set_loading(self, loading: bool):
        """Actualiza estado de carga"""
        if self._loading != loading:
            self._loading = loading
            self.loadingChanged.emit()

# ===============================
# REGISTRO PARA QML
# ===============================

def register_confi_consulta_model():
    """Registra el ConfiConsultaModel para uso en QML"""
    qmlRegisterType(ConfiConsultaModel, "ClinicaModels", 1, 0, "ConfiConsultaModel")
    print("🔗 ConfiConsultaModel registrado para QML")

# Para facilitar la importación
__all__ = ['ConfiConsultaModel', 'register_confi_consulta_model']