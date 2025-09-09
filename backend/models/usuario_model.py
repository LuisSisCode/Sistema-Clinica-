from typing import List, Dict, Any, Optional
from PySide6.QtCore import QObject, Signal, Slot, Property
from PySide6.QtQml import qmlRegisterType

from ..repositories.usuario_repository import UsuarioRepository
from ..core.excepciones import ExceptionHandler, ValidationError, AuthenticationError

class UsuarioModel(QObject):
    """
    Model QObject para gestión de usuarios en QML
    Conecta la interfaz QML con el UsuarioRepository
    """
    
    # ===============================
    # SIGNALS - Notificaciones a QML
    # ===============================
    
    # Señales para cambios en datos
    usuariosChanged = Signal()
    rolesChanged = Signal()
    estadisticasChanged = Signal()
    
    # Señales para operaciones
    usuarioCreado = Signal(bool, str)  # success, message
    usuarioActualizado = Signal(bool, str)
    usuarioEliminado = Signal(bool, str)
    
    # Señales para autenticación
    loginCompleted = Signal(bool, str, 'QVariantMap')  # success, message, userData
    logoutCompleted = Signal(bool, str)
    
    # Señales para UI
    loadingChanged = Signal()
    errorOccurred = Signal(str, str)  # title, message
    successMessage = Signal(str)
    
    def __init__(self, parent=None):
        super().__init__(parent)
        
        # Referencias a repositories
        self.repository = UsuarioRepository()
        
        # Estado interno
        self._usuarios: List[Dict[str, Any]] = []
        self._usuarios_filtrados: List[Dict[str, Any]] = []
        self._roles: List[Dict[str, Any]] = []
        self._estadisticas: Dict[str, Any] = {}
        self._usuario_actual: Optional[Dict[str, Any]] = None
        self._loading: bool = False
        
        # Filtros activos
        self._filtro_rol: str = "Todos los roles"
        self._filtro_estado: str = "Todos"
        self._filtro_busqueda: str = ""
        
        # Configuración inicial
        self._cargar_datos_iniciales()
        
        print("🎯 UsuarioModel inicializado")
    
    # ===============================
    # PROPERTIES - Datos para QML
    # ===============================
    
    @Property(list, notify=usuariosChanged)
    def usuarios(self) -> List[Dict[str, Any]]:
        """Lista de usuarios para mostrar en QML"""
        return self._usuarios 
    
    @Property(list, notify=rolesChanged)
    def roles(self) -> List[Dict[str, Any]]:
        """Lista de roles disponibles"""
        return self._roles
    
    @Property('QVariantMap', notify=estadisticasChanged)
    def estadisticas(self) -> Dict[str, Any]:
        """Estadísticas de usuarios"""
        return self._estadisticas
    
    @Property(bool, notify=loadingChanged)
    def loading(self) -> bool:
        """Estado de carga"""
        return self._loading
    
    @Property('QVariantMap')
    def usuarioActual(self) -> Optional[Dict[str, Any]]:
        """Usuario actualmente autenticado"""
        return self._usuario_actual or {}
    
    @Property(int, notify=usuariosChanged)
    def totalUsuarios(self) -> int:
        """Total de usuarios filtrados"""
        return len(self._usuarios_filtrados)
    
    @Property(str)
    def filtroRol(self) -> str:
        """Filtro actual por rol"""
        return self._filtro_rol
    
    @Property(str)
    def filtroEstado(self) -> str:
        """Filtro actual por estado"""
        return self._filtro_estado
    
    @Property(str)
    def filtroBusqueda(self) -> str:
        """Texto de búsqueda actual"""
        return self._filtro_busqueda
    
    # ===============================
    # SLOTS - Métodos llamables desde QML
    # ===============================
    
    # --- OPERACIONES CRUD ---
    
    @Slot(str, str, str, str, str, str, int, bool, result=bool)
    def crearUsuario(self, nombre: str, apellido_paterno: str, apellido_materno: str,
                    correo: str, contrasena: str, confirmar_contrasena: str, 
                    rol_id: int, estado: bool) -> bool:
        """
        Crea nuevo usuario desde QML
        
        Args:
            nombre: Nombre del usuario
            apellido_paterno: Apellido paterno
            apellido_materno: Apellido materno
            correo: Correo electrónico
            contrasena: Contraseña
            confirmar_contrasena: Confirmación de contraseña
            rol_id: ID del rol
            estado: Estado activo/inactivo
            
        Returns:
            True si se creó exitosamente
        """
        try:
            self._set_loading(True)
            
            # Validar contraseñas coinciden
            if contrasena != confirmar_contrasena:
                self.errorOccurred.emit("Error de validación", "Las contraseñas no coinciden")
                return False
            
            # Crear usuario usando el repository
            usuario_id = self.repository.create_user(
                nombre=nombre.strip(),
                apellido_paterno=apellido_paterno.strip(),
                apellido_materno=apellido_materno.strip(),
                correo=correo.strip(),
                contrasena=contrasena,
                rol_id=rol_id,
                estado=estado
            )
            
            if usuario_id:
                # Recargar datos
                self._cargar_usuarios()
                self._cargar_estadisticas()
                
                # Notificar éxito
                mensaje = f"Usuario {nombre} {apellido_paterno} creado exitosamente"
                self.usuarioCreado.emit(True, mensaje)
                self.successMessage.emit(mensaje)
                
                print(f"✅ Usuario creado desde QML: {correo}")
                return True
            else:
                self.usuarioCreado.emit(False, "Error creando usuario")
                return False
                
        except (ValidationError, AuthenticationError) as e:
            error_msg = str(e)
            self.usuarioCreado.emit(False, error_msg)
            self.errorOccurred.emit("Error de validación", error_msg)
            return False
        except Exception as e:
            error_msg = f"Error inesperado: {str(e)}"
            self.usuarioCreado.emit(False, error_msg)
            self.errorOccurred.emit("Error crítico", error_msg)
            return False
        finally:
            self._set_loading(False)
    
    @Slot(int, str, str, str, str, int, bool, result=bool)
    def actualizarUsuario(self, usuario_id: int, nombre: str, apellido_paterno: str, 
                         apellido_materno: str, correo: str, rol_id: int, estado: bool) -> bool:
        """Actualiza usuario existente desde QML"""
        try:
            self._set_loading(True)
            
            # Actualizar usando el repository
            success = self.repository.update_user(
                usuario_id=usuario_id,
                nombre=nombre.strip() if nombre else None,
                apellido_paterno=apellido_paterno.strip() if apellido_paterno else None,
                apellido_materno=apellido_materno.strip() if apellido_materno else None,
                correo=correo.strip() if correo else None,
                rol_id=rol_id if rol_id > 0 else None,
                estado=estado
            )
            
            if success:
                # Recargar datos
                self._cargar_usuarios()
                self._cargar_estadisticas()
                
                # Notificar éxito
                mensaje = "Usuario actualizado exitosamente"
                self.usuarioActualizado.emit(True, mensaje)
                self.successMessage.emit(mensaje)
                
                print(f"✅ Usuario actualizado desde QML: ID {usuario_id}")
                return True
            else:
                self.usuarioActualizado.emit(False, "Error actualizando usuario")
                return False
                
        except (ValidationError, AuthenticationError) as e:
            error_msg = str(e)
            self.usuarioActualizado.emit(False, error_msg)
            self.errorOccurred.emit("Error de validación", error_msg)
            return False
        except Exception as e:
            error_msg = f"Error inesperado: {str(e)}"
            self.usuarioActualizado.emit(False, error_msg)
            self.errorOccurred.emit("Error crítico", error_msg)
            return False
        finally:
            self._set_loading(False)
    
    @Slot(int, result=bool)
    def eliminarUsuario(self, usuario_id: int) -> bool:
        """Elimina usuario desde QML"""
        try:
            self._set_loading(True)
            
            # Eliminar usando el repository
            success = self.repository.delete(usuario_id)
            
            if success:
                # Recargar datos
                self._cargar_usuarios()
                self._cargar_estadisticas()
                
                # Notificar éxito
                mensaje = "Usuario eliminado exitosamente"
                self.usuarioEliminado.emit(True, mensaje)
                self.successMessage.emit(mensaje)
                
                print(f"🗑️ Usuario eliminado desde QML: ID {usuario_id}")
                return True
            else:
                self.usuarioEliminado.emit(False, "Usuario no encontrado")
                return False
                
        except Exception as e:
            error_msg = f"Error inesperado: {str(e)}"
            self.usuarioEliminado.emit(False, error_msg)
            self.errorOccurred.emit("Error crítico", error_msg)
            return False
        finally:
            self._set_loading(False)
    
    # --- BÚSQUEDA Y FILTROS ---
    
    @Slot(str, str, str)
    def aplicarFiltros(self, filtro_rol: str, filtro_estado: str, texto_busqueda: str):
        """Aplica filtros a la lista de usuarios"""
        try:
            self._filtro_rol = filtro_rol
            self._filtro_estado = filtro_estado
            self._filtro_busqueda = texto_busqueda.strip()
            
            # Filtrar usuarios
            usuarios_filtrados = self._usuarios.copy()
            
            # Filtro por rol
            if filtro_rol != "Todos los roles":
                usuarios_filtrados = [u for u in usuarios_filtrados 
                                    if u.get('rol_nombre') == filtro_rol]
            
            # Filtro por estado
            if filtro_estado != "Todos":
                if filtro_estado == "Activo":
                    usuarios_filtrados = [u for u in usuarios_filtrados if u.get('Estado')]
                elif filtro_estado == "Inactivo":
                    usuarios_filtrados = [u for u in usuarios_filtrados if not u.get('Estado')]
            
            # Filtro por búsqueda de texto
            if self._filtro_busqueda:
                termino = self._filtro_busqueda.lower()
                usuarios_filtrados = [
                    u for u in usuarios_filtrados 
                    if (termino in (u.get('Nombre', '') + ' ' + u.get('Apellido_Paterno', '')).lower() or 
                        termino in u.get('correo', '').lower())
                ]
            
            # Actualizar lista filtrada
            self._usuarios_filtrados = usuarios_filtrados
            self.usuariosChanged.emit()
            
            print(f"🔍 Filtros aplicados: {len(usuarios_filtrados)} usuarios de {len(self._usuarios)}")
            
        except Exception as e:
            self.errorOccurred.emit("Error en filtros", f"Error aplicando filtros: {str(e)}")
    
    @Slot(str, result=list)
    def buscarUsuarios(self, termino: str) -> List[Dict[str, Any]]:
        """Búsqueda avanzada de usuarios"""
        try:
            if not termino.strip():
                return self._usuarios
            
            resultados = self.repository.search_users(termino.strip())
            print(f"🔍 Búsqueda '{termino}': {len(resultados)} resultados")
            return resultados
            
        except Exception as e:
            self.errorOccurred.emit("Error en búsqueda", f"Error buscando usuarios: {str(e)}")
            return []
    
    @Slot()
    def limpiarFiltros(self):
        """Limpia todos los filtros aplicados"""
        self._filtro_rol = "Todos los roles"
        self._filtro_estado = "Todos"
        self._filtro_busqueda = ""
        self._usuarios_filtrados = self._usuarios.copy()
        self.usuariosChanged.emit()
        print("🧹 Filtros limpiados")
    
    # --- AUTENTICACIÓN ---
    
    @Slot(str, str)
    def login(self, correo: str, contrasena: str):
        """Autentica usuario desde QML"""
        try:
            self._set_loading(True)
            
            usuario = self.repository.authenticate(correo, contrasena)
            
            if usuario:
                self._usuario_actual = usuario
                mensaje = f"Bienvenido, {usuario.get('Nombre', '')} {usuario.get('Apellido_Paterno', '')}"
                self.loginCompleted.emit(True, mensaje, usuario)
                self.successMessage.emit(mensaje)
                print(f"🔑 Login exitoso desde QML: {correo}")
            else:
                self.loginCompleted.emit(False, "Credenciales inválidas", {})
                
        except AuthenticationError as e:
            error_msg = str(e)
            self.loginCompleted.emit(False, error_msg, {})
            self.errorOccurred.emit("Error de autenticación", error_msg)
        except Exception as e:
            error_msg = f"Error inesperado en login: {str(e)}"
            self.loginCompleted.emit(False, error_msg, {})
            self.errorOccurred.emit("Error crítico", error_msg)
        finally:
            self._set_loading(False)
    
    @Slot()
    def logout(self):
        """Cierra sesión desde QML"""
        try:
            self._usuario_actual = None
            self.logoutCompleted.emit(True, "Sesión cerrada correctamente")
            print("🚪 Logout exitoso desde QML")
        except Exception as e:
            error_msg = f"Error en logout: {str(e)}"
            self.logoutCompleted.emit(False, error_msg)
    
    # --- OPERACIONES ESPECIALES ---
    
    @Slot(int, str, str, result=bool)
    def cambiarContrasena(self, usuario_id: int, contrasena_actual: str, nueva_contrasena: str) -> bool:
        """Cambiar contraseña de usuario"""
        try:
            self._set_loading(True)
            
            success = self.repository.change_password(usuario_id, contrasena_actual, nueva_contrasena)
            
            if success:
                self.successMessage.emit("Contraseña cambiada exitosamente")
                return True
            else:
                self.errorOccurred.emit("Error", "Error cambiando contraseña")
                return False
                
        except (ValidationError, AuthenticationError) as e:
            self.errorOccurred.emit("Error", str(e))
            return False
        except Exception as e:
            self.errorOccurred.emit("Error crítico", f"Error cambiando contraseña: {str(e)}")
            return False
        finally:
            self._set_loading(False)
    
    @Slot(int, str, result=bool)
    def resetearContrasena(self, usuario_id: int, nueva_contrasena: str) -> bool:
        """Reset de contraseña por administrador"""
        try:
            self._set_loading(True)
            
            success = self.repository.reset_password(usuario_id, nueva_contrasena)
            
            if success:
                self.successMessage.emit("Contraseña reseteada exitosamente")
                return True
            else:
                self.errorOccurred.emit("Error", "Error reseteando contraseña")
                return False
                
        except (ValidationError, AuthenticationError) as e:
            self.errorOccurred.emit("Error", str(e))
            return False
        except Exception as e:
            self.errorOccurred.emit("Error crítico", f"Error reseteando contraseña: {str(e)}")
            return False
        finally:
            self._set_loading(False)
    
    # --- CONSULTAS ESPECÍFICAS ---
    
    @Slot(result=list)
    def obtenerAdministradores(self) -> List[Dict[str, Any]]:
        """Obtiene lista de administradores"""
        try:
            return self.repository.get_administrators()
        except Exception as e:
            self.errorOccurred.emit("Error", f"Error obteniendo administradores: {str(e)}")
            return []
    
    @Slot(result=list)
    def obtenerMedicos(self) -> List[Dict[str, Any]]:
        """Obtiene lista de médicos"""
        try:
            return self.repository.get_doctors()
        except Exception as e:
            self.errorOccurred.emit("Error", f"Error obteniendo médicos: {str(e)}")
            return []
    
    @Slot(int, result='QVariantMap')
    def obtenerUsuarioPorId(self, usuario_id: int) -> Dict[str, Any]:
        """Obtiene usuario específico por ID"""
        try:
            usuario = self.repository.get_by_id_with_role(usuario_id)
            return usuario if usuario else {}
        except Exception as e:
            self.errorOccurred.emit("Error", f"Error obteniendo usuario: {str(e)}")
            return {}
    
    # --- RECARGA DE DATOS ---
        
    @Slot()
    def recargarDatos(self):
        """Recarga todos los datos desde la base de datos"""
        try:
            self._set_loading(True)
            print("🔄 Iniciando recarga de datos de usuarios...")
            
            # Cargar datos desde la base de datos
            self._cargar_datos_iniciales()
            
            # Emitir señal de éxito
            self.successMessage.emit("Datos recargados exitosamente")
            print("✅ Datos recargados desde QML")
            
            # IMPORTANTE: Forzar emisión de señal usuariosChanged
            print(f"📊 Total usuarios cargados: {len(self._usuarios)}")
            print(f"📊 Total usuarios filtrados: {len(self._usuarios_filtrados)}")
            
            # Emitir señales de cambio para notificar a todos los QML conectados
            self.usuariosChanged.emit()
            self.estadisticasChanged.emit()
            
        except Exception as e:
            error_msg = f"Error recargando datos: {str(e)}"
            print(f"❌ {error_msg}")
            self.errorOccurred.emit("Error", error_msg)
        finally:
            self._set_loading(False)
    
    @Slot()
    def recargarUsuarios(self):
        """Recarga solo la lista de usuarios"""
        try:
            self._cargar_usuarios()
            print("🔄 Usuarios recargados")
        except Exception as e:
            self.errorOccurred.emit("Error", f"Error recargando usuarios: {str(e)}")
    
    # --- UTILIDADES ---
    
    @Slot(result=list)
    def obtenerRolesDisponibles(self) -> List[str]:
        """Obtiene lista de nombres de roles para ComboBox"""
        try:
            roles = self.repository.get_active_roles()
            return ["Todos los roles"] + [rol['Nombre'] for rol in roles]
        except Exception as e:
            self.errorOccurred.emit("Error", f"Error obteniendo roles: {str(e)}")
            return ["Todos los roles"]
    
    @Slot(result=list)
    def obtenerEstadosDisponibles(self) -> List[str]:
        """Obtiene lista de estados para ComboBox"""
        return ["Todos", "Activo", "Inactivo"]
    
    @Slot()
    def limpiarCache(self):
        """Limpia el caché del sistema"""
        try:
            self.repository.refresh_cache()
            self.successMessage.emit("Caché limpiado exitosamente")
            print("🗑️ Caché limpiado desde QML")
        except Exception as e:
            self.errorOccurred.emit("Error", f"Error limpiando caché: {str(e)}")
    
    @Slot(str, result=bool)
    def validarEmail(self, email: str) -> bool:
        """Valida formato de email"""
        try:
            return self.repository.email_exists(email) == False  # Email válido si NO existe
        except Exception:
            return False
    
    @Slot(int, result=str)
    def obtenerNombreRol(self, rol_id: int) -> str:
        """Obtiene nombre del rol por ID"""
        try:
            rol = self.repository.get_role_by_id(rol_id)
            return rol['Nombre'] if rol else "Desconocido"
        except Exception:
            return "Desconocido"
    
    # ===============================
    # MÉTODOS PRIVADOS
    # ===============================
    
    def _cargar_datos_iniciales(self):
        """Carga todos los datos necesarios al inicializar"""
        try:
            self._cargar_usuarios()
            self._cargar_roles()
            self._cargar_estadisticas()
            print("📊 Datos iniciales cargados")
        except Exception as e:
            print(f"❌ Error cargando datos iniciales: {e}")
            self.errorOccurred.emit("Error inicial", f"Error cargando datos: {str(e)}")
    
    def _cargar_usuarios(self):
        """Carga lista de usuarios desde el repository"""
        try:
            usuarios = self.repository.get_all_with_roles()
            self._usuarios = usuarios
            self._usuarios_filtrados = usuarios.copy()
            self.usuariosChanged.emit()
            print(f"👥 Usuarios cargados: {len(usuarios)}")
        except Exception as e:
            print(f"❌ Error cargando usuarios: {e}")
            raise e
    
    def _cargar_roles(self):
        """Carga lista de roles desde el repository"""
        try:
            roles = self.repository.get_all_roles()
            self._roles = roles
            self.rolesChanged.emit()
            print(f"🏷️ Roles cargados: {len(roles)}")
        except Exception as e:
            print(f"❌ Error cargando roles: {e}")
            raise e
    
    def _cargar_estadisticas(self):
        """Carga estadísticas desde el repository"""
        try:
            estadisticas = self.repository.get_user_statistics()
            self._estadisticas = estadisticas
            self.estadisticasChanged.emit()
            print("📈 Estadísticas cargadas")
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

def register_usuario_model():
    """Registra el UsuarioModel para uso en QML"""
    qmlRegisterType(UsuarioModel, "ClinicaModels", 1, 0, "UsuarioModel")
    print("🔗 UsuarioModel registrado para QML")

# Para facilitar la importación
__all__ = ['UsuarioModel', 'register_usuario_model']