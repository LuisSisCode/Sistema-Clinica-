from typing import List, Dict, Any, Optional

from ...core.base_repository import BaseRepository
from ...core.excepciones import (
    ValidationError, ExceptionHandler, validate_required
)
from ...core.cache_system import cached_query
from ...core.utils import (
    normalize_name, validate_required_string, safe_int
)

class ConfiTrabajadoresRepository(BaseRepository):
    """Repository para gestión de Configuración de Tipos de Trabajadores"""
    
    def __init__(self):
        super().__init__('Tipo_Trabajadores', 'confi_trabajadores')
    
    # ===============================
    # CONSTANTES DE ÁREAS FUNCIONALES
    # ===============================
    
    @staticmethod
    def get_areas_funcionales_validas() -> List[str]:
        """Retorna lista de áreas funcionales válidas"""
        return ['MEDICO', 'ENFERMERIA', 'LABORATORIO', 'FARMACIA', 'ADMINISTRATIVO']
    
    @staticmethod
    def get_areas_funcionales_con_nombres() -> List[Dict[str, str]]:
        """Retorna áreas funcionales con nombres amigables para UI"""
        return [
            {'value': 'MEDICO', 'label': 'Área Médica'},
            {'value': 'ENFERMERIA', 'label': 'Área de Enfermería'},
            {'value': 'LABORATORIO', 'label': 'Área de Laboratorio'},
            {'value': 'FARMACIA', 'label': 'Área de Farmacia'},
            {'value': 'ADMINISTRATIVO', 'label': 'Área Administrativa'},
            {'value': None, 'label': 'Sin área específica'}
        ]
    
    # ===============================
    # IMPLEMENTACIÓN ABSTRACTA
    # ===============================
    
    def get_active(self) -> List[Dict[str, Any]]:
        """Obtiene todos los tipos de trabajadores activos"""
        return self.get_all_tipos_trabajadores()
    
    # ===============================
    # CRUD ESPECÍFICO - TIPOS DE TRABAJADORES
    # ===============================
    
    def create_tipo_trabajador(self, tipo: str, descripcion: str = None, 
                             area_funcional: str = None) -> int:
        """
        Crea nuevo tipo de trabajador con validaciones
        
        Args:
            tipo: Nombre del tipo de trabajador
            descripcion: Descripción del tipo de trabajador
            area_funcional: Área funcional (MEDICO, ENFERMERIA, LABORATORIO, FARMACIA, ADMINISTRATIVO, o None)
            
        Returns:
            ID del tipo de trabajador creado
        """
        # Validaciones
        tipo = validate_required_string(tipo, "tipo", 2)
        validate_required(tipo, "tipo")
        
        # Validar area_funcional si se proporciona
        AREAS_VALIDAS = self.get_areas_funcionales_validas()
        if area_funcional and area_funcional not in AREAS_VALIDAS:
            raise ValidationError("area_funcional", area_funcional, 
                                f"Área funcional inválida. Valores permitidos: {', '.join(AREAS_VALIDAS)}")
        
        # Verificar que el tipo no exista
        if self.tipo_trabajador_name_exists(tipo):
            raise ValidationError("tipo", tipo, "El tipo de trabajador ya existe")
        
        # Crear tipo de trabajador
        tipo_data = {
            'Tipo': normalize_name(tipo),
        }
        
        # Agregar descripción si se proporciona
        if descripcion and descripcion.strip():
            tipo_data['descripcion'] = descripcion.strip()
        else:
            tipo_data['descripcion'] = None
        
        # Agregar area_funcional si se proporciona
        if area_funcional and area_funcional in AREAS_VALIDAS:
            tipo_data['area_funcional'] = area_funcional
        else:
            tipo_data['area_funcional'] = None
        
        tipo_id = self.insert(tipo_data)
        area_str = f" [{area_funcional}]" if area_funcional else ""
        print(f"👥 Tipo de trabajador creado: {tipo}{area_str} - ID: {tipo_id}")
        
        return tipo_id
    
    def update_tipo_trabajador(self, tipo_id: int, tipo: str = None, 
                             descripcion: str = None, area_funcional: str = None) -> bool:
        """Actualiza tipo de trabajador existente incluyendo area_funcional"""
        # Verificar existencia
        if not self.get_by_id(tipo_id):
            raise ValidationError("tipo_id", tipo_id, "Tipo de trabajador no encontrado")
        
        update_data = {}
        
        if tipo is not None:
            tipo = validate_required_string(tipo, "tipo", 2)
            # Verificar nombre único (excepto el mismo registro)
            if self.tipo_trabajador_name_exists(tipo, exclude_id=tipo_id):
                raise ValidationError("tipo", tipo, "El tipo de trabajador ya existe")
            update_data['Tipo'] = normalize_name(tipo)
        
        if descripcion is not None:
            update_data['descripcion'] = descripcion.strip() if descripcion.strip() else None
        
        # Manejar area_funcional
        if area_funcional is not None:
            AREAS_VALIDAS = self.get_areas_funcionales_validas()
            
            # Permitir cadena vacía para limpiar el área
            if area_funcional == "" or area_funcional.upper() == "NINGUNA":
                update_data['area_funcional'] = None
            elif area_funcional in AREAS_VALIDAS:
                update_data['area_funcional'] = area_funcional
            else:
                raise ValidationError("area_funcional", area_funcional, 
                                    f"Área funcional inválida. Valores: {', '.join(AREAS_VALIDAS)} o vacío")
        
        if not update_data:
            return True
        
        success = self.update(tipo_id, update_data)
        if success:
            print(f"👥 Tipo de trabajador actualizado: ID {tipo_id}")
        
        return success
    
    def delete_tipo_trabajador(self, tipo_id: int) -> bool:
        """Elimina tipo de trabajador si no tiene trabajadores asociados"""
        # Verificar que no tenga trabajadores asociados
        trabajadores_count = self.count_trabajadores_asociados(tipo_id)
        if trabajadores_count > 0:
            raise ValidationError("tipo_id", tipo_id, 
                                f"No se puede eliminar. Tiene {trabajadores_count} trabajadores asociados")
        
        success = self.delete(tipo_id)
        if success:
            print(f"🗑️ Tipo de trabajador eliminado: ID {tipo_id}")
        
        return success
    
    # ===============================
    # CONSULTAS PRINCIPALES
    # ===============================
    
    @cached_query('tipos_trabajadores_all', ttl=600)
    def get_all_tipos_trabajadores(self) -> List[Dict[str, Any]]:
        """Obtiene todos los tipos de trabajadores incluyendo area_funcional"""
        query = """
        SELECT id, Tipo, descripcion, area_funcional
        FROM Tipo_Trabajadores
        ORDER BY 
            CASE area_funcional
                WHEN 'MEDICO' THEN 1
                WHEN 'ENFERMERIA' THEN 2
                WHEN 'LABORATORIO' THEN 3
                WHEN 'FARMACIA' THEN 4
                WHEN 'ADMINISTRATIVO' THEN 5
                ELSE 6
            END,
            Tipo
        """
        return self._execute_query(query)
    
    def get_tipo_trabajador_by_id(self, tipo_id: int) -> Optional[Dict[str, Any]]:
        """Obtiene tipo de trabajador específico por ID incluyendo area_funcional"""
        query = """
        SELECT id, Tipo, descripcion, area_funcional
        FROM Tipo_Trabajadores
        WHERE id = ?
        """
        return self._execute_query(query, (tipo_id,), fetch_one=True)
    
    def get_tipo_trabajador_by_name(self, tipo: str) -> Optional[Dict[str, Any]]:
        """Obtiene tipo de trabajador por nombre"""
        query = "SELECT * FROM Tipo_Trabajadores WHERE Tipo = ?"
        return self._execute_query(query, (tipo.strip(),), fetch_one=True)
    
    def get_tipos_by_area_funcional(self, area: str) -> List[Dict[str, Any]]:
        """
        Obtiene tipos de trabajadores de un área funcional específica
        
        Args:
            area: Área funcional (MEDICO, ENFERMERIA, LABORATORIO, FARMACIA, ADMINISTRATIVO)
        
        Returns:
            Lista de tipos de trabajadores del área especificada
        """
        query = """
        SELECT id, Tipo, descripcion, area_funcional
        FROM Tipo_Trabajadores
        WHERE area_funcional = ?
        ORDER BY Tipo
        """
        return self._execute_query(query, (area,))
    
    # ===============================
    # BÚSQUEDAS Y FILTROS
    # ===============================
    
    def search_tipos_trabajadores(self, search_term: str, limit: int = 50) -> List[Dict[str, Any]]:
        """Búsqueda por tipo o descripción"""
        if not search_term:
            return []
        
        search_term = f"%{search_term.strip()}%"
        
        query = """
        SELECT id, Tipo, descripcion, area_funcional
        FROM Tipo_Trabajadores
        WHERE Tipo LIKE ? OR descripcion LIKE ?
        ORDER BY Tipo
        OFFSET 0 ROWS FETCH NEXT ? ROWS ONLY
        """
        
        return self._execute_query(query, (search_term, search_term, limit))
    
    # ===============================
    # VALIDACIONES Y UTILIDADES
    # ===============================
    
    def tipo_trabajador_exists(self, tipo_id: int) -> bool:
        """Verifica si existe un tipo de trabajador"""
        query = "SELECT COUNT(*) as count FROM Tipo_Trabajadores WHERE id = ?"
        result = self._execute_query(query, (tipo_id,), fetch_one=True)
        return result['count'] > 0 if result else False
    
    def tipo_trabajador_name_exists(self, tipo: str, exclude_id: int = None) -> bool:
        """Verifica si existe un nombre de tipo de trabajador (excluyendo un ID específico)"""
        query = "SELECT COUNT(*) as count FROM Tipo_Trabajadores WHERE Tipo = ?"
        params = [tipo.strip()]
        
        if exclude_id:
            query += " AND id != ?"
            params.append(exclude_id)
        
        result = self._execute_query(query, tuple(params), fetch_one=True)
        return result['count'] > 0 if result else False
    
    def validate_tipo_trabajador_exists(self, tipo_id: int) -> bool:
        """Valida que el tipo de trabajador existe"""
        return self.exists('id', tipo_id)
    
    def get_available_tipo_trabajadores_names(self) -> List[str]:
        """Obtiene lista de nombres de tipos de trabajadores disponibles"""
        query = "SELECT Tipo FROM Tipo_Trabajadores ORDER BY Tipo"
        result = self._execute_query(query)
        return [row['Tipo'] for row in result]
    
    # ===============================
    # ESTADÍSTICAS SIMPLIFICADAS
    # ===============================
    
    @cached_query('stats_tipos_trabajadores', ttl=600)
    def get_tipos_trabajadores_statistics(self) -> Dict[str, Any]:
        """Estadísticas básicas de tipos de trabajadores"""
        query = """
        SELECT 
            COUNT(*) as total_tipos_trabajadores,
            COUNT(CASE WHEN descripcion IS NOT NULL AND descripcion != '' THEN 1 END) as con_descripcion,
            COUNT(CASE WHEN descripcion IS NULL OR descripcion = '' THEN 1 END) as sin_descripcion,
            COUNT(CASE WHEN area_funcional IS NOT NULL THEN 1 END) as con_area_funcional,
            COUNT(CASE WHEN area_funcional IS NULL THEN 1 END) as sin_area_funcional
        FROM Tipo_Trabajadores
        """
        
        general_stats = self._execute_query(query, fetch_one=True)
        
        # Estadísticas por área funcional
        query_areas = """
        SELECT area_funcional, COUNT(*) as cantidad
        FROM Tipo_Trabajadores
        WHERE area_funcional IS NOT NULL
        GROUP BY area_funcional
        ORDER BY cantidad DESC
        """
        
        areas_stats = self._execute_query(query_areas)
        
        return {
            'general': general_stats,
            'areas_funcionales': areas_stats
        }
    
    # ===============================
    # REPORTES SIMPLIFICADOS
    # ===============================
    
    def get_tipos_trabajadores_for_report(self) -> List[Dict[str, Any]]:
        """Obtiene tipos de trabajadores formateados para reportes"""
        query = """
        SELECT id, Tipo, descripcion, area_funcional
        FROM Tipo_Trabajadores
        ORDER BY 
            CASE area_funcional
                WHEN 'MEDICO' THEN 1
                WHEN 'ENFERMERIA' THEN 2
                WHEN 'LABORATORIO' THEN 3
                WHEN 'FARMACIA' THEN 4
                WHEN 'ADMINISTRATIVO' THEN 5
                ELSE 6
            END,
            Tipo
        """
        
        tipos_trabajadores = self._execute_query(query)
        
        # Agregar información adicional
        for tipo in tipos_trabajadores:
            if not tipo.get('descripcion'):
                tipo['descripcion'] = 'Sin descripción'
            if not tipo.get('area_funcional'):
                tipo['area_funcional'] = 'Sin área específica'
        
        return tipos_trabajadores
    
    def get_tipos_trabajadores_summary(self) -> Dict[str, Any]:
        """Resumen simplificado de tipos de trabajadores"""
        query = """
        SELECT Tipo, descripcion, area_funcional
        FROM Tipo_Trabajadores
        ORDER BY 
            CASE area_funcional
                WHEN 'MEDICO' THEN 1
                WHEN 'ENFERMERIA' THEN 2
                WHEN 'LABORATORIO' THEN 3
                WHEN 'FARMACIA' THEN 4
                WHEN 'ADMINISTRATIVO' THEN 5
                ELSE 6
            END,
            Tipo
        """
        
        tipos_data = self._execute_query(query)
        
        # Calcular totales generales
        total_tipos = len(tipos_data)
        tipos_con_descripcion = len([item for item in tipos_data if item.get('descripcion')])
        tipos_sin_descripcion = total_tipos - tipos_con_descripcion
        tipos_con_area = len([item for item in tipos_data if item.get('area_funcional')])
        tipos_sin_area = total_tipos - tipos_con_area
        
        return {
            'tipos_trabajadores': tipos_data,
            'resumen': {
                'total_tipos': total_tipos,
                'tipos_con_descripcion': tipos_con_descripcion,
                'tipos_sin_descripcion': tipos_sin_descripcion,
                'tipos_con_area_funcional': tipos_con_area,
                'tipos_sin_area_funcional': tipos_sin_area
            }
        }
    
    # ===============================
    # CACHÉ
    # ===============================
    
    def invalidate_tipos_trabajadores_caches(self):
        """Invalida cachés relacionados con tipos de trabajadores"""
        cache_types = ['tipos_trabajadores_all', 'stats_tipos_trabajadores', 'confi_trabajadores']
        from ...core.cache_system import invalidate_after_update
        invalidate_after_update(cache_types)
    
    def _invalidate_cache_after_modification(self):
        """Override para invalidación específica"""
        super()._invalidate_cache_after_modification()
        self.invalidate_tipos_trabajadores_caches()

    def count_trabajadores_asociados(self, tipo_id: int) -> int:
        """Cuenta trabajadores asociados a un tipo específico"""
        query = "SELECT COUNT(*) as count FROM Trabajadores WHERE Id_Tipo_Trabajador = ?"  
        result = self._execute_query(query, (tipo_id,), fetch_one=True)
        return result['count'] if result else 0