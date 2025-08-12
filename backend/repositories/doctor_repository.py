from typing import List, Dict, Any, Optional
from datetime import datetime

from ..core.base_repository import BaseRepository
from ..core.excepciones import (
    ValidationError, ExceptionHandler, validate_required
)
from ..core.cache_system import cached_query
from ..core.utils import (
    normalize_name, validate_age, validate_required_string,
    safe_float, validate_positive_number
)

class DoctorRepository(BaseRepository):
    """Repository para gestión de Doctores y Especialidades"""
    
    def __init__(self):
        super().__init__('Doctores', 'doctores')
        print("👨‍⚕️ DoctorRepository inicializado")
    
    # ===============================
    # IMPLEMENTACIÓN ABSTRACTA
    # ===============================
    
    def get_active(self) -> List[Dict[str, Any]]:
        """Obtiene todos los doctores con sus especialidades"""
        return self.get_all_with_specialties()
    
    # ===============================
    # CRUD ESPECÍFICO
    # ===============================
    
    def create_doctor(self, nombre: str, apellido_paterno: str, apellido_materno: str,
                     especialidad: str, matricula: str, edad: int) -> int:
        """
        Crea nuevo doctor con validaciones
        
        Args:
            nombre: Nombre del doctor
            apellido_paterno: Apellido paterno
            apellido_materno: Apellido materno
            especialidad: Especialidad médica
            matricula: Matrícula profesional única
            edad: Edad (18-80 años)
            
        Returns:
            ID del doctor creado
        """
        # Validaciones
        nombre = validate_required_string(nombre, "nombre", 2)
        apellido_paterno = validate_required_string(apellido_paterno, "apellido_paterno", 2)
        apellido_materno = validate_required_string(apellido_materno, "apellido_materno", 2)
        especialidad = validate_required_string(especialidad, "especialidad", 3)
        matricula = validate_required_string(matricula, "matricula", 3)
        edad = validate_age(edad, 18, 80)
        
        # Verificar matrícula única
        if self.matricula_exists(matricula):
            raise ValidationError("matricula", matricula, "Matrícula ya existe en el sistema")
        
        # Crear doctor
        doctor_data = {
            'Nombre': normalize_name(nombre),
            'Apellido_Paterno': normalize_name(apellido_paterno),
            'Apellido_Materno': normalize_name(apellido_materno),
            'Especialidad': especialidad.strip(),
            'Matricula': matricula.upper().strip(),
            'Edad': edad
        }
        
        doctor_id = self.insert(doctor_data)
        print(f"👨‍⚕️ Doctor creado: Dr. {nombre} {apellido_paterno} - ID: {doctor_id}")
        
        return doctor_id
    
    def update_doctor(self, doctor_id: int, nombre: str = None, apellido_paterno: str = None,
                     apellido_materno: str = None, especialidad: str = None, 
                     matricula: str = None, edad: int = None) -> bool:
        """Actualiza doctor existente"""
        # Verificar existencia
        existing_doctor = self.get_by_id(doctor_id)
        if not existing_doctor:
            raise ValidationError("doctor_id", doctor_id, "Doctor no encontrado")
        
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
        
        if especialidad is not None:
            especialidad = validate_required_string(especialidad, "especialidad", 3)
            update_data['Especialidad'] = especialidad.strip()
        
        if matricula is not None:
            matricula = validate_required_string(matricula, "matricula", 3)
            matricula = matricula.upper().strip()
            
            # Verificar matrícula única (excepto el mismo doctor)
            if matricula != existing_doctor['Matricula'] and self.matricula_exists(matricula):
                raise ValidationError("matricula", matricula, "Matrícula ya existe en el sistema")
            
            update_data['Matricula'] = matricula
        
        if edad is not None:
            edad = validate_age(edad, 18, 80)
            update_data['Edad'] = edad
        
        if not update_data:
            return True
        
        success = self.update(doctor_id, update_data)
        if success:
            print(f"👨‍⚕️ Doctor actualizado: ID {doctor_id}")
        
        return success
    
    # ===============================
    # CONSULTAS CON ESPECIALIDADES
    # ===============================
    
    @cached_query('doctores_especialidades', ttl=600)
    def get_all_with_specialties(self) -> List[Dict[str, Any]]:
        """Obtiene doctores con sus servicios de especialidad"""
        query = """
        SELECT d.*, 
               COUNT(e.id) as total_servicios,
               STRING_AGG(e.Nombre, ', ') as servicios_ofrecidos,
               AVG(e.Precio_Normal) as precio_promedio_normal,
               AVG(e.Precio_Emergencia) as precio_promedio_emergencia
        FROM Doctores d
        LEFT JOIN Especialidad e ON d.id = e.Id_Doctor
        GROUP BY d.id, d.Nombre, d.Apellido_Paterno, d.Apellido_Materno, 
                 d.Especialidad, d.Matricula, d.Edad
        ORDER BY d.Nombre, d.Apellido_Paterno
        """
        return self._execute_query(query)
    
    def get_doctor_with_services(self, doctor_id: int) -> Optional[Dict[str, Any]]:
        """Obtiene doctor específico con todos sus servicios"""
        doctor = self.get_by_id(doctor_id)
        if not doctor:
            return None
        
        services_query = """
        SELECT * FROM Especialidad 
        WHERE Id_Doctor = ? 
        ORDER BY Nombre
        """
        
        services = self._execute_query(services_query, (doctor_id,))
        doctor['servicios'] = services
        doctor['total_servicios'] = len(services)
        
        # Calcular estadísticas de precios
        if services:
            precios_normales = [s['Precio_Normal'] for s in services]
            precios_emergencia = [s['Precio_Emergencia'] for s in services]
            
            doctor['precio_min_normal'] = min(precios_normales)
            doctor['precio_max_normal'] = max(precios_normales)
            doctor['precio_promedio_normal'] = sum(precios_normales) / len(precios_normales)
            
            doctor['precio_min_emergencia'] = min(precios_emergencia)
            doctor['precio_max_emergencia'] = max(precios_emergencia)
            doctor['precio_promedio_emergencia'] = sum(precios_emergencia) / len(precios_emergencia)
        
        return doctor
    
    # ===============================
    # BÚSQUEDAS ESPECÍFICAS
    # ===============================
    
    def search_doctors(self, search_term: str, limit: int = 50) -> List[Dict[str, Any]]:
        """Búsqueda por nombre, apellidos, especialidad o matrícula"""
        if not search_term:
            return []
        
        search_term = f"%{search_term.strip()}%"
        
        query = """
        SELECT d.*, 
               COUNT(e.id) as total_servicios
        FROM Doctores d
        LEFT JOIN Especialidad e ON d.id = e.Id_Doctor
        WHERE d.Nombre LIKE ? OR d.Apellido_Paterno LIKE ? OR d.Apellido_Materno LIKE ? 
           OR d.Especialidad LIKE ? OR d.Matricula LIKE ?
        GROUP BY d.id, d.Nombre, d.Apellido_Paterno, d.Apellido_Materno, 
                 d.Especialidad, d.Matricula, d.Edad
        ORDER BY d.Nombre, d.Apellido_Paterno
        OFFSET 0 ROWS FETCH NEXT ? ROWS ONLY
        """
        
        return self._execute_query(query, (search_term, search_term, search_term, 
                                         search_term, search_term, limit))
    
    def get_by_specialty(self, especialidad: str) -> List[Dict[str, Any]]:
        """Obtiene doctores por especialidad"""
        query = "SELECT * FROM Doctores WHERE Especialidad LIKE ? ORDER BY Nombre, Apellido_Paterno"
        return self._execute_query(query, (f"%{especialidad}%",))
    
    def get_by_matricula(self, matricula: str) -> Optional[Dict[str, Any]]:
        """Obtiene doctor por matrícula"""
        query = "SELECT * FROM Doctores WHERE Matricula = ?"
        return self._execute_query(query, (matricula.upper().strip(),), fetch_one=True)
    
    def matricula_exists(self, matricula: str) -> bool:
        """Verifica si existe una matrícula"""
        return self.exists('Matricula', matricula.upper().strip())
    
    def get_by_age_range(self, min_age: int, max_age: int) -> List[Dict[str, Any]]:
        """Obtiene doctores por rango de edad"""
        query = """
        SELECT * FROM Doctores 
        WHERE Edad BETWEEN ? AND ?
        ORDER BY Edad, Nombre
        """
        return self._execute_query(query, (min_age, max_age))
    
    # ===============================
    # GESTIÓN DE ESPECIALIDADES/SERVICIOS
    # ===============================
    
    def create_specialty_service(self, doctor_id: int, nombre: str, detalles: str,
                               precio_normal: float, precio_emergencia: float) -> int:
        """
        Crea servicio de especialidad para un doctor
        
        Args:
            doctor_id: ID del doctor
            nombre: Nombre del servicio
            detalles: Descripción del servicio
            precio_normal: Precio en horario normal
            precio_emergencia: Precio en emergencia
        """
        # Validaciones
        if not self.get_by_id(doctor_id):
            raise ValidationError("doctor_id", doctor_id, "Doctor no encontrado")
        
        nombre = validate_required_string(nombre, "nombre", 3)
        precio_normal = validate_positive_number(precio_normal, "precio_normal")
        precio_emergencia = validate_positive_number(precio_emergencia, "precio_emergencia")
        
        if precio_emergencia < precio_normal:
            raise ValidationError("precio_emergencia", precio_emergencia, 
                                "Precio de emergencia debe ser mayor o igual al normal")
        
        specialty_data = {
            'Nombre': nombre.strip(),
            'Detalles': detalles.strip() if detalles else '',
            'Precio_Normal': precio_normal,
            'Precio_Emergencia': precio_emergencia,
            'Id_Doctor': doctor_id
        }
        
        # Insertar en tabla Especialidad
        query = """
        INSERT INTO Especialidad (Nombre, Detalles, Precio_Normal, Precio_Emergencia, Id_Doctor)
        OUTPUT INSERTED.id
        VALUES (?, ?, ?, ?, ?)
        """
        params = (nombre.strip(), detalles.strip() if detalles else '',
                 precio_normal, precio_emergencia, doctor_id)
        
        result = self._execute_query(query, params, fetch_one=True)
        service_id = result['id'] if result else None
        
        if service_id:
            print(f"🏥 Servicio creado: {nombre} para Doctor ID {doctor_id}")
        
        return service_id
    
    def get_all_specialty_services(self) -> List[Dict[str, Any]]:
        """Obtiene todos los servicios con información del doctor"""
        query = """
        SELECT e.*, 
               CONCAT('Dr. ', d.Nombre, ' ', d.Apellido_Paterno, ' ', d.Apellido_Materno) as doctor_completo,
               d.Especialidad as doctor_especialidad,
               d.Matricula as doctor_matricula
        FROM Especialidad e
        INNER JOIN Doctores d ON e.Id_Doctor = d.id
        ORDER BY d.Nombre, e.Nombre
        """
        return self._execute_query(query)
    
    def update_specialty_service(self, service_id: int, nombre: str = None, detalles: str = None,
                               precio_normal: float = None, precio_emergencia: float = None) -> bool:
        """Actualiza servicio de especialidad"""
        # Verificar existencia
        service_query = "SELECT * FROM Especialidad WHERE id = ?"
        existing_service = self._execute_query(service_query, (service_id,), fetch_one=True)
        
        if not existing_service:
            raise ValidationError("service_id", service_id, "Servicio no encontrado")
        
        update_data = {}
        
        if nombre is not None:
            nombre = validate_required_string(nombre, "nombre", 3)
            update_data['Nombre'] = nombre.strip()
        
        if detalles is not None:
            update_data['Detalles'] = detalles.strip()
        
        if precio_normal is not None:
            precio_normal = validate_positive_number(precio_normal, "precio_normal")
            update_data['Precio_Normal'] = precio_normal
        
        if precio_emergencia is not None:
            precio_emergencia = validate_positive_number(precio_emergencia, "precio_emergencia")
            update_data['Precio_Emergencia'] = precio_emergencia
        
        # Validar precios si ambos están presentes
        current_normal = update_data.get('Precio_Normal', existing_service['Precio_Normal'])
        current_emergencia = update_data.get('Precio_Emergencia', existing_service['Precio_Emergencia'])
        
        if current_emergencia < current_normal:
            raise ValidationError("precios", current_emergencia, 
                                "Precio de emergencia debe ser mayor o igual al normal")
        
        if not update_data:
            return True
        
        # Actualizar servicio
        fields = list(update_data.keys())
        set_clause = ', '.join([f"{field} = ?" for field in fields])
        values = tuple(update_data.values()) + (service_id,)
        
        update_query = f"UPDATE Especialidad SET {set_clause} WHERE id = ?"
        affected_rows = self._execute_query(update_query, values, fetch_all=False, use_cache=False)
        
        success = affected_rows > 0
        if success:
            print(f"🏥 Servicio actualizado: ID {service_id}")
        
        return success
    
    def delete_specialty_service(self, service_id: int) -> bool:
        """Elimina servicio de especialidad"""
        # Verificar que no tenga consultas asociadas
        consultations_query = """
        SELECT COUNT(*) as count FROM Consultas WHERE Id_Especialidad = ?
        """
        result = self._execute_query(consultations_query, (service_id,), fetch_one=True)
        
        if result and result['count'] > 0:
            raise ValidationError("service_id", service_id, 
                                "No se puede eliminar servicio con consultas asociadas")
        
        delete_query = "DELETE FROM Especialidad WHERE id = ?"
        affected_rows = self._execute_query(delete_query, (service_id,), fetch_all=False, use_cache=False)
        
        success = affected_rows > 0
        if success:
            print(f"🗑️ Servicio eliminado: ID {service_id}")
        
        return success
    
    # ===============================
    # CONSULTAS CON HISTORIAL
    # ===============================
    
    def get_doctor_with_consultation_history(self, doctor_id: int) -> Optional[Dict[str, Any]]:
        """Obtiene doctor con historial de consultas"""
        doctor = self.get_doctor_with_services(doctor_id)
        if not doctor:
            return None
        
        consultations_query = """
        SELECT c.id, c.Fecha, c.Detalles,
               e.Nombre as servicio_nombre, e.Precio_Normal, e.Precio_Emergencia,
               CONCAT(p.Nombre, ' ', p.Apellido_Paterno, ' ', p.Apellido_Materno) as paciente_completo,
               p.Edad as paciente_edad,
               CONCAT(u.Nombre, ' ', u.Apellido_Paterno) as usuario_registro
        FROM Consultas c
        INNER JOIN Especialidad e ON c.Id_Especialidad = e.id
        INNER JOIN Pacientes p ON c.Id_Paciente = p.id
        INNER JOIN Usuario u ON c.Id_Usuario = u.id
        WHERE e.Id_Doctor = ?
        ORDER BY c.Fecha DESC
        """
        
        consultations = self._execute_query(consultations_query, (doctor_id,))
        doctor['historial_consultas'] = consultations
        doctor['total_consultas_realizadas'] = len(consultations)
        
        # Estadísticas de consultas
        if consultations:
            doctor['ultima_consulta'] = consultations[0]['Fecha']
            doctor['primera_consulta'] = consultations[-1]['Fecha']
        
        return doctor
    
    # ===============================
    # ESTADÍSTICAS
    # ===============================
    
    @cached_query('stats_doctores', ttl=600)
    def get_doctor_statistics(self) -> Dict[str, Any]:
        """Estadísticas completas de doctores"""
        # Estadísticas generales
        general_query = """
        SELECT 
            COUNT(*) as total_doctores,
            AVG(CAST(Edad AS FLOAT)) as edad_promedio,
            COUNT(DISTINCT Especialidad) as especialidades_diferentes
        FROM Doctores
        """
        
        # Por especialidades
        specialties_query = """
        SELECT Especialidad, COUNT(*) as cantidad
        FROM Doctores
        GROUP BY Especialidad
        ORDER BY cantidad DESC
        """
        
        # Servicios por doctor
        services_query = """
        SELECT d.id, 
               CONCAT('Dr. ', d.Nombre, ' ', d.Apellido_Paterno) as doctor_nombre,
               d.Especialidad,
               COUNT(e.id) as total_servicios,
               AVG(e.Precio_Normal) as precio_promedio
        FROM Doctores d
        LEFT JOIN Especialidad e ON d.id = e.Id_Doctor
        GROUP BY d.id, d.Nombre, d.Apellido_Paterno, d.Especialidad
        ORDER BY total_servicios DESC
        """
        
        general_stats = self._execute_query(general_query, fetch_one=True)
        specialties_stats = self._execute_query(specialties_query)
        services_stats = self._execute_query(services_query)
        
        return {
            'general': general_stats,
            'por_especialidades': specialties_stats,
            'servicios_por_doctor': services_stats
        }
    
    def get_most_active_doctors(self, limit: int = 10) -> List[Dict[str, Any]]:
        """Doctores más activos por número de consultas"""
        query = """
        SELECT d.*, COUNT(c.id) as total_consultas,
               MAX(c.Fecha) as ultima_consulta,
               COUNT(DISTINCT c.Id_Paciente) as pacientes_unicos
        FROM Doctores d
        INNER JOIN Especialidad e ON d.id = e.Id_Doctor
        INNER JOIN Consultas c ON e.id = c.Id_Especialidad
        GROUP BY d.id, d.Nombre, d.Apellido_Paterno, d.Apellido_Materno, 
                 d.Especialidad, d.Matricula, d.Edad
        ORDER BY total_consultas DESC, d.Nombre
        OFFSET 0 ROWS FETCH NEXT ? ROWS ONLY
        """
        return self._execute_query(query, (limit,))
    
    # ===============================
    # UTILIDADES
    # ===============================
    
    def get_doctor_full_name(self, doctor_id: int) -> str:
        """Obtiene nombre completo del doctor"""
        doctor = self.get_by_id(doctor_id)
        if not doctor:
            return ""
        
        return f"Dr. {doctor['Nombre']} {doctor['Apellido_Paterno']} {doctor['Apellido_Materno']}"
    
    def validate_doctor_exists(self, doctor_id: int) -> bool:
        """Valida que el doctor existe"""
        return self.exists('id', doctor_id)
    
    def get_available_specialties(self) -> List[str]:
        """Obtiene lista de especialidades disponibles"""
        query = "SELECT DISTINCT Especialidad FROM Doctores ORDER BY Especialidad"
        result = self._execute_query(query)
        return [row['Especialidad'] for row in result]
    
    # ===============================
    # CACHÉ
    # ===============================
    
    def invalidate_doctor_caches(self):
        """Invalida cachés relacionados con doctores"""
        cache_types = ['doctores', 'doctores_especialidades', 'stats_doctores']
        from ..core.cache_system import invalidate_after_update
        invalidate_after_update(cache_types)
    
    def _invalidate_cache_after_modification(self):
        """Override para invalidación específica"""
        super()._invalidate_cache_after_modification()
        self.invalidate_doctor_caches()