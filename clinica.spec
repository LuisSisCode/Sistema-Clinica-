"""
Configuración SEGURA de PyInstaller para Sistema Clínica
- Archivos QML empaquetados internamente
- Scripts SQL protegidos
- Icono en todas las ventanas
"""

import sys
import os
from pathlib import Path

# Directorio base
project_dir = Path('.').resolve()

# ============================================
# 1. ARCHIVOS QML (EMPAQUETADOS INTERNAMENTE)
# ============================================
qml_files = [
    'main.qml', 'login.qml', 'setup_wizard.qml', 'Dashboard.qml',
    'Compras.qml', 'CrearCompra.qml', 'ComprasMain.qml',
    'Ventas.qml', 'CrearVenta.qml', 'VentasMain.qml',
    'Proveedores.qml', 'CrearProveedor.qml',
    'Productos.qml', 'CrearProducto.qml', 'DetalleProducto.qml',
    'Farmacia.qml', 'Consultas.qml', 'Laboratorio.qml', 'Enfermeria.qml',
    'ServiciosBasicos.qml', 'Trabajadores.qml', 'Usuario.qml',
    'Configuracion.qml', 'ConfiConsultas.qml', 'ConfiEnfermeria.qml',
    'ConfiLaboratorio.qml', 'ConfiServiciosBasicos.qml', 
    'ConfiTrabajadores.qml', 'ConfiUsuarios.qml',
    'Reportes.qml', 'CierreCaja.qml', 'IngresosExtras.qml',
    'MarcaComboBox.qml', 'ProveedorComboBox.qml', 'GlobalDataCenter.qml',
]

# Empaquetar QML en _internal (no visible directamente)
datas_qml = [(str(project_dir / qml), '_internal/qml') for qml in qml_files 
             if (project_dir / qml).exists()]

print(f"✅ {len(datas_qml)} archivos QML empaquetados en _internal/qml")

# ============================================
# 2. SCRIPTS SQL (PROTEGIDOS)
# ============================================
datas_db_scripts = []
db_scripts_dir = project_dir / 'database_scripts'
if db_scripts_dir.exists():
    # Empaquetar en _internal (no visible)
    datas_db_scripts.append((str(db_scripts_dir), '_internal/database_scripts'))
    print(f"✅ Scripts SQL empaquetados en _internal/database_scripts")

# ============================================
# 3. RECURSOS (ICONOS - NECESARIOS)
# ============================================
datas_resources = []
resources_dir = project_dir / 'Resources'
if resources_dir.exists():
    # Iconos sí deben estar visibles para Qt
    datas_resources.append((str(resources_dir), 'Resources'))
    print(f"✅ Recursos incluidos")

# ============================================
# 4. DOCUMENTACIÓN PARA USUARIO
# ============================================
datas_docs = []
readme = project_dir / 'README.md'
if readme.exists():
    datas_docs.append((str(readme), '.'))

# ============================================
# 5. COMBINAR DATOS
# ============================================
all_datas = datas_qml + datas_db_scripts + datas_resources + datas_docs

