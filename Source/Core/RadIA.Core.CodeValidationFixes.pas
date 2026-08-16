unit RadIA.Core.CodeValidationFixes;

interface

uses
  System.JSON,
  RadIA.Core.Patches,
  RadIA.Core.Tools;

type
  IRadIACodeValidationFixService = interface
    ['{ED558D1E-127F-41BA-A45C-D62EF793347C}']
    procedure CaptureDelphiLintFixes(
      const AResponseJson: string;
      const ARootPath: string;
      const ATarget: TJSONArray
    );
    procedure Clear;
    function Prepare(const AId: string): TRadIAPatchResult;
  end;

function CreateRadIACodeValidationFixService(
  const AMutation: IRadIAEditorMutationFacade;
  const APatches: IRadIAPatchService
): IRadIACodeValidationFixService;

procedure RegisterRadIACodeValidationFixTools(
  const ARegistry: IRadIAToolRegistry;
  const AService: IRadIACodeValidationFixService
);

implementation

uses
  System.DateUtils,
  System.Generics.Collections,
  System.IOUtils,
  System.StrUtils,
  System.SysUtils,
  RadIA.Core.Workspace;

const
  CMaxCapturedFixes = 64;
  CMaxEditCount = 64;
  CMaxFileCharacters = 2 * 1024 * 1024;

type
  TRadIACodeValidationTextEdit = record
    EndLine: Integer;
    EndOffset: Integer;
    Replacement: string;
    StartLine: Integer;
    StartOffset: Integer;
  end;

  TRadIACodeValidationFix = record
    BaseRevision: string;
    ExpiresAtUtc: TDateTime;
    FileName: string;
    Id: string;
    Message: string;
    TextEdits: TArray<TRadIACodeValidationTextEdit>;
  end;

  TRadIACodeValidationFixService = class(
    TInterfacedObject,
    IRadIACodeValidationFixService
  )
  private
    FFixes: TDictionary<string, TRadIACodeValidationFix>;
    FMutation: IRadIAEditorMutationFacade;
    FPatches: IRadIAPatchService;
    function ApplyEdits(
      const AContent: string;
      const AEdits: TArray<TRadIACodeValidationTextEdit>;
      out AProposed: string;
      out AError: string
    ): Boolean;
    function CaptureFix(
      const AIssue: TJSONObject;
      const AFix: TJSONObject;
      const ARootPath: string;
      out AFixInfo: TRadIACodeValidationFix
    ): Boolean;
    procedure CaptureIssueFixes(
      const AIssue: TJSONObject;
      const ARootPath: string;
      const ATarget: TJSONArray
    );
    function ResolveFileName(
      const AFileName: string;
      const ARootPath: string
    ): string;
  public
    constructor Create(
      const AMutation: IRadIAEditorMutationFacade;
      const APatches: IRadIAPatchService
    );
    destructor Destroy; override;
    procedure CaptureDelphiLintFixes(
      const AResponseJson: string;
      const ARootPath: string;
      const ATarget: TJSONArray
    );
    procedure Clear;
    function Prepare(const AId: string): TRadIAPatchResult;
  end;

  TRadIAPrepareCodeValidationFixTool = class(TInterfacedObject, IRadIATool)
  private
    FService: IRadIACodeValidationFixService;
  public
    constructor Create(const AService: IRadIACodeValidationFixService);
    function Execute(const ARequest: TRadIAToolRequest): TRadIAToolResult;
    function GetDescriptor: TRadIAToolDescriptor;
  end;

function JsonInteger(const AObject: TJSONObject; const AName: string): Integer;
begin
  Result := AObject.GetValue<Integer>(AName, 0);
end;

function LineOffsetToIndex(
  const AContent: string;
  const ALine: Integer;
  const AOffset: Integer
): Integer;
var
  LCurrentLine: Integer;
  LIndex: Integer;
begin
  if (ALine < 1) or (AOffset < 0) then
    Exit(0);
  LCurrentLine := 1;
  LIndex := 1;
  while (LIndex <= Length(AContent)) and (LCurrentLine < ALine) do
  begin
    if AContent[LIndex] = #10 then
      Inc(LCurrentLine);
    Inc(LIndex);
  end;
  if LCurrentLine <> ALine then
    Exit(0);
  Result := LIndex + AOffset;
  if Result > Length(AContent) + 1 then
    Result := 0;
end;

