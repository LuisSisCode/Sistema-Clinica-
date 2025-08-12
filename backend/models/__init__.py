"""
Models QObject - Conectores entre QML y Backend

Models disponibles:
- InventarioModel: Gestión de inventario con FIFO y alertas
- VentaModel: Procesamiento de ventas con carrito reactivo
- CompraModel: Gestión de compras con auto-creación de lotes

Todos los models tienen Signals/Slots/Properties para integración QML
"""

from .inventario_model import InventarioModel, register_inventario_model
from .venta_model import VentaModel, register_venta_model
from .compra_model import CompraModel, register_compra_model
from .usuario_model import UsuarioModel, register_usuario_model  # ← AGREGAR

__all__ = [
    'InventarioModel', 'register_inventario_model',
    'VentaModel', 'register_venta_model',
    'CompraModel', 'register_compra_model',
    'UsuarioModel', 'register_usuario_model'  # ← AGREGAR
]

print("🎯 Models QObject cargados")