# ============================================
# 6. MÓDULOS OCULTOS
# ============================================
hiddenimports = [
    # PySide6
    'PySide6.QtCore', 'PySide6.QtGui', 'PySide6.QtQml',
    'PySide6.QtQuick', 'PySide6.QtQuickControls2', 'PySide6.QtWidgets',
    
    # Backend
    'backend', 'backend.core', 'backend.core.config',
    'backend.core.database_conexion', 'backend.core.cache_system',
    'backend.core.excepciones', 'backend.core.base_repository',
    'backend.core.utils', 'backend.core.db_installer',
    'backend.core.config_manager',
    
    # Models
    'backend.models', 'backend.models.auth_model',
    'backend.models.usuario_model', 'backend.models.paciente_model',
    'backend.models.trabajador_model', 'backend.models.consulta_model',
    'backend.models.enfermeria_model', 'backend.models.laboratorio_model',
    'backend.models.inventario_model', 'backend.models.proveedor_model',
    'backend.models.compra_model', 'backend.models.venta_model',
    'backend.models.gasto_model', 'backend.models.cierre_caja_model',
    'backend.models.ingreso_extra_model', 'backend.models.reportes_model',
    'backend.models.dashboard_model',
    
    # Configuración Models
    'backend.models.ConfiguracionModel',
    'backend.models.ConfiguracionModel.ConfiConsulta_model',
    'backend.models.ConfiguracionModel.ConfiEnfermeria_model',
    'backend.models.ConfiguracionModel.ConfiLaboratorio_model',
    'backend.models.ConfiguracionModel.ConfiServiciosbasicos_model',
    'backend.models.ConfiguracionModel.ConfiTrabajadores_model',
    
    # Repositories
    'backend.repositories', 'backend.repositories.auth_repository',
    'backend.repositories.usuario_repository', 'backend.repositories.paciente_repository',
    'backend.repositories.trabajador_repository', 'backend.repositories.consulta_repository',
    'backend.repositories.enfermeria_repository', 'backend.repositories.laboratorio_repository',
    'backend.repositories.producto_repository', 'backend.repositories.proveedor_repository',
    'backend.repositories.compra_repository', 'backend.repositories.venta_repository',
    'backend.repositories.gasto_repository', 'backend.repositories.cierre_caja_repository',
    'backend.repositories.ingreso_extra_repository', 'backend.repositories.reportes_repository',
    
    # Configuración Repositories
    'backend.repositories.ConfiguracionRepositor',
    'backend.repositories.ConfiguracionRepositor.ConfiConsulta_repository',
    'backend.repositories.ConfiguracionRepositor.ConfiEnfermeria_repository',
    'backend.repositories.ConfiguracionRepositor.ConfiLaboratorio_repository',
    'backend.repositories.ConfiguracionRepositor.ConfiServiciosbasicos_repository',
    'backend.repositories.ConfiguracionRepositor.ConfiTrabajadores_repository',
    
    # Dependencias
    'pyodbc', 'reportlab', 'reportlab.pdfgen', 'reportlab.pdfgen.canvas',
    'reportlab.lib', 'reportlab.lib.pagesizes', 'reportlab.lib.styles',
    'reportlab.lib.colors', 'reportlab.lib.units',
    'reportlab.platypus', 'reportlab.platypus.paragraph',
    'reportlab.platypus.tables', 'reportlab.platypus.frames',
    'dotenv', 'pathlib', 'PIL', 'PIL.Image',
]

# ============================================
# 7. ANÁLISIS
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
    excludes=['matplotlib', 'numpy', 'pandas', 'scipy', 'IPython',
              'jupyter', 'notebook', 'pytest', 'setuptools', 'pip',
              'wheel', 'tkinter', 'unittest'],
    noarchive=False,
    optimize=0,
)

pyz = PYZ(a.pure, a.zipped_data)

# ============================================
# 8. EJECUTABLE CON ICONO
# ============================================
# Buscar icono
icon_path = None
possible_icons = [
    'Resources/iconos/logo_CMI.ico',
    'Resources/iconos/Logo_de_Emergencia_Médica_RGL-removebg-preview.ico',
]

for icon in possible_icons:
    if os.path.exists(icon):
        icon_path = icon
        print(f"✅ Icono encontrado: {icon}")
        break

if not icon_path:
    print("⚠️ No se encontró icono, ejecutable sin icono")

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
    icon=icon_path,  # Icono del ejecutable
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

print("\n" + "="*60)
print("✅ CONFIGURACIÓN DE SEGURIDAD APLICADA")
print("="*60)
print(f"🔒 Archivos QML: Empaquetados en _internal/qml")
print(f"🔒 Scripts SQL: Empaquetados en _internal/database_scripts")
print(f"📦 Icono: {icon_path if icon_path else 'No configurado'}")
print(f"📊 Total archivos: {len(all_datas)}")
print("="*60 + "\n")