constructor TRadIACodeValidationFixService.Create(
  const AMutation: IRadIAEditorMutationFacade;
  const APatches: IRadIAPatchService
);
begin
  inherited Create;
  if not Assigned(AMutation) then
    raise EArgumentNilException.Create('AMutation');
  if not Assigned(APatches) then
    raise EArgumentNilException.Create('APatches');
  FMutation := AMutation;
  FPatches := APatches;
  FFixes := TDictionary<string, TRadIACodeValidationFix>.Create;
end;

destructor TRadIACodeValidationFixService.Destroy;
begin
  FFixes.Free;
  inherited Destroy;
end;

procedure TRadIACodeValidationFixService.Clear;
begin
  FFixes.Clear;
end;

function TRadIACodeValidationFixService.ResolveFileName(
  const AFileName: string;
  const ARootPath: string
): string;
var
  LRoot: string;
begin
  if TPath.IsPathRooted(AFileName) then
    Result := AFileName
  else
    Result := TPath.Combine(ARootPath, AFileName);
  Result := TPath.GetFullPath(Result);
  LRoot := IncludeTrailingPathDelimiter(TPath.GetFullPath(ARootPath));
  if not StartsText(LRoot, Result) then
    Result := '';
end;

function TRadIACodeValidationFixService.CaptureFix(
  const AIssue: TJSONObject;
  const AFix: TJSONObject;
  const ARootPath: string;
  out AFixInfo: TRadIACodeValidationFix
): Boolean;
var
  LEdit: TJSONValue;
  LEditObject: TJSONObject;
  LEdits: TJSONArray;
  LIndex: Integer;
  LRange: TJSONObject;
  LSnapshot: TRadIAEditorContent;
begin
  Result := False;
  LEdits := AFix.GetValue('textEdits') as TJSONArray;
  if not Assigned(LEdits) or (LEdits.Count = 0) or
    (LEdits.Count > CMaxEditCount) then
    Exit;
  SetLength(AFixInfo.TextEdits, LEdits.Count);
  LIndex := 0;
  for LEdit in LEdits do
  begin
    if not (LEdit is TJSONObject) then
      Exit;
    LEditObject := TJSONObject(LEdit);
    LRange := LEditObject.GetValue('range') as TJSONObject;
    if not Assigned(LRange) then
      Exit;
    AFixInfo.TextEdits[LIndex].StartLine := JsonInteger(LRange, 'startLine');
    AFixInfo.TextEdits[LIndex].StartOffset := JsonInteger(LRange, 'startOffset');
    AFixInfo.TextEdits[LIndex].EndLine := JsonInteger(LRange, 'endLine');
    AFixInfo.TextEdits[LIndex].EndOffset := JsonInteger(LRange, 'endOffset');
    AFixInfo.TextEdits[LIndex].Replacement :=
      LEditObject.GetValue<string>('replacement', '');
    if Length(AFixInfo.TextEdits[LIndex].Replacement) > 65536 then
      Exit;
    Inc(LIndex);
  end;
  AFixInfo.Id := TGUID.NewGuid.ToString.Replace('{', '').Replace('}', '');
  AFixInfo.Message := AFix.GetValue<string>('message', 'DelphiLint quick fix');
  AFixInfo.FileName := ResolveFileName(
    AIssue.GetValue<string>('file', ''),
    ARootPath
  );
  if AFixInfo.FileName.IsEmpty or not TFile.Exists(AFixInfo.FileName) then
    Exit;
  LSnapshot := FMutation.ReadContent(AFixInfo.FileName, CMaxFileCharacters);
  if LSnapshot.Truncated or LSnapshot.Content.IsEmpty or
    not SameText(LSnapshot.FileName, AFixInfo.FileName) then
    Exit;
  if TFile.ReadAllText(AFixInfo.FileName) <> LSnapshot.Content then
    Exit;
  AFixInfo.BaseRevision := LSnapshot.Revision;
  AFixInfo.ExpiresAtUtc := IncMinute(TTimeZone.Local.ToUniversalTime(Now), 10);
  Result := not AFixInfo.BaseRevision.IsEmpty;
end;

procedure TRadIACodeValidationFixService.CaptureIssueFixes(
  const AIssue: TJSONObject;
  const ARootPath: string;
  const ATarget: TJSONArray
);
var
  LFix: TJSONValue;
  LFixInfo: TRadIACodeValidationFix;
  LFixes: TJSONArray;
  LItem: TJSONObject;
