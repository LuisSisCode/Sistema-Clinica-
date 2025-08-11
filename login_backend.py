# login_backend.py - Backend integrado para el sistema de login
import sys
import os
import logging
from datetime import datetime
from pathlib import Path

# Importaciones de PySide6
from PySide6.QtCore import QObject, Slot, Property, Signal, QUrl
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine

# Importaciones del sistema de autenticación
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

try:
    from backend.database.connection import db_connection
    from backend.services.auth_service import auth_service
    from backend.api.auth_api import auth_api
    from backend.core.config import Config
    from backend.cache.memory_cache import memory_cache
except ImportError as e:
    print(f"Error importando módulos del backend: {e}")
    print("Asegúrate de que la estructura del backend esté completa")
    sys.exit(1)

# Configurar logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('logs/login.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

class LoginBackend(QObject):
    """Backend para el sistema de login integrado con la base de datos"""
    
    # Señales para comunicación con QML
    loginResult = Signal(bool, str, 'QVariant')
    connectionStatus = Signal(bool, str)
    userAuthenticated = Signal('QVariant')
    
    def __init__(self):
        super().__init__()
        self._status = "Inicializando sistema..."
        self._connection_ok = False
        self._current_user = None
        
        # Inicializar sistema
        self._initialize_system()
    
    def _initialize_system(self):
        """Inicializa el sistema completo"""
        try:
            # Validar configuración
            Config.validate_config()
            logger.info("✅ Configuración validada")
            
            # Crear directorios necesarios
            self._create_directories()
            
            # Probar conexión a base de datos
            self._test_database_connection()
            
            # Conectar señales del auth_api
            auth_api.loginResult.connect(self._handle_login_result)
            
            self._status = "Sistema listo para autenticar"
            logger.info("✅ Sistema inicializado correctamente")
            
        except Exception as e:
            self._status = f"Error de inicialización: {str(e)}"
            logger.error(f"❌ Error inicializando sistema: {e}")
            self.connectionStatus.emit(False, self._status)
    
    def _create_directories(self):
        """Crea los directorios necesarios"""
        directories = [
            'logs',
            'cache',
            'cache/data',
            'cache/temp',
            'cache/sessions'
        ]
        
        for directory in directories:
            Path(directory).mkdir(parents=True, exist_ok=True)
        
        logger.info("📁 Directorios creados/verificados")
    
    def _test_database_connection(self):
        """Prueba la conexión a la base de datos"""
        try:
            # Probar consulta simple
            result = db_connection.execute_query(
                "SELECT COUNT(*) as total FROM Usuario WHERE Estado = 1",
                fetch_one=True
            )
            
            if result:
                user_count = result['total']
                self._connection_ok = True
                status_msg = f"✅ Conexión BD exitosa. Usuarios activos: {user_count}"
                logger.info(status_msg)
                self.connectionStatus.emit(True, status_msg)
            else:
                raise Exception("No se pudo obtener datos de la base")
                
        except Exception as e:
            self._connection_ok = False
            error_msg = f"❌ Error de conexión BD: {str(e)}"
            logger.error(error_msg)
            self.connectionStatus.emit(False, error_msg)
            raise
    
    @Property(str, notify=connectionStatus)
    def status(self):
        """Propiedad status para QML"""
        return self._status
    
    @Property(bool, notify=connectionStatus)
    def isConnected(self):
        """Propiedad de conexión para QML"""
        return self._connection_ok
    
    @Slot(str, str)
    def authenticateUser(self, email, password):
        """
        Autentica un usuario desde QML
        
        Args:
            email (str): Email del usuario
            password (str): Contraseña
        """
        try:
            if not self._connection_ok:
                self.loginResult.emit(False, "Error de conexión a la base de datos", {})
                return
            
            if not email or not password:
                self.loginResult.emit(False, "Email y contraseña son requeridos", {})
                return
            
            logger.info(f"🔐 Intentando autenticar usuario: {email}")
            
            # Usar el auth_api para login
            auth_api.login(email.strip(), password)
            
        except Exception as e:
            logger.error(f"❌ Error en authenticateUser: {e}")
            self.loginResult.emit(False, "Error interno del sistema", {})
    
    def _handle_login_result(self, success, message, user_data):
        """Maneja el resultado del login desde auth_api"""
        try:
            if success:
                self._current_user = user_data
                logger.info(f"✅ Login exitoso para: {user_data.get('usuario', {}).get('correo', 'N/A')}")
                
                # Emitir señal para QML
                self.loginResult.emit(True, "Login exitoso", user_data)
                self.userAuthenticated.emit(user_data)
                
            else:
                self._current_user = None
                logger.warning(f"❌ Login fallido: {message}")
                self.loginResult.emit(False, message, {})
                
        except Exception as e:
            logger.error(f"❌ Error manejando resultado de login: {e}")
            self.loginResult.emit(False, "Error procesando autenticación", {})
    
    @Slot(result='QVariant')
    def getCurrentUser(self):
        """Obtiene el usuario actual"""
        return self._current_user or {}
    
    @Slot(result='QVariant')
    def getSystemStats(self):
        """Obtiene estadísticas del sistema para debug"""
        try:
            # Estadísticas de caché
            cache_stats = memory_cache.get_stats()
            
            # Estadísticas de base de datos
            db_stats = self._get_database_stats()
            
            return {
                'cache': cache_stats,
                'database': db_stats,
                'connection_ok': self._connection_ok,
                'status': self._status
            }
            
        except Exception as e:
            logger.error(f"Error obteniendo estadísticas: {e}")
            return {'error': str(e)}
    
    def _get_database_stats(self):
        """Obtiene estadísticas básicas de la base de datos"""
        try:
            if not self._connection_ok:
                return {'error': 'No hay conexión'}
            
            queries = {
                'usuarios_activos': "SELECT COUNT(*) as count FROM Usuario WHERE Estado = 1",
                'total_pacientes': "SELECT COUNT(*) as count FROM Pacientes",
                'total_doctores': "SELECT COUNT(*) as count FROM Doctores",
                'consultas_hoy': """
                    SELECT COUNT(*) as count FROM Consultas 
                    WHERE CAST(Fecha AS DATE) = CAST(GETDATE() AS DATE)
                """
            }
            
            stats = {}
            for key, query in queries.items():
                try:
                    result = db_connection.execute_query(query, fetch_one=True)
                    stats[key] = result['count'] if result else 0
                except:
                    stats[key] = 0
            
            return stats
            
        except Exception as e:
            logger.error(f"Error obteniendo estadísticas de BD: {e}")
            return {'error': str(e)}
    
    @Slot()
    def clearCache(self):
        """Limpia el caché del sistema"""
        try:
            memory_cache.clear()
            logger.info("🧹 Caché limpiado")
        except Exception as e:
            logger.error(f"Error limpiando caché: {e}")
    
    @Slot(result='QVariant')
    def getTestUsers(self):
        """Obtiene usuarios de prueba para testing (solo en desarrollo)"""
        try:
            if not self._connection_ok:
                return []
            
            query = """
                SELECT TOP 5 u.correo, u.Nombre, u.Apellido_Paterno, r.Nombre as Rol
                FROM Usuario u
                INNER JOIN Roles r ON u.Id_Rol = r.id
                WHERE u.Estado = 1
                ORDER BY u.id
            """
            
            results = db_connection.execute_query(query)
            return results or []
            
        except Exception as e:
            logger.error(f"Error obteniendo usuarios de prueba: {e}")
            return []

