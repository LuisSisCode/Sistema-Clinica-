"""
Configuración centralizada del sistema
"""

import os
from datetime import timedelta

class Config:
    """Configuración principal del sistema"""
    
    # ===== BASE DE DATOS =====
    DB_SERVER = "10.171.82.135"
    DB_NAME = "ClinicaMariaInmaculada"  # Debe coincidir con database_conexion.py
    DB_TRUSTED_CONNECTION = True
    DB_TIMEOUT = 30
    
    # ===== CACHÉ =====
    CACHE_DEFAULT_TTL = 300  # 5 minutos
    CACHE_TTL_CONFIG = {
        'productos': 180,        # 3 min
        'marcas': 1800,         # 30 min  
        'ventas_today': 60,     # 1 min
        'stock_producto': 120,  # 2 min
        'lotes_activos': 300,   # 5 min
        'proveedores': 900,     # 15 min
        'precios': 240,         # 4 min
    }
    
    # ===== ARCHIVOS Y DIRECTORIOS =====
    BASE_DIR = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    REPORTS_DIR = os.path.join(BASE_DIR, "reportes")
    TEMP_DIR = os.path.join(BASE_DIR, "temp")
    LOGS_DIR = os.path.join(BASE_DIR, "logs")
    
    # ===== LOGGING =====
    LOG_LEVEL = "INFO"
    LOG_FORMAT = "%(asctime)s - %(name)s - %(levelname)s - %(message)s"
    LOG_FILE = os.path.join(LOGS_DIR, "clinica.log")
    
    # ===== FARMACIA / INVENTARIO =====
    STOCK_MINIMO_DEFAULT = 10
    DIAS_VENCIMIENTO_ALERTA = 90
    FIFO_ENABLED = True
    
    # ===== PERFORMANCE =====
    THREAD_POOL_MAX_WORKERS = 4
    AUTO_UPDATE_INTERVAL = 30000  # ms (30 segundos)
    
    # ===== SEGURIDAD =====
    SESSION_TIMEOUT = timedelta(hours=8)
    MAX_LOGIN_ATTEMPTS = 3
    
    @classmethod
    def ensure_directories(cls):
        """Crea directorios necesarios si no existen"""
        directories = [cls.REPORTS_DIR, cls.TEMP_DIR, cls.LOGS_DIR]
        
        for directory in directories:
            if not os.path.exists(directory):
                os.makedirs(directory, exist_ok=True)
                print(f"📁 Directorio creado: {directory}")
    
    @classmethod 
    def get_db_connection_string(cls):
        """Retorna string de conexión para SQL Server"""
        conn_str = f"DRIVER={{SQL Server}};SERVER={cls.DB_SERVER};DATABASE={cls.DB_NAME};"
        
        if cls.DB_TRUSTED_CONNECTION:
            conn_str += "Trusted_Connection=yes;"
        
        return conn_str
    
    @classmethod
    def print_config(cls):
        """Imprime configuración actual"""
        print("⚙️ CONFIGURACIÓN DEL SISTEMA")
        print("="*40)
        print(f"🗄️  Base de datos: {cls.DB_SERVER}/{cls.DB_NAME}")
        print(f"💾 Caché TTL default: {cls.CACHE_DEFAULT_TTL}s")
        print(f"📁 Directorio base: {cls.BASE_DIR}")
        print(f"📊 Reportes: {cls.REPORTS_DIR}")
        print(f"🧵 Thread pool: {cls.THREAD_POOL_MAX_WORKERS} workers")
        print("="*40)

# Crear directorios al importar
Config.ensure_directories()