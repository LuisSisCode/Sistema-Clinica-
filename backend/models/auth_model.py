# backend/models/auth_model.py

from typing import Dict, Any, Optional
from PySide6.QtCore import QObject, Signal, Slot, Property, QTimer
from PySide6.QtQml import qmlRegisterType

from ..repositories.auth_repository import AuthRepository
from ..core.excepciones import ExceptionHandler, AuthenticationError

class AuthModel(QObject):
    """
    Model QObject para autenticación y gestión de sesiones en QML
    Conecta la interfaz QML con el AuthRepository
    """
    
    # ===============================
    # SIGNALS - Notificaciones a QML
    # ===============================
    
    # Señales de autenticación
    loginSuccessful = Signal(str, 'QVariantMap')  # token, userData
    loginFailed = Signal(str, str)  # error, code
    logoutCompleted = Signal(str)  # message
    
    # Señales de estado
    isAuthenticatedChanged = Signal()
    currentUserChanged = Signal()
    sessionTokenChanged = Signal()
    loadingChanged = Signal()
    
    # Señales de sesión
    sessionExpired = Signal(str)  # message
    sessionValidated = Signal('QVariantMap')  # userData
    sessionInvalid = Signal(str)  # reason
    
    # Señales de error
    errorOccurred = Signal(str, str)  # title, message
    warningMessage = Signal(str)  # message
    
    def __init__(self, parent=None):
        super().__init__(parent)
        
        # Repository en lugar de service
        self.repository = AuthRepository()
        
        # Estado interno
        self._is_authenticated: bool = False
        self._current_user: Optional[Dict[str, Any]] = None
        self._session_token: str = ""
        self._loading: bool = False
        self._session_timeout: int = 0
        self._remember_me: bool = False
        
        # Auto-limpieza de sesiones cada 5 minutos
        self._setup_session_cleanup()
        
        print("🔐 AuthModel inicializado")
    
    # ===============================
    # PROPERTIES - Datos para QML
    # ===============================
    
    @Property(bool, notify=isAuthenticatedChanged)
    def isAuthenticated(self) -> bool:
        """Indica si el usuario está autenticado"""
        return self._is_authenticated
    
    @Property('QVariantMap', notify=currentUserChanged)
    def currentUser(self) -> Dict[str, Any]:
        """Información del usuario actual"""
        return self._current_user or {}
    
    @Property(str, notify=sessionTokenChanged)
    def sessionToken(self) -> str:
        """Token de sesión actual"""
        return self._session_token
    
    @Property(bool, notify=loadingChanged)
    def loading(self) -> bool:
        """Estado de carga"""
        return self._loading
    
    @Property(int)
    def sessionTimeout(self) -> int:
        """Tiempo de expiración de sesión en segundos"""
        return self._session_timeout
    
    @Property(str)
    def userName(self) -> str:
        """Nombre del usuario actual"""
        if self._current_user:
            return self._current_user.get('nombre_completo', '')
        return ""
    
    @Property(str)
    def userRole(self) -> str:
        """Rol del usuario actual"""
        if self._current_user:
            return self._current_user.get('rol_nombre', '')
        return ""
    
    @Property(str)
    def userEmail(self) -> str:
        """Email del usuario actual"""
        if self._current_user:
            return self._current_user.get('correo', '')
        return ""
    
    @Property('QVariantMap')
    def userPermissions(self) -> Dict[str, Any]:
        """Permisos del usuario actual"""
        if self._current_user:
            return self._current_user.get('permisos', {})
        return {}
    
    # ===============================
    # SLOTS - Métodos llamables desde QML
    # ===============================
    
    @Slot(str, str, bool)
    def login(self, email: str, password: str, remember_me: bool = False):
        """
        Autentica usuario desde QML
        
        Args:
            email: Correo electrónico
            password: Contraseña
            remember_me: Si recordar la sesión
        """
        try:
            self._set_loading(True)
            self._remember_me = remember_me
            
            # Validaciones básicas en el frontend
            if not email.strip():
                self.loginFailed.emit("Email requerido", "VALIDATION_ERROR")
                return
            
            if not password.strip():
                self.loginFailed.emit("Contraseña requerida", "VALIDATION_ERROR")
                return
            
            # Intentar login usando el repository
            resultado = self.repository.authenticate_user(email.strip(), password)
            
            if resultado['success']:
                # Login exitoso
                self._session_token = resultado['token']
                self._current_user = resultado['usuario']
                self._is_authenticated = True
                self._session_timeout = resultado.get('session_timeout', 28800)
                
                # Emitir señales
                self.sessionTokenChanged.emit()
                self.currentUserChanged.emit()
                self.isAuthenticatedChanged.emit()
                
                self.loginSuccessful.emit(self._session_token, self._current_user)
                
                print(f"🔓 Login exitoso: {email}")
                
            else:
                # Login fallido
                self.loginFailed.emit(
                    resultado['error'], 
                    resultado.get('code', 'LOGIN_ERROR')
                )
                print(f"❌ Login fallido: {email}")
                
        except Exception as e:
            self.loginFailed.emit(f"Error inesperado: {str(e)}", "INTERNAL_ERROR")
            self.errorOccurred.emit("Error de autenticación", str(e))
        finally:
            self._set_loading(False)
    
    @Slot()
    def logout(self):
        """Cierra sesión del usuario"""
        try:
            self._set_loading(True)
            
            # Cerrar sesión usando el repository
            if self._session_token:
                resultado = self.repository.logout_user(self._session_token)
                
                if resultado['success']:
                    self.logoutCompleted.emit(resultado['message'])
                else:
                    self.warningMessage.emit(f"Advertencia al cerrar sesión: {resultado['error']}")
            
            # Limpiar estado local
            self._clear_session()
            
            print("🚪 Logout exitoso")
            
        except Exception as e:
            self.errorOccurred.emit("Error cerrando sesión", str(e))
            # Limpiar estado de todas formas
            self._clear_session()
        finally:
            self._set_loading(False)
    
    @Slot(result=bool)
    def validateCurrentSession(self) -> bool:
        """Valida la sesión actual"""
        try:
            if not self._session_token:
                return False
            
            resultado = self.repository.verify_session(self._session_token)
            
            if resultado['valid']:
                # Sesión válida, actualizar datos del usuario
                self._current_user = resultado['usuario']
                self.currentUserChanged.emit()
                self.sessionValidated.emit(self._current_user)
                return True
            else:
                # Sesión inválida
                self._handle_invalid_session(resultado.get('error', 'Sesión inválida'))
                return False
                
        except Exception as e:
            self.errorOccurred.emit("Error validando sesión", str(e))
            return False
    
    @Slot(str, result=bool)
    def validateSessionToken(self, token: str) -> bool:
        """Valida un token de sesión específico"""
        try:
            resultado = self.repository.verify_session(token)
            return resultado['valid']
        except Exception:
            return False
    
    @Slot()
    def refreshSession(self):
        """Refresca la sesión actual"""
        if self._session_token:
            self.validateCurrentSession()
    
    @Slot(str, result=bool)
    def hasPermission(self, permission: str) -> bool:
        """Verifica si el usuario tiene un permiso específico"""
        if not self._current_user:
            return False
        
        permisos = self._current_user.get('permisos', {})
        return permisos.get(permission, False)
    
    @Slot(result=bool)
    def isAdmin(self) -> bool:
        """Verifica si el usuario es administrador"""
        if not self._current_user:
            return False
        return self._current_user.get('rol_nombre', '').lower() == 'administrador'
    
    @Slot(result=bool)
    def isMedico(self) -> bool:
        """Verifica si el usuario es médico"""
        if not self._current_user:
            return False
        rol = self._current_user.get('rol_nombre', '').lower()
        return rol == 'médico' or rol == 'medico'
    
    @Slot(result='QVariantList')
    def getActiveSessions(self) -> list:
        """Obtiene lista de sesiones activas (solo admin)"""
        try:
            if not self.isAdmin():
                return []
            
            return self.repository.get_active_sessions()
        except Exception as e:
            self.errorOccurred.emit("Error obteniendo sesiones", str(e))
            return []
    
    @Slot(str, result=str)
    def getUserDisplayName(self, format_type: str = "full") -> str:
        """
        Obtiene nombre formateado del usuario
        
        Args:
            format_type: 'full', 'short', 'formal'
        """
        if not self._current_user:
            return ""
        
        nombre = self._current_user.get('nombre_completo', '')
        
        if format_type == "short":
            # Solo primer nombre y apellido
            partes = nombre.split()
            return f"{partes[0]} {partes[1]}" if len(partes) >= 2 else nombre
        elif format_type == "formal":
            # Con título según rol
            rol = self._current_user.get('rol_nombre', '')
            if rol.lower() in ['médico', 'medico']:
                return f"Dr. {nombre}"
            else:
                return nombre
        else:
            return nombre
    
    @Slot()
    def clearRememberedCredentials(self):
        """Limpia credenciales recordadas"""
        self._remember_me = False
        # En implementación real, limpiar del almacenamiento local
        print("🧹 Credenciales recordadas limpiadas")
    
    # ===============================
    # SLOTS PARA GESTIÓN DE USUARIOS
    # ===============================
    
    @Slot(str, str, str, str, str, int, result=bool)
    def crearUsuario(self, nombre: str, apellido_paterno: str, apellido_materno: str,
                    email: str, password: str, rol_id: int = 1) -> bool:
        """Crea nuevo usuario (solo admin)"""
        try:
            if not self.isAdmin():
                self.errorOccurred.emit("Acceso denegado", "Solo administradores pueden crear usuarios")
                return False
            
            self._set_loading(True)
            
            user_id = self.repository.create_user(
                nombre=nombre,
                apellido_paterno=apellido_paterno,
                apellido_materno=apellido_materno,
                email=email,
                password=password,
                rol_id=rol_id
            )
            
            if user_id:
                print(f"✅ Usuario creado desde QML: {email} - ID: {user_id}")
                return True
            else:
                self.errorOccurred.emit("Error", "No se pudo crear el usuario")
                return False
                
        except Exception as e:
            self.errorOccurred.emit("Error crítico", f"Error creando usuario: {str(e)}")
            return False
        finally:
            self._set_loading(False)
    
    @Slot(str, result=bool)
    def cambiarPassword(self, new_password: str) -> bool:
        """Cambia contraseña del usuario actual"""
        try:
            if not self._current_user:
                self.errorOccurred.emit("Error", "No hay usuario autenticado")
                return False
            
            self._set_loading(True)
            
            success = self.repository.update_user_password(
                self._current_user['id'],
                new_password
            )
            
            if success:
                # Cerrar sesión para forzar nuevo login
                self.logout()
                print("🔑 Contraseña cambiada exitosamente")
                return True
            else:
                self.errorOccurred.emit("Error", "No se pudo cambiar la contraseña")
                return False
                
        except Exception as e:
            self.errorOccurred.emit("Error crítico", f"Error cambiando contraseña: {str(e)}")
            return False
        finally:
            self._set_loading(False)
    
    @Slot(str, result=bool)
    def emailExists(self, email: str) -> bool:
        """Verifica si un email ya está registrado"""
        try:
            return self.repository.email_exists(email)
        except Exception:
            return False
    
    # ===============================
    # MÉTODOS PRIVADOS
    # ===============================
    
    def _set_loading(self, loading: bool):
        """Actualiza estado de carga"""
        if self._loading != loading:
            self._loading = loading
            self.loadingChanged.emit()
    
    def _clear_session(self):
        """Limpia el estado de la sesión"""
        old_authenticated = self._is_authenticated
        
        self._is_authenticated = False
        self._current_user = None
        self._session_token = ""
        self._session_timeout = 0
        
        # Emitir señales solo si cambió el estado
        if old_authenticated:
            self.isAuthenticatedChanged.emit()
        
        self.currentUserChanged.emit()
        self.sessionTokenChanged.emit()
    
    def _handle_invalid_session(self, reason: str):
        """Maneja sesión inválida"""
        self._clear_session()
        
        if "expired" in reason.lower() or "expirada" in reason.lower():
            self.sessionExpired.emit("Su sesión ha expirado. Por favor, inicie sesión nuevamente.")
        else:
            self.sessionInvalid.emit(reason)
    
    def _setup_session_cleanup(self):
        """Configura limpieza automática de sesiones"""
        self.cleanup_timer = QTimer()
        self.cleanup_timer.timeout.connect(self._cleanup_expired_sessions)
        self.cleanup_timer.start(300000)  # 5 minutos
    
    def _cleanup_expired_sessions(self):
        """Limpia sesiones expiradas automáticamente"""
        try:
            cleaned = self.repository.cleanup_expired_sessions()
            if cleaned > 0:
                print(f"🧹 {cleaned} sesiones expiradas limpiadas automáticamente")
        except Exception as e:
            print(f"⚠️ Error en limpieza automática: {e}")
    
    # ===============================
    # MÉTODOS DE ESTADO
    # ===============================
    
    @Slot(result='QVariantMap')
    def getSessionInfo(self) -> Dict[str, Any]:
        """Obtiene información de la sesión actual"""
        return {
            'is_authenticated': self._is_authenticated,
            'session_token': self._session_token[:8] + "..." if self._session_token else "",
            'user_email': self.userEmail,
            'user_role': self.userRole,
            'session_timeout': self._session_timeout,
            'remember_me': self._remember_me
        }
    
    @Slot(result='QVariantMap')
    def getAuthStats(self) -> Dict[str, Any]:
        """Obtiene estadísticas de autenticación (admin only)"""
        try:
            if not self.isAdmin():
                return {}
            
            return self.repository.get_auth_statistics()
        except Exception:
            return {}
    
    @Slot(result='QVariantList')
    def getUsuariosActivos(self) -> list:
        """Obtiene lista de usuarios activos (admin only)"""
        try:
            if not self.isAdmin():
                return []
            
            return self.repository.get_active_users()
        except Exception as e:
            self.errorOccurred.emit("Error", f"Error obteniendo usuarios: {str(e)}")
            return []
    
    @Slot(int, result='QVariantList')
    def getSesionesUsuario(self, user_id: int) -> list:
        """Obtiene sesiones de un usuario específico (admin only)"""
        try:
            if not self.isAdmin():
                return []
            
            return self.repository.get_user_sessions(user_id)
        except Exception as e:
            self.errorOccurred.emit("Error", f"Error obteniendo sesiones: {str(e)}")
            return []
    
    @Slot()
    def limpiarSesionesExpiradas(self):
        """Limpia sesiones expiradas manualmente (admin only)"""
        try:
            if not self.isAdmin():
                self.errorOccurred.emit("Acceso denegado", "Solo administradores")
                return
            
            cleaned = self.repository.cleanup_expired_sessions()
            if cleaned > 0:
                print(f"🧹 {cleaned} sesiones expiradas limpiadas manualmente")
            else:
                print("✅ No hay sesiones expiradas que limpiar")
                
        except Exception as e:
            self.errorOccurred.emit("Error", f"Error limpiando sesiones: {str(e)}")
    
    def __del__(self):
        """Destructor para limpieza"""
        if hasattr(self, 'cleanup_timer'):
            self.cleanup_timer.stop()

# ===============================
# REGISTRO PARA QML
# ===============================

def register_auth_model():
    """Registra el AuthModel para uso en QML"""
    qmlRegisterType(AuthModel, "ClinicaModels", 1, 0, "AuthModel")
    print("🔗 AuthModel registrado para QML")

# Para facilitar la importación
__all__ = ['AuthModel', 'register_auth_model']