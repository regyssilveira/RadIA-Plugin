unit RadIA.Core.DebuggerTools;

interface

uses
  RadIA.Core.Debugger,
  RadIA.Core.Tools;

procedure RegisterRadIADebuggerTools(
  const ARegistry: IRadIAToolRegistry;
  const ADebugger: IRadIADebuggerFacade
);

implementation

uses
  System.JSON,
  System.SysUtils;

type
  TRadIADebuggerToolKind = (
    dbtkGetDebuggerState,
    dbtkListBreakpoints,
    dbtkGetCallStack
  );

  TRadIADebuggerTool = class(TInterfacedObject, IRadIATool)
  private
    FDebugger: IRadIADebuggerFacade;
    FKind: TRadIADebuggerToolKind;
    function ExecuteGetState: TRadIAToolResult;
    function ExecuteListBreakpoints(
      const ARequest: TRadIAToolRequest
    ): TRadIAToolResult;
    function ExecuteGetCallStack(
      const ARequest: TRadIAToolRequest
    ): TRadIAToolResult;
    function GetDescriptor: TRadIAToolDescriptor;
    function GetMaxCount(const AArgumentsJson: string): Integer;
  public
    constructor Create(
      const AKind: TRadIADebuggerToolKind;
      const ADebugger: IRadIADebuggerFacade
    );
    function Execute(
      const ARequest: TRadIAToolRequest
    ): TRadIAToolResult;
  end;

const
  CEmptyInputSchema =
    '{"type":"object","additionalProperties":false}';
  CListInputSchema =
    '{"type":"object","properties":{"maxCount":{"type":"integer","minimum":1,' +
    '"maximum":1000}},"additionalProperties":false}';
  CObjectOutputSchema = '{"type":"object"}';

procedure RegisterRadIADebuggerTools(
  const ARegistry: IRadIAToolRegistry;
  const ADebugger: IRadIADebuggerFacade
);
var
  LKind: TRadIADebuggerToolKind;
begin
  if not Assigned(ARegistry) then
    raise EArgumentNilException.Create('ARegistry');
  if not Assigned(ADebugger) then
    raise EArgumentNilException.Create('ADebugger');

  for LKind := Low(TRadIADebuggerToolKind) to
    High(TRadIADebuggerToolKind) do
    ARegistry.RegisterTool(
      TRadIADebuggerTool.Create(LKind, ADebugger)
    );
end;

{ TRadIADebuggerTool }

constructor TRadIADebuggerTool.Create(
  const AKind: TRadIADebuggerToolKind;
  const ADebugger: IRadIADebuggerFacade
);
begin
  inherited Create;
  if not Assigned(ADebugger) then
    raise EArgumentNilException.Create('ADebugger');
  FKind := AKind;
  FDebugger := ADebugger;
end;

function TRadIADebuggerTool.Execute(
  const ARequest: TRadIAToolRequest
): TRadIAToolResult;
begin
  case FKind of
    dbtkGetDebuggerState:
      Result := ExecuteGetState;
    dbtkListBreakpoints:
      Result := ExecuteListBreakpoints(ARequest);
    dbtkGetCallStack:
      Result := ExecuteGetCallStack(ARequest);
  else
    Result := TRadIAToolResult.Failed(
      'unsupported_tool',
      'Debugger tool kind is not supported.'
    );
  end;
end;

function TRadIADebuggerTool.ExecuteGetCallStack(
  const ARequest: TRadIAToolRequest
): TRadIAToolResult;
var
  LArray: TJSONArray;
  LFrame: TRadIACallStackFrame;
  LItem: TJSONObject;
  LRoot: TJSONObject;
  LSnapshot: TRadIACallStackSnapshot;
begin
  LSnapshot := FDebugger.GetCallStack(
    GetMaxCount(ARequest.ArgumentsJson)
  );
  LRoot := TJSONObject.Create;
  try
    LRoot.AddPair(
      'accessible',
      TJSONBool.Create(LSnapshot.Accessible)
    );
    LRoot.AddPair('status', LSnapshot.Status);
    LArray := TJSONArray.Create;
    LRoot.AddPair('frames', LArray);
    for LFrame in LSnapshot.Frames do
    begin
      LItem := TJSONObject.Create;
      LItem.AddPair('index', TJSONNumber.Create(LFrame.Index));
      LItem.AddPair('header', LFrame.Header);
      LItem.AddPair('fileName', LFrame.FileName);
      LItem.AddPair(
        'lineNumber',
        TJSONNumber.Create(LFrame.LineNumber)
      );
      LArray.AddElement(LItem);
    end;
    LRoot.AddPair(
      'count',
      TJSONNumber.Create(Length(LSnapshot.Frames))
    );
    Result := TRadIAToolResult.Succeeded(LRoot.ToJSON);
  finally
    LRoot.Free;
  end;
