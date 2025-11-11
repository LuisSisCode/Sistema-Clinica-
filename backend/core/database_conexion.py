"""
Gestor de conexión a SQL Server
✅ CORREGIDO: Soporta múltiples drivers ODBC automáticamente
"""

import pyodbc
import logging
from .config import Config

logging.basicConfig(
    level=logging.INFO, 
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger('database_conexion')

class DatabaseConnection:
    """
    Clase Singleton para manejar la conexión a SQL Server.
    ✅ CORREGIDO: Detecta automáticamente el mejor driver ODBC disponible
    """
    _instance = None
    
    # ✅ NUEVO: Lista de drivers ODBC en orden de preferencia
    ODBC_DRIVERS = [
        "ODBC Driver 18 for SQL Server",
        "ODBC Driver 17 for SQL Server",
        "ODBC Driver 13 for SQL Server",
        "SQL Server Native Client 11.0",
        "SQL Server"
    ]
    
    def __new__(cls):
        if cls._instance is None:
            cls._instance = super(DatabaseConnection, cls).__new__(cls)
            cls._instance._initialized = False
        return cls._instance
    
    def __init__(self):
        """
        Inicializa la conexión usando Config centralizado.
        ✅ CORREGIDO: Detecta automáticamente el driver ODBC disponible
        """
        if self._initialized:
            return
        
        try:
            # Obtener configuración
            self.server = Config.DB_SERVER
            self.database = Config.DB_DATABASE
            self.timeout = getattr(Config, 'DB_TIMEOUT', 30)
            
            # ✅ NUEVO: Detectar driver ODBC disponible
            self.driver = self._detectar_driver_odbc()
            
            if not self.driver:
                raise Exception(
                    "❌ No se encontró ningún driver ODBC para SQL Server instalado.\n"
                    "Por favor, instala 'ODBC Driver 17 for SQL Server' o superior."
                )
            
            # Construir cadena de conexión con el driver detectado
            self.connection_string = self._build_connection_string(
                self.server, 
                self.database, 
                self.driver
            )
            
            logger.info(f"🔌 Driver ODBC detectado: {self.driver}")
            logger.info(f"📡 Configurando conexión a: {self.server}/{self.database}")
            self._initialized = True
            
        except Exception as e:
            logger.error(f"❌ Error configurando conexión: {e}")
            raise
    
    def _detectar_driver_odbc(self):
        """
        ✅ NUEVO: Detecta automáticamente el driver ODBC disponible
        
        Returns:
            str: Nombre del driver ODBC encontrado, o None si no hay ninguno
        """
        try:
            drivers_disponibles = [d for d in pyodbc.drivers()]
            logger.info(f"🔍 Drivers ODBC disponibles: {drivers_disponibles}")
            
            # Buscar el primer driver de nuestra lista que esté disponible
            for driver in self.ODBC_DRIVERS:
                if driver in drivers_disponibles:
                    logger.info(f"✅ Driver seleccionado: {driver}")
                    return driver
            
            logger.warning("⚠️ No se encontró ningún driver ODBC recomendado")
            return None
            
        except Exception as e:
            logger.error(f"❌ Error detectando drivers ODBC: {e}")
            return None
    
    def _build_connection_string(self, server, database, driver):
        """
        ✅ NUEVO: Construye la cadena de conexión con el driver especificado
        
        Args:
            server: Servidor SQL Server
            database: Nombre de la base de datos
            driver: Driver ODBC a usar
            
        Returns:
            str: Cadena de conexión completa
        """
        # Configuración base
        conn_parts = [
            f"DRIVER={{{driver}}}",
            f"SERVER={server}",
            f"DATABASE={database}",
            "Trusted_Connection=yes",
            f"Timeout={self.timeout}"
        ]
        
        # ✅ Para drivers modernos (17+), agregar configuración de encriptación
        if "17" in driver or "18" in driver:
            conn_parts.extend([
                "Encrypt=no",  # Desactivar encriptación para desarrollo local
                "TrustServerCertificate=yes"
            ])
        
        return ";".join(conn_parts)
    
    def get_connection_string_for_server(self, server, database=None):
        """
        ✅ NUEVO: Obtiene cadena de conexión para un servidor/BD específico
        Útil para el setup wizard
        
        Args:
            server: Servidor SQL Server
            database: Base de datos (opcional, usa 'master' si no se especifica)
            
        Returns:
            str: Cadena de conexión
        """
        db = database if database else "master"
        return self._build_connection_string(server, db, self.driver)

    def test_connection(self):
        """
        Prueba la conexión a la base de datos.
        ✅ MEJORADO: Mejor manejo de errores
        
        Returns:
            tuple: (bool: éxito, str: mensaje)
        """
        try:
            with pyodbc.connect(self.connection_string, timeout=5) as conn:
                cursor = conn.cursor()
                cursor.execute("SELECT 1")
                cursor.fetchone()
            
            logger.info("✅ Conexión a BD exitosa")
            return True, "✅ Conexión exitosa"
            
        except pyodbc.Error as e:
            error_msg = f"❌ Error de ODBC: {e}"
            logger.error(error_msg)
            return False, error_msg
            
        except Exception as e:
            error_msg = f"❌ Error al conectar: {e}"
            logger.error(error_msg)
            return False, error_msg
    
    def get_connection(self):
        """
        Obtiene una nueva conexión a la base de datos.
        
        Returns:
            pyodbc.Connection: Objeto de conexión.
        
        Raises:
            Exception: Si no puede establecer conexión.
        """
        try:
            return pyodbc.connect(self.connection_string)
        except Exception as e:
            logger.error(f"❌ Error obteniendo conexión: {e}")
            raise
    
    def get_connection_string(self):
        """
        Obtiene la cadena de conexión actual.
        
        Returns:
            str: Connection string.
        """
        return self.connection_string
    
    def database_exists(self):
        """
        Verifica si la base de datos existe.
        ✅ CORREGIDO: Mejor detección de errores
        
        Returns:
            tuple: (bool: existe, str: mensaje)
        """
        try:
            # Construir cadena para master
            master_conn_str = self._build_connection_string(
                self.server,
                "master",
                self.driver
            )
            
            logger.info(f"🔍 Verificando BD: {self.database} en servidor: {self.server}")
            
            with pyodbc.connect(master_conn_str, timeout=5) as conn:
                cursor = conn.cursor()
                cursor.execute(
                    "SELECT name FROM sys.databases WHERE name = ?",
                    (self.database,)
                )
                result = cursor.fetchone()
                
                if result:
                    logger.info(f"✅ Base de datos '{self.database}' existe")
                    return True, f"✅ Base de datos '{self.database}' encontrada"
                else:
                    logger.info(f"ℹ️ Base de datos '{self.database}' NO existe")
                    return False, f"ℹ️ Base de datos '{self.database}' no existe"
        
        except pyodbc.Error as e:
            error_msg = f"❌ Error ODBC verificando BD: {e}"
            logger.error(error_msg)
            return False, error_msg
            
        except Exception as e:
            error_msg = f"❌ Error verificando existencia de BD: {e}"
            logger.error(error_msg)
            return False, error_msg
    
    def test_server_connection(self, server=None):
        """
        ✅ NUEVO: Prueba conexión al servidor (sin especificar BD)
        Útil para verificar que SQL Server está corriendo
        
        Args:
            server: Servidor a probar (opcional, usa el configurado si no se especifica)
            
        Returns:
            tuple: (bool: éxito, str: mensaje)
        """
        test_server = server if server else self.server
        
        try:
            master_conn_str = self._build_connection_string(
                test_server,
                "master",
                self.driver
            )
            
            with pyodbc.connect(master_conn_str, timeout=5) as conn:
                cursor = conn.cursor()
                cursor.execute("SELECT @@VERSION")
                version = cursor.fetchone()[0]
                
                logger.info(f"✅ SQL Server conectado: {test_server}")
                logger.info(f"   Versión: {version[:100]}...")
                
                return True, f"✅ SQL Server disponible: {test_server}"
                
        except pyodbc.Error as e:
            error_msg = f"❌ Error ODBC conectando al servidor: {e}"
            logger.error(error_msg)
            return False, error_msg
            
        except Exception as e:
            error_msg = f"❌ Error conectando al servidor: {e}"
            logger.error(error_msg)
            return False, error_msg


# Testing
if __name__ == "__main__":
    print("🧪 Testing DatabaseConnection...")
    
    try:
        db = DatabaseConnection()
        print(f"\n📋 Configuración:")
        print(f"  Driver: {db.driver}")
        print(f"  Servidor: {db.server}")
        print(f"  Base de datos: {db.database}")
        print(f"  Connection string: {db.connection_string}")
        
        print("\n🔍 Probando conexión al servidor...")
        exito, mensaje = db.test_server_connection()
        print(f"  {mensaje}")
        
        if exito:
            print("\n🔍 Verificando si existe la base de datos...")
            existe, mensaje = db.database_exists()
            print(f"  {mensaje}")
            
            if existe:
                print("\n🔍 Probando conexión a la base de datos...")
                exito, mensaje = db.test_connection()
                print(f"  {mensaje}")
        
    except Exception as e:
        print(f"❌ Error: {e}")
        import traceback
        traceback.print_exc()