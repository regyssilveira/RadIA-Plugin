unit RadIA.Core.SemanticQueries;

interface

uses
  RadIA.Semantic.Workspace;

type
  TRadIASemanticLocation = record
  private
    FContainerName: string;
    FFileName: string;
    FKind: string;
    FName: string;
    FSignature: string;
    FSymbolId: string;
    FStartOffset: Integer;
    FUnitKey: string;
    FVisibility: string;
  public
    constructor Create(
      const AName: string;
      const AKind: string;
      const AContainerName: string;
      const AFileName: string;
      const ASignature: string;
      const AStartOffset: Integer
    ); overload;
    constructor Create(
      const AName: string;
      const AKind: string;
      const AContainerName: string;
      const AFileName: string;
      const ASignature: string;
      const AVisibility: string;
      const AStartOffset: Integer
    ); overload;
    property ContainerName: string read FContainerName;
    property FileName: string read FFileName;
    property Kind: string read FKind;
    property Name: string read FName;
    property Signature: string read FSignature;
    property SymbolId: string read FSymbolId;
    property StartOffset: Integer read FStartOffset;
    property Visibility: string read FVisibility;
    property UnitKey: string read FUnitKey;
  end;

  TRadIASemanticReferenceLocation = record
  private
    FColumn: Integer;
    FFileName: string;
    FKind: string;
    FLength: Integer;
    FLine: Integer;
    FReason: string;
    FStartOffset: Integer;
    FUnitKey: string;
  public
    constructor Create(
      const AUnitKey: string;
      const AFileName: string;
      const ALine: Integer;
      const AColumn: Integer;
      const AKind: string;
      const AReason: string
    );
    property Column: Integer read FColumn;
    property FileName: string read FFileName;
    property Kind: string read FKind;
    property Length: Integer read FLength;
    property Line: Integer read FLine;
    property Reason: string read FReason;
    property StartOffset: Integer read FStartOffset;
    property UnitKey: string read FUnitKey;
  end;

  IRadIASemanticQueryService = interface
    ['{F2743307-AB37-43F2-8C4B-3E3C99AD29DE}']
    function FindSymbols(
      const AName: string;
      out ASymbols: TArray<TRadIASemanticLocation>;
      out AError: string
    ): Boolean;
    function FindResolvedMembers(
      const AContainerName: string;
      out AMembers: TArray<TRadIASemanticLocation>;
      out AError: string
    ): Boolean;
    function FindReferences(
      const ASymbolId: string;
      const AIncludeCandidates: Boolean;
      const AMaxItems: Integer;
      out AReferences: TArray<TRadIASemanticReferenceLocation>;
      out AError: string
    ): Boolean;
    function ListPublicApiSymbols(
      out ASymbols: TArray<TRadIASemanticLocation>;
      out AError: string
    ): Boolean;
    function BuildContext(
      const ASymbolName: string;
      const AMaxCharacters: Integer;
      out AContext: string;
      out AError: string
    ): Boolean;
    function HasResolvedMember(
      const AContainerName: string;
      const AMemberName: string
    ): Boolean;
  end;

  TRadIASemanticQueryService = class(
    TInterfacedObject,
    IRadIASemanticQueryService
  )
  private
    FClient: IRadIASemanticRequestClient;
    function Execute(
      const AMethod: string;
      const AFieldName: string;
      const AFieldValue: string;
      out AItems: TArray<TRadIASemanticLocation>;
      out AError: string
    ): Boolean;
    function ExecuteReferences(
      const ASymbolId: string;
      const AIncludeCandidates: Boolean;
      const AMaxItems: Integer;
      out AReferences: TArray<TRadIASemanticReferenceLocation>;
      out AError: string
    ): Boolean;
  public
    constructor Create(const AClient: IRadIASemanticRequestClient);
    function FindSymbols(
      const AName: string;
      out ASymbols: TArray<TRadIASemanticLocation>;
      out AError: string
    ): Boolean;
    function FindResolvedMembers(
      const AContainerName: string;
      out AMembers: TArray<TRadIASemanticLocation>;
      out AError: string
    ): Boolean;
    function FindReferences(
      const ASymbolId: string;
      const AIncludeCandidates: Boolean;
      const AMaxItems: Integer;
      out AReferences: TArray<TRadIASemanticReferenceLocation>;
      out AError: string
    ): Boolean;
    function ListPublicApiSymbols(
      out ASymbols: TArray<TRadIASemanticLocation>;
      out AError: string
    ): Boolean;
    function BuildContext(
      const ASymbolName: string;
      const AMaxCharacters: Integer;
      out AContext: string;
      out AError: string
    ): Boolean;
    function HasResolvedMember(
      const AContainerName: string;
      const AMemberName: string
    ): Boolean;
  end;

implementation

uses
  System.Generics.Collections,
  System.JSON,
  System.SysUtils;

const
  CMaximumSemanticQueryItems = 200;

constructor TRadIASemanticLocation.Create(
  const AName: string;
  const AKind: string;
  const AContainerName: string;
  const AFileName: string;
  const ASignature: string;
  const AStartOffset: Integer
);
begin
  Create(
    AName,
    AKind,
    AContainerName,
    AFileName,
    ASignature,
    '',
    AStartOffset
  );
