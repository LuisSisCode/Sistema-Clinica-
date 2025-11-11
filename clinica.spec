"""
═══════════════════════════════════════════════════════════════
CONFIGURACIÓN PYINSTALLER - Sistema Clínica María Inmaculada
Versión 1.0 - Actualizado con arquitectura completa
═══════════════════════════════════════════════════════════════
"""

import sys
import os
from pathlib import Path
from PyInstaller.building.build_main import Analysis, EXE, COLLECT, PYZ

# ═══════════════════════════════════════════════════════════════
# CONFIGURACIÓN INICIAL
# ═══════════════════════════════════════════════════════════════
project_dir = Path('.').resolve()

print("=" * 70)
print("🏥 SISTEMA CLÍNICA MARÍA INMACULADA - BUILD v1.0")
print("=" * 70)
print(f"📁 Directorio del proyecto: {project_dir}")
print("=" * 70)

# ═══════════════════════════════════════════════════════════════
# 1. ARCHIVOS QML (INTERFAZ DE USUARIO)
# ═══════════════════════════════════════════════════════════════
print("\n📋 RECOPILANDO ARCHIVOS QML...")

qml_files = [
    # Core / Principal
    'main.qml',
    'login.qml',
    'setup_wizard.qml',
    'Dashboard.qml',
    
    # Módulo de Compras
    'Compras.qml',
    'CrearCompra.qml',
    'ComprasMain.qml',
    
    # Módulo de Ventas
    'Ventas.qml',
    'CrearVenta.qml',
    'VentasMain.qml',
    
    # Módulo de Proveedores
    'Proveedores.qml',
    'CrearProveedor.qml',
    
    # Módulo de Productos/Inventario
    'Productos.qml',
    'CrearProducto.qml',
    'DetalleProducto.qml',
    
    # Módulos Clínicos
    'Farmacia.qml',
    'Consultas.qml',
    'Laboratorio.qml',
    'Enfermeria.qml',
    
    # Módulo de Trabajadores
    'Trabajadores.qml',
    'ConfiTrabajadores.qml',
    
    # Módulo de Usuarios
    'Usuario.qml',
    'ConfiUsuarios.qml',
    
    # Módulos de Configuración
    'Configuracion.qml',
    'ConfiConsultas.qml',
    'ConfiEnfermeria.qml',
    'ConfiLaboratorio.qml',
    'ConfiServiciosBasicos.qml',
    
    # Módulos Financieros
    'ServiciosBasicos.qml',
    'Reportes.qml',
    'CierreCaja.qml',
    'IngresosExtras.qml',
    'Gastos.qml',
    'Egresos.qml',
    
    # Componentes Reutilizables
    'MarcaComboBox.qml',
    'ProveedorComboBox.qml',
    'GlobalDataCenter.qml',
]

datas_qml = []
qml_found = 0
qml_missing = 0

for qml_file in qml_files:
    full_path = project_dir / qml_file
    if full_path.exists():
        datas_qml.append((str(full_path), '.'))
        qml_found += 1
        print(f"  ✅ {qml_file}")
    else:
        qml_missing += 1
        print(f"  ⚠️  {qml_file} (no encontrado)")

print(f"\n📊 Archivos QML: {qml_found} encontrados, {qml_missing} faltantes")

# ═══════════════════════════════════════════════════════════════
# 2. SCRIPTS DE BASE DE DATOS
# ═══════════════════════════════════════════════════════════════
print("\n💾 RECOPILANDO SCRIPTS SQL...")

datas_db_scripts = []
db_scripts_dir = project_dir / 'database_scripts'

if db_scripts_dir.exists():
    sql_files = list(db_scripts_dir.glob('*.sql'))
    for sql_file in sql_files:
        datas_db_scripts.append((str(sql_file), 'database_scripts'))
        print(f"  ✅ {sql_file.name}")
    print(f"\n📊 Scripts SQL: {len(sql_files)} archivos")
else:
    print("  ❌ ERROR: Carpeta 'database_scripts' no encontrada")
    print("  💡 Asegúrate de que exista la carpeta con los archivos SQL")

