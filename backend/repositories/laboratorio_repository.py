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
    """Repository para gestión de Exámenes de Laboratorio"""
    
    def __init__(self):
        super().__init__('Laboratorio', 'laboratorio')
        print("🔬 LaboratorioRepository inicializado")
    
    # ===============================
    # IMPLEMENTACIÓN ABSTRACTA
    # ===============================
    
    def get_active(self) -> List[Dict[str, Any]]:
        """Obtiene todos los exámenes de laboratorio con información completa"""
        return self.get_all_with_details()
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
    
    # ===============================
    # CRUD ESPECÍFICO
    # ===============================
    
    def create_lab_exam(self, paciente_id: int, tipo_analisis_id: int, tipo: str = "Normal", 
                   trabajador_id: int = None, usuario_id: int = 10) -> int:
        """
        Crea nuevo examen de laboratorio
        """
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
            'Id_Paciente': paciente_id,
            'Id_Tipo_Analisis': tipo_analisis_id,
            'Id_Trabajador': trabajador_id,
            'Fecha': datetime.now(),
            'Id_RegistradoPor': usuario_id,
            'Tipo': tipo.capitalize()
        }
        
        lab_id = self.insert(lab_data)
        print(f"🧪 Examen creado: ID {lab_id}")
        return lab_id
    
    def update_lab_exam(self, lab_id: int, nombre: str = None, precio_normal: float = None,
                       precio_emergencia: float = None, detalles: str = None,
                       trabajador_id: int = None) -> bool:
        """Actualiza examen de laboratorio existente"""
        # Verificar existencia
        existing_exam = self.get_by_id(lab_id)
        if not existing_exam:
            raise ValidationError("lab_id", lab_id, "Examen de laboratorio no encontrado")
        
        update_data = {}
        
        if nombre is not None:
            nombre = validate_required_string(nombre, "nombre", 3)
            update_data['Nombre'] = nombre.strip()
        
        if precio_normal is not None:
            precio_normal = validate_positive_number(precio_normal, "precio_normal")
            update_data['Precio_Normal'] = precio_normal
        
        if precio_emergencia is not None:
            precio_emergencia = validate_positive_number(precio_emergencia, "precio_emergencia")
            update_data['Precio_Emergencia'] = precio_emergencia
        
        if detalles is not None:
            update_data['Detalles'] = detalles.strip()
        
        if trabajador_id is not None:
            if trabajador_id > 0 and not self._worker_exists(trabajador_id):
                raise ValidationError("trabajador_id", trabajador_id, "Trabajador no encontrado")
            update_data['Id_Trabajador'] = trabajador_id if trabajador_id > 0 else None
        
        # Validar precios si ambos están presentes
        current_normal = update_data.get('Precio_Normal', existing_exam['Precio_Normal'])
        current_emergencia = update_data.get('Precio_Emergencia', existing_exam['Precio_Emergencia'])
        
        if current_emergencia < current_normal:
            raise ValidationError("precios", current_emergencia,
                                "Precio de emergencia debe ser mayor o igual al normal")
        
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
        return self.update_lab_exam(lab_id, trabajador_id=0)  # 0 se convierte a None
    
    # ===============================
    # CONSULTAS CON RELACIONES
    # ===============================
    
    @cached_query('laboratorio_completo', ttl=300)
    def get_all_with_details(self, limit: int = 100) -> List[Dict[str, Any]]:
        """Obtiene exámenes con información completa"""
        query = """
        SELECT l.id, l.Fecha, l.Tipo,
            -- Paciente
            CONCAT(p.Nombre, ' ', p.Apellido_Paterno, ' ', p.Apellido_Materno) as paciente_completo,
            p.Edad as paciente_edad,
            -- Tipo de Análisis
            ta.Nombre as tipo_analisis,
            ta.Descripcion as detalles,
            ta.Precio_Normal, ta.Precio_Emergencia,
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
        """Obtiene examen específico con información completa"""
        query = """
        SELECT l.id, l.Nombre, l.Detalles, l.Precio_Normal, l.Precio_Emergencia,
               -- Paciente
               p.id as paciente_id,
               CONCAT(p.Nombre, ' ', p.Apellido_Paterno, ' ', p.Apellido_Materno) as paciente_completo,
               p.Nombre as paciente_nombre, p.Apellido_Paterno as paciente_apellido_p,
               p.Apellido_Materno as paciente_apellido_m, p.Edad as paciente_edad,
               -- Trabajador (puede ser NULL)
               t.id as trabajador_id,
               CASE 
                   WHEN t.id IS NOT NULL THEN CONCAT(t.Nombre, ' ', t.Apellido_Paterno, ' ', t.Apellido_Materno)
                   ELSE 'Sin asignar'
               END as trabajador_completo,
               t.Nombre as trabajador_nombre, t.Apellido_Paterno as trabajador_apellido_p,
               t.Apellido_Materno as trabajador_apellido_m,
               tt.id as trabajador_tipo_id, tt.Tipo as trabajador_tipo
        FROM Laboratorio l
        INNER JOIN Pacientes p ON l.Id_Paciente = p.id
        LEFT JOIN Trabajadores t ON l.Id_Trabajador = t.id
        LEFT JOIN Tipo_Trabajadores tt ON t.Id_Tipo_Trabajador = tt.id
        WHERE l.id = ?
        """
        return self._execute_query(query, (lab_id,), fetch_one=True)
    
    # ===============================
    # BÚSQUEDAS POR ENTIDADES
    # ===============================
    
    def get_exams_by_patient(self, paciente_id: int) -> List[Dict[str, Any]]:
        """Obtiene exámenes de un paciente específico"""
        query = """
        SELECT l.*, 
               CASE 
                   WHEN t.id IS NOT NULL THEN CONCAT(t.Nombre, ' ', t.Apellido_Paterno)
                   ELSE 'Sin asignar'
               END as trabajador_nombre,
               tt.Tipo as trabajador_tipo
        FROM Laboratorio l
        LEFT JOIN Trabajadores t ON l.Id_Trabajador = t.id
        LEFT JOIN Tipo_Trabajadores tt ON t.Id_Tipo_Trabajador = tt.id
        WHERE l.Id_Paciente = ?
        ORDER BY l.id DESC
        """
        return self._execute_query(query, (paciente_id,))
    
    def get_exams_by_worker(self, trabajador_id: int) -> List[Dict[str, Any]]:
        """Obtiene exámenes asignados a un trabajador"""
        query = """
        SELECT l.*, 
               CONCAT(p.Nombre, ' ', p.Apellido_Paterno, ' ', p.Apellido_Materno) as paciente_completo,
               p.Edad as paciente_edad
        FROM Laboratorio l
        INNER JOIN Pacientes p ON l.Id_Paciente = p.id
        WHERE l.Id_Trabajador = ?
        ORDER BY l.id DESC
        """
        return self._execute_query(query, (trabajador_id,))
    
    def get_unassigned_exams(self) -> List[Dict[str, Any]]:
        """Obtiene exámenes sin trabajador asignado"""
        query = """
        SELECT l.*, 
               CONCAT(p.Nombre, ' ', p.Apellido_Paterno, ' ', p.Apellido_Materno) as paciente_completo,
               p.Edad as paciente_edad
        FROM Laboratorio l
        INNER JOIN Pacientes p ON l.Id_Paciente = p.id
        WHERE l.Id_Trabajador IS NULL
        ORDER BY l.id DESC
        """
        return self._execute_query(query)
    
    def get_assigned_exams(self) -> List[Dict[str, Any]]:
        """Obtiene exámenes con trabajador asignado"""
        query = """
        SELECT l.*, 
               CONCAT(p.Nombre, ' ', p.Apellido_Paterno, ' ', p.Apellido_Materno) as paciente_completo,
               p.Edad as paciente_edad,
               CONCAT(t.Nombre, ' ', t.Apellido_Paterno) as trabajador_nombre,
               tt.Tipo as trabajador_tipo
        FROM Laboratorio l
        INNER JOIN Pacientes p ON l.Id_Paciente = p.id
        INNER JOIN Trabajadores t ON l.Id_Trabajador = t.id
        INNER JOIN Tipo_Trabajadores tt ON t.Id_Tipo_Trabajador = tt.id
        ORDER BY l.id DESC
        """
        return self._execute_query(query)
    
    # ===============================
    # BÚSQUEDAS POR TIPO DE EXAMEN
    # ===============================
    
    def search_exams(self, search_term: str, limit: int = 50) -> List[Dict[str, Any]]:
        """Búsqueda por nombre del examen, paciente o trabajador"""
        if not search_term:
            return []
        
        search_term = f"%{search_term.strip()}%"
        
        query = """
        SELECT l.*, 
               CONCAT(p.Nombre, ' ', p.Apellido_Paterno, ' ', p.Apellido_Materno) as paciente_completo,
               CASE 
                   WHEN t.id IS NOT NULL THEN CONCAT(t.Nombre, ' ', t.Apellido_Paterno)
                   ELSE 'Sin asignar'
               END as trabajador_nombre
        FROM Laboratorio l
        INNER JOIN Pacientes p ON l.Id_Paciente = p.id
        LEFT JOIN Trabajadores t ON l.Id_Trabajador = t.id
        WHERE l.Nombre LIKE ? OR l.Detalles LIKE ?
           OR p.Nombre LIKE ? OR p.Apellido_Paterno LIKE ? OR p.Apellido_Materno LIKE ?
           OR t.Nombre LIKE ? OR t.Apellido_Paterno LIKE ? OR t.Apellido_Materno LIKE ?
        ORDER BY l.id DESC
        OFFSET 0 ROWS FETCH NEXT ? ROWS ONLY
        """
        
        return self._execute_query(query, (search_term, search_term, search_term, 
                                         search_term, search_term, search_term,
                                         search_term, search_term, limit))
    
    def get_exams_by_type(self, exam_name_pattern: str) -> List[Dict[str, Any]]:
        """Obtiene exámenes por tipo/nombre similar"""
        query = """
        SELECT l.*, 
               CONCAT(p.Nombre, ' ', p.Apellido_Paterno) as paciente_nombre,
               CASE 
                   WHEN t.id IS NOT NULL THEN CONCAT(t.Nombre, ' ', t.Apellido_Paterno)
                   ELSE 'Sin asignar'
               END as trabajador_nombre
        FROM Laboratorio l
        INNER JOIN Pacientes p ON l.Id_Paciente = p.id
        LEFT JOIN Trabajadores t ON l.Id_Trabajador = t.id
        WHERE l.Nombre LIKE ?
        ORDER BY l.Nombre, l.id DESC
        """
        return self._execute_query(query, (f"%{exam_name_pattern}%",))
    
    def get_common_exam_types(self, limit: int = 20) -> List[Dict[str, Any]]:
        """Obtiene tipos de exámenes más comunes"""
        query = """
        SELECT l.Nombre, 
               COUNT(*) as cantidad_realizados,
               AVG(l.Precio_Normal) as precio_promedio_normal,
               AVG(l.Precio_Emergencia) as precio_promedio_emergencia,
               COUNT(DISTINCT l.Id_Paciente) as pacientes_unicos
        FROM Laboratorio l
        GROUP BY l.Nombre
        ORDER BY cantidad_realizados DESC, l.Nombre
        OFFSET 0 ROWS FETCH NEXT ? ROWS ONLY
        """
        return self._execute_query(query, (limit,))
    
    # ===============================
    # BÚSQUEDAS POR PRECIO
    # ===============================
    
    def get_exams_by_price_range(self, min_price: float, max_price: float, 
                                use_emergency_price: bool = False) -> List[Dict[str, Any]]:
        """Obtiene exámenes por rango de precio"""
        price_field = "Precio_Emergencia" if use_emergency_price else "Precio_Normal"
        
        query = f"""
        SELECT l.*, 
               CONCAT(p.Nombre, ' ', p.Apellido_Paterno) as paciente_nombre
        FROM Laboratorio l
        INNER JOIN Pacientes p ON l.Id_Paciente = p.id
        WHERE l.{price_field} BETWEEN ? AND ?
        ORDER BY l.{price_field}, l.Nombre
        """
        return self._execute_query(query, (min_price, max_price))
    
    def get_expensive_exams(self, min_price: float = 100.0) -> List[Dict[str, Any]]:
        """Obtiene exámenes más costosos"""
        return self.get_exams_by_price_range(min_price, 999999.0)
    
    def get_affordable_exams(self, max_price: float = 50.0) -> List[Dict[str, Any]]:
        """Obtiene exámenes más económicos"""
        return self.get_exams_by_price_range(0.0, max_price)
    
    # ===============================
    # ESTADÍSTICAS
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
            AVG(Precio_Normal) as precio_promedio_normal,
            AVG(Precio_Emergencia) as precio_promedio_emergencia,
            MIN(Precio_Normal) as precio_min_normal,
            MAX(Precio_Normal) as precio_max_normal
        FROM Laboratorio
        """
        
        # Por tipo de examen
        exam_types_query = """
        SELECT Nombre as tipo_examen,
               COUNT(*) as cantidad,
               AVG(Precio_Normal) as precio_promedio,
               COUNT(DISTINCT Id_Paciente) as pacientes_unicos
        FROM Laboratorio
        GROUP BY Nombre
        ORDER BY cantidad DESC
        """
        
        # Por trabajador
        workers_query = """
        SELECT CONCAT(t.Nombre, ' ', t.Apellido_Paterno) as trabajador,
               tt.Tipo as trabajador_tipo,
               COUNT(l.id) as examenes_asignados,
               COUNT(DISTINCT l.Id_Paciente) as pacientes_unicos,
               AVG(l.Precio_Normal) as valor_promedio_examenes
        FROM Laboratorio l
        INNER JOIN Trabajadores t ON l.Id_Trabajador = t.id
        INNER JOIN Tipo_Trabajadores tt ON t.Id_Tipo_Trabajador = tt.id
        GROUP BY t.id, t.Nombre, t.Apellido_Paterno, tt.Tipo
        ORDER BY examenes_asignados DESC
        """
        
        general_stats = self._execute_query(general_query, fetch_one=True)
        exam_types_stats = self._execute_query(exam_types_query)
        workers_stats = self._execute_query(workers_query)
        
        return {
            'general': general_stats,
            'por_tipo_examen': exam_types_stats,
            'por_trabajador': workers_stats
        }
    
    def get_workload_distribution(self) -> List[Dict[str, Any]]:
        """Obtiene distribución de carga de trabajo"""
        query = """
        SELECT 
            -- Trabajadores con asignaciones
            'CON_ASIGNACIONES' as categoria,
            COUNT(DISTINCT l.Id_Trabajador) as cantidad_trabajadores,
            COUNT(l.id) as total_examenes,
            AVG(examenes_por_trabajador.examenes) as promedio_examenes_por_trabajador
        FROM Laboratorio l
        INNER JOIN (
            SELECT Id_Trabajador, COUNT(*) as examenes
            FROM Laboratorio 
            WHERE Id_Trabajador IS NOT NULL
            GROUP BY Id_Trabajador
        ) examenes_por_trabajador ON l.Id_Trabajador = examenes_por_trabajador.Id_Trabajador
        WHERE l.Id_Trabajador IS NOT NULL
        
        UNION ALL
        
        SELECT 
            'SIN_ASIGNACIONES' as categoria,
            0 as cantidad_trabajadores,
            COUNT(*) as total_examenes,
            0 as promedio_examenes_por_trabajador
        FROM Laboratorio
        WHERE Id_Trabajador IS NULL
        """
        return self._execute_query(query)
    
    def get_patient_lab_summary(self, paciente_id: int) -> Dict[str, Any]:
        """Obtiene resumen de laboratorio de un paciente"""
        stats_query = """
        SELECT 
            COUNT(*) as total_examenes,
            COUNT(DISTINCT Nombre) as tipos_diferentes,
            AVG(Precio_Normal) as costo_promedio_normal,
            SUM(Precio_Normal) as costo_total_normal,
            COUNT(CASE WHEN Id_Trabajador IS NOT NULL THEN 1 END) as examenes_asignados
        FROM Laboratorio
        WHERE Id_Paciente = ?
        """
        
        exams_query = """
        SELECT Nombre as tipo_examen, COUNT(*) as cantidad
        FROM Laboratorio
        WHERE Id_Paciente = ?
        GROUP BY Nombre
        ORDER BY cantidad DESC
        """
        
        stats = self._execute_query(stats_query, (paciente_id,), fetch_one=True)
        exams_breakdown = self._execute_query(exams_query, (paciente_id,))
        
        return {
            'estadisticas': stats,
            'examenes_por_tipo': exams_breakdown
        }
    
    # ===============================
    # UTILIDADES Y VALIDACIONES
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
    
    def get_available_lab_workers(self) -> List[Dict[str, Any]]:
        """Obtiene trabajadores disponibles para laboratorio"""
        query = """
        SELECT t.id, 
               CONCAT(t.Nombre, ' ', t.Apellido_Paterno, ' ', t.Apellido_Materno) as nombre_completo,
               tt.Tipo as tipo_trabajador,
               COUNT(l.id) as examenes_asignados
        FROM Trabajadores t
        INNER JOIN Tipo_Trabajadores tt ON t.Id_Tipo_Trabajador = tt.id
        LEFT JOIN Laboratorio l ON t.id = l.Id_Trabajador
        WHERE tt.Tipo LIKE '%Laboratorio%' OR tt.Tipo LIKE '%Técnico%'
        GROUP BY t.id, t.Nombre, t.Apellido_Paterno, t.Apellido_Materno, tt.Tipo
        ORDER BY examenes_asignados, t.Nombre
        """
        return self._execute_query(query)
    
    def get_exam_types_list(self) -> List[str]:
        """Obtiene lista de tipos de exámenes disponibles"""
        query = "SELECT DISTINCT Nombre FROM Laboratorio ORDER BY Nombre"
        result = self._execute_query(query)
        return [row['Nombre'] for row in result]
    
    # ===============================
    # REPORTES
    # ===============================
    
    def get_labs_for_report(self, paciente_id: int = None, trabajador_id: int = None,
                           exam_type: str = None, include_unassigned: bool = False) -> List[Dict[str, Any]]:
        """Obtiene exámenes formateados para reportes"""
        base_query = """
        SELECT l.id, l.Nombre as examen_nombre, l.Detalles, l.Precio_Normal, l.Precio_Emergencia,
               -- Paciente
               CONCAT(p.Nombre, ' ', p.Apellido_Paterno, ' ', p.Apellido_Materno) as paciente_completo,
               p.Edad as paciente_edad,
               -- Trabajador
               CASE 
                   WHEN t.id IS NOT NULL THEN CONCAT(t.Nombre, ' ', t.Apellido_Paterno, ' ', t.Apellido_Materno)
                   ELSE 'Sin asignar'
               END as trabajador_completo,
               tt.Tipo as trabajador_tipo
        FROM Laboratorio l
        INNER JOIN Pacientes p ON l.Id_Paciente = p.id
        LEFT JOIN Trabajadores t ON l.Id_Trabajador = t.id
        LEFT JOIN Tipo_Trabajadores tt ON t.Id_Tipo_Trabajador = tt.id
        """
        
        conditions = []
        params = []
        
        if paciente_id:
            conditions.append("l.Id_Paciente = ?")
            params.append(paciente_id)
        
        if trabajador_id:
            conditions.append("l.Id_Trabajador = ?")
            params.append(trabajador_id)
        
        if exam_type:
            conditions.append("l.Nombre LIKE ?")
            params.append(f"%{exam_type}%")
        
        if include_unassigned:
            conditions.append("l.Id_Trabajador IS NULL")
        
        if conditions:
            base_query += " WHERE " + " AND ".join(conditions)
        
        base_query += " ORDER BY l.Nombre, l.id DESC"
        
        return self._execute_query(base_query, tuple(params))
    
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

    def _analysis_type_exists(self, tipo_id: int) -> bool:
        """Verifica si existe el tipo de análisis"""
        query = "SELECT COUNT(*) as count FROM Tipos_Analisis WHERE id = ?"
        result = self._execute_query(query, (tipo_id,), fetch_one=True)
        return result['count'] > 0 if result else False