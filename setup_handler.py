# setup_handler.py
"""
Handler Principal del Setup Wizard
Coordinador entre la UI (QML) y la lógica (Python)
"""

from PySide6.QtCore import QObject, Signal, Slot, Property
from backend.core.db_installer import DatabaseInstaller
from backend.core.config_manager import ConfigManager
from typing import Optional

class SetupHandler(QObject):
    """
    Handler para el Setup Wizard
    Conecta la interfaz QML con la lógica Python
    """
    
    # Señales
    setupProgress = Signal(str)  # Mensaje de progreso
    setupCompleted = Signal(bool, str, 'QVariantMap')  # (éxito, mensaje, credenciales)
    validationCompleted = Signal(bool, str)  # Para validación de SQL Server
    
    def __init__(self, parent=None):
        super().__init__(parent)
        
        self.db_installer = DatabaseInstaller()
        self.config_manager = ConfigManager()
        
        self._is_processing = False
        self._setup_message = ""
        self._credenciales = {}
    
    # Propiedades para QML
    @Property(bool)
    def is_processing(self):
        return self._is_processing
    
    @Property(str)
    def setup_message(self):
        return self._setup_message
    
    @Slot()
    def validar_sql_server(self):
        """Valida que SQL Server esté instalado y disponible"""
        print("🔍 Validando SQL Server...")
        
        try:
            exito, mensaje = self.db_installer.verificar_sql_server()
            self.validationCompleted.emit(exito, mensaje)
            
        except Exception as e:
            self.validationCompleted.emit(False, f"❌ Error: {str(e)}")
    
    @Slot()
    def ejecutar_setup_automatico(self):
        """Ejecuta el setup automático completo"""
        print("\n🚀 INICIANDO SETUP AUTOMÁTICO DESDE QML")
        
        self._is_processing = True
        self._setup_message = "Iniciando setup automático..."
        self.setupProgress.emit(self._setup_message)
        
        try:
            # Ejecutar setup
            exito, mensaje, credenciales = self.db_installer.setup_completo()
            
            if exito:
                # Crear archivo de configuración
                self.setupProgress.emit("📝 Guardando configuración...")
                
                server = credenciales.get('server', 'localhost\\SQLEXPRESS')
                database = credenciales.get('database', 'ClinicaMariaInmaculada')
                
                if self.config_manager.crear_configuracion(server, database):
                    self.config_manager.marcar_setup_completado()
                    
                    # Convertir credenciales a QVariantMap compatible
                    creds_dict = {
                        'username': credenciales.get('username', 'admin'),
                        'password': credenciales.get('password', 'admin123'),
                        'server': server,
                        'database': database
                    }
                    
                    self._credenciales = creds_dict
                    self.setupCompleted.emit(True, mensaje, creds_dict)
                else:
                    self.setupCompleted.emit(False, "❌ Error guardando configuración", {})
            else:
                self.setupCompleted.emit(False, mensaje, {})
        
        except Exception as e:
            error_msg = f"❌ Error inesperado: {str(e)}"
            print(error_msg)
            import traceback
            traceback.print_exc()
            self.setupCompleted.emit(False, error_msg, {})
        
        finally:
            self._is_processing = False
    
    @Slot(str, str)
    def ejecutar_setup_manual(self, server: str, database: str):
        """Ejecuta setup con configuración manual"""
        print(f"\n🔧 SETUP MANUAL: {server} / {database}")
        
        self._is_processing = True
        self.setupProgress.emit("Ejecutando setup manual...")
        
        try:
            # Validar servidor
            self.setupProgress.emit(f"🔍 Validando servidor: {server}...")
            exito, mensaje = self.db_installer.verificar_sql_server(server)
            
            if not exito:
                self.setupCompleted.emit(False, mensaje, {})
                return
            
            # Crear base de datos
            self.setupProgress.emit(f"📊 Creando base de datos: {database}...")
            exito, mensaje = self.db_installer.crear_base_datos(server, database)
            
            if not exito:
                self.setupCompleted.emit(False, mensaje, {})
                return
            
            # Crear usuario admin
            self.setupProgress.emit("👤 Creando usuario administrador...")
            exito, mensaje = self.db_installer.crear_usuario_admin(server, database)
            
            if not exito:
                self.setupCompleted.emit(False, mensaje, {})
                return
            
            # Guardar configuración
            self.setupProgress.emit("💾 Guardando configuración...")
            if self.config_manager.crear_configuracion(server, database):
                self.config_manager.marcar_setup_completado()
                
                creds_dict = {
                    'username': 'admin',
                    'password': 'admin123',
                    'server': server,
                    'database': database
                }
                
                self.setupCompleted.emit(True, "✅ Setup completado", creds_dict)
            else:
                self.setupCompleted.emit(False, "❌ Error guardando configuración", {})
        
        except Exception as e:
            self.setupCompleted.emit(False, f"❌ Error: {str(e)}", {})
        
        finally:
            self._is_processing = False


# Testing
if __name__ == "__main__":
    print("🧪 Testing SetupHandler...")
    
    from PySide6.QtWidgets import QApplication
    import sys
    
    app = QApplication(sys.argv)
    handler = SetupHandler()
    
    # Test validación
    handler.validationCompleted.connect(lambda ok, msg: print(f"Validación: {ok} - {msg}"))
    handler.validar_sql_server()
    
    sys.exit(app.exec())