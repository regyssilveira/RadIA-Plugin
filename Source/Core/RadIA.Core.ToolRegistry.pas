unit RadIA.Core.ToolRegistry;

interface

uses
  System.Generics.Collections,
  System.SysUtils,
  RadIA.Core.Tools,
  RadIA.Core.ToolViews;

type
  ERadIAToolRegistry = class(Exception);
  ERadIAToolAlreadyRegistered = class(ERadIAToolRegistry);
  ERadIAToolNotFound = class(ERadIAToolRegistry);
  ERadIAInvalidToolDescriptor = class(ERadIAToolRegistry);

  TRadIAToolRegistry = class(
    TInterfacedObject,
    IRadIAToolRegistry,
    IRadIAToolRegistryAtomicUpdater
  )
  private
    FTools: TDictionary<string, IRadIATool>;
    procedure ApplyReplacementLocked(
      const AOldNames: TArray<string>;
      const ANewTools: TArray<IRadIATool>
    );
    procedure EnsureReplacementAvailable(
      const AOldNameSet: TDictionary<string, Byte>;
      const ANewTools: TArray<IRadIATool>
    );
    function IsValidToolName(const AName: string): Boolean;
    procedure ValidateJsonSchema(
      const ASchema: string;
      const AFieldName: string
    );
    procedure ValidateDescriptor(
      const ADescriptor: TRadIAToolDescriptor
    );
    procedure ValidateReplacementTools(
      const ANewTools: TArray<IRadIATool>;
      const ANewNames: TDictionary<string, Byte>
    );
  public
    constructor Create;
    destructor Destroy; override;
    procedure RegisterTool(const ATool: IRadIATool);
    procedure RegisterTools(const ATools: TArray<IRadIATool>);
    procedure ReplaceTools(
      const AOldNames: TArray<string>;
      const ANewTools: TArray<IRadIATool>
    );
    procedure UnregisterTools(const ANames: TArray<string>);
    function Resolve(const AName: string): IRadIATool;
    function TryResolve(
      const AName: string;
      out ATool: IRadIATool
    ): Boolean;
    function GetDescriptors: TArray<TRadIAToolDescriptor>;
    function GetCount: Integer;
    procedure Clear;
  end;

  TRadIAToolExecutor = class(
    TInterfacedObject,
    IRadIAToolExecutor,
    IRadIAToolDescriptorProvider
  )
  private
    FRegistry: IRadIAToolRegistry;
    FViewResolver: IRadIAToolViewResolver;
    function ValidateRequest(
      const ARequest: TRadIAToolRequest
    ): TRadIAToolResult;
  public
    constructor Create(
      const ARegistry: IRadIAToolRegistry;
      const AViewResolver: IRadIAToolViewResolver = nil
    );
    function Execute(
      const ARequest: TRadIAToolRequest
    ): TRadIAToolResult;
    function TryGetToolDescriptor(
      const AName: string;
      out ADescriptor: TRadIAToolDescriptor
    ): Boolean;
  end;

implementation

uses
  System.Generics.Defaults,
  System.JSON;

const
  CInvalidRequest = 'invalid_request';
  CToolCancelled = 'tool_cancelled';
  CToolNotFound = 'tool_not_found';
  CToolExecutionFailed = 'tool_execution_failed';

{ TRadIAToolRegistry }

constructor TRadIAToolRegistry.Create;
begin
  inherited Create;
  FTools := TDictionary<string, IRadIATool>.Create(
    TIStringComparer.Ordinal
  );
end;

destructor TRadIAToolRegistry.Destroy;
begin
  FTools.Free;
  inherited;
end;

procedure TRadIAToolRegistry.Clear;
begin
  TMonitor.Enter(FTools);
  try
    FTools.Clear;
  finally
    TMonitor.Exit(FTools);
  end;
end;

function TRadIAToolRegistry.GetCount: Integer;
var
  LPair: TPair<string, IRadIATool>;
begin
  TMonitor.Enter(FTools);
  try
    Result := 0;
    for LPair in FTools do
      Inc(Result);
  finally
    TMonitor.Exit(FTools);
  end;
end;

