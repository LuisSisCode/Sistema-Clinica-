"""
Repositories - Acceso a datos SQL Server

Repositories disponibles:
- ConfiguracionRepository: Gestión de tipos de gastos
- ConfiLaboratorioRepository: Gestión de tipos de análisis de laboratorio
"""

from .ConfiServiciosbasicos_repository import ConfiguracionRepository
from .ConfiLaboratorio_repository import ConfiLaboratorioRepository
from .ConfiEnfermeria_repository import ConfiEnfermeriaRepository
from .ConfiConsulta_repository import ConfiConsultaRepository
from .ConfiTrabajadores_repository import ConfiTrabajadoresRepository
__all__ = [
    'ConfiguracionRepository',
    'ConfiLaboratorioRepository',
    'ConfiEnfermeriaRepository',
    'ConfiConsultaRepository',
    'ConfiTrabajadoresRepository',
    
]

print("📊 Repositories de configuración cargados")