unit RadIA.Core.DfmPasAuditTools;

interface

uses
  RadIA.Core.Designer,
  RadIA.Core.DfmPasAudit,
  RadIA.Core.Patches,
  RadIA.Core.Tools;

procedure RegisterRadIADfmPasAuditTools(
  const ARegistry: IRadIAToolRegistry;
  const ADesigner: IRadIAFormDesignerFacade;
  const AMutation: IRadIAEditorMutationFacade;
  const AAuditor: IRadIADfmPasAuditor;
  const APatches: IRadIAPatchService
);

implementation

uses
  System.JSON,
  System.RegularExpressions,
  System.SysUtils,
  RadIA.Core.Workspace;

type
  TRadIADfmPasAuditToolKind = (
    datAudit,
    datPrepareFix
  );

  TRadIADfmPasAuditSnapshot = record
    Form: TRadIAFormSnapshot;
    Dfm: TRadIAEditorContent;
    Pascal: TRadIAEditorContent;
    Audit: TRadIADfmPasAuditResult;
  end;

  TRadIADfmPasAuditTool = class(TInterfacedObject, IRadIATool)
  private
    FAuditor: IRadIADfmPasAuditor;
    FDesigner: IRadIAFormDesignerFacade;
    FKind: TRadIADfmPasAuditToolKind;
    FMutation: IRadIAEditorMutationFacade;
    FPatches: IRadIAPatchService;
    function BuildSnapshot(
      out ASnapshot: TRadIADfmPasAuditSnapshot;
      out AError: TRadIAToolResult
    ): Boolean;
    function ExecuteAudit: TRadIAToolResult;
    function ExecutePrepareFix(
      const ARequest: TRadIAToolRequest
    ): TRadIAToolResult;
    function FindingsToJson(
      const ASnapshot: TRadIADfmPasAuditSnapshot
    ): string;
    function GetDescriptor: TRadIAToolDescriptor;
    function PreparePascalFix(
      const ASnapshot: TRadIADfmPasAuditSnapshot;
      const AFindingCode: string;
      const AName: string;
      out AContent: string
    ): Boolean;
  public
    constructor Create(
      const AKind: TRadIADfmPasAuditToolKind;
      const ADesigner: IRadIAFormDesignerFacade;
      const AMutation: IRadIAEditorMutationFacade;
      const AAuditor: IRadIADfmPasAuditor;
      const APatches: IRadIAPatchService
    );
    function Execute(
      const ARequest: TRadIAToolRequest
    ): TRadIAToolResult;
  end;

const
  CMaxFileCharacters = 2 * 1024 * 1024;
  CAuditInputSchema =
    '{"type":"object","additionalProperties":false}';
  CFixInputSchema =
    '{"type":"object","required":["findingCode","name"],' +
    '"properties":{"findingCode":{"type":"string","enum":[' +
    '"missing_event_handler","missing_component_field"]},' +
    '"name":{"type":"string"}},"additionalProperties":false}';
  COutputSchema = '{"type":"object"}';

procedure RegisterRadIADfmPasAuditTools(
  const ARegistry: IRadIAToolRegistry;
  const ADesigner: IRadIAFormDesignerFacade;
  const AMutation: IRadIAEditorMutationFacade;
  const AAuditor: IRadIADfmPasAuditor;
  const APatches: IRadIAPatchService
);
var
  LKind: TRadIADfmPasAuditToolKind;
begin
  if not Assigned(ARegistry) then
    raise EArgumentNilException.Create('ARegistry');
  for LKind := Low(TRadIADfmPasAuditToolKind) to
    High(TRadIADfmPasAuditToolKind) do
    ARegistry.RegisterTool(
      TRadIADfmPasAuditTool.Create(
        LKind,
        ADesigner,
        AMutation,
        AAuditor,
        APatches
      )
    );
end;

function AddClassMember(
  const AContent: string;
  const AMember: string;
  out AUpdated: string
): Boolean;
var
  LClassEnd: Integer;
  LClassStart: Integer;
  LEndPosition: Integer;
  LLowerContent: string;
