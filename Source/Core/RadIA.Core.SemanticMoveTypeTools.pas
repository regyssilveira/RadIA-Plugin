unit RadIA.Core.SemanticMoveTypeTools;

interface

uses
  RadIA.Core.MultiFilePatches,
  RadIA.Core.Patches,
  RadIA.Core.SemanticQueries,
  RadIA.Core.Tools,
  RadIA.Core.Workspace;

procedure RegisterRadIASemanticMoveTypeTools(
  const ARegistry: IRadIAToolRegistry;
  const AWorkspace: IRadIAWorkspaceFacade;
  const AQueries: IRadIASemanticQueryService;
  const AMutation: IRadIAEditorMutationFacade;
  const APatches: IRadIAMultiFilePatchService
);

implementation

uses
  System.Generics.Collections,
  System.JSON,
  System.StrUtils,
  System.SysUtils,
  RadIA.Core.DelphiTypeMove,
  RadIA.Semantic.Lexer,
  RadIA.Semantic.Parser;

type
  TRadIAMoveTypeRequest = record
  private
    FDestinationFile: string;
    FSymbolName: string;
  public
    constructor Create(
      const ASymbolName: string;
      const ADestinationFile: string
    );
    property DestinationFile: string read FDestinationFile;
    property SymbolName: string read FSymbolName;
  end;

  TRadIAMoveTypeComposition = record
  private
    FDestination: TRadIAEditorContent;
    FDestinationContent: string;
    FImplementationCount: Integer;
    FSource: TRadIAEditorContent;
    FSourceContent: string;
  public
    constructor Create(
      const ASource: TRadIAEditorContent;
      const ADestination: TRadIAEditorContent;
      const ASourceContent: string;
      const ADestinationContent: string;
      const AImplementationCount: Integer
    );
    property Destination: TRadIAEditorContent read FDestination;
    property DestinationContent: string read FDestinationContent;
    property ImplementationCount: Integer read FImplementationCount;
    property Source: TRadIAEditorContent read FSource;
    property SourceContent: string read FSourceContent;
  end;

  TRadIAMoveTypeConsumerContext = class
  private
    FProposals: TDictionary<string, string>;
    FSnapshots: TDictionary<string, TRadIAEditorContent>;
    FSourceContent: string;
  public
    constructor Create(const ASourceContent: string);
    destructor Destroy; override;
    property Proposals: TDictionary<string, string> read FProposals;
    property Snapshots: TDictionary<string, TRadIAEditorContent> read FSnapshots;
    property SourceContent: string read FSourceContent write FSourceContent;
  end;

  TRadIAPrepareMoveTypeTool = class(TInterfacedObject, IRadIATool)
  private
    FMutation: IRadIAEditorMutationFacade;
    FPatches: IRadIAMultiFilePatchService;
    FQueries: IRadIASemanticQueryService;
    FWorkspace: IRadIAWorkspaceFacade;
    function BuildComposition(
      const ARequest: TRadIAMoveTypeRequest;
      const ASymbol: TRadIASemanticLocation;
      out AComposition: TRadIAMoveTypeComposition;
      out AError: string
    ): Boolean;
    function BuildDestination(
      const ASource: TRadIAEditorContent;
      const ADestination: TRadIAEditorContent;
      const AMovableType: TRadIADelphiMovableType;
      const AImplementations: TArray<TRadIADelphiMoveBlock>;
      out AContent: string;
      out AError: string
    ): Boolean;
    function BuildResult(
      const ARequest: TRadIAMoveTypeRequest;
      const AComposition: TRadIAMoveTypeComposition;
      const APatchResult: TRadIAMultiFilePatchResult
    ): TRadIAToolResult;
    function BuildSpecs(
      const ARequest: TRadIAMoveTypeRequest;
      const ASymbol: TRadIASemanticLocation;
      const AComposition: TRadIAMoveTypeComposition;
      out ASpecs: TArray<TRadIAMultiFilePatchSpec>;
      out AError: string
    ): Boolean;
    procedure AppendConsumerSpecs(
      const ASnapshots: TDictionary<string, TRadIAEditorContent>;
      const AProposals: TDictionary<string, string>;
      const ASpecs: TList<TRadIAMultiFilePatchSpec>
    );
    function ProcessReference(
      const AReference: TRadIASemanticReferenceLocation;
      const AComposition: TRadIAMoveTypeComposition;
      const AMovableType: TRadIADelphiMovableType;
      const AImplementations: TArray<TRadIADelphiMoveBlock>;
      const AContext: TRadIAMoveTypeConsumerContext;
      out AError: string
    ): Boolean;
    function LoadRequest(
      const AArgumentsJson: string;
      out ARequest: TRadIAMoveTypeRequest;
      out AError: string
    ): Boolean;
    function ResolveSymbol(
      const AName: string;
      out ASymbol: TRadIASemanticLocation;
      out AError: string
    ): Boolean;
    function ValidateProjectGraph(
      const ASpecs: TArray<TRadIAMultiFilePatchSpec>;
      out AError: string
    ): Boolean;
  public
    constructor Create(
      const AWorkspace: IRadIAWorkspaceFacade;
      const AQueries: IRadIASemanticQueryService;
      const AMutation: IRadIAEditorMutationFacade;
      const APatches: IRadIAMultiFilePatchService
    );
    function Execute(const ARequest: TRadIAToolRequest): TRadIAToolResult;
    function GetDescriptor: TRadIAToolDescriptor;
  end;

