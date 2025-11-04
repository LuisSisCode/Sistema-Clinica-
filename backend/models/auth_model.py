# backend/models/auth_model.py - VERSIÓN SIMPLIFICADA Y CORREGIDA

from typing import Dict, Any, Optional
from PySide6.QtCore import QObject, Signal, Slot, Property
from PySide6.QtQml import qmlRegisterType

class AuthModel(QObject):
    """Model de autenticación simplificado y corregido"""
    
    # Signals para QML
    loginSuccessful = Signal(bool, str, 'QVariantMap')  # success, message, userData
    loginFailed = Signal(str)  # error message
    logoutCompleted = Signal()
    currentUserChanged = Signal()
    
    def __init__(self, parent=None):
        super().__init__(parent)
        self._current_user: Optional[Dict[str, Any]] = None
        self._is_authenticated: bool = False
        print("🔐 AuthModel inicializado - Versión Simplificada")
        
    # Properties para QML - EXISTENTES
    @Property('QVariantMap', notify=currentUserChanged)
    def currentUser(self) -> Dict[str, Any]:
        return self._current_user.copy() if self._current_user else {}
    
    @Property(bool, notify=currentUserChanged)
    def isAuthenticated(self) -> bool:
        return self._is_authenticated
    
    @Property(str, notify=currentUserChanged)
    def userName(self) -> str:
        if self._current_user:
            nombre = self._current_user.get('Nombre', '')
            apellido = self._current_user.get('Apellido_Paterno', '')
            return f"{nombre} {apellido}".strip()
        return ""
    
    @Property(str, notify=currentUserChanged)
    def userRole(self) -> str:
        return self._current_user.get('rol_nombre', '') if self._current_user else ""
    
    @Property(str, notify=currentUserChanged)
    def userUsername(self) -> str:
        return self._current_user.get('nombre_usuario', '') if self._current_user else ""
    
    @Property(str, notify=currentUserChanged)
    def userEmail(self) -> str:
        # Si no hay email en BD, generar uno basado en username
        if self._current_user:
            email = self._current_user.get('email', '')
            if not email:
                username = self._current_user.get('nombre_usuario', '')
                if username:
                    return f"{username}@clinica.local"
        return ""
    
    # NUEVAS PROPERTIES SOLICITADAS
    @Property(int, notify=loginSuccessful)
    def current_user_id(self) -> int:
        """Property para obtener el ID del usuario actual"""
        return self.get_user_id()

    @Property(str, notify=loginSuccessful) 
    def current_user_name(self) -> str:
        """Property para obtener el nombre del usuario actual"""
        if hasattr(self, '_current_user') and self._current_user:
            nombre = self._current_user.get('Nombre', '')
            apellido = self._current_user.get('Apellido_Paterno', '')
            return f"{nombre} {apellido}".strip()
        return ""

    @Property(str, notify=loginSuccessful)
    def current_user_role(self) -> str:
        """Property para obtener el rol del usuario actual"""
        if hasattr(self, '_current_user') and self._current_user:
            return self._current_user.get('rol_nombre', '')
        return ""

    @Property(str, notify=loginSuccessful)
    def current_username(self) -> str:
        """Property para obtener el username del usuario actual"""
        if hasattr(self, '_current_user') and self._current_user:
            return self._current_user.get('nombre_usuario', '')
        return ""
    
    # Slots para QML
    @Slot(str, str)
    def login(self, username: str, password: str):
        """Autenticación usando AuthRepository con bcrypt"""
        try:
            print(f"🔐 Login attempt: {username}")
            
            # Validaciones básicas
            if not username.strip():
                self.loginFailed.emit("Nombre de usuario requerido")
                return
            
            if not password.strip():
                self.loginFailed.emit("Contraseña requerida")
                return
            
            # Limpiar estado anterior
            self._clear_current_user()
            
            # ✅ USAR authenticate_user del repository (tiene bcrypt)
            from ..repositories.auth_repository import AuthRepository
            auth_repo = AuthRepository()
            
            # Llamar al método que YA tiene bcrypt
            result = auth_repo.authenticate_user(username.strip(), password.strip())
            
            # Verificar resultado
            if not result.get('success', False):
                error = result.get('error', 'Error de autenticación')
                print(f"❌ Login fallido: {error}")
                self.loginFailed.emit(error)
                return
            
            # Login exitoso - Obtener datos del usuario
            user_data = result.get('usuario', {})
            
            if not user_data:
                print(f"❌ No se obtuvieron datos del usuario")
                self.loginFailed.emit("Error obteniendo datos del usuario")
                return
            
            # Establecer usuario actual
            self._current_user = user_data
            self._is_authenticated = True
            
            # Emitir señal de cambio
            self.currentUserChanged.emit()
            
            # Mensaje de bienvenida
            message = result.get('message', f"Bienvenido, {user_data.get('nombre_completo', '')}")
            
            print(f"✅ Login exitoso:")
            print(f"   Usuario: {username}")
            print(f"   Nombre: {user_data.get('nombre_completo', '')}")
            print(f"   Rol: {user_data.get('rol_nombre', '')}")
            print(f"   ID: {user_data.get('id', 0)}")
            
            # Emitir señal de éxito
            self.loginSuccessful.emit(True, message, self._current_user.copy())
            
        except Exception as e:
            error_msg = f"Error de autenticación: {str(e)}"
            print(f"❌ {error_msg}")
            import traceback
            traceback.print_exc()
            self._clear_current_user()
            self.loginFailed.emit(error_msg)
    
    def _clear_current_user(self):
        """Limpia el usuario actual completamente"""
        self._current_user = None
        self._is_authenticated = False
    
    @Slot()
    def logout(self):
        """Cerrar sesión simple y limpia"""
        try:
            user_name = self.userName
            user_username = self.userUsername
            
            print(f"🚪 Iniciando logout para: {user_name} ({user_username})")
            
            # Limpiar completamente
            self._clear_current_user()
            
            # Emitir señales
            self.currentUserChanged.emit()
            self.logoutCompleted.emit()
            
            print(f"✅ Logout exitoso: {user_name}")
            
        except Exception as e:
            print(f"❌ Error en logout: {e}")
            # Forzar limpieza en caso de error
            self._clear_current_user()
            self.currentUserChanged.emit()
            self.logoutCompleted.emit()
    
    # Métodos de verificación de roles - CORREGIDOS
    @Slot(result=bool)
    def isAdmin(self) -> bool:
        if not self._current_user:
            return False
        rol = self._current_user.get('rol_nombre', '').lower()
        return rol == 'administrador'
    
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
    
    # Métodos para obtener datos del usuario - SIMPLIFICADOS
    @Slot(result='QVariantMap')
    def get_user_data(self) -> Dict[str, Any]:
        """Obtiene los datos del usuario autenticado"""
        if not self._current_user:
            return {}
        
        result = self._current_user.copy()
        print(f"📋 get_user_data retornando: {result}")
        return result
    
    @Slot(result=int)
    def get_user_id(self) -> int:
        """Obtiene el ID del usuario autenticado actualmente"""
        if hasattr(self, '_current_user') and self._current_user:
            return self._current_user.get('id', 0)
        return 0
    
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
            'email': self.userEmail,
            'is_admin': self.isAdmin(),
            'is_medico': self.isMedico(),
            'user_data': self._current_user.copy() if self._current_user else {}
        }
    
    # Método adicional para debug
    @Slot()
    def debug_print_user(self):
        """Imprime información del usuario actual para debug"""
        print(f"🔍 DEBUG AuthModel:")
        print(f"   Autenticado: {self._is_authenticated}")
        print(f"   Usuario actual: {self._current_user}")
        print(f"   Nombre: {self.userName}")
        print(f"   Rol: {self.userRole}")
        print(f"   Username: {self.userUsername}")
        print(f"   Es Admin: {self.isAdmin()}")
        print(f"   Es Médico: {self.isMedico()}")

def register_auth_model():
    """Registra el AuthModel para uso en QML"""
    qmlRegisterType(AuthModel, "ClinicaModels", 1, 0, "AuthModel")
    print("🔗 AuthModel registrado para QML")

# Para facilitar importación
__all__ = ['AuthModel', 'register_auth_model']