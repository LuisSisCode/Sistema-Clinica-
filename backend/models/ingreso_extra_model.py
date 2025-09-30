from dataclasses import dataclass
from datetime import datetime
from typing import Optional
from decimal import Decimal


@dataclass
class IngresoExtra:
    """
    Modelo para la tabla de Ingresos Extras
    """
    id: Optional[int] = None
    descripcion: str = ""
    monto: Decimal = Decimal('0.00')
    fecha: datetime = None
    id_registrado_por: Optional[int] = None
    
    # Campos adicionales para mostrar en la UI (joins)
    nombre_registrado_por: Optional[str] = None
    
    def __post_init__(self):
        """Validaciones y conversiones despuÃ©s de inicializar"""
        if self.fecha is None:
            self.fecha = datetime.now()
        
        # Asegurar que el monto sea Decimal
        if not isinstance(self.monto, Decimal):
            self.monto = Decimal(str(self.monto))
    
    def to_dict(self):
        """Convierte el objeto a diccionario para JSON/QML"""
        return {
            'id': self.id,
            'descripcion': self.descripcion,
            'monto': float(self.monto),
            'fecha': self.fecha.strftime('%Y-%m-%d') if isinstance(self.fecha, datetime) else self.fecha,
            'id_registrado_por': self.id_registrado_por,
            'nombre_registrado_por': self.nombre_registrado_por or "N/A"
        }
    
    @staticmethod
    def from_dict(data: dict):
        """Crea un objeto IngresoExtra desde un diccionario"""
        fecha = data.get('fecha')
        if isinstance(fecha, str):
            fecha = datetime.strptime(fecha, '%Y-%m-%d')
        
        return IngresoExtra(
            id=data.get('id'),
            descripcion=data.get('descripcion', ''),
            monto=Decimal(str(data.get('monto', 0))),
            fecha=fecha,
            id_registrado_por=data.get('id_registrado_por'),
            nombre_registrado_por=data.get('nombre_registrado_por')
        )
    
    def validate(self) -> tuple[bool, str]:
        """
        Valida los datos del ingreso extra
        Returns: (es_valido, mensaje_error)
        """
        if not self.descripcion or len(self.descripcion.strip()) == 0:
            return False, "La descripciÃ³n es obligatoria"
        
        if self.monto <= 0:
            return False, "El monto debe ser mayor a 0"
        
        if not self.fecha:
            return False, "La fecha es obligatoria"
        
        if not self.id_registrado_por:
            return False, "Debe especificar el usuario que registra"
        
        return True, ""