begin
  AUpdated := AContent;
  LLowerContent := LowerCase(AContent);
  LClassStart := Pos('= class(', LLowerContent);
  if LClassStart = 0 then
    Exit(False);
  LClassEnd := Pos(')', LLowerContent, LClassStart);
  if LClassEnd = 0 then
    Exit(False);
  LEndPosition := Pos(
    sLineBreak + '  end;',
    LLowerContent,
    LClassEnd
  );
  if LEndPosition = 0 then
    Exit(False);
  Insert(sLineBreak + '    ' + AMember, AUpdated, LEndPosition);
  Result := True;
end;

function AddMethodImplementation(
  const AContent: string;
  const AClassName: string;
  const AMethodName: string;
  out AUpdated: string
): Boolean;
var
  LEndPosition: Integer;
  LLowerContent: string;
  LMethod: string;
  LSearchPosition: Integer;
begin
  AUpdated := AContent;
  LLowerContent := LowerCase(AContent);
  LEndPosition := 0;
  LSearchPosition := Pos('end.', LLowerContent);
  while LSearchPosition > 0 do
  begin
    LEndPosition := LSearchPosition;
    LSearchPosition := Pos('end.', LLowerContent, LSearchPosition + 1);
  end;
  if LEndPosition = 0 then
    Exit(False);
  LMethod := 'procedure ' + AClassName + '.' + AMethodName +
    '(Sender: TObject);' + sLineBreak + 'begin' + sLineBreak +
    'end;' + sLineBreak + sLineBreak;
  Insert(LMethod, AUpdated, LEndPosition);
  Result := True;
end;

function GetRequiredString(
  const AJson: TJSONObject;
  const AName: string
): string;
begin
  Result := Trim(AJson.GetValue<string>(AName, ''));
  if Result = '' then
    raise EArgumentException.CreateFmt(
      'Argument "%s" must not be empty.',
      [AName]
    );
end;

function HasAuditFinding(
  const AFindings: TArray<TRadIADfmPasFinding>;
  const ACode: string;
  const AName: string
): Boolean;
var
  LFinding: TRadIADfmPasFinding;
begin
  for LFinding in AFindings do
    if SameText(LFinding.Code, ACode) and SameText(LFinding.Name, AName) then
      Exit(True);
  Result := False;
end;

function IsIdentifier(const AValue: string): Boolean;
begin
  Result := TRegEx.IsMatch(AValue, '^[A-Za-z_]\w*$');
end;

function FindClassName(const AContent: string): string;
var
  LClassPosition: Integer;
  LEqualsPosition: Integer;
  LLineStart: Integer;