const
  CInputSchema =
    '{"type":"object","required":["symbol","destinationFile"],' +
    '"properties":{"symbol":{"type":"string","minLength":1},' +
    '"destinationFile":{"type":"string","minLength":1}},' +
    '"additionalProperties":false}';
  COutputSchema =
    '{"type":"object","required":["previewId","state","symbol",' +
    '"sourceFile","destinationFile","implementationCount","files",' +
    '"nextAction"],"properties":{"previewId":{"type":"string"},' +
    '"state":{"type":"string"},"symbol":{"type":"string"},' +
    '"sourceFile":{"type":"string"},"destinationFile":{"type":"string"},' +
    '"implementationCount":{"type":"integer"},"files":{"type":"array"},' +
    '"nextAction":{"type":"string"}}}';
  CMaxFileCharacters = 2 * 1024 * 1024;
  CReferenceLimit = 1000;

constructor TRadIAMoveTypeRequest.Create(
  const ASymbolName: string;
  const ADestinationFile: string
);
begin
  FSymbolName := ASymbolName;
  FDestinationFile := ADestinationFile;
end;

constructor TRadIAMoveTypeComposition.Create(
  const ASource: TRadIAEditorContent;
  const ADestination: TRadIAEditorContent;
  const ASourceContent: string;
  const ADestinationContent: string;
  const AImplementationCount: Integer
);
begin
  FSource := ASource;
  FDestination := ADestination;
  FSourceContent := ASourceContent;
  FDestinationContent := ADestinationContent;
  FImplementationCount := AImplementationCount;
end;

constructor TRadIAPrepareMoveTypeTool.Create(
  const AWorkspace: IRadIAWorkspaceFacade;
  const AQueries: IRadIASemanticQueryService;
  const AMutation: IRadIAEditorMutationFacade;
  const APatches: IRadIAMultiFilePatchService
);
begin
  inherited Create;
  if not Assigned(AWorkspace) then
    raise EArgumentNilException.Create('AWorkspace');
  if not Assigned(AQueries) then
    raise EArgumentNilException.Create('AQueries');
  if not Assigned(AMutation) then
    raise EArgumentNilException.Create('AMutation');
  if not Assigned(APatches) then
    raise EArgumentNilException.Create('APatches');
  FWorkspace := AWorkspace;
  FQueries := AQueries;
  FMutation := AMutation;
  FPatches := APatches;
end;

function TRadIAPrepareMoveTypeTool.LoadRequest(
  const AArgumentsJson: string;
  out ARequest: TRadIAMoveTypeRequest;
  out AError: string
): Boolean;
var
  LDocument: TJSONObject;
