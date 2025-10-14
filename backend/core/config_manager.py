# backend/core/config_manager.py
"""
Gestor de Configuración
Maneja el archivo .env de forma segura
"""

import os
from pathlib import Path
from typing import Dict, Optional

class ConfigManager:
    """Gestor de configuración del sistema"""
    
    def __init__(self):
        self.base_dir = Path(__file__).resolve().parent.parent.parent
        self.env_file = self.base_dir / ".env"
        self.template_file = self.base_dir / "config_template.txt"
    
    def existe_configuracion(self) -> bool:
        """Verifica si existe el archivo de configuración"""
        return self.env_file.exists()
    
    def leer_configuracion(self) -> Dict[str, str]:
        """
        Lee la configuración actual
        
        Returns:
            Dict con la configuración
        """
        config = {}
        
        if not self.env_file.exists():
            return config
        
        try:
            with open(self.env_file, 'r', encoding='utf-8') as f:
                for line in f:
                    line = line.strip()
                    if line and not line.startswith('#') and '=' in line:
                        key, value = line.split('=', 1)
                        config[key.strip()] = value.strip()
            
            return config
            
        except Exception as e:
            print(f"⚠️ Error leyendo configuración: {e}")
            return {}
    
    def crear_configuracion(self, 
                           server: str = "localhost\\SQLEXPRESS",
                           database: str = "ClinicaMariaInmaculada",
                           trusted_connection: str = "yes") -> bool:
        """
        Crea el archivo de configuración .env
        
        Args:
            server: Servidor SQL
            database: Nombre de la base de datos
            trusted_connection: Usar autenticación de Windows
            
        Returns:
            bool: True si se creó exitosamente
        """
        try:
            config_content = f"""# Configuración - Sistema Clínica María Inmaculada
# Archivo generado automáticamente por Setup Wizard

[DATABASE]
DB_SERVER={server}
DB_DATABASE={database}
DB_TRUSTED_CONNECTION={trusted_connection}
DB_TIMEOUT=30

[APPLICATION]
CLINIC_NAME=Clínica María Inmaculada
FIRST_TIME_SETUP=False
REPORTS_DIR=reportes
LOG_LEVEL=INFO

[SECURITY]
SECRET_KEY=clinica-secret-key-2025
"""
            
            with open(self.env_file, 'w', encoding='utf-8') as f:
                f.write(config_content)
            
            print(f"✅ Archivo de configuración creado: {self.env_file}")
            return True
            
        except Exception as e:
            print(f"❌ Error creando configuración: {e}")
            return False
    
    def actualizar_configuracion(self, key: str, value: str) -> bool:
        """Actualiza un valor específico en la configuración"""
        try:
            config = self.leer_configuracion()
            config[key] = value
            
            # Reescribir archivo
            with open(self.env_file, 'w', encoding='utf-8') as f:
                for k, v in config.items():
                    f.write(f"{k}={v}\n")
            
            return True
            
        except Exception as e:
            print(f"❌ Error actualizando configuración: {e}")
            return False
    
    def marcar_setup_completado(self) -> bool:
        """Marca el setup como completado"""
        return self.actualizar_configuracion("FIRST_TIME_SETUP", "False")
    
    def es_primera_vez(self) -> bool:
        """
        Determina si es la primera ejecución
        
        Returns:
            bool: True si es primera vez
        """
        # Si no existe .env, es primera vez
        if not self.existe_configuracion():
            return True
        
        # Leer configuración
        config = self.leer_configuracion()
        
        # Si FIRST_TIME_SETUP no existe o es True, es primera vez
        first_time = config.get("FIRST_TIME_SETUP", "True")
        return first_time.lower() in ["true", "yes", "1"]


# Testing
if __name__ == "__main__":
    print("🧪 Probando ConfigManager...")
    
    manager = ConfigManager()
    
    print(f"¿Es primera vez? {manager.es_primera_vez()}")
    print(f"¿Existe configuración? {manager.existe_configuracion()}")
    
    if manager.existe_configuracion():
        config = manager.leer_configuracion()
        print(f"Configuración actual: {config}")