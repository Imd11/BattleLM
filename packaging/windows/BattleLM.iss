#define AppName "BattleLM"
#define AppPublisher "BattleLM"
#define AppExeName "battle_lm.exe"

#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif

#ifndef BuildDir
  #define BuildDir "..\\..\\flutter_app\\build\\windows\\x64\\runner\\Release"
#endif

#ifndef OutputDir
  #define OutputDir ".\\dist"
#endif

[Setup]
AppId={{A11C3CC0-4A9B-4C88-8D1F-5DDB0B6D4B1D}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
OutputDir={#OutputDir}
OutputBaseFilename=BattleLM-Setup-{#AppVersion}
Compression=lzma
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
SetupIconFile=..\\..\\flutter_app\\windows\\runner\\resources\\app_icon.ico
UninstallDisplayIcon={app}\{#AppExeName}

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; Flags: unchecked

[Files]
Source: "{#BuildDir}\\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#AppName}"; Filename: "{app}\{#AppExeName}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExeName}"; Description: "Launch {#AppName}"; Flags: nowait postinstall skipifsilent
