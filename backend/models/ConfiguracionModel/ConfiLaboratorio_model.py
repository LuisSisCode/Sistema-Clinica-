from typing import List, Dict, Any, Optional
from PySide6.QtCore import QObject, Signal, Slot, Property
from PySide6.QtQml import qmlRegisterType

from ...repositories.ConfiguracionRepositor import ConfiLaboratorioRepository
from ...core.excepciones import ExceptionHandler, ValidationError

class ConfiLaboratorioModel(QObject):
    """
    Model QObject para gestión de configuración de tipos de análisis en QML
    Conecta la interfaz QML con el ConfiLaboratorioRepository
    """
    
    # ===============================
    # SIGNALS - Notificaciones a QML
    # ===============================
    
    # Señales para cambios en datos
    tiposAnalisisChanged = Signal()
    estadisticasChanged = Signal()
    
    # Señales para operaciones
    tipoAnalisisCreado = Signal(bool, str)  # success, message
    tipoAnalisisActualizado = Signal(bool, str)
    tipoAnalisisEliminado = Signal(bool, str)
    
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
        self.repository = ConfiLaboratorioRepository()
        
        # Estado interno
        self._tipos_analisis: List[Dict[str, Any]] = []
        self._tipos_analisis_filtrados: List[Dict[str, Any]] = []
        self._estadisticas: Dict[str, Any] = {}
        self._loading: bool = False
        
        # Filtros activos
        self._filtro_busqueda: str = ""
        
        # Configuración inicial
        self._cargar_datos_iniciales()
        
        print("🧪 ConfiLaboratorioModel inicializado")
    
    # ===============================
    # PROPERTIES - Datos para QML
    # ===============================
    
    @Property(list, notify=tiposAnalisisChanged)
    def tiposAnalisis(self) -> List[Dict[str, Any]]:
        """Lista de tipos de análisis para mostrar en QML"""
        return self._tipos_analisis_filtrados
    
    @Property('QVariantMap', notify=estadisticasChanged)
    def estadisticas(self) -> Dict[str, Any]:
        """Estadísticas de tipos de análisis"""
        return self._estadisticas
    
    @Property(bool, notify=loadingChanged)
    def loading(self) -> bool:
        """Estado de carga"""
        return self._loading
    
    @Property(int, notify=tiposAnalisisChanged)
    def totalTiposAnalisis(self) -> int:
        """Total de tipos de análisis filtrados"""
        return len(self._tipos_analisis_filtrados)
    
    @Property(str)
    def filtroBusqueda(self) -> str:
        """Texto de búsqueda actual"""
        return self._filtro_busqueda
    
    # ===============================
    # SLOTS - Métodos llamables desde QML
    # ===============================
    
    # --- OPERACIONES CRUD TIPOS DE ANÁLISIS ---
    
    @Slot(str, str, float, float, result=bool)
    def crearTipoAnalisis(self, nombre: str, descripcion: str = "", 
                         precio_normal: float = 0.0, precio_emergencia: float = 0.0) -> bool:
        """Crea nuevo tipo de análisis desde QML"""
        try:
            self._set_loading(True)
            
            tipo_id = self.repository.create_tipo_analisis(
                nombre=nombre.strip(),
                descripcion=descripcion.strip() if descripcion.strip() else None,
                precio_normal=precio_normal,
                precio_emergencia=precio_emergencia
            )
            
            if tipo_id:
                # Carga inmediata y forzada de datos
                self._cargar_tipos_analisis()
                self._cargar_estadisticas()
                
                # Forzar aplicación de filtros actuales
                self.aplicarFiltros(self._filtro_busqueda)
                
                mensaje = f"Tipo de análisis creado exitosamente - ID: {tipo_id}"
                self.tipoAnalisisCreado.emit(True, mensaje)
                self.successMessage.emit(mensaje)
                
                print(f"✅ Tipo de análisis creado desde QML: {nombre}")
                print(f"🔄 Datos actualizados automáticamente - Total: {len(self._tipos_analisis)}")
                return True
            else:
                error_msg = "Error creando tipo de análisis"
                self.tipoAnalisisCreado.emit(False, error_msg)
                self.errorOccurred.emit("Error de validación", error_msg)
                return False
                
        except Exception as e:
            error_msg = f"Error inesperado: {str(e)}"
            self.tipoAnalisisCreado.emit(False, error_msg)
            self.errorOccurred.emit("Error crítico", error_msg)
            return False
        finally:
            self._set_loading(False)

    @Slot()
    def refrescarDatosInmediato(self):
        """Método para refrescar datos inmediatamente desde QML"""
        try:
            print("🔄 Refrescando datos inmediatamente...")
            self._cargar_tipos_analisis()
            
            # Aplicar filtros actuales
            self.aplicarFiltros(self._filtro_busqueda)
            
            print(f"✅ Datos refrescados: {len(self._tipos_analisis)} tipos de análisis")
            
        except Exception as e:
            print(f"❌ Error refrescando datos: {e}")
            self.errorOccurred.emit("Error", f"Error refrescando datos: {str(e)}")
    
    @Slot(int, str, str, float, float, result=bool)
    def actualizarTipoAnalisis(self, tipo_id: int, nombre: str = "", 
                              descripcion: str = "", precio_normal: float = -1.0,
                              precio_emergencia: float = -1.0) -> bool:
        """Actualiza tipo de análisis existente desde QML"""
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
            
            success = self.repository.update_tipo_analisis(tipo_id, **kwargs)
            
            if success:
                self._cargar_tipos_analisis()
                
                mensaje = "Tipo de análisis actualizado exitosamente"
                self.tipoAnalisisActualizado.emit(True, mensaje)
                self.successMessage.emit(mensaje)
                
                print(f"✅ Tipo de análisis actualizado desde QML: ID {tipo_id}")
                return True
            else:
                error_msg = "Error actualizando tipo de análisis"
                self.tipoAnalisisActualizado.emit(False, error_msg)
                self.errorOccurred.emit("Error de actualización", error_msg)
                return False
                
        except Exception as e:
            error_msg = f"Error inesperado: {str(e)}"
            self.tipoAnalisisActualizado.emit(False, error_msg)
            self.errorOccurred.emit("Error crítico", error_msg)
            return False
        finally:
            self._set_loading(False)
    
    @Slot(int, result=bool)
    def eliminarTipoAnalisis(self, tipo_id: int) -> bool:
        """Elimina tipo de análisis desde QML"""
        try:
            self._set_loading(True)
            
            success = self.repository.delete_tipo_analisis(tipo_id)
            
            if success:
                self._cargar_tipos_analisis()
                self._cargar_estadisticas()
                
                mensaje = "Tipo de análisis eliminado exitosamente"
                self.tipoAnalisisEliminado.emit(True, mensaje)
                self.successMessage.emit(mensaje)
                
                print(f"🗑️ Tipo de análisis eliminado desde QML: ID {tipo_id}")
                return True
            else:
                error_msg = "Error eliminando tipo de análisis"
                self.tipoAnalisisEliminado.emit(False, error_msg)
                self.errorOccurred.emit("Error de eliminación", error_msg)
                return False
                
        except Exception as e:
            error_msg = f"Error inesperado: {str(e)}"
            self.tipoAnalisisEliminado.emit(False, error_msg)
            self.errorOccurred.emit("Error crítico", error_msg)
            return False
        finally:
            self._set_loading(False)
    
    # --- BÚSQUEDA Y FILTROS ---
    
    @Slot(str)
    def aplicarFiltros(self, buscar: str):
        """Aplica filtros a la lista de tipos de análisis"""
        try:
            self._filtro_busqueda = buscar.strip()
            
            # Filtrar datos locales
            tipos_filtrados = self._tipos_analisis.copy()
            
            # Filtro por búsqueda
            if buscar.strip():
                buscar_lower = buscar.lower()
                tipos_filtrados = [
                    t for t in tipos_filtrados
                    if (buscar_lower in t.get('Nombre', '').lower() or
                        buscar_lower in str(t.get('Descripcion', '')).lower())
                ]
            
            self._tipos_analisis_filtrados = tipos_filtrados
            self.tiposAnalisisChanged.emit()
            
            total = len(tipos_filtrados)
            self.busquedaCompleta.emit(True, f"Encontrados {total} tipos de análisis", total)
            print(f"🔍 Filtros aplicados: {total} tipos de análisis")
                
        except Exception as e:
            self.errorOccurred.emit("Error en filtros", f"Error aplicando filtros: {str(e)}")
    
    @Slot(str, int, result=list)
    def buscarTiposAnalisis(self, termino: str, limite: int = 50) -> List[Dict[str, Any]]:
        """Búsqueda rápida de tipos de análisis"""
        try:
            if not termino.strip():
                return self._tipos_analisis
            
            tipos_analisis = self.repository.search_tipos_analisis(termino.strip(), limite)
            print(f"🔍 Búsqueda '{termino}': {len(tipos_analisis)} resultados")
            return tipos_analisis
            
        except Exception as e:
            self.errorOccurred.emit("Error en búsqueda", f"Error buscando tipos de análisis: {str(e)}")
            return []
    
    @Slot()
    def limpiarFiltros(self):
        """Limpia todos los filtros aplicados"""
        self._filtro_busqueda = ""
        self._tipos_analisis_filtrados = self._tipos_analisis.copy()
        self.tiposAnalisisChanged.emit()
        print("🧹 Filtros limpiados")
    
    # --- CONSULTAS ESPECÍFICAS ---
    
    @Slot(int, result='QVariantMap')
    def obtenerTipoAnalisisPorId(self, tipo_id: int) -> Dict[str, Any]:
        """Obtiene tipo de análisis específico por ID"""
        try:
            tipo_analisis = self.repository.get_tipo_analisis_by_id(tipo_id)
            return tipo_analisis if tipo_analisis else {}
        except Exception as e:
            self.errorOccurred.emit("Error", f"Error obteniendo tipo de análisis: {str(e)}")
            return {}
    
    @Slot(float, float, result=list)
    def obtenerTiposAnalisisPorRangoPrecios(self, precio_min: float, precio_max: float = -1) -> List[Dict[str, Any]]:
        """Obtiene tipos de análisis por rango de precios"""
        try:
            precio_max_param = precio_max if precio_max >= 0 else None
            return self.repository.get_tipos_analisis_by_price_range(precio_min, precio_max_param)
        except Exception as e:
            self.errorOccurred.emit("Error", f"Error obteniendo tipos por precio: {str(e)}")
            return []
    
    # --- RECARGA DE DATOS ---
    
    @Slot()
    def recargarDatos(self):
        """Recarga todos los datos desde la base de datos"""
        try:
            self._set_loading(True)
            self._cargar_datos_iniciales()
            self.successMessage.emit("Datos recargados exitosamente")
            print("🔄 Datos de configuración de laboratorio recargados desde QML")
        except Exception as e:
            self.errorOccurred.emit("Error", f"Error recargando datos: {str(e)}")
        finally:
            self._set_loading(False)
    
    @Slot()
    def recargarTiposAnalisis(self):
        """Recarga solo la lista de tipos de análisis"""
        try:
            self._cargar_tipos_analisis()
            print("🔄 Tipos de análisis recargados")
        except Exception as e:
            self.errorOccurred.emit("Error", f"Error recargando tipos de análisis: {str(e)}")
    
    # --- UTILIDADES ---
    
    @Slot(result=list)
    def obtenerTiposParaComboBox(self) -> List[Dict[str, Any]]:
        """Obtiene tipos de análisis formateados para ComboBox"""
        try:
            tipos_formateados = []
            
            # Agregar opción "Todos"
            tipos_formateados.append({
                'id': 0,
                'text': 'Todos los tipos',
                'data': {}
            })
            
            # Agregar tipos existentes
            for tipo in self._tipos_analisis:
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
            return not self.repository.tipo_analisis_name_exists(nombre.strip(), exclude_id=tipo_id if tipo_id > 0 else None)
        except Exception as e:
            return False
    
    @Slot(result='QVariantMap')
    def obtenerEstadisticasCompletas(self) -> Dict[str, Any]:
        """Obtiene estadísticas completas del sistema"""
        try:
            return self.repository.get_tipos_analisis_statistics()
        except Exception as e:
            self.errorOccurred.emit("Error", f"Error obteniendo estadísticas: {str(e)}")
            return {}
    
    @Slot(result='QVariantMap')
    def obtenerResumenUso(self) -> Dict[str, Any]:
        """Obtiene resumen de uso de tipos de análisis"""
        try:
            return self.repository.get_tipos_analisis_summary()
        except Exception as e:
            self.errorOccurred.emit("Error", f"Error obteniendo resumen: {str(e)}")
            return {}
    
    # ===============================
    # MÉTODOS PRIVADOS
    # ===============================
    
    def _cargar_datos_iniciales(self):
        """Carga todos los datos necesarios al inicializar"""
        try:
            self._cargar_tipos_analisis()
            self._cargar_estadisticas()
            print("📊 Datos iniciales de configuración de laboratorio cargados")
        except Exception as e:
            print(f"❌ Error cargando datos iniciales de configuración: {e}")
            self.errorOccurred.emit("Error inicial", f"Error cargando datos: {str(e)}")
    
    def _cargar_tipos_analisis(self):
        """Carga lista de tipos de análisis desde el repository"""
        try:
            tipos_analisis = self.repository.get_all_tipos_analisis()
            
            # Procesar datos adicionales
            for tipo in tipos_analisis:
                if not tipo.get('Descripcion'):
                    tipo['Descripcion'] = 'Sin descripción'
                
                # Asegurar que los precios sean float
                tipo['Precio_Normal'] = float(tipo.get('Precio_Normal', 0))
                tipo['Precio_Emergencia'] = float(tipo.get('Precio_Emergencia', 0))
                
                # Agregar información calculada
                precio_normal = tipo.get('Precio_Normal', 0)
                precio_emergencia = tipo.get('Precio_Emergencia', 0)
                
                if precio_normal > 0:
                    diferencia_porcentual = ((precio_emergencia - precio_normal) / precio_normal) * 100
                    tipo['diferencia_porcentual'] = round(diferencia_porcentual, 2)
                else:
                    tipo['diferencia_porcentual'] = 0
            
            self._tipos_analisis = tipos_analisis
            self._tipos_analisis_filtrados = tipos_analisis.copy()
            self.tiposAnalisisChanged.emit()
            print(f"🧪 Tipos de análisis cargados: {len(tipos_analisis)}")
                
        except Exception as e:
            print(f"❌ Error cargando tipos de análisis: {e}")
            self._tipos_analisis = []
            self._tipos_analisis_filtrados = []
            raise e
    
    def _cargar_estadisticas(self):
        """Carga estadísticas desde el repository"""
        try:
            estadisticas = self.repository.get_tipos_analisis_statistics()
            self._estadisticas = estadisticas
            self.estadisticasChanged.emit()
            print("📈 Estadísticas de tipos de análisis cargadas")
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

def register_confi_laboratorio_model():
    """Registra el ConfiLaboratorioModel para uso en QML"""
    qmlRegisterType(ConfiLaboratorioModel, "ClinicaModels", 1, 0, "ConfiLaboratorioModel")
    print("🔗 ConfiLaboratorioModel registrado para QML")

# Para facilitar la importación
__all__ = ['ConfiLaboratorioModel', 'register_confi_laboratorio_model']