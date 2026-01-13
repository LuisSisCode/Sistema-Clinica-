@echo off
chcp 65001 >nul
echo ═══════════════════════════════════════════════════════════════
echo 🏥 COMPILADOR AUTOMÁTICO - SISTEMA CLÍNICA MARÍA INMACULADA v2.0
echo ═══════════════════════════════════════════════════════════════
echo.

:: ══════════════════════════════════════════════════════════════
:: VERIFICAR PYTHON
:: ══════════════════════════════════════════════════════════════
echo [1/7] Verificando Python...
python --version >nul 2>&1
if errorlevel 1 (
    echo ❌ ERROR: Python no está instalado o no está en el PATH
    echo.
    echo 💡 SOLUCIÓN: Instala Python desde: https://www.python.org/downloads/
    pause
    exit /b 1
)

for /f "tokens=2" %%v in ('python --version 2^>^&1') do echo ✅ Python %%v
echo.

:: ══════════════════════════════════════════════════════════════
:: VERIFICAR PYINSTALLER
:: ══════════════════════════════════════════════════════════════
echo [2/7] Verificando PyInstaller...
python -c "import PyInstaller" >nul 2>&1
if errorlevel 1 (
    echo ⚠️  PyInstaller no instalado. Instalando...
    pip install pyinstaller
    if errorlevel 1 (
        echo ❌ ERROR: No se pudo instalar PyInstaller
        pause
        exit /b 1
    )
)

for /f "tokens=2" %%v in ('pip show pyinstaller ^| findstr Version') do echo ✅ PyInstaller %%v
echo.

:: ══════════════════════════════════════════════════════════════
:: VERIFICAR ARCHIVOS CRÍTICOS
:: ══════════════════════════════════════════════════════════════
echo [3/7] Verificando archivos críticos...

set "ERRORS=0"

if not exist "main.py" (
    echo ❌ main.py NO encontrado
    set /a ERRORS+=1
) else (
    echo ✅ main.py
)

if not exist "clinica.spec" (
    echo ⚠️  clinica.spec NO encontrado
    echo    Se generará automáticamente durante la compilación
) else (
    echo ✅ clinica.spec
)

if not exist "backend\" (
    echo ❌ backend\ NO encontrado
    set /a ERRORS+=1
) else (
    echo ✅ backend\
)

:: ✅ VERIFICAR SCRIPTS SQL CRÍTICOS
if not exist "database_scripts\" (
    echo ❌ database_scripts\ NO encontrado
    set /a ERRORS+=1
) else (
    echo ✅ database_scripts\
    
    if not exist "database_scripts\01_schema.sql" (
        echo   ❌ 01_schema.sql FALTANTE (CRÍTICO)
        set /a ERRORS+=1
    ) else (
        echo   ✅ 01_schema.sql
    )
    
    if not exist "database_scripts\02_datos_iniciales.sql" (
        echo   ❌ 02_datos_iniciales.sql FALTANTE (CRÍTICO)
        set /a ERRORS+=1
    ) else (
        echo   ✅ 02_datos_iniciales.sql
    )
    
    if not exist "database_scripts\03_indices_optimizacion.sql" (
        echo   ⚠️  03_indices_optimizacion.sql FALTANTE (IMPORTANTE)
    ) else (
        echo   ✅ 03_indices_optimizacion.sql
    )
)

if not exist "Resources\" (
    echo ⚠️  Resources\ NO encontrado (los iconos no se incluirán)
) else (
    echo ✅ Resources\
)

if %ERRORS% GTR 0 (
    echo.
    echo ❌ ERRORES ENCONTRADOS: %ERRORS%
    echo    Corrige los errores antes de continuar
    pause
    exit /b 1
)

echo.

:: ══════════════════════════════════════════════════════════════
:: VERIFICAR DEPENDENCIAS
:: ══════════════════════════════════════════════════════════════
echo [4/7] Verificando dependencias Python...

set "MISSING_DEPS=0"

python -c "import PySide6" >nul 2>&1
if errorlevel 1 (
    echo ❌ PySide6 NO instalado
    set /a MISSING_DEPS+=1
) else (
    echo ✅ PySide6
)

