from typing import List, Dict, Any, Optional
from datetime import datetime

from ..core.base_repository import BaseRepository
from ..core.excepciones import (
    ValidationError, ExceptionHandler, validate_required
)
from ..core.cache_system import cached_query
from ..core.utils import (
    normalize_name, validate_required_string,
    safe_int, calculate_percentage
)

class PacienteRepository(BaseRepository):
    """Repository para gestión de Pacientes - ACTUALIZADO sin campo Edad"""
    
    def __init__(self):
        super().__init__('Pacientes', 'pacientes')
        print("👥 PacienteRepository inicializado - SIN campo Edad")
    
    # ===============================
    # IMPLEMENTACIÓN ABSTRACTA
    # ===============================
    
    def get_active(self) -> List[Dict[str, Any]]:
        """Obtiene todos los pacientes activos"""
        return self.get_all(order_by="Nombre, Apellido_Paterno")
    
    # ===============================
    # CRUD ESPECÍFICO - SIN EDAD
    # ===============================
    
    def create_patient(self, nombre: str, apellido_paterno: str, 
                      apellido_materno: str, cedula: str) -> int:
        """Crea nuevo paciente - SOLO con datos básicos obligatorios"""
        nombre = normalize_name(nombre.strip()) if nombre.strip() else "Sin nombre"
        apellido_paterno = normalize_name(apellido_paterno.strip()) if apellido_paterno.strip() else ""
        apellido_materno = normalize_name(apellido_materno.strip()) if apellido_materno.strip() else ""
        
        # Validar cédula obligatoria
        if not cedula or not cedula.strip():
            raise ValidationError("cedula", cedula, "Cédula es obligatoria")
        
        cedula = cedula.strip()
        if len(cedula) < 5:
            raise ValidationError("cedula", cedula, "Cédula debe tener al menos 5 dígitos")
        
        # Verificar que no existe cédula duplicada
        existing = self.search_by_cedula_exact(cedula)
        if existing:
            raise ValidationError("cedula", cedula, f"Ya existe paciente con cédula {cedula}")
        
        patient_data = {
            'Nombre': nombre,
            'Apellido_Paterno': apellido_paterno,
            'Apellido_Materno': apellido_materno,
            'Cedula': cedula
        }
        
        patient_id = self.insert(patient_data)
        print(f"👥 Paciente creado: {nombre} {apellido_paterno} - Cédula: {cedula} - ID: {patient_id}")
        
        return patient_id
    
    def update_patient(self, paciente_id: int, nombre: str = None, 
                      apellido_paterno: str = None, apellido_materno: str = None,
                      cedula: str = None) -> bool:
        """Actualiza paciente existente - SIN EDAD"""
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
            
        if cedula is not None:
            if cedula.strip():
                cedula = cedula.strip()
                if len(cedula) < 5:
                    raise ValidationError("cedula", cedula, "Cédula debe tener al menos 5 dígitos")
                
                # Verificar duplicado (excluyendo el paciente actual)
                existing = self.search_by_cedula_exact(cedula)
                if existing and existing['id'] != paciente_id:
                    raise ValidationError("cedula", cedula, f"Ya existe otro paciente con cédula {cedula}")
                
                update_data['Cedula'] = cedula
        
        if not update_data:
            return True
        
        success = self.update(paciente_id, update_data)
        if success:
            print(f"👥 Paciente actualizado: ID {paciente_id}")
        
        return success
    
    # ===============================
    # BÚSQUEDAS ESPECÍFICAS - SIN EDAD
    # ===============================
    
    def search_patients(self, search_term: str, limit: int = 50) -> List[Dict[str, Any]]:
        """Búsqueda por nombre, apellidos O cédula"""
        if not search_term:
            return []
        
        search_term = search_term.strip()
        
        # Si parece ser una cédula (solo números), buscar por cédula primero
        if search_term.isdigit() and len(search_term) >= 5:
            cedula_results = self.search_by_cedula(search_term)
            if cedula_results:
                return cedula_results
        
        # Búsqueda por nombre/apellidos
        search_pattern = f"%{search_term}%"
        
        query = """
        SELECT TOP (?) * FROM Pacientes 
        WHERE Nombre LIKE ? OR Apellido_Paterno LIKE ? OR Apellido_Materno LIKE ?
        OR (Cedula IS NOT NULL AND Cedula LIKE ?)
        ORDER BY 
            CASE 
                WHEN Cedula = ? THEN 1
                WHEN LOWER(Nombre) LIKE LOWER(?) THEN 2
                WHEN LOWER(Apellido_Paterno) LIKE LOWER(?) THEN 3
                ELSE 4
            END,
            Nombre, Apellido_Paterno
        """
        
        start_pattern = f"{search_term}%"
        
        return self._execute_query(query, (
            limit, search_pattern, search_pattern, search_pattern, search_pattern,
            search_term, start_pattern, start_pattern
        ))
    
    def search_by_cedula(self, cedula: str) -> List[Dict[str, Any]]:
        """Búsqueda específica por cédula"""
        if not cedula or not cedula.strip():
            return []
        
        cedula = cedula.strip()
        
        # Búsqueda exacta primero
        query_exact = "SELECT * FROM Pacientes WHERE Cedula = ?"
        results = self._execute_query(query_exact, (cedula,))
        
        if results:
            return results
        
        # Si no hay resultados exactos, búsqueda parcial
        query_partial = "SELECT TOP (10) * FROM Pacientes WHERE Cedula LIKE ? ORDER BY Cedula"
        return self._execute_query(query_partial, (f"%{cedula}%",))
    
    def search_by_cedula_exact(self, cedula: str) -> Optional[Dict[str, Any]]:
        """Búsqueda exacta por cédula - devuelve un solo resultado"""
        if not cedula or not cedula.strip():
            return None
        
        query = "SELECT * FROM Pacientes WHERE Cedula = ?"
        return self._execute_query(query, (cedula.strip(),), fetch_one=True)
    
    def search_patients_incremental(self, termino: str, limit: int = 10) -> List[Dict[str, Any]]:
        """Búsqueda incremental para autocompletado - SIN EDAD"""
        if not termino or len(termino.strip()) < 2:
            return []
        
        termino_clean = termino.strip()
        
        # Si parece cédula, buscar por cédula
        if termino_clean.isdigit():
            cedula_results = self.search_by_cedula(termino_clean)
            if cedula_results:
                # Formatear para autocompletado - SIN EDAD
                for result in cedula_results:
                    result['nombre_completo'] = f"{result.get('Nombre', '')} {result.get('Apellido_Paterno', '')} {result.get('Apellido_Materno', '')}".strip()
                return cedula_results[:limit]
        
        # Búsqueda por nombre
        search_pattern = f"%{termino_clean.lower()}%"
        
        query = """
        SELECT TOP (?) 
            id, Nombre, Apellido_Paterno, Apellido_Materno, 
            Cedula,
            CONCAT(Nombre, ' ', Apellido_Paterno, ' ', Apellido_Materno) as nombre_completo
        FROM Pacientes 
        WHERE LOWER(Nombre) LIKE ? 
        OR LOWER(Apellido_Paterno) LIKE ? 
        OR LOWER(Apellido_Materno) LIKE ?
        OR LOWER(CONCAT(Nombre, ' ', Apellido_Paterno)) LIKE ?
        OR (Cedula IS NOT NULL AND Cedula LIKE ?)
        ORDER BY 
            CASE 
                WHEN LOWER(Nombre) LIKE ? THEN 1
                WHEN LOWER(Apellido_Paterno) LIKE ? THEN 2
                WHEN Cedula LIKE ? THEN 3
                ELSE 4
            END,
            Nombre, Apellido_Paterno
        """
        
        start_pattern = f"{termino_clean.lower()}%"
        
        return self._execute_query(query, (
            limit, 
            search_pattern, search_pattern, search_pattern, search_pattern, 
            f"%{termino_clean}%",  # Para cédula
            start_pattern, start_pattern, f"{termino_clean}%"
        ))
    
    def search_patients_by_field(self, field_name: str, value: str, limit: int = 10) -> List[Dict[str, Any]]:
        """Búsqueda específica por campo - SIN EDAD"""
        if not value or len(value.strip()) < 2:
            return []
        
        valid_fields = ['Nombre', 'Apellido_Paterno', 'Apellido_Materno', 'Cedula']
        if field_name not in valid_fields:
            return []
        
        value_clean = value.strip()
        
        # Para cédula, búsqueda exacta y parcial
        if field_name == 'Cedula':
            query = f"""
            SELECT TOP (?) 
                id, Nombre, Apellido_Paterno, Apellido_Materno, Cedula,
                CONCAT(Nombre, ' ', Apellido_Paterno, ' ', Apellido_Materno) as nombre_completo
            FROM Pacientes 
            WHERE {field_name} = ? OR {field_name} LIKE ?
            ORDER BY 
                CASE WHEN {field_name} = ? THEN 1 ELSE 2 END,
                {field_name}
            """
            return self._execute_query(query, (limit, value_clean, f"%{value_clean}%", value_clean))
        
        # Para otros campos, búsqueda por patrón
        search_pattern = f"%{value_clean.lower()}%"
        
        query = f"""
        SELECT TOP (?) 
            id, Nombre, Apellido_Paterno, Apellido_Materno, Cedula,
            CONCAT(Nombre, ' ', Apellido_Paterno, ' ', Apellido_Materno) as nombre_completo
        FROM Pacientes 
        WHERE LOWER({field_name}) LIKE ?
        ORDER BY {field_name}, Nombre
        """
        
        return self._execute_query(query, (limit, search_pattern))
    
    # ===============================
    # FUNCIONES DE GESTIÓN INTELIGENTE - SIN EDAD
    # ===============================
    
    def buscar_o_crear_paciente_simple(self, nombre: str, apellido_paterno: str, 
                                      apellido_materno: str = "", cedula: str = None) -> int:
        """Busca paciente similar o crea nuevo - SIN EDAD, cédula obligatoria"""
        nombre = nombre.strip()
        apellido_paterno = apellido_paterno.strip() 
        apellido_materno = apellido_materno.strip()
        
        if not nombre or len(nombre) < 2:
            raise ValidationError("nombre", nombre, "Nombre es obligatorio")
        if not apellido_paterno:
            apellido_paterno = "Sin apellido"
        if not cedula or len(cedula.strip()) < 5:
            raise ValidationError("cedula", cedula, "Cédula es obligatoria (mínimo 5 dígitos)")

        cedula_clean = cedula.strip()

        # 1. Buscar por cédula exacta primero
        existing_by_cedula = self.search_by_cedula_exact(cedula_clean)
        if existing_by_cedula:
            print(f"👤 Paciente encontrado por cédula: {cedula_clean} -> ID {existing_by_cedula['id']}")
            return existing_by_cedula['id']

        # 2. Crear nuevo paciente (ahora requiere cédula)
        try:
            paciente_id = self.create_patient(nombre, apellido_paterno, apellido_materno, cedula_clean)
            print(f"👤 Nuevo paciente: {nombre} {apellido_paterno} -> ID {paciente_id}")
            return paciente_id
        except Exception as e:
            print(f"❌ Error creando paciente: {e}")
            raise

    def buscar_pacientes_por_nombre_exacto(self, nombre: str, apellido_paterno: str, apellido_materno: str = ""):
        """Busca pacientes con nombre exacto - SIN EDAD"""
        query = """
        SELECT TOP 5 *
        FROM Pacientes 
        WHERE LOWER(Nombre) = LOWER(?) 
        AND LOWER(Apellido_Paterno) = LOWER(?)
        """
        params = [nombre.strip(), apellido_paterno.strip()]
        
        if apellido_materno and apellido_materno.strip():
            query += " AND LOWER(Apellido_Materno) = LOWER(?)"
            params.append(apellido_materno.strip())
        
        query += " ORDER BY id DESC"
        return self._execute_query(query, tuple(params))

    # ===============================
    # CONSULTAS CON RELACIONES - SIN EDAD
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
        SELECT l.*, 
               ta.Nombre as tipo_analisis,
               CONCAT(t.Nombre, ' ', t.Apellido_Paterno) as trabajador_nombre,
               tt.Tipo as trabajador_tipo
        FROM Laboratorio l
        LEFT JOIN Tipos_Analisis ta ON l.Id_Tipo_Analisis = ta.id
        LEFT JOIN Trabajadores t ON l.Id_Trabajador = t.id
        LEFT JOIN Tipo_Trabajadores tt ON t.Id_Tipo_Trabajador = tt.id
        WHERE l.Id_Paciente = ?
        ORDER BY l.Fecha DESC
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
        SELECT c.id, c.Fecha, c.Detalles, c.tipo_consulta,
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
        SELECT l.id, l.Nombre, l.Detalles, l.tipo, l.Fecha,
               ta.Nombre as tipo_analisis, ta.Precio_Normal, ta.Precio_Emergencia,
               CONCAT(t.Nombre, ' ', t.Apellido_Paterno) as trabajador_encargado,
               tt.Tipo as trabajador_tipo
        FROM Laboratorio l
        LEFT JOIN Tipos_Analisis ta ON l.Id_Tipo_Analisis = ta.id
        LEFT JOIN Trabajadores t ON l.Id_Trabajador = t.id
        LEFT JOIN Tipo_Trabajadores tt ON t.Id_Tipo_Trabajador = tt.id
        WHERE l.Id_Paciente = ?
        ORDER BY l.Fecha DESC
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
    # ESTADÍSTICAS - SIN EDAD
    # ===============================
    
    @cached_query('stats_pacientes', ttl=600)
    def get_patient_statistics(self) -> Dict[str, Any]:
        """Estadísticas de pacientes - SIN referencias a Edad"""
        # Estadísticas básicas
        general_query = """
        SELECT 
            COUNT(*) as total_pacientes,
            COUNT(CASE WHEN Cedula IS NOT NULL THEN 1 END) as pacientes_con_cedula,
            COUNT(CASE WHEN LEN(Nombre) > 10 THEN 1 END) as nombres_largos,
            COUNT(CASE WHEN Apellido_Materno IS NOT NULL AND Apellido_Materno != '' THEN 1 END) as con_apellido_materno
        FROM Pacientes
        """
        
        # Top apellidos más frecuentes
        surnames_query = """
        SELECT TOP 10 Apellido_Paterno, COUNT(*) as cantidad
        FROM Pacientes
        WHERE Apellido_Paterno IS NOT NULL AND Apellido_Paterno != ''
        GROUP BY Apellido_Paterno
        ORDER BY cantidad DESC
        """
        
        # Nombres más comunes
        names_query = """
        SELECT TOP 10 Nombre, COUNT(*) as cantidad
        FROM Pacientes
        WHERE Nombre IS NOT NULL AND Nombre != ''
        GROUP BY Nombre
        ORDER BY cantidad DESC
        """
        
        general_stats = self._execute_query(general_query, fetch_one=True)
        surnames_stats = self._execute_query(surnames_query)
        names_stats = self._execute_query(names_query)
        
        return {
            'general': general_stats,
            'apellidos_frecuentes': surnames_stats,
            'nombres_frecuentes': names_stats
        }
    
    # ===============================
    # UTILIDADES
    # ===============================
    
    def validate_patient_exists(self, paciente_id: int) -> bool:
        """Valida que el paciente existe"""
        return self.exists('id', paciente_id)
    
    def get_patient_full_name(self, paciente_id: int) -> str:
        """Obtiene nombre completo del paciente"""
        patient = self.get_by_id(paciente_id)
        if not patient:
            return ""
        
        return f"{patient['Nombre']} {patient['Apellido_Paterno']} {patient['Apellido_Materno']}".strip()
    
    def validate_cedula_unique(self, cedula: str, exclude_id: int = None) -> bool:
        """Valida que la cédula sea única (excluyendo opcionalmente un ID)"""
        if not cedula:
            return False
        
        query = "SELECT id FROM Pacientes WHERE Cedula = ?"
        params = [cedula.strip()]
        
        if exclude_id:
            query += " AND id != ?"
            params.append(exclude_id)
        
        result = self._execute_query(query, params, fetch_one=True)
        return result is None
    
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