begin
  LFixes := AIssue.GetValue('quickFixes') as TJSONArray;
  if not Assigned(LFixes) then
    Exit;
  for LFix in LFixes do
  begin
    if (FFixes.Count >= CMaxCapturedFixes) or not (LFix is TJSONObject) then
      Break;
    if not CaptureFix(AIssue, TJSONObject(LFix), ARootPath, LFixInfo) then
      Continue;
    FFixes.Add(LFixInfo.Id, LFixInfo);
    LItem := TJSONObject.Create;
    LItem.AddPair('fixId', LFixInfo.Id);
    LItem.AddPair('message', LFixInfo.Message);
    LItem.AddPair('fileName', LFixInfo.FileName);
    LItem.AddPair('editCount', Length(LFixInfo.TextEdits));
    ATarget.AddElement(LItem);
  end;
end;

procedure TRadIACodeValidationFixService.CaptureDelphiLintFixes(
  const AResponseJson: string;
  const ARootPath: string;
  const ATarget: TJSONArray
);
var
  LIssue: TJSONValue;
  LIssues: TJSONArray;
  LRoot: TJSONValue;
begin
  if not Assigned(ATarget) then
    Exit;
  LRoot := TJSONObject.ParseJSONValue(AResponseJson);
  try
    if not (LRoot is TJSONObject) then
      Exit;
    LIssues := TJSONObject(LRoot).GetValue('issues') as TJSONArray;
    if not Assigned(LIssues) then
      Exit;
    for LIssue in LIssues do
    begin
      if (FFixes.Count >= CMaxCapturedFixes) or not (LIssue is TJSONObject) then
        Break;
      CaptureIssueFixes(TJSONObject(LIssue), ARootPath, ATarget);
    end;
  finally
    LRoot.Free;
  end;
end;

function TRadIACodeValidationFixService.ApplyEdits(
  const AContent: string;
  const AEdits: TArray<TRadIACodeValidationTextEdit>;
  out AProposed: string;
  out AError: string
): Boolean;
var
  LEndIndex: Integer;
  LIndex: Integer;
  LNextEnd: Integer;
  LOrder: TArray<Integer>;
  LPosition: Integer;
  LStartIndex: Integer;
  LSwap: Integer;
begin
  Result := False;
  AError := '';
  AProposed := AContent;
  SetLength(LOrder, Length(AEdits));
  for LIndex := 0 to High(LOrder) do
    LOrder[LIndex] := LIndex;
  for LIndex := 0 to High(LOrder) do
    for LPosition := LIndex + 1 to High(LOrder) do
      if (AEdits[LOrder[LPosition]].StartLine >
        AEdits[LOrder[LIndex]].StartLine) or
        ((AEdits[LOrder[LPosition]].StartLine =
          AEdits[LOrder[LIndex]].StartLine) and
        (AEdits[LOrder[LPosition]].StartOffset >
          AEdits[LOrder[LIndex]].StartOffset)) then
      begin
        LSwap := LOrder[LIndex];
        LOrder[LIndex] := LOrder[LPosition];
        LOrder[LPosition] := LSwap;
      end;
  LNextEnd := Length(AContent) + 1;
  for LIndex in LOrder do
  begin
    LStartIndex := LineOffsetToIndex(
      AContent,
      AEdits[LIndex].StartLine,
      AEdits[LIndex].StartOffset
    );
    LEndIndex := LineOffsetToIndex(
      AContent,
      AEdits[LIndex].EndLine,
      AEdits[LIndex].EndOffset
    );
    if (LStartIndex = 0) or (LEndIndex < LStartIndex) or
      (LEndIndex > LNextEnd) then
    begin
      AError := 'Quick-fix ranges are invalid or overlap.';
      Exit;
    end;
    Delete(AProposed, LStartIndex, LEndIndex - LStartIndex);
    Insert(AEdits[LIndex].Replacement, AProposed, LStartIndex);
    LNextEnd := LStartIndex;
  end;
  Result := True;
end;

function TRadIACodeValidationFixService.Prepare(
  const AId: string
): TRadIAPatchResult;
var
  LError: string;
  LFix: TRadIACodeValidationFix;
  LProposed: string;
  LSnapshot: TRadIAEditorContent;
