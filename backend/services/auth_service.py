import hashlib
import secrets
import logging
from datetime import datetime, timedelta
from typing import Optional, Dict, Any, List
from dataclasses import dataclass

from ..repositories.usuario_repository import UsuarioRepository
from ..core.excepciones import AuthenticationError, ValidationError, ExceptionHandler

logger = logging.getLogger(__name__)

@dataclass
class UsuarioSesion:
    """Clase para manejar información de sesión de usuario"""
    usuario_id: int
    nombre_completo: str
    correo: str
    rol_id: int
    rol_nombre: str
    token: str
    fecha_login: datetime
    ultimo_acceso: datetime

class AuthService:
    """Servicio de autenticación y gestión de sesiones"""
    
    def __init__(self):
        self.repository = UsuarioRepository()
        self.sesiones_activas: Dict[str, UsuarioSesion] = {}
        self.intentos_login: Dict[str, Dict] = {}
        
        # Configuración
        self.MAX_LOGIN_ATTEMPTS = 5
        self.LOGIN_BLOCK_TIME = 15  # minutos
        self.SESSION_TIMEOUT = 8 * 60 * 60  # 8 horas en segundos
    
    @ExceptionHandler.handle_exception
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
                    'error': f'Demasiados intentos de login. Intente en {self.LOGIN_BLOCK_TIME} minutos.',
                    'code': 'MAX_ATTEMPTS'
                }
            
            # Autenticar usando repository
            usuario_data = self.repository.authenticate(email, password)
            
            if not usuario_data:
                self._registrar_intento_fallido(email)
                return {
                    'success': False,
                    'error': 'Credenciales incorrectas',
                    'code': 'INVALID_CREDENTIALS'
                }
            
            # Verificar que el rol esté activo
            if not usuario_data.get('rol_estado', True):
                return {
                    'success': False,
                    'error': 'Su rol está inactivo. Contacte al administrador.',
                    'code': 'ROLE_INACTIVE'
                }
            
            # Generar token de sesión
            token = self._generar_token()
            
            # Crear sesión de usuario
            sesion = UsuarioSesion(
                usuario_id=usuario_data['id'],
                nombre_completo=f"{usuario_data['Nombre']} {usuario_data['Apellido_Paterno']} {usuario_data['Apellido_Materno']}",
                correo=usuario_data['correo'],
                rol_id=usuario_data['rol_id'],
                rol_nombre=usuario_data['rol_nombre'],
                token=token,
                fecha_login=datetime.now(),
                ultimo_acceso=datetime.now()
            )
            
            # Guardar sesión activa
            self.sesiones_activas[token] = sesion
            
            # Limpiar intentos fallidos
            self._limpiar_intentos_login(email)
            
            logger.info(f"Login exitoso para usuario: {email}")
            
            return {
                'success': True,
                'token': token,
                'usuario': {
                    'id': sesion.usuario_id,
                    'nombre_completo': sesion.nombre_completo,
                    'correo': sesion.correo,
                    'rol_id': sesion.rol_id,
                    'rol_nombre': sesion.rol_nombre,
                    'rol_descripcion': usuario_data.get('rol_descripcion', '')
                },
                'fecha_login': sesion.fecha_login.isoformat(),
                'session_timeout': self.SESSION_TIMEOUT
            }
            
        except AuthenticationError as e:
            self._registrar_intento_fallido(email)
            return {
                'success': False,
                'error': str(e),
                'code': 'AUTH_ERROR'
            }
        except Exception as e:
            logger.error(f"Error en login para {email}: {e}")
            return {
                'success': False,
                'error': 'Error interno del servidor',
                'code': 'INTERNAL_ERROR'
            }
    
    @ExceptionHandler.handle_exception
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
            tiempo_transcurrido = datetime.now() - sesion.ultimo_acceso
            if tiempo_transcurrido.total_seconds() > self.SESSION_TIMEOUT:
                del self.sesiones_activas[token]
                return {
                    'valid': False,
                    'error': 'Sesión expirada',
                    'code': 'SESSION_EXPIRED'
                }
            
            # Actualizar último acceso
            sesion.ultimo_acceso = datetime.now()
            
            # Verificar que el usuario siga activo en BD
            usuario = self.repository.get_by_id(sesion.usuario_id)
            if not usuario or not usuario.get('Estado', False):
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
                },
                'tiempo_restante': self.SESSION_TIMEOUT - tiempo_transcurrido.total_seconds()
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
                tiempo_activo = datetime.now() - sesion.fecha_login
                sesiones.append({
                    'token': token[:8] + "...",  # Solo mostrar parte del token
                    'usuario': sesion.nombre_completo,
                    'correo': sesion.correo,
                    'rol': sesion.rol_nombre,
                    'fecha_login': sesion.fecha_login.isoformat(),
                    'ultimo_acceso': sesion.ultimo_acceso.isoformat(),
                    'tiempo_activo': str(tiempo_activo)
                })
            
            return sorted(sesiones, key=lambda x: x['ultimo_acceso'], reverse=True)
            
        except Exception as e:
            logger.error(f"Error listando sesiones activas: {e}")
            return []
    
    def cerrar_sesion_usuario(self, usuario_id: int) -> int:
        """Cierra todas las sesiones de un usuario específico"""
        tokens_a_eliminar = []
        for token, sesion in self.sesiones_activas.items():
            if sesion.usuario_id == usuario_id:
                tokens_a_eliminar.append(token)
        
        for token in tokens_a_eliminar:
            del self.sesiones_activas[token]
        
        if tokens_a_eliminar:
            logger.info(f"Sesiones cerradas para usuario ID {usuario_id}: {len(tokens_a_eliminar)}")
        
        return len(tokens_a_eliminar)
    
    def limpiar_sesiones_expiradas(self) -> int:
        """Limpia sesiones expiradas"""
        ahora = datetime.now()
        tokens_expirados = []
        
        for token, sesion in self.sesiones_activas.items():
            tiempo_transcurrido = ahora - sesion.ultimo_acceso
            if tiempo_transcurrido.total_seconds() > self.SESSION_TIMEOUT:
                tokens_expirados.append(token)
        
        for token in tokens_expirados:
            del self.sesiones_activas[token]
        
        if tokens_expirados:
            logger.info(f"Sesiones expiradas limpiadas: {len(tokens_expirados)}")
        
        return len(tokens_expirados)
    
    def get_stats(self) -> Dict[str, Any]:
        """Obtiene estadísticas de sesiones"""
        return {
            'sesiones_activas': len(self.sesiones_activas),
            'usuarios_unicos': len(set(s.usuario_id for s in self.sesiones_activas.values())),
            'intentos_login_fallidos': len(self.intentos_login)
        }
    
    # ===============================
    # MÉTODOS PRIVADOS
    # ===============================
    
    def _verificar_password(self, password_plain: str, password_hash: str) -> bool:
        """
        Verifica una contraseña contra su hash
        Nota: Usar el mismo método que en UsuarioRepository
        """
        try:
            # Si usa el sistema de hash con salt del repository
            if '$' in password_hash:
                salt, stored_hash = password_hash.split('$')
                password_hash_check = hashlib.pbkdf2_hmac('sha256', password_plain.encode(), salt.encode(), 100000)
                return password_hash_check.hex() == stored_hash
            
            # Si las contraseñas están en texto plano (no recomendado)
            if password_plain == password_hash:
                return True
            
            # Si usas hash MD5 o SHA256 simple
            hash_md5 = hashlib.md5(password_plain.encode()).hexdigest()
            hash_sha256 = hashlib.sha256(password_plain.encode()).hexdigest()
            
            return password_hash in [hash_md5, hash_sha256, password_plain]
            
        except Exception:
            return False
    
    def _generar_token(self) -> str:
        """Genera un token único para la sesión"""
        return secrets.token_urlsafe(32)
    
    def _verificar_intentos_login(self, email: str) -> bool:
        """Verifica si se han excedido los intentos de login"""
        if email not in self.intentos_login:
            return False
        
        datos = self.intentos_login[email]
        ahora = datetime.now()
        
        # Si han pasado más del tiempo de bloqueo, limpiar intentos
        if (ahora - datos['ultimo_intento']).total_seconds() > (self.LOGIN_BLOCK_TIME * 60):
            del self.intentos_login[email]
            return False
        
        return datos['intentos'] >= self.MAX_LOGIN_ATTEMPTS
    
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