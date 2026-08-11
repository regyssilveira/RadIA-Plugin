unit RadIA.Core.PromptHistory;

interface

uses  System.Generics.Collections;

const
  DEFAULT_MAX_PROMPT_HISTORY = 50;

type
  { Manages prompt history navigation (like a terminal up/down arrow) }
  TPromptHistoryManager = class
  private
    FHistory: TList<string>;
    FCurrentIndex: NativeInt;
    FMaxSize: Integer;
  public
    constructor Create(const AMaxSize: Integer = DEFAULT_MAX_PROMPT_HISTORY);
    destructor Destroy; override;

    { Add a prompt to history and reset navigation cursor }
    procedure Add(const APrompt: string);

    { Navigate backwards in history (↑). Returns empty string at oldest boundary. }
    function NavigateUp: string;

    { Navigate forward in history (↓). Returns empty string when past the newest entry. }
    function NavigateDown: string;

    { Reset cursor to "past the end" position (after navigating up and then sending new) }
    procedure ResetCursor;

    { Persist history to JSON file }
    procedure SaveToFile(const AFilePath: string);

    { Load history from JSON file }
    procedure LoadFromFile(const AFilePath: string);

    { Current number of stored prompts }
    function Count: Integer;

    { Retrieve prompt by index (0 = oldest) }
    function GetItem(const AIndex: Integer): string;
  end;

implementation

uses
  System.IOUtils, System.JSON, System.SysUtils;

{ TPromptHistoryManager }

constructor TPromptHistoryManager.Create(const AMaxSize: Integer);
begin
  inherited Create;
  FMaxSize := AMaxSize;
  if FMaxSize <= 0 then
    FMaxSize := DEFAULT_MAX_PROMPT_HISTORY;
  FHistory := TList<string>.Create;
  FCurrentIndex := -1;
end;

destructor TPromptHistoryManager.Destroy;
begin
  FHistory.Free;
  inherited Destroy;
end;

procedure TPromptHistoryManager.Add(const APrompt: string);
begin
  if APrompt.IsEmpty then
    Exit;

  { Avoid duplicate consecutive entries }
  if (FHistory.Count > 0) and (FHistory.Last = APrompt) then
  begin
    ResetCursor;
    Exit;
  end;

  FHistory.Add(APrompt);

  { Enforce max size — discard oldest (FIFO) }
  while FHistory.Count > FMaxSize do
    FHistory.Delete(0);

  ResetCursor;
end;

function TPromptHistoryManager.NavigateUp: string;
begin
  if FHistory.Count = 0 then
  begin
    Result := '';
    Exit;
  end;

  { First ↑ press: go to last item }
  if FCurrentIndex = -1 then
    FCurrentIndex := FHistory.Count - 1
  else if FCurrentIndex > 0 then
    Dec(FCurrentIndex);
  { At index 0 = oldest; stay there }

  Result := FHistory[FCurrentIndex];
end;

function TPromptHistoryManager.NavigateDown: string;
begin
  if (FHistory.Count = 0) or (FCurrentIndex = -1) then
  begin
    Result := '';
    Exit;
  end;

  Inc(FCurrentIndex);

  if FCurrentIndex >= FHistory.Count then
  begin
    { Past the end = back to empty input }
    FCurrentIndex := -1;
    Result := '';
  end
  else
    Result := FHistory[FCurrentIndex];
end;

procedure TPromptHistoryManager.ResetCursor;
begin
  FCurrentIndex := -1;
end;

function TPromptHistoryManager.Count: Integer;
var
  LItem: string;
begin
  Result := 0;
  for LItem in FHistory do
    Inc(Result);
end;

function TPromptHistoryManager.GetItem(const AIndex: Integer): string;
begin
  if (AIndex >= 0) and (AIndex < FHistory.Count) then
    Result := FHistory[AIndex]
  else
    Result := '';
end;

procedure TPromptHistoryManager.SaveToFile(const AFilePath: string);
var
  LJsonArr: TJSONArray;
  LItem: string;
begin
  ForceDirectories(TPath.GetDirectoryName(AFilePath));
  LJsonArr := TJSONArray.Create;
  try
    for LItem in FHistory do
      LJsonArr.Add(LItem);
    TFile.WriteAllText(AFilePath, LJsonArr.ToJSON, TEncoding.UTF8);
  finally
    LJsonArr.Free;
  end;
end;

procedure TPromptHistoryManager.LoadFromFile(const AFilePath: string);
var
  LContent: string;
  LJsonArr: TJSONArray;
  LVal: TJSONValue;
  LParsedVal: TJSONValue;
begin
  FHistory.Clear;
  ResetCursor;

  if not TFile.Exists(AFilePath) then
    Exit;

  try
    LContent := TFile.ReadAllText(AFilePath, TEncoding.UTF8);
    if LContent.IsEmpty then
      Exit;

    LParsedVal := TJSONObject.ParseJSONValue(LContent);
    if Assigned(LParsedVal) then
    begin
      try
        if LParsedVal is TJSONArray then
        begin
          LJsonArr := LParsedVal as TJSONArray;
          for LVal in LJsonArr do
          begin
            if FHistory.Count < FMaxSize then
              FHistory.Add(LVal.Value);
          end;
        end;
      finally
        LParsedVal.Free;
      end;
    end;
  except
    FHistory.Clear;
  end;
end;

end.
