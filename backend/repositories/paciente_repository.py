from typing import List, Dict, Any, Optional
from datetime import datetime

from ..core.base_repository import BaseRepository
from ..core.excepciones import (
    ValidationError, ExceptionHandler, validate_required
)
from ..core.cache_system import cached_query
from ..core.utils import (
    normalize_name, validate_age, validate_required_string,
    safe_int, calculate_percentage
)

class PacienteRepository(BaseRepository):
    """Repository para gestión de Pacientes"""
    
    def __init__(self):
        super().__init__('Pacientes', 'pacientes')
        print("👥 PacienteRepository inicializado")
    
    # ===============================
    # IMPLEMENTACIÓN ABSTRACTA
    # ===============================
    
    def get_active(self) -> List[Dict[str, Any]]:
        """Obtiene todos los pacientes (no hay campo estado)"""
        return self.get_all(order_by="Nombre, Apellido_Paterno")
    
    # ===============================
    # CRUD ESPECÍFICO
    # ===============================
    
    def create_patient(self, nombre: str, apellido_paterno: str, 
                      apellido_materno: str, edad: int) -> int:
        """
        Crea nuevo paciente con validaciones
        
        Args:
            nombre: Nombre del paciente
            apellido_paterno: Apellido paterno
            apellido_materno: Apellido materno
            edad: Edad (0-120 años)
            
        Returns:
            ID del paciente creado
        """
        # Validaciones
        nombre = normalize_name(nombre.strip()) if nombre.strip() else "Sin nombre"
        apellido_paterno = normalize_name(apellido_paterno.strip()) if apellido_paterno.strip() else ""
        apellido_materno = normalize_name(apellido_materno.strip()) if apellido_materno.strip() else ""
        edad = validate_age(edad, 0, 120) if edad else 0
        
        # Normalizar nombres
        patient_data = {
            'Nombre': nombre,
            'Apellido_Paterno': apellido_paterno,
            'Apellido_Materno': apellido_materno,
            'Edad': edad
        }
        
        patient_id = self.insert(patient_data)
        print(f"👥 Paciente creado: {nombre} {apellido_paterno} - ID: {patient_id}")
        
        return self.insert(patient_data)
    
    def update_patient(self, paciente_id: int, nombre: str = None, 
                      apellido_paterno: str = None, apellido_materno: str = None,
                      edad: int = None) -> bool:
        """Actualiza paciente existente"""
        # Verificar existencia
        if not self.get_by_id(paciente_id):
            raise ValidationError("paciente_id", paciente_id, "Paciente no encontrado")
        
        update_data = {}
        
        if nombre is not None:
            nombre = validate_required_string(nombre, "nombre", 2)
            update_data['Nombre'] = normalize_name(nombre)
        
        if apellido_paterno is not None:
            apellido_paterno = validate_required_string(apellido_paterno, "apellido_paterno", 2)
            update_data['Apellido_Paterno'] = normalize_name(apellido_paterno)
        
        if apellido_materno is not None:
            apellido_materno = validate_required_string(apellido_materno, "apellido_materno", 2)
            update_data['Apellido_Materno'] = normalize_name(apellido_materno)
        
        if edad is not None:
            edad = validate_age(edad, 0, 120)
            update_data['Edad'] = edad
        
        if not update_data:
            return True
        
        success = self.update(paciente_id, update_data)
        if success:
            print(f"👥 Paciente actualizado: ID {paciente_id}")
        
        return success
    
    # ===============================
    # BÚSQUEDAS ESPECÍFICAS
    # ===============================
    
    def search_patients(self, search_term: str, limit: int = 50) -> List[Dict[str, Any]]:
        """Búsqueda por nombre o apellidos"""
        if not search_term:
            return []
        
        search_term = f"%{search_term.strip()}%"
        
        query = """
        SELECT * FROM Pacientes 
        WHERE Nombre LIKE ? OR Apellido_Paterno LIKE ? OR Apellido_Materno LIKE ?
        ORDER BY Nombre, Apellido_Paterno
        OFFSET 0 ROWS FETCH NEXT ? ROWS ONLY
        """
        
        return self._execute_query(query, (search_term, search_term, search_term, limit))
    
    def get_by_age_range(self, min_age: int, max_age: int) -> List[Dict[str, Any]]:
        """Obtiene pacientes por rango de edad"""
        query = """
        SELECT * FROM Pacientes 
        WHERE Edad BETWEEN ? AND ?
        ORDER BY Edad, Nombre
        """
        return self._execute_query(query, (min_age, max_age))
    
    def get_pediatric_patients(self, max_age: int = 17) -> List[Dict[str, Any]]:
        """Obtiene pacientes pediátricos"""
        return self.get_by_age_range(0, max_age)
    
    def get_adult_patients(self, min_age: int = 18) -> List[Dict[str, Any]]:
        """Obtiene pacientes adultos"""
        query = "SELECT * FROM Pacientes WHERE Edad >= ? ORDER BY Nombre, Apellido_Paterno"
        return self._execute_query(query, (min_age,))
    
    def get_elderly_patients(self, min_age: int = 65) -> List[Dict[str, Any]]:
        """Obtiene pacientes adultos mayores"""
        return self.get_by_age_range(min_age, 120)
    
    def get_patients_by_name(self, nombre: str = None, apellido_paterno: str = None) -> List[Dict[str, Any]]:
        """Busca pacientes por nombre exacto o apellido"""
        conditions = []
        params = []
        
        if nombre:
            conditions.append("Nombre = ?")
            params.append(nombre.strip())
        
        if apellido_paterno:
            conditions.append("Apellido_Paterno = ?")
            params.append(apellido_paterno.strip())
        
        if not conditions:
            return []
        
        where_clause = " AND ".join(conditions)
        query = f"SELECT * FROM Pacientes WHERE {where_clause} ORDER BY Nombre, Apellido_Paterno"
        
        return self._execute_query(query, tuple(params))
    
    # ===============================
    # CONSULTAS CON RELACIONES
    # ===============================
    
    def get_patient_with_consultations(self, paciente_id: int) -> Optional[Dict[str, Any]]:
        """Obtiene paciente con historial de consultas"""
        patient = self.get_by_id(paciente_id)
        if not patient:
            return None
        
        consultations_query = """
        SELECT c.*, e.Nombre as especialidad, 
               CONCAT(d.Nombre, ' ', d.Apellido_Paterno) as doctor_nombre
        FROM Consultas c
        INNER JOIN Especialidad e ON c.Id_Especialidad = e.id
        INNER JOIN Doctores d ON e.Id_Doctor = d.id
        WHERE c.Id_Paciente = ?
        ORDER BY c.Fecha DESC
        """
        
        consultations = self._execute_query(consultations_query, (paciente_id,))
        patient['consultas'] = consultations
        patient['total_consultas'] = len(consultations)
        
        return patient
    
    def get_patient_with_lab_results(self, paciente_id: int) -> Optional[Dict[str, Any]]:
        """Obtiene paciente con resultados de laboratorio"""
        patient = self.get_by_id(paciente_id)
        if not patient:
            return None
        
        lab_query = """
        SELECT l.*, CONCAT(t.Nombre, ' ', t.Apellido_Paterno) as trabajador_nombre,
               tt.Tipo as trabajador_tipo
        FROM Laboratorio l
        LEFT JOIN Trabajadores t ON l.Id_Trabajador = t.id
        LEFT JOIN Tipo_Trabajadores tt ON t.Id_Tipo_Trabajador = tt.id
        WHERE l.Id_Paciente = ?
        ORDER BY l.id DESC
        """
        
        lab_results = self._execute_query(lab_query, (paciente_id,))
        patient['laboratorio'] = lab_results
        patient['total_laboratorio'] = len(lab_results)
        
        return patient
    
    def get_complete_patient_record(self, paciente_id: int) -> Optional[Dict[str, Any]]:
        """Obtiene registro completo del paciente (consultas + laboratorio)"""
        patient = self.get_by_id(paciente_id)
        if not patient:
            return None
        
        # Obtener consultas
        consultations_query = """
        SELECT c.id, c.Fecha, c.Detalles,
               e.Nombre as especialidad, e.Precio_Normal, e.Precio_Emergencia,
               CONCAT(d.Nombre, ' ', d.Apellido_Paterno, ' ', d.Apellido_Materno) as doctor_completo,
               CONCAT(u.Nombre, ' ', u.Apellido_Paterno) as usuario_registro
        FROM Consultas c
        INNER JOIN Especialidad e ON c.Id_Especialidad = e.id
        INNER JOIN Doctores d ON e.Id_Doctor = d.id
        INNER JOIN Usuario u ON c.Id_Usuario = u.id
        WHERE c.Id_Paciente = ?
        ORDER BY c.Fecha DESC
        """
        
        # Obtener laboratorio
        lab_query = """
        SELECT l.id, l.Nombre, l.Detalles, l.Precio_Normal, l.Precio_Emergencia,
               CONCAT(t.Nombre, ' ', t.Apellido_Paterno) as trabajador_encargado,
               tt.Tipo as trabajador_tipo
        FROM Laboratorio l
        LEFT JOIN Trabajadores t ON l.Id_Trabajador = t.id
        LEFT JOIN Tipo_Trabajadores tt ON t.Id_Tipo_Trabajador = tt.id
        WHERE l.Id_Paciente = ?
        ORDER BY l.id DESC
        """
        
        consultations = self._execute_query(consultations_query, (paciente_id,))
        lab_results = self._execute_query(lab_query, (paciente_id,))
        
        patient['historial_consultas'] = consultations
        patient['resultados_laboratorio'] = lab_results
        patient['total_consultas'] = len(consultations)
        patient['total_laboratorio'] = len(lab_results)
        
        # Calcular estadísticas
        if consultations:
            last_consultation = consultations[0]['Fecha']
            patient['ultima_consulta'] = last_consultation
        
        return patient
    
    # ===============================
    # ESTADÍSTICAS
    # ===============================
    
    @cached_query('stats_pacientes', ttl=600)
    def get_patient_statistics(self) -> Dict[str, Any]:
        """Estadísticas completas de pacientes"""
        # Estadísticas generales
        general_query = """
        SELECT 
            COUNT(*) as total_pacientes,
            AVG(CAST(Edad AS FLOAT)) as edad_promedio,
            MIN(Edad) as edad_minima,
            MAX(Edad) as edad_maxima
        FROM Pacientes
        """
        
        # Por rangos de edad
        age_ranges_query = """
        SELECT 
            SUM(CASE WHEN Edad BETWEEN 0 AND 17 THEN 1 ELSE 0 END) as pediatricos,
            SUM(CASE WHEN Edad BETWEEN 18 AND 64 THEN 1 ELSE 0 END) as adultos,
            SUM(CASE WHEN Edad >= 65 THEN 1 ELSE 0 END) as adultos_mayores
        FROM Pacientes
        """
        
        # Top apellidos más frecuentes
        surnames_query = """
        SELECT TOP 10 Apellido_Paterno, COUNT(*) as cantidad
        FROM Pacientes
        GROUP BY Apellido_Paterno
        ORDER BY cantidad DESC
        """
        
        general_stats = self._execute_query(general_query, fetch_one=True)
        age_stats = self._execute_query(age_ranges_query, fetch_one=True)
        surnames_stats = self._execute_query(surnames_query)
        
        return {
            'general': general_stats,
            'por_edades': age_stats,
            'apellidos_frecuentes': surnames_stats
        }
    
    @cached_query('pacientes_con_consultas', ttl=300)
    def get_patients_consultation_stats(self) -> List[Dict[str, Any]]:
        """Pacientes con estadísticas de consultas"""
        query = """
        SELECT p.id, p.Nombre, p.Apellido_Paterno, p.Apellido_Materno, p.Edad,
               COUNT(c.id) as total_consultas,
               MAX(c.Fecha) as ultima_consulta,
               MIN(c.Fecha) as primera_consulta
        FROM Pacientes p
        LEFT JOIN Consultas c ON p.id = c.Id_Paciente
        GROUP BY p.id, p.Nombre, p.Apellido_Paterno, p.Apellido_Materno, p.Edad
        HAVING COUNT(c.id) > 0
        ORDER BY total_consultas DESC, p.Nombre
        """
        return self._execute_query(query)
    
    def get_patients_without_recent_visits(self, days: int = 365) -> List[Dict[str, Any]]:
        """Pacientes sin consultas recientes"""
        query = """
        SELECT p.*, MAX(c.Fecha) as ultima_consulta
        FROM Pacientes p
        LEFT JOIN Consultas c ON p.id = c.Id_Paciente
        GROUP BY p.id, p.Nombre, p.Apellido_Paterno, p.Apellido_Materno, p.Edad
        HAVING MAX(c.Fecha) IS NULL OR MAX(c.Fecha) < DATEADD(day, -?, GETDATE())
        ORDER BY ultima_consulta DESC, p.Nombre
        """
        return self._execute_query(query, (days,))
    
    def get_most_frequent_patients(self, limit: int = 20) -> List[Dict[str, Any]]:
        """Pacientes más frecuentes por número de consultas"""
        query = """
        SELECT p.*, COUNT(c.id) as total_consultas,
               MAX(c.Fecha) as ultima_consulta
        FROM Pacientes p
        INNER JOIN Consultas c ON p.id = c.Id_Paciente
        GROUP BY p.id, p.Nombre, p.Apellido_Paterno, p.Apellido_Materno, p.Edad
        ORDER BY total_consultas DESC, p.Nombre
        OFFSET 0 ROWS FETCH NEXT ? ROWS ONLY
        """
        return self._execute_query(query, (limit,))
    
    # ===============================
    # UTILIDADES ESPECÍFICAS
    # ===============================
    
    def get_patient_full_name(self, paciente_id: int) -> str:
        """Obtiene nombre completo del paciente"""
        patient = self.get_by_id(paciente_id)
        if not patient:
            return ""
        
        return f"{patient['Nombre']} {patient['Apellido_Paterno']} {patient['Apellido_Materno']}"
    
    def get_age_group(self, edad: int) -> str:
        """Determina grupo etario"""
        if edad <= 17:
            return "PEDIÁTRICO"
        elif edad <= 64:
            return "ADULTO"
        else:
            return "ADULTO_MAYOR"
    
    def validate_patient_exists(self, paciente_id: int) -> bool:
        """Valida que el paciente existe"""
        return self.exists('id', paciente_id)
    
    # ===============================
    # REPORTES
    # ===============================
    
    def get_patients_for_report(self, age_group: str = None, with_stats: bool = False) -> List[Dict[str, Any]]:
        """Obtiene pacientes formateados para reportes"""
        base_query = """
        SELECT p.id, p.Nombre, p.Apellido_Paterno, p.Apellido_Materno, p.Edad
        """
        
        if with_stats:
            base_query += """
            , COUNT(c.id) as total_consultas,
              MAX(c.Fecha) as ultima_consulta
            """
        
        from_clause = " FROM Pacientes p"
        
        if with_stats:
            from_clause += " LEFT JOIN Consultas c ON p.id = c.Id_Paciente"
        
        where_conditions = []
        params = []
        
        if age_group:
            if age_group.upper() == "PEDIÁTRICO":
                where_conditions.append("p.Edad BETWEEN 0 AND 17")
            elif age_group.upper() == "ADULTO":
                where_conditions.append("p.Edad BETWEEN 18 AND 64")
            elif age_group.upper() == "ADULTO_MAYOR":
                where_conditions.append("p.Edad >= 65")
        
        where_clause = ""
        if where_conditions:
            where_clause = " WHERE " + " AND ".join(where_conditions)
        
        group_clause = ""
        if with_stats:
            group_clause = " GROUP BY p.id, p.Nombre, p.Apellido_Paterno, p.Apellido_Materno, p.Edad"
        
        order_clause = " ORDER BY p.Nombre, p.Apellido_Paterno"
        
        final_query = base_query + from_clause + where_clause + group_clause + order_clause
        
        patients = self._execute_query(final_query, tuple(params))
        
        # Agregar información adicional
        for patient in patients:
            patient['nombre_completo'] = f"{patient['Nombre']} {patient['Apellido_Paterno']} {patient['Apellido_Materno']}"
            patient['grupo_etario'] = self.get_age_group(patient['Edad'])
        
        return patients
    def buscar_pacientes_similares(self, nombre: str, apellido_paterno: str, 
                              apellido_materno: str = "", edad: int = 0) -> List[Dict[str, Any]]:
        """Busca pacientes con nombres similares"""
        query = """
        SELECT *, 
            (CASE 
                WHEN Nombre = ? AND Apellido_Paterno = ? AND Apellido_Materno = ? THEN 100
                WHEN Nombre = ? AND Apellido_Paterno = ? THEN 90
                WHEN Nombre LIKE ? AND Apellido_Paterno LIKE ? THEN 70
                ELSE 50
            END) as similitud_score
        FROM Pacientes 
        WHERE (Nombre LIKE ? OR Apellido_Paterno LIKE ? OR Apellido_Materno LIKE ?)
        AND ABS(Edad - ?) <= 5
        ORDER BY similitud_score DESC, Nombre
        """
        
        nombre_like = f"%{nombre}%"
        apellido_p_like = f"%{apellido_paterno}%"
        apellido_m_like = f"%{apellido_materno}%" if apellido_materno else "%"
        
        return self._execute_query(query, (
            nombre, apellido_paterno, apellido_materno,  # Exacto 100%
            nombre, apellido_paterno,                     # Sin materno 90%
            nombre_like, apellido_p_like,                 # Similar 70%
            nombre_like, apellido_p_like, apellido_m_like,  # Búsqueda general
            edad or 0
        ))

    def buscar_o_crear_paciente(self, nombre: str, apellido_paterno: str, 
                            apellido_materno: str = "", edad: int = 0) -> int:
        """Busca paciente similar o crea nuevo"""
        # Limpiar datos
        nombre = nombre.strip() or "Sin nombre"
        apellido_paterno = apellido_paterno.strip() or "Sin apellido"
        apellido_materno = apellido_materno.strip()
        edad = max(0, edad or 0)
        
        # Buscar similares
        similares = self.buscar_pacientes_similares(nombre, apellido_paterno, apellido_materno, edad)
        
        # Si encuentra match con alta similitud (>=90), usar existente
        if similares and similares[0]['similitud_score'] >= 90:
            paciente_id = similares[0]['id']
            print(f"👤 Paciente existente encontrado: {nombre} {apellido_paterno} -> ID {paciente_id}")
            return paciente_id
        
        # Crear nuevo paciente
        paciente_id = self.create_patient(nombre, apellido_paterno, apellido_materno, edad)
        print(f"👤 Nuevo paciente creado: {nombre} {apellido_paterno} -> ID {paciente_id}")
        return paciente_id
    # ===============================
    # CACHÉ
    # ===============================
    
    def invalidate_patient_caches(self):
        """Invalida cachés relacionados con pacientes"""
        cache_types = ['pacientes', 'stats_pacientes', 'pacientes_con_consultas']
        from ..core.cache_system import invalidate_after_update
        invalidate_after_update(cache_types)
    
    def _invalidate_cache_after_modification(self):
        """Override para invalidación específica"""
        super()._invalidate_cache_after_modification()
        self.invalidate_patient_caches()