# ═══════════════════════════════════════════════════════════════
# 3. RECURSOS (ICONOS, IMÁGENES, ETC.)
# ═══════════════════════════════════════════════════════════════
print("\n🎨 RECOPILANDO RECURSOS...")

datas_resources = []
resources_dir = project_dir / 'Resources'

if resources_dir.exists():
    # Incluir toda la carpeta Resources recursivamente
    datas_resources.append((str(resources_dir), 'Resources'))
    
    # Contar archivos dentro de Resources
    resource_count = sum(1 for _ in resources_dir.rglob('*') if _.is_file())
    print(f"  ✅ Carpeta Resources incluida ({resource_count} archivos)")
else:
    print("  ⚠️  Carpeta 'Resources' no encontrada")

# ═══════════════════════════════════════════════════════════════
# 4. ARCHIVOS ADICIONALES
# ═══════════════════════════════════════════════════════════════
print("\n📄 RECOPILANDO ARCHIVOS ADICIONALES...")

datas_additional = []
additional_files = [
    'generar_pdf.py',
    'setup_handler.py',
    'logger_config.py',
    'resource_validator.py',
    'README.md',
    'LEEME.txt',
    'LICENSE.txt',
]

for file in additional_files:
    full_path = project_dir / file
    if full_path.exists():
        datas_additional.append((str(full_path), '.'))
        print(f"  ✅ {file}")
    else:
        print(f"  ⚠️  {file} (opcional)")

# ═══════════════════════════════════════════════════════════════
# 5. COMBINAR TODOS LOS DATOS
# ═══════════════════════════════════════════════════════════════
all_datas = datas_qml + datas_db_scripts + datas_resources + datas_additional

print("\n" + "=" * 70)
print(f"📦 TOTAL ARCHIVOS A INCLUIR: {len(all_datas)}")
print("=" * 70)

# ═══════════════════════════════════════════════════════════════
# 6. MÓDULOS OCULTOS (HIDDEN IMPORTS)
# ═══════════════════════════════════════════════════════════════
print("\n🔧 CONFIGURANDO MÓDULOS OCULTOS...")

hiddenimports = [
    # ========== PySide6 (Framework Qt) ==========
    'PySide6.QtCore',
    'PySide6.QtGui',
    'PySide6.QtQml',
    'PySide6.QtQuick',
    'PySide6.QtQuickControls2',
    'PySide6.QtWidgets',
    'PySide6.QtSql',
    'PySide6.QtNetwork',
    'PySide6.QtPrintSupport',
    
    # ========== Backend Core ==========
    'backend',
    'backend.core',
    'backend.core.config',
    'backend.core.database_conexion',
    'backend.core.cache_system',
    'backend.core.excepciones',
    'backend.core.base_repository',
    'backend.core.utils',
    'backend.core.db_installer',
    'backend.core.config_manager',
    
    # ========== Backend Models ==========
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
    
    # ========== Backend Models - Configuración ==========
    'backend.models.ConfiguracionModel',
    'backend.models.ConfiguracionModel.ConfiConsulta_model',
    'backend.models.ConfiguracionModel.ConfiEnfermeria_model',
    'backend.models.ConfiguracionModel.ConfiLaboratorio_model',
    'backend.models.ConfiguracionModel.ConfiServiciosbasicos_model',
    'backend.models.ConfiguracionModel.ConfiTrabajadores_model',
    
    # ========== Backend Repositories ==========
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
    
    # ========== Backend Repositories - Configuración ==========
    'backend.repositories.ConfiguracionRepositor',
    'backend.repositories.ConfiguracionRepositor.ConfiConsulta_repository',
    'backend.repositories.ConfiguracionRepositor.ConfiEnfermeria_repository',
    'backend.repositories.ConfiguracionRepositor.ConfiLaboratorio_repository',
    'backend.repositories.ConfiguracionRepositor.ConfiServiciosbasicos_repository',
    'backend.repositories.ConfiguracionRepositor.ConfiTrabajadores_repository',
    
    # ========== Dependencias Externas ==========
    # Base de datos
    'pyodbc',
    'sqlalchemy',
    
    # Generación de PDFs
    'reportlab',
    'reportlab.pdfgen',
    'reportlab.pdfgen.canvas',
    'reportlab.lib',
    'reportlab.lib.pagesizes',
    'reportlab.lib.styles',
    'reportlab.lib.colors',
    'reportlab.lib.units',
    'reportlab.lib.enums',
    'reportlab.platypus',
    'reportlab.platypus.paragraph',
    'reportlab.platypus.tables',
    'reportlab.platypus.frames',
    'reportlab.platypus.doctemplate',
    
    # Configuración y utilidades
    'dotenv',
    'pathlib',
    
    # Manejo de imágenes
    'PIL',
    'PIL.Image',
    'PIL.ImageDraw',
    'PIL.ImageFont',
    
    # Sistema y logging
    'logging',
    'logging.handlers',
    'logger_config',
    'resource_validator',
    
    # Otros
    'datetime',
    'decimal',
    'json',
    'hashlib',
]

