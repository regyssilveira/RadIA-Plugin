unit RadIA.Core.DeclarativeExtensions;

interface

uses
  System.Generics.Collections,
  System.JSON;

const
  CRadIADeclarativeExtensionSchemaVersion = 3;

type
  TRadIADeclarativeCommand = record
  private
    FExtensionId: string;
    FKind: string;
    FName: string;
    FDescription: string;
    FSlashCommand: string;
    FPrompt: string;
  public
    constructor Create(
      const AExtensionId: string;
      const AKind: string;
      const AName: string;
      const ADescription: string;
      const ASlashCommand: string;
      const APrompt: string
    );
    property ExtensionId: string read FExtensionId;
    property Kind: string read FKind;
    property Name: string read FName;
    property Description: string read FDescription;
    property SlashCommand: string read FSlashCommand;
    property Prompt: string read FPrompt;
  end;

  TRadIADeclarativeTool = record
  private
    FExtensionId: string;
    FName: string;
    FDescription: string;
    FTargetTool: string;
  public
    constructor Create(
      const AExtensionId: string;
      const AName: string;
      const ADescription: string;
      const ATargetTool: string
    );
    property ExtensionId: string read FExtensionId;
    property Name: string read FName;
    property Description: string read FDescription;
    property TargetTool: string read FTargetTool;
  end;

  TRadIADeclarativeExtensionDiagnostic = record
  private
    FFileName: string;
    FExtensionId: string;
    FStatus: string;
    FMessage: string;
  public
    constructor Create(
      const AFileName: string;
      const AExtensionId: string;
      const AStatus: string;
      const AMessage: string
    );
    property FileName: string read FFileName;
    property ExtensionId: string read FExtensionId;
    property Status: string read FStatus;
    property Message: string read FMessage;
  end;

  TRadIADeclarativeExtensionManager = class
  private
    FDirectory: string;
    FCommands: TList<TRadIADeclarativeCommand>;
    FTools: TList<TRadIADeclarativeTool>;
    FDiagnostics: TList<TRadIADeclarativeExtensionDiagnostic>;
    procedure AtomicWrite(
      const AFileName: string;
      const AContent: TArray<Byte>
    );
    function FindDiagnostic(
      const AExtensionId: string;
      out ADiagnostic: TRadIADeclarativeExtensionDiagnostic
    ): Boolean;
    function IsAcceptedFile(
      const AFileName: string;
      const AExtensionId: string;
      out AMessage: string
    ): Boolean;
    function ValidateCandidate(
      const ASourceFileName: string;
      const AReservedCommands: TArray<string>;
      out AExtensionId: string;
      out AMessage: string
    ): Boolean;
    function IsReserved(
      const ACommand: string;
      const AReservedCommands: TArray<string>
    ): Boolean;
    procedure LoadManifest(
      const AFileName: string;
      const AReservedCommands: TArray<string>
    );
    function ParseCommand(
      const AJson: TJSONObject;
      const AExtensionId: string;
      const AReservedCommands: TArray<string>;
      const AExistingCommands: TArray<TRadIADeclarativeCommand>;
      const AKind: string;
      const APromptField: string
    ): TRadIADeclarativeCommand;
    procedure ParseCapabilityArray(
      const AJson: TJSONObject;
      const AArrayName: string;
      const AKind: string;
      const APromptField: string;
      const AExtensionId: string;
      const AReservedCommands: TArray<string>;
      const ACommands: TList<TRadIADeclarativeCommand>
    );
    function ParseCommands(
      const AJson: TJSONObject;
      const AExtensionId: string;
      const AReservedCommands: TArray<string>;
      const ASchemaVersion: Integer
    ): TArray<TRadIADeclarativeCommand>;
    function ParseTools(
      const AJson: TJSONObject;
      const AExtensionId: string;
      const ASchemaVersion: Integer
    ): TArray<TRadIADeclarativeTool>;
    function ParseTool(
      const AJson: TJSONObject;
      const AExtensionId: string
    ): TRadIADeclarativeTool;
    procedure ValidateToolFields(
      const AExtensionId: string;
      const AName: string;
      const ADescription: string;
      const ATargetTool: string
    );
    procedure ValidateCommandFields(
      const AName: string;
      const ADescription: string;
      const ASlashCommand: string;
      const APrompt: string
    );
    procedure ValidateManifestIdentity(
      const AExtensionId: string;
      const AVersion: string
    );
    procedure ValidatePermissions(
      const AJson: TJSONObject;
      const AHasPromptCapabilities: Boolean;
      const AHasTools: Boolean
    );
  public
    constructor Create(const ADirectory: string);
    destructor Destroy; override;
    function InstallOrUpdate(
      const ASourceFileName: string;
      const AReservedCommands: TArray<string>;
      out AExtensionId: string;
      out AMessage: string
    ): Boolean;
    function Remove(
      const AExtensionId: string;
      const AReservedCommands: TArray<string>;
      out AMessage: string
    ): Boolean;
    function RemoveManifest(
      const AFileName: string;
      const AReservedCommands: TArray<string>;
      out AMessage: string
    ): Boolean;
    procedure Reload(const AReservedCommands: TArray<string>);
    procedure ReportRuntimeError(const AMessage: string);
    function SetEnabled(
      const AExtensionId: string;
      const AEnabled: Boolean;
      const AReservedCommands: TArray<string>;
      out AMessage: string
    ): Boolean;
    function GetCommands: TArray<TRadIADeclarativeCommand>;
    function GetTools: TArray<TRadIADeclarativeTool>;
    function GetDiagnostics:
      TArray<TRadIADeclarativeExtensionDiagnostic>;
    function TryResolve(
      const ASlashCommand: string;
      out ACommand: TRadIADeclarativeCommand
    ): Boolean;
  end;

