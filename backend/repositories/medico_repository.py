"""
MedicoRepository - Gestión de Médicos (Trabajadores tipo Médico)
Reemplaza DoctorRepository, ahora consulta tabla Trabajadores
"""

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

# Importar los repositories que usaremos internamente
from .trabajador_repository import TrabajadorRepository
from .especialidad_repository import EspecialidadRepository

class MedicoRepository(BaseRepository):
    """
    Repository para gestión de Médicos (usa TrabajadorRepository internamente)
    Mantiene API similar a DoctorRepository para facilitar migración
    """
    
    def __init__(self):
        super().__init__('Trabajadores', 'medicos')
        self.trabajador_repo = TrabajadorRepository()
        self.especialidad_repo = EspecialidadRepository()
        print("👨‍⚕️ MedicoRepository inicializado (usa Trabajadores)")
    
    # ===============================
    # IMPLEMENTACIÓN ABSTRACTA
    # ===============================
    
    def get_active(self) -> List[Dict[str, Any]]:
        """Obtiene todos los médicos con sus especialidades"""
        return self.get_all_with_specialties()
    
    # ===============================
    # CRUD ESPECÍFICO (Compatibilidad con DoctorRepository)
    # ===============================
    
    def create_doctor(self, nombre: str, apellido_paterno: str, apellido_materno: str,
                     especialidad: str, matricula: str, edad: int) -> int:
        """
        Crea nuevo médico en tabla Trabajadores
        Mantiene firma del método original para compatibilidad
        
        Args:
            nombre: Nombre del médico
            apellido_paterno: Apellido paterno
            apellido_materno: Apellido materno
            especialidad: Especialidad médica (campo descriptivo)
            matricula: Matrícula profesional única
            edad: Edad (18-80 años) - NOTA: Este campo ya no se usa en Trabajadores
            
        Returns:
            ID del trabajador (médico) creado
        """
        # Validaciones
        nombre = validate_required_string(nombre, "nombre", 2)
        apellido_paterno = validate_required_string(apellido_paterno, "apellido_paterno", 2)
        apellido_materno = validate_required_string(apellido_materno, "apellido_materno", 2)
        especialidad = validate_required_string(especialidad, "especialidad", 3)
        matricula = validate_required_string(matricula, "matricula", 3)
        edad = validate_age(edad, 18, 80)  # Validamos pero no guardamos
        
        # Verificar matrícula única en Trabajadores
        if self.matricula_exists(matricula):
            raise ValidationError("matricula", matricula, "Matrícula ya existe en el sistema")
        
        # Obtener ID del tipo "Médico General" o "Médico"
        tipo_medico_id = self._get_tipo_medico_id()
        
        # Crear médico usando TrabajadorRepository
        medico_id = self.trabajador_repo.create_worker(
            nombre=nombre,
            apellido_paterno=apellido_paterno,
            apellido_materno=apellido_materno,
            tipo_trabajador_id=tipo_medico_id,
            especialidad=especialidad,  # Campo descriptivo
            matricula=matricula
        )
        
        print(f"👨‍⚕️ Médico creado: Dr. {nombre} {apellido_paterno} - ID: {medico_id}")
        return medico_id
    
    def update_doctor(self, medico_id: int, nombre: str = None, apellido_paterno: str = None,
                     apellido_materno: str = None, especialidad: str = None, 
                     matricula: str = None, edad: int = None) -> bool:
        """
        Actualiza médico existente
        Mantiene firma del método original para compatibilidad
        """
        # Verificar que el trabajador existe y es médico
        medico = self.get_by_id(medico_id)
        if not medico:
            raise ValidationError("medico_id", medico_id, "Médico no encontrado")
        
        # Verificar que sea tipo médico
        if not self._es_medico(medico_id):
            raise ValidationError("medico_id", medico_id, "El trabajador no es médico")
        
        # Actualizar usando TrabajadorRepository
        success = self.trabajador_repo.update_worker(
            trabajador_id=medico_id,
            nombre=nombre,
            apellido_paterno=apellido_paterno,
            apellido_materno=apellido_materno,
            especialidad=especialidad,
            matricula=matricula
            # Nota: edad ya no se usa en Trabajadores
        )
        
        if success:
            print(f"👨‍⚕️ Médico actualizado: ID {medico_id}")
            self.invalidate_doctor_caches()
        
        return success
    
    # ===============================
    # CONSULTAS CON ESPECIALIDADES
    # ===============================
    
    @cached_query('medicos_especialidades', ttl=600)
    def get_all_with_specialties(self) -> List[Dict[str, Any]]:
        """
        Obtiene médicos con sus especialidades asignadas
        Reemplaza funcionalidad de DoctorRepository.get_all_with_specialties()
        """
        return self.trabajador_repo.get_medicos_con_especialidades()
    
    def get_doctor_with_services(self, medico_id: int) -> Optional[Dict[str, Any]]:
        """
        Obtiene médico específico con todas sus especialidades
        Mantiene compatibilidad con método original
        """
        return self.trabajador_repo.get_medico_con_especialidades(medico_id)
    
    def get_doctor_with_consultation_history(self, medico_id: int) -> Optional[Dict[str, Any]]:
        """
        Obtiene médico con historial de consultas
        """
        medico = self.get_doctor_with_services(medico_id)
        if not medico:
            return None
        
        # Obtener consultas del médico a través de sus especialidades
        consultations_query = """
        SELECT 
            c.id, c.Fecha, c.Detalles, c.Tipo_Consulta,
            e.Nombre as especialidad_nombre,
            e.Precio_Normal, e.Precio_Emergencia,
            CONCAT(p.Nombre, ' ', p.Apellido_Paterno, ' ', p.Apellido_Materno) as paciente_completo,
            CONCAT(u.Nombre, ' ', u.Apellido_Paterno) as usuario_registro
        FROM Consultas c
        INNER JOIN Especialidad e ON c.Id_Especialidad = e.id
        INNER JOIN Trabajador_Especialidad te ON e.id = te.Id_Especialidad
        INNER JOIN Pacientes p ON c.Id_Paciente = p.id
        INNER JOIN Usuario u ON c.Id_Usuario = u.id
        WHERE te.Id_Trabajador = ?
        ORDER BY c.Fecha DESC
        """
        
        consultations = self._execute_query(consultations_query, (medico_id,))
        medico['historial_consultas'] = consultations
        medico['total_consultas_realizadas'] = len(consultations)
        
        # Estadísticas de consultas
        if consultations:
            medico['ultima_consulta'] = consultations[0]['Fecha']
            medico['primera_consulta'] = consultations[-1]['Fecha']
        
        return medico
    
    # ===============================
    # BÚSQUEDAS ESPECÍFICAS
    # ===============================
    
    def search_doctors(self, search_term: str, limit: int = 50) -> List[Dict[str, Any]]:
        """
        Búsqueda por nombre, apellidos, especialidad o matrícula
        Mantiene compatibilidad con método original
        """
        return self.trabajador_repo.search_medicos(search_term, limit)
    
    def get_by_specialty(self, especialidad: str) -> List[Dict[str, Any]]:
        """
        Obtiene médicos por especialidad descriptiva
        """
        if not especialidad or len(especialidad.strip()) < 2:
            return []
        
        search_term = f"%{especialidad.strip()}%"
        
        query = """
        SELECT 
            t.id,
            t.Nombre,
            t.Apellido_Paterno,
            t.Apellido_Materno,
            t.Matricula,
            t.Especialidad as especialidad_descriptiva,
            tt.Tipo as tipo_trabajador
        FROM Trabajadores t
        INNER JOIN Tipo_Trabajadores tt ON t.Id_Tipo_Trabajador = tt.id
        WHERE tt.area_funcional = 'MEDICO'
          AND t.Especialidad LIKE ?
        ORDER BY t.Nombre, t.Apellido_Paterno
        """
        
        return self._execute_query(query, (search_term,))
    
    def get_by_matricula(self, matricula: str) -> Optional[Dict[str, Any]]:
        """Obtiene médico por matrícula"""
        query = """
        SELECT t.*
        FROM Trabajadores t
        INNER JOIN Tipo_Trabajadores tt ON t.Id_Tipo_Trabajador = tt.id
        WHERE tt.area_funcional = 'MEDICO'
          AND t.Matricula = ?
        """
        return self._execute_query(query, (matricula.upper().strip(),), fetch_one=True)
    
    # ===============================
    # GESTIÓN DE ESPECIALIDADES (Servicios)
    # ===============================
    
    def create_specialty_service(self, medico_id: int, nombre: str, detalles: str,
                                precio_normal: float, precio_emergencia: float) -> int:
        """
        Crea especialidad y la asigna al médico
        Mantiene compatibilidad con método original
        """
        # Verificar que el trabajador es médico
        if not self._es_medico(medico_id):
            raise ValidationError("medico_id", medico_id, "El trabajador no es médico")
        
        # Crear especialidad
        especialidad_id = self.especialidad_repo.create_especialidad(
            nombre=nombre,
            detalles=detalles,
            precio_normal=precio_normal,
            precio_emergencia=precio_emergencia
        )
        
        # Asignar al médico
        self.trabajador_repo.asignar_especialidad(
            trabajador_id=medico_id,
            especialidad_id=especialidad_id,
            es_principal=True  # Asumimos que es principal si la crea él
        )
        
        print(f"🏥 Especialidad creada y asignada al médico {medico_id}")
        return especialidad_id
    
    def get_all_specialty_services(self) -> List[Dict[str, Any]]:
        """Obtiene todos los servicios con información del médico"""
        return self.especialidad_repo.get_all_especialidades()
    
    def update_specialty_service(self, service_id: int, nombre: str = None, detalles: str = None,
                                precio_normal: float = None, precio_emergencia: float = None) -> bool:
        """Actualiza servicio de especialidad"""
        return self.especialidad_repo.update_especialidad(
            especialidad_id=service_id,
            nombre=nombre,
            detalles=detalles,
            precio_normal=precio_normal,
            precio_emergencia=precio_emergencia
        )
    
    def delete_specialty_service(self, service_id: int) -> bool:
        """Elimina servicio de especialidad"""
        return self.especialidad_repo.delete_especialidad(service_id)
    
    # ===============================
    # ESTADÍSTICAS
    # ===============================
    
    @cached_query('stats_medicos', ttl=600)
    def get_doctor_statistics(self) -> Dict[str, Any]:
        """Estadísticas completas de médicos"""
        # Estadísticas generales de médicos
        general_query = """
        SELECT 
            COUNT(*) as total_medicos,
            COUNT(DISTINCT t.Especialidad) as especialidades_diferentes,
            COUNT(DISTINCT te.Id_Especialidad) as servicios_ofrecidos
        FROM Trabajadores t
        INNER JOIN Tipo_Trabajadores tt ON t.Id_Tipo_Trabajador = tt.id
        LEFT JOIN Trabajador_Especialidad te ON t.id = te.Id_Trabajador
        WHERE tt.area_funcional = 'MEDICO'
        """
        
        # Por especialidades descriptivas
        specialties_query = """
        SELECT 
            t.Especialidad,
            COUNT(*) as cantidad
        FROM Trabajadores t
        INNER JOIN Tipo_Trabajadores tt ON t.Id_Tipo_Trabajador = tt.id
        WHERE tt.area_funcional = 'MEDICO'
          AND t.Especialidad IS NOT NULL
        GROUP BY t.Especialidad
        ORDER BY cantidad DESC
        """
        
        # Servicios por médico
        services_query = """
        SELECT 
            t.id,
            CONCAT('Dr. ', t.Nombre, ' ', t.Apellido_Paterno) as medico_nombre,
            t.Especialidad as especialidad_descriptiva,
            COUNT(te.Id_Especialidad) as total_servicios
        FROM Trabajadores t
        INNER JOIN Tipo_Trabajadores tt ON t.Id_Tipo_Trabajador = tt.id
        LEFT JOIN Trabajador_Especialidad te ON t.id = te.Id_Trabajador
        WHERE tt.area_funcional = 'MEDICO'
        GROUP BY t.id, t.Nombre, t.Apellido_Paterno, t.Especialidad
        ORDER BY total_servicios DESC
        """
        
        general_stats = self._execute_query(general_query, fetch_one=True)
        specialties_stats = self._execute_query(specialties_query)
        services_stats = self._execute_query(services_query)
        
        return {
            'general': general_stats,
            'por_especialidades': specialties_stats,
            'servicios_por_medico': services_stats
        }
    
    def get_most_active_doctors(self, limit: int = 10) -> List[Dict[str, Any]]:
        """Médicos más activos por número de consultas"""
        query = """
        SELECT TOP (?)
            t.id, t.Nombre, t.Apellido_Paterno, t.Apellido_Materno,
            t.Matricula, t.Especialidad,
            COUNT(DISTINCT c.id) as total_consultas,
            MAX(c.Fecha) as ultima_consulta,
            COUNT(DISTINCT c.Id_Paciente) as pacientes_unicos
        FROM Trabajadores t
        INNER JOIN Tipo_Trabajadores tt ON t.Id_Tipo_Trabajador = tt.id
        INNER JOIN Trabajador_Especialidad te ON t.id = te.Id_Trabajador
        INNER JOIN Especialidad e ON te.Id_Especialidad = e.id
        INNER JOIN Consultas c ON e.id = c.Id_Especialidad
        WHERE tt.area_funcional = 'MEDICO'
        GROUP BY t.id, t.Nombre, t.Apellido_Paterno, t.Apellido_Materno, 
                 t.Matricula, t.Especialidad
        ORDER BY total_consultas DESC, t.Nombre
        """
        return self._execute_query(query, (limit,))
    
    # ===============================
    # UTILIDADES
    # ===============================
    
    def get_doctor_full_name(self, medico_id: int) -> str:
        """Obtiene nombre completo del médico"""
        medico = self.get_by_id(medico_id)
        if not medico:
            return ""
        
        return f"Dr. {medico['Nombre']} {medico['Apellido_Paterno']} {medico['Apellido_Materno']}"
    
    def validate_doctor_exists(self, medico_id: int) -> bool:
        """Valida que el médico existe"""
        return self._es_medico(medico_id)
    
    def get_available_specialties(self) -> List[str]:
        """Obtiene lista de especialidades descriptivas disponibles"""
        query = """
        SELECT DISTINCT Especialidad 
        FROM Trabajadores t
        INNER JOIN Tipo_Trabajadores tt ON t.Id_Tipo_Trabajador = tt.id
        WHERE tt.area_funcional = 'MEDICO'
          AND Especialidad IS NOT NULL
        ORDER BY Especialidad
        """
        result = self._execute_query(query)
        return [row['Especialidad'] for row in result]
    
    def matricula_exists(self, matricula: str, exclude_id: int = None) -> bool:
        """Verifica si existe una matrícula"""
        query = "SELECT COUNT(*) as count FROM Trabajadores WHERE Matricula = ?"
        params = [matricula.upper().strip()]
        
        if exclude_id:
            query += " AND id != ?"
            params.append(exclude_id)
        
        result = self._execute_query(query, tuple(params), fetch_one=True)
        return result['count'] > 0 if result else False
    
    # ===============================
    # MÉTODOS PRIVADOS
    # ===============================
    
    def _get_tipo_medico_id(self) -> int:
        """Obtiene el ID del tipo de trabajador Médico"""
        query = """
        SELECT TOP 1 id 
        FROM Tipo_Trabajadores 
        WHERE area_funcional = 'MEDICO'
        ORDER BY id
        """
        result = self._execute_query(query, fetch_one=True)
        
        if not result:
            raise ValidationError("tipo_trabajador", "Médico", 
                                "No existe el tipo de trabajador Médico")
        
        return result['id']
    
    def _es_medico(self, trabajador_id: int) -> bool:
        """Verifica si un trabajador es médico"""
        query = """
        SELECT COUNT(*) as count
        FROM Trabajadores t
        INNER JOIN Tipo_Trabajadores tt ON t.Id_Tipo_Trabajador = tt.id
        WHERE t.id = ? 
          AND tt.area_funcional = 'MEDICO'
        """
        result = self._execute_query(query, (trabajador_id,), fetch_one=True)
        return result['count'] > 0 if result else False
    
    # ===============================
    # CACHÉ
    # ===============================
    
    def invalidate_doctor_caches(self):
        """Invalida cachés relacionados con médicos"""
        cache_types = ['medicos', 'medicos_especialidades', 'stats_medicos']
        from ..core.cache_system import invalidate_after_update
        invalidate_after_update(cache_types)
        
        # También invalidar cachés de trabajadores y especialidades
        self.trabajador_repo.invalidate_medico_caches()
        self.especialidad_repo.invalidate_especialidad_caches()
    
    def _invalidate_cache_after_modification(self):
        """Override para invalidación específica"""
        super()._invalidate_cache_after_modification()
        self.invalidate_doctor_caches()


# ===============================
# UTILIDADES Y EXPORTACIÓN
# ===============================

__all__ = ['MedicoRepository']