print(f"  ✅ {len(hiddenimports)} módulos configurados")

# ═══════════════════════════════════════════════════════════════
# 7. ANÁLISIS PRINCIPAL
# ═══════════════════════════════════════════════════════════════
print("\n🔍 INICIANDO ANÁLISIS DE DEPENDENCIAS...")

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
        # Excluir librerías innecesarias para reducir tamaño
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
        'test',
        '_pytest',
        'django',
        'flask',
    ],
    noarchive=False,
    optimize=0,
)

print("  ✅ Análisis completado")

# ═══════════════════════════════════════════════════════════════
# 8. COMPILACIÓN DE ARCHIVOS PYTHON
# ═══════════════════════════════════════════════════════════════
print("\n📦 EMPAQUETANDO ARCHIVOS PYTHON...")

pyz = PYZ(a.pure, a.zipped_data)
print("  ✅ Archivos Python empaquetados")

# ═══════════════════════════════════════════════════════════════
# 9. CONFIGURACIÓN DEL EJECUTABLE
# ═══════════════════════════════════════════════════════════════
print("\n🎯 CONFIGURANDO EJECUTABLE...")

# Buscar icono disponible
icon_path = None
possible_icons = [
    'Resources/iconos/logo_CMI.ico',
    'Resources/iconos/Logo_de_Emergencia_Médica_RGL-removebg-preview.ico',
    'Resources/logo.ico',
    'icon.ico',
]

for icon in possible_icons:
    icon_full_path = project_dir / icon
    if icon_full_path.exists():
        icon_path = str(icon_full_path)
        print(f"  ✅ Icono encontrado: {icon}")
        break

if not icon_path:
    print("  ⚠️  No se encontró archivo de icono")

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
    console=False,  # Sin ventana de consola
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
    icon=icon_path,
    version='file_version_info.txt',  # Opcional: info de versión
)

print("  ✅ Configuración del ejecutable completada")

# ═══════════════════════════════════════════════════════════════
# 10. RECOPILACIÓN FINAL
# ═══════════════════════════════════════════════════════════════
print("\n📂 RECOPILANDO ARCHIVOS FINALES...")

coll = COLLECT(
    exe,
    a.binaries,
    a.datas,
    strip=False,
    upx=True,
    upx_exclude=[],
    name='ClinicaApp',
)

print("  ✅ Recopilación completada")

# ═══════════════════════════════════════════════════════════════
# RESUMEN FINAL
# ═══════════════════════════════════════════════════════════════
print("\n" + "=" * 70)
print("🎉 CONFIGURACIÓN COMPLETADA EXITOSAMENTE")
print("=" * 70)
print("\n📋 RESUMEN:")
print(f"  • Archivos QML: {qml_found}")
print(f"  • Scripts SQL: {len(datas_db_scripts)}")
print(f"  • Recursos: {'Sí' if datas_resources else 'No'}")
print(f"  • Módulos ocultos: {len(hiddenimports)}")
print(f"  • Total archivos: {len(all_datas)}")
print("\n🚀 LISTO PARA COMPILAR")
print("\nPara compilar, ejecuta:")
print("  pyinstaller clinica.spec")
print("\nEl ejecutable estará en: dist/ClinicaApp/")
print("=" * 70)
