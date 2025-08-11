"""
Repositories - Acceso a datos SQL Server

Repositories disponibles:
- ProductoRepository: Gestión de productos con FIFO
- VentaRepository: Ventas con actualización automática de stock
- CompraRepository: Compras con creación automática de lotes
"""

from .producto_repository import ProductoRepository
from .venta_repository import VentaRepository
from .compra_repository import CompraRepository

__all__ = [
    'ProductoRepository',
    'VentaRepository', 
    'CompraRepository'
]

print("📊 Repositories cargados")