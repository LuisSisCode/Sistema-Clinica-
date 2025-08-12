from typing import List, Dict, Any, Optional, Tuple
from datetime import datetime, timedelta
import secrets
import re
from dataclasses import dataclass

from ..repositories.usuario_repository import UsuarioRepository
from ..core.excepciones import (
    ValidationError, AuthenticationError, PermissionError,
    ExceptionHandler, validate_required, validate_email
)
from ..core.cache_system import cached_query, invalidate_after_update

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
    permisos: Dict[str, bool] = None

class UsuarioService:
    """
    Servicio de lógica de negocio para gestión completa de usuarios
    Capa intermedia entre Repository y QML Model
    """
    
    def __init__(self):
        self.repository = UsuarioRepository()
        self.sesiones_activas: Dict[str, UsuarioSesion] = {}
        self.intentos_login: Dict[str, Dict] = {}
        
        # Configuración de negocio
        self.MAX_LOGIN_ATTEMPTS = 5
        self.LOGIN_BLOCK_TIME = 15  # minutos
        self.SESSION_TIMEOUT = 8 * 60 * 60  # 8 horas en segundos
        
        print("🧠 UsuarioService inicializado")
    
    # ===============================
    # AUTENTICACIÓN Y SESIONES
    # ===============================
    
    @ExceptionHandler.handle_exception
    def login(self, correo: str, contrasena: str) -> Dict[str, Any]:
        """
        Autentica usuario y crea sesión activa
        
        Args:
            correo: Email del usuario
            contrasena: Contraseña en texto plano
            
        Returns:
            Dict con resultado del login y datos de sesión
        """
        try:
            # Verificar intentos de login
            if self._verificar_intentos_login(correo):
                return {
                    'success': False,
                    'error': f'Demasiados intentos de login. Intente en {self.LOGIN_BLOCK_TIME} minutos.',
                    'code': 'MAX_ATTEMPTS'
                }
            
            # Autenticar usando repository
            usuario_data = self.repository.authenticate(correo, contrasena)
            
            if not usuario_data:
                self._registrar_intento_fallido(correo)
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
                ultimo_acceso=datetime.now(),
                permisos=self._obtener_permisos_rol(usuario_data['rol_nombre'])
            )
            
            # Guardar sesión activa
            self.sesiones_activas[token] = sesion
            
            # Limpiar intentos fallidos
            self._limpiar_intentos_login(correo)
            
            print(f"🔑 Login exitoso: {correo} - Token: {token[:8]}...")
            
            return {
                'success': True,
                'token': token,
                'usuario': {
                    'id': sesion.usuario_id,
                    'nombre_completo': sesion.nombre_completo,
                    'correo': sesion.correo,
                    'rol_id': sesion.rol_id,
                    'rol_nombre': sesion.rol_nombre,
                    'permisos': sesion.permisos
                },
                'fecha_login': sesion.fecha_login.isoformat(),
                'session_timeout': self.SESSION_TIMEOUT
            }
            
        except AuthenticationError as e:
            self._registrar_intento_fallido(correo)
            return {
                'success': False,
                'error': str(e),
                'code': 'AUTH_ERROR'
            }
    
    @ExceptionHandler.handle_exception
    def logout(self, token: str) -> Dict[str, Any]:
        """Cierra sesión de usuario"""
        if token in self.sesiones_activas:
            sesion = self.sesiones_activas[token]
            del self.sesiones_activas[token]
            
            print(f"🚪 Logout: {sesion.correo}")
            
            return {
                'success': True,
                'message': 'Sesión cerrada correctamente'
            }
        
        return {
            'success': False,
            'error': 'Token de sesión no válido',
            'code': 'INVALID_TOKEN'
        }
    
    def verificar_sesion(self, token: str) -> Dict[str, Any]:
        """Verifica si una sesión es válida y actualiza último acceso"""
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
        
        return {
            'valid': True,
            'usuario': {
                'id': sesion.usuario_id,
                'nombre_completo': sesion.nombre_completo,
                'correo': sesion.correo,
                'rol_id': sesion.rol_id,
                'rol_nombre': sesion.rol_nombre,
                'permisos': sesion.permisos
            },
            'tiempo_restante': self.SESSION_TIMEOUT - tiempo_transcurrido.total_seconds()
        }
    
    def obtener_sesiones_activas(self) -> List[Dict[str, Any]]:
        """Lista todas las sesiones activas (solo para admin)"""
        sesiones = []
        for token, sesion in self.sesiones_activas.items():
            tiempo_activo = datetime.now() - sesion.fecha_login
            sesiones.append({
                'token_partial': token[:8] + "...",
                'usuario': sesion.nombre_completo,
                'correo': sesion.correo,
                'rol': sesion.rol_nombre,
                'fecha_login': sesion.fecha_login.isoformat(),
                'ultimo_acceso': sesion.ultimo_acceso.isoformat(),
                'tiempo_activo_minutos': int(tiempo_activo.total_seconds() / 60)
            })
        
        return sorted(sesiones, key=lambda x: x['ultimo_acceso'], reverse=True)
    
    # ===============================
    # GESTIÓN DE USUARIOS
    # ===============================
    
    @ExceptionHandler.handle_exception
    def crear_usuario(self, datos_usuario: Dict[str, Any]) -> Dict[str, Any]:
        """
        Crea nuevo usuario con validaciones de negocio
        
        Args:
            datos_usuario: Dict con datos del usuario a crear
            
        Returns:
            Dict con resultado de la operación
        """
        try:
            # Validaciones de negocio
            self._validar_datos_usuario(datos_usuario, es_creacion=True)
            
            # Validaciones específicas para creación
            if self.repository.email_exists(datos_usuario['correo']):
                return {
                    'success': False,
                    'error': 'El correo electrónico ya está registrado',
                    'code': 'EMAIL_EXISTS'
                }
            
            # Crear usuario usando repository
            usuario_id = self.repository.create_user(
                nombre=datos_usuario['nombre'],
                apellido_paterno=datos_usuario['apellido_paterno'],
                apellido_materno=datos_usuario['apellido_materno'],
                correo=datos_usuario['correo'],
                contrasena=datos_usuario['contrasena'],
                rol_id=datos_usuario['rol_id'],
                estado=datos_usuario.get('estado', True)
            )
            
            # Obtener datos completos del usuario creado
            usuario_completo = self.repository.get_by_id_with_role(usuario_id)
            
            print(f"👤 Usuario creado: {usuario_completo['correo']} - ID: {usuario_id}")
            
            return {
                'success': True,
                'usuario_id': usuario_id,
                'usuario': self._formatear_usuario_para_qml(usuario_completo),
                'message': 'Usuario creado exitosamente'
            }
            
        except ValidationError as e:
            return {
                'success': False,
                'error': str(e),
                'code': 'VALIDATION_ERROR',
                'field': e.details.get('field')
            }
    
    @ExceptionHandler.handle_exception
    def actualizar_usuario(self, usuario_id: int, datos_usuario: Dict[str, Any]) -> Dict[str, Any]:
        """Actualiza usuario existente"""
        try:
            # Validar que el usuario existe
            usuario_actual = self.repository.get_by_id(usuario_id)
            if not usuario_actual:
                return {
                    'success': False,
                    'error': 'Usuario no encontrado',
                    'code': 'USER_NOT_FOUND'
                }
            
            # Validaciones de negocio
            self._validar_datos_usuario(datos_usuario, es_creacion=False)
            
            # Verificar email único si se está cambiando
            if 'correo' in datos_usuario and datos_usuario['correo'] != usuario_actual['correo']:
                if self.repository.email_exists(datos_usuario['correo']):
                    return {
                        'success': False,
                        'error': 'El correo electrónico ya está registrado',
                        'code': 'EMAIL_EXISTS'
                    }
            
            # Actualizar usando repository
            success = self.repository.update_user(
                usuario_id=usuario_id,
                nombre=datos_usuario.get('nombre'),
                apellido_paterno=datos_usuario.get('apellido_paterno'),
                apellido_materno=datos_usuario.get('apellido_materno'),
                correo=datos_usuario.get('correo'),
                rol_id=datos_usuario.get('rol_id'),
                estado=datos_usuario.get('estado')
            )
            
            if success:
                # Obtener datos actualizados
                usuario_actualizado = self.repository.get_by_id_with_role(usuario_id)
                
                # Si el usuario tiene sesión activa, actualizar datos
                self._actualizar_sesiones_usuario(usuario_id, usuario_actualizado)
                
                return {
                    'success': True,
                    'usuario': self._formatear_usuario_para_qml(usuario_actualizado),
                    'message': 'Usuario actualizado exitosamente'
                }
            
            return {
                'success': False,
                'error': 'Error actualizando usuario',
                'code': 'UPDATE_ERROR'
            }
            
        except ValidationError as e:
            return {
                'success': False,
                'error': str(e),
                'code': 'VALIDATION_ERROR',
                'field': e.details.get('field')
            }
    
    @ExceptionHandler.handle_exception
    def eliminar_usuario(self, usuario_id: int) -> Dict[str, Any]:
        """Elimina usuario (soft delete cambiando estado)"""
        try:
            # No permitir auto-eliminación
            # TODO: Agregar verificación cuando tengamos el contexto de usuario actual
            
            # Verificar que el usuario existe
            usuario = self.repository.get_by_id(usuario_id)
            if not usuario:
                return {
                    'success': False,
                    'error': 'Usuario no encontrado',
                    'code': 'USER_NOT_FOUND'
                }
            
            # Soft delete - cambiar estado a inactivo
            success = self.repository.update_user(usuario_id, estado=False)
            
            if success:
                # Cerrar sesiones activas del usuario
                self._cerrar_sesiones_usuario(usuario_id)
                
                return {
                    'success': True,
                    'message': 'Usuario eliminado exitosamente'
                }
            
            return {
                'success': False,
                'error': 'Error eliminando usuario',
                'code': 'DELETE_ERROR'
            }
            
        except Exception as e:
            return {
                'success': False,
                'error': f'Error eliminando usuario: {str(e)}',
                'code': 'DELETE_ERROR'
            }
    
    @ExceptionHandler.handle_exception
    def cambiar_contrasena(self, usuario_id: int, contrasena_actual: str, 
                          nueva_contrasena: str) -> Dict[str, Any]:
        """Cambio de contraseña por el usuario"""
        try:
            success = self.repository.change_password(
                usuario_id=usuario_id,
                current_password=contrasena_actual,
                new_password=nueva_contrasena
            )
            
            if success:
                return {
                    'success': True,
                    'message': 'Contraseña cambiada exitosamente'
                }
            
            return {
                'success': False,
                'error': 'Error cambiando contraseña',
                'code': 'PASSWORD_CHANGE_ERROR'
            }
            
        except AuthenticationError:
            return {
                'success': False,
                'error': 'Contraseña actual incorrecta',
                'code': 'INVALID_CURRENT_PASSWORD'
            }
        except ValidationError as e:
            return {
                'success': False,
                'error': str(e),
                'code': 'VALIDATION_ERROR'
            }
    
    @ExceptionHandler.handle_exception
    def resetear_contrasena(self, usuario_id: int, nueva_contrasena: str) -> Dict[str, Any]:
        """Reset de contraseña por administrador"""
        try:
            success = self.repository.reset_password(usuario_id, nueva_contrasena)
            
            if success:
                # Cerrar sesiones activas del usuario
                self._cerrar_sesiones_usuario(usuario_id)
                
                return {
                    'success': True,
                    'message': 'Contraseña reseteada exitosamente'
                }
            
            return {
                'success': False,
                'error': 'Error reseteando contraseña',
                'code': 'PASSWORD_RESET_ERROR'
            }
            
        except ValidationError as e:
            return {
                'success': False,
                'error': str(e),
                'code': 'VALIDATION_ERROR'
            }
    
    # ===============================
    # CONSULTAS Y FILTROS
    # ===============================
    
    @cached_query('usuarios_completos', ttl=180)
    def obtener_todos_usuarios(self, incluir_inactivos: bool = True) -> List[Dict[str, Any]]:
        """Obtiene todos los usuarios con información completa"""
        usuarios = self.repository.get_all_with_roles()
        
        if not incluir_inactivos:
            usuarios = [u for u in usuarios if u.get('Estado', False)]
        
        return [self._formatear_usuario_para_qml(usuario) for usuario in usuarios]
    
    def obtener_usuario_por_id(self, usuario_id: int) -> Optional[Dict[str, Any]]:
        """Obtiene usuario por ID con formato para QML"""
        usuario = self.repository.get_by_id_with_role(usuario_id)
        return self._formatear_usuario_para_qml(usuario) if usuario else None
    
    def buscar_usuarios(self, termino_busqueda: str, filtros: Dict[str, Any] = None) -> List[Dict[str, Any]]:
        """
        Búsqueda avanzada de usuarios con filtros
        
        Args:
            termino_busqueda: Término a buscar en nombre, apellidos, correo
            filtros: Dict con filtros adicionales (rol_id, estado, etc.)
        """
        if not termino_busqueda and not filtros:
            return self.obtener_todos_usuarios()
        
        # Búsqueda por término
        usuarios = []
        if termino_busqueda:
            usuarios = self.repository.search_users(termino_busqueda)
        else:
            usuarios = self.repository.get_all_with_roles()
        
        # Aplicar filtros adicionales
        if filtros:
            usuarios_filtrados = []
            for usuario in usuarios:
                incluir = True
                
                # Filtro por rol
                if 'rol_id' in filtros and filtros['rol_id'] is not None:
                    if usuario.get('rol_id') != filtros['rol_id']:
                        incluir = False
                
                # Filtro por estado
                if 'estado' in filtros and filtros['estado'] is not None:
                    if usuario.get('Estado') != filtros['estado']:
                        incluir = False
                
                # Filtro por fecha de registro
                if 'fecha_desde' in filtros and filtros['fecha_desde']:
                    # TODO: Implementar filtro por fecha si es necesario
                    pass
                
                if incluir:
                    usuarios_filtrados.append(usuario)
            
            usuarios = usuarios_filtrados
        
        return [self._formatear_usuario_para_qml(usuario) for usuario in usuarios]
    
    def obtener_usuarios_por_rol(self, rol_id: int, solo_activos: bool = True) -> List[Dict[str, Any]]:
        """Obtiene usuarios por rol específico"""
        usuarios = self.repository.get_users_by_role(rol_id, solo_activos)
        return [self._formatear_usuario_para_qml(usuario) for usuario in usuarios]
    
    def obtener_administradores(self) -> List[Dict[str, Any]]:
        """Obtiene todos los administradores activos"""
        usuarios = self.repository.get_administrators()
        return [self._formatear_usuario_para_qml(usuario) for usuario in usuarios]
    
    def obtener_medicos(self) -> List[Dict[str, Any]]:
        """Obtiene todos los médicos activos"""
        usuarios = self.repository.get_doctors()
        return [self._formatear_usuario_para_qml(usuario) for usuario in usuarios]
    
    # ===============================
    # GESTIÓN DE ROLES
    # ===============================
    
    @cached_query('roles_activos', ttl=1800)
    def obtener_roles(self, solo_activos: bool = True) -> List[Dict[str, Any]]:
        """Obtiene lista de roles disponibles"""
        if solo_activos:
            return self.repository.get_active_roles()
        return self.repository.get_all_roles()
    
    def obtener_rol_por_id(self, rol_id: int) -> Optional[Dict[str, Any]]:
        """Obtiene información de rol por ID"""
        return self.repository.get_role_by_id(rol_id)
    
    # ===============================
    # ESTADÍSTICAS Y REPORTES
    # ===============================
    
    @cached_query('estadisticas_usuarios', ttl=300)
    def obtener_estadisticas(self) -> Dict[str, Any]:
        """Obtiene estadísticas completas de usuarios"""
        stats = self.repository.get_user_statistics()
        
        # Agregar estadísticas de sesiones activas
        sesiones_stats = {
            'sesiones_activas': len(self.sesiones_activas),
            'usuarios_online': len(set(s.usuario_id for s in self.sesiones_activas.values()))
        }
        
        return {
            'general': stats['general'],
            'por_roles': stats['por_roles'],
            'sesiones': sesiones_stats,
            'fecha_actualizacion': datetime.now().isoformat()
        }
    
    def obtener_actividad_reciente(self, dias: int = 7) -> List[Dict[str, Any]]:
        """Obtiene actividad reciente de usuarios"""
        # Por ahora retornamos las sesiones activas
        # TODO: Implementar log de actividad si es necesario
        return self.obtener_sesiones_activas()
    
    # ===============================
    # OPERACIONES EN LOTE
    # ===============================
    
    @ExceptionHandler.handle_exception
    def importar_usuarios_lote(self, usuarios_data: List[Dict[str, Any]]) -> Dict[str, Any]:
        """Importa múltiples usuarios en una operación"""
        resultados = {
            'exitosos': 0,
            'errores': 0,
            'detalles': []
        }
        
        for i, datos_usuario in enumerate(usuarios_data):
            try:
                resultado = self.crear_usuario(datos_usuario)
                if resultado['success']:
                    resultados['exitosos'] += 1
                    resultados['detalles'].append({
                        'fila': i + 1,
                        'estado': 'exitoso',
                        'correo': datos_usuario.get('correo'),
                        'usuario_id': resultado['usuario_id']
                    })
                else:
                    resultados['errores'] += 1
                    resultados['detalles'].append({
                        'fila': i + 1,
                        'estado': 'error',
                        'correo': datos_usuario.get('correo'),
                        'error': resultado['error']
                    })
            except Exception as e:
                resultados['errores'] += 1
                resultados['detalles'].append({
                    'fila': i + 1,
                    'estado': 'error',
                    'correo': datos_usuario.get('correo'),
                    'error': str(e)
                })
        
        return {
            'success': resultados['errores'] == 0,
            'total_procesados': len(usuarios_data),
            'exitosos': resultados['exitosos'],
            'errores': resultados['errores'],
            'detalles': resultados['detalles']
        }
    
    def activar_usuarios_lote(self, usuarios_ids: List[int]) -> Dict[str, Any]:
        """Activa múltiples usuarios"""
        return self._operacion_lote_estado(usuarios_ids, True, "activar")
    
    def desactivar_usuarios_lote(self, usuarios_ids: List[int]) -> Dict[str, Any]:
        """Desactiva múltiples usuarios"""
        return self._operacion_lote_estado(usuarios_ids, False, "desactivar")
    
    # ===============================
    # MÉTODOS PRIVADOS
    # ===============================
    
    def _validar_datos_usuario(self, datos: Dict[str, Any], es_creacion: bool = True):
        """Validaciones de negocio para datos de usuario"""
        
        # Validaciones básicas
        if 'nombre' in datos:
            validate_required(datos['nombre'], "nombre")
            if len(datos['nombre'].strip()) < 2:
                raise ValidationError("nombre", datos['nombre'], "Nombre debe tener al menos 2 caracteres")
        
        if 'apellido_paterno' in datos:
            validate_required(datos['apellido_paterno'], "apellido_paterno")
            if len(datos['apellido_paterno'].strip()) < 2:
                raise ValidationError("apellido_paterno", datos['apellido_paterno'], "Apellido paterno debe tener al menos 2 caracteres")
        
        if 'apellido_materno' in datos:
            validate_required(datos['apellido_materno'], "apellido_materno")
            if len(datos['apellido_materno'].strip()) < 2:
                raise ValidationError("apellido_materno", datos['apellido_materno'], "Apellido materno debe tener al menos 2 caracteres")
        
        if 'correo' in datos:
            validate_email(datos['correo'])
            if not self._validar_correo_dominio(datos['correo']):
                raise ValidationError("correo", datos['correo'], "Correo debe ser del dominio de la clínica")
        
        if 'contrasena' in datos and es_creacion:
            validate_required(datos['contrasena'], "contrasena")
            if not self._validar_contrasena_fuerte(datos['contrasena']):
                raise ValidationError("contrasena", "***", "Contraseña debe tener al menos 6 caracteres, incluir mayúsculas, minúsculas y números")
        
        if 'rol_id' in datos:
            validate_required(datos['rol_id'], "rol_id")
            if not self.repository._role_exists_and_active(datos['rol_id']):
                raise ValidationError("rol_id", datos['rol_id'], "Rol no existe o está inactivo")
    
    def _validar_correo_dominio(self, correo: str) -> bool:
        """Valida que el correo sea del dominio de la clínica"""
        dominios_permitidos = ['@clinica.com', '@mariainmaculada.com']
        return any(correo.lower().endswith(dominio) for dominio in dominios_permitidos)
    
    def _validar_contrasena_fuerte(self, contrasena: str) -> bool:
        """Valida que la contraseña cumpla criterios de seguridad"""
        if len(contrasena) < 6:
            return False
        
        # Al menos una mayúscula, una minúscula, un número
        tiene_mayuscula = re.search(r'[A-Z]', contrasena)
        tiene_minuscula = re.search(r'[a-z]', contrasena)
        tiene_numero = re.search(r'\d', contrasena)
        
        return bool(tiene_mayuscula and tiene_minuscula and tiene_numero)
    
    def _formatear_usuario_para_qml(self, usuario: Dict[str, Any]) -> Dict[str, Any]:
        """Formatea datos de usuario para consumo en QML"""
        if not usuario:
            return None
        print(f"🔍 DEBUG - Usuario raw desde BD: {usuario}")
        resultado = {
            'usuarioId': str(usuario['id']),
            'nombreCompleto': f"{usuario['Nombre']} {usuario['Apellido_Paterno']} {usuario['Apellido_Materno']}",
            'nombre': usuario['Nombre'],
            'apellidoPaterno': usuario['Apellido_Paterno'],
            'apellidoMaterno': usuario['Apellido_Materno'],
            'nombreUsuario': usuario['correo'].split('@')[0],  # Parte antes del @
            'correoElectronico': usuario['correo'],
            'rolPerfil': usuario.get('rol_nombre', 'Sin rol'),
            'rolId': usuario.get('rol_id'),
            'estado': 'Activo' if usuario.get('Estado', False) else 'Inactivo',
            'estadoBool': bool(usuario.get('Estado', False)),
            'ultimoAcceso': 'No disponible',  # TODO: Implementar tracking de último acceso
            'fechaRegistro': datetime.now().strftime('%Y-%m-%d'),  # TODO: Obtener fecha real de BD
            # Campos adicionales para QML
            'rolDescripcion': usuario.get('rol_descripcion', ''),
            'esAdmin': usuario.get('rol_nombre') == 'Administrador',
            'esMedico': usuario.get('rol_nombre') == 'Médico'
        }
        print(f"🔍 DEBUG - Datos formateados para QML: {resultado}")
        return resultado
    
    def _obtener_permisos_rol(self, rol_nombre: str) -> Dict[str, bool]:
        """Define permisos según el rol"""
        permisos_por_rol = {
            'Administrador': {
                'Vista general': True,
                'Farmacia': True,
                'Consultas': True,
                'Laboratorio': True,
                'Enfermería': True,
                'Servicios Básicos': True,
                'Usuarios': True,
                'Trabajadores': True,
                'Configuración': True
            },
            'Médico': {
                'Vista general': True,
                'Farmacia': False,
                'Consultas': True,
                'Laboratorio': True,
                'Enfermería': False,
                'Servicios Básicos': False,
                'Usuarios': False,
                'Trabajadores': False,
                'Configuración': False
            }
        }
        
        return permisos_por_rol.get(rol_nombre, {})
    
    def _generar_token(self) -> str:
        """Genera token único para sesión"""
        return secrets.token_urlsafe(32)
    
    def _verificar_intentos_login(self, correo: str) -> bool:
        """Verifica si se han excedido los intentos de login"""
        if correo not in self.intentos_login:
            return False
        
        datos = self.intentos_login[correo]
        tiempo_transcurrido = datetime.now() - datos['ultimo_intento']
        
        # Si han pasado más del tiempo de bloqueo, limpiar intentos
        if tiempo_transcurrido.total_seconds() > (self.LOGIN_BLOCK_TIME * 60):
            del self.intentos_login[correo]
            return False
        
        return datos['intentos'] >= self.MAX_LOGIN_ATTEMPTS
    
    def _registrar_intento_fallido(self, correo: str):
        """Registra intento de login fallido"""
        ahora = datetime.now()
        
        if correo not in self.intentos_login:
            self.intentos_login[correo] = {
                'intentos': 1,
                'primer_intento': ahora,
                'ultimo_intento': ahora
            }
        else:
            self.intentos_login[correo]['intentos'] += 1
            self.intentos_login[correo]['ultimo_intento'] = ahora
        
        print(f"⚠️ Intento fallido: {correo} - Total: {self.intentos_login[correo]['intentos']}")
    
    def _limpiar_intentos_login(self, correo: str):
        """Limpia intentos de login después de éxito"""
        if correo in self.intentos_login:
            del self.intentos_login[correo]
    
    def _actualizar_sesiones_usuario(self, usuario_id: int, datos_actualizados: Dict[str, Any]):
        """Actualiza datos en sesiones activas del usuario"""
        for sesion in self.sesiones_activas.values():
            if sesion.usuario_id == usuario_id:
                sesion.nombre_completo = f"{datos_actualizados['Nombre']} {datos_actualizados['Apellido_Paterno']} {datos_actualizados['Apellido_Materno']}"
                sesion.correo = datos_actualizados['correo']
                sesion.rol_nombre = datos_actualizados.get('rol_nombre', sesion.rol_nombre)
                sesion.permisos = self._obtener_permisos_rol(sesion.rol_nombre)
    
    def _cerrar_sesiones_usuario(self, usuario_id: int):
        """Cierra todas las sesiones activas de un usuario"""
        tokens_a_eliminar = []
        for token, sesion in self.sesiones_activas.items():
            if sesion.usuario_id == usuario_id:
                tokens_a_eliminar.append(token)
        
        for token in tokens_a_eliminar:
            del self.sesiones_activas[token]
        
        if tokens_a_eliminar:
            print(f"🚪 Sesiones cerradas para usuario ID {usuario_id}: {len(tokens_a_eliminar)}")
    
    def _operacion_lote_estado(self, usuarios_ids: List[int], nuevo_estado: bool, operacion: str) -> Dict[str, Any]:
        """Operación en lote para cambiar estado de usuarios"""
        resultados = {'exitosos': 0, 'errores': 0, 'detalles': []}
        
        for usuario_id in usuarios_ids:
            try:
                success = self.repository.update_user(usuario_id, estado=nuevo_estado)
                if success:
                    resultados['exitosos'] += 1
                    if not nuevo_estado:  # Si se desactiva, cerrar sesiones
                        self._cerrar_sesiones_usuario(usuario_id)
                else:
                    resultados['errores'] += 1
                    resultados['detalles'].append({
                        'usuario_id': usuario_id,
                        'error': f'No se pudo {operacion} usuario'
                    })
            except Exception as e:
                resultados['errores'] += 1
                resultados['detalles'].append({
                    'usuario_id': usuario_id,
                    'error': str(e)
                })
        
        return {
            'success': resultados['errores'] == 0,
            'total_procesados': len(usuarios_ids),
            'exitosos': resultados['exitosos'],
            'errores': resultados['errores'],
            'detalles': resultados['detalles'] if resultados['errores'] > 0 else []
        }
    
    # ===============================
    # LIMPIEZA Y MANTENIMIENTO
    # ===============================
    
    def limpiar_sesiones_expiradas(self):
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
            print(f"🧹 Sesiones expiradas limpiadas: {len(tokens_expirados)}")
        
        return len(tokens_expirados)
    
    def invalidar_cache_usuarios(self):
        """Invalida todos los cachés relacionados con usuarios"""
        self.repository.invalidate_user_caches()
        invalidate_after_update(['usuarios_completos', 'roles_activos', 'estadisticas_usuarios'])
        print("🗑️ Cache de usuarios invalidado")

# Instancia global del servicio
usuario_service = UsuarioService()