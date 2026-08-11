#ifndef ProductVersion
  #error ProductVersion is required
#endif
#ifndef PackageRoot23
  #error PackageRoot23 is required
#endif
#ifndef PackageRoot37Win32
  #error PackageRoot37Win32 is required
#endif
#ifndef PackageRoot37Win64
  #error PackageRoot37Win64 is required
#endif

#define ProductName "RadIA"
#define ProductPublisher "RadIA"

[Setup]
AppId={{D80E5F95-A879-44BB-A5E7-4EE7AD7509D7}
AppName={#ProductName}
AppVersion={#ProductVersion}
AppPublisher={#ProductPublisher}
DefaultDirName={autopf}\RadIA
DefaultGroupName=RadIA
DisableProgramGroupPage=yes
OutputDir={#OutputDirectory}
OutputBaseFilename={#OutputBaseFilename}
Compression=lzma2/max
SolidCompression=yes
ArchitecturesAllowed=x86compatible x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=admin
SetupLogging=yes
WizardStyle=modern

[Languages]
Name: "brazilianportuguese"; MessagesFile: "compiler:Languages\BrazilianPortuguese.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Types]
Name: "auto"; Description: "Automatically detected Delphi installations"
Name: "custom"; Description: "Custom target selection"; Flags: iscustom

[Components]
Name: "d12"; Description: "Delphi 12 Win32"; Types: auto
Name: "d13win32"; Description: "Delphi 13 Win32"; Types: auto
Name: "d13win64"; Description: "Delphi 13 IDE64"; Types: auto

[Files]
Source: "{#PackageRoot23}\*"; DestDir: "{app}\Packages\23.0-Win32"; \
  Flags: ignoreversion recursesubdirs createallsubdirs; Components: d12
Source: "{#PackageRoot37Win32}\*"; DestDir: "{app}\Packages\37.0-Win32"; \
  Flags: ignoreversion recursesubdirs createallsubdirs; Components: d13win32
Source: "{#PackageRoot37Win64}\*"; DestDir: "{app}\Packages\37.0-Win64"; \
  Flags: ignoreversion recursesubdirs createallsubdirs; Components: d13win64

[InstallDelete]
Type: filesandordirs; Name: "{app}\Packages\23.0-Win32"; Components: d12
Type: filesandordirs; Name: "{app}\Packages\37.0-Win32"; Components: d13win32
Type: filesandordirs; Name: "{app}\Packages\37.0-Win64"; Components: d13win64

[UninstallRun]
Filename: "{sys}\WindowsPowerShell\v1.0\powershell.exe"; \
  Parameters: "{code:GetD12UninstallParameters}"; \
  Flags: runhidden waituntilterminated; Components: d12; RunOnceId: "RadIA-D12"
Filename: "{sys}\WindowsPowerShell\v1.0\powershell.exe"; \
  Parameters: "{code:GetD13Win32UninstallParameters}"; \
  Flags: runhidden waituntilterminated; Components: d13win32; RunOnceId: "RadIA-D13-Win32"
Filename: "{sys}\WindowsPowerShell\v1.0\powershell.exe"; \
  Parameters: "{code:GetD13Win64UninstallParameters}"; \
  Flags: runhidden waituntilterminated; Components: d13win64; RunOnceId: "RadIA-D13-Win64"

[Code]
function BuildPackageParameters(
  const PackageName: String;
  const Version: String;
  const Mode: String;
  const IDE64: Boolean
): String;
var
  ScriptPath: String;
begin
  ScriptPath := ExpandConstant(
    '{app}\Packages\' + PackageName +
    '\Scripts\Install-RadIA.Package.ps1'
  );
  Result :=
    '-NoProfile -ExecutionPolicy Bypass -File ' +
    AddQuotes(ScriptPath) +
    ' -DelphiVersion ' + Version;
  if IDE64 then
    Result := Result + ' -IDE64';
  Result := Result + ' -Mode ' + Mode;
end;

function GetD12InstallParameters(Param: String): String;
begin
  Result := BuildPackageParameters('23.0-Win32', '23.0', 'Install', False);
end;

function GetD13Win32InstallParameters(Param: String): String;
begin
  Result := BuildPackageParameters('37.0-Win32', '37.0', 'Install', False);
end;

function GetD13Win64InstallParameters(Param: String): String;
begin
  Result := BuildPackageParameters('37.0-Win64', '37.0', 'Install', True);
end;

function GetD12UninstallParameters(Param: String): String;
begin
  Result := BuildPackageParameters('23.0-Win32', '23.0', 'Uninstall', False);
end;

function GetD13Win32UninstallParameters(Param: String): String;
begin
  Result := BuildPackageParameters('37.0-Win32', '37.0', 'Uninstall', False);
end;

function GetD13Win64UninstallParameters(Param: String): String;
begin
  Result := BuildPackageParameters('37.0-Win64', '37.0', 'Uninstall', True);
end;

procedure ExecutePackageInstaller(
  const Parameters: String;
  const Description: String
);
var
  ResultCode: Integer;
begin
  WizardForm.StatusLabel.Caption := Description;
  if not Exec(
    ExpandConstant('{sys}\WindowsPowerShell\v1.0\powershell.exe'),
    Parameters,
    '',
    SW_HIDE,
    ewWaitUntilTerminated,
    ResultCode
  ) or (ResultCode <> 0) then
    RaiseException(Description + ' failed with exit code ' + IntToStr(ResultCode) + '.');
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep <> ssPostInstall then
    Exit;
  if WizardIsComponentSelected('d12') then
    ExecutePackageInstaller(
      GetD12InstallParameters(''),
      'Installing RadIA for Delphi 12'
    );
  if WizardIsComponentSelected('d13win32') then
    ExecutePackageInstaller(
      GetD13Win32InstallParameters(''),
      'Installing RadIA for Delphi 13 Win32'
    );
  if WizardIsComponentSelected('d13win64') then
    ExecutePackageInstaller(
      GetD13Win64InstallParameters(''),
      'Installing RadIA for Delphi 13 IDE64'
    );
end;

function IsDelphiInstalled(const Version: String; const IDE64: Boolean): Boolean;
var
  RootDirectory: String;
  BinaryDirectory: String;
begin
  RootDirectory := ExpandConstant('{pf32}\Embarcadero\Studio\' + Version);
  if RegQueryStringValue(
    HKCU,
    'Software\Embarcadero\BDS\' + Version,
    'RootDir',
    RootDirectory
  ) then
  begin
    { Registry value resolved. }
  end;
  BinaryDirectory := 'bin';
  if IDE64 then
    BinaryDirectory := 'bin64';
  Result := FileExists(AddBackslash(RootDirectory) + BinaryDirectory + '\bds.exe');
end;

procedure InitializeWizard;
var
  SelectedComponents: String;
begin
  SelectedComponents := '';
  if IsDelphiInstalled('23.0', False) then
    SelectedComponents := SelectedComponents + 'd12,';
  if IsDelphiInstalled('37.0', False) then
    SelectedComponents := SelectedComponents + 'd13win32,';
  if IsDelphiInstalled('37.0', True) then
    SelectedComponents := SelectedComponents + 'd13win64,';
  if SelectedComponents <> '' then
    Delete(SelectedComponents, Length(SelectedComponents), 1);
  WizardSelectComponents(SelectedComponents);
end;
