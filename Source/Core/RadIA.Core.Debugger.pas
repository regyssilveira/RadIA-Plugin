unit RadIA.Core.Debugger;

interface

type
  TRadIADebuggerAction = (
    daPause,
    daContinue,
    daStepInto,
    daStepOver,
    daStepOut,
    daStop
  );

  TRadIADebuggerActionResult = record
  private
    FAccepted: Boolean;
    FErrorCode: string;
    FMessage: string;
    FStateAfter: string;
    FStateBefore: string;
  public
    class function Failed(
      const AErrorCode: string;
      const AMessage: string;
      const AStateBefore: string
    ): TRadIADebuggerActionResult; static;
    class function Succeeded(
      const AMessage: string;
      const AStateBefore: string;
      const AStateAfter: string
    ): TRadIADebuggerActionResult; static;
    property Accepted: Boolean read FAccepted;
    property ErrorCode: string read FErrorCode;
    property Message: string read FMessage;
    property StateBefore: string read FStateBefore;
    property StateAfter: string read FStateAfter;
  end;

  TRadIACallStackFrame = record
  private
    FFileName: string;
    FHeader: string;
    FIndex: Integer;
    FLineNumber: Integer;
  public
    constructor Create(
      const AIndex: Integer;
      const AHeader: string;
      const AFileName: string;
      const ALineNumber: Integer
    );
    property Index: Integer read FIndex;
    property Header: string read FHeader;
    property FileName: string read FFileName;
    property LineNumber: Integer read FLineNumber;
  end;

  TRadIACallStackSnapshot = record
  private
    FAccessible: Boolean;
    FFrames: TArray<TRadIACallStackFrame>;
    FStatus: string;
  public
    constructor Create(
      const AAccessible: Boolean;
      const AStatus: string;
      const AFrames: TArray<TRadIACallStackFrame>
    );
    property Accessible: Boolean read FAccessible;
    property Status: string read FStatus;
    property Frames: TArray<TRadIACallStackFrame> read FFrames;
  end;

  TRadIADebuggerSnapshot = record
  private
    FAvailable: Boolean;
    FBreakpointCount: Integer;
    FExecutableName: string;
    FLocation: string;
    FOSProcessId: LongWord;
    FProcessId: LongWord;
    FState: string;
    FStatus: string;
    FThreadCount: Integer;
  public
    constructor Create(
      const AAvailable: Boolean;
      const AState: string;
      const AProcessId: LongWord;
      const AExecutableName: string;
      const AThreadCount: Integer;
      const ABreakpointCount: Integer
    );
    procedure SetProcessDetails(
      const AOSProcessId: LongWord;
      const ALocation: string;
      const AStatus: string
    );
    property Available: Boolean read FAvailable;
    property State: string read FState;
    property ProcessId: LongWord read FProcessId;
    property OSProcessId: LongWord read FOSProcessId;
    property ExecutableName: string read FExecutableName;
    property Location: string read FLocation;
    property Status: string read FStatus;
    property ThreadCount: Integer read FThreadCount;
    property BreakpointCount: Integer read FBreakpointCount;
  end;

  TRadIABreakpointSnapshot = record
  private
    FCondition: string;
    FCurrentHitCount: Integer;
    FDoBreak: Boolean;
    FEnabled: Boolean;
    FEvaluateExpression: string;
    FFileName: string;
    FHitCount: Integer;
    FLineNumber: Integer;
    FLogMessage: string;
    FLogResult: Boolean;
    FStackFramesToLog: Integer;
    FThreadCondition: string;
    FValid: Boolean;
  public
    constructor Create(
      const AFileName: string;
      const ALineNumber: Integer;
      const AEnabled: Boolean;
      const AValid: Boolean
    );
    procedure SetAdvanced(
      const ACondition: string;
      const AHitCount: Integer;
      const ACurrentHitCount: Integer;
      const ADoBreak: Boolean;
      const ALogMessage: string;
      const AEvaluateExpression: string;
      const ALogResult: Boolean
    );
    procedure SetAdvancedContext(
      const AStackFramesToLog: Integer;
      const AThreadCondition: string
    );
    property Condition: string read FCondition;
    property CurrentHitCount: Integer read FCurrentHitCount;
    property DoBreak: Boolean read FDoBreak;
    property FileName: string read FFileName;
    property LineNumber: Integer read FLineNumber;
    property Enabled: Boolean read FEnabled;
    property Valid: Boolean read FValid;
    property EvaluateExpression: string read FEvaluateExpression;
    property HitCount: Integer read FHitCount;
    property LogMessage: string read FLogMessage;
    property LogResult: Boolean read FLogResult;
    property StackFramesToLog: Integer read FStackFramesToLog;
    property ThreadCondition: string read FThreadCondition;
  end;

  TRadIADebuggerBreakpointCapabilities = record
  private
    FAvailable: Boolean;
    FCondition: Boolean;
    FExceptionFilters: Boolean;
    FHitCount: Boolean;
    FLogpoint: Boolean;
    FStackFrames: Boolean;
    FThreadCondition: Boolean;
  public
    constructor Create(
      const AAvailable: Boolean;
      const ACondition: Boolean;
      const AHitCount: Boolean;
      const ALogpoint: Boolean;
      const AStackFrames: Boolean;
      const AThreadCondition: Boolean;
      const AExceptionFilters: Boolean
    );
    property Available: Boolean read FAvailable;
    property Condition: Boolean read FCondition;
    property ExceptionFilters: Boolean read FExceptionFilters;
    property HitCount: Boolean read FHitCount;
    property Logpoint: Boolean read FLogpoint;
    property StackFrames: Boolean read FStackFrames;
    property ThreadCondition: Boolean read FThreadCondition;
  end;

  TRadIABreakpointConfiguration = record
  private
    FCondition: string;
    FDoBreak: Boolean;
    FEvaluateExpression: string;
    FHitCount: Integer;
    FLogMessage: string;
    FLogResult: Boolean;
    FStackFramesToLog: Integer;
    FThreadCondition: string;
  public
    property Condition: string read FCondition write FCondition;
    property DoBreak: Boolean read FDoBreak write FDoBreak;
    property EvaluateExpression: string
      read FEvaluateExpression write FEvaluateExpression;
    property HitCount: Integer read FHitCount write FHitCount;
    property LogMessage: string read FLogMessage write FLogMessage;
    property LogResult: Boolean read FLogResult write FLogResult;
    property StackFramesToLog: Integer
      read FStackFramesToLog write FStackFramesToLog;
    property ThreadCondition: string
      read FThreadCondition write FThreadCondition;
  end;

  TRadIADebugValueSnapshot = record
  private
    FAddress: UInt64;
    FCanModify: Boolean;
    FExpression: string;
    FResultText: string;
    FSize: LongWord;
    FStatus: string;
  public
    constructor Create(
      const AExpression: string;
      const AResultText: string;
      const AStatus: string;
      const ACanModify: Boolean;
      const AAddress: UInt64;
      const ASize: LongWord
    );
    property Expression: string read FExpression;
    property ResultText: string read FResultText;
    property Status: string read FStatus;
    property CanModify: Boolean read FCanModify;
    property Address: UInt64 read FAddress;
    property Size: LongWord read FSize;
  end;

  IRadIADebuggerFacade = interface
    ['{0D0DA4E7-C0B9-4329-B97E-511543BA89F1}']
    function GetDebuggerState: TRadIADebuggerSnapshot;
    function ListBreakpoints(
      const AMaxCount: Integer
    ): TArray<TRadIABreakpointSnapshot>;
    function GetCallStack(
      const AMaxCount: Integer
    ): TRadIACallStackSnapshot;
  end;

  IRadIADebuggerRuntimeFacade = interface
    ['{B664E55F-0A56-49DA-A5EB-30749E5A47A6}']
    function ResolveRuntimeProcess(
      out AProcessId: LongWord;
      out ACreatedAtUtc: TDateTime;
      out AExecutablePath: string;
      out ABuildId: string
    ): Boolean;
  end;

  IRadIADebuggerControlFacade = interface
    ['{09E0E712-C0D2-4DEB-972C-A70DF3E56BC8}']
    function ExecuteAction(
      const AAction: TRadIADebuggerAction
    ): TRadIADebuggerActionResult;
  end;

  IRadIADebuggerBreakpointFacade = interface
    ['{3AF9402E-C816-47B4-83E5-275D02BFA9F0}']
    function HasSourceBreakpoint(
      const AFileName: string;
      const ALineNumber: Integer
    ): Boolean;
    function AddSourceBreakpoint(
      const AFileName: string;
      const ALineNumber: Integer
    ): Boolean;
    function RemoveSourceBreakpoint(
      const AFileName: string;
      const ALineNumber: Integer
    ): Boolean;
    function GetBreakpointCapabilities:
      TRadIADebuggerBreakpointCapabilities;
    function GetSourceBreakpointConfiguration(
      const AFileName: string;
      const ALineNumber: Integer;
      out AConfiguration: TRadIABreakpointConfiguration;
      out AError: string
    ): Boolean;
    function ConfigureSourceBreakpoint(
      const AFileName: string;
      const ALineNumber: Integer;
      const AConfiguration: TRadIABreakpointConfiguration;
      out APrevious: TRadIABreakpointConfiguration;
      out AError: string
    ): Boolean;
  end;

  IRadIADebuggerEvaluationFacade = interface
    ['{54E195CF-9D78-462D-93E8-E38F0A8EB923}']
    function EvaluateExpression(
      const AExpression: string
    ): TRadIADebugValueSnapshot;
  end;

  IRadIADebuggerSessionFacade = interface
    ['{189FDF6A-A8C7-498A-B3E5-00943969A75F}']
    function StartDebugging: TRadIADebuggerActionResult;
    function StartRuntimeProcess(
      out AProcessId: LongWord;
      out ACreatedAtUtc: TDateTime;
      out AExecutablePath: string;
      out ABuildId: string
    ): TRadIADebuggerActionResult;
    function StopRuntimeProcess(const AProcessId: LongWord): Boolean;
  end;