end;

constructor TRadIASemanticLocation.Create(
  const AName: string;
  const AKind: string;
  const AContainerName: string;
  const AFileName: string;
  const ASignature: string;
  const AVisibility: string;
  const AStartOffset: Integer
);
begin
  FName := AName;
  FKind := AKind;
  FContainerName := AContainerName;
  FFileName := AFileName;
  FSignature := ASignature;
  FVisibility := AVisibility;
  FStartOffset := AStartOffset;
end;

constructor TRadIASemanticReferenceLocation.Create(
  const AUnitKey: string;
  const AFileName: string;
  const ALine: Integer;
  const AColumn: Integer;
  const AKind: string;
  const AReason: string
);
begin
  FUnitKey := AUnitKey;
  FFileName := AFileName;
  FLine := ALine;
  FColumn := AColumn;
  FKind := AKind;
  FReason := AReason;
  FStartOffset := 0;
  FLength := 0;
end;

constructor TRadIASemanticQueryService.Create(
  const AClient: IRadIASemanticRequestClient
);
begin
  inherited Create;
  if not Assigned(AClient) then
    raise EArgumentNilException.Create('AClient');
  FClient := AClient;
end;

function TRadIASemanticQueryService.Execute(
  const AMethod: string;
  const AFieldName: string;
  const AFieldValue: string;
  out AItems: TArray<TRadIASemanticLocation>;
  out AError: string
): Boolean;
var
  LArray: TJSONArray;
  LDocument: TJSONObject;
  LIndex: Integer;
  LItem: TJSONObject;
  LLocation: TRadIASemanticLocation;
  LList: TList<TRadIASemanticLocation>;
  LParameters: TJSONObject;
  LResponse: string;
  LResult: TJSONObject;
begin
  AItems := nil;
  AError := '';
  LParameters := TJSONObject.Create;
  try
    LParameters.AddPair(AFieldName, AFieldValue);
    Result := FClient.Request(AMethod, LParameters.ToJSON, LResponse, AError);
  finally
    LParameters.Free;
  end;
  if not Result then
    Exit;
  LDocument := TJSONObject.ParseJSONValue(LResponse) as TJSONObject;
  try
    if not Assigned(LDocument) then
    begin
      AError := 'The semantic engine returned invalid JSON.';
      Exit(False);
    end;
    LResult := LDocument.GetValue<TJSONObject>('result');
    if not Assigned(LResult) then
    begin
      AError := 'The semantic engine returned no query result.';
      Exit(False);
    end;
    LArray := LResult.GetValue<TJSONArray>('symbols');
    if not Assigned(LArray) then
    begin
      AError := 'The semantic engine returned no symbol array.';
      Exit(False);
    end;
    LList := TList<TRadIASemanticLocation>.Create;
    try
      for LIndex := 0 to LArray.Count - 1 do
      begin
        if LList.Count >= CMaximumSemanticQueryItems then
          Break;
        LItem := LArray[LIndex] as TJSONObject;
        LLocation := TRadIASemanticLocation.Create(
          LItem.GetValue<string>('name', ''),
          LItem.GetValue<string>('kind', ''),
          LItem.GetValue<string>('container', ''),
          LItem.GetValue<string>('fileName', ''),
          LItem.GetValue<string>('signature', ''),
          LItem.GetValue<string>('visibility', ''),
          LItem.GetValue<Integer>('startOffset', 0)
        );
        LLocation.FSymbolId := LItem.GetValue<string>('symbolId', '');
        LLocation.FUnitKey := LItem.GetValue<string>('unitKey', '');
        LList.Add(LLocation);
      end;
      AItems := LList.ToArray;
    finally
      LList.Free;
    end;
    Result := True;
  finally
    LDocument.Free;
  end;
end;

function TRadIASemanticQueryService.ExecuteReferences(
  const ASymbolId: string;
  const AIncludeCandidates: Boolean;
  const AMaxItems: Integer;
  out AReferences: TArray<TRadIASemanticReferenceLocation>;
  out AError: string
): Boolean;
var
  LArray: TJSONArray;
  LDocument: TJSONObject;
  LIndex: Integer;
  LItem: TJSONObject;
  LList: TList<TRadIASemanticReferenceLocation>;
  LParameters: TJSONObject;
  LReference: TRadIASemanticReferenceLocation;
  LResponse: string;
  LResult: TJSONObject;
