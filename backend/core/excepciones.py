import logging
from typing import Optional, Dict, Any
from datetime import datetime

# Configurar logging para excepciones
logging.basicConfig(
    level=logging.ERROR,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger('clinica_exceptions')

class ClinicaBaseException(Exception):
    """Excepción base para toda la aplicación de clínica"""
    
    def __init__(self, message: str, error_code: str = None, details: Dict[str, Any] = None):
        self.message = message
        self.error_code = error_code or self.__class__.__name__
        self.details = details or {}
        self.timestamp = datetime.now()
        
        super().__init__(self.message)
        
        # Log automático en terminal
        logger.error(f"🚨 {self.error_code}: {self.message}")
        if self.details:
            logger.error(f"📋 Detalles: {self.details}")

# ===============================
# EXCEPCIONES DE BASE DE DATOS
# ===============================

class DatabaseConnectionError(ClinicaBaseException):
    """Error de conexión a SQL Server"""
    def __init__(self, message: str = "Error conectando a SQL Server", server: str = None):
        details = {"servidor": server} if server else {}
        super().__init__(message, "DB_CONNECTION_ERROR", details)

class DatabaseQueryError(ClinicaBaseException):
    """Error ejecutando consulta SQL"""
    def __init__(self, message: str, query: str = None, params: tuple = None):
        details = {
            "query": query[:100] + "..." if query and len(query) > 100 else query,
            "params": str(params) if params else None
        }
        super().__init__(message, "DB_QUERY_ERROR", details)

class DatabaseTransactionError(ClinicaBaseException):
    """Error en transacción de base de datos"""
    def __init__(self, message: str = "Error en transacción", operation: str = None):
        details = {"operation": operation} if operation else {}
        super().__init__(message, "DB_TRANSACTION_ERROR", details)

# ===============================
# EXCEPCIONES DE FARMACIA
# ===============================

class ProductoNotFoundError(ClinicaBaseException):
    """Producto no encontrado"""
    def __init__(self, codigo: str = None, producto_id: int = None):
        message = f"Producto no encontrado"
        details = {}
        if codigo:
            message += f" con código: {codigo}"
            details["codigo"] = codigo
        if producto_id:
            message += f" con ID: {producto_id}"
            details["producto_id"] = producto_id
        super().__init__(message, "PRODUCTO_NOT_FOUND", details)

class StockInsuficienteError(ClinicaBaseException):
    """Stock insuficiente para la venta"""
    def __init__(self, codigo_producto: str, stock_disponible: int, cantidad_solicitada: int):
        message = f"Stock insuficiente para {codigo_producto}. Disponible: {stock_disponible}, Solicitado: {cantidad_solicitada}"
        details = {
            "codigo_producto": codigo_producto,
            "stock_disponible": stock_disponible,
            "cantidad_solicitada": cantidad_solicitada
        }
        super().__init__(message, "STOCK_INSUFICIENTE", details)

class ProductoVencidoError(ClinicaBaseException):
    """Producto vencido en lote FIFO"""
    def __init__(self, codigo_producto: str, fecha_vencimiento: str, lote_id: int = None):
        message = f"Producto {codigo_producto} vencido (Vence: {fecha_vencimiento})"
        details = {
            "codigo_producto": codigo_producto,
            "fecha_vencimiento": fecha_vencimiento,
            "lote_id": lote_id
        }
        super().__init__(message, "PRODUCTO_VENCIDO", details)

class PrecioInvalidoError(ClinicaBaseException):
    """Precio inválido para producto"""
    def __init__(self, precio: float, codigo_producto: str = None):
        message = f"Precio inválido: {precio}"
        details = {"precio": precio, "codigo_producto": codigo_producto}
        super().__init__(message, "PRECIO_INVALIDO", details)

class VentaError(ClinicaBaseException):
    """Error general en proceso de venta"""
    def __init__(self, message: str, venta_id: int = None, items: list = None):
        details = {"venta_id": venta_id, "items_count": len(items) if items else 0}
        super().__init__(message, "VENTA_ERROR", details)

class CompraError(ClinicaBaseException):
    """Error en proceso de compra"""
    def __init__(self, message: str, proveedor_id: int = None, total: float = None):
        details = {"proveedor_id": proveedor_id, "total": total}
        super().__init__(message, "COMPRA_ERROR", details)

# ===============================
# EXCEPCIONES DE VALIDACIÓN
# ===============================

class ValidationError(ClinicaBaseException):
    """Error de validación de datos"""
    def __init__(self, field: str, value: Any, rule: str):
        message = f"Validación falló para '{field}': {rule}"
        details = {"field": field, "value": str(value), "rule": rule}
        super().__init__(message, "VALIDATION_ERROR", details)

class AuthenticationError(ClinicaBaseException):
    """Error de autenticación"""
    def __init__(self, username: str = None):
        message = "Credenciales inválidas"
        details = {"username": username} if username else {}
        super().__init__(message, "AUTH_ERROR", details)

class PermissionError(ClinicaBaseException):
    """Error de permisos de usuario"""
    def __init__(self, action: str, user_role: str = None):
        message = f"Sin permisos para: {action}"
        details = {"action": action, "user_role": user_role}
        super().__init__(message, "PERMISSION_ERROR", details)

# ===============================
# EXCEPCIONES DE CACHÉ
# ===============================

class CacheError(ClinicaBaseException):
    """Error en sistema de caché"""
    def __init__(self, message: str, cache_key: str = None):
        details = {"cache_key": cache_key} if cache_key else {}
        super().__init__(message, "CACHE_ERROR", details)

# ===============================
# EXCEPCIONES DE INTEGRACIÓN QML
# ===============================

class QMLIntegrationError(ClinicaBaseException):
    """Error en integración QML-Python"""
    def __init__(self, message: str, model_name: str = None, signal_name: str = None):
        details = {"model_name": model_name, "signal_name": signal_name}
        super().__init__(message, "QML_INTEGRATION_ERROR", details)

class ModelError(ClinicaBaseException):
    """Error en Models QObject"""
    def __init__(self, message: str, model_class: str = None, method: str = None):
        details = {"model_class": model_class, "method": method}
        super().__init__(message, "MODEL_ERROR", details)

# ===============================
# EXCEPCIONES DE REPORTES
# ===============================

class ReporteError(ClinicaBaseException):
    """Error generando reportes PDF"""
    def __init__(self, message: str, tipo_reporte: str = None, fecha_range: tuple = None):
        details = {"tipo_reporte": tipo_reporte, "fecha_range": fecha_range}
        super().__init__(message, "REPORTE_ERROR", details)

# ===============================
# MANEJADOR GLOBAL DE EXCEPCIONES
# ===============================

class ExceptionHandler:
    """Manejador centralizado de excepciones"""
    
    @staticmethod
    def handle_exception(func):
        """Decorador para manejo automático de excepciones"""
        def wrapper(*args, **kwargs):
            try:
                return func(*args, **kwargs)
            except ClinicaBaseException as e:
                # Ya está loggeada automáticamente
                raise
            except Exception as e:
                # Convertir excepción genérica a ClinicaBaseException
                error_msg = f"Error inesperado en {func.__name__}: {str(e)}"
                logger.error(f"💥 {error_msg}")
                raise ClinicaBaseException(error_msg, "UNEXPECTED_ERROR", {
                    "function": func.__name__,
                    "original_error": str(e),
                    "args": str(args[1:]) if len(args) > 1 else None  # Excluir 'self'
                })
        return wrapper
    
    @staticmethod
    def log_warning(message: str, details: Dict[str, Any] = None):
        """Log de advertencias (no son errores críticos)"""
        logger.warning(f"⚠️ {message}")
        if details:
            logger.warning(f"📋 Detalles: {details}")
    
    @staticmethod
    def log_info(message: str, operation: str = None):
        """Log de información general"""
        prefix = f"[{operation}] " if operation else ""
        print(f"ℹ️ {prefix}{message}")

# ===============================
# VALIDADORES COMUNES
# ===============================

def validate_required(value: Any, field_name: str):
    """Valida que un campo requerido no esté vacío"""
    if value is None or (isinstance(value, str) and value.strip() == ""):
        raise ValidationError(field_name, value, "Campo requerido")

def validate_positive_number(value: float, field_name: str):
    """Valida que un número sea positivo"""
    if not isinstance(value, (int, float)) or value < 0:
        raise ValidationError(field_name, value, "Debe ser un número positivo")

def validate_email(email: str):
    """Validación básica de email"""
    if not email or "@" not in email or "." not in email:
        raise ValidationError("email", email, "Formato de email inválido")

def validate_stock_operation(cantidad: int, stock_disponible: int, codigo_producto: str):
    """Valida operaciones de stock"""
    if cantidad <= 0:
        raise ValidationError("cantidad", cantidad, "Cantidad debe ser mayor a 0")
    
    if cantidad > stock_disponible:
        raise StockInsuficienteError(codigo_producto, stock_disponible, cantidad)

# Función de utilidad para manejo rápido
def safe_execute(func, *args, **kwargs):
    """Ejecuta función de forma segura con manejo de excepciones"""
    try:
        return func(*args, **kwargs)
    except ClinicaBaseException:
        raise
    except Exception as e:
        raise ClinicaBaseException(f"Error ejecutando {func.__name__}: {str(e)}")

# Instancia global del manejador
exception_handler = ExceptionHandler()