function TRadIAToolRegistry.GetDescriptors:
  TArray<TRadIAToolDescriptor>;
var
  LIndex: Integer;
  LPair: TPair<string, IRadIATool>;
begin
  TMonitor.Enter(FTools);
  try
    Result := [];
    LIndex := 0;
    for LPair in FTools do
    begin
      SetLength(Result, Length(Result) + 1);
      Result[LIndex] := LPair.Value.Descriptor;
      Inc(LIndex);
    end;
  finally
    TMonitor.Exit(FTools);
  end;

  TArray.Sort<TRadIAToolDescriptor>(
    Result,
    TComparer<TRadIAToolDescriptor>.Construct(
      function(
        const ALeft: TRadIAToolDescriptor;
        const ARight: TRadIAToolDescriptor
      ): Integer
      begin
        Result := CompareText(ALeft.Name, ARight.Name);
      end
    )
  );
end;

function TRadIAToolRegistry.IsValidToolName(
  const AName: string
): Boolean;
var
  LChar: Char;
  LIndex: Integer;
begin
  Result := False;
  if AName = '' then
    Exit;
  if AName.StartsWith('mcp.') then
  begin
    if (Length(AName) > 256) or AName.EndsWith('.') or
       AName.Contains('..') then
      Exit;
    for LIndex := Low(AName) to High(AName) do
    begin
      LChar := AName[LIndex];
      if not CharInSet(
        LChar,
        ['A'..'Z', 'a'..'z', '0'..'9', '_', '-', '.']
      ) then
        Exit;
    end;
    Exit(True);
  end;
  if not CharInSet(AName[Low(AName)], ['A'..'Z']) then
    Exit;

  for LIndex := Low(AName) to High(AName) do
  begin
    LChar := AName[LIndex];
    if not CharInSet(LChar, ['A'..'Z', 'a'..'z', '0'..'9']) then
      Exit;
  end;
  Result := True;
end;

procedure TRadIAToolRegistry.RegisterTool(
  const ATool: IRadIATool
);
var
  LTools: TArray<IRadIATool>;
begin
  SetLength(LTools, 1);
  LTools[0] := ATool;
  RegisterTools(LTools);
end;

procedure TRadIAToolRegistry.RegisterTools(
  const ATools: TArray<IRadIATool>
);
var
  LDescriptor: TRadIAToolDescriptor;
  LNames: TDictionary<string, Byte>;
  LTool: IRadIATool;
begin
  LNames := TDictionary<string, Byte>.Create(
    TIStringComparer.Ordinal
  );
  try
    for LTool in ATools do
    begin
      if not Assigned(LTool) then
        raise ERadIAInvalidToolDescriptor.Create(
          'Tool instance must be assigned.'
        );

      LDescriptor := LTool.Descriptor;
      ValidateDescriptor(LDescriptor);
      if LNames.ContainsKey(LDescriptor.Name) then
        raise ERadIAToolAlreadyRegistered.CreateFmt(
          'Tool "%s" occurs more than once in the registration batch.',
          [LDescriptor.Name]
        );
      LNames.Add(LDescriptor.Name, 0);
    end;

    TMonitor.Enter(FTools);
    try
      for LTool in ATools do
      begin
        LDescriptor := LTool.Descriptor;
        if FTools.ContainsKey(LDescriptor.Name) then
          raise ERadIAToolAlreadyRegistered.CreateFmt(
            'Tool "%s" is already registered.',
            [LDescriptor.Name]
          );
      end;
      for LTool in ATools do
        FTools.Add(LTool.Descriptor.Name, LTool);
    finally
      TMonitor.Exit(FTools);
    end;
  finally
    LNames.Free;
  end;
end;

procedure TRadIAToolRegistry.ApplyReplacementLocked(
  const AOldNames: TArray<string>;
  const ANewTools: TArray<IRadIATool>
);
var
  LName: string;
  LOldTools: TDictionary<string, IRadIATool>;
  LTool: IRadIATool;
