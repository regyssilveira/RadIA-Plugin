unit RadIA.Core.ExternalMcpSecurity;

interface

uses
  System.JSON,
  RadIA.Core.ExternalMcp,
  RadIA.Core.ExternalMcpClient,
  RadIA.Core.Tools,
  RadIA.Core.WorkspaceBoundary;

type
  TRadIAExternalMcpToolGrant = record
  private
    FAllowUnboundedAccess: Boolean;
    FConsentEveryTime: Boolean;
    FNamespacedName: string;
    FPathArguments: TArray<string>;
    FRisk: TRadIAToolRisk;
  public
    constructor Create(
      const ANamespacedName: string;
      const ARisk: TRadIAToolRisk;
      const AConsentEveryTime: Boolean;
      const APathArguments: TArray<string>;
      const AAllowUnboundedAccess: Boolean
    );
    function Validate(out AError: string): Boolean;
    property AllowUnboundedAccess: Boolean read FAllowUnboundedAccess;
    property ConsentEveryTime: Boolean read FConsentEveryTime;
    property NamespacedName: string read FNamespacedName;
    property PathArguments: TArray<string> read FPathArguments;
    property Risk: TRadIAToolRisk read FRisk;
  end;

  IRadIAExternalMcpWorkspaceRootProvider = interface
    ['{292E4DA5-666D-4A13-9569-9298A0C6677F}']
    function GetWorkspaceRoot: string;
  end;

  TRadIAExternalMcpToolAdapter = class(
    TInterfacedObject,
    IRadIATool
  )
  private
    FBoundary: IRadIAWorkspaceBoundary;
    FClient: IRadIAExternalMcpClient;
    FDescriptor: TRadIAToolDescriptor;
    FGrant: TRadIAExternalMcpToolGrant;
    FRootProvider: IRadIAExternalMcpWorkspaceRootProvider;
    FTool: TRadIAExternalMcpTool;
    function ValidateArgumentPath(
      const AName: string;
      const AValue: TJSONValue;
      out AError: string
    ): Boolean;
    function ValidatePaths(
      const AArgumentsJson: string;
      out AError: string
    ): Boolean;
  public
    constructor Create(
      const AClient: IRadIAExternalMcpClient;
      const ATool: TRadIAExternalMcpTool;
      const AGrant: TRadIAExternalMcpToolGrant;
      const ARootProvider: IRadIAExternalMcpWorkspaceRootProvider;
      const ABoundary: IRadIAWorkspaceBoundary
    );
    function Execute(
      const ARequest: TRadIAToolRequest
    ): TRadIAToolResult;
    function GetDescriptor: TRadIAToolDescriptor;
  end;

implementation

uses
  System.SysUtils;

const
  CExternalMcpFailed = 'external_mcp_failed';
  CExternalMcpPathDenied = 'external_mcp_path_denied';
  CToolCancelled = 'tool_cancelled';
  COutputSchema = '{"type":"object"}';

{ TRadIAExternalMcpToolGrant }

constructor TRadIAExternalMcpToolGrant.Create(
  const ANamespacedName: string;
  const ARisk: TRadIAToolRisk;
  const AConsentEveryTime: Boolean;
  const APathArguments: TArray<string>;
  const AAllowUnboundedAccess: Boolean
);
begin
  FNamespacedName := Trim(ANamespacedName);
  FRisk := ARisk;
  FConsentEveryTime := AConsentEveryTime;
  FPathArguments := Copy(APathArguments);
  FAllowUnboundedAccess := AAllowUnboundedAccess;
end;

function TRadIAExternalMcpToolGrant.Validate(
  out AError: string
): Boolean;
var
  LArgument: string;
begin
  AError := '';
  if not FNamespacedName.StartsWith('mcp.') then
    AError := 'External MCP grant must target a federated tool name.'
  else if (Length(FPathArguments) = 0) and not FAllowUnboundedAccess then
    AError := 'Grant must declare path arguments or explicitly allow unbounded access.';
  if AError = '' then
    for LArgument in FPathArguments do
      if Trim(LArgument) = '' then
      begin
        AError := 'External MCP path argument names cannot be empty.';
        Break;
      end;
  Result := AError = '';
end;

{ TRadIAExternalMcpToolAdapter }

