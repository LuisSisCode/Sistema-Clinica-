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
    # GESTIÓN DE TIPOS DE TRABAJADORES
    # ===============================
    
    @cached_query('tipos_trabajadores', ttl=1800)
    def get_all_worker_types(self) -> List[Dict[str, Any]]:
        """Obtiene todos los tipos de trabajadores"""
        query = """
        SELECT tt.id, tt.Tipo, tt.descripcion, COUNT(t.id) as total_trabajadores
        FROM Tipo_Trabajadores tt
        LEFT JOIN Trabajadores t ON tt.id = t.Id_Tipo_Trabajador
        GROUP BY tt.id, tt.Tipo, tt.descripcion
        ORDER BY tt.Tipo
        """
        return self._execute_query(query)
        
    
    def get_worker_type_by_id(self, tipo_id: int) -> Optional[Dict[str, Any]]:
        """Obtiene tipo de trabajador por ID"""
        query = "SELECT * FROM Tipo_Trabajadores WHERE id = ?"
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
        """Obtiene carga de trabajo por trabajador de laboratorio"""
        query = """
        SELECT t.id, t.Nombre, t.Apellido_Paterno, t.Apellido_Materno,
               tt.Tipo as tipo_nombre,
               COUNT(l.id) as total_examenes,
               COALESCE(SUM(l.Precio_Normal), 0) as valor_total_examenes
        FROM Trabajadores t
        INNER JOIN Tipo_Trabajadores tt ON t.Id_Tipo_Trabajador = tt.id
        LEFT JOIN Laboratorio l ON t.id = l.Id_Trabajador
        WHERE tt.Tipo LIKE '%Laboratorio%'
        GROUP BY t.id, t.Nombre, t.Apellido_Paterno, t.Apellido_Materno, tt.Tipo
        ORDER BY total_examenes DESC, t.Nombre
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
        WHERE tt.Tipo LIKE '%Médico%' OR tt.Tipo LIKE '%Medico%'
        GROUP BY t.id, t.Nombre, t.Apellido_Paterno, t.Apellido_Materno, 
                 t.Matricula, t.Especialidad, tt.Tipo
        ORDER BY t.Nombre, t.Apellido_Paterno
        """
        return self._execute_query(query)
    
    def get_medico_con_especialidades(self, trabajador_id: int) -> Optional[Dict[str, Any]]:
        """
        Obtiene médico específico con todas sus especialidades
        Reemplaza funcionalidad de DoctorRepository.get_doctor_with_services()
        """
        # Verificar que sea médico
        trabajador = self.get_by_id(trabajador_id)
        if not trabajador:
            return None
        
        # Verificar que sea tipo médico
        tipo_query = """
        SELECT tt.Tipo 
        FROM Trabajadores t
        INNER JOIN Tipo_Trabajadores tt ON t.Id_Tipo_Trabajador = tt.id
        WHERE t.id = ?
        """
        tipo_result = self._execute_query(tipo_query, (trabajador_id,), fetch_one=True)
        
        if not tipo_result or 'Médico' not in tipo_result.get('Tipo', ''):
            print(f"⚠️ Trabajador {trabajador_id} no es médico")
            return None
        
        # Obtener especialidades asignadas
        especialidades_query = """
        SELECT 
            e.id,
            e.Nombre,
            e.Detalles,
            e.Precio_Normal,
            e.Precio_Emergencia,
            te.Es_Principal,
            te.Fecha_Asignacion
        FROM Trabajador_Especialidad te
        INNER JOIN Especialidad e ON te.Id_Especialidad = e.id
        WHERE te.Id_Trabajador = ?
        ORDER BY te.Es_Principal DESC, e.Nombre
        """
        
        especialidades = self._execute_query(especialidades_query, (trabajador_id,))
        trabajador['especialidades'] = especialidades
        trabajador['total_especialidades'] = len(especialidades)
        
        # Calcular estadísticas de precios
        if especialidades:
            precios_normales = [float(e['Precio_Normal']) for e in especialidades]
            precios_emergencia = [float(e['Precio_Emergencia']) for e in especialidades]
            
            trabajador['precio_min_normal'] = min(precios_normales)
            trabajador['precio_max_normal'] = max(precios_normales)
            trabajador['precio_promedio_normal'] = sum(precios_normales) / len(precios_normales)
            
            trabajador['precio_min_emergencia'] = min(precios_emergencia)
            trabajador['precio_max_emergencia'] = max(precios_emergencia)
            trabajador['precio_promedio_emergencia'] = sum(precios_emergencia) / len(precios_emergencia)
        
        return trabajador
    
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
            trabajador_id: ID del trabajador (debe ser médico)
            especialidad_id: ID de la especialidad a asignar
            es_principal: Si es la especialidad principal del médico
            
        Returns:
            True si se asignó correctamente
        """
        # Validar que el trabajador existe y es médico
        trabajador = self.get_medico_con_especialidades(trabajador_id)
        if not trabajador:
            raise ValidationError("trabajador_id", trabajador_id, 
                                "Trabajador no encontrado o no es médico")
        
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
        Reemplaza funcionalidad de DoctorRepository.search_doctors()
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
            COUNT(DISTINCT te.Id_Especialidad) as total_especialidades,
            STRING_AGG(e.Nombre, ', ') as especialidades_nombres
        FROM Trabajadores t
        INNER JOIN Tipo_Trabajadores tt ON t.Id_Tipo_Trabajador = tt.id
        LEFT JOIN Trabajador_Especialidad te ON t.id = te.Id_Trabajador
        LEFT JOIN Especialidad e ON te.Id_Especialidad = e.id
        WHERE (tt.Tipo LIKE '%Médico%' OR tt.Tipo LIKE '%Medico%')
          AND (t.Nombre LIKE ? OR t.Apellido_Paterno LIKE ? 
               OR t.Apellido_Materno LIKE ? OR t.Matricula LIKE ?)
        GROUP BY t.id, t.Nombre, t.Apellido_Paterno, t.Apellido_Materno, 
                 t.Matricula, t.Especialidad, tt.Tipo
        ORDER BY t.Nombre, t.Apellido_Paterno
        """
        
        return self._execute_query(query, (limit, search_term, search_term, 
                                          search_term, search_term))
    
    def get_medicos_activos_simple(self) -> List[Dict[str, Any]]:
        """
        Obtiene lista simple de médicos activos (para ComboBox en QML)
        Reemplaza funcionalidad usada en ConsultaModel
        """
        query = """
        SELECT 
            t.id,
            t.Nombre,
            t.Apellido_Paterno,
            t.Apellido_Materno,
            t.Matricula,
            t.Especialidad as especialidad_descriptiva
        FROM Trabajadores t
        INNER JOIN Tipo_Trabajadores tt ON t.Id_Tipo_Trabajador = tt.id
        WHERE tt.Tipo LIKE '%Médico%' OR tt.Tipo LIKE '%Medico%'
        ORDER BY t.Nombre, t.Apellido_Paterno
        """
        return self._execute_query(query)
    
    def invalidate_medico_caches(self):
        """Invalida cachés relacionados con médicos"""
        cache_types = ['trabajadores', 'trabajadores_tipos', 'medicos_especialidades']
        from ..core.cache_system import invalidate_after_update
        invalidate_after_update(cache_types)
    
    # ===============================
    # ESTADÍSTICAS
    # ===============================
    
    @cached_query('stats_trabajadores', ttl=600)
    def get_worker_statistics(self) -> Dict[str, Any]:
        """Estadísticas completas de trabajadores"""
        # Estadísticas generales
        general_query = """
        SELECT 
            COUNT(*) as total_trabajadores,
            COUNT(DISTINCT Id_Tipo_Trabajador) as tipos_diferentes
        FROM Trabajadores
        """
        
        # Por tipos
        by_type_query = """
        SELECT tt.Tipo, COUNT(t.id) as cantidad,
               ROUND(COUNT(t.id) * 100.0 / (SELECT COUNT(*) FROM Trabajadores), 2) as porcentaje
        FROM Tipo_Trabajadores tt
        LEFT JOIN Trabajadores t ON tt.id = t.Id_Tipo_Trabajador
        GROUP BY tt.id, tt.Tipo
        ORDER BY cantidad DESC
        """
        
        # Trabajadores con más asignaciones de laboratorio
        lab_activity_query = """
        SELECT TOP 10 
               CONCAT(t.Nombre, ' ', t.Apellido_Paterno) as trabajador_nombre,
               tt.Tipo as tipo_nombre,
               COUNT(l.id) as total_examenes_lab
        FROM Trabajadores t
        INNER JOIN Tipo_Trabajadores tt ON t.Id_Tipo_Trabajador = tt.id
        LEFT JOIN Laboratorio l ON t.id = l.Id_Trabajador
        GROUP BY t.id, t.Nombre, t.Apellido_Paterno, tt.Tipo
        HAVING COUNT(l.id) > 0
        ORDER BY total_examenes_lab DESC
        """
        
        general_stats = self._execute_query(general_query, fetch_one=True)
        by_type_stats = self._execute_query(by_type_query)
        lab_activity_stats = self._execute_query(lab_activity_query)
        
        return {
            'general': general_stats,
            'por_tipos': by_type_stats,
            'actividad_laboratorio': lab_activity_stats
        }
    
    def get_workers_without_assignments(self) -> List[Dict[str, Any]]:
        """Trabajadores sin asignaciones de laboratorio"""
        query = """
        SELECT t.*, tt.Tipo as tipo_nombre
        FROM Trabajadores t
        INNER JOIN Tipo_Trabajadores tt ON t.Id_Tipo_Trabajador = tt.id
        LEFT JOIN Laboratorio l ON t.id = l.Id_Trabajador
        WHERE l.Id_Trabajador IS NULL
        ORDER BY tt.Tipo, t.Nombre, t.Apellido_Paterno
        """
        return self._execute_query(query)
    
    # ===============================
    # UTILIDADES
    # ===============================
    
    def get_worker_full_name(self, trabajador_id: int) -> str:
        """Obtiene nombre completo del trabajador"""
        worker = self.get_by_id(trabajador_id)
        if not worker:
            return ""
        
        return f"{worker['Nombre']} {worker['Apellido_Paterno']} {worker['Apellido_Materno']}"
    
    def validate_worker_exists(self, trabajador_id: int) -> bool:
        """Valida que el trabajador existe"""
        return self.exists('id', trabajador_id)
    
    def get_available_worker_types(self) -> List[str]:
        """Obtiene lista de tipos de trabajadores disponibles"""
        query = "SELECT Tipo FROM Tipo_Trabajadores ORDER BY Tipo"
        result = self._execute_query(query)
        return [row['Tipo'] for row in result]
    
    def get_worker_type_distribution(self) -> Dict[str, int]:
        """Obtiene distribución de trabajadores por tipo"""
        by_type_stats = self.get_worker_statistics()['por_tipos']
        return {item['Tipo']: item['cantidad'] for item in by_type_stats}
    
    def matricula_exists(self, matricula: str) -> bool:
        """Verifica si existe una matrícula en el sistema"""
        if not matricula or not matricula.strip():
            return False
        
        query = "SELECT COUNT(*) as count FROM Trabajadores WHERE Matricula = ?"
        result = self._execute_query(query, (matricula.strip(),), fetch_one=True)
        return result['count'] > 0 if result else False

    def validate_matricula_unique(self, matricula: str, exclude_id: int = None) -> bool:
        """Valida que la matrícula sea única (excluyendo un ID específico)"""
        if not matricula or not matricula.strip():
            return True  # Matrícula vacía es válida
        
        query = "SELECT COUNT(*) as count FROM Trabajadores WHERE Matricula = ?"
        params = [matricula.strip()]
        
        if exclude_id:
            query += " AND id != ?"
            params.append(exclude_id)
        
        result = self._execute_query(query, tuple(params), fetch_one=True)
        return result['count'] == 0 if result else True
    
    # ===============================
    # REPORTES
    # ===============================
    
    def get_workers_for_report(self, tipo_id: int = None, include_lab_stats: bool = False) -> List[Dict[str, Any]]:
        """Obtiene trabajadores formateados para reportes"""
        base_query = """
        SELECT t.*, tt.Tipo as tipo_nombre
        """
        
        if include_lab_stats:
            base_query += """
            , COUNT(l.id) as total_examenes_lab,
              COALESCE(SUM(l.Precio_Normal), 0) as valor_examenes_lab
            """
        
        from_clause = """
        FROM Trabajadores t
        INNER JOIN Tipo_Trabajadores tt ON t.Id_Tipo_Trabajador = tt.id
        """
        
        if include_lab_stats:
            from_clause += " LEFT JOIN Laboratorio l ON t.id = l.Id_Trabajador"
        
        where_clause = ""
        params = []
        
        if tipo_id:
            where_clause = " WHERE t.Id_Tipo_Trabajador = ?"
            params.append(tipo_id)
        
        group_clause = ""
        if include_lab_stats:
            group_clause = " GROUP BY t.id, t.Nombre, t.Apellido_Paterno, t.Apellido_Materno, t.Id_Tipo_Trabajador, tt.Tipo"
        
        order_clause = " ORDER BY tt.Tipo, t.Nombre, t.Apellido_Paterno"
        
        final_query = base_query + from_clause + where_clause + group_clause + order_clause
        
        workers = self._execute_query(final_query, tuple(params))
        
        # Agregar información adicional
        for worker in workers:
            worker['nombre_completo'] = f"{worker['Nombre']} {worker['Apellido_Paterno']} {worker['Apellido_Materno']}"
        
        return workers
    
    # ===============================
    # CACHÉ
    # ===============================
    
    def invalidate_worker_caches(self):
        """Invalida cachés de trabajadores"""
        try:
            from ..core.cache_system import invalidate_after_update
            
            cache_types = [
                'trabajadores',
                'trabajadores_activos', 
                'tipos_trabajador',
                'stats_trabajadores',
                'medicos_especialidades'
            ]
            
            invalidate_after_update(cache_types)
            print("🗑️ Cachés de trabajadores invalidados")
            
        except Exception as e:
            print(f"⚠️ Error invalidando cachés: {e}")
    
    def _invalidate_cache_after_modification(self):
        """Override para invalidación específica"""
        super()._invalidate_cache_after_modification()
        self.invalidate_worker_caches()