begin
  Result := False;
  ARequest := Default(TRadIAMoveTypeRequest);
  AError := '';
  LDocument := TJSONObject.ParseJSONValue(AArgumentsJson) as TJSONObject;
  if not Assigned(LDocument) then
  begin
    AError := 'Move Type arguments must be a JSON object.';
    Exit;
  end;
  try
    ARequest := TRadIAMoveTypeRequest.Create(
      Trim(LDocument.GetValue<string>('symbol', '')),
      Trim(LDocument.GetValue<string>('destinationFile', ''))
    );
    if ARequest.SymbolName.IsEmpty or ARequest.DestinationFile.IsEmpty then
    begin
      AError := 'Symbol and destinationFile are required.';
      Exit;
    end;
    Result := True;
  finally
    LDocument.Free;
  end;
end;

function TRadIAPrepareMoveTypeTool.ResolveSymbol(
  const AName: string;
  out ASymbol: TRadIASemanticLocation;
  out AError: string
): Boolean;
var
  LCandidate: TRadIASemanticLocation;
  LMatchCount: Integer;
  LSymbols: TArray<TRadIASemanticLocation>;
begin
  Result := FQueries.FindSymbols(AName, LSymbols, AError);
  ASymbol := Default(TRadIASemanticLocation);
  if not Result then
    Exit;
  LMatchCount := 0;
  for LCandidate in LSymbols do
    if SameText(LCandidate.Name, AName) and
      LCandidate.ContainerName.IsEmpty and
      SameText(LCandidate.DeclarationSection, 'interface') then
    begin
      ASymbol := LCandidate;
      Inc(LMatchCount);
    end;
  if LMatchCount <> 1 then
  begin
    AError := 'Move Type requires exactly one top-level interface type identity.';
    Exit(False);
  end;
  if ASymbol.SymbolId.IsEmpty or ASymbol.FileName.IsEmpty then
  begin
    AError := 'The Delphi type has no stable semantic identity or source file.';
    Exit(False);
  end;
  Result := True;
end;

function IsProjectUnit(
  const AFileName: string;
  const AProjectUnits: TArray<string>
): Boolean;
var
  LProjectUnit: string;
begin
  for LProjectUnit in AProjectUnits do
    if SameFileName(LProjectUnit, AFileName) then
      Exit(True);
  Result := False;
end;

function IsCompleteSnapshot(const ASnapshot: TRadIAEditorContent): Boolean;
begin
  Result := not ASnapshot.FileName.IsEmpty and
    not ASnapshot.Revision.IsEmpty and
    not ASnapshot.Truncated and
    (ASnapshot.OriginalLength = Length(ASnapshot.Content));
end;

function DestinationContainsType(
  const AContent: string;
  const ATypeName: string
): Boolean;
var
  LParsed: TRadIASemanticParseResult;
  LSymbol: TRadIASemanticSymbol;
begin
  LParsed := TRadIASemanticParser.Parse(AContent, []);
  for LSymbol in LParsed.Symbols do
    if (LSymbol.Kind in [sskClass, sskRecord, sskInterface, sskHelper]) and
      SameText(LSymbol.Name, ATypeName) then
      Exit(True);
  Result := False;
end;

function CollectImplementationContent(
  const ABlocks: TArray<TRadIADelphiMoveBlock>
): TArray<string>;
var
  LIndex: Integer;
begin
  SetLength(Result, Length(ABlocks));
  for LIndex := Low(ABlocks) to High(ABlocks) do
    Result[LIndex] := ABlocks[LIndex].Content;
end;

function AddSourceDependencies(
  const ASource: TRadIAEditorContent;
  const ADestinationUnit: string;
  var AContent: string;
  out AError: string
): Boolean;
var
  LInterfaceSection: Boolean;
  LParsed: TRadIASemanticParseResult;
  LProposed: string;
  LSymbol: TRadIASemanticSymbol;
