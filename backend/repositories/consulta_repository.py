from typing import List, Dict, Any, Optional, Tuple
from datetime import datetime, timedelta

from ..core.base_repository import BaseRepository
from ..core.excepciones import (
    ValidationError, ExceptionHandler, validate_required
)
from ..core.cache_system import cached_query
from ..core.utils import (
    get_current_datetime, format_date_for_db, parse_date_from_str,
    get_date_range_query, validate_required_string, safe_float
)

class ConsultaRepository(BaseRepository):
    """Repository para gestión de Consultas Médicas - CORREGIDO con nombres reales de BD"""
    
    def __init__(self):
        super().__init__('Consultas', 'consultas')
        print("🩺 ConsultaRepository inicializado con gestión de pacientes")
    
    # ===============================
    # IMPLEMENTACIÓN ABSTRACTA
    # ===============================
    
    def get_active(self) -> List[Dict[str, Any]]:
        """Obtiene consultas recientes con información completa"""
        return self.get_recent_consultations(days=30)
    
    # ===============================
    # GESTIÓN DE PACIENTES - CORREGIDO
    # ===============================
    
    def search_patient_by_cedula_exact(self, cedula: str) -> Optional[Dict[str, Any]]:
        """Busca paciente por cédula exacta"""
        try:
            if not cedula or len(cedula.strip()) < 5:
                return None
            
            cedula_clean = cedula.strip()
            
            query = """
            SELECT 
                id,
                Nombre,
                Apellido_Paterno,
                Apellido_Materno,
                Cedula,
                CONCAT(Nombre, ' ', Apellido_Paterno, ' ', ISNULL(Apellido_Materno, '')) as nombre_completo
            FROM Pacientes
            WHERE Cedula = ?
            """
            
            result = self._execute_query(query, (cedula_clean,), fetch_one=True)
            
            if result:
                print(f"👤 Paciente encontrado por cédula: {cedula_clean} -> {result['nombre_completo']}")
                return result
            
            return None
            
        except Exception as e:
            print(f"⚠️ Error buscando paciente por cédula: {e}")
            return None
    
    def search_patients_by_cedula_partial(self, cedula: str, limit: int = 5) -> List[Dict[str, Any]]:
        """Busca pacientes por cédula parcial (para sugerencias)"""
        try:
            if not cedula or len(cedula.strip()) < 3:
                return []
            
            cedula_clean = cedula.strip()
            
            query = """
            SELECT TOP (?)
                id,
                Nombre,
                Apellido_Paterno, 
                Apellido_Materno,
                Cedula,
                CONCAT(Nombre, ' ', Apellido_Paterno, ' ', ISNULL(Apellido_Materno, '')) as nombre_completo
            FROM Pacientes
            WHERE Cedula LIKE ?
            ORDER BY 
                CASE WHEN Cedula = ? THEN 1 ELSE 2 END,
                Cedula
            """
            
            search_pattern = f"%{cedula_clean}%"
            return self._execute_query(query, (limit, search_pattern, cedula_clean))
            
        except Exception as e:
            print(f"⚠️ Error en búsqueda parcial por cédula: {e}")
            return []
    
    def buscar_o_crear_paciente_simple(self, nombre: str, apellido_paterno: str, 
                              apellido_materno: str = "", cedula: str = "") -> int:
        """
        ✅ MÉTODO CORREGIDO - Busca paciente de forma inteligente antes de crear uno nuevo
        
        Estrategia de búsqueda:
        1. Si hay cédula → buscar por cédula exacta
        2. Si no encuentra por cédula o no hay cédula → buscar por nombre completo
        3. Solo si no encuentra por ningún método → crear nuevo paciente
        """
        try:
            nombre = nombre.strip()
            apellido_paterno = apellido_paterno.strip()
            apellido_materno = apellido_materno.strip()
            cedula_clean = cedula.strip() if cedula else None
            
            # Validaciones básicas (sin cédula obligatoria)
            if not nombre or len(nombre) < 2:
                raise ValidationError("nombre", nombre, "Nombre es obligatorio")
            if not apellido_paterno or len(apellido_paterno) < 2:
                raise ValidationError("apellido_paterno", apellido_paterno, "Apellido paterno es obligatorio")
            
            print(f"🔍 Buscando paciente: {nombre} {apellido_paterno} {apellido_materno} - Cédula: {cedula_clean or 'N/A'}")
            
            # ✅ ESTRATEGIA 1: Buscar por cédula si existe y es válida
            if cedula_clean and len(cedula_clean) >= 5:
                print(f"📋 Buscando por cédula: {cedula_clean}")
                existing_patient = self.search_patient_by_cedula_exact(cedula_clean)
                if existing_patient:
                    print(f"✅ Paciente encontrado por cédula: {existing_patient['nombre_completo']} (ID: {existing_patient['id']})")
                    return existing_patient['id']
                else:
                    print(f"❌ No se encontró paciente con cédula: {cedula_clean}")
            
            # ✅ ESTRATEGIA 2: Buscar por nombre completo (NUEVA LÓGICA)
            nombre_completo_busqueda = f"{nombre} {apellido_paterno} {apellido_materno}".strip()
            print(f"👤 Buscando por nombre completo: '{nombre_completo_busqueda}'")
            
            # Usar el método existente de búsqueda por nombre
            pacientes_por_nombre = self.search_patient_by_full_name(nombre_completo_busqueda, limite=10)
            
            if pacientes_por_nombre:
                # ✅ BUSCAR COINCIDENCIA EXACTA O MUY SIMILAR
                paciente_encontrado = self._encontrar_mejor_coincidencia_nombre(
                    nombre, apellido_paterno, apellido_materno, pacientes_por_nombre
                )
                
                if paciente_encontrado:
                    print(f"✅ Paciente encontrado por nombre: {paciente_encontrado['nombre_completo']} (ID: {paciente_encontrado['id']})")
                    return paciente_encontrado['id']
            
            print(f"❌ No se encontró paciente existente")
            
            # ✅ ESTRATEGIA 3: Crear nuevo paciente solo si no se encontró por ningún método
            print(f"➕ Creando nuevo paciente: {nombre} {apellido_paterno} {apellido_materno}")
            
            query = """
            INSERT INTO Pacientes (Nombre, Apellido_Paterno, Apellido_Materno, Cedula)
            OUTPUT INSERTED.id
            VALUES (?, ?, ?, ?)
            """
            
            result = self._execute_query(query, (nombre, apellido_paterno, apellido_materno, cedula_clean), fetch_one=True)
            patient_id = result['id'] if result else None
            
            if patient_id:
                print(f"✅ Nuevo paciente creado: {nombre} {apellido_paterno} - ID: {patient_id}")
                return patient_id
            else:
                raise ValidationError("paciente", None, "Error creando paciente en base de datos")
            
        except Exception as e:
            print(f"❌ Error gestionando paciente: {e}")
            raise ValidationError("paciente", str(e), "Error creando/buscando paciente")
    
    # ===============================
    # CRUD ESPECÍFICO - CORREGIDO
    # ===============================
    
    def create_consultation(self, usuario_id: int, paciente_id: int, especialidad_id: int,
                       detalles: str, tipo_consulta: str = "Normal", fecha: datetime = None) -> int:
        """Crea nueva consulta médica"""
        
        # Validaciones
        validate_required(usuario_id, "usuario_id")
        validate_required(paciente_id, "paciente_id") 
        validate_required(especialidad_id, "especialidad_id")
        detalles = validate_required_string(detalles, "detalles", 5)
        
        # Verificar entidades
        if not self._user_exists(usuario_id):
            raise ValidationError("usuario_id", usuario_id, "Usuario no encontrado")
        if not self._patient_exists(paciente_id):
            raise ValidationError("paciente_id", paciente_id, "Paciente no encontrado")
        if not self._specialty_exists(especialidad_id):
            raise ValidationError("especialidad_id", especialidad_id, "Especialidad no encontrada")
        
        # Fecha actual si no se proporciona
        if fecha is None:
            fecha = get_current_datetime()
        
        # Validar tipo_consulta - CORREGIDO para coincidir con BD
        if tipo_consulta.lower() not in ['normal', 'emergencia']:
            tipo_consulta = "Normal"
        else:
            tipo_consulta = tipo_consulta.capitalize()
        
        # Crear consulta - NOMBRES CORREGIDOS DE LA BD
        consultation_data = {
            'Id_Usuario': usuario_id,
            'Id_Paciente': paciente_id,
            'Id_Especialidad': especialidad_id,
            'Fecha': fecha,
            'Detalles': detalles.strip(),
            'Tipo_Consulta': tipo_consulta  # CORREGIDO: Tipo_Consulta no tipo_consulta
        }
        
        consultation_id = self.insert(consultation_data)
        if consultation_id:
            # AGREGAR: Invalidar cache inmediatamente después de crear
            self.invalidate_consultation_caches()
            print(f"🔄 Cache de consultas invalidado después de crear consulta {consultation_id}")
            
            print(f"🩺 Consulta creada: Paciente ID {paciente_id} - Consulta ID: {consultation_id}")
        
        return consultation_id
    
    def update_consultation(self, consulta_id: int, detalles: str = None, 
                   tipo_consulta: str = None, especialidad_id: int = None,
                   fecha: datetime = None) -> bool:
        """Actualiza consulta existente"""
        # Verificar existencia
        if not self.get_by_id(consulta_id):
            raise ValidationError("consulta_id", consulta_id, "Consulta no encontrada")
        
        update_data = {}
        
        if detalles is not None:
            detalles = validate_required_string(detalles, "detalles", 5)
            update_data['Detalles'] = detalles.strip()
        
        if tipo_consulta is not None:
            if tipo_consulta.lower() in ['normal', 'emergencia']:
                update_data['Tipo_Consulta'] = tipo_consulta.capitalize()
        
        # ✅ AGREGAR ESTE BLOQUE:
        if especialidad_id is not None:
            try:
                especialidad_id_int = int(especialidad_id)
                if especialidad_id_int > 0:
                    # Verificar que la especialidad existe
                    if self._specialty_exists(especialidad_id_int):
                        update_data['Id_Especialidad'] = especialidad_id_int
                        print(f"🏥 Repository: Especialidad actualizada a ID {especialidad_id_int}")
                    else:
                        print(f"❌ Repository: Especialidad {especialidad_id_int} no existe")
                else:
                    print(f"❌ Repository: ID de especialidad inválido: {especialidad_id_int}")
            except (ValueError, TypeError) as e:
                print(f"❌ Repository: Error procesando especialidad_id: {e}")
        
        if fecha is not None:
            update_data['Fecha'] = fecha
        
        if not update_data:
            return True
        
        success = self.update(consulta_id, update_data)
        if success:
            # Invalidar cache después de actualizar
            self.invalidate_consultation_caches()
            print(f"🔄 Cache invalidado después de actualizar consulta {consulta_id}")
            print(f"🩺 Consulta actualizada: ID {consulta_id}")
        
        return success
    
    # ===============================
    # CONSULTAS CON RELACIONES COMPLETAS - TOTALMENTE CORREGIDO
    # ===============================
    
    #@cached_query('consultas_completas', ttl=300)  # CAMBIAR: 30 segundos en lugar de 180
    def get_all_with_details(self, limit: int = 100) -> List[Dict[str, Any]]:
        """Obtiene consultas con información completa - SQL SIMPLIFICADO"""
        query = """
        SELECT 
            c.id, 
            c.Fecha,
            c.Detalles, 
            c.Tipo_Consulta as tipo_consulta,
            CONCAT(p.Nombre, ' ', p.Apellido_Paterno, ' ', ISNULL(p.Apellido_Materno, '')) as paciente_completo,
            p.Cedula as paciente_cedula,
            ISNULL(e.Nombre, 'Sin especialidad') as especialidad_nombre,
            ISNULL(e.Precio_Normal, 0) as Precio_Normal, 
            ISNULL(e.Precio_Emergencia, 0) as Precio_Emergencia,
            ISNULL(CONCAT('Dr. ', d.Nombre, ' ', d.Apellido_Paterno, ' ', ISNULL(d.Apellido_Materno, '')), 'Sin doctor') as doctor_nombre,
            CONCAT(ISNULL(e.Nombre, 'Sin especialidad'), ' - ', ISNULL(CONCAT('Dr. ', d.Nombre, ' ', d.Apellido_Paterno), 'Sin doctor')) as especialidad_doctor,
            CASE 
                WHEN c.Tipo_Consulta = 'Emergencia' THEN ISNULL(e.Precio_Emergencia, 0)
                ELSE ISNULL(e.Precio_Normal, 0)
            END as precio
        FROM Consultas c
        LEFT JOIN Pacientes p ON c.Id_Paciente = p.id
        LEFT JOIN Especialidad e ON c.Id_Especialidad = e.id
        LEFT JOIN Doctores d ON e.Id_Doctor = d.id
        ORDER BY c.Fecha DESC
        OFFSET 0 ROWS FETCH NEXT ? ROWS ONLY
        """
        
        result = self._execute_query(query, (limit,))
        #print(f"🔍 Query devolvió {len(result)} consultas de BD")
        return result
    
    def get_consultation_by_id_complete(self, consulta_id: int) -> Optional[Dict[str, Any]]:
        """Obtiene consulta específica con información completa - ACTUALIZADO para Trabajadores"""
        query = """
        SELECT 
            c.id, c.Fecha, 
            CAST(c.Detalles AS VARCHAR(MAX)) as Detalles,
            c.Tipo_Consulta as tipo_consulta,
            
            -- Paciente (CON CÉDULA)
            p.id as paciente_id,
            CONCAT(p.Nombre, ' ', p.Apellido_Paterno, ' ', ISNULL(p.Apellido_Materno, '')) as paciente_completo,
            p.Nombre as paciente_nombre, 
            p.Apellido_Paterno as paciente_apellido_p,
            p.Apellido_Materno as paciente_apellido_m,
            p.Cedula as paciente_cedula,
            
            -- Especialidad/Servicio
            e.id as especialidad_id, 
            e.Nombre as especialidad_nombre, 
            e.Detalles as especialidad_detalles,
            e.Precio_Normal, 
            e.Precio_Emergencia,
            
            -- Médicos asignados a esta especialidad (pueden ser varios)
            STRING_AGG(
                CONCAT('Dr. ', t.Nombre, ' ', t.Apellido_Paterno, ' ', ISNULL(t.Apellido_Materno, '')),
                ', '
            ) as medicos_asignados,
            STRING_AGG(CAST(t.id AS VARCHAR), ',') as medicos_ids,
            STRING_AGG(t.Especialidad, ', ') as medicos_especialidades,
            STRING_AGG(t.Matricula, ', ') as medicos_matriculas,
            
            -- Usuario que registró
            u.id as usuario_id,
            CONCAT(u.Nombre, ' ', u.Apellido_Paterno) as usuario_registro,
            u.nombre_usuario as usuario_username
            
        FROM Consultas c
        INNER JOIN Pacientes p ON c.Id_Paciente = p.id
        INNER JOIN Especialidad e ON c.Id_Especialidad = e.id
        LEFT JOIN Trabajador_Especialidad te ON e.id = te.Id_Especialidad
        LEFT JOIN Trabajadores t ON te.Id_Trabajador = t.id
        INNER JOIN Usuario u ON c.Id_Usuario = u.id
        WHERE c.id = ?
        GROUP BY 
            c.id, c.Fecha, 
            CAST(c.Detalles AS VARCHAR(MAX)),
            c.Tipo_Consulta,
            p.id, p.Nombre, p.Apellido_Paterno, p.Apellido_Materno, p.Cedula,
            e.id, e.Nombre, e.Detalles, e.Precio_Normal, e.Precio_Emergencia,
            u.id, u.Nombre, u.Apellido_Paterno, u.nombre_usuario
        """
        return self._execute_query(query, (consulta_id,), fetch_one=True)
    
    # ===============================
    # BÚSQUEDAS POR FECHAS - CORREGIDO
    # ===============================
    
    def get_consultations_by_date(self, fecha: datetime) -> List[Dict[str, Any]]:
        """Obtiene consultas de una fecha específica"""
        start_date = fecha.replace(hour=0, minute=0, second=0, microsecond=0)
        end_date = start_date + timedelta(days=1)
        
        return self.get_consultations_by_date_range(start_date, end_date)
    
    def get_consultations_by_date_range(self, start_date: datetime, end_date: datetime) -> List[Dict[str, Any]]:
        """Obtiene consultas en rango de fechas - CORREGIDO CON PRECIOS"""
        query = """
            SELECT 
                c.id,
                c.Fecha,
                CAST(c.Detalles AS VARCHAR(MAX)) as Detalles,
                c.Tipo_Consulta,
                c.Id_Especialidad,
                
                -- Información del paciente
                CONCAT(p.Nombre, ' ', p.Apellido_Paterno, ' ', p.Apellido_Materno) as paciente_nombre,
                p.Cedula as paciente_cedula,
                
                -- Información de la especialidad
                e.Nombre as especialidad_nombre,
                e.Precio_Normal,
                e.Precio_Emergencia,
                
                -- Médicos asignados
                STRING_AGG(
                    CONCAT('Dr. ', t.Nombre, ' ', t.Apellido_Paterno),
                    ', '
                ) as medicos_asignados,
                
                -- Usuario que registró
                CONCAT(u.Nombre, ' ', u.Apellido_Paterno) as usuario_nombre
                
            FROM Consultas c
            INNER JOIN Pacientes p ON c.Id_Paciente = p.id
            LEFT JOIN Especialidad e ON c.Id_Especialidad = e.id
            LEFT JOIN Trabajador_Especialidad te ON e.id = te.Id_Especialidad
            LEFT JOIN Trabajadores t ON te.Id_Trabajador = t.id
            INNER JOIN Usuario u ON c.Id_Usuario = u.id
            WHERE c.Fecha BETWEEN ? AND ?
            GROUP BY 
                c.id, c.Fecha, 
                CAST(c.Detalles AS VARCHAR(MAX)),
                c.Tipo_Consulta, c.Id_Especialidad,
                p.Nombre, p.Apellido_Paterno, p.Apellido_Materno, p.Cedula,
                e.Nombre, e.Precio_Normal, e.Precio_Emergencia,
                u.Nombre, u.Apellido_Paterno
            ORDER BY c.Fecha DESC
            """
        return self._execute_query(query, (start_date, end_date))
    
    @cached_query('consultas_hoy', ttl=60)
    def get_today_consultations(self) -> List[Dict[str, Any]]:
        """Obtiene consultas del día actual"""
        today = datetime.now().replace(hour=0, minute=0, second=0, microsecond=0)
        return self.get_consultations_by_date(today)
    
    def get_recent_consultations(self, days: int = 7) -> List[Dict[str, Any]]:
        """Obtiene consultas recientes - TOTALMENTE CORREGIDO"""
        query = """
            SELECT 
                c.id, c.Fecha, 
                CAST(c.Detalles AS VARCHAR(MAX)) as Detalles,  -- ← Convertir TEXT a VARCHAR
                c.Tipo_Consulta,
                c.Id_Paciente, c.Id_Especialidad, c.Id_Usuario,
                
                -- Información del paciente
                CONCAT(p.Nombre, ' ', p.Apellido_Paterno, ' ', p.Apellido_Materno) as paciente_nombre_completo,
                p.Cedula as paciente_cedula,
                
                -- Información de la especialidad
                ISNULL(e.Nombre, 'Sin especialidad') as especialidad_nombre,
                e.Precio_Normal as especialidad_precio_normal,
                e.Precio_Emergencia as especialidad_precio_emergencia,
                
                -- Información del médico (a través de Trabajador_Especialidad)
                STRING_AGG(
                    CONCAT('Dr. ', t.Nombre, ' ', t.Apellido_Paterno), 
                    ', '
                ) as medicos_asignados,
                
                -- Información del usuario que registró
                CONCAT(u.Nombre, ' ', u.Apellido_Paterno) as usuario_nombre
                
            FROM Consultas c
            INNER JOIN Pacientes p ON c.Id_Paciente = p.id
            LEFT JOIN Especialidad e ON c.Id_Especialidad = e.id
            LEFT JOIN Trabajador_Especialidad te ON e.id = te.Id_Especialidad
            LEFT JOIN Trabajadores t ON te.Id_Trabajador = t.id
            INNER JOIN Usuario u ON c.Id_Usuario = u.id
            WHERE c.Fecha >= DATEADD(day, -?, GETDATE())
            GROUP BY 
                c.id, c.Fecha, 
                CAST(c.Detalles AS VARCHAR(MAX)),
                c.Tipo_Consulta,
                c.Id_Paciente, c.Id_Especialidad, c.Id_Usuario,
                p.Nombre, p.Apellido_Paterno, p.Apellido_Materno, p.Cedula,
                e.Nombre, e.Precio_Normal, e.Precio_Emergencia,
                u.Nombre, u.Apellido_Paterno
            ORDER BY c.Fecha DESC
            OFFSET 0 ROWS FETCH NEXT 100 ROWS ONLY
            """
        return self._execute_query(query, (days,))
    
    def get_consultations_this_month(self) -> List[Dict[str, Any]]:
        """Obtiene consultas del mes actual"""
        now = get_current_datetime()
        start_of_month = now.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
        
        return self.get_consultations_by_date_range(start_of_month, now)
    
    # ===============================
    # BÚSQUEDAS POR ENTIDADES - CORREGIDAS
    # ===============================
    
    def get_consultations_by_patient(self, paciente_id: int, limit: int = 50) -> List[Dict[str, Any]]:
        """Obtiene historial de consultas de un paciente - CORREGIDO"""
        query = """
        SELECT c.id, c.Fecha, c.Detalles, c.Tipo_Consulta as tipo_consulta,
               e.Nombre as especialidad_nombre, e.Precio_Normal, e.Precio_Emergencia,
               CONCAT('Dr. ', d.Nombre, ' ', d.Apellido_Paterno, ' ', ISNULL(d.Apellido_Materno, '')) as doctor_completo,
               d.Especialidad as doctor_especialidad,
               CONCAT(u.Nombre, ' ', u.Apellido_Paterno) as usuario_registro
        FROM Consultas c
        INNER JOIN Especialidad e ON c.Id_Especialidad = e.id
        INNER JOIN Doctores d ON e.Id_Doctor = d.id
        INNER JOIN Usuario u ON c.Id_Usuario = u.id
        WHERE c.Id_Paciente = ?
        ORDER BY c.Fecha DESC
        OFFSET 0 ROWS FETCH NEXT ? ROWS ONLY
        """
        return self._execute_query(query, (paciente_id, limit))
    
    def get_consultations_by_doctor(self, medico_id: int, limit: int = 50) -> List[Dict[str, Any]]:
        """Obtiene consultas atendidas por un doctor - CORREGIDO"""
        query = """
        SELECT c.id, c.Fecha, c.Detalles, c.Tipo_Consulta as tipo_consulta,
               CONCAT(p.Nombre, ' ', p.Apellido_Paterno, ' ', ISNULL(p.Apellido_Materno, '')) as paciente_completo,
               p.Cedula as paciente_cedula,
               e.Nombre as especialidad_nombre, e.Precio_Normal, e.Precio_Emergencia,
               CONCAT(u.Nombre, ' ', u.Apellido_Paterno) as usuario_registro
        FROM Consultas c
        INNER JOIN Pacientes p ON c.Id_Paciente = p.id
        INNER JOIN Especialidad e ON c.Id_Especialidad = e.id
        INNER JOIN Usuario u ON c.Id_Usuario = u.id
        WHERE e.Id_Doctor = ?
        ORDER BY c.Fecha DESC
        OFFSET 0 ROWS FETCH NEXT ? ROWS ONLY
        """
        return self._execute_query(query, (medico_id, limit))
    
    def get_consultations_by_specialty(self, especialidad_id: int, limit: int = 50) -> List[Dict[str, Any]]:
        """Obtiene consultas por especialidad específica - CORREGIDO"""
        query = """
        SELECT c.id, c.Fecha, c.Detalles, c.Tipo_Consulta as tipo_consulta,
               CONCAT(p.Nombre, ' ', p.Apellido_Paterno, ' ', ISNULL(p.Apellido_Materno, '')) as paciente_completo,
               p.Cedula as paciente_cedula,
               CONCAT('Dr. ', d.Nombre, ' ', d.Apellido_Paterno) as doctor_nombre,
               CONCAT(u.Nombre, ' ', u.Apellido_Paterno) as usuario_registro
        FROM Consultas c
        INNER JOIN Pacientes p ON c.Id_Paciente = p.id
        INNER JOIN Especialidad e ON c.Id_Especialidad = e.id
        INNER JOIN Doctores d ON e.Id_Doctor = d.id
        INNER JOIN Usuario u ON c.Id_Usuario = u.id
        WHERE c.Id_Especialidad = ?
        ORDER BY c.Fecha DESC
        OFFSET 0 ROWS FETCH NEXT ? ROWS ONLY
        """
        return self._execute_query(query, (especialidad_id, limit))
    
    def get_consultations_by_user(self, usuario_id: int, limit: int = 50) -> List[Dict[str, Any]]:
        """Obtiene consultas registradas por un usuario - CORREGIDO"""
        query = """
        SELECT c.id, c.Fecha, c.Detalles, c.Tipo_Consulta as tipo_consulta,
               CONCAT(p.Nombre, ' ', p.Apellido_Paterno, ' ', ISNULL(p.Apellido_Materno, '')) as paciente_completo,
               p.Cedula as paciente_cedula,
               e.Nombre as especialidad_nombre,
               CONCAT('Dr. ', d.Nombre, ' ', d.Apellido_Paterno) as doctor_nombre
        FROM Consultas c
        INNER JOIN Pacientes p ON c.Id_Paciente = p.id
        INNER JOIN Especialidad e ON c.Id_Especialidad = e.id
        INNER JOIN Doctores d ON e.Id_Doctor = d.id
        WHERE c.Id_Usuario = ?
        ORDER BY c.Fecha DESC
        OFFSET 0 ROWS FETCH NEXT ? ROWS ONLY
        """
        return self._execute_query(query, (usuario_id, limit))
    
    def get_consultas_paginadas(self, page: int, limit: int = 5, filters: dict = None) -> dict:
        """Obtiene consultas con paginación - SQL SIMPLIFICADO"""
        offset = page * limit
        
        # Construir WHERE clause
        where_conditions = []
        params = []
        
        if filters and filters.get('tipo_consulta'):
            where_conditions.append("c.Tipo_Consulta = ?")
            params.append(filters['tipo_consulta'])
        
        if filters and filters.get('especialidad') and filters['especialidad'] != 'Todas':
            where_conditions.append("e.Nombre LIKE ?")
            params.append(f"%{filters['especialidad']}%")
        
        if filters and filters.get('busqueda'):
            busqueda = f"%{filters['busqueda']}%"
            where_conditions.append("""(
                p.Nombre LIKE ? OR 
                p.Apellido_Paterno LIKE ? OR 
                p.Apellido_Materno LIKE ? OR 
                p.Cedula LIKE ? OR 
                c.Detalles LIKE ? OR
                e.Nombre LIKE ?
            )""")
            params.extend([busqueda] * 6)
        
        if filters and filters.get('fecha_desde'):
            try:
                fecha_desde = datetime.fromisoformat(filters['fecha_desde'].replace('Z', ''))
                where_conditions.append("CAST(c.Fecha AS DATE) >= CAST(? AS DATE)")
                params.append(fecha_desde.strftime('%Y-%m-%d'))
            except ValueError:
                pass
        
        if filters and filters.get('fecha_hasta'):
            try:
                fecha_hasta = datetime.fromisoformat(filters['fecha_hasta'].replace('Z', ''))
                where_conditions.append("CAST(c.Fecha AS DATE) <= CAST(? AS DATE)")
                params.append(fecha_hasta.strftime('%Y-%m-%d'))
            except ValueError:
                pass
        
        where_clause = ""
        if where_conditions:
            where_clause = "WHERE " + " AND ".join(where_conditions)
        
        # Query principal simplificado
        query = f"""
        SELECT 
            c.id, 
            c.Fecha,
            c.Detalles, 
            c.Tipo_Consulta as tipo_consulta,
            CONCAT(p.Nombre, ' ', p.Apellido_Paterno, ' ', ISNULL(p.Apellido_Materno, '')) as paciente_completo,
            p.Cedula as paciente_cedula,
            ISNULL(e.Nombre, 'Sin especialidad') as especialidad_nombre,
            ISNULL(e.Precio_Normal, 0) as Precio_Normal, 
            ISNULL(e.Precio_Emergencia, 0) as Precio_Emergencia,
            ISNULL(CONCAT('Dr. ', d.Nombre, ' ', d.Apellido_Paterno, ' ', ISNULL(d.Apellido_Materno, '')), 'Sin doctor') as doctor_nombre,
            CONCAT(ISNULL(e.Nombre, 'Sin especialidad'), ' - ', ISNULL(CONCAT('Dr. ', d.Nombre, ' ', d.Apellido_Paterno), 'Sin doctor')) as especialidad_doctor,
            CASE 
                WHEN c.Tipo_Consulta = 'Emergencia' THEN ISNULL(e.Precio_Emergencia, 0)
                ELSE ISNULL(e.Precio_Normal, 0)
            END as precio
        FROM Consultas c
        LEFT JOIN Pacientes p ON c.Id_Paciente = p.id
        LEFT JOIN Especialidad e ON c.Id_Especialidad = e.id
        LEFT JOIN Doctores d ON e.Id_Doctor = d.id
        {where_clause}
        ORDER BY c.Fecha DESC
        OFFSET ? ROWS FETCH NEXT ? ROWS ONLY
        """
        
        count_query = f"""
        SELECT COUNT(*) as total 
        FROM Consultas c 
        LEFT JOIN Pacientes p ON c.Id_Paciente = p.id
        LEFT JOIN Especialidad e ON c.Id_Especialidad = e.id
        LEFT JOIN Doctores d ON e.Id_Doctor = d.id
        {where_clause}
        """
        
        try:
            params_with_pagination = params + [offset, limit]
            consultas = self._execute_query(query, params_with_pagination)
            
            total_result = self._execute_query(count_query, params, fetch_one=True)
            total = total_result['total'] if total_result else 0
            
            return {
                'consultas': consultas,
                'total': total,
                'page': page,
                'limit': limit,
                'total_pages': (total + limit - 1) // limit
            }
        except Exception as e:
            print(f"Error en get_consultas_paginadas: {e}")
            return {'consultas': [], 'total': 0, 'page': 0, 'total_pages': 0, 'limit': limit}
        
    # ===============================
    # BÚSQUEDAS AVANZADAS - CORREGIDAS
    # ===============================
    
    def search_consultations(self, search_term: str, start_date: datetime = None,
                           end_date: datetime = None, limit: int = 50) -> List[Dict[str, Any]]:
        """Búsqueda avanzada en consultas - CORREGIDO"""
        if not search_term:
            if start_date and end_date:
                return self.get_consultations_by_date_range(start_date, end_date)
            return []
        
        search_term = f"%{search_term.strip()}%"
        
        base_query = """
        SELECT c.id, c.Fecha, c.Detalles, c.Tipo_Consulta as tipo_consulta,
               CONCAT(p.Nombre, ' ', p.Apellido_Paterno, ' ', ISNULL(p.Apellido_Materno, '')) as paciente_completo,
               p.Cedula as paciente_cedula,
               e.Nombre as especialidad_nombre,
               CONCAT('Dr. ', d.Nombre, ' ', d.Apellido_Paterno, ' ', ISNULL(d.Apellido_Materno, '')) as doctor_completo
        FROM Consultas c
        INNER JOIN Pacientes p ON c.Id_Paciente = p.id
        INNER JOIN Especialidad e ON c.Id_Especialidad = e.id
        INNER JOIN Doctores d ON e.Id_Doctor = d.id
        WHERE (p.Nombre LIKE ? OR p.Apellido_Paterno LIKE ? OR p.Apellido_Materno LIKE ?
               OR d.Nombre LIKE ? OR d.Apellido_Paterno LIKE ? OR d.Apellido_Materno LIKE ?
               OR e.Nombre LIKE ? OR c.Detalles LIKE ? OR p.Cedula LIKE ?)
        """
        
        params = [search_term] * 9
        
        # Agregar filtros de fecha si se proporcionan
        if start_date and end_date:
            base_query += " AND c.Fecha BETWEEN ? AND ?"
            params.extend([start_date, end_date])
        
        base_query += " ORDER BY c.Fecha DESC OFFSET 0 ROWS FETCH NEXT ? ROWS ONLY"
        params.append(limit)
        
        return self._execute_query(base_query, tuple(params))
    
    def search_patient_by_full_name(self, nombre_completo: str, limite: int = 10) -> List[Dict[str, Any]]:
        """
        ✅ MÉTODO MEJORADO - Búsqueda más robusta por nombre completo
        
        Mejoras:
        - Búsqueda con múltiples estrategias
        - Manejo de apellidos opcionales
        - Ordenamiento por relevancia
        """
        try:
            if not nombre_completo or len(nombre_completo.strip()) < 3:
                return []
            
            nombre_limpio = nombre_completo.strip()
            print(f"🔍 Búsqueda mejorada por nombre: '{nombre_limpio}'")
            
            # ✅ ESTRATEGIA 1: Búsqueda exacta
            query_exacta = """
            SELECT TOP (?)
                id, Nombre, Apellido_Paterno, Apellido_Materno, Cedula,
                CONCAT(Nombre, ' ', Apellido_Paterno, ' ', ISNULL(Apellido_Materno, '')) as nombre_completo,
                1 as relevancia
            FROM Pacientes
            WHERE CONCAT(Nombre, ' ', Apellido_Paterno, ' ', ISNULL(Apellido_Materno, '')) = ?
            """
            
            resultados_exactos = self._execute_query(query_exacta, (limite, nombre_limpio))
            
            if resultados_exactos:
                print(f"✅ Encontradas {len(resultados_exactos)} coincidencias exactas")
                return resultados_exactos
            
            # ✅ ESTRATEGIA 2: Búsqueda con LIKE (contiene)
            query_like = """
            SELECT TOP (?)
                id, Nombre, Apellido_Paterno, Apellido_Materno, Cedula,
                CONCAT(Nombre, ' ', Apellido_Paterno, ' ', ISNULL(Apellido_Materno, '')) as nombre_completo,
                2 as relevancia
            FROM Pacientes
            WHERE CONCAT(Nombre, ' ', Apellido_Paterno, ' ', ISNULL(Apellido_Materno, '')) LIKE ?
            """
            
            pattern_like = f"%{nombre_limpio}%"
            resultados_like = self._execute_query(query_like, (limite, pattern_like))
            
            if resultados_like:
                print(f"✅ Encontradas {len(resultados_like)} coincidencias parciales")
                return resultados_like
            
            # ✅ ESTRATEGIA 3: Búsqueda por palabras individuales
            palabras = nombre_limpio.split()
            if len(palabras) >= 2:
                query_palabras = """
                SELECT TOP (?)
                    id, Nombre, Apellido_Paterno, Apellido_Materno, Cedula,
                    CONCAT(Nombre, ' ', Apellido_Paterno, ' ', ISNULL(Apellido_Materno, '')) as nombre_completo,
                    3 as relevancia
                FROM Pacientes
                WHERE Nombre LIKE ? OR Apellido_Paterno LIKE ?
                ORDER BY 
                    CASE WHEN Nombre LIKE ? THEN 1 ELSE 2 END,
                    Nombre, Apellido_Paterno
                """
                
                palabra1_pattern = f"%{palabras[0]}%"
                palabra2_pattern = f"%{palabras[1]}%" if len(palabras) > 1 else palabra1_pattern
                
                resultados_palabras = self._execute_query(query_palabras, (
                    limite, palabra1_pattern, palabra2_pattern, palabra1_pattern
                ))
                
                if resultados_palabras:
                    print(f"✅ Encontradas {len(resultados_palabras)} coincidencias por palabras")
                    return resultados_palabras
            
            print(f"❌ No se encontraron pacientes con nombre: '{nombre_limpio}'")
            return []
            
        except Exception as e:
            print(f"❌ Error en búsqueda mejorada por nombre: {e}")
            return []
    
    # ===============================
    # ESTADÍSTICAS - CORREGIDAS
    # ===============================
    
    @cached_query('stats_consultas', ttl=300)
    def get_consultation_statistics(self) -> Dict[str, Any]:
        """Estadísticas completas de consultas - CORREGIDO"""
        # Estadísticas generales básicas
        general_query = """
        SELECT 
            COUNT(*) as total_consultas,
            COUNT(DISTINCT Id_Paciente) as pacientes_unicos,
            COUNT(DISTINCT Id_Especialidad) as especialidades_utilizadas,
            COUNT(CASE WHEN Tipo_Consulta = 'Normal' THEN 1 END) as consultas_normales,
            COUNT(CASE WHEN Tipo_Consulta = 'Emergencia' THEN 1 END) as consultas_emergencia
        FROM Consultas
        """
        
        # Promedio de días entre consultas (consulta separada)
        dias_promedio_query = """
        WITH ConsultasConLag AS (
            SELECT 
                Id_Paciente,
                Fecha,
                LAG(Fecha) OVER (PARTITION BY Id_Paciente ORDER BY Fecha) as fecha_anterior
            FROM Consultas
        )
        SELECT AVG(CAST(DATEDIFF(day, fecha_anterior, Fecha) AS FLOAT)) as dias_promedio_entre_consultas
        FROM ConsultasConLag
        WHERE fecha_anterior IS NOT NULL
        """
        
        general_stats = self._execute_query(general_query, fetch_one=True) or {}
        dias_promedio = self._execute_query(dias_promedio_query, fetch_one=True) or {}
        
        # Combinar resultados
        if general_stats and dias_promedio:
            general_stats['dias_promedio_entre_consultas'] = dias_promedio.get('dias_promedio_entre_consultas', 0)
        
        # Resto de las consultas...
        monthly_query = """
        SELECT 
            FORMAT(Fecha, 'yyyy-MM') as mes,
            COUNT(*) as cantidad_consultas,
            COUNT(DISTINCT Id_Paciente) as pacientes_unicos
        FROM Consultas
        WHERE Fecha >= DATEADD(month, -12, GETDATE())
        GROUP BY FORMAT(Fecha, 'yyyy-MM')
        ORDER BY mes DESC
        """
        
        specialty_query = """
        SELECT e.Nombre as especialidad,
            COUNT(c.id) as total_consultas,
            COUNT(DISTINCT c.Id_Paciente) as pacientes_unicos,
            AVG(e.Precio_Normal) as precio_promedio
        FROM Consultas c
        INNER JOIN Especialidad e ON c.Id_Especialidad = e.id
        GROUP BY e.id, e.Nombre
        ORDER BY total_consultas DESC
        """
        
        doctor_query = """
        SELECT CONCAT('Dr. ', d.Nombre, ' ', d.Apellido_Paterno) as doctor,
            d.Especialidad as doctor_especialidad,
            COUNT(c.id) as total_consultas,
            COUNT(DISTINCT c.Id_Paciente) as pacientes_unicos
        FROM Consultas c
        INNER JOIN Especialidad e ON c.Id_Especialidad = e.id
        INNER JOIN Doctores d ON e.Id_Doctor = d.id
        GROUP BY d.id, d.Nombre, d.Apellido_Paterno, d.Especialidad
        ORDER BY total_consultas DESC
        """
        
        monthly_stats = self._execute_query(monthly_query)
        specialty_stats = self._execute_query(specialty_query)
        doctor_stats = self._execute_query(doctor_query)
        
        return {
            'general': general_stats,
            'por_mes': monthly_stats,
            'por_especialidad': specialty_stats,
            'por_doctor': doctor_stats
        }
    
    @cached_query('consultas_today_stats', ttl=60)
    def get_today_statistics(self) -> Dict[str, Any]:
        """Estadísticas del día actual - CORREGIDO"""
        today_start = datetime.now().replace(hour=0, minute=0, second=0, microsecond=0)
        today_end = today_start + timedelta(days=1)
        
        query = """
        SELECT 
            COUNT(*) as consultas_hoy,
            COUNT(DISTINCT Id_Paciente) as pacientes_hoy,
            COUNT(DISTINCT e.Id_Doctor) as doctores_activos_hoy
        FROM Consultas c
        INNER JOIN Especialidad e ON c.Id_Especialidad = e.id
        WHERE c.Fecha BETWEEN ? AND ?
        """
        
        return self._execute_query(query, (today_start, today_end), fetch_one=True)
    
    def get_consultation_trends(self, months: int = 6) -> List[Dict[str, Any]]:
        """Obtiene tendencias de consultas por mes - CORREGIDO"""
        query = """
        SELECT 
            FORMAT(Fecha, 'yyyy-MM') as mes,
            FORMAT(Fecha, 'MMMM yyyy', 'es-ES') as mes_nombre,
            COUNT(*) as total_consultas,
            COUNT(DISTINCT Id_Paciente) as pacientes_unicos,
            COUNT(DISTINCT e.Id_Doctor) as doctores_activos,
            AVG(e.Precio_Normal) as precio_promedio
        FROM Consultas c
        INNER JOIN Especialidad e ON c.Id_Especialidad = e.id
        WHERE c.Fecha >= DATEADD(month, -?, GETDATE())
        GROUP BY FORMAT(Fecha, 'yyyy-MM'), FORMAT(Fecha, 'MMMM yyyy', 'es-ES')
        ORDER BY mes DESC
        """
        return self._execute_query(query, (months,))
    
    def get_most_frequent_patients(self, limit: int = 20) -> List[Dict[str, Any]]:
        """Pacientes con más consultas - CORREGIDO"""
        query = """
        SELECT 
            p.id as paciente_id,
            CONCAT(p.Nombre, ' ', p.Apellido_Paterno, ' ', ISNULL(p.Apellido_Materno, '')) as paciente_completo,
            p.Cedula as paciente_cedula,
            COUNT(c.id) as total_consultas,
            MAX(c.Fecha) as ultima_consulta,
            MIN(c.Fecha) as primera_consulta,
            COUNT(DISTINCT c.Id_Especialidad) as especialidades_diferentes
        FROM Consultas c
        INNER JOIN Pacientes p ON c.Id_Paciente = p.id
        GROUP BY p.id, p.Nombre, p.Apellido_Paterno, p.Apellido_Materno, p.Cedula
        ORDER BY total_consultas DESC, p.Nombre
        OFFSET 0 ROWS FETCH NEXT ? ROWS ONLY
        """
        return self._execute_query(query, (limit,))
    
    # ===============================
    # UTILIDADES Y VALIDACIONES - CORREGIDAS
    # ===============================
    
    def _user_exists(self, usuario_id: int) -> bool:
        """Verifica si existe el usuario"""
        query = "SELECT COUNT(*) as count FROM Usuario WHERE id = ? AND Estado = 1"
        result = self._execute_query(query, (usuario_id,), fetch_one=True)
        return result['count'] > 0 if result else False
    
    def _patient_exists(self, paciente_id: int) -> bool:
        """Verifica si existe el paciente"""
        query = "SELECT COUNT(*) as count FROM Pacientes WHERE id = ?"
        result = self._execute_query(query, (paciente_id,), fetch_one=True)
        return result['count'] > 0 if result else False
    
    def _specialty_exists(self, especialidad_id: int) -> bool:
        """Verifica si existe la especialidad"""
        query = "SELECT COUNT(*) as count FROM Especialidad WHERE id = ?"
        result = self._execute_query(query, (especialidad_id,), fetch_one=True)
        return result['count'] > 0 if result else False
    
    def get_patient_consultation_count(self, paciente_id: int) -> int:
        """Obtiene número total de consultas de un paciente"""
        return self.count("Id_Paciente = ?", (paciente_id,))
    
    def get_doctor_consultation_count(self, medico_id: int) -> int:
        """Obtiene número total de consultas atendidas por un doctor"""
        query = """
        SELECT COUNT(c.id) as count
        FROM Consultas c
        INNER JOIN Especialidad e ON c.Id_Especialidad = e.id
        WHERE e.Id_Doctor = ?
        """
        result = self._execute_query(query, (medico_id,), fetch_one=True)
        return result['count'] if result else 0
    
    def validate_consultation_exists(self, consulta_id: int) -> bool:
        """Valida que la consulta existe"""
        return self.exists('id', consulta_id)
    
    def _encontrar_mejor_coincidencia_nombre(self, nombre: str, apellido_paterno: str, 
                                  apellido_materno: str, candidatos: List[Dict]) -> Optional[Dict]:
        """
        ✅ MÉTODO MEJORADO - Encuentra la mejor coincidencia por nombre entre los candidatos
        Más tolerante con coincidencias para evitar duplicados
        
        Prioridades de coincidencia:
        1. Coincidencia exacta completa
        2. Coincidencia de nombre + apellido paterno (ignorando apellido materno)
        3. Coincidencia similar con tolerancia a errores menores
        """
        if not candidatos:
            return None
        
        nombre_target = nombre.lower().strip()
        apellido_p_target = apellido_paterno.lower().strip()
        apellido_m_target = apellido_materno.lower().strip() if apellido_materno else ""
        
        print(f"🎯 Buscando mejor coincidencia para: '{nombre_target} {apellido_p_target} {apellido_m_target}'")
        
        mejor_candidato = None
        mejor_score = 0
        
        for candidato in candidatos:
            nombre_db = candidato.get('Nombre', '').lower().strip()
            apellido_p_db = candidato.get('Apellido_Paterno', '').lower().strip()
            apellido_m_db = candidato.get('Apellido_Materno', '').lower().strip() if candidato.get('Apellido_Materno') else ""
            
            score = 0
            
            # ✅ COINCIDENCIA EXACTA COMPLETA (máxima prioridad)
            if (nombre_db == nombre_target and 
                apellido_p_db == apellido_p_target and 
                apellido_m_db == apellido_m_target):
                print(f"🎯 Coincidencia exacta completa: {candidato['nombre_completo']}")
                return candidato
            
            # ✅ COINCIDENCIA NOMBRE + APELLIDO PATERNO (alta prioridad) - IGNORAR APELLIDO MATERNO
            if nombre_db == nombre_target and apellido_p_db == apellido_p_target:
                score = 95  # ✅ AUMENTADO para dar más prioridad
                print(f"🎯 Coincidencia nombre + apellido paterno: {candidato['nombre_completo']} (score: {score})")
            
            # ✅ COINCIDENCIA FLEXIBLE: nombre + apellido con tolerancia
            elif (self._nombres_similares(nombre_db, nombre_target) and 
                self._nombres_similares(apellido_p_db, apellido_p_target)):
                score = 85  # ✅ AUMENTADO para ser más tolerante
                print(f"🎯 Coincidencia similar: {candidato['nombre_completo']} (score: {score})")
            
            # ✅ NUEVA: Coincidencia solo por nombre completo concatenado
            elif self._nombres_similares(f"{nombre_db} {apellido_p_db}", f"{nombre_target} {apellido_p_target}"):
                score = 80
                print(f"🎯 Coincidencia nombre completo: {candidato['nombre_completo']} (score: {score})")
            
            # ✅ COINCIDENCIA PARCIAL (baja prioridad)
            elif (nombre_db == nombre_target or apellido_p_db == apellido_p_target):
                score = 60  # ✅ AUMENTADO ligeramente
                print(f"🎯 Coincidencia parcial: {candidato['nombre_completo']} (score: {score})")
            
            # Actualizar mejor candidato
            if score > mejor_score:
                mejor_score = score
                mejor_candidato = candidato
        
        # ✅ UMBRAL REDUCIDO para ser más tolerante
        if mejor_score >= 60:  # ✅ REDUCIDO de 70 a 60
            print(f"✅ Mejor candidato seleccionado: {mejor_candidato['nombre_completo']} (score: {mejor_score})")
            return mejor_candidato
        else:
            print(f"❌ Ningún candidato cumple el umbral mínimo (mejor score: {mejor_score})")
            return None
        
    def _nombres_similares(self, nombre1: str, nombre2: str, tolerancia: float = 0.75) -> bool:
        """
        ✅ MÉTODO MEJORADO - Compara similaridad entre nombres con tolerancia a errores menores
        Más permisivo para evitar duplicados
        """
        if not nombre1 or not nombre2:
            return False
        
        if nombre1 == nombre2:
            return True
        
        # ✅ TOLERANCIA MEJORADA para nombres con acentos o ligeras diferencias
        nombre1_norm = self._normalizar_texto_completo(nombre1)
        nombre2_norm = self._normalizar_texto_completo(nombre2)
        
        if nombre1_norm == nombre2_norm:
            return True
        
        # Similaridad simple basada en caracteres comunes
        len_max = max(len(nombre1), len(nombre2))
        len_min = min(len(nombre1), len(nombre2))
        
        if len_max == 0:
            return False
        
        # ✅ MÁS TOLERANTE: Si uno es significativamente más largo que el otro
        if len_min / len_max < 0.5:  # ✅ REDUCIDO de 0.6 a 0.5
            return False
        
        # Contar caracteres comunes en posiciones similares
        caracteres_comunes = 0
        for i in range(min(len(nombre1), len(nombre2))):
            if nombre1[i] == nombre2[i]:
                caracteres_comunes += 1
        
        ratio = caracteres_comunes / len_max
        return ratio >= tolerancia
    
    def _normalizar_texto_completo(self, texto: str) -> str:
        """
        ✅ NUEVO MÉTODO - Normalización completa de texto para comparaciones
        Elimina acentos, ñ, mayúsculas y espacios extra
        """
        if not texto:
            return ""
        
        # Diccionario de reemplazos para caracteres especiales
        reemplazos = {
            'á': 'a', 'à': 'a', 'ä': 'a', 'â': 'a', 'ā': 'a', 'ă': 'a', 'ą': 'a',
            'é': 'e', 'è': 'e', 'ë': 'e', 'ê': 'e', 'ē': 'e', 'ĕ': 'e', 'ę': 'e', 
            'í': 'i', 'ì': 'i', 'ï': 'i', 'î': 'i', 'ī': 'i', 'ĭ': 'i', 'į': 'i',
            'ó': 'o', 'ò': 'o', 'ö': 'o', 'ô': 'o', 'ō': 'o', 'ŏ': 'o', 'ő': 'o',
            'ú': 'u', 'ù': 'u', 'ü': 'u', 'û': 'u', 'ū': 'u', 'ŭ': 'u', 'ů': 'u', 'ű': 'u', 'ų': 'u',
            'ñ': 'n', 'ň': 'n', 'ņ': 'n',
            'ç': 'c', 'ć': 'c', 'č': 'c', 'ĉ': 'c', 'ċ': 'c',
            'ß': 'ss'
        }
        
        texto_normalizado = texto.lower().strip()
        
        # Aplicar reemplazos
        for original, reemplazo in reemplazos.items():
            texto_normalizado = texto_normalizado.replace(original, reemplazo)
        
        # Limpiar espacios múltiples
        texto_normalizado = ' '.join(texto_normalizado.split())
        
        return texto_normalizado
    # ===============================
    # REPORTES - CORREGIDOS
    # ===============================
    
    def get_consultations_for_report(self, start_date: datetime = None, end_date: datetime = None,
                               medico_id: int = None, specialty_id: int = None) -> List[Dict[str, Any]]:
        """Obtiene consultas formateadas para reportes - CORREGIDO"""
        base_query = """
        SELECT c.id, c.Fecha, c.Detalles, c.Tipo_Consulta as tipo_consulta,
            -- Paciente (CON CÉDULA)
            CONCAT(p.Nombre, ' ', p.Apellido_Paterno, ' ', ISNULL(p.Apellido_Materno, '')) as paciente_completo,
            p.Cedula as paciente_cedula,
            -- Especialidad/Servicio
            e.Nombre as especialidad_nombre, e.Precio_Normal, e.Precio_Emergencia,
            -- Doctor
            CONCAT('Dr. ', d.Nombre, ' ', d.Apellido_Paterno, ' ', ISNULL(d.Apellido_Materno, '')) as doctor_completo,
            d.Especialidad as doctor_especialidad, d.Matricula as doctor_matricula,
            -- Usuario
            CONCAT(u.Nombre, ' ', u.Apellido_Paterno) as usuario_registro,
            u.nombre_usuario as usuario_username
        FROM Consultas c
        INNER JOIN Pacientes p ON c.Id_Paciente = p.id
        INNER JOIN Especialidad e ON c.Id_Especialidad = e.id
        INNER JOIN Doctores d ON e.Id_Doctor = d.id
        INNER JOIN Usuario u ON c.Id_Usuario = u.id
        """
        
        conditions = []
        params = []
        
        if start_date and end_date:
            conditions.append("c.Fecha BETWEEN ? AND ?")
            params.extend([start_date, end_date])
        
        if medico_id:
            conditions.append("d.id = ?")
            params.append(medico_id)
        
        if specialty_id:
            conditions.append("e.id = ?")
            params.append(specialty_id)
        
        if conditions:
            base_query += " WHERE " + " AND ".join(conditions)
        
        base_query += " ORDER BY c.Fecha DESC"
        
        consultations = self._execute_query(base_query, tuple(params))
        
        # Agregar información adicional para reporte
        for consultation in consultations:
            consultation['fecha_formato'] = consultation['Fecha'].strftime('%d/%m/%Y %H:%M')
        
        return consultations
    
    def _detectar_tipo_busqueda(self, termino: str) -> str:
        """
        Detecta automáticamente si el término de búsqueda es cédula o nombre
        
        Returns:
            'cedula' si es número de cédula
            'nombre' si es texto/nombre
            'mixto' si contiene números y letras
        """
        if not termino or len(termino.strip()) < 2:
            return 'invalido'
        
        termino_limpio = termino.strip()
        
        # Verificar si es solo números (posible cédula)
        if termino_limpio.replace(' ', '').isdigit():
            return 'cedula'
        
        # Verificar si contiene solo letras y espacios (nombre)
        if all(c.isalpha() or c.isspace() for c in termino_limpio):
            return 'nombre'
        
        # Si contiene números y letras
        return 'mixto'
    
    def _es_cedula_valida(self, termino: str) -> bool:
        """
        Valida si un término tiene formato válido de cédula
        """
        if not termino:
            return False
        
        # Limpiar espacios y caracteres especiales
        cedula_limpia = ''.join(c for c in termino if c.isdigit())
        
        # Debe tener entre 6 y 12 dígitos
        if len(cedula_limpia) < 6 or len(cedula_limpia) > 12:
            return False
        
        return True
    
    def _normalizar_termino_busqueda(self, termino: str) -> str:
        """
        Normaliza término de búsqueda eliminando caracteres especiales
        """
        if not termino:
            return ""
        
        # Convertir a minúsculas y quitar espacios extra
        normalizado = ' '.join(termino.strip().lower().split())
        
        # Eliminar caracteres especiales comunes
        caracteres_especiales = ['ñ', 'á', 'é', 'í', 'ó', 'ú']
        reemplazos = ['n', 'a', 'e', 'i', 'o', 'u']
        
        for i, char in enumerate(caracteres_especiales):
            normalizado = normalizado.replace(char, reemplazos[i])
        
        return normalizado
    
    def _analizar_termino_nombre(self, termino: str) -> Dict[str, str]:
        """
        Analiza un nombre completo y lo separa en componentes - VERSIÓN MEJORADA
        Considera nombres compuestos típicos latinoamericanos
        
        Returns:
            Dict con 'nombre', 'apellido_paterno', 'apellido_materno'
        """
        if not termino:
            return {'nombre': '', 'apellido_paterno': '', 'apellido_materno': ''}
        
        # Limpiar y dividir por espacios
        palabras = [p.strip().title() for p in termino.strip().split() if p.strip()]
        
        if len(palabras) == 0:
            return {'nombre': '', 'apellido_paterno': '', 'apellido_materno': ''}
        
        # Palabras conectoras que suelen ser parte de apellidos
        conectores = {'de', 'del', 'de la', 'van', 'von', 'da', 'dos', 'las', 'los', 'mc', 'mac'}
        
        # ✅ NOMBRES COMUNES QUE SUELEN IR JUNTOS (nombres compuestos)
        nombres_compuestos_comunes = {
            'ana', 'maria', 'jose', 'juan', 'luis', 'carlos', 'miguel', 'angel',
            'pedro', 'antonio', 'francisco', 'manuel', 'rafael', 'alejandro',
            'fernando', 'ricardo', 'roberto', 'eduardo', 'daniel', 'david',
            'rosa', 'carmen', 'elena', 'laura', 'patricia', 'sandra', 'monica',
            'claudia', 'gloria', 'martha', 'teresa', 'angela', 'beatriz',
            'luz', 'esperanza', 'dolores', 'pilar', 'mercedes', 'socorro'
        }
        
        # Análisis según cantidad de palabras
        if len(palabras) == 1:
            return {
                'nombre': palabras[0],
                'apellido_paterno': '',
                'apellido_materno': ''
            }
        elif len(palabras) == 2:
            return {
                'nombre': palabras[0],
                'apellido_paterno': palabras[1],
                'apellido_materno': ''
            }
        elif len(palabras) == 3:
            # ✅ LÓGICA MEJORADA PARA 3 PALABRAS
            primera = palabras[0].lower()
            segunda = palabras[1].lower()
            
            # Si las dos primeras son nombres comunes → nombre compuesto
            if (primera in nombres_compuestos_comunes and 
                segunda in nombres_compuestos_comunes):
                return {
                    'nombre': f"{palabras[0]} {palabras[1]}",
                    'apellido_paterno': palabras[2],
                    'apellido_materno': ''
                }
            else:
                # Patrón normal: Nombre + Apellido Paterno + Apellido Materno
                return {
                    'nombre': palabras[0],
                    'apellido_paterno': palabras[1],
                    'apellido_materno': palabras[2]
                }
                
        elif len(palabras) == 4:
            # ✅ LÓGICA MEJORADA PARA 4 PALABRAS
            primera = palabras[0].lower()
            segunda = palabras[1].lower()
            tercera = palabras[2].lower()
            
            # Caso 1: Dos nombres + dos apellidos (más común)
            if (primera in nombres_compuestos_comunes and 
                segunda in nombres_compuestos_comunes):
                return {
                    'nombre': f"{palabras[0]} {palabras[1]}",
                    'apellido_paterno': palabras[2],
                    'apellido_materno': palabras[3]
                }
            
            # Caso 2: Un nombre + apellido con conector
            if tercera in conectores:
                return {
                    'nombre': palabras[0],
                    'apellido_paterno': palabras[1],
                    'apellido_materno': f"{palabras[2]} {palabras[3]}"
                }
            
            # Caso 3: Nombre + apellido compuesto + apellido simple
            # Ejemplo: "Ana Flores Gutierrez Martinez"
            else:
                # Asumir que es: Nombre + Apellido_Paterno + Apellido_Materno (compuesto)
                return {
                    'nombre': palabras[0],
                    'apellido_paterno': palabras[1],
                    'apellido_materno': f"{palabras[2]} {palabras[3]}"
                }
        
        else:
            # ✅ 5 O MÁS PALABRAS - LÓGICA COMPLEJA
            nombre_parts = []
            apellido_parts = []
            en_apellidos = False
            
            for i, palabra in enumerate(palabras):
                palabra_lower = palabra.lower()
                
                # Si es un conector, probablemente estamos en apellidos
                if palabra_lower in conectores:
                    en_apellidos = True
                    apellido_parts.append(palabra)
                elif en_apellidos:
                    apellido_parts.append(palabra)
                else:
                    # ✅ MEJORAR: Detectar cuándo termina el nombre
                    if i < 2:  # Máximo 2 nombres
                        # Si es nombre común, puede ser parte del nombre compuesto
                        if (palabra_lower in nombres_compuestos_comunes or 
                            (i == 1 and palabras[0].lower() in nombres_compuestos_comunes)):
                            nombre_parts.append(palabra)
                        else:
                            # Ya no es nombre, empezar apellidos
                            en_apellidos = True
                            apellido_parts.append(palabra)
                    else:
                        # A partir del 3er elemento, son apellidos
                        en_apellidos = True
                        apellido_parts.append(palabra)
            
            # Si no se identificaron apellidos claramente
            if not apellido_parts and len(palabras) >= 3:
                # Estrategia de respaldo: últimas 2 palabras son apellidos
                nombre_parts = palabras[:-2]
                apellido_parts = palabras[-2:]
            elif not apellido_parts:
                # Solo hay nombres
                nombre_parts = palabras[:-1]  
                apellido_parts = [palabras[-1]]
            
            # Construir resultado
            nombre = ' '.join(nombre_parts) if nombre_parts else palabras[0]
            
            if len(apellido_parts) >= 2:
                apellido_paterno = apellido_parts[0]
                apellido_materno = ' '.join(apellido_parts[1:])
            elif len(apellido_parts) == 1:
                apellido_paterno = apellido_parts[0]
                apellido_materno = ''
            else:
                # Respaldo para casos extremos
                apellido_paterno = palabras[1] if len(palabras) > 1 else ''
                apellido_materno = palabras[2] if len(palabras) > 2 else ''
            
            return {
                'nombre': nombre,
                'apellido_paterno': apellido_paterno,
                'apellido_materno': apellido_materno
            }
    
    def buscar_paciente_unificado(self, termino_busqueda: str, limite: int = 5) -> List[Dict[str, Any]]:
        """
        Búsqueda unificada que detecta automáticamente el tipo de entrada
        
        Args:
            termino_busqueda: Término a buscar (cédula o nombre)
            limite: Máximo número de resultados
            
        Returns:
            Lista de pacientes encontrados con score de relevancia
        """
        try:
            if not termino_busqueda or len(termino_busqueda.strip()) < 2:
                return []
            
            termino_limpio = termino_busqueda.strip()
            tipo_busqueda = self._detectar_tipo_busqueda(termino_limpio)
            
            print(f"🔍 Búsqueda unificada: '{termino_limpio}' - Tipo: {tipo_busqueda}")
            
            resultados = []
            
            if tipo_busqueda == 'cedula':
                # Búsqueda por cédula
                resultados = self._buscar_por_cedula_mejorado(termino_limpio, limite)
            elif tipo_busqueda == 'nombre':
                # Búsqueda por nombre
                resultados = self._buscar_por_nombre_mejorado(termino_limpio, limite)
            elif tipo_busqueda == 'mixto':
                # Búsqueda mixta - intentar ambos métodos
                resultados_cedula = self._buscar_por_cedula_mejorado(termino_limpio, limite//2)
                resultados_nombre = self._buscar_por_nombre_mejorado(termino_limpio, limite//2)
                resultados = resultados_cedula + resultados_nombre
            
            # Ordenar por relevancia y limitar resultados
            resultados_ordenados = sorted(resultados, key=lambda x: x.get('relevancia', 999))
            return resultados_ordenados[:limite]
            
        except Exception as e:
            print(f"❌ Error en búsqueda unificada: {e}")
            return []
        
    def _buscar_por_cedula_mejorado(self, cedula: str, limite: int) -> List[Dict[str, Any]]:
        """Búsqueda mejorada por cédula con scoring"""
        if not self._es_cedula_valida(cedula):
            return []
        
        cedula_numeros = ''.join(c for c in cedula if c.isdigit())
        
        # Búsqueda exacta primero
        query_exacta = """
        SELECT 
            id, Nombre, Apellido_Paterno, Apellido_Materno, Cedula,
            CONCAT(Nombre, ' ', Apellido_Paterno, ' ', ISNULL(Apellido_Materno, '')) as nombre_completo,
            1 as relevancia
        FROM Pacientes
        WHERE Cedula = ?
        """
        
        resultados_exactos = self._execute_query(query_exacta, (cedula_numeros,))
        
        if resultados_exactos:
            return resultados_exactos
        
        # Búsqueda parcial si no hay exacta
        query_parcial = """
        SELECT TOP (?)
            id, Nombre, Apellido_Paterno, Apellido_Materno, Cedula,
            CONCAT(Nombre, ' ', Apellido_Paterno, ' ', ISNULL(Apellido_Materno, '')) as nombre_completo,
            2 as relevancia
        FROM Pacientes
        WHERE Cedula LIKE ?
        ORDER BY 
            CASE WHEN Cedula LIKE ? THEN 1 ELSE 2 END,
            LEN(Cedula),
            Cedula
        """
        
        patron_inicio = f"{cedula_numeros}%"
        patron_contiene = f"%{cedula_numeros}%"
        
        return self._execute_query(query_parcial, (limite, patron_contiene, patron_inicio))
    
    def _buscar_por_nombre_mejorado(self, nombre: str, limite: int) -> List[Dict[str, Any]]:
        """Búsqueda mejorada por nombre con scoring"""
        termino_normalizado = self._normalizar_termino_busqueda(nombre)
        
        # Búsqueda por coincidencia en nombre completo
        query = """
        SELECT TOP (?)
            id, Nombre, Apellido_Paterno, Apellido_Materno, Cedula,
            CONCAT(Nombre, ' ', Apellido_Paterno, ' ', ISNULL(Apellido_Materno, '')) as nombre_completo,
            CASE 
                WHEN LOWER(CONCAT(Nombre, ' ', Apellido_Paterno, ' ', ISNULL(Apellido_Materno, ''))) LIKE ? THEN 1
                WHEN LOWER(Nombre) LIKE ? OR LOWER(Apellido_Paterno) LIKE ? THEN 2
                ELSE 3
            END as relevancia
        FROM Pacientes
        WHERE 
            LOWER(Nombre) LIKE ? OR 
            LOWER(Apellido_Paterno) LIKE ? OR 
            LOWER(Apellido_Materno) LIKE ? OR
            LOWER(CONCAT(Nombre, ' ', Apellido_Paterno, ' ', ISNULL(Apellido_Materno, ''))) LIKE ?
        ORDER BY relevancia, Nombre, Apellido_Paterno
        """
        
        patron_exacto = f"%{termino_normalizado}%"
        patron_palabra = f"%{termino_normalizado}%"
        
        return self._execute_query(query, (
            limite, patron_exacto, patron_palabra, patron_palabra,
            patron_palabra, patron_palabra, patron_palabra, patron_exacto
        ))
    
    # ===============================
    # MÉTODOS PARA ESPECIALIDADES
    # ===============================
    
    @cached_query('consulta_especialidades', ttl=600)
    def get_especialidades(self) -> List[Dict[str, Any]]:
        """
        Obtiene especialidades disponibles para consultas
        NUEVO: Reemplaza funcionalidad que estaba en DoctorRepository
        """
        query = """
        SELECT 
            e.id,
            e.Nombre,
            e.Detalles,
            e.Precio_Normal,
            e.Precio_Emergencia,
            COUNT(DISTINCT te.Id_Trabajador) as medicos_disponibles
        FROM Especialidad e
        LEFT JOIN Trabajador_Especialidad te ON e.id = te.Id_Especialidad
        GROUP BY e.id, e.Nombre, e.Detalles, e.Precio_Normal, e.Precio_Emergencia
        HAVING COUNT(DISTINCT te.Id_Trabajador) > 0
        ORDER BY e.Nombre
        """
        return self._execute_query(query)
    
    # ===============================
    # CACHÉ
    # ===============================
    
    def invalidate_consultation_caches(self):
        """Invalida cachés relacionados con consultas"""
        cache_types = ['consultas', 'consultas_completas', 'consultas_hoy', 'stats_consultas', 'consultas_today_stats']
        from ..core.cache_system import invalidate_after_update
        invalidate_after_update(cache_types)
    
    def _invalidate_cache_after_modification(self):
        """Override para invalidación específica"""
        super()._invalidate_cache_after_modification()
        self.invalidate_consultation_caches()