"""
Repositorio para manejo de datos de enfermería COMPLETO - CORREGIDO
ARREGLOS CRÍTICOS:
- Error SQL JOIN duplicado eliminado
- Filtros estandarizados y consistentes
- Manejo robusto de parámetros
- Consultas optimizadas
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
    # ✅ MÉTODO EXISTENTE: buscar_paciente_por_cedula_exacta
    # ===============================
    
    def buscar_paciente_por_cedula_exacta(self, cedula: str) -> Optional[Dict[str, Any]]:
        """
        ✅ MÉTODO EXISTENTE: Busca un paciente específico por cédula exacta
        """
        try:
            if not cedula or len(cedula.strip()) < 5:
                return None
            
            cedula_clean = cedula.strip()
            
            with self.db.get_connection() as conn:
                cursor = conn.cursor()
                cursor.execute("""
                    SELECT 
                        id,
                        Nombre,
                        Apellido_Paterno,
                        ISNULL(Apellido_Materno, '') as Apellido_Materno,
                        Cedula,
                        CONCAT(Nombre, ' ', Apellido_Paterno, ' ', ISNULL(Apellido_Materno, '')) as nombreCompleto
                    FROM Pacientes
                    WHERE Cedula = ?
                """, (cedula_clean,))
                
                resultado = cursor.fetchone()
                
                if resultado:
                    return {
                        'id': resultado.id,
                        'nombreCompleto': resultado.nombreCompleto,
                        'nombre': resultado.Nombre,
                        'apellidoPaterno': resultado.Apellido_Paterno,
                        'apellidoMaterno': resultado.Apellido_Materno,
                        'cedula': resultado.Cedula
                    }
                
                return None
                
        except Exception as e:
            logger.error(f"Error buscando paciente por cédula exacta: {e}")
            return None
    
    # ===============================
    # ✅ PAGINACIÓN CORREGIDA COMPLETAMENTE
    # ===============================
    
    def obtener_procedimientos_paginados(self, offset: int, limit: int, filtros: Optional[Dict] = None) -> List[Dict[str, Any]]:
        """
        ✅ COMPLETAMENTE CORREGIDO: Paginación con filtros y logs de diagnóstico
        """
        try:
            with self.db.get_connection() as conn:
                cursor = conn.cursor()
                
                # ✅ LOGS DE DIAGNÓSTICO DETALLADOS
                logger.info(f"🔍 REPOSITORIO - Filtros recibidos: {filtros}")
                
                # Consulta base corregida
                query = """
                    SELECT 
                        e.id,
                        e.Cantidad,
                        e.Fecha,
                        e.Tipo,
                        CONCAT(p.Nombre, ' ', p.Apellido_Paterno, ' ', ISNULL(p.Apellido_Materno, '')) as NombrePaciente,
                        ISNULL(p.Cedula, '') as Cedula,
                        p.Nombre as pacienteNombre,
                        p.Apellido_Paterno as pacienteApellidoP,
                        ISNULL(p.Apellido_Materno, '') as pacienteApellidoM,
                        ISNULL(tp.Nombre, 'Procedimiento General') as TipoProcedimiento,
                        ISNULL(tp.Descripcion, '') as Descripcion,
                        CASE 
                            WHEN e.Tipo = 'Emergencia' THEN ISNULL(tp.Precio_Emergencia, 0)
                            ELSE ISNULL(tp.Precio_Normal, 0)
                        END as PrecioUnitario,
                        (e.Cantidad * CASE 
                            WHEN e.Tipo = 'Emergencia' THEN ISNULL(tp.Precio_Emergencia, 0)
                            ELSE ISNULL(tp.Precio_Normal, 0)
                        END) as PrecioTotal,
                        CONCAT(ISNULL(t.Nombre, ''), ' ', ISNULL(t.Apellido_Paterno, ''), ' ', ISNULL(t.Apellido_Materno, '')) as TrabajadorRealizador,
                        CONCAT(ISNULL(u.Nombre, ''), ' ', ISNULL(u.Apellido_Paterno, ''), ' ', ISNULL(u.Apellido_Materno, '')) as RegistradoPor
                    FROM Enfermeria e
                    INNER JOIN Pacientes p ON e.Id_Paciente = p.id
                    LEFT JOIN Tipos_Procedimientos tp ON e.Id_Procedimiento = tp.id
                    LEFT JOIN Trabajadores t ON e.Id_Trabajador = t.id
                    LEFT JOIN Usuario u ON e.Id_RegistradoPor = u.id
                """
                
                conditions = []
                params = []
                
                # ✅ FILTROS CORREGIDOS CON LOGS
                if filtros:
                    logger.info(f"📋 Aplicando filtros: {filtros}")
                    
                    # Filtro por búsqueda (paciente/cédula)
                    busqueda = filtros.get('busqueda', '').strip()
                    if busqueda:
                        search_pattern = f"%{busqueda}%"
                        conditions.append("""(
                            ISNULL(p.Nombre, '') LIKE ? OR 
                            ISNULL(p.Apellido_Paterno, '') LIKE ? OR 
                            ISNULL(p.Apellido_Materno, '') LIKE ? OR 
                            ISNULL(p.Cedula, '') LIKE ? OR 
                            ISNULL(CONCAT(p.Nombre, ' ', p.Apellido_Paterno, ' ', p.Apellido_Materno), '') LIKE ?
                        )""")
                        params.extend([search_pattern] * 5)
                        logger.info(f"🔎 Filtro búsqueda aplicado: '{busqueda}'")
                    
                    # ✅ FILTRO POR TIPO DE PROCEDIMIENTO CORREGIDO
                    tipo_procedimiento = filtros.get('tipo_procedimiento', '').strip()
                    if tipo_procedimiento and tipo_procedimiento not in ["", "Todos", "Seleccionar procedimiento..."]:
                        conditions.append("ISNULL(tp.Nombre, '') = ?")
                        params.append(tipo_procedimiento)
                        logger.info(f"🏥 Filtro tipo procedimiento aplicado: '{tipo_procedimiento}'")
                    
                    # ✅ FILTRO POR TIPO DE SERVICIO - CRÍTICO
                    tipo_servicio = filtros.get('tipo', '').strip()
                    if tipo_servicio and tipo_servicio not in ["", "Todos"]:
                        # ✅ VALIDACIÓN ESPECÍFICA
                        if tipo_servicio in ["Normal", "Emergencia"]:
                            conditions.append("ISNULL(e.Tipo, 'Normal') = ?") 
                            params.append(tipo_servicio)
                            logger.info(f"🎯 Filtro tipo servicio aplicado: '{tipo_servicio}'")
                        else:
                            logger.warning(f"⚠️ Tipo de servicio inválido ignorado: '{tipo_servicio}'")
                    
                    # Filtros por fecha
                    fecha_desde = filtros.get('fecha_desde', '').strip()
                    if fecha_desde:
                        conditions.append("CAST(e.Fecha AS DATE) >= ?")
                        params.append(fecha_desde)
                        logger.info(f"📅 Filtro fecha desde: '{fecha_desde}'")
                    
                    fecha_hasta = filtros.get('fecha_hasta', '').strip()
                    if fecha_hasta:
                        conditions.append("CAST(e.Fecha AS DATE) <= ?")
                        params.append(fecha_hasta)
                        logger.info(f"📅 Filtro fecha hasta: '{fecha_hasta}'")
                else:
                    logger.info("📋 Sin filtros aplicados")
                
                # Agregar condiciones WHERE
                if conditions:
                    query += " WHERE " + " AND ".join(conditions)
                
                query += " ORDER BY e.Fecha DESC, e.id DESC"
                query += " OFFSET ? ROWS FETCH NEXT ? ROWS ONLY"
                params.extend([offset, limit])
                
                # ✅ LOG DE QUERY FINAL
                logger.info(f"🗃️ Query final - offset={offset}, limit={limit}")
                logger.info(f"📝 Condiciones WHERE: {len(conditions)} aplicadas")
                if conditions:
                    logger.info(f"🔍 WHERE clause: {' AND '.join(conditions)}")
                
                cursor.execute(query, params)
                
                procedimientos = []
                for row in cursor.fetchall():
                    procedimientos.append({
                        'procedimientoId': str(row.id),
                        'paciente': row.NombrePaciente.strip(),
                        'cedula': row.Cedula,
                        'tipoProcedimiento': row.TipoProcedimiento,
                        'descripcion': row.Descripcion,
                        'cantidad': row.Cantidad,
                        'tipo': row.Tipo,  # ✅ ESTE ES EL CAMPO CRÍTICO
                        'precioUnitario': f"{float(row.PrecioUnitario):.2f}",
                        'precioTotal': f"{float(row.PrecioTotal):.2f}",
                        'fecha': row.Fecha.strftime('%Y-%m-%d') if row.Fecha else '',
                        'trabajadorRealizador': row.TrabajadorRealizador.strip(),
                        'registradoPor': row.RegistradoPor.strip(),
                        'pacienteNombre': row.pacienteNombre,
                        'pacienteApellidoP': row.pacienteApellidoP,
                        'pacienteApellidoM': row.pacienteApellidoM
                    })
                
                logger.info(f"✅ Obtenidos {len(procedimientos)} procedimientos paginados exitosamente")
                
                # ✅ LOG DE MUESTRA DE DATOS
                if procedimientos:
                    primer_proc = procedimientos[0]
                    logger.info(f"📋 Muestra primer resultado - Tipo: '{primer_proc['tipo']}', ID: {primer_proc['procedimientoId']}")
                
                return procedimientos
                
        except Exception as e:
            logger.error(f"❌ Error obteniendo procedimientos paginados: {e}")
            return []

    def contar_procedimientos_filtrados(self, filtros: Optional[Dict] = None) -> int:
        """
        ✅ CORREGIDO: Contar con filtros estandarizados y logs
        """
        try:
            with self.db.get_connection() as conn:
                cursor = conn.cursor()
                
                # ✅ LOG DE DIAGNÓSTICO
                logger.info(f"🔢 Contando registros con filtros: {filtros}")
                
                query = """
                    SELECT COUNT(*) as total 
                    FROM Enfermeria e 
                    INNER JOIN Pacientes p ON e.Id_Paciente = p.id
                    LEFT JOIN Tipos_Procedimientos tp ON e.Id_Procedimiento = tp.id
                """
                params = []
                conditions = []
                
                # ✅ APLICAR FILTROS ESTANDARIZADOS (misma lógica que paginación)
                if filtros:
                    busqueda = filtros.get('busqueda', '').strip()
                    if busqueda:
                        search_pattern = f"%{busqueda}%"
                        conditions.append("""(
                            ISNULL(p.Nombre, '') LIKE ? OR 
                            ISNULL(p.Apellido_Paterno, '') LIKE ? OR 
                            ISNULL(p.Apellido_Materno, '') LIKE ? OR 
                            ISNULL(p.Cedula, '') LIKE ? OR 
                            ISNULL(CONCAT(p.Nombre, ' ', p.Apellido_Paterno, ' ', p.Apellido_Materno), '') LIKE ?
                        )""")
                        params.extend([search_pattern] * 5)
                    
                    tipo_procedimiento = filtros.get('tipo_procedimiento', '').strip()
                    if tipo_procedimiento and tipo_procedimiento not in ["", "Todos", "Seleccionar procedimiento..."]:
                        conditions.append("ISNULL(tp.Nombre, '') = ?")
                        params.append(tipo_procedimiento)
                    
                    # ✅ FILTRO CRÍTICO CORREGIDO
                    tipo_servicio = filtros.get('tipo', '').strip()
                    if tipo_servicio and tipo_servicio not in ["", "Todos"]:
                        if tipo_servicio in ["Normal", "Emergencia"]:
                            conditions.append("ISNULL(e.Tipo, 'Normal') = ?")
                            params.append(tipo_servicio)
                            logger.info(f"🎯 Count - Filtro tipo aplicado: '{tipo_servicio}'")
                    
                    fecha_desde = filtros.get('fecha_desde', '').strip()
                    if fecha_desde:
                        conditions.append("CAST(e.Fecha AS DATE) >= ?")
                        params.append(fecha_desde)
                    
                    fecha_hasta = filtros.get('fecha_hasta', '').strip()
                    if fecha_hasta:
                        conditions.append("CAST(e.Fecha AS DATE) <= ?")
                        params.append(fecha_hasta)
                
                if conditions:
                    query += " WHERE " + " AND ".join(conditions)
                
                cursor.execute(query, params)
                result = cursor.fetchone()
                total = result.total if result else 0
                
                logger.info(f"✅ Total de procedimientos con filtros: {total}")
                return total
                
        except Exception as e:
            logger.error(f"❌ Error contando procedimientos filtrados: {e}")
            return 0
        
    def get_procedimiento_by_id(self, procedimiento_id: int) -> Optional[Dict[str, Any]]:
        """Obtiene procedimiento por ID con información completa"""
        try:
            with self.db.get_connection() as conn:
                cursor = conn.cursor()
                cursor.execute("""
                    SELECT 
                        e.*,
                        CONCAT(p.Nombre, ' ', p.Apellido_Paterno, ' ', ISNULL(p.Apellido_Materno, '')) as paciente_nombre
                    FROM Enfermeria e
                    INNER JOIN Pacientes p ON e.Id_Paciente = p.id
                    WHERE e.id = ?
                """, (procedimiento_id,))
                
                resultado = cursor.fetchone()
                
                if resultado:
                    return {
                        'id': resultado.id,
                        'Id_Paciente': resultado.Id_Paciente,
                        'Id_Procedimiento': resultado.Id_Procedimiento,
                        'Cantidad': resultado.Cantidad,
                        'Tipo': resultado.Tipo,
                        'Fecha': resultado.Fecha,
                        'Id_Trabajador': resultado.Id_Trabajador,
                        'Id_RegistradoPor': resultado.Id_RegistradoPor,
                        'paciente_nombre': resultado.paciente_nombre
                    }
                
                return None
                
        except Exception as e:
            logger.error(f"Error obteniendo procedimiento por ID: {e}")
            return None
    
    # ===============================
    # OPERACIONES DE TIPOS DE PROCEDIMIENTOS (sin cambios)
    # ===============================
    
    def obtener_tipos_procedimientos(self) -> List[Dict[str, Any]]:
        """Obtiene todos los tipos de procedimientos disponibles"""
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
        """Crea un nuevo tipo de procedimiento"""
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
    # OPERACIONES DE PROCEDIMIENTOS DE ENFERMERÍA (sin cambios críticos)
    # ===============================
    
    def obtener_procedimientos_enfermeria(self, filtros: Optional[Dict] = None) -> List[Dict[str, Any]]:
        """Obtiene todos los procedimientos de enfermería con filtros opcionales"""
        try:
            with self.db.get_connection() as conn:
                cursor = conn.cursor()
                
                # Consulta base con JOINs corregidos
                query = """
                    SELECT 
                        e.id,
                        e.Cantidad,
                        e.Fecha,
                        e.Tipo,
                        CONCAT(p.Nombre, ' ', p.Apellido_Paterno, ' ', ISNULL(p.Apellido_Materno, '')) as NombrePaciente,
                        ISNULL(p.Cedula, '') as Cedula,
                        ISNULL(tp.Nombre, 'Procedimiento General') as TipoProcedimiento,
                        ISNULL(tp.Descripcion, '') as Descripcion,
                        CASE 
                            WHEN e.Tipo = 'Emergencia' THEN ISNULL(tp.Precio_Emergencia, 0)
                            ELSE ISNULL(tp.Precio_Normal, 0)
                        END as PrecioUnitario,
                        (e.Cantidad * CASE 
                            WHEN e.Tipo = 'Emergencia' THEN ISNULL(tp.Precio_Emergencia, 0)
                            ELSE ISNULL(tp.Precio_Normal, 0)
                        END) as PrecioTotal,
                        CONCAT(ISNULL(t.Nombre, ''), ' ', ISNULL(t.Apellido_Paterno, ''), ' ', ISNULL(t.Apellido_Materno, '')) as TrabajadorRealizador,
                        CONCAT(ISNULL(u.Nombre, ''), ' ', ISNULL(u.Apellido_Paterno, ''), ' ', ISNULL(u.Apellido_Materno, '')) as RegistradoPor
                    FROM Enfermeria e
                    INNER JOIN Pacientes p ON e.Id_Paciente = p.id
                    LEFT JOIN Tipos_Procedimientos tp ON e.Id_Procedimiento = tp.id
                    LEFT JOIN Trabajadores t ON e.Id_Trabajador = t.id
                    LEFT JOIN Usuario u ON e.Id_RegistradoPor = u.id
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
                        'paciente': row.NombrePaciente.strip(),
                        'cedula': row.Cedula,
                        'tipoProcedimiento': row.TipoProcedimiento,
                        'descripcion': row.Descripcion,
                        'cantidad': row.Cantidad,
                        'tipo': row.Tipo,
                        'precioUnitario': f"{float(row.PrecioUnitario):.2f}",
                        'precioTotal': f"{float(row.PrecioTotal):.2f}",
                        'fecha': row.Fecha.strftime('%Y-%m-%d') if row.Fecha else '',
                        'trabajadorRealizador': row.TrabajadorRealizador.strip(),
                        'registradoPor': row.RegistradoPor.strip(),
                        'observaciones': ''
                    })
                
                logger.info(f"Obtenidos {len(procedimientos)} procedimientos de enfermería")
                return procedimientos
                
        except Exception as e:
            logger.error(f"Error obteniendo procedimientos de enfermería: {e}")
            return []
    
    def crear_procedimiento_enfermeria(self, datos: Dict[str, Any]) -> Optional[int]:
        """Crea un nuevo procedimiento de enfermería"""
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
        """Actualiza un procedimiento de enfermería existente"""
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
        """Elimina un procedimiento de enfermería"""
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
    # OPERACIONES DE PACIENTES (mejoradas)
    # ===============================
    
    def _limpiar_cedula(self, cedula_raw: str) -> Optional[str]:
        """Limpia y valida el formato de cédula según las restricciones de la BD"""
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
        """✅ CORREGIDO: Obtiene o crea paciente manteniendo funcionalidad original + mejoras"""
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
        """✅ CORREGIDO: Busca pacientes manteniendo funcionalidad original"""
        try:
            with self.db.get_connection() as conn:
                cursor = conn.cursor()
                
                # Si el término parece una cédula (solo números), priorizar búsqueda exacta
                if termino_busqueda.replace(' ', '').isdigit() and len(termino_busqueda.replace(' ', '')) >= 6:
                    cursor.execute("""
                        SELECT 
                            id,
                            Nombre + ' ' + Apellido_Paterno + ' ' + ISNULL(Apellido_Materno, '') as NombreCompleto,
                            Nombre,
                            Apellido_Paterno,
                            ISNULL(Apellido_Materno, '') as Apellido_Materno,
                            ISNULL(Cedula, '') as Cedula
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
                            Nombre + ' ' + Apellido_Paterno + ' ' + ISNULL(Apellido_Materno, '') as NombreCompleto,
                            Nombre,
                            Apellido_Paterno, 
                            ISNULL(Apellido_Materno, '') as Apellido_Materno,
                            ISNULL(Cedula, '') as Cedula
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
                        'nombreCompleto': row.NombreCompleto.strip(),
                        'nombre': row.Nombre,
                        'apellidoPaterno': row.Apellido_Paterno,
                        'apellidoMaterno': row.Apellido_Materno,
                        'cedula': row.Cedula
                    })
                
            logger.info(f"Búsqueda '{termino_busqueda}': {len(pacientes)} pacientes encontrados")
            return pacientes
        except Exception as e:
            logger.error(f"Error al buscar pacientes: {e}")
            return []
        
    def buscar_pacientes_por_nombre_completo(self, nombre_completo: str, limite: int = 10) -> List[Dict[str, Any]]:
        """Busca pacientes por nombre completo con múltiples estrategias"""
        try:
            if not nombre_completo or len(nombre_completo.strip()) < 3:
                return []
            
            nombre_limpio = nombre_completo.strip()
            
            with self.db.get_connection() as conn:
                cursor = conn.cursor()
                
                # Búsqueda con LIKE
                cursor.execute("""
                    SELECT TOP (?)
                        id,
                        Nombre,
                        Apellido_Paterno,
                        ISNULL(Apellido_Materno, '') as Apellido_Materno,
                        ISNULL(Cedula, '') as Cedula,
                        CONCAT(Nombre, ' ', Apellido_Paterno, ' ', ISNULL(Apellido_Materno, '')) as nombreCompleto
                    FROM Pacientes
                    WHERE CONCAT(Nombre, ' ', Apellido_Paterno, ' ', ISNULL(Apellido_Materno, '')) LIKE ?
                    ORDER BY Nombre, Apellido_Paterno
                """, (limite, f'%{nombre_limpio}%'))
                
                pacientes = []
                for row in cursor.fetchall():
                    pacientes.append({
                        'id': row.id,
                        'nombre': row.Nombre,
                        'apellidoPaterno': row.Apellido_Paterno,
                        'apellidoMaterno': row.Apellido_Materno,
                        'cedula': row.Cedula,
                        'nombreCompleto': row.nombreCompleto.strip()
                    })
                
                return pacientes
                
        except Exception as e:
            logger.error(f"Error buscando pacientes por nombre: {e}")
            return []
    
    # ===============================
    # OPERACIONES DE TRABAJADORES (mejoradas)
    # ===============================
    
    def obtener_trabajadores_enfermeria(self) -> List[Dict[str, Any]]:
        """✅ CORREGIDO: Obtiene trabajadores con estructura completa para QML"""
        try:
            with self.db.get_connection() as conn:
                cursor = conn.cursor()
                cursor.execute("""
                    SELECT 
                        id,
                        CONCAT(Nombre, ' ', Apellido_Paterno, ' ', ISNULL(Apellido_Materno, '')) as NombreCompleto,
                        Nombre,
                        Apellido_Paterno,
                        ISNULL(Apellido_Materno, '') as Apellido_Materno,
                        Id_Tipo_Trabajador,
                        ISNULL(Matricula, '') as Matricula,
                        ISNULL(Especialidad, '') as Especialidad
                    FROM Trabajadores
                    ORDER BY Nombre, Apellido_Paterno
                """)
                
                trabajadores = []
                for row in cursor.fetchall():
                    trabajadores.append({
                        'id': row.id,
                        'nombreCompleto': row.NombreCompleto.strip(),
                        'nombre': row.Nombre,
                        'apellidoPaterno': row.Apellido_Paterno,
                        'apellidoMaterno': row.Apellido_Materno,
                        'tipoTrabajador': row.Id_Tipo_Trabajador,
                        'matricula': row.Matricula,
                        'especialidad': row.Especialidad
                    })
                
                logger.info(f"Obtenidos {len(trabajadores)} trabajadores de enfermería")
                return trabajadores
                
        except Exception as e:
            logger.error(f"Error obteniendo trabajadores de enfermería: {e}")
            return []
    
    def buscar_procedimientos(self, termino_busqueda: str, limit: int = 50) -> List[Dict[str, Any]]:
        """Búsqueda de procedimientos por término en base de datos"""
        try:
            with self.db.get_connection() as conn:
                cursor = conn.cursor()
                
                query = """
                    SELECT 
                        e.id,
                        e.Cantidad,
                        e.Fecha,
                        e.Tipo,
                        CONCAT(p.Nombre, ' ', p.Apellido_Paterno, ' ', ISNULL(p.Apellido_Materno, '')) as NombrePaciente,
                        ISNULL(p.Cedula, '') as Cedula,
                        ISNULL(tp.Nombre, 'Procedimiento General') as TipoProcedimiento,
                        CASE 
                            WHEN e.Tipo = 'Emergencia' THEN ISNULL(tp.Precio_Emergencia, 0)
                            ELSE ISNULL(tp.Precio_Normal, 0)
                        END as PrecioUnitario,
                        (e.Cantidad * CASE 
                            WHEN e.Tipo = 'Emergencia' THEN ISNULL(tp.Precio_Emergencia, 0)
                            ELSE ISNULL(tp.Precio_Normal, 0)
                        END) as PrecioTotal,
                        CONCAT(ISNULL(t.Nombre, ''), ' ', ISNULL(t.Apellido_Paterno, ''), ' ', ISNULL(t.Apellido_Materno, '')) as TrabajadorRealizador
                    FROM Enfermeria e
                    INNER JOIN Pacientes p ON e.Id_Paciente = p.id
                    LEFT JOIN Tipos_Procedimientos tp ON e.Id_Procedimiento = tp.id
                    LEFT JOIN Trabajadores t ON e.Id_Trabajador = t.id
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
                        'paciente': row.NombrePaciente.strip(),
                        'cedula': row.Cedula,
                        'tipoProcedimiento': row.TipoProcedimiento,
                        'cantidad': row.Cantidad,
                        'tipo': row.Tipo,
                        'precioUnitario': f"{float(row.PrecioUnitario):.2f}",
                        'precioTotal': f"{float(row.PrecioTotal):.2f}",
                        'fecha': row.Fecha.strftime('%Y-%m-%d') if row.Fecha else '',
                        'trabajadorRealizador': row.TrabajadorRealizador.strip()
                    })
                
                logger.info(f"Búsqueda '{termino_busqueda}': {len(procedimientos)} resultados")
                return procedimientos
                
        except Exception as e:
            logger.error(f"Error buscando procedimientos: {e}")
            return []

    # ===============================
    # REPORTES Y ESTADÍSTICAS (sin cambios)
    # ===============================
    
    def obtener_estadisticas_enfermeria(self, periodo: str = 'mes') -> Dict[str, Any]:
        """Obtiene estadísticas de procedimientos de enfermería"""
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
                        SUM(CASE WHEN e.Tipo = 'Normal' THEN ISNULL(tp.Precio_Normal, 0) * e.Cantidad 
                                 ELSE ISNULL(tp.Precio_Emergencia, 0) * e.Cantidad END) as IngresoTotal,
                        SUM(CASE WHEN e.Tipo = 'Normal' THEN e.Cantidad ELSE 0 END) as ProcedimientosNormales,
                        SUM(CASE WHEN e.Tipo = 'Emergencia' THEN e.Cantidad ELSE 0 END) as ProcedimientosEmergencia
                    FROM Enfermeria e
                    LEFT JOIN Tipos_Procedimientos tp ON e.Id_Procedimiento = tp.id
                    WHERE {filtro_fecha}
                """)
                
                estadisticas = cursor.fetchone()
                
                # Procedimientos más realizados
                cursor.execute(f"""
                    SELECT TOP 5
                        ISNULL(tp.Nombre, 'Procedimiento General') as Nombre,
                        COUNT(*) as Cantidad,
                        SUM(e.Cantidad) as TotalUnidades
                    FROM Enfermeria e
                    LEFT JOIN Tipos_Procedimientos tp ON e.Id_Procedimiento = tp.id
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