def main():
    """Función principal para ejecutar el sistema de login"""
    try:
        # Configuración de la aplicación
        os.environ["QT_QUICK_CONTROLS_STYLE"] = "Basic"
        os.environ["QT_DEBUG_PLUGINS"] = "1"
        
        app = QGuiApplication(sys.argv)
        app.setApplicationName("Clínica App - Login")
        app.setApplicationVersion("1.0.0")
        
        # Crear el motor QML
        engine = QQmlApplicationEngine()
        
        # Crear e instalar el backend
        backend = LoginBackend()
        engine.rootContext().setContextProperty("backend", backend)
        engine.rootContext().setContextProperty("authAPI", auth_api)
        
        # Cargar el archivo QML
        qml_file = os.path.join(os.path.dirname(__file__), "login.qml")
        
        if not os.path.exists(qml_file):
            logger.error(f"❌ Archivo QML no encontrado: {qml_file}")
            sys.exit(1)
        
        logger.info(f"🎨 Cargando interfaz: {qml_file}")
        engine.load(QUrl.fromLocalFile(qml_file))
        
        if not engine.rootObjects():
            logger.error("❌ No se pudo cargar la interfaz QML")
            sys.exit(1)
        
        logger.info("🚀 Sistema de login iniciado correctamente")
        return app.exec()
        
    except Exception as e:
        logger.error(f"❌ Error crítico en main: {e}")
        return 1

if __name__ == "__main__":
    sys.exit(main())