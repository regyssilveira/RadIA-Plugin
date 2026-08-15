unit RadIA.Core.DfmPasAudit;

interface

uses
  RadIA.Core.SemanticQueries;

type
  TRadIADfmPasSeverity = (
    dpsInfo,
    dpsWarning,
    dpsError
  );

  TRadIADfmPasFinding = record
  private
    FCode: string;
    FFileKind: string;
    FLine: Integer;
    FMessage: string;
    FName: string;
    FSeverity: TRadIADfmPasSeverity;
  public
    constructor Create(
      const ACode: string;
      const ASeverity: TRadIADfmPasSeverity;
      const AFileKind: string;
      const ALine: Integer;
      const AName: string;
      const AMessage: string
    );
    property Code: string read FCode;
    property Severity: TRadIADfmPasSeverity read FSeverity;
    property FileKind: string read FFileKind;
    property Line: Integer read FLine;
    property Name: string read FName;
    property Message: string read FMessage;
  end;

  TRadIADfmPasAuditInput = record
  private
    FDfmContent: string;
    FDfmFileName: string;
    FPasContent: string;
    FPasFileName: string;
  public
    constructor Create(
      const ADfmFileName: string;
      const ADfmContent: string;
      const APasFileName: string;
      const APasContent: string
    );
    property DfmContent: string read FDfmContent;
    property PasContent: string read FPasContent;
  end;

  TRadIADfmPasAuditResult = record
  private
    FFindings: TArray<TRadIADfmPasFinding>;
  public
    constructor Create(const AFindings: TArray<TRadIADfmPasFinding>);
    function HasErrors: Boolean;
    property Findings: TArray<TRadIADfmPasFinding> read FFindings;
  end;

  IRadIADfmPasAuditor = interface
    ['{DA5377FB-B4F8-4D38-8905-956597A7C4DC}']
    function Audit(
      const AInput: TRadIADfmPasAuditInput
    ): TRadIADfmPasAuditResult;
  end;

  TRadIADfmPasAuditor = class(TInterfacedObject, IRadIADfmPasAuditor)
  private
    FSemanticQueries: IRadIASemanticQueryService;
  public
    constructor Create; overload;
    constructor Create(
      const ASemanticQueries: IRadIASemanticQueryService
    ); overload;
    function Audit(
      const AInput: TRadIADfmPasAuditInput
    ): TRadIADfmPasAuditResult;
  end;

function RadIADfmPasSeverityName(
  const ASeverity: TRadIADfmPasSeverity
): string;

implementation

uses
  System.Generics.Collections,
  System.RegularExpressions,
  System.StrUtils,
  System.SysUtils;

type
  TRadIANamedDeclaration = record
    Name: string;
    TypeName: string;
    Line: Integer;
  end;

  TRadIADfmEvent = record
    ComponentName: string;
    EventName: string;
    HandlerName: string;
    Line: Integer;
  end;

const
  CMaxAuditCharacters = 2 * 1024 * 1024;
  CMaxFindings = 500;

function RadIADfmPasSeverityName(
  const ASeverity: TRadIADfmPasSeverity
): string;
begin
  case ASeverity of
    dpsInfo:
      Result := 'info';
    dpsWarning:
      Result := 'warning';
    dpsError:
      Result := 'error';
  else
    Result := 'unknown';
  end;
end;

procedure AddFinding(
  const AList: TList<TRadIADfmPasFinding>;
  const AFinding: TRadIADfmPasFinding
);
begin
  if AList.Count < CMaxFindings then
    AList.Add(AFinding);
end;

function ExtractMatch(
  const AText: string;
  const APattern: string;
  const AGroup: string
): string;
var
  LMatch: TMatch;
begin
  LMatch := TRegEx.Match(AText, APattern, [roIgnoreCase]);
  if LMatch.Success then
    Result := LMatch.Groups[AGroup].Value
  else
    Result := '';
end;

function IsNotifyEvent(const AEventName: string): Boolean;
begin
  Result := SameText(AEventName, 'OnClick') or
    SameText(AEventName, 'OnChange') or
    SameText(AEventName, 'OnCreate') or
    SameText(AEventName, 'OnDestroy') or
    SameText(AEventName, 'OnEnter') or
    SameText(AEventName, 'OnExit');
