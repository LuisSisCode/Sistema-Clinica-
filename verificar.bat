@echo off
chcp 65001 >nul
echo ═══════════════════════════════════════════════════════════════
echo 🔍 VERIFICACIÓN PRE-COMPILACIÓN
echo Sistema Clínica María Inmaculada v1.0
echo ═══════════════════════════════════════════════════════════════
echo.

set "ERRORS=0"
set "WARNINGS=0"

:: ══════════════════════════════════════════════════════════════
:: 1. VERIFICAR PYTHON Y DEPENDENCIAS
:: ══════════════════════════════════════════════════════════════
echo [1] VERIFICANDO ENTORNO PYTHON
echo ───────────────────────────────────────────────────────────────

python --version >nul 2>&1
if errorlevel 1 (
    echo ❌ Python NO instalado
    set /a ERRORS+=1
) else (
    for /f "tokens=2" %%v in ('python --version 2^>^&1') do echo ✅ Python %%v
)

echo.
echo Verificando módulos Python:

python -c "import PySide6" >nul 2>&1
if errorlevel 1 (
    echo ❌ PySide6 NO instalado
    set /a ERRORS+=1
) else (
    echo ✅ PySide6
)

python -c "import pyodbc" >nul 2>&1
if errorlevel 1 (
    echo ❌ pyodbc NO instalado
    set /a ERRORS+=1
) else (
    echo ✅ pyodbc
)

python -c "import reportlab" >nul 2>&1
if errorlevel 1 (
    echo ❌ reportlab NO instalado
    set /a ERRORS+=1
) else (
    echo ✅ reportlab
)

python -c "import PyInstaller" >nul 2>&1
if errorlevel 1 (
    echo ❌ PyInstaller NO instalado
    set /a ERRORS+=1
) else (
    echo ✅ PyInstaller
)

python -c "import dotenv" >nul 2>&1
if errorlevel 1 (
    echo ⚠️  python-dotenv NO instalado (opcional)
    set /a WARNINGS+=1
) else (
    echo ✅ python-dotenv
)

python -c "import PIL" >nul 2>&1
if errorlevel 1 (
    echo ⚠️  Pillow NO instalado (opcional)
    set /a WARNINGS+=1
) else (
    echo ✅ Pillow
)

echo.

:: ══════════════════════════════════════════════════════════════
:: 2. VERIFICAR ESTRUCTURA DEL PROYECTO
:: ══════════════════════════════════════════════════════════════
echo [2] VERIFICANDO ESTRUCTURA DEL PROYECTO
echo ───────────────────────────────────────────────────────────────

if exist "main.py" (
    echo ✅ main.py
) else (
    echo ❌ main.py NO encontrado
    set /a ERRORS+=1
)

if exist "clinica.spec" (
    echo ✅ clinica.spec
) else (
    echo ⚠️  clinica.spec NO encontrado (se puede generar)
    set /a WARNINGS+=1
)

if exist "backend\" (
    echo ✅ backend\
    
    if exist "backend\__init__.py" (
        echo   ✅ backend\__init__.py
    ) else (
        echo   ❌ backend\__init__.py NO encontrado
        set /a ERRORS+=1
    )
    
    if exist "backend\core\" (
        echo   ✅ backend\core\
    ) else (
        echo   ❌ backend\core\ NO encontrado
        set /a ERRORS+=1
    )
    
    if exist "backend\models\" (
        echo   ✅ backend\models\
    ) else (
        echo   ❌ backend\models\ NO encontrado
        set /a ERRORS+=1
    )
    
    if exist "backend\repositories\" (
        echo   ✅ backend\repositories\
    ) else (
        echo   ❌ backend\repositories\ NO encontrado
        set /a ERRORS+=1
    )
) else (
    echo ❌ backend\ NO encontrado
    set /a ERRORS+=1
)

if exist "database_scripts\" (
    echo ✅ database_scripts\
    
    if exist "database_scripts\01_schema.sql" (
        echo   ✅ 01_schema.sql
    ) else (
        echo   ❌ 01_schema.sql NO encontrado
        set /a ERRORS+=1
    )
    
    if exist "database_scripts\02_datos_iniciales.sql" (
        echo   ✅ 02_datos_iniciales.sql
    ) else (
        echo   ❌ 02_datos_iniciales.sql NO encontrado
        set /a ERRORS+=1
    )
) else (
    echo ⚠️  database_scripts\ NO encontrado
    set /a WARNINGS+=1
)

if exist "Resources\" (
    echo ✅ Resources\
) else (
    echo ⚠️  Resources\ NO encontrado (opcional)
    set /a WARNINGS+=1
)

echo.

:: ══════════════════════════════════════════════════════════════
:: 3. VERIFICAR ARCHIVOS QML
:: ══════════════════════════════════════════════════════════════
echo [3] VERIFICANDO ARCHIVOS QML
echo ───────────────────────────────────────────────────────────────

