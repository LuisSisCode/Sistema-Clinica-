from typing import List, Dict, Any, Optional

from ...core.base_repository import BaseRepository
from ...core.excepciones import (
    ValidationError, ExceptionHandler, validate_required
)
from ...core.cache_system import cached_query
from ...core.utils import (
    normalize_name, validate_required_string, safe_float
)

class ConfiEnfermeriaRepository(BaseRepository):
    """Repository para gestión de Configuración de Tipos de Procedimientos de Enfermería"""
    
    def __init__(self):
        super().__init__('Tipos_Procedimientos', 'confi_enfermeria')
    
    # ===============================
    # IMPLEMENTACIÓN ABSTRACTA
    # ===============================
    
    def get_active(self) -> List[Dict[str, Any]]:
        """Obtiene todos los tipos de procedimientos activos"""
        return self.get_all_tipos_procedimientos()
    
    # ===============================
    # CRUD ESPECÍFICO - TIPOS DE PROCEDIMIENTOS
    # ===============================
    
    def create_tipo_procedimiento(self, nombre: str, descripcion: str = None, 
                                 precio_normal: float = 0.0, precio_emergencia: float = 0.0) -> int:
        """
        Crea nuevo tipo de procedimiento con validaciones
        
        Args:
            nombre: Nombre del tipo de procedimiento
            descripcion: Descripción del tipo de procedimiento
            precio_normal: Precio en horario normal
            precio_emergencia: Precio en horario de emergencia
            
        Returns:
            ID del tipo de procedimiento creado
        """
        # Validaciones
        nombre = validate_required_string(nombre, "nombre", 2)
        validate_required(nombre, "nombre")
        
        # Verificar que el nombre no exista
        if self.tipo_procedimiento_name_exists(nombre):
            raise ValidationError("nombre", nombre, "El tipo de procedimiento ya existe")
        
        # Validar precios
        precio_normal = safe_float(precio_normal, 0.0)
        precio_emergencia = safe_float(precio_emergencia, 0.0)
        
        if precio_normal < 0:
            raise ValidationError("precio_normal", precio_normal, "El precio normal debe ser mayor o igual a 0")
        if precio_emergencia < 0:
            raise ValidationError("precio_emergencia", precio_emergencia, "El precio de emergencia debe ser mayor o igual a 0")
        
        # Crear tipo de procedimiento
        procedimiento_data = {
            'Nombre': normalize_name(nombre),
            'Precio_Normal': precio_normal,
            'Precio_Emergencia': precio_emergencia
        }
        
        # Agregar descripción si se proporciona
        if descripcion and descripcion.strip():
            procedimiento_data['Descripcion'] = descripcion.strip()
        else:
            procedimiento_data['Descripcion'] = None
        
        procedimiento_id = self.insert(procedimiento_data)
        print(f"🩹 Tipo de procedimiento creado: {nombre} - ID: {procedimiento_id}")
        
        return procedimiento_id
    
    def update_tipo_procedimiento(self, procedimiento_id: int, nombre: str = None, 
                                 descripcion: str = None, precio_normal: float = None,
                                 precio_emergencia: float = None) -> bool:
        """Actualiza tipo de procedimiento existente"""
        # Verificar existencia
        if not self.get_by_id(procedimiento_id):
            raise ValidationError("procedimiento_id", procedimiento_id, "Tipo de procedimiento no encontrado")
        
        update_data = {}
        
        if nombre is not None:
            nombre = validate_required_string(nombre, "nombre", 2)
            # Verificar nombre único (excepto el mismo registro)
            if self.tipo_procedimiento_name_exists(nombre, exclude_id=procedimiento_id):
                raise ValidationError("nombre", nombre, "El tipo de procedimiento ya existe")
            update_data['Nombre'] = normalize_name(nombre)
        
        if descripcion is not None:
            update_data['Descripcion'] = descripcion.strip() if descripcion.strip() else None
        
        if precio_normal is not None:
            precio_normal = safe_float(precio_normal, 0.0)
            if precio_normal < 0:
                raise ValidationError("precio_normal", precio_normal, "El precio normal debe ser mayor o igual a 0")
            update_data['Precio_Normal'] = precio_normal
        
        if precio_emergencia is not None:
            precio_emergencia = safe_float(precio_emergencia, 0.0)
            if precio_emergencia < 0:
                raise ValidationError("precio_emergencia", precio_emergencia, "El precio de emergencia debe ser mayor o igual a 0")
            update_data['Precio_Emergencia'] = precio_emergencia
        
        if not update_data:
            return True
        
        success = self.update(procedimiento_id, update_data)
        if success:
            print(f"🩹 Tipo de procedimiento actualizado: ID {procedimiento_id}")
        
        return success
    
    def delete_tipo_procedimiento(self, procedimiento_id: int) -> bool:
        """Elimina tipo de procedimiento si no tiene procedimientos asociados"""
        # Verificar que no tenga procedimientos asociados
        procedimientos_count = self.count_procedimientos_asociados(procedimiento_id)
        if procedimientos_count > 0:
            raise ValidationError("procedimiento_id", procedimiento_id, 
                                f"No se puede eliminar. Tiene {procedimientos_count} procedimientos asociados")
        
        success = self.delete(procedimiento_id)
        if success:
            print(f"🗑️ Tipo de procedimiento eliminado: ID {procedimiento_id}")
        
        return success
    
    # ===============================
    # CONSULTAS PRINCIPALES
    # ===============================
    
    @cached_query('tipos_procedimientos_all', ttl=600)
    def get_all_tipos_procedimientos(self) -> List[Dict[str, Any]]:
        """Obtiene todos los tipos de procedimientos"""
        query = """
        SELECT id, Nombre, Descripcion, Precio_Normal, Precio_Emergencia
        FROM Tipos_Procedimientos
        ORDER BY Nombre
        """
        return self._execute_query(query)
    
    def get_tipo_procedimiento_by_id(self, procedimiento_id: int) -> Optional[Dict[str, Any]]:
        """Obtiene tipo de procedimiento específico por ID"""
        query = """
        SELECT id, Nombre, Descripcion, Precio_Normal, Precio_Emergencia
        FROM Tipos_Procedimientos
        WHERE id = ?
        """
        return self._execute_query(query, (procedimiento_id,), fetch_one=True)
    
    def get_tipo_procedimiento_by_name(self, nombre: str) -> Optional[Dict[str, Any]]:
        """Obtiene tipo de procedimiento por nombre"""
        query = "SELECT * FROM Tipos_Procedimientos WHERE Nombre = ?"
        return self._execute_query(query, (nombre.strip(),), fetch_one=True)
    
    # ===============================
    # BÚSQUEDAS Y FILTROS
    # ===============================
    
    def search_tipos_procedimientos(self, search_term: str, limit: int = 50) -> List[Dict[str, Any]]:
        """Búsqueda por nombre o descripción"""
        if not search_term:
            return []
        
        search_term = f"%{search_term.strip()}%"
        
        query = """
        SELECT id, Nombre, Descripcion, Precio_Normal, Precio_Emergencia
        FROM Tipos_Procedimientos
        WHERE Nombre LIKE ? OR Descripcion LIKE ?
        ORDER BY Nombre
        OFFSET 0 ROWS FETCH NEXT ? ROWS ONLY
        """
        
        return self._execute_query(query, (search_term, search_term, limit))
    
    def get_tipos_procedimientos_por_rango_precios(self, precio_min: float = 0.0, 
                                                  precio_max: float = -1.0) -> List[Dict[str, Any]]:
        """Obtiene tipos de procedimientos filtrados por rango de precios"""
        params = [precio_min]
        query = """
        SELECT id, Nombre, Descripcion, Precio_Normal, Precio_Emergencia
        FROM Tipos_Procedimientos
        WHERE Precio_Normal >= ?
        """
        
        if precio_max > 0:
            query += " AND Precio_Normal <= ?"
            params.append(precio_max)
        
        query += " ORDER BY Precio_Normal"
        
        return self._execute_query(query, tuple(params))
    
    # ===============================
    # VALIDACIONES Y UTILIDADES
    # ===============================
    
    def tipo_procedimiento_exists(self, procedimiento_id: int) -> bool:
        """Verifica si existe un tipo de procedimiento"""
        query = "SELECT COUNT(*) as count FROM Tipos_Procedimientos WHERE id = ?"
        result = self._execute_query(query, (procedimiento_id,), fetch_one=True)
        return result['count'] > 0 if result else False
    
    def tipo_procedimiento_name_exists(self, nombre: str, exclude_id: int = None) -> bool:
        """Verifica si existe un nombre de tipo de procedimiento (excluyendo un ID específico)"""
        query = "SELECT COUNT(*) as count FROM Tipos_Procedimientos WHERE Nombre = ?"
        params = [nombre.strip()]
        
        if exclude_id:
            query += " AND id != ?"
            params.append(exclude_id)
        
        result = self._execute_query(query, tuple(params), fetch_one=True)
        return result['count'] > 0 if result else False
    
    def validate_tipo_procedimiento_exists(self, procedimiento_id: int) -> bool:
        """Valida que el tipo de procedimiento existe"""
        return self.exists('id', procedimiento_id)
    
    def get_available_tipo_procedimientos_names(self) -> List[str]:
        """Obtiene lista de nombres de tipos de procedimientos disponibles"""
        query = "SELECT Nombre FROM Tipos_Procedimientos ORDER BY Nombre"
        result = self._execute_query(query)
        return [row['Nombre'] for row in result]
    
    # ===============================
    # ESTADÍSTICAS SIMPLIFICADAS
    # ===============================
    
    @cached_query('stats_tipos_procedimientos', ttl=600)
    def get_tipos_procedimientos_statistics(self) -> Dict[str, Any]:
        """Estadísticas básicas de tipos de procedimientos"""
        query = """
        SELECT 
            COUNT(*) as total_tipos_procedimientos,
            COUNT(CASE WHEN Descripcion IS NOT NULL AND Descripcion != '' THEN 1 END) as con_descripcion,
            COUNT(CASE WHEN Descripcion IS NULL OR Descripcion = '' THEN 1 END) as sin_descripcion,
            AVG(Precio_Normal) as precio_normal_promedio,
            AVG(Precio_Emergencia) as precio_emergencia_promedio,
            MIN(Precio_Normal) as precio_normal_minimo,
            MAX(Precio_Normal) as precio_normal_maximo,
            MIN(Precio_Emergencia) as precio_emergencia_minimo,
            MAX(Precio_Emergencia) as precio_emergencia_maximo
        FROM Tipos_Procedimientos
        """
        
        general_stats = self._execute_query(query, fetch_one=True)
        
        # Estadísticas por rangos de precios
        rangos_query = """
        SELECT 
            CASE 
                WHEN Precio_Normal = 0 THEN 'Gratuito'
                WHEN Precio_Normal <= 50 THEN 'Bajo (0-50)'
                WHEN Precio_Normal <= 100 THEN 'Medio (51-100)'
                WHEN Precio_Normal <= 200 THEN 'Alto (101-200)'
                ELSE 'Muy Alto (>200)'
            END as rango_precio,
            COUNT(*) as cantidad
        FROM Tipos_Procedimientos
        GROUP BY 
            CASE 
                WHEN Precio_Normal = 0 THEN 'Gratuito'
                WHEN Precio_Normal <= 50 THEN 'Bajo (0-50)'
                WHEN Precio_Normal <= 100 THEN 'Medio (51-100)'
                WHEN Precio_Normal <= 200 THEN 'Alto (101-200)'
                ELSE 'Muy Alto (>200)'
            END
        ORDER BY cantidad DESC
        """
        
        rangos_stats = self._execute_query(rangos_query)
        
        return {
            'general': general_stats,
            'rangos_precios': rangos_stats
        }
    
    # ===============================
    # REPORTES SIMPLIFICADOS
    # ===============================
    
    def get_tipos_procedimientos_for_report(self) -> List[Dict[str, Any]]:
        """Obtiene tipos de procedimientos formateados para reportes"""
        query = """
        SELECT id, Nombre, Descripcion, Precio_Normal, Precio_Emergencia
        FROM Tipos_Procedimientos
        ORDER BY Nombre
        """
        
        tipos_procedimientos = self._execute_query(query)
        
        # Agregar información adicional
        for procedimiento in tipos_procedimientos:
            if not procedimiento.get('Descripcion'):
                procedimiento['Descripcion'] = 'Sin descripción'
            
            # Calcular diferencia de precios
            precio_normal = procedimiento.get('Precio_Normal', 0)
            precio_emergencia = procedimiento.get('Precio_Emergencia', 0)
            if precio_normal > 0:
                diferencia_porcentual = ((precio_emergencia - precio_normal) / precio_normal) * 100
                procedimiento['diferencia_porcentual'] = round(diferencia_porcentual, 2)
            else:
                procedimiento['diferencia_porcentual'] = 0
        
        return tipos_procedimientos
    
    def get_tipo_procedimientos_summary(self) -> Dict[str, Any]:
        """Resumen simplificado de tipos de procedimientos"""
        query = """
        SELECT Nombre, Descripcion, Precio_Normal, Precio_Emergencia
        FROM Tipos_Procedimientos
        ORDER BY Nombre
        """
        
        procedimientos_data = self._execute_query(query)
        
        # Calcular totales generales
        total_procedimientos = len(procedimientos_data)
        procedimientos_con_descripcion = len([item for item in procedimientos_data if item.get('Descripcion')])
        procedimientos_sin_descripcion = total_procedimientos - procedimientos_con_descripcion
        
        # Calcular estadísticas de precios
        if procedimientos_data:
            precios_normales = [item.get('Precio_Normal', 0) for item in procedimientos_data]
            precios_emergencia = [item.get('Precio_Emergencia', 0) for item in procedimientos_data]
            
            precio_normal_promedio = sum(precios_normales) / len(precios_normales)
            precio_emergencia_promedio = sum(precios_emergencia) / len(precios_emergencia)
        else:
            precio_normal_promedio = 0
            precio_emergencia_promedio = 0
        
        return {
            'tipos_procedimientos': procedimientos_data,
            'resumen': {
                'total_procedimientos': total_procedimientos,
                'procedimientos_con_descripcion': procedimientos_con_descripcion,
                'procedimientos_sin_descripcion': procedimientos_sin_descripcion,
                'precio_normal_promedio': round(precio_normal_promedio, 2),
                'precio_emergencia_promedio': round(precio_emergencia_promedio, 2)
            }
        }
    
    # ===============================
    # UTILIDADES ESPECÍFICAS
    # ===============================
    
    def count_procedimientos_asociados(self, procedimiento_id: int) -> int:
        """Cuenta procedimientos asociados a un tipo específico (en tabla de procedimientos de enfermería)"""
        # Nota: Esta tabla puede no existir aún, ajustar según la estructura real
        try:
            query = "SELECT COUNT(*) as count FROM Procedimientos_Enfermeria WHERE ID_Tipo_Procedimiento = ?"
            result = self._execute_query(query, (procedimiento_id,), fetch_one=True)
            return result['count'] if result else 0
        except:
            # Si la tabla no existe, asumir que no hay asociaciones
            return 0
    
    def get_procedimientos_mas_utilizados(self, limit: int = 10) -> List[Dict[str, Any]]:
        """Obtiene los tipos de procedimientos más utilizados"""
        try:
            query = """
            SELECT tp.id, tp.Nombre, tp.Descripcion, tp.Precio_Normal, tp.Precio_Emergencia,
                   COUNT(pe.id) as total_usos
            FROM Tipos_Procedimientos tp
            LEFT JOIN Procedimientos_Enfermeria pe ON tp.id = pe.ID_Tipo_Procedimiento
            GROUP BY tp.id, tp.Nombre, tp.Descripcion, tp.Precio_Normal, tp.Precio_Emergencia
            ORDER BY total_usos DESC, tp.Nombre
            OFFSET 0 ROWS FETCH NEXT ? ROWS ONLY
            """
            return self._execute_query(query, (limit,))
        except:
            # Si las tablas no existen, devolver lista simple
            return self.get_all_tipos_procedimientos()[:limit]
    
    # ===============================
    # CACHÉ
    # ===============================
    
    def invalidate_tipos_procedimientos_caches(self):
        """Invalida cachés relacionados con tipos de procedimientos"""
        cache_types = ['tipos_procedimientos_all', 'stats_tipos_procedimientos', 'confi_enfermeria']
        from ...core.cache_system import invalidate_after_update
        invalidate_after_update(cache_types)
    
    def _invalidate_cache_after_modification(self):
        """Override para invalidación específica"""
        super()._invalidate_cache_after_modification()
        self.invalidate_tipos_procedimientos_caches()