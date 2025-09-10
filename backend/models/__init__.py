"""
Models QObject - Conectores entre QML y Backend

Models disponibles:
- InventarioModel: Gestión de inventario con FIFO y alertas
- VentaModel: Procesamiento de ventas con carrito reactivo
- CompraModel: Gestión de compras con auto-creación de lotes

Todos los models tienen Signals/Slots/Properties para integración QML
"""
 
from .auth_model import AuthModel, register_auth_model                              # 1
from .compra_model import CompraModel, register_compra_model                        # 2
from .consulta_model import ConsultaModel, register_consulta_model                  # 3
from .dashboard_model import *                                                      # 4
from .doctor_model import DoctorModel, register_doctor_model                        # 5
from .gasto_model import GastoModel, register_gasto_model                                                         # 6
from .inventario_model import InventarioModel, register_inventario_model            # 7
from .laboratorio_model import LaboratorioModel, register_laboratorio_model         # 8
from .paciente_model import PacienteModel, register_paciente_model                  # 9
from .trabajador_model import TrabajadorModel, register_trabajador_model     # 10
from .usuario_model import UsuarioModel, register_usuario_model                     # 11
from .venta_model import VentaModel, register_venta_model 
from .proveedor_model import ProveedorModel, register_proveedor_model                          # 12


__all__ = [
    'AuthModel', 'register_auth_model',
    'CompraModel', 'register_compra_model',
    'ConsultaModel', 'register_consulta_model',
    '', '',
    'DoctorModel', 'register_doctor_model',
    'GastoModel', 'register_gasto_model',
    'InventarioModel', 'register_inventario_model',
    'LaboratorioModel', 'register_laboratorio_model',
    'PacienteModel', 'register_paciente_model',
    'TrabajadorModel', 'register_trabajador_model',
    'UsuarioModel', 'register_usuario_model',
    'VentaModel', 'register_venta_model',
    'ProveedorModel','register_proveedor_model'
    
]

print("🎯 Models QObject cargados")