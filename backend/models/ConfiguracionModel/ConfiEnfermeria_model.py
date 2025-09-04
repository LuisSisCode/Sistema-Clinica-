from typing import List, Dict, Any, Optional
from PySide6.QtCore import QObject, Signal, Slot, Property
from PySide6.QtQml import qmlRegisterType

from ...repositories.ConfiguracionRepositor import ConfiEnfermeriaRepository
from ...core.excepciones import ExceptionHandler, ValidationError

class ConfiEnfermeriaModel(QObject):
    """
    Model QObject para gestión de configuración de tipos de procedimientos de enfermería en QML
    Conecta la interfaz QML con el ConfiEnfermeriaRepository
    """
    
    # ===============================
    # SIGNALS - Notificaciones a QML
    # ===============================
    
    # Señales para cambios en datos
    tiposProcedimientosChanged = Signal()
    estadisticasChanged = Signal()
    
    # Señales para operaciones
    tipoProcedimientoCreado = Signal(bool, str)  # success, message
    tipoProcedimientoActualizado = Signal(bool, str)
    tipoProcedimientoEliminado = Signal(bool, str)
    
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
        self.repository = ConfiEnfermeriaRepository()
        
        # Estado interno
        self._tipos_procedimientos: List[Dict[str, Any]] = []
        self._tipos_procedimientos_filtrados: List[Dict[str, Any]] = []
        self._estadisticas: Dict[str, Any] = {}
        self._loading: bool = False
        
        # Filtros activos
        self._filtro_busqueda: str = ""
        self._filtro_precio_min: float = 0.0
        self._filtro_precio_max: float = -1.0
        
        # Configuración inicial
        self._cargar_datos_iniciales()
        
        print("🩹 ConfiEnfermeriaModel inicializado")
    
    # ===============================
    # PROPERTIES - Datos para QML
    # ===============================
    
    @Property(list, notify=tiposProcedimientosChanged)
    def tiposProcedimientos(self) -> List[Dict[str, Any]]:
        """Lista de tipos de procedimientos para mostrar en QML"""
        return self._tipos_procedimientos_filtrados
    
    @Property('QVariantMap', notify=estadisticasChanged)
    def estadisticas(self) -> Dict[str, Any]:
        """Estadísticas de tipos de procedimientos"""
        return self._estadisticas
    
    @Property(bool, notify=loadingChanged)
    def loading(self) -> bool:
        """Estado de carga"""
        return self._loading
    
    @Property(int, notify=tiposProcedimientosChanged)
    def totalTiposProcedimientos(self) -> int:
        """Total de tipos de procedimientos filtrados"""
        return len(self._tipos_procedimientos_filtrados)
    
    @Property(str)
    def filtroBusqueda(self) -> str:
        """Texto de búsqueda actual"""
        return self._filtro_busqueda
    
    @Property(float)
    def filtroPrecioMin(self) -> float:
        """Filtro de precio mínimo"""
        return self._filtro_precio_min
    
    @Property(float)
    def filtroPrecioMax(self) -> float:
        """Filtro de precio máximo"""
        return self._filtro_precio_max
    
    # ===============================
    # SLOTS - Métodos llamables desde QML
    # ===============================
    
    # --- OPERACIONES CRUD TIPOS DE PROCEDIMIENTOS ---
    
    @Slot(str, str, float, float, result=bool)
    def crearTipoProcedimiento(self, nombre: str, descripcion: str = "", 
                              precio_normal: float = 0.0, precio_emergencia: float = 0.0) -> bool:
        """Crea nuevo tipo de procedimiento desde QML"""
        try:
            self._set_loading(True)
            
            procedimiento_id = self.repository.create_tipo_procedimiento(
                nombre=nombre.strip(),
                descripcion=descripcion.strip() if descripcion.strip() else None,
                precio_normal=precio_normal,
                precio_emergencia=precio_emergencia
            )
            
            if procedimiento_id:
                # Carga inmediata y forzada de datos
                self._cargar_tipos_procedimientos()
                self._cargar_estadisticas()
                
                # Forzar aplicación de filtros actuales
                self.aplicarFiltros(self._filtro_busqueda, self._filtro_precio_min, self._filtro_precio_max)
                
                mensaje = f"Tipo de procedimiento creado exitosamente - ID: {procedimiento_id}"
                self.tipoProcedimientoCreado.emit(True, mensaje)
                self.successMessage.emit(mensaje)
                
                print(f"✅ Tipo de procedimiento creado desde QML: {nombre}")
                print(f"🔄 Datos actualizados automáticamente - Total: {len(self._tipos_procedimientos)}")
                return True
            else:
                error_msg = "Error creando tipo de procedimiento"
                self.tipoProcedimientoCreado.emit(False, error_msg)
                self.errorOccurred.emit("Error de validación", error_msg)
                return False
                
        except Exception as e:
            error_msg = f"Error inesperado: {str(e)}"
            self.tipoProcedimientoCreado.emit(False, error_msg)
            self.errorOccurred.emit("Error crítico", error_msg)
            return False
        finally:
            self._set_loading(False)

    @Slot()
    def refrescarDatosInmediato(self):
        """Método para refrescar datos inmediatamente desde QML"""
        try:
            print("🔄 Refrescando datos inmediatamente...")
            self._cargar_tipos_procedimientos()
            
            # Aplicar filtros actuales
            self.aplicarFiltros(self._filtro_busqueda, self._filtro_precio_min, self._filtro_precio_max)
            
            print(f"✅ Datos refrescados: {len(self._tipos_procedimientos)} tipos de procedimientos")
            
        except Exception as e:
            print(f"❌ Error refrescando datos: {e}")
            self.errorOccurred.emit("Error", f"Error refrescando datos: {str(e)}")
    
    @Slot(int, str, str, float, float, result=bool)
    def actualizarTipoProcedimiento(self, procedimiento_id: int, nombre: str = "", 
                                   descripcion: str = "", precio_normal: float = -1.0,
                                   precio_emergencia: float = -1.0) -> bool:
        """Actualiza tipo de procedimiento existente desde QML"""
        try:
            self._set_loading(True)
            
            # Preparar argumentos solo con valores válidos
            kwargs = {}
            if nombre.strip():
                kwargs['nombre'] = nombre.strip()
            if descripcion.strip():
                kwargs['descripcion'] = descripcion.strip()
            elif descripcion == "":  # Si es cadena vacía explícita, establecer None
                kwargs['descripcion'] = None
            if precio_normal >= 0:
                kwargs['precio_normal'] = precio_normal
            if precio_emergencia >= 0:
                kwargs['precio_emergencia'] = precio_emergencia
            
            success = self.repository.update_tipo_procedimiento(procedimiento_id, **kwargs)
            
            if success:
                self._cargar_tipos_procedimientos()
                
                mensaje = "Tipo de procedimiento actualizado exitosamente"
                self.tipoProcedimientoActualizado.emit(True, mensaje)
                self.successMessage.emit(mensaje)
                
                print(f"✅ Tipo de procedimiento actualizado desde QML: ID {procedimiento_id}")
                return True
            else:
                error_msg = "Error actualizando tipo de procedimiento"
                self.tipoProcedimientoActualizado.emit(False, error_msg)
                self.errorOccurred.emit("Error de actualización", error_msg)
                return False
                
        except Exception as e:
            error_msg = f"Error inesperado: {str(e)}"
            self.tipoProcedimientoActualizado.emit(False, error_msg)
            self.errorOccurred.emit("Error crítico", error_msg)
            return False
        finally:
            self._set_loading(False)
    
    @Slot(int, result=bool)
    def eliminarTipoProcedimiento(self, procedimiento_id: int) -> bool:
        """Elimina tipo de procedimiento desde QML"""
        try:
            self._set_loading(True)
            
            success = self.repository.delete_tipo_procedimiento(procedimiento_id)
            
            if success:
                self._cargar_tipos_procedimientos()
                self._cargar_estadisticas()
                
                mensaje = "Tipo de procedimiento eliminado exitosamente"
                self.tipoProcedimientoEliminado.emit(True, mensaje)
                self.successMessage.emit(mensaje)
                
                print(f"🗑️ Tipo de procedimiento eliminado desde QML: ID {procedimiento_id}")
                return True
            else:
                error_msg = "Error eliminando tipo de procedimiento"
                self.tipoProcedimientoEliminado.emit(False, error_msg)
                self.errorOccurred.emit("Error de eliminación", error_msg)
                return False
                
        except Exception as e:
            error_msg = f"Error inesperado: {str(e)}"
            self.tipoProcedimientoEliminado.emit(False, error_msg)
            self.errorOccurred.emit("Error crítico", error_msg)
            return False
        finally:
            self._set_loading(False)
    
    # --- BÚSQUEDA Y FILTROS ---
    
    @Slot(str, float, float)
    def aplicarFiltros(self, buscar: str, precio_min: float = 0.0, precio_max: float = -1.0):
        """Aplica filtros a la lista de tipos de procedimientos"""
        try:
            self._filtro_busqueda = buscar.strip()
            self._filtro_precio_min = precio_min
            self._filtro_precio_max = precio_max
            
            # Filtrar datos locales
            procedimientos_filtrados = self._tipos_procedimientos.copy()
            
            # Filtro por búsqueda
            if buscar.strip():
                buscar_lower = buscar.lower()
                procedimientos_filtrados = [
                    p for p in procedimientos_filtrados
                    if (buscar_lower in p.get('Nombre', '').lower() or
                        buscar_lower in str(p.get('Descripcion', '')).lower())
                ]
            
            # Filtro por precio mínimo
            if precio_min > 0:
                procedimientos_filtrados = [
                    p for p in procedimientos_filtrados
                    if p.get('Precio_Normal', 0) >= precio_min
                ]
            
            # Filtro por precio máximo
            if precio_max > 0:
                procedimientos_filtrados = [
                    p for p in procedimientos_filtrados
                    if p.get('Precio_Normal', 0) <= precio_max
                ]
            
            self._tipos_procedimientos_filtrados = procedimientos_filtrados
            self.tiposProcedimientosChanged.emit()
            
            total = len(procedimientos_filtrados)
            self.busquedaCompleta.emit(True, f"Encontrados {total} tipos de procedimientos", total)
            print(f"🔍 Filtros aplicados: {total} tipos de procedimientos")
                
        except Exception as e:
            self.errorOccurred.emit("Error en filtros", f"Error aplicando filtros: {str(e)}")
    
    @Slot(str, int, result=list)
    def buscarTiposProcedimientos(self, termino: str, limite: int = 50) -> List[Dict[str, Any]]:
        """Búsqueda rápida de tipos de procedimientos"""
        try:
            if not termino.strip():
                return self._tipos_procedimientos
            
            tipos_procedimientos = self.repository.search_tipos_procedimientos(termino.strip(), limite)
            print(f"🔍 Búsqueda '{termino}': {len(tipos_procedimientos)} resultados")
            return tipos_procedimientos
            
        except Exception as e:
            self.errorOccurred.emit("Error en búsqueda", f"Error buscando tipos de procedimientos: {str(e)}")
            return []
    
    @Slot()
    def limpiarFiltros(self):
        """Limpia todos los filtros aplicados"""
        self._filtro_busqueda = ""
        self._filtro_precio_min = 0.0
        self._filtro_precio_max = -1.0
        self._tipos_procedimientos_filtrados = self._tipos_procedimientos.copy()
        self.tiposProcedimientosChanged.emit()
        print("🧹 Filtros limpiados")
    
    # --- CONSULTAS ESPECÍFICAS ---
    
    @Slot(int, result='QVariantMap')
    def obtenerTipoProcedimientoPorId(self, procedimiento_id: int) -> Dict[str, Any]:
        """Obtiene tipo de procedimiento específico por ID"""
        try:
            tipo_procedimiento = self.repository.get_tipo_procedimiento_by_id(procedimiento_id)
            return tipo_procedimiento if tipo_procedimiento else {}
        except Exception as e:
            self.errorOccurred.emit("Error", f"Error obteniendo tipo de procedimiento: {str(e)}")
            return {}
    
    @Slot(float, float, result=list)
    def obtenerTiposProcedimientosPorRangoPrecios(self, precio_min: float = 0.0, 
                                                 precio_max: float = -1.0) -> List[Dict[str, Any]]:
        """Obtiene tipos de procedimientos filtrados por rango de precios"""
        try:
            return self.repository.get_tipos_procedimientos_por_rango_precios(precio_min, precio_max)
        except Exception as e:
            self.errorOccurred.emit("Error", f"Error obteniendo procedimientos por precio: {str(e)}")
            return []
    
    # --- RECARGA DE DATOS ---
    
    @Slot()
    def recargarDatos(self):
        """Recarga todos los datos desde la base de datos"""
        try:
            self._set_loading(True)
            self._cargar_datos_iniciales()
            self.successMessage.emit("Datos recargados exitosamente")
            print("🔄 Datos de configuración de enfermería recargados desde QML")
        except Exception as e:
            self.errorOccurred.emit("Error", f"Error recargando datos: {str(e)}")
        finally:
            self._set_loading(False)
    
    @Slot()
    def recargarTiposProcedimientos(self):
        """Recarga solo la lista de tipos de procedimientos"""
        try:
            self._cargar_tipos_procedimientos()
            print("🔄 Tipos de procedimientos recargados")
        except Exception as e:
            self.errorOccurred.emit("Error", f"Error recargando tipos de procedimientos: {str(e)}")
    
    # --- UTILIDADES ---
    
    @Slot(result=list)
    def obtenerTiposParaComboBox(self) -> List[Dict[str, Any]]:
        """Obtiene tipos de procedimientos formateados para ComboBox"""
        try:
            tipos_formateados = []
            
            # Agregar opción "Todos"
            tipos_formateados.append({
                'id': 0,
                'text': 'Todos los procedimientos',
                'data': {}
            })
            
            # Agregar tipos existentes
            for tipo in self._tipos_procedimientos:
                tipos_formateados.append({
                    'id': tipo.get('id', 0),
                    'text': tipo.get('Nombre', 'Sin nombre'),
                    'data': tipo
                })
            
            return tipos_formateados
            
        except Exception as e:
            self.errorOccurred.emit("Error", f"Error obteniendo tipos: {str(e)}")
            return [{'id': 0, 'text': 'Todos los procedimientos', 'data': {}}]
    
    @Slot(str, int, result=bool)
    def validarNombreUnico(self, nombre: str, procedimiento_id: int = 0) -> bool:
        """Valida que el nombre sea único"""
        try:
            if not nombre.strip():
                return False
            return not self.repository.tipo_procedimiento_name_exists(
                nombre.strip(), exclude_id=procedimiento_id if procedimiento_id > 0 else None)
        except Exception as e:
            return False
    
    @Slot(result='QVariantMap')
    def obtenerEstadisticasCompletas(self) -> Dict[str, Any]:
        """Obtiene estadísticas completas del sistema"""
        try:
            return self.repository.get_tipos_procedimientos_statistics()
        except Exception as e:
            self.errorOccurred.emit("Error", f"Error obteniendo estadísticas: {str(e)}")
            return {}
    
    @Slot(result='QVariantMap')
    def obtenerResumenUso(self) -> Dict[str, Any]:
        """Obtiene resumen de uso de tipos de procedimientos"""
        try:
            return self.repository.get_tipo_procedimientos_summary()
        except Exception as e:
            self.errorOccurred.emit("Error", f"Error obteniendo resumen: {str(e)}")
            return {}
        
    @Slot(int, result=int)
    def obtenerProcedimientosAsociados(self, procedimiento_id: int) -> int:
        """Obtiene cantidad de procedimientos asociados a un tipo"""
        try:
            return self.repository.count_procedimientos_asociados(procedimiento_id)
        except Exception as e:
            self.errorOccurred.emit("Error", f"Error obteniendo procedimientos asociados: {str(e)}")
            return 0
    
    @Slot(int, result=list)
    def obtenerProcedimientosMasUtilizados(self, limite: int = 10) -> List[Dict[str, Any]]:
        """Obtiene los tipos de procedimientos más utilizados"""
        try:
            return self.repository.get_procedimientos_mas_utilizados(limite)
        except Exception as e:
            self.errorOccurred.emit("Error", f"Error obteniendo procedimientos más utilizados: {str(e)}")
            return []
    
    # ===============================
    # MÉTODOS PRIVADOS
    # ===============================
    
    def _cargar_datos_iniciales(self):
        """Carga todos los datos necesarios al inicializar"""
        try:
            self._cargar_tipos_procedimientos()
            self._cargar_estadisticas()
            print("📊 Datos iniciales de configuración de enfermería cargados")
        except Exception as e:
            print(f"❌ Error cargando datos iniciales de configuración de enfermería: {e}")
            self.errorOccurred.emit("Error inicial", f"Error cargando datos: {str(e)}")
    
    def _cargar_tipos_procedimientos(self):
        """Carga lista de tipos de procedimientos desde el repository"""
        try:
            tipos_procedimientos = self.repository.get_all_tipos_procedimientos()
            
            # Procesar datos adicionales
            for procedimiento in tipos_procedimientos:
                if not procedimiento.get('Descripcion'):
                    procedimiento['Descripcion'] = 'Sin descripción'
                
                # Asegurar que los precios sean numéricos
                procedimiento['Precio_Normal'] = float(procedimiento.get('Precio_Normal', 0))
                procedimiento['Precio_Emergencia'] = float(procedimiento.get('Precio_Emergencia', 0))
            
            self._tipos_procedimientos = tipos_procedimientos
            self._tipos_procedimientos_filtrados = tipos_procedimientos.copy()
            self.tiposProcedimientosChanged.emit()
            print(f"🩹 Tipos de procedimientos cargados: {len(tipos_procedimientos)}")
                
        except Exception as e:
            print(f"❌ Error cargando tipos de procedimientos: {e}")
            self._tipos_procedimientos = []
            self._tipos_procedimientos_filtrados = []
            raise e
    
    def _cargar_estadisticas(self):
        """Carga estadísticas desde el repository"""
        try:
            estadisticas = self.repository.get_tipos_procedimientos_statistics()
            self._estadisticas = estadisticas
            self.estadisticasChanged.emit()
            print("📈 Estadísticas de tipos de procedimientos cargadas")
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

def register_confi_enfermeria_model():
    """Registra el ConfiEnfermeriaModel para uso en QML"""
    qmlRegisterType(ConfiEnfermeriaModel, "ClinicaModels", 1, 0, "ConfiEnfermeriaModel")
    print("🔗 ConfiEnfermeriaModel registrado para QML")

# Para facilitar la importación
__all__ = ['ConfiEnfermeriaModel', 'register_confi_enfermeria_model']