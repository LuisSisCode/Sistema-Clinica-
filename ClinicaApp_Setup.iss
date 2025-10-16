
[Setup]
; ════════════════════════════════════════════════════════
; INSTALADOR PROFESIONAL - CLÍNICA MARÍA INMACULADA
; Versión 1.0 - Generado con Inno Setup
; ════════════════════════════════════════════════════════

#define MyAppName "Sistema Clínica María Inmaculada"
#define MyAppVersion "1.0"
#define MyAppPublisher "Clínica María Inmaculada"
#define MyAppURL "https://clinicamariainmaculada.com"
#define MyAppExeName "ClinicaApp.exe"
#define MyAppContact "llopezbeltran0@gmail.com"

[Setup]
; ════════════════════════════════════════════════════════
; INFORMACIÓN BÁSICA
; ════════════════════════════════════════════════════════
AppId={{12345678-1234-1234-1234-123456789012}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
AppContact={#MyAppContact}

; ════════════════════════════════════════════════════════
; CONFIGURACIÓN DE INSTALACIÓN
; ════════════════════════════════════════════════════════
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
AllowNoIcons=yes
;LicenseFile=LICENCIA.txt
;InfoBeforeFile=ANTES_DE_INSTALAR.txt
;InfoAfterFile=DESPUES_DE_INSTALAR.txt
OutputDir=Instaladores
OutputBaseFilename=ClinicaApp_Setup_v1.0
;SetupIconFile=icono_instalador.ico
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
;WizardImageFile=wizard_image.bmp
;WizardSmallImageFile=wizard_small.bmp

; ════════════════════════════════════════════════════════
; REQUISITOS DEL SISTEMA
; ════════════════════════════════════════════════════════
MinVersion=10.0
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64
PrivilegesRequired=admin

; ════════════════════════════════════════════════════════
; DESINSTALADOR
; ════════════════════════════════════════════════════════
UninstallDisplayIcon={app}\{#MyAppExeName}
UninstallDisplayName={#MyAppName}

[Languages]
Name: "spanish"; MessagesFile: "compiler:Languages\Spanish.isl"

[Tasks]
Name: "desktopicon"; Description: "Crear acceso directo en el Escritorio"; GroupDescription: "Accesos directos:"
Name: "quicklaunchicon"; Description: "Crear acceso directo en Inicio Rápido"; GroupDescription: "Accesos directos:"; Flags: unchecked

[Files]
; ════════════════════════════════════════════════════════
; ARCHIVOS A INSTALAR
; ════════════════════════════════════════════════════════
Source: "dist\ClinicaApp\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
;Source: "INSTRUCCIONES.txt"; DestDir: "{app}"; Flags: isreadme

[Icons]
; ════════════════════════════════════════════════════════
; ACCESOS DIRECTOS
; ════════════════════════════════════════════════════════
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\Instrucciones"; Filename: "{app}\INSTRUCCIONES.txt"
Name: "{group}\Desinstalar {#MyAppName}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon
Name: "{userappdata}\Microsoft\Internet Explorer\Quick Launch\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: quicklaunchicon

[Run]
; ════════════════════════════════════════════════════════
; EJECUTAR AL FINALIZAR
; ════════════════════════════════════════════════════════
Filename: "{app}\{#MyAppExeName}"; Description: "Ejecutar {#MyAppName}"; Flags: nowait postinstall skipifsilent

[Code]

// Verificar si SQL Server está instalado
function IsSQLServerInstalled(): Boolean;
var
  ResultCode: Integer;
begin
  Result := RegKeyExists(HKEY_LOCAL_MACHINE, 'SOFTWARE\Microsoft\Microsoft SQL Server');
end;

// Mostrar advertencia si SQL Server no está instalado
function InitializeSetup(): Boolean;
begin
  Result := True;
  
  if not IsSQLServerInstalled() then
  begin
    if MsgBox('⚠️ ADVERTENCIA: No se detectó SQL Server instalado.' + #13#10 + #13#10 +
              'El sistema requiere SQL Server para funcionar.' + #13#10 + #13#10 +
              '¿Desea continuar con la instalación de todas formas?' + #13#10 +
              '(Puede instalar SQL Server después)', 
              mbConfirmation, MB_YESNO) = IDNO then
    begin
      Result := False;
    end;
  end;
end;

// Mensaje después de la instalación
procedure CurStepChanged(CurStep: TSetupStep);
var
  AppDataDir: String;
begin
  if CurStep = ssPostInstall then
  begin
    // Crear carpetas en APPDATA (donde SÍ hay permisos)
    AppDataDir := ExpandConstant('{userappdata}\ClinicaMariaInmaculada');
    CreateDir(AppDataDir);
    CreateDir(AppDataDir + '\logs');
    CreateDir(AppDataDir + '\reportes');
    CreateDir(AppDataDir + '\temp');
  end;
end;