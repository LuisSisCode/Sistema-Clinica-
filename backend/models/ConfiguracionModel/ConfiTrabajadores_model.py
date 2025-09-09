from typing import List, Dict, Any, Optional
from PySide6.QtCore import QObject, Signal, Slot, Property
from PySide6.QtQml import qmlRegisterType

from ...repositories.ConfiguracionRepositor import ConfiTrabajadoresRepository
from ...core.excepciones import ExceptionHandler, ValidationError

class ConfiTrabajadoresModel(QObject):
    """
    Model QObject para gestión de configuración de tipos de trabajadores en QML
    Conecta la interfaz QML con el ConfiTrabajadoresRepository
    """
    
    # ===============================
    # SIGNALS - Notificaciones a QML
    # ===============================
    
    # Señales para cambios en datos
    tiposTrabajadoresChanged = Signal()
    estadisticasChanged = Signal()
    
    # Señales para operaciones
    tipoTrabajadorCreado = Signal(bool, str)  # success, message
    tipoTrabajadorActualizado = Signal(bool, str)
    tipoTrabajadorEliminado = Signal(bool, str)
    
    # Señales para búsquedas
    busquedaCompleta = Signal(bool, str, int)  # success, message, total
    
    # Señales para UI
    loadingChanged = Signal()
    errorOccurred = Signal(str, str)  # title, message
    successMessage = Signal(str)
    warningMessage = Signal(str)
    
    def __init__(self, parent=None):
        super().__init__(parent)
        
        # Repository
        self.repository = ConfiTrabajadoresRepository()
        
        # Estado interno
        self._tipos_trabajadores: List[Dict[str, Any]] = []
        self._tipos_trabajadores_filtrados: List[Dict[str, Any]] = []
        self._estadisticas: Dict[str, Any] = {}
        self._loading: bool = False
        
        # Filtros activos
        self._filtro_busqueda: str = ""
        
        # Configuración inicial
        self._cargar_datos_iniciales()
        
        print("👥 ConfiTrabajadoresModel inicializado")
    
    # ===============================
    # PROPERTIES - Datos para QML
    # ===============================
    
    @Property(list, notify=tiposTrabajadoresChanged)
    def tiposTrabajadores(self) -> List[Dict[str, Any]]:
        """Lista de tipos de trabajadores para mostrar en QML"""
        return self._tipos_trabajadores_filtrados
    
    @Property('QVariantMap', notify=estadisticasChanged)
    def estadisticas(self) -> Dict[str, Any]:
        """Estadísticas de tipos de trabajadores"""
        return self._estadisticas
    
    @Property(bool, notify=loadingChanged)
    def loading(self) -> bool:
        """Estado de carga"""
        return self._loading
    
    @Property(int, notify=tiposTrabajadoresChanged)
    def totalTiposTrabajadores(self) -> int:
        """Total de tipos de trabajadores filtrados"""
        return len(self._tipos_trabajadores_filtrados)
    
    @Property(str)
    def filtroBusqueda(self) -> str:
        """Texto de búsqueda actual"""
        return self._filtro_busqueda
    
    # ===============================
    # SLOTS - Métodos llamables desde QML
    # ===============================
    
    # --- OPERACIONES CRUD TIPOS DE TRABAJADORES ---
    
    @Slot(str, str, result=bool)
    def crearTipoTrabajador(self, tipo: str, descripcion: str = "") -> bool:
        """Crea nuevo tipo de trabajador desde QML"""
        try:
            self._set_loading(True)
            
            tipo_id = self.repository.create_tipo_trabajador(
                tipo=tipo.strip(),
                descripcion=descripcion.strip() if descripcion.strip() else None
            )
            
            if tipo_id:
                # Carga inmediata y forzada de datos
                self._cargar_tipos_trabajadores()
                self._cargar_estadisticas()
                
                # Forzar aplicación de filtros actuales
                self.aplicarFiltros(self._filtro_busqueda)
                
                mensaje = f"Tipo de trabajador creado exitosamente - ID: {tipo_id}"
                self.tipoTrabajadorCreado.emit(True, mensaje)
                self.successMessage.emit(mensaje)
                
                print(f"✅ Tipo de trabajador creado desde QML: {tipo}")
                print(f"🔄 Datos actualizados automáticamente - Total: {len(self._tipos_trabajadores)}")
                return True
            else:
                error_msg = "Error creando tipo de trabajador"
                self.tipoTrabajadorCreado.emit(False, error_msg)
                self.errorOccurred.emit("Error de validación", error_msg)
                return False
                
        except Exception as e:
            error_msg = f"Error inesperado: {str(e)}"
            self.tipoTrabajadorCreado.emit(False, error_msg)
            self.errorOccurred.emit("Error crítico", error_msg)
            return False
        finally:
            self._set_loading(False)

    @Slot()
    def refrescarDatosInmediato(self):
        """Método para refrescar datos inmediatamente desde QML"""
        try:
            print("🔄 Refrescando datos inmediatamente...")
            self._cargar_tipos_trabajadores()
            
            # Aplicar filtros actuales
            self.aplicarFiltros(self._filtro_busqueda)
            
            print(f"✅ Datos refrescados: {len(self._tipos_trabajadores)} tipos de trabajadores")
            
        except Exception as e:
            print(f"❌ Error refrescando datos: {e}")
            self.errorOccurred.emit("Error", f"Error refrescando datos: {str(e)}")
    
    @Slot(int, str, str, result=bool)
    def actualizarTipoTrabajador(self, tipo_id: int, tipo: str = "", 
                               descripcion: str = "") -> bool:
        """Actualiza tipo de trabajador existente desde QML"""
        try:
            self._set_loading(True)
            
            # Preparar argumentos solo con valores no vacíos
            kwargs = {}
            if tipo.strip():
                kwargs['tipo'] = tipo.strip()
            if descripcion.strip():
                kwargs['descripcion'] = descripcion.strip()
            elif descripcion == "":  # Si es cadena vacía explícita, establecer None
                kwargs['descripcion'] = None
            
            success = self.repository.update_tipo_trabajador(tipo_id, **kwargs)
            
            if success:
                self._cargar_tipos_trabajadores()
                
                mensaje = "Tipo de trabajador actualizado exitosamente"
                self.tipoTrabajadorActualizado.emit(True, mensaje)
                self.successMessage.emit(mensaje)
                
                print(f"✅ Tipo de trabajador actualizado desde QML: ID {tipo_id}")
                return True
            else:
                error_msg = "Error actualizando tipo de trabajador"
                self.tipoTrabajadorActualizado.emit(False, error_msg)
                self.errorOccurred.emit("Error de actualización", error_msg)
                return False
                
        except Exception as e:
            error_msg = f"Error inesperado: {str(e)}"
            self.tipoTrabajadorActualizado.emit(False, error_msg)
            self.errorOccurred.emit("Error crítico", error_msg)
            return False
        finally:
            self._set_loading(False)
    
    @Slot(int, result=bool)
    def eliminarTipoTrabajador(self, tipo_id: int) -> bool:
        """Elimina tipo de trabajador desde QML"""
        try:
            self._set_loading(True)
            
            success = self.repository.delete_tipo_trabajador(tipo_id)
            
            if success:
                self._cargar_tipos_trabajadores()
                self._cargar_estadisticas()
                
                mensaje = "Tipo de trabajador eliminado exitosamente"
                self.tipoTrabajadorEliminado.emit(True, mensaje)
                self.successMessage.emit(mensaje)
                
                print(f"🗑️ Tipo de trabajador eliminado desde QML: ID {tipo_id}")
                return True
            else:
                error_msg = "Error eliminando tipo de trabajador"
                self.tipoTrabajadorEliminado.emit(False, error_msg)
                self.errorOccurred.emit("Error de eliminación", error_msg)
                return False
                
        except Exception as e:
            error_msg = f"Error inesperado: {str(e)}"
            self.tipoTrabajadorEliminado.emit(False, error_msg)
            self.errorOccurred.emit("Error crítico", error_msg)
            return False
        finally:
            self._set_loading(False)
    
    # --- BÚSQUEDA Y FILTROS ---
    
    @Slot(str)
    def aplicarFiltros(self, buscar: str):
        """Aplica filtros a la lista de tipos de trabajadores"""
        try:
            self._filtro_busqueda = buscar.strip()
            
            # Filtrar datos locales
            tipos_filtrados = self._tipos_trabajadores.copy()
            
            # Filtro por búsqueda
            if buscar.strip():
                buscar_lower = buscar.lower()
                tipos_filtrados = [
                    t for t in tipos_filtrados
                    if (buscar_lower in t.get('Tipo', '').lower() or
                        buscar_lower in str(t.get('descripcion', '')).lower())
                ]
            
            self._tipos_trabajadores_filtrados = tipos_filtrados
            self.tiposTrabajadoresChanged.emit()
            
            total = len(tipos_filtrados)
            self.busquedaCompleta.emit(True, f"Encontrados {total} tipos de trabajadores", total)
            print(f"🔍 Filtros aplicados: {total} tipos de trabajadores")
                
        except Exception as e:
            self.errorOccurred.emit("Error en filtros", f"Error aplicando filtros: {str(e)}")
    
    @Slot(str, int, result=list)
    def buscarTiposTrabajadores(self, termino: str, limite: int = 50) -> List[Dict[str, Any]]:
        """Búsqueda rápida de tipos de trabajadores"""
        try:
            if not termino.strip():
                return self._tipos_trabajadores
            
            tipos_trabajadores = self.repository.search_tipos_trabajadores(termino.strip(), limite)
            print(f"🔍 Búsqueda '{termino}': {len(tipos_trabajadores)} resultados")
            return tipos_trabajadores
            
        except Exception as e:
            self.errorOccurred.emit("Error en búsqueda", f"Error buscando tipos de trabajadores: {str(e)}")
            return []
    
    @Slot()
    def limpiarFiltros(self):
        """Limpia todos los filtros aplicados"""
        self._filtro_busqueda = ""
        self._tipos_trabajadores_filtrados = self._tipos_trabajadores.copy()
        self.tiposTrabajadoresChanged.emit()
        print("🧹 Filtros limpiados")
    
    # --- CONSULTAS ESPECÍFICAS ---
    
    @Slot(int, result='QVariantMap')
    def obtenerTipoTrabajadorPorId(self, tipo_id: int) -> Dict[str, Any]:
        """Obtiene tipo de trabajador específico por ID"""
        try:
            tipo_trabajador = self.repository.get_tipo_trabajador_by_id(tipo_id)
            return tipo_trabajador if tipo_trabajador else {}
        except Exception as e:
            self.errorOccurred.emit("Error", f"Error obteniendo tipo de trabajador: {str(e)}")
            return {}
    
    # --- RECARGA DE DATOS ---
    
    @Slot()
    def recargarDatos(self):
        """Recarga todos los datos desde la base de datos"""
        try:
            self._set_loading(True)
            self._cargar_datos_iniciales()
            self.successMessage.emit("Datos recargados exitosamente")
            print("🔄 Datos de configuración de trabajadores recargados desde QML")
        except Exception as e:
            self.errorOccurred.emit("Error", f"Error recargando datos: {str(e)}")
        finally:
            self._set_loading(False)
    
    @Slot()
    def recargarTiposTrabajadores(self):
        """Recarga solo la lista de tipos de trabajadores"""
        try:
            self._cargar_tipos_trabajadores()
            print("🔄 Tipos de trabajadores recargados")
        except Exception as e:
            self.errorOccurred.emit("Error", f"Error recargando tipos de trabajadores: {str(e)}")
    
    # --- UTILIDADES ---
    
    @Slot(result=list)
    def obtenerTiposParaComboBox(self) -> List[Dict[str, Any]]:
        """Obtiene tipos de trabajadores formateados para ComboBox"""
        try:
            tipos_formateados = []
            
            # Agregar opción "Todos"
            tipos_formateados.append({
                'id': 0,
                'text': 'Todos los tipos',
                'data': {}
            })
            
            # Agregar tipos existentes
            for tipo in self._tipos_trabajadores:
                tipos_formateados.append({
                    'id': tipo.get('id', 0),
                    'text': tipo.get('Tipo', 'Sin nombre'),
                    'data': tipo
                })
            
            return tipos_formateados
            
        except Exception as e:
            self.errorOccurred.emit("Error", f"Error obteniendo tipos: {str(e)}")
            return [{'id': 0, 'text': 'Todos los tipos', 'data': {}}]
    
    @Slot(str, result=bool)
    def validarTipoUnico(self, tipo: str, tipo_id: int = 0) -> bool:
        """Valida que el tipo sea único"""
        try:
            if not tipo.strip():
                return False
            return not self.repository.tipo_trabajador_name_exists(tipo.strip(), exclude_id=tipo_id if tipo_id > 0 else None)
        except Exception as e:
            return False
    
    @Slot(result='QVariantMap')
    def obtenerEstadisticasCompletas(self) -> Dict[str, Any]:
        """Obtiene estadísticas completas del sistema"""
        try:
            return self.repository.get_tipos_trabajadores_statistics()
        except Exception as e:
            self.errorOccurred.emit("Error", f"Error obteniendo estadísticas: {str(e)}")
            return {}
    
    @Slot(result='QVariantMap')
    def obtenerResumenUso(self) -> Dict[str, Any]:
        """Obtiene resumen de uso de tipos de trabajadores"""
        try:
            return self.repository.get_tipos_trabajadores_summary()
        except Exception as e:
            self.errorOccurred.emit("Error", f"Error obteniendo resumen: {str(e)}")
            return {}
        
    @Slot(int, result=int)
    def obtenerTrabajadoresAsociados(self, tipo_id: int) -> int:
        """Obtiene cantidad de trabajadores asociados a un tipo"""
        try:
            return self.repository.count_trabajadores_asociados(tipo_id)
        except Exception as e:
            self.errorOccurred.emit("Error", f"Error obteniendo trabajadores asociados: {str(e)}")
            return 0
    
    # ===============================
    # MÉTODOS PRIVADOS
    # ===============================
    
    def _cargar_datos_iniciales(self):
        """Carga todos los datos necesarios al inicializar"""
        try:
            self._cargar_tipos_trabajadores()
            self._cargar_estadisticas()
            print("📊 Datos iniciales de configuración de trabajadores cargados")
        except Exception as e:
            print(f"❌ Error cargando datos iniciales de configuración de trabajadores: {e}")
            self.errorOccurred.emit("Error inicial", f"Error cargando datos: {str(e)}")
    
    def _cargar_tipos_trabajadores(self):
        """Carga lista de tipos de trabajadores desde el repository"""
        try:
            tipos_trabajadores = self.repository.get_all_tipos_trabajadores()
            
            # Procesar datos adicionales
            for tipo in tipos_trabajadores:
                if not tipo.get('descripcion'):
                    tipo['descripcion'] = 'Sin descripción'
            
            self._tipos_trabajadores = tipos_trabajadores
            self._tipos_trabajadores_filtrados = tipos_trabajadores.copy()
            self.tiposTrabajadoresChanged.emit()
            print(f"👥 Tipos de trabajadores cargados: {len(tipos_trabajadores)}")
                
        except Exception as e:
            print(f"❌ Error cargando tipos de trabajadores: {e}")
            self._tipos_trabajadores = []
            self._tipos_trabajadores_filtrados = []
            raise e
    
    def _cargar_estadisticas(self):
        """Carga estadísticas desde el repository"""
        try:
            estadisticas = self.repository.get_tipos_trabajadores_statistics()
            self._estadisticas = estadisticas
            self.estadisticasChanged.emit()
            print("📈 Estadísticas de tipos de trabajadores cargadas")
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

def register_confi_trabajadores_model():
    """Registra el ConfiTrabajadoresModel para uso en QML"""
    qmlRegisterType(ConfiTrabajadoresModel, "ClinicaModels", 1, 0, "ConfiTrabajadoresModel")
    print("🔗 ConfiTrabajadoresModel registrado para QML")

# Para facilitar la importación
__all__ = ['ConfiTrabajadoresModel', 'register_confi_trabajadores_model']