implementation

uses
  System.IOUtils,
  System.RegularExpressions,
  System.SysUtils,
  Winapi.Windows;

const
  CCommandPermission = 'chat.prompt';
  CToolAliasPermission = 'tool.alias';
  CMaximumCommandsPerExtension = 100;
  CMaximumDescriptionLength = 500;
  CMaximumManifestBytes = 1048576;
  CMaximumPromptLength = 32768;

procedure TRadIADeclarativeExtensionManager.AtomicWrite(
  const AFileName: string;
  const AContent: TArray<Byte>
);
var
  LTemporaryFileName: string;
begin
  TDirectory.CreateDirectory(ExtractFilePath(AFileName));
  LTemporaryFileName := AFileName + '.' +
    TGUID.NewGuid.ToString.Replace('{', '').Replace('}', '') + '.tmp';
  try
    TFile.WriteAllBytes(LTemporaryFileName, AContent);
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

function IsPascalIdentifier(const AValue: string): Boolean;
var
  LCharacter: Char;
  LIndex: Integer;
begin
  Result := False;
  if (AValue = '') or
    not CharInSet(AValue[Low(AValue)], ['A'..'Z']) then
    Exit;
  for LIndex := Low(AValue) to High(AValue) do
  begin
    LCharacter := AValue[LIndex];
    if not CharInSet(
      LCharacter,
      ['A'..'Z', 'a'..'z', '0'..'9']
    ) then
      Exit;
  end;
  Result := True;
end;

function IsValidSlashCommand(const AValue: string): Boolean;
begin
  Result := TRegEx.IsMatch(
    AValue,
    '^/[a-z][a-z0-9-]{1,31}$',
    [roIgnoreCase]
  );
end;

{ TRadIADeclarativeCommand }

constructor TRadIADeclarativeCommand.Create(
  const AExtensionId: string;
  const AKind: string;
  const AName: string;
  const ADescription: string;
  const ASlashCommand: string;
  const APrompt: string
);
begin
  FExtensionId := AExtensionId;
  FKind := AKind;
  FName := AName;
  FDescription := ADescription;
  FSlashCommand := ASlashCommand;
  FPrompt := APrompt;
end;

{ TRadIADeclarativeTool }

constructor TRadIADeclarativeTool.Create(
  const AExtensionId: string;
  const AName: string;
  const ADescription: string;
  const ATargetTool: string
);
begin
  FExtensionId := AExtensionId;
  FName := AName;
  FDescription := ADescription;
  FTargetTool := ATargetTool;
end;

{ TRadIADeclarativeExtensionDiagnostic }

constructor TRadIADeclarativeExtensionDiagnostic.Create(
  const AFileName: string;
  const AExtensionId: string;
  const AStatus: string;
  const AMessage: string
);
begin
  FFileName := AFileName;
  FExtensionId := AExtensionId;
  FStatus := AStatus;
  FMessage := AMessage;
end;

