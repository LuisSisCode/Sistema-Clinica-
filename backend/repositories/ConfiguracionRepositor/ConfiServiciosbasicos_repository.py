from typing import List, Dict, Any, Optional

from ...core.base_repository import BaseRepository
from ...core.excepciones import (
    ValidationError, ExceptionHandler, validate_required
)
from ...core.cache_system import cached_query
from ...core.utils import (
    normalize_name, validate_required_string, safe_int
)

class ConfiguracionRepository(BaseRepository):
    """Repository para gestión de Configuración de Tipos de Gastos"""
    
    def __init__(self):
        super().__init__('Tipo_Gastos', 'configuracion')
    
    # ===============================
    # IMPLEMENTACIÓN ABSTRACTA
    # ===============================
    
    def get_active(self) -> List[Dict[str, Any]]:
        """Obtiene todos los tipos de gastos activos"""
        return self.get_all_tipos_gastos()
    
    # ===============================
    # CRUD ESPECÍFICO - TIPOS DE GASTOS
    # ===============================
    
    def create_tipo_gasto(self, nombre: str, descripcion: str = None) -> int:
        """
        Crea nuevo tipo de gasto con validaciones
        
        Args:
            nombre: Nombre del tipo de gasto
            descripcion: Descripción del tipo de gasto
            
        Returns:
            ID del tipo de gasto creado
        """
        # Validaciones
        nombre = validate_required_string(nombre, "nombre", 2)
        validate_required(nombre, "nombre")
        
        # Verificar que el nombre no exista
        if self.tipo_gasto_name_exists(nombre):
            raise ValidationError("nombre", nombre, "El tipo de gasto ya existe")
        
        # Crear tipo de gasto
        tipo_data = {
            'Nombre': normalize_name(nombre),
        }
        
        # Agregar descripción si se proporciona
        if descripcion and descripcion.strip():
            tipo_data['descripcion'] = descripcion.strip()
        else:
            tipo_data['descripcion'] = None
        
        tipo_id = self.insert(tipo_data)
        print(f"💰 Tipo de gasto creado: {nombre} - ID: {tipo_id}")
        
        return tipo_id
    
    def update_tipo_gasto(self, tipo_id: int, nombre: str = None, 
                         descripcion: str = None) -> bool:
        """Actualiza tipo de gasto existente"""
        # Verificar existencia
        if not self.get_by_id(tipo_id):
            raise ValidationError("tipo_id", tipo_id, "Tipo de gasto no encontrado")
        
        update_data = {}
        
        if nombre is not None:
            nombre = validate_required_string(nombre, "nombre", 2)
            # Verificar nombre único (excepto el mismo registro)
            if self.tipo_gasto_name_exists(nombre, exclude_id=tipo_id):
                raise ValidationError("nombre", nombre, "El tipo de gasto ya existe")
            update_data['Nombre'] = normalize_name(nombre)
        
        if descripcion is not None:
            update_data['descripcion'] = descripcion.strip() if descripcion.strip() else None
        
        if not update_data:
            return True
        
        success = self.update(tipo_id, update_data)
        if success:
            print(f"💰 Tipo de gasto actualizado: ID {tipo_id}")
        
        return success
    
    def delete_tipo_gasto(self, tipo_id: int) -> bool:
        """Elimina tipo de gasto si no tiene gastos asociados"""
        # Verificar que no tenga gastos asociados
        gastos_count = self.count_gastos_asociados(tipo_id)
        if gastos_count > 0:
            raise ValidationError("tipo_id", tipo_id, 
                                f"No se puede eliminar. Tiene {gastos_count} gastos asociados")
        
        success = self.delete(tipo_id)
        if success:
            print(f"🗑️ Tipo de gasto eliminado: ID {tipo_id}")
        
        return success
    
    # ===============================
    # CONSULTAS PRINCIPALES
    # ===============================
    
    @cached_query('tipos_gastos_all', ttl=600)
    def get_all_tipos_gastos(self) -> List[Dict[str, Any]]:
        """Obtiene todos los tipos de gastos"""
        query = """
        SELECT id, Nombre, descripcion
        FROM Tipo_Gastos
        ORDER BY Nombre
        """
        return self._execute_query(query)
    
    def get_tipo_gasto_by_id(self, tipo_id: int) -> Optional[Dict[str, Any]]:
        """Obtiene tipo de gasto específico por ID"""
        query = """
        SELECT id, Nombre, descripcion
        FROM Tipo_Gastos
        WHERE id = ?
        """
        return self._execute_query(query, (tipo_id,), fetch_one=True)
    
    def get_tipo_gasto_by_name(self, nombre: str) -> Optional[Dict[str, Any]]:
        """Obtiene tipo de gasto por nombre"""
        query = "SELECT * FROM Tipo_Gastos WHERE Nombre = ?"
        return self._execute_query(query, (nombre.strip(),), fetch_one=True)
    
    # ===============================
    # BÚSQUEDAS Y FILTROS
    # ===============================
    
    def search_tipos_gastos(self, search_term: str, limit: int = 50) -> List[Dict[str, Any]]:
        """Búsqueda por nombre o descripción"""
        if not search_term:
            return []
        
        search_term = f"%{search_term.strip()}%"
        
        query = """
        SELECT id, Nombre, descripcion
        FROM Tipo_Gastos
        WHERE Nombre LIKE ? OR descripcion LIKE ?
        ORDER BY Nombre
        OFFSET 0 ROWS FETCH NEXT ? ROWS ONLY
        """
        
        return self._execute_query(query, (search_term, search_term, limit))
    
    # ===============================
    # VALIDACIONES Y UTILIDADES
    # ===============================
    
    def tipo_gasto_exists(self, tipo_id: int) -> bool:
        """Verifica si existe un tipo de gasto"""
        query = "SELECT COUNT(*) as count FROM Tipo_Gastos WHERE id = ?"
        result = self._execute_query(query, (tipo_id,), fetch_one=True)
        return result['count'] > 0 if result else False
    
    def tipo_gasto_name_exists(self, nombre: str, exclude_id: int = None) -> bool:
        """Verifica si existe un nombre de tipo de gasto (excluyendo un ID específico)"""
        query = "SELECT COUNT(*) as count FROM Tipo_Gastos WHERE Nombre = ?"
        params = [nombre.strip()]
        
        if exclude_id:
            query += " AND id != ?"
            params.append(exclude_id)
        
        result = self._execute_query(query, tuple(params), fetch_one=True)
        return result['count'] > 0 if result else False
    
    def validate_tipo_gasto_exists(self, tipo_id: int) -> bool:
        """Valida que el tipo de gasto existe"""
        return self.exists('id', tipo_id)
    
    def get_available_tipo_gastos_names(self) -> List[str]:
        """Obtiene lista de nombres de tipos de gastos disponibles"""
        query = "SELECT Nombre FROM Tipo_Gastos ORDER BY Nombre"
        result = self._execute_query(query)
        return [row['Nombre'] for row in result]
    
    # ===============================
    # ESTADÍSTICAS SIMPLIFICADAS
    # ===============================
    
    @cached_query('stats_tipos_gastos', ttl=600)
    def get_tipos_gastos_statistics(self) -> Dict[str, Any]:
        """Estadísticas básicas de tipos de gastos"""
        query = """
        SELECT 
            COUNT(*) as total_tipos_gastos,
            COUNT(CASE WHEN descripcion IS NOT NULL AND descripcion != '' THEN 1 END) as con_descripcion,
            COUNT(CASE WHEN descripcion IS NULL OR descripcion = '' THEN 1 END) as sin_descripcion
        FROM Tipo_Gastos
        """
        
        general_stats = self._execute_query(query, fetch_one=True)
        
        return {
            'general': general_stats
        }
    
    # ===============================
    # REPORTES SIMPLIFICADOS
    # ===============================
    
    def get_tipos_gastos_for_report(self) -> List[Dict[str, Any]]:
        """Obtiene tipos de gastos formateados para reportes"""
        query = """
        SELECT id, Nombre, descripcion
        FROM Tipo_Gastos
        ORDER BY Nombre
        """
        
        tipos_gastos = self._execute_query(query)
        
        # Agregar información adicional
        for tipo in tipos_gastos:
            if not tipo.get('descripcion'):
                tipo['descripcion'] = 'Sin descripción'
        
        return tipos_gastos
    
    def get_tipo_gastos_summary(self) -> Dict[str, Any]:
        """Resumen simplificado de tipos de gastos"""
        query = """
        SELECT Nombre, descripcion
        FROM Tipo_Gastos
        ORDER BY Nombre
        """
        
        tipos_data = self._execute_query(query)
        
        # Calcular totales generales
        total_tipos = len(tipos_data)
        tipos_con_descripcion = len([item for item in tipos_data if item.get('descripcion')])
        tipos_sin_descripcion = total_tipos - tipos_con_descripcion
        
        return {
            'tipos_gastos': tipos_data,
            'resumen': {
                'total_tipos': total_tipos,
                'tipos_con_descripcion': tipos_con_descripcion,
                'tipos_sin_descripcion': tipos_sin_descripcion
            }
        }
    
    # ===============================
    # CACHÉ
    # ===============================
    
    def invalidate_tipos_gastos_caches(self):
        """Invalida cachés relacionados con tipos de gastos"""
        cache_types = ['tipos_gastos_all', 'stats_tipos_gastos', 'configuracion']
        from ...core.cache_system import invalidate_after_update
        invalidate_after_update(cache_types)
    
    def _invalidate_cache_after_modification(self):
        """Override para invalidación específica"""
        super()._invalidate_cache_after_modification()
        self.invalidate_tipos_gastos_caches()

    def count_gastos_asociados(self, tipo_id: int) -> int:
        """Cuenta gastos asociados a un tipo específico"""
        query = "SELECT COUNT(*) as count FROM Gastos WHERE ID_Tipo = ?"
        result = self._execute_query(query, (tipo_id,), fetch_one=True)
        return result['count'] if result else 0