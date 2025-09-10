from PySide6.QtCore import QObject, Signal
from typing import Optional

class GlobalSignalsManager(QObject):
    """Gestor global de señales para comunicación entre módulos desacoplados"""
    
    # ===== LABORATORIO =====
    tipoAnalisisCreado = Signal(int, str, float, float)  # id, nombre, precio_normal, precio_emergencia
    tipoAnalisisActualizado = Signal(int, str)  # id, nombre
    tipoAnalisisEliminado = Signal(int, str)  # id, mensaje
    tiposAnalisisModificados = Signal()
    laboratorioNecesitaActualizacion = Signal(str)  # mensaje
    
    # ===== ENFERMERÍA =====
    tipoProcedimientoCreado = Signal(int, str, float, float)  # id, nombre, precio_normal, precio_emergencia
    tipoProcedimientoActualizado = Signal(int, str)  # id, nombre
    tipoProcedimientoEliminado = Signal(int, str)  # id, mensaje
    tiposProcedimientosModificados = Signal()
    enfermeriaNecesitaActualizacion = Signal(str)  # mensaje
    
    # ===== TIPOS DE GASTOS =====
    tipoGastoCreado = Signal(int, str)  # id, nombre
    tipoGastoActualizado = Signal(int, str)  # id, nombre
    tipoGastoEliminado = Signal(int, str)  # id, mensaje
    tiposGastosModificados = Signal()
    configuracionGastosNecesitaActualizacion = Signal(str)  # mensaje
    
    # ===== TIPOS DE TRABAJADORES =====
    tipoTrabajadorCreado = Signal(int, str)  # id, tipo
    tipoTrabajadorActualizado = Signal(int, str)  # id, tipo
    tipoTrabajadorEliminado = Signal(int, str)  # id, mensaje
    tiposTrabajadoresModificados = Signal()
    trabajadoresNecesitaActualizacion = Signal(str)  # mensaje
    
    # ===== ESPECIALIDADES/CONSULTAS =====
    especialidadCreada = Signal(int, str, float, float)  # id, nombre, precio_normal, precio_emergencia
    especialidadActualizada = Signal(int, str)  # id, nombre
    especialidadEliminada = Signal(int, str)  # id, mensaje
    especialidadesModificadas = Signal()
    consultasNecesitaActualizacion = Signal(str)  # mensaje
    
    # ===== GESTIÓN DE GASTOS =====
    gastoCreado = Signal(int, float, str)  # id, monto, descripcion
    gastoActualizado = Signal(int, str)  # id, mensaje
    gastoEliminado = Signal(int, str)  # id, mensaje
    gastosModificados = Signal()
    gastosNecesitaActualizacion = Signal(str)  # mensaje
    
    # ===== GENERALES =====
    pacienteModificado = Signal(int)  # id
    configuracionCambiada = Signal(str, 'QVariant')  # tipo, datos
    actualizacionGlobal = Signal(str)  # mensaje global
    
    def __init__(self):
        super().__init__()
        print("🔗 GlobalSignalsManager inicializado")
    
    # ===== MÉTODOS PARA NOTIFICAR CAMBIOS =====
    
    def notificar_cambio_tipos_analisis(self, accion: str, tipo_id: int = 0, nombre: str = ""):
        """Notifica cambios de tipos de análisis"""
        mensaje = f"Tipos de análisis {accion}"
        print(f"📡 Notificando: {mensaje}")
        
        self.tiposAnalisisModificados.emit()
        self.laboratorioNecesitaActualizacion.emit(mensaje)
        
        # Notificar también a módulos relacionados
        self.actualizacionGlobal.emit(f"Laboratorio: {mensaje}")
    
    def notificar_cambio_tipos_procedimientos(self, accion: str, tipo_id: int = 0, nombre: str = ""):
        """Notifica cambios de tipos de procedimientos de enfermería"""
        mensaje = f"Tipos de procedimientos {accion}"
        print(f"📡 Notificando: {mensaje}")
        
        self.tiposProcedimientosModificados.emit()
        self.enfermeriaNecesitaActualizacion.emit(mensaje)
        
        # Notificar también a módulos relacionados
        self.actualizacionGlobal.emit(f"Enfermería: {mensaje}")
    
    def notificar_cambio_tipos_gastos(self, accion: str, tipo_id: int = 0, nombre: str = ""):
        """Notifica cambios de tipos de gastos"""
        mensaje = f"Tipos de gastos {accion}"
        print(f"📡 Notificando: {mensaje}")
        
        self.tiposGastosModificados.emit()
        self.configuracionGastosNecesitaActualizacion.emit(mensaje)
        self.gastosNecesitaActualizacion.emit(mensaje)
        
        # Notificar también a módulos relacionados
        self.actualizacionGlobal.emit(f"Gastos: {mensaje}")
    
    def notificar_cambio_tipos_trabajadores(self, accion: str, tipo_id: int = 0, tipo: str = ""):
        """Notifica cambios de tipos de trabajadores"""
        mensaje = f"Tipos de trabajadores {accion}"
        print(f"📡 Notificando: {mensaje}")
        
        self.tiposTrabajadoresModificados.emit()
        self.trabajadoresNecesitaActualizacion.emit(mensaje)
        
        # Notificar también a módulos relacionados
        self.actualizacionGlobal.emit(f"Trabajadores: {mensaje}")
    
    def notificar_cambio_especialidades(self, accion: str, esp_id: int = 0, nombre: str = ""):
        """Notifica cambios de especialidades/consultas"""
        mensaje = f"Especialidades {accion}"
        print(f"📡 Notificando: {mensaje}")
        
        self.especialidadesModificadas.emit()
        self.consultasNecesitaActualizacion.emit(mensaje)
        
        # Notificar también a módulos relacionados
        self.actualizacionGlobal.emit(f"Consultas: {mensaje}")

# ===== SINGLETON =====
_global_signals_instance: Optional[GlobalSignalsManager] = None

def get_global_signals() -> GlobalSignalsManager:
    """Obtiene la instancia singleton del gestor de señales globales"""
    global _global_signals_instance
    if _global_signals_instance is None:
        _global_signals_instance = GlobalSignalsManager()
    return _global_signals_instance

def reset_global_signals():
    """Reinicia el singleton (solo para testing)"""
    global _global_signals_instance
    if _global_signals_instance is not None:
        _global_signals_instance.deleteLater()
    _global_signals_instance = None