implementation

{ TRadIADebuggerActionResult }

class function TRadIADebuggerActionResult.Failed(
  const AErrorCode: string;
  const AMessage: string;
  const AStateBefore: string
): TRadIADebuggerActionResult;
begin
  Result.FAccepted := False;
  Result.FErrorCode := AErrorCode;
  Result.FMessage := AMessage;
  Result.FStateBefore := AStateBefore;
  Result.FStateAfter := AStateBefore;
end;

class function TRadIADebuggerActionResult.Succeeded(
  const AMessage: string;
  const AStateBefore: string;
  const AStateAfter: string
): TRadIADebuggerActionResult;
begin
  Result.FAccepted := True;
  Result.FErrorCode := '';
  Result.FMessage := AMessage;
  Result.FStateBefore := AStateBefore;
  Result.FStateAfter := AStateAfter;
end;

{ TRadIACallStackFrame }

constructor TRadIACallStackFrame.Create(
  const AIndex: Integer;
  const AHeader: string;
  const AFileName: string;
  const ALineNumber: Integer
);
begin
  FIndex := AIndex;
  FHeader := AHeader;
  FFileName := AFileName;
  FLineNumber := ALineNumber;
end;

{ TRadIACallStackSnapshot }

constructor TRadIACallStackSnapshot.Create(
  const AAccessible: Boolean;
  const AStatus: string;
  const AFrames: TArray<TRadIACallStackFrame>
);
begin
  FAccessible := AAccessible;
  FStatus := AStatus;
  FFrames := AFrames;
