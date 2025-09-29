from typing import List, Dict, Any, Optional
from PySide6.QtCore import QObject, Signal, Slot, Property
from PySide6.QtQml import qmlRegisterType
from datetime import datetime

from ..repositories.gasto_repository import GastoRepository
from ..core.excepciones import ExceptionHandler, ValidationError
from ..core.Signals_manager import get_global_signals

class GastoModel(QObject):
    """
    Model QObject para gestión de gastos en QML - CON AUTENTICACIÓN ESTANDARIZADA
    """
    
    # ===============================
    # SIGNALS - Notificaciones a QML
    # ===============================
    
    # Señales para cambios en datos
    gastosChanged = Signal()
    tiposGastosChanged = Signal()
    proveedoresChanged = Signal()
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
    operacionError = Signal(str, arguments=['mensaje'])  # Para compatibilidad
    operacionExitosa = Signal(str, arguments=['mensaje'])
    
    def __init__(self, parent=None):
        super().__init__(parent)
        
        # Repository en lugar de service
        self.repository = GastoRepository()
        self.global_signals = get_global_signals()
        self._conectar_senales_globales()
    
        # ✅ AUTENTICACIÓN ESTANDARIZADA
        self._usuario_actual_id = 0  # Cambio de hardcoded a dinámico
        print("💸 GastoModel inicializado - Esperando autenticación")
        
        # Estado interno
        self._gastos: List[Dict[str, Any]] = []
        self._gastos_filtrados: List[Dict[str, Any]] = []
        self._tipos_gastos: List[Dict[str, Any]] = []
        self._proveedores: List[Dict[str, Any]] = []
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
    
    # ===============================
    # ✅ MÉTODO REQUERIDO PARA APPCONTROLLER
    # ===============================
    
    @Slot(int)
    def set_usuario_actual(self, usuario_id: int):
        """Establece el usuario actual para las operaciones"""
        try:
            if usuario_id > 0:
                self._usuario_actual_id = usuario_id
                print(f"👤 Usuario autenticado establecido en GastoModel: {usuario_id}")
                self.operacionExitosa.emit(f"Usuario {usuario_id} establecido en módulo de gastos")
            else:
                print(f"⚠️ ID de usuario inválido en GastoModel: {usuario_id}")
                self.operacionError.emit("ID de usuario inválido")
        except Exception as e:
            print(f"❌ Error estableciendo usuario en GastoModel: {e}")
            self.operacionError.emit(f"Error estableciendo usuario: {str(e)}")

    @Slot(int, str)
    def set_usuario_actual_con_rol(self, usuario_id: int, usuario_rol: str):
        """Establece usuario actual CON ROL"""
        try:
            self._usuario_actual_id = usuario_id
            self._usuario_actual_rol = usuario_rol.strip()  # ✅ Agregar esta línea
            print(f"👤 Usuario {usuario_id} con rol '{usuario_rol}' establecido en GastoModel")
            self.operacionExitosa.emit(f"Usuario {usuario_id} ({usuario_rol}) establecido")
        except Exception as e:
            print(f"❌ Error: {e}")
            self.operacionError.emit(f"Error: {str(e)}")
    
    @Property(int, notify=operacionExitosa)
    def usuario_actual_id(self):
        """Property para obtener el usuario actual"""
        return self._usuario_actual_id

    @Slot(int, result=bool)
    def puedeEditarGasto(self, gasto_id: int) -> bool:
        """Verifica si el usuario puede editar el gasto (para QML)"""
        if not self._verificar_autenticacion():
            return False
        return self._puede_editar_gasto(gasto_id)

    @Slot(result=bool)
    def puedeEliminarGastos(self) -> bool:
        """Verifica si el usuario puede eliminar gastos (para QML)"""
        return self._es_administrador()
    
    @Slot(result=bool)
    def esAdministrador(self) -> bool:
        """Verifica si el usuario es administrador (para QML)"""
        return self._es_administrador()
    
    # ===============================
    # PROPIEDADES DE AUTENTICACIÓN
    # ===============================
    
    def _verificar_autenticacion(self) -> bool:
        """Verifica si el usuario está autenticado"""
        if self._usuario_actual_id <= 0:
            self.operacionError.emit("Usuario no autenticado. Por favor inicie sesión.")
            return False
        return True
    
    def _es_administrador(self) -> bool:
        """Verifica si el usuario actual es administrador"""
        try:
            # Usar rol almacenado directamente (como en laboratorio_model)
            if hasattr(self, '_usuario_actual_rol'):
                es_admin = self._usuario_actual_rol == "Administrador"
                #print(f"🔐 Verificando rol: '{self._usuario_actual_rol}' -> Admin: {es_admin}")
                return es_admin
            
            print("⚠️ No hay rol almacenado")
            return False
            
        except Exception as e:
            print(f"Error verificando rol: {e}")
            return False

    def _puede_editar_gasto(self, gasto_id: int) -> bool:
        """Verifica si el usuario puede editar el gasto"""
        if self._es_administrador():
            return True
        
        # Query simplificado solo para verificación
        try:
            query = "SELECT Id_RegistradoPor, Fecha FROM Gastos WHERE id = ?"
            result = self.repository._execute_query(query, (gasto_id,), fetch_one=True)
            
            if not result:
                return False
            
            # Verificar que sea el creador
            if result.get('Id_RegistradoPor') != self._usuario_actual_id:
                return False
            
            # Verificar que sea < 30 días
            from datetime import datetime
            fecha_creacion = result.get('Fecha')
            if isinstance(fecha_creacion, str):
                fecha_creacion = datetime.strptime(fecha_creacion[:10], '%Y-%m-%d')
            elif not isinstance(fecha_creacion, datetime):
                return False
            
            dias_transcurridos = (datetime.now() - fecha_creacion).days
            return dias_transcurridos <= 30
            
        except Exception as e:
            print(f"Error verificando permisos: {e}")
            return False
        
    # ===============================
    # CONEXIONES Y FUNCIONES HELPER (SIN CAMBIOS)
    # ===============================
    
    def _conectar_senales_globales(self):
        """Conecta con las señales globales para recibir actualizaciones"""
        try:
            self.global_signals.tiposGastosModificados.connect(self._actualizar_tipos_gastos_desde_signal)
            self.global_signals.configuracionGastosNecesitaActualizacion.connect(self._manejar_actualizacion_global)
            self.global_signals.gastosNecesitaActualizacion.connect(self._manejar_actualizacion_global)
            #print("🔗 Señales globales conectadas en GastoModel")
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
    # PROPERTIES - Datos para QML (SIN CAMBIOS)
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
        """Lista de proveedores disponibles"""
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
    # ✅ OPERACIONES CRUD GASTOS - CON VERIFICACIÓN DE AUTENTICACIÓN
    # ===============================
    
    @Slot(int, float, str, str, str, result=bool)
    def crearGasto(self, tipo_gasto_id: int, monto: float, descripcion: str = "", 
                   fecha_gasto: str = "", proveedor: str = "") -> bool:
        """Crea nuevo gasto - ✅ CON VERIFICACIÓN DE AUTENTICACIÓN"""
        try:
            # ✅ VERIFICAR AUTENTICACIÓN PRIMERO
            if not self._verificar_autenticacion():
                return False
            
            self._set_loading(True)
            
            print(f"💰 Creando gasto - Usuario: {self._usuario_actual_id}")
            print(f"   - tipo_gasto_id: {tipo_gasto_id}")
            print(f"   - monto: {monto}")
            print(f"   - descripcion: '{descripcion}'")
            print(f"   - fecha_gasto: '{fecha_gasto}'")
            print(f"   - proveedor: '{proveedor}'")
            
            fecha_obj = None
            if fecha_gasto:
                try:
                    # Convertir fecha desde QML
                    fecha_solo = datetime.strptime(fecha_gasto, '%Y-%m-%d').date()
                    # Obtener hora actual
                    hora_actual = datetime.now().time()
                    # Combinar fecha del usuario con hora actual
                    fecha_obj = datetime.combine(fecha_solo, hora_actual)
                    print(f"   - fecha_obj convertida: {fecha_obj}")
                except Exception as e:
                    print(f"   - Error convirtiendo fecha: {e}")
                    fecha_obj = None
            proveedor_final = proveedor.strip() if proveedor else None
            
            # ✅ USAR usuario_actual_id EN LUGAR DE PARÁMETRO
            gasto_id = self.repository.create_expense(
                tipo_gasto_id=tipo_gasto_id,
                monto=monto,
                usuario_id=self._usuario_actual_id,  # ✅ USAR USUARIO AUTENTICADO
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
                
                print(f"✅ Gasto creado por usuario {self._usuario_actual_id}: {monto}")
                return True
            else:
                error_msg = "Error creando gasto"
                self.gastoCreado.emit(False, error_msg)
                return False
                
        except Exception as e:
            error_msg = f"Error inesperado: {str(e)}"
            print(f"⚠ Exception en crearGasto: {error_msg}")
            self.gastoCreado.emit(False, error_msg)
            self.errorOccurred.emit("Error crítico", error_msg)
            return False
        finally:
            self._set_loading(False)
    
    @Slot(int, float, int, str, str, str, result=bool) 
    def actualizarGasto(self, gasto_id: int, monto: float = 0, tipo_gasto_id: int = 0, 
                descripcion: str = "", proveedor: str = "", fecha_gasto: str = "") -> bool:
        """Actualiza gasto existente - ✅ CON VERIFICACIÓN DE AUTENTICACIÓN"""
        try:
            # ✅ VERIFICAR AUTENTICACIÓN
            if not self._verificar_autenticacion():
                return False
            
            if not self._puede_editar_gasto(gasto_id):
                mensaje_error = "No tienes permisos para editar este gasto"
                if not self._es_administrador():
                    mensaje_error += " (solo puedes editar tus gastos dentro de 30 días)"
                self.operacionError.emit(mensaje_error)
                return False
            
            self._set_loading(True)
            
            print(f"✏️ Actualizando gasto ID: {gasto_id} por usuario: {self._usuario_actual_id}")
            
            kwargs = {}
            if monto > 0:
                kwargs['monto'] = monto
            if tipo_gasto_id > 0:
                kwargs['tipo_gasto_id'] = tipo_gasto_id
            if descripcion:  
                kwargs['descripcion'] = descripcion
            if proveedor:
                kwargs['proveedor'] = proveedor.strip()
            
            if fecha_gasto:
                try:
                    fecha_obj = datetime.strptime(fecha_gasto, '%Y-%m-%d')
                    kwargs['fecha'] = fecha_obj
                except Exception as e:
                    print(f"Error convirtiendo fecha: {e}")
            
            success = self.repository.update_expense(gasto_id, **kwargs)
            
            if success:
                self._cargar_gastos()
                
                mensaje = "Gasto actualizado exitosamente"
                self.gastoActualizado.emit(True, mensaje)
                self.successMessage.emit(mensaje)
                
                print(f"✅ Gasto actualizado por usuario {self._usuario_actual_id}")
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
        """Elimina un gasto (solo administradores)"""
        try:
            print(f"🗑️ Eliminando gasto ID: {gasto_id}")
            print(f"🔐 Verificando permisos de admin...")
            
            es_admin = self._es_administrador()
            print(f"🔐 Es administrador: {es_admin}")
            
            if not es_admin:
                print("❌ No es administrador")
                return False
            
            print(f"🗑️ Llamando repository.delete_expense({gasto_id})")    
            resultado = self.repository.delete_expense(gasto_id)
            print(f"🗑️ Resultado repository: {resultado}")
            
            if resultado:
                print("✅ Emitiendo señal gastosChanged")
                self.gastosChanged.emit()  # ← Cambio aquí
                return True
            return False
            
        except Exception as e:
            print(f"❌ Error eliminando gasto: {e}")
            return False
    
    # ===============================
    # ✅ OPERACIONES CRUD TIPOS GASTOS - CON VERIFICACIÓN DE AUTENTICACIÓN
    # ===============================
    
    @Slot(str, result=bool)
    def crearTipoGasto(self, nombre: str) -> bool:
        """Crea nuevo tipo de gasto - ✅ CON VERIFICACIÓN DE AUTENTICACIÓN"""
        try:
            # ✅ VERIFICAR AUTENTICACIÓN
            if not self._verificar_autenticacion():
                return False
            
            self._set_loading(True)
            
            print(f"📂 Creando tipo de gasto por usuario: {self._usuario_actual_id}")
            
            tipo_id = self.repository.create_expense_type(nombre.strip())
            
            if tipo_id:
                self._cargar_tipos_gastos()
                
                mensaje = f"Tipo de gasto creado exitosamente - ID: {tipo_id}"
                self.tipoGastoCreado.emit(True, mensaje)
                self.successMessage.emit(mensaje)
                self.global_signals.notificar_cambio_tipos_gastos("creado", tipo_id, nombre.strip())
                print(f"✅ Tipo gasto creado por usuario {self._usuario_actual_id}: {nombre}")
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
        """Actualiza tipo de gasto - ✅ CON VERIFICACIÓN DE AUTENTICACIÓN"""
        try:
            # ✅ VERIFICAR AUTENTICACIÓN
            if not self._verificar_autenticacion():
                return False
            
            self._set_loading(True)
            
            print(f"✏️ Actualizando tipo gasto ID: {tipo_id} por usuario: {self._usuario_actual_id}")
            
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
        """Elimina tipo de gasto - ✅ CON VERIFICACIÓN DE AUTENTICACIÓN"""
        try:
            # ✅ VERIFICAR AUTENTICACIÓN
            if not self._verificar_autenticacion():
                return False
            
            self._set_loading(True)
            
            print(f"🗑️ Eliminando tipo gasto ID: {tipo_id} por usuario: {self._usuario_actual_id}")
            
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
    
    # ===============================
    # GESTIÓN DE PROVEEDORES (SIN VERIFICACIÓN - LECTURA)
    # ===============================
    
    @Slot(result=list)
    def obtenerProveedoresParaComboBox(self) -> List[Dict[str, Any]]:
        """Obtiene proveedores formateados para ComboBox"""
        try:
            proveedores_combo = self.repository.get_providers_for_combobox()
            return self._convert_dates_for_qml(proveedores_combo)
        except Exception as e:
            self.errorOccurred.emit("Error", f"Error obteniendo proveedores: {str(e)}")
            return []
    
    @Slot(str, result='QVariantMap')
    def obtenerProveedorPorNombre(self, nombre: str) -> Dict[str, Any]:
        """Busca proveedor por nombre exacto"""
        try:
            proveedor = self.repository.get_provider_by_name(nombre)
            return self._convert_dates_for_qml(proveedor) if proveedor else {}
        except Exception as e:
            self.errorOccurred.emit("Error", f"Error buscando proveedor: {str(e)}")
            return {}
    
    @Slot(str, result=bool)
    def proveedorExiste(self, nombre: str) -> bool:
        """Verifica si existe un proveedor con el nombre dado"""
        try:
            return self.repository.provider_exists(nombre)
        except Exception as e:
            self.errorOccurred.emit("Error", f"Error verificando proveedor: {str(e)}")
            return False
    
    @Slot()
    def recargarProveedores(self):
        """Recarga lista de proveedores"""
        try:
            self._cargar_proveedores()
            self.successMessage.emit("Proveedores recargados exitosamente")
            print("🔄 Proveedores recargados desde QML")
        except Exception as e:
            self.errorOccurred.emit("Error", f"Error recargando proveedores: {str(e)}")
    
    # ===============================
    # BÚSQUEDA Y FILTROS (SIN VERIFICACIÓN - LECTURA)
    # ===============================
    
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
    
    # ===============================
    # REPORTES (SIN VERIFICACIÓN - LECTURA)
    # ===============================
    
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

    def set_auth_model_ref(self, auth_model):
        """Establece referencia al modelo de autenticación"""
        self._auth_model_ref = auth_model
        print("🔐 Referencia AuthModel establecida en GastoModel")
    
    # ===============================
    # CONSULTAS ESPECÍFICAS (SIN VERIFICACIÓN - LECTURA)
    # ===============================
    
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
    
    # ===============================
    # RECARGA DE DATOS (SIN VERIFICACIÓN - LECTURA)
    # ===============================
    
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
    
    # ===============================
    # UTILIDADES (SIN VERIFICACIÓN)
    # ===============================
    
    @Slot(result=list)
    def obtenerTiposParaComboBox(self) -> List[Dict[str, Any]]:
        """Obtiene tipos de gastos formateados para ComboBox"""
        try:
            tipos_formateados = []
            
            tipos_formateados.append({
                'id': 0,
                'text': 'Todos los tipos',
                'data': {}
            })
            
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
    # PAGINACIÓN (SIN VERIFICACIÓN - LECTURA)
    # ===============================
    
    @Slot(int, int, 'QVariantMap', result=list)
    def obtenerGastosPaginados(self, offset: int, limit: int, filters: Dict[str, Any] = None) -> List[Dict[str, Any]]:
        """Obtiene gastos paginados desde QML"""
        try:
            if offset < 0:
                offset = 0
            if limit <= 0:
                limit = 10
            
            processed_filters = {}
            if filters:
                if 'tipo_id' in filters:
                    processed_filters['tipo_id'] = filters['tipo_id']
                
                if 'mes' in filters and 'año' in filters:
                    mes_valor = filters['mes']
                    año_valor = filters['año']
                    
                    if mes_valor == 0:
                        pass  
                    elif mes_valor == -1:
                        processed_filters['mes'] = -1
                        processed_filters['año'] = año_valor
                    else:
                        processed_filters['mes'] = mes_valor
                        processed_filters['año'] = año_valor
            
            gastos = self.repository.get_paginated_expenses(offset, limit, processed_filters)
            
            gastos_convertidos = []
            for gasto in gastos:
                gasto_convertido = {}
                for key, value in gasto.items():
                    if key == 'Fecha' and value:
                        if hasattr(value, 'strftime'):
                            gasto_convertido[key] = value.strftime('%Y-%m-%d')
                        elif isinstance(value, str):
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
            
            #print(f"✅ Gastos paginados obtenidos: {len(gastos_convertidos)}")
            return gastos_convertidos
            
        except Exception as e:
            error_msg = f"Error obteniendo gastos: {str(e)}"
            self.errorOccurred.emit("Error", error_msg)
            return []

    @Slot('QVariantMap', result=int)
    def obtenerTotalGastos(self, filters: Dict[str, Any] = None) -> int:
        """Obtiene total de gastos con filtros"""
        try:
            processed_filters = {}
            if filters:
                if 'tipo_id' in filters:
                    processed_filters['tipo_id'] = filters['tipo_id']
                
                if 'mes' in filters and 'año' in filters:
                    mes_valor = filters['mes']
                    año_valor = filters['año']
                    
                    if mes_valor == 0:
                        pass  
                    elif mes_valor == -1:
                        processed_filters['mes'] = -1
                        processed_filters['año'] = año_valor
                    else:
                        processed_filters['mes'] = mes_valor
                        processed_filters['año'] = año_valor
            
            total = self.repository.get_expenses_count(processed_filters)
            return total
        except Exception as e:
            self.errorOccurred.emit("Error", f"Error contando gastos: {str(e)}")
            return 0
    
    @Slot(int, result=int)
    def diasParaEditar(self, gasto_id: int) -> int:
        """Obtiene días restantes para editar (solo para médicos)"""
        if self._es_administrador():
            return -1  # Sin límite
        
        try:
            query = "SELECT Fecha FROM Gastos WHERE id = ? AND Id_RegistradoPor = ?"
            result = self.repository._execute_query(query, (gasto_id, self._usuario_actual_id), fetch_one=True)
            
            if not result:
                return 0
            
            from datetime import datetime
            fecha_creacion = result.get('Fecha')
            if isinstance(fecha_creacion, str):
                fecha_creacion = datetime.strptime(fecha_creacion[:10], '%Y-%m-%d')
            
            dias_transcurridos = (datetime.now() - fecha_creacion).days
            return max(0, 30 - dias_transcurridos)
            
        except:
            return 0

    # ===============================
    # MÉTODOS PRIVADOS (SIN CAMBIOS)
    # ===============================
    
    def _cargar_datos_iniciales(self):
        """Carga todos los datos necesarios al inicializar"""
        try:
            self._cargar_gastos()
            self._cargar_tipos_gastos()
            self._cargar_proveedores()
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
        """Carga lista de proveedores"""
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
            
            if hasattr(self.repository, 'invalidate_expense_caches'):
                self.repository.invalidate_expense_caches()
                print("🗑️ Cache de tipos invalidado en GastoModel")
            
            self._cargar_tipos_gastos()
            print("✅ Tipos de gastos actualizados desde señal global en GastoModel")
        except Exception as e:
            print(f"❌ Error actualizando tipos desde señal: {e}")
    
    @Slot(str)
    def _manejar_actualizacion_global(self, mensaje: str):
        """Maneja actualizaciones globales de gastos"""
        try:
            print(f"📡 GastoModel: {mensaje}")
            self.tiposGastosChanged.emit()
        except Exception as e:
            print(f"❌ Error manejando actualización global: {e}")

    def emergency_disconnect(self):
        """Desconexión de emergencia para GastoModel"""
        try:
            print("🚨 GastoModel: Iniciando desconexión de emergencia...")
            
            # Establecer estado shutdown
            self._loading = False
            self._usuario_actual_id = 0
            
            # Limpiar datos
            self._gastos = []
            self._gastos_filtrados = []
            self._tipos_gastos = []
            self._proveedores = []
            self._estadisticas = {}
            
            # Desconectar señales globales
            try:
                if hasattr(self, 'global_signals'):
                    self.global_signals.tiposGastosModificados.disconnect(self._actualizar_tipos_gastos_desde_signal)
                    self.global_signals.configuracionGastosNecesitaActualizacion.disconnect(self._manejar_actualizacion_global)
                    self.global_signals.gastosNecesitaActualizacion.disconnect(self._manejar_actualizacion_global)
            except:
                pass
            
            self.repository = None
            
            print("✅ GastoModel: Desconexión de emergencia completada")
            
        except Exception as e:
            print(f"❌ Error en desconexión GastoModel: {e}")

# ===============================
# REGISTRO PARA QML
# ===============================

def register_gasto_model():
    """Registra el GastoModel para uso en QML"""
    qmlRegisterType(GastoModel, "ClinicaModels", 1, 0, "GastoModel")
    print("📗 GastoModel con autenticación registrado para QML")

__all__ = ['GastoModel', 'register_gasto_model']