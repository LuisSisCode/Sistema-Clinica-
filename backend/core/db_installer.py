# backend/core/db_installer.py
"""
Sistema de Instalación de Base de Datos
✅ CORREGIDO: Bug crítico en creación de usuario admin
✅ MEJORADO: Ejecuta 3 scripts, mejor logging, rollback, validación
"""

import os
import pyodbc
from pathlib import Path
from typing import Tuple, Optional, Dict, Callable
import sys
import time
import re
import logging

# Configurar logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger('db_installer')

class DatabaseInstaller:
    """Instalador automatizado de base de datos con validación y rollback"""
    
    # ✅ Lista de drivers ODBC en orden de preferencia
    ODBC_DRIVERS = [
        "ODBC Driver 18 for SQL Server",
        "ODBC Driver 17 for SQL Server",
        "ODBC Driver 13 for SQL Server",
        "SQL Server Native Client 11.0",
        "SQL Server"
    ]
    
    # ✅ NUEVO: Scripts requeridos en orden de ejecución
    REQUIRED_SCRIPTS = [
        "01_schema.sql",
        "02_datos_iniciales.sql",
        "03_indices_optimizacion.sql"
    ]
    
    def __init__(self, progress_callback: Optional[Callable[[str, int], None]] = None):
        """
        Inicializar instalador con rutas correctas y detección de driver
        
        Args:
            progress_callback: Función opcional para reportar progreso (mensaje, porcentaje)
        """
        self.progress_callback = progress_callback
        
        # Detectar driver ODBC disponible
        self.driver = self._detectar_driver_odbc()
        
        if not self.driver:
            logger.warning("No se detectó driver ODBC para SQL Server")
            logger.warning("Instala 'ODBC Driver 17 for SQL Server' o superior")
        else:
            logger.info(f"Driver ODBC detectado: {self.driver}")
        
        # Configurar directorio de scripts
        self.scripts_dir = self._detectar_directorio_scripts()
        
        logger.info(f"Directorio de scripts SQL: {self.scripts_dir}")
        logger.info(f"¿Existe? {self.scripts_dir.exists()}")
        
        # ✅ NUEVO: Validar scripts requeridos
        self._validar_scripts_requeridos()
    
    def _report_progress(self, message: str, percent: int = 0):
        """Reporta progreso vía callback y logging"""
        logger.info(f"[{percent}%] {message}")
        if self.progress_callback:
            try:
                self.progress_callback(message, percent)
            except Exception as e:
                logger.error(f"Error en callback de progreso: {e}")
    
    def _detectar_directorio_scripts(self) -> Path:
        """Detecta el directorio donde están los scripts SQL"""
        if getattr(sys, 'frozen', False):
            # ✅ EJECUTABLE: Scripts en RAÍZ de _MEIPASS
            base_path = sys._MEIPASS
            
            possible_paths = [
                Path(base_path) / 'database_scripts',
                Path(base_path) / '_internal' / 'database_scripts',
            ]
            
            for path in possible_paths:
                if path.exists():
                    logger.info(f"Scripts SQL encontrados en: {path}")
                    return path
            
            # Si no se encuentra, usar la primera opción por defecto
            logger.warning(f"Scripts SQL NO encontrados, usando ruta por defecto")
            return possible_paths[0]
        else:
            # ✅ DESARROLLO
            scripts_dir = Path(__file__).parent.parent.parent / 'database_scripts'
            logger.info(f"MODO DESARROLLO - Scripts en: {scripts_dir}")
            return scripts_dir
    
    def _leer_script_sql(self, script_path: Path) -> Optional[str]:
        """
        ✅ NUEVO: Lee un archivo SQL con detección automática de codificación
        
        Args:
            script_path: Ruta al archivo SQL
            
        Returns:
            str: Contenido del archivo, o None si falla
        """
        # Lista de codificaciones a probar en orden
        encodings = [
            'utf-8',
            'utf-8-sig',      # UTF-8 con BOM
            'utf-16',         # UTF-16 (detecta LE/BE automáticamente)
            'utf-16-le',      # UTF-16 Little Endian
            'utf-16-be',      # UTF-16 Big Endian
            'latin-1',        # ISO-8859-1
            'cp1252',         # Windows-1252
        ]
        
        for encoding in encodings:
            try:
                logger.debug(f"Intentando leer {script_path.name} con codificación: {encoding}")
                with open(script_path, 'r', encoding=encoding) as f:
                    content = f.read()
                    logger.info(f"✅ Script leído exitosamente con codificación: {encoding}")
                    return content
            except (UnicodeDecodeError, UnicodeError):
                continue
            except Exception as e:
                logger.error(f"Error leyendo archivo con {encoding}: {e}")
                continue
        
        logger.error(f"❌ No se pudo leer {script_path.name} con ninguna codificación")
        return None
    
    def _validar_scripts_requeridos(self) -> bool:
        """
        ✅ NUEVO: Valida que todos los scripts requeridos existan
        
        Returns:
            bool: True si todos existen
        """
        if not self.scripts_dir.exists():
            logger.error(f"Directorio de scripts no existe: {self.scripts_dir}")
            return False
        
        scripts_faltantes = []
        
        for script_name in self.REQUIRED_SCRIPTS:
            script_path = self.scripts_dir / script_name
            if script_path.exists():
                logger.info(f"  ✅ {script_name} - OK")
            else:
                logger.error(f"  ❌ {script_name} - NO ENCONTRADO")
                scripts_faltantes.append(script_name)
        
        if scripts_faltantes:
            logger.error(f"Scripts faltantes: {', '.join(scripts_faltantes)}")
            return False
        
        return True
    
    def _detectar_driver_odbc(self) -> Optional[str]:
        """
        Detecta automáticamente el driver ODBC disponible
        
        Returns:
            str: Nombre del driver encontrado, o None
        """
        try:
            drivers_disponibles = list(pyodbc.drivers())
            logger.debug(f"Drivers ODBC disponibles: {drivers_disponibles}")
            
            for driver in self.ODBC_DRIVERS:
                if driver in drivers_disponibles:
                    return driver
            
            return None
            
        except Exception as e:
            logger.error(f"Error detectando drivers: {e}")
            return None
    
    def _build_connection_string(self, server: str, database: str = "master", timeout: int = 30) -> str:
        """
        Construye cadena de conexión con el driver detectado
        
        Args:
            server: Servidor SQL Server
            database: Base de datos
            timeout: Timeout en segundos
            
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
            f"Timeout={timeout}"
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
            
            self._report_progress("Conectando a SQL Server...", 5)
            
            conn_str = self._build_connection_string(server, "master", timeout=10)
            
            conn = pyodbc.connect(conn_str, timeout=5)
            cursor = conn.cursor()
            cursor.execute("SELECT @@VERSION")
            version = cursor.fetchone()[0]
            conn.close()
            
            # Extraer versión corta
            version_short = version.split('\n')[0][:80]
            logger.info(f"SQL Server conectado: {version_short}")
            
            return True, f"✅ SQL Server detectado: {server}"
            
        except pyodbc.Error as e:
            error_msg = str(e)
            
            if "Login timeout expired" in error_msg:
                return False, "❌ SQL Server no responde. Verifica que el servicio esté iniciado."
            elif "Data source name not found" in error_msg or "IM002" in error_msg:
                return False, "❌ Driver ODBC no encontrado. Instala 'ODBC Driver 17 for SQL Server'."
            else:
                return False, f"❌ Error conectando: {error_msg[:200]}"
        
        except Exception as e:
            return False, f"❌ Error inesperado: {str(e)}"
    
    def verificar_base_datos_existe(self, server: str, db_name: str) -> Tuple[bool, str]:
        """
        Verifica si la base de datos existe y está completa
        
        Args:
            server: Servidor SQL
            db_name: Nombre de la base de datos
        
        Returns:
            Tuple[bool, str]: (existe_y_completa, mensaje)
        """
        try:
            logger.info(f"Verificando BD: {db_name} en servidor: {server}")
            
            if not self.driver:
                return False, "❌ No hay driver ODBC disponible"
            
            # Conectar a master
            conn_str = self._build_connection_string(server, "master", timeout=10)
            conn = pyodbc.connect(conn_str, timeout=5)
            
            # Verificar si existe
            cursor = conn.cursor()
            cursor.execute("SELECT database_id FROM sys.databases WHERE name = ?", (db_name,))
            existe = cursor.fetchone() is not None
            
            if not existe:
                cursor.close()
                conn.close()
                return False, f"❌ Base de datos '{db_name}' no existe"
            
            cursor.close()
            conn.close()
            
            # Verificar que tenga tablas
            conn_str_db = self._build_connection_string(server, db_name, timeout=10)
            
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
                
                # ✅ Esperamos al menos 20 tablas (según esquema)
                if num_tablas < 20:
                    return False, f"⚠️ BD '{db_name}' está incompleta ({num_tablas} tablas, se esperan 20+)"
                
                logger.info(f"BD '{db_name}' existe y parece completa ({num_tablas} tablas)")
                return True, f"✅ Base de datos '{db_name}' existe ({num_tablas} tablas)"
                
            except pyodbc.Error as e:
                return False, f"❌ No se puede acceder a '{db_name}': {str(e)[:100]}"
                
        except Exception as e:
            logger.error(f"Error verificando BD: {e}")
            return False, f"❌ Error verificando BD: {str(e)}"
    
    def ejecutar_script_sql(self, script_path: Path, server: str, db_name: str) -> Tuple[bool, str]:
        """
        ✅ MEJORADO: Ejecuta un script SQL con mejor manejo de batches
        
        Args:
            script_path: Ruta al script SQL
            server: Servidor SQL
            db_name: Base de datos
            
        Returns:
            Tuple[bool, str]: (éxito, mensaje)
        """
        try:
            if not script_path.exists():
                return False, f"❌ Script no encontrado: {script_path}"
            
            logger.info(f"Ejecutando script: {script_path.name}")
            
            # ✅ CORREGIDO: Leer contenido con detección automática de codificación
            sql_content = self._leer_script_sql(script_path)
            if sql_content is None:
                return False, f"❌ No se pudo leer el script (problema de codificación)"
            
            # ✅ MEJORADO: Parser de batches más robusto
            batches = self._split_sql_batches(sql_content)
            
            # ✅ FILTRAR comandos de gestión de BD (CREATE/ALTER DATABASE)
            # Estos no deben ejecutarse cuando la BD ya existe
            batches = self._filtrar_comandos_database(batches, script_path.name)
            
            logger.info(f"Script dividido en {len(batches)} batches")
            
            # Conectar y ejecutar
            conn_str = self._build_connection_string(server, db_name, timeout=120)
            conn = pyodbc.connect(conn_str, timeout=120)
            conn.autocommit = True  # ✅ Cambio a autocommit para evitar errores de transacción
            cursor = conn.cursor()
            
            ejecutados = 0
            errores = 0
            
            for i, batch in enumerate(batches, 1):
                batch = batch.strip()
                
                if not batch or batch.startswith('--'):
                    continue
                
                try:
                    # ✅ NUEVO: Feedback de progreso cada 10 batches
                    if i % 10 == 0:
                        logger.debug(f"Ejecutando batch {i}/{len(batches)}")
                    
                    cursor.execute(batch)
                    ejecutados += 1
                    
                except pyodbc.Error as e:
                    error_msg = str(e)
                    
                    # Ignorar ciertos errores esperados
                    if "already exists" in error_msg.lower():
                        logger.debug(f"Batch {i}: Objeto ya existe (ignorado)")
                        continue
                    
                    logger.error(f"Error en batch {i}: {error_msg[:200]}")
                    errores += 1
                    
                    # Si hay muchos errores, abortar
                    if errores > 10:  # ✅ Aumentado de 5 a 10
                        cursor.close()
                        conn.close()
                        return False, f"❌ Demasiados errores ({errores}), abortando"
            
            # No hay commit porque autocommit=True
            cursor.close()
            conn.close()
            
            logger.info(f"Script ejecutado: {ejecutados} comandos, {errores} errores menores")
            
            if errores > 0:
                return True, f"⚠️ Script ejecutado con {errores} advertencias"
            else:
                return True, f"✅ Script ejecutado exitosamente"
            
        except Exception as e:
            logger.error(f"Error ejecutando script: {e}")
            return False, f"❌ Error ejecutando script: {str(e)}"
    
    def _split_sql_batches(self, sql_content: str) -> list:
        """
        ✅ MEJORADO: Divide script SQL en batches usando GO como separador
        Maneja comentarios y strings correctamente
        
        Args:
            sql_content: Contenido del script SQL
            
        Returns:
            list: Lista de batches SQL
        """
        # Remover comentarios de línea (--) pero no dentro de strings
        lines = sql_content.split('\n')
        cleaned_lines = []
        
        in_string = False
        string_char = None
        
        for line in lines:
            cleaned_line = []
            i = 0
            
            while i < len(line):
                char = line[i]
                
                # Detectar inicio/fin de string
                if char in ("'", '"') and (i == 0 or line[i-1] != '\\'):
                    if not in_string:
                        in_string = True
                        string_char = char
                    elif char == string_char:
                        in_string = False
                        string_char = None
                    cleaned_line.append(char)
                
                # Detectar comentario
                elif not in_string and char == '-' and i+1 < len(line) and line[i+1] == '-':
                    # Ignorar resto de la línea
                    break
                
                else:
                    cleaned_line.append(char)
                
                i += 1
            
            cleaned_lines.append(''.join(cleaned_line))
        
        cleaned_content = '\n'.join(cleaned_lines)
        
        # Dividir por GO (case insensitive, solo línea completa)
        batches = re.split(r'^\s*GO\s*$', cleaned_content, flags=re.MULTILINE | re.IGNORECASE)
        
        # Limpiar batches vacíos
        batches = [b.strip() for b in batches if b.strip()]
        
        return batches
    
    def _filtrar_comandos_database(self, batches: list, script_name: str) -> list:
        """
        ✅ NUEVO: Filtra comandos CREATE DATABASE y ALTER DATABASE
        Estos comandos no deben ejecutarse cuando la BD ya está creada
        
        Args:
            batches: Lista de batches SQL
            script_name: Nombre del script (para logging)
            
        Returns:
            list: Batches filtrados
        """
        filtered_batches = []
        comandos_filtrados = 0
        
        # Patrones a filtrar
        patrones_filtrar = [
            r'^\s*CREATE\s+DATABASE\s+',
            r'^\s*ALTER\s+DATABASE\s+',
            r'^\s*USE\s+\[?master\]?\s*$',
        ]
        
        for batch in batches:
            batch_upper = batch.upper().strip()
            
            # Verificar si debe filtrarse
            debe_filtrar = False
            for patron in patrones_filtrar:
                if re.search(patron, batch, re.IGNORECASE | re.MULTILINE):
                    debe_filtrar = True
                    break
            
            if debe_filtrar:
                logger.debug(f"Filtrando comando de gestión de BD: {batch[:50]}...")
                comandos_filtrados += 1
            else:
                filtered_batches.append(batch)
        
        if comandos_filtrados > 0:
            logger.info(f"✂️ Filtrados {comandos_filtrados} comandos de gestión de BD")
        
        return filtered_batches
    
    def crear_base_datos(self, server: str, db_name: str) -> Tuple[bool, str]:
        """
        ✅ MEJORADO: Crea la BD y ejecuta los 3 scripts
        
        Args:
            server: Servidor SQL
            db_name: Nombre de la base de datos
            
        Returns:
            Tuple[bool, str]: (éxito, mensaje)
        """
        try:
            logger.info(f"Creando base de datos: {db_name}")
            self._report_progress(f"Creando base de datos {db_name}...", 10)
            
            # Verificar que no exista
            existe, _ = self.verificar_base_datos_existe(server, db_name)
            if existe:
                return True, f"ℹ️ Base de datos '{db_name}' ya existe y está completa"
            
            # Conectar a master
            conn_str = self._build_connection_string(server, "master", timeout=30)
            conn = pyodbc.connect(conn_str, autocommit=True)
            cursor = conn.cursor()
            
            # Crear BD
            logger.info("Creando estructura de base de datos...")
            cursor.execute(f"CREATE DATABASE [{db_name}]")
            
            cursor.close()
            conn.close()
            
            # Esperar a que SQL Server finalice la creación
            time.sleep(2)
            
            # ✅ SCRIPT 1: Esquema (tablas, vistas, procedimientos)
            self._report_progress("Creando tablas y procedimientos...", 20)
            schema_script = self.scripts_dir / "01_schema.sql"
            
            if not schema_script.exists():
                return False, f"❌ No se encontró: {schema_script.name}"
            
            logger.info(f"Ejecutando {schema_script.name}...")
            exito, mensaje = self.ejecutar_script_sql(schema_script, server, db_name)
            
            if not exito:
                # ✅ Intentar eliminar BD fallida
                self._eliminar_base_datos(server, db_name)
                return False, f"❌ Error en esquema: {mensaje}"
            
            logger.info("✅ Esquema creado exitosamente")
            
            # ✅ SCRIPT 2: Datos iniciales
            self._report_progress("Cargando datos iniciales...", 50)
            datos_script = self.scripts_dir / "02_datos_iniciales.sql"
            
            if datos_script.exists():
                logger.info(f"Ejecutando {datos_script.name}...")
                time.sleep(1)
                exito, mensaje = self.ejecutar_script_sql(datos_script, server, db_name)
                
                if not exito:
                    logger.warning(f"Advertencia en datos iniciales: {mensaje}")
                    # No abortamos por errores en datos iniciales
                else:
                    logger.info("✅ Datos iniciales cargados")
            else:
                logger.warning(f"⚠️ No se encontró {datos_script.name}")
            
            # ✅ SCRIPT 3: Índices de optimización (NUEVO)
            self._report_progress("Creando índices de optimización...", 70)
            indices_script = self.scripts_dir / "03_indices_optimizacion.sql"
            
            if indices_script.exists():
                logger.info(f"Ejecutando {indices_script.name}...")
                time.sleep(1)
                exito, mensaje = self.ejecutar_script_sql(indices_script, server, db_name)
                
                if not exito:
                    logger.warning(f"Advertencia en índices: {mensaje}")
                    # No abortamos por errores en índices
                else:
                    logger.info("✅ Índices de optimización creados")
            else:
                logger.warning(f"⚠️ No se encontró {indices_script.name}")
            
            # ✅ NUEVO: Validar instalación
            self._report_progress("Validando instalación...", 80)
            valido, mensaje_validacion = self._validar_instalacion(server, db_name)
            
            if not valido:
                logger.warning(f"Validación: {mensaje_validacion}")
            
            return True, f"✅ Base de datos '{db_name}' creada exitosamente"
            
        except Exception as e:
            logger.error(f"Error creando BD: {e}")
            import traceback
            traceback.print_exc()
            
            # Intentar limpiar
            try:
                self._eliminar_base_datos(server, db_name)
            except:
                pass
            
            return False, f"❌ Error creando BD: {str(e)}"
    
    def _eliminar_base_datos(self, server: str, db_name: str):
        """
        ✅ NUEVO: Elimina una base de datos (rollback)
        """
        try:
            logger.warning(f"Intentando eliminar BD fallida: {db_name}")
            
            conn_str = self._build_connection_string(server, "master", timeout=10)
            conn = pyodbc.connect(conn_str, autocommit=True)
            cursor = conn.cursor()
            
            # Forzar cierre de conexiones
            cursor.execute(f"""
                ALTER DATABASE [{db_name}] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
                DROP DATABASE [{db_name}];
            """)
            
            cursor.close()
            conn.close()
            
            logger.info(f"BD '{db_name}' eliminada")
            
        except Exception as e:
            logger.error(f"No se pudo eliminar BD: {e}")
    
    def _validar_instalacion(self, server: str, db_name: str) -> Tuple[bool, str]:
        """
        ✅ NUEVO: Valida que la instalación esté completa
        
        Returns:
            Tuple[bool, str]: (válido, mensaje)
        """
        try:
            conn_str = self._build_connection_string(server, db_name, timeout=10)
            conn = pyodbc.connect(conn_str, timeout=5)
            cursor = conn.cursor()
            
            # Contar tablas
            cursor.execute("""
                SELECT COUNT(*) 
                FROM INFORMATION_SCHEMA.TABLES 
                WHERE TABLE_TYPE = 'BASE TABLE'
            """)
            num_tablas = cursor.fetchone()[0]
            
            # Contar procedimientos almacenados
            cursor.execute("""
                SELECT COUNT(*) 
                FROM INFORMATION_SCHEMA.ROUTINES 
                WHERE ROUTINE_TYPE = 'PROCEDURE'
            """)
            num_procedures = cursor.fetchone()[0]
            
            # Contar vistas
            cursor.execute("""
                SELECT COUNT(*) 
                FROM INFORMATION_SCHEMA.VIEWS
            """)
            num_views = cursor.fetchone()[0]
            
            cursor.close()
            conn.close()
            
            logger.info(f"Validación: {num_tablas} tablas, {num_procedures} SP, {num_views} vistas")
            
            # Validación básica
            if num_tablas < 20:
                return False, f"⚠️ Faltan tablas (encontradas: {num_tablas}, esperadas: 20+)"
            
            if num_procedures < 5:
                return False, f"⚠️ Faltan procedimientos (encontrados: {num_procedures})"
            
            return True, f"✅ Instalación válida: {num_tablas} tablas, {num_procedures} SP"
            
        except Exception as e:
            return False, f"⚠️ Error validando: {str(e)}"
    
    def crear_usuario_admin(self, server: str, db_name: str, 
                           username: str = "admin", 
                           password: str = "admin123") -> Tuple[bool, str]:
        """
        ✅ CORREGIDO: Crea el usuario administrador inicial (bug crítico arreglado)
        
        Args:
            server: Servidor SQL
            db_name: Base de datos
            username: Nombre de usuario
            password: Contraseña
            
        Returns:
            Tuple[bool, str]: (éxito, mensaje)
        """
        try:
            logger.info(f"Creando usuario administrador: {username}")
            
            time.sleep(1)
            
            conn_str = self._build_connection_string(server, db_name, timeout=30)
            conn = pyodbc.connect(conn_str, timeout=30)
            cursor = conn.cursor()
            
            # Verificar si existe
            cursor.execute("SELECT id FROM Usuario WHERE nombre_usuario = ?", (username,))
            if cursor.fetchone():
                conn.close()
                logger.info(f"Usuario '{username}' ya existe")
                return True, f"ℹ️ Usuario '{username}' ya existe"
            
            # Obtener ID del rol Administrador
            cursor.execute("SELECT id FROM Roles WHERE Nombre = 'Administrador'")
            rol = cursor.fetchone()
            
            if not rol:
                conn.close()
                return False, "❌ Rol 'Administrador' no encontrado"
            
            rol_id = rol[0]
            
            # ✅ CORREGIDO: Sintaxis SQL correcta
            sql = """
            INSERT INTO Usuario 
            (Nombre, Apellido_Paterno, Apellido_Materno, nombre_usuario, contrasena, Id_Rol, Estado)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            """
            
            cursor.execute(sql, (
                'Administrador',
                'Sistema',
                'General',
                username,
                password,
                rol_id,
                1  # Estado = activo
            ))
            conn.commit()
            
            # Verificar que se creó
            cursor.execute("SELECT id FROM Usuario WHERE nombre_usuario = ?", (username,))
            user_id = cursor.fetchone()[0]
            
            conn.close()
            
            logger.info(f"Usuario administrador creado (ID: {user_id})")
            
            return True, f"✅ Usuario '{username}' creado exitosamente"
            
        except Exception as e:
            logger.error(f"Error creando usuario: {e}")
            import traceback
            traceback.print_exc()
            return False, f"❌ Error creando usuario: {str(e)}"
    
    def setup_completo(self, 
                       server: str = "localhost\\SQLEXPRESS", 
                       db_name: str = "ClinicaMariaInmaculada") -> Tuple[bool, str, Dict]:
        """
        ✅ MEJORADO: Ejecuta el setup completo con validación y mejor feedback
        
        Returns:
            Tuple[bool, str, dict]: (éxito, mensaje, credenciales)
        """
        credenciales = {}
        
        try:
            logger.info("="*60)
            logger.info("INICIANDO SETUP AUTOMÁTICO")
            logger.info("="*60)
            
            self._report_progress("Iniciando setup...", 0)
            
            # Paso 1: Verificar SQL Server
            self._report_progress("Verificando SQL Server...", 5)
            logger.info("Paso 1/5: Verificando SQL Server...")
            exito, mensaje = self.verificar_sql_server(server)
            if not exito:
                return False, mensaje, credenciales
            logger.info(f"   {mensaje}")
            
            # Paso 2: Validar scripts
            self._report_progress("Validando scripts de instalación...", 8)
            logger.info("Paso 2/5: Validando scripts...")
            if not self._validar_scripts_requeridos():
                return False, "❌ Faltan scripts SQL requeridos", credenciales
            logger.info("   ✅ Todos los scripts encontrados")
            
            # Paso 3: Verificar BD
            self._report_progress("Verificando base de datos...", 10)
            logger.info("Paso 3/5: Verificando base de datos...")
            existe, mensaje = self.verificar_base_datos_existe(server, db_name)
            logger.info(f"   {mensaje}")
            
            if not existe:
                # Paso 4: Crear BD
                logger.info("Paso 4/5: Creando base de datos...")
                exito, mensaje = self.crear_base_datos(server, db_name)
                if not exito:
                    return False, mensaje, credenciales
                logger.info(f"   {mensaje}")
            else:
                logger.info("   ✅ Usando base de datos existente")
                self._report_progress("Base de datos existente encontrada", 80)
            
            # Paso 5: Crear usuario admin
            self._report_progress("Creando usuario administrador...", 85)
            logger.info("Paso 5/5: Creando usuario administrador...")
            username = "admin"
            password = "admin123"
            exito, mensaje = self.crear_usuario_admin(server, db_name, username, password)
            if not exito:
                # No es crítico si el usuario ya existe
                if "ya existe" not in mensaje:
                    return False, mensaje, credenciales
            logger.info(f"   {mensaje}")
            
            credenciales = {
                "username": username,
                "password": password,
                "server": server,
                "database": db_name
            }
            
            self._report_progress("Setup completado exitosamente", 100)
            
            logger.info("="*60)
            logger.info("✅ ¡SETUP COMPLETADO EXITOSAMENTE!")
            logger.info("="*60)
            logger.info(f"\n📝 Credenciales de acceso:")
            logger.info(f"   Usuario: {username}")
            logger.info(f"   Contraseña: {password}")
            logger.info(f"\n⚠️  IMPORTANTE: Cambia tu contraseña después del primer inicio de sesión\n")
            
            return True, "✅ Setup completado exitosamente", credenciales
            
        except Exception as e:
            logger.error(f"Error en setup: {e}")
            import traceback
            traceback.print_exc()
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