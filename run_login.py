# run_login.py - Script principal para lanzar el sistema de login
"""
Script de lanzamiento para el sistema de login de Clínica App
Este script inicializa todo el sistema y lanza la interfaz de autenticación.
"""

import sys
import os
import logging
from pathlib import Path

# Configurar el path para importar nuestros módulos
project_root = Path(__file__).parent
sys.path.insert(0, str(project_root))

def setup_logging():
    """Configura el sistema de logging"""
    log_dir = project_root / "logs"
    log_dir.mkdir(exist_ok=True)
    
    # Configurar logging SIN emojis para Windows
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
        handlers=[
            logging.FileHandler(log_dir / "login.log", encoding='utf-8'),  # ← encoding añadido
            logging.StreamHandler(sys.stdout)
        ]
    )

def check_dependencies():
    """Verifica que todas las dependencias estén instaladas"""
    required_modules = [
        'PySide6',
        'pyodbc',
        'dotenv'
    ]
    
    missing_modules = []
    
    for module in required_modules:
        try:
            __import__(module)
        except ImportError:
            missing_modules.append(module)
    
    if missing_modules:
        print("❌ Módulos faltantes:")
        for module in missing_modules:
            print(f"   - {module}")
        print("\n💡 Instala las dependencias con:")
        print("   pip install -r requirements.txt")
        return False
    
    return True

def check_files():
    """Verifica que los archivos necesarios existan"""
    required_files = [
        "login.qml",
        ".env"  # Opcional pero recomendado
    ]
    
    missing_files = []
    
    for file_path in required_files:
        full_path = project_root / file_path
        if not full_path.exists():
            if file_path == ".env":
                # Crear .env básico si no existe
                create_default_env()
            else:
                missing_files.append(file_path)
    
    if missing_files:
        print("❌ Archivos faltantes:")
        for file_path in missing_files:
            print(f"   - {file_path}")
        return False
    
    return True

def create_default_env():
    """Crea un archivo .env por defecto"""
    env_content = """# Configuración de base de datos
DB_SERVER=DESKTOP-HOE6AHT\\SQLEXPRESS
DB_DATABASE=ClinicaDB
DB_USERNAME=sa
DB_PASSWORD=tu_password_aqui
DB_DRIVER=ODBC Driver 17 for SQL Server

# Para autenticación de Windows, comenta USERNAME/PASSWORD y descomenta:
# DB_TRUSTED_CONNECTION=yes

# Configuración de la aplicación
SECRET_KEY=clinica-secret-key-2025
LOG_LEVEL=INFO
SESSION_TIMEOUT=3600
"""
    
    env_path = project_root / ".env"
    with open(env_path, 'w', encoding='utf-8') as f:
        f.write(env_content)
    
    print("✅ Archivo .env creado con configuración por defecto")
    print("⚠️  Edita el archivo .env con tu configuración de base de datos")

def main():
    """Función principal"""
    print("🏥 Clínica App - Sistema de Login")
    print("=" * 40)
    
    # Configurar logging
    setup_logging()
    logger = logging.getLogger(__name__)
    
    try:
        # Verificar dependencias
        print("🔍 Verificando dependencias...")
        if not check_dependencies():
            return 1
        print("✅ Dependencias verificadas")
        
        # Verificar archivos
        print("📁 Verificando archivos...")
        if not check_files():
            return 1
        print("✅ Archivos verificados")
        
        # Importar y ejecutar el backend de login
        print("🚀 Iniciando sistema de login...")
        from login_backend import main as login_main
        
        return login_main()
        
    except KeyboardInterrupt:
        print("\n👋 Aplicación cancelada por el usuario")
        return 0
        
    except Exception as e:
        logger.error(f"❌ Error crítico: {e}")
        import traceback
        traceback.print_exc()
        return 1

if __name__ == "__main__":
    sys.exit(main())