{ TRadIADeclarativeExtensionManager }

constructor TRadIADeclarativeExtensionManager.Create(
  const ADirectory: string
);
begin
  inherited Create;
  if Trim(ADirectory) = '' then
    raise EArgumentException.Create(
      'Declarative extension directory cannot be empty.'
    );
  FDirectory := TPath.GetFullPath(ADirectory);
  FCommands := TList<TRadIADeclarativeCommand>.Create;
  FTools := TList<TRadIADeclarativeTool>.Create;
  FDiagnostics := TList<TRadIADeclarativeExtensionDiagnostic>.Create;
end;

destructor TRadIADeclarativeExtensionManager.Destroy;
begin
  FDiagnostics.Free;
  FTools.Free;
  FCommands.Free;
  inherited Destroy;
end;

function TRadIADeclarativeExtensionManager.FindDiagnostic(
  const AExtensionId: string;
  out ADiagnostic: TRadIADeclarativeExtensionDiagnostic
): Boolean;
var
  LDiagnostic: TRadIADeclarativeExtensionDiagnostic;
begin
  ADiagnostic := Default(TRadIADeclarativeExtensionDiagnostic);
  for LDiagnostic in FDiagnostics do
    if SameText(LDiagnostic.ExtensionId, AExtensionId) then
    begin
      ADiagnostic := LDiagnostic;
      Exit(True);
    end;
  Result := False;
end;

function TRadIADeclarativeExtensionManager.GetCommands:
  TArray<TRadIADeclarativeCommand>;
begin
  Result := FCommands.ToArray;
end;

function TRadIADeclarativeExtensionManager.GetDiagnostics:
  TArray<TRadIADeclarativeExtensionDiagnostic>;
begin
  Result := FDiagnostics.ToArray;
end;

function TRadIADeclarativeExtensionManager.GetTools:
  TArray<TRadIADeclarativeTool>;
begin
  Result := FTools.ToArray;
end;

function TRadIADeclarativeExtensionManager.InstallOrUpdate(
  const ASourceFileName: string;
  const AReservedCommands: TArray<string>;
  out AExtensionId: string;
  out AMessage: string
): Boolean;
var
  LBackup: TArray<Byte>;
  LContent: TArray<Byte>;
  LExistingDiagnostic: TRadIADeclarativeExtensionDiagnostic;
  LHadExistingFile: Boolean;
  LTargetFileName: string;
begin
  Result := False;
  AExtensionId := '';
  AMessage := '';
  if not ValidateCandidate(
    ASourceFileName,
    AReservedCommands,
    AExtensionId,
    AMessage
  ) then
    Exit;

  Reload(AReservedCommands);
  if FindDiagnostic(AExtensionId, LExistingDiagnostic) then
    LTargetFileName := LExistingDiagnostic.FileName
  else
    LTargetFileName := TPath.Combine(
      FDirectory,
      AExtensionId + '.radia.json'
    );
  LHadExistingFile := TFile.Exists(LTargetFileName);
  if LHadExistingFile then
    LBackup := TFile.ReadAllBytes(LTargetFileName);
  LContent := TFile.ReadAllBytes(ASourceFileName);
  try
    AtomicWrite(LTargetFileName, LContent);
    Reload(AReservedCommands);
    if not IsAcceptedFile(
      LTargetFileName,
      AExtensionId,
      AMessage
    ) then
      raise EInvalidOpException.Create(AMessage);
    AMessage := 'Extension installed and activated without restarting the IDE.';
    Result := True;
  except
    on E: Exception do
    begin
      if LHadExistingFile then
        AtomicWrite(LTargetFileName, LBackup)
      else if TFile.Exists(LTargetFileName) then
        TFile.Delete(LTargetFileName);
      Reload(AReservedCommands);
      AMessage := 'Install rolled back: ' + E.Message;
    end;
  end;
end;

function TRadIADeclarativeExtensionManager.ValidateCandidate(
  const ASourceFileName: string;
  const AReservedCommands: TArray<string>;
  out AExtensionId: string;
  out AMessage: string
): Boolean;
var
  LDiagnostic: TRadIADeclarativeExtensionDiagnostic;
  LFileName: string;
  LManager: TRadIADeclarativeExtensionManager;
  LTemporaryDirectory: string;
