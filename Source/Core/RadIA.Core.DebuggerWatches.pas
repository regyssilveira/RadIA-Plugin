unit RadIA.Core.DebuggerWatches;

interface

uses
  System.Generics.Collections,
  RadIA.Core.Debugger;

type
  IRadIADebuggerWatchService = interface
    ['{4B34AE72-759A-4F54-BB25-9BEE1BBE6B23}']
    function Add(const AExpression: string): Boolean;
    function Remove(const AExpression: string): Boolean;
    function List: TArray<string>;
    function Evaluate(
      const AMaxCount: Integer
    ): TArray<TRadIADebugValueSnapshot>;
    procedure Clear;
  end;

  TRadIADebuggerWatchService = class(
    TInterfacedObject,
    IRadIADebuggerWatchService
  )
  private
    FEvaluator: IRadIADebuggerEvaluationFacade;
    FExpressions: TList<string>;
    function FindExpression(const AExpression: string): Integer;
    function Normalize(const AExpression: string): string;
  public
    constructor Create(
      const AEvaluator: IRadIADebuggerEvaluationFacade
    );
    destructor Destroy; override;
    function Add(const AExpression: string): Boolean;
    function Remove(const AExpression: string): Boolean;
    function List: TArray<string>;
    function Evaluate(
      const AMaxCount: Integer
    ): TArray<TRadIADebugValueSnapshot>;
    procedure Clear;
  end;

implementation

uses
  System.SysUtils;

const
  CMaxExpressionLength = 256;
  CMaxWatches = 32;

function TRadIADebuggerWatchService.Add(
  const AExpression: string
): Boolean;
var
  LExpression: string;
begin
  LExpression := Normalize(AExpression);
  TMonitor.Enter(FExpressions);
  try
    Result := (FExpressions.Count < CMaxWatches) and
      (FindExpression(LExpression) < 0);
    if Result then
      FExpressions.Add(LExpression);
  finally
    TMonitor.Exit(FExpressions);
  end;
end;

procedure TRadIADebuggerWatchService.Clear;
begin
  TMonitor.Enter(FExpressions);
  try
    FExpressions.Clear;
  finally
    TMonitor.Exit(FExpressions);
  end;
end;

constructor TRadIADebuggerWatchService.Create(
  const AEvaluator: IRadIADebuggerEvaluationFacade
);
begin
  inherited Create;
  if not Assigned(AEvaluator) then
    raise EArgumentNilException.Create('AEvaluator');
  FEvaluator := AEvaluator;
  FExpressions := TList<string>.Create;
end;

destructor TRadIADebuggerWatchService.Destroy;
begin
  FExpressions.Free;
  inherited;
end;

function TRadIADebuggerWatchService.Evaluate(
  const AMaxCount: Integer
): TArray<TRadIADebugValueSnapshot>;
var
  LExpressions: TArray<string>;
  LIndex: Integer;
  LLimit: Integer;
begin
  if AMaxCount <= 0 then
    Exit(nil);
  LExpressions := List;
  LLimit := Length(LExpressions);
  if LLimit > AMaxCount then
    LLimit := AMaxCount;
  SetLength(Result, LLimit);
  for LIndex := 0 to LLimit - 1 do
    Result[LIndex] := FEvaluator.EvaluateExpression(
      LExpressions[LIndex]
    );
end;

function TRadIADebuggerWatchService.FindExpression(
  const AExpression: string
): Integer;
var
  LIndex: Integer;
begin
  for LIndex := 0 to FExpressions.Count - 1 do
  begin
    if SameText(FExpressions[LIndex], AExpression) then
      Exit(LIndex);
  end;
  Result := -1;
end;

function TRadIADebuggerWatchService.List: TArray<string>;
begin
  TMonitor.Enter(FExpressions);
  try
    Result := FExpressions.ToArray;
  finally
    TMonitor.Exit(FExpressions);
  end;
end;

function TRadIADebuggerWatchService.Normalize(
  const AExpression: string
): string;
begin
  Result := Trim(AExpression);
  if Result = '' then
    raise EArgumentException.Create(
      'Watch expression must not be empty.'
    );
  if Length(Result) > CMaxExpressionLength then
    raise EArgumentOutOfRangeException.Create(
      'Watch expression exceeds 256 characters.'
    );
  if Result.Contains(#10) or Result.Contains(#13) or
    Result.Contains(#0) then
    raise EArgumentException.Create(
      'Watch expression must use a single text line.'
    );
end;

function TRadIADebuggerWatchService.Remove(
  const AExpression: string
): Boolean;
var
  LIndex: Integer;
begin
  TMonitor.Enter(FExpressions);
  try
    LIndex := FindExpression(Normalize(AExpression));
    Result := LIndex >= 0;
    if Result then
      FExpressions.Delete(LIndex);
  finally
    TMonitor.Exit(FExpressions);
  end;
end;

end.
