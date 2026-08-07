unit RadIA.Core.FastMM5;

interface

uses
  RadIA.Core.MemoryDiagnostics,
  RadIA.Core.SettingsStorage,
  RadIA.Core.Tools;

type
  TRadIAFastMM5Settings = record
  private
    FLicenseAcknowledged: Boolean;
    FLimits: TRadIAMemoryDiagnosticsLimits;
    FRootPath: string;
  public
    constructor Create(
      const ARootPath: string;
      const ALicenseAcknowledged: Boolean;
      const ALimits: TRadIAMemoryDiagnosticsLimits
    );
    property LicenseAcknowledged: Boolean read FLicenseAcknowledged;
    property Limits: TRadIAMemoryDiagnosticsLimits read FLimits;
    property RootPath: string read FRootPath;
  end;

  TRadIAFastMM5SettingsStore = class
  private
    FSettingsPath: string;
    FStorage: IRadIASettingsStorage;
  public
    constructor Create(
      const AStorage: IRadIASettingsStorage = nil;
      const ASettingsPath: string = ''
    );
    function Load: TRadIAFastMM5Settings;
    procedure Save(const ASettings: TRadIAFastMM5Settings);
  end;

  TRadIAFastMM5Detector = class
  private
    function FindVersion(const AUnitPath: string): string;
    function ResolveDebugLibrary(
      const ARootPath: string;
      const ATargetPlatform: string
    ): string;
  public
    function Detect(
      const ASettings: TRadIAFastMM5Settings;
      const ATargetPlatform: string
    ): TRadIAMemoryBackendStatus;
  end;

procedure RegisterRadIAFastMM5Tools(
  const ARegistry: IRadIAToolRegistry
);

implementation

uses
  System.IOUtils,
  System.JSON,
  System.SysUtils,
  RadIA.Core.Config;

type
  TRadIAFastMM5StatusTool = class(TInterfacedObject, IRadIATool)
  public
    function Execute(
      const ARequest: TRadIAToolRequest
    ): TRadIAToolResult;
    function GetDescriptor: TRadIAToolDescriptor;
  end;

  TRadIAConfigureFastMM5Tool = class(TInterfacedObject, IRadIATool)
  public
    function Execute(
      const ARequest: TRadIAToolRequest
    ): TRadIAToolResult;
    function GetDescriptor: TRadIAToolDescriptor;
  end;

const
  CDefaultDurationMs = 120000;
  CDefaultLogBytes = 52428800;
  CDefaultRepetitions = 10;
  CEmptyInputSchema =
    '{"type":"object","additionalProperties":false}';
  CConfigureInputSchema =
    '{"type":"object","required":["rootPath","licenseAcknowledged"],' +
    '"properties":{"rootPath":{"type":"string","minLength":1},' +
    '"licenseAcknowledged":{"type":"boolean"}},"additionalProperties":false}';

constructor TRadIAFastMM5Settings.Create(
  const ARootPath: string;
  const ALicenseAcknowledged: Boolean;
  const ALimits: TRadIAMemoryDiagnosticsLimits
);
begin
  FRootPath := Trim(ARootPath);
  FLicenseAcknowledged := ALicenseAcknowledged;
  FLimits := ALimits;
end;

constructor TRadIAFastMM5SettingsStore.Create(
  const AStorage: IRadIASettingsStorage;
  const ASettingsPath: string
);
begin
  inherited Create;
  if Assigned(AStorage) then
    FStorage := AStorage
  else
    FStorage := TRadIARegistrySettingsStorage.Create;
  FSettingsPath := Trim(ASettingsPath);
  if FSettingsPath.IsEmpty then
    FSettingsPath := TRadIAConfig.GetRegistryPath + '\MemoryDiagnostics';
end;

function TRadIAFastMM5SettingsStore.Load: TRadIAFastMM5Settings;
var
  LAcknowledged: Boolean;
  LDurationMs: Integer;
  LLogBytes: Int64;
  LRepetitions: Integer;
  LRootPath: string;
begin
  if not FStorage.OpenKey(FSettingsPath, False) then
    Exit(
      TRadIAFastMM5Settings.Create(
        '',
        False,
        TRadIAMemoryDiagnosticsLimits.Create(
          CDefaultDurationMs,
          CDefaultLogBytes,
          CDefaultRepetitions
        )
      )
    );
  try
    LRootPath := FStorage.ReadString('RootPath', '');
    LAcknowledged := FStorage.ReadInteger('LicenseAcknowledged', 0) = 1;
    LDurationMs := FStorage.ReadInteger(
      'MaxDurationMs',
      CDefaultDurationMs
    );
    LLogBytes := StrToInt64Def(
      FStorage.ReadString('MaxLogBytes', IntToStr(CDefaultLogBytes)),
      CDefaultLogBytes
    );
    LRepetitions := FStorage.ReadInteger(
      'MaxRepetitions',
      CDefaultRepetitions
    );
    Result := TRadIAFastMM5Settings.Create(
      LRootPath,
      LAcknowledged,
      TRadIAMemoryDiagnosticsLimits.Create(
        LDurationMs,
        LLogBytes,
        LRepetitions
      )
    );
  finally
    FStorage.CloseKey;
  end;
