"""
Configuración centralizada del sistema
Lee variables de entorno desde .env o config.env
"""
import sys
import os
from pathlib import Path
from datetime import timedelta
from dotenv import load_dotenv

# Detectar si estamos en ejecutable o desarrollo
if getattr(sys, 'frozen', False):
    # Ejecutable PyInstaller
    BASE_DIR = Path(sys._MEIPASS).parent
else:
    # Desarrollo
    BASE_DIR = Path(__file__).resolve().parent.parent.parent

# Intentar cargar .env del directorio base
env_path = BASE_DIR / '.env'
if env_path.exists():
    load_dotenv(env_path)
    print(f"✅ Configuración cargada desde: {env_path}")
else:
    # Buscar config.env (generado por wizard de setup)
    config_env_path = BASE_DIR / 'config.env'
    if config_env_path.exists():
        load_dotenv(config_env_path)
        print(f"✅ Configuración cargada desde: {config_env_path}")
    else:
        print("⚠️ No se encontró archivo .env, usando valores por defecto")

class Config:
    """Configuración principal del sistema"""
    
    # ===== BASE DE DATOS =====
    DB_SERVER = os.getenv('DB_SERVER', 'localhost\\SQLEXPRESS')
    DB_DATABASE = os.getenv('DB_DATABASE', 'ClinicaMariaInmaculada')
    DB_TRUSTED_CONNECTION = os.getenv('DB_TRUSTED_CONNECTION', 'yes').lower() in ('yes', 'true', '1')
    DB_USER = os.getenv('DB_USER', '')
    DB_PASSWORD = os.getenv('DB_PASSWORD', '')
    DB_TIMEOUT = int(os.getenv('DB_TIMEOUT', '30'))
    
    # ===== APLICACIÓN =====
    CLINIC_NAME = os.getenv('CLINIC_NAME', 'Clínica María Inmaculada')
    FIRST_TIME_SETUP = os.getenv('FIRST_TIME_SETUP', 'True').lower() in ('true', '1', 'yes')
    
    # ===== CACHÉ =====
    CACHE_DEFAULT_TTL = 300  # 5 minutos
    CACHE_TTL_CONFIG = {
        'productos': 180,
        'marcas': 1800,
        'ventas_today': 60,
        'stock_producto': 120,
        'lotes_activos': 300,
        'proveedores': 900,
        'precios': 240,
    }
    
    # ===== ARCHIVOS Y DIRECTORIOS =====
    REPORTS_DIR = BASE_DIR / "reportes"
    TEMP_DIR = BASE_DIR / "temp"
    LOGS_DIR = BASE_DIR / "logs"
    DATABASE_SCRIPTS_DIR = BASE_DIR / "database_scripts"
    
    # ===== LOGGING =====
    LOG_LEVEL = os.getenv('LOG_LEVEL', 'INFO')
    LOG_FORMAT = "%(asctime)s - %(name)s - %(levelname)s - %(message)s"
    LOG_FILE = LOGS_DIR / "clinica.log"
    
    # ===== FARMACIA / INVENTARIO =====
    STOCK_MINIMO_DEFAULT = 10
    DIAS_VENCIMIENTO_ALERTA = 90
    FIFO_ENABLED = True
    
    # ===== PERFORMANCE =====
    THREAD_POOL_MAX_WORKERS = 4
    AUTO_UPDATE_INTERVAL = 30000  # ms
    
    # ===== SEGURIDAD =====
    SECRET_KEY = os.getenv('SECRET_KEY', 'clinica-secret-key-default-change-me')
    SESSION_TIMEOUT = timedelta(hours=8)
    MAX_LOGIN_ATTEMPTS = 3
    
    @classmethod
    def ensure_directories(cls):
        """Crea directorios necesarios si no existen"""
        directories = [cls.REPORTS_DIR, cls.TEMP_DIR, cls.LOGS_DIR]
        
        for directory in directories:
            directory.mkdir(parents=True, exist_ok=True)
            print(f"📁 Directorio verificado: {directory}")
    
    @classmethod 
    def get_db_connection_string(cls):
        """Retorna string de conexión para SQL Server"""
        conn_str = f"DRIVER={{SQL Server}};SERVER={cls.DB_SERVER};DATABASE={cls.DB_DATABASE};"
        
        if cls.DB_TRUSTED_CONNECTION:
            conn_str += "Trusted_Connection=yes;"
        else:
            if cls.DB_USER and cls.DB_PASSWORD:
                conn_str += f"UID={cls.DB_USER};PWD={cls.DB_PASSWORD};"
            else:
                raise ValueError("Se requiere DB_USER y DB_PASSWORD cuando DB_TRUSTED_CONNECTION=no")
        
        return conn_str
    
    @classmethod
    def is_first_run(cls):
        """Verifica si es la primera ejecución del sistema"""
        # Verificar si existe config.env
        config_env = BASE_DIR / 'config.env'
        if not config_env.exists():
            return True
        
        # Verificar si FIRST_TIME_SETUP está en True
        return cls.FIRST_TIME_SETUP
    
    @classmethod
    def mark_setup_complete(cls):
        """Marca el setup como completado"""
        config_env = BASE_DIR / 'config.env'
        if config_env.exists():
            # Leer archivo y actualizar FIRST_TIME_SETUP
            with open(config_env, 'r', encoding='utf-8') as f:
                lines = f.readlines()
            
            with open(config_env, 'w', encoding='utf-8') as f:
                for line in lines:
                    if line.startswith('FIRST_TIME_SETUP'):
                        f.write('FIRST_TIME_SETUP=False\n')
                    else:
                        f.write(line)
    
    @classmethod
    def print_config(cls):
        """Imprime configuración actual"""
        print("\n⚙️ CONFIGURACIÓN DEL SISTEMA")
        print("="*50)
        print(f"🏥 Clínica: {cls.CLINIC_NAME}")
        print(f"🗄️ Servidor BD: {cls.DB_SERVER}")
        print(f"💾 Base de datos: {cls.DB_DATABASE}")
        print(f"🔐 Auth Windows: {'Sí' if cls.DB_TRUSTED_CONNECTION else 'No'}")
        print(f"📁 Dir base: {BASE_DIR}")
        print(f"📊 Reportes: {cls.REPORTS_DIR}")
        print(f"🆕 Primera vez: {'Sí' if cls.FIRST_TIME_SETUP else 'No'}")
        print("="*50 + "\n")

# Crear directorios al importar
try:
    Config.ensure_directories()
except Exception as e:
    print(f"⚠️ Error creando directorios: {e}")