begin
  if not FFixes.TryGetValue(AId, LFix) then
    Exit(TRadIAPatchResult.Failed(
      'validation_fix_not_found',
      'The suggested fix no longer exists. Run ValidateDelphiCode again.'
    ));
  if TTimeZone.Local.ToUniversalTime(Now) > LFix.ExpiresAtUtc then
  begin
    FFixes.Remove(AId);
    Exit(TRadIAPatchResult.Failed(
      'validation_fix_expired',
      'The suggested fix expired. Run ValidateDelphiCode again.'
    ));
  end;
  LSnapshot := FMutation.ReadContent(LFix.FileName, CMaxFileCharacters);
  if LSnapshot.Truncated or LSnapshot.Content.IsEmpty then
    Exit(TRadIAPatchResult.Failed(
      'validation_fix_file_unavailable',
      'The target file is empty, unavailable, or exceeds the safe limit.'
    ));
  if not SameText(LSnapshot.Revision, LFix.BaseRevision) then
    Exit(TRadIAPatchResult.Failed(
      'validation_fix_stale',
      'The target changed after validation. Run ValidateDelphiCode again.'
    ));
  if not ApplyEdits(LSnapshot.Content, LFix.TextEdits, LProposed, LError) then
    Exit(TRadIAPatchResult.Failed('validation_fix_invalid', LError));
  Result := FPatches.Prepare(TRadIAPatchSpec.Create(
    LFix.FileName,
    LSnapshot.Revision,
    LSnapshot.Content,
    LProposed
  ));
end;

constructor TRadIAPrepareCodeValidationFixTool.Create(
  const AService: IRadIACodeValidationFixService
);
begin
  inherited Create;
  if not Assigned(AService) then
    raise EArgumentNilException.Create('AService');
  FService := AService;
end;

function TRadIAPrepareCodeValidationFixTool.Execute(
  const ARequest: TRadIAToolRequest
): TRadIAToolResult;
var
  LArguments: TJSONObject;
  LJson: TJSONObject;
  LResult: TRadIAPatchResult;
begin
  LArguments := TJSONObject.ParseJSONValue(ARequest.ArgumentsJson) as TJSONObject;
  if not Assigned(LArguments) then
    Exit(TRadIAToolResult.Failed('invalid_request',
      'Fix arguments must be a JSON object.'));
  try
    LResult := FService.Prepare(LArguments.GetValue<string>('id', ''));
    if not LResult.Success then
      Exit(TRadIAToolResult.Failed(LResult.ErrorCode, LResult.ErrorMessage));
    LJson := TJSONObject.Create;
    try
      LJson.AddPair('previewId', LResult.Preview.Id);
      LJson.AddPair('targetFile', LResult.Preview.Spec.TargetFile);
      LJson.AddPair('baseRevision', LResult.Preview.Spec.BaseRevision);
      LJson.AddPair('proposedRevision', LResult.Preview.ProposedRevision);
      LJson.AddPair('originalContent', LResult.Preview.OriginalContent);
      LJson.AddPair('proposedContent', LResult.Preview.ProposedContent);
      Result := TRadIAToolResult.Succeeded(LJson.ToJSON);
    finally
      LJson.Free;
    end;
  finally
    LArguments.Free;
  end;
end;

function TRadIAPrepareCodeValidationFixTool.GetDescriptor: TRadIAToolDescriptor;
begin
  Result := TRadIAToolDescriptor.Create(
    'PrepareCodeValidationFix',
    '1.0.0',
    'Prepares a fingerprinted preview for a DelphiLint suggested fix.',
    '{"type":"object","required":["id"],"properties":{' +
      '"id":{"type":"string","minLength":1}},"additionalProperties":false}',
    '{"type":"object","required":["previewId","targetFile",' +
      '"originalContent","proposedContent"]}',
    trReadOnly
  );
end;

function CreateRadIACodeValidationFixService(
  const AMutation: IRadIAEditorMutationFacade;
  const APatches: IRadIAPatchService
): IRadIACodeValidationFixService;
begin
  Result := TRadIACodeValidationFixService.Create(AMutation, APatches);
end;

procedure RegisterRadIACodeValidationFixTools(
  const ARegistry: IRadIAToolRegistry;
  const AService: IRadIACodeValidationFixService
);
begin
  if not Assigned(ARegistry) then
    raise EArgumentNilException.Create('ARegistry');
  ARegistry.RegisterTool(TRadIAPrepareCodeValidationFixTool.Create(AService));
end;

end.