begin
  Result := False;
  AExtensionId := '';
  AMessage := '';
  if not TFile.Exists(ASourceFileName) then
  begin
    AMessage := 'The selected manifest does not exist.';
    Exit;
  end;
  if (GetFileAttributes(PChar(ASourceFileName)) and
    FILE_ATTRIBUTE_REPARSE_POINT) <> 0 then
  begin
    AMessage := 'Manifest reparse points are not allowed.';
    Exit;
  end;
  LTemporaryDirectory := TPath.Combine(
    TPath.GetTempPath,
    'RadIA-ExtensionValidation-' + TGUID.NewGuid.ToString
  );
  TDirectory.CreateDirectory(LTemporaryDirectory);
  try
    LFileName := TPath.Combine(
      LTemporaryDirectory,
      'candidate.radia.json'
    );
    TFile.Copy(ASourceFileName, LFileName);
    LManager := TRadIADeclarativeExtensionManager.Create(
      LTemporaryDirectory
    );
    try
      LManager.Reload(AReservedCommands);
      if Length(LManager.GetDiagnostics) <> 1 then
      begin
        AMessage := 'The selected manifest could not be validated.';
        Exit;
      end;
      LDiagnostic := LManager.GetDiagnostics[0];
      AMessage := LDiagnostic.Message;
      if SameText(LDiagnostic.Status, 'rejected') then
        Exit;
      AExtensionId := LDiagnostic.ExtensionId;
      Result := True;
    finally
      LManager.Free;
    end;
  finally
    if TDirectory.Exists(LTemporaryDirectory) then
      TDirectory.Delete(LTemporaryDirectory, True);
  end;
end;

function TRadIADeclarativeExtensionManager.IsAcceptedFile(
  const AFileName: string;
  const AExtensionId: string;
  out AMessage: string
): Boolean;
var
  LDiagnostic: TRadIADeclarativeExtensionDiagnostic;
begin
  for LDiagnostic in FDiagnostics do
    if SameFileName(LDiagnostic.FileName, AFileName) then
    begin
      AMessage := LDiagnostic.Message;
      Exit(
        SameText(LDiagnostic.ExtensionId, AExtensionId) and
        (SameText(LDiagnostic.Status, 'loaded') or
        SameText(LDiagnostic.Status, 'disabled'))
      );
    end;
  AMessage := 'The installed manifest was not found after reload.';
  Result := False;
end;

function TRadIADeclarativeExtensionManager.IsReserved(
  const ACommand: string;
  const AReservedCommands: TArray<string>
): Boolean;
var
  LCommand: TRadIADeclarativeCommand;
  LReservedCommand: string;
begin
  for LReservedCommand in AReservedCommands do
    if SameText(LReservedCommand, ACommand) then
      Exit(True);
  for LCommand in FCommands do
    if SameText(LCommand.SlashCommand, ACommand) then
      Exit(True);
  Result := False;
end;

function TRadIADeclarativeExtensionManager.Remove(
  const AExtensionId: string;
  const AReservedCommands: TArray<string>;
  out AMessage: string
): Boolean;
var
  LDiagnostic: TRadIADeclarativeExtensionDiagnostic;
begin
  Result := False;
  Reload(AReservedCommands);
  if not FindDiagnostic(AExtensionId, LDiagnostic) then
  begin
    AMessage := 'The extension was not found.';
    Exit;
  end;
  Result := RemoveManifest(
    LDiagnostic.FileName,
    AReservedCommands,
    AMessage
  );
end;

function TRadIADeclarativeExtensionManager.RemoveManifest(
  const AFileName: string;
  const AReservedCommands: TArray<string>;
  out AMessage: string
): Boolean;
var
  LDiagnostic: TRadIADeclarativeExtensionDiagnostic;
  LKnownManifest: Boolean;
begin
  Result := False;
  LKnownManifest := False;
  Reload(AReservedCommands);
  for LDiagnostic in FDiagnostics do
    if SameFileName(LDiagnostic.FileName, AFileName) then
    begin
      LKnownManifest := True;
      Break;
    end;
  if not LKnownManifest then
  begin
    AMessage := 'The manifest is not managed by Rad IA.';
    Exit;
  end;
  try
    TFile.Delete(AFileName);
    Reload(AReservedCommands);
    AMessage := 'Extension removed.';
    Result := True;
  except
    on E: Exception do
      AMessage := 'Unable to remove extension: ' + E.Message;
  end;
end;

