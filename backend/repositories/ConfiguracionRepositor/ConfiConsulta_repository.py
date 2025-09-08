from typing import List, Dict, Any, Optional

from ...core.base_repository import BaseRepository
from ...core.excepciones import (
    ValidationError, ExceptionHandler, validate_required
)
from ...core.cache_system import cached_query
from ...core.utils import (
    normalize_name, validate_required_string, safe_int
)

class ConfiConsultaRepository(BaseRepository):
    """Repository para gestión de Configuración de Especialidades/Consultas"""
    
    def __init__(self):
        super().__init__('Especialidad', 'confi_consulta')
    
    # ===============================
    # IMPLEMENTACIÓN ABSTRACTA
    # ===============================
    
    def get_active(self) -> List[Dict[str, Any]]:
        """Obtiene todas las especialidades activas"""
        return self.get_all_especialidades()
    
    # ===============================
    # CRUD ESPECÍFICO - ESPECIALIDADES
    # ===============================
    
    def create_especialidad(self, nombre: str, detalles: str = None, 
                           precio_normal: float = 0.0, precio_emergencia: float = 0.0,
                           id_doctor: int = None) -> int:
        """
        Crea nueva especialidad con validaciones
        
        Args:
            nombre: Nombre de la especialidad
            detalles: Descripción de la especialidad
            precio_normal: Precio para consulta normal
            precio_emergencia: Precio para consulta de emergencia
            id_doctor: ID del doctor asignado
            
        Returns:
            ID de la especialidad creada
        """
        # Validaciones
        nombre = validate_required_string(nombre, "nombre", 2)
        validate_required(nombre, "nombre")
        
        # Verificar que el nombre no exista
        if self.especialidad_name_exists(nombre):
            raise ValidationError("nombre", nombre, "La especialidad ya existe")
        
        # Validar precios
        if precio_normal < 0:
            raise ValidationError("precio_normal", precio_normal, "El precio normal debe ser mayor o igual a 0")
        
        if precio_emergencia < 0:
            raise ValidationError("precio_emergencia", precio_emergencia, "El precio de emergencia debe ser mayor o igual a 0")
        
        # Verificar que el doctor existe si se proporciona
        if id_doctor is not None and not self.doctor_exists(id_doctor):
            raise ValidationError("id_doctor", id_doctor, "El doctor especificado no existe")
        
        # Crear especialidad
        especialidad_data = {
            'Nombre': normalize_name(nombre),
            'Precio_Normal': precio_normal,
            'Precio_Emergencia': precio_emergencia
        }
        
        # Agregar detalles si se proporciona
        if detalles and detalles.strip():
            especialidad_data['Detalles'] = detalles.strip()
        else:
            especialidad_data['Detalles'] = None
        
        # Agregar doctor si se proporciona
        if id_doctor is not None:
            especialidad_data['Id_Doctor'] = id_doctor
        else:
            especialidad_data['Id_Doctor'] = None
        
        especialidad_id = self.insert(especialidad_data)
        print(f"🏥 Especialidad creada: {nombre} - ID: {especialidad_id}")
        
        return especialidad_id
    
    def update_especialidad(self, especialidad_id: int, nombre: str = None, 
                           detalles: str = None, precio_normal: float = None,
                           precio_emergencia: float = None, id_doctor: int = None) -> bool:
        """Actualiza especialidad existente"""
        # Verificar existencia
        if not self.get_by_id(especialidad_id):
            raise ValidationError("especialidad_id", especialidad_id, "Especialidad no encontrada")
        
        update_data = {}
        
        if nombre is not None:
            nombre = validate_required_string(nombre, "nombre", 2)
            # Verificar nombre único (excepto el mismo registro)
            if self.especialidad_name_exists(nombre, exclude_id=especialidad_id):
                raise ValidationError("nombre", nombre, "La especialidad ya existe")
            update_data['Nombre'] = normalize_name(nombre)
        
        if detalles is not None:
            update_data['Detalles'] = detalles.strip() if detalles.strip() else None
        
        if precio_normal is not None:
            if precio_normal < 0:
                raise ValidationError("precio_normal", precio_normal, "El precio normal debe ser mayor o igual a 0")
            update_data['Precio_Normal'] = precio_normal
        
        if precio_emergencia is not None:
            if precio_emergencia < 0:
                raise ValidationError("precio_emergencia", precio_emergencia, "El precio de emergencia debe ser mayor o igual a 0")
            update_data['Precio_Emergencia'] = precio_emergencia
        
        if id_doctor is not None:
            if id_doctor > 0 and not self.doctor_exists(id_doctor):
                raise ValidationError("id_doctor", id_doctor, "El doctor especificado no existe")
            update_data['Id_Doctor'] = id_doctor if id_doctor > 0 else None
        
        if not update_data:
            return True
        
        success = self.update(especialidad_id, update_data)
        if success:
            print(f"🏥 Especialidad actualizada: ID {especialidad_id}")
        
        return success
    
    def delete_especialidad(self, especialidad_id: int) -> bool:
        """Elimina especialidad si no tiene consultas asociadas"""
        # Verificar que no tenga consultas asociadas
        consultas_count = self.count_consultas_asociadas(especialidad_id)
        if consultas_count > 0:
            raise ValidationError("especialidad_id", especialidad_id, 
                                f"No se puede eliminar. Tiene {consultas_count} consultas asociadas")
        
        success = self.delete(especialidad_id)
        if success:
            print(f"🗑️ Especialidad eliminada: ID {especialidad_id}")
        
        return success
    
    # ===============================
    # CONSULTAS PRINCIPALES
    # ===============================
    
    @cached_query('especialidades_all', ttl=600)
    def get_all_especialidades(self) -> List[Dict[str, Any]]:
        """Obtiene todas las especialidades con información del doctor"""
        query = """
        SELECT 
            e.id, 
            e.Nombre, 
            e.Detalles, 
            e.Precio_Normal, 
            e.Precio_Emergencia,
            e.Id_Doctor,
            CASE 
                WHEN e.Id_Doctor IS NOT NULL THEN 
                    CONCAT(d.Nombre, ' ', d.Apellido_Paterno, ' ', d.Apellido_Materno)
                ELSE NULL 
            END as nombre_doctor
        FROM Especialidad e
        LEFT JOIN Doctores d ON e.Id_Doctor = d.id
        ORDER BY e.Nombre
        """
        return self._execute_query(query)
    
    def get_especialidad_by_id(self, especialidad_id: int) -> Optional[Dict[str, Any]]:
        """Obtiene especialidad específica por ID"""
        query = """
        SELECT 
            e.id, 
            e.Nombre, 
            e.Detalles, 
            e.Precio_Normal, 
            e.Precio_Emergencia,
            e.Id_Doctor,
            CASE 
                WHEN e.Id_Doctor IS NOT NULL THEN 
                    CONCAT(d.Nombre, ' ', d.Apellido_Paterno, ' ', d.Apellido_Materno)
                ELSE NULL 
            END as nombre_doctor
        FROM Especialidad e
        LEFT JOIN Doctores d ON e.Id_Doctor = d.id
        WHERE e.id = ?
        """
        return self._execute_query(query, (especialidad_id,), fetch_one=True)
    
    def get_especialidad_by_name(self, nombre: str) -> Optional[Dict[str, Any]]:
        """Obtiene especialidad por nombre"""
        query = "SELECT * FROM Especialidad WHERE Nombre = ?"
        return self._execute_query(query, (nombre.strip(),), fetch_one=True)
    
    # ===============================
    # BÚSQUEDAS Y FILTROS
    # ===============================
    
    def search_especialidades(self, search_term: str, limit: int = 50) -> List[Dict[str, Any]]:
        """Búsqueda por nombre o detalles"""
        if not search_term:
            return []
        
        search_term = f"%{search_term.strip()}%"
        
        query = """
        SELECT 
            e.id, 
            e.Nombre, 
            e.Detalles, 
            e.Precio_Normal, 
            e.Precio_Emergencia,
            e.Id_Doctor,
            CASE 
                WHEN e.Id_Doctor IS NOT NULL THEN 
                    CONCAT(d.Nombre, ' ', d.Apellido_Paterno, ' ', d.Apellido_Materno)
                ELSE NULL 
            END as nombre_doctor
        FROM Especialidad e
        LEFT JOIN Doctores d ON e.Id_Doctor = d.id
        WHERE e.Nombre LIKE ? OR e.Detalles LIKE ?
        ORDER BY e.Nombre
        OFFSET 0 ROWS FETCH NEXT ? ROWS ONLY
        """
        
        return self._execute_query(query, (search_term, search_term, limit))
    
    def get_especialidades_por_doctor(self, id_doctor: int) -> List[Dict[str, Any]]:
        """Obtiene especialidades asignadas a un doctor específico"""
        query = """
        SELECT 
            e.id, 
            e.Nombre, 
            e.Detalles, 
            e.Precio_Normal, 
            e.Precio_Emergencia,
            e.Id_Doctor
        FROM Especialidad e
        WHERE e.Id_Doctor = ?
        ORDER BY e.Nombre
        """
        return self._execute_query(query, (id_doctor,))
    
    def get_especialidades_por_rango_precios(self, precio_min: float, precio_max: float) -> List[Dict[str, Any]]:
        """Obtiene especialidades en un rango de precios específico"""
        if precio_max == -1:  # -1 significa sin límite superior
            query = """
            SELECT 
                e.id, 
                e.Nombre, 
                e.Detalles, 
                e.Precio_Normal, 
                e.Precio_Emergencia,
                e.Id_Doctor,
                CASE 
                    WHEN e.Id_Doctor IS NOT NULL THEN 
                        CONCAT(d.Nombre, ' ', d.Apellido_Paterno, ' ', d.Apellido_Materno)
                    ELSE NULL 
                END as nombre_doctor
            FROM Especialidad e
            LEFT JOIN Doctores d ON e.Id_Doctor = d.id
            WHERE e.Precio_Normal >= ?
            ORDER BY e.Precio_Normal
            """
            return self._execute_query(query, (precio_min,))
        else:
            query = """
            SELECT 
                e.id, 
                e.Nombre, 
                e.Detalles, 
                e.Precio_Normal, 
                e.Precio_Emergencia,
                e.Id_Doctor,
                CASE 
                    WHEN e.Id_Doctor IS NOT NULL THEN 
                        CONCAT(d.Nombre, ' ', d.Apellido_Paterno, ' ', d.Apellido_Materno)
                    ELSE NULL 
                END as nombre_doctor
            FROM Especialidad e
            LEFT JOIN Doctores d ON e.Id_Doctor = d.id
            WHERE e.Precio_Normal BETWEEN ? AND ?
            ORDER BY e.Precio_Normal
            """
            return self._execute_query(query, (precio_min, precio_max))
    
    # ===============================
    # VALIDACIONES Y UTILIDADES
    # ===============================
    
    def especialidad_exists(self, especialidad_id: int) -> bool:
        """Verifica si existe una especialidad"""
        query = "SELECT COUNT(*) as count FROM Especialidad WHERE id = ?"
        result = self._execute_query(query, (especialidad_id,), fetch_one=True)
        return result['count'] > 0 if result else False
    
    def especialidad_name_exists(self, nombre: str, exclude_id: int = None) -> bool:
        """Verifica si existe un nombre de especialidad (excluyendo un ID específico)"""
        query = "SELECT COUNT(*) as count FROM Especialidad WHERE Nombre = ?"
        params = [nombre.strip()]
        
        if exclude_id:
            query += " AND id != ?"
            params.append(exclude_id)
        
        result = self._execute_query(query, tuple(params), fetch_one=True)
        return result['count'] > 0 if result else False
    
    def doctor_exists(self, id_doctor: int) -> bool:
        """Verifica si existe un doctor en el sistema"""
        query = "SELECT COUNT(*) as count FROM Doctores WHERE id = ?"
        result = self._execute_query(query, (id_doctor,), fetch_one=True)
        return result['count'] > 0 if result else False
    
    def validate_especialidad_exists(self, especialidad_id: int) -> bool:
        """Valida que la especialidad existe"""
        return self.exists('id', especialidad_id)
    
    def get_available_especialidades_names(self) -> List[str]:
        """Obtiene lista de nombres de especialidades disponibles"""
        query = "SELECT Nombre FROM Especialidad ORDER BY Nombre"
        result = self._execute_query(query)
        return [row['Nombre'] for row in result]
    
    def get_doctores_disponibles(self) -> List[Dict[str, Any]]:
        """Obtiene lista de doctores disponibles para asignar"""
        try:
            query = """
            SELECT 
                id, 
                CONCAT(Nombre, ' ', Apellido_Paterno, ' ', Apellido_Materno) as nombre,
                Especialidad as especialidad,
                Matricula as matricula,
                Edad as edad
            FROM Doctores 
            ORDER BY Apellido_Paterno, Apellido_Materno, Nombre
            """
            result = self._execute_query(query)
            print(f"✅ Doctores cargados exitosamente: {len(result)}")
            return result
            
        except Exception as e:
            print(f"❌ Error cargando doctores: {e}")
            # Devolver lista vacía en caso de error
            return []
    
    # ===============================
    # ESTADÍSTICAS
    # ===============================
    
    @cached_query('stats_especialidades', ttl=600)
    def get_especialidades_statistics(self) -> Dict[str, Any]:
        """Estadísticas de especialidades"""
        query = """
        SELECT 
            COUNT(*) as total_especialidades,
            COUNT(CASE WHEN Id_Doctor IS NOT NULL THEN 1 END) as con_doctor_asignado,
            COUNT(CASE WHEN Id_Doctor IS NULL THEN 1 END) as sin_doctor_asignado,
            AVG(Precio_Normal) as precio_normal_promedio,
            AVG(Precio_Emergencia) as precio_emergencia_promedio,
            MIN(Precio_Normal) as precio_normal_minimo,
            MAX(Precio_Normal) as precio_normal_maximo,
            MIN(Precio_Emergencia) as precio_emergencia_minimo,
            MAX(Precio_Emergencia) as precio_emergencia_maximo
        FROM Especialidad
        """
        
        general_stats = self._execute_query(query, fetch_one=True)
        
        return {
            'general': general_stats
        }
    
    # ===============================
    # REPORTES
    # ===============================
    
    def get_especialidades_for_report(self) -> List[Dict[str, Any]]:
        """Obtiene especialidades formateadas para reportes"""
        query = """
        SELECT 
            e.id, 
            e.Nombre, 
            e.Detalles, 
            e.Precio_Normal, 
            e.Precio_Emergencia,
            e.Id_Doctor,
            CASE 
                WHEN e.Id_Doctor IS NOT NULL THEN 
                    CONCAT(d.Nombre, ' ', d.Apellido_Paterno, ' ', d.Apellido_Materno)
                ELSE NULL 
            END as nombre_doctor,
            d.Especialidad as especialidad_doctor
        FROM Especialidad e
        LEFT JOIN Doctores d ON e.Id_Doctor = d.id
        ORDER BY e.Nombre
        """
        
        especialidades = self._execute_query(query)
        
        # Agregar información adicional
        for especialidad in especialidades:
            if not especialidad.get('Detalles'):
                especialidad['Detalles'] = 'Sin detalles'
            if not especialidad.get('nombre_doctor'):
                especialidad['nombre_doctor'] = 'Sin doctor asignado'
        
        return especialidades
    
    def get_especialidades_summary(self) -> Dict[str, Any]:
        """Resumen de especialidades"""
        query = """
        SELECT 
            e.Nombre, 
            e.Detalles, 
            e.Precio_Normal, 
            e.Precio_Emergencia,
            CASE 
                WHEN e.Id_Doctor IS NOT NULL THEN 
                    CONCAT(d.Nombre, ' ', d.Apellido_Paterno, ' ', d.Apellido_Materno)
                ELSE NULL 
            END as nombre_doctor
        FROM Especialidad e
        LEFT JOIN Doctores d ON e.Id_Doctor = d.id
        ORDER BY e.Nombre
        """
        
        especialidades_data = self._execute_query(query)
        
        # Calcular totales generales
        total_especialidades = len(especialidades_data)
        especialidades_con_doctor = len([item for item in especialidades_data if item.get('nombre_doctor')])
        especialidades_sin_doctor = total_especialidades - especialidades_con_doctor
        
        # Calcular promedios de precios
        precio_normal_promedio = sum(item['Precio_Normal'] for item in especialidades_data) / total_especialidades if total_especialidades > 0 else 0
        precio_emergencia_promedio = sum(item['Precio_Emergencia'] for item in especialidades_data) / total_especialidades if total_especialidades > 0 else 0
        
        return {
            'especialidades': especialidades_data,
            'resumen': {
                'total_especialidades': total_especialidades,
                'especialidades_con_doctor': especialidades_con_doctor,
                'especialidades_sin_doctor': especialidades_sin_doctor,
                'precio_normal_promedio': precio_normal_promedio,
                'precio_emergencia_promedio': precio_emergencia_promedio
            }
        }
    
    # ===============================
    # CACHÉ
    # ===============================
    
    def invalidate_especialidades_caches(self):
        """Invalida cachés relacionados con especialidades"""
        cache_types = ['especialidades_all', 'stats_especialidades', 'confi_consulta']
        from ...core.cache_system import invalidate_after_update
        invalidate_after_update(cache_types)
    
    def _invalidate_cache_after_modification(self):
        """Override para invalidación específica"""
        super()._invalidate_cache_after_modification()
        self.invalidate_especialidades_caches()

    def count_consultas_asociadas(self, especialidad_id: int) -> int:
        """Cuenta consultas asociadas a una especialidad específica"""
        query = "SELECT COUNT(*) as count FROM Consultas WHERE ID_Especialidad = ?"
        result = self._execute_query(query, (especialidad_id,), fetch_one=True)
        return result['count'] if result else 0