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
from .gasto_service import *
from .inventario_service import *
from .laboratorio_service import *
from .paciente_service import *
from .reporte_service import *
from .trabajador_service import *
from .usuario_service import UsuarioService

__all__ = [
    'AuthService',
    'CompraService',
    'ConsultaService',
    'DoctorService',
    'UsuarioService'
]

print("🧠 Services disponibles (opcional)")