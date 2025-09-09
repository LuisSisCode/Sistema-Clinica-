#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Sistema de Login para Clínica App - SQL Server
Ejecuta la interfaz QML con backend integrado para autenticación
"""

import sys
import os
import json
import hashlib
import threading
import time
from datetime import datetime, timedelta
from pathlib import Path

from PySide6.QtCore import QObject, Signal, Slot, QTimer, Property
from PySide6.QtQml import QQmlApplicationEngine, qmlRegisterType
from PySide6.QtGui import QIcon
from PySide6.QtWidgets import QApplication, QMessageBox
from .database_conexion import DatabaseConnection


class DatabaseManager:
    """Gestor de base de datos SQL Server para el sistema de login"""
    
    def __init__(self):
        self.database_conexion = DatabaseConnection()
        self.init_database()
    
    def init_database(self):
        """Inicializa la base de datos y crea tablas si no existen"""
        try:
            conn = self.database_conexion.get_connection()
            cursor = conn.cursor()
            
            # Verificar que existe la tabla Usuario
            cursor.execute("""
                SELECT COUNT(*) 
                FROM INFORMATION_SCHEMA.TABLES 
                WHERE TABLE_NAME = 'Usuario'
            """)
            
            if cursor.fetchone()[0] == 0:
                print("❌ Error: No se encontró la tabla Usuario en la base de datos")
                raise Exception("Tabla Usuario no encontrada")
            
            # Crear tabla de sesiones si no existe
            cursor.execute("""
                IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'Sesiones')
                BEGIN
                    CREATE TABLE Sesiones (
                        id INT IDENTITY(1,1) PRIMARY KEY,
                        usuario_id INT NOT NULL,
                        token NVARCHAR(255) UNIQUE NOT NULL,
                        expires_at DATETIME NOT NULL,
                        created_at DATETIME DEFAULT GETDATE(),
                        FOREIGN KEY (usuario_id) REFERENCES Usuario(id)
                    )
                END
            """)
            
            conn.commit()
            conn.close()
            print("✅ Base de datos SQL Server inicializada correctamente")
            
        except Exception as e:
            print(f"❌ Error inicializando base de datos: {e}")
            raise
    
    def _hash_password(self, password):
        """Hashea la contraseña usando SHA-256"""
        return hashlib.sha256(password.encode()).hexdigest()
    
    def _get_role_name(self, id_rol):
        """Convierte el ID de rol a nombre de rol"""
        role_mapping = {
            1: "admin",
            2: "doctor", 
            3: "nurse",
            4: "receptionist",
            5: "system"
        }
        return role_mapping.get(id_rol, "user")
    
    def authenticate_user(self, email, password):
        """Autentica un usuario contra la tabla Usuario de SQL Server"""
        try:
            conn = self.database_conexion.get_connection()
            cursor = conn.cursor()
            
            # Buscar usuario por email (correo)
            cursor.execute("""
                SELECT id, Nombre, Apellido_Paterno, Apellido_Materno, 
                       correo, contrasena, Id_Rol, Estado
                FROM Usuario 
                WHERE correo = ? AND Estado = 1
            """, (email,))
            
            user = cursor.fetchone()
            
            if not user:
                conn.close()
                return False, "Usuario no encontrado o inactivo", None
            
            user_id, nombre, apellido_p, apellido_m, correo, contrasena_db, id_rol, estado = user
            
            # Verificar contraseña
            password_hash = self._hash_password(password)
            
            # Comparar con hash almacenado o contraseña plana (para migración)
            if contrasena_db != password_hash and contrasena_db != password:
                conn.close()
                return False, "Contraseña incorrecta", None
            
            # Si la contraseña es correcta pero está en texto plano, actualizarla
            if contrasena_db == password:
                cursor.execute("""
                    UPDATE Usuario 
                    SET contrasena = ? 
                    WHERE id = ?
                """, (password_hash, user_id))
                print(f"🔐 Contraseña actualizada a hash para usuario {email}")
            
            # Construir nombre completo
            full_name = f"{nombre} {apellido_p}"
            if apellido_m:
                full_name += f" {apellido_m}"
            
            # Obtener nombre del rol
            role_name = self._get_role_name(id_rol)
            
            # Crear token de sesión
            token = self._generate_token()
            expires_at = datetime.now() + timedelta(hours=8)
            
            cursor.execute("""
                INSERT INTO Sesiones (usuario_id, token, expires_at)
                VALUES (?, ?, ?)
            """, (user_id, token, expires_at))
            
            # Actualizar último login (si existe el campo)
            try:
                cursor.execute("""
                    IF COL_LENGTH('Usuario', 'last_login') IS NOT NULL
                        UPDATE Usuario SET last_login = GETDATE() WHERE id = ?
                """, (user_id,))
            except:
                pass  # Campo last_login no existe, continuar
            
            conn.commit()
            conn.close()
            
            user_data = {
                "id": user_id,
                "email": correo,
                "full_name": full_name.strip(),
                "role": role_name,
                "department": self._get_department_by_role(role_name),
                "token": token,
                "login_time": datetime.now().isoformat()
            }
            
            return True, "Acceso autorizado", user_data
                
        except Exception as e:
            print(f"❌ Error en autenticación: {e}")
            if 'conn' in locals():
                conn.close()
            return False, f"Error del sistema: {str(e)}", None
    
    def _get_department_by_role(self, role):
        """Asigna departamento basado en el rol"""
        dept_mapping = {
            "admin": "Administración",
            "doctor": "Medicina General", 
            "nurse": "Enfermería",
            "receptionist": "Recepción",
            "system": "IT"
        }
        return dept_mapping.get(role, "General")
    
    def _generate_token(self):
        """Genera un token único para la sesión"""
        import secrets
        return secrets.token_urlsafe(32)
    
    def get_test_users(self):
        """Obtiene la lista de usuarios de la base de datos"""
        try:
            conn = self.database_conexion.get_connection()
            cursor = conn.cursor()
            
            cursor.execute("""
                SELECT correo, Nombre, Apellido_Paterno, Apellido_Materno, 
                       Id_Rol, Estado, 
                       CASE 
                           WHEN COL_LENGTH('Usuario', 'last_login') IS NOT NULL 
                           THEN last_login 
                           ELSE NULL 
                       END as last_login
                FROM Usuario 
                WHERE Estado = 1
                ORDER BY Id_Rol, Nombre
            """)
            
            users = []
            for row in cursor.fetchall():
                correo, nombre, apellido_p, apellido_m, id_rol, estado, last_login = row
                
                full_name = f"{nombre} {apellido_p}"
                if apellido_m:
                    full_name += f" {apellido_m}"
                
                users.append({
                    "email": correo,
                    "full_name": full_name.strip(),
                    "role": self._get_role_name(id_rol),
                    "department": self._get_department_by_role(self._get_role_name(id_rol)),
                    "last_login": last_login.isoformat() if last_login else None
                })
            
            conn.close()
            return users
            
        except Exception as e:
            print(f"❌ Error obteniendo usuarios: {e}")
            return []
    
    def get_system_stats(self):
        """Obtiene estadísticas del sistema"""
        try:
            conn = self.database_conexion.get_connection()
            cursor = conn.cursor()
            
            # Contar usuarios por rol
            cursor.execute("""
                SELECT Id_Rol, COUNT(*) 
                FROM Usuario 
                WHERE Estado = 1 
                GROUP BY Id_Rol
            """)
            
            users_by_role = {}
            for row in cursor.fetchall():
                id_rol, count = row
                role_name = self._get_role_name(id_rol)
                users_by_role[role_name] = count
            
            # Contar sesiones activas
            cursor.execute("""
                SELECT COUNT(*) 
                FROM Sesiones 
                WHERE expires_at > GETDATE()
            """)
            active_sessions = cursor.fetchone()[0]
            
            # Total de usuarios activos
            cursor.execute("""
                SELECT COUNT(*) 
                FROM Usuario 
                WHERE Estado = 1
            """)
            total_users = cursor.fetchone()[0]
            
            conn.close()
            
            return {
                "total_users": total_users,
                "users_by_role": users_by_role,
                "active_sessions": active_sessions,
                "database_size": "SQL Server",
                "last_updated": datetime.now().isoformat()
            }
            
        except Exception as e:
            print(f"❌ Error obteniendo estadísticas: {e}")
            return {}


class LoginBackend(QObject):
    """Backend para la interfaz de login en QML"""
    
    # Señales que emite hacia QML
    connectionStatus = Signal(bool, str)
    loginResult = Signal(bool, str, 'QVariant')
    userAuthenticated = Signal('QVariant')
    
    def __init__(self):
        super().__init__()
        self.db = None
        self.is_connected = False
        self.current_user = None
        
        # Inicializar base de datos
        QTimer.singleShot(500, self._init_database)
        
        # Timer para verificar conexión
        self.connection_timer = QTimer()
        self.connection_timer.timeout.connect(self.check_connection)
        self.connection_timer.start(3000)  # Verificar cada 3 segundos
    
    def _init_database(self):
        """Inicializa la conexión a la base de datos"""
        try:
            self.db = DatabaseManager()
            self.is_connected = True
            self.connectionStatus.emit(True, "Conectado a SQL Server")
            print("✅ Conectado a SQL Server")
        except Exception as e:
            self.is_connected = False
            self.connectionStatus.emit(False, f"Error conectando a SQL Server: {str(e)}")
            print(f"❌ Error conectando a SQL Server: {e}")
    
    @Slot()
    def check_connection(self):
        """Verifica el estado de la conexión a la base de datos"""
        if not self.db:
            return
            
        try:
            # Intentar una consulta simple
            test_stats = self.db.get_system_stats()
            if test_stats:
                if not self.is_connected:
                    self.is_connected = True
                    self.connectionStatus.emit(True, "Conexión restablecida con SQL Server")
                    print("✅ Reconectado a SQL Server")
            else:
                raise Exception("No se pudo obtener estadísticas")
                
        except Exception as e:
            if self.is_connected:
                self.is_connected = False
                self.connectionStatus.emit(False, f"Error de conexión SQL Server: {str(e)}")
                print(f"❌ Error de conexión SQL Server: {e}")
    
    @Slot(str, str)
    def authenticateUser(self, email, password):
        """Autentica un usuario de forma asíncrona"""
        def authenticate():
            try:
                print(f"🔐 Intentando autenticar: {email}")
                
                if not self.db:
                    self.loginResult.emit(False, "Base de datos no disponible", None)
                    return
                
                # Simular un pequeño delay para mostrar loading
                time.sleep(1)
                
                success, message, user_data = self.db.authenticate_user(email, password)
                
                if success:
                    self.current_user = user_data
                    print(f"✅ Usuario autenticado: {user_data['full_name']}")
                    self.userAuthenticated.emit(user_data)
                else:
                    print(f"❌ Autenticación fallida: {message}")
                
                # Emitir resultado
                self.loginResult.emit(success, message, user_data)
                
            except Exception as e:
                error_msg = f"Error del sistema: {str(e)}"
                print(f"❌ Error en autenticación: {e}")
                self.loginResult.emit(False, error_msg, None)
        
        # Ejecutar en hilo separado para no bloquear la UI
        thread = threading.Thread(target=authenticate)
        thread.daemon = True
        thread.start()
    
    @Slot(result='QVariant')
    def getTestUsers(self):
        """Obtiene usuarios de la base de datos"""
        if not self.db:
            return []
        
        users = self.db.get_test_users()
        print(f"📋 Obtenidos {len(users)} usuarios de la base de datos")
        return users
    
    @Slot(result='QVariant')
    def getSystemStats(self):
        """Obtiene estadísticas del sistema"""
        if not self.db:
            return {}
        
        stats = self.db.get_system_stats()
        print(f"📊 Estadísticas del sistema: {stats}")
        return stats


class LoginApplication:
    """Aplicación principal de login - MODIFICADA para reutilizar QApplication existente"""
    
    def __init__(self, existing_app=None):
        # ✅ CAMBIO PRINCIPAL: No crear nueva app, usar la existente
        if existing_app:
            self.app = existing_app
            self.owns_app = False  # No somos dueños de la app
            print("🔄 Reutilizando QApplication existente para login")
        else:
            # Solo crear app si no existe una
            self.app = QApplication(sys.argv)
            self.owns_app = True  # Somos dueños de la app
            print("🆕 Creando nueva QApplication para login")
        
        # Crear engine y backend
        self.engine = QQmlApplicationEngine()
        self.backend = LoginBackend()
        
        # Configurar aplicación solo si somos dueños
        if self.owns_app:
            self.app.setApplicationName("Clínica App - Login SQL Server")
            self.app.setApplicationVersion("2.0.0")
            self.app.setOrganizationName("Clínica María Inmaculada")
        
        # Configurar icono si existe
        icon_path = Path("Image/Image_login/icon.png")
        if icon_path.exists() and self.app:
            self.app.setWindowIcon(QIcon(str(icon_path)))
    
    def setup_qml(self):
        """Configura el contexto QML"""
        # Registrar el backend en QML
        self.engine.rootContext().setContextProperty("backend", self.backend)
        
        # Manejar errores de QML
        self.engine.objectCreated.connect(self.on_object_created)
        
    def on_object_created(self, obj, url):
        """Maneja la creación de objetos QML"""
        if obj is None:
            print(f"❌ Error cargando QML: {url}")
            if self.app:
                QMessageBox.critical(
                    None,
                    "Error de Carga",
                    f"No se pudo cargar la interfaz de login.\n\nArchivo: {url}\n\nVerifique que el archivo login.qml existe y está bien formado."
                )
                if self.owns_app:
                    self.app.quit()
        else:
            print("✅ Interfaz QML de login cargada correctamente")
    
    def run(self, execute_app=None):
        """
        Ejecuta la aplicación de login
        
        Args:
            execute_app (bool): Si True, ejecuta app.exec(). Si None, decide automáticamente según owns_app
        """
        try:
            # Configurar QML
            self.setup_qml()
            
            # Verificar que el archivo QML existe
            qml_file = Path("login.qml")
            if not qml_file.exists():
                if self.app:
                    QMessageBox.critical(
                        None,
                        "Archivo No Encontrado",
                        f"No se encontró el archivo login.qml en el directorio actual.\n\nDirectorio actual: {os.getcwd()}\n\nAsegúrese de que el archivo login.qml está en la misma carpeta que login.py"
                    )
                return 1
            
            # Cargar QML
            print(f"📂 Cargando {qml_file.absolute()}")
            self.engine.load(qml_file.absolute().as_uri())
            
            # Verificar si hay ventanas cargadas
            if not self.engine.rootObjects():
                print("❌ No se cargó ninguna ventana de login")
                return 1
            
            print("🚀 Interfaz de login iniciada con SQL Server")
            
            # ✅ CAMBIO: Solo ejecutar app.exec() si decidimos hacerlo
            should_execute = execute_app if execute_app is not None else self.owns_app
            
            if should_execute and self.app:
                print("\n" + "="*60)
                print("CONEXIÓN SQL SERVER:")
                print("="*60)
                print("📍 Servidor: LUISLOPEZ\\SQLEXPRESS")
                print("🗄️ Base de datos: ClinicaMariaInmaculada")
                print("📋 Tabla: Usuario")
                print("="*60)
                print("💡 Consejos:")
                print("   • Presiona F12 para mostrar/ocultar el panel de debug")
                print("   • Presiona ESC para cerrar la aplicación")
                print("   • Los usuarios se cargan desde SQL Server")
                print("   • Las contraseñas se hashean automáticamente")
                print("="*60 + "\n")
                
                return self.app.exec()
            else:
                print("🔄 Login QML cargado, control retornado al proceso principal")
                return 0
            
        except Exception as e:
            print(f"❌ Error fatal en login: {e}")
            if self.app:
                QMessageBox.critical(
                    None,
                    "Error Fatal",
                    f"Error inesperado al iniciar la aplicación:\n\n{str(e)}\n\nVerifique la conexión a SQL Server.\n\nLa aplicación se cerrará."
                )
            return 1


def main():
    """Función principal - Solo para ejecutar login independiente"""
    try:
        # Esta función es para ejecutar el login de forma independiente
        app = LoginApplication()  # Sin pasar existing_app, creará su propia QApplication
        return app.run()  # Ejecutará app.exec() automáticamente
    except KeyboardInterrupt:
        print("\n👋 Aplicación interrumpida por el usuario")
        return 0
    except Exception as e:
        print(f"❌ Error crítico: {e}")
        return 1


if __name__ == "__main__":
    exit_code = main()
    sys.exit(exit_code)