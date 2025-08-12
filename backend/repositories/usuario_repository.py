from typing import List, Dict, Any, Optional
import hashlib
import secrets
from datetime import datetime, timedelta

from ..core.base_repository import BaseRepository
from ..core.excepciones import (
    ValidationError, AuthenticationError, DatabaseQueryError,
    ExceptionHandler, validate_required, validate_email
)
from ..core.cache_system import cached_query, invalidate_after_update

class UsuarioRepository(BaseRepository):
    """Repository para gestión completa de Usuarios + Roles"""
    
    def __init__(self):
        super().__init__('Usuario', 'usuarios')
        print("👤 UsuarioRepository inicializado")
    
    # ===============================
    # IMPLEMENTACIÓN ABSTRACTA
    # ===============================
    
    def get_active(self) -> List[Dict[str, Any]]:
        """Obtiene usuarios activos con información de rol"""
        query = """
        SELECT u.*, r.Nombre as rol_nombre, r.Descripcion as rol_descripcion
        FROM Usuario u
        INNER JOIN Roles r ON u.Id_Rol = r.id
        WHERE u.Estado = 1 AND r.Estado = 1
        ORDER BY u.Nombre, u.Apellido_Paterno
        """
        return self._execute_query(query)
    
    # ===============================
    # OPERACIONES CRUD ESPECÍFICAS
    # ===============================
    
    @cached_query('usuarios', ttl=300)
    def get_all_with_roles(self) -> List[Dict[str, Any]]:
        """Obtiene todos los usuarios con información completa de roles"""
        query = """
        SELECT 
            u.id,
            u.Nombre,
            u.Apellido_Paterno,
            u.Apellido_Materno,
            u.correo,
            u.Estado,
            r.id as rol_id,
            r.Nombre as rol_nombre,
            r.Descripcion as rol_descripcion,
            r.Estado as rol_estado
        FROM Usuario u
        INNER JOIN Roles r ON u.Id_Rol = r.id
        ORDER BY u.Estado DESC, u.Nombre, u.Apellido_Paterno
        """
        return self._execute_query(query)
    
    def get_by_id_with_role(self, usuario_id: int) -> Optional[Dict[str, Any]]:
        """Obtiene usuario por ID con información de rol"""
        query = """
        SELECT 
            u.id,
            u.Nombre,
            u.Apellido_Paterno,
            u.Apellido_Materno,
            u.correo,
            u.Estado,
            r.id as rol_id,
            r.Nombre as rol_nombre,
            r.Descripcion as rol_descripcion
        FROM Usuario u
        INNER JOIN Roles r ON u.Id_Rol = r.id
        WHERE u.id = ?
        """
        return self._execute_query(query, (usuario_id,), fetch_one=True)
    
    def create_user(self, nombre: str, apellido_paterno: str, apellido_materno: str,
                   correo: str, contrasena: str, rol_id: int, estado: bool = True) -> int:
        """
        Crea nuevo usuario con validaciones completas
        
        Args:
            nombre: Nombre del usuario
            apellido_paterno: Apellido paterno
            apellido_materno: Apellido materno  
            correo: Email único
            contrasena: Contraseña en texto plano (se hasheará)
            rol_id: ID del rol asignado
            estado: Estado activo/inactivo
            
        Returns:
            ID del usuario creado
            
        Raises:
            ValidationError: Si los datos no son válidos
            DatabaseQueryError: Si hay errores de BD
        """
        # Validaciones
        validate_required(nombre, "nombre")
        validate_required(apellido_paterno, "apellido_paterno")
        validate_required(apellido_materno, "apellido_materno")
        validate_required(correo, "correo")
        validate_required(contrasena, "contrasena")
        validate_required(rol_id, "rol_id")
        
        validate_email(correo)
        
        # Validar contraseña fuerte
        self._validate_password_strength(contrasena)
        
        # Verificar que el email no exista
        if self.email_exists(correo):
            raise ValidationError("correo", correo, "Email ya existe en el sistema")
        
        # Verificar que el rol exista y esté activo
        if not self._role_exists_and_active(rol_id):
            raise ValidationError("rol_id", rol_id, "Rol no existe o está inactivo")
        
        # Hashear contraseña
        hashed_password = self._hash_password(contrasena)
        
        # Crear usuario
        user_data = {
            'Nombre': nombre.strip(),
            'Apellido_Paterno': apellido_paterno.strip(),
            'Apellido_Materno': apellido_materno.strip(),
            'correo': correo.lower().strip(),
            'contrasena': hashed_password,
            'Id_Rol': rol_id,
            'Estado': estado
        }
        
        user_id = self.insert(user_data)
        print(f"👤 Usuario creado: {nombre} {apellido_paterno} - ID: {user_id}")
        
        return user_id
    
    def update_user(self, usuario_id: int, nombre: str = None, apellido_paterno: str = None,
                   apellido_materno: str = None, correo: str = None, rol_id: int = None,
                   estado: bool = None) -> bool:
        """
        Actualiza usuario existente (sin cambiar contraseña)
        
        Args:
            usuario_id: ID del usuario a actualizar
            Solo se actualizan los campos que no sean None
            
        Returns:
            True si se actualizó correctamente
        """
        # Verificar que el usuario existe
        existing_user = self.get_by_id(usuario_id)
        if not existing_user:
            raise ValidationError("usuario_id", usuario_id, "Usuario no encontrado")
        
        # Construir datos a actualizar
        update_data = {}
        
        if nombre is not None:
            validate_required(nombre, "nombre")
            update_data['Nombre'] = nombre.strip()
        
        if apellido_paterno is not None:
            validate_required(apellido_paterno, "apellido_paterno")
            update_data['Apellido_Paterno'] = apellido_paterno.strip()
        
        if apellido_materno is not None:
            validate_required(apellido_materno, "apellido_materno")
            update_data['Apellido_Materno'] = apellido_materno.strip()
        
        if correo is not None:
            validate_email(correo)
            correo = correo.lower().strip()
            
            # Verificar que el nuevo email no exista (excepto el mismo usuario)
            if correo != existing_user['correo'] and self.email_exists(correo):
                raise ValidationError("correo", correo, "Email ya existe en el sistema")
            
            update_data['correo'] = correo
        
        if rol_id is not None:
            if not self._role_exists_and_active(rol_id):
                raise ValidationError("rol_id", rol_id, "Rol no existe o está inactivo")
            update_data['Id_Rol'] = rol_id
        
        if estado is not None:
            update_data['Estado'] = estado
        
        if not update_data:
            print("⚠️ No hay datos para actualizar")
            return True
        
        success = self.update(usuario_id, update_data)
        if success:
            print(f"👤 Usuario actualizado: ID {usuario_id}")
        
        return success
    
    def change_password(self, usuario_id: int, current_password: str, new_password: str) -> bool:
        """
        Cambia contraseña de usuario con validación de contraseña actual
        
        Args:
            usuario_id: ID del usuario
            current_password: Contraseña actual (texto plano)
            new_password: Nueva contraseña (texto plano)
            
        Returns:
            True si se cambió correctamente
        """
        # Obtener usuario actual
        user = self.get_by_id(usuario_id)
        if not user:
            raise ValidationError("usuario_id", usuario_id, "Usuario no encontrado")
        
        # Verificar contraseña actual
        if not self._verify_password(current_password, user['contrasena']):
            raise AuthenticationError("Contraseña actual incorrecta")
        
        # Validar nueva contraseña
        validate_required(new_password, "new_password")
        self._validate_password_strength(new_password)
        
        # No permitir la misma contraseña
        if self._verify_password(new_password, user['contrasena']):
            raise ValidationError("new_password", "***", "La nueva contraseña debe ser diferente a la actual")
        
        # Hashear nueva contraseña y actualizar
        hashed_new_password = self._hash_password(new_password)
        success = self.update(usuario_id, {'contrasena': hashed_new_password})
        
        if success:
            print(f"🔐 Contraseña cambiada: Usuario ID {usuario_id}")
        
        return success
    
    def reset_password(self, usuario_id: int, new_password: str) -> bool:
        """
        Resetea contraseña (solo para administradores)
        
        Args:
            usuario_id: ID del usuario
            new_password: Nueva contraseña
            
        Returns:
            True si se reseteó correctamente
        """
        user = self.get_by_id(usuario_id)
        if not user:
            raise ValidationError("usuario_id", usuario_id, "Usuario no encontrado")
        
        validate_required(new_password, "new_password")
        self._validate_password_strength(new_password)
        
        hashed_password = self._hash_password(new_password)
        success = self.update(usuario_id, {'contrasena': hashed_password})
        
        if success:
            print(f"🔐 Contraseña reseteada: Usuario ID {usuario_id}")
        
        return success
    
    # ===============================
    # OPERACIONES DE AUTENTICACIÓN
    # ===============================
    
    def authenticate(self, correo: str, contrasena: str) -> Optional[Dict[str, Any]]:
        """
        Autentica usuario por email y contraseña
        
        Args:
            correo: Email del usuario
            contrasena: Contraseña en texto plano
            
        Returns:
            Datos del usuario autenticado o None si falla
        """
        validate_required(correo, "correo")
        validate_required(contrasena, "contrasena")
        validate_email(correo)
        
        # Obtener usuario por email
        user = self.get_by_email(correo.lower().strip())
        if not user:
            raise AuthenticationError(correo)
        
        # Verificar que esté activo
        if not user.get('Estado', False):
            raise AuthenticationError("Usuario inactivo")
        
        # Verificar contraseña
        if not self._verify_password(contrasena, user['contrasena']):
            raise AuthenticationError(correo)
        
        # Obtener información completa con rol
        authenticated_user = self.get_by_id_with_role(user['id'])
        
        if authenticated_user:
            print(f"🔑 Usuario autenticado: {authenticated_user['correo']}")
        
        return authenticated_user
    
    def get_by_email(self, correo: str) -> Optional[Dict[str, Any]]:
        """Obtiene usuario por email"""
        query = "SELECT * FROM Usuario WHERE correo = ?"
        return self._execute_query(query, (correo.lower().strip(),), fetch_one=True)
    
    def email_exists(self, correo: str) -> bool:
        """Verifica si existe un email en el sistema"""
        return self.exists('correo', correo.lower().strip())
    
    # ===============================
    # CONSULTAS ESPECÍFICAS
    # ===============================
    
    @cached_query('usuarios_por_rol', ttl=600)
    def get_users_by_role(self, rol_id: int, solo_activos: bool = True) -> List[Dict[str, Any]]:
        """Obtiene usuarios por rol específico"""
        where_clause = "u.Id_Rol = ?"
        params = [rol_id]
        
        if solo_activos:
            where_clause += " AND u.Estado = 1 AND r.Estado = 1"
        
        query = f"""
        SELECT u.*, r.Nombre as rol_nombre
        FROM Usuario u
        INNER JOIN Roles r ON u.Id_Rol = r.id
        WHERE {where_clause}
        ORDER BY u.Nombre, u.Apellido_Paterno
        """
        
        return self._execute_query(query, tuple(params))
    
    def get_administrators(self) -> List[Dict[str, Any]]:
        """Obtiene todos los usuarios administradores activos"""
        query = """
        SELECT u.*, r.Nombre as rol_nombre
        FROM Usuario u
        INNER JOIN Roles r ON u.Id_Rol = r.id
        WHERE r.Nombre = 'Administrador' AND u.Estado = 1 AND r.Estado = 1
        ORDER BY u.Nombre, u.Apellido_Paterno
        """
        return self._execute_query(query)
    
    def get_doctors(self) -> List[Dict[str, Any]]:
        """Obtiene todos los usuarios médicos activos"""
        query = """
        SELECT u.*, r.Nombre as rol_nombre
        FROM Usuario u
        INNER JOIN Roles r ON u.Id_Rol = r.id
        WHERE r.Nombre = 'Médico' AND u.Estado = 1 AND r.Estado = 1
        ORDER BY u.Nombre, u.Apellido_Paterno
        """
        return self._execute_query(query)
    
    def search_users(self, search_term: str, limit: int = 20) -> List[Dict[str, Any]]:
        """
        Búsqueda avanzada de usuarios por nombre, apellidos o email
        
        Args:
            search_term: Término de búsqueda
            limit: Límite de resultados
        """
        if not search_term:
            return []
        
        search_term = f"%{search_term.strip()}%"
        
        query = """
        SELECT u.*, r.Nombre as rol_nombre, r.Descripcion as rol_descripcion
        FROM Usuario u
        INNER JOIN Roles r ON u.Id_Rol = r.id
        WHERE (u.Nombre LIKE ? OR u.Apellido_Paterno LIKE ? OR 
               u.Apellido_Materno LIKE ? OR u.correo LIKE ?)
        ORDER BY u.Estado DESC, u.Nombre, u.Apellido_Paterno
        OFFSET 0 ROWS FETCH NEXT ? ROWS ONLY
        """
        
        params = (search_term, search_term, search_term, search_term, limit)
        return self._execute_query(query, params)
    
    # ===============================
    # GESTIÓN DE ROLES
    # ===============================
    
    @cached_query('roles', ttl=1800)
    def get_all_roles(self) -> List[Dict[str, Any]]:
        """Obtiene todos los roles del sistema"""
        query = "SELECT * FROM Roles ORDER BY Nombre"
        return self._execute_query(query)
    
    def get_active_roles(self) -> List[Dict[str, Any]]:
        """Obtiene roles activos"""
        query = "SELECT * FROM Roles WHERE Estado = 1 ORDER BY Nombre"
        return self._execute_query(query)
    
    def get_role_by_id(self, rol_id: int) -> Optional[Dict[str, Any]]:
        """Obtiene rol por ID"""
        query = "SELECT * FROM Roles WHERE id = ?"
        return self._execute_query(query, (rol_id,), fetch_one=True)
    
    # ===============================
    # ESTADÍSTICAS Y REPORTES
    # ===============================
    
    @cached_query('stats_usuarios', ttl=300)
    def get_user_statistics(self) -> Dict[str, Any]:
        """Obtiene estadísticas de usuarios"""
        stats_query = """
        SELECT 
            COUNT(*) as total_usuarios,
            SUM(CASE WHEN Estado = 1 THEN 1 ELSE 0 END) as usuarios_activos,
            SUM(CASE WHEN Estado = 0 THEN 1 ELSE 0 END) as usuarios_inactivos
        FROM Usuario
        """
        
        roles_query = """
        SELECT r.Nombre as rol, COUNT(u.id) as cantidad
        FROM Roles r
        LEFT JOIN Usuario u ON r.id = u.Id_Rol AND u.Estado = 1
        WHERE r.Estado = 1
        GROUP BY r.id, r.Nombre
        ORDER BY cantidad DESC
        """
        
        general_stats = self._execute_query(stats_query, fetch_one=True)
        roles_stats = self._execute_query(roles_query)
        
        return {
            'general': general_stats,
            'por_roles': roles_stats
        }
    
    # ===============================
    # MÉTODOS PRIVADOS DE UTILIDAD
    # ===============================
    
    def _hash_password(self, password: str) -> str:
        """Genera hash seguro de contraseña con salt"""
        salt = secrets.token_hex(32)
        password_hash = hashlib.pbkdf2_hmac('sha256', password.encode(), salt.encode(), 100000)
        return f"{salt}${password_hash.hex()}"
    
    def _verify_password(self, password: str, hashed: str) -> bool:
        """Verifica contraseña contra hash almacenado"""
        try:
            salt, stored_hash = hashed.split('$')
            password_hash = hashlib.pbkdf2_hmac('sha256', password.encode(), salt.encode(), 100000)
            return password_hash.hex() == stored_hash
        except Exception:
            return False
    
    def _validate_password_strength(self, password: str):
        """Valida fortaleza de contraseña"""
        if len(password) < 6:
            raise ValidationError("password", "***", "Contraseña debe tener mínimo 6 caracteres")
        
        # Opcional: Agregar más validaciones
        # - Mayúsculas, minúsculas, números, símbolos
        # - No contraseñas comunes
        
    def _role_exists_and_active(self, rol_id: int) -> bool:
        """Verifica que el rol existe y está activo"""
        role = self.get_role_by_id(rol_id)
        return role is not None and role.get('Estado', False)
    
    # ===============================
    # GESTIÓN DE CACHÉ
    # ===============================
    
    def invalidate_user_caches(self):
        """Invalida todos los cachés relacionados con usuarios"""
        cache_types = ['usuarios', 'usuarios_por_rol', 'roles', 'stats_usuarios']
        invalidate_after_update(cache_types)
        print("🗑️ Cachés de usuarios invalidados")
    
    # Override del método de BaseRepository para invalidación específica
    def _invalidate_cache_after_modification(self):
        """Invalida cachés específicos después de modificaciones"""
        super()._invalidate_cache_after_modification()
        self.invalidate_user_caches()