"""
═══════════════════════════════════════════════════════════════
CONFIGURACIÓN PYINSTALLER - Sistema Clínica María Inmaculada
Versión 2.0 - Actualizado con db_installer v3.0 y mejoras
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
print("🏥 SISTEMA CLÍNICA MARÍA INMACULADA - BUILD v2.0")
print("=" * 70)
print(f"📁 Directorio del proyecto: {project_dir}")
print("=" * 70)

# ═══════════════════════════════════════════════════════════════
# 1. ARCHIVOS QML (INTERFAZ DE USUARIO) - AUTO-DISCOVER
# ═══════════════════════════════════════════════════════════════
print("\n📋 RECOPILANDO ARCHIVOS QML...")

datas_qml = []
qml_found = 0

# ✅ Auto-descubrir todos los archivos .qml en la raíz
qml_files_in_root = list(project_dir.glob('*.qml'))

for qml_file in qml_files_in_root:
    datas_qml.append((str(qml_file), '.'))
    qml_found += 1
    print(f"  ✅ {qml_file.name}")

print(f"\n📊 Archivos QML: {qml_found} encontrados")

# ═══════════════════════════════════════════════════════════════
# 2. SCRIPTS DE BASE DE DATOS - CRÍTICO PARA SETUP
# ═══════════════════════════════════════════════════════════════
print("\n💾 RECOPILANDO SCRIPTS SQL...")

datas_db_scripts = []
db_scripts_dir = project_dir / 'database_scripts'

required_scripts = [
    '01_schema.sql',
    '02_datos_iniciales.sql',
    '03_indices_optimizacion.sql',  # ✅ NUEVO
]

if db_scripts_dir.exists():
    for script_name in required_scripts:
        script_path = db_scripts_dir / script_name
        if script_path.exists():
            datas_db_scripts.append((str(script_path), 'database_scripts'))
            print(f"  ✅ {script_name}")
        else:
            print(f"  ❌ {script_name} - NO ENCONTRADO (CRÍTICO)")
    
    print(f"\n📊 Scripts SQL: {len(datas_db_scripts)}/3 requeridos")
    
    if len(datas_db_scripts) < 3:
        print("\n⚠️  ADVERTENCIA: Faltan scripts SQL críticos")
        print("   El setup automático podría no funcionar correctamente")
else:
    print("  ❌ ERROR: Carpeta 'database_scripts' no encontrada")
    print("  💡 SOLUCIÓN: Crea la carpeta y copia los 3 archivos SQL")

# ═══════════════════════════════════════════════════════════════
# 3. BACKEND COMPLETO - INCLUIR TODO
# ═══════════════════════════════════════════════════════════════
print("\n🔧 RECOPILANDO BACKEND...")

datas_backend = []
backend_dir = project_dir / 'backend'

if backend_dir.exists():
    # Incluir toda la carpeta backend recursivamente
    for py_file in backend_dir.rglob('*.py'):
        # Calcular ruta relativa para mantener estructura
        rel_path = py_file.relative_to(project_dir)
        dest_dir = str(rel_path.parent)
        datas_backend.append((str(py_file), dest_dir))
    
    print(f"  ✅ Backend incluido ({len(datas_backend)} archivos .py)")
else:
    print("  ❌ ERROR: Carpeta 'backend' no encontrada")

# ═══════════════════════════════════════════════════════════════
# 4. RECURSOS (ICONOS, IMÁGENES, ETC.)
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
# 5. ARCHIVOS ADICIONALES OPCIONALES
# ═══════════════════════════════════════════════════════════════
print("\n📄 RECOPILANDO ARCHIVOS ADICIONALES...")

datas_additional = []
additional_files = [
    'generar_pdf.py',
    'setup_handler.py',
    'logger_config.py',
    'resource_validator.py',
    'README.md',
    'LICENSE.txt',
]

for file in additional_files:
    full_path = project_dir / file
    if full_path.exists():
        datas_additional.append((str(full_path), '.'))
        print(f"  ✅ {file}")

# ═══════════════════════════════════════════════════════════════
# 6. COMBINAR TODOS LOS DATOS
# ═══════════════════════════════════════════════════════════════
all_datas = datas_qml + datas_db_scripts + datas_backend + datas_resources + datas_additional

print("\n" + "=" * 70)
print(f"📦 TOTAL ARCHIVOS A INCLUIR: {len(all_datas)}")
print("=" * 70)

# ═══════════════════════════════════════════════════════════════
# 7. MÓDULOS OCULTOS (HIDDEN IMPORTS) - ACTUALIZADO
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
    'PySide6.QtConcurrent',
    
    # ========== Backend Core ==========
    'backend',
    'backend.core',
    'backend.core.config',
    'backend.core.database_conexion',
    'backend.core.cache_system',
    'backend.core.excepciones',
    'backend.core.base_repository',
    'backend.core.utils',
    'backend.core.db_installer',        # ✅ Actualizado v3.0
    'backend.core.config_manager',
    'backend.core.config_fifo',
    'backend.core.login',
    'backend.core.signals_manager',
    
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
    'backend.models.medico_model',
    
    # ========== Backend Models - Configuración ==========
    'backend.models.ConfiguracionModel',
    'backend.models.ConfiguracionModel.configuracion_model',
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
    'backend.repositories.especialidad_repository',
    'backend.repositories.estadistica_repository',
    
    # ========== Backend Repositories - Configuración ==========
    'backend.repositories.ConfiguracionRepositor',
    'backend.repositories.ConfiguracionRepositor.configuracion_repository',
    'backend.repositories.ConfiguracionRepositor.ConfiConsulta_repository',
    'backend.repositories.ConfiguracionRepositor.ConfiEnfermeria_repository',
    'backend.repositories.ConfiguracionRepositor.ConfiLaboratorio_repository',
    'backend.repositories.ConfiguracionRepositor.ConfiServiciosbasicos_repository',
    'backend.repositories.ConfiguracionRepositor.ConfiTrabajadores_repository',
    
    # ========== Dependencias de Base de Datos ==========
    'pyodbc',
    'sqlalchemy',
    'sqlalchemy.engine',
    'sqlalchemy.pool',
    
    # ========== Generación de PDFs ==========
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
    'reportlab.platypus.flowables',
    
    # ========== Configuración y Utilidades ==========
    'dotenv',
    'python_dotenv',
    'pathlib',
    'bcrypt',
    
    # ========== Manejo de Imágenes ==========
    'PIL',
    'PIL.Image',
    'PIL.ImageDraw',
    'PIL.ImageFont',
    'PIL.ImageOps',
    'PIL.ImageFilter',
    
    # ========== Sistema y Logging ==========
    'logging',
    'logging.handlers',
    'logger_config',
    'resource_validator',
    
    # ========== Otros Módulos Estándar ==========
    'datetime',
    'decimal',
    'json',
    'hashlib',
    'threading',
    'queue',
    'weakref',
    'collections',
    'itertools',
    'functools',
    're',
    'typing',
]

print(f"  ✅ {len(hiddenimports)} módulos configurados")

# ═══════════════════════════════════════════════════════════════
# 8. ANÁLISIS PRINCIPAL
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
        'flask_cors',
        'tornado',
        'twisted',
        'asyncio',
        'multiprocessing',
    ],
    noarchive=False,
    optimize=0,
)

print("  ✅ Análisis completado")

# ═══════════════════════════════════════════════════════════════
# 9. COMPILACIÓN DE ARCHIVOS PYTHON
# ═══════════════════════════════════════════════════════════════
print("\n📦 EMPAQUETANDO ARCHIVOS PYTHON...")

pyz = PYZ(a.pure, a.zipped_data)
print("  ✅ Archivos Python empaquetados")

# ═══════════════════════════════════════════════════════════════
# 10. CONFIGURACIÓN DEL EJECUTABLE
# ═══════════════════════════════════════════════════════════════
print("\n🎯 CONFIGURANDO EJECUTABLE...")

# Buscar icono disponible
icon_path = None
possible_icons = [
    'Resources/iconos/Logo_de_Emergencia_Médica_RGL-removebg-preview.ico',
    'Resources/iconos/logo_CMI.ico',
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
    print("  ⚠️  No se encontró archivo de icono (.ico)")

# ✅ Información de versión para Windows
version_info = None
try:
    from PyInstaller.utils.win32.versioninfo import VSVersionInfo, FixedFileInfo, \
        StringFileInfo, StringTable, StringStruct, VarFileInfo, VarStruct
    
    version_info = VSVersionInfo(
        ffi=FixedFileInfo(
            filevers=(1, 0, 0, 0),
            prodvers=(1, 0, 0, 0),
            mask=0x3f,
            flags=0x0,
            OS=0x40004,
            fileType=0x1,
            subtype=0x0,
            date=(0, 0)
        ),
        kids=[
            StringFileInfo([
                StringTable(
                    '040904B0',  # English (US) + Unicode
                    [
                        StringStruct('CompanyName', 'Clínica María Inmaculada'),
                        StringStruct('FileDescription', 'Sistema de Gestión Clínica'),
                        StringStruct('FileVersion', '1.0.0.0'),
                        StringStruct('InternalName', 'ClinicaApp'),
                        StringStruct('LegalCopyright', '© 2026 Clínica María Inmaculada'),
                        StringStruct('OriginalFilename', 'ClinicaApp.exe'),
                        StringStruct('ProductName', 'Sistema Clínica María Inmaculada'),
                        StringStruct('ProductVersion', '1.0.0.0'),
                    ]
                )
            ]),
            VarFileInfo([VarStruct('Translation', [1033, 1200])])
        ]
    )
    print("  ✅ Información de versión configurada")
except:
    print("  ⚠️  No se pudo configurar información de versión")

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
    console=False,  # ✅ Sin ventana de consola (aplicación de ventanas)
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
    icon=icon_path,
    version=version_info  # ✅ Información de versión incluida
)

print("  ✅ Configuración del ejecutable completada")

# ═══════════════════════════════════════════════════════════════
# 11. RECOPILACIÓN FINAL
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
print(f"  • Scripts SQL: {len(datas_db_scripts)}/3 requeridos")
print(f"  • Backend: {len(datas_backend)} archivos")
print(f"  • Recursos: {'Sí' if datas_resources else 'No'}")
print(f"  • Módulos ocultos: {len(hiddenimports)}")
print(f"  • Total archivos: {len(all_datas)}")

# ✅ Advertencias importantes
if len(datas_db_scripts) < 3:
    print("\n⚠️  ADVERTENCIA: Faltan scripts SQL críticos")
    print("   El setup automático NO funcionará sin los 3 scripts")

if not icon_path:
    print("\n⚠️  ADVERTENCIA: No se encontró icono")
    print("   El ejecutable no tendrá icono personalizado")

print("\n🚀 LISTO PARA COMPILAR")
print("\n📝 Para compilar, ejecuta:")
print("   pyinstaller clinica.spec --clean")
print("\n📦 El ejecutable estará en:")
print("   dist/ClinicaApp/ClinicaApp.exe")
print("\n📊 Tamaño estimado: ~150-250 MB")
print("=" * 70)
