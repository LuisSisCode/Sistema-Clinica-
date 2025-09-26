import threading
import time
from typing import Dict, Any, Optional, Callable
from datetime import datetime, timedelta
import json
import hashlib

class CacheSystem:
    """Sistema de caché thread-safe para consultas SQL Server"""
    
    def __init__(self, default_ttl: int = 300):  # 5 minutos default
        self._cache: Dict[str, Dict[str, Any]] = {}
        self._lock = threading.RLock()
        self._default_ttl = default_ttl
        self._hits = 0
        self._misses = 0
        
        # Configuraciones específicas por tipo de consulta
        self._ttl_config = {
            'productos': 180,        # 3 min - cambia frecuentemente
            'marcas': 1800,         # 30 min - relativamente estático
            'ventas_today': 60,     # 1 min - muy dinámico
            'stock_producto': 120,  # 2 min - importante para farmacia
            'lotes_activos': 300,   # 5 min - moderadamente dinámico
            'proveedores': 900,     # 15 min - poco cambio
            'precios': 240,         # 4 min - importante para ventas
        }
    
    def _generate_key(self, query: str, params: tuple = ()) -> str:
        """Genera clave única para la consulta"""
        combined = f"{query}:{str(params)}"
        return hashlib.md5(combined.encode()).hexdigest()
    
    def _is_expired(self, cache_entry: Dict[str, Any]) -> bool:
        """Verifica si la entrada está expirada"""
        return time.time() > cache_entry['expires_at']
    
    def _cleanup_expired(self):
        """Limpia entradas expiradas (thread-safe)"""
        with self._lock:
            current_time = time.time()
            expired_keys = [
                key for key, entry in self._cache.items() 
                if current_time > entry['expires_at']
            ]
            for key in expired_keys:
                del self._cache[key]
    
    def get(self, query: str, params: tuple = (), cache_type: str = 'default') -> Optional[Any]:
        """
        Obtiene datos del caché
        
        Args:
            query: Consulta SQL
            params: Parámetros de la consulta
            cache_type: Tipo de caché (productos, ventas_today, etc.)
        """
        cache_key = self._generate_key(query, params)
        
        with self._lock:
            if cache_key in self._cache:
                entry = self._cache[cache_key]
                if not self._is_expired(entry):
                    self._hits += 1
                    #print(f"🎯 Cache HIT: {cache_type} - {cache_key[:8]}")
                    return entry['data']
                else:
                    # Entrada expirada
                    del self._cache[cache_key]
                    self._misses += 1
                    #print(f"⏰ Cache EXPIRED: {cache_type}")
            
            self._misses += 1
            return None
    
    def set(self, query: str, data: Any, params: tuple = (), cache_type: str = 'default') -> None:
        """
        Almacena datos en caché
        
        Args:
            query: Consulta SQL
            data: Datos a cachear
            params: Parámetros de la consulta
            cache_type: Tipo de caché para determinar TTL
        """
        cache_key = self._generate_key(query, params)
        ttl = self._ttl_config.get(cache_type, self._default_ttl)
        expires_at = time.time() + ttl
        
        with self._lock:
            self._cache[cache_key] = {
                'data': data,
                'created_at': time.time(),
                'expires_at': expires_at,
                'cache_type': cache_type,
                'query_hash': cache_key[:8]
            }
            #print(f"💾 Cache SET: {cache_type} - TTL:{ttl}s - {cache_key[:8]}")
        
        # Limpieza ocasional
        if len(self._cache) % 50 == 0:
            self._cleanup_expired()
    
    def invalidate_by_type(self, cache_type: str) -> int:
        """
        Invalida todas las entradas de un tipo específico
        Útil cuando se actualizan productos, ventas, etc.
        """
        with self._lock:
            keys_to_remove = [
                key for key, entry in self._cache.items()
                if entry.get('cache_type') == cache_type
            ]
            
            for key in keys_to_remove:
                del self._cache[key]
            
            count = len(keys_to_remove)
            if count > 0:
                pass
                #print(f"🗑️ Cache INVALIDATED: {cache_type} - {count} entries")
            return count
    
    def invalidate_pattern(self, pattern: str) -> int:
        """Invalida entradas que contengan el patrón en la query"""
        with self._lock:
            keys_to_remove = []
            for key, entry in self._cache.items():
                # Buscar patrón en las queries originales (tendríamos que guardarlas)
                # Por ahora, invalidamos por cache_type que contenga el patrón
                if pattern.lower() in entry.get('cache_type', '').lower():
                    keys_to_remove.append(key)
            
            for key in keys_to_remove:
                del self._cache[key]
            
            count = len(keys_to_remove)
            if count > 0:
                print(f"🔍 Cache PATTERN INVALIDATED: '{pattern}' - {count} entries")
            return count
    
    def clear_all(self) -> int:
        """Limpia todo el caché"""
        with self._lock:
            count = len(self._cache)
            self._cache.clear()
            self._hits = 0
            self._misses = 0
            print(f"🧹 Cache CLEARED: {count} entries removed")
            return count
    
    def get_stats(self) -> Dict[str, Any]:
        """Estadísticas del caché"""
        with self._lock:
            total_requests = self._hits + self._misses
            hit_rate = (self._hits / total_requests * 100) if total_requests > 0 else 0
            
            # Estadísticas por tipo
            type_stats = {}
            for entry in self._cache.values():
                cache_type = entry.get('cache_type', 'unknown')
                if cache_type not in type_stats:
                    type_stats[cache_type] = 0
                type_stats[cache_type] += 1
            
            return {
                'total_entries': len(self._cache),
                'hits': self._hits,
                'misses': self._misses,
                'hit_rate': round(hit_rate, 2),
                'types': type_stats,
                'memory_usage_mb': self._estimate_memory_usage()
            }
    
    def _estimate_memory_usage(self) -> float:
        """Estima uso de memoria del caché"""
        try:
            import sys
            total_size = sys.getsizeof(self._cache)
            for entry in self._cache.values():
                total_size += sys.getsizeof(entry)
                total_size += sys.getsizeof(entry.get('data', ''))
            return round(total_size / (1024 * 1024), 2)  # MB
        except:
            return 0.0
    
    def print_stats(self):
        """Imprime estadísticas en terminal"""
        stats = self.get_stats()
        print("\n" + "="*50)
        print("📊 CACHE STATISTICS")
        print("="*50)
        print(f"Total Entries: {stats['total_entries']}")
        print(f"Hits: {stats['hits']} | Misses: {stats['misses']}")
        print(f"Hit Rate: {stats['hit_rate']}%")
        print(f"Memory Usage: {stats['memory_usage_mb']} MB")
        print("\nEntries by type:")
        for cache_type, count in stats['types'].items():
            ttl = self._ttl_config.get(cache_type, self._default_ttl)
            print(f"  {cache_type}: {count} entries (TTL: {ttl}s)")
        print("="*50 + "\n")