begin
  LOldTools := TDictionary<string, IRadIATool>.Create(TIStringComparer.Ordinal);
  try
    for LName in AOldNames do
      if FTools.TryGetValue(LName, LTool) then
        LOldTools.AddOrSetValue(LName, LTool);
    try
      for LName in AOldNames do
        FTools.Remove(LName);
      for LTool in ANewTools do
        FTools.Add(LTool.Descriptor.Name, LTool);
    except
      for LTool in ANewTools do
        FTools.Remove(LTool.Descriptor.Name);
      for LName in LOldTools.Keys do
        FTools.AddOrSetValue(LName, LOldTools[LName]);
      raise;
    end;
  finally
    LOldTools.Free;
  end;
end;

procedure TRadIAToolRegistry.EnsureReplacementAvailable(
  const AOldNameSet: TDictionary<string, Byte>;
  const ANewTools: TArray<IRadIATool>
);
var
  LName: string;
  LTool: IRadIATool;
begin
  for LTool in ANewTools do
  begin
    LName := LTool.Descriptor.Name;
    if FTools.ContainsKey(LName) and not AOldNameSet.ContainsKey(LName) then
      raise ERadIAToolAlreadyRegistered.CreateFmt(
        'Tool "%s" is already registered.',
        [LName]
      );
  end;
end;

procedure TRadIAToolRegistry.ReplaceTools(
  const AOldNames: TArray<string>;
  const ANewTools: TArray<IRadIATool>
);
var
  LName: string;
  LNewNames: TDictionary<string, Byte>;
  LOldNameSet: TDictionary<string, Byte>;
begin
  LNewNames := TDictionary<string, Byte>.Create(TIStringComparer.Ordinal);
  LOldNameSet := TDictionary<string, Byte>.Create(TIStringComparer.Ordinal);
  try
    for LName in AOldNames do
      LOldNameSet.AddOrSetValue(LName, 0);
    ValidateReplacementTools(ANewTools, LNewNames);
    TMonitor.Enter(FTools);
    try
      EnsureReplacementAvailable(LOldNameSet, ANewTools);
      ApplyReplacementLocked(AOldNames, ANewTools);
    finally
      TMonitor.Exit(FTools);
    end;
  finally
    LOldNameSet.Free;
    LNewNames.Free;
  end;
end;

procedure TRadIAToolRegistry.UnregisterTools(
  const ANames: TArray<string>
);
var
  LName: string;
begin
  TMonitor.Enter(FTools);
  try
    for LName in ANames do
      FTools.Remove(LName);
  finally
    TMonitor.Exit(FTools);
  end;
end;

function TRadIAToolRegistry.Resolve(
  const AName: string
): IRadIATool;
begin
  if not TryResolve(AName, Result) then
    raise ERadIAToolNotFound.CreateFmt(
      'Tool "%s" is not registered.',
      [AName]
    );
end;

function TRadIAToolRegistry.TryResolve(
  const AName: string;
  out ATool: IRadIATool
): Boolean;
begin
  ATool := nil;
  TMonitor.Enter(FTools);
  try
    Result := FTools.TryGetValue(AName, ATool);
  finally
    TMonitor.Exit(FTools);
  end;
end;

procedure TRadIAToolRegistry.ValidateDescriptor(
  const ADescriptor: TRadIAToolDescriptor
);
begin
  if not IsValidToolName(ADescriptor.Name) then
    raise ERadIAInvalidToolDescriptor.Create(
      'Tool name must use alphanumeric PascalCase.'
    );
  if Trim(ADescriptor.Version) = '' then
    raise ERadIAInvalidToolDescriptor.Create(
      'Tool version must not be empty.'
    );
  if Trim(ADescriptor.Description) = '' then
    raise ERadIAInvalidToolDescriptor.Create(
      'Tool description must not be empty.'
    );
  if ADescriptor.TimeoutMs = 0 then
    raise ERadIAInvalidToolDescriptor.Create(
      'Tool timeout must be greater than zero.'
    );

  ValidateJsonSchema(ADescriptor.InputSchema, 'Input schema');
  ValidateJsonSchema(ADescriptor.OutputSchema, 'Output schema');
end;

procedure TRadIAToolRegistry.ValidateJsonSchema(
  const ASchema: string;
  const AFieldName: string
);
var
  LJson: TJSONValue;
