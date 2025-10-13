"""
Gestor de conexión a SQL Server
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
    """
    _instance = None
    
    def __new__(cls):
        if cls._instance is None:
            cls._instance = super(DatabaseConnection, cls).__new__(cls)
            cls._instance._initialized = False
        return cls._instance
    
    def __init__(self):
        """
        Inicializa la conexión usando Config centralizado.
        """
        if self._initialized:
            return
        
        try:
            # Usar configuración centralizada
            self.connection_string = Config.get_db_connection_string()
            self.server = Config.DB_SERVER
            self.database = Config.DB_DATABASE
            
            logger.info(f"📡 Configurando conexión a: {self.server}/{self.database}")
            self._initialized = True
            
        except Exception as e:
            logger.error(f"❌ Error configurando conexión: {e}")
            raise

    def test_connection(self):
        """
        Prueba la conexión a la base de datos.
        
        Returns:
            bool: True si conecta exitosamente, False si falla.
        """
        try:
            with pyodbc.connect(self.connection_string, timeout=5) as conn:
                cursor = conn.cursor()
                cursor.execute("SELECT 1")
                cursor.fetchone()
            logger.info("✅ Conexión a BD exitosa")
            return True
        except Exception as e:
            logger.error(f"❌ Error al conectar a BD: {e}")
            return False
    
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
        Obtiene la cadena de conexión.
        
        Returns:
            str: Connection string.
        """
        return self.connection_string
    
    def database_exists(self):
        """
        Verifica si la base de datos existe.
        
        Returns:
            bool: True si existe, False si no.
        """
        try:
            # Conectar a master para verificar si DB existe
            master_conn_str = self.connection_string.replace(
                f"DATABASE={self.database}",
                "DATABASE=master"
            )
            
            with pyodbc.connect(master_conn_str) as conn:
                cursor = conn.cursor()
                cursor.execute(
                    "SELECT name FROM sys.databases WHERE name = ?",
                    (self.database,)
                )
                result = cursor.fetchone()
                return result is not None
                
        except Exception as e:
            logger.error(f"❌ Error verificando existencia de BD: {e}")
            return False

# NO ejecutar nada al importar - solo definir la clase
# Esto permite que el código decida cuándo conectar