begin
  Result := False;
  LParsed := TRadIASemanticParser.Parse(ASource.Content, []);
  for LSymbol in LParsed.Symbols do
  begin
    if (LSymbol.Kind <> sskUnitReference) or
      SameText(LSymbol.Name, ADestinationUnit) or
      SameText(LSymbol.Name, ASource.UnitName) then
      Continue;
    LInterfaceSection :=
      LSymbol.DeclarationSection = sdsInterface;
    if not TRadIADelphiTypeMoveEditor.TryEnsureUsesUnit(
      AContent,
      LSymbol.Name,
      LInterfaceSection,
      LProposed,
      AError
    ) then
      Exit;
    AContent := LProposed;
  end;
  Result := True;
end;

function InterfaceUsesUnit(
  const AContent: string;
  const AUnitName: string
): Boolean;
var
  LParsed: TRadIASemanticParseResult;
  LSymbol: TRadIASemanticSymbol;
begin
  LParsed := TRadIASemanticParser.Parse(AContent, []);
  for LSymbol in LParsed.Symbols do
    if (LSymbol.Kind = sskUnitReference) and
      (LSymbol.DeclarationSection = sdsInterface) and
      SameText(LSymbol.Name, AUnitName) then
      Exit(True);
  Result := False;
end;

function IsInsideMovedBlock(
  const AOffset: Integer;
  const AMovableType: TRadIADelphiMovableType;
  const AImplementations: TArray<TRadIADelphiMoveBlock>
): Boolean;
var
  LBlock: TRadIADelphiMoveBlock;
begin
  if (AOffset >= AMovableType.StartOffset) and
    (AOffset < AMovableType.StartOffset + AMovableType.Length) then
    Exit(True);
  for LBlock in AImplementations do
    if (AOffset >= LBlock.StartOffset) and
      (AOffset < LBlock.StartOffset + LBlock.Length) then
      Exit(True);
  Result := False;
end;

function ContainsIdentifier(
  const AContent: string;
  const AIdentifier: string
): Boolean;
var
  LToken: TRadIASemanticToken;
begin
  for LToken in TRadIASemanticLexer.Tokenize(AContent) do
    if SameText(LToken.Text, AIdentifier) then
      Exit(True);
  Result := False;
end;

function HasPrivateSourceDependency(
  const ASource: string;
  const ATypeName: string;
  const AMovableType: TRadIADelphiMovableType;
  const AImplementations: TArray<TRadIADelphiMoveBlock>;
  out ADependency: string
): Boolean;
var
  LBlock: TRadIADelphiMoveBlock;
  LContent: string;
  LParsed: TRadIASemanticParseResult;
  LSymbol: TRadIASemanticSymbol;
begin
  LContent := AMovableType.Content;
  for LBlock in AImplementations do
    LContent := LContent + sLineBreak + LBlock.Content;
  LParsed := TRadIASemanticParser.Parse(ASource, []);
  for LSymbol in LParsed.Symbols do
    if (LSymbol.DeclarationSection = sdsImplementation) and
      not SameText(LSymbol.ContainerName, ATypeName) and
      not LSymbol.Name.IsEmpty and
      ContainsIdentifier(LContent, LSymbol.Name) then
    begin
      ADependency := LSymbol.Name;
      Exit(True);
    end;
  ADependency := '';
  Result := False;
end;

function TRadIAPrepareMoveTypeTool.BuildDestination(
  const ASource: TRadIAEditorContent;
  const ADestination: TRadIAEditorContent;
  const AMovableType: TRadIADelphiMovableType;
  const AImplementations: TArray<TRadIADelphiMoveBlock>;
  out AContent: string;
  out AError: string
): Boolean;
var
  LProposed: string;
begin
  Result := False;
  AContent := ADestination.Content;
  if not AddSourceDependencies(
    ASource,
    ADestination.UnitName,
    AContent,
    AError
  ) then
    Exit;
  if not TRadIADelphiTypeMoveEditor.TryInsertDeclaration(
    AContent,
    AMovableType.Content,
    LProposed,
    AError
  ) then
    Exit;
  AContent := LProposed;
  if not TRadIADelphiTypeMoveEditor.TryInsertImplementations(
    AContent,
    CollectImplementationContent(AImplementations),
    LProposed,
    AError
  ) then
    Exit;
  AContent := LProposed;
  Result := True;
