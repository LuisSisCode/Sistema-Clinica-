"""
Services - Lógica de negocio (OPCIONAL)

En esta arquitectura QObject, la lógica de negocio está principalmente 
en los Models. Los Services son opcionales para casos complejos.

Services potenciales:
- auth_service: Autenticación y sesiones
- reporte_service: Generación de reportes complejos  
- notification_service: Sistema de notificaciones
"""
from .auth_service import AuthService
from .compra_service import CompraService
from .consulta_service import ConsultaService
from .dashboard_service import *
from .doctor_service import DoctorService
from .gasto_service import GastoService
from .inventario_service import InventarioService
from .laboratorio_service import LaboratorioService
from .paciente_service import PacienteService
from .reporte_service import ReporteService
from .trabajador_service import TrabajadorService
from .usuario_service import UsuarioService

__all__ = [
    'AuthService',
    'CompraService',
    'ConsultaService',
    '',
    'DoctorService',
    'GastoService',
    'InventarioService',
    'LaboratorioService',
    'PacienteService',
    'ReporteService',
    'TrabajadorService',
    'UsuarioService'
]

print("🧠 Services disponibles (opcional)")