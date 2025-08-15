import pyodbc
import logging

# Configurar logging

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(name)s - %(levelname)s - %(message)s')
logger = logging.getLogger('db_connection')

class DatabaseConnection:
    """
    Clase para manejar la conexión a la base de datos SQL Server.
    """
    _instance = None
    
    def __new__(cls, *args, **kwargs):
        """
        Implementación del patrón Singleton para asegurar una única instancia
        de la conexión a la base de datos.
        """
        if cls._instance is None:
            cls._instance = super(DatabaseConnection, cls).__new__(cls)
            cls._instance._initialized = False
        return cls._instance
    
    def __init__(self, server="192.168.0.105", database="ClinicaMariaInmaculada", trusted_connection=False):
        """
        Inicializa la conexión a la base de datos SQL Server.
        
        Args:
            server (str): Nombre del servidor SQL Server.
            database (str): Nombre de la base de datos.
            trusted_connection (bool): Usar autenticación de Windows (True) o SQL Server (False).
        """
        # Evitar reinicialización si ya está inicializado (parte del patrón Singleton)
        if self._initialized:
            return
            
        self.server = server
        self.database = database
        self.trusted_connection = trusted_connection
        
        try:
            self.connection_string = f"DRIVER={{SQL Server}};SERVER={server};DATABASE={database};"
            
            if trusted_connection:
                self.connection_string += "Trusted_Connection=yes;"
            else:
                # Si necesitas usar autenticación de SQL Server, añade usuario y contraseña
                self.connection_string += "UID=ADMIN;PWD=admin;"
                pass
                
            # Probar la conexión al iniciar
            self.test_connection()
            logger.info("Conexión a la base de datos establecida correctamente.")
            self._initialized = True
        except Exception as e:
            logger.error(f"Error al establecer la conexión a la base de datos: {str(e)}")
            raise

    def test_connection(self):
        """Prueba la conexión a la base de datos."""
        try:
            with pyodbc.connect(self.connection_string) as conn:
                pass
        except Exception as e:
            logger.error(f"Error al probar la conexión: {str(e)}")
            raise
    
    def get_connection(self):
        """
        Obtiene una conexión a la base de datos.
        
        Returns:
            Connection: Objeto de conexión pyodbc.
        """
        try:
            return pyodbc.connect(self.connection_string)
        except Exception as e:
            logger.error(f"Error al obtener conexión: {str(e)}")
            raise
            
    def get_connection_string(self):
        """
        Obtiene la cadena de conexión.
        
        Returns:
            str: Cadena de conexión a la base de datos.
        """
        return self.connection_string

x = DatabaseConnection()
x.test_connection()