end;

function TRadIAPrepareMoveTypeTool.BuildComposition(
  const ARequest: TRadIAMoveTypeRequest;
  const ASymbol: TRadIASemanticLocation;
  out AComposition: TRadIAMoveTypeComposition;
  out AError: string
): Boolean;
var
  LDependency: string;
  LDestination: TRadIAEditorContent;
  LDestinationContent: string;
  LImplementations: TArray<TRadIADelphiMoveBlock>;
  LMovableType: TRadIADelphiMovableType;
  LSource: TRadIAEditorContent;
  LSourceContent: string;
begin
  Result := False;
  AComposition := Default(TRadIAMoveTypeComposition);
  LSource := FMutation.ReadContent(ASymbol.FileName, CMaxFileCharacters);
  LDestination := FMutation.ReadContent(
    ARequest.DestinationFile,
    CMaxFileCharacters
  );
  if not IsProjectUnit(ASymbol.FileName, FWorkspace.ListProjectUnits) or
    not IsProjectUnit(ARequest.DestinationFile, FWorkspace.ListProjectUnits) then
  begin
    AError := 'Move Type source and destination must belong to the active project.';
    Exit;
  end;
  if SameFileName(LSource.FileName, LDestination.FileName) then
  begin
    AError := 'Move Type source and destination must be different units.';
    Exit;
  end;
  if not IsCompleteSnapshot(LSource) or not IsCompleteSnapshot(LDestination) then
  begin
    AError := 'Move Type requires complete, revisioned source and destination buffers.';
    Exit;
  end;
  if FileExists(ChangeFileExt(LSource.FileName, '.dfm')) then
  begin
    AError := 'Move Type does not move types owned by a Delphi form resource.';
    Exit;
  end;
  if DestinationContainsType(LDestination.Content, ARequest.SymbolName) then
  begin
    AError := 'The destination already declares a type with the requested name.';
    Exit;
  end;
  if not TRadIADelphiTypeMoveAnalyzer.TryAnalyze(
    LSource.Content,
    ARequest.SymbolName,
    ASymbol.StartOffset,
    LMovableType,
    AError
  ) or not TRadIADelphiTypeMoveAnalyzer.TryFindImplementations(
    LSource.Content,
    ARequest.SymbolName,
    LImplementations,
    AError
  ) then
    Exit;
  if ContainsText(LMovableType.Content, '{$R') or
    ContainsText(LMovableType.Content, '{$RESOURCE') then
  begin
    AError := 'Move Type does not move declarations coupled to resources.';
    Exit;
  end;
  if HasPrivateSourceDependency(
    LSource.Content,
    ARequest.SymbolName,
    LMovableType,
    LImplementations,
    LDependency
  ) then
  begin
    AError := 'Move Type cannot access the source implementation symbol ' +
      LDependency + ' from the destination.';
    Exit;
  end;
  if not TRadIADelphiTypeMoveEditor.TryRemoveMoveBlocks(
    LSource.Content,
    LMovableType,
    LImplementations,
    LSourceContent,
    AError
  ) or not BuildDestination(
    LSource,
    LDestination,
    LMovableType,
    LImplementations,
    LDestinationContent,
    AError
  ) then
    Exit;
  AComposition := TRadIAMoveTypeComposition.Create(
    LSource,
    LDestination,
    LSourceContent,
    LDestinationContent,
    Length(LImplementations)
  );
  Result := True;
end;

function TRadIAPrepareMoveTypeTool.BuildResult(
  const ARequest: TRadIAMoveTypeRequest;
  const AComposition: TRadIAMoveTypeComposition;
  const APatchResult: TRadIAMultiFilePatchResult
): TRadIAToolResult;
var
  LEntry: TRadIAMultiFilePatchEntry;
  LFiles: TJSONArray;
  LRoot: TJSONObject;