# Instancia global singleton
_cache_instance = None
_cache_lock = threading.Lock()

def get_cache() -> CacheSystem:
    """Obtiene la instancia singleton del cache"""
    global _cache_instance
    if _cache_instance is None:
        with _cache_lock:
            if _cache_instance is None:
                _cache_instance = CacheSystem()
                print("🚀 Cache System initialized")
    return _cache_instance

# Decorador para funciones que usan caché
def cached_query(cache_type: str = 'default', ttl: int = None):
    """
    Decorador para cachear automáticamente resultados de consultas
    
    Usage:
        @cached_query('productos', ttl=180)
        def get_productos(self):
            # Tu consulta SQL aquí
            pass
    """
    def decorator(func: Callable):
        def wrapper(*args, **kwargs):
            cache = get_cache()
            
            # Generar clave basada en función y argumentos
            func_key = f"{func.__name__}:{str(args[1:])}{str(kwargs)}"  # Excluir 'self'
            
            # Intentar obtener del caché
            cached_result = cache.get(func_key, (), cache_type)
            if cached_result is not None:
                return cached_result
            
            # Ejecutar función y cachear resultado
            result = func(*args, **kwargs)
            if result is not None:
                cache.set(func_key, result, (), cache_type)
            
            return result
        return wrapper
    return decorator

# Función de utilidad para invalidación rápida después de operaciones CUD
def invalidate_after_update(cache_types: list):
    """
    Invalida tipos de caché después de operaciones de actualización
    
    Usage:
        invalidate_after_update(['productos', 'stock_producto'])
    """
    cache = get_cache()
    for cache_type in cache_types:
        cache.invalidate_by_type(cache_type)