begin
  Result := '';
  LClassPosition := Pos('= class(', LowerCase(AContent));
  if LClassPosition = 0 then
    Exit;
  LEqualsPosition := LClassPosition - 1;
  while (LEqualsPosition > 0) and
    CharInSet(AContent[LEqualsPosition], [#9, ' ']) do
    Dec(LEqualsPosition);
  LLineStart := LEqualsPosition;
  while (LLineStart > 0) and
    not CharInSet(AContent[LLineStart], [#10, #13]) do
    Dec(LLineStart);
  Result := Trim(Copy(
    AContent,
    LLineStart + 1,
    LEqualsPosition - LLineStart
  ));
end;

function FindDfmComponentType(
  const AContent: string;
  const AName: string
): string;
var
  LColonPosition: Integer;
  LEndPosition: Integer;
  LNamePosition: Integer;
  LSearch: string;
begin
  Result := '';
  LSearch := LowerCase(AName) + ':';
  LNamePosition := Pos(LSearch, LowerCase(AContent));
  if LNamePosition = 0 then
    Exit;
  LColonPosition := LNamePosition + Length(LSearch);
  while (LColonPosition <= Length(AContent)) and
    CharInSet(AContent[LColonPosition], [#9, ' ']) do
    Inc(LColonPosition);
  LEndPosition := LColonPosition;
  while (LEndPosition <= Length(AContent)) and
    not CharInSet(AContent[LEndPosition], [#9, #10, #13, ' ']) do
    Inc(LEndPosition);
  Result := Copy(AContent, LColonPosition, LEndPosition - LColonPosition);
end;

{ TRadIADfmPasAuditTool }

constructor TRadIADfmPasAuditTool.Create(
  const AKind: TRadIADfmPasAuditToolKind;
  const ADesigner: IRadIAFormDesignerFacade;
  const AMutation: IRadIAEditorMutationFacade;
  const AAuditor: IRadIADfmPasAuditor;
  const APatches: IRadIAPatchService
);
begin
  inherited Create;
  if not Assigned(ADesigner) then
    raise EArgumentNilException.Create('ADesigner');
  if not Assigned(AMutation) then
    raise EArgumentNilException.Create('AMutation');
  if not Assigned(AAuditor) then
    raise EArgumentNilException.Create('AAuditor');
  if not Assigned(APatches) then
    raise EArgumentNilException.Create('APatches');
  FKind := AKind;
  FDesigner := ADesigner;
  FMutation := AMutation;
  FAuditor := AAuditor;
  FPatches := APatches;
end;

function TRadIADfmPasAuditTool.BuildSnapshot(
  out ASnapshot: TRadIADfmPasAuditSnapshot;
  out AError: TRadIAToolResult
): Boolean;
begin
  ASnapshot := Default(TRadIADfmPasAuditSnapshot);
  ASnapshot.Form := FDesigner.GetActiveForm;
  if not ASnapshot.Form.Available then
  begin
    AError := TRadIAToolResult.Failed(
      'form_unavailable',
      'An active Form Designer is required.'
    );
    Exit(False);
  end;
  ASnapshot.Dfm := FMutation.ReadContent(
    ASnapshot.Form.FormFileName,
    CMaxFileCharacters
  );
  ASnapshot.Pascal := FMutation.ReadContent(
    ASnapshot.Form.UnitFileName,
    CMaxFileCharacters
  );
  if ASnapshot.Dfm.Truncated or ASnapshot.Pascal.Truncated then
  begin
    AError := TRadIAToolResult.Failed(
      'resource_limit',
      'DFM and Pascal files must each be at most 2 MiB.'
    );
    Exit(False);
  end;
  ASnapshot.Audit := FAuditor.Audit(
    TRadIADfmPasAuditInput.Create(
      ASnapshot.Form.FormFileName,
      ASnapshot.Dfm.Content,
      ASnapshot.Form.UnitFileName,
      ASnapshot.Pascal.Content
    )
  );
  Result := True;
end;

function TRadIADfmPasAuditTool.Execute(
  const ARequest: TRadIAToolRequest
): TRadIAToolResult;
begin
  if FKind = datAudit then
    Result := ExecuteAudit
  else
    Result := ExecutePrepareFix(ARequest);
end;

function TRadIADfmPasAuditTool.ExecuteAudit: TRadIAToolResult;
var
  LError: TRadIAToolResult;
  LSnapshot: TRadIADfmPasAuditSnapshot;
begin
  if not BuildSnapshot(LSnapshot, LError) then
    Exit(LError);
  Result := TRadIAToolResult.Succeeded(FindingsToJson(LSnapshot));
end;

function TRadIADfmPasAuditTool.ExecutePrepareFix(
  const ARequest: TRadIAToolRequest
): TRadIAToolResult;
var
  LCode: string;
  LContent: string;
  LError: TRadIAToolResult;
  LJson: TJSONObject;
  LName: string;
  LPatch: TRadIAPatchResult;
  LRoot: TJSONObject;
  LSnapshot: TRadIADfmPasAuditSnapshot;
begin
  LJson := TJSONObject.ParseJSONValue(ARequest.ArgumentsJson) as TJSONObject;
  if not Assigned(LJson) then
    Exit(TRadIAToolResult.Failed(
      'invalid_request',
      'Audit fix arguments must be a JSON object.'
    ));
  try
    LCode := GetRequiredString(LJson, 'findingCode');
    LName := GetRequiredString(LJson, 'name');
    if not IsIdentifier(LName) then
      Exit(TRadIAToolResult.Failed(
        'invalid_identifier',
        'Finding name must be a valid Pascal identifier.'
      ));
    if not BuildSnapshot(LSnapshot, LError) then
      Exit(LError);
    if not PreparePascalFix(LSnapshot, LCode, LName, LContent) then
      Exit(TRadIAToolResult.Failed(
        'fix_unavailable',
        'The requested finding is absent or has no safe automatic fix.'
      ));
    LPatch := FPatches.Prepare(
      TRadIAPatchSpec.Create(
        LSnapshot.Form.UnitFileName,
        LSnapshot.Pascal.Revision,
        LSnapshot.Pascal.Content,
        LContent
      )
    );
    if not LPatch.Success then
      Exit(TRadIAToolResult.Failed(
        LPatch.ErrorCode,
        LPatch.ErrorMessage
      ));
    LRoot := TJSONObject.Create;
    try
      LRoot.AddPair('previewId', LPatch.Preview.Id);
      LRoot.AddPair('findingCode', LCode);
      LRoot.AddPair('name', LName);
      LRoot.AddPair('targetFile', LSnapshot.Form.UnitFileName);
      LRoot.AddPair('applied', TJSONBool.Create(False));
      Result := TRadIAToolResult.Succeeded(LRoot.ToJSON);
    finally
      LRoot.Free;
    end;
  finally
    LJson.Free;
  end;
end;

function TRadIADfmPasAuditTool.FindingsToJson(
  const ASnapshot: TRadIADfmPasAuditSnapshot
): string;
var
  LArray: TJSONArray;
  LFinding: TRadIADfmPasFinding;
  LItem: TJSONObject;
  LRoot: TJSONObject;
begin
  LRoot := TJSONObject.Create;
  try
    LRoot.AddPair('dfmFile', ASnapshot.Form.FormFileName);
    LRoot.AddPair('pasFile', ASnapshot.Form.UnitFileName);
    LRoot.AddPair(
      'hasErrors',
      TJSONBool.Create(ASnapshot.Audit.HasErrors)
    );
    LArray := TJSONArray.Create;
    LRoot.AddPair('findings', LArray);
    for LFinding in ASnapshot.Audit.Findings do
    begin
      LItem := TJSONObject.Create;
      LItem.AddPair('code', LFinding.Code);
      LItem.AddPair(
        'severity',
        RadIADfmPasSeverityName(LFinding.Severity)
      );
      LItem.AddPair('fileKind', LFinding.FileKind);
      LItem.AddPair('line', TJSONNumber.Create(LFinding.Line));
      LItem.AddPair('name', LFinding.Name);
      LItem.AddPair('message', LFinding.Message);
      LArray.AddElement(LItem);
    end;
    LRoot.AddPair(
      'count',
      TJSONNumber.Create(Length(ASnapshot.Audit.Findings))
    );
    Result := LRoot.ToJSON;
  finally
    LRoot.Free;
  end;
end;

function TRadIADfmPasAuditTool.GetDescriptor: TRadIAToolDescriptor;
begin
  if FKind = datAudit then
    Result := TRadIAToolDescriptor.Create(
      'AuditActiveDfmPasConsistency',
      '1.0.0',
      'Audits the active DFM and Pascal pair without modifying either file.',
      CAuditInputSchema,
      COutputSchema,
      trReadOnly
    )
  else
    Result := TRadIAToolDescriptor.Create(
      'PrepareDfmPasAuditFix',
      '1.0.0',
      'Prepares a reviewable Pascal patch for a supported DFM audit finding.',
      CFixInputSchema,
      COutputSchema,
      trReadOnly
    );
end;

function TRadIADfmPasAuditTool.PreparePascalFix(
  const ASnapshot: TRadIADfmPasAuditSnapshot;
  const AFindingCode: string;
  const AName: string;
  out AContent: string
): Boolean;
var
  LClassName: string;
  LIntermediate: string;
  LMember: string;
  LTypeName: string;
begin
  Result := False;
  if not HasAuditFinding(ASnapshot.Audit.Findings, AFindingCode, AName) then
    Exit;
  if SameText(AFindingCode, 'missing_component_field') then
  begin
    LTypeName := FindDfmComponentType(ASnapshot.Dfm.Content, AName);
    if LTypeName = '' then
      Exit;
    LMember := AName + ': ' + LTypeName + ';';
    Exit(AddClassMember(ASnapshot.Pascal.Content, LMember, AContent));
  end;
  if not SameText(AFindingCode, 'missing_event_handler') then
    Exit;
  LClassName := FindClassName(ASnapshot.Pascal.Content);
  if (LClassName = '') or not AddClassMember(
    ASnapshot.Pascal.Content,
    'procedure ' + AName + '(Sender: TObject);',
    LIntermediate
  ) then
    Exit;
  Result := AddMethodImplementation(
    LIntermediate,
    LClassName,
    AName,
    AContent
  );
end;

end.
