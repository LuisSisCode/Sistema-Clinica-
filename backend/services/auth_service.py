# backend/services/auth_service.py
import hashlib
import secrets
import logging
from datetime import datetime, timedelta
from typing import Optional, Dict, Any
from ..database.repositories.seguridad_repository import seguridad_repository
from ..database.models import UsuarioSesion
from ..core.config import Config
from ..cache.cache_decorators import cache_usuario, invalidate_usuario_cache

logger = logging.getLogger(__name__)

class AuthService:
    """Servicio de autenticación y gestión de sesiones"""
    
    def __init__(self):
        self.sesiones_activas: Dict[str, UsuarioSesion] = {}
        self.intentos_login: Dict[str, Dict] = {}
    
    def login(self, email: str, password: str) -> Dict[str, Any]:
        """
        Autentica un usuario y crea una sesión
        
        Returns:
            Dict con resultado del login (success, token, usuario, error)
        """
        try:
            # Verificar intentos de login
            if self._verificar_intentos_login(email):
                return {
                    'success': False,
                    'error': 'Demasiados intentos de login. Intente más tarde.',
                    'code': 'MAX_ATTEMPTS'
                }
            
            # Obtener usuario por email
            usuario = seguridad_repository.get_usuario_by_email(email)
            
            if not usuario:
                self._registrar_intento_fallido(email)
                return {
                    'success': False,
                    'error': 'Credenciales incorrectas',
                    'code': 'INVALID_CREDENTIALS'
                }
            
            # Verificar contraseña
            if not self._verificar_password(password, usuario.contrasena):
                self._registrar_intento_fallido(email)
                return {
                    'success': False,
                    'error': 'Credenciales incorrectas',
                    'code': 'INVALID_CREDENTIALS'
                }
            
            # Verificar que el usuario esté activo
            if not usuario.estado:
                return {
                    'success': False,
                    'error': 'Usuario inactivo. Contacte al administrador.',
                    'code': 'USER_INACTIVE'
                }
            
            # Obtener información del rol
            rol = seguridad_repository.get_rol_by_id(usuario.id_rol)
            if not rol:
                return {
                    'success': False,
                    'error': 'Rol de usuario no válido',
                    'code': 'INVALID_ROLE'
                }
            
            # Generar token de sesión
            token = self._generar_token()
            
            # Crear sesión de usuario
            sesion = UsuarioSesion(
                usuario_id=usuario.id,
                nombre_completo=usuario.nombre_completo,
                correo=usuario.correo,
                rol_id=usuario.id_rol,
                rol_nombre=rol.nombre,
                fecha_login=datetime.now(),
                token=token
            )
            
            # Guardar sesión activa
            self.sesiones_activas[token] = sesion
            
            # Actualizar último acceso
            seguridad_repository.actualizar_ultimo_acceso(usuario.id)
            
            # Limpiar intentos fallidos
            self._limpiar_intentos_login(email)
            
            logger.info(f"Login exitoso para usuario: {email}")
            
            return {
                'success': True,
                'token': token,
                'usuario': {
                    'id': usuario.id,
                    'nombre_completo': usuario.nombre_completo,
                    'correo': usuario.correo,
                    'rol_id': usuario.id_rol,
                    'rol_nombre': rol.nombre,
                    'rol_descripcion': rol.descripcion
                },
                'fecha_login': sesion.fecha_login.isoformat()
            }
            
        except Exception as e:
            logger.error(f"Error en login para {email}: {e}")
            return {
                'success': False,
                'error': 'Error interno del servidor',
                'code': 'INTERNAL_ERROR'
            }
    
    def logout(self, token: str) -> Dict[str, Any]:
        """Cierra una sesión de usuario"""
        try:
            if token in self.sesiones_activas:
                sesion = self.sesiones_activas[token]
                del self.sesiones_activas[token]
                
                logger.info(f"Logout exitoso para usuario: {sesion.correo}")
                
                return {
                    'success': True,
                    'message': 'Sesión cerrada correctamente'
                }
            
            return {
                'success': False,
                'error': 'Token de sesión no válido',
                'code': 'INVALID_TOKEN'
            }
            
        except Exception as e:
            logger.error(f"Error en logout: {e}")
            return {
                'success': False,
                'error': 'Error cerrando sesión',
                'code': 'INTERNAL_ERROR'
            }
    
    def verificar_sesion(self, token: str) -> Dict[str, Any]:
        """Verifica si una sesión es válida"""
        try:
            if not token or token not in self.sesiones_activas:
                return {
                    'valid': False,
                    'error': 'Token de sesión no válido',
                    'code': 'INVALID_TOKEN'
                }
            
            sesion = self.sesiones_activas[token]
            
            # Verificar tiempo de expiración
            tiempo_transcurrido = datetime.now() - sesion.fecha_login
            if tiempo_transcurrido.total_seconds() > Config.SESSION_TIMEOUT:
                del self.sesiones_activas[token]
                return {
                    'valid': False,
                    'error': 'Sesión expirada',
                    'code': 'SESSION_EXPIRED'
                }
            
            # Verificar que el usuario siga activo en BD
            if not seguridad_repository.verificar_usuario_activo(sesion.usuario_id):
                del self.sesiones_activas[token]
                return {
                    'valid': False,
                    'error': 'Usuario inactivo',
                    'code': 'USER_INACTIVE'
                }
            
            return {
                'valid': True,
                'usuario': {
                    'id': sesion.usuario_id,
                    'nombre_completo': sesion.nombre_completo,
                    'correo': sesion.correo,
                    'rol_id': sesion.rol_id,
                    'rol_nombre': sesion.rol_nombre
                }
            }
            
        except Exception as e:
            logger.error(f"Error verificando sesión: {e}")
            return {
                'valid': False,
                'error': 'Error verificando sesión',
                'code': 'INTERNAL_ERROR'
            }
    
    def obtener_usuario_sesion(self, token: str) -> Optional[UsuarioSesion]:
        """Obtiene información completa del usuario de la sesión"""
        if token in self.sesiones_activas:
            return self.sesiones_activas[token]
        return None
    
    def listar_sesiones_activas(self) -> List[Dict]:
        """Lista todas las sesiones activas (solo admin)"""
        try:
            sesiones = []
            for token, sesion in self.sesiones_activas.items():
                sesiones.append({
                    'token': token[:8] + "...",  # Solo mostrar parte del token
                    'usuario': sesion.nombre_completo,
                    'correo': sesion.correo,
                    'rol': sesion.rol_nombre,
                    'fecha_login': sesion.fecha_login.isoformat(),
                    'tiempo_activo': str(datetime.now() - sesion.fecha_login)
                })
            
            return sesiones
            
        except Exception as e:
            logger.error(f"Error listando sesiones activas: {e}")
            return []
    
    def _verificar_password(self, password_plain: str, password_hash: str) -> bool:
        """
        Verifica una contraseña contra su hash
        Nota: Ajustar según el método de hash usado en tu BD
        """
        # Si las contraseñas están en texto plano en la BD (no recomendado)
        if password_plain == password_hash:
            return True
        
        # Si usas hash MD5 o SHA256
        hash_md5 = hashlib.md5(password_plain.encode()).hexdigest()
        hash_sha256 = hashlib.sha256(password_plain.encode()).hexdigest()
        
        return password_hash in [hash_md5, hash_sha256, password_plain]
    
    def _generar_token(self) -> str:
        """Genera un token único para la sesión"""
        return secrets.token_urlsafe(32)
    
    def _verificar_intentos_login(self, email: str) -> bool:
        """Verifica si se han excedido los intentos de login"""
        if email not in self.intentos_login:
            return False
        
        datos = self.intentos_login[email]
        ahora = datetime.now()
        
        # Si han pasado más de 15 minutos, limpiar intentos
        if (ahora - datos['ultimo_intento']).total_seconds() > 900:  # 15 minutos
            del self.intentos_login[email]
            return False
        
        return datos['intentos'] >= Config.MAX_LOGIN_ATTEMPTS
    
    def _registrar_intento_fallido(self, email: str):
        """Registra un intento de login fallido"""
        ahora = datetime.now()
        
        if email not in self.intentos_login:
            self.intentos_login[email] = {
                'intentos': 1,
                'primer_intento': ahora,
                'ultimo_intento': ahora
            }
        else:
            self.intentos_login[email]['intentos'] += 1
            self.intentos_login[email]['ultimo_intento'] = ahora
        
        logger.warning(f"Intento de login fallido para {email}. Total: {self.intentos_login[email]['intentos']}")
    
    def _limpiar_intentos_login(self, email: str):
        """Limpia los intentos de login después de un login exitoso"""
        if email in self.intentos_login:
            del self.intentos_login[email]

# Instancia global del servicio de autenticación
auth_service = AuthService()