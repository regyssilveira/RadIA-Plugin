unit RadIA.Core.ResultCompactor;

interface

uses
  System.JSON;

type
  TRadIACompactionProfile = (
    cpOff,
    cpConservative,
    cpBalanced
  );

  TRadIAResultCompaction = record
  private
    FCompactedJson: string;
    FOriginalCharacters: Integer;
    FCompactedCharacters: Integer;
    FCompacted: Boolean;
    FDurationMicroseconds: Int64;
    FRuleName: string;
  public
    constructor Create(
      const ACompactedJson: string;
      const AOriginalCharacters: Integer;
      const ACompactedCharacters: Integer;
      const ACompacted: Boolean;
      const ARuleName: string = '';
      const ADurationMicroseconds: Int64 = 0
    );
    property CompactedJson: string read FCompactedJson;
    property OriginalCharacters: Integer read FOriginalCharacters;
    property CompactedCharacters: Integer read FCompactedCharacters;
    property Compacted: Boolean read FCompacted;
    property DurationMicroseconds: Int64 read FDurationMicroseconds;
    property RuleName: string read FRuleName;
  end;

  IRadIAResultCompactor = interface
    ['{C1F01321-608C-4741-A397-8FD27A55AADB}']
    function CompactResult(
      const AToolName: string;
      const AResultJson: string;
      const AProfile: TRadIACompactionProfile
    ): TRadIAResultCompaction;
  end;

  TRadIAResultCompactor = class(
    TInterfacedObject,
    IRadIAResultCompactor
  )
  private
    class procedure CompactBuildMessages(const ARoot: TJSONObject); static;
    class procedure CompactKnowledgeItems(const ARoot: TJSONObject); static;
    class procedure CompactListItems(const ARoot: TJSONObject); static;
    class function CompactLines(const AText: string): string; static;
    class function CompactText(const AText: string): string; static;
    class function ExtractCriticalLines(const AText: string): string; static;
    class function IsCompactableField(
      const AToolName: string;
      const AFieldName: string
    ): Boolean; static;
    class function StripAnsi(const AText: string): string; static;
  public
    function CompactResult(
      const AToolName: string;
      const AResultJson: string;
      const AProfile: TRadIACompactionProfile
    ): TRadIAResultCompaction;
    class function Compact(
      const AToolName: string;
      const AResultJson: string
    ): TRadIAResultCompaction; static;
  end;

function RadIACompactionProfileName(
  const AProfile: TRadIACompactionProfile
): string;
function RadIAResolveCompactionProfile: TRadIACompactionProfile;

implementation

uses
  System.Classes,
  System.Diagnostics,
  System.Math,
  System.StrUtils,
  System.SysUtils,
  RadIA.Core.ResultCompactionSettings;

const
  CMaximumCompactedTextCharacters = 24000;
  CCompactedTextHeadCharacters = 8000;
  CCompactedTextTailCharacters = 5000;
  CCompactionMarker =
    sLineBreak + '[RadIA omitted repetitive or middle output]' + sLineBreak;

function RadIACompactionProfileName(
  const AProfile: TRadIACompactionProfile
): string;
begin
  case AProfile of
    cpOff: Result := 'Off';
    cpBalanced: Result := 'Balanced';
  else
    Result := 'Conservative';
  end;
end;

function RadIAResolveCompactionProfile: TRadIACompactionProfile;
var
  LValue: string;
  LSettingsStore: TRadIAResultCompactionSettingsStore;
begin
  LValue := Trim(GetEnvironmentVariable('RADIA_RESULT_COMPACTION_PROFILE'));
  if LValue = '' then
  begin
    LSettingsStore := TRadIAResultCompactionSettingsStore.Create;
    try
      LValue := LSettingsStore.Load.ProfileName;
    finally
      LSettingsStore.Free;
    end;
  end;
  if SameText(LValue, 'Off') then
    Exit(cpOff);
  if SameText(LValue, 'Balanced') then
    Exit(cpBalanced);
  Result := cpConservative;
end;

{ TRadIAResultCompaction }