end;

{ TRadIADebuggerSnapshot }

constructor TRadIADebuggerSnapshot.Create(
  const AAvailable: Boolean;
  const AState: string;
  const AProcessId: LongWord;
  const AExecutableName: string;
  const AThreadCount: Integer;
  const ABreakpointCount: Integer
);
begin
  FAvailable := AAvailable;
  FState := AState;
  FProcessId := AProcessId;
  FExecutableName := AExecutableName;
  FThreadCount := AThreadCount;
  FBreakpointCount := ABreakpointCount;
  FOSProcessId := 0;
  FLocation := '';
  FStatus := '';
end;

procedure TRadIADebuggerSnapshot.SetProcessDetails(
  const AOSProcessId: LongWord;
  const ALocation: string;
  const AStatus: string
);
begin
  FOSProcessId := AOSProcessId;
  FLocation := ALocation;
  FStatus := AStatus;
end;

{ TRadIABreakpointSnapshot }

constructor TRadIABreakpointSnapshot.Create(
  const AFileName: string;
  const ALineNumber: Integer;
  const AEnabled: Boolean;
  const AValid: Boolean
);
begin
  FFileName := AFileName;
  FLineNumber := ALineNumber;
  FEnabled := AEnabled;
  FValid := AValid;
end;

procedure TRadIABreakpointSnapshot.SetAdvanced(
  const ACondition: string;
  const AHitCount: Integer;
  const ACurrentHitCount: Integer;
  const ADoBreak: Boolean;
  const ALogMessage: string;
  const AEvaluateExpression: string;
  const ALogResult: Boolean
);
begin
  FCondition := ACondition;
  FHitCount := AHitCount;
  FCurrentHitCount := ACurrentHitCount;
  FDoBreak := ADoBreak;
  FLogMessage := ALogMessage;
  FEvaluateExpression := AEvaluateExpression;
  FLogResult := ALogResult;
end;

procedure TRadIABreakpointSnapshot.SetAdvancedContext(
  const AStackFramesToLog: Integer;
  const AThreadCondition: string
);
begin
  FStackFramesToLog := AStackFramesToLog;
  FThreadCondition := AThreadCondition;
end;

{ TRadIADebuggerBreakpointCapabilities }

constructor TRadIADebuggerBreakpointCapabilities.Create(
  const AAvailable: Boolean;
  const ACondition: Boolean;
  const AHitCount: Boolean;
  const ALogpoint: Boolean;
  const AStackFrames: Boolean;
  const AThreadCondition: Boolean;
  const AExceptionFilters: Boolean
);
begin
  FAvailable := AAvailable;
  FCondition := ACondition;
  FHitCount := AHitCount;
  FLogpoint := ALogpoint;
  FStackFrames := AStackFrames;
  FThreadCondition := AThreadCondition;
  FExceptionFilters := AExceptionFilters;
end;

{ TRadIADebugValueSnapshot }

constructor TRadIADebugValueSnapshot.Create(
  const AExpression: string;
  const AResultText: string;
  const AStatus: string;
  const ACanModify: Boolean;
  const AAddress: UInt64;
  const ASize: LongWord
);
begin
  FExpression := AExpression;
  FResultText := AResultText;
  FStatus := AStatus;
  FCanModify := ACanModify;
  FAddress := AAddress;
  FSize := ASize;
end;

end.
