from typing import List, Dict, Any, Optional
from datetime import datetime, timedelta
import hashlib
import secrets

from ..core.base_repository import BaseRepository
from ..core.excepciones import (
    ValidationError, ExceptionHandler, validate_required
)
from ..core.cache_system import cached_query
from ..core.utils import (
    validate_required_string, validate_email, get_current_datetime
)

class AuthRepository(BaseRepository):
    """Repository para gestión de Autenticación y Sesiones"""
    
    def __init__(self):
        super().__init__('Usuario', 'auth')
        print("🔐 AuthRepository inicializado")
    
    # ===============================
    # IMPLEMENTACIÓN ABSTRACTA
    # ===============================
    
    def get_active(self) -> List[Dict[str, Any]]:
        """Obtiene usuarios activos"""
        return self.get_active_users()
    
    # ===============================
    # AUTENTICACIÓN
    # ===============================
    
    def authenticate_user(self, email: str, password: str) -> Dict[str, Any]:
        """
        Autentica usuario con email y contraseña
        
        Args:
            email: Correo electrónico del usuario
            password: Contraseña en texto plano
            
        Returns:
            Dict con resultado de autenticación
        """
        # Validaciones
        email = validate_email(email, "email")
        validate_required_string(password, "password", 6)
        
        # Buscar usuario por email
        user = self.get_user_by_email(email)
        if not user:
            return {
                'success': False,
                'error': 'Credenciales incorrectas',
                'code': 'INVALID_CREDENTIALS'
            }
        
        # Verificar que el usuario esté activo
        if not user.get('Estado', False):
            return {
                'success': False,
                'error': 'Usuario inactivo',
                'code': 'USER_INACTIVE'
            }
        
        # Verificar contraseña (en implementación real, usar hash)
        # Por simplicidad, asumir contraseña plana por ahora
        stored_password = user.get('Password', '')
        if not self._verify_password(password, stored_password):
            return {
                'success': False,
                'error': 'Credenciales incorrectas',
                'code': 'INVALID_CREDENTIALS'
            }
        
        # Crear sesión
        session_token = self._generate_session_token()
        session_id = self._create_user_session(user['id'], session_token)
        
        if not session_id:
            return {
                'success': False,
                'error': 'Error creando sesión',
                'code': 'SESSION_ERROR'
            }
        
        # Obtener información completa del usuario
        user_info = self._prepare_user_info(user)
        
        return {
            'success': True,
            'token': session_token,
            'usuario': user_info,
            'session_timeout': 28800,  # 8 horas en segundos
            'message': f'Bienvenido, {user_info["nombre_completo"]}'
        }
    
    def logout_user(self, session_token: str) -> Dict[str, Any]:
        """
        Cierra sesión del usuario
        
        Args:
            session_token: Token de sesión a cerrar
            
        Returns:
            Dict con resultado del logout
        """
        validate_required_string(session_token, "session_token", 10)
        
        # Invalidar sesión
        success = self._invalidate_session(session_token)
        
        if success:
            return {
                'success': True,
                'message': 'Sesión cerrada exitosamente'
            }
        else:
            return {
                'success': False,
                'error': 'Error cerrando sesión',
                'code': 'LOGOUT_ERROR'
            }
    
    def verify_session(self, session_token: str) -> Dict[str, Any]:
        """
        Verifica validez de una sesión
        
        Args:
            session_token: Token de sesión a verificar
            
        Returns:
            Dict con resultado de verificación
        """
        validate_required_string(session_token, "session_token", 10)
        
        session = self._get_session_by_token(session_token)
        
        if not session:
            return {
                'valid': False,
                'error': 'Sesión no encontrada',
                'code': 'SESSION_NOT_FOUND'
            }
        
        # Verificar expiración
        if self._is_session_expired(session):
            self._invalidate_session(session_token)
            return {
                'valid': False,
                'error': 'Sesión expirada',
                'code': 'SESSION_EXPIRED'
            }
        
        # Obtener usuario actualizado
        user = self.get_by_id(session['Id_Usuario'])
        if not user or not user.get('Estado', False):
            self._invalidate_session(session_token)
            return {
                'valid': False,
                'error': 'Usuario inactivo',
                'code': 'USER_INACTIVE'
            }
        
        # Actualizar último acceso
        self._update_session_last_access(session['id'])
        
        return {
            'valid': True,
            'usuario': self._prepare_user_info(user),
            'session_expires_at': session['Fecha_Expiracion']
        }
    
    # ===============================
    # GESTIÓN DE USUARIOS
    # ===============================
    
    @cached_query('usuarios_activos', ttl=600)
    def get_active_users(self) -> List[Dict[str, Any]]:
        """Obtiene usuarios activos con información básica"""
        query = """
        SELECT u.id, u.Nombre, u.Apellido_Paterno, u.Apellido_Materno,
               u.correo, u.Estado, u.fecha_creacion,
               r.id as rol_id, r.nombre as rol_nombre
        FROM Usuario u
        LEFT JOIN Rol r ON u.rol_id = r.id
        WHERE u.Estado = 1
        ORDER BY u.Nombre, u.Apellido_Paterno
        """
        return self._execute_query(query)
    
    def get_user_by_email(self, email: str) -> Optional[Dict[str, Any]]:
        """Obtiene usuario por email"""
        query = """
        SELECT u.*, r.nombre as rol_nombre
        FROM Usuario u
        LEFT JOIN Rol r ON u.rol_id = r.id
        WHERE u.correo = ?
        """
        return self._execute_query(query, (email.strip().lower(),), fetch_one=True)
    
    def get_user_by_id_with_role(self, user_id: int) -> Optional[Dict[str, Any]]:
        """Obtiene usuario por ID con información de rol"""
        query = """
        SELECT u.*, r.nombre as rol_nombre, r.permisos
        FROM Usuario u
        LEFT JOIN Rol r ON u.rol_id = r.id
        WHERE u.id = ?
        """
        return self._execute_query(query, (user_id,), fetch_one=True)
    
    def create_user(self, nombre: str, apellido_paterno: str, apellido_materno: str,
                   email: str, password: str, rol_id: int = 1) -> int:
        """
        Crea nuevo usuario
        
        Args:
            nombre: Nombre del usuario
            apellido_paterno: Apellido paterno
            apellido_materno: Apellido materno
            email: Correo electrónico
            password: Contraseña en texto plano
            rol_id: ID del rol (por defecto 1)
            
        Returns:
            ID del usuario creado
        """
        # Validaciones
        nombre = validate_required_string(nombre, "nombre", 2)
        apellido_paterno = validate_required_string(apellido_paterno, "apellido_paterno", 2)
        apellido_materno = validate_required_string(apellido_materno, "apellido_materno", 2)
        email = validate_email(email, "email")
        validate_required_string(password, "password", 6)
        
        # Verificar que el email no exista
        if self.email_exists(email):
            raise ValidationError("email", email, "Email ya registrado")
        
        # Hash de la contraseña (simplificado)
        password_hash = self._hash_password(password)
        
        user_data = {
            'Nombre': nombre.strip().title(),
            'Apellido_Paterno': apellido_paterno.strip().title(),
            'Apellido_Materno': apellido_materno.strip().title(),
            'correo': email.strip().lower(),
            'Password': password_hash,
            'rol_id': rol_id,
            'Estado': 1,
            'fecha_creacion': get_current_datetime()
        }
        
        user_id = self.insert(user_data)
        print(f"👤 Usuario creado: {email} - ID: {user_id}")
        
        return user_id
    
    def update_user_password(self, user_id: int, new_password: str) -> bool:
        """Actualiza contraseña del usuario"""
        validate_required_string(new_password, "new_password", 6)
        
        password_hash = self._hash_password(new_password)
        success = self.update(user_id, {'Password': password_hash})
        
        if success:
            # Invalidar todas las sesiones del usuario
            self._invalidate_user_sessions(user_id)
            print(f"🔑 Contraseña actualizada para usuario ID: {user_id}")
        
        return success
    
    def email_exists(self, email: str) -> bool:
        """Verifica si existe un email"""
        query = "SELECT COUNT(*) as count FROM Usuario WHERE correo = ?"
        result = self._execute_query(query, (email.strip().lower(),), fetch_one=True)
        return result['count'] > 0 if result else False
    
    # ===============================
    # GESTIÓN DE SESIONES
    # ===============================
    
    def get_active_sessions(self) -> List[Dict[str, Any]]:
        """Obtiene sesiones activas"""
        query = """
        SELECT s.id, s.token, s.Fecha_Creacion, s.Fecha_Ultimo_Acceso, s.Fecha_Expiracion,
               CONCAT(u.Nombre, ' ', u.Apellido_Paterno, ' ', u.Apellido_Materno) as usuario_completo,
               u.correo as usuario_email, r.nombre as rol_nombre
        FROM Sesiones_Usuario s
        INNER JOIN Usuario u ON s.Id_Usuario = u.id
        LEFT JOIN Rol r ON u.rol_id = r.id
        WHERE s.Activa = 1 AND s.Fecha_Expiracion > GETDATE()
        ORDER BY s.Fecha_Ultimo_Acceso DESC
        """
        return self._execute_query(query)
    
    def cleanup_expired_sessions(self) -> int:
        """Limpia sesiones expiradas"""
        query = """
        UPDATE Sesiones_Usuario 
        SET Activa = 0 
        WHERE Activa = 1 AND Fecha_Expiracion <= GETDATE()
        """
        affected_rows = self._execute_query(query, fetch_all=False, use_cache=False)
        
        if affected_rows > 0:
            print(f"🧹 {affected_rows} sesiones expiradas limpiadas")
        
        return affected_rows
    
    def get_user_sessions(self, user_id: int) -> List[Dict[str, Any]]:
        """Obtiene sesiones de un usuario específico"""
        query = """
        SELECT id, token, Fecha_Creacion, Fecha_Ultimo_Acceso, Fecha_Expiracion, Activa
        FROM Sesiones_Usuario
        WHERE Id_Usuario = ?
        ORDER BY Fecha_Creacion DESC
        """
        return self._execute_query(query, (user_id,))
    
    # ===============================
    # ESTADÍSTICAS
    # ===============================
    
    @cached_query('auth_stats', ttl=300)
    def get_auth_statistics(self) -> Dict[str, Any]:
        """Obtiene estadísticas de autenticación"""
        # Estadísticas generales
        general_query = """
        SELECT 
            COUNT(*) as total_usuarios,
            SUM(CASE WHEN Estado = 1 THEN 1 ELSE 0 END) as usuarios_activos,
            SUM(CASE WHEN Estado = 0 THEN 1 ELSE 0 END) as usuarios_inactivos
        FROM Usuario
        """
        
        # Sesiones activas
        sessions_query = """
        SELECT COUNT(*) as sesiones_activas
        FROM Sesiones_Usuario
        WHERE Activa = 1 AND Fecha_Expiracion > GETDATE()
        """
        
        # Por roles
        roles_query = """
        SELECT r.nombre as rol, COUNT(u.id) as cantidad_usuarios
        FROM Rol r
        LEFT JOIN Usuario u ON r.id = u.rol_id AND u.Estado = 1
        GROUP BY r.id, r.nombre
        ORDER BY cantidad_usuarios DESC
        """
        
        general_stats = self._execute_query(general_query, fetch_one=True)
        sessions_stats = self._execute_query(sessions_query, fetch_one=True)
        roles_stats = self._execute_query(roles_query)
        
        return {
            'general': general_stats,
            'sesiones': sessions_stats,
            'por_roles': roles_stats
        }
    
    # ===============================
    # MÉTODOS PRIVADOS
    # ===============================
    
    def _generate_session_token(self) -> str:
        """Genera token único para sesión"""
        return secrets.token_urlsafe(32)
    
    def _hash_password(self, password: str) -> str:
        """Hash simple de contraseña (usar bcrypt en producción)"""
        return hashlib.sha256(password.encode()).hexdigest()
    
    def _verify_password(self, password: str, password_hash: str) -> bool:
        """Verifica contraseña contra hash"""
        return self._hash_password(password) == password_hash
    
    def _create_user_session(self, user_id: int, session_token: str) -> Optional[int]:
        """Crea nueva sesión de usuario"""
        try:
            expiration_time = get_current_datetime() + timedelta(hours=8)
            
            session_data = {
                'Id_Usuario': user_id,
                'token': session_token,
                'Fecha_Creacion': get_current_datetime(),
                'Fecha_Ultimo_Acceso': get_current_datetime(),
                'Fecha_Expiracion': expiration_time,
                'Activa': 1
            }
            
            # Crear tabla si no existe
            self._ensure_sessions_table()
            
            query = """
            INSERT INTO Sesiones_Usuario (Id_Usuario, token, Fecha_Creacion, Fecha_Ultimo_Acceso, Fecha_Expiracion, Activa)
            OUTPUT INSERTED.id
            VALUES (?, ?, ?, ?, ?, ?)
            """
            
            result = self._execute_query(
                query, 
                (user_id, session_token, session_data['Fecha_Creacion'], 
                 session_data['Fecha_Ultimo_Acceso'], expiration_time, 1),
                fetch_one=True
            )
            
            return result['id'] if result else None
            
        except Exception as e:
            print(f"❌ Error creando sesión: {e}")
            return None
    
    def _get_session_by_token(self, session_token: str) -> Optional[Dict[str, Any]]:
        """Obtiene sesión por token"""
        query = """
        SELECT id, Id_Usuario, token, Fecha_Creacion, Fecha_Ultimo_Acceso, Fecha_Expiracion, Activa
        FROM Sesiones_Usuario
        WHERE token = ? AND Activa = 1
        """
        return self._execute_query(query, (session_token,), fetch_one=True)
    
    def _is_session_expired(self, session: Dict[str, Any]) -> bool:
        """Verifica si una sesión está expirada"""
        expiration = session.get('Fecha_Expiracion')
        if not expiration:
            return True
        
        if isinstance(expiration, str):
            from datetime import datetime
            expiration = datetime.fromisoformat(expiration)
        
        return expiration <= datetime.now()
    
    def _invalidate_session(self, session_token: str) -> bool:
        """Invalida sesión específica"""
        query = "UPDATE Sesiones_Usuario SET Activa = 0 WHERE token = ?"
        affected_rows = self._execute_query(query, (session_token,), fetch_all=False, use_cache=False)
        return affected_rows > 0
    
    def _invalidate_user_sessions(self, user_id: int) -> int:
        """Invalida todas las sesiones de un usuario"""
        query = "UPDATE Sesiones_Usuario SET Activa = 0 WHERE Id_Usuario = ?"
        affected_rows = self._execute_query(query, (user_id,), fetch_all=False, use_cache=False)
        print(f"🔒 {affected_rows} sesiones invalidadas para usuario ID: {user_id}")
        return affected_rows
    
    def _update_session_last_access(self, session_id: int) -> bool:
        """Actualiza último acceso de sesión"""
        query = "UPDATE Sesiones_Usuario SET Fecha_Ultimo_Acceso = GETDATE() WHERE id = ?"
        affected_rows = self._execute_query(query, (session_id,), fetch_all=False, use_cache=False)
        return affected_rows > 0
    
    def _prepare_user_info(self, user: Dict[str, Any]) -> Dict[str, Any]:
        """Prepara información del usuario para respuesta"""
        return {
            'id': user['id'],
            'nombre': user['Nombre'],
            'apellido_paterno': user['Apellido_Paterno'],
            'apellido_materno': user['Apellido_Materno'],
            'nombre_completo': f"{user['Nombre']} {user['Apellido_Paterno']} {user['Apellido_Materno']}",
            'correo': user['correo'],
            'rol_id': user.get('rol_id'),
            'rol_nombre': user.get('rol_nombre', 'Usuario'),
            'estado': user.get('Estado', False),
            'fecha_creacion': user.get('fecha_creacion'),
            'permisos': self._get_user_permissions(user)
        }
    
    def _get_user_permissions(self, user: Dict[str, Any]) -> Dict[str, bool]:
        """Obtiene permisos del usuario (simplificado)"""
        rol_nombre = user.get('rol_nombre', '').lower()
        
        # Permisos básicos según rol
        if rol_nombre == 'administrador':
            return {
                'farmacia_gestionar': True,
                'laboratorio_gestionar': True,
                'consultas_gestionar': True,
                'usuarios_gestionar': True,
                'reportes_acceder': True,
                'configuracion_acceder': True
            }
        elif rol_nombre == 'medico' or rol_nombre == 'médico':
            return {
                'farmacia_gestionar': False,
                'laboratorio_gestionar': True,
                'consultas_gestionar': True,
                'usuarios_gestionar': False,
                'reportes_acceder': True,
                'configuracion_acceder': False
            }
        else:
            return {
                'farmacia_gestionar': False,
                'laboratorio_gestionar': False,
                'consultas_gestionar': False,
                'usuarios_gestionar': False,
                'reportes_acceder': False,
                'configuracion_acceder': False
            }
    
    def _ensure_sessions_table(self):
        """Asegura que la tabla de sesiones existe"""
        create_table_query = """
        IF NOT EXISTS (SELECT * FROM sysobjects WHERE name='Sesiones_Usuario' AND xtype='U')
        CREATE TABLE Sesiones_Usuario (
            id INT IDENTITY(1,1) PRIMARY KEY,
            Id_Usuario INT NOT NULL,
            token NVARCHAR(255) NOT NULL UNIQUE,
            Fecha_Creacion DATETIME2 NOT NULL,
            Fecha_Ultimo_Acceso DATETIME2 NOT NULL,
            Fecha_Expiracion DATETIME2 NOT NULL,
            Activa BIT NOT NULL DEFAULT 1,
            FOREIGN KEY (Id_Usuario) REFERENCES Usuario(id)
        )
        """
        try:
            self._execute_query(create_table_query, fetch_all=False, use_cache=False)
        except Exception as e:
            print(f"⚠️ Tabla de sesiones ya existe o error: {e}")
    
    # ===============================
    # CACHÉ
    # ===============================
    
    def invalidate_auth_caches(self):
        """Invalida cachés relacionados con autenticación"""
        cache_types = ['auth', 'usuarios_activos', 'auth_stats']
        from ..core.cache_system import invalidate_after_update
        invalidate_after_update(cache_types)
    
    def _invalidate_cache_after_modification(self):
        """Override para invalidación específica"""
        super()._invalidate_cache_after_modification()
        self.invalidate_auth_caches()