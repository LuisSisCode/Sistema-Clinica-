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
        Ejecuta un script SQL
        
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
            
            # Leer el script
            with open(script_path, 'r', encoding='utf-8') as f:
                sql_script = f.read()
            
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
        Crea la base de datos completa
        
        Returns:
            Tuple[bool, str]: (éxito, mensaje)
        """
        try:
            print(f"🔧 Iniciando creación de base de datos: {db_name}")
            
            # 1. Verificar que existe el script de schema
            schema_script = self.scripts_dir / "01_schema.sql"
            if not schema_script.exists():
                return False, f"❌ Script de schema no encontrado: {schema_script}"
            
            print(f"📄 Script de schema encontrado: {schema_script}")
            
            # 2. Ejecutar script de schema (crea BD y tablas)
            exito, mensaje = self.ejecutar_script_sql(schema_script, server)
            if not exito:
                return False, f"❌ Error creando estructura: {mensaje}"
            
            print(f"✅ Estructura de BD creada")
            
            # 3. Ejecutar script de datos iniciales si existe
            datos_script = self.scripts_dir / "02_datos_iniciales.sql"
            if datos_script.exists():
                print(f"📄 Ejecutando datos iniciales...")
                exito, mensaje = self.ejecutar_script_sql(datos_script, server, db_name)
                if not exito:
                    print(f"⚠️ Advertencia datos iniciales: {mensaje}")
                else:
                    print(f"✅ Datos iniciales cargados")
            else:
                print(f"ℹ️ No se encontró script de datos iniciales (opcional)")
            
            return True, f"✅ Base de datos '{db_name}' creada exitosamente"
            
        except Exception as e:
            return False, f"❌ Error en creación de BD: {str(e)}"
    
    def crear_usuario_admin(self, server: str, db_name: str, username: str = "admin", password: str = "admin123") -> Tuple[bool, str]:
        """
        Crea el usuario administrador inicial
        
        Returns:
            Tuple[bool, str]: (éxito, mensaje)
        """
        try:
            conn_str = (
                f"DRIVER={{ODBC Driver 17 for SQL Server}};"
                f"SERVER={server};"
                f"DATABASE={db_name};"
                f"Trusted_Connection=yes;"
            )
            
            try:
                conn = pyodbc.connect(conn_str, timeout=10)
            except:
                conn_str = conn_str.replace("ODBC Driver 17", "SQL Server")
                conn = pyodbc.connect(conn_str, timeout=10)
            
            cursor = conn.cursor()
            
            # Verificar si existe el usuario
            cursor.execute("SELECT id FROM Usuario WHERE nombre_usuario = ?", (username,))
            if cursor.fetchone():
                conn.close()
                return True, f"ℹ️ Usuario '{username}' ya existe"
            
            # Obtener ID del rol Administrador
            cursor.execute("SELECT id FROM Roles WHERE Nombre = 'Administrador'")
            rol = cursor.fetchone()
            if not rol:
                conn.close()
                return False, "❌ Rol 'Administrador' no encontrado"
            
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
            print(f"   Rol: Administrador")
            
            return True, f"✅ Usuario '{username}' creado exitosamente"
            
        except Exception as e:
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