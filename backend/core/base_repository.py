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
    ✅ CORREGIDO: Con invalidación mejorada de cache para ventas
    """
    
    def __init__(self, table_name: str, cache_type: str = 'default'):
        self.table_name = table_name
        self.cache_type = cache_type
        self.db = DatabaseConnection()
        self.cache = get_cache()
        self._lock = threading.RLock()
        
        # ✅ NUEVOS: Flags para control de cache
        self._bypass_all_cache = False
        self._force_reload = False
        self._force_reload_productos = False
        self._last_cache_invalidation = None
    
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
        ✅ VERSIÓN MEJORADA: Ejecuta consulta SQL con manejo robusto de errores
        NUNCA lanza excepciones sin control, SIEMPRE retorna valores seguros
        """
        
        # ✅ VALIDAR QUERY NO VACÍA
        if not query or query.strip() == "":
            print(f"❌ Query vacía en {self.table_name}")
            if fetch_one:
                return None
            return [] if query.strip().upper().startswith('SELECT') else 0
        
        # ✅ VERIFICAR FLAGS DE BYPASS PRIMERO
        if hasattr(self, '_bypass_all_cache') and self._bypass_all_cache:
            use_cache = False
        
        if hasattr(self, '_force_reload') and self._force_reload:
            use_cache = False
        
        # Flag específico para productos después de ventas
        if (hasattr(self, '_force_reload_productos') and self._force_reload_productos 
            and ('Productos' in query or 'productos' in query.lower())):
            use_cache = False
        
        # Verificar caché para SELECT queries (solo si use_cache es True)
        if use_cache and query.strip().upper().startswith('SELECT'):
            cached_result = self.cache.get(query, params, self.cache_type)
            if cached_result is not None:
                return cached_result
        
        with self._lock:
            conn = None
            cursor = None
            
            try:
                # ✅ OBTENER CONEXIÓN CON VALIDACIÓN
                try:
                    conn = self._get_connection()
                except Exception as conn_error:
                    print(f"❌ Error obteniendo conexión en {self.table_name}: {conn_error}")
                    if fetch_one:
                        return None
                    return [] if query.strip().upper().startswith('SELECT') else 0
                
                # ✅ VALIDAR QUE LA CONEXIÓN SEA VÁLIDA
                if not conn:
                    print(f"❌ Conexión None en {self.table_name}")
                    if fetch_one:
                        return None
                    return [] if query.strip().upper().startswith('SELECT') else 0
                
                cursor = conn.cursor()
                
                # Debug: Mostrar análisis de la query
                query_upper = query.strip().upper()
                is_select = query_upper.startswith('SELECT')
                has_output = 'OUTPUT INSERTED' in query_upper
                has_insert = 'INSERT' in query_upper
                
                # ✅ EJECUTAR QUERY CON VALIDACIÓN
                try:
                    cursor.execute(query, params)
                except Exception as exec_error:
                    print(f"❌ Error ejecutando query en {self.table_name}: {exec_error}")
                    print(f"🔍 Query: {query[:100]}...")
                    print(f"🔍 Params: {params}")
                    if conn:
                        conn.rollback()
                    
                    # ✅ RETORNAR VALOR SEGURO SEGÚN TIPO DE QUERY
                    if fetch_one:
                        return None
                    return [] if is_select else 0
                
                # ✅ PROCESAR RESULTADOS SEGÚN TIPO DE QUERY
                if query_upper.startswith('SELECT'):
                    # SELECT queries
                    try:
                        if fetch_one:
                            row = cursor.fetchone()
                            result = self._row_to_dict(cursor, row) if row else None
                        else:
                            rows = cursor.fetchall()
                            # ✅ VALIDAR QUE rows SEA UNA LISTA
                            if not isinstance(rows, list):
                                print(f"⚠️ fetchall() no retornó lista en {self.table_name}")
                                result = []
                            else:
                                result = [self._row_to_dict(cursor, row) for row in rows]
                        
                        # Cachear resultado SOLO SI use_cache es True
                        if use_cache and result is not None:
                            self.cache.set(query, result, params, self.cache_type)
                        
                        return result
                        
                    except Exception as fetch_error:
                        print(f"❌ Error procesando resultados SELECT en {self.table_name}: {fetch_error}")
                        if fetch_one:
                            return None
                        return []
                        
                elif has_output and has_insert:
                    # INSERT con OUTPUT - MANEJO ESPECÍFICO PARA SQL SERVER
                    print(f"🔍 Procesando INSERT con OUTPUT en {self.table_name}...")
                    
                    try:
                        row = cursor.fetchone()
                        
                        if row is not None:
                            # Convertir la fila a diccionario
                            columns = [column[0] for column in cursor.description]
                            result = {}
                            
                            for column, value in zip(columns, row):
                                result[column] = value
                            
                            # Verificar que tenemos el ID
                            if 'id' in result and result['id'] is not None:
                                conn.commit()
                                # ✅ INVALIDACIÓN MEJORADA DESPUÉS DE INSERT
                                self._invalidate_cache_after_modification()
                                print(f"✅ INSERT con OUTPUT exitoso en {self.table_name} - ID: {result['id']}")
                                return result
                            else:
                                print(f"❌ ERROR: ID no encontrado en resultado INSERT")
                                conn.rollback()
                                return None
                        else:
                            print(f"❌ ERROR: cursor.fetchone() retornó None en INSERT")
                            conn.rollback()
                            return None
                            
                    except Exception as fetch_error:
                        print(f"❌ ERROR en fetchone() INSERT: {fetch_error}")
                        if conn:
                            conn.rollback()
                        return None
                        
                else:
                    # UPDATE, DELETE queries normales
                    try:
                        affected_rows = cursor.rowcount
                        
                        # ✅ VALIDAR QUE affected_rows SEA NUMÉRICO
                        if not isinstance(affected_rows, int):
                            print(f"⚠️ rowcount no es int: {type(affected_rows)}")
                            affected_rows = 0
                        
                        conn.commit()
                        
                        # ✅ INVALIDAR caché después de operaciones CUD
                        self._invalidate_cache_after_modification()
                        
                        print(f"✅ {query.split()[0]} completado en {self.table_name} - Filas: {affected_rows}")
                        return affected_rows
                        
                    except Exception as update_error:
                        print(f"❌ Error en UPDATE/DELETE en {self.table_name}: {update_error}")
                        if conn:
                            conn.rollback()
                        return 0
                        
            except pyodbc.Error as e:
                if conn:
                    try:
                        conn.rollback()
                    except:
                        pass
                
                print(f"❌ ERROR SQL en {self.table_name}: {str(e)}")
                print(f"🔍 Query: {query[:200]}...")
                print(f"🔍 Params: {params}")
                
                # ✅ NO LANZAR EXCEPCIÓN, RETORNAR VALOR SEGURO
                if fetch_one:
                    return None
                return [] if query.strip().upper().startswith('SELECT') else 0
                
            except Exception as e:
                if conn:
                    try:
                        conn.rollback()
                    except:
                        pass
                
                print(f"❌ ERROR INESPERADO en {self.table_name}: {str(e)}")
                import traceback
                traceback.print_exc()
                
                # ✅ NO LANZAR EXCEPCIÓN, RETORNAR VALOR SEGURO
                if fetch_one:
                    return None
                return [] if query.strip().upper().startswith('SELECT') else 0
                
            finally:
                # ✅ CERRAR CURSOR PRIMERO
                if cursor:
                    try:
                        cursor.close()
                    except:
                        pass
                
                # ✅ CERRAR CONEXIÓN
                if conn:
                    try:
                        conn.close()
                    except Exception as close_error:
                        print(f"⚠️ Error cerrando conexión: {close_error}")

    
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
        """
        ✅ MEJORADO: Invalida caché después de operaciones que modifican datos
        """
        try:
            print(f"🧹 INICIANDO INVALIDACIÓN COMPLETA DE CACHE para {self.table_name}...")
            
            # Marcar timestamp de invalidación
            self._last_cache_invalidation = datetime.now()
            
            # Invalidar caché principal
            invalidate_after_update([self.cache_type])
            print(f"   🗑️ Cache tipo '{self.cache_type}' invalidado")
            
            # ✅ INVALIDACIÓN CRUZADA MEJORADA según el tipo de tabla
            if self.cache_type == 'productos' or self.table_name == 'Productos':
                # Productos afecta stock, lotes, ventas
                cache_types_to_invalidate = ['stock_producto', 'lotes_activos', 'ventas', 'ventas_today']
                invalidate_after_update(cache_types_to_invalidate)
                print(f"   🔄 Caches cruzados invalidados para productos: {cache_types_to_invalidate}")
                
            elif self.cache_type == 'ventas' or self.table_name == 'Ventas':
                # Ventas afecta productos, stock, estadísticas
                cache_types_to_invalidate = ['productos', 'stock_producto', 'ventas_today', 'estadisticas_ventas']
                invalidate_after_update(cache_types_to_invalidate)
                print(f"   🔄 Caches cruzados invalidados para ventas: {cache_types_to_invalidate}")
                
            elif self.cache_type == 'lotes' or self.table_name == 'Lote':
                # Lotes afecta productos y stock
                cache_types_to_invalidate = ['productos', 'stock_producto', 'lotes_activos']
                invalidate_after_update(cache_types_to_invalidate)
                print(f"   🔄 Caches cruzados invalidados para lotes: {cache_types_to_invalidate}")
                
            elif self.cache_type == 'compras' or self.table_name == 'Compras':
                # Compras afecta productos, lotes, stock
                cache_types_to_invalidate = ['productos', 'lotes_activos', 'stock_producto']
                invalidate_after_update(cache_types_to_invalidate)
                print(f"   🔄 Caches cruzados invalidados para compras: {cache_types_to_invalidate}")
            
            # ✅ LIMPIAR CACHES INTERNOS DEL OBJETO
            caches_to_clear = [
                '_cache', '_query_cache', '_result_cache', '_data_cache', 
                '_product_cache', '_stock_cache', '_search_cache'
            ]
            
            cache_cleared_count = 0
            for cache_name in caches_to_clear:
                if hasattr(self, cache_name):
                    cache_obj = getattr(self, cache_name)
                    if hasattr(cache_obj, 'clear'):
                        cache_obj.clear()
                        cache_cleared_count += 1
                        print(f"   🗑️ {cache_name} limpiado")
            
            # ✅ RESETEAR TIMESTAMPS DE CACHÉ
            timestamp_attrs = [
                '_last_cache_time', '_cache_timestamp', '_last_update',
                '_last_product_cache', '_last_stock_update'
            ]
            
            for attr_name in timestamp_attrs:
                if hasattr(self, attr_name):
                    setattr(self, attr_name, None)
            
            # ✅ ACTIVAR FLAGS DE BYPASS TEMPORALES
            self._force_reload = True
            self._bypass_all_cache = True
            
            # Para queries de productos específicamente
            if self.cache_type in ['ventas', 'lotes', 'compras']:
                self._force_reload_productos = True
            
           
        except Exception as e:
            print(f"⚠️ Error en invalidación completa de cache: {e}")
            # No fallar por esto, es solo optimización
    
    # ✅ NUEVOS MÉTODOS PARA CONTROL DE CACHE
    
    def force_query_without_cache(self, query: str, params: tuple = (), fetch_one: bool = False):
        """
        ✅ NUEVO: Fuerza una consulta sin usar cache bajo ninguna circunstancia
        """
        print(f"🚫 FORZANDO CONSULTA SIN CACHE en {self.table_name}: {query[:50]}...")
        
        # Temporalmente desactivar TODOS los caches
        original_bypass = getattr(self, '_bypass_all_cache', False)
        original_force = getattr(self, '_force_reload', False)
        
        self._bypass_all_cache = True
        self._force_reload = True
        
        try:
            result = self._execute_query(query, params, fetch_one=fetch_one, use_cache=False)
            print(f"✅ Consulta sin cache completada en {self.table_name}")
            return result
        finally:
            # Restaurar estados originales
            self._bypass_all_cache = original_bypass
            self._force_reload = original_force
    
    def reset_bypass_flags(self):
        """
        ✅ NUEVO: Resetea flags de bypass después de operaciones críticas
        """
        try:
            self._bypass_all_cache = False
            self._force_reload = False
            self._force_reload_productos = False
            print(f"🔄 Flags de bypass reseteados en {self.table_name}")
        except Exception as e:
            print(f"⚠️ Error reseteando flags en {self.table_name}: {e}")
    
    def invalidate_all_caches(self):
        """
        ✅ NUEVO: Invalida TODOS los caches - para usar después de ventas críticas
        """
        try:
            print(f"🧹 INVALIDACIÓN TOTAL DE CACHES iniciada desde {self.table_name}")
            
            # Invalidar todos los tipos de cache conocidos
            all_cache_types = [
                'default', 'productos', 'ventas', 'lotes', 'compras', 'usuarios',
                'stock_producto', 'lotes_activos', 'ventas_today', 'estadisticas_ventas',
                'search_productos', 'producto_cache', 'venta_cache'
            ]
            
            invalidate_after_update(all_cache_types)
            
            # Activar todos los flags de bypass
            self._bypass_all_cache = True
            self._force_reload = True
            self._force_reload_productos = True
            
            # Limpiar cache del objeto
            if hasattr(self, 'cache') and self.cache:
                if hasattr(self.cache, 'clear_all'):
                    self.cache.clear_all()
                elif hasattr(self.cache, 'clear'):
                    self.cache.clear()
            
            print(f"✅ INVALIDACIÓN TOTAL completada desde {self.table_name}")
            
        except Exception as e:
            print(f"❌ Error en invalidación total: {e}")
    
    def get_cache_status(self):
        """
        ✅ NUEVO: Obtiene estado actual del cache para debug
        """
        return {
            'table_name': self.table_name,
            'cache_type': self.cache_type,
            'bypass_all_cache': getattr(self, '_bypass_all_cache', False),
            'force_reload': getattr(self, '_force_reload', False),
            'force_reload_productos': getattr(self, '_force_reload_productos', False),
            'last_invalidation': getattr(self, '_last_cache_invalidation', None)
        }
    
    # ===============================
    # MÉTODOS CRUD BÁSICOS (MEJORADOS)
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
    
    # ✅ NUEVOS MÉTODOS SIN CACHE
    def get_by_id_no_cache(self, record_id: int) -> Optional[Dict[str, Any]]:
        """✅ NUEVO: Obtiene registro por ID SIN usar cache"""
        query = f"SELECT * FROM {self.table_name} WHERE id = ?"
        return self.force_query_without_cache(query, (record_id,), fetch_one=True)
    
    def get_by_field_no_cache(self, field_name: str, value: Any) -> List[Dict[str, Any]]:
        """✅ NUEVO: Obtiene registros por campo SIN usar cache"""
        query = f"SELECT * FROM {self.table_name} WHERE {field_name} = ?"
        return self.force_query_without_cache(query, (value,))
    
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
        """✅ MEJORADO: Insert con invalidación automática de cache"""
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
        
        print(f"🔍 DEBUG INSERT: Tabla {self.table_name}")
        print(f"🔍 DEBUG INSERT: Campos {fields}")
        print(f"🔍 DEBUG INSERT: Valores {values}")
        
        result = self._execute_query(query, values, fetch_one=True, use_cache=False)
        
        # Manejo mejorado del resultado
        if result and isinstance(result, dict) and 'id' in result:
            inserted_id = result['id']
            print(f"✅ INSERT {self.table_name}: ID {inserted_id}")
            
            # ✅ INVALIDACIÓN FORZADA DESPUÉS DE INSERT EXITOSO
            self.invalidate_all_caches()
            
            return inserted_id
        else:
            print(f"❌ ERROR: INSERT falló para {self.table_name}")
            print(f"❌ Resultado obtenido: {result} (tipo: {type(result)})")
            return None

    def update(self, record_id: int, data: Dict[str, Any]) -> bool:
        """
        ✅ MEJORADO: Actualiza registro con invalidación de cache
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
            # ✅ INVALIDACIÓN FORZADA DESPUÉS DE UPDATE EXITOSO
            self.invalidate_all_caches()
        else:
            print(f"⚠️ UPDATE {self.table_name}: ID {record_id} no encontrado")
            
        return success
    
    def delete(self, record_id: int) -> bool:
        """
        ✅ MEJORADO: Elimina registro con invalidación de cache
        """
        validate_required(record_id, "record_id")
        
        query = f"DELETE FROM {self.table_name} WHERE id = ?"
        affected_rows = self._execute_query(query, (record_id,), fetch_all=False, use_cache=False)
        success = affected_rows > 0
        
        if success:
            print(f"🗑️ DELETE {self.table_name}: ID {record_id}")
            # ✅ INVALIDACIÓN FORZADA DESPUÉS DE DELETE EXITOSO
            self.invalidate_all_caches()
        else:
            print(f"⚠️ DELETE {self.table_name}: ID {record_id} no encontrado")
            
        return success
    
    # ===============================
    # MÉTODOS DE TRANSACCIONES (MEJORADOS)
    # ===============================
    
    def execute_transaction(self, operations: List[Tuple[str, tuple]]) -> bool:
        """
        ✅ MEJORADO: Ejecuta múltiples operaciones con invalidación completa
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
                
                # ✅ INVALIDACIÓN COMPLETA después de transacción exitosa
                self.invalidate_all_caches()
                
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
              limit: int = 50, offset: int = 0, use_cache: bool = True) -> List[Dict[str, Any]]:
        """
        ✅ MEJORADO: Búsqueda con control de cache
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
        
        return self._execute_query(query, tuple(params), use_cache=use_cache)
    
    def search_no_cache(self, search_term: str, search_fields: List[str], 
                       limit: int = 50, offset: int = 0) -> List[Dict[str, Any]]:
        """✅ NUEVO: Búsqueda garantizada sin cache"""
        return self.search(search_term, search_fields, limit, offset, use_cache=False)
    
    def get_paginated(self, page: int = 1, per_page: int = 50, 
                     order_by: str = "id", where_clause: str = "", 
                     params: tuple = ()) -> Dict[str, Any]:
        """
        Obtiene resultados paginados
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
    # MÉTODOS DE UTILIDAD (MEJORADOS)
    # ===============================
    
    def refresh_cache(self):
        """✅ MEJORADO: Refresca el caché para este repository"""
        self.cache.invalidate_by_type(self.cache_type)
        self.invalidate_all_caches()
        print(f"🔄 Cache completamente refrescado: {self.cache_type}")
    
    def get_cache_stats(self):
        """Obtiene estadísticas de caché"""
        stats = self.cache.get_stats() if self.cache else {}
        stats.update(self.get_cache_status())
        return stats
    
    @ExceptionHandler.handle_exception
    def safe_execute_custom(self, query: str, params: tuple = ()):
        """Ejecuta consulta personalizada de forma segura"""
        return self._execute_query(query, params, use_cache=False)
    
    # ✅ NUEVOS MÉTODOS DE MANTENIMIENTO
    
    def clear_all_internal_caches(self):
        """✅ NUEVO: Limpia todos los caches internos del objeto"""
        try:
            # Lista extendida de posibles caches internos
            possible_caches = [
                '_cache', '_query_cache', '_result_cache', '_data_cache',
                '_product_cache', '_stock_cache', '_search_cache', '_lote_cache',
                '_venta_cache', '_user_cache', '_stats_cache'
            ]
            
            cleared_count = 0
            for cache_name in possible_caches:
                if hasattr(self, cache_name):
                    cache_obj = getattr(self, cache_name)
                    if hasattr(cache_obj, 'clear'):
                        cache_obj.clear()
                        cleared_count += 1
                    elif isinstance(cache_obj, dict):
                        cache_obj.clear()
                        cleared_count += 1
            
            print(f"🧹 {cleared_count} caches internos limpiados en {self.table_name}")
            
        except Exception as e:
            print(f"⚠️ Error limpiando caches internos: {e}")
    
    def emergency_cache_reset(self):
        """✅ NUEVO: Reseteo de emergencia de todos los caches"""
        try:
            print(f"🚨 RESETEO DE EMERGENCIA DE CACHE en {self.table_name}")
            
            # Limpiar todos los caches internos
            self.clear_all_internal_caches()
            
            # Invalidar completamente
            self.invalidate_all_caches()
            
            # Activar todos los flags de bypass
            self._bypass_all_cache = True
            self._force_reload = True
            self._force_reload_productos = True
            
            # Resetear todos los timestamps
            time_attrs = [attr for attr in dir(self) if 'time' in attr.lower() or 'timestamp' in attr.lower()]
            for attr in time_attrs:
                if not attr.startswith('__'):
                    try:
                        setattr(self, attr, None)
                    except:
                        pass
            
            print(f"✅ RESETEO DE EMERGENCIA completado en {self.table_name}")
            
        except Exception as e:
            print(f"❌ Error en reseteo de emergencia: {e}")