constructor TRadIAResultCompaction.Create(
  const ACompactedJson: string;
  const AOriginalCharacters: Integer;
  const ACompactedCharacters: Integer;
  const ACompacted: Boolean;
  const ARuleName: string;
  const ADurationMicroseconds: Int64
);
begin
  FCompactedJson := ACompactedJson;
  FOriginalCharacters := AOriginalCharacters;
  FCompactedCharacters := ACompactedCharacters;
  FCompacted := ACompacted;
  FRuleName := ARuleName;
  FDurationMicroseconds := ADurationMicroseconds;
end;

{ TRadIAResultCompactor }

class function TRadIAResultCompactor.Compact(
  const AToolName: string;
  const AResultJson: string
): TRadIAResultCompaction;
var
  LCompactedText: string;
  LFieldName: string;
  LPair: TJSONPair;
  LRoot: TJSONObject;
  LStarted: Int64;
begin
  LStarted := TStopwatch.GetTimeStamp;
  Result := TRadIAResultCompaction.Create(
    AResultJson,
    Length(AResultJson),
    Length(AResultJson),
    False
  );
  LRoot := TJSONObject.ParseJSONValue(AResultJson) as TJSONObject;
  if not Assigned(LRoot) then
    Exit;
  try
    if SameText(AToolName, 'BuildProject') then
      CompactBuildMessages(LRoot);
    if SameText(AToolName, 'SearchKnowledge') or
      SameText(AToolName, 'RetrieveKnowledge') then
      CompactKnowledgeItems(LRoot);
    if SameText(AToolName, 'ListOpenFiles') or
      SameText(AToolName, 'ListProjectUnits') or
      SameText(AToolName, 'GetUnitSymbols') or
      SameText(AToolName, 'ListIDEActions') or
      SameText(AToolName, 'ListProjectGroupProjects') then
      CompactListItems(LRoot);
    for LFieldName in ['output', 'diff'] do
    begin
      if not IsCompactableField(AToolName, LFieldName) then
        Continue;
      LPair := LRoot.RemovePair(LFieldName);
      if not Assigned(LPair) then
        Continue;
      try
        LCompactedText := CompactText(LPair.JsonValue.Value);
      finally
        LPair.Free;
      end;
      LRoot.AddPair(LFieldName, LCompactedText);
    end;
    LCompactedText := LRoot.ToJSON;
    if Length(LCompactedText) >= Length(AResultJson) then
      Exit;
    Result := TRadIAResultCompaction.Create(
      LCompactedText,
      Length(AResultJson),
      Length(LCompactedText),
      Length(LCompactedText) < Length(AResultJson),
      LowerCase(AToolName),
      Round(
        (TStopwatch.GetTimeStamp - LStarted) * 1000000 /
        TStopwatch.Frequency
      )
    );
  finally
    LRoot.Free;
  end;
end;

class procedure TRadIAResultCompactor.CompactListItems(
  const ARoot: TJSONObject
);
const
  CMaximumListItems = 50;
  CPreservedListHead = 30;
  CPreservedListTail = 20;
var
  LArray: TJSONArray;
  LArrayName: string;
  LIndex: Integer;
  LNewArray: TJSONArray;
  LOmitted: Integer;
  LPair: TJSONPair;
  LValue: TJSONValue;
begin
  for LArrayName in ['items', 'symbols', 'actions', 'projects'] do
  begin
    LValue := ARoot.GetValue(LArrayName);
    if not (LValue is TJSONArray) then
      Continue;
    LArray := TJSONArray(LValue);
    if LArray.Count <= CMaximumListItems then
      Continue;
    LNewArray := TJSONArray.Create;
    try
      for LIndex := 0 to CPreservedListHead - 1 do
        LNewArray.AddElement(TJSONObject.ParseJSONValue(LArray[LIndex].ToJSON));
      for LIndex := LArray.Count - CPreservedListTail to LArray.Count - 1 do
        LNewArray.AddElement(TJSONObject.ParseJSONValue(LArray[LIndex].ToJSON));
      LOmitted := LArray.Count - LNewArray.Count;
      LPair := ARoot.RemovePair(LArrayName);
      LPair.Free;
      ARoot.AddPair(LArrayName, LNewArray);
      LNewArray := nil;
      ARoot.AddPair(
        'omitted' + UpperCase(Copy(LArrayName, 1, 1)) +
          Copy(LArrayName, 2, MaxInt),
        TJSONNumber.Create(LOmitted)
      );
    finally
      LNewArray.Free;
    end;
  end;
