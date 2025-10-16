# logger_config.py
"""
Sistema de Logging para Aplicación Compilada
Guarda logs en archivo cuando console=False
"""

import logging
import sys
import os
from pathlib import Path
from datetime import datetime

def setup_logger(app_name="ClinicaApp"):
    """
    Configura el sistema de logging para el ejecutable
    ✅ CORREGIDO: Logs en carpeta del usuario (no en Program Files)
    
    Returns:
        logging.Logger: Logger configurado
    """
    # Determinar directorio de logs
    if getattr(sys, 'frozen', False):
        # ✅ EJECUTABLE: logs en APPDATA del usuario
        app_dir = Path(os.environ['APPDATA']) / 'ClinicaMariaInmaculada'
    else:
        # Desarrollo: logs en carpeta del proyecto
        app_dir = Path(__file__).parent
    
    # Crear carpeta logs si no existe
    log_dir = app_dir / 'logs'
    log_dir.mkdir(parents=True, exist_ok=True)
    
    # Nombre del archivo con fecha
    timestamp = datetime.now().strftime('%Y%m%d')
    log_file = log_dir / f'{app_name}_{timestamp}.log'
    
    # Configurar logging
    logger = logging.getLogger(app_name)
    logger.setLevel(logging.DEBUG)
    
    # Limpiar handlers existentes
    if logger.handlers:
        logger.handlers.clear()
    
    # Handler para archivo
    file_handler = logging.FileHandler(
        log_file, 
        mode='a', 
        encoding='utf-8'
    )
    file_handler.setLevel(logging.DEBUG)
    
    # Formato detallado
    formatter = logging.Formatter(
        '%(asctime)s - %(levelname)s - %(funcName)s:%(lineno)d - %(message)s',
        datefmt='%Y-%m-%d %H:%M:%S'
    )
    file_handler.setFormatter(formatter)
    logger.addHandler(file_handler)
    
    # Si NO es ejecutable (desarrollo), también mostrar en consola
    if not getattr(sys, 'frozen', False):
        console_handler = logging.StreamHandler(sys.stdout)
        console_handler.setLevel(logging.INFO)
        console_handler.setFormatter(formatter)
        logger.addHandler(console_handler)
    
    # Log inicial
    logger.info("="*60)
    logger.info(f"INICIO DE SESIÓN - {app_name}")
    logger.info(f"Ejecutable: {getattr(sys, 'frozen', False)}")
    logger.info(f"Python: {sys.version}")
    logger.info(f"Directorio logs: {log_dir}")
    logger.info("="*60)
    
    return logger


def log_exception(logger, exception, context=""):
    """
    Log detallado de excepción
    
    Args:
        logger: Logger configurado
        exception: Excepción capturada
        context: Contexto donde ocurrió
    """
    import traceback
    
    logger.error(f"{'='*60}")
    logger.error(f"EXCEPCIÓN CAPTURADA: {context}")
    logger.error(f"Tipo: {type(exception).__name__}")
    logger.error(f"Mensaje: {str(exception)}")
    logger.error(f"Traceback:")
    logger.error(traceback.format_exc())
    logger.error(f"{'='*60}")


class LoggerPrintRedirect:
    """Redirige print() a logger (para ejecutable)"""
    
    def __init__(self, logger, level=logging.INFO):
        self.logger = logger
        self.level = level
        
    def write(self, message):
        if message.strip():  # Ignorar líneas vacías
            self.logger.log(self.level, message.strip())
    
    def flush(self):
        pass


def redirect_prints_to_logger(logger):
    """
    Redirige todos los print() al logger (útil con console=False)
    
    Args:
        logger: Logger configurado
    """
    if getattr(sys, 'frozen', False):
        sys.stdout = LoggerPrintRedirect(logger, logging.INFO)
        sys.stderr = LoggerPrintRedirect(logger, logging.ERROR)