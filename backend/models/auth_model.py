# backend/models/auth_model.py

from typing import Dict, Any, Optional
from PySide6.QtCore import QObject, Signal, Slot, Property
from PySide6.QtQml import qmlRegisterType

class AuthModel(QObject):
    """Model simple de autenticación sin sesiones persistentes"""
    
    # Signals para QML
    loginSuccessful = Signal(bool, str, 'QVariantMap')  # success, message, userData
    loginFailed = Signal(str)  # error message
    logoutCompleted = Signal()
    currentUserChanged = Signal()
    
    def __init__(self, parent=None):
        super().__init__(parent)
        self._current_user: Optional[Dict[str, Any]] = None
        self._is_authenticated: bool = False
        print("🔐 AuthModel inicializado")
        
    # Properties para QML
    @Property('QVariantMap', notify=currentUserChanged)
    def currentUser(self) -> Dict[str, Any]:
        return self._current_user or {}
    
    @Property(bool, notify=currentUserChanged)
    def isAuthenticated(self) -> bool:
        return self._is_authenticated
    
    @Property(str, notify=currentUserChanged)
    def userName(self) -> str:
        if self._current_user:
            return f"{self._current_user.get('Nombre', '')} {self._current_user.get('Apellido_Paterno', '')}"
        return ""
    
    @Property(str, notify=currentUserChanged)
    def userRole(self) -> str:
        return self._current_user.get('rol_nombre', '') if self._current_user else ""
    
    @Property(str, notify=currentUserChanged)
    def userUsername(self) -> str:
        return self._current_user.get('nombre_usuario', '') if self._current_user else ""
    
    # Slots para QML
    @Slot(str, str)
    def login(self, username: str, password: str):
        """Autenticación usando la BD existente"""
        try:
            print(f"🔐 Login: {username} | Pass: {password}")
            from ..repositories.usuario_repository import UsuarioRepository
            repo = UsuarioRepository()
            
            # Validaciones básicas
            if not username.strip():
                self.loginFailed.emit("Nombre de usuario requerido")
                return
            
            if not password.strip():
                self.loginFailed.emit("Contraseña requerida")
                return
            
            # Usar el repository existente
            from ..repositories.usuario_repository import UsuarioRepository
            repo = UsuarioRepository()
            
            # Autenticar usuario
            usuario = repo.authenticate(username.strip(), password)
            usuarios = repo.get_all()
            print(f"📋 Usuarios en BD: {[u.get('nombre_usuario') for u in usuarios]}")
            usuario = repo.authenticate(username.strip(), password)
            
            if usuario and usuario.get('Estado'):
                # Login exitoso
                self._current_user = usuario
                self._is_authenticated = True
                self.currentUserChanged.emit()
                
                message = f"Bienvenido, {usuario.get('Nombre', '')} {usuario.get('Apellido_Paterno', '')}"
                print(f"✅ Login exitoso: {username}")
                self.loginSuccessful.emit(True, message, usuario)
                
            else:
                # Login fallido
                print(f"❌ Login fallido: {username}")
                self.loginFailed.emit("Credenciales incorrectas o usuario inactivo")
                
        except Exception as e:
            error_msg = f"Error de autenticación: {str(e)}"
            print(f"❌ {error_msg}")
            self.loginFailed.emit(error_msg)
    
    @Slot()
    def logout(self):
        """Cerrar sesión simple"""
        try:
            user_name = self.userName
            self._current_user = None
            self._is_authenticated = False
            self.currentUserChanged.emit()
            self.logoutCompleted.emit()
            print(f"🚪 Logout exitoso: {user_name}")
        except Exception as e:
            print(f"❌ Error en logout: {e}")
    
    # Métodos de verificación de roles
    @Slot(result=bool)
    def isAdmin(self) -> bool:
        if not self._current_user:
            return False
        return self._current_user.get('rol_nombre', '').lower() == 'administrador'
    
    @Slot(result=bool)
    def isMedico(self) -> bool:
        if not self._current_user:
            return False
        rol = self._current_user.get('rol_nombre', '').lower()
        return rol in ['medico', 'médico']
    
    @Slot(result=bool)
    def canAccessFarmacia(self) -> bool:
        return self.isAdmin()
    
    @Slot(result=bool)
    def canAccessReportes(self) -> bool:
        return self.isAdmin() or self.isMedico()
    
    @Slot(result=bool)
    def canAccessUsuarios(self) -> bool:
        return self.isAdmin()
    
    # ✅ MÉTODOS AGREGADOS PARA OBTENER DATOS DEL USUARIO
    @Slot(result='QVariantMap')
    def get_user_data(self) -> Dict[str, Any]:
        """Obtiene los datos del usuario autenticado"""
        if not self._current_user:
            return {}
        return self._current_user.copy()
    
    @Slot(result=int)
    def get_user_id(self) -> int:
        """Obtiene solo el ID del usuario autenticado"""
        if not self._current_user:
            return 0
        return self._current_user.get('id', 0)
    
    @Slot(result=str)
    def get_user_name(self) -> str:
        """Obtiene el nombre completo del usuario autenticado"""
        return self.userName
    
    @Slot(result=str)
    def get_username(self) -> str:
        """Obtiene el nombre de usuario del usuario autenticado"""
        return self.userUsername
    
    @Slot(result='QVariantMap')
    def getUserInfo(self) -> Dict[str, Any]:
        """Obtiene información completa del usuario actual"""
        return {
            'authenticated': self._is_authenticated,
            'name': self.userName,
            'username': self.userUsername,
            'role': self.userRole,
            'is_admin': self.isAdmin(),
            'is_medico': self.isMedico(),
            'user_data': self._current_user or {}
        }

def register_auth_model():
    """Registra el AuthModel para uso en QML"""
    qmlRegisterType(AuthModel, "ClinicaModels", 1, 0, "AuthModel")
    print("🔗 AuthModel registrado para QML")

# Para facilitar importación
__all__ = ['AuthModel', 'register_auth_model']