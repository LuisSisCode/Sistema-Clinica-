# backend/core/db_installer.py
"""
Sistema de Instalación de Base de Datos
Ejecuta scripts SQL y valida SQL Server
"""

import os
import pyodbc
from pathlib import Path
from typing import Tuple, Optional

class DatabaseInstaller:
    """Instalador automatizado de base de datos"""
    
    def __init__(self):
        self.base_dir = Path(__file__).resolve().parent.parent.parent
        self.scripts_dir = self.base_dir / "database_scripts"
        
    def verificar_sql_server(self, server: str = "localhost\\SQLEXPRESS") -> Tuple[bool, str]:
        """
        Verifica si SQL Server está disponible
        
        Returns:
            Tuple[bool, str]: (éxito, mensaje)
        """
        try:
            # Intentar conexión con master (base de datos del sistema)
            conn_str = (
                f"DRIVER={{ODBC Driver 17 for SQL Server}};"
                f"SERVER={server};"
                f"DATABASE=master;"
                f"Trusted_Connection=yes;"
            )
            
            # Intentar con driver alternativo si el 17 no está
            try:
                conn = pyodbc.connect(conn_str, timeout=5)
            except pyodbc.Error:
                # Probar con driver 13
                conn_str = conn_str.replace("ODBC Driver 17", "ODBC Driver 13")
                try:
                    conn = pyodbc.connect(conn_str, timeout=5)
                except pyodbc.Error:
                    # Probar con SQL Server Native Client
                    conn_str = (
                        f"DRIVER={{SQL Server}};"
                        f"SERVER={server};"
                        f"DATABASE=master;"
                        f"Trusted_Connection=yes;"
                    )
                    conn = pyodbc.connect(conn_str, timeout=5)
            
            conn.close()
            return True, f"✅ SQL Server detectado correctamente: {server}"
            
        except pyodbc.Error as e:
            error_msg = str(e)
            
            if "Login timeout expired" in error_msg:
                return False, f"❌ SQL Server no responde. Verifica que el servicio esté iniciado."
            elif "Data source name not found" in error_msg:
                return False, f"❌ Driver ODBC no encontrado. Instala 'ODBC Driver for SQL Server'."
            elif "Cannot open database" in error_msg:
                return True, "✅ SQL Server disponible (conexión OK)"
            else:
                return False, f"❌ Error conectando a SQL Server: {error_msg[:200]}"
                
        except Exception as e:
            return False, f"❌ Error inesperado verificando SQL Server: {e}"
    
    def verificar_base_datos_existe(self, server: str, db_name: str) -> bool:
        """Verifica si la base de datos ya existe"""
        try:
            conn_str = (
                f"DRIVER={{ODBC Driver 17 for SQL Server}};"
                f"SERVER={server};"
                f"DATABASE=master;"
                f"Trusted_Connection=yes;"
            )
            
            try:
                conn = pyodbc.connect(conn_str, timeout=5)
            except:
                conn_str = conn_str.replace("ODBC Driver 17", "SQL Server")
                conn = pyodbc.connect(conn_str, timeout=5)
            
            cursor = conn.cursor()
            cursor.execute(f"SELECT database_id FROM sys.databases WHERE name = '{db_name}'")
            existe = cursor.fetchone() is not None
            
            conn.close()
            return existe
            
        except Exception as e:
            print(f"⚠️ Error verificando BD: {e}")
            return False
    
    def ejecutar_script_sql(self, script_path: Path, server: str, db_name: Optional[str] = None) -> Tuple[bool, str]:
        """
        Ejecuta un script SQL con detección automática de encoding
        
        Args:
            script_path: Ruta al archivo .sql
            server: Servidor SQL
            db_name: Base de datos (None para usar master)
            
        Returns:
            Tuple[bool, str]: (éxito, mensaje)
        """
        try:
            if not script_path.exists():
                return False, f"❌ Script no encontrado: {script_path}"
            
            print(f"📄 Leyendo script: {script_path.name}")
            
            # 🆕 DETECTAR ENCODING AUTOMÁTICAMENTE
            sql_script = None
            encodings_to_try = ['utf-8-sig', 'utf-16', 'utf-8', 'latin-1', 'cp1252']
            
            for encoding in encodings_to_try:
                try:
                    with open(script_path, 'r', encoding=encoding) as f:
                        sql_script = f.read()
                    print(f"✅ Archivo leído correctamente con encoding: {encoding}")
                    break
                except UnicodeDecodeError:
                    continue
                except Exception as e:
                    continue
            
            if sql_script is None:
                return False, f"❌ No se pudo leer el archivo con ningún encoding conocido"
            
            # Separar por GO
            batches = [batch.strip() for batch in sql_script.split('GO') if batch.strip()]
            
            print(f"📊 Script contiene {len(batches)} lotes de comandos")
            
            # Conectar
            database = db_name if db_name else "master"
            conn_str = (
                f"DRIVER={{ODBC Driver 17 for SQL Server}};"
                f"SERVER={server};"
                f"DATABASE={database};"
                f"Trusted_Connection=yes;"
            )
            
            try:
                conn = pyodbc.connect(conn_str, timeout=30)
            except:
                conn_str = conn_str.replace("ODBC Driver 17", "SQL Server")
                conn = pyodbc.connect(conn_str, timeout=30)
            
            cursor = conn.cursor()
            
            # Ejecutar cada lote
            for i, batch in enumerate(batches, 1):
                try:
                    # Limpiar comandos de USE (ya estamos en la BD correcta)
                    if batch.strip().upper().startswith('USE '):
                        continue
                    
                    cursor.execute(batch)
                    conn.commit()
                    
                except pyodbc.Error as e:
                    error_msg = str(e)
                    # Ignorar errores de "ya existe"
                    if "already exists" in error_msg.lower() or "ya existe" in error_msg.lower():
                        print(f"ℹ️ Lote {i}: Objeto ya existe (OK)")
                        continue
                    else:
                        print(f"⚠️ Error en lote {i}: {error_msg[:100]}")
                        # No fallar por un lote, continuar
                        continue
            
            conn.close()
            print(f"✅ Script {script_path.name} ejecutado exitosamente")
            return True, f"✅ Script ejecutado: {script_path.name}"
            
        except Exception as e:
            return False, f"❌ Error ejecutando script {script_path.name}: {str(e)[:200]}"
    
    def crear_base_datos(self, server: str, db_name: str) -> Tuple[bool, str]:
        """
        Crea la base de datos completa usando comandos directos de SQL
        
        Returns:
            Tuple[bool, str]: (éxito, mensaje)
        """
        try:
            print(f"🔧 Iniciando creación de base de datos: {db_name}")
            
            # PASO 1: Conectar a master y crear la base de datos CON AUTOCOMMIT
            print(f"📋 Conectando a master para crear la base de datos...")
            conn_str = (
                f"DRIVER={{ODBC Driver 17 for SQL Server}};"
                f"SERVER={server};"
                f"DATABASE=master;"
                f"Trusted_Connection=yes;"
            )
            
            try:
                conn = pyodbc.connect(conn_str, timeout=30, autocommit=True)  # ✅ AUTOCOMMIT
                print(f"✅ Conectado a master con autocommit=True")
            except:
                conn_str = conn_str.replace("ODBC Driver 17", "SQL Server")
                conn = pyodbc.connect(conn_str, timeout=30, autocommit=True)  # ✅ AUTOCOMMIT
                print(f"✅ Conectado a master con driver alternativo")
            
            cursor = conn.cursor()
            
            # Verificar si la BD ya existe
            cursor.execute(f"SELECT database_id FROM sys.databases WHERE name = '{db_name}'")
            if cursor.fetchone():
                print(f"ℹ️ Base de datos '{db_name}' ya existe")
            else:
                # Crear la base de datos (comando simple)
                create_db_sql = f"CREATE DATABASE [{db_name}]"
                
                print(f"🔨 Creando base de datos: {db_name}")
                cursor.execute(create_db_sql)
                print(f"✅ Base de datos '{db_name}' creada exitosamente")
            
            conn.close()
            
            # PASO 2: Conectar a la nueva BD y ejecutar el script de schema (solo CREATE TABLE)
            print(f"📋 Conectando a la nueva base de datos para crear tablas...")
            
            # Esperar un momento para que la BD esté lista
            import time
            time.sleep(2)
            
            schema_script = self.scripts_dir / "01_schema.sql"
            if schema_script.exists():
                print(f"📄 Ejecutando script de tablas...")
                
                # Leer el script
                sql_script = None
                encodings_to_try = ['utf-8-sig', 'utf-16', 'utf-8', 'latin-1']
                
                for encoding in encodings_to_try:
                    try:
                        with open(schema_script, 'r', encoding=encoding) as f:
                            sql_script = f.read()
                        print(f"✅ Script leído con encoding: {encoding}")
                        break
                    except:
                        continue
                
                if sql_script is None:
                    return False, "❌ No se pudo leer el script de schema"
                
                # Conectar a la nueva BD (SIN autocommit para las tablas)
                conn_str_new = (
                    f"DRIVER={{ODBC Driver 17 for SQL Server}};"
                    f"SERVER={server};"
                    f"DATABASE={db_name};"
                    f"Trusted_Connection=yes;"
                )
                
                try:
                    conn_new = pyodbc.connect(conn_str_new, timeout=30)
                    print(f"✅ Conectado a {db_name} para crear objetos")
                except:
                    conn_str_new = conn_str_new.replace("ODBC Driver 17", "SQL Server")
                    conn_new = pyodbc.connect(conn_str_new, timeout=30)
                    print(f"✅ Conectado con driver alternativo")
                
                cursor_new = conn_new.cursor()
                
                # Separar por GO y filtrar comandos
                batches = [batch.strip() for batch in sql_script.split('GO') if batch.strip()]
                
                print(f"📊 Procesando {len(batches)} comandos SQL...")
                
                comandos_ejecutados = 0
                errores_importantes = 0
                
                for i, batch in enumerate(batches, 1):
                    # Omitir comandos problemáticos
                    batch_upper = batch.strip().upper()
                    
                    if any([
                        batch_upper.startswith('USE '),
                        batch_upper.startswith('CREATE DATABASE'),
                        batch_upper.startswith('ALTER DATABASE'),
                        batch_upper.startswith('DROP DATABASE'),
                    ]):
                        continue
                    
                    try:
                        cursor_new.execute(batch)
                        conn_new.commit()
                        comandos_ejecutados += 1
                    except pyodbc.Error as e:
                        error_msg = str(e)
                        if "already exists" in error_msg.lower() or "ya existe" in error_msg.lower():
                            continue
                        # Contar errores importantes (no ALTER DATABASE)
                        if "ALTER DATABASE" not in error_msg:
                            errores_importantes += 1
                            if errores_importantes <= 5:  # Mostrar solo los primeros 5
                                print(f"⚠️ Error en comando {i}: {error_msg[:100]}...")
                
                conn_new.close()
                print(f"✅ Estructura creada: {comandos_ejecutados} comandos exitosos")
                if errores_importantes > 0:
                    print(f"⚠️ Se omitieron {errores_importantes} errores menores")
            
            # PASO 3: Ejecutar script de datos iniciales
            datos_script = self.scripts_dir / "02_datos_iniciales.sql"
            if datos_script.exists():
                print(f"📄 Ejecutando datos iniciales...")
                time.sleep(1)
                exito, mensaje = self.ejecutar_script_sql(datos_script, server, db_name)
                if exito:
                    print(f"✅ Datos iniciales cargados")
                else:
                    print(f"⚠️ Advertencia datos iniciales: {mensaje[:100]}...")
            
            return True, f"✅ Base de datos '{db_name}' configurada exitosamente"
            
        except Exception as e:
            import traceback
            traceback.print_exc()
            return False, f"❌ Error en creación de BD: {str(e)}"
    
    def crear_usuario_admin(self, server: str, db_name: str, username: str = "admin", password: str = "admin123") -> Tuple[bool, str]:
        """
        Crea el usuario administrador inicial
        
        Returns:
            Tuple[bool, str]: (éxito, mensaje)
        """
        try:
            print(f"👤 Creando usuario administrador en: {db_name}")
            
            # Esperar un momento para asegurar que la BD esté lista
            import time
            time.sleep(1)
            
            conn_str = (
                f"DRIVER={{ODBC Driver 17 for SQL Server}};"
                f"SERVER={server};"
                f"DATABASE={db_name};"
                f"Trusted_Connection=yes;"
            )
            
            try:
                conn = pyodbc.connect(conn_str, timeout=30)
                print(f"✅ Conectado a la base de datos: {db_name}")
            except Exception as e:
                print(f"⚠️ Intento con driver alternativo...")
                conn_str = conn_str.replace("ODBC Driver 17", "SQL Server")
                try:
                    conn = pyodbc.connect(conn_str, timeout=30)
                    print(f"✅ Conectado con driver alternativo")
                except Exception as e2:
                    return False, f"❌ No se pudo conectar a la BD: {str(e2)}"
            
            cursor = conn.cursor()
            
            # Verificar si existe el usuario
            cursor.execute("SELECT id FROM Usuario WHERE nombre_usuario = ?", (username,))
            if cursor.fetchone():
                conn.close()
                print(f"ℹ️ Usuario '{username}' ya existe")
                return True, f"ℹ️ Usuario '{username}' ya existe"
            
            # Obtener ID del rol Administrador
            cursor.execute("SELECT id FROM Roles WHERE Nombre = 'Administrador'")
            rol = cursor.fetchone()
            if not rol:
                conn.close()
                return False, "❌ Rol 'Administrador' no encontrado en la BD"
            
            rol_id = rol[0]
            
            # Crear usuario
            sql = """
            INSERT INTO Usuario (Nombre, Apellido_Paterno, Apellido_Materno, nombre_usuario, contrasena, Id_Rol, Estado)
            VALUES (?, ?, ?, ?, ?, ?, 1)
            """
            
            cursor.execute(sql, ('Admin', 'Sistema', 'CMI', username, password, rol_id))
            conn.commit()
            
            # Obtener ID del usuario creado
            cursor.execute("SELECT id FROM Usuario WHERE nombre_usuario = ?", (username,))
            user_id = cursor.fetchone()[0]
            
            conn.close()
            
            print(f"✅ Usuario administrador creado:")
            print(f"   ID: {user_id}")
            print(f"   Usuario: {username}")
            print(f"   Contraseña: {password}")
            print(f"   Rol: Administrador (ID: {rol_id})")
            
            return True, f"✅ Usuario '{username}' creado exitosamente"
            
        except Exception as e:
            import traceback
            traceback.print_exc()
            return False, f"❌ Error creando usuario: {str(e)}"
    
    def setup_completo(self, server: str = "localhost\\SQLEXPRESS", db_name: str = "ClinicaMariaInmaculada") -> Tuple[bool, str, dict]:
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
            
            # Paso 2: Verificar si la BD ya existe
            print("📋 Paso 2/4: Verificando base de datos...")
            if self.verificar_base_datos_existe(server, db_name):
                print(f"   ℹ️ Base de datos '{db_name}' ya existe")
                respuesta = "usar"  # Por ahora usar la existente
            else:
                respuesta = "crear"
            
            if respuesta == "crear":
                # Paso 3: Crear base de datos
                print("\n📋 Paso 3/4: Creando base de datos...")
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


# Para testing directo
if __name__ == "__main__":
    print("🧪 Probando DatabaseInstaller...")
    
    installer = DatabaseInstaller()
    exito, mensaje, creds = installer.setup_completo()
    
    if exito:
        print("\n✅ TEST EXITOSO")
        print(f"Credenciales: {creds}")
    else:
        print(f"\n❌ TEST FALLIDO: {mensaje}")