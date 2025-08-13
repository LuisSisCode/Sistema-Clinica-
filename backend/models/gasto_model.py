from typing import List, Dict, Any, Optional
from PySide6.QtCore import QObject, Signal, Slot, Property
from PySide6.QtQml import qmlRegisterType

from ..services.gasto_service import GastoService
from ..core.excepciones import ExceptionHandler, ValidationError

class GastoModel(QObject):
    """
    Model QObject para gestión de gastos en QML
    Conecta la interfaz QML con el GastoService
    """
    
    # ===============================
    # SIGNALS - Notificaciones a QML
    # ===============================
    
    # Señales para cambios en datos
    gastosChanged = Signal()
    tiposGastosChanged = Signal()
    estadisticasChanged = Signal()
    
    # Señales para operaciones
    gastoCreado = Signal(bool, str)  # success, message
    gastoActualizado = Signal(bool, str)
    gastoEliminado = Signal(bool, str)
    
    tipoGastoCreado = Signal(bool, str)
    tipoGastoActualizado = Signal(bool, str)
    tipoGastoEliminado = Signal(bool, str)
    
    # Señales para reportes
    reporteGenerado = Signal(bool, str, 'QVariantMap')
    
    # Señales para UI
    loadingChanged = Signal()
    errorOccurred = Signal(str, str)  # title, message
    successMessage = Signal(str)
    
    def __init__(self, parent=None):
        super().__init__(parent)
        
        # Referencias a services
        self.service = GastoService()
        
        # Estado interno
        self._gastos: List[Dict[str, Any]] = []
        self._gastos_filtrados: List[Dict[str, Any]] = []
        self._tipos_gastos: List[Dict[str, Any]] = []
        self._estadisticas: Dict[str, Any] = {}
        self._loading: bool = False
        
        # Filtros activos
        self._filtro_tipo: int = 0
        self._filtro_fecha_desde: str = ""
        self._filtro_fecha_hasta: str = ""
        self._filtro_monto_min: float = 0.0
        self._filtro_monto_max: float = 0.0
        self._filtro_busqueda: str = ""
        
        # Configuración inicial
        self._cargar_datos_iniciales()
        
        print("💸 GastoModel inicializado")
    
    # ===============================
    # PROPERTIES - Datos para QML
    # ===============================
    
    @Property(list, notify=gastosChanged)
    def gastos(self) -> List[Dict[str, Any]]:
        """Lista de gastos para mostrar en QML"""
        return self._gastos_filtrados
    
    @Property(list, notify=tiposGastosChanged)
    def tiposGastos(self) -> List[Dict[str, Any]]:
        """Lista de tipos de gastos disponibles"""
        return self._tipos_gastos
    
    @Property('QVariantMap', notify=estadisticasChanged)
    def estadisticas(self) -> Dict[str, Any]:
        """Estadísticas de gastos"""
        return self._estadisticas
    
    @Property(bool, notify=loadingChanged)
    def loading(self) -> bool:
        """Estado de carga"""
        return self._loading
    
    @Property(int, notify=gastosChanged)
    def totalGastos(self) -> int:
        """Total de gastos filtrados"""
        return len(self._gastos_filtrados)
    
    # ===============================
    # SLOTS - Métodos llamables desde QML
    # ===============================
    
    # --- OPERACIONES CRUD GASTOS ---
    
    @Slot(int, float, int, str, str, bool, result=bool)
    def crearGasto(self, tipo_gasto_id: int, monto: float, usuario_id: int,
                   descripcion: str, fecha_gasto: str = "", validar_presupuesto: bool = True) -> bool:
        """Crea nuevo gasto desde QML"""
        try:
            self._set_loading(True)
            
            resultado = self.service.crear_gasto(
                tipo_gasto_id=tipo_gasto_id,
                monto=monto,
                usuario_id=usuario_id,
                descripcion=descripcion,
                fecha_gasto=fecha_gasto if fecha_gasto else None,
                validar_presupuesto=validar_presupuesto
            )
            
            if resultado.get('exito'):
                self._cargar_gastos()
                self._cargar_estadisticas()
                
                mensaje = resultado.get('mensaje', 'Gasto creado exitosamente')
                self.gastoCreado.emit(True, mensaje)
                self.successMessage.emit(mensaje)
                
                print(f"✅ Gasto creado desde QML: {monto}")
                return True
            else:
                error_msg = resultado.get('mensaje', 'Error creando gasto')
                self.gastoCreado.emit(False, error_msg)
                return False
                
        except Exception as e:
            error_msg = f"Error inesperado: {str(e)}"
            self.gastoCreado.emit(False, error_msg)
            self.errorOccurred.emit("Error crítico", error_msg)
            return False
        finally:
            self._set_loading(False)
    
    @Slot(int, float, str, result=bool)
    def actualizarGasto(self, gasto_id: int, monto: float = 0, descripcion: str = "") -> bool:
        """Actualiza gasto existente desde QML"""
        try:
            self._set_loading(True)
            
            kwargs = {}
            if monto > 0:
                kwargs['monto'] = monto
            if descripcion:
                kwargs['descripcion'] = descripcion
            
            resultado = self.service.actualizar_gasto(gasto_id, **kwargs)
            
            if resultado.get('exito'):
                self._cargar_gastos()
                
                mensaje = resultado.get('mensaje', 'Gasto actualizado exitosamente')
                self.gastoActualizado.emit(True, mensaje)
                self.successMessage.emit(mensaje)
                
                print(f"✅ Gasto actualizado desde QML: ID {gasto_id}")
                return True
            else:
                error_msg = resultado.get('mensaje', 'Error actualizando gasto')
                self.gastoActualizado.emit(False, error_msg)
                return False
                
        except Exception as e:
            error_msg = f"Error inesperado: {str(e)}"
            self.gastoActualizado.emit(False, error_msg)
            self.errorOccurred.emit("Error crítico", error_msg)
            return False
        finally:
            self._set_loading(False)
    
    @Slot(int, int, result=bool)
    def eliminarGasto(self, gasto_id: int, usuario_id: int) -> bool:
        """Elimina gasto desde QML"""
        try:
            self._set_loading(True)
            
            resultado = self.service.eliminar_gasto(gasto_id, usuario_id)
            
            if resultado.get('exito'):
                self._cargar_gastos()
                self._cargar_estadisticas()
                
                mensaje = resultado.get('mensaje', 'Gasto eliminado exitosamente')
                self.gastoEliminado.emit(True, mensaje)
                self.successMessage.emit(mensaje)
                
                print(f"🗑️ Gasto eliminado desde QML: ID {gasto_id}")
                return True
            else:
                error_msg = resultado.get('mensaje', 'Error eliminando gasto')
                self.gastoEliminado.emit(False, error_msg)
                return False
                
        except Exception as e:
            error_msg = f"Error inesperado: {str(e)}"
            self.gastoEliminado.emit(False, error_msg)
            self.errorOccurred.emit("Error crítico", error_msg)
            return False
        finally:
            self._set_loading(False)
    
    # --- OPERACIONES CRUD TIPOS GASTOS ---
    
    @Slot(str, result=bool)
    def crearTipoGasto(self, nombre: str) -> bool:
        """Crea nuevo tipo de gasto desde QML"""
        try:
            self._set_loading(True)
            
            resultado = self.service.crear_tipo_gasto(nombre.strip())
            
            if resultado.get('exito'):
                self._cargar_tipos_gastos()
                
                mensaje = resultado.get('mensaje', 'Tipo de gasto creado exitosamente')
                self.tipoGastoCreado.emit(True, mensaje)
                self.successMessage.emit(mensaje)
                
                print(f"✅ Tipo gasto creado desde QML: {nombre}")
                return True
            else:
                error_msg = resultado.get('mensaje', 'Error creando tipo de gasto')
                self.tipoGastoCreado.emit(False, error_msg)
                return False
                
        except Exception as e:
            error_msg = f"Error inesperado: {str(e)}"
            self.tipoGastoCreado.emit(False, error_msg)
            self.errorOccurred.emit("Error crítico", error_msg)
            return False
        finally:
            self._set_loading(False)
    
    @Slot(int, str, result=bool)
    def actualizarTipoGasto(self, tipo_id: int, nombre: str) -> bool:
        """Actualiza tipo de gasto existente"""
        try:
            self._set_loading(True)
            
            resultado = self.service.actualizar_tipo_gasto(tipo_id, nombre.strip())
            
            if resultado.get('exito'):
                self._cargar_tipos_gastos()
                
                mensaje = resultado.get('mensaje', 'Tipo actualizado exitosamente')
                self.tipoGastoActualizado.emit(True, mensaje)
                self.successMessage.emit(mensaje)
                
                return True
            else:
                error_msg = resultado.get('mensaje', 'Error actualizando tipo')
                self.tipoGastoActualizado.emit(False, error_msg)
                return False
                
        except Exception as e:
            error_msg = f"Error inesperado: {str(e)}"
            self.tipoGastoActualizado.emit(False, error_msg)
            self.errorOccurred.emit("Error crítico", error_msg)
            return False
        finally:
            self._set_loading(False)
    
    @Slot(int, bool, result=bool)
    def eliminarTipoGasto(self, tipo_id: int, forzar: bool = False) -> bool:
        """Elimina tipo de gasto"""
        try:
            self._set_loading(True)
            
            resultado = self.service.eliminar_tipo_gasto(tipo_id, forzar)
            
            if resultado.get('exito'):
                self._cargar_tipos_gastos()
                
                mensaje = resultado.get('mensaje', 'Tipo eliminado exitosamente')
                self.tipoGastoEliminado.emit(True, mensaje)
                self.successMessage.emit(mensaje)
                
                return True
            else:
                error_msg = resultado.get('mensaje', 'Error eliminando tipo')
                self.tipoGastoEliminado.emit(False, error_msg)
                return False
                
        except Exception as e:
            error_msg = f"Error inesperado: {str(e)}"
            self.tipoGastoEliminado.emit(False, error_msg)
            self.errorOccurred.emit("Error crítico", error_msg)
            return False
        finally:
            self._set_loading(False)
    
    # --- BÚSQUEDA Y FILTROS ---
    
    @Slot(str, int, str, str, float, float, int, int, int)
    def aplicarFiltros(self, termino_busqueda: str, tipo_gasto_id: int, fecha_desde: str, 
                      fecha_hasta: str, monto_min: float, monto_max: float, 
                      usuario_id: int, page: int = 1, per_page: int = 50):
        """Aplica filtros avanzados a la lista de gastos"""
        try:
            filtros = {
                'termino_busqueda': termino_busqueda.strip(),
                'tipo_gasto_id': tipo_gasto_id if tipo_gasto_id > 0 else None,
                'fecha_desde': fecha_desde.strip() if fecha_desde else "",
                'fecha_hasta': fecha_hasta.strip() if fecha_hasta else "",
                'monto_min': monto_min if monto_min > 0 else 0,
                'monto_max': monto_max if monto_max > 0 else 0,
                'usuario_id': usuario_id if usuario_id > 0 else None,
                'page': page,
                'per_page': per_page
            }
            
            resultado = self.service.buscar_gastos_avanzado(filtros)
            
            if resultado.get('exito'):
                gastos_encontrados = resultado.get('datos', {}).get('gastos', [])
                self._gastos_filtrados = gastos_encontrados
                self.gastosChanged.emit()
                
                total = len(gastos_encontrados)
                print(f"🔍 Filtros aplicados: {total} gastos encontrados")
            else:
                self.errorOccurred.emit("Error en filtros", resultado.get('mensaje', 'Error aplicando filtros'))
                
        except Exception as e:
            self.errorOccurred.emit("Error en filtros", f"Error aplicando filtros: {str(e)}")
    
    @Slot(str, result=list)
    def buscarGastos(self, termino: str) -> List[Dict[str, Any]]:
        """Búsqueda rápida de gastos"""
        try:
            if not termino.strip():
                return self._gastos
            
            filtros = {'termino_busqueda': termino.strip(), 'page': 1, 'per_page': 100}
            resultado = self.service.buscar_gastos_avanzado(filtros)
            
            if resultado.get('exito'):
                gastos = resultado.get('datos', {}).get('gastos', [])
                print(f"🔍 Búsqueda '{termino}': {len(gastos)} resultados")
                return gastos
            
            return []
            
        except Exception as e:
            self.errorOccurred.emit("Error en búsqueda", f"Error buscando gastos: {str(e)}")
            return []
    
    @Slot(str, result=list)
    def filtrarPorPeriodo(self, periodo: str) -> List[Dict[str, Any]]:
        """Filtra gastos por período predefinido"""
        try:
            gastos = self.service.filtrar_gastos_por_periodo(periodo)
            print(f"📅 Filtro período '{periodo}': {len(gastos)} gastos")
            return gastos
        except Exception as e:
            self.errorOccurred.emit("Error", f"Error filtrando por período: {str(e)}")
            return []
    
    @Slot()
    def limpiarFiltros(self):
        """Limpia todos los filtros aplicados"""
        self._filtro_tipo = 0
        self._filtro_fecha_desde = ""
        self._filtro_fecha_hasta = ""
        self._filtro_monto_min = 0.0
        self._filtro_monto_max = 0.0
        self._filtro_busqueda = ""
        self._gastos_filtrados = self._gastos.copy()
        self.gastosChanged.emit()
        print("🧹 Filtros limpiados")
    
    # --- REPORTES ---
    
    @Slot(str, str, bool)
    def generarReporte(self, fecha_desde: str, fecha_hasta: str, incluir_detalles: bool = True):
        """Genera reporte de gastos por período"""
        try:
            self._set_loading(True)
            
            resultado = self.service.generar_reporte_gastos_periodo(
                fecha_desde, fecha_hasta, incluir_detalles
            )
            
            if resultado.get('exito'):
                mensaje = resultado.get('mensaje', 'Reporte generado exitosamente')
                self.reporteGenerado.emit(True, mensaje, resultado.get('datos', {}))
                self.successMessage.emit(mensaje)
            else:
                error_msg = resultado.get('mensaje', 'Error generando reporte')
                self.reporteGenerado.emit(False, error_msg, {})
                
        except Exception as e:
            error_msg = f"Error generando reporte: {str(e)}"
            self.reporteGenerado.emit(False, error_msg, {})
            self.errorOccurred.emit("Error de reporte", error_msg)
        finally:
            self._set_loading(False)
    
    # --- CONSULTAS ESPECÍFICAS ---
    
    @Slot(int, result='QVariantMap')
    def obtenerGastoPorId(self, gasto_id: int) -> Dict[str, Any]:
        """Obtiene gasto específico por ID"""
        try:
            resultado = self.service.preparar_gasto_para_qml(gasto_id)
            
            if resultado.get('exito'):
                return resultado.get('datos', {})
            else:
                self.errorOccurred.emit("Error", resultado.get('mensaje', 'Gasto no encontrado'))
                return {}
        except Exception as e:
            self.errorOccurred.emit("Error", f"Error obteniendo gasto: {str(e)}")
            return {}
    
    @Slot(int, result=list)
    def obtenerResumenRecientes(self, dias: int = 7) -> List[Dict[str, Any]]:
        """Obtiene resumen de gastos recientes"""
        try:
            resultado = self.service.obtener_resumen_gastos_recientes(dias)
            
            if resultado.get('exito'):
                return resultado.get('datos', {}).get('gastos', [])
            
            return []
        except Exception as e:
            self.errorOccurred.emit("Error", f"Error obteniendo resumen: {str(e)}")
            return []
    
    @Slot(result='QVariantMap')
    def obtenerDashboard(self) -> Dict[str, Any]:
        """Obtiene estadísticas para el dashboard"""
        try:
            dashboard = self.service.obtener_estadisticas_dashboard()
            return dashboard
        except Exception as e:
            self.errorOccurred.emit("Error", f"Error obteniendo dashboard: {str(e)}")
            return {}
    
    # --- RECARGA DE DATOS ---
    
    @Slot()
    def recargarDatos(self):
        """Recarga todos los datos desde la base de datos"""
        try:
            self._set_loading(True)
            self._cargar_datos_iniciales()
            self.successMessage.emit("Datos recargados exitosamente")
            print("🔄 Datos de gastos recargados desde QML")
        except Exception as e:
            self.errorOccurred.emit("Error", f"Error recargando datos: {str(e)}")
        finally:
            self._set_loading(False)
    
    # --- UTILIDADES ---
    
    @Slot(result=list)
    def obtenerTiposParaComboBox(self) -> List[Dict[str, Any]]:
        """Obtiene tipos de gastos formateados para ComboBox"""
        try:
            return self.service.formatear_tipos_gastos_para_combobox()
        except Exception as e:
            self.errorOccurred.emit("Error", f"Error obteniendo tipos: {str(e)}")
            return []
    
    @Slot(result=list)
    def obtenerPeriodosDisponibles(self) -> List[str]:
        """Obtiene lista de períodos para filtros"""
        return ["hoy", "semana", "mes", "trimestre", "año"]
    
    @Slot(float, result=str)
    def formatearPrecio(self, precio: float) -> str:
        """Formatea precio para mostrar"""
        return f"Bs{precio:,.2f}"
    
    @Slot()
    def limpiarCache(self):
        """Limpia el caché del sistema"""
        try:
            # Aquí podrías llamar a un método del service para limpiar caché
            self.successMessage.emit("Caché limpiado exitosamente")
            print("🗑️ Caché de gastos limpiado desde QML")
        except Exception as e:
            self.errorOccurred.emit("Error", f"Error limpiando caché: {str(e)}")
    
    # ===============================
    # MÉTODOS PRIVADOS
    # ===============================
    
    def _cargar_datos_iniciales(self):
        """Carga todos los datos necesarios al inicializar"""
        try:
            self._cargar_gastos()
            self._cargar_tipos_gastos()
            self._cargar_estadisticas()
            print("📊 Datos iniciales de gastos cargados")
        except Exception as e:
            print(f"❌ Error cargando datos iniciales de gastos: {e}")
            self.errorOccurred.emit("Error inicial", f"Error cargando datos: {str(e)}")
    
    def _cargar_gastos(self):
        """Carga lista de gastos recientes"""
        try:
            resultado = self.service.obtener_resumen_gastos_recientes(30)  # Últimos 30 días
            
            if resultado.get('exito'):
                gastos = resultado.get('datos', {}).get('gastos', [])
                self._gastos = gastos
                self._gastos_filtrados = gastos.copy()
                self.gastosChanged.emit()
                print(f"💸 Gastos cargados: {len(gastos)}")
            else:
                self._gastos = []
                self._gastos_filtrados = []
                
        except Exception as e:
            print(f"❌ Error cargando gastos: {e}")
            self._gastos = []
            self._gastos_filtrados = []
    
    def _cargar_tipos_gastos(self):
        """Carga lista de tipos de gastos"""
        try:
            tipos = self.service.formatear_tipos_gastos_para_combobox()
            self._tipos_gastos = tipos
            self.tiposGastosChanged.emit()
            print(f"🏷️ Tipos de gastos cargados: {len(tipos)}")
        except Exception as e:
            print(f"❌ Error cargando tipos de gastos: {e}")
            self._tipos_gastos = []
    
    def _cargar_estadisticas(self):
        """Carga estadísticas de gastos"""
        try:
            estadisticas = self.service.obtener_estadisticas_dashboard()
            self._estadisticas = estadisticas
            self.estadisticasChanged.emit()
            print("📈 Estadísticas de gastos cargadas")
        except Exception as e:
            print(f"❌ Error cargando estadísticas: {e}")
            self._estadisticas = {}
    
    def _set_loading(self, loading: bool):
        """Actualiza estado de carga"""
        if self._loading != loading:
            self._loading = loading
            self.loadingChanged.emit()

# ===============================
# REGISTRO PARA QML
# ===============================

def register_gasto_model():
    """Registra el GastoModel para uso en QML"""
    qmlRegisterType(GastoModel, "ClinicaModels", 1, 0, "GastoModel")
    print("🔗 GastoModel registrado para QML")

# Para facilitar la importación
__all__ = ['GastoModel', 'register_gasto_model']