end;

class procedure TRadIAResultCompactor.CompactBuildMessages(
  const ARoot: TJSONObject
);
const
  CMaximumRoutineMessages = 60;
var
  LIndex: Integer;
  LKeptRoutineMessages: Integer;
  LMessage: TJSONObject;
  LMessages: TJSONArray;
  LNewMessages: TJSONArray;
  LOmitted: Integer;
  LPair: TJSONPair;
  LText: string;
  LValue: TJSONValue;
begin
  LValue := ARoot.GetValue('messages');
  if not (LValue is TJSONArray) then
    Exit;
  LMessages := TJSONArray(LValue);
  if LMessages.Count <= CMaximumRoutineMessages then
    Exit;
  LNewMessages := TJSONArray.Create;
  try
    LKeptRoutineMessages := 0;
    LOmitted := 0;
    for LIndex := 0 to LMessages.Count - 1 do
    begin
      if not (LMessages[LIndex] is TJSONObject) then
      begin
        Inc(LOmitted);
        Continue;
      end;
      LMessage := TJSONObject(LMessages[LIndex]);
      LText := LMessage.GetValue<string>('text', '');
      if ContainsText(LText, 'error') or ContainsText(LText, 'fatal') or
        (LKeptRoutineMessages < CMaximumRoutineMessages) then
      begin
        LNewMessages.AddElement(TJSONObject.ParseJSONValue(LMessage.ToJSON));
        if not ContainsText(LText, 'error') and
          not ContainsText(LText, 'fatal') then
          Inc(LKeptRoutineMessages);
      end
      else
        Inc(LOmitted);
    end;
    if LOmitted = 0 then
      Exit;
    LPair := ARoot.RemovePair('messages');
    LPair.Free;
    ARoot.AddPair('messages', LNewMessages);
    LNewMessages := nil;
    ARoot.AddPair('omittedRoutineMessages', TJSONNumber.Create(LOmitted));
  finally
    LNewMessages.Free;
  end;
end;

class procedure TRadIAResultCompactor.CompactKnowledgeItems(
  const ARoot: TJSONObject
);
const
  CMaximumKnowledgeContentCharacters = 4000;
var
  LArray: TJSONArray;
  LArrayName: string;
  LContent: string;
  LIndex: Integer;
  LItem: TJSONObject;
  LPair: TJSONPair;
  LValue: TJSONValue;
begin
  for LArrayName in ['results', 'documents', 'chunks'] do
  begin
    LValue := ARoot.GetValue(LArrayName);
    if not (LValue is TJSONArray) then
      Continue;
    LArray := TJSONArray(LValue);
    for LIndex := 0 to LArray.Count - 1 do
    begin
      if not (LArray[LIndex] is TJSONObject) then
        Continue;
      LItem := TJSONObject(LArray[LIndex]);
      LContent := LItem.GetValue<string>('content', '');
      if Length(LContent) <= CMaximumKnowledgeContentCharacters then
        Continue;
      LPair := LItem.RemovePair('content');
      LPair.Free;
      LItem.AddPair(
        'content',
        Copy(LContent, 1, 2800) + CCompactionMarker +
          Copy(LContent, Length(LContent) - 999, 1000)
      );
      LItem.AddPair(
        'originalContentCharacters',
        TJSONNumber.Create(Length(LContent))
      );
    end;
  end;
end;

function TRadIAResultCompactor.CompactResult(
  const AToolName: string;
  const AResultJson: string;
  const AProfile: TRadIACompactionProfile
): TRadIAResultCompaction;
begin
  if AProfile = cpOff then
  begin
    Result := TRadIAResultCompaction.Create(
      AResultJson,
      Length(AResultJson),
      Length(AResultJson),
      False
    );
    Exit;
  end;
  Result := Compact(AToolName, AResultJson);
end;

class function TRadIAResultCompactor.CompactLines(
  const AText: string
): string;
var
  LCount: Integer;
  LIndex: Integer;
  LLastLine: string;
  LLines: TStringList;
  LOutput: TStringList;
