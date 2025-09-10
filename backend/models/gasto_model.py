from typing import List, Dict, Any, Optional
from PySide6.QtCore import QObject, Signal, Slot, Property
from PySide6.QtQml import qmlRegisterType
from datetime import datetime

from ..repositories.gasto_repository import GastoRepository
from ..core.excepciones import ExceptionHandler, ValidationError
from ..core.Signals_manager import get_global_signals

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
    proveedoresChanged = Signal()  # NUEVA SEÑAL
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
        self.global_signals = get_global_signals()
        self._conectar_senales_globales()
    
        # Estado interno
        self._gastos: List[Dict[str, Any]] = []
        self._gastos_filtrados: List[Dict[str, Any]] = []
        self._tipos_gastos: List[Dict[str, Any]] = []
        self._proveedores: List[Dict[str, Any]] = []  # NUEVA PROPIEDAD
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
        
        print("💸 GastoModel inicializado con soporte para proveedores")
    
    # ===============================
    # FUNCIÓN HELPER PARA FECHAS QML
    # ===============================
    def _conectar_senales_globales(self):
        """Conecta con las señales globales para recibir actualizaciones"""
        try:
            # Conectar señales de tipos de gastos
            self.global_signals.tiposGastosModificados.connect(self._actualizar_tipos_gastos_desde_signal)
            self.global_signals.configuracionGastosNecesitaActualizacion.connect(self._manejar_actualizacion_global)
            self.global_signals.gastosNecesitaActualizacion.connect(self._manejar_actualizacion_global)
            
            print("🔗 Señales globales conectadas en GastoModel")
        except Exception as e:
            print(f"❌ Error conectando señales globales en GastoModel: {e}")
    def _convert_dates_for_qml(self, data: Any) -> Any:
        """Convierte fechas Python datetime a strings para compatibilidad con QML"""
        if isinstance(data, list):
            return [self._convert_dates_for_qml(item) for item in data]
        elif isinstance(data, dict):
            converted = {}
            for key, value in data.items():
                if isinstance(value, datetime):
                    converted[key] = value.strftime('%Y-%m-%d %H:%M:%S')
                elif key.lower() in ['fecha', 'fecha_gasto', 'ultimo_gasto', 'tipo_fecha_creacion'] and value:
                    # Campos específicos de fecha
                    if hasattr(value, 'strftime'):
                        converted[key] = value.strftime('%Y-%m-%d %H:%M:%S')
                    else:
                        converted[key] = str(value)
                else:
                    converted[key] = self._convert_dates_for_qml(value)
            return converted
        else:
            return data
    
    # ===============================
    # PROPERTIES - Datos para QML
    # ===============================
    
    @Property(list, notify=gastosChanged)
    def gastos(self) -> List[Dict[str, Any]]:
        """Lista de gastos para mostrar en QML"""
        return self._convert_dates_for_qml(self._gastos_filtrados)
    
    @Property(list, notify=tiposGastosChanged)
    def tiposGastos(self) -> List[Dict[str, Any]]:
        """Lista de tipos de gastos disponibles"""
        return self._convert_dates_for_qml(self._tipos_gastos)
    
    @Property(list, notify=proveedoresChanged)
    def proveedores(self) -> List[Dict[str, Any]]:
        """Lista de proveedores disponibles - NUEVA PROPIEDAD"""
        return self._convert_dates_for_qml(self._proveedores)
    
    @Property('QVariantMap', notify=estadisticasChanged)
    def estadisticas(self) -> Dict[str, Any]:
        """Estadísticas de gastos"""
        return self._convert_dates_for_qml(self._estadisticas)
    
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
            
            # DEBUG: Imprimir todos los parámetros recibidos
            print(f"🔍 CREANDO GASTO - Parámetros recibidos:")
            print(f"   - tipo_gasto_id: {tipo_gasto_id}")
            print(f"   - monto: {monto}")
            print(f"   - usuario_id: {usuario_id}")
            print(f"   - descripcion: '{descripcion}'")
            print(f"   - fecha_gasto: '{fecha_gasto}'")
            print(f"   - proveedor: '{proveedor}'")
            
            fecha_obj = None
            if fecha_gasto:
                try:
                    fecha_obj = datetime.strptime(fecha_gasto, '%Y-%m-%d')
                    print(f"   - fecha_obj convertida: {fecha_obj}")
                except Exception as e:
                    print(f"   - Error convirtiendo fecha: {e}")
                    fecha_obj = None
            
            # VALIDAR QUE EL PROVEEDOR NO ESTÉ VACÍO
            proveedor_final = proveedor.strip() if proveedor else None
            print(f"   - proveedor_final: '{proveedor_final}'")
            
            # Crear usando repository
            gasto_id = self.repository.create_expense(
                tipo_gasto_id=tipo_gasto_id,
                monto=monto,
                usuario_id=usuario_id,
                fecha=fecha_obj,
                descripcion=descripcion if descripcion else None,
                proveedor=proveedor_final
            )
            
            if gasto_id:
                self._cargar_gastos()
                self._cargar_estadisticas()
                
                mensaje = f"Gasto creado exitosamente - ID: {gasto_id}"
                self.gastoCreado.emit(True, mensaje)
                self.successMessage.emit(mensaje)
                
                print(f"✅ Gasto creado desde QML: {monto} - Proveedor: '{proveedor_final}'")
                return True
            else:
                error_msg = "Error creando gasto"
                self.gastoCreado.emit(False, error_msg)
                print(f"⚠ {error_msg}")
                return False
                
        except Exception as e:
            error_msg = f"Error inesperado: {str(e)}"
            print(f"⚠ Exception en crearGasto: {error_msg}")
            import traceback
            traceback.print_exc()
            
            self.gastoCreado.emit(False, error_msg)
            self.errorOccurred.emit("Error crítico", error_msg)
            return False
        finally:
            self._set_loading(False)
    
    @Slot(int, float, int, str, str, str, result=bool) 
    def actualizarGasto(self, gasto_id: int, monto: float = 0, tipo_gasto_id: int = 0, 
                descripcion: str = "", proveedor: str = "", fecha_gasto: str = "") -> bool:
        """Actualiza gasto existente desde QML (ahora permite actualizar fecha)"""
        try:
            self._set_loading(True)
            
            # DEBUG: Imprimir todos los parámetros recibidos
            print(f"✏️ ACTUALIZANDO GASTO - Parámetros recibidos:")
            print(f"   - gasto_id: {gasto_id}")
            print(f"   - monto: {monto}")
            print(f"   - tipo_gasto_id: {tipo_gasto_id}")
            print(f"   - descripcion: '{descripcion}'")
            print(f"   - proveedor: '{proveedor}'")
            print(f"   - fecha_gasto: '{fecha_gasto}'")
            
            kwargs = {}
            if monto > 0:
                kwargs['monto'] = monto
            if tipo_gasto_id > 0:
                kwargs['tipo_gasto_id'] = tipo_gasto_id
            if descripcion:  
                kwargs['descripcion'] = descripcion
            if proveedor:
                kwargs['proveedor'] = proveedor.strip()
            
            # ✅ NUEVA LÓGICA PARA FECHA
            if fecha_gasto:
                try:
                    fecha_obj = datetime.strptime(fecha_gasto, '%Y-%m-%d')
                    kwargs['fecha'] = fecha_obj
                    print(f"   - fecha_obj convertida: {fecha_obj}")
                except Exception as e:
                    print(f"Error convirtiendo fecha: {e}")
            
            print(f"   - kwargs a enviar: {kwargs}")
            
            success = self.repository.update_expense(gasto_id, **kwargs)
            
            if success:
                self._cargar_gastos()
                
                mensaje = "Gasto actualizado exitosamente"
                self.gastoActualizado.emit(True, mensaje)
                self.successMessage.emit(mensaje)
                
                print(f"✅ Gasto actualizado desde QML: ID {gasto_id} - Proveedor: '{proveedor}'")
                return True
            else:
                error_msg = "Error actualizando gasto"
                self.gastoActualizado.emit(False, error_msg)
                print(f"⚠ {error_msg}")
                return False
                
        except Exception as e:
            error_msg = f"Error inesperado: {str(e)}"
            print(f"⚠ Exception en actualizarGasto: {error_msg}")
            import traceback
            traceback.print_exc()
            
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
                self.global_signals.notificar_cambio_tipos_gastos("creado", tipo_id, nombre.strip())
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
    
    # --- GESTIÓN DE PROVEEDORES - NUEVOS MÉTODOS ---
    
    @Slot(result=list)
    def obtenerProveedoresParaComboBox(self) -> List[Dict[str, Any]]:
        """Obtiene proveedores formateados para ComboBox de QML - NUEVO"""
        try:
            proveedores_combo = self.repository.get_providers_for_combobox()
            return self._convert_dates_for_qml(proveedores_combo)
        except Exception as e:
            self.errorOccurred.emit("Error", f"Error obteniendo proveedores: {str(e)}")
            return []
    
    @Slot(str, result='QVariantMap')
    def obtenerProveedorPorNombre(self, nombre: str) -> Dict[str, Any]:
        """Busca proveedor por nombre exacto - NUEVO"""
        try:
            proveedor = self.repository.get_provider_by_name(nombre)
            return self._convert_dates_for_qml(proveedor) if proveedor else {}
        except Exception as e:
            self.errorOccurred.emit("Error", f"Error buscando proveedor: {str(e)}")
            return {}
    
    @Slot(str, result=bool)
    def proveedorExiste(self, nombre: str) -> bool:
        """Verifica si existe un proveedor con el nombre dado - NUEVO"""
        try:
            return self.repository.provider_exists(nombre)
        except Exception as e:
            self.errorOccurred.emit("Error", f"Error verificando proveedor: {str(e)}")
            return False
    
    @Slot()
    def recargarProveedores(self):
        """Recarga lista de proveedores - NUEVO"""
        try:
            self._cargar_proveedores()
            self.successMessage.emit("Proveedores recargados exitosamente")
            print("🔄 Proveedores recargados desde QML")
        except Exception as e:
            self.errorOccurred.emit("Error", f"Error recargando proveedores: {str(e)}")
    
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
                return self._convert_dates_for_qml(self._gastos)
            
            gastos = self.repository.search_expenses(termino.strip(), limit=100)
            print(f"🔍 Búsqueda '{termino}': {len(gastos)} resultados")
            return self._convert_dates_for_qml(gastos)
            
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
            
            start_date = datetime.strptime(fecha_desde, '%Y-%m-%d') if fecha_desde else None
            end_date = datetime.strptime(fecha_hasta, '%Y-%m-%d') if fecha_hasta else None
            
            gastos_reporte = self.repository.get_expenses_for_report(
                start_date=start_date,
                end_date=end_date
            )
            
            total_gastos = len(gastos_reporte)
            total_monto = sum(g.get('Monto', 0) for g in gastos_reporte)
            
            reporte_data = {
                'gastos': self._convert_dates_for_qml(gastos_reporte),
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
            return self._convert_dates_for_qml(gasto) if gasto else {}
        except Exception as e:
            self.errorOccurred.emit("Error", f"Error obteniendo gasto: {str(e)}")
            return {}
    
    @Slot(int, result=list)
    def obtenerResumenRecientes(self, dias: int = 7) -> List[Dict[str, Any]]:
        """Obtiene resumen de gastos recientes"""
        try:
            gastos = self.repository.get_recent_expenses(dias)
            return self._convert_dates_for_qml(gastos)
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
            return self._convert_dates_for_qml(dashboard)
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
                    'data': self._convert_dates_for_qml(tipo)
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
    # MÉTODOS DE PAGINACIÓN - CORREGIDOS Y MEJORADOS
    # ===============================
    
    @Slot(int, int, 'QVariantMap', result=list)
    def obtenerGastosPaginados(self, offset: int, limit: int, filters: Dict[str, Any] = None) -> List[Dict[str, Any]]:
        """Obtiene gastos paginados desde QML - MEJORADO CON FILTRO "TODOS"""
        try:
            # Validar parámetros
            if offset < 0:
                offset = 0
            if limit <= 0:
                limit = 10
            
            print(f"📊 Obteniendo gastos paginados: offset={offset}, limit={limit}, filters={filters}")
            
            # Procesar filtros para soportar "todos los períodos"
            processed_filters = {}
            if filters:
                # Copiar filtros básicos
                if 'tipo_id' in filters:
                    processed_filters['tipo_id'] = filters['tipo_id']
                
                # Procesar filtros temporales mejorados
                if 'mes' in filters and 'año' in filters:
                    mes_valor = filters['mes']
                    año_valor = filters['año']
                    
                    # mes = 0 significa "todos los períodos"
                    # mes = -1 significa "todo el año especificado"
                    # mes > 0 significa mes específico
                    if mes_valor == 0:
                        # No agregar filtro temporal (mostrar todos)
                        pass  
                    elif mes_valor == -1:
                        # Mostrar todo el año
                        processed_filters['mes'] = -1
                        processed_filters['año'] = año_valor
                    else:
                        # Mes específico
                        processed_filters['mes'] = mes_valor
                        processed_filters['año'] = año_valor
            
            print(f"🔍 Filtros procesados: {processed_filters}")
            
            # Obtener datos del repository
            gastos = self.repository.get_paginated_expenses(offset, limit, processed_filters)
            
            # CONVERSIÓN ESPECÍFICA PARA QML CON FECHAS CORREGIDAS
            gastos_convertidos = []
            for gasto in gastos:
                gasto_convertido = {}
                for key, value in gasto.items():
                    if key == 'Fecha' and value:
                        # Asegurar que la fecha esté en formato string para QML
                        if hasattr(value, 'strftime'):
                            gasto_convertido[key] = value.strftime('%Y-%m-%d')
                        elif isinstance(value, str):
                            # Si ya es string, asegurar formato correcto
                            try:
                                fecha_obj = datetime.strptime(value, '%Y-%m-%d %H:%M:%S')
                                gasto_convertido[key] = fecha_obj.strftime('%Y-%m-%d')
                            except:
                                gasto_convertido[key] = value[:10] if len(value) >= 10 else value
                        else:
                            gasto_convertido[key] = str(value)
                    else:
                        gasto_convertido[key] = value
                
                gastos_convertidos.append(gasto_convertido)
            
            print(f"✅ Gastos paginados obtenidos: {len(gastos_convertidos)}")
            return gastos_convertidos
            
        except Exception as e:
            error_msg = f"Error obteniendo gastos: {str(e)}"
            print(f"⚠ {error_msg}")
            import traceback
            traceback.print_exc()
            self.errorOccurred.emit("Error", error_msg)
            return []

    @Slot('QVariantMap', result=int)
    def obtenerTotalGastos(self, filters: Dict[str, Any] = None) -> int:
        """Obtiene total de gastos con filtros mejorados - INCLUYENDO FILTRO "TODOS"""
        try:
            print(f"📊 Contando gastos con filtros: {filters}")
            
            # Procesar filtros igual que en obtenerGastosPaginados
            processed_filters = {}
            if filters:
                if 'tipo_id' in filters:
                    processed_filters['tipo_id'] = filters['tipo_id']
                
                if 'mes' in filters and 'año' in filters:
                    mes_valor = filters['mes']
                    año_valor = filters['año']
                    
                    if mes_valor == 0:
                        # No agregar filtro temporal (mostrar todos)
                        pass  
                    elif mes_valor == -1:
                        # Mostrar todo el año
                        processed_filters['mes'] = -1
                        processed_filters['año'] = año_valor
                    else:
                        # Mes específico
                        processed_filters['mes'] = mes_valor
                        processed_filters['año'] = año_valor
            
            total = self.repository.get_expenses_count(processed_filters)
            print(f"✅ Total gastos encontrados: {total}")
            return total
        except Exception as e:
            error_msg = f"Error contando gastos: {str(e)}"
            print(f"⚠ {error_msg}")
            self.errorOccurred.emit("Error", error_msg)
            return 0
    
    # ===============================
    # MÉTODOS PRIVADOS
    # ===============================
    
    def _cargar_datos_iniciales(self):
        """Carga todos los datos necesarios al inicializar"""
        try:
            self._cargar_gastos()
            self._cargar_tipos_gastos()
            self._cargar_proveedores()  # NUEVA CARGA
            self._cargar_estadisticas()
            print("📊 Datos iniciales de gastos cargados (incluyendo proveedores)")
        except Exception as e:
            print(f"⚠ Error cargando datos iniciales de gastos: {e}")
            self.errorOccurred.emit("Error inicial", f"Error cargando datos: {str(e)}")
    
    def _cargar_gastos(self):
        """Carga lista de gastos recientes"""
        try:
            gastos = self.repository.get_recent_expenses(180)  # Últimos 180 días
            self._gastos = gastos
            self._gastos_filtrados = gastos.copy()
            self.gastosChanged.emit()
            print(f"💸 Gastos cargados: {len(gastos)}")
        except Exception as e:
            print(f"⚠ Error cargando gastos: {e}")
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
            print(f"⚠ Error cargando tipos de gastos: {e}")
            self._tipos_gastos = []
    
    def _cargar_proveedores(self):
        """Carga lista de proveedores - NUEVO MÉTODO"""
        try:
            proveedores = self.repository.get_all_providers()
            self._proveedores = proveedores
            self.proveedoresChanged.emit()
            print(f"🏢 Proveedores cargados: {len(proveedores)}")
        except Exception as e:
            print(f"⚠ Error cargando proveedores: {e}")
            self._proveedores = []
    
    def _cargar_estadisticas(self):
        """Carga estadísticas de gastos"""
        try:
            estadisticas = self.repository.get_expense_statistics()
            self._estadisticas = estadisticas
            self.estadisticasChanged.emit()
            print("📈 Estadísticas de gastos cargadas")
        except Exception as e:
            print(f"⚠ Error cargando estadísticas: {e}")
            self._estadisticas = {}
    
    def _set_loading(self, loading: bool):
        """Actualiza estado de carga"""
        if self._loading != loading:
            self._loading = loading
            self.loadingChanged.emit()
    @Slot()
    def _actualizar_tipos_gastos_desde_signal(self):
        """Actualiza tipos de gastos cuando recibe señal global"""
        try:
            print("📡 GastoModel: Recibida señal de actualización de tipos de gastos")
            
            # ✅ INVALIDAR CACHE ANTES DE RECARGAR
            if hasattr(self.repository, 'invalidate_expense_caches'):
                self.repository.invalidate_expense_caches()
                print("🗑️ Cache de tipos invalidado en GastoModel")
            # Ahora recargar
            self._cargar_tipos_gastos()
            
            print("✅ Tipos de gastos actualizados desde señal global en GastoModel")
        except Exception as e:
            print(f"❌ Error actualizando tipos desde señal: {e}")
    @Slot(str)
    def _manejar_actualizacion_global(self, mensaje: str):
        """Maneja actualizaciones globales de gastos"""
        try:
            print(f"📡 GastoModel: {mensaje}")
            # Emitir señal para notificar a QML que hay cambios
            self.tiposGastosChanged.emit()
        except Exception as e:
            print(f"❌ Error manejando actualización global: {e}")
# ===============================
# REGISTRO PARA QML
# ===============================

def register_gasto_model():
    """Registra el GastoModel para uso en QML"""
    qmlRegisterType(GastoModel, "ClinicaModels", 1, 0, "GastoModel")
    print("🔗 GastoModel registrado para QML con soporte para proveedores")

# Para facilitar la importación
__all__ = ['GastoModel', 'register_gasto_model']