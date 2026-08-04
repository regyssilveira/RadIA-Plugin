unit RadIA.Core.McpProvisioning;

interface

type
  TRadIAMcpConfigFormat = (
    mcfJson,
    mcfToml
  );

  TRadIAMcpProvisionState = (
    mpsMissing,
    mpsConfigured,
    mpsDrifted,
    mpsInvalid
  );

  TRadIAMcpClientProfile = record
  private
    FId: string;
    FDisplayName: string;
    FFormat: TRadIAMcpConfigFormat;
    FServerContainer: string;
  public
    constructor Create(
      const AId: string;
      const ADisplayName: string;
      const AFormat: TRadIAMcpConfigFormat;
      const AServerContainer: string
    );
    property Id: string read FId;
    property DisplayName: string read FDisplayName;
    property Format: TRadIAMcpConfigFormat read FFormat;
    property ServerContainer: string read FServerContainer;
  end;

  TRadIAMcpProvisionPreview = record
  private
    FState: TRadIAMcpProvisionState;
    FChanged: Boolean;
    FCurrentContent: string;
    FProposedContent: string;
    FSummary: string;
  public
    constructor Create(
      const AState: TRadIAMcpProvisionState;
      const AChanged: Boolean;
      const ACurrentContent: string;
      const AProposedContent: string;
      const ASummary: string
    );
    function ToDiagnosticText: string;
    property State: TRadIAMcpProvisionState read FState;
    property Changed: Boolean read FChanged;
    property CurrentContent: string read FCurrentContent;
    property ProposedContent: string read FProposedContent;
    property Summary: string read FSummary;
  end;

  TRadIAMcpProvisionResult = record
  private
    FSucceeded: Boolean;
    FChanged: Boolean;
    FBackupPath: string;
    FMessage: string;
  public
    constructor Create(
      const ASucceeded: Boolean;
      const AChanged: Boolean;
      const ABackupPath: string;
      const AMessage: string
    );
    function ToDiagnosticText: string;
    property Succeeded: Boolean read FSucceeded;
    property Changed: Boolean read FChanged;
    property BackupPath: string read FBackupPath;
    property Message: string read FMessage;
  end;

  IRadIAMcpConfigStorage = interface
    ['{3E7F93C9-98AA-4F09-A35B-E8CA5D3D80D8}']
    function FileExists(const AFileName: string): Boolean;
    function ReadText(const AFileName: string): string;
    procedure WriteText(const AFileName: string; const AContent: string);
    procedure CopyFile(const ASource, ADestination: string);
    procedure DeleteFile(const AFileName: string);
  end;

  TRadIAMcpConfigStorage = class(
    TInterfacedObject,
    IRadIAMcpConfigStorage
  )
  public
    function FileExists(const AFileName: string): Boolean;
    function ReadText(const AFileName: string): string;
    procedure WriteText(const AFileName: string; const AContent: string);
    procedure CopyFile(const ASource, ADestination: string);
    procedure DeleteFile(const AFileName: string);
  end;

  TRadIAMcpClientCatalog = class
  public
    class function All: TArray<TRadIAMcpClientProfile>; static;
    class function FindById(
      const AId: string;
      out AProfile: TRadIAMcpClientProfile
    ): Boolean; static;
  end;

  TRadIAMcpProvisioner = class
  private const
    CServerId = 'radia';
    CTomlBegin = '# BEGIN RadIA managed MCP server';
    CTomlEnd = '# END RadIA managed MCP server';
  private
    FStorage: IRadIAMcpConfigStorage;
    function Backup(
      const AConfigPath: string
    ): string;
    function BuildJsonContent(
      const AProfile: TRadIAMcpClientProfile;
      const ACurrentContent: string;
      const ABridgePath: string;
      const ARemove: Boolean
    ): string;
    function BuildTomlContent(
      const ACurrentContent: string;
      const ABridgePath: string;
      const ARemove: Boolean
    ): string;
    function BuildContent(
      const AProfile: TRadIAMcpClientProfile;
      const ACurrentContent: string;
      const ABridgePath: string;
      const ARemove: Boolean
    ): string;
    function ReadCurrent(const AConfigPath: string): string;
    function StateOf(
      const AProfile: TRadIAMcpClientProfile;
      const ACurrentContent: string;
      const ABridgePath: string
    ): TRadIAMcpProvisionState;
  public
    constructor Create(
      const AStorage: IRadIAMcpConfigStorage = nil
    );
    function Preview(
      const AProfile: TRadIAMcpClientProfile;
      const AConfigPath: string;
      const ABridgePath: string
    ): TRadIAMcpProvisionPreview;
    function Provision(
      const AProfile: TRadIAMcpClientProfile;
      const AConfigPath: string;
      const ABridgePath: string
    ): TRadIAMcpProvisionResult;
    function Remove(
      const AProfile: TRadIAMcpClientProfile;
      const AConfigPath: string
    ): TRadIAMcpProvisionResult;
    function Verify(
      const AProfile: TRadIAMcpClientProfile;
      const AConfigPath: string;
      const ABridgePath: string
    ): Boolean;
  end;

