; Inno Setup script - RITALICIOUS FOOD SUPPLY (Windows)
; Build: ISCC /DSourceDir="<folder ya build\windows\x64\runner\Release>" ritalicious.iss
#define MyAppName "RITALICIOUS FOOD SUPPLY"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "Ritalicious Food Supply"
#define MyAppExe "ritalicous_food_supply.exe"
#ifndef SourceDir
  #define SourceDir "..\build\windows\x64\runner\Release"
#endif

[Setup]
AppId={{F854BB43-EDE0-45BC-965A-CC715EF7F702}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\Ritalicious Food Supply
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
; Installs without needing administrator rights (per-user), admin optional.
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
OutputDir=..\dist
OutputBaseFilename=Ritalicious-Food-Supply-Setup
SetupIconFile=app_icon.ico
UninstallDisplayIcon={app}\{#MyAppExe}
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
CloseApplications=yes

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Files]
; Everything the app needs is inside this single Setup.exe (Flutter engine,
; plugins, SQLite and the Visual C++ runtime) - no other files or internet.
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "app_icon.ico"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
; Desktop shortcut is always created automatically and opens FULL SCREEN.
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExe}"; Parameters: "--fullscreen"; WorkingDir: "{app}"; IconFilename: "{app}\app_icon.ico"
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExe}"; Parameters: "--fullscreen"; WorkingDir: "{app}"; IconFilename: "{app}\app_icon.ico"

[Run]
Filename: "{app}\{#MyAppExe}"; Parameters: "--fullscreen"; WorkingDir: "{app}"; Description: "Fungua RITALICIOUS FOOD SUPPLY sasa"; Flags: nowait postinstall skipifsilent
