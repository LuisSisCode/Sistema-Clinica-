"""
TrabajadorModel - ACTUALIZADO con autenticación estandarizada
Migrado del patrón sin autenticación al patrón de ConsultaModel
"""

from typing import List, Dict, Any, Optional
from PySide6.QtCore import QObject, Signal, Slot, Property
from PySide6.QtQml import qmlRegisterType

from ..repositories.trabajador_repository import TrabajadorRepository
from ..core.excepciones import ExceptionHandler, ValidationError
from ..core.Signals_manager import get_global_signals

class TrabajadorModel(QObject):
    """
    Model QObject para gestión de trabajadores en QML - ACTUALIZADO con autenticación
    Conecta la interfaz QML con el TrabajadorRepository
    """
    
    # ===============================
    # SIGNALS - Notificaciones a QML
    # ===============================
    
    # Señales para cambios en datos
    trabajadoresChanged = Signal()
    tiposTrabajadorChanged = Signal()
    estadisticasChanged = Signal()
    
    # Señales para operaciones
    trabajadorCreado = Signal(bool, str)  # success, message
    trabajadorActualizado = Signal(bool, str)
    trabajadorEliminado = Signal(bool, str)
    
    tipoTrabajadorCreado = Signal(bool, str)
    tipoTrabajadorActualizado = Signal(bool, str)
    tipoTrabajadorEliminado = Signal(bool, str)
    
    # Señales para búsquedas
    busquedaCompleta = Signal(bool, str, int)  # success, message, total
    
    # Señales para UI
    loadingChanged = Signal()
    errorOccurred = Signal(str, str)  # title, message
    successMessage = Signal(str)
    warningMessage = Signal(str)
    operacionError = Signal(str)     # Para compatibilidad
    operacionExitosa = Signal(str)   # Para compatibilidad
    
    def __init__(self, parent=None):
        super().__init__(parent)
        
        # Repository en lugar de service
        self.repository = TrabajadorRepository()
        self.global_signals = get_global_signals()
        self._conectar_senales_globales()
        
        # Estado interno
        self._trabajadores: List[Dict[str, Any]] = []
        self._trabajadores_filtrados: List[Dict[str, Any]] = []
        self._tipos_trabajador: List[Dict[str, Any]] = []
        self._estadisticas: Dict[str, Any] = {}
        self._loading: bool = False
        
        # ✅ AUTENTICACIÓN ESTANDARIZADA - COMO CONSULTAMODEL
        self._usuario_actual_id = 0  # Cambio de hardcoded a dinámico
        print("👷‍♂️ TrabajadorModel inicializado - Esperando autenticación")
        
        # Filtros activos
        self._filtro_tipo: int = 0
        self._filtro_area: str = "Todos"
        self._filtro_busqueda: str = ""
        self._incluir_stats: bool = False
        
        # Configuración inicial
        self._cargar_datos_iniciales()
        
        print("👷‍♂️ TrabajadorModel inicializado con autenticación estandarizada")
    
    # ===============================
    # ✅ MÉTODO REQUERIDO PARA APPCONTROLLER
    # ===============================
    
    def _conectar_senales_globales(self):
        """Conecta con las señales globales para recibir actualizaciones"""
        try:
            # Conectar señales de tipos de trabajadores
            self.global_signals.tiposTrabajadoresModificados.connect(self._actualizar_tipos_trabajadores_desde_signal)
            self.global_signals.trabajadoresNecesitaActualizacion.connect(self._manejar_actualizacion_global)
            
            print("🔗 Señales globales conectadas en TrabajadorModel")
        except Exception as e:
            print(f"❌ Error conectando señales globales en TrabajadorModel: {e}")
    
    @Slot(int)
    def set_usuario_actual(self, usuario_id: int):
        """
        Establece el usuario actual para las operaciones - MÉTODO REQUERIDO por AppController
        """
        try:
            if usuario_id > 0:
                self._usuario_actual_id = usuario_id
                print(f"👤 Usuario autenticado establecido en TrabajadorModel: {usuario_id}")
                self.operacionExitosa.emit(f"Usuario {usuario_id} establecido en módulo de trabajadores")
            else:
                print(f"⚠️ ID de usuario inválido en TrabajadorModel: {usuario_id}")
                self.operacionError.emit("ID de usuario inválido")
        except Exception as e:
            print(f"❌ Error estableciendo usuario en TrabajadorModel: {e}")
            self.operacionError.emit(f"Error estableciendo usuario: {str(e)}")
    
    @Property(int, notify=operacionExitosa)
    def usuario_actual_id(self):
        """Property para obtener el usuario actual"""
        return self._usuario_actual_id
    
    # ===============================
    # PROPIEDADES DE AUTENTICACIÓN
    # ===============================
    
    def _verificar_autenticacion(self) -> bool:
        """Verifica si el usuario está autenticado"""
        if self._usuario_actual_id <= 0:
            self.operacionError.emit("Usuario no autenticado. Por favor inicie sesión.")
            return False
        return True
    
    # ===============================
    # PROPERTIES - Datos para QML (SIN CAMBIOS)
    # ===============================
   
    @Property(list, notify=trabajadoresChanged)
    def trabajadores(self) -> List[Dict[str, Any]]:
        """Lista de trabajadores para mostrar en QML"""
        return self._trabajadores_filtrados
    
    @Property(list, notify=tiposTrabajadorChanged)
    def tiposTrabajador(self) -> List[Dict[str, Any]]:
        """Lista de tipos de trabajador disponibles"""
        return self._tipos_trabajador
    
    @Property('QVariantMap', notify=estadisticasChanged)
    def estadisticas(self) -> Dict[str, Any]:
        """Estadísticas de trabajadores"""
        return self._estadisticas
    
    @Property(bool, notify=loadingChanged)
    def loading(self) -> bool:
        """Estado de carga"""
        return self._loading
    
    @Property(int, notify=trabajadoresChanged)
    def totalTrabajadores(self) -> int:
        """Total de trabajadores filtrados"""
        return len(self._trabajadores_filtrados)
    
    @Property(str)
    def filtroTipo(self) -> str:
        """Filtro actual por tipo"""
        return str(self._filtro_tipo)
    
    @Property(str)
    def filtroArea(self) -> str:
        """Filtro actual por área"""
        return self._filtro_area
    
    @Property(str)
    def filtroBusqueda(self) -> str:
        """Texto de búsqueda actual"""
        return self._filtro_busqueda
    
    # ===============================
    # SLOTS PARA OPERACIONES CRUD TRABAJADORES - ✅ CON VERIFICACIÓN DE AUTENTICACIÓN
    # ===============================
    
    @Slot(str, str, str, int, str, str, result=bool)
    def crearTrabajador(self, nombre: str, apellido_paterno: str, 
                apellido_materno: str, tipo_trabajador_id: int,
                especialidad: str = "", matricula: str = "") -> bool:
        """Crea nuevo trabajador desde QML - ✅ CON VERIFICACIÓN DE AUTENTICACIÓN"""
        # ✅ VERIFICAR AUTENTICACIÓN PRIMERO
        if not self._verificar_autenticacion():
            self.trabajadorCreado.emit(False, "Usuario no autenticado")
            return False
        
        try:
            self._set_loading(True)
            
            print(f"👷‍♂️ Creando trabajador - Usuario: {self._usuario_actual_id}")
            
            trabajador_id = self.repository.create_worker(
                nombre=nombre.strip(),
                apellido_paterno=apellido_paterno.strip(),
                apellido_materno=apellido_materno.strip(),
                tipo_trabajador_id=tipo_trabajador_id
            )

            # Actualizar especialidad y matrícula después de crear
            if trabajador_id and (especialidad.strip() or matricula.strip()):
                self.repository.update_worker(
                    trabajador_id,
                    especialidad=especialidad.strip() if especialidad.strip() else None,
                    matricula=matricula.strip() if matricula.strip() else None
                )
            
            if trabajador_id:
                # Carga inmediata y forzada de datos
                self._cargar_trabajadores()
                self._cargar_tipos_trabajador()
                self._cargar_estadisticas()
                
                # Forzar aplicación de filtros actuales
                self.aplicarFiltros(self._filtro_tipo, self._filtro_busqueda, 
                                self._incluir_stats, self._filtro_area)
                
                mensaje = f"Trabajador creado exitosamente - ID: {trabajador_id}"
                self.trabajadorCreado.emit(True, mensaje)
                self.successMessage.emit(mensaje)
                
                print(f"✅ Trabajador creado desde QML: {nombre} {apellido_paterno}, Usuario: {self._usuario_actual_id}")
                return True
            else:
                error_msg = "Error creando trabajador"
                self.trabajadorCreado.emit(False, error_msg)
                self.errorOccurred.emit("Error de validación", error_msg)
                return False
                
        except Exception as e:
            error_msg = f"Error inesperado: {str(e)}"
            self.trabajadorCreado.emit(False, error_msg)
            self.errorOccurred.emit("Error crítico", error_msg)
            return False
        finally:
            self._set_loading(False)
    
    @Slot(int, str, str, str, int, str, str, result=bool)
    def actualizarTrabajador(self, trabajador_id: int, nombre: str = "", 
                            apellido_paterno: str = "", apellido_materno: str = "",
                            tipo_trabajador_id: int = 0, especialidad: str = "", 
                            matricula: str = "") -> bool:
        """Actualiza trabajador existente - ✅ CON VERIFICACIÓN DE AUTENTICACIÓN"""
        # ✅ VERIFICAR AUTENTICACIÓN
        if not self._verificar_autenticacion():
            self.trabajadorActualizado.emit(False, "Usuario no autenticado")
            return False
        
        try:
            self._set_loading(True)
            
            print(f"📝 Actualizando trabajador ID: {trabajador_id} por usuario: {self._usuario_actual_id}")
            
            # Preparar argumentos solo con valores no vacíos
            kwargs = {}
            if nombre.strip():
                kwargs['nombre'] = nombre.strip()
            if apellido_paterno.strip():
                kwargs['apellido_paterno'] = apellido_paterno.strip()
            if apellido_materno.strip():
                kwargs['apellido_materno'] = apellido_materno.strip()
            if tipo_trabajador_id > 0:
                kwargs['tipo_trabajador_id'] = tipo_trabajador_id
            if especialidad.strip():
                kwargs['especialidad'] = especialidad.strip()
            if matricula.strip():
                kwargs['matricula'] = matricula.strip()
            
            success = self.repository.update_worker(trabajador_id, **kwargs)
            
            if success:
                self._cargar_trabajadores()
                
                mensaje = "Trabajador actualizado exitosamente"
                self.trabajadorActualizado.emit(True, mensaje)
                self.successMessage.emit(mensaje)
                
                print(f"✅ Trabajador actualizado desde QML: ID {trabajador_id}")
                return True
            else:
                error_msg = "Error actualizando trabajador"
                self.trabajadorActualizado.emit(False, error_msg)
                self.errorOccurred.emit("Error de actualización", error_msg)
                return False
                
        except Exception as e:
            error_msg = f"Error inesperado: {str(e)}"
            self.trabajadorActualizado.emit(False, error_msg)
            self.errorOccurred.emit("Error crítico", error_msg)
            return False
        finally:
            self._set_loading(False)
    
    @Slot(int, result=bool)
    def eliminarTrabajador(self, trabajador_id: int) -> bool:
        """Elimina trabajador desde QML - ✅ CON VERIFICACIÓN DE AUTENTICACIÓN"""
        # ✅ VERIFICAR AUTENTICACIÓN
        if not self._verificar_autenticacion():
            self.trabajadorEliminado.emit(False, "Usuario no autenticado")
            return False
        
        try:
            self._set_loading(True)
            
            print(f"🗑️ Eliminando trabajador ID: {trabajador_id} por usuario: {self._usuario_actual_id}")
            
            # Verificar que no tenga asignaciones de laboratorio
            asignaciones = self.repository.get_worker_lab_assignments(trabajador_id)
            if asignaciones:
                self.warningMessage.emit(f"Trabajador tiene {len(asignaciones)} asignaciones de laboratorio activas")
                return False
            
            success = self.repository.delete(trabajador_id)
            
            if success:
                self._cargar_trabajadores()
                self._cargar_estadisticas()
                
                mensaje = "Trabajador eliminado exitosamente"
                self.trabajadorEliminado.emit(True, mensaje)
                self.successMessage.emit(mensaje)
                
                print(f"🗑️ Trabajador eliminado desde QML: ID {trabajador_id}")
                return True
            else:
                error_msg = "Error eliminando trabajador"
                self.trabajadorEliminado.emit(False, error_msg)
                self.errorOccurred.emit("Error de eliminación", error_msg)
                return False
                
        except Exception as e:
            error_msg = f"Error inesperado: {str(e)}"
            self.trabajadorEliminado.emit(False, error_msg)
            self.errorOccurred.emit("Error crítico", error_msg)
            return False
        finally:
            self._set_loading(False)
    
    # ===============================
    # SLOTS PARA OPERACIONES CRUD TIPOS - ✅ CON VERIFICACIÓN DE AUTENTICACIÓN
    # ===============================
    
    @Slot(str, result=bool)
    def crearTipoTrabajador(self, nombre: str) -> bool:
        """Crea nuevo tipo de trabajador - ✅ CON VERIFICACIÓN DE AUTENTICACIÓN"""
        # ✅ VERIFICAR AUTENTICACIÓN
        if not self._verificar_autenticacion():
            self.tipoTrabajadorCreado.emit(False, "Usuario no autenticado")
            return False
        
        try:
            self._set_loading(True)
            
            print(f"🏷️ Creando tipo trabajador - Usuario: {self._usuario_actual_id}")
            
            tipo_id = self.repository.create_worker_type(nombre.strip())
            
            if tipo_id:
                self._cargar_tipos_trabajador()
                
                mensaje = f"Tipo de trabajador creado exitosamente - ID: {tipo_id}"
                self.tipoTrabajadorCreado.emit(True, mensaje)
                self.successMessage.emit(mensaje)
                
                print(f"✅ Tipo trabajador creado desde QML: {nombre}")
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
    
    @Slot(int, str, result=bool)
    def actualizarTipoTrabajador(self, tipo_id: int, nombre: str) -> bool:
        """Actualiza tipo de trabajador existente - ✅ CON VERIFICACIÓN DE AUTENTICACIÓN"""
        # ✅ VERIFICAR AUTENTICACIÓN
        if not self._verificar_autenticacion():
            self.tipoTrabajadorActualizado.emit(False, "Usuario no autenticado")
            return False
        
        try:
            self._set_loading(True)
            
            print(f"📝 Actualizando tipo trabajador ID: {tipo_id} por usuario: {self._usuario_actual_id}")
            
            success = self.repository.update_worker_type(tipo_id, nombre.strip())
            
            if success:
                self._cargar_tipos_trabajador()
                
                mensaje = "Tipo actualizado exitosamente"
                self.tipoTrabajadorActualizado.emit(True, mensaje)
                self.successMessage.emit(mensaje)
                
                return True
            else:
                error_msg = "Error actualizando tipo"
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
        """Elimina tipo de trabajador - ✅ CON VERIFICACIÓN DE AUTENTICACIÓN"""
        # ✅ VERIFICAR AUTENTICACIÓN
        if not self._verificar_autenticacion():
            self.tipoTrabajadorEliminado.emit(False, "Usuario no autenticado")
            return False
        
        try:
            self._set_loading(True)
            
            print(f"🗑️ Eliminando tipo trabajador ID: {tipo_id} por usuario: {self._usuario_actual_id}")
            
            # Verificar que no tenga trabajadores asociados
            trabajadores_del_tipo = self.repository.get_workers_by_type(tipo_id)
            if trabajadores_del_tipo:
                error_msg = f"Tipo tiene {len(trabajadores_del_tipo)} trabajadores asociados"
                self.warningMessage.emit(error_msg)
                self.tipoTrabajadorEliminado.emit(False, error_msg)
                return False
            
            success = self.repository.delete_worker_type(tipo_id)
            
            if success:
                self._cargar_tipos_trabajador()
                
                mensaje = "Tipo eliminado exitosamente"
                self.tipoTrabajadorEliminado.emit(True, mensaje)
                self.successMessage.emit(mensaje)
                
                return True
            else:
                error_msg = "Error eliminando tipo"
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
    
    # ===============================
    # SLOTS PARA BÚSQUEDA Y FILTROS (SIN VERIFICACIÓN - LECTURA)
    # ===============================
    
    @Slot(int, str, bool, str)
    def aplicarFiltros(self, tipo_id: int, buscar: str, incluir_stats: bool, area: str):
        """Aplica filtros a la lista de trabajadores - SIN VERIFICACIÓN (solo lectura)"""
        try:
            self._filtro_tipo = tipo_id
            self._filtro_busqueda = buscar.strip()
            self._incluir_stats = incluir_stats
            self._filtro_area = area
            
            # Filtrar datos locales
            trabajadores_filtrados = self._trabajadores.copy()
            
            # Filtro por tipo
            if tipo_id > 0:
                trabajadores_filtrados = [
                    t for t in trabajadores_filtrados
                    if t.get('Id_Tipo_Trabajador') == tipo_id
                ]
            
            # Filtro por búsqueda
            if buscar.strip():
                buscar_lower = buscar.lower()
                trabajadores_filtrados = [
                    t for t in trabajadores_filtrados
                    if (buscar_lower in t.get('Nombre', '').lower() or
                        buscar_lower in t.get('Apellido_Paterno', '').lower() or
                        buscar_lower in t.get('Apellido_Materno', '').lower() or
                        buscar_lower in t.get('tipo_nombre', '').lower())
                ]
            
            # Filtro por área
            if area and area != "Todos":
                area_lower = area.lower()
                trabajadores_filtrados = [
                    t for t in trabajadores_filtrados
                    if area_lower in t.get('tipo_nombre', '').lower()
                ]
            
            self._trabajadores_filtrados = trabajadores_filtrados
            self.trabajadoresChanged.emit()
            
            total = len(trabajadores_filtrados)
            self.busquedaCompleta.emit(True, f"Encontrados {total} trabajadores", total)
            print(f"🔍 Filtros aplicados: {total} trabajadores")
                
        except Exception as e:
            self.errorOccurred.emit("Error en filtros", f"Error aplicando filtros: {str(e)}")
    
    @Slot(str, int, result=list)
    def buscarTrabajadores(self, termino: str, limite: int = 50) -> List[Dict[str, Any]]:
        """Búsqueda rápida de trabajadores - SIN VERIFICACIÓN (solo lectura)"""
        try:
            if not termino.strip():
                return self._trabajadores
            
            trabajadores = self.repository.search_workers(termino.strip(), limite)
            print(f"🔍 Búsqueda '{termino}': {len(trabajadores)} resultados")
            return trabajadores
            
        except Exception as e:
            self.errorOccurred.emit("Error en búsqueda", f"Error buscando trabajadores: {str(e)}")
            return []
    
    @Slot(str, result=list)
    def obtenerTrabajadoresPorArea(self, area: str) -> List[Dict[str, Any]]:
        """Obtiene trabajadores por área específica - SIN VERIFICACIÓN (solo lectura)"""
        try:
            if area == "Todos":
                return self._trabajadores
            
            trabajadores = self.repository.get_workers_by_type_name(area)
            print(f"🏢 Área '{area}': {len(trabajadores)} trabajadores")
            return trabajadores
            
        except Exception as e:
            self.errorOccurred.emit("Error", f"Error obteniendo trabajadores por área: {str(e)}")
            return []
    
    @Slot()
    def limpiarFiltros(self):
        """Limpia todos los filtros aplicados - SIN VERIFICACIÓN (solo lectura)"""
        self._filtro_tipo = 0
        self._filtro_area = "Todos"
        self._filtro_busqueda = ""
        self._incluir_stats = False
        self._trabajadores_filtrados = self._trabajadores.copy()
        self.trabajadoresChanged.emit()
        print("🧹 Filtros limpiados")
    
    # ===============================
    # SLOTS PARA CONSULTAS ESPECÍFICAS (SIN VERIFICACIÓN - LECTURA)
    # ===============================
    
    @Slot(int, result='QVariantMap')
    def obtenerTrabajadorPorId(self, trabajador_id: int) -> Dict[str, Any]:
        """Obtiene trabajador específico por ID - SIN VERIFICACIÓN (solo lectura)"""
        try:
            trabajador = self.repository.get_worker_with_type(trabajador_id)
            return trabajador if trabajador else {}
        except Exception as e:
            self.errorOccurred.emit("Error", f"Error obteniendo trabajador: {str(e)}")
            return {}
    
    @Slot(result=list)
    def obtenerTrabajadoresLaboratorio(self) -> List[Dict[str, Any]]:
        """Obtiene trabajadores del área de laboratorio - SIN VERIFICACIÓN (solo lectura)"""
        return self.repository.get_laboratory_workers()
    
    @Slot(result=list)
    def obtenerTrabajadoresFarmacia(self) -> List[Dict[str, Any]]:
        """Obtiene trabajadores del área de farmacia - SIN VERIFICACIÓN (solo lectura)"""
        return self.repository.get_pharmacy_workers()
    
    @Slot(result=list)
    def obtenerTrabajadoresEnfermeria(self) -> List[Dict[str, Any]]:
        """Obtiene trabajadores del área de enfermería - SIN VERIFICACIÓN (solo lectura)"""
        return self.repository.get_nursing_staff()
    
    @Slot(result=list)
    def obtenerTrabajadoresAdministrativos(self) -> List[Dict[str, Any]]:
        """Obtiene trabajadores administrativos - SIN VERIFICACIÓN (solo lectura)"""
        return self.repository.get_administrative_staff()
    
    @Slot(result=list)
    def obtenerTrabajadoresSinAsignaciones(self) -> List[Dict[str, Any]]:
        """Obtiene trabajadores sin asignaciones - SIN VERIFICACIÓN (solo lectura)"""
        try:
            return self.repository.get_workers_without_assignments()
        except Exception as e:
            self.errorOccurred.emit("Error", f"Error obteniendo trabajadores sin asignaciones: {str(e)}")
            return []
    
    @Slot(int, result='QVariantMap')
    def obtenerCargaTrabajo(self, trabajador_id: int) -> Dict[str, Any]:
        """Obtiene carga de trabajo de un trabajador - SIN VERIFICACIÓN (solo lectura)"""
        try:
            trabajador = self.repository.get_worker_with_lab_stats(trabajador_id)
            return trabajador if trabajador else {}
        except Exception as e:
            self.errorOccurred.emit("Error", f"Error obteniendo carga de trabajo: {str(e)}")
            return {}
    
    # ===============================
    # SLOTS PARA RECARGA DE DATOS (SIN VERIFICACIÓN - LECTURA)
    # ===============================
    
    @Slot()
    def refrescarDatosInmediato(self):
        """Método para refrescar datos inmediatamente desde QML - SIN VERIFICACIÓN (solo lectura)"""
        try:
            print("🔄 Refrescando datos inmediatamente...")
            self._cargar_trabajadores()
            self._cargar_tipos_trabajador()
            
            # Aplicar filtros actuales
            self.aplicarFiltros(self._filtro_tipo, self._filtro_busqueda, 
                            self._incluir_stats, self._filtro_area)
            
            print(f"✅ Datos refrescados: {len(self._trabajadores)} trabajadores")
            
        except Exception as e:
            print(f"❌ Error refrescando datos: {e}")
            self.errorOccurred.emit("Error", f"Error refrescando datos: {str(e)}")
    
    @Slot()
    def recargarDatos(self):
        """Recarga todos los datos desde la base de datos - SIN VERIFICACIÓN (solo lectura)"""
        try:
            self._set_loading(True)
            self._cargar_datos_iniciales()
            self.successMessage.emit("Datos recargados exitosamente")
            print("🔄 Datos de trabajadores recargados desde QML")
        except Exception as e:
            self.errorOccurred.emit("Error", f"Error recargando datos: {str(e)}")
        finally:
            self._set_loading(False)
    
    @Slot()
    def recargarTrabajadores(self):
        """Recarga solo la lista de trabajadores - SIN VERIFICACIÓN (solo lectura)"""
        try:
            self._cargar_trabajadores()
            print("🔄 Trabajadores recargados")
        except Exception as e:
            self.errorOccurred.emit("Error", f"Error recargando trabajadores: {str(e)}")
    
    # ===============================
    # SLOTS PARA UTILIDADES (SIN VERIFICACIÓN - LECTURA)
    # ===============================
    
    @Slot(result=list)
    def obtenerTiposParaComboBox(self) -> List[Dict[str, Any]]:
        """Obtiene tipos de trabajador formateados para ComboBox - SIN VERIFICACIÓN (solo lectura)"""
        try:
            tipos_formateados = []
            
            # Agregar opción "Todos"
            tipos_formateados.append({
                'id': 0,
                'text': 'Todos los tipos',
                'data': {}
            })
            
            # Agregar tipos existentes
            for tipo in self._tipos_trabajador:
                tipos_formateados.append({
                    'id': tipo.get('id', 0),
                    'text': tipo.get('Tipo', 'Sin nombre'),
                    'data': tipo
                })
            
            return tipos_formateados
            
        except Exception as e:
            self.errorOccurred.emit("Error", f"Error obteniendo tipos: {str(e)}")
            return [{'id': 0, 'text': 'Todos los tipos', 'data': {}}]
    
    @Slot(result=list)
    def obtenerAreasDisponibles(self) -> List[str]:
        """Obtiene lista de áreas disponibles para filtros - SIN VERIFICACIÓN (solo lectura)"""
        return [
            "Todos",
            "Laboratorio", 
            "Farmacia", 
            "Enfermería", 
            "Administrativo", 
            "Técnico", 
            "Salud"
        ]
    
    @Slot(str, str, str, result=str)
    def formatearNombreCompleto(self, nombre: str, apellido_paterno: str, apellido_materno: str = "") -> str:
        """Formatea nombre completo del trabajador - SIN VERIFICACIÓN (solo lectura)"""
        partes = [nombre.strip(), apellido_paterno.strip()]
        
        if apellido_materno and apellido_materno.strip():
            partes.append(apellido_materno.strip())
        
        return " ".join(parte for parte in partes if parte)
    
    @Slot(int, result=str)
    def obtenerNombreTipo(self, tipo_id: int) -> str:
        """Obtiene nombre del tipo por ID - SIN VERIFICACIÓN (solo lectura)"""
        try:
            for tipo in self._tipos_trabajador:
                if tipo.get('id') == tipo_id:
                    return tipo.get('Tipo', 'Desconocido')
            return "Desconocido"
        except Exception:
            return "Desconocido"
    
    @Slot(result='QVariantMap')
    def obtenerEstadisticasCompletas(self) -> Dict[str, Any]:
        """Obtiene estadísticas completas del sistema - SIN VERIFICACIÓN (solo lectura)"""
        try:
            return self.repository.get_worker_statistics()
        except Exception as e:
            self.errorOccurred.emit("Error", f"Error obteniendo estadísticas: {str(e)}")
            return {}
    
    @Slot(result='QVariantMap')
    def obtenerDistribucionCarga(self) -> Dict[str, Any]:
        """Obtiene distribución de carga de trabajo - SIN VERIFICACIÓN (solo lectura)"""
        try:
            carga = self.repository.get_laboratory_workload()
            return {
                'trabajadores_laboratorio': carga,
                'total_trabajadores': len(carga),
                'con_asignaciones': len([t for t in carga if t.get('total_examenes', 0) > 0])
            }
        except Exception as e:
            self.errorOccurred.emit("Error", f"Error obteniendo distribución: {str(e)}")
            return {}
    
    # ===============================
    # MÉTODOS PRIVADOS (SIN CAMBIOS)
    # ===============================
    
    def _cargar_datos_iniciales(self):
        """Carga todos los datos necesarios al inicializar"""
        try:
            self._cargar_trabajadores()
            self._cargar_tipos_trabajador()
            self._cargar_estadisticas()
            print("📊 Datos iniciales de trabajadores cargados")
        except Exception as e:
            print(f"❌ Error cargando datos iniciales de trabajadores: {e}")
            self.errorOccurred.emit("Error inicial", f"Error cargando datos: {str(e)}")
    
    def _cargar_trabajadores(self):
        """Carga lista de trabajadores desde el repository"""
        try:
            trabajadores = self.repository.get_all_with_types()
            
            # Agregar nombre completo
            for trabajador in trabajadores:
                trabajador['nombre_completo'] = f"{trabajador.get('Nombre', '')} {trabajador.get('Apellido_Paterno', '')} {trabajador.get('Apellido_Materno', '')}"
            
            self._trabajadores = trabajadores
            self._trabajadores_filtrados = trabajadores.copy()
            self.trabajadoresChanged.emit()
            print(f"👷‍♂️ Trabajadores cargados: {len(trabajadores)}")
                
        except Exception as e:
            print(f"❌ Error cargando trabajadores: {e}")
            self._trabajadores = []
            self._trabajadores_filtrados = []
            raise e
    
    def _cargar_tipos_trabajador(self):
        """Carga lista de tipos de trabajador desde el repository"""
        try:
            tipos = self.repository.get_all_worker_types()
            self._tipos_trabajador = tipos
            self.tiposTrabajadorChanged.emit()
            print(f"🏷️ Tipos de trabajador cargados: {len(self._tipos_trabajador)}")
                
        except Exception as e:
            print(f"❌ Error cargando tipos de trabajador: {e}")
            self._tipos_trabajador = []
            raise e
    
    def _cargar_estadisticas(self):
        """Carga estadísticas desde el repository"""
        try:
            estadisticas = self.repository.get_worker_statistics()
            self._estadisticas = estadisticas
            self.estadisticasChanged.emit()
            print("📈 Estadísticas de trabajadores cargadas")
        except Exception as e:
            print(f"❌ Error cargando estadísticas: {e}")
            # No es crítico, continuar sin estadísticas
            self._estadisticas = {}
    
    def _set_loading(self, loading: bool):
        """Actualiza estado de carga"""
        if self._loading != loading:
            self._loading = loading
            self.loadingChanged.emit()
    
    @Slot()
    def _actualizar_tipos_trabajadores_desde_signal(self):
        """Actualiza tipos de trabajadores cuando recibe señal global"""
        try:
            print("📡 TrabajadorModel: Recibida señal de actualización de tipos de trabajadores")
            
            # Invalidar cache si existe el método
            if hasattr(self.repository, 'invalidate_worker_caches'):
                self.repository.invalidate_worker_caches()
                print("🗑️ Cache de tipos invalidado en TrabajadorModel")
            
            self._cargar_tipos_trabajador()
            print("✅ Tipos de trabajadores actualizados desde señal global en TrabajadorModel")
        except Exception as e:
            print(f"❌ Error actualizando tipos desde señal: {e}")

    @Slot(str)
    def _manejar_actualizacion_global(self, mensaje: str):
        """Maneja actualizaciones globales de trabajadores"""
        try:
            print(f"📡 TrabajadorModel: {mensaje}")
            # Emitir señal para notificar a QML que hay cambios
            self.tiposTrabajadorChanged.emit()
        except Exception as e:
            print(f"❌ Error manejando actualización global: {e}")

    def emergency_disconnect(self):
        """Desconexión de emergencia para TrabajadorModel"""
        try:
            print("🚨 TrabajadorModel: Iniciando desconexión de emergencia...")
            
            # Desconectar señales globales
            try:
                if hasattr(self, 'global_signals'):
                    self.global_signals.tiposTrabajadoresModificados.disconnect(self._actualizar_tipos_trabajadores_desde_signal)
                    self.global_signals.trabajadoresNecesitaActualizacion.disconnect(self._manejar_actualizacion_global)
            except:
                pass
            
            # Desconectar señales propias
            signals_to_disconnect = [
                'trabajadoresChanged', 'tiposTrabajadorChanged', 'estadisticasChanged',
                'trabajadorCreado', 'trabajadorActualizado', 'trabajadorEliminado',
                'tipoTrabajadorCreado', 'tipoTrabajadorActualizado', 'tipoTrabajadorEliminado',
                'busquedaCompleta', 'loadingChanged', 'errorOccurred', 'successMessage',
                'warningMessage', 'operacionError', 'operacionExitosa'
            ]
            
            for signal_name in signals_to_disconnect:
                if hasattr(self, signal_name):
                    try:
                        getattr(self, signal_name).disconnect()
                    except:
                        pass
            
            # Limpiar datos
            self._trabajadores = []
            self._trabajadores_filtrados = []
            self._tipos_trabajador = []
            self._estadisticas = {}
            self._filtro_tipo = 0
            self._filtro_area = "Todos"
            self._filtro_busqueda = ""
            self._incluir_stats = False
            self._usuario_actual_id = 0  # ✅ RESETEAR USUARIO
            
            # Anular repository
            self.repository = None
            
            print("✅ TrabajadorModel: Desconexión de emergencia completada")
            
        except Exception as e:
            print(f"❌ Error en desconexión TrabajadorModel: {e}")

# ===============================
# REGISTRO PARA QML
# ===============================

def register_trabajador_model():
    """Registra el TrabajadorModel para uso en QML"""
    qmlRegisterType(TrabajadorModel, "ClinicaModels", 1, 0, "TrabajadorModel")
    print("🔗 TrabajadorModel registrado para QML con autenticación estandarizada")

# Para facilitar la importación
__all__ = ['TrabajadorModel', 'register_trabajador_model']