begin
  if not APatchResult.Success then
    Exit(TRadIAToolResult.Failed(
      APatchResult.ErrorCode,
      APatchResult.ErrorMessage
    ));
  LRoot := TJSONObject.Create;
  try
    LRoot.AddPair('previewId', APatchResult.Preview.Id);
    LRoot.AddPair('state', 'prepared');
    LRoot.AddPair('symbol', ARequest.SymbolName);
    LRoot.AddPair('sourceFile', AComposition.Source.FileName);
    LRoot.AddPair('destinationFile', AComposition.Destination.FileName);
    LRoot.AddPair(
      'implementationCount',
      TJSONNumber.Create(AComposition.ImplementationCount)
    );
    LFiles := TJSONArray.Create;
    LRoot.AddPair('files', LFiles);
    for LEntry in APatchResult.Preview.Entries do
      LFiles.Add(LEntry.Spec.TargetFile);
    LRoot.AddPair(
      'nextAction',
      'Review the preview, then use ApplyMultiFilePatch. ' +
      'Use RevertMultiFilePatch to roll back.'
    );
    Result := TRadIAToolResult.Succeeded(LRoot.ToJSON);
  finally
    LRoot.Free;
  end;
end;

function TRadIAPrepareMoveTypeTool.ValidateProjectGraph(
  const ASpecs: TArray<TRadIAMultiFilePatchSpec>;
  out AError: string
): Boolean;
var
  LCycle: string;
  LFileName: string;
  LProposals: TDictionary<string, string>;
  LSnapshot: TRadIAEditorContent;
  LSource: TRadIADelphiUnitSource;
  LSources: TList<TRadIADelphiUnitSource>;
  LSpec: TRadIAMultiFilePatchSpec;
begin
  Result := False;
  AError := '';
  LProposals := TDictionary<string, string>.Create;
  LSources := TList<TRadIADelphiUnitSource>.Create;
  try
    for LSpec in ASpecs do
      LProposals.AddOrSetValue(
        LowerCase(LSpec.TargetFile),
        LSpec.ProposedContent
      );
    for LFileName in FWorkspace.ListProjectUnits do
    begin
      if not SameText(ExtractFileExt(LFileName), '.pas') then
        Continue;
      LSnapshot := FMutation.ReadContent(LFileName, CMaxFileCharacters);
      if not IsCompleteSnapshot(LSnapshot) then
      begin
        AError := 'Move Type cannot validate the complete project dependency graph.';
        Exit;
      end;
      if LProposals.ContainsKey(LowerCase(LFileName)) then
        LSource := TRadIADelphiUnitSource.Create(
          LSnapshot.UnitName,
          LProposals[LowerCase(LFileName)]
        )
      else
        LSource := TRadIADelphiUnitSource.Create(
          LSnapshot.UnitName,
          LSnapshot.Content
        );
      LSources.Add(LSource);
    end;
    if not TRadIADelphiUnitDependencyGraph.TryValidateAcyclic(
      LSources.ToArray,
      LCycle
    ) then
    begin
      AError := 'Move Type would create an interface dependency cycle: ' +
        LCycle + '.';
      Exit;
    end;
    Result := True;
  finally
    LSources.Free;
    LProposals.Free;
  end;
end;

constructor TRadIAMoveTypeConsumerContext.Create(const ASourceContent: string);
begin
  inherited Create;
  FSnapshots := TDictionary<string, TRadIAEditorContent>.Create;
  FProposals := TDictionary<string, string>.Create;
  FSourceContent := ASourceContent;
end;

destructor TRadIAMoveTypeConsumerContext.Destroy;
begin
  FProposals.Free;
  FSnapshots.Free;
  inherited Destroy;
end;

procedure TRadIAPrepareMoveTypeTool.AppendConsumerSpecs(
  const ASnapshots: TDictionary<string, TRadIAEditorContent>;
  const AProposals: TDictionary<string, string>;
  const ASpecs: TList<TRadIAMultiFilePatchSpec>
);
var
  LPair: TPair<string, string>;
  LSnapshot: TRadIAEditorContent;