python -c "import pyodbc" >nul 2>&1
if errorlevel 1 (
    echo ❌ pyodbc NO instalado
    set /a MISSING_DEPS+=1
) else (
    echo ✅ pyodbc
)

python -c "import reportlab" >nul 2>&1
if errorlevel 1 (
    echo ❌ reportlab NO instalado
    set /a MISSING_DEPS+=1
) else (
    echo ✅ reportlab
)

if %MISSING_DEPS% GTR 0 (
    echo.
    echo ⚠️  FALTAN %MISSING_DEPS% DEPENDENCIAS
    echo.
    set /p install="¿Deseas instalar las dependencias faltantes? (S/N): "
    if /i "%install%"=="S" (
        echo.
        echo Instalando dependencias...
        pip install -r requirements.txt
        if errorlevel 1 (
            echo ❌ Error instalando dependencias
            pause
            exit /b 1
        )
        echo ✅ Dependencias instaladas
    ) else (
        echo ❌ No se puede continuar sin las dependencias
        pause
        exit /b 1
    )
)

echo.

:: ══════════════════════════════════════════════════════════════
:: LIMPIAR BUILDS ANTERIORES
:: ══════════════════════════════════════════════════════════════
echo [5/7] Limpiando builds anteriores...

if exist "build\" (
    echo    Eliminando carpeta build\...
    rmdir /s /q build 2>nul
)

if exist "dist\" (
    echo    Eliminando carpeta dist\...
    rmdir /s /q dist 2>nul
)

:: Limpiar archivos de caché
if exist "__pycache__\" (
    echo    Limpiando caché Python...
    rmdir /s /q __pycache__ 2>nul
)

echo ✅ Limpieza completada
echo.

:: ══════════════════════════════════════════════════════════════
:: COMPILAR CON PYINSTALLER
:: ══════════════════════════════════════════════════════════════
echo [6/7] Compilando con PyInstaller...
echo ⏱️  Esto puede tomar 3-5 minutos...
echo.

if exist "clinica.spec" (
    echo 📝 Usando clinica.spec existente...
    echo.
    pyinstaller clinica.spec --clean --noconfirm
) else (
    echo 📝 Generando configuración automática...
    echo.
    pyinstaller main.py ^
        --name=ClinicaApp ^
        --noconsole ^
        --onedir ^
        --add-data "*.qml;." ^
        --add-data "database_scripts;database_scripts" ^
        --add-data "Resources;Resources" ^
        --add-data "backend;backend" ^
        --hidden-import=PySide6.QtCore ^
        --hidden-import=PySide6.QtQml ^
        --hidden-import=PySide6.QtQuick ^
        --hidden-import=backend ^
        --hidden-import=backend.core.db_installer ^
        --hidden-import=pyodbc ^
        --clean ^
        --noconfirm
)

if errorlevel 1 (
    echo.
    echo ❌ ERROR: La compilación falló
    echo.
    echo 💡 SOLUCIONES COMUNES:
    echo    1. Verifica que todas las dependencias estén instaladas
    echo    2. Revisa el log de PyInstaller arriba
    echo    3. Intenta ejecutar: pip install --upgrade pyinstaller
    echo.
    pause
    exit /b 1
)

echo.
echo ✅ Compilación completada exitosamente
echo.

:: ══════════════════════════════════════════════════════════════
:: VERIFICAR RESULTADO Y ESTADÍSTICAS
:: ══════════════════════════════════════════════════════════════
echo [7/7] Verificando resultado...

if not exist "dist\ClinicaApp\ClinicaApp.exe" (
    echo ❌ ERROR: No se generó el ejecutable
    echo    Ubicación esperada: dist\ClinicaApp\ClinicaApp.exe
    pause
    exit /b 1
)

echo ✅ Ejecutable generado: dist\ClinicaApp\ClinicaApp.exe
echo.

:: Calcular tamaño total
set size=0
for /f "tokens=3" %%a in ('dir "dist\ClinicaApp" /s /-c 2^>nul ^| find "File(s)"') do set size=%%a