end;

function IsCompatibleNotifyDeclaration(const ALine: string): Boolean;
var
  LCompact: string;
begin
  LCompact := LowerCase(StringReplace(ALine, ' ', '', [rfReplaceAll]));
  Result := ContainsText(LCompact, '(sender:tobject)');
end;

procedure ParseDfm(
  const AContent: string;
  const AComponents: TDictionary<string, TRadIANamedDeclaration>;
  const AEvents: TList<TRadIADfmEvent>;
  out ARoot: TRadIANamedDeclaration
);
var
  LCurrentComponent: string;
  LDeclaration: TRadIANamedDeclaration;
  LEvent: TRadIADfmEvent;
  LEventName: string;
  LHandlerName: string;
  LLines: TArray<string>;
  LName: string;
  LTypeName: string;
  I: Integer;
begin
  ARoot := Default(TRadIANamedDeclaration);
  LLines := AContent.Replace(#13#10, #10).Split([#10]);
  for I := 0 to High(LLines) do
  begin
    LName := ExtractMatch(
      LLines[I],
      '^\s*(?:object|inherited|inline)\s+(?<name>[A-Za-z_]\w*)\s*:\s*' +
        '(?<type>[A-Za-z_]\w*)',
      'name'
    );
    if LName <> '' then
    begin
      LTypeName := ExtractMatch(
        LLines[I],
        '^\s*(?:object|inherited|inline)\s+(?<name>[A-Za-z_]\w*)\s*:\s*' +
          '(?<type>[A-Za-z_]\w*)',
        'type'
      );
      LDeclaration.Name := LName;
      LDeclaration.TypeName := LTypeName;
      LDeclaration.Line := I + 1;
      if ARoot.Name = '' then
        ARoot := LDeclaration;
      AComponents.AddOrSetValue(LowerCase(LName), LDeclaration);
      LCurrentComponent := LName;
      Continue;
    end;
    LEventName := ExtractMatch(
      LLines[I],
      '^\s*(?<event>On[A-Za-z0-9_]+)\s*=\s*(?<handler>[A-Za-z_]\w*)\s*$',
      'event'
    );
    if LEventName = '' then
      Continue;
    LHandlerName := ExtractMatch(
      LLines[I],
      '^\s*(?<event>On[A-Za-z0-9_]+)\s*=\s*(?<handler>[A-Za-z_]\w*)\s*$',
      'handler'
    );
    LEvent.ComponentName := LCurrentComponent;
    LEvent.EventName := LEventName;
    LEvent.HandlerName := LHandlerName;
    LEvent.Line := I + 1;
    AEvents.Add(LEvent);
  end;
end;

procedure AddPascalField(
  const ALine: string;
  const ALineNumber: Integer;
  const AFields: TDictionary<string, TRadIANamedDeclaration>
);
var
  LDeclaration: TRadIANamedDeclaration;
  LName: string;
  LTypeName: string;
begin
  LName := ExtractMatch(
    ALine,
    '^\s*(?<name>[A-Za-z_]\w*)\s*:\s*(?<type>T[A-Za-z_]\w*)\s*;',
    'name'
  );
  if LName = '' then
    Exit;
  LTypeName := ExtractMatch(
    ALine,
    '^\s*(?<name>[A-Za-z_]\w*)\s*:\s*(?<type>T[A-Za-z_]\w*)\s*;',
    'type'
  );
  LDeclaration.Name := LName;
  LDeclaration.TypeName := LTypeName;
  LDeclaration.Line := ALineNumber;
  AFields.AddOrSetValue(LowerCase(LName), LDeclaration);
end;

procedure AddPascalMethod(
  const ALine: string;
  const ALineNumber: Integer;
  const AMethods: TDictionary<string, TRadIANamedDeclaration>
);
var
  LDeclaration: TRadIANamedDeclaration;
  LName: string;
begin
  LName := ExtractMatch(
    ALine,
    '^\s*(?:class\s+)?procedure\s+(?<name>[A-Za-z_]\w*)\s*\(',
    'name'
  );
  if LName = '' then
    Exit;
  LDeclaration.Name := LName;
  LDeclaration.TypeName := Trim(ALine);
  LDeclaration.Line := ALineNumber;
  AMethods.AddOrSetValue(LowerCase(LName), LDeclaration);
end;

procedure ParsePascal(
  const AContent: string;
  const AFields: TDictionary<string, TRadIANamedDeclaration>;
  const AMethods: TDictionary<string, TRadIANamedDeclaration>;
  out ARootClass: TRadIANamedDeclaration
);
var
  LInFormClass: Boolean;
  LLines: TArray<string>;
  LName: string;
  I: Integer;
begin
  ARootClass := Default(TRadIANamedDeclaration);
  LInFormClass := False;
  LLines := AContent.Replace(#13#10, #10).Split([#10]);
  for I := 0 to High(LLines) do
  begin
    if ARootClass.Name = '' then
    begin
      LName := ExtractMatch(
        LLines[I],
        '^\s*(?<name>T[A-Za-z_]\w*)\s*=\s*class\s*\(',
        'name'
      );
      if LName <> '' then
      begin
        ARootClass.Name := LName;
        ARootClass.Line := I + 1;
        LInFormClass := True;
      end;
    end;
    if LInFormClass then
      AddPascalField(LLines[I], I + 1, AFields);
    AddPascalMethod(LLines[I], I + 1, AMethods);
    if LInFormClass and TRegEx.IsMatch(LLines[I], '^\s*end\s*;') then
      LInFormClass := False;
  end;
end;

procedure AuditRootClass(
  const ADfmRoot: TRadIANamedDeclaration;
  const APasRoot: TRadIANamedDeclaration;
  const AFindings: TList<TRadIADfmPasFinding>
);
begin
  if (ADfmRoot.TypeName <> '') and (APasRoot.Name <> '') and
    not SameText(ADfmRoot.TypeName, APasRoot.Name) then
    AddFinding(
      AFindings,
      TRadIADfmPasFinding.Create(
        'root_class_mismatch',
        dpsError,
        'dfm',
        ADfmRoot.Line,
        ADfmRoot.Name,
        'DFM root class does not match the Pascal form class.'
      )
    );
end;

procedure AuditComponents(
  const AComponents: TDictionary<string, TRadIANamedDeclaration>;
  const AFields: TDictionary<string, TRadIANamedDeclaration>;
  const ARootName: string;
  const AFindings: TList<TRadIADfmPasFinding>
);
var
  LComponent: TRadIANamedDeclaration;
  LField: TRadIANamedDeclaration;
  LPair: TPair<string, TRadIANamedDeclaration>;
begin
  for LPair in AComponents do
  begin
    LComponent := LPair.Value;
    if SameText(LComponent.Name, ARootName) then
      Continue;
    if not AFields.TryGetValue(LPair.Key, LField) then
    begin
      AddFinding(
        AFindings,
        TRadIADfmPasFinding.Create(
          'missing_component_field',
          dpsError,
          'dfm',
          LComponent.Line,
          LComponent.Name,
          'DFM component has no matching Pascal field.'
        )
      );
      Continue;
    end;
    if not SameText(LComponent.TypeName, LField.TypeName) then
      AddFinding(
        AFindings,
        TRadIADfmPasFinding.Create(
          'component_class_mismatch',
          dpsError,
          'pas',
          LField.Line,
          LField.Name,
          'Pascal field type does not match the DFM component class.'
        )
      );
  end;
end;

procedure AuditEvents(
  const AEvents: TList<TRadIADfmEvent>;
  const AMethods: TDictionary<string, TRadIANamedDeclaration>;
  const ARootClassName: string;
  const ASemanticQueries: IRadIASemanticQueryService;
  const AFindings: TList<TRadIADfmPasFinding>
);
var
  LEvent: TRadIADfmEvent;
  LMethod: TRadIANamedDeclaration;
  LQueryError: string;
  LResolvedMember: TRadIASemanticLocation;
  LResolvedMembers: TDictionary<string, Boolean>;
  LResolvedSymbols: TArray<TRadIASemanticLocation>;
begin
  LResolvedMembers := TDictionary<string, Boolean>.Create;
  try
    if Assigned(ASemanticQueries) and
      ASemanticQueries.FindResolvedMembers(
        ARootClassName,
        LResolvedSymbols,
        LQueryError
      ) then
      for LResolvedMember in LResolvedSymbols do
        LResolvedMembers.AddOrSetValue(
          LowerCase(LResolvedMember.Name),
          True
        );
    for LEvent in AEvents do
    begin
      if not AMethods.TryGetValue(LowerCase(LEvent.HandlerName), LMethod) then
      begin
        if LResolvedMembers.ContainsKey(
          LowerCase(LEvent.HandlerName)
        ) then
          Continue;
        AddFinding(
          AFindings,
          TRadIADfmPasFinding.Create(
            'missing_event_handler',
            dpsError,
            'dfm',
            LEvent.Line,
            LEvent.HandlerName,
            'DFM event references a missing Pascal method.'
          )
        );
        Continue;
      end;
      if IsNotifyEvent(LEvent.EventName) and
        not IsCompatibleNotifyDeclaration(LMethod.TypeName) then
        AddFinding(
          AFindings,
          TRadIADfmPasFinding.Create(
            'incompatible_event_handler',
            dpsError,
            'pas',
            LMethod.Line,
            LMethod.Name,
            'Common notification event handler must receive Sender: TObject.'
          )
        );
    end;
  finally
    LResolvedMembers.Free;
  end;
end;

procedure AuditOrphanFields(
  const AComponents: TDictionary<string, TRadIANamedDeclaration>;
  const AFields: TDictionary<string, TRadIANamedDeclaration>;
  const AFindings: TList<TRadIADfmPasFinding>
);
var
  LField: TRadIANamedDeclaration;
  LPair: TPair<string, TRadIANamedDeclaration>;
begin
  for LPair in AFields do
  begin
    LField := LPair.Value;
    if not AComponents.ContainsKey(LPair.Key) then
      AddFinding(
        AFindings,
        TRadIADfmPasFinding.Create(
          'orphan_component_field',
          dpsWarning,
          'pas',
          LField.Line,
          LField.Name,
          'Pascal component field has no matching DFM component.'
        )
      );
  end;
end;

function IsReferencedHandler(
  const AEvents: TList<TRadIADfmEvent>;
  const AMethodName: string
): Boolean;
var
  LEvent: TRadIADfmEvent;
begin
  for LEvent in AEvents do
    if SameText(LEvent.HandlerName, AMethodName) then
      Exit(True);
  Result := False;
end;

function LooksLikeComponentHandler(
  const AComponents: TDictionary<string, TRadIANamedDeclaration>;
  const AMethodName: string
): Boolean;
var
  LPair: TPair<string, TRadIANamedDeclaration>;
  LSuffix: string;
begin
  for LPair in AComponents do
    if StartsText(LPair.Value.Name, AMethodName) then
    begin
      LSuffix := Copy(AMethodName, Length(LPair.Value.Name) + 1, MaxInt);
      if SameText(LSuffix, 'Click') or SameText(LSuffix, 'Change') or
        SameText(LSuffix, 'Enter') or SameText(LSuffix, 'Exit') then
        Exit(True);
    end;
  Result := False;
end;

procedure AuditOrphanHandlers(
  const AComponents: TDictionary<string, TRadIANamedDeclaration>;
  const AEvents: TList<TRadIADfmEvent>;
  const AMethods: TDictionary<string, TRadIANamedDeclaration>;
  const AFindings: TList<TRadIADfmPasFinding>
);
var
  LMethod: TRadIANamedDeclaration;
  LPair: TPair<string, TRadIANamedDeclaration>;
begin
  for LPair in AMethods do
  begin
    LMethod := LPair.Value;
    if LooksLikeComponentHandler(AComponents, LMethod.Name) and
      not IsReferencedHandler(AEvents, LMethod.Name) then
      AddFinding(
        AFindings,
        TRadIADfmPasFinding.Create(
          'orphan_event_handler',
          dpsWarning,
          'pas',
          LMethod.Line,
          LMethod.Name,
          'Pascal method looks like a component handler but is not assigned in the DFM.'
        )
      );
  end;
end;

{ TRadIADfmPasFinding }

constructor TRadIADfmPasFinding.Create(
  const ACode: string;
  const ASeverity: TRadIADfmPasSeverity;
  const AFileKind: string;
  const ALine: Integer;
  const AName: string;
  const AMessage: string
);
begin
  FCode := ACode;
  FSeverity := ASeverity;
  FFileKind := AFileKind;
  FLine := ALine;
  FName := AName;
  FMessage := AMessage;
end;

{ TRadIADfmPasAuditInput }

constructor TRadIADfmPasAuditInput.Create(
  const ADfmFileName: string;
  const ADfmContent: string;
  const APasFileName: string;
  const APasContent: string
);
begin
  FDfmFileName := ADfmFileName;
  FDfmContent := ADfmContent;
  FPasFileName := APasFileName;
  FPasContent := APasContent;
end;

{ TRadIADfmPasAuditResult }

constructor TRadIADfmPasAuditResult.Create(
  const AFindings: TArray<TRadIADfmPasFinding>
);
begin
  FFindings := AFindings;
end;

function TRadIADfmPasAuditResult.HasErrors: Boolean;
var
  LFinding: TRadIADfmPasFinding;
begin
  for LFinding in FFindings do
    if LFinding.Severity = dpsError then
      Exit(True);
  Result := False;
end;

{ TRadIADfmPasAuditor }

constructor TRadIADfmPasAuditor.Create;
begin
  inherited Create;
  FSemanticQueries := nil;
end;

constructor TRadIADfmPasAuditor.Create(
  const ASemanticQueries: IRadIASemanticQueryService
);
begin
  inherited Create;
  FSemanticQueries := ASemanticQueries;
end;

function TRadIADfmPasAuditor.Audit(
  const AInput: TRadIADfmPasAuditInput
): TRadIADfmPasAuditResult;
var
  LComponents: TDictionary<string, TRadIANamedDeclaration>;
  LDfmRoot: TRadIANamedDeclaration;
  LEvents: TList<TRadIADfmEvent>;
  LFields: TDictionary<string, TRadIANamedDeclaration>;
  LFindings: TList<TRadIADfmPasFinding>;
  LMethods: TDictionary<string, TRadIANamedDeclaration>;
  LPasRoot: TRadIANamedDeclaration;
begin
  if (Length(AInput.DfmContent) > CMaxAuditCharacters) or
    (Length(AInput.PasContent) > CMaxAuditCharacters) then
    raise EArgumentOutOfRangeException.Create(
      'DFM and Pascal content must each be at most 2 MiB.'
    );
  LComponents := TDictionary<string, TRadIANamedDeclaration>.Create;
  LEvents := TList<TRadIADfmEvent>.Create;
  LFields := TDictionary<string, TRadIANamedDeclaration>.Create;
  LFindings := TList<TRadIADfmPasFinding>.Create;
  LMethods := TDictionary<string, TRadIANamedDeclaration>.Create;
  try
    ParseDfm(AInput.DfmContent, LComponents, LEvents, LDfmRoot);
    ParsePascal(AInput.PasContent, LFields, LMethods, LPasRoot);
    AuditRootClass(LDfmRoot, LPasRoot, LFindings);
    AuditComponents(LComponents, LFields, LDfmRoot.Name, LFindings);
    AuditEvents(
      LEvents,
      LMethods,
      LPasRoot.Name,
      FSemanticQueries,
      LFindings
    );
    AuditOrphanFields(LComponents, LFields, LFindings);
    AuditOrphanHandlers(LComponents, LEvents, LMethods, LFindings);
    Result := TRadIADfmPasAuditResult.Create(LFindings.ToArray);
  finally
    LMethods.Free;
    LFindings.Free;
    LFields.Free;
    LEvents.Free;
    LComponents.Free;
  end;
end;

end.
