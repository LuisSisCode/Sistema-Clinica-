from typing import List, Dict, Any, Optional
from PySide6.QtCore import QObject, Signal, Slot, Property
from PySide6.QtQml import qmlRegisterType

from ..repositories.gasto_repository import GastoRepository
from ..core.excepciones import ExceptionHandler, ValidationError

class GastoModel(QObject):
    """
    Model QObject para gestión de gastos en QML
    Conecta la interfaz QML con el GastoRepository
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
        
        # Repository en lugar de service
        self.repository = GastoRepository()
        
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
    
    @Slot(int, float, int, str, str, str, result=bool)
    def crearGasto(self, tipo_gasto_id: int, monto: float, usuario_id: int,
                descripcion: str = "", fecha_gasto: str = "", proveedor: str = "") -> bool:
        """Crea nuevo gasto desde QML"""
        try:
            self._set_loading(True)
            
            from datetime import datetime
            fecha_obj = None
            if fecha_gasto:
                try:
                    fecha_obj = datetime.strptime(fecha_gasto, '%Y-%m-%d')
                except:
                    fecha_obj = None
            
            # Crear usando repository
            gasto_id = self.repository.create_expense(
                tipo_gasto_id=tipo_gasto_id,
                monto=monto,
                usuario_id=usuario_id,
                fecha=fecha_obj,
                descripcion=descripcion if descripcion else None,
                proveedor=proveedor if proveedor else None
            )
            
            if gasto_id:
                self._cargar_gastos()
                self._cargar_estadisticas()
                
                mensaje = f"Gasto creado exitosamente - ID: {gasto_id}"
                self.gastoCreado.emit(True, mensaje)
                self.successMessage.emit(mensaje)
                
                print(f"✅ Gasto creado desde QML: {monto}")
                return True
            else:
                error_msg = "Error creando gasto"
                self.gastoCreado.emit(False, error_msg)
                return False
                
        except Exception as e:
            error_msg = f"Error inesperado: {str(e)}"
            self.gastoCreado.emit(False, error_msg)
            self.errorOccurred.emit("Error crítico", error_msg)
            return False
        finally:
            self._set_loading(False)
    
    @Slot(int, float, int, str, str, result=bool)
    def actualizarGasto(self, gasto_id: int, monto: float = 0, tipo_gasto_id: int = 0, 
                   descripcion: str = "", proveedor: str = "") -> bool:
        """Actualiza gasto existente desde QML"""
        try:
            self._set_loading(True)
            
            kwargs = {}
            if monto > 0:
                kwargs['monto'] = monto
            if tipo_gasto_id > 0:
                kwargs['tipo_gasto_id'] = tipo_gasto_id
            if descripcion:  # ✅ Nuevo campo
                kwargs['descripcion'] = descripcion
            if proveedor:   # ✅ Nuevo campo
                kwargs['proveedor'] = proveedor
            success = self.repository.update_expense(gasto_id, **kwargs)
            
            if success:
                self._cargar_gastos()
                
                mensaje = "Gasto actualizado exitosamente"
                self.gastoActualizado.emit(True, mensaje)
                self.successMessage.emit(mensaje)
                
                print(f"✅ Gasto actualizado desde QML: ID {gasto_id}")
                return True
            else:
                error_msg = "Error actualizando gasto"
                self.gastoActualizado.emit(False, error_msg)
                return False
                
        except Exception as e:
            error_msg = f"Error inesperado: {str(e)}"
            self.gastoActualizado.emit(False, error_msg)
            self.errorOccurred.emit("Error crítico", error_msg)
            return False
        finally:
            self._set_loading(False)
    
    @Slot(int, result=bool)
    def eliminarGasto(self, gasto_id: int) -> bool:
        """Elimina gasto desde QML"""
        try:
            self._set_loading(True)
            
            success = self.repository.delete(gasto_id)
            
            if success:
                self._cargar_gastos()
                self._cargar_estadisticas()
                
                mensaje = "Gasto eliminado exitosamente"
                self.gastoEliminado.emit(True, mensaje)
                self.successMessage.emit(mensaje)
                
                print(f"🗑️ Gasto eliminado desde QML: ID {gasto_id}")
                return True
            else:
                error_msg = "Error eliminando gasto"
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
            
            tipo_id = self.repository.create_expense_type(nombre.strip())
            
            if tipo_id:
                self._cargar_tipos_gastos()
                
                mensaje = f"Tipo de gasto creado exitosamente - ID: {tipo_id}"
                self.tipoGastoCreado.emit(True, mensaje)
                self.successMessage.emit(mensaje)
                
                print(f"✅ Tipo gasto creado desde QML: {nombre}")
                return True
            else:
                error_msg = "Error creando tipo de gasto"
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
            
            success = self.repository.update_expense_type(tipo_id, nombre.strip())
            
            if success:
                self._cargar_tipos_gastos()
                
                mensaje = "Tipo actualizado exitosamente"
                self.tipoGastoActualizado.emit(True, mensaje)
                self.successMessage.emit(mensaje)
                
                return True
            else:
                error_msg = "Error actualizando tipo"
                self.tipoGastoActualizado.emit(False, error_msg)
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
        """Elimina tipo de gasto"""
        try:
            self._set_loading(True)
            
            success = self.repository.delete_expense_type(tipo_id)
            
            if success:
                self._cargar_tipos_gastos()
                
                mensaje = "Tipo eliminado exitosamente"
                self.tipoGastoEliminado.emit(True, mensaje)
                self.successMessage.emit(mensaje)
                
                return True
            else:
                error_msg = "Error eliminando tipo"
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
    
    @Slot(str, int, str, str, float, float)
    def aplicarFiltros(self, termino_busqueda: str, tipo_gasto_id: int, fecha_desde: str, 
                      fecha_hasta: str, monto_min: float, monto_max: float):
        """Aplica filtros avanzados a la lista de gastos"""
        try:
            self._filtro_busqueda = termino_busqueda.strip()
            self._filtro_tipo = tipo_gasto_id
            self._filtro_fecha_desde = fecha_desde
            self._filtro_fecha_hasta = fecha_hasta
            self._filtro_monto_min = monto_min
            self._filtro_monto_max = monto_max
            
            # Aplicar filtros
            gastos_filtrados = self._gastos.copy()
            
            # Filtro por búsqueda
            if termino_busqueda:
                gastos_filtrados = [
                    g for g in gastos_filtrados
                    if (termino_busqueda.lower() in g.get('tipo_nombre', '').lower() or
                        termino_busqueda.lower() in g.get('usuario_nombre', '').lower())
                ]
            
            # Filtro por tipo
            if tipo_gasto_id > 0:
                gastos_filtrados = [
                    g for g in gastos_filtrados
                    if g.get('tipo_id') == tipo_gasto_id
                ]
            
            # Filtro por monto
            if monto_min > 0:
                gastos_filtrados = [
                    g for g in gastos_filtrados
                    if g.get('Monto', 0) >= monto_min
                ]
            
            if monto_max > 0:
                gastos_filtrados = [
                    g for g in gastos_filtrados
                    if g.get('Monto', 0) <= monto_max
                ]
            
            self._gastos_filtrados = gastos_filtrados
            self.gastosChanged.emit()
            
            total = len(gastos_filtrados)
            print(f"🔍 Filtros aplicados: {total} gastos encontrados")
                
        except Exception as e:
            self.errorOccurred.emit("Error en filtros", f"Error aplicando filtros: {str(e)}")
    
    @Slot(str, result=list)
    def buscarGastos(self, termino: str) -> List[Dict[str, Any]]:
        """Búsqueda rápida de gastos"""
        try:
            if not termino.strip():
                return self._gastos
            
            gastos = self.repository.search_expenses(termino.strip(), limit=100)
            print(f"🔍 Búsqueda '{termino}': {len(gastos)} resultados")
            return gastos
            
        except Exception as e:
            self.errorOccurred.emit("Error en búsqueda", f"Error buscando gastos: {str(e)}")
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
            
            from datetime import datetime
            start_date = datetime.strptime(fecha_desde, '%Y-%m-%d') if fecha_desde else None
            end_date = datetime.strptime(fecha_hasta, '%Y-%m-%d') if fecha_hasta else None
            
            gastos_reporte = self.repository.get_expenses_for_report(
                start_date=start_date,
                end_date=end_date
            )
            
            total_gastos = len(gastos_reporte)
            total_monto = sum(g.get('Monto', 0) for g in gastos_reporte)
            
            reporte_data = {
                'gastos': gastos_reporte,
                'total_gastos': total_gastos,
                'total_monto': total_monto,
                'fecha_desde': fecha_desde,
                'fecha_hasta': fecha_hasta
            }
            
            mensaje = f"Reporte generado: {total_gastos} gastos, Total: ${total_monto:,.2f}"
            self.reporteGenerado.emit(True, mensaje, reporte_data)
            self.successMessage.emit(mensaje)
                
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
            gasto = self.repository.get_expense_by_id_complete(gasto_id)
            return gasto if gasto else {}
        except Exception as e:
            self.errorOccurred.emit("Error", f"Error obteniendo gasto: {str(e)}")
            return {}
    
    @Slot(int, result=list)
    def obtenerResumenRecientes(self, dias: int = 7) -> List[Dict[str, Any]]:
        """Obtiene resumen de gastos recientes"""
        try:
            gastos = self.repository.get_recent_expenses(dias)
            return gastos
        except Exception as e:
            self.errorOccurred.emit("Error", f"Error obteniendo resumen: {str(e)}")
            return []
    
    @Slot(result='QVariantMap')
    def obtenerDashboard(self) -> Dict[str, Any]:
        """Obtiene estadísticas para el dashboard"""
        try:
            dashboard = {
                'gastos_hoy': self.repository.get_today_statistics(),
                'estadisticas_generales': self.repository.get_expense_statistics()
            }
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
    
    @Slot(float, result=str)
    def formatearPrecio(self, precio: float) -> str:
        """Formatea precio para mostrar"""
        return f"Bs{precio:,.2f}"
    
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
            gastos = self.repository.get_recent_expenses(180)  # Últimos 30 días
            self._gastos = gastos
            self._gastos_filtrados = gastos.copy()
            self.gastosChanged.emit()
            print(f"💸 Gastos cargados: {len(gastos)}")
        except Exception as e:
            print(f"❌ Error cargando gastos: {e}")
            self._gastos = []
            self._gastos_filtrados = []
    
    def _cargar_tipos_gastos(self):
        """Carga lista de tipos de gastos"""
        try:
            tipos = self.repository.get_all_expense_types()
            self._tipos_gastos = tipos
            self.tiposGastosChanged.emit()
            print(f"🏷️ Tipos de gastos cargados: {len(tipos)}")
        except Exception as e:
            print(f"❌ Error cargando tipos de gastos: {e}")
            self._tipos_gastos = []
    
    def _cargar_estadisticas(self):
        """Carga estadísticas de gastos"""
        try:
            estadisticas = self.repository.get_expense_statistics()
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