"""
Repositories - Acceso a datos SQL Server

Repositories disponibles:
- ProductoRepository: Gestión de productos con FIFO
- VentaRepository: Ventas con actualización automática de stock
- CompraRepository: Compras con creación automática de lotes
"""

from .producto_repository import ProductoRepository         # 1
from .venta_repository import VentaRepository               # 2
from .compra_repository import CompraRepository             # 3
from .consulta_repository import ConsultaRepository         # 4
from .doctor_repository import DoctorRepository             # 5
from .gasto_repository import GastoRepository               # 6
from .laboratorio_repository import LaboratorioRepository   # 7
from .paciente_repository import PacienteRepository         # 8
from .estadistica_repository import EstadisticaRepository   # 9
from .trabajador_repository import TrabajadorRepository     # 10

__all__ = [
    'ProductoRepository',
    'VentaRepository', 
    'CompraRepository',
    'ConsultaRepository',
    'DoctorRepository',
    'GastoRepository',
    'LaboratorioRepository',
    'PacienteRepository',
    'EstadisticaRepository',
    'TrabajadorRepository'

]

print("📊 Repositories cargados")