implementation

uses
  System.IOUtils,
  System.JSON,
  System.StrUtils,
  System.SysUtils;

{ TRadIAMcpClientProfile }

constructor TRadIAMcpClientProfile.Create(
  const AId: string;
  const ADisplayName: string;
  const AFormat: TRadIAMcpConfigFormat;
  const AServerContainer: string
);
begin
  FId := AId;
  FDisplayName := ADisplayName;
  FFormat := AFormat;
  FServerContainer := AServerContainer;
end;

{ TRadIAMcpProvisionPreview }

constructor TRadIAMcpProvisionPreview.Create(
  const AState: TRadIAMcpProvisionState;
  const AChanged: Boolean;
  const ACurrentContent: string;
  const AProposedContent: string;
  const ASummary: string
);
begin
  FState := AState;
  FChanged := AChanged;
  FCurrentContent := ACurrentContent;
  FProposedContent := AProposedContent;
  FSummary := ASummary;
end;

function TRadIAMcpProvisionPreview.ToDiagnosticText: string;
begin
  Result := Format(
    '%d|%s|%d|%d|%s',
    [
      Ord(State),
      BoolToStr(Changed, True),
      Length(CurrentContent),
      Length(ProposedContent),
      Summary
    ]
  );
end;

{ TRadIAMcpProvisionResult }

constructor TRadIAMcpProvisionResult.Create(
  const ASucceeded: Boolean;
  const AChanged: Boolean;
  const ABackupPath: string;
  const AMessage: string
);
begin
  FSucceeded := ASucceeded;
  FChanged := AChanged;
  FBackupPath := ABackupPath;
  FMessage := AMessage;
end;

function TRadIAMcpProvisionResult.ToDiagnosticText: string;
begin
  Result := Format(
    '%s|%s|%s|%s',
    [
      BoolToStr(Succeeded, True),
      BoolToStr(Changed, True),
      BackupPath,
      Message
    ]
  );
end;

{ TRadIAMcpConfigStorage }

procedure TRadIAMcpConfigStorage.CopyFile(
  const ASource, ADestination: string
);
begin
  TFile.Copy(ASource, ADestination, True);
end;

procedure TRadIAMcpConfigStorage.DeleteFile(
  const AFileName: string
);
begin
  TFile.Delete(AFileName);
end;

function TRadIAMcpConfigStorage.FileExists(
  const AFileName: string
): Boolean;
begin
  Result := TFile.Exists(AFileName);
end;

function TRadIAMcpConfigStorage.ReadText(
  const AFileName: string
): string;
begin
  Result := TFile.ReadAllText(AFileName, TEncoding.UTF8);
end;

