unit RadIA.Core.ProblemProjection;

interface

type
  TRadIAProjectedProblem = record
  private
    FColumn: Integer;
    FFileName: string;
    FLine: Integer;
    FMessage: string;
    FSeverity: string;
    FTitle: string;
  public
    constructor Create(
      const ATitle: string;
      const AMessage: string;
      const ASeverity: string;
      const AFileName: string;
      const ALine: Integer;
      const AColumn: Integer
    );
    property Column: Integer read FColumn;
    property FileName: string read FFileName;
    property Line: Integer read FLine;
    property Message: string read FMessage;
    property Severity: string read FSeverity;
    property Title: string read FTitle;
  end;

  IRadIAProblemProjector = interface
    ['{056E2259-42BA-4BF0-A981-68812F1DE910}']
    function ProjectSnapshot(
      const AJson: string;
      out AProjectedCount: Integer;
      out AError: string
    ): Boolean;
  end;

  TRadIAProblemProjectionParser = class
  private
    class function BoundedText(
      const AValue: string;
      const AMaximumLength: Integer
    ): string; static;
    class function JsonInteger(
      const AObject: TObject;
      const AName: string
    ): Integer; static;
    class function JsonText(
      const AObject: TObject;
      const AName: string
    ): string; static;
    class function NormalizeSeverity(const AValue: string): string; static;
  public
    class function Parse(
      const AJson: string;
      out AProblems: TArray<TRadIAProjectedProblem>;
      out AError: string
    ): Boolean; static;
  end;

implementation

uses
  System.Generics.Collections,
  System.JSON,
  System.Math,
  System.SysUtils;

const
  CMaximumProblems = 200;
  CMaximumFileNameLength = 1024;
  CMaximumMessageLength = 2000;
  CMaximumTitleLength = 200;

{ TRadIAProjectedProblem }

constructor TRadIAProjectedProblem.Create(
  const ATitle: string;
  const AMessage: string;
  const ASeverity: string;
  const AFileName: string;
  const ALine: Integer;
  const AColumn: Integer
);
begin
  FTitle := ATitle;
  FMessage := AMessage;
  FSeverity := ASeverity;
  FFileName := AFileName;
  FLine := Max(0, ALine);
  FColumn := Max(0, AColumn);
end;

{ TRadIAProblemProjectionParser }

class function TRadIAProblemProjectionParser.BoundedText(
  const AValue: string;
  const AMaximumLength: Integer
): string;
begin
  Result := AValue.Trim;
  if Length(Result) > AMaximumLength then
    SetLength(Result, AMaximumLength);
end;

class function TRadIAProblemProjectionParser.JsonInteger(
  const AObject: TObject;
  const AName: string
): Integer;
var
  LValue: TJSONValue;
begin
  Result := 0;
  if not (AObject is TJSONObject) then
    Exit;
  LValue := TJSONObject(AObject).GetValue(AName);
  if Assigned(LValue) then
    Result := StrToIntDef(LValue.Value, 0);
end;

class function TRadIAProblemProjectionParser.JsonText(
  const AObject: TObject;
  const AName: string
): string;
var
  LValue: TJSONValue;
begin
  Result := '';
  if not (AObject is TJSONObject) then
    Exit;
  LValue := TJSONObject(AObject).GetValue(AName);
  if Assigned(LValue) and not (LValue is TJSONNull) then
    Result := LValue.Value;
end;

class function TRadIAProblemProjectionParser.NormalizeSeverity(
  const AValue: string
): string;
begin
  Result := LowerCase(AValue.Trim);
  if (Result <> 'critical') and (Result <> 'error') and
    (Result <> 'warning') and (Result <> 'information') then
    Result := 'information';
end;

class function TRadIAProblemProjectionParser.Parse(
  const AJson: string;
  out AProblems: TArray<TRadIAProjectedProblem>;
  out AError: string
): Boolean;
var
  LArray: TJSONArray;
  LIndex: Integer;
  LItem: TJSONObject;
  LMessage: string;
  LProblems: TList<TRadIAProjectedProblem>;
  LRoot: TJSONValue;
  LTitle: string;
begin
  AProblems := nil;
  AError := '';
  LRoot := TJSONObject.ParseJSONValue(AJson);
  try
    if not (LRoot is TJSONArray) then
    begin
      AError := 'Problems projection requires a JSON array.';
      Exit(False);
    end;
    LArray := TJSONArray(LRoot);
    LProblems := TList<TRadIAProjectedProblem>.Create;
    try
      for LIndex := 0 to Min(LArray.Count, CMaximumProblems) - 1 do
      begin
        if not (LArray.Items[LIndex] is TJSONObject) then
          Continue;
        LItem := TJSONObject(LArray.Items[LIndex]);
        LMessage := BoundedText(
          JsonText(LItem, 'message'),
          CMaximumMessageLength
        );
        if LMessage.IsEmpty then
          Continue;
        LTitle := BoundedText(
          JsonText(LItem, 'title'),
          CMaximumTitleLength
        );
        if LTitle.IsEmpty then
          LTitle := BoundedText(
            JsonText(LItem, 'code'),
            CMaximumTitleLength
          );
        if LTitle.IsEmpty then
          LTitle := 'Problem';
        LProblems.Add(TRadIAProjectedProblem.Create(
          LTitle,
          LMessage,
          NormalizeSeverity(JsonText(LItem, 'severity')),
          BoundedText(
            JsonText(LItem, 'fileName'),
            CMaximumFileNameLength
          ),
          JsonInteger(LItem, 'line'),
          JsonInteger(LItem, 'column')
        ));
      end;
      AProblems := LProblems.ToArray;
      Result := True;
    finally
      LProblems.Free;
    end;
  finally
    LRoot.Free;
  end;
end;

end.