procedure TRadIADeclarativeExtensionManager.LoadManifest(
  const AFileName: string;
  const AReservedCommands: TArray<string>
);
var
  LCommands: TArray<TRadIADeclarativeCommand>;
  LDiagnostic: TRadIADeclarativeExtensionDiagnostic;
  LEnabled: Boolean;
  LExtensionId: string;
  LHasPromptCapabilities: Boolean;
  LHasTools: Boolean;
  LJson: TJSONObject;
  LSchemaVersion: Integer;
  LTools: TArray<TRadIADeclarativeTool>;
  LVersion: string;
begin
  if TFile.GetSize(AFileName) > CMaximumManifestBytes then
    raise EArgumentException.Create(
      'Manifest exceeds the 1 MiB size limit.'
    );
  if (GetFileAttributes(PChar(AFileName)) and
    FILE_ATTRIBUTE_REPARSE_POINT) <> 0 then
    raise EArgumentException.Create(
      'Manifest reparse points are not allowed.'
    );
  LJson := TJSONObject.ParseJSONValue(
    TFile.ReadAllText(AFileName, TEncoding.UTF8)
  ) as TJSONObject;
  if not Assigned(LJson) then
    raise EArgumentException.Create('Manifest root must be a JSON object.');
  try
    LSchemaVersion := LJson.GetValue<Integer>('schemaVersion', 0);
    if (LSchemaVersion < 1) or
      (LSchemaVersion > CRadIADeclarativeExtensionSchemaVersion) then
      raise EArgumentException.Create(
        'Unsupported declarative extension schema version.'
      );
    LExtensionId := Trim(LJson.GetValue<string>('id', ''));
    LVersion := Trim(LJson.GetValue<string>('version', ''));
    ValidateManifestIdentity(LExtensionId, LVersion);
    for LDiagnostic in FDiagnostics do
      if SameText(LDiagnostic.ExtensionId, LExtensionId) then
        raise EArgumentException.Create(
          'Extension ID is already loaded from another manifest.'
        );
    LEnabled := LJson.GetValue<Boolean>('enabled', True);
    LHasPromptCapabilities :=
      Assigned(LJson.GetValue('commands')) or
      Assigned(LJson.GetValue('templates')) or
      Assigned(LJson.GetValue('skills'));
    LHasTools := Assigned(LJson.GetValue('tools'));
    ValidatePermissions(
      LJson,
      LHasPromptCapabilities,
      LHasTools
    );
    if not LEnabled then
    begin
      FDiagnostics.Add(
        TRadIADeclarativeExtensionDiagnostic.Create(
          AFileName,
          LExtensionId,
          'disabled',
          'Extension is disabled by its manifest.'
        )
      );
      Exit;
    end;
    LCommands := ParseCommands(
      LJson,
      LExtensionId,
      AReservedCommands,
      LSchemaVersion
    );
    LTools := ParseTools(LJson, LExtensionId, LSchemaVersion);
    if (Length(LCommands) + Length(LTools) = 0) or
      (Length(LCommands) + Length(LTools) >
        CMaximumCommandsPerExtension) then
      raise EArgumentException.Create(
        'Manifest must contain between 1 and 100 capabilities.'
      );
    FCommands.AddRange(LCommands);
    FTools.AddRange(LTools);
    FDiagnostics.Add(
      TRadIADeclarativeExtensionDiagnostic.Create(
        AFileName,
        LExtensionId,
        'loaded',
        Format(
          '%d capability item(s) loaded.',
          [Length(LCommands) + Length(LTools)]
        )
      )
    );
  finally
    LJson.Free;
  end;
end;

function TRadIADeclarativeExtensionManager.ParseCommand(
  const AJson: TJSONObject;
  const AExtensionId: string;
  const AReservedCommands: TArray<string>;
  const AExistingCommands: TArray<TRadIADeclarativeCommand>;
  const AKind: string;
  const APromptField: string
): TRadIADeclarativeCommand;
var
  LDescription: string;
  LExistingCommand: TRadIADeclarativeCommand;
  LName: string;
  LPrompt: string;
  LSlashCommand: string;
