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
        
    # Properties para QML
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
    
    # Slots para QML
    @Slot(str, str)
    def login(self, username: str, password: str):
        """Autenticación usando la BD existente - VERSIÓN CORREGIDA"""
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
            
            # Usar AuthRepository para obtener usuario con rol
            from ..repositories.auth_repository import AuthRepository
            auth_repo = AuthRepository()
            
            # Obtener usuario por username (incluye rol)
            user_data = auth_repo.get_user_by_username(username.strip())
            
            # Verificar credenciales y estado
            if not user_data:
                print(f"❌ Usuario no encontrado: {username}")
                self.loginFailed.emit("Usuario no encontrado")
                return
            
            if not user_data.get('Estado', True):
                print(f"❌ Usuario inactivo: {username}")
                self.loginFailed.emit("Usuario inactivo")
                return
            
            # Verificar contraseña
            stored_password = user_data.get('contrasena', '')
            if password != stored_password:
                print(f"❌ Contraseña incorrecta para: {username}")
                self.loginFailed.emit("Contraseña incorrecta")
                return
            
            # Verificar que tenga rol
            rol_nombre = user_data.get('rol_nombre', '')
            if not rol_nombre:
                print(f"⚠️ Usuario sin rol asignado: {username}")
                self.loginFailed.emit("Usuario sin rol asignado")
                return
            
            # Login exitoso - Establecer usuario
            self._current_user = user_data.copy()
            self._is_authenticated = True
            
            # Emitir señal de cambio
            self.currentUserChanged.emit()
            
            # Preparar mensaje de bienvenida
            full_name = self.userName
            message = f"Bienvenido, {full_name}"
            
            print(f"✅ Login exitoso:")
            print(f"   Usuario: {username}")
            print(f"   Nombre: {full_name}")
            print(f"   Rol: {rol_nombre}")
            print(f"   ID: {user_data.get('id', 0)}")
            
            # Emitir señal de éxito
            self.loginSuccessful.emit(True, message, self._current_user.copy())
            
        except Exception as e:
            error_msg = f"Error de autenticación: {str(e)}"
            print(f"❌ {error_msg}")
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