from typing import List, Dict, Any, Optional
from datetime import datetime, timedelta

from ..core.base_repository import BaseRepository
from ..core.excepciones import (
    ValidationError, ExceptionHandler, validate_required
)
from ..core.cache_system import cached_query
from ..core.utils import (
    validate_required_string, validate_positive_number, safe_float
)

class LaboratorioRepository(BaseRepository):
    """Repository para gestión de Exámenes de Laboratorio - ACTUALIZADO con búsqueda por cédula"""
    
    def __init__(self):
        super().__init__('Laboratorio', 'laboratorio')
        print("🔬 LaboratorioRepository inicializado")
    
    # ===============================
    # IMPLEMENTACIÓN ABSTRACTA
    # ===============================
    
    def get_active(self) -> List[Dict[str, Any]]:
        """Obtiene todos los exámenes de laboratorio con información completa"""
        return self.get_all_with_details()
    
    # ===============================
    # GESTIÓN DE TIPOS DE ANÁLISIS
    # ===============================
    
    def get_analysis_types(self) -> List[Dict[str, Any]]:
        """Obtiene tipos de análisis disponibles"""
        query = """
        SELECT id, Nombre, Descripcion, Precio_Normal, Precio_Emergencia 
        FROM Tipos_Analisis 
        ORDER BY Nombre
        """
        return self._execute_query(query)

    def get_analysis_type_by_id(self, tipo_id: int) -> Optional[Dict[str, Any]]:
        """Obtiene tipo de análisis por ID"""
        query = "SELECT * FROM Tipos_Analisis WHERE id = ?"
        return self._execute_query(query, (tipo_id,), fetch_one=True)
    
    def _analysis_type_exists(self, tipo_id: int) -> bool:
        """Verifica si existe el tipo de análisis"""
        query = "SELECT COUNT(*) as count FROM Tipos_Analisis WHERE id = ?"
        result = self._execute_query(query, (tipo_id,), fetch_one=True)
        return result['count'] > 0 if result else False
    
    # ===============================
    # GESTIÓN DE PACIENTES - NUEVO
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
                CONCAT(Nombre, ' ', Apellido_Paterno, ' ', Apellido_Materno) as nombre_completo
            FROM Pacientes
            WHERE Cedula = ?
            """
            
            result = self._execute_query(query, (cedula_clean,), fetch_one=True)
            
            if result:
                print(f"👤 Paciente encontrado por cédula: {cedula_clean} -> {result['nombre_completo']}")
                return result
            
            return None
            
        except Exception as e:
            print(f"❌ Error buscando paciente por cédula: {e}")
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
                CONCAT(Nombre, ' ', Apellido_Paterno, ' ', Apellido_Materno) as nombre_completo
            FROM Pacientes
            WHERE Cedula LIKE ?
            ORDER BY 
                CASE WHEN Cedula = ? THEN 1 ELSE 2 END,
                Cedula
            """
            
            search_pattern = f"%{cedula_clean}%"
            return self._execute_query(query, (limit, search_pattern, cedula_clean))
            
        except Exception as e:
            print(f"❌ Error en búsqueda parcial por cédula: {e}")
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
            
            patient_id = self.insert(patient_data)
            print(f"👤 Nuevo paciente creado: {nombre} {apellido_paterno} - ID: {patient_id}")
            
            return patient_id
            
        except Exception as e:
            print(f"❌ Error gestionando paciente: {e}")
            raise ValidationError("paciente", str(e), "Error creando/buscando paciente")
    
    # ===============================
    # CRUD ESPECÍFICO - CORREGIDO
    # ===============================
    
    def create_lab_exam(self, paciente_id: int, tipo_analisis_id: int, tipo: str = "Normal", 
                   trabajador_id: int = None, usuario_id: int = 10, detalles: str = None) -> int:
        """Crea nuevo examen de laboratorio"""
        validate_required(paciente_id, "paciente_id")
        validate_required(tipo_analisis_id, "tipo_analisis_id")
        validate_required(usuario_id, "usuario_id")
        
        # Verificar entidades
        if not self._patient_exists(paciente_id):
            raise ValidationError("paciente_id", paciente_id, "Paciente no encontrado")
        if not self._analysis_type_exists(tipo_analisis_id):
            raise ValidationError("tipo_analisis_id", tipo_analisis_id, "Tipo de análisis no encontrado")
        if trabajador_id and not self._worker_exists(trabajador_id):
            raise ValidationError("trabajador_id", trabajador_id, "Trabajador no encontrado")
        
        lab_data = {
            'Detalles': detalles or f"Examen de laboratorio",
            'tipo': tipo.capitalize(),
            'Id_Paciente': paciente_id,
            'Id_Trabajador': trabajador_id,
            'Id_Tipo_Analisis': tipo_analisis_id,
            'Fecha': datetime.now(),
            'Id_RegistradoPor': usuario_id
        }
        
        lab_id = self.insert(lab_data)
        print(f"🧪 Examen creado - ID {lab_id}")
        return lab_id
    
    def update_lab_exam(self, lab_id: int, tipo_analisis_id: int = None, 
                       tipo_servicio: str = None, trabajador_id: int = None,
                       detalles: str = None) -> bool:
        """Actualiza examen de laboratorio existente"""
        # Verificar existencia
        existing_exam = self.get_by_id(lab_id)
        if not existing_exam:
            raise ValidationError("lab_id", lab_id, "Examen de laboratorio no encontrado")
        
        update_data = {}
        
        if tipo_analisis_id is not None:
            if not self._analysis_type_exists(tipo_analisis_id):
                raise ValidationError("tipo_analisis_id", tipo_analisis_id, "Tipo de análisis no encontrado")
            
            # Obtener nombre del nuevo tipo
            tipo_analisis = self.get_analysis_type_by_id(tipo_analisis_id)
            update_data['Id_Tipo_Analisis'] = tipo_analisis_id
            update_data['Nombre'] = tipo_analisis['Nombre']
        
        if tipo_servicio is not None:
            if tipo_servicio not in ['Normal', 'Emergencia']:
                raise ValidationError("tipo_servicio", tipo_servicio, "Tipo de servicio debe ser Normal o Emergencia")
            update_data['tipo'] = tipo_servicio
        
        if trabajador_id is not None:
            if trabajador_id and not self._worker_exists(trabajador_id):
                raise ValidationError("trabajador_id", trabajador_id, "Trabajador no encontrado")
            update_data['Id_Trabajador'] = trabajador_id if trabajador_id != 0 else None
        
        if detalles is not None:
            update_data['Detalles'] = detalles.strip() if detalles else None
        
        if not update_data:
            return True
        
        success = self.update(lab_id, update_data)
        if success:
            print(f"🔬 Examen de laboratorio actualizado: ID {lab_id}")
        
        return success
    
    def assign_worker_to_exam(self, lab_id: int, trabajador_id: int) -> bool:
        """Asigna trabajador a examen de laboratorio"""
        return self.update_lab_exam(lab_id, trabajador_id=trabajador_id)
    
    def unassign_worker_from_exam(self, lab_id: int) -> bool:
        """Desasigna trabajador de examen"""
        return self.update_lab_exam(lab_id, trabajador_id=0)
    
    # ===============================
    # CONSULTAS CON RELACIONES - ACTUALIZADAS (SIN EDAD)
    # ===============================
    
    @cached_query('laboratorio_completo', ttl=300)
    def get_all_with_details(self, limit: int = 100) -> List[Dict[str, Any]]:
        """Obtiene todos los exámenes con información completa - ACTUALIZADO sin edad"""
        query = """
        SELECT l.id, l.Detalles as detalles_examen, l.tipo, l.Fecha,
            -- Paciente (SIN EDAD, CON CÉDULA)
            CONCAT(p.Nombre, ' ', p.Apellido_Paterno, ' ', p.Apellido_Materno) as paciente_completo,
            p.Cedula as paciente_cedula,
            p.Nombre as paciente_nombre, 
            p.Apellido_Paterno as paciente_apellido_p,
            p.Apellido_Materno as paciente_apellido_m,
            -- Tipo de Análisis
            ta.Nombre as tipo_analisis,
            ta.Descripcion as detalles_analisis,
            ta.Precio_Normal, ta.Precio_Emergencia,
            -- Precio según tipo
            CASE 
                WHEN l.tipo = 'Normal' THEN ta.Precio_Normal 
                ELSE ta.Precio_Emergencia 
            END as precio,
            -- Trabajador (puede ser NULL)
            l.Id_Trabajador,
            CASE 
                WHEN t.id IS NOT NULL THEN CONCAT(t.Nombre, ' ', t.Apellido_Paterno, ' ', t.Apellido_Materno)
                ELSE 'Sin asignar'
            END as trabajador_completo,
            tt.Tipo as trabajador_tipo,
            -- Usuario registro
            CONCAT(u.Nombre, ' ', u.Apellido_Paterno) as registrado_por,
            -- IDs para referencias
            l.Id_Paciente, l.Id_Tipo_Analisis, l.Id_RegistradoPor
        FROM Laboratorio l
        INNER JOIN Pacientes p ON l.Id_Paciente = p.id
        INNER JOIN Tipos_Analisis ta ON l.Id_Tipo_Analisis = ta.id
        INNER JOIN Usuario u ON l.Id_RegistradoPor = u.id
        LEFT JOIN Trabajadores t ON l.Id_Trabajador = t.id
        LEFT JOIN Tipo_Trabajadores tt ON t.Id_Tipo_Trabajador = tt.id
        ORDER BY l.Fecha DESC
        OFFSET 0 ROWS FETCH NEXT ? ROWS ONLY
        """
        return self._execute_query(query, (limit,))
    
    def get_lab_exam_by_id_complete(self, lab_id: int) -> Optional[Dict[str, Any]]:
        """Obtiene examen específico con información completa - ACTUALIZADO sin edad"""
        query = """
        SELECT l.id, l.Nombre, l.Detalles, l.tipo, l.Fecha,
               -- Paciente (SIN EDAD)
               p.id as paciente_id,
               CONCAT(p.Nombre, ' ', p.Apellido_Paterno, ' ', p.Apellido_Materno) as paciente_completo,
               p.Nombre as paciente_nombre, p.Apellido_Paterno as paciente_apellido_p,
               p.Apellido_Materno as paciente_apellido_m,
               p.Cedula as paciente_cedula,
               -- Tipo de Análisis
               ta.id as tipo_analisis_id, ta.Nombre as tipo_analisis,
               ta.Descripcion as detalles_analisis,
               ta.Precio_Normal, ta.Precio_Emergencia,
               -- Trabajador (puede ser NULL)
               t.id as trabajador_id,
               CASE 
                   WHEN t.id IS NOT NULL THEN CONCAT(t.Nombre, ' ', t.Apellido_Paterno, ' ', t.Apellido_Materno)
                   ELSE 'Sin asignar'
               END as trabajador_completo,
               t.Nombre as trabajador_nombre, t.Apellido_Paterno as trabajador_apellido_p,
               t.Apellido_Materno as trabajador_apellido_m,
               tt.id as trabajador_tipo_id, tt.Tipo as trabajador_tipo,
               -- Usuario que registró
               u.Nombre as usuario_nombre, u.Apellido_Paterno as usuario_apellido
        FROM Laboratorio l
        INNER JOIN Pacientes p ON l.Id_Paciente = p.id
        INNER JOIN Tipos_Analisis ta ON l.Id_Tipo_Analisis = ta.id
        INNER JOIN Usuario u ON l.Id_RegistradoPor = u.id
        LEFT JOIN Trabajadores t ON l.Id_Trabajador = t.id
        LEFT JOIN Tipo_Trabajadores tt ON t.Id_Tipo_Trabajador = tt.id
        WHERE l.id = ?
        """
        return self._execute_query(query, (lab_id,), fetch_one=True)
    
    # ===============================
    # BÚSQUEDAS POR ENTIDADES - ACTUALIZADAS
    # ===============================
    
    def get_exams_by_patient(self, paciente_id: int) -> List[Dict[str, Any]]:
        """Obtiene exámenes de un paciente específico"""
        query = """
        SELECT l.*, ta.Nombre as tipo_analisis, ta.Precio_Normal, ta.Precio_Emergencia,
               CASE 
                   WHEN t.id IS NOT NULL THEN CONCAT(t.Nombre, ' ', t.Apellido_Paterno)
                   ELSE 'Sin asignar'
               END as trabajador_nombre,
               tt.Tipo as trabajador_tipo
        FROM Laboratorio l
        INNER JOIN Tipos_Analisis ta ON l.Id_Tipo_Analisis = ta.id
        LEFT JOIN Trabajadores t ON l.Id_Trabajador = t.id
        LEFT JOIN Tipo_Trabajadores tt ON t.Id_Tipo_Trabajador = tt.id
        WHERE l.Id_Paciente = ?
        ORDER BY l.Fecha DESC
        """
        return self._execute_query(query, (paciente_id,))
    
    def get_exams_by_worker(self, trabajador_id: int) -> List[Dict[str, Any]]:
        """Obtiene exámenes asignados a un trabajador"""
        query = """
        SELECT l.*, ta.Nombre as tipo_analisis,
               CONCAT(p.Nombre, ' ', p.Apellido_Paterno, ' ', p.Apellido_Materno) as paciente_completo,
               p.Cedula as paciente_cedula
        FROM Laboratorio l
        INNER JOIN Pacientes p ON l.Id_Paciente = p.id
        INNER JOIN Tipos_Analisis ta ON l.Id_Tipo_Analisis = ta.id
        WHERE l.Id_Trabajador = ?
        ORDER BY l.Fecha DESC
        """
        return self._execute_query(query, (trabajador_id,))
    
    def get_unassigned_exams(self) -> List[Dict[str, Any]]:
        """Obtiene exámenes sin trabajador asignado"""
        query = """
        SELECT l.*, ta.Nombre as tipo_analisis,
               CONCAT(p.Nombre, ' ', p.Apellido_Paterno, ' ', p.Apellido_Materno) as paciente_completo,
               p.Cedula as paciente_cedula
        FROM Laboratorio l
        INNER JOIN Pacientes p ON l.Id_Paciente = p.id
        INNER JOIN Tipos_Analisis ta ON l.Id_Tipo_Analisis = ta.id
        WHERE l.Id_Trabajador IS NULL
        ORDER BY l.Fecha DESC
        """
        return self._execute_query(query)
    
    def get_assigned_exams(self) -> List[Dict[str, Any]]:
        """Obtiene exámenes con trabajador asignado"""
        query = """
        SELECT l.*, ta.Nombre as tipo_analisis,
               CONCAT(p.Nombre, ' ', p.Apellido_Paterno, ' ', p.Apellido_Materno) as paciente_completo,
               p.Cedula as paciente_cedula,
               CONCAT(t.Nombre, ' ', t.Apellido_Paterno) as trabajador_nombre,
               tt.Tipo as trabajador_tipo
        FROM Laboratorio l
        INNER JOIN Pacientes p ON l.Id_Paciente = p.id
        INNER JOIN Tipos_Analisis ta ON l.Id_Tipo_Analisis = ta.id
        INNER JOIN Trabajadores t ON l.Id_Trabajador = t.id
        INNER JOIN Tipo_Trabajadores tt ON t.Id_Tipo_Trabajador = tt.id
        ORDER BY l.Fecha DESC
        """
        return self._execute_query(query)
    
    # ===============================
    # BÚSQUEDAS ESPECÍFICAS - ACTUALIZADAS
    # ===============================
    
    def search_exams(self, search_term: str, limit: int = 50) -> List[Dict[str, Any]]:
        """Búsqueda por nombre del examen, paciente o trabajador"""
        if not search_term:
            return []
        
        search_term = f"%{search_term.strip()}%"
        
        query = """
        SELECT l.*, ta.Nombre as tipo_analisis,
               CONCAT(p.Nombre, ' ', p.Apellido_Paterno, ' ', p.Apellido_Materno) as paciente_completo,
               p.Cedula as paciente_cedula,
               CASE 
                   WHEN t.id IS NOT NULL THEN CONCAT(t.Nombre, ' ', t.Apellido_Paterno)
                   ELSE 'Sin asignar'
               END as trabajador_nombre
        FROM Laboratorio l
        INNER JOIN Pacientes p ON l.Id_Paciente = p.id
        INNER JOIN Tipos_Analisis ta ON l.Id_Tipo_Analisis = ta.id
        LEFT JOIN Trabajadores t ON l.Id_Trabajador = t.id
        WHERE l.Nombre LIKE ? OR l.Detalles LIKE ? OR ta.Nombre LIKE ?
           OR p.Nombre LIKE ? OR p.Apellido_Paterno LIKE ? OR p.Apellido_Materno LIKE ?
           OR t.Nombre LIKE ? OR t.Apellido_Paterno LIKE ? OR t.Apellido_Materno LIKE ?
           OR p.Cedula LIKE ?
        ORDER BY l.Fecha DESC
        OFFSET 0 ROWS FETCH NEXT ? ROWS ONLY
        """
        
        return self._execute_query(query, (search_term, search_term, search_term, 
                                         search_term, search_term, search_term,
                                         search_term, search_term, search_term,
                                         search_term, limit))
    
    # ===============================
    # TRABAJADORES DISPONIBLES
    # ===============================
    
    def get_available_lab_workers(self) -> List[Dict[str, Any]]:
        """Obtiene trabajadores disponibles para laboratorio"""
        query = """
        SELECT t.id, 
               t.Nombre, t.Apellido_Paterno, t.Apellido_Materno,
               CONCAT(t.Nombre, ' ', t.Apellido_Paterno, ' ', t.Apellido_Materno) as nombre_completo,
               tt.Tipo as tipo_trabajador,
               COUNT(l.id) as examenes_asignados
        FROM Trabajadores t
        INNER JOIN Tipo_Trabajadores tt ON t.Id_Tipo_Trabajador = tt.id
        LEFT JOIN Laboratorio l ON t.id = l.Id_Trabajador
        WHERE tt.Tipo LIKE '%Laboratorio%' OR tt.Tipo LIKE '%Técnico%' OR tt.Tipo LIKE '%Lab%'
        GROUP BY t.id, t.Nombre, t.Apellido_Paterno, t.Apellido_Materno, tt.Tipo
        ORDER BY examenes_asignados, t.Nombre
        """
        return self._execute_query(query)
    
    def get_exam_types_list(self) -> List[str]:
        """Obtiene lista de tipos de exámenes disponibles desde Tipos_Analisis"""
        query = "SELECT DISTINCT Nombre FROM Tipos_Analisis ORDER BY Nombre"
        result = self._execute_query(query)
        return [row['Nombre'] for row in result]
    
    # ===============================
    # ESTADÍSTICAS - ACTUALIZADAS
    # ===============================
    
    @cached_query('stats_laboratorio', ttl=300)
    def get_laboratory_statistics(self) -> Dict[str, Any]:
        """Estadísticas completas de laboratorio"""
        # Estadísticas generales
        general_query = """
        SELECT 
            COUNT(*) as total_examenes,
            COUNT(DISTINCT Id_Paciente) as pacientes_unicos,
            COUNT(DISTINCT CASE WHEN Id_Trabajador IS NOT NULL THEN Id_Trabajador END) as trabajadores_asignados,
            COUNT(CASE WHEN Id_Trabajador IS NULL THEN 1 END) as examenes_sin_asignar,
            COUNT(CASE WHEN tipo = 'Normal' THEN 1 END) as examenes_normales,
            COUNT(CASE WHEN tipo = 'Emergencia' THEN 1 END) as examenes_emergencia
        FROM Laboratorio
        """
        
        # Por tipo de análisis
        analysis_types_query = """
        SELECT ta.Nombre as tipo_analisis,
               COUNT(l.id) as cantidad,
               AVG(ta.Precio_Normal) as precio_promedio_normal,
               AVG(ta.Precio_Emergencia) as precio_promedio_emergencia,
               COUNT(DISTINCT l.Id_Paciente) as pacientes_unicos
        FROM Laboratorio l
        INNER JOIN Tipos_Analisis ta ON l.Id_Tipo_Analisis = ta.id
        GROUP BY ta.Nombre, ta.Precio_Normal, ta.Precio_Emergencia
        ORDER BY cantidad DESC
        """
        
        # Por trabajador
        workers_query = """
        SELECT CONCAT(t.Nombre, ' ', t.Apellido_Paterno) as trabajador,
               tt.Tipo as trabajador_tipo,
               COUNT(l.id) as examenes_asignados,
               COUNT(DISTINCT l.Id_Paciente) as pacientes_unicos
        FROM Laboratorio l
        INNER JOIN Trabajadores t ON l.Id_Trabajador = t.id
        INNER JOIN Tipo_Trabajadores tt ON t.Id_Tipo_Trabajador = tt.id
        GROUP BY t.id, t.Nombre, t.Apellido_Paterno, tt.Tipo
        ORDER BY examenes_asignados DESC
        """
        
        general_stats = self._execute_query(general_query, fetch_one=True)
        analysis_types_stats = self._execute_query(analysis_types_query)
        workers_stats = self._execute_query(workers_query)
        
        return {
            'general': general_stats,
            'por_tipo_analisis': analysis_types_stats,
            'por_trabajador': workers_stats
        }
    
    # ===============================
    # VALIDACIONES - CORREGIDAS
    # ===============================
    
    def _patient_exists(self, paciente_id: int) -> bool:
        """Verifica si existe el paciente"""
        query = "SELECT COUNT(*) as count FROM Pacientes WHERE id = ?"
        result = self._execute_query(query, (paciente_id,), fetch_one=True)
        return result['count'] > 0 if result else False
    
    def _worker_exists(self, trabajador_id: int) -> bool:
        """Verifica si existe el trabajador"""
        query = "SELECT COUNT(*) as count FROM Trabajadores WHERE id = ?"
        result = self._execute_query(query, (trabajador_id,), fetch_one=True)
        return result['count'] > 0 if result else False
    
    def validate_lab_exam_exists(self, lab_id: int) -> bool:
        """Valida que el examen existe"""
        return self.exists('id', lab_id)
    
    # ===============================
    # CACHÉ
    # ===============================
    
    def invalidate_laboratory_caches(self):
        """Invalida cachés relacionados con laboratorio"""
        cache_types = ['laboratorio', 'laboratorio_completo', 'stats_laboratorio']
        from ..core.cache_system import invalidate_after_update
        invalidate_after_update(cache_types)
    
    def _invalidate_cache_after_modification(self):
        """Override para invalidación específica"""
        super()._invalidate_cache_after_modification()
        self.invalidate_laboratory_caches()