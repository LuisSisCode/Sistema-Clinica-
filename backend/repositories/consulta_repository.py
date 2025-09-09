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
        """Busca paciente por cédula o crea uno nuevo si no existe"""
        try:
            nombre = nombre.strip()
            apellido_paterno = apellido_paterno.strip()
            apellido_materno = apellido_materno.strip()
            cedula_clean = cedula.strip() if cedula else ""
            
            # Validaciones básicas
            if not nombre or len(nombre) < 2:
                raise ValidationError("nombre", nombre, "Nombre es obligatorio (mínimo 2 caracteres)")
            if not apellido_paterno or len(apellido_paterno) < 2:
                raise ValidationError("apellido_paterno", apellido_paterno, "Apellido paterno es obligatorio")
            if not cedula_clean or len(cedula_clean) < 5:
                raise ValidationError("cedula", cedula_clean, "Cédula es obligatoria (mínimo 5 dígitos)")
            
            # 1. Buscar por cédula exacta primero
            existing_patient = self.search_patient_by_cedula_exact(cedula_clean)
            if existing_patient:
                print(f"👤 Paciente existente encontrado: {existing_patient['nombre_completo']}")
                return existing_patient['id']
            
            # 2. Crear nuevo paciente
            patient_data = {
                'Nombre': nombre,
                'Apellido_Paterno': apellido_paterno,
                'Apellido_Materno': apellido_materno,
                'Cedula': cedula_clean
            }
            
            # Insertar en tabla Pacientes
            query = """
            INSERT INTO Pacientes (Nombre, Apellido_Paterno, Apellido_Materno, Cedula)
            OUTPUT INSERTED.id
            VALUES (?, ?, ?, ?)
            """
            
            result = self._execute_query(query, (nombre, apellido_paterno, apellido_materno, cedula_clean), fetch_one=True)
            patient_id = result['id'] if result else None
            
            if patient_id:
                print(f"👤 Nuevo paciente creado: {nombre} {apellido_paterno} - ID: {patient_id}")
                return patient_id
            else:
                raise ValidationError("paciente", None, "Error creando paciente")
            
        except Exception as e:
            print(f"⚠️ Error gestionando paciente: {e}")
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
                update_data['Tipo_Consulta'] = tipo_consulta.capitalize()  # CORREGIDO
        
        if fecha is not None:
            update_data['Fecha'] = fecha
        
        if not update_data:
            return True
        
        success = self.update(consulta_id, update_data)
        if success:
            # AGREGAR: Invalidar cache después de actualizar
            self.invalidate_consultation_caches()
            print(f"🔄 Cache invalidado después de actualizar consulta {consulta_id}")
            print(f"🩺 Consulta actualizada: ID {consulta_id}")
        if success:
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
        print(f"🔍 Query devolvió {len(result)} consultas de BD")
        return result
    
    def get_consultation_by_id_complete(self, consulta_id: int) -> Optional[Dict[str, Any]]:
        """Obtiene consulta específica con información completa - CORREGIDO"""
        query = """
        SELECT c.id, c.Fecha, c.Detalles, c.Tipo_Consulta as tipo_consulta,
               -- Paciente (CON CÉDULA)
               p.id as paciente_id,
               CONCAT(p.Nombre, ' ', p.Apellido_Paterno, ' ', ISNULL(p.Apellido_Materno, '')) as paciente_completo,
               p.Nombre as paciente_nombre, p.Apellido_Paterno as paciente_apellido_p,
               p.Apellido_Materno as paciente_apellido_m,
               p.Cedula as paciente_cedula,
               -- Especialidad/Servicio
               e.id as especialidad_id, e.Nombre as especialidad_nombre, 
               e.Detalles as especialidad_detalles,
               e.Precio_Normal, e.Precio_Emergencia,
               -- Doctor
               d.id as doctor_id,
               CONCAT('Dr. ', d.Nombre, ' ', d.Apellido_Paterno, ' ', ISNULL(d.Apellido_Materno, '')) as doctor_completo,
               d.Especialidad as doctor_especialidad, d.Matricula as doctor_matricula,
               -- Usuario que registró
               u.id as usuario_id,
               CONCAT(u.Nombre, ' ', u.Apellido_Paterno) as usuario_registro,
               u.correo as usuario_email
        FROM Consultas c
        INNER JOIN Pacientes p ON c.Id_Paciente = p.id
        INNER JOIN Especialidad e ON c.Id_Especialidad = e.id
        INNER JOIN Doctores d ON e.Id_Doctor = d.id
        INNER JOIN Usuario u ON c.Id_Usuario = u.id
        WHERE c.id = ?
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
        """Obtiene consultas en rango de fechas - CORREGIDO"""
        query = """
        SELECT c.*, 
               CONCAT(p.Nombre, ' ', p.Apellido_Paterno, ' ', ISNULL(p.Apellido_Materno, '')) as paciente_nombre,
               p.Cedula as paciente_cedula,
               e.Nombre as especialidad_nombre,
               CONCAT('Dr. ', d.Nombre, ' ', d.Apellido_Paterno) as doctor_nombre
        FROM Consultas c
        INNER JOIN Pacientes p ON c.Id_Paciente = p.id
        INNER JOIN Especialidad e ON c.Id_Especialidad = e.id
        INNER JOIN Doctores d ON e.Id_Doctor = d.id
        WHERE c.Fecha BETWEEN ? AND ?
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
        SELECT c.id, c.Fecha, c.Detalles, c.Tipo_Consulta as tipo_consulta,
            CONCAT(p.Nombre, ' ', p.Apellido_Paterno, ' ', ISNULL(p.Apellido_Materno, '')) as paciente_completo,
            p.Cedula as paciente_cedula,
            e.Nombre as especialidad_nombre,
            e.Precio_Normal, e.Precio_Emergencia,
            CONCAT('Dr. ', d.Nombre, ' ', d.Apellido_Paterno, ' ', ISNULL(d.Apellido_Materno, '')) as doctor_completo,
            -- Campo combinado para la interfaz
            CONCAT(e.Nombre, ' - Dr. ', d.Nombre, ' ', d.Apellido_Paterno) as especialidad_doctor,
            -- Precio según tipo
            CASE 
                WHEN c.Tipo_Consulta = 'Emergencia' THEN e.Precio_Emergencia 
                ELSE e.Precio_Normal 
            END as precio
        FROM Consultas c
        LEFT JOIN Pacientes p ON c.Id_Paciente = p.id
        LEFT JOIN Especialidad e ON c.Id_Especialidad = e.id
        LEFT JOIN Doctores d ON e.Id_Doctor = d.id
        WHERE c.Fecha >= DATEADD(day, -?, GETDATE())
            AND c.id IS NOT NULL
        ORDER BY c.Fecha DESC
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
    
    def get_consultations_by_doctor(self, doctor_id: int, limit: int = 50) -> List[Dict[str, Any]]:
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
        return self._execute_query(query, (doctor_id, limit))
    
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
    
    def get_doctor_consultation_count(self, doctor_id: int) -> int:
        """Obtiene número total de consultas atendidas por un doctor"""
        query = """
        SELECT COUNT(c.id) as count
        FROM Consultas c
        INNER JOIN Especialidad e ON c.Id_Especialidad = e.id
        WHERE e.Id_Doctor = ?
        """
        result = self._execute_query(query, (doctor_id,), fetch_one=True)
        return result['count'] if result else 0
    
    def validate_consultation_exists(self, consulta_id: int) -> bool:
        """Valida que la consulta existe"""
        return self.exists('id', consulta_id)
    
    # ===============================
    # REPORTES - CORREGIDOS
    # ===============================
    
    def get_consultations_for_report(self, start_date: datetime = None, end_date: datetime = None,
                                   doctor_id: int = None, specialty_id: int = None) -> List[Dict[str, Any]]:
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
               CONCAT(u.Nombre, ' ', u.Apellido_Paterno) as usuario_registro
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
        
        if doctor_id:
            conditions.append("d.id = ?")
            params.append(doctor_id)
        
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