begin
  LLines := TStringList.Create;
  try
    LOutput := TStringList.Create;
    try
      LLines.Text := AText;
      LCount := 0;
      LLastLine := '';
      for LIndex := 0 to LLines.Count - 1 do
      begin
        if (LLines[LIndex] = LLastLine) and (LLastLine <> '') then
        begin
          Inc(LCount);
          Continue;
        end;
        if LCount > 0 then
          LOutput.Add(Format('[previous line repeated %d times]', [LCount]));
        LLastLine := LLines[LIndex];
        LCount := 0;
        LOutput.Add(LLines[LIndex]);
      end;
      if LCount > 0 then
        LOutput.Add(Format('[previous line repeated %d times]', [LCount]));
      Result := LOutput.Text.TrimRight;
    finally
      LOutput.Free;
    end;
  finally
    LLines.Free;
  end;
end;

class function TRadIAResultCompactor.CompactText(
  const AText: string
): string;
var
  LCriticalLines: string;
begin
  Result := CompactLines(StripAnsi(AText));
  if Length(Result) <= CMaximumCompactedTextCharacters then
    Exit;
  LCriticalLines := ExtractCriticalLines(Result);
  Result := Copy(Result, 1, CCompactedTextHeadCharacters) +
    CCompactionMarker + LCriticalLines + CCompactionMarker +
    Copy(
      Result,
      Max(1, Length(Result) - CCompactedTextTailCharacters + 1),
      CCompactedTextTailCharacters
    );
end;

class function TRadIAResultCompactor.ExtractCriticalLines(
  const AText: string
): string;
const
  CMaximumCriticalLineCharacters = 1000;
var
  LIndex: Integer;
  LLine: string;
  LLines: TStringList;
  LOutput: TStringList;
begin
  LLines := TStringList.Create;
  try
    LOutput := TStringList.Create;
    try
      LLines.Text := AText;
      for LIndex := 0 to LLines.Count - 1 do
      begin
        LLine := LLines[LIndex];
        if ContainsText(LLine, 'error') or ContainsText(LLine, 'failed') or
          ContainsText(LLine, 'failure') or ContainsText(LLine, 'fatal') or
          StartsText('diff --git ', LLine) or StartsText('@@', LLine) or
          StartsText('--- ', LLine) or StartsText('+++ ', LLine) then
        begin
          if Length(LLine) > CMaximumCriticalLineCharacters then
            LLine := Copy(LLine, 1, CMaximumCriticalLineCharacters) +
              CCompactionMarker;
          LOutput.Add(LLine);
        end;
      end;
      Result := LOutput.Text.TrimRight;
    finally
      LOutput.Free;
    end;
  finally
    LLines.Free;
  end;
end;

class function TRadIAResultCompactor.IsCompactableField(
  const AToolName: string;
  const AFieldName: string
): Boolean;
begin
  Result :=
    (SameText(AToolName, 'RunDUnitXTests') and
      SameText(AFieldName, 'output')) or
    (SameText(AToolName, 'GetGitDiff') and
      SameText(AFieldName, 'diff'));
end;

class function TRadIAResultCompactor.StripAnsi(
  const AText: string
): string;
var
  LCharacter: Char;
  LIndex: Integer;
  LEscapeState: Integer;
  LOutput: TStringBuilder;
begin
  LOutput := TStringBuilder.Create;
  try
    LEscapeState := 0;
    for LIndex := Low(AText) to High(AText) do
    begin
      LCharacter := AText[LIndex];
      if LEscapeState = 0 then
      begin
        if LCharacter = #27 then
          LEscapeState := 1
        else
          LOutput.Append(LCharacter);
        Continue;
      end;
      if (LEscapeState = 1) and (LCharacter = '[') then
      begin
        LEscapeState := 2;
        Continue;
      end;
      if (LEscapeState = 1) or
        ((LEscapeState = 2) and (LCharacter >= '@') and
          (LCharacter <= '~')) then
        LEscapeState := 0;
    end;
    Result := LOutput.ToString;
  finally
    LOutput.Free;
  end;
end;

end.
