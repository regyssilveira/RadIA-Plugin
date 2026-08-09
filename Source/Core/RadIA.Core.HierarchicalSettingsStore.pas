unit RadIA.Core.HierarchicalSettingsStore;

interface

uses
  System.JSON,
  RadIA.Core.HierarchicalSettings;

type
  TRadIASettingsScopeKind = (
    rssProject,
    rssSession
  );

  IRadIAHierarchicalSettingsStore = interface
    ['{59309327-373A-433B-B915-31DAB11D6B2C}']
    function Load(
      const AScopeKind: TRadIASettingsScopeKind;
      const AScopeId: string
    ): TRadIAExecutionSettings;
    procedure Save(
      const AScopeKind: TRadIASettingsScopeKind;
      const AScopeId: string;
      const ASettings: TRadIAExecutionSettings
    );
    procedure Clear(
      const AScopeKind: TRadIASettingsScopeKind;
      const AScopeId: string
    );
    function GetScopeFileName(
      const AScopeKind: TRadIASettingsScopeKind;
      const AScopeId: string
    ): string;
  end;

  TRadIAJsonHierarchicalSettingsStore = class(
    TInterfacedObject,
    IRadIAHierarchicalSettingsStore
  )
  private
    FLock: TObject;
    FRootPath: string;
    class function ScopeKindName(
      const AScopeKind: TRadIASettingsScopeKind
    ): string; static;
    class function ReadInteger(
      const AJson: TJSONObject;
      const AName: string
    ): Int64; static;
    class procedure SetInteger(
      const AJson: TJSONObject;
      const AName: string;
      const AValue: Int64
    ); static;
    class procedure SetString(
      const AJson: TJSONObject;
      const AName: string;
      const AValue: string
    ); static;
    class procedure AtomicWrite(
      const AFileName: string;
      const AContent: string
    ); static;
  public
    constructor Create(const ARootPath: string = '');
    destructor Destroy; override;
    class function DefaultRootPath: string; static;
    function Load(
      const AScopeKind: TRadIASettingsScopeKind;
      const AScopeId: string
    ): TRadIAExecutionSettings;
    procedure Save(
      const AScopeKind: TRadIASettingsScopeKind;
      const AScopeId: string;
      const ASettings: TRadIAExecutionSettings
    );
    procedure Clear(
      const AScopeKind: TRadIASettingsScopeKind;
      const AScopeId: string
    );
    function GetScopeFileName(
      const AScopeKind: TRadIASettingsScopeKind;
      const AScopeId: string
    ): string;
  end;

implementation

uses
  System.Hash,
  System.IOUtils,
  System.SysUtils,
  Winapi.Windows;

const
  CSchemaVersion = 1;
  CUnsetInteger = -1;

function RequireScopeId(const AScopeId: string): string;
begin
  Result := Trim(AScopeId);
  if Result = '' then
    raise EArgumentException.Create('The scope id is required.');
end;

function ParseObject(const AText, ASourceName: string): TJSONObject;
var
  LValue: TJSONValue;
begin
  LValue := TJSONObject.ParseJSONValue(AText);
  if not (LValue is TJSONObject) then
  begin
    LValue.Free;
    raise EConvertError.Create(
      'The hierarchical settings file is not a JSON object: ' + ASourceName
    );
  end;
  Result := TJSONObject(LValue);
end;

function GetSettingsObject(
  const ARoot: TJSONObject;
  const ACreate: Boolean
): TJSONObject;
var
  LValue: TJSONValue;
begin
  LValue := ARoot.GetValue('settings');
  if Assigned(LValue) and not (LValue is TJSONObject) then
    raise EConvertError.Create('The settings property must be a JSON object.');
  Result := TJSONObject(LValue);
  if not Assigned(Result) and ACreate then
  begin
    Result := TJSONObject.Create;
    ARoot.AddPair('settings', Result);
  end;
end;

{ TRadIAJsonHierarchicalSettingsStore }

constructor TRadIAJsonHierarchicalSettingsStore.Create(
  const ARootPath: string
);
begin
  inherited Create;
  FLock := TObject.Create;
  if Trim(ARootPath) = '' then
    FRootPath := DefaultRootPath
  else
    FRootPath := TPath.GetFullPath(ARootPath);
end;

destructor TRadIAJsonHierarchicalSettingsStore.Destroy;
begin
  FLock.Free;
  inherited Destroy;
end;

class function TRadIAJsonHierarchicalSettingsStore.DefaultRootPath: string;
var
  LAppDataPath: string;
begin
  LAppDataPath := GetEnvironmentVariable('APPDATA');
  if LAppDataPath = '' then
    LAppDataPath := TPath.GetHomePath;
  Result := TPath.Combine(LAppDataPath, 'RadIA\settings\scopes');
end;

class function TRadIAJsonHierarchicalSettingsStore.ScopeKindName(
  const AScopeKind: TRadIASettingsScopeKind
): string;
begin
  if AScopeKind = rssProject then
    Result := 'project'
  else
    Result := 'session';
end;

function TRadIAJsonHierarchicalSettingsStore.GetScopeFileName(
  const AScopeKind: TRadIASettingsScopeKind;
  const AScopeId: string
): string;
var
  LHash: string;
begin
  LHash := LowerCase(THashSHA2.GetHashString(
    ScopeKindName(AScopeKind) + ':' + LowerCase(RequireScopeId(AScopeId))
  ));
  Result := TPath.Combine(
    FRootPath,
    ScopeKindName(AScopeKind) + '-' + LHash + '.json'
  );