procedure TRadIAMcpConfigStorage.WriteText(
  const AFileName: string;
  const AContent: string
);
var
  LDirectory: string;
begin
  LDirectory := TPath.GetDirectoryName(AFileName);
  if (LDirectory <> '') and not TDirectory.Exists(LDirectory) then
    TDirectory.CreateDirectory(LDirectory);
  TFile.WriteAllText(AFileName, AContent, TEncoding.UTF8);
end;

{ TRadIAMcpClientCatalog }

class function TRadIAMcpClientCatalog.All:
  TArray<TRadIAMcpClientProfile>;
begin
  Result := [
    TRadIAMcpClientProfile.Create(
      'codex',
      'Codex CLI',
      mcfToml,
      'mcp_servers'
    ),
    TRadIAMcpClientProfile.Create(
      'claude',
      'Claude Code',
      mcfJson,
      'mcpServers'
    ),
    TRadIAMcpClientProfile.Create(
      'gemini',
      'Gemini CLI',
      mcfJson,
      'mcpServers'
    ),
    TRadIAMcpClientProfile.Create(
      'copilot',
      'GitHub Copilot CLI',
      mcfJson,
      'mcpServers'
    )
  ];
end;

class function TRadIAMcpClientCatalog.FindById(
  const AId: string;
  out AProfile: TRadIAMcpClientProfile
): Boolean;
var
  LProfile: TRadIAMcpClientProfile;
begin
  for LProfile in All do
    if SameText(LProfile.Id, Trim(AId)) then
    begin
      AProfile := LProfile;
      Exit(True);
    end;
  AProfile := Default(TRadIAMcpClientProfile);
  Result := False;
end;

{ TRadIAMcpProvisioner }

constructor TRadIAMcpProvisioner.Create(
  const AStorage: IRadIAMcpConfigStorage
);
begin
  inherited Create;
  if Assigned(AStorage) then
    FStorage := AStorage
  else
    FStorage := TRadIAMcpConfigStorage.Create;
end;

function TRadIAMcpProvisioner.Backup(
  const AConfigPath: string
): string;
begin
  Result := '';
  if not FStorage.FileExists(AConfigPath) then
    Exit;
  Result := AConfigPath + '.radia.bak';
  FStorage.CopyFile(AConfigPath, Result);
end;

function TRadIAMcpProvisioner.BuildContent(
  const AProfile: TRadIAMcpClientProfile;
  const ACurrentContent: string;
  const ABridgePath: string;
  const ARemove: Boolean
): string;
begin
  case AProfile.Format of
    mcfJson:
      Result := BuildJsonContent(
        AProfile,
        ACurrentContent,
        ABridgePath,
        ARemove
      );
    mcfToml:
      Result := BuildTomlContent(
        ACurrentContent,
        ABridgePath,
        ARemove
      );
  else
    raise EArgumentException.Create('Unsupported MCP configuration format.');
  end;
end;

function TRadIAMcpProvisioner.BuildJsonContent(
  const AProfile: TRadIAMcpClientProfile;
  const ACurrentContent: string;
  const ABridgePath: string;
  const ARemove: Boolean
): string;
var
  LRoot: TJSONObject;
  LValue: TJSONValue;
  LServers: TJSONObject;
  LServer: TJSONObject;
  LPair: TJSONPair;
begin
  if Trim(ACurrentContent) <> '' then
  begin
    LValue := TJSONObject.ParseJSONValue(ACurrentContent);
    if not (LValue is TJSONObject) then
    begin
      LValue.Free;
      raise EConvertError.Create('The MCP client configuration is not a JSON object.');
    end;
    LRoot := TJSONObject(LValue);
  end
  else
    LRoot := TJSONObject.Create;
  try
    LValue := LRoot.GetValue(AProfile.ServerContainer);
    if Assigned(LValue) and not (LValue is TJSONObject) then
      raise EConvertError.Create(
        'The MCP server container is not a JSON object.'
      );
    LServers := TJSONObject(LValue);
    if not Assigned(LServers) then
    begin
      LServers := TJSONObject.Create;
      LRoot.AddPair(AProfile.ServerContainer, LServers);
    end;

    LPair := LServers.RemovePair(CServerId);
    LPair.Free;
    if not ARemove then
    begin
      LServer := TJSONObject.Create;
      LServer.AddPair('command', ABridgePath);
      LServers.AddPair(CServerId, LServer);
    end;
    Result := LRoot.Format(2);
  finally
    LRoot.Free;
  end;
