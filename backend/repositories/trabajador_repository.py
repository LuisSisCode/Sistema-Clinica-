from typing import List, Dict, Any, Optional

from ..core.base_repository import BaseRepository
from ..core.excepciones import (
    ValidationError, ExceptionHandler, validate_required
)
from ..core.cache_system import cached_query
from ..core.utils import (
    normalize_name, validate_required_string, safe_int
)

class TrabajadorRepository(BaseRepository):
    """Repository para gestión de Trabajadores y Tipos de Trabajadores"""
    
    def __init__(self):
        super().__init__('Trabajadores', 'trabajadores')
    
    # ===============================
    # IMPLEMENTACIÓN ABSTRACTA
    # ===============================
    
    def get_active(self) -> List[Dict[str, Any]]:
        """Obtiene todos los trabajadores con sus tipos"""
        return self.get_all_with_types()
    
    # ===============================
    # CRUD ESPECÍFICO
    # ===============================
    
    def create_worker(self, nombre: str, apellido_paterno: str, apellido_materno: str,
             tipo_trabajador_id: int, especialidad: str = None, 
             matricula: str = None, usuario_id: int = None) -> int:
        """
        Crea nuevo trabajador con validaciones
        
        Args:
            nombre: Nombre del trabajador
            apellido_paterno: Apellido paterno
            apellido_materno: Apellido materno
            tipo_trabajador_id: ID del tipo de trabajador
            especialidad: Especialidad del trabajador (opcional)
            matricula: Matrícula profesional (opcional)
            usuario_id: ID del usuario que crea el registro (opcional, para auditoría)
            
        Returns:
            ID del trabajador creado
        """
        # Validaciones
        nombre = validate_required_string(nombre, "nombre", 2)
        apellido_paterno = validate_required_string(apellido_paterno, "apellido_paterno", 2)
        apellido_materno = validate_required_string(apellido_materno, "apellido_materno", 2)
        validate_required(tipo_trabajador_id, "tipo_trabajador_id")
        
        # Verificar que el tipo existe
        if not self.worker_type_exists(tipo_trabajador_id):
            raise ValidationError("tipo_trabajador_id", tipo_trabajador_id, "Tipo de trabajador no existe")
        
        # Crear trabajador
        worker_data = {
            'Nombre': normalize_name(nombre),
            'Apellido_Paterno': normalize_name(apellido_paterno),
            'Apellido_Materno': normalize_name(apellido_materno),
            'Id_Tipo_Trabajador': tipo_trabajador_id
        }
        
        # Agregar especialidad y matrícula si se proporcionan
        if especialidad and especialidad.strip():
            worker_data['Especialidad'] = especialidad.strip()
        
        if matricula and matricula.strip():
            worker_data['Matricula'] = matricula.strip()
        
        # OPCIONAL: Agregar usuario_id para auditoría si se proporciona
        if usuario_id:
            print(f"👤 Trabajador creado por usuario ID: {usuario_id}")
        
        worker_id = self.insert(worker_data)
        print(f"👷‍♂️ Trabajador creado: {nombre} {apellido_paterno} - ID: {worker_id}")
        
        return worker_id
    
    def update_worker(self, trabajador_id: int, nombre: str = None, 
                    apellido_paterno: str = None, apellido_materno: str = None,
                    tipo_trabajador_id: int = None, especialidad: str = None, 
                    matricula: str = None) -> bool:
        """Actualiza trabajador existente con todas las columnas"""
        # Verificar existencia
        if not self.get_by_id(trabajador_id):
            raise ValidationError("trabajador_id", trabajador_id, "Trabajador no encontrado")
        
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
        
        if tipo_trabajador_id is not None:
            if not self.worker_type_exists(tipo_trabajador_id):
                raise ValidationError("tipo_trabajador_id", tipo_trabajador_id, "Tipo de trabajador no existe")
            update_data['Id_Tipo_Trabajador'] = tipo_trabajador_id
        
        if especialidad is not None:
            update_data['Especialidad'] = especialidad.strip() if especialidad.strip() else None
        
        if matricula is not None:
            matricula_clean = matricula.strip() if matricula and matricula.strip() else None
            if matricula_clean and not self.validate_matricula_unique(matricula_clean, trabajador_id):
                raise ValidationError("matricula", matricula_clean, "Matrícula ya existe")
            update_data['Matricula'] = matricula_clean
        
        if not update_data:
            return True
        
        success = self.update(trabajador_id, update_data)
        if success:
            print(f"👷‍♂️ Trabajador actualizado: ID {trabajador_id}")
        
        return success
    
    # ===============================
    # CONSULTAS CON TIPOS
    # ===============================
    
    @cached_query('trabajadores_tipos', ttl=600)
    def get_all_with_types(self) -> List[Dict[str, Any]]:
        """Obtiene trabajadores con información de tipo, especialidad y matrícula"""
        query = """
        SELECT t.id, t.Nombre, t.Apellido_Paterno, t.Apellido_Materno,
            t.Id_Tipo_Trabajador, t.Especialidad, t.Matricula,
            tt.Tipo as tipo_nombre
        FROM Trabajadores t
        INNER JOIN Tipo_Trabajadores tt ON t.Id_Tipo_Trabajador = tt.id
        ORDER BY tt.Tipo, t.Nombre, t.Apellido_Paterno
        """
        return self._execute_query(query)
    
    def get_worker_with_type(self, trabajador_id: int) -> Optional[Dict[str, Any]]:
        """Obtiene trabajador específico con información completa"""
        query = """
        SELECT t.*, tt.Tipo as tipo_nombre
        FROM Trabajadores t
        INNER JOIN Tipo_Trabajadores tt ON t.Id_Tipo_Trabajador = tt.id
        WHERE t.id = ?
        """
        return self._execute_query(query, (trabajador_id,), fetch_one=True)
    
    # ===============================
    # BÚSQUEDAS ESPECÍFICAS
    # ===============================
        
    def search_workers(self, search_term: str, limit: int = 50) -> List[Dict[str, Any]]:
        """Búsqueda por nombre, apellidos, tipo, especialidad o matrícula"""
        if not search_term:
            return []
        
        search_term = f"%{search_term.strip()}%"
        
        query = """
        SELECT t.*, tt.Tipo as tipo_nombre
        FROM Trabajadores t
        INNER JOIN Tipo_Trabajadores tt ON t.Id_Tipo_Trabajador = tt.id
        WHERE t.Nombre LIKE ? OR t.Apellido_Paterno LIKE ? OR t.Apellido_Materno LIKE ?
        OR tt.Tipo LIKE ? OR t.Especialidad LIKE ? OR t.Matricula LIKE ?
        ORDER BY tt.Tipo, t.Nombre, t.Apellido_Paterno
        OFFSET 0 ROWS FETCH NEXT ? ROWS ONLY
        """
        
        return self._execute_query(query, (search_term, search_term, search_term, 
                                        search_term, search_term, search_term, limit))
    
    def get_workers_by_type(self, tipo_trabajador_id: int) -> List[Dict[str, Any]]:
        """Obtiene trabajadores por tipo específico"""
        query = """
        SELECT t.*, tt.Tipo as tipo_nombre
        FROM Trabajadores t
        INNER JOIN Tipo_Trabajadores tt ON t.Id_Tipo_Trabajador = tt.id
        WHERE t.Id_Tipo_Trabajador = ?
        ORDER BY t.Nombre, t.Apellido_Paterno
        """
        return self._execute_query(query, (tipo_trabajador_id,))
    
    def get_workers_by_type_name(self, tipo_nombre: str) -> List[Dict[str, Any]]:
        """Obtiene trabajadores por nombre de tipo"""
        query = """
        SELECT t.*, tt.Tipo as tipo_nombre
        FROM Trabajadores t
        INNER JOIN Tipo_Trabajadores tt ON t.Id_Tipo_Trabajador = tt.id
        WHERE tt.Tipo LIKE ?
        ORDER BY t.Nombre, t.Apellido_Paterno
        """
        return self._execute_query(query, (f"%{tipo_nombre}%",))
    
    # ===============================
    # CONSULTAS POR ÁREA DE TRABAJO
    # ===============================
    
    def get_laboratory_workers(self) -> List[Dict[str, Any]]:
        """Obtiene trabajadores de laboratorio"""
        return self.get_workers_by_type_name("Laboratorio")
    
    def get_pharmacy_workers(self) -> List[Dict[str, Any]]:
        """Obtiene trabajadores de farmacia"""
        return self.get_workers_by_type_name("Farmacia")
    
    def get_nursing_staff(self) -> List[Dict[str, Any]]:
        """Obtiene personal de enfermería"""
        return self.get_workers_by_type_name("Enfermero")
    
    def get_administrative_staff(self) -> List[Dict[str, Any]]:
        """Obtiene personal administrativo"""
        query = """
        SELECT t.*, tt.Tipo as tipo_nombre
        FROM Trabajadores t
        INNER JOIN Tipo_Trabajadores tt ON t.Id_Tipo_Trabajador = tt.id
        WHERE tt.Tipo IN ('Secretaria', 'Contador')
        ORDER BY tt.Tipo, t.Nombre, t.Apellido_Paterno
        """
        return self._execute_query(query)
    
    def get_technical_staff(self) -> List[Dict[str, Any]]:
        """Obtiene personal técnico"""
        query = """
        SELECT t.*, tt.Tipo as tipo_nombre
        FROM Trabajadores t
        INNER JOIN Tipo_Trabajadores tt ON t.Id_Tipo_Trabajador = tt.id
        WHERE tt.Tipo LIKE '%Técnico%'
        ORDER BY tt.Tipo, t.Nombre, t.Apellido_Paterno
        """
        return self._execute_query(query)
    
    def get_healthcare_professionals(self) -> List[Dict[str, Any]]:
        """Obtiene profesionales de la salud"""
        query = """
        SELECT t.*, tt.Tipo as tipo_nombre
        FROM Trabajadores t
        INNER JOIN Tipo_Trabajadores tt ON t.Id_Tipo_Trabajador = tt.id
        WHERE tt.Tipo IN ('Enfermero', 'Fisioterapeuta', 'Nutricionista', 'Psicólogo')
        ORDER BY tt.Tipo, t.Nombre, t.Apellido_Paterno
        """
        return self._execute_query(query)
    
    # ===============================
    # MÉTODOS NUEVOS: FILTRADO POR ÁREA FUNCIONAL
    # ===============================
    
    def get_workers_by_area_funcional(self, area: str) -> List[Dict[str, Any]]:
        """
        Obtiene trabajadores por área funcional específica
        
        Args:
            area: Área funcional (MEDICO, ENFERMERIA, LABORATORIO, FARMACIA, ADMINISTRATIVO)
        
        Returns:
            Lista de trabajadores con información completa
        """
        query = """
        SELECT t.*, tt.Tipo as tipo_nombre, tt.area_funcional
        FROM Trabajadores t
        INNER JOIN Tipo_Trabajadores tt ON t.Id_Tipo_Trabajador = tt.id
        WHERE tt.area_funcional = ?
        ORDER BY t.Nombre, t.Apellido_Paterno
        """
        return self._execute_query(query, (area,))
    
    def get_medicos_con_especialidades(self) -> List[Dict[str, Any]]:
        """
        Obtiene todos los médicos con sus especialidades asignadas
        Usa area_funcional en lugar de filtros LIKE
        """
        query = """
        SELECT 
            t.id, t.Nombre, t.Apellido_Paterno, t.Apellido_Materno,
            t.Matricula, t.Especialidad as especialidad_descriptiva,
            tt.Tipo as tipo_nombre,
            CONCAT('Dr. ', t.Nombre, ' ', t.Apellido_Paterno) as nombre_display,
            (
                SELECT STRING_AGG(e.Nombre, ', ')
                FROM Trabajador_Especialidad te
                INNER JOIN Especialidad e ON te.Id_Especialidad = e.id
                WHERE te.Id_Trabajador = t.id
            ) as especialidades_asignadas,
            (
                SELECT COUNT(*)
                FROM Trabajador_Especialidad te
                WHERE te.Id_Trabajador = t.id
            ) as total_especialidades
        FROM Trabajadores t
        INNER JOIN Tipo_Trabajadores tt ON t.Id_Tipo_Trabajador = tt.id
        WHERE tt.area_funcional = 'MEDICO'
        ORDER BY t.Apellido_Paterno, t.Nombre
        """
        return self._execute_query(query)
    
    def get_medico_con_especialidades(self, medico_id: int) -> Optional[Dict[str, Any]]:
        """
        Obtiene un médico específico con todas sus especialidades
        Usa area_funcional para validar que sea médico
        """
        query = """
        SELECT 
            t.id, t.Nombre, t.Apellido_Paterno, t.Apellido_Materno,
            t.Matricula, t.Especialidad as especialidad_descriptiva,
            tt.Tipo as tipo_nombre, tt.area_funcional,
            CONCAT('Dr. ', t.Nombre, ' ', t.Apellido_Paterno) as nombre_display
        FROM Trabajadores t
        INNER JOIN Tipo_Trabajadores tt ON t.Id_Tipo_Trabajador = tt.id
        WHERE t.id = ? AND tt.area_funcional = 'MEDICO'
        """
        
        medico = self._execute_query(query, (medico_id,), fetch_one=True)
        
        if not medico:
            return None
        
        # Obtener especialidades asignadas
        especialidades_query = """
        SELECT 
            e.id, e.Nombre, e.Detalles,
            e.Precio_Normal, e.Precio_Emergencia,
            te.Es_Principal, te.Fecha_Asignacion
        FROM Trabajador_Especialidad te
        INNER JOIN Especialidad e ON te.Id_Especialidad = e.id
        WHERE te.Id_Trabajador = ?
        ORDER BY te.Es_Principal DESC, e.Nombre
        """
        
        especialidades = self._execute_query(especialidades_query, (medico_id,))
        medico['especialidades'] = especialidades
        medico['total_especialidades'] = len(especialidades)
        
        return medico
    
    def search_medicos(self, search_term: str, limit: int = 50) -> List[Dict[str, Any]]:
        """
        Búsqueda de médicos por nombre, apellidos, especialidad o matrícula
        Usa area_funcional para filtrar solo médicos
        """
        if not search_term:
            return []
        
        search_term = f"%{search_term.strip()}%"
        
        query = """
        SELECT t.*, tt.Tipo as tipo_nombre, tt.area_funcional
        FROM Trabajadores t
        INNER JOIN Tipo_Trabajadores tt ON t.Id_Tipo_Trabajador = tt.id
        WHERE tt.area_funcional = 'MEDICO'
          AND (
              t.Nombre LIKE ? OR 
              t.Apellido_Paterno LIKE ? OR 
              t.Apellido_Materno LIKE ? OR
              t.Especialidad LIKE ? OR 
              t.Matricula LIKE ?
          )
        ORDER BY t.Apellido_Paterno, t.Nombre
        OFFSET 0 ROWS FETCH NEXT ? ROWS ONLY
        """
        
        return self._execute_query(query, (search_term, search_term, search_term, 
                                          search_term, search_term, limit))
    
    def validate_worker_area(self, trabajador_id: int, area_requerida: str) -> bool:
        """
        Valida que un trabajador pertenezca a un área funcional específica
        
        Args:
            trabajador_id: ID del trabajador
            area_requerida: Área funcional esperada (MEDICO, ENFERMERIA, etc.)
        
        Returns:
            True si el trabajador pertenece al área, False en caso contrario
        """
        query = """
        SELECT COUNT(*) as count
        FROM Trabajadores t
        INNER JOIN Tipo_Trabajadores tt ON t.Id_Tipo_Trabajador = tt.id
        WHERE t.id = ? AND tt.area_funcional = ?
        """
        
        result = self._execute_query(query, (trabajador_id, area_requerida), fetch_one=True)
        return result['count'] > 0 if result else False
    
    @cached_query('areas_funcionales', ttl=3600)
    def get_areas_funcionales_disponibles(self) -> List[Dict[str, Any]]:
        """
        Obtiene lista de áreas funcionales con conteo de trabajadores
        """
        query = """
        SELECT 
            tt.area_funcional,
            COUNT(DISTINCT t.id) as total_trabajadores,
            STRING_AGG(DISTINCT tt.Tipo, ', ') as tipos_incluidos
        FROM Tipo_Trabajadores tt
        LEFT JOIN Trabajadores t ON tt.id = t.Id_Tipo_Trabajador
        WHERE tt.area_funcional IS NOT NULL
        GROUP BY tt.area_funcional
        ORDER BY tt.area_funcional
        """
        return self._execute_query(query)
    
    def invalidate_medico_caches(self):
        """Invalida cachés relacionados con médicos"""
        cache_types = ['trabajadores_tipos', 'medicos', 'medicos_especialidades']
        from ..core.cache_system import invalidate_after_update
        invalidate_after_update(cache_types)
    
    # ===============================
    # GESTIÓN DE TIPOS DE TRABAJADORES
    # ===============================
    
    @cached_query('tipos_trabajadores', ttl=1800)
    def get_all_worker_types(self) -> List[Dict[str, Any]]:
        """Obtiene todos los tipos de trabajadores INCLUYENDO area_funcional"""
        query = """
        SELECT 
            tt.id, 
            tt.Tipo, 
            tt.descripcion, 
            tt.area_funcional,  -- ✅ AGREGAR ESTE CAMPO CRÍTICO
            COUNT(t.id) as total_trabajadores
        FROM Tipo_Trabajadores tt
        LEFT JOIN Trabajadores t ON tt.id = t.Id_Tipo_Trabajador
        GROUP BY tt.id, tt.Tipo, tt.descripcion, tt.area_funcional  -- ✅ AGREGAR AL GROUP BY
        ORDER BY tt.Tipo
        """
        return self._execute_query(query)
        
    
    def get_worker_type_by_id(self, tipo_id: int) -> Optional[Dict[str, Any]]:
        """Obtiene tipo de trabajador por ID INCLUYENDO area_funcional"""
        query = "SELECT id, Tipo, descripcion, area_funcional FROM Tipo_Trabajadores WHERE id = ?"
        return self._execute_query(query, (tipo_id,), fetch_one=True)
    
    def get_worker_type_by_name(self, tipo_nombre: str) -> Optional[Dict[str, Any]]:
        """Obtiene tipo de trabajador por nombre"""
        query = "SELECT * FROM Tipo_Trabajadores WHERE Tipo = ?"
        return self._execute_query(query, (tipo_nombre.strip(),), fetch_one=True)
    
    def create_worker_type(self, tipo_nombre: str) -> int:
        """
        Crea nuevo tipo de trabajador
        
        Args:
            tipo_nombre: Nombre del tipo de trabajador
            
        Returns:
            ID del tipo creado
        """
        tipo_nombre = validate_required_string(tipo_nombre, "tipo_nombre", 3)
        
        # Verificar que no exista
        if self.worker_type_name_exists(tipo_nombre):
            raise ValidationError("tipo_nombre", tipo_nombre, "Tipo de trabajador ya existe")
        
        query = """
        INSERT INTO Tipo_Trabajadores (Tipo)
        OUTPUT INSERTED.id
        VALUES (?)
        """
        
        result = self._execute_query(query, (tipo_nombre.strip(),), fetch_one=True)
        tipo_id = result['id'] if result else None
        
        if tipo_id:
            print(f"👷‍♂️ Tipo de trabajador creado: {tipo_nombre} - ID: {tipo_id}")
        
        return tipo_id
    
    def update_worker_type(self, tipo_id: int, tipo_nombre: str) -> bool:
        """Actualiza tipo de trabajador"""
        tipo_nombre = validate_required_string(tipo_nombre, "tipo_nombre", 3)
        
        # Verificar existencia
        existing_type = self.get_worker_type_by_id(tipo_id)
        if not existing_type:
            raise ValidationError("tipo_id", tipo_id, "Tipo de trabajador no encontrado")
        
        # Verificar nombre único (excepto el mismo)
        if tipo_nombre != existing_type['Tipo'] and self.worker_type_name_exists(tipo_nombre):
            raise ValidationError("tipo_nombre", tipo_nombre, "Tipo de trabajador ya existe")
        
        query = "UPDATE Tipo_Trabajadores SET Tipo = ? WHERE id = ?"
        affected_rows = self._execute_query(query, (tipo_nombre.strip(), tipo_id), 
                                          fetch_all=False, use_cache=False)
        
        success = affected_rows > 0
        if success:
            print(f"👷‍♂️ Tipo de trabajador actualizado: ID {tipo_id}")
        
        return success
    
    def delete_worker_type(self, tipo_id: int) -> bool:
        """Elimina tipo de trabajador si no tiene trabajadores asociados"""
        # Verificar que no tenga trabajadores
        workers_count = self.count("Id_Tipo_Trabajador = ?", (tipo_id,))
        if workers_count > 0:
            raise ValidationError("tipo_id", tipo_id, 
                                f"No se puede eliminar tipo con {workers_count} trabajadores asociados")
        
        query = "DELETE FROM Tipo_Trabajadores WHERE id = ?"
        affected_rows = self._execute_query(query, (tipo_id,), fetch_all=False, use_cache=False)
        
        success = affected_rows > 0
        if success:
            print(f"🗑️ Tipo de trabajador eliminado: ID {tipo_id}")
        
        return success
    
    def worker_type_exists(self, tipo_id: int) -> bool:
        """Verifica si existe un tipo de trabajador"""
        query = "SELECT COUNT(*) as count FROM Tipo_Trabajadores WHERE id = ?"
        result = self._execute_query(query, (tipo_id,), fetch_one=True)
        return result['count'] > 0 if result else False
    
    def worker_type_name_exists(self, tipo_nombre: str) -> bool:
        """Verifica si existe un nombre de tipo"""
        query = "SELECT COUNT(*) as count FROM Tipo_Trabajadores WHERE Tipo = ?"
        result = self._execute_query(query, (tipo_nombre.strip(),), fetch_one=True)
        return result['count'] > 0 if result else False
    
    # ===============================
    # CONSULTAS CON LABORATORIO
    # ===============================
    
    def get_worker_lab_assignments(self, trabajador_id: int) -> List[Dict[str, Any]]:
        """Obtiene asignaciones de laboratorio del trabajador"""
        query = """
        SELECT l.*, 
            CONCAT(p.Nombre, ' ', p.Apellido_Paterno, ' ', p.Apellido_Materno) as paciente_completo,
            p.Cedula as paciente_cedula
        FROM Laboratorio l
        INNER JOIN Pacientes p ON l.Id_Paciente = p.id
        WHERE l.Id_Trabajador = ?
        ORDER BY l.id DESC
        """
        return self._execute_query(query, (trabajador_id,))
    
    def get_worker_with_lab_stats(self, trabajador_id: int) -> Optional[Dict[str, Any]]:
        """Obtiene trabajador con estadísticas de laboratorio"""
        worker = self.get_worker_with_type(trabajador_id)
        if not worker:
            return None
        
        lab_assignments = self.get_worker_lab_assignments(trabajador_id)
        worker['asignaciones_laboratorio'] = lab_assignments
        worker['total_laboratorio'] = len(lab_assignments)
        
        return worker
    
    def get_laboratory_workload(self) -> List[Dict[str, Any]]:
        """Obtiene carga de trabajo de personal de laboratorio"""
        query = """
        SELECT t.id, 
            t.Nombre, t.Apellido_Paterno, t.Apellido_Materno,
            CONCAT(t.Nombre, ' ', t.Apellido_Paterno, ' ', t.Apellido_Materno) as nombre_completo,
            tt.Tipo as tipo_trabajador,
            COUNT(l.id) as examenes_asignados
        FROM Trabajadores t
        INNER JOIN Tipo_Trabajadores tt ON t.Id_Tipo_Trabajador = tt.id
        LEFT JOIN Laboratorio l ON t.id = l.Id_Trabajador
        WHERE tt.area_funcional = 'LABORATORIO'
        GROUP BY t.id, t.Nombre, t.Apellido_Paterno, t.Apellido_Materno, tt.Tipo
        ORDER BY examenes_asignados, t.Nombre
        """
        return self._execute_query(query)
    
    # ===============================
    # MÉTODOS PARA MÉDICOS Y ESPECIALIDADES
    # ===============================
    
    @cached_query('medicos_especialidades', ttl=600)
    def get_medicos_con_especialidades(self) -> List[Dict[str, Any]]:
        """
        Obtiene trabajadores médicos con sus especialidades asignadas
        Reemplaza funcionalidad de DoctorRepository.get_all_with_specialties()
        """
        query = """
        SELECT 
            t.id,
            t.Nombre,
            t.Apellido_Paterno,
            t.Apellido_Materno,
            t.Matricula,
            t.Especialidad as especialidad_descriptiva,
            tt.Tipo as tipo_trabajador,
            COUNT(DISTINCT te.Id_Especialidad) as total_especialidades,
            STRING_AGG(e.Nombre, ', ') as especialidades_nombres,
            AVG(e.Precio_Normal) as precio_promedio_normal,
            AVG(e.Precio_Emergencia) as precio_promedio_emergencia
        FROM Trabajadores t
        INNER JOIN Tipo_Trabajadores tt ON t.Id_Tipo_Trabajador = tt.id
        LEFT JOIN Trabajador_Especialidad te ON t.id = te.Id_Trabajador
        LEFT JOIN Especialidad e ON te.Id_Especialidad = e.id
        WHERE tt.area_funcional = 'MEDICO'
        GROUP BY t.id, t.Nombre, t.Apellido_Paterno, t.Apellido_Materno, 
                 t.Matricula, t.Especialidad, tt.Tipo
        ORDER BY t.Nombre, t.Apellido_Paterno
        """
        return self._execute_query(query)
    
    def get_medico_con_especialidades(self, trabajador_id: int) -> Optional[Dict[str, Any]]:
        """
        Obtiene médico específico con todas sus especialidades
        Usa area_funcional para validar que sea médico - CORREGIDO
        """
        # Verificar que sea médico usando area_funcional
        validate_query = """
        SELECT 
            t.id, t.Nombre, t.Apellido_Paterno, t.Apellido_Materno,
            t.Matricula, t.Especialidad as especialidad_descriptiva,
            tt.Tipo as tipo_nombre, tt.area_funcional
        FROM Trabajadores t
        INNER JOIN Tipo_Trabajadores tt ON t.Id_Tipo_Trabajador = tt.id
        WHERE t.id = ? AND tt.area_funcional = 'MEDICO'
        """
        
        medico = self._execute_query(validate_query, (trabajador_id,), fetch_one=True)
        
        if not medico:
            print(f"⚠️ Trabajador {trabajador_id} no es médico (no tiene área funcional 'MEDICO')")
            return None
        
        print(f"✅ Trabajador {trabajador_id} validado como médico - Área: {medico.get('area_funcional')}")
        
        # Obtener especialidades asignadas
        especialidades_query = """
        SELECT 
            e.id, e.Nombre, e.Detalles,
            e.Precio_Normal, e.Precio_Emergencia,
            te.Es_Principal, te.Fecha_Asignacion
        FROM Trabajador_Especialidad te
        INNER JOIN Especialidad e ON te.Id_Especialidad = e.id
        WHERE te.Id_Trabajador = ?
        ORDER BY te.Es_Principal DESC, e.Nombre
        """
        
        especialidades = self._execute_query(especialidades_query, (trabajador_id,))
        medico['especialidades'] = especialidades
        medico['total_especialidades'] = len(especialidades)
        
        # Calcular estadísticas de precios
        if especialidades:
            precios_normales = [float(e['Precio_Normal']) for e in especialidades]
            precios_emergencia = [float(e['Precio_Emergencia']) for e in especialidades]
            
            medico['precio_min_normal'] = min(precios_normales)
            medico['precio_max_normal'] = max(precios_normales)
            medico['precio_promedio_normal'] = sum(precios_normales) / len(precios_normales)
            
            medico['precio_min_emergencia'] = min(precios_emergencia)
            medico['precio_max_emergencia'] = max(precios_emergencia)
            medico['precio_promedio_emergencia'] = sum(precios_emergencia) / len(precios_emergencia)
        
        return medico
    
    def get_medicos_por_especialidad(self, especialidad_id: int) -> List[Dict[str, Any]]:
        """
        Obtiene médicos que tienen asignada una especialidad específica
        """
        query = """
        SELECT 
            t.id,
            t.Nombre,
            t.Apellido_Paterno,
            t.Apellido_Materno,
            t.Matricula,
            te.Es_Principal,
            te.Fecha_Asignacion
        FROM Trabajador_Especialidad te
        INNER JOIN Trabajadores t ON te.Id_Trabajador = t.id
        WHERE te.Id_Especialidad = ?
        ORDER BY te.Es_Principal DESC, t.Nombre
        """
        return self._execute_query(query, (especialidad_id,))
    
    def asignar_especialidad(self, trabajador_id: int, especialidad_id: int, 
                        es_principal: bool = False) -> bool:
        """
        Asigna una especialidad a un médico
        
        Args:
            trabajador_id: ID del trabajador (debe ser médico con area_funcional='MEDICO')
            especialidad_id: ID de la especialidad a asignar
            es_principal: Si es la especialidad principal del médico
            
        Returns:
            True si se asignó correctamente
        """
        # Validar que el trabajador existe y es médico usando área funcional
        validate_query = """
        SELECT COUNT(*) as count
        FROM Trabajadores t
        INNER JOIN Tipo_Trabajadores tt ON t.Id_Tipo_Trabajador = tt.id
        WHERE t.id = ? AND tt.area_funcional = 'MEDICO'
        """
        
        validation_result = self._execute_query(validate_query, (trabajador_id,), fetch_one=True)
        
        if not validation_result or validation_result['count'] == 0:
            print(f"⚠️ Trabajador {trabajador_id} no es médico (validación por área funcional)")
            raise ValidationError("trabajador_id", trabajador_id, 
                                "Trabajador no encontrado o no es médico")
        
        print(f"✅ Trabajador {trabajador_id} validado como médico para asignar especialidad")
        
        # Validar que la especialidad existe
        esp_query = "SELECT id FROM Especialidad WHERE id = ?"
        esp_exists = self._execute_query(esp_query, (especialidad_id,), fetch_one=True)
        if not esp_exists:
            raise ValidationError("especialidad_id", especialidad_id, 
                                "Especialidad no encontrada")
        
        # Verificar si ya está asignada
        check_query = """
        SELECT id FROM Trabajador_Especialidad 
        WHERE Id_Trabajador = ? AND Id_Especialidad = ?
        """
        already_assigned = self._execute_query(check_query, 
                                            (trabajador_id, especialidad_id), 
                                            fetch_one=True)
        
        if already_assigned:
            print(f"⚠️ Especialidad {especialidad_id} ya está asignada al trabajador {trabajador_id}")
            return True
        
        # Si es principal, quitar la marca de principal de otras
        if es_principal:
            update_query = """
            UPDATE Trabajador_Especialidad 
            SET Es_Principal = 0 
            WHERE Id_Trabajador = ?
            """
            self._execute_query(update_query, (trabajador_id,), fetch_all=False, use_cache=False)
        
        # Insertar asignación
        insert_query = """
        INSERT INTO Trabajador_Especialidad (Id_Trabajador, Id_Especialidad, Es_Principal)
        VALUES (?, ?, ?)
        """
        affected = self._execute_query(insert_query, 
                                    (trabajador_id, especialidad_id, 1 if es_principal else 0),
                                    fetch_all=False, use_cache=False)
        
        success = affected > 0
        if success:
            print(f"✅ Especialidad {especialidad_id} asignada al médico {trabajador_id}")
            self.invalidate_worker_caches()
        
        return success
    
    def desasignar_especialidad(self, trabajador_id: int, especialidad_id: int) -> bool:
        """
        Desasigna una especialidad de un médico
        
        Args:
            trabajador_id: ID del trabajador
            especialidad_id: ID de la especialidad a desasignar
            
        Returns:
            True si se desasignó correctamente
        """
        delete_query = """
        DELETE FROM Trabajador_Especialidad 
        WHERE Id_Trabajador = ? AND Id_Especialidad = ?
        """
        
        affected = self._execute_query(delete_query, 
                                      (trabajador_id, especialidad_id),
                                      fetch_all=False, use_cache=False)
        
        success = affected > 0
        if success:
            print(f"🗑️ Especialidad {especialidad_id} desasignada del médico {trabajador_id}")
            self.invalidate_worker_caches()
        
        return success
    
    def search_medicos(self, search_term: str, limit: int = 50) -> List[Dict[str, Any]]:
        """
        Búsqueda de médicos por nombre, apellidos o matrícula
        Usa area_funcional para filtrar solo médicos - CORREGIDO
        """
        if not search_term or len(search_term.strip()) < 2:
            return []
        
        search_term = f"%{search_term.strip()}%"
        
        query = """
        SELECT TOP (?)
            t.id,
            t.Nombre,
            t.Apellido_Paterno,
            t.Apellido_Materno,
            t.Matricula,
            t.Especialidad as especialidad_descriptiva,
            tt.Tipo as tipo_trabajador,
            COUNT(DISTINCT te.Id_Especialidad) as total_especialidades
        FROM Trabajadores t
        INNER JOIN Tipo_Trabajadores tt ON t.Id_Tipo_Trabajador = tt.id
        LEFT JOIN Trabajador_Especialidad te ON t.id = te.Id_Trabajador
        WHERE tt.area_funcional = 'MEDICO'
        AND (t.Nombre LIKE ? OR t.Apellido_Paterno LIKE ? OR t.Apellido_Materno LIKE ? 
            OR t.Matricula LIKE ? OR t.Especialidad LIKE ?)
        GROUP BY t.id, t.Nombre, t.Apellido_Paterno, t.Apellido_Materno, 
                t.Matricula, t.Especialidad, tt.Tipo
        ORDER BY t.Nombre, t.Apellido_Paterno
        """
        
        return self._execute_query(query, (limit, search_term, search_term, 
                                        search_term, search_term, search_term))
    
    # ===============================
    # VALIDACIONES Y UTILIDADES
    # ===============================
    
    def validate_matricula_unique(self, matricula: str, exclude_id: int = None) -> bool:
        """Valida que la matrícula sea única"""
        if not matricula:
            return True
        
        if exclude_id:
            query = "SELECT COUNT(*) as count FROM Trabajadores WHERE Matricula = ? AND id != ?"
            result = self._execute_query(query, (matricula.strip(), exclude_id), fetch_one=True)
        else:
            query = "SELECT COUNT(*) as count FROM Trabajadores WHERE Matricula = ?"
            result = self._execute_query(query, (matricula.strip(),), fetch_one=True)
        
        return result['count'] == 0 if result else True
    
    def get_worker_by_matricula(self, matricula: str) -> Optional[Dict[str, Any]]:
        """Obtiene trabajador por matrícula"""
        query = """
        SELECT t.*, tt.Tipo as tipo_nombre
        FROM Trabajadores t
        INNER JOIN Tipo_Trabajadores tt ON t.Id_Tipo_Trabajador = tt.id
        WHERE t.Matricula = ?
        """
        return self._execute_query(query, (matricula.strip(),), fetch_one=True)
    
    def get_workers_by_specialty(self, especialidad: str) -> List[Dict[str, Any]]:
        """Obtiene trabajadores por especialidad descriptiva"""
        query = """
        SELECT t.*, tt.Tipo as tipo_nombre
        FROM Trabajadores t
        INNER JOIN Tipo_Trabajadores tt ON t.Id_Tipo_Trabajador = tt.id
        WHERE t.Especialidad LIKE ?
        ORDER BY tt.Tipo, t.Nombre
        """
        return self._execute_query(query, (f"%{especialidad}%",))
    
    # ===============================
    # ESTADÍSTICAS Y REPORTES
    # ===============================
    
    def get_worker_statistics(self) -> Dict[str, Any]:
        """Obtiene estadísticas generales de trabajadores"""
        total_query = "SELECT COUNT(*) as total FROM Trabajadores"
        total_result = self._execute_query(total_query, fetch_one=True)
        
        tipos_query = """
        SELECT tt.Tipo, COUNT(t.id) as cantidad
        FROM Tipo_Trabajadores tt
        LEFT JOIN Trabajadores t ON tt.id = t.Id_Tipo_Trabajador
        GROUP BY tt.id, tt.Tipo
        ORDER BY cantidad DESC
        """
        tipos_result = self._execute_query(tipos_query)
        
        especialidades_query = """
        SELECT Especialidad, COUNT(*) as cantidad
        FROM Trabajadores
        WHERE Especialidad IS NOT NULL AND Especialidad != ''
        GROUP BY Especialidad
        ORDER BY cantidad DESC
        """
        especialidades_result = self._execute_query(especialidades_query)
        
        return {
            'total_trabajadores': total_result['total'] if total_result else 0,
            'distribucion_tipos': tipos_result,
            'distribucion_especialidades': especialidades_result,
            'tipos_unicos': len(tipos_result),
            'especialidades_unicas': len(especialidades_result)
        }
    
    def get_worker_type_statistics(self) -> Dict[str, Any]:
        """Obtiene estadísticas de tipos de trabajadores"""
        query = """
        SELECT 
            tt.id,
            tt.Tipo,
            COUNT(t.id) as total_trabajadores,
            COUNT(DISTINCT t.Especialidad) as especialidades_unicas,
            AVG(CASE WHEN t.Matricula IS NOT NULL THEN 1 ELSE 0 END) * 100 as porcentaje_con_matricula
        FROM Tipo_Trabajadores tt
        LEFT JOIN Trabajadores t ON tt.id = t.Id_Tipo_Trabajador
        GROUP BY tt.id, tt.Tipo
        ORDER BY total_trabajadores DESC
        """
        return self._execute_query(query)
    
    def get_worker_activity_report(self, days: int = 30) -> List[Dict[str, Any]]:
        """Reporte de actividad de trabajadores en laboratorio"""
        query = """
        SELECT 
            t.id,
            t.Nombre,
            t.Apellido_Paterno,
            t.Apellido_Materno,
            tt.Tipo as tipo_nombre,
            COUNT(l.id) as total_examenes,
            COALESCE(SUM(l.Precio_Normal), 0) as valor_total,
            MAX(l.Fecha_Registro) as ultima_actividad
        FROM Trabajadores t
        INNER JOIN Tipo_Trabajadores tt ON t.Id_Tipo_Trabajador = tt.id
        LEFT JOIN Laboratorio l ON t.id = l.Id_Trabajador
        WHERE l.Fecha_Registro >= DATEADD(day, -?, GETDATE())
        GROUP BY t.id, t.Nombre, t.Apellido_Paterno, t.Apellido_Materno, tt.Tipo
        ORDER BY total_examenes DESC, valor_total DESC
        """
        return self._execute_query(query, (days,))
    
    # ===============================
    # GESTIÓN DE CACHÉ
    # ===============================
    
    def invalidate_worker_caches(self):
        """Invalida cachés relacionados con trabajadores"""
        cache_types = ['trabajadores_tipos', 'tipos_trabajadores', 'medicos_especialidades']
        from ..core.cache_system import invalidate_after_update
        invalidate_after_update(cache_types)
    
    # ===============================
    # MÉTODOS DE MIGRACIÓN Y BACKUP
    # ===============================
    
    def export_workers_data(self) -> List[Dict[str, Any]]:
        """Exporta datos completos de trabajadores para backup"""
        query = """
        SELECT 
            t.*,
            tt.Tipo as tipo_nombre,
            tt.descripcion as tipo_descripcion,
            STRING_AGG(e.Nombre, '; ') as especialidades_asignadas
        FROM Trabajadores t
        INNER JOIN Tipo_Trabajadores tt ON t.Id_Tipo_Trabajador = tt.id
        LEFT JOIN Trabajador_Especialidad te ON t.id = te.Id_Trabajador
        LEFT JOIN Especialidad e ON te.Id_Especialidad = e.id
        GROUP BY t.id, t.Nombre, t.Apellido_Paterno, t.Apellido_Materno,
                 t.Id_Tipo_Trabajador, t.Especialidad, t.Matricula,
                 tt.Tipo, tt.descripcion
        ORDER BY tt.Tipo, t.Nombre, t.Apellido_Paterno
        """
        return self._execute_query(query)
    
    def import_workers_data(self, workers_data: List[Dict[str, Any]]) -> Dict[str, int]:
        """
        Importa datos de trabajadores desde backup
        
        Args:
            workers_data: Lista de trabajadores a importar
            
        Returns:
            Diccionario con estadísticas de importación
        """
        stats = {
            'total': len(workers_data),
            'creados': 0,
            'actualizados': 0,
            'errores': 0
        }
        
        for worker in workers_data:
            try:
                # Verificar si existe por matrícula o por nombre completo
                existing_worker = None
                
                if worker.get('Matricula'):
                    existing_worker = self.get_worker_by_matricula(worker['Matricula'])
                
                if not existing_worker:
                    # Buscar por nombre completo
                    search_term = f"{worker.get('Nombre', '')} {worker.get('Apellido_Paterno', '')}"
                    results = self.search_workers(search_term, limit=5)
                    for result in results:
                        if (result.get('Nombre') == worker.get('Nombre') and
                            result.get('Apellido_Paterno') == worker.get('Apellido_Paterno') and
                            result.get('Apellido_Materno') == worker.get('Apellido_Materno')):
                            existing_worker = result
                            break
                
                if existing_worker:
                    # Actualizar existente
                    success = self.update_worker(
                        existing_worker['id'],
                        nombre=worker.get('Nombre'),
                        apellido_paterno=worker.get('Apellido_Paterno'),
                        apellido_materno=worker.get('Apellido_Materno'),
                        tipo_trabajador_id=worker.get('Id_Tipo_Trabajador'),
                        especialidad=worker.get('Especialidad'),
                        matricula=worker.get('Matricula')
                    )
                    if success:
                        stats['actualizados'] += 1
                    else:
                        stats['errores'] += 1
                else:
                    # Crear nuevo
                    worker_id = self.create_worker(
                        nombre=worker.get('Nombre', ''),
                        apellido_paterno=worker.get('Apellido_Paterno', ''),
                        apellido_materno=worker.get('Apellido_Materno', ''),
                        tipo_trabajador_id=worker.get('Id_Tipo_Trabajador'),
                        especialidad=worker.get('Especialidad'),
                        matricula=worker.get('Matricula')
                    )
                    if worker_id:
                        stats['creados'] += 1
                    else:
                        stats['errores'] += 1
                        
            except Exception as e:
                print(f"❌ Error importando trabajador {worker.get('Nombre')}: {str(e)}")
                stats['errores'] += 1
        
        return stats