end;

class function TRadIAJsonHierarchicalSettingsStore.ReadInteger(
  const AJson: TJSONObject;
  const AName: string
): Int64;
var
  LValue: TJSONValue;
begin
  Result := CUnsetInteger;
  LValue := AJson.GetValue(AName);
  if Assigned(LValue) and not TryStrToInt64(LValue.Value, Result) then
    raise EConvertError.Create('Invalid integer setting: ' + AName);
end;

class procedure TRadIAJsonHierarchicalSettingsStore.SetInteger(
  const AJson: TJSONObject;
  const AName: string;
  const AValue: Int64
);
var
  LPair: TJSONPair;
begin
  LPair := AJson.RemovePair(AName);
  LPair.Free;
  if AValue >= 0 then
    AJson.AddPair(AName, TJSONNumber.Create(AValue));
end;

class procedure TRadIAJsonHierarchicalSettingsStore.SetString(
  const AJson: TJSONObject;
  const AName: string;
  const AValue: string
);
var
  LPair: TJSONPair;
begin
  LPair := AJson.RemovePair(AName);
  LPair.Free;
  if Trim(AValue) <> '' then
    AJson.AddPair(AName, Trim(AValue));
end;

class procedure TRadIAJsonHierarchicalSettingsStore.AtomicWrite(
  const AFileName: string;
  const AContent: string
);
var
  LTemporaryFileName: string;
begin
  TDirectory.CreateDirectory(ExtractFilePath(AFileName));
  LTemporaryFileName := AFileName + '.' +
    TGUID.NewGuid.ToString.Replace('{', '').Replace('}', '') + '.tmp';
  try
    TFile.WriteAllText(LTemporaryFileName, AContent, TEncoding.UTF8);
    if not MoveFileEx(
      PChar(LTemporaryFileName),
      PChar(AFileName),
      MOVEFILE_REPLACE_EXISTING or MOVEFILE_WRITE_THROUGH
    ) then
      RaiseLastOSError;
  finally
    if TFile.Exists(LTemporaryFileName) then
      TFile.Delete(LTemporaryFileName);
  end;
end;

function TRadIAJsonHierarchicalSettingsStore.Load(
  const AScopeKind: TRadIASettingsScopeKind;
  const AScopeId: string
): TRadIAExecutionSettings;
var
  LFileName: string;
  LJson: TJSONObject;
  LSettings: TJSONObject;
  LText: string;
begin
  LFileName := GetScopeFileName(AScopeKind, AScopeId);
  TMonitor.Enter(FLock);
  try
    if not TFile.Exists(LFileName) then
      Exit(TRadIAExecutionSettings.Empty);
    LText := TFile.ReadAllText(LFileName, TEncoding.UTF8);
    LJson := ParseObject(LText, LFileName);
    try
      LSettings := GetSettingsObject(LJson, False);
      if not Assigned(LSettings) then
        Exit(TRadIAExecutionSettings.Empty);
      Result := TRadIAExecutionSettings.Create(
        LSettings.GetValue<string>('provider', ''),
        LSettings.GetValue<string>('model', ''),
        LSettings.GetValue<string>('executor', ''),
        ReadInteger(LSettings, 'maxTokens'),
        ReadInteger(LSettings, 'timeoutMs'),
        ReadInteger(LSettings, 'tokenBudget')
      );
    finally
      LJson.Free;
    end;
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure TRadIAJsonHierarchicalSettingsStore.Save(
  const AScopeKind: TRadIASettingsScopeKind;
  const AScopeId: string;
  const ASettings: TRadIAExecutionSettings
);
var
  LFileName: string;
  LJson: TJSONObject;
  LPair: TJSONPair;
  LSettings: TJSONObject;
begin
  LFileName := GetScopeFileName(AScopeKind, AScopeId);
  TMonitor.Enter(FLock);
  try
    if TFile.Exists(LFileName) then
      LJson := ParseObject(
        TFile.ReadAllText(LFileName, TEncoding.UTF8),
        LFileName
      )
    else
      LJson := TJSONObject.Create;
    try
      LPair := LJson.RemovePair('schemaVersion');
      LPair.Free;
      LJson.AddPair('schemaVersion', TJSONNumber.Create(CSchemaVersion));
      LPair := LJson.RemovePair('scopeKind');
      LPair.Free;
      LJson.AddPair('scopeKind', ScopeKindName(AScopeKind));
      LSettings := GetSettingsObject(LJson, True);
      SetString(LSettings, 'provider', ASettings.ProviderId);
      SetString(LSettings, 'model', ASettings.ModelId);
      SetString(LSettings, 'executor', ASettings.ExecutorId);
      SetInteger(LSettings, 'maxTokens', ASettings.MaxTokens);
      SetInteger(LSettings, 'timeoutMs', ASettings.TimeoutMs);
      SetInteger(LSettings, 'tokenBudget', ASettings.TokenBudget);
      AtomicWrite(LFileName, LJson.Format(2));
    finally
      LJson.Free;
    end;
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure TRadIAJsonHierarchicalSettingsStore.Clear(
  const AScopeKind: TRadIASettingsScopeKind;
  const AScopeId: string
);
var
  LFileName: string;
begin
  LFileName := GetScopeFileName(AScopeKind, AScopeId);
  TMonitor.Enter(FLock);
  try
    if TFile.Exists(LFileName) then
      TFile.Delete(LFileName);
  finally
    TMonitor.Exit(FLock);
  end;
end;

end.