begin
  LName := Trim(AJson.GetValue<string>('name', ''));
  LDescription := Trim(AJson.GetValue<string>('description', ''));
  LSlashCommand := LowerCase(
    Trim(AJson.GetValue<string>('command', ''))
  );
  LPrompt := Trim(AJson.GetValue<string>(APromptField, ''));
  ValidateCommandFields(
    LName,
    LDescription,
    LSlashCommand,
    LPrompt
  );
  if IsReserved(LSlashCommand, AReservedCommands) then
    raise EArgumentException.Create(
      'Command collides with an existing slash command.'
    );
  for LExistingCommand in AExistingCommands do
    if SameText(
      LExistingCommand.SlashCommand,
      LSlashCommand
    ) then
      raise EArgumentException.Create(
        'Manifest contains duplicate slash commands.'
      );
  Result := TRadIADeclarativeCommand.Create(
    AExtensionId,
    AKind,
    LName,
    LDescription,
    LSlashCommand,
    LPrompt
  );
end;

procedure TRadIADeclarativeExtensionManager.ParseCapabilityArray(
  const AJson: TJSONObject;
  const AArrayName: string;
  const AKind: string;
  const APromptField: string;
  const AExtensionId: string;
  const AReservedCommands: TArray<string>;
  const ACommands: TList<TRadIADeclarativeCommand>
);
var
  LArray: TJSONArray;
  LIndex: Integer;
  LValue: TJSONValue;
begin
  LValue := AJson.GetValue(AArrayName);
  if not Assigned(LValue) then
    Exit;
  if not (LValue is TJSONArray) then
    raise EArgumentException.Create(
      'Manifest ' + AArrayName + ' must be an array.'
    );
  LArray := TJSONArray(LValue);
  for LIndex := 0 to LArray.Count - 1 do
  begin
    if not (LArray[LIndex] is TJSONObject) then
      raise EArgumentException.Create(
        'Each ' + AKind + ' must be a JSON object.'
      );
    ACommands.Add(
      ParseCommand(
        TJSONObject(LArray[LIndex]),
        AExtensionId,
        AReservedCommands,
        ACommands.ToArray,
        AKind,
        APromptField
      )
    );
  end;
end;

function TRadIADeclarativeExtensionManager.ParseCommands(
  const AJson: TJSONObject;
  const AExtensionId: string;
  const AReservedCommands: TArray<string>;
  const ASchemaVersion: Integer
): TArray<TRadIADeclarativeCommand>;
var
  LCommands: TList<TRadIADeclarativeCommand>;
begin
  LCommands := TList<TRadIADeclarativeCommand>.Create;
  try
    ParseCapabilityArray(
      AJson,
      'commands',
      'command',
      'prompt',
      AExtensionId,
      AReservedCommands,
      LCommands
    );
    if ASchemaVersion >= 2 then
    begin
      ParseCapabilityArray(
        AJson,
        'templates',
        'template',
        'prompt',
        AExtensionId,
        AReservedCommands,
        LCommands
      );
      ParseCapabilityArray(
        AJson,
        'skills',
        'skill',
        'instructions',
        AExtensionId,
        AReservedCommands,
        LCommands
      );
    end;
    if LCommands.Count > CMaximumCommandsPerExtension then
      raise EArgumentException.Create(
        'Manifest cannot contain more than 100 prompt capabilities.'
      );
    Result := LCommands.ToArray;
  finally
    LCommands.Free;
  end;
end;

function TRadIADeclarativeExtensionManager.ParseTools(
  const AJson: TJSONObject;
  const AExtensionId: string;
  const ASchemaVersion: Integer
): TArray<TRadIADeclarativeTool>;
var
  LArray: TJSONArray;
  LExistingTool: TRadIADeclarativeTool;
  LIndex: Integer;
  LParsedTool: TRadIADeclarativeTool;
  LTools: TList<TRadIADeclarativeTool>;
  LValue: TJSONValue;
begin
  Result := [];
  LValue := AJson.GetValue('tools');
  if not Assigned(LValue) then
    Exit;
  if ASchemaVersion < 3 then
    raise EArgumentException.Create(
      'Declarative tools require schema version 3.'
    );
  if not (LValue is TJSONArray) then
    raise EArgumentException.Create('Manifest tools must be an array.');
  LArray := TJSONArray(LValue);
  LTools := TList<TRadIADeclarativeTool>.Create;
  try
    for LIndex := 0 to LArray.Count - 1 do
    begin
      if not (LArray[LIndex] is TJSONObject) then
        raise EArgumentException.Create(
          'Each declarative tool must be a JSON object.'
        );
      LParsedTool := ParseTool(
        TJSONObject(LArray[LIndex]),
        AExtensionId
      );
      for LExistingTool in LTools do
        if SameText(
          LExistingTool.Name,
          LParsedTool.Name
        ) then
          raise EArgumentException.Create(
            'Manifest contains duplicate declarative tool names.'
          );
      LTools.Add(LParsedTool);
    end;
    Result := LTools.ToArray;
  finally
    LTools.Free;
  end;
