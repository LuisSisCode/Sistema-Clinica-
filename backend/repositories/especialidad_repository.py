"""
EspecialidadRepository - Gestión de Especialidades Médicas
Maneja la tabla Especialidad y las asignaciones a trabajadores médicos
"""

from typing import List, Dict, Any, Optional
from ..core.base_repository import BaseRepository
from ..core.excepciones import (
    ValidationError, ExceptionHandler, validate_required
)
from ..core.cache_system import cached_query
from ..core.utils import (
    validate_required_string, validate_positive_number, safe_float
)

class EspecialidadRepository(BaseRepository):
    """Repository para gestión de Especialidades y sus asignaciones"""
    
    def __init__(self):
        super().__init__('Especialidad', 'especialidades')
        print("🏥 EspecialidadRepository inicializado")
    
    # ===============================
    # IMPLEMENTACIÓN ABSTRACTA
    # ===============================
    
    def get_active(self) -> List[Dict[str, Any]]:
        """Obtiene todas las especialidades activas"""
        return self.get_all_especialidades()
    
    # ===============================
    # CRUD ESPECÍFICO
    # ===============================
    
    def create_especialidad(self, nombre: str, detalles: str = None,
                          precio_normal: float = 0, precio_emergencia: float = 0) -> int:
        """
        Crea nueva especialidad con validaciones
        
        Args:
            nombre: Nombre de la especialidad
            detalles: Descripción de la especialidad
            precio_normal: Precio para consulta normal
            precio_emergencia: Precio para consulta de emergencia
            
        Returns:
            ID de la especialidad creada
        """
        # Validaciones
        nombre = validate_required_string(nombre, "nombre", 3)
        precio_normal = validate_positive_number(precio_normal, "precio_normal")
        precio_emergencia = validate_positive_number(precio_emergencia, "precio_emergencia")
        
        # Validar que precio emergencia >= precio normal
        if precio_emergencia < precio_normal:
            raise ValidationError("precio_emergencia", precio_emergencia,
                                "Precio de emergencia debe ser mayor o igual al normal")
        
        # Verificar nombre único
        if self.especialidad_name_exists(nombre):
            raise ValidationError("nombre", nombre, "Especialidad ya existe")
        
        # Crear especialidad (sin Id_Doctor, ya que ahora usamos tabla intermedia)
        especialidad_data = {
            'Nombre': nombre.strip(),
            'Detalles': detalles.strip() if detalles else None,
            'Precio_Normal': precio_normal,
            'Precio_Emergencia': precio_emergencia,
            'Id_Doctor': None  # Ya no se usa, pero el campo existe
        }
        
        especialidad_id = self.insert(especialidad_data)
        print(f"🏥 Especialidad creada: {nombre} - ID: {especialidad_id}")
        
        return especialidad_id
    
    def update_especialidad(self, especialidad_id: int, nombre: str = None,
                          detalles: str = None, precio_normal: float = None,
                          precio_emergencia: float = None) -> bool:
        """Actualiza especialidad existente"""
        # Verificar existencia
        existing = self.get_by_id(especialidad_id)
        if not existing:
            raise ValidationError("especialidad_id", especialidad_id, 
                                "Especialidad no encontrada")
        
        update_data = {}
        
        if nombre is not None:
            nombre = validate_required_string(nombre, "nombre", 3)
            # Verificar nombre único (excepto la misma especialidad)
            if nombre != existing['Nombre'] and self.especialidad_name_exists(nombre):
                raise ValidationError("nombre", nombre, "Especialidad ya existe")
            update_data['Nombre'] = nombre.strip()
        
        if detalles is not None:
            update_data['Detalles'] = detalles.strip() if detalles.strip() else None
        
        if precio_normal is not None:
            precio_normal = validate_positive_number(precio_normal, "precio_normal")
            update_data['Precio_Normal'] = precio_normal
        
        if precio_emergencia is not None:
            precio_emergencia = validate_positive_number(precio_emergencia, "precio_emergencia")
            update_data['Precio_Emergencia'] = precio_emergencia
        
        # Validar precios si ambos están presentes
        current_normal = update_data.get('Precio_Normal', existing['Precio_Normal'])
        current_emergencia = update_data.get('Precio_Emergencia', existing['Precio_Emergencia'])
        
        if current_emergencia < current_normal:
            raise ValidationError("precios", current_emergencia,
                                "Precio de emergencia debe ser mayor o igual al normal")
        
        if not update_data:
            return True
        
        success = self.update(especialidad_id, update_data)
        if success:
            print(f"🏥 Especialidad actualizada: ID {especialidad_id}")
            self.invalidate_especialidad_caches()
        
        return success
    
    def delete_especialidad(self, especialidad_id: int) -> bool:
        """
        Elimina especialidad si no tiene consultas asociadas
        También elimina las asignaciones en Trabajador_Especialidad
        """
        # Verificar que no tenga consultas asociadas
        consultas_query = """
        SELECT COUNT(*) as count FROM Consultas WHERE Id_Especialidad = ?
        """
        result = self._execute_query(consultas_query, (especialidad_id,), fetch_one=True)
        
        if result and result['count'] > 0:
            raise ValidationError("especialidad_id", especialidad_id,
                                f"No se puede eliminar. Tiene {result['count']} consultas asociadas")
        
        # Eliminar asignaciones primero (cascade manual)
        delete_asignaciones_query = """
        DELETE FROM Trabajador_Especialidad WHERE Id_Especialidad = ?
        """
        self._execute_query(delete_asignaciones_query, (especialidad_id,), 
                          fetch_all=False, use_cache=False)
        
        # Eliminar especialidad
        success = self.delete(especialidad_id)
        if success:
            print(f"🗑️ Especialidad eliminada: ID {especialidad_id}")
            self.invalidate_especialidad_caches()
        
        return success
    
    # ===============================
    # CONSULTAS PRINCIPALES
    # ===============================
    
    @cached_query('especialidades_all', ttl=600)
    def get_all_especialidades(self) -> List[Dict[str, Any]]:
        """Obtiene todas las especialidades con información de médicos asignados"""
        query = """
        SELECT 
            e.id,
            e.Nombre,
            e.Detalles,
            e.Precio_Normal,
            e.Precio_Emergencia,
            COUNT(DISTINCT te.Id_Trabajador) as medicos_asignados,
            COUNT(DISTINCT c.id) as total_consultas,
            STRING_AGG(
                CONCAT(t.Nombre, ' ', t.Apellido_Paterno), 
                ', '
            ) as medicos_nombres
        FROM Especialidad e
        LEFT JOIN Trabajador_Especialidad te ON e.id = te.Id_Especialidad
        LEFT JOIN Trabajadores t ON te.Id_Trabajador = t.id
        LEFT JOIN Consultas c ON e.id = c.Id_Especialidad
        GROUP BY e.id, e.Nombre, e.Detalles, e.Precio_Normal, e.Precio_Emergencia
        ORDER BY e.Nombre
        """
        return self._execute_query(query)
    
    def get_especialidad_completa(self, especialidad_id: int) -> Optional[Dict[str, Any]]:
        """Obtiene especialidad con todos los médicos asignados"""
        especialidad = self.get_by_id(especialidad_id)
        if not especialidad:
            return None
        
        # Obtener médicos asignados
        medicos_query = """
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
        
        medicos = self._execute_query(medicos_query, (especialidad_id,))
        especialidad['medicos_asignados'] = medicos
        especialidad['total_medicos'] = len(medicos)
        
        # Estadísticas de consultas
        stats_query = """
        SELECT 
            COUNT(*) as total_consultas,
            COUNT(DISTINCT Id_Paciente) as pacientes_unicos,
            MAX(Fecha) as ultima_consulta,
            MIN(Fecha) as primera_consulta
        FROM Consultas
        WHERE Id_Especialidad = ?
        """
        
        stats = self._execute_query(stats_query, (especialidad_id,), fetch_one=True)
        if stats:
            especialidad.update(stats)
        
        return especialidad
    
    @cached_query('especialidades_disponibles', ttl=300)
    def get_especialidades_disponibles(self) -> List[Dict[str, Any]]:
        """
        Obtiene especialidades disponibles (con al menos un médico asignado)
        Usado en ComboBox de Consultas
        """
        query = """
        SELECT DISTINCT
            e.id,
            e.Nombre,
            e.Precio_Normal,
            e.Precio_Emergencia,
            COUNT(DISTINCT te.Id_Trabajador) as medicos_disponibles
        FROM Especialidad e
        INNER JOIN Trabajador_Especialidad te ON e.id = te.Id_Especialidad
        GROUP BY e.id, e.Nombre, e.Precio_Normal, e.Precio_Emergencia
        HAVING COUNT(DISTINCT te.Id_Trabajador) > 0
        ORDER BY e.Nombre
        """
        return self._execute_query(query)
    
    def get_especialidades_sin_asignar(self) -> List[Dict[str, Any]]:
        """Obtiene especialidades sin médicos asignados"""
        query = """
        SELECT e.*
        FROM Especialidad e
        WHERE NOT EXISTS (
            SELECT 1 FROM Trabajador_Especialidad te 
            WHERE te.Id_Especialidad = e.id
        )
        ORDER BY e.Nombre
        """
        return self._execute_query(query)
    
    # ===============================
    # BÚSQUEDAS Y FILTROS
    # ===============================
    
    def search_especialidades(self, search_term: str, limit: int = 50) -> List[Dict[str, Any]]:
        """Búsqueda por nombre o detalles"""
        if not search_term or len(search_term.strip()) < 2:
            return []
        
        search_term = f"%{search_term.strip()}%"
        
        query = """
        SELECT TOP (?)
            e.*,
            COUNT(DISTINCT te.Id_Trabajador) as medicos_asignados
        FROM Especialidad e
        LEFT JOIN Trabajador_Especialidad te ON e.id = te.Id_Especialidad
        WHERE e.Nombre LIKE ? OR e.Detalles LIKE ?
        GROUP BY e.id, e.Nombre, e.Detalles, e.Precio_Normal, e.Precio_Emergencia, e.Id_Doctor
        ORDER BY e.Nombre
        """
        
        return self._execute_query(query, (limit, search_term, search_term))
    
    def filter_by_price_range(self, precio_min: float, precio_max: float,
                             tipo: str = 'normal') -> List[Dict[str, Any]]:
        """Filtra especialidades por rango de precio"""
        campo_precio = 'Precio_Normal' if tipo == 'normal' else 'Precio_Emergencia'
        
        query = f"""
        SELECT *
        FROM Especialidad
        WHERE {campo_precio} BETWEEN ? AND ?
        ORDER BY {campo_precio}
        """
        
        return self._execute_query(query, (precio_min, precio_max))
    
    # ===============================
    # VALIDACIONES Y UTILIDADES
    # ===============================
    
    def especialidad_exists(self, especialidad_id: int) -> bool:
        """Verifica si existe una especialidad"""
        return self.exists('id', especialidad_id)
    
    def especialidad_name_exists(self, nombre: str, exclude_id: int = None) -> bool:
        """Verifica si existe un nombre de especialidad"""
        query = "SELECT COUNT(*) as count FROM Especialidad WHERE Nombre = ?"
        params = [nombre.strip()]
        
        if exclude_id:
            query += " AND id != ?"
            params.append(exclude_id)
        
        result = self._execute_query(query, tuple(params), fetch_one=True)
        return result['count'] > 0 if result else False
    
    def get_precio_especialidad(self, especialidad_id: int, 
                               tipo_consulta: str = 'Normal') -> float:
        """Obtiene el precio de una especialidad según el tipo de consulta"""
        especialidad = self.get_by_id(especialidad_id)
        if not especialidad:
            return 0.0
        
        if tipo_consulta == 'Emergencia':
            return safe_float(especialidad.get('Precio_Emergencia', 0))
        else:
            return safe_float(especialidad.get('Precio_Normal', 0))
    
    def get_nombres_especialidades(self) -> List[str]:
        """Obtiene lista de nombres de especialidades"""
        query = "SELECT Nombre FROM Especialidad ORDER BY Nombre"
        result = self._execute_query(query)
        return [row['Nombre'] for row in result]
    
    # ===============================
    # ESTADÍSTICAS
    # ===============================
    
    @cached_query('stats_especialidades', ttl=600)
    def get_especialidad_statistics(self) -> Dict[str, Any]:
        """Estadísticas completas de especialidades"""
        # Estadísticas generales
        general_query = """
        SELECT 
            COUNT(*) as total_especialidades,
            AVG(CAST(Precio_Normal AS FLOAT)) as precio_promedio_normal,
            AVG(CAST(Precio_Emergencia AS FLOAT)) as precio_promedio_emergencia,
            MIN(Precio_Normal) as precio_min_normal,
            MAX(Precio_Normal) as precio_max_normal,
            MIN(Precio_Emergencia) as precio_min_emergencia,
            MAX(Precio_Emergencia) as precio_max_emergencia
        FROM Especialidad
        """
        
        # Especialidades más consultadas
        top_query = """
        SELECT TOP 10
            e.Nombre,
            COUNT(c.id) as total_consultas,
            COUNT(DISTINCT c.Id_Paciente) as pacientes_unicos,
            COUNT(DISTINCT te.Id_Trabajador) as medicos_asignados
        FROM Especialidad e
        LEFT JOIN Consultas c ON e.id = c.Id_Especialidad
        LEFT JOIN Trabajador_Especialidad te ON e.id = te.Id_Especialidad
        GROUP BY e.id, e.Nombre
        ORDER BY total_consultas DESC
        """
        
        # Distribución de médicos
        distribucion_query = """
        SELECT 
            COUNT(DISTINCT te.Id_Trabajador) as total_medicos,
            COUNT(DISTINCT te.Id_Especialidad) as especialidades_cubiertas,
            AVG(CAST(medicos_por_esp AS FLOAT)) as promedio_medicos_por_especialidad
        FROM (
            SELECT Id_Especialidad, COUNT(DISTINCT Id_Trabajador) as medicos_por_esp
            FROM Trabajador_Especialidad
            GROUP BY Id_Especialidad
        ) sub
        CROSS JOIN Trabajador_Especialidad te
        """
        
        general_stats = self._execute_query(general_query, fetch_one=True)
        top_especialidades = self._execute_query(top_query)
        distribucion = self._execute_query(distribucion_query, fetch_one=True)
        
        return {
            'general': general_stats,
            'top_especialidades': top_especialidades,
            'distribucion_medicos': distribucion
        }
    
    def get_especialidades_mas_consultadas(self, limit: int = 10) -> List[Dict[str, Any]]:
        """Especialidades más consultadas"""
        query = """
        SELECT TOP (?)
            e.id, e.Nombre, e.Precio_Normal, e.Precio_Emergencia,
            COUNT(c.id) as total_consultas,
            COUNT(DISTINCT c.Id_Paciente) as pacientes_unicos,
            MAX(c.Fecha) as ultima_consulta
        FROM Especialidad e
        INNER JOIN Consultas c ON e.id = c.Id_Especialidad
        GROUP BY e.id, e.Nombre, e.Precio_Normal, e.Precio_Emergencia
        ORDER BY total_consultas DESC
        """
        return self._execute_query(query, (limit,))
    
    # ===============================
    # CACHÉ
    # ===============================
    
    def invalidate_especialidad_caches(self):
        """Invalida cachés relacionados con especialidades"""
        cache_types = [
            'especialidades', 'especialidades_all', 
            'especialidades_disponibles', 'stats_especialidades'
        ]
        from ..core.cache_system import invalidate_after_update
        invalidate_after_update(cache_types)
    
    def _invalidate_cache_after_modification(self):
        """Override para invalidación específica"""
        super()._invalidate_cache_after_modification()
        self.invalidate_especialidad_caches()


# ===============================
# UTILIDADES Y EXPORTACIÓN
# ===============================

__all__ = ['EspecialidadRepository']