end;

function TRadIAMcpProvisioner.BuildTomlContent(
  const ACurrentContent: string;
  const ABridgePath: string;
  const ARemove: Boolean
): string;
var
  LBefore: string;
  LAfter: string;
  LStartIndex: Integer;
  LEndIndex: Integer;
  LManagedBlock: string;
  LEscapedPath: string;
begin
  LBefore := ACurrentContent;
  LAfter := '';
  LStartIndex := Pos(CTomlBegin, LBefore);
  if LStartIndex > 0 then
  begin
    LEndIndex := PosEx(CTomlEnd, LBefore, LStartIndex);
    if LEndIndex = 0 then
      raise EConvertError.Create('The managed MCP TOML block is incomplete.');
    LAfter := Copy(
      LBefore,
      LEndIndex + Length(CTomlEnd),
      MaxInt
    );
    LBefore := Copy(LBefore, 1, LStartIndex - 1);
  end;
  Result := TrimRight(LBefore);
  if not ARemove then
  begin
    LEscapedPath := StringReplace(ABridgePath, '\', '\\', [rfReplaceAll]);
    LEscapedPath := StringReplace(LEscapedPath, '"', '\"', [rfReplaceAll]);
    LManagedBlock := CTomlBegin + sLineBreak +
      '[mcp_servers.' + CServerId + ']' + sLineBreak +
      'command = "' + LEscapedPath + '"' + sLineBreak +
      CTomlEnd;
    if Result <> '' then
      Result := Result + sLineBreak + sLineBreak;
    Result := Result + LManagedBlock;
  end;
  LAfter := TrimLeft(LAfter);
  if LAfter <> '' then
  begin
    if Result <> '' then
      Result := Result + sLineBreak + sLineBreak;
    Result := Result + LAfter;
  end;
  if Result <> '' then
    Result := Result + sLineBreak;
end;

function TRadIAMcpProvisioner.Preview(
  const AProfile: TRadIAMcpClientProfile;
  const AConfigPath: string;
  const ABridgePath: string
): TRadIAMcpProvisionPreview;
var
  LCurrent: string;
  LProposed: string;
  LState: TRadIAMcpProvisionState;
begin
  LCurrent := ReadCurrent(AConfigPath);
  try
    LState := StateOf(AProfile, LCurrent, ABridgePath);
    LProposed := BuildContent(
      AProfile,
      LCurrent,
      ABridgePath,
      False
    );
    Result := TRadIAMcpProvisionPreview.Create(
      LState,
      LCurrent <> LProposed,
      LCurrent,
      LProposed,
      'Configure the RadIA MCP bridge for ' + AProfile.DisplayName + '.'
    );
  except
    on E: EConvertError do
      Result := TRadIAMcpProvisionPreview.Create(
        mpsInvalid,
        False,
        LCurrent,
        '',
        E.Message
      );
  end;
end;

function TRadIAMcpProvisioner.Provision(
  const AProfile: TRadIAMcpClientProfile;
  const AConfigPath: string;
  const ABridgePath: string
): TRadIAMcpProvisionResult;
var
  LBackupPath: string;
  LPreview: TRadIAMcpProvisionPreview;
  LVerified: Boolean;
begin
  if not FStorage.FileExists(ABridgePath) then
    Exit(
      TRadIAMcpProvisionResult.Create(
        False,
        False,
        '',
        'The RadIA MCP bridge executable was not found.'
      )
    );
  LPreview := Preview(AProfile, AConfigPath, ABridgePath);
  if LPreview.State = mpsInvalid then
    Exit(
      TRadIAMcpProvisionResult.Create(
        False,
        False,
        '',
        LPreview.Summary
      )
    );
  if not LPreview.Changed then
    Exit(
      TRadIAMcpProvisionResult.Create(
        True,
        False,
        '',
        'The RadIA MCP bridge is already configured.'
      )
    );
  LBackupPath := Backup(AConfigPath);
  FStorage.WriteText(AConfigPath, LPreview.ProposedContent);
  LVerified := Verify(AProfile, AConfigPath, ABridgePath);
  if not LVerified then
  begin
    if LBackupPath <> '' then
      FStorage.CopyFile(LBackupPath, AConfigPath)
    else
      FStorage.DeleteFile(AConfigPath);
  end;
  Result := TRadIAMcpProvisionResult.Create(
    LVerified,
    True,
    LBackupPath,
    IfThen(
      LVerified,
      'The RadIA MCP bridge configuration was written and verified.',
      'Verification failed and the previous configuration was restored.'
    )
  );
end;

function TRadIAMcpProvisioner.ReadCurrent(
  const AConfigPath: string
): string;
begin
  if FStorage.FileExists(AConfigPath) then
    Result := FStorage.ReadText(AConfigPath)
  else
    Result := '';
end;

function TRadIAMcpProvisioner.Remove(
  const AProfile: TRadIAMcpClientProfile;
  const AConfigPath: string
): TRadIAMcpProvisionResult;
var
  LBackupPath: string;
  LCurrent: string;
  LProposed: string;
begin
  if not FStorage.FileExists(AConfigPath) then
    Exit(
      TRadIAMcpProvisionResult.Create(
        True,
        False,
        '',
        'The MCP client configuration does not exist.'
      )
    );
  LCurrent := ReadCurrent(AConfigPath);
  try
    LProposed := BuildContent(AProfile, LCurrent, '', True);
  except
    on E: EConvertError do
      Exit(
        TRadIAMcpProvisionResult.Create(
          False,
          False,
          '',
          E.Message
        )
      );
  end;
  if LCurrent = LProposed then
    Exit(
      TRadIAMcpProvisionResult.Create(
        True,
        False,
        '',
        'No managed RadIA MCP entry was found.'
      )
    );
  LBackupPath := Backup(AConfigPath);
  if Trim(LProposed) = '' then
    FStorage.DeleteFile(AConfigPath)
  else
    FStorage.WriteText(AConfigPath, LProposed);
  Result := TRadIAMcpProvisionResult.Create(
    True,
    True,
    LBackupPath,
    'The managed RadIA MCP entry was removed.'
  );
end;

function TRadIAMcpProvisioner.StateOf(
  const AProfile: TRadIAMcpClientProfile;
  const ACurrentContent: string;
  const ABridgePath: string
): TRadIAMcpProvisionState;
var
  LExpected: string;
begin
  if Trim(ACurrentContent) = '' then
    Exit(mpsMissing);
  try
    LExpected := BuildContent(
      AProfile,
      ACurrentContent,
      ABridgePath,
      False
    );
  except
    on EConvertError do
      Exit(mpsInvalid);
  end;
  if LExpected = ACurrentContent then
    Result := mpsConfigured
  else
    Result := mpsDrifted;
end;

function TRadIAMcpProvisioner.Verify(
  const AProfile: TRadIAMcpClientProfile;
  const AConfigPath: string;
  const ABridgePath: string
): Boolean;
begin
  Result :=
    FStorage.FileExists(ABridgePath) and
    (StateOf(
      AProfile,
      ReadCurrent(AConfigPath),
      ABridgePath
    ) = mpsConfigured);
end;

end.
