from typing import List, Dict, Any, Optional
from PySide6.QtCore import QObject, Signal, Slot, Property
from PySide6.QtQml import qmlRegisterType

from ...repositories.ConfiguracionRepositor import ConfiguracionRepository
from ...core.excepciones import ExceptionHandler, ValidationError
from ...core.Signals_manager import get_global_signals
class ConfiguracionModel(QObject):
    """
    Model QObject para gestión de configuración de tipos de gastos en QML
    Conecta la interfaz QML con el ConfiguracionRepository
    """
    
    # ===============================
    # SIGNALS - Notificaciones a QML
    # ===============================
    
    # Señales para cambios en datos
    tiposGastosChanged = Signal()
    estadisticasChanged = Signal()
    
    # Señales para operaciones
    tipoGastoCreado = Signal(bool, str)  # success, message
    tipoGastoActualizado = Signal(bool, str)
    tipoGastoEliminado = Signal(bool, str)
    
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
        self.repository = ConfiguracionRepository()
        
        # Estado interno
        self._tipos_gastos: List[Dict[str, Any]] = []
        self._tipos_gastos_filtrados: List[Dict[str, Any]] = []
        self._estadisticas: Dict[str, Any] = {}
        self._loading: bool = False
        
        # Filtros activos
        self._filtro_busqueda: str = ""
        
        # Configuración inicial
        self._cargar_datos_iniciales()
        
        print("💰 ConfiguracionModel inicializado")
    
    # ===============================
    # PROPERTIES - Datos para QML
    # ===============================
    
    @Property(list, notify=tiposGastosChanged)
    def tiposGastos(self) -> List[Dict[str, Any]]:
        """Lista de tipos de gastos para mostrar en QML"""
        return self._tipos_gastos_filtrados
    
    @Property('QVariantMap', notify=estadisticasChanged)
    def estadisticas(self) -> Dict[str, Any]:
        """Estadísticas de tipos de gastos"""
        return self._estadisticas
    
    @Property(bool, notify=loadingChanged)
    def loading(self) -> bool:
        """Estado de carga"""
        return self._loading
    
    @Property(int, notify=tiposGastosChanged)
    def totalTiposGastos(self) -> int:
        """Total de tipos de gastos filtrados"""
        return len(self._tipos_gastos_filtrados)
    
    @Property(str)
    def filtroBusqueda(self) -> str:
        """Texto de búsqueda actual"""
        return self._filtro_busqueda
    
    # ===============================
    # SLOTS - Métodos llamables desde QML
    # ===============================
    
    # --- OPERACIONES CRUD TIPOS DE GASTOS ---
    
    @Slot(str, str, result=bool)
    def crearTipoGasto(self, nombre: str, descripcion: str = "") -> bool:
        """Crea nuevo tipo de gasto desde QML"""
        try:
            self._set_loading(True)
            
            tipo_id = self.repository.create_tipo_gasto(
                nombre=nombre.strip(),
                descripcion=descripcion.strip() if descripcion.strip() else None
            )
            
            if tipo_id:
                # Carga inmediata y forzada de datos
                self._cargar_tipos_gastos()
                self._cargar_estadisticas()
                
                # Forzar aplicación de filtros actuales
                self.aplicarFiltros(self._filtro_busqueda)
                
                mensaje = f"Tipo de gasto creado exitosamente - ID: {tipo_id}"
                self.tipoGastoCreado.emit(True, mensaje)
                self.successMessage.emit(mensaje)
                self.global_signals.notificar_cambio_tipos_gastos("creado", tipo_id, nombre.strip())
                if hasattr(self, 'repository') and hasattr(self.repository, 'invalidate_all_caches'):
                    self.repository.invalidate_all_caches()
                print(f"✅ Tipo de gasto creado desde QML: {nombre}")
                print(f"🔄 Datos actualizados automáticamente - Total: {len(self._tipos_gastos)}")
                return True
            else:
                error_msg = "Error creando tipo de gasto"
                self.tipoGastoCreado.emit(False, error_msg)
                self.errorOccurred.emit("Error de validación", error_msg)
                return False
                
        except Exception as e:
            error_msg = f"Error inesperado: {str(e)}"
            self.tipoGastoCreado.emit(False, error_msg)
            self.errorOccurred.emit("Error crítico", error_msg)
            return False
        finally:
            self._set_loading(False)

    @Slot()
    def refrescarDatosInmediato(self):
        """Método para refrescar datos inmediatamente desde QML"""
        try:
            print("🔄 Refrescando datos inmediatamente...")
            self._cargar_tipos_gastos()
            
            # Aplicar filtros actuales
            self.aplicarFiltros(self._filtro_busqueda)
            
            print(f"✅ Datos refrescados: {len(self._tipos_gastos)} tipos de gastos")
            
        except Exception as e:
            print(f"❌ Error refrescando datos: {e}")
            self.errorOccurred.emit("Error", f"Error refrescando datos: {str(e)}")
    
    @Slot(int, str, str, result=bool)
    def actualizarTipoGasto(self, tipo_id: int, nombre: str = "", 
                           descripcion: str = "") -> bool:
        """Actualiza tipo de gasto existente desde QML"""
        try:
            self._set_loading(True)
            
            # Preparar argumentos solo con valores no vacíos
            kwargs = {}
            if nombre.strip():
                kwargs['nombre'] = nombre.strip()
            if descripcion.strip():
                kwargs['descripcion'] = descripcion.strip()
            elif descripcion == "":  # Si es cadena vacía explícita, establecer None
                kwargs['descripcion'] = None
            
            success = self.repository.update_tipo_gasto(tipo_id, **kwargs)
            
            if success:
                self._cargar_tipos_gastos()
                
                mensaje = "Tipo de gasto actualizado exitosamente"
                self.tipoGastoActualizado.emit(True, mensaje)
                self.successMessage.emit(mensaje)
                self.global_signals.notificar_cambio_tipos_gastos("actualizado", tipo_id, nombre.strip() if nombre.strip() else "")
                print(f"✅ Tipo de gasto actualizado desde QML: ID {tipo_id}")
                return True
            else:
                error_msg = "Error actualizando tipo de gasto"
                self.tipoGastoActualizado.emit(False, error_msg)
                self.errorOccurred.emit("Error de actualización", error_msg)
                return False
                
        except Exception as e:
            error_msg = f"Error inesperado: {str(e)}"
            self.tipoGastoActualizado.emit(False, error_msg)
            self.errorOccurred.emit("Error crítico", error_msg)
            return False
        finally:
            self._set_loading(False)
    
    @Slot(int, result=bool)
    def eliminarTipoGasto(self, tipo_id: int) -> bool:
        """Elimina tipo de gasto desde QML"""
        try:
            self._set_loading(True)
            
            success = self.repository.delete_tipo_gasto(tipo_id)
            
            if success:
                self._cargar_tipos_gastos()
                self._cargar_estadisticas()
                
                mensaje = "Tipo de gasto eliminado exitosamente"
                self.tipoGastoEliminado.emit(True, mensaje)
                self.successMessage.emit(mensaje)
                self.global_signals.notificar_cambio_tipos_gastos("eliminado", tipo_id, "")
                print(f"🗑️ Tipo de gasto eliminado desde QML: ID {tipo_id}")
                return True
            else:
                error_msg = "Error eliminando tipo de gasto"
                self.tipoGastoEliminado.emit(False, error_msg)
                self.errorOccurred.emit("Error de eliminación", error_msg)
                return False
                
        except Exception as e:
            error_msg = f"Error inesperado: {str(e)}"
            self.tipoGastoEliminado.emit(False, error_msg)
            self.errorOccurred.emit("Error crítico", error_msg)
            return False
        finally:
            self._set_loading(False)
    
    # --- BÚSQUEDA Y FILTROS ---
    
    @Slot(str)
    def aplicarFiltros(self, buscar: str):
        """Aplica filtros a la lista de tipos de gastos"""
        try:
            self._filtro_busqueda = buscar.strip()
            
            # Filtrar datos locales
            tipos_filtrados = self._tipos_gastos.copy()
            
            # Filtro por búsqueda
            if buscar.strip():
                buscar_lower = buscar.lower()
                tipos_filtrados = [
                    t for t in tipos_filtrados
                    if (buscar_lower in t.get('Nombre', '').lower() or
                        buscar_lower in str(t.get('descripcion', '')).lower())
                ]
            
            self._tipos_gastos_filtrados = tipos_filtrados
            self.tiposGastosChanged.emit()
            
            total = len(tipos_filtrados)
            self.busquedaCompleta.emit(True, f"Encontrados {total} tipos de gastos", total)
            print(f"🔍 Filtros aplicados: {total} tipos de gastos")
                
        except Exception as e:
            self.errorOccurred.emit("Error en filtros", f"Error aplicando filtros: {str(e)}")
    
    @Slot(str, int, result=list)
    def buscarTiposGastos(self, termino: str, limite: int = 50) -> List[Dict[str, Any]]:
        """Búsqueda rápida de tipos de gastos"""
        try:
            if not termino.strip():
                return self._tipos_gastos
            
            tipos_gastos = self.repository.search_tipos_gastos(termino.strip(), limite)
            print(f"🔍 Búsqueda '{termino}': {len(tipos_gastos)} resultados")
            return tipos_gastos
            
        except Exception as e:
            self.errorOccurred.emit("Error en búsqueda", f"Error buscando tipos de gastos: {str(e)}")
            return []
    
    @Slot()
    def limpiarFiltros(self):
        """Limpia todos los filtros aplicados"""
        self._filtro_busqueda = ""
        self._tipos_gastos_filtrados = self._tipos_gastos.copy()
        self.tiposGastosChanged.emit()
        print("🧹 Filtros limpiados")
    
    # --- CONSULTAS ESPECÍFICAS ---
    
    @Slot(int, result='QVariantMap')
    def obtenerTipoGastoPorId(self, tipo_id: int) -> Dict[str, Any]:
        """Obtiene tipo de gasto específico por ID"""
        try:
            tipo_gasto = self.repository.get_tipo_gasto_by_id(tipo_id)
            return tipo_gasto if tipo_gasto else {}
        except Exception as e:
            self.errorOccurred.emit("Error", f"Error obteniendo tipo de gasto: {str(e)}")
            return {}
    
    # --- RECARGA DE DATOS ---
    
    @Slot()
    def recargarDatos(self):
        """Recarga todos los datos desde la base de datos"""
        try:
            self._set_loading(True)
            self._cargar_datos_iniciales()
            self.successMessage.emit("Datos recargados exitosamente")
            print("🔄 Datos de configuración recargados desde QML")
        except Exception as e:
            self.errorOccurred.emit("Error", f"Error recargando datos: {str(e)}")
        finally:
            self._set_loading(False)
    
    @Slot()
    def recargarTiposGastos(self):
        """Recarga solo la lista de tipos de gastos"""
        try:
            self._cargar_tipos_gastos()
            print("🔄 Tipos de gastos recargados")
        except Exception as e:
            self.errorOccurred.emit("Error", f"Error recargando tipos de gastos: {str(e)}")
    
    # --- UTILIDADES ---
    
    @Slot(result=list)
    def obtenerTiposParaComboBox(self) -> List[Dict[str, Any]]:
        """Obtiene tipos de gastos formateados para ComboBox"""
        try:
            tipos_formateados = []
            
            # Agregar opción "Todos"
            tipos_formateados.append({
                'id': 0,
                'text': 'Todos los tipos',
                'data': {}
            })
            
            # Agregar tipos existentes
            for tipo in self._tipos_gastos:
                tipos_formateados.append({
                    'id': tipo.get('id', 0),
                    'text': tipo.get('Nombre', 'Sin nombre'),
                    'data': tipo
                })
            
            return tipos_formateados
            
        except Exception as e:
            self.errorOccurred.emit("Error", f"Error obteniendo tipos: {str(e)}")
            return [{'id': 0, 'text': 'Todos los tipos', 'data': {}}]
    
    @Slot(str, result=bool)
    def validarNombreUnico(self, nombre: str, tipo_id: int = 0) -> bool:
        """Valida que el nombre sea único"""
        try:
            if not nombre.strip():
                return False
            return not self.repository.tipo_gasto_name_exists(nombre.strip(), exclude_id=tipo_id if tipo_id > 0 else None)
        except Exception as e:
            return False
    
    @Slot(result='QVariantMap')
    def obtenerEstadisticasCompletas(self) -> Dict[str, Any]:
        """Obtiene estadísticas completas del sistema"""
        try:
            return self.repository.get_tipos_gastos_statistics()
        except Exception as e:
            self.errorOccurred.emit("Error", f"Error obteniendo estadísticas: {str(e)}")
            return {}
    
    @Slot(result='QVariantMap')
    def obtenerResumenUso(self) -> Dict[str, Any]:
        """Obtiene resumen de uso de tipos de gastos"""
        try:
            return self.repository.get_tipo_gastos_summary()
        except Exception as e:
            self.errorOccurred.emit("Error", f"Error obteniendo resumen: {str(e)}")
            return {}
        
    @Slot(int, result=int)
    def obtenerGastosAsociados(self, tipo_id: int) -> int:
        """Obtiene cantidad de gastos asociados a un tipo"""
        try:
            return self.repository.count_gastos_asociados(tipo_id)
        except Exception as e:
            self.errorOccurred.emit("Error", f"Error obteniendo gastos asociados: {str(e)}")
            return 0
    # ===============================
    # MÉTODOS PRIVADOS
    # ===============================
    
    def _cargar_datos_iniciales(self):
        """Carga todos los datos necesarios al inicializar"""
        try:
            self._cargar_tipos_gastos()
            self._cargar_estadisticas()
            print("📊 Datos iniciales de configuración cargados")
        except Exception as e:
            print(f"❌ Error cargando datos iniciales de configuración: {e}")
            self.errorOccurred.emit("Error inicial", f"Error cargando datos: {str(e)}")
    
    def _cargar_tipos_gastos(self):
        """Carga lista de tipos de gastos desde el repository"""
        try:
            tipos_gastos = self.repository.get_all_tipos_gastos()
            
            # Procesar datos adicionales
            for tipo in tipos_gastos:
                if not tipo.get('descripcion'):
                    tipo['descripcion'] = 'Sin descripción'
            
            self._tipos_gastos = tipos_gastos
            self._tipos_gastos_filtrados = tipos_gastos.copy()
            self.tiposGastosChanged.emit()
            print(f"💰 Tipos de gastos cargados: {len(tipos_gastos)}")
                
        except Exception as e:
            print(f"❌ Error cargando tipos de gastos: {e}")
            self._tipos_gastos = []
            self._tipos_gastos_filtrados = []
            raise e
    
    def _cargar_estadisticas(self):
        """Carga estadísticas desde el repository"""
        try:
            estadisticas = self.repository.get_tipos_gastos_statistics()
            self._estadisticas = estadisticas
            self.estadisticasChanged.emit()
            print("📈 Estadísticas de tipos de gastos cargadas")
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

def register_configuracion_model():
    """Registra el ConfiguracionModel para uso en QML"""
    qmlRegisterType(ConfiguracionModel, "ClinicaModels", 1, 0, "ConfiguracionModel")
    print("🔗 ConfiguracionModel registrado para QML")

# Para facilitar la importación
__all__ = ['ConfiguracionModel', 'register_configuracion_model']