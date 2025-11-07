"""
Repositories - Acceso a datos SQL Server

Repositories disponibles:
- ProductoRepository: Gestión de productos con FIFO
- VentaRepository: Ventas con actualización automática de stock
- CompraRepository: Compras con creación automática de lotes
"""

from .auth_repository import AuthRepository          # 0
from .producto_repository import ProductoRepository         # 1
from .venta_repository import VentaRepository               # 2
from .compra_repository import CompraRepository             # 3
from .consulta_repository import ConsultaRepository         # 4
from .medico_repository import MedicoRepository             # 5
from .gasto_repository import GastoRepository               # 6
from .laboratorio_repository import LaboratorioRepository   # 7
from .paciente_repository import PacienteRepository         # 8
from .estadistica_repository import EstadisticaRepository   # 9
from .trabajador_repository import TrabajadorRepository     # 10
from .proveedor_repository import ProveedorRepository     # 11
from .cierre_caja_repository import CierreCajaRepository  # 12
from .ingreso_extra_repository import IngresoExtraRepository  # 13
from .especialidad_repository import EspecialidadRepository # 14

__all__ = [
    'AuthRepository',
    'ProductoRepository',
    'VentaRepository', 
    'CompraRepository',
    'ConsultaRepository',
    'MedicoRepository',
    'GastoRepository',
    'LaboratorioRepository',
    'PacienteRepository',
    'EstadisticaRepository',
    'TrabajadorRepository',
    'ProveedorRepository',
    'CierreCajaRepository',
    'IngresoExtraRepository',
    'EspecialidadRepository'

]

print("📊 Repositories cargados")