:: Convertir bytes a MB (aproximado)
if defined size (
    set /a size_mb=!size! / 1048576
    echo 📊 Tamaño total: ~!size_mb! MB
) else (
    echo 📊 Tamaño total: No disponible
)

:: Contar archivos
for /f %%a in ('dir "dist\ClinicaApp" /s /b 2^>nul ^| find /c /v ""') do set file_count=%%a
echo 📁 Archivos totales: %file_count%

echo.

:: ══════════════════════════════════════════════════════════════
:: RESUMEN FINAL
:: ══════════════════════════════════════════════════════════════
echo ═══════════════════════════════════════════════════════════════
echo 🎉 ¡COMPILACIÓN EXITOSA!
echo ═══════════════════════════════════════════════════════════════
echo.
echo 📁 Ubicación del ejecutable:
echo    %CD%\dist\ClinicaApp\
echo.
echo 📋 Archivos importantes incluidos:
echo    ✅ ClinicaApp.exe (ejecutable principal)
echo    ✅ Scripts SQL (setup automático)
echo    ✅ Backend Python (lógica de negocio)
echo    ✅ Interfaz QML (pantallas)
echo    ✅ Recursos (iconos, imágenes)
echo.
echo 📝 SIGUIENTES PASOS:
echo    1. Prueba el ejecutable:
echo       dist\ClinicaApp\ClinicaApp.exe
echo.
echo    2. Si funciona correctamente, crea el instalador:
echo       a) Abre Inno Setup Compiler
echo       b) Abre: ClinicaApp_Setup.iss
echo       c) Build → Compile (F9)
echo.
echo    3. El instalador se generará en:
echo       instaladores\ClinicaApp_Setup.exe
echo.
echo ⚠️  NOTAS IMPORTANTES:
echo    • El ejecutable requiere SQL Server instalado
echo    • Primera ejecución mostrará wizard de configuración
echo    • Usuario por defecto: admin / admin123
echo.
echo ═══════════════════════════════════════════════════════════════
echo.

:: ══════════════════════════════════════════════════════════════
:: OPCIONES POST-COMPILACIÓN
:: ══════════════════════════════════════════════════════════════
:menu
echo ¿Qué deseas hacer?
echo.
echo [1] Abrir carpeta del ejecutable
echo [2] Ejecutar la aplicación (prueba)
echo [3] Crear instalador con Inno Setup
echo [4] Salir
echo.
set /p option="Selecciona una opción (1-4): "

if "%option%"=="1" goto open_folder
if "%option%"=="2" goto run_app
if "%option%"=="3" goto create_installer
if "%option%"=="4" goto end

echo ⚠️  Opción inválida
goto menu

:open_folder
explorer "dist\ClinicaApp"
goto menu

:run_app
echo.
echo 🚀 Iniciando aplicación...
echo.
start "" "dist\ClinicaApp\ClinicaApp.exe"
timeout /t 2 >nul
echo ✅ Aplicación iniciada
echo.
goto menu

:create_installer
echo.
if not exist "ClinicaApp_Setup.iss" (
    echo ❌ No se encontró ClinicaApp_Setup.iss
    echo    Crea el archivo de configuración de Inno Setup primero
    pause
    goto menu
)

if exist "%ProgramFiles(x86)%\Inno Setup 6\ISCC.exe" (
    echo 📦 Compilando instalador...
    "%ProgramFiles(x86)%\Inno Setup 6\ISCC.exe" "ClinicaApp_Setup.iss"
    if errorlevel 1 (
        echo ❌ Error creando instalador
    ) else (
        echo ✅ Instalador creado exitosamente
        if exist "instaladores\" explorer "instaladores"
    )
) else (
    echo ⚠️  Inno Setup no está instalado
    echo    Descárgalo desde: https://jrsoftware.org/isdl.php
    echo.
    echo    O abre ClinicaApp_Setup.iss manualmente en Inno Setup
)
pause
goto menu

:end
echo.
echo 👋 ¡Hasta luego!
echo.
pause >nul