begin
  LJson := TJSONObject.ParseJSONValue(ASchema);
  try
    if not (LJson is TJSONObject) then
      raise ERadIAInvalidToolDescriptor.CreateFmt(
        '%s must be a valid JSON object.',
        [AFieldName]
      );
  finally
    LJson.Free;
  end;
end;

{ TRadIAToolExecutor }

constructor TRadIAToolExecutor.Create(
  const ARegistry: IRadIAToolRegistry;
  const AViewResolver: IRadIAToolViewResolver
);
begin
  inherited Create;
  if not Assigned(ARegistry) then
    raise EArgumentNilException.Create('ARegistry');
  FRegistry := ARegistry;
  if Assigned(AViewResolver) then
    FViewResolver := AViewResolver
  else
    FViewResolver := TRadIAToolViewResolver.Create;
end;

function TRadIAToolExecutor.Execute(
  const ARequest: TRadIAToolRequest
): TRadIAToolResult;
var
  LTool: IRadIATool;
begin
  Result := ValidateRequest(ARequest);
  if not Result.Success then
    Exit;

  if not FRegistry.TryResolve(ARequest.ToolName, LTool) then
    Exit(
      TRadIAToolResult.Failed(
        CToolNotFound,
        Format('Tool "%s" is not registered.', [ARequest.ToolName])
      )
    );

  if Assigned(ARequest.CancellationToken) and
    ARequest.CancellationToken.CancellationRequested then
    Exit(
      TRadIAToolResult.Failed(
        CToolCancelled,
        'Tool execution was cancelled.'
      )
    );

  try
    Result := LTool.Execute(ARequest);
    Result := FViewResolver.Attach(ARequest.ToolName, Result);
  except
    on E: Exception do
      Result := TRadIAToolResult.Failed(
        CToolExecutionFailed,
        E.Message
      );
  end;
end;

function TRadIAToolExecutor.TryGetToolDescriptor(
  const AName: string;
  out ADescriptor: TRadIAToolDescriptor
): Boolean;
var
  LTool: IRadIATool;
begin
  Result := FRegistry.TryResolve(AName, LTool);
  if Result then
    ADescriptor := LTool.Descriptor
  else
    ADescriptor := Default(TRadIAToolDescriptor);
end;

function TRadIAToolExecutor.ValidateRequest(
  const ARequest: TRadIAToolRequest
): TRadIAToolResult;
var
  LJson: TJSONValue;
begin
  if Trim(ARequest.ToolName) = '' then
    Exit(
      TRadIAToolResult.Failed(
        CInvalidRequest,
        'Tool name must not be empty.'
      )
    );

  if Trim(ARequest.CorrelationId) = '' then
    Exit(
      TRadIAToolResult.Failed(
        CInvalidRequest,
        'Correlation ID must not be empty.'
      )
    );

  LJson := TJSONObject.ParseJSONValue(ARequest.ArgumentsJson);
  try
    if not (LJson is TJSONObject) then
      Exit(
        TRadIAToolResult.Failed(
          CInvalidRequest,
          'Tool arguments must be a valid JSON object.'
        )
      );
  finally
    LJson.Free;
  end;

  Result := TRadIAToolResult.Succeeded('{}');
end;

procedure TRadIAToolRegistry.ValidateReplacementTools(
  const ANewTools: TArray<IRadIATool>;
  const ANewNames: TDictionary<string, Byte>
);
var
  LDescriptor: TRadIAToolDescriptor;
  LTool: IRadIATool;
begin
  for LTool in ANewTools do
  begin
    if not Assigned(LTool) then
      raise ERadIAInvalidToolDescriptor.Create('Tool instance must be assigned.');
    LDescriptor := LTool.Descriptor;
    ValidateDescriptor(LDescriptor);
    if ANewNames.ContainsKey(LDescriptor.Name) then
      raise ERadIAToolAlreadyRegistered.CreateFmt(
        'Tool "%s" occurs more than once in the replacement batch.',
        [LDescriptor.Name]
      );
    ANewNames.Add(LDescriptor.Name, 0);
  end;
end;

end.