end;

function TRadIADeclarativeExtensionManager.ParseTool(
  const AJson: TJSONObject;
  const AExtensionId: string
): TRadIADeclarativeTool;
var
  LDescription: string;
  LName: string;
  LTargetTool: string;
begin
  LName := Trim(AJson.GetValue<string>('name', ''));
  LDescription := Trim(AJson.GetValue<string>('description', ''));
  LTargetTool := Trim(AJson.GetValue<string>('targetTool', ''));
  ValidateToolFields(
    AExtensionId,
    LName,
    LDescription,
    LTargetTool
  );
  Result := TRadIADeclarativeTool.Create(
    AExtensionId,
    LName,
    LDescription,
    LTargetTool
  );
end;

procedure TRadIADeclarativeExtensionManager.ValidateToolFields(
  const AExtensionId: string;
  const AName: string;
  const ADescription: string;
  const ATargetTool: string
);
begin
  if not IsPascalIdentifier(AName) then
    raise EArgumentException.Create(
      'Declarative tool name must use alphanumeric PascalCase.'
    );
  if not AName.StartsWith(AExtensionId, True) then
    raise EArgumentException.Create(
      'Declarative tool name must start with the extension ID.'
    );
  if (ADescription = '') or
    (Length(ADescription) > CMaximumDescriptionLength) then
    raise EArgumentException.Create(
      'Tool description must contain between 1 and 500 characters.'
    );
  if not IsPascalIdentifier(ATargetTool) then
    raise EArgumentException.Create(
      'Declarative target tool must use alphanumeric PascalCase.'
    );
end;

procedure TRadIADeclarativeExtensionManager.ValidateCommandFields(
  const AName: string;
  const ADescription: string;
  const ASlashCommand: string;
  const APrompt: string
);
begin
  if (AName = '') or (Length(AName) > 100) then
    raise EArgumentException.Create(
      'Command name must contain between 1 and 100 characters.'
    );
  if (ADescription = '') or
    (Length(ADescription) > CMaximumDescriptionLength) then
    raise EArgumentException.Create(
      'Command description must contain between 1 and 500 characters.'
    );
  if not IsValidSlashCommand(ASlashCommand) then
    raise EArgumentException.Create(
      'Command must match /name using letters, numbers, or hyphens.'
    );
  if (APrompt = '') or (Length(APrompt) > CMaximumPromptLength) then
    raise EArgumentException.Create(
      'Command prompt must contain between 1 and 32768 characters.'
    );
end;

procedure TRadIADeclarativeExtensionManager.ValidatePermissions(
  const AJson: TJSONObject;
  const AHasPromptCapabilities: Boolean;
  const AHasTools: Boolean
);
var
  LArray: TJSONArray;
  LHasPromptPermission: Boolean;
  LHasToolPermission: Boolean;
  LIndex: Integer;
  LPermission: string;
  LValue: TJSONValue;
begin
  LValue := AJson.GetValue('permissions');
  if not (LValue is TJSONArray) then
    raise EArgumentException.Create(
      'Manifest permissions must be an array.'
    );
  LArray := TJSONArray(LValue);
  LHasPromptPermission := False;
  LHasToolPermission := False;
  for LIndex := 0 to LArray.Count - 1 do
  begin
    LPermission := LArray[LIndex].Value;
    if SameText(LPermission, CCommandPermission) then
      LHasPromptPermission := True
    else if SameText(LPermission, CToolAliasPermission) then
      LHasToolPermission := True
    else
      raise EArgumentException.Create(
        'Manifest contains an unsupported permission.'
      );
  end;
  if AHasPromptCapabilities <> LHasPromptPermission then
    raise EArgumentException.Create(
      'Prompt capabilities require exactly the chat.prompt permission.'
    );
  if AHasTools <> LHasToolPermission then
    raise EArgumentException.Create(
      'Declarative tools require exactly the tool.alias permission.'
    );
  if LArray.Count <> Ord(AHasPromptCapabilities) + Ord(AHasTools) then
    raise EArgumentException.Create(
      'Manifest permissions must not contain duplicates.'
    );
