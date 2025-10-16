"""
Configuración CORREGIDA - Archivos QML y SQL en RAÍZ
"""

import sys
import os
from pathlib import Path
from PyInstaller.building.build_main import Analysis, EXE, COLLECT, PYZ

# Directorio base
project_dir = Path('.').resolve()

print("="*60)
print("🔨 CONFIGURACIÓN DE PYINSTALLER - VERSIÓN CORREGIDA")
print("="*60)

# ============================================
# 1. ARCHIVOS QML (EN RAÍZ - CORREGIDO)
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

datas_qml = []
for qml_file in qml_files:
    full_path = project_dir / qml_file
    if full_path.exists():
        # ✅ CORRECCIÓN CRÍTICA: Incluir archivo individualmente
        datas_qml.append((str(full_path), '.'))
        print(f"✅ QML incluido: {qml_file}")
    else:
        print(f"⚠️ QML no encontrado: {qml_file}")

print(f"📦 Total archivos QML: {len(datas_qml)}")

# ============================================
# 2. SCRIPTS SQL (EN database_scripts/ - CORREGIDO)
# ============================================
datas_db_scripts = []
db_scripts_dir = project_dir / 'database_scripts'
if db_scripts_dir.exists():
    for sql_file in db_scripts_dir.glob('*.sql'):
        # ✅ CORRECCIÓN CRÍTICA: Incluir archivos SQL individualmente
        datas_db_scripts.append((str(sql_file), 'database_scripts'))
        print(f"✅ SQL incluido: {sql_file.name}")
    print(f"📦 Total archivos SQL: {len(datas_db_scripts)}")
else:
    print("❌ ERROR: Carpeta database_scripts no encontrada")

# ============================================
# 3. RECURSOS (ICONOS)
# ============================================
datas_resources = []
resources_dir = project_dir / 'Resources'
if resources_dir.exists():
    # ✅ Incluir carpeta Resources completa
    datas_resources.append((str(resources_dir), 'Resources'))
    print("✅ Carpeta Resources incluida")
else:
    print("⚠️ Carpeta Resources no encontrada")

# ============================================
# 4. ARCHIVOS ADICIONALES (MODIFICADO)
# ============================================
datas_additional = []
additional_files = [
    'generar_pdf.py', 
    'setup_handler.py',
    'logger_config.py',        # ✅ AGREGADO
    'resource_validator.py',   # ✅ AGREGADO
    'README.md', 
    'LEEME.txt'
]

for file in additional_files:
    full_path = project_dir / file
    if full_path.exists():
        datas_additional.append((str(full_path), '.'))
        print(f"✅ Archivo adicional: {file}")
    else:
        print(f"⚠️ Archivo adicional no encontrado: {file}")

# ============================================
# 5. COMBINAR TODOS LOS DATOS
# ============================================
all_datas = datas_qml + datas_db_scripts + datas_resources + datas_additional
print(f"📊 TOTAL ARCHIVOS A INCLUIR: {len(all_datas)}")

# ============================================
# 6. MÓDULOS OCULTOS (MODIFICADO)
# ============================================
hiddenimports = [
    'PySide6.QtCore', 'PySide6.QtGui', 'PySide6.QtQml',
    'PySide6.QtQuick', 'PySide6.QtQuickControls2', 'PySide6.QtWidgets',
    
    # Backend
    'backend', 'backend.core', 'backend.core.config',
    'backend.core.database_conexion', 'backend.core.cache_system',
    'backend.core.excepciones', 'backend.core.base_repository',
    'backend.core.utils', 'backend.core.db_installer',
    'backend.core.config_manager',
    
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
    
    # Dependencias
    'pyodbc', 
    'reportlab', 'reportlab.pdfgen', 'reportlab.pdfgen.canvas',
    'reportlab.lib', 'reportlab.lib.pagesizes', 'reportlab.lib.styles',
    'reportlab.lib.colors', 'reportlab.lib.units',
    'reportlab.platypus', 'reportlab.platypus.paragraph',
    'reportlab.platypus.tables', 'reportlab.platypus.frames',
    'dotenv', 
    'pathlib', 
    'PIL', 'PIL.Image',
    
    # ✅ AGREGADOS AL FINAL:
    'logger_config',
    'resource_validator',
]

print("✅ Módulos ocultos configurados")

# ============================================
# 7. ANÁLISIS PRINCIPAL
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
    print("⚠️ No se encontró icono")

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
    console=False,  # ✅ SIN CONSOLA
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
    icon=icon_path,
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

print("="*60)
print("🎯 CONFIGURACIÓN COMPLETADA - LISTO PARA COMPILAR")
print("="*60)