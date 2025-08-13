from typing import List, Dict, Any, Optional
from PySide6.QtCore import QObject, Signal, Slot, Property
from PySide6.QtQml import qmlRegisterType

from ..services.trabajador_service import TrabajadorService
from ..core.excepciones import ExceptionHandler, ValidationError

class TrabajadorModel(QObject):
    """
    Model QObject para gestión de trabajadores en QML
    Conecta la interfaz QML con el TrabajadorService
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
    
    def __init__(self, parent=None):
        super().__init__(parent)
        
        # Referencias a services
        self.service = TrabajadorService()
        
        # Estado interno
        self._trabajadores: List[Dict[str, Any]] = []
        self._trabajadores_filtrados: List[Dict[str, Any]] = []
        self._tipos_trabajador: List[Dict[str, Any]] = []
        self._estadisticas: Dict[str, Any] = {}
        self._loading: bool = False
        
        # Filtros activos
        self._filtro_tipo: int = 0
        self._filtro_area: str = "Todos"
        self._filtro_busqueda: str = ""
        self._incluir_stats: bool = False
        
        # Configuración inicial
        self._cargar_datos_iniciales()
        
        print("👷‍♂️ TrabajadorModel inicializado")
    
    # ===============================
    # PROPERTIES - Datos para QML
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
    # SLOTS - Métodos llamables desde QML
    # ===============================
    
    # --- OPERACIONES CRUD TRABAJADORES ---
    
    @Slot(str, str, str, int, result=bool)
    def crearTrabajador(self, nombre: str, apellido_paterno: str, 
                       apellido_materno: str, tipo_trabajador_id: int) -> bool:
        """Crea nuevo trabajador desde QML"""
        try:
            self._set_loading(True)
            
            resultado = self.service.crear_trabajador(
                nombre=nombre.strip(),
                apellido_paterno=apellido_paterno.strip(),
                apellido_materno=apellido_materno.strip(),
                tipo_trabajador_id=tipo_trabajador_id
            )
            
            if resultado.get('success'):
                self._cargar_trabajadores()
                self._cargar_estadisticas()
                
                mensaje = resultado.get('message', 'Trabajador creado exitosamente')
                self.trabajadorCreado.emit(True, mensaje)
                self.successMessage.emit(mensaje)
                
                print(f"✅ Trabajador creado desde QML: {nombre} {apellido_paterno}")
                return True
            else:
                error_msg = resultado.get('error', 'Error creando trabajador')
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
    
    @Slot(int, str, str, str, int, result=bool)
    def actualizarTrabajador(self, trabajador_id: int, nombre: str = "", 
                            apellido_paterno: str = "", apellido_materno: str = "",
                            tipo_trabajador_id: int = 0) -> bool:
        """Actualiza trabajador existente desde QML"""
        try:
            self._set_loading(True)
            
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
            
            resultado = self.service.actualizar_trabajador(trabajador_id, **kwargs)
            
            if resultado.get('success'):
                self._cargar_trabajadores()
                
                mensaje = resultado.get('message', 'Trabajador actualizado exitosamente')
                self.trabajadorActualizado.emit(True, mensaje)
                self.successMessage.emit(mensaje)
                
                print(f"✅ Trabajador actualizado desde QML: ID {trabajador_id}")
                return True
            else:
                error_msg = resultado.get('error', 'Error actualizando trabajador')
                
                # Mostrar advertencia si hay restricciones
                if resultado.get('code') == 'CAMBIO_TIPO_RESTRINGIDO':
                    self.warningMessage.emit(error_msg)
                
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
    
    @Slot(int, bool, result=bool)
    def eliminarTrabajador(self, trabajador_id: int, forzar: bool = False) -> bool:
        """Elimina trabajador desde QML"""
        try:
            self._set_loading(True)
            
            resultado = self.service.eliminar_trabajador(trabajador_id, forzar)
            
            if resultado.get('success'):
                self._cargar_trabajadores()
                self._cargar_estadisticas()
                
                mensaje = resultado.get('message', 'Trabajador eliminado exitosamente')
                self.trabajadorEliminado.emit(True, mensaje)
                self.successMessage.emit(mensaje)
                
                # Mostrar advertencia si fue eliminación forzada
                if forzar and resultado.get('data', {}).get('dependencias_afectadas'):
                    self.warningMessage.emit("Eliminación forzada: se afectaron dependencias")
                
                print(f"🗑️ Trabajador eliminado desde QML: ID {trabajador_id}")
                return True
            else:
                error_msg = resultado.get('error', 'Error eliminando trabajador')
                
                # Mostrar detalles de dependencias si las hay
                if resultado.get('code') == 'TIENE_DEPENDENCIAS':
                    details = resultado.get('details', {})
                    if details:
                        dependencias_msg = f"Trabajador tiene dependencias. Use 'forzar' para eliminar."
                        self.warningMessage.emit(dependencias_msg)
                
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
    
    # --- OPERACIONES CRUD TIPOS TRABAJADOR ---
    
    @Slot(str, result=bool)
    def crearTipoTrabajador(self, nombre: str) -> bool:
        """Crea nuevo tipo de trabajador desde QML"""
        try:
            self._set_loading(True)
            
            resultado = self.service.crear_tipo_trabajador(nombre.strip())
            
            if resultado.get('success'):
                self._cargar_tipos_trabajador()
                
                mensaje = resultado.get('message', 'Tipo de trabajador creado exitosamente')
                self.tipoTrabajadorCreado.emit(True, mensaje)
                self.successMessage.emit(mensaje)
                
                print(f"✅ Tipo trabajador creado desde QML: {nombre}")
                return True
            else:
                error_msg = resultado.get('error', 'Error creando tipo de trabajador')
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
        """Actualiza tipo de trabajador existente"""
        try:
            self._set_loading(True)
            
            resultado = self.service.actualizar_tipo_trabajador(tipo_id, nombre.strip())
            
            if resultado.get('success'):
                self._cargar_tipos_trabajador()
                
                mensaje = resultado.get('message', 'Tipo actualizado exitosamente')
                self.tipoTrabajadorActualizado.emit(True, mensaje)
                self.successMessage.emit(mensaje)
                
                return True
            else:
                error_msg = resultado.get('error', 'Error actualizando tipo')
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
        """Elimina tipo de trabajador"""
        try:
            self._set_loading(True)
            
            resultado = self.service.eliminar_tipo_trabajador(tipo_id)
            
            if resultado.get('success'):
                self._cargar_tipos_trabajador()
                
                mensaje = resultado.get('message', 'Tipo eliminado exitosamente')
                self.tipoTrabajadorEliminado.emit(True, mensaje)
                self.successMessage.emit(mensaje)
                
                return True
            else:
                error_msg = resultado.get('error', 'Error eliminando tipo')
                
                # Mostrar detalles si tiene trabajadores asociados
                if resultado.get('code') == 'TIPO_CON_TRABAJADORES':
                    details = resultado.get('details', {})
                    cantidad = details.get('cantidad_trabajadores', 0)
                    self.warningMessage.emit(f"Tipo tiene {cantidad} trabajadores asociados")
                
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
    
    @Slot(int, str, bool, str)
    def aplicarFiltros(self, tipo_id: int, buscar: str, incluir_stats: bool, area: str):
        """Aplica filtros a la lista de trabajadores"""
        try:
            self._filtro_tipo = tipo_id
            self._filtro_busqueda = buscar.strip()
            self._incluir_stats = incluir_stats
            self._filtro_area = area
            
            # Preparar filtros para el service
            filtros = {}
            if tipo_id > 0:
                filtros['tipo_id'] = tipo_id
            if buscar.strip():
                filtros['buscar'] = buscar.strip()
            if incluir_stats:
                filtros['incluir_stats'] = True
            if area and area != "Todos":
                filtros['area'] = area.lower()
            
            resultado = self.service.obtener_trabajadores(filtros)
            
            if resultado.get('success'):
                trabajadores = resultado.get('data', {}).get('trabajadores', [])
                self._trabajadores_filtrados = trabajadores
                self.trabajadoresChanged.emit()
                
                total = len(trabajadores)
                self.busquedaCompleta.emit(True, f"Encontrados {total} trabajadores", total)
                print(f"🔍 Filtros aplicados: {total} trabajadores")
            else:
                self.errorOccurred.emit("Error en filtros", resultado.get('error', 'Error aplicando filtros'))
                
        except Exception as e:
            self.errorOccurred.emit("Error en filtros", f"Error aplicando filtros: {str(e)}")
    
    @Slot(str, int, result=list)
    def buscarTrabajadores(self, termino: str, limite: int = 50) -> List[Dict[str, Any]]:
        """Búsqueda rápida de trabajadores"""
        try:
            if not termino.strip():
                return self._trabajadores
            
            resultado = self.service.buscar_trabajadores(termino.strip(), limite)
            
            if resultado.get('success'):
                trabajadores = resultado.get('data', {}).get('trabajadores', [])
                total = resultado.get('data', {}).get('total', 0)
                print(f"🔍 Búsqueda '{termino}': {total} resultados")
                return trabajadores
            
            return []
            
        except Exception as e:
            self.errorOccurred.emit("Error en búsqueda", f"Error buscando trabajadores: {str(e)}")
            return []
    
    @Slot(str, result=list)
    def obtenerTrabajadoresPorArea(self, area: str) -> List[Dict[str, Any]]:
        """Obtiene trabajadores por área específica"""
        try:
            filtros = {'area': area.lower()} if area != "Todos" else {}
            resultado = self.service.obtener_trabajadores(filtros)
            
            if resultado.get('success'):
                trabajadores = resultado.get('data', {}).get('trabajadores', [])
                print(f"🏢 Área '{area}': {len(trabajadores)} trabajadores")
                return trabajadores
            
            return []
            
        except Exception as e:
            self.errorOccurred.emit("Error", f"Error obteniendo trabajadores por área: {str(e)}")
            return []
    
    @Slot()
    def limpiarFiltros(self):
        """Limpia todos los filtros aplicados"""
        self._filtro_tipo = 0
        self._filtro_area = "Todos"
        self._filtro_busqueda = ""
        self._incluir_stats = False
        self._trabajadores_filtrados = self._trabajadores.copy()
        self.trabajadoresChanged.emit()
        print("🧹 Filtros limpiados")
    
    # --- CONSULTAS ESPECÍFICAS ---
    
    @Slot(int, result='QVariantMap')
    def obtenerTrabajadorPorId(self, trabajador_id: int) -> Dict[str, Any]:
        """Obtiene trabajador específico por ID"""
        try:
            # Buscar en la lista local primero
            for trabajador in self._trabajadores:
                if trabajador.get('id') == trabajador_id:
                    return trabajador
            
            # Si no está en local, validar existencia
            resultado = self.service.validar_trabajador_existe(trabajador_id)
            
            if resultado.get('success') and resultado.get('data', {}).get('existe'):
                return resultado.get('data', {}).get('trabajador', {})
            else:
                self.errorOccurred.emit("Error", "Trabajador no encontrado")
                return {}
                
        except Exception as e:
            self.errorOccurred.emit("Error", f"Error obteniendo trabajador: {str(e)}")
            return {}
    
    @Slot(result=list)
    def obtenerTrabajadoresLaboratorio(self) -> List[Dict[str, Any]]:
        """Obtiene trabajadores del área de laboratorio"""
        return self.obtenerTrabajadoresPorArea("laboratorio")
    
    @Slot(result=list)
    def obtenerTrabajadoresFarmacia(self) -> List[Dict[str, Any]]:
        """Obtiene trabajadores del área de farmacia"""
        return self.obtenerTrabajadoresPorArea("farmacia")
    
    @Slot(result=list)
    def obtenerTrabajadoresEnfermeria(self) -> List[Dict[str, Any]]:
        """Obtiene trabajadores del área de enfermería"""
        return self.obtenerTrabajadoresPorArea("enfermeria")
    
    @Slot(result=list)
    def obtenerTrabajadoresAdministrativos(self) -> List[Dict[str, Any]]:
        """Obtiene trabajadores administrativos"""
        return self.obtenerTrabajadoresPorArea("administrativo")
    
    @Slot(result=list)
    def obtenerTrabajadoresSinAsignaciones(self) -> List[Dict[str, Any]]:
        """Obtiene trabajadores sin asignaciones"""
        try:
            # Esta funcionalidad específica del service no está expuesta directamente
            # Se podría implementar como un filtro especial
            trabajadores_sin_asignaciones = []
            for trabajador in self._trabajadores:
                if trabajador.get('total_asignaciones_laboratorio', 0) == 0:
                    trabajadores_sin_asignaciones.append(trabajador)
            
            return trabajadores_sin_asignaciones
            
        except Exception as e:
            self.errorOccurred.emit("Error", f"Error obteniendo trabajadores sin asignaciones: {str(e)}")
            return []
    
    # --- RECARGA DE DATOS ---
    
    @Slot()
    def recargarDatos(self):
        """Recarga todos los datos desde la base de datos"""
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
        """Recarga solo la lista de trabajadores"""
        try:
            self._cargar_trabajadores()
            print("🔄 Trabajadores recargados")
        except Exception as e:
            self.errorOccurred.emit("Error", f"Error recargando trabajadores: {str(e)}")
    
    # --- UTILIDADES ---
    
    @Slot(result=list)
    def obtenerTiposParaComboBox(self) -> List[Dict[str, Any]]:
        """Obtiene tipos de trabajador formateados para ComboBox"""
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
        """Obtiene lista de áreas disponibles para filtros"""
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
        """Formatea nombre completo del trabajador"""
        partes = [nombre.strip(), apellido_paterno.strip()]
        
        if apellido_materno and apellido_materno.strip():
            partes.append(apellido_materno.strip())
        
        return " ".join(parte for parte in partes if parte)
    
    @Slot(int, result=str)
    def obtenerNombreTipo(self, tipo_id: int) -> str:
        """Obtiene nombre del tipo por ID"""
        try:
            for tipo in self._tipos_trabajador:
                if tipo.get('id') == tipo_id:
                    return tipo.get('Tipo', 'Desconocido')
            return "Desconocido"
        except Exception:
            return "Desconocido"
    
    @Slot()
    def invalidarCache(self):
        """Invalida el caché del sistema"""
        try:
            self.service.invalidar_cache()
            self.successMessage.emit("Caché invalidado exitosamente")
            print("🗑️ Caché de trabajadores invalidado desde QML")
        except Exception as e:
            self.errorOccurred.emit("Error", f"Error invalidando caché: {str(e)}")
    
    @Slot(result='QVariantMap')
    def obtenerEstadisticasCompletas(self) -> Dict[str, Any]:
        """Obtiene estadísticas completas del sistema"""
        try:
            resultado = self.service.obtener_estadisticas()
            
            if resultado.get('success'):
                return resultado.get('data', {})
            
            return {}
            
        except Exception as e:
            self.errorOccurred.emit("Error", f"Error obteniendo estadísticas: {str(e)}")
            return {}
    
    # ===============================
    # MÉTODOS PRIVADOS
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
        """Carga lista de trabajadores desde el service"""
        try:
            resultado = self.service.obtener_trabajadores()
            
            if resultado.get('success'):
                trabajadores = resultado.get('data', {}).get('trabajadores', [])
                self._trabajadores = trabajadores
                self._trabajadores_filtrados = trabajadores.copy()
                self.trabajadoresChanged.emit()
                print(f"👷‍♂️ Trabajadores cargados: {len(trabajadores)}")
            else:
                self._trabajadores = []
                self._trabajadores_filtrados = []
                
        except Exception as e:
            print(f"❌ Error cargando trabajadores: {e}")
            self._trabajadores = []
            self._trabajadores_filtrados = []
            raise e
    
    def _cargar_tipos_trabajador(self):
        """Carga lista de tipos de trabajador desde el service"""
        try:
            resultado = self.service.obtener_tipos_trabajadores()
            
            if resultado.get('success'):
                tipos = resultado.get('data', {}).get('tipos', [])
                self._tipos_trabajador = tipos
                self.tiposTrabajadorChanged.emit()
                print(f"🏷️ Tipos de trabajador cargados: {len(tipos)}")
            else:
                self._tipos_trabajador = []
                
        except Exception as e:
            print(f"❌ Error cargando tipos de trabajador: {e}")
            self._tipos_trabajador = []
            raise e
    
    def _cargar_estadisticas(self):
        """Carga estadísticas desde el service"""
        try:
            resultado = self.service.obtener_estadisticas()
            
            if resultado.get('success'):
                estadisticas = resultado.get('data', {})
                self._estadisticas = estadisticas
                self.estadisticasChanged.emit()
                print("📈 Estadísticas de trabajadores cargadas")
            else:
                self._estadisticas = {}
                
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

def register_trabajador_model():
    """Registra el TrabajadorModel para uso en QML"""
    qmlRegisterType(TrabajadorModel, "ClinicaModels", 1, 0, "TrabajadorModel")
    print("🔗 TrabajadorModel registrado para QML")

# Para facilitar la importación
__all__ = ['TrabajadorModel', 'register_trabajador_model']