end;

procedure TRadIADeclarativeExtensionManager.Reload(
  const AReservedCommands: TArray<string>
);
var
  LFileName: string;
  LFileNames: TArray<string>;
begin
  FCommands.Clear;
  FTools.Clear;
  FDiagnostics.Clear;
  if not TDirectory.Exists(FDirectory) then
    TDirectory.CreateDirectory(FDirectory);
  LFileNames := TDirectory.GetFiles(
    FDirectory,
    '*.radia.json',
    TSearchOption.soTopDirectoryOnly
  );
  TArray.Sort<string>(LFileNames);
  for LFileName in LFileNames do
  begin
    try
      LoadManifest(LFileName, AReservedCommands);
    except
      on E: Exception do
        FDiagnostics.Add(
          TRadIADeclarativeExtensionDiagnostic.Create(
            LFileName,
            '',
            'rejected',
            E.Message
          )
        );
    end;
  end;
end;

procedure TRadIADeclarativeExtensionManager.ReportRuntimeError(
  const AMessage: string
);
begin
  FDiagnostics.Add(
    TRadIADeclarativeExtensionDiagnostic.Create(
      '',
      '',
      'runtime-rejected',
      AMessage
    )
  );
end;

function TRadIADeclarativeExtensionManager.SetEnabled(
  const AExtensionId: string;
  const AEnabled: Boolean;
  const AReservedCommands: TArray<string>;
  out AMessage: string
): Boolean;
var
  LBackup: TArray<Byte>;
  LDiagnostic: TRadIADeclarativeExtensionDiagnostic;
  LEnabledPair: TJSONPair;
  LJson: TJSONObject;
begin
  Result := False;
  Reload(AReservedCommands);
  if not FindDiagnostic(AExtensionId, LDiagnostic) then
  begin
    AMessage := 'The extension was not found.';
    Exit;
  end;
  LBackup := TFile.ReadAllBytes(LDiagnostic.FileName);
  LJson := TJSONObject.ParseJSONValue(
    TEncoding.UTF8.GetString(LBackup)
  ) as TJSONObject;
  if not Assigned(LJson) then
  begin
    AMessage := 'Manifest root must be a JSON object.';
    Exit;
  end;
  try
    LEnabledPair := LJson.RemovePair('enabled');
    LEnabledPair.Free;
    LJson.AddPair('enabled', TJSONBool.Create(AEnabled));
    try
      AtomicWrite(
        LDiagnostic.FileName,
        TEncoding.UTF8.GetBytes(LJson.ToJSON)
      );
      Reload(AReservedCommands);
      if not IsAcceptedFile(
        LDiagnostic.FileName,
        AExtensionId,
        AMessage
      ) then
        raise EInvalidOpException.Create(AMessage);
      if AEnabled then
        AMessage := 'Extension enabled without restarting the IDE.'
      else
        AMessage := 'Extension disabled without restarting the IDE.';
      Result := True;
    except
      on E: Exception do
      begin
        AtomicWrite(LDiagnostic.FileName, LBackup);
        Reload(AReservedCommands);
        AMessage := 'Status change rolled back: ' + E.Message;
      end;
    end;
  finally
    LJson.Free;
  end;
end;

function TRadIADeclarativeExtensionManager.TryResolve(
  const ASlashCommand: string;
  out ACommand: TRadIADeclarativeCommand
): Boolean;
var
  LCommand: TRadIADeclarativeCommand;
begin
  ACommand := Default(TRadIADeclarativeCommand);
  for LCommand in FCommands do
  begin
    if SameText(LCommand.SlashCommand, ASlashCommand) then
    begin
      ACommand := LCommand;
      Exit(True);
    end;
  end;
  Result := False;
end;

procedure TRadIADeclarativeExtensionManager.ValidateManifestIdentity(
  const AExtensionId: string;
  const AVersion: string
);
begin
  if not IsPascalIdentifier(AExtensionId) then
    raise EArgumentException.Create(
      'Extension ID must use alphanumeric PascalCase.'
    );
  if not TRegEx.IsMatch(AVersion, '^\d+\.\d+\.\d+$') then
    raise EArgumentException.Create(
      'Extension version must use semantic major.minor.patch format.'
    );
end;

end.