end;

procedure TRadIAFastMM5SettingsStore.Save(
  const ASettings: TRadIAFastMM5Settings
);
begin
  if not ASettings.Limits.IsValid then
    raise EArgumentException.Create('Memory diagnostic limits are invalid.');
  if not FStorage.OpenKey(FSettingsPath, True) then
    raise EInOutError.Create('Unable to open memory diagnostic settings.');
  try
    FStorage.WriteString('RootPath', ASettings.RootPath);
    FStorage.WriteInteger(
      'LicenseAcknowledged',
      Ord(ASettings.LicenseAcknowledged)
    );
    FStorage.WriteInteger(
      'MaxDurationMs',
      ASettings.Limits.MaxDurationMs
    );
    FStorage.WriteString(
      'MaxLogBytes',
      IntToStr(ASettings.Limits.MaxLogBytes)
    );
    FStorage.WriteInteger(
      'MaxRepetitions',
      ASettings.Limits.MaxRepetitions
    );
  finally
    FStorage.CloseKey;
  end;
end;

function TRadIAFastMM5Detector.FindVersion(
  const AUnitPath: string
): string;
var
  LContent: string;
  LEndIndex: Integer;
  LStartIndex: Integer;
  LValue: Integer;
begin
  Result := '';
  LContent := TFile.ReadAllText(AUnitPath, TEncoding.UTF8);
  LStartIndex := Pos('CFastMM_Version =', LContent);
  if LStartIndex = 0 then
    Exit;
  Inc(LStartIndex, Length('CFastMM_Version ='));
  while (LStartIndex <= Length(LContent)) and
    CharInSet(LContent[LStartIndex], [' ', #9]) do
    Inc(LStartIndex);
  LEndIndex := LStartIndex;
  while (LEndIndex <= Length(LContent)) and
    CharInSet(LContent[LEndIndex], ['0'..'9']) do
    Inc(LEndIndex);
  if not TryStrToInt(
    Copy(LContent, LStartIndex, LEndIndex - LStartIndex),
    LValue
  ) then
    Exit;
  Result := Format('%d.%.2d', [LValue div 100, LValue mod 100]);
end;

function TRadIAFastMM5Detector.ResolveDebugLibrary(
  const ARootPath: string;
  const ATargetPlatform: string
): string;
var
  LLibraryName: string;
begin
  if SameText(ATargetPlatform, 'Win64') then
    LLibraryName := 'FastMM_FullDebugMode64.dll'
  else
    LLibraryName := 'FastMM_FullDebugMode.dll';
  Result := TPath.Combine(
    TPath.Combine(ARootPath, 'FullDebugMode DLL\Precompiled'),
    LLibraryName
  );
end;

function TRadIAFastMM5Detector.Detect(
  const ASettings: TRadIAFastMM5Settings;
  const ATargetPlatform: string
): TRadIAMemoryBackendStatus;
var
  LDebugLibrary: string;
  LRootPath: string;
  LUnitPath: string;
  LVersion: string;
begin
  LRootPath := ASettings.RootPath;
  if LRootPath.IsEmpty then
    Exit(
      TRadIAMemoryBackendStatus.Create(
        mbkFastMM5,
        mbsUnavailable,
        '',
        '',
        '',
        ATargetPlatform,
        'Configure the FastMM5 root directory.'
      )
    );
  LUnitPath := TPath.Combine(LRootPath, 'FastMM5.pas');
  LDebugLibrary := ResolveDebugLibrary(LRootPath, ATargetPlatform);
  if not TFile.Exists(LUnitPath) or not TFile.Exists(LDebugLibrary) then
    Exit(
      TRadIAMemoryBackendStatus.Create(
        mbkFastMM5,
        mbsInvalid,
        '',
        LRootPath,
        LDebugLibrary,
        ATargetPlatform,
        'FastMM5 source or the FullDebugMode library is missing.'
      )
    );
  LVersion := FindVersion(LUnitPath);
  if LVersion.IsEmpty then
    Exit(
      TRadIAMemoryBackendStatus.Create(
        mbkFastMM5,
        mbsIncompatible,
        '',
        LRootPath,
        LDebugLibrary,
        ATargetPlatform,
        'The FastMM5 version could not be identified.'
      )
    );
  if not ASettings.LicenseAcknowledged then
    Exit(
      TRadIAMemoryBackendStatus.Create(
        mbkFastMM5,
        mbsInvalid,
        LVersion,
        LRootPath,
        LDebugLibrary,
        ATargetPlatform,
        'Acknowledge the FastMM5 license before enabling diagnostics.'
      )
    );
  Result := TRadIAMemoryBackendStatus.Create(
    mbkFastMM5,
    mbsReady,
    LVersion,
    LRootPath,
    LDebugLibrary,
    ATargetPlatform,
    'FastMM5 is ready for memory diagnostics.'
  );
end;

function BuildStatusJson(
  const AStatus: TRadIAMemoryBackendStatus
): string;
var
  LRoot: TJSONObject;
begin
  LRoot := TJSONObject.Create;
  try
    LRoot.AddPair('backend', 'fastmm5');
    LRoot.AddPair('state', Ord(AStatus.State));
    LRoot.AddPair('ready', TJSONBool.Create(AStatus.IsReady));
    LRoot.AddPair('version', AStatus.BackendVersion);
    LRoot.AddPair('rootPath', AStatus.RootPath);
    LRoot.AddPair('debugLibraryPath', AStatus.DebugLibraryPath);
    LRoot.AddPair('targetPlatform', AStatus.TargetPlatform);
    LRoot.AddPair('message', AStatus.Message);
    Result := LRoot.ToJSON;
  finally
    LRoot.Free;
  end;
end;

function DetectConfiguredFastMM5: TRadIAMemoryBackendStatus;
var
  LDetector: TRadIAFastMM5Detector;
  LSettings: TRadIAFastMM5Settings;
  LStore: TRadIAFastMM5SettingsStore;
begin
  LStore := TRadIAFastMM5SettingsStore.Create;
  try
    LSettings := LStore.Load;
  finally
    LStore.Free;
  end;
  LDetector := TRadIAFastMM5Detector.Create;
  try
    {$IFDEF WIN64}
    Result := LDetector.Detect(LSettings, 'Win64');
    {$ELSE}
    Result := LDetector.Detect(LSettings, 'Win32');
    {$ENDIF}
  finally
    LDetector.Free;
  end;
end;

function TRadIAFastMM5StatusTool.Execute(
  const ARequest: TRadIAToolRequest
): TRadIAToolResult;
begin
  Result := TRadIAToolResult.Succeeded(
    BuildStatusJson(DetectConfiguredFastMM5)
  );
end;

function TRadIAFastMM5StatusTool.GetDescriptor: TRadIAToolDescriptor;
begin
  Result := TRadIAToolDescriptor.Create(
    'GetMemoryDiagnosticsStatus',
    '1.0.0',
    'Checks FastMM5 configuration, version, license acknowledgement, and runtime library readiness.',
    CEmptyInputSchema,
    '{"type":"object"}',
    trReadOnly
  );
end;

function TRadIAConfigureFastMM5Tool.Execute(
  const ARequest: TRadIAToolRequest
): TRadIAToolResult;
var
  LAcknowledged: Boolean;
  LArguments: TJSONObject;
  LRootPath: string;
  LSettings: TRadIAFastMM5Settings;
  LStore: TRadIAFastMM5SettingsStore;
begin
  LArguments := TJSONObject.ParseJSONValue(
    ARequest.ArgumentsJson
  ) as TJSONObject;
  if not Assigned(LArguments) then
    Exit(TRadIAToolResult.Failed('invalid_arguments', 'Invalid JSON.'));
  try
    if not LArguments.TryGetValue<string>('rootPath', LRootPath) or
      not LArguments.TryGetValue<Boolean>(
        'licenseAcknowledged',
        LAcknowledged
      ) then
      Exit(
        TRadIAToolResult.Failed(
          'missing_arguments',
          'rootPath and licenseAcknowledged are required.'
        )
      );
  finally
    LArguments.Free;
  end;
  LSettings := TRadIAFastMM5Settings.Create(
    LRootPath,
    LAcknowledged,
    TRadIAMemoryDiagnosticsLimits.Create(
      CDefaultDurationMs,
      CDefaultLogBytes,
      CDefaultRepetitions
    )
  );
  LStore := TRadIAFastMM5SettingsStore.Create;
  try
    LStore.Save(LSettings);
  finally
    LStore.Free;
  end;
  Result := TRadIAToolResult.Succeeded(
    BuildStatusJson(DetectConfiguredFastMM5)
  );
end;

function TRadIAConfigureFastMM5Tool.GetDescriptor:
  TRadIAToolDescriptor;
begin
  Result := TRadIAToolDescriptor.Create(
    'ConfigureMemoryDiagnostics',
    '1.0.0',
    'Stores the user-provided FastMM5 root and explicit license acknowledgement, then reports readiness.',
    CConfigureInputSchema,
    '{"type":"object"}',
    trStructuralWrite
  );
end;

procedure RegisterRadIAFastMM5Tools(
  const ARegistry: IRadIAToolRegistry
);
begin
  if not Assigned(ARegistry) then
    raise EArgumentNilException.Create('ARegistry');
  ARegistry.RegisterTool(TRadIAFastMM5StatusTool.Create);
  ARegistry.RegisterTool(TRadIAConfigureFastMM5Tool.Create);
end;

end.
