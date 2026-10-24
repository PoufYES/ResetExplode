#ifndef PayloadDir
  #error PayloadDir is required
#endif
#ifndef PrerequisiteDir
  #error PrerequisiteDir is required
#endif
#ifndef AppVersion
  #define AppVersion "0.16.0"
#endif

[Setup]
AppId={{C551D064-7E11-4F3A-89C0-32C5FD9B5BE2}
AppName=AG Bench
AppVersion={#AppVersion}
AppVerName=AG Bench {#AppVersion}
AppPublisher=GustavoReset / AG Bench
AppPublisherURL=https://github.com/GustavoReset/ResetExplode
DefaultDirName={autopf}\AG Bench
DefaultGroupName=AG Bench
DisableProgramGroupPage=yes
ArchitecturesAllowed=x64os
ArchitecturesInstallIn64BitMode=x64os
MinVersion=10.0.17763
PrivilegesRequired=admin
PrivilegesRequiredOverridesAllowed=commandline
OutputDir=..\release
OutputBaseFilename=AGBench-{#AppVersion}-Setup-x64
SetupIconFile=..\Assets\app.ico
UninstallDisplayIcon={app}\AGBench.exe
UninstallDisplayName=AG Bench
LicenseFile=..\LICENSE
InfoBeforeFile=INSTALACAO.txt
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
WizardSizePercent=110
CloseApplications=yes
RestartApplications=no
AppMutex=Local\AGBench.SingleInstance
SetupMutex=AGBench.Setup
VersionInfoVersion={#AppVersion}.0
VersionInfoProductName=AG Bench
VersionInfoDescription=Instalador do AG Bench
Uninstallable=yes
ChangesAssociations=no
AllowNoIcons=yes

[Languages]
Name: "brazilianportuguese"; MessagesFile: "compiler:Languages\BrazilianPortuguese.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Criar atalho na Área de Trabalho"; GroupDescription: "Atalhos:"
Name: "pawnio"; Description: "Instalar PawnIO 2.2.0 para sensores de temperatura e consumo da CPU"; GroupDescription: "Driver de sensores (oficial, assinado; pode exigir reinicialização):"; Check: CanInstallPawnIO

[Files]
Source: "{#PayloadDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "{#PrerequisiteDir}\PawnIO_setup.exe"; Flags: dontcopy

[Icons]
Name: "{group}\AG Bench"; Filename: "{app}\AGBench.exe"; WorkingDir: "{app}"
Name: "{group}\Desinstalar AG Bench"; Filename: "{uninstallexe}"
Name: "{autodesktop}\AG Bench"; Filename: "{app}\AGBench.exe"; WorkingDir: "{app}"; Tasks: desktopicon

[Run]
Filename: "{app}\AGBench.exe"; Description: "Abrir AG Bench"; Flags: nowait postinstall skipifsilent shellexec

[Code]
var
  DriverNeedsRestart: Boolean;

function NeedsPawnIO: Boolean;
begin
  Result := not RegKeyExists(HKLM64, 'SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\PawnIO');
end;

function CanInstallPawnIO: Boolean;
begin
  Result := IsAdminInstallMode and NeedsPawnIO;
end;

procedure CurStepChanged(CurStep: TSetupStep);
var
  ExitCode: Integer;
begin
  if (CurStep = ssPostInstall) and WizardIsTaskSelected('pawnio') and NeedsPawnIO then
  begin
    ExtractTemporaryFile('PawnIO_setup.exe');
    WizardForm.StatusLabel.Caption := 'Instalando driver de sensores PawnIO...';
    if Exec(ExpandConstant('{tmp}\PawnIO_setup.exe'), '-install -silent', '', SW_HIDE, ewWaitUntilTerminated, ExitCode) then
    begin
      DriverNeedsRestart := ExitCode = 3010;
      if (ExitCode <> 0) and (ExitCode <> 3010) then
        MsgBox('O AG Bench foi instalado, mas o PawnIO retornou o código ' + IntToStr(ExitCode) + '. Use o botão CORRIGIR dos sensores no aplicativo para tentar novamente.', mbInformation, MB_OK);
    end
    else
      MsgBox('O AG Bench foi instalado, mas não foi possível iniciar o instalador do PawnIO. Use o botão CORRIGIR dos sensores no aplicativo.', mbInformation, MB_OK);
  end;
end;

function NeedRestart: Boolean;
begin
  Result := DriverNeedsRestart;
end;
