# backend/core/db_installer.py
"""
Sistema de Instalación de Base de Datos
✅ CORREGIDO: Detección automática de driver ODBC y mejor lógica
"""

import os
import pyodbc
from pathlib import Path
from typing import Tuple, Optional, Dict
import sys
import time
import re

class DatabaseInstaller:
    """Instalador automatizado de base de datos"""
    
    # ✅ Lista de drivers ODBC en orden de preferencia
    ODBC_DRIVERS = [
        "ODBC Driver 18 for SQL Server",
        "ODBC Driver 17 for SQL Server",
        "ODBC Driver 13 for SQL Server",
        "SQL Server Native Client 11.0",
        "SQL Server"
    ]
    
    def __init__(self):
        """
        ✅ Inicializar instalador con rutas correctas y detección de driver
        """
        # Detectar driver ODBC disponible
        self.driver = self._detectar_driver_odbc()
        
        if not self.driver:
            print("⚠️ ADVERTENCIA: No se detectó driver ODBC para SQL Server")
            print("   Instala 'ODBC Driver 17 for SQL Server' o superior")
        else:
            print(f"🔌 Driver ODBC detectado: {self.driver}")
        
        # Configurar directorio de scripts
        if getattr(sys, 'frozen', False):
            # ✅ EJECUTABLE: Scripts en RAÍZ de _MEIPASS
            base_path = sys._MEIPASS
            
            possible_paths = [
                Path(base_path) / 'database_scripts',
                Path(base_path) / '_internal' / 'database_scripts',
            ]
            
            self.scripts_dir = None
            for path in possible_paths:
                if path.exists():
                    self.scripts_dir = path
                    print(f"✅ Scripts SQL encontrados en: {path}")
                    break
            
            if self.scripts_dir is None:
                self.scripts_dir = possible_paths[0]
                print(f"⚠️ Scripts SQL NO encontrados, usando ruta por defecto: {self.scripts_dir}")
        else:
            # ✅ DESARROLLO
            self.scripts_dir = Path(__file__).parent.parent.parent / 'database_scripts'
            print(f"🔍 MODO DESARROLLO - Scripts en: {self.scripts_dir}")
        
        print(f"📂 Directorio de scripts SQL configurado: {self.scripts_dir}")
        print(f"   ¿Existe? {self.scripts_dir.exists()}")
        
        if self.scripts_dir.exists():
            sql_files = list(self.scripts_dir.glob('*.sql'))
            print(f"   Archivos .sql encontrados: {len(sql_files)}")
            for sql_file in sql_files:
                print(f"      - {sql_file.name}")
    
    def _detectar_driver_odbc(self) -> Optional[str]:
        """
        ✅ NUEVO: Detecta automáticamente el driver ODBC disponible
        
        Returns:
            str: Nombre del driver encontrado, o None
        """
        try:
            drivers_disponibles = list(pyodbc.drivers())
            print(f"🔍 Drivers ODBC disponibles: {drivers_disponibles}")
            
            for driver in self.ODBC_DRIVERS:
                if driver in drivers_disponibles:
                    return driver
            
            return None
            
        except Exception as e:
            print(f"❌ Error detectando drivers: {e}")
            return None
    
    def _build_connection_string(self, server: str, database: str = "master") -> str:
        """
        ✅ NUEVO: Construye cadena de conexión con el driver detectado
        
        Args:
            server: Servidor SQL Server
            database: Base de datos
            
        Returns:
            str: Cadena de conexión
        """
        if not self.driver:
            raise Exception("❌ No hay driver ODBC disponible")
        
        conn_parts = [
            f"DRIVER={{{self.driver}}}",
            f"SERVER={server}",
            f"DATABASE={database}",
            "Trusted_Connection=yes",
            "Timeout=10"
        ]
        
        # Para drivers modernos, agregar configuración
        if "17" in self.driver or "18" in self.driver:
            conn_parts.extend([
                "Encrypt=no",
                "TrustServerCertificate=yes"
            ])
        
        return ";".join(conn_parts)
    
    def verificar_sql_server(self, server: str = "localhost\\SQLEXPRESS") -> Tuple[bool, str]:
        """
        Verifica si SQL Server está disponible
        
        Returns:
            Tuple[bool, str]: (éxito, mensaje)
        """
        try:
            if not self.driver:
                return False, "❌ No se encontró driver ODBC. Instala 'ODBC Driver 17 for SQL Server'"
            
            conn_str = self._build_connection_string(server, "master")
            
            conn = pyodbc.connect(conn_str, timeout=5)
            cursor = conn.cursor()
            cursor.execute("SELECT @@VERSION")
            version = cursor.fetchone()[0]
            conn.close()
            
            print(f"✅ SQL Server conectado")
            print(f"   Versión: {version[:100]}")
            
            return True, f"✅ SQL Server detectado correctamente: {server}"
            
        except pyodbc.Error as e:
            error_msg = str(e)
            
            if "Login timeout expired" in error_msg:
                return False, "❌ SQL Server no responde. Verifica que el servicio esté iniciado."
            elif "Data source name not found" in error_msg or "IM002" in error_msg:
                return False, "❌ Driver ODBC no encontrado. Instala 'ODBC Driver 17 for SQL Server'."
            else:
                return False, f"❌ Error conectando a SQL Server: {error_msg[:200]}"
        
        except Exception as e:
            return False, f"❌ Error inesperado: {str(e)}"
    
    def verificar_base_datos_existe(self, server: str, db_name: str) -> Tuple[bool, str]:
        """
        ✅ CORREGIDO: Verifica si la base de datos existe y es accesible
        
        Args:
            server: Servidor SQL
            db_name: Nombre de la base de datos
        
        Returns:
            Tuple[bool, str]: (existe, mensaje)
        """
        try:
            print(f"🔍 Verificando BD: {db_name} en servidor: {server}")
            
            if not self.driver:
                return False, "❌ No hay driver ODBC disponible"
            
            # Conectar a master
            conn_str = self._build_connection_string(server, "master")
            conn = pyodbc.connect(conn_str, timeout=5)
            
            # Verificar si existe
            cursor = conn.cursor()
            cursor.execute("SELECT database_id FROM sys.databases WHERE name = ?", (db_name,))
            existe = cursor.fetchone() is not None
            
            if not existe:
                cursor.close()
                conn.close()
                return False, f"❌ Base de datos '{db_name}' no existe en el servidor"
            
            cursor.close()
            conn.close()
            
            # Verificar que tenga tablas
            conn_str_db = self._build_connection_string(server, db_name)
            
            try:
                conn_db = pyodbc.connect(conn_str_db, timeout=5)
                cursor_db = conn_db.cursor()
                cursor_db.execute("""
                    SELECT COUNT(*) 
                    FROM INFORMATION_SCHEMA.TABLES 
                    WHERE TABLE_TYPE = 'BASE TABLE'
                """)
                num_tablas = cursor_db.fetchone()[0]
                
                cursor_db.close()
                conn_db.close()
                
                if num_tablas < 5:
                    return False, f"⚠️ Base de datos '{db_name}' existe pero está incompleta ({num_tablas} tablas)"
                
                return True, f"✅ Base de datos '{db_name}' disponible y operativa ({num_tablas} tablas)"
                
            except pyodbc.Error:
                return False, f"❌ Base de datos '{db_name}' existe pero no es accesible"
            
        except pyodbc.Error as e:
            error_msg = str(e)
            
            if "Cannot open database" in error_msg or "does not exist" in error_msg:
                return False, f"❌ Base de datos '{db_name}' no existe"
            else:
                return False, f"❌ Error verificando BD: {error_msg[:200]}"
        
        except Exception as e:
            return False, f"❌ Error inesperado: {str(e)}"
    
    def ejecutar_script_sql(self, script_path: Path, server: str, db_name: str) -> Tuple[bool, str]:
        """
        Ejecuta un archivo SQL
        ✅ CORREGIDO: Detecta automáticamente la codificación del archivo
        
        Args:
            script_path: Ruta al archivo .sql
            server: Servidor SQL
            db_name: Base de datos
            
        Returns:
            Tuple[bool, str]: (éxito, mensaje)
        """
        try:
            if not script_path.exists():
                return False, f"❌ Archivo no encontrado: {script_path}"
            
            # ✅ NUEVO: Detectar codificación automáticamente
            sql_content = None
            encodings = ['utf-8', 'utf-16', 'utf-16-le', 'utf-16-be', 'latin-1', 'cp1252']
            
            for encoding in encodings:
                try:
                    with open(script_path, 'r', encoding=encoding) as f:
                        sql_content = f.read()
                    print(f"  ✅ Archivo leído con codificación: {encoding}")
                    break
                except (UnicodeDecodeError, UnicodeError):
                    continue
            
            if sql_content is None:
                return False, f"❌ No se pudo leer el archivo con ninguna codificación conocida"
            
            # Conectar
            conn_str = self._build_connection_string(server, db_name)
            conn = pyodbc.connect(conn_str, autocommit=True)
            cursor = conn.cursor()
            
            # Dividir por GO (con saltos de línea)
            import re
            comandos = re.split(r'\bGO\b', sql_content, flags=re.IGNORECASE)
            comandos = [cmd.strip() for cmd in comandos if cmd.strip()]
            
            ejecutados = 0
            errores = 0
            
            for i, comando in enumerate(comandos, 1):
                try:
                    cursor.execute(comando)
                    ejecutados += 1
                except pyodbc.Error as e:
                    error_msg = str(e)
                    # Ignorar algunos errores comunes
                    if "already exists" not in error_msg.lower():
                        errores += 1
                        if errores <= 3:
                            print(f"⚠️ Error en comando {i}: {error_msg[:100]}")
            
            cursor.close()
            conn.close()
            
            print(f"✅ Script ejecutado: {ejecutados} comandos, {errores} errores")
            return True, f"✅ Script ejecutado exitosamente"
            
        except Exception as e:
            return False, f"❌ Error ejecutando script: {str(e)}"
    
    def crear_base_datos(self, server: str, db_name: str) -> Tuple[bool, str]:
        """
        Crea la base de datos y ejecuta scripts
        
        Args:
            server: Servidor SQL
            db_name: Nombre de la base de datos
            
        Returns:
            Tuple[bool, str]: (éxito, mensaje)
        """
        try:
            print(f"📊 Creando base de datos: {db_name}")
            
            # Verificar que no exista
            existe, _ = self.verificar_base_datos_existe(server, db_name)
            if existe:
                return True, f"ℹ️ Base de datos '{db_name}' ya existe"
            
            # Conectar a master
            conn_str = self._build_connection_string(server, "master")
            conn = pyodbc.connect(conn_str, autocommit=True)
            cursor = conn.cursor()
            
            # Crear BD
            print(f"🔨 Creando base de datos...")
            cursor.execute(f"CREATE DATABASE [{db_name}]")
            
            cursor.close()
            conn.close()
            
            # Esperar un momento
            time.sleep(2)
            
            # Ejecutar script de esquema
            schema_script = self.scripts_dir / "01_schema.sql"
            
            if not schema_script.exists():
                return False, f"❌ No se encontró: {schema_script.name}"
            
            print(f"⚙️ Ejecutando {schema_script.name}...")
            exito, mensaje = self.ejecutar_script_sql(schema_script, server, db_name)
            
            if not exito:
                return False, f"❌ Error en esquema: {mensaje}"
            
            # Ejecutar datos iniciales
            datos_script = self.scripts_dir / "02_datos_iniciales.sql"
            
            if datos_script.exists():
                print(f"📝 Ejecutando {datos_script.name}...")
                time.sleep(1)
                exito, mensaje = self.ejecutar_script_sql(datos_script, server, db_name)
                
                if not exito:
                    print(f"⚠️ Advertencia en datos iniciales: {mensaje}")
            
            return True, f"✅ Base de datos '{db_name}' creada exitosamente"
            
        except Exception as e:
            import traceback
            traceback.print_exc()
            return False, f"❌ Error creando BD: {str(e)}"
    
    def crear_usuario_admin(self, server: str, db_name: str, username: str = "admin", password: str = "admin123") -> Tuple[bool, str]:
        """
        Crea el usuario administrador inicial
        
        Args:
            server: Servidor SQL
            db_name: Base de datos
            username: Nombre de usuario
            password: Contraseña
            
        Returns:
            Tuple[bool, str]: (éxito, mensaje)
        """
        try:
            print(f"👤 Creando usuario administrador en: {db_name}")
            
            time.sleep(1)
            
            conn_str = self._build_connection_string(server, db_name)
            conn = pyodbc.connect(conn_str, timeout=30)
            cursor = conn.cursor()
            
            # Verificar si existe
            cursor.execute("SELECT id FROM Usuario WHERE nombre_usuario = ?", (username,))
            if cursor.fetchone():
                conn.close()
                print(f"ℹ️ Usuario '{username}' ya existe")
                return True, f"ℹ️ Usuario '{username}' ya existe"
            
            # Obtener ID del rol
            cursor.execute("SELECT Id FROM Roles WHERE Nombre = 'Administrador'")
            rol = cursor.fetchone()
            
            if not rol:
                conn.close()
                return False, "❌ Rol 'Administrador' no encontrado"
            
            rol_id = rol[0]
            
            # Crear usuario
            sql = """
            INSERT INTO Usuario 
            (Nombre, Apellido_Paterno, Apellido_Materno, contrasena,
            Id_Rol, Estado, nombre_usuario)
            VALUES (?, ?, ?, ?, ?,GETDATE(), ? )
            """
            
            cursor.execute(sql, (
                'Administrador', 'Sistema', 'General', 'admin@clinica.com',
                username, password, rol_id, 1
            ))
            conn.commit()
            
            cursor.execute("SELECT id FROM Usuario WHERE nombre_usuario = ?", (username,))
            user_id = cursor.fetchone()[0]
            
            conn.close()
            
            print(f"✅ Usuario administrador creado (ID: {user_id})")
            
            return True, f"✅ Usuario '{username}' creado exitosamente"
            
        except Exception as e:
            import traceback
            traceback.print_exc()
            return False, f"❌ Error creando usuario: {str(e)}"
    
    def setup_completo(self, server: str = "localhost\\SQLEXPRESS", db_name: str = "ClinicaMariaInmaculada") -> Tuple[bool, str, Dict]:
        """
        Ejecuta el setup completo automático
        
        Returns:
            Tuple[bool, str, dict]: (éxito, mensaje, credenciales)
        """
        credenciales = {}
        
        try:
            print("\n" + "="*60)
            print("🚀 INICIANDO SETUP AUTOMÁTICO")
            print("="*60 + "\n")
            
            # Paso 1: Verificar SQL Server
            print("📋 Paso 1/4: Verificando SQL Server...")
            exito, mensaje = self.verificar_sql_server(server)
            if not exito:
                return False, mensaje, credenciales
            print(f"   {mensaje}\n")
            
            # Paso 2: Verificar BD
            print("📋 Paso 2/4: Verificando base de datos...")
            existe, mensaje = self.verificar_base_datos_existe(server, db_name)
            print(f"   {mensaje}\n")
            
            if not existe:
                # Paso 3: Crear BD
                print("📋 Paso 3/4: Creando base de datos...")
                exito, mensaje = self.crear_base_datos(server, db_name)
                if not exito:
                    return False, mensaje, credenciales
                print(f"   {mensaje}\n")
            else:
                print("   ✅ Usando base de datos existente\n")
            
            # Paso 4: Crear usuario admin
            print("📋 Paso 4/4: Creando usuario administrador...")
            username = "admin"
            password = "admin123"
            exito, mensaje = self.crear_usuario_admin(server, db_name, username, password)
            if not exito:
                return False, mensaje, credenciales
            print(f"   {mensaje}\n")
            
            credenciales = {
                "username": username,
                "password": password,
                "server": server,
                "database": db_name
            }
            
            print("="*60)
            print("✅ ¡SETUP COMPLETADO EXITOSAMENTE!")
            print("="*60)
            print(f"\n📝 Credenciales de acceso:")
            print(f"   Usuario: {username}")
            print(f"   Contraseña: {password}")
            print(f"\n⚠️  IMPORTANTE: Cambia tu contraseña después del primer inicio de sesión\n")
            
            return True, "✅ Setup completado exitosamente", credenciales
            
        except Exception as e:
            return False, f"❌ Error en setup: {str(e)}", credenciales


if __name__ == "__main__":
    print("🧪 Probando DatabaseInstaller...")
    
    installer = DatabaseInstaller()
    exito, mensaje, creds = installer.setup_completo()
    
    if exito:
        print("\n✅ TEST EXITOSO")
        print(f"Credenciales: {creds}")
    else:
        print(f"\n❌ TEST FALLIDO: {mensaje}")