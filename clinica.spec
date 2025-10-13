# -*- mode: python ; coding: utf-8 -*-
"""
Configuración de PyInstaller para Sistema Clínica
Genera un ejecutable standalone con todos los recursos necesarios
"""

import sys
from pathlib import Path

# Directorio base del proyecto
project_dir = Path('.').resolve()

# ============================================
# 1. ARCHIVOS QML (Interfaz gráfica)
# ============================================
qml_files = [
    'main.qml',
    'login.qml',
    'Dashboard.qml',
    'Compras.qml',
    'CrearCompra.qml',
    'CompraMain.qml',
    'Ventas.qml',
    'CrearVenta.qml',
    'VentasMain.qml',
    'Proveedores.qml',
    'CrearProveedor.qml',
    'Productos.qml',
    'CrearProducto.qml',
    'DetalleProducto.qml',
    'Farmacia.qml',
    'Consultas.qml',
    'Laboratorio.qml',
    'Enfermeria.qml',
    'ServiciosBasicos.qml',
    'Trabajadores.qml',
    'GlobalDataCenter.qml',
    'Usuario.qml',
    'Configuracion.qml',
    'ConfiConsultas.qml',
    'ConfiEnfermeria.qml',
    'ConfiLaboratorio.qml',
    'ConfiServiciosBasicos.qml',
    'ConfiTrabajadores.qml',
    'ConfiUsuarios.qml',
    'Reportes.qml',
    'CierreCaja.qml',
    'IngresosExtras.qml',
    'MarcaComboBox.qml',
    'ProveedorComboBox.qml',
]

# Convertir a tuplas (source, destino) para PyInstaller
datas_qml = [(str(project_dir / qml), '.') for qml in qml_files if (project_dir / qml).exists()]

# ============================================
# 2. RECURSOS (Iconos, fuentes, etc)
# ============================================
datas_resources = []
resources_dir = project_dir / 'Resources'
if resources_dir.exists():
    datas_resources.append((str(resources_dir), 'Resources'))

# ============================================
# 3. SCRIPTS DE BASE DE DATOS
# ============================================
datas_db_scripts = []
db_scripts_dir = project_dir / 'database_scripts'
if db_scripts_dir.exists():
    for script in db_scripts_dir.glob('*.sql'):
        datas_db_scripts.append((str(script), 'database_scripts'))

# ============================================
# 4. ARCHIVOS DE CONFIGURACIÓN
# ============================================
datas_config = []
config_template = project_dir / 'config_template.txt'
if config_template.exists():
    datas_config.append((str(config_template), '.'))

# ============================================
# 5. COMBINAR TODOS LOS DATOS
# ============================================
all_datas = datas_qml + datas_resources + datas_db_scripts + datas_config

# ============================================
# 6. MÓDULOS OCULTOS (Hidden Imports)
# ============================================
hiddenimports = [
    # PySide6 core
    'PySide6.QtCore',
    'PySide6.QtGui',
    'PySide6.QtQml',
    'PySide6.QtQuick',
    'PySide6.QtWidgets',
    
    # Backend modules
    'backend.core',
    'backend.core.config',
    'backend.core.database_conexion',
    'backend.core.cache_system',
    'backend.core.excepciones',
    'backend.core.base_repository',
    'backend.core.utils',
    
    # Models
    'backend.models',
    'backend.models.auth_model',
    'backend.models.usuario_model',
    'backend.models.paciente_model',
    'backend.models.trabajador_model',
    'backend.models.consulta_model',
    'backend.models.enfermeria_model',
    'backend.models.laboratorio_model',
    'backend.models.inventario_model',
    'backend.models.proveedor_model',
    'backend.models.compra_model',
    'backend.models.venta_model',
    'backend.models.gasto_model',
    'backend.models.cierre_caja_model',
    'backend.models.ingreso_extra_model',
    'backend.models.reportes_model',
    'backend.models.dashboard_model',
    
    # Configuración Models
    'backend.models.ConfiguracionModel',
    'backend.models.ConfiguracionModel.ConfiConsulta_model',
    'backend.models.ConfiguracionModel.ConfiEnfermeria_model',
    'backend.models.ConfiguracionModel.ConfiLaboratorio_model',
    'backend.models.ConfiguracionModel.ConfiServiciosbasicos_model',
    'backend.models.ConfiguracionModel.ConfiTrabajadores_model',
    
    # Repositories
    'backend.repositories',
    'backend.repositories.auth_repository',
    'backend.repositories.usuario_repository',
    'backend.repositories.paciente_repository',
    'backend.repositories.trabajador_repository',
    'backend.repositories.consulta_repository',
    'backend.repositories.enfermeria_repository',
    'backend.repositories.laboratorio_repository',
    'backend.repositories.producto_repository',
    'backend.repositories.proveedor_repository',
    'backend.repositories.compra_repository',
    'backend.repositories.venta_repository',
    'backend.repositories.gasto_repository',
    'backend.repositories.cierre_caja_repository',
    'backend.repositories.ingreso_extra_repository',
    'backend.repositories.reportes_repository',
    
    # Configuración Repositories
    'backend.repositories.ConfiguracionRepositor',
    'backend.repositories.ConfiguracionRepositor.ConfiConsulta_repository',
    'backend.repositories.ConfiguracionRepositor.ConfiEnfermeria_repository',
    'backend.repositories.ConfiguracionRepositor.ConfiLaboratorio_repository',
    'backend.repositories.ConfiguracionRepositor.ConfiServiciosbasicos_repository',
    'backend.repositories.ConfiguracionRepositor.ConfiTrabajadores_repository',
    
    # Otras dependencias
    'pyodbc',
    'reportlab',
    'reportlab.pdfgen',
    'reportlab.lib',
    'reportlab.platypus',
    'dotenv',
    'pathlib',
]

# ============================================
# 7. ANÁLISIS DE LA APLICACIÓN
# ============================================
a = Analysis(
    ['main.py'],
    pathex=[str(project_dir)],
    binaries=[],
    datas=all_datas,
    hiddenimports=hiddenimports,
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[
        'matplotlib',
        'numpy',
        'pandas',
        'scipy',
        'IPython',
        'jupyter',
        'notebook',
        'pytest',
        'setuptools',
        'pip',
        'wheel',
    ],
    noarchive=False,
)

# ============================================
# 8. EMPAQUETADO
# ============================================
pyz = PYZ(a.pure)

exe = EXE(
    pyz,
    a.scripts,
    [],
    exclude_binaries=True,
    name='ClinicaApp',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,
    console=False,  # Sin consola (app gráfica)
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
    icon='Resources/iconos/Logo_de_Emergencia_Médica_RGL-removebg-preview.ico',
)

coll = COLLECT(
    exe,
    a.binaries,
    a.datas,
    strip=False,
    upx=True,
    upx_exclude=[],
    name='ClinicaApp',
)