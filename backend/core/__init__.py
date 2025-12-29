"""
Core Backend - Sistema base y utilidades compartidas

Componentes principales:
- database_conexion: Conexión SQL Server con patrón Singleton
- cache_system: Sistema de caché thread-safe con TTL
- excepciones: Manejo de errores personalizado
- base_repository: Clase base para repositories CRUD
"""

from .database_conexion import DatabaseConnection
from .cache_system import CacheSystem, get_cache
from .excepciones import (
    ClinicaBaseException, DatabaseConnectionError, DatabaseQueryError,
    ProductoNotFoundError, StockInsuficienteError, VentaError, CompraError,
    ValidationError, ExceptionHandler
)
from .base_repository import BaseRepository
from .config_fifo import ConfigFIFO

__all__ = [
    'DatabaseConnection',
    'CacheSystem', 'get_cache',
    'ClinicaBaseException', 'DatabaseConnectionError', 'DatabaseQueryError',
    'ProductoNotFoundError', 'StockInsuficienteError', 'VentaError', 'CompraError',
    'ValidationError', 'ExceptionHandler',
    'BaseRepository',
    'ConfigFIFO',
]

print("🔧 Core Backend cargado")