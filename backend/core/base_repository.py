import pyodbc
import threading
from typing import List, Dict, Any, Optional, Union, Tuple
from abc import ABC, abstractmethod
from datetime import datetime
import decimal 

from .database_conexion import DatabaseConnection
from .cache_system import get_cache, cached_query, invalidate_after_update
from .excepciones import (
    DatabaseQueryError, DatabaseTransactionError, DatabaseConnectionError,
    ExceptionHandler, safe_execute, validate_required
)

class BaseRepository(ABC):
    """
    Clase base para todos los repositories con CRUD + Caché + Transacciones
    """
    
    def __init__(self, table_name: str, cache_type: str = 'default'):
        self.table_name = table_name
        self.cache_type = cache_type
        self.db = DatabaseConnection()
        self.cache = get_cache()
        self._lock = threading.RLock()
        
        print(f"🗃️ Repository inicializado: {table_name} (cache: {cache_type})")
    
    # ===============================
    # MÉTODOS DE CONEXIÓN SEGUROS
    # ===============================
    
    def _get_connection(self) -> pyodbc.Connection:
        """Obtiene conexión thread-safe"""
        try:
            return self.db.get_connection()
        except Exception as e:
            raise DatabaseConnectionError(f"Error obteniendo conexión: {str(e)}")
    
    def _execute_query(self, query: str, params: tuple = (), fetch_one: bool = False, 
                      fetch_all: bool = True, use_cache: bool = True) -> Union[List[Dict], Dict, int]:
        """
        Ejecuta consulta SQL con manejo de errores y caché
        
        Args:
            query: Consulta SQL
            params: Parámetros de la consulta
            fetch_one: Retornar solo un registro
            fetch_all: Retornar todos los registros
            use_cache: Usar sistema de caché
            
        Returns:
            Lista de diccionarios, diccionario único, o número de filas afectadas
        """
        # Verificar caché para SELECT queries
        if use_cache and query.strip().upper().startswith('SELECT'):
            cached_result = self.cache.get(query, params, self.cache_type)
            if cached_result is not None:
                return cached_result
        
        with self._lock:
            try:
                conn = self._get_connection()
                cursor = conn.cursor()
                
                cursor.execute(query, params)
                
                if query.strip().upper().startswith('SELECT'):
                    # SELECT queries
                    if fetch_one:
                        row = cursor.fetchone()
                        result = self._row_to_dict(cursor, row) if row else None
                    else:
                        rows = cursor.fetchall()
                        result = [self._row_to_dict(cursor, row) for row in rows]
                    
                    # Cachear resultado
                    if use_cache and result is not None:
                        self.cache.set(query, result, params, self.cache_type)
                    
                    return result
                else:
                    # INSERT, UPDATE, DELETE queries
                    affected_rows = cursor.rowcount
                    conn.commit()
                    
                    # Invalidar caché después de operaciones CUD
                    self._invalidate_cache_after_modification()
                    
                    return affected_rows
                    
            except pyodbc.Error as e:
                if 'conn' in locals():
                    conn.rollback()
                raise DatabaseQueryError(f"Error SQL: {str(e)}", query, params)
            except Exception as e:
                if 'conn' in locals():
                    conn.rollback()
                raise DatabaseQueryError(f"Error inesperado: {str(e)}", query, params)
            finally:
                if 'conn' in locals():
                    conn.close()
    
    def _row_to_dict(self, cursor: pyodbc.Cursor, row: pyodbc.Row) -> Dict[str, Any]:
        """Convierte fila de SQL a diccionario"""
        if row is None:
            return None
        
        columns = [column[0] for column in cursor.description]
        result = {}
        
        for column, value in zip(columns, row):
            # Convertir Decimal a float para compatibilidad con QML
            if isinstance(value, decimal.Decimal):
                result[column] = float(value)
            else:
                result[column] = value
        
        return result
    
    def _invalidate_cache_after_modification(self):
        """Invalida caché después de operaciones que modifican datos"""
        invalidate_after_update([self.cache_type])
        
        # Invalidar cachés relacionados (ej: productos también afecta stock)
        if self.cache_type == 'productos':
            invalidate_after_update(['stock_producto', 'lotes_activos'])
        elif self.cache_type == 'ventas':
            invalidate_after_update(['productos', 'stock_producto', 'ventas_today'])
        elif self.cache_type == 'compras':
            invalidate_after_update(['productos', 'lotes_activos'])
    
    # ===============================
    # MÉTODOS CRUD BÁSICOS
    # ===============================
    
    def get_all(self, order_by: str = "id", where_clause: str = "", params: tuple = ()) -> List[Dict[str, Any]]:
        """Obtiene todos los registros"""
        where_sql = f" WHERE {where_clause}" if where_clause else ""
        query = f"SELECT * FROM {self.table_name}{where_sql} ORDER BY {order_by}"
        
        return self._execute_query(query, params)
    
    def get_by_id(self, record_id: int) -> Optional[Dict[str, Any]]:
        """Obtiene registro por ID"""
        query = f"SELECT * FROM {self.table_name} WHERE id = ?"
        return self._execute_query(query, (record_id,), fetch_one=True)
    
    def get_by_field(self, field_name: str, value: Any) -> List[Dict[str, Any]]:
        """Obtiene registros por campo específico"""
        query = f"SELECT * FROM {self.table_name} WHERE {field_name} = ?"
        return self._execute_query(query, (value,))
    
    def get_one_by_field(self, field_name: str, value: Any) -> Optional[Dict[str, Any]]:
        """Obtiene un registro por campo específico"""
        query = f"SELECT * FROM {self.table_name} WHERE {field_name} = ?"
        return self._execute_query(query, (value,), fetch_one=True)
    
    def exists(self, field_name: str, value: Any) -> bool:
        """Verifica si existe un registro"""
        query = f"SELECT COUNT(*) as count FROM {self.table_name} WHERE {field_name} = ?"
        result = self._execute_query(query, (value,), fetch_one=True)
        return result['count'] > 0 if result else False
    
    def count(self, where_clause: str = "", params: tuple = ()) -> int:
        """Cuenta registros"""
        where_sql = f" WHERE {where_clause}" if where_clause else ""
        query = f"SELECT COUNT(*) as count FROM {self.table_name}{where_sql}"
        result = self._execute_query(query, params, fetch_one=True)
        return result['count'] if result else 0
    
    def insert(self, data: Dict[str, Any]) -> int:
        """
        Inserta nuevo registro
        
        Args:
            data: Diccionario con datos a insertar
            
        Returns:
            ID del registro insertado
        """
        validate_required(data, "data")
        
        fields = list(data.keys())
        placeholders = ', '.join(['?' for _ in fields])
        fields_str = ', '.join(fields)
        values = tuple(data.values())
        
        query = f"""
        INSERT INTO {self.table_name} ({fields_str}) 
        OUTPUT INSERTED.id 
        VALUES ({placeholders})
        """
        
        result = self._execute_query(query, values, fetch_one=True)
        inserted_id = result['id'] if result else None
        
        print(f"✅ INSERT {self.table_name}: ID {inserted_id}")
        return inserted_id
    
    def update(self, record_id: int, data: Dict[str, Any]) -> bool:
        """
        Actualiza registro existente
        
        Args:
            record_id: ID del registro a actualizar
            data: Diccionario con datos a actualizar
            
        Returns:
            True si se actualizó correctamente
        """
        validate_required(data, "data")
        validate_required(record_id, "record_id")
        
        fields = list(data.keys())
        set_clause = ', '.join([f"{field} = ?" for field in fields])
        values = tuple(data.values()) + (record_id,)
        
        query = f"UPDATE {self.table_name} SET {set_clause} WHERE id = ?"
        
        affected_rows = self._execute_query(query, values, fetch_all=False, use_cache=False)
        success = affected_rows > 0
        
        if success:
            print(f"✅ UPDATE {self.table_name}: ID {record_id}")
        else:
            print(f"⚠️ UPDATE {self.table_name}: ID {record_id} no encontrado")
            
        return success
    
    def delete(self, record_id: int) -> bool:
        """
        Elimina registro por ID
        
        Args:
            record_id: ID del registro a eliminar
            
        Returns:
            True si se eliminó correctamente
        """
        validate_required(record_id, "record_id")
        
        query = f"DELETE FROM {self.table_name} WHERE id = ?"
        affected_rows = self._execute_query(query, (record_id,), fetch_all=False, use_cache=False)
        success = affected_rows > 0
        
        if success:
            print(f"🗑️ DELETE {self.table_name}: ID {record_id}")
        else:
            print(f"⚠️ DELETE {self.table_name}: ID {record_id} no encontrado")
            
        return success
    
    # ===============================
    # MÉTODOS DE TRANSACCIONES
    # ===============================
    
    def execute_transaction(self, operations: List[Tuple[str, tuple]]) -> bool:
        """
        Ejecuta múltiples operaciones en una transacción
        
        Args:
            operations: Lista de tuplas (query, params)
            
        Returns:
            True si todas las operaciones fueron exitosas
        """
        if not operations:
            return True
        
        with self._lock:
            conn = None
            try:
                conn = self._get_connection()
                cursor = conn.cursor()
                
                # Comenzar transacción
                for query, params in operations:
                    cursor.execute(query, params)
                
                # Confirmar transacción
                conn.commit()
                
                # Invalidar caché después de transacción exitosa
                self._invalidate_cache_after_modification()
                
                print(f"✅ TRANSACTION {self.table_name}: {len(operations)} operaciones")
                return True
                
            except Exception as e:
                if conn:
                    conn.rollback()
                raise DatabaseTransactionError(f"Error en transacción: {str(e)}")
            finally:
                if conn:
                    conn.close()
    
    # ===============================
    # MÉTODOS DE BÚSQUEDA AVANZADA
    # ===============================
    
    def search(self, search_term: str, search_fields: List[str], 
              limit: int = 50, offset: int = 0) -> List[Dict[str, Any]]:
        """
        Búsqueda de texto en múltiples campos
        
        Args:
            search_term: Término a buscar
            search_fields: Campos donde buscar
            limit: Límite de resultados
            offset: Offset para paginación
        """
        if not search_term or not search_fields:
            return []
        
        search_conditions = []
        params = []
        
        for field in search_fields:
            search_conditions.append(f"{field} LIKE ?")
            params.append(f"%{search_term}%")
        
        where_clause = " OR ".join(search_conditions)
        query = f"""
        SELECT * FROM {self.table_name} 
        WHERE {where_clause}
        ORDER BY id 
        OFFSET ? ROWS FETCH NEXT ? ROWS ONLY
        """
        params.extend([offset, limit])
        
        return self._execute_query(query, tuple(params))
    
    def get_paginated(self, page: int = 1, per_page: int = 50, 
                     order_by: str = "id", where_clause: str = "", 
                     params: tuple = ()) -> Dict[str, Any]:
        """
        Obtiene resultados paginados
        
        Returns:
            {
                'data': [...],
                'total': int,
                'page': int,
                'per_page': int,
                'pages': int
            }
        """
        offset = (page - 1) * per_page
        
        # Query para datos
        where_sql = f" WHERE {where_clause}" if where_clause else ""
        data_query = f"""
        SELECT * FROM {self.table_name}{where_sql}
        ORDER BY {order_by}
        OFFSET ? ROWS FETCH NEXT ? ROWS ONLY
        """
        data_params = params + (offset, per_page)
        
        # Query para total
        count_query = f"SELECT COUNT(*) as total FROM {self.table_name}{where_sql}"
        
        data = self._execute_query(data_query, data_params)
        total_result = self._execute_query(count_query, params, fetch_one=True)
        total = total_result['total'] if total_result else 0
        
        return {
            'data': data,
            'total': total,
            'page': page,
            'per_page': per_page,
            'pages': (total + per_page - 1) // per_page
        }
    
    # ===============================
    # MÉTODOS ABSTRACTOS
    # ===============================
    
    @abstractmethod
    def get_active(self) -> List[Dict[str, Any]]:
        """Obtiene registros activos (debe implementarse en cada repository)"""
        pass
    
    # ===============================
    # MÉTODOS DE UTILIDAD
    # ===============================
    
    def refresh_cache(self):
        """Refresca el caché para este repository"""
        self.cache.invalidate_by_type(self.cache_type)
        print(f"🔄 Cache refrescado: {self.cache_type}")
    
    def get_cache_stats(self):
        """Obtiene estadísticas de caché"""
        return self.cache.get_stats()
    
    @ExceptionHandler.handle_exception
    def safe_execute_custom(self, query: str, params: tuple = ()):
        """Ejecuta consulta personalizada de forma segura"""
        return self._execute_query(query, params, use_cache=False)