set "QML_COUNT=0"
set "QML_CRITICAL=0"

for %%f in (main.qml login.qml Dashboard.qml) do (
    if exist "%%f" (
        echo ✅ %%f
        set /a QML_COUNT+=1
    ) else (
        echo ❌ %%f NO encontrado (crítico)
        set /a ERRORS+=1
        set /a QML_CRITICAL+=1
    )
)

for %%f in (*.qml) do set /a QML_COUNT+=1

echo.
echo 📊 Total archivos QML encontrados: %QML_COUNT%

if %QML_CRITICAL% GTR 0 (
    echo ⚠️  Faltan %QML_CRITICAL% archivos QML críticos
)

echo.

:: ══════════════════════════════════════════════════════════════
:: 4. VERIFICAR SQL SERVER
:: ══════════════════════════════════════════════════════════════
echo [4] VERIFICANDO SQL SERVER
echo ───────────────────────────────────────────────────────────────

sc query MSSQL$SQLEXPRESS >nul 2>&1
if errorlevel 1 (
    sc query MSSQLSERVER >nul 2>&1
    if errorlevel 1 (
        echo ⚠️  SQL Server NO detectado
        echo    El sistema requiere SQL Server para funcionar
        set /a WARNINGS+=1
    ) else (
        echo ✅ SQL Server (MSSQLSERVER) detectado
    )
) else (
    sc query MSSQL$SQLEXPRESS | find "RUNNING" >nul
    if errorlevel 1 (
        echo ⚠️  SQL Server Express instalado pero NO está corriendo
        echo    Inicia el servicio antes de usar la aplicación
        set /a WARNINGS+=1
    ) else (
        echo ✅ SQL Server Express corriendo
    )
)

echo.

:: ══════════════════════════════════════════════════════════════
:: 5. VERIFICAR INNO SETUP (para instalador)
:: ══════════════════════════════════════════════════════════════
echo [5] VERIFICANDO INNO SETUP (Opcional)
echo ───────────────────────────────────────────────────────────────

if exist "%ProgramFiles(x86)%\Inno Setup 6\ISCC.exe" (
    echo ✅ Inno Setup 6 instalado
) else (
    if exist "%ProgramFiles%\Inno Setup 6\ISCC.exe" (
        echo ✅ Inno Setup 6 instalado
    ) else (
        echo ⚠️  Inno Setup NO instalado
        echo    Necesario para crear el instalador
        set /a WARNINGS+=1
    )
)

if exist "ClinicaApp_Setup.iss" (
    echo ✅ ClinicaApp_Setup.iss
) else (
    echo ⚠️  ClinicaApp_Setup.iss NO encontrado
    set /a WARNINGS+=1
)

echo.

:: ══════════════════════════════════════════════════════════════
:: 6. VERIFICAR ESPACIO EN DISCO
:: ══════════════════════════════════════════════════════════════
echo [6] VERIFICANDO ESPACIO EN DISCO
echo ───────────────────────────────────────────────────────────────

for /f "tokens=3" %%a in ('dir %CD% /-c ^| find "bytes free"') do set free=%%a
set /a free_mb=%free:~0,-6%

echo 💾 Espacio disponible: ~%free_mb% MB

if %free_mb% LSS 500 (
    echo ⚠️  ADVERTENCIA: Espacio bajo (se recomienda 500MB+)
    set /a WARNINGS+=1
) else (
    echo ✅ Espacio suficiente
)

echo.

:: ══════════════════════════════════════════════════════════════
:: RESUMEN FINAL
:: ══════════════════════════════════════════════════════════════
echo ═══════════════════════════════════════════════════════════════
echo 📊 RESUMEN DE VERIFICACIÓN
echo ═══════════════════════════════════════════════════════════════
echo.

if %ERRORS% EQU 0 (
    if %WARNINGS% EQU 0 (
        echo ✅ TODO PERFECTO - Listo para compilar
        echo.
        echo Ejecuta: compilar.bat
    ) else (
        echo ⚠️  %WARNINGS% advertencia(s) encontrada(s)
        echo.
        echo Puedes compilar, pero revisa las advertencias
        echo Ejecuta: compilar.bat
    )
) else (
    echo ❌ %ERRORS% error(es) encontrado(s)
    if %WARNINGS% GTR 0 echo ⚠️  %WARNINGS% advertencia(s) adicional(es)
    echo.
    echo ⚠️  CORRIGE LOS ERRORES ANTES DE COMPILAR
    echo.
    echo Errores comunes:
    echo   • Instalar dependencias: pip install -r requirements.txt
    echo   • Verificar estructura de carpetas
    echo   • Asegurar que main.py existe
)

echo.
echo ═══════════════════════════════════════════════════════════════
echo.

if %ERRORS% GTR 0 (
    echo ¿Necesitas ayuda? Revisa GUIA_COMPILACION.md
    echo.
)

pause