end;

function TRadIADebuggerTool.ExecuteGetState:
  TRadIAToolResult;
var
  LJson: TJSONObject;
  LState: TRadIADebuggerSnapshot;
begin
  LState := FDebugger.GetDebuggerState;
  LJson := TJSONObject.Create;
  try
    LJson.AddPair('available', TJSONBool.Create(LState.Available));
    LJson.AddPair('state', LState.State);
    LJson.AddPair(
      'processId',
      TJSONNumber.Create(LState.ProcessId)
    );
    LJson.AddPair(
      'osProcessId',
      TJSONNumber.Create(LState.OSProcessId)
    );
    LJson.AddPair('executableName', LState.ExecutableName);
    LJson.AddPair('location', LState.Location);
    LJson.AddPair('status', LState.Status);
    LJson.AddPair(
      'threadCount',
      TJSONNumber.Create(LState.ThreadCount)
    );
    LJson.AddPair(
      'breakpointCount',
      TJSONNumber.Create(LState.BreakpointCount)
    );
    Result := TRadIAToolResult.Succeeded(LJson.ToJSON);
  finally
    LJson.Free;
  end;
end;

function TRadIADebuggerTool.ExecuteListBreakpoints(
  const ARequest: TRadIAToolRequest
): TRadIAToolResult;
var
  LArray: TJSONArray;
  LBreakpoint: TRadIABreakpointSnapshot;
  LBreakpoints: TArray<TRadIABreakpointSnapshot>;
  LItem: TJSONObject;
  LRoot: TJSONObject;
begin
  LBreakpoints := FDebugger.ListBreakpoints(
    GetMaxCount(ARequest.ArgumentsJson)
  );
  LRoot := TJSONObject.Create;
  try
    LArray := TJSONArray.Create;
    LRoot.AddPair('breakpoints', LArray);
    for LBreakpoint in LBreakpoints do
    begin
      LItem := TJSONObject.Create;
      LItem.AddPair('fileName', LBreakpoint.FileName);
      LItem.AddPair(
        'lineNumber',
        TJSONNumber.Create(LBreakpoint.LineNumber)
      );
      LItem.AddPair(
        'enabled',
        TJSONBool.Create(LBreakpoint.Enabled)
      );
      LItem.AddPair(
        'valid',
        TJSONBool.Create(LBreakpoint.Valid)
      );
      LArray.AddElement(LItem);
    end;
    LRoot.AddPair(
      'count',
      TJSONNumber.Create(Length(LBreakpoints))
    );
    Result := TRadIAToolResult.Succeeded(LRoot.ToJSON);
  finally
    LRoot.Free;
  end;
end;

function TRadIADebuggerTool.GetDescriptor:
  TRadIAToolDescriptor;
begin
  case FKind of
    dbtkGetDebuggerState:
      Result := TRadIAToolDescriptor.Create(
        'GetDebuggerState',
        '1.0',
        'Returns a read-only snapshot of the IDE debugger.',
        CEmptyInputSchema,
        CObjectOutputSchema,
        trReadOnly
      );
    dbtkListBreakpoints:
      Result := TRadIAToolDescriptor.Create(
        'ListBreakpoints',
        '1.0',
        'Lists source breakpoints without changing debugger state.',
        CListInputSchema,
        CObjectOutputSchema,
        trReadOnly
      );
    dbtkGetCallStack:
      Result := TRadIAToolDescriptor.Create(
        'GetCallStack',
        '1.0',
        'Returns the current debugger thread call stack without changing execution.',
        CListInputSchema,
        CObjectOutputSchema,
        trReadOnly
      );
  else
    Result := Default(TRadIAToolDescriptor);
  end;
end;

function TRadIADebuggerTool.GetMaxCount(
  const AArgumentsJson: string
): Integer;
var
  LJson: TJSONObject;
  LValue: TJSONValue;
begin
  Result := 200;
  if Trim(AArgumentsJson) = '' then
    Exit;

  LJson := TJSONObject.ParseJSONValue(AArgumentsJson) as TJSONObject;
  if not Assigned(LJson) then
    raise EArgumentException.Create('Arguments must be a JSON object.');
  try
    LValue := LJson.GetValue('maxCount');
    if Assigned(LValue) then
    begin
      if not (LValue is TJSONNumber) then
        raise EArgumentException.Create('maxCount must be an integer.');
      Result := TJSONNumber(LValue).AsInt;
    end;
    if (Result < 1) or (Result > 1000) then
      raise EArgumentOutOfRangeException.Create(
        'maxCount must be between 1 and 1000.'
      );
  finally
    LJson.Free;
  end;
end;

end.