begin
  for LPair in AProposals do
  begin
    LSnapshot := ASnapshots[LPair.Key];
    ASpecs.Add(TRadIAMultiFilePatchSpec.Create(
      LSnapshot.FileName,
      LSnapshot.Revision,
      LPair.Value
    ));
  end;
end;

function TRadIAPrepareMoveTypeTool.ProcessReference(
  const AReference: TRadIASemanticReferenceLocation;
  const AComposition: TRadIAMoveTypeComposition;
  const AMovableType: TRadIADelphiMovableType;
  const AImplementations: TArray<TRadIADelphiMoveBlock>;
  const AContext: TRadIAMoveTypeConsumerContext;
  out AError: string
): Boolean;
var
  LContent: string;
  LKey: string;
  LSnapshot: TRadIAEditorContent;
begin
  Result := False;
  if not SameText(AReference.Kind, 'exact') then
  begin
    AError := 'Move Type found a candidate or ambiguous type reference.';
    Exit;
  end;
  if SameFileName(AReference.FileName, AComposition.Destination.FileName) or
    (SameFileName(AReference.FileName, AComposition.Source.FileName) and
      IsInsideMovedBlock(AReference.StartOffset, AMovableType, AImplementations)) then
    Exit(True);
  if SameFileName(AReference.FileName, AComposition.Source.FileName) then
  begin
    if InterfaceUsesUnit(
      AComposition.DestinationContent,
      AComposition.Source.UnitName
    ) then
    begin
      AError := 'Move Type would create an interface cycle between source and destination.';
      Exit;
    end;
    Result := TRadIADelphiTypeMoveEditor.TryEnsureUsesUnit(
      AContext.SourceContent,
      AComposition.Destination.UnitName,
      True,
      LContent,
      AError
    );
    if Result then
      AContext.SourceContent := LContent;
    Exit;
  end;
  LKey := LowerCase(AReference.FileName);
  if AContext.Snapshots.ContainsKey(LKey) then
    Exit(True);
  LSnapshot := FMutation.ReadContent(AReference.FileName, CMaxFileCharacters);
  if not IsProjectUnit(AReference.FileName, FWorkspace.ListProjectUnits) or
    not IsCompleteSnapshot(LSnapshot) then
  begin
    AError := 'A confirmed Move Type consumer is unavailable or incomplete.';
    Exit;
  end;
  if InterfaceUsesUnit(AComposition.DestinationContent, LSnapshot.UnitName) then
  begin
    AError := 'Move Type would create an interface cycle with a consumer unit.';
    Exit;
  end;
  if not TRadIADelphiTypeMoveEditor.TryEnsureUsesUnit(
    LSnapshot.Content,
    AComposition.Destination.UnitName,
    True,
    LContent,
    AError
  ) then
    Exit;
  AContext.Snapshots.Add(LKey, LSnapshot);
  AContext.Proposals.Add(LKey, LContent);
  Result := True;
end;

function TRadIAPrepareMoveTypeTool.BuildSpecs(
  const ARequest: TRadIAMoveTypeRequest;
  const ASymbol: TRadIASemanticLocation;
  const AComposition: TRadIAMoveTypeComposition;
  out ASpecs: TArray<TRadIAMultiFilePatchSpec>;
  out AError: string
): Boolean;
var
  LContext: TRadIAMoveTypeConsumerContext;
  LImplementations: TArray<TRadIADelphiMoveBlock>;
  LMovableType: TRadIADelphiMovableType;
  LReference: TRadIASemanticReferenceLocation;
  LReferences: TArray<TRadIASemanticReferenceLocation>;
  LSpecs: TList<TRadIAMultiFilePatchSpec>;