begin
  AReferences := nil;
  AError := '';
  LParameters := TJSONObject.Create;
  try
    LParameters.AddPair('symbolId', ASymbolId);
    LParameters.AddPair(
      'includeCandidates',
      TJSONBool.Create(AIncludeCandidates)
    );
    LParameters.AddPair('maxItems', TJSONNumber.Create(AMaxItems));
    Result := FClient.Request(
      'findReferences',
      LParameters.ToJSON,
      LResponse,
      AError
    );
  finally
    LParameters.Free;
  end;
  if not Result then
    Exit;
  LDocument := TJSONObject.ParseJSONValue(LResponse) as TJSONObject;
  try
    if not Assigned(LDocument) then
    begin
      AError := 'The semantic engine returned invalid reference JSON.';
      Exit(False);
    end;
    LResult := LDocument.GetValue<TJSONObject>('result');
    if not Assigned(LResult) then
    begin
      AError := 'The semantic engine returned no reference result.';
      Exit(False);
    end;
    if not SameText(LResult.GetValue<string>('status', ''), 'resolved') then
    begin
      AError := 'The requested semantic symbol identity was not found.';
      Exit(False);
    end;
    LArray := LResult.GetValue<TJSONArray>('references');
    if not Assigned(LArray) then
    begin
      AError := 'The semantic engine returned no reference array.';
      Exit(False);
    end;
    LList := TList<TRadIASemanticReferenceLocation>.Create;
    try
      for LIndex := 0 to LArray.Count - 1 do
      begin
        LItem := LArray[LIndex] as TJSONObject;
        LReference := TRadIASemanticReferenceLocation.Create(
          LItem.GetValue<string>('unitKey', ''),
          LItem.GetValue<string>('fileName', ''),
          LItem.GetValue<Integer>('line', 1),
          LItem.GetValue<Integer>('column', 1),
          LItem.GetValue<string>('kind', ''),
          LItem.GetValue<string>('reason', '')
        );
        LReference.FStartOffset := LItem.GetValue<Integer>(
          'startOffset',
          0
        );
        LReference.FLength := LItem.GetValue<Integer>('length', 0);
        LList.Add(LReference);
      end;
      AReferences := LList.ToArray;
    finally
      LList.Free;
    end;
    Result := True;
  finally
    LDocument.Free;
  end;
end;

function TRadIASemanticQueryService.ListPublicApiSymbols(
  out ASymbols: TArray<TRadIASemanticLocation>;
  out AError: string
): Boolean;
begin
  Result := Execute(
    'listPublicApiSymbols',
    'scope',
    'project',
    ASymbols,
    AError
  );
end;

function TRadIASemanticQueryService.FindSymbols(
  const AName: string;
  out ASymbols: TArray<TRadIASemanticLocation>;
  out AError: string
): Boolean;
begin
  Result := Execute('findSymbols', 'name', AName, ASymbols, AError);
end;

function TRadIASemanticQueryService.FindResolvedMembers(
  const AContainerName: string;
  out AMembers: TArray<TRadIASemanticLocation>;
  out AError: string
): Boolean;
begin
  Result := Execute(
    'findResolvedMembers',
    'container',
    AContainerName,
    AMembers,
    AError
  );
end;

function TRadIASemanticQueryService.FindReferences(
  const ASymbolId: string;
  const AIncludeCandidates: Boolean;
  const AMaxItems: Integer;
  out AReferences: TArray<TRadIASemanticReferenceLocation>;
  out AError: string
): Boolean;
begin
  Result := ExecuteReferences(
    ASymbolId,
    AIncludeCandidates,
    AMaxItems,
    AReferences,
    AError
  );
end;

function TRadIASemanticQueryService.BuildContext(
  const ASymbolName: string;
  const AMaxCharacters: Integer;
  out AContext: string;
  out AError: string
): Boolean;
var
  LItem: TRadIASemanticLocation;
  LMemberError: string;
  LMembers: TArray<TRadIASemanticLocation>;
  LSymbols: TArray<TRadIASemanticLocation>;
begin
  AContext := '';
  Result := FindSymbols(ASymbolName, LSymbols, AError);
  if not Result then
    Exit;
  for LItem in LSymbols do
  begin
    AContext := AContext + Format(
      '%s %s in %s',
      [LItem.Kind, LItem.Name, LItem.FileName]
    ) + sLineBreak;
    if LItem.Signature <> '' then
      AContext := AContext + 'Declaration: ' + LItem.Signature + sLineBreak;
  end;
  if FindResolvedMembers(ASymbolName, LMembers, LMemberError) then
    for LItem in LMembers do
      AContext := AContext + Format(
        'Member: %s.%s - %s',
        [LItem.ContainerName, LItem.Name, LItem.Signature]
      ) + sLineBreak;
  if LMemberError <> '' then
    AContext := AContext +
      'Diagnostic: resolved members unavailable - ' + LMemberError +
      sLineBreak;
  AError := '';
  AContext := Trim(AContext);
  if (AMaxCharacters > 0) and (Length(AContext) > AMaxCharacters) then
    SetLength(AContext, AMaxCharacters);
  Result := AContext <> '';
end;

function TRadIASemanticQueryService.HasResolvedMember(
  const AContainerName: string;
  const AMemberName: string
): Boolean;
var
  LError: string;
  LMember: TRadIASemanticLocation;
  LMembers: TArray<TRadIASemanticLocation>;
begin
  Result := FindResolvedMembers(AContainerName, LMembers, LError);
  if not Result then
    Exit;
  for LMember in LMembers do
    if SameText(LMember.Name, AMemberName) then
      Exit(True);
  Result := False;
end;

end.