constructor TRadIAExternalMcpToolAdapter.Create(
  const AClient: IRadIAExternalMcpClient;
  const ATool: TRadIAExternalMcpTool;
  const AGrant: TRadIAExternalMcpToolGrant;
  const ARootProvider: IRadIAExternalMcpWorkspaceRootProvider;
  const ABoundary: IRadIAWorkspaceBoundary
);
var
  LError: string;
begin
  inherited Create;
  if not Assigned(AClient) then
    raise EArgumentNilException.Create('External MCP client is required.');
  if not Assigned(ARootProvider) then
    raise EArgumentNilException.Create('Workspace root provider is required.');
  if not Assigned(ABoundary) then
    raise EArgumentNilException.Create('Workspace boundary is required.');
  if not SameText(ATool.NamespacedName, AGrant.NamespacedName) then
    raise EArgumentException.Create('External MCP tool and grant do not match.');
  if not AGrant.Validate(LError) then
    raise EArgumentException.Create(LError);
  FClient := AClient;
  FTool := ATool;
  FGrant := AGrant;
  FRootProvider := ARootProvider;
  FBoundary := ABoundary;
  FDescriptor := TRadIAToolDescriptor.Create(
    FTool.NamespacedName,
    '1.0.0',
    FTool.Description,
    FTool.InputSchema,
    COutputSchema,
    FGrant.Risk
  );
  if FGrant.ConsentEveryTime then
    FDescriptor := FDescriptor.WithConsentEveryTime;
end;

function TRadIAExternalMcpToolAdapter.Execute(
  const ARequest: TRadIAToolRequest
): TRadIAToolResult;
var
  LError: string;
  LResultJson: string;
begin
  if Assigned(ARequest.CancellationToken) and
     ARequest.CancellationToken.CancellationRequested then
    Exit(TRadIAToolResult.Failed(CToolCancelled, 'Tool execution was cancelled.'));
  if not ValidatePaths(ARequest.ArgumentsJson, LError) then
    Exit(TRadIAToolResult.Failed(CExternalMcpPathDenied, LError));
  if not FClient.CallTool(
    FTool.NamespacedName,
    ARequest.ArgumentsJson,
    LResultJson,
    LError
  ) then
    Exit(TRadIAToolResult.Failed(CExternalMcpFailed, LError));
  Result := TRadIAToolResult.Succeeded(LResultJson);
end;

function TRadIAExternalMcpToolAdapter.GetDescriptor:
  TRadIAToolDescriptor;
begin
  Result := FDescriptor;
end;

function TRadIAExternalMcpToolAdapter.ValidateArgumentPath(
  const AName: string;
  const AValue: TJSONValue;
  out AError: string
): Boolean;
var
  LIndex: Integer;
  LPath: string;
  LValidation: TRadIAPathValidation;
  LValues: TJSONArray;
begin
  AError := '';
  if AValue is TJSONString then
  begin
    LPath := AValue.Value;
    LValidation := FBoundary.ValidatePath(FRootProvider.GetWorkspaceRoot, LPath);
    if not LValidation.Allowed then
      AError := AName + ': ' + LValidation.ErrorMessage;
    Exit(AError = '');
  end;
  if not (AValue is TJSONArray) then
  begin
    AError := AName + ' must be a path string or an array of path strings.';
    Exit(False);
  end;
  LValues := TJSONArray(AValue);
  for LIndex := 0 to LValues.Count - 1 do
    if not ValidateArgumentPath(AName, LValues[LIndex], AError) then
      Exit(False);
  Result := True;
end;

function TRadIAExternalMcpToolAdapter.ValidatePaths(
  const AArgumentsJson: string;
  out AError: string
): Boolean;
var
  LArgument: string;
  LArguments: TJSONValue;
  LObject: TJSONObject;
  LValue: TJSONValue;
begin
  AError := '';
  if FGrant.AllowUnboundedAccess then
    Exit(True);
  LArguments := TJSONObject.ParseJSONValue(AArgumentsJson);
  try
    if not (LArguments is TJSONObject) then
    begin
      AError := 'External MCP arguments must be a JSON object.';
      Exit(False);
    end;
    LObject := TJSONObject(LArguments);
    for LArgument in FGrant.PathArguments do
    begin
      LValue := LObject.GetValue(LArgument);
      if not Assigned(LValue) then
      begin
        AError := 'Required path argument is missing: ' + LArgument;
        Exit(False);
      end;
      if not ValidateArgumentPath(LArgument, LValue, AError) then
        Exit(False);
    end;
    Result := True;
  finally
    LArguments.Free;
  end;
end;

end.