begin
  Result := False;
  ASpecs := nil;
  AError := '';
  if not FQueries.FindReferences(
    ASymbol.SymbolId,
    False,
    CReferenceLimit,
    LReferences,
    AError
  ) then
    Exit;
  if Length(LReferences) >= CReferenceLimit then
  begin
    AError := 'Move Type reference discovery reached its safety limit.';
    Exit;
  end;
  if not TRadIADelphiTypeMoveAnalyzer.TryAnalyze(
    AComposition.Source.Content,
    ARequest.SymbolName,
    ASymbol.StartOffset,
    LMovableType,
    AError
  ) or not TRadIADelphiTypeMoveAnalyzer.TryFindImplementations(
    AComposition.Source.Content,
    ARequest.SymbolName,
    LImplementations,
    AError
  ) then
    Exit;
  LContext := TRadIAMoveTypeConsumerContext.Create(AComposition.SourceContent);
  LSpecs := TList<TRadIAMultiFilePatchSpec>.Create;
  try
    for LReference in LReferences do
      if not ProcessReference(
        LReference,
        AComposition,
        LMovableType,
        LImplementations,
        LContext,
        AError
      ) then
        Exit;
    LSpecs.Add(TRadIAMultiFilePatchSpec.Create(
      AComposition.Source.FileName,
      AComposition.Source.Revision,
      LContext.SourceContent
    ));
    LSpecs.Add(TRadIAMultiFilePatchSpec.Create(
      AComposition.Destination.FileName,
      AComposition.Destination.Revision,
      AComposition.DestinationContent
    ));
    AppendConsumerSpecs(LContext.Snapshots, LContext.Proposals, LSpecs);
    ASpecs := LSpecs.ToArray;
    Result := True;
  finally
    LSpecs.Free;
    LContext.Free;
  end;
end;

function TRadIAPrepareMoveTypeTool.Execute(
  const ARequest: TRadIAToolRequest
): TRadIAToolResult;
var
  LComposition: TRadIAMoveTypeComposition;
  LError: string;
  LMoveRequest: TRadIAMoveTypeRequest;
  LPatchResult: TRadIAMultiFilePatchResult;
  LSpecs: TArray<TRadIAMultiFilePatchSpec>;
  LSymbol: TRadIASemanticLocation;
begin
  if not LoadRequest(ARequest.ArgumentsJson, LMoveRequest, LError) then
    Exit(TRadIAToolResult.Failed('invalid_request', LError));
  if not ResolveSymbol(LMoveRequest.SymbolName, LSymbol, LError) then
    Exit(TRadIAToolResult.Failed('type_resolution_failed', LError));
  if not BuildComposition(LMoveRequest, LSymbol, LComposition, LError) then
    Exit(TRadIAToolResult.Failed('move_type_precondition', LError));
  if not BuildSpecs(
    LMoveRequest,
    LSymbol,
    LComposition,
    LSpecs,
    LError
  ) then
    Exit(TRadIAToolResult.Failed('move_type_precondition', LError));
  if not ValidateProjectGraph(LSpecs, LError) then
    Exit(TRadIAToolResult.Failed('move_type_precondition', LError));
  LPatchResult := FPatches.Prepare(LSpecs);
  Result := BuildResult(LMoveRequest, LComposition, LPatchResult);
end;

function TRadIAPrepareMoveTypeTool.GetDescriptor: TRadIAToolDescriptor;
begin
  Result := TRadIAToolDescriptor.Create(
    'PrepareMoveType',
    '1.0.0',
    'Prepares a transactional Delphi type move between project units.',
    CInputSchema,
    COutputSchema,
    trReadOnly
  ).WithExecutionOptions(20000, True);
end;

procedure RegisterRadIASemanticMoveTypeTools(
  const ARegistry: IRadIAToolRegistry;
  const AWorkspace: IRadIAWorkspaceFacade;
  const AQueries: IRadIASemanticQueryService;
  const AMutation: IRadIAEditorMutationFacade;
  const APatches: IRadIAMultiFilePatchService
);
begin
  if not Assigned(ARegistry) then
    raise EArgumentNilException.Create('ARegistry');
  ARegistry.RegisterTool(TRadIAPrepareMoveTypeTool.Create(
    AWorkspace,
    AQueries,
    AMutation,
    APatches
  ));
end;

end.
