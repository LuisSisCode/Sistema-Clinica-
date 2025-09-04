"""
Models QObject - Conectores entre QML y Backend

Models disponibles:
- ConfiguracionModel: Gestión de configuración de tipos de gastos
- ConfiLaboratorioModel: Gestión de configuración de tipos de análisis de laboratorio

Todos los models tienen Signals/Slots/Properties para integración QML
"""

from .ConfiServiciosbasicos_model import ConfiguracionModel, register_configuracion_model
from .ConfiLaboratorio_model import ConfiLaboratorioModel, register_confi_laboratorio_model
from .ConfiEnfermeria_model import ConfiEnfermeriaModel, register_confi_enfermeria_model
__all__ = [
    'ConfiguracionModel', 'register_configuracion_model',
    'ConfiLaboratorioModel', 'register_confi_laboratorio_model',
    'ConfiEnfermeriaModel', 'register_confi_enfermeria_model',
    
]

print("🎯 Models QObject de configuración cargados")