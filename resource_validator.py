# resource_validator.py
"""
Validador de Recursos para Ejecutable
Verifica que todos los archivos necesarios existan
"""

import sys
import os
from pathlib import Path
from typing import Tuple, List
from PySide6.QtWidgets import QMessageBox

def get_base_path():
    """Obtiene el directorio base (ejecutable o desarrollo)"""
    if getattr(sys, 'frozen', False):
        return Path(sys._MEIPASS)
    else:
        return Path(__file__).parent


def get_resource_path(relative_path: str, logger=None) -> str:
    """
    ✅ VERSIÓN MEJORADA: Obtiene ruta de recurso con validación
    
    Args:
        relative_path: Ruta relativa del archivo
        logger: Logger opcional para debugging
        
    Returns:
        str: Ruta absoluta del recurso
        
    Raises:
        FileNotFoundError: Si el archivo no existe
    """
    base_path = get_base_path()
    
    # Rutas posibles en orden de prioridad
    possible_paths = [
        base_path / relative_path,                          # _MEIPASS/archivo
        base_path / '_internal' / relative_path,            # Legacy
        Path(sys.executable).parent / relative_path,        # Junto al .exe
    ]
    
    # Log de búsqueda
    if logger:
        logger.debug(f"Buscando recurso: {relative_path}")
        logger.debug(f"Base path: {base_path}")
    
    # Buscar en cada ruta
    for i, path in enumerate(possible_paths, 1):
        if logger:
            logger.debug(f"  Intento {i}: {path}")
        
        if path.exists():
            if logger:
                logger.info(f"✅ Recurso encontrado: {path}")
            return str(path)
    
    # Si no encuentra, lanzar excepción detallada
    error_msg = f"Recurso no encontrado: {relative_path}\n"
    error_msg += f"Rutas verificadas:\n"
    for i, path in enumerate(possible_paths, 1):
        error_msg += f"  {i}. {path} {'✓' if path.exists() else '✗'}\n"
    
    if logger:
        logger.error(error_msg)
    
    raise FileNotFoundError(error_msg)


def validate_qml_files(logger=None) -> Tuple[bool, List[str]]:
    """
    Valida que todos los archivos QML necesarios existan
    
    Returns:
        Tuple[bool, List[str]]: (éxito, lista de archivos faltantes)
    """
    required_qml = [
        'login.qml',
        'setup_wizard.qml',
        'main.qml',
        'Dashboard.qml',
    ]
    
    missing_files = []
    
    for qml_file in required_qml:
        try:
            get_resource_path(qml_file, logger)
        except FileNotFoundError:
            missing_files.append(qml_file)
    
    if missing_files:
        if logger:
            logger.error(f"❌ Archivos QML faltantes: {missing_files}")
        return False, missing_files
    
    if logger:
        logger.info(f"✅ Todos los archivos QML necesarios encontrados")
    
    return True, []


def validate_sql_scripts(logger=None) -> Tuple[bool, List[str]]:
    """
    Valida que los scripts SQL existan
    
    Returns:
        Tuple[bool, List[str]]: (éxito, lista de archivos faltantes)
    """
    required_sql = [
        'database_scripts/01_schema.sql',
        'database_scripts/02_datos_iniciales.sql',
    ]
    
    missing_files = []
    
    for sql_file in required_sql:
        try:
            get_resource_path(sql_file, logger)
        except FileNotFoundError:
            missing_files.append(sql_file)
    
    if missing_files:
        if logger:
            logger.error(f"❌ Scripts SQL faltantes: {missing_files}")
        return False, missing_files
    
    if logger:
        logger.info(f"✅ Scripts SQL encontrados")
    
    return True, []


def validate_all_resources(logger=None) -> Tuple[bool, str]:
    """
    Validación completa de todos los recursos necesarios
    
    Returns:
        Tuple[bool, str]: (éxito, mensaje de error si falla)
    """
    if logger:
        logger.info("🔍 Validando recursos del ejecutable...")
    
    # 1. Validar QML
    qml_ok, missing_qml = validate_qml_files(logger)
    if not qml_ok:
        error = f"Archivos QML faltantes:\n" + "\n".join(f"  • {f}" for f in missing_qml)
        return False, error
    
    # 2. Validar SQL
    sql_ok, missing_sql = validate_sql_scripts(logger)
    if not sql_ok:
        error = f"Scripts SQL faltantes:\n" + "\n".join(f"  • {f}" for f in missing_sql)
        # SQL no es crítico para mostrar UI, solo advertencia
        if logger:
            logger.warning(f"⚠️ {error}")
    
    if logger:
        logger.info("✅ Validación de recursos completada")
    
    return True, ""


def show_error_message(title: str, message: str, details: str = ""):
    """
    Muestra un cuadro de diálogo de error (funciona con console=False)
    
    Args:
        title: Título del mensaje
        message: Mensaje principal
        details: Detalles técnicos (opcional)
    """
    try:
        from PySide6.QtWidgets import QApplication, QMessageBox
        
        # Crear QApplication temporal si no existe
        app = QApplication.instance()
        if app is None:
            app = QApplication(sys.argv)
        
        # Crear mensaje de error
        msg_box = QMessageBox()
        msg_box.setIcon(QMessageBox.Critical)
        msg_box.setWindowTitle(title)
        msg_box.setText(message)
        
        if details:
            msg_box.setDetailedText(details)
        
        msg_box.setStandardButtons(QMessageBox.Ok)
        msg_box.exec()
        
    except Exception as e:
        # Fallback: escribir a archivo
        error_file = Path(sys.executable).parent / 'ERROR.txt' if getattr(sys, 'frozen', False) else Path('ERROR.txt')
        with open(error_file, 'w', encoding='utf-8') as f:
            f.write(f"{title}\n")
            f.write(f"{'='*60}\n")
            f.write(f"{message}\n\n")
            if details:
                f.write(f"Detalles:\n{details}\n")


def list_available_files(logger=None):
    """
    Lista todos los archivos disponibles (útil para debugging)
    """
    base_path = get_base_path()
    
    if logger:
        logger.info(f"📂 Archivos disponibles en: {base_path}")
    
    try:
        for item in sorted(base_path.iterdir())[:30]:  # Primeros 30
            if logger:
                logger.info(f"  {'📁' if item.is_dir() else '📄'} {item.name}")
    except Exception as e:
        if logger:
            logger.error(f"Error listando archivos: {e}")