# -*- mode: python ; coding: utf-8 -*-
"""
Configuración de PyInstaller para Sistema Clínica María Inmaculada
Genera un ejecutable standalone con todos los recursos necesarios
ACTUALIZADO: Incluye Setup Wizard y sistema de primera configuración
"""

import sys
import os
from pathlib import Path

# Directorio base del proyecto
project_dir = Path('.').resolve()

# ============================================
# 1. ARCHIVOS QML (Interfaz gráfica)
# ============================================
qml_files = [
    # Archivos principales
    'main.qml',
    'login.qml',
    'setup_wizard.qml',  # ✅ NUEVO - Wizard de configuración inicial
    'Dashboard.qml',
    
    # Módulos principales
    'Compras.qml',
    'CrearCompra.qml',
    'ComprasMain.qml',
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
    'Usuario.qml',
    
    # Configuración
    'Configuracion.qml',
    'ConfiConsultas.qml',
    'ConfiEnfermeria.qml',
    'ConfiLaboratorio.qml',
    'ConfiServiciosBasicos.qml',
    'ConfiTrabajadores.qml',
    'ConfiUsuarios.qml',
    
    # Otros módulos
    'Reportes.qml',
    'CierreCaja.qml',
    'IngresosExtras.qml',
    'GlobalDataCenter.qml',
    
    # Componentes reutilizables
    'MarcaComboBox.qml',
    'ProveedorComboBox.qml',
]

# Convertir a tuplas (source, destino) para PyInstaller
datas_qml = []
for qml in qml_files:
    qml_path = project_dir / qml
    if qml_path.exists():
        datas_qml.append((str(qml_path), '.'))
        print(f"✅ QML encontrado: {qml}")
    else:
        print(f"⚠️ QML no encontrado: {qml}")

# ============================================
# 2. SCRIPTS DE BASE DE DATOS (CRÍTICO)
# ============================================
datas_db_scripts = []
db_scripts_dir = project_dir / 'database_scripts'
if db_scripts_dir.exists():
    # Incluir TODOS los archivos .sql
    for script in db_scripts_dir.glob('*.sql'):
        datas_db_scripts.append((str(script), 'database_scripts'))
        print(f"✅ Script SQL: {script.name}")
    
    # También incluir la carpeta completa como respaldo
    datas_db_scripts.append((str(db_scripts_dir), 'database_scripts'))
else:
    print("⚠️ ADVERTENCIA: Carpeta database_scripts no encontrada")

# ============================================
# 3. RECURSOS (Iconos, fuentes, imágenes)
# ============================================
datas_resources = []
resources_dir = project_dir / 'Resources'
if resources_dir.exists():
    datas_resources.append((str(resources_dir), 'Resources'))
    print(f"✅ Recursos incluidos: {resources_dir}")
else:
    print("⚠️ Carpeta Resources no encontrada")

# Assets adicionales
assets_dir = project_dir / 'assets'
if assets_dir.exists():
    datas_resources.append((str(assets_dir), 'assets'))
    print(f"✅ Assets incluidos: {assets_dir}")

# ============================================
# 4. ARCHIVOS DE CONFIGURACIÓN
# ============================================
datas_config = []

# Config template
config_template = project_dir / 'config_template.txt'
if config_template.exists():
    datas_config.append((str(config_template), '.'))

# README y documentación
readme = project_dir / 'README.md'
if readme.exists():
    datas_config.append((str(readme), '.'))

# ============================================
# 5. COMBINAR TODOS LOS DATOS
# ============================================
all_datas = datas_qml + datas_db_scripts + datas_resources + datas_config

print(f"\n📊 Total de archivos incluidos: {len(all_datas)}")

# ============================================
# 6. MÓDULOS OCULTOS (Hidden Imports)
# ============================================
hiddenimports = [
    # ===== PYSIDE6 =====
    'PySide6.QtCore',
    'PySide6.QtGui',
    'PySide6.QtQml',
    'PySide6.QtQuick',
    'PySide6.QtQuickControls2',
    'PySide6.QtWidgets',
    
    # ===== BACKEND CORE =====
    'backend',
    'backend.core',
    'backend.core.config',
    'backend.core.database_conexion',
    'backend.core.cache_system',
    'backend.core.excepciones',
    'backend.core.base_repository',
    'backend.core.utils',
    'backend.core.db_installer',        # ✅ NUEVO - Instalador de BD
    'backend.core.config_manager',      # ✅ NUEVO - Gestor de configuración
    
    # ===== MODELS =====
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
    
    # ===== CONFIGURACIÓN MODELS =====
    'backend.models.ConfiguracionModel',
    'backend.models.ConfiguracionModel.ConfiConsulta_model',
    'backend.models.ConfiguracionModel.ConfiEnfermeria_model',
    'backend.models.ConfiguracionModel.ConfiLaboratorio_model',
    'backend.models.ConfiguracionModel.ConfiServiciosbasicos_model',
    'backend.models.ConfiguracionModel.ConfiTrabajadores_model',
    
    # ===== REPOSITORIES =====
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
    
    # ===== CONFIGURACIÓN REPOSITORIES =====
    'backend.repositories.ConfiguracionRepositor',
    'backend.repositories.ConfiguracionRepositor.ConfiConsulta_repository',
    'backend.repositories.ConfiguracionRepositor.ConfiEnfermeria_repository',
    'backend.repositories.ConfiguracionRepositor.ConfiLaboratorio_repository',
    'backend.repositories.ConfiguracionRepositor.ConfiServiciosbasicos_repository',
    'backend.repositories.ConfiguracionRepositor.ConfiTrabajadores_repository',
    
    # ===== DEPENDENCIAS EXTERNAS =====
    'pyodbc',
    'reportlab',
    'reportlab.pdfgen',
    'reportlab.pdfgen.canvas',
    'reportlab.lib',
    'reportlab.lib.pagesizes',
    'reportlab.lib.styles',
    'reportlab.lib.colors',
    'reportlab.lib.units',
    'reportlab.platypus',
    'reportlab.platypus.paragraph',
    'reportlab.platypus.tables',
    'reportlab.platypus.frames',
    'dotenv',
    'pathlib',
    'PIL',
    'PIL.Image',
    
    # ===== PYTHON STDLIB =====
    'datetime',
    'decimal',
    'json',
    'os',
    'sys',
    'typing',
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
        # Excluir paquetes innecesarios para reducir tamaño
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
        'tkinter',
        'unittest',
    ],
    noarchive=False,
    optimize=0,
)

# ============================================
# 8. EMPAQUETADO
# ============================================
pyz = PYZ(a.pure, a.zipped_data)

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
    console=True,  # ✅ True para debug - cambiar a False en producción
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
    icon='Resources/iconos/Logo_de_Emergencia_Médica_RGL-removebg-preview.ico' if os.path.exists('Resources/iconos/Logo_de_Emergencia_Médica_RGL-removebg-preview.ico') else None,
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
print("✅ SPEC FILE CONFIGURADO EXITOSAMENTE")
print("="*60)
print(f"📦 Archivos incluidos: {len(all_datas)}")
print(f"🔧 Módulos ocultos: {len(hiddenimports)}")
print(f"📁 Ejecutable: dist/ClinicaApp/ClinicaApp.exe")
print("="*60 + "\n")