from typing import List, Dict, Any, Optional

from ...core.base_repository import BaseRepository
from ...core.excepciones import (
    ValidationError, ExceptionHandler, validate_required
)
from ...core.cache_system import cached_query
from ...core.utils import (
    normalize_name, validate_required_string, safe_int, safe_float
)

class ConfiLaboratorioRepository(BaseRepository):
    """Repository para gestión de Configuración de Tipos de Análisis"""
    
    def __init__(self):
        super().__init__('Tipos_Analisis', 'configuracion_laboratorio')
    
    # ===============================
    # IMPLEMENTACIÓN ABSTRACTA
    # ===============================
    
    def get_active(self) -> List[Dict[str, Any]]:
        """Obtiene todos los tipos de análisis activos"""
        return self.get_all_tipos_analisis()
    
    # ===============================
    # CRUD ESPECÍFICO - TIPOS DE ANÁLISIS
    # ===============================
    
    def create_tipo_analisis(self, nombre: str, descripcion: str = None, 
                           precio_normal: float = 0.0, precio_emergencia: float = 0.0) -> int:
        """
        Crea nuevo tipo de análisis con validaciones
        
        Args:
            nombre: Nombre del tipo de análisis
            descripcion: Descripción del tipo de análisis
            precio_normal: Precio normal del análisis
            precio_emergencia: Precio de emergencia del análisis
            
        Returns:
            ID del tipo de análisis creado
        """
        # Validaciones
        nombre = validate_required_string(nombre, "nombre", 2)
        validate_required(nombre, "nombre")
        
        # Validar precios
        precio_normal = safe_float(precio_normal)
        precio_emergencia = safe_float(precio_emergencia)
        
        if precio_normal < 0:
            raise ValidationError("precio_normal", precio_normal, "El precio normal no puede ser negativo")
        
        if precio_emergencia < 0:
            raise ValidationError("precio_emergencia", precio_emergencia, "El precio de emergencia no puede ser negativo")
        
        # Verificar que el nombre no exista
        if self.tipo_analisis_name_exists(nombre):
            raise ValidationError("nombre", nombre, "El tipo de análisis ya existe")
        
        # Crear tipo de análisis
        tipo_data = {
            'Nombre': normalize_name(nombre),
            'Precio_Normal': precio_normal,
            'Precio_Emergencia': precio_emergencia
        }
        
        # Agregar descripción si se proporciona
        if descripcion and descripcion.strip():
            tipo_data['Descripcion'] = descripcion.strip()
        else:
            tipo_data['Descripcion'] = None
        
        tipo_id = self.insert(tipo_data)
        print(f"🧪 Tipo de análisis creado: {nombre} - ID: {tipo_id}")
        
        return tipo_id
    
    def update_tipo_analisis(self, tipo_id: int, nombre: str = None, 
                           descripcion: str = None, precio_normal: float = None,
                           precio_emergencia: float = None) -> bool:
        """Actualiza tipo de análisis existente"""
        # Verificar existencia
        if not self.get_by_id(tipo_id):
            raise ValidationError("tipo_id", tipo_id, "Tipo de análisis no encontrado")
        
        update_data = {}
        
        if nombre is not None:
            nombre = validate_required_string(nombre, "nombre", 2)
            # Verificar nombre único (excepto el mismo registro)
            if self.tipo_analisis_name_exists(nombre, exclude_id=tipo_id):
                raise ValidationError("nombre", nombre, "El tipo de análisis ya existe")
            update_data['Nombre'] = normalize_name(nombre)
        
        if descripcion is not None:
            update_data['Descripcion'] = descripcion.strip() if descripcion.strip() else None
        
        if precio_normal is not None:
            precio_normal = safe_float(precio_normal)
            if precio_normal < 0:
                raise ValidationError("precio_normal", precio_normal, "El precio normal no puede ser negativo")
            update_data['Precio_Normal'] = precio_normal
        
        if precio_emergencia is not None:
            precio_emergencia = safe_float(precio_emergencia)
            if precio_emergencia < 0:
                raise ValidationError("precio_emergencia", precio_emergencia, "El precio de emergencia no puede ser negativo")
            update_data['Precio_Emergencia'] = precio_emergencia
        
        if not update_data:
            return True
        
        success = self.update(tipo_id, update_data)
        if success:
            print(f"🧪 Tipo de análisis actualizado: ID {tipo_id}")
        
        return success
    
    def delete_tipo_analisis(self, tipo_id: int) -> bool:
        """Elimina tipo de análisis"""
        success = self.delete(tipo_id)
        if success:
            print(f"🗑️ Tipo de análisis eliminado: ID {tipo_id}")
        
        return success
    
    # ===============================
    # CONSULTAS PRINCIPALES
    # ===============================
    
    @cached_query('tipos_analisis_all', ttl=600)
    def get_all_tipos_analisis(self) -> List[Dict[str, Any]]:
        """Obtiene todos los tipos de análisis"""
        query = """
        SELECT id, Nombre, Descripcion, Precio_Normal, Precio_Emergencia
        FROM Tipos_Analisis
        ORDER BY Nombre
        """
        return self._execute_query(query)
    
    def get_tipo_analisis_by_id(self, tipo_id: int) -> Optional[Dict[str, Any]]:
        """Obtiene tipo de análisis específico por ID"""
        query = """
        SELECT id, Nombre, Descripcion, Precio_Normal, Precio_Emergencia
        FROM Tipos_Analisis
        WHERE id = ?
        """
        return self._execute_query(query, (tipo_id,), fetch_one=True)
    
    def get_tipo_analisis_by_name(self, nombre: str) -> Optional[Dict[str, Any]]:
        """Obtiene tipo de análisis por nombre"""
        query = "SELECT * FROM Tipos_Analisis WHERE Nombre = ?"
        return self._execute_query(query, (nombre.strip(),), fetch_one=True)
    
    # ===============================
    # BÚSQUEDAS Y FILTROS
    # ===============================
    
    def search_tipos_analisis(self, search_term: str, limit: int = 50) -> List[Dict[str, Any]]:
        """Búsqueda por nombre o descripción"""
        if not search_term:
            return []
        
        search_term = f"%{search_term.strip()}%"
        
        query = """
        SELECT id, Nombre, Descripcion, Precio_Normal, Precio_Emergencia
        FROM Tipos_Analisis
        WHERE Nombre LIKE ? OR Descripcion LIKE ?
        ORDER BY Nombre
        OFFSET 0 ROWS FETCH NEXT ? ROWS ONLY
        """
        
        return self._execute_query(query, (search_term, search_term, limit))
    
    def get_tipos_analisis_by_price_range(self, precio_min: float = 0, 
                                        precio_max: float = None) -> List[Dict[str, Any]]:
        """Obtiene tipos de análisis por rango de precios"""
        query = """
        SELECT id, Nombre, Descripcion, Precio_Normal, Precio_Emergencia
        FROM Tipos_Analisis
        WHERE Precio_Normal >= ?
        """
        params = [precio_min]
        
        if precio_max is not None:
            query += " AND Precio_Normal <= ?"
            params.append(precio_max)
        
        query += " ORDER BY Precio_Normal"
        
        return self._execute_query(query, tuple(params))
    
    # ===============================
    # VALIDACIONES Y UTILIDADES
    # ===============================
    
    def tipo_analisis_exists(self, tipo_id: int) -> bool:
        """Verifica si existe un tipo de análisis"""
        query = "SELECT COUNT(*) as count FROM Tipos_Analisis WHERE id = ?"
        result = self._execute_query(query, (tipo_id,), fetch_one=True)
        return result['count'] > 0 if result else False
    
    def tipo_analisis_name_exists(self, nombre: str, exclude_id: int = None) -> bool:
        """Verifica si existe un nombre de tipo de análisis (excluyendo un ID específico)"""
        query = "SELECT COUNT(*) as count FROM Tipos_Analisis WHERE Nombre = ?"
        params = [nombre.strip()]
        
        if exclude_id:
            query += " AND id != ?"
            params.append(exclude_id)
        
        result = self._execute_query(query, tuple(params), fetch_one=True)
        return result['count'] > 0 if result else False
    
    def validate_tipo_analisis_exists(self, tipo_id: int) -> bool:
        """Valida que el tipo de análisis existe"""
        return self.exists('id', tipo_id)
    
    def get_available_tipos_analisis_names(self) -> List[str]:
        """Obtiene lista de nombres de tipos de análisis disponibles"""
        query = "SELECT Nombre FROM Tipos_Analisis ORDER BY Nombre"
        result = self._execute_query(query)
        return [row['Nombre'] for row in result]
    
    # ===============================
    # ESTADÍSTICAS
    # ===============================
    
    @cached_query('stats_tipos_analisis', ttl=600)
    def get_tipos_analisis_statistics(self) -> Dict[str, Any]:
        """Estadísticas básicas de tipos de análisis"""
        general_query = """
        SELECT 
            COUNT(*) as total_tipos_analisis,
            COUNT(CASE WHEN Descripcion IS NOT NULL AND Descripcion != '' THEN 1 END) as con_descripcion,
            COUNT(CASE WHEN Descripcion IS NULL OR Descripcion = '' THEN 1 END) as sin_descripcion,
            AVG(Precio_Normal) as precio_normal_promedio,
            AVG(Precio_Emergencia) as precio_emergencia_promedio,
            MIN(Precio_Normal) as precio_normal_minimo,
            MAX(Precio_Normal) as precio_normal_maximo,
            MIN(Precio_Emergencia) as precio_emergencia_minimo,
            MAX(Precio_Emergencia) as precio_emergencia_maximo
        FROM Tipos_Analisis
        """
        
        general_stats = self._execute_query(general_query, fetch_one=True)
        
        # Análisis más caros
        expensive_query = """
        SELECT TOP 5 Nombre, Precio_Normal, Precio_Emergencia
        FROM Tipos_Analisis
        ORDER BY Precio_Normal DESC
        """
        expensive_stats = self._execute_query(expensive_query)
        
        # Análisis más baratos
        cheap_query = """
        SELECT TOP 5 Nombre, Precio_Normal, Precio_Emergencia
        FROM Tipos_Analisis
        WHERE Precio_Normal > 0
        ORDER BY Precio_Normal ASC
        """
        cheap_stats = self._execute_query(cheap_query)
        
        return {
            'general': general_stats,
            'mas_caros': expensive_stats,
            'mas_baratos': cheap_stats
        }
    
    # ===============================
    # REPORTES
    # ===============================
    
    def get_tipos_analisis_for_report(self) -> List[Dict[str, Any]]:
        """Obtiene tipos de análisis formateados para reportes"""
        query = """
        SELECT id, Nombre, Descripcion, Precio_Normal, Precio_Emergencia
        FROM Tipos_Analisis
        ORDER BY Nombre
        """
        
        tipos_analisis = self._execute_query(query)
        
        # Agregar información adicional
        for tipo in tipos_analisis:
            if not tipo.get('Descripcion'):
                tipo['Descripcion'] = 'Sin descripción'
            
            # Calcular diferencia de precios
            precio_normal = tipo.get('Precio_Normal', 0)
            precio_emergencia = tipo.get('Precio_Emergencia', 0)
            
            if precio_normal > 0:
                diferencia_porcentual = ((precio_emergencia - precio_normal) / precio_normal) * 100
                tipo['diferencia_porcentual'] = round(diferencia_porcentual, 2)
            else:
                tipo['diferencia_porcentual'] = 0
        
        return tipos_analisis
    
    def get_tipos_analisis_summary(self) -> Dict[str, Any]:
        """Resumen de tipos de análisis"""
        query = """
        SELECT Nombre, Descripcion, Precio_Normal, Precio_Emergencia
        FROM Tipos_Analisis
        ORDER BY Nombre
        """
        
        tipos_data = self._execute_query(query)
        
        # Calcular totales
        total_tipos = len(tipos_data)
        tipos_con_descripcion = len([item for item in tipos_data if item.get('Descripcion')])
        tipos_sin_descripcion = total_tipos - tipos_con_descripcion
        
        # Calcular promedios de precios
        if tipos_data:
            precio_normal_promedio = sum(item.get('Precio_Normal', 0) for item in tipos_data) / total_tipos
            precio_emergencia_promedio = sum(item.get('Precio_Emergencia', 0) for item in tipos_data) / total_tipos
        else:
            precio_normal_promedio = 0
            precio_emergencia_promedio = 0
        
        return {
            'tipos_analisis': tipos_data,
            'resumen': {
                'total_tipos': total_tipos,
                'tipos_con_descripcion': tipos_con_descripcion,
                'tipos_sin_descripcion': tipos_sin_descripcion,
                'precio_normal_promedio': round(precio_normal_promedio, 2),
                'precio_emergencia_promedio': round(precio_emergencia_promedio, 2)
            }
        }
    
    # ===============================
    # CACHÉ
    # ===============================
    
    def invalidate_tipos_analisis_caches(self):
        """Invalida cachés relacionados con tipos de análisis"""
        cache_types = ['tipos_analisis_all', 'stats_tipos_analisis', 'configuracion_laboratorio']
        from ...core.cache_system import invalidate_after_update
        invalidate_after_update(cache_types)
    
    def _invalidate_cache_after_modification(self):
        """Override para invalidación específica"""
        super()._invalidate_cache_after_modification()
        self.invalidate_tipos_analisis_caches()