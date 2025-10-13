============================================
  SISTEMA DE GESTIÓN CLÍNICA
  Versión 1.0
============================================

REQUISITOS DEL SISTEMA:
- Windows 10 o superior (64 bits)
- SQL Server 2019 o superior (Express es suficiente)
- Driver ODBC para SQL Server (incluido en Windows)
- 4GB de RAM mínimo
- 500MB de espacio en disco

INSTALACIÓN:

1. INSTALAR SQL SERVER (si no lo tienes)
   - Descargar SQL Server Express desde Microsoft
   - Instalar con configuración predeterminada
   - Recordar el nombre de la instancia (ejemplo: localhost\SQLEXPRESS)

2. PRIMERA EJECUCIÓN
   - Ejecutar ClinicaApp.exe
   - El sistema detectará que es la primera vez
   - Configurar conexión a SQL Server:
     * Servidor: localhost\SQLEXPRESS (o tu servidor)
     * Base de datos: ClinicaMariaInmaculada
     * Autenticación: Windows (recomendado)
   
3. CONFIGURACIÓN DE BASE DE DATOS
   - El sistema ejecutará automáticamente los scripts SQL
   - Se crearán las tablas y datos iniciales
   - Se creará un usuario administrador inicial

USUARIO INICIAL:
(Se configurará durante la instalación)

SOPORTE:
Para ayuda o reportar problemas, contactar a:
[Tu información de contacto]

CARPETAS:
- reportes/  : PDFs generados
- logs/      : Registros del sistema
- temp/      : Archivos temporales
- database_scripts/ : Scripts SQL de instalación

NOTAS:
- NO eliminar la carpeta database_scripts
- Hacer backup regular de la base de datos
- Los reportes se guardan en la carpeta reportes/

============================================
© 2025 - Clínica María Inmaculada
============================================