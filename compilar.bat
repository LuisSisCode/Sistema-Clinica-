@echo off
chcp 65001 >nul
echo ═══════════════════════════════════════════════════════════════
echo 🏥 COMPILADOR AUTOMÁTICO - SISTEMA CLÍNICA MARÍA INMACULADA
echo ═══════════════════════════════════════════════════════════════
echo.

:: ══════════════════════════════════════════════════════════════
:: VERIFICAR PYTHON
:: ══════════════════════════════════════════════════════════════
echo [1/6] Verificando Python...
python --version >nul 2>&1
if errorlevel 1 (
    echo ❌ ERROR: Python no está instalado o no está en el PATH
    echo.
    echo Instala Python desde: https://www.python.org/downloads/
    pause
    exit /b 1
)
echo ✅ Python encontrado
echo.

:: ══════════════════════════════════════════════════════════════
:: VERIFICAR PYINSTALLER
:: ══════════════════════════════════════════════════════════════
echo [2/6] Verificando PyInstaller...
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
echo ✅ PyInstaller disponible
echo.

:: ══════════════════════════════════════════════════════════════
:: VERIFICAR ARCHIVOS NECESARIOS
:: ══════════════════════════════════════════════════════════════
echo [3/6] Verificando archivos necesarios...

if not exist "main.py" (
    echo ❌ ERROR: No se encuentra main.py
    pause
    exit /b 1
)
echo ✅ main.py encontrado

if not exist "clinica.spec" (
    echo ⚠️  clinica.spec no encontrado. Usando configuración por defecto...
) else (
    echo ✅ clinica.spec encontrado
)

if not exist "database_scripts" (
    echo ⚠️  ADVERTENCIA: Carpeta database_scripts no encontrada
    echo    Los scripts SQL no se incluirán en el ejecutable
) else (
    echo ✅ database_scripts encontrado
)

if not exist "backend" (
    echo ❌ ERROR: Carpeta backend no encontrada
    pause
    exit /b 1
)
echo ✅ backend encontrado
echo.

:: ══════════════════════════════════════════════════════════════
:: LIMPIAR BUILDS ANTERIORES
:: ══════════════════════════════════════════════════════════════
echo [4/6] Limpiando builds anteriores...

if exist "build" (
    echo    Eliminando carpeta build...
    rmdir /s /q build
)

if exist "dist" (
    echo    Eliminando carpeta dist...
    rmdir /s /q dist
)

echo ✅ Limpieza completada
echo.

:: ══════════════════════════════════════════════════════════════
:: COMPILAR CON PYINSTALLER
:: ══════════════════════════════════════════════════════════════
echo [5/6] Compilando con PyInstaller...
echo    Esto puede tomar varios minutos...
echo.

if exist "clinica.spec" (
    echo    Usando clinica.spec...
    pyinstaller clinica.spec --clean
) else (
    echo    Generando ejecutable sin .spec...
    pyinstaller --name=ClinicaApp ^
                --noconsole ^
                --onedir ^
                --add-data "*.qml;." ^
                --add-data "database_scripts;database_scripts" ^
                --add-data "Resources;Resources" ^
                --hidden-import=PySide6.QtCore ^
                --hidden-import=PySide6.QtQml ^
                --hidden-import=PySide6.QtQuick ^
                --hidden-import=backend ^
                main.py
)

if errorlevel 1 (
    echo.
    echo ❌ ERROR: La compilación falló
    echo    Revisa los mensajes de error arriba
    pause
    exit /b 1
)

echo.
echo ✅ Compilación completada exitosamente
echo.

:: ══════════════════════════════════════════════════════════════
:: VERIFICAR RESULTADO
:: ══════════════════════════════════════════════════════════════
echo [6/6] Verificando resultado...

if not exist "dist\ClinicaApp\ClinicaApp.exe" (
    echo ❌ ERROR: No se generó el ejecutable
    pause
    exit /b 1
)

echo ✅ Ejecutable generado: dist\ClinicaApp\ClinicaApp.exe
echo.

:: Calcular tamaño
for /f "tokens=3" %%a in ('dir "dist\ClinicaApp" /s /-c ^| find "bytes"') do set size=%%a
set /a size_mb=%size:~0,-6%
echo 📊 Tamaño total: ~%size_mb% MB
echo.

:: ══════════════════════════════════════════════════════════════
:: RESUMEN
:: ══════════════════════════════════════════════════════════════
echo ═══════════════════════════════════════════════════════════════
echo 🎉 ¡COMPILACIÓN EXITOSA!
echo ═══════════════════════════════════════════════════════════════
echo.
echo 📁 Ubicación del ejecutable:
echo    %CD%\dist\ClinicaApp\
echo.
echo 📋 Siguientes pasos:
echo    1. Prueba el ejecutable: dist\ClinicaApp\ClinicaApp.exe
echo    2. Si funciona, crea el instalador con Inno Setup
echo.
echo 🔧 Para crear el instalador:
echo    1. Abre Inno Setup Compiler
echo    2. Abre el archivo: ClinicaApp_Setup.iss
echo    3. Build -^> Compile (F9)
echo.
echo ═══════════════════════════════════════════════════════════════
echo.

:: ══════════════════════════════════════════════════════════════
:: PREGUNTAR SI ABRIR LA CARPETA
:: ══════════════════════════════════════════════════════════════
set /p open="¿Deseas abrir la carpeta del ejecutable? (S/N): "
if /i "%open%"=="S" (
    explorer "dist\ClinicaApp"
)

echo.
echo Presiona cualquier tecla para salir...
pause >nul
