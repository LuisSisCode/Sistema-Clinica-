"""
Repositorio para manejo de datos de enfermería
Maneja las operaciones CRUD para procedimientos de enfermería
"""

import logging
from typing import List, Dict, Optional, Any
from datetime import datetime, date
from decimal import Decimal

# Configurar logging
logger = logging.getLogger(__name__)

class EnfermeriaRepository:
    def __init__(self, db_connection):
        """
        Inicializa el repositorio con una conexión a la base de datos
        
        Args:
            db_connection: Instancia de DatabaseConnection
        """
        self.db = db_connection
    
    # ===============================
    # OPERACIONES DE TIPOS DE PROCEDIMIENTOS
    # ===============================
    
    def obtener_tipos_procedimientos(self) -> List[Dict[str, Any]]:
        """
        Obtiene todos los tipos de procedimientos disponibles
        
        Returns:
            List[Dict]: Lista de tipos de procedimientos
        """
        try:
            with self.db.get_connection() as conn:
                cursor = conn.cursor()
                cursor.execute("""
                    SELECT 
                        id,
                        Nombre,
                        Descripcion,
                        Precio_Normal,
                        Precio_Emergencia
                    FROM Tipos_Procedimientos
                    ORDER BY Nombre
                """)
                
                tipos = []
                for row in cursor.fetchall():
                    tipos.append({
                        'id': row.id,
                        'nombre': row.Nombre,
                        'descripcion': row.Descripcion or '',
                        'precioNormal': float(row.Precio_Normal),
                        'precioEmergencia': float(row.Precio_Emergencia)
                    })
                
                logger.info(f"Obtenidos {len(tipos)} tipos de procedimientos")
                return tipos
                
        except Exception as e:
            logger.error(f"Error obteniendo tipos de procedimientos: {e}")
            return []
    
    def crear_tipo_procedimiento(self, datos: Dict[str, Any]) -> bool:
        """
        Crea un nuevo tipo de procedimiento
        
        Args:
            datos (Dict): Datos del tipo de procedimiento
            
        Returns:
            bool: True si se creó exitosamente
        """
        try:
            with self.db.get_connection() as conn:
                cursor = conn.cursor()
                cursor.execute("""
                    INSERT INTO Tipos_Procedimientos 
                    (Nombre, Descripcion, Precio_Normal, Precio_Emergencia)
                    VALUES (?, ?, ?, ?)
                """, (
                    datos['nombre'],
                    datos.get('descripcion', ''),
                    Decimal(str(datos['precioNormal'])),
                    Decimal(str(datos['precioEmergencia']))
                ))
                
                conn.commit()
                logger.info(f"Tipo de procedimiento creado: {datos['nombre']}")
                return True
                
        except Exception as e:
            logger.error(f"Error creando tipo de procedimiento: {e}")
            return False
    
    # ===============================
    # OPERACIONES DE PROCEDIMIENTOS DE ENFERMERÍA
    # ===============================
    
    def obtener_procedimientos_enfermeria(self, filtros: Optional[Dict] = None) -> List[Dict[str, Any]]:
        """
        Obtiene todos los procedimientos de enfermería con filtros opcionales
        
        Args:
            filtros (Dict, optional): Filtros para la consulta
            
        Returns:
            List[Dict]: Lista de procedimientos
        """
        try:
            with self.db.get_connection() as conn:
                cursor = conn.cursor()
                
                # Consulta base con JOINs
                query = """
                    SELECT 
                        e.id,
                        e.Cantidad,
                        e.Fecha,
                        e.Tipo,
                        p.Nombre + ' ' + p.Apellido_Paterno + ' ' + p.Apellido_Materno as NombrePaciente,
                        p.Cedula,
                        tp.Nombre as TipoProcedimiento,
                        tp.Descripcion,
                        CASE 
                            WHEN e.Tipo = 'Normal' THEN tp.Precio_Normal 
                            ELSE tp.Precio_Emergencia 
                        END as PrecioUnitario,
                        (e.Cantidad * CASE 
                            WHEN e.Tipo = 'Normal' THEN tp.Precio_Normal 
                            ELSE tp.Precio_Emergencia 
                        END) as PrecioTotal,
                        t.Nombre + ' ' + t.Apellido_Paterno + ' ' + t.Apellido_Materno as TrabajadorRealizador,
                        u.Nombre + ' ' + u.Apellido_Paterno + ' ' + u.Apellido_Materno as RegistradoPor
                    FROM Enfermeria e
                    INNER JOIN Pacientes p ON e.Id_Paciente = p.id
                    INNER JOIN Tipos_Procedimientos tp ON e.Id_Procedimiento = tp.id
                    INNER JOIN Trabajadores t ON e.Id_Trabajador = t.id
                    INNER JOIN Usuario u ON e.Id_RegistradoPor = u.id
                """
                
                conditions = []
                params = []
                
                # Aplicar filtros si existen
                if filtros:
                    if filtros.get('fechaDesde'):
                        conditions.append("e.Fecha >= ?")
                        params.append(filtros['fechaDesde'])
                    
                    if filtros.get('fechaHasta'):
                        conditions.append("e.Fecha <= ?")
                        params.append(filtros['fechaHasta'])
                    
                    if filtros.get('tipo'):
                        conditions.append("e.Tipo = ?")
                        params.append(filtros['tipo'])
                    
                    if filtros.get('idPaciente'):
                        conditions.append("e.Id_Paciente = ?")
                        params.append(filtros['idPaciente'])
                    
                    if filtros.get('idTrabajador'):
                        conditions.append("e.Id_Trabajador = ?")
                        params.append(filtros['idTrabajador'])
                
                if conditions:
                    query += " WHERE " + " AND ".join(conditions)
                
                query += " ORDER BY e.Fecha DESC, e.id DESC"
                
                cursor.execute(query, params)
                
                procedimientos = []
                for row in cursor.fetchall():
                    procedimientos.append({
                        'procedimientoId': str(row.id),
                        'paciente': row.NombrePaciente,
                        'cedula': row.Cedula or '',
                        'tipoProcedimiento': row.TipoProcedimiento,
                        'descripcion': row.Descripcion or '',
                        'cantidad': row.Cantidad,
                        'tipo': row.Tipo,
                        'precioUnitario': f"{float(row.PrecioUnitario):.2f}",
                        'precioTotal': f"{float(row.PrecioTotal):.2f}",
                        'fecha': row.Fecha.strftime('%Y-%m-%d') if row.Fecha else '',
                        'trabajadorRealizador': row.TrabajadorRealizador,
                        'registradoPor': row.RegistradoPor,
                        'observaciones': ''  # Campo adicional para el QML
                    })
                
                logger.info(f"Obtenidos {len(procedimientos)} procedimientos de enfermería")
                return procedimientos
                
        except Exception as e:
            logger.error(f"Error obteniendo procedimientos de enfermería: {e}")
            return []
    
    def obtener_procedimientos_paginados(self, offset: int, limit: int, filtros: Optional[Dict] = None) -> List[Dict[str, Any]]:
        """
        Obtiene procedimientos de enfermería paginados con filtros aplicados directamente en la base de datos
        
        Args:
            offset: Desplazamiento para paginación
            limit: Límite de registros por página
            filtros: Diccionario con filtros aplicables
            
        Returns:
            List[Dict]: Lista de procedimientos paginados
        """
        try:
            with self.db.get_connection() as conn:
                cursor = conn.cursor()
                
                # Construir consulta base
                query = """
                    SELECT 
                        e.id,
                        e.Cantidad,
                        e.Fecha,
                        e.Tipo,
                        p.Nombre + ' ' + p.Apellido_Paterno + ' ' + p.Apellido_Materno as NombrePaciente,
                        p.Cedula,
                        tp.Nombre as TipoProcedimiento,
                        tp.Descripcion,
                        CASE 
                            WHEN e.Tipo = 'Normal' THEN tp.Precio_Normal 
                            ELSE tp.Precio_Emergencia 
                        END as PrecioUnitario,
                        (e.Cantidad * CASE 
                            WHEN e.Tipo = 'Normal' THEN tp.Precio_Normal 
                            ELSE tp.Precio_Emergencia 
                        END) as PrecioTotal,
                        t.Nombre + ' ' + t.Apellido_Paterno + ' ' + t.Apellido_Materno as TrabajadorRealizador,
                        u.Nombre + ' ' + u.Apellido_Paterno + ' ' + u.Apellido_Materno as RegistradoPor
                    FROM Enfermeria e
                    INNER JOIN Pacientes p ON e.Id_Paciente = p.id
                    INNER JOIN Tipos_Procedimientos tp ON e.Id_Procedimiento = tp.id
                    INNER JOIN Trabajadores t ON e.Id_Trabajador = t.id
                    INNER JOIN Usuario u ON e.Id_RegistradoPor = u.id
                """
                
                conditions = []
                params = []
                
                # Aplicar filtros si existen
                if filtros:
                    if filtros.get('busqueda'):
                        conditions.append("(p.Nombre LIKE ? OR p.Apellido_Paterno LIKE ? OR p.Apellido_Materno LIKE ? OR p.Cedula LIKE ?)")
                        search_term = f"%{filtros['busqueda']}%"
                        params.extend([search_term, search_term, search_term, search_term])
                    
                    if filtros.get('tipo_procedimiento'):
                        conditions.append("tp.Nombre = ?")
                        params.append(filtros['tipo_procedimiento'])
                    
                    if filtros.get('tipo'):
                        conditions.append("e.Tipo = ?")
                        params.append(filtros['tipo'])
                    
                    if filtros.get('fecha_desde'):
                        conditions.append("CAST(e.Fecha AS DATE) >= ?")
                        params.append(filtros['fecha_desde'])
                    
                    if filtros.get('fecha_hasta'):
                        conditions.append("CAST(e.Fecha AS DATE) <= ?")
                        params.append(filtros['fecha_hasta'])
                
                if conditions:
                    query += " WHERE " + " AND ".join(conditions)
                
                query += " ORDER BY e.Fecha DESC, e.id DESC"
                
                # Agregar paginación
                query += " OFFSET ? ROWS FETCH NEXT ? ROWS ONLY"
                params.extend([offset, limit])
                
                cursor.execute(query, params)
                
                procedimientos = []
                for row in cursor.fetchall():
                    procedimientos.append({
                        'procedimientoId': str(row.id),
                        'paciente': row.NombrePaciente,
                        'cedula': row.Cedula or '',
                        'tipoProcedimiento': row.TipoProcedimiento,
                        'descripcion': row.Descripcion or '',
                        'cantidad': row.Cantidad,
                        'tipo': row.Tipo,
                        'precioUnitario': f"{float(row.PrecioUnitario):.2f}",
                        'precioTotal': f"{float(row.PrecioTotal):.2f}",
                        'fecha': row.Fecha.strftime('%Y-%m-%d') if row.Fecha else '',
                        'trabajadorRealizador': row.TrabajadorRealizador,
                        'registradoPor': row.RegistradoPor
                    })
                
                logger.info(f"Obtenidos {len(procedimientos)} procedimientos paginados (offset: {offset}, limit: {limit})")
                return procedimientos
                
        except Exception as e:
            logger.error(f"Error obteniendo procedimientos paginados: {e}")
            return []

    def contar_procedimientos_filtrados(self, filtros: Optional[Dict] = None) -> int:
        """
        Cuenta el total de procedimientos que cumplen con los filtros
        
        Args:
            filtros: Diccionario con filtros aplicables
            
        Returns:
            int: Total de procedimientos
        """
        try:
            with self.db.get_connection() as conn:
                cursor = conn.cursor()
                
                query = """
                    SELECT COUNT(*) as total 
                    FROM Enfermeria e 
                    INNER JOIN Pacientes p ON e.Id_Paciente = p.id
                """
                params = []
                conditions = []
                
                # Aplicar filtros si existen
                if filtros:
                    if filtros.get('busqueda'):
                        conditions.append("(p.Nombre LIKE ? OR p.Apellido_Paterno LIKE ? OR p.Apellido_Materno LIKE ? OR p.Cedula LIKE ?)")
                        search_term = f"%{filtros['busqueda']}%"
                        params.extend([search_term, search_term, search_term, search_term])
                    
                    if filtros.get('tipo_procedimiento'):
                        query += " INNER JOIN Tipos_Procedimientos tp ON e.Id_Procedimiento = tp.id"
                        conditions.append("tp.Nombre = ?")
                        params.append(filtros['tipo_procedimiento'])
                    
                    if filtros.get('tipo'):
                        conditions.append("e.Tipo = ?")
                        params.append(filtros['tipo'])
                    
                    if filtros.get('fecha_desde'):
                        conditions.append("CAST(e.Fecha AS DATE) >= ?")
                        params.append(filtros['fecha_desde'])
                    
                    if filtros.get('fecha_hasta'):
                        conditions.append("CAST(e.Fecha AS DATE) <= ?")
                        params.append(filtros['fecha_hasta'])
                
                if conditions:
                    query += " WHERE " + " AND ".join(conditions)
                
                cursor.execute(query, params)
                result = cursor.fetchone()
                total = result.total if result else 0
                
                logger.info(f"Total de procedimientos con filtros: {total}")
                return total
                
        except Exception as e:
            logger.error(f"Error contando procedimientos filtrados: {e}")
            return 0

    def crear_procedimiento_enfermeria(self, datos: Dict[str, Any]) -> Optional[int]:
        """
        Crea un nuevo procedimiento de enfermería
        
        Args:
            datos (Dict): Datos del procedimiento
            
        Returns:
            Optional[int]: ID del procedimiento creado o None si falló
        """
        try:
            with self.db.get_connection() as conn:
                cursor = conn.cursor()
                
                # Primero verificar/crear el paciente
                id_paciente = self._obtener_o_crear_paciente(cursor, datos)
                if not id_paciente:
                    raise Exception("No se pudo crear o encontrar el paciente")
                
                # Insertar el procedimiento
                cursor.execute("""
                    INSERT INTO Enfermeria 
                    (Id_Paciente, Id_Procedimiento, Cantidad, Id_RegistradoPor, Id_Trabajador, Tipo, Fecha)
                    VALUES (?, ?, ?, ?, ?, ?, ?)
                """, (
                    id_paciente,
                    datos['idProcedimiento'],
                    datos['cantidad'],
                    datos['idRegistradoPor'],
                    datos['idTrabajador'],
                    datos['tipo'],
                    datos.get('fecha', datetime.now())
                ))
                
                # Obtener el ID del procedimiento creado
                cursor.execute("SELECT @@IDENTITY")
                procedimiento_id = cursor.fetchone()[0]
                
                conn.commit()
                logger.info(f"Procedimiento de enfermería creado con ID: {procedimiento_id}")
                return int(procedimiento_id)
                
        except Exception as e:
            logger.error(f"Error creando procedimiento de enfermería: {e}")
            return None
    
    def actualizar_procedimiento_enfermeria(self, id_procedimiento: int, datos: Dict[str, Any]) -> bool:
        """
        Actualiza un procedimiento de enfermería existente
        
        Args:
            id_procedimiento (int): ID del procedimiento a actualizar
            datos (Dict): Nuevos datos del procedimiento
            
        Returns:
            bool: True si se actualizó exitosamente
        """
        try:
            with self.db.get_connection() as conn:
                cursor = conn.cursor()
                
                # Actualizar datos del paciente si es necesario
                id_paciente = self._obtener_o_crear_paciente(cursor, datos)
                if not id_paciente:
                    raise Exception("No se pudo actualizar el paciente")
                
                cursor.execute("""
                    UPDATE Enfermeria 
                    SET Id_Paciente = ?, 
                        Id_Procedimiento = ?, 
                        Cantidad = ?, 
                        Id_Trabajador = ?, 
                        Tipo = ?
                    WHERE id = ?
                """, (
                    id_paciente,
                    datos['idProcedimiento'],
                    datos['cantidad'],
                    datos['idTrabajador'],
                    datos['tipo'],
                    id_procedimiento
                ))
                
                if cursor.rowcount > 0:
                    conn.commit()
                    logger.info(f"Procedimiento de enfermería actualizado: {id_procedimiento}")
                    return True
                else:
                    logger.warning(f"No se encontró el procedimiento con ID: {id_procedimiento}")
                    return False
                
        except Exception as e:
            logger.error(f"Error actualizando procedimiento de enfermería: {e}")
            return False
    
    def eliminar_procedimiento_enfermeria(self, id_procedimiento: int) -> bool:
        """
        Elimina un procedimiento de enfermería
        
        Args:
            id_procedimiento (int): ID del procedimiento a eliminar
            
        Returns:
            bool: True si se eliminó exitosamente
        """
        try:
            with self.db.get_connection() as conn:
                cursor = conn.cursor()
                cursor.execute("DELETE FROM Enfermeria WHERE id = ?", (id_procedimiento,))
                
                if cursor.rowcount > 0:
                    conn.commit()
                    logger.info(f"Procedimiento de enfermería eliminado: {id_procedimiento}")
                    return True
                else:
                    logger.warning(f"No se encontró el procedimiento con ID: {id_procedimiento}")
                    return False
                
        except Exception as e:
            logger.error(f"Error eliminando procedimiento de enfermería: {e}")
            return False
    
    # ===============================
    # OPERACIONES DE PACIENTES
    # ===============================
    def _limpiar_cedula(self, cedula_raw: str) -> Optional[str]:
        """
        Limpia y valida el formato de cédula según las restricciones de la BD
        
        Args:
            cedula_raw (str): Cédula sin limpiar
            
        Returns:
            Optional[str]: Cédula limpia o None si es inválida
        """
        try:
            if not cedula_raw:
                return None
            
            # Remover espacios y convertir a mayúsculas
            cedula = cedula_raw.strip().upper()
            
            # Validar formato: solo números y letras, máximo 12 dígitos + 3 letras
            import re
            if not re.match(r'^\d{1,12}[A-Z]{0,3}$', cedula):
                # Si no cumple el formato, intentar extraer solo números
                numeros = re.sub(r'[^\d]', '', cedula)
                if len(numeros) >= 6 and len(numeros) <= 12:
                    return numeros
                else:
                    logger.warning(f"Formato de cédula inválido: {cedula_raw}")
                    return None
            
            return cedula
            
        except Exception as e:
            logger.error(f"Error limpiando cédula: {e}")
            return None
    
    def _obtener_o_crear_paciente(self, cursor, datos: Dict[str, Any]) -> Optional[int]:
        try:
            nombres = datos['nombreCompleto'].strip().split()
            
            # Extraer nombre y apellidos
            nombre = nombres[0] if len(nombres) > 0 else ''
            apellido_paterno = nombres[1] if len(nombres) > 1 else ''
            apellido_materno = ' '.join(nombres[2:]) if len(nombres) > 2 else ''
            cedula_raw = datos.get('cedula', '').strip()
            
            # Limpiar y validar formato de cédula
            cedula = self._limpiar_cedula(cedula_raw) if cedula_raw else None
            
            # Buscar paciente existente por cédula (si se proporciona)
            if cedula:
                cursor.execute("""
                    SELECT id FROM Pacientes WHERE Cedula = ?
                """, (cedula,))
                resultado = cursor.fetchone()
                if resultado:
                    return resultado.id
            
            # Buscar por nombre completo si no hay cédula
            cursor.execute("""
                SELECT id FROM Pacientes 
                WHERE Nombre = ? AND Apellido_Paterno = ? AND Apellido_Materno = ?
            """, (nombre, apellido_paterno, apellido_materno))
            resultado = cursor.fetchone()
            if resultado:
                return resultado.id
            
            # Crear nuevo paciente
            cursor.execute("""
                INSERT INTO Pacientes (Nombre, Apellido_Paterno, Apellido_Materno, Cedula)
                VALUES (?, ?, ?, ?)
            """, (nombre, apellido_paterno, apellido_materno, cedula))
            
            cursor.execute("SELECT @@IDENTITY")
            paciente_id = cursor.fetchone()[0]
            
            logger.info(f"Paciente creado con ID: {paciente_id}")
            return int(paciente_id)
            
        except Exception as e:
            logger.error(f"Error obteniendo/creando paciente: {e}")
            return None
    
    def buscar_pacientes(self, termino_busqueda: str) -> List[Dict[str, Any]]:
        try:
            with self.db.get_connection() as conn:
                cursor = conn.cursor()
                
                # Si el término parece una cédula (solo números), priorizar búsqueda exacta
                if termino_busqueda.replace(' ', '').isdigit() and len(termino_busqueda.replace(' ', '')) >= 6:
                    cursor.execute("""
                        SELECT 
                            id,
                            Nombre + ' ' + Apellido_Paterno + ' ' + Apellido_Materno as NombreCompleto,
                            Nombre,
                            Apellido_Paterno,
                            Apellido_Materno,
                            Cedula
                        FROM Pacientes
                        WHERE Cedula = ? OR Cedula LIKE ?
                        ORDER BY 
                            CASE WHEN Cedula = ? THEN 1 ELSE 2 END,
                            Nombre, Apellido_Paterno
                    """, (termino_busqueda.replace(' ', ''), f'%{termino_busqueda.replace(" ", "")}%', termino_busqueda.replace(' ', '')))
                else:
                    cursor.execute("""
                        SELECT 
                            id,
                            Nombre + ' ' + Apellido_Paterno + ' ' + Apellido_Materno as NombreCompleto,
                            Nombre,
                            Apellido_Paterno, 
                            Apellido_Materno,
                            Cedula
                        FROM Pacientes
                        WHERE Nombre LIKE ? 
                        OR Apellido_Paterno LIKE ?
                        OR Apellido_Materno LIKE ?
                        OR Cedula LIKE ?
                        ORDER BY Nombre, Apellido_Paterno
                    """, (f'%{termino_busqueda}%', f'%{termino_busqueda}%', 
                        f'%{termino_busqueda}%', f'%{termino_busqueda}%'))
                
                pacientes = []
                for row in cursor.fetchall():
                    pacientes.append({
                        'id': row.id,
                        'nombreCompleto': row.NombreCompleto,
                        'nombre': row.Nombre,
                        'apellidoPaterno': row.Apellido_Paterno,
                        'apellidoMaterno': row.Apellido_Materno or '',
                        'cedula': row.Cedula or ''
                    })
                
            logger.info(f"Búsqueda '{termino_busqueda}': {len(pacientes)} pacientes encontrados")
            return pacientes
        except Exception as e:
            logger.error(f"Error al buscar pacientes: {e}")
            return []
    # ===============================
    # OPERACIONES DE TRABAJADORES
    # ===============================
    
    def obtener_trabajadores_enfermeria(self) -> List[Dict[str, Any]]:
        """
        Obtiene los trabajadores que pueden realizar procedimientos de enfermería
        
        Returns:
            List[Dict]: Lista de trabajadores de enfermería
        """
        try:
            with self.db.get_connection() as conn:
                cursor = conn.cursor()
                cursor.execute("""
                    SELECT 
                        id,
                        Nombre + ' ' + Apellido_Paterno + ' ' + Apellido_Materno as NombreCompleto,
                        Id_Tipo_Trabajador,
                        Especialidad
                    FROM Trabajadores
                    ORDER BY Nombre, Apellido_Paterno
                """)
                
                trabajadores = []
                for row in cursor.fetchall():
                    trabajadores.append({
                        'id': row.id,
                        'nombreCompleto': row.NombreCompleto,
                        'tipoTrabajador': f"Tipo {row.Id_Tipo_Trabajador}",
                        'especialidad': row.Especialidad or ''
                    })
                
                logger.info(f"Obtenidos {len(trabajadores)} trabajadores de enfermería")
                return trabajadores
                
        except Exception as e:
            logger.error(f"Error obteniendo trabajadores de enfermería: {e}")
            return []
    
    def buscar_procedimientos(self, termino_busqueda: str, limit: int = 50) -> List[Dict[str, Any]]:
        """
        Búsqueda de procedimientos por término en base de datos
        
        Args:
            termino_busqueda: Término a buscar
            limit: Límite de resultados
            
        Returns:
            List[Dict]: Lista de procedimientos encontrados
        """
        try:
            with self.db.get_connection() as conn:
                cursor = conn.cursor()
                
                query = """
                    SELECT 
                        e.id,
                        e.Cantidad,
                        e.Fecha,
                        e.Tipo,
                        p.Nombre + ' ' + p.Apellido_Paterno + ' ' + p.Apellido_Materno as NombrePaciente,
                        p.Cedula,
                        tp.Nombre as TipoProcedimiento,
                        CASE 
                            WHEN e.Tipo = 'Normal' THEN tp.Precio_Normal 
                            ELSE tp.Precio_Emergencia 
                        END as PrecioUnitario,
                        (e.Cantidad * CASE 
                            WHEN e.Tipo = 'Normal' THEN tp.Precio_Normal 
                            ELSE tp.Precio_Emergencia 
                        END) as PrecioTotal,
                        t.Nombre + ' ' + t.Apellido_Paterno + ' ' + t.Apellido_Materno as TrabajadorRealizador
                    FROM Enfermeria e
                    INNER JOIN Pacientes p ON e.Id_Paciente = p.id
                    INNER JOIN Tipos_Procedimientos tp ON e.Id_Procedimiento = tp.id
                    INNER JOIN Trabajadores t ON e.Id_Trabajador = t.id
                    WHERE (p.Nombre LIKE ? OR p.Apellido_Paterno LIKE ? OR p.Apellido_Materno LIKE ? 
                           OR p.Cedula LIKE ? OR tp.Nombre LIKE ?)
                    ORDER BY e.Fecha DESC
                    OFFSET 0 ROWS FETCH NEXT ? ROWS ONLY
                """
                
                search_term = f"%{termino_busqueda}%"
                params = [search_term, search_term, search_term, search_term, search_term, limit]
                
                cursor.execute(query, params)
                
                procedimientos = []
                for row in cursor.fetchall():
                    procedimientos.append({
                        'procedimientoId': str(row.id),
                        'paciente': row.NombrePaciente,
                        'cedula': row.Cedula or '',
                        'tipoProcedimiento': row.TipoProcedimiento,
                        'cantidad': row.Cantidad,
                        'tipo': row.Tipo,
                        'precioUnitario': f"{float(row.PrecioUnitario):.2f}",
                        'precioTotal': f"{float(row.PrecioTotal):.2f}",
                        'fecha': row.Fecha.strftime('%Y-%m-%d') if row.Fecha else '',
                        'trabajadorRealizador': row.TrabajadorRealizador
                    })
                
                logger.info(f"Búsqueda '{termino_busqueda}': {len(procedimientos)} resultados")
                return procedimientos
                
        except Exception as e:
            logger.error(f"Error buscando procedimientos: {e}")
            return []

    # ===============================
    # REPORTES Y ESTADÍSTICAS
    # ===============================
    
    def obtener_estadisticas_enfermeria(self, periodo: str = 'mes') -> Dict[str, Any]:
        """
        Obtiene estadísticas de procedimientos de enfermería
        
        Args:
            periodo (str): Periodo para las estadísticas ('dia', 'semana', 'mes', 'año')
            
        Returns:
            Dict: Estadísticas de enfermería
        """
        try:
            with self.db.get_connection() as conn:
                cursor = conn.cursor()
                
                # Determinar el filtro de fecha según el periodo
                if periodo == 'dia':
                    filtro_fecha = "CAST(e.Fecha AS DATE) = CAST(GETDATE() AS DATE)"
                elif periodo == 'semana':
                    filtro_fecha = "e.Fecha >= DATEADD(day, -7, GETDATE())"
                elif periodo == 'mes':
                    filtro_fecha = "e.Fecha >= DATEADD(month, -1, GETDATE())"
                elif periodo == 'año':
                    filtro_fecha = "e.Fecha >= DATEADD(year, -1, GETDATE())"
                else:
                    filtro_fecha = "1=1"  # Sin filtro de fecha
                
                # Consulta de estadísticas
                cursor.execute(f"""
                    SELECT 
                        COUNT(*) as TotalProcedimientos,
                        COUNT(DISTINCT e.Id_Paciente) as TotalPacientes,
                        COUNT(DISTINCT e.Id_Trabajador) as TotalTrabajadores,
                        SUM(CASE WHEN e.Tipo = 'Normal' THEN tp.Precio_Normal * e.Cantidad 
                                 ELSE tp.Precio_Emergencia * e.Cantidad END) as IngresoTotal,
                        SUM(CASE WHEN e.Tipo = 'Normal' THEN e.Cantidad ELSE 0 END) as ProcedimientosNormales,
                        SUM(CASE WHEN e.Tipo = 'Emergencia' THEN e.Cantidad ELSE 0 END) as ProcedimientosEmergencia
                    FROM Enfermeria e
                    INNER JOIN Tipos_Procedimientos tp ON e.Id_Procedimiento = tp.id
                    WHERE {filtro_fecha}
                """)
                
                estadisticas = cursor.fetchone()
                
                # Procedimientos más realizados
                cursor.execute(f"""
                    SELECT TOP 5
                        tp.Nombre,
                        COUNT(*) as Cantidad,
                        SUM(e.Cantidad) as TotalUnidades
                    FROM Enfermeria e
                    INNER JOIN Tipos_Procedimientos tp ON e.Id_Procedimiento = tp.id
                    WHERE {filtro_fecha}
                    GROUP BY tp.Nombre
                    ORDER BY COUNT(*) DESC
                """)
                
                procedimientos_top = []
                for row in cursor.fetchall():
                    procedimientos_top.append({
                        'nombre': row.Nombre,
                        'cantidad': row.Cantidad,
                        'totalUnidades': row.TotalUnidades
                    })
                
                return {
                    'totalProcedimientos': estadisticas.TotalProcedimientos or 0,
                    'totalPacientes': estadisticas.TotalPacientes or 0,
                    'totalTrabajadores': estadisticas.TotalTrabajadores or 0,
                    'ingresoTotal': float(estadisticas.IngresoTotal or 0),
                    'procedimientosNormales': estadisticas.ProcedimientosNormales or 0,
                    'procedimientosEmergencia': estadisticas.ProcedimientosEmergencia or 0,
                    'procedimientosTop': procedimientos_top,
                    'periodo': periodo
                }
                
        except Exception as e:
            logger.error(f"Error obteniendo estadísticas de enfermería: {e}")
            return {
                'totalProcedimientos': 0,
                'totalPacientes': 0,
                'totalTrabajadores': 0,
                'ingresoTotal': 0.0,
                'procedimientosNormales': 0,
                'procedimientosEmergencia': 0,
                'procedimientosTop': [],
                'periodo': periodo
            }
    def buscar_paciente_por_cedula_exacta(self, cedula: str) -> Optional[Dict[str, Any]]:
        """
        Busca un paciente específico por cédula exacta
        
        Args:
            cedula (str): Cédula del paciente
            
        Returns:
            Optional[Dict]: Datos del paciente encontrado
        """
        try:
            with self.db.get_connection() as conn:
                cursor = conn.cursor()
                
                # Limpiar cédula antes de buscar
                cedula_limpia = self._limpiar_cedula(cedula)
                
                if not cedula_limpia:
                    return None
                
                cursor.execute("""
                    SELECT 
                        id,
                        Nombre + ' ' + Apellido_Paterno + ' ' + Apellido_Materno as NombreCompleto,
                        Nombre,
                        Apellido_Paterno,
                        Apellido_Materno,
                        Cedula
                    FROM Pacientes
                    WHERE Cedula = ?
                """, (cedula_limpia,))
                
                resultado = cursor.fetchone()
                
                if resultado:
                    return {
                        'id': resultado.id,
                        'nombreCompleto': resultado.NombreCompleto,
                        'nombre': resultado.Nombre,
                        'apellidoPaterno': resultado.Apellido_Paterno,
                        'apellidoMaterno': resultado.Apellido_Materno or '',
                        'cedula': resultado.Cedula
                    }
                
                return None
                
        except Exception as e:
            logger.error(f"Error buscando paciente por cédula exacta: {e}")
            return None