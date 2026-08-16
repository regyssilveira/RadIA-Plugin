unit RadIA.Core.DelphiEcosystemTools;

interface

uses
  RadIA.Core.Patches,
  RadIA.Core.Tools,
  RadIA.Core.Workspace,
  RadIA.Core.WorkspaceBoundary;

procedure RegisterRadIADelphiEcosystemTools(
  const ARegistry: IRadIAToolRegistry;
  const AWorkspace: IRadIAWorkspaceFacade;
  const APatches: IRadIAPatchService;
  const ABoundary: IRadIAWorkspaceBoundary
);

implementation

uses
  System.Generics.Collections,
  System.IOUtils,
  System.JSON,
  System.RegularExpressions,
  System.StrUtils,
  System.SysUtils,
  RadIA.Core.FireDAC.Model,
  RadIA.Core.FireDAC.Scanner;

const
  CEmptyInputSchema = '{"type":"object","additionalProperties":false}';
  CMaximumFiles = 2000;

type
  TRadIADelphiEcosystemToolKind = (
    detFireDAC,
    detFireDACProject,
    detFireDACTransactions,
    detFireDACConfiguration,
    detFireDACThreadSafety,
    detDependencies,
    detLocalization
  );

  TRadIADelphiEcosystemTool = class(TInterfacedObject, IRadIATool)
  private
    FKind: TRadIADelphiEcosystemToolKind;
    FWorkspace: IRadIAWorkspaceFacade;
    FBoundary: IRadIAWorkspaceBoundary;
    procedure AddFinding(
      const AFindings: TJSONArray;
      const AFileName: string;
      const AKind: string;
      const AMessage: string;
      const ALine: Integer = 0
    );
    procedure AnalyzeDependencies(
      const ARootPath: string;
      const AFiles: TArray<string>;
      const ARoot: TJSONObject;
      const AFindings: TJSONArray
    );
    procedure AnalyzeDependencyPath(
      const ARootPath: string;
      const AProjectFile: string;
      const AEntry: string;
      const AFindings: TJSONArray;
      var APathCount: Integer;
      var AMissingCount: Integer
    );
    procedure AnalyzeProjectDependencyPaths(
      const ARootPath: string;
      const AProjectFile: string;
      const AFindings: TJSONArray;
      var APathCount: Integer;
      var AMissingCount: Integer
    );
    procedure AnalyzeLocalization(
      const ARootPath: string;
      const AFiles: TArray<string>;
      const ARoot: TJSONObject;
      const AFindings: TJSONArray
    );
    function CollectFiles(const ARootPath: string): TArray<string>;
    function ExecuteFireDAC(const AProject: TRadIAProjectSnapshot): TRadIAToolResult;
    function RelativeName(const ARootPath, AFileName: string): string;
  public
    constructor Create(
      const AWorkspace: IRadIAWorkspaceFacade;
      const ABoundary: IRadIAWorkspaceBoundary;
      const AKind: TRadIADelphiEcosystemToolKind
    );
    function Execute(const ARequest: TRadIAToolRequest): TRadIAToolResult;
    function GetDescriptor: TRadIAToolDescriptor;
  end;

  TRadIAPrepareLocalizationExtractionTool = class(TInterfacedObject, IRadIATool)
  private
    FPatches: IRadIAPatchService;
    FWorkspace: IRadIAWorkspaceFacade;
  public
    constructor Create(
      const AWorkspace: IRadIAWorkspaceFacade;
      const APatches: IRadIAPatchService
    );
    function Execute(const ARequest: TRadIAToolRequest): TRadIAToolResult;
    function GetDescriptor: TRadIAToolDescriptor;
  end;

constructor TRadIADelphiEcosystemTool.Create(
  const AWorkspace: IRadIAWorkspaceFacade;
  const ABoundary: IRadIAWorkspaceBoundary;
  const AKind: TRadIADelphiEcosystemToolKind
);
begin
  inherited Create;
  if not Assigned(AWorkspace) then
    raise EArgumentNilException.Create('AWorkspace');
  if not Assigned(ABoundary) then
    raise EArgumentNilException.Create('ABoundary');
  FWorkspace := AWorkspace;
  FBoundary := ABoundary;
  FKind := AKind;
end;

function TRadIADelphiEcosystemTool.RelativeName(
  const ARootPath: string;
  const AFileName: string
): string;
begin
  Result := AFileName;
  if AFileName.StartsWith(IncludeTrailingPathDelimiter(ARootPath), True) then
    Result := AFileName.Substring(IncludeTrailingPathDelimiter(ARootPath).Length);
end;

procedure TRadIADelphiEcosystemTool.AddFinding(
  const AFindings: TJSONArray;
  const AFileName: string;
  const AKind: string;
  const AMessage: string;
  const ALine: Integer
);
var
  LFinding: TJSONObject;
begin
  LFinding := TJSONObject.Create;
  LFinding.AddPair('file', AFileName);
  LFinding.AddPair('kind', AKind);
  LFinding.AddPair('message', AMessage);
  if ALine > 0 then
    LFinding.AddPair('line', TJSONNumber.Create(ALine));
  AFindings.AddElement(LFinding);
end;

function TRadIADelphiEcosystemTool.CollectFiles(
  const ARootPath: string
): TArray<string>;
var
  LAllFiles: TArray<string>;
  LFile: string;
  LFiles: TList<string>;
  LExtension: string;
begin
  LFiles := TList<string>.Create;
  try
    LAllFiles := TDirectory.GetFiles(ARootPath, '*', TSearchOption.soAllDirectories);
    for LFile in LAllFiles do
    begin
      LExtension := TPath.GetExtension(LFile).ToLower;
      if MatchText(LExtension, ['.pas', '.dfm', '.dproj', '.json']) then
        LFiles.Add(LFile);
      if LFiles.Count >= CMaximumFiles then
        Break;
    end;
    Result := LFiles.ToArray;
  finally
    LFiles.Free;
  end;
end;

procedure TRadIADelphiEcosystemTool.AnalyzeDependencies(
  const ARootPath: string;
  const AFiles: TArray<string>;
  const ARoot: TJSONObject;
  const AFindings: TJSONArray
);
var
  LFile: string;
  LMissingCount: Integer;
  LPathCount: Integer;
begin
  LMissingCount := 0;
  LPathCount := 0;
  for LFile in AFiles do
  begin
    if SameText(TPath.GetFileName(LFile), 'boss.json') then
      AddFinding(AFindings, RelativeName(ARootPath, LFile), 'boss', 'Boss dependency manifest detected.');
    if SameText(TPath.GetExtension(LFile), '.dproj') then
      AnalyzeProjectDependencyPaths(
        ARootPath,
        LFile,
        AFindings,
        LPathCount,
        LMissingCount
      );
  end;
  ARoot.AddPair('declaredPathCount', TJSONNumber.Create(LPathCount));
  ARoot.AddPair('missingPathCount', TJSONNumber.Create(LMissingCount));
  ARoot.AddPair('nextAction', 'Review missing paths before installing or changing dependencies.');
end;

procedure TRadIADelphiEcosystemTool.AnalyzeDependencyPath(
  const ARootPath: string;
  const AProjectFile: string;
  const AEntry: string;
  const AFindings: TJSONArray;
  var APathCount: Integer;
  var AMissingCount: Integer
);
var
  LPath: string;
begin
  LPath := AEntry.Trim;
  if LPath.IsEmpty then
    Exit;
  Inc(APathCount);
  if LPath.Contains('$(') then
    Exit;
  if not TPath.IsPathRooted(LPath) then
    LPath := TPath.Combine(ARootPath, LPath);
  if TDirectory.Exists(TPath.GetFullPath(LPath)) then
    Exit;
  Inc(AMissingCount);
  AddFinding(
    AFindings,
    RelativeName(ARootPath, AProjectFile),
    'missing-path',
    'Project search path does not exist: ' + AEntry.Trim
  );
end;

procedure TRadIADelphiEcosystemTool.AnalyzeProjectDependencyPaths(
  const ARootPath: string;
  const AProjectFile: string;
  const AFindings: TJSONArray;
  var APathCount: Integer;
  var AMissingCount: Integer
);
var
  LContent: string;
  LEntry: string;
  LMatch: TMatch;
begin
  LContent := TFile.ReadAllText(AProjectFile);
  LMatch := TRegEx.Match(
    LContent,
    '(?is)<DCC_(?:UnitSearchPath|IncludePath|ResourcePath)>(.*?)</DCC_[^>]+>'
  );
  while LMatch.Success do
  begin
    for LEntry in LMatch.Groups[1].Value.Split([';']) do
      AnalyzeDependencyPath(
        ARootPath,
        AProjectFile,
        LEntry,
        AFindings,
        APathCount,
        AMissingCount
      );
    LMatch := LMatch.NextMatch;
  end;
end;

procedure TRadIADelphiEcosystemTool.AnalyzeLocalization(
  const ARootPath: string;
  const AFiles: TArray<string>;
  const ARoot: TJSONObject;
  const AFindings: TJSONArray
);
var
  LCandidateCount: Integer;
  LContent: string;
  LFile: string;
  LLine: string;
  LLineNumber: Integer;
  LResourceStringCount: Integer;
begin
  LCandidateCount := 0;
  LResourceStringCount := 0;
  for LFile in AFiles do
  begin
    if not MatchText(TPath.GetExtension(LFile), ['.pas', '.dfm']) then
      Continue;
    LContent := TFile.ReadAllText(LFile);
    Inc(LResourceStringCount, TRegEx.Matches(LContent, '(?im)^\s*resourcestring\b').Count);
    LLineNumber := 0;
    for LLine in LContent.Split([sLineBreak]) do
    begin
      Inc(LLineNumber);
      if TRegEx.IsMatch(
        LLine,
        '(?i)(?:Caption|Hint|Text)\s*=\s*''[^'']+''|(?:ShowMessage|MessageDlg)\s*\(\s*''[^'']+'''
      ) then
      begin
        Inc(LCandidateCount);
        if AFindings.Count < 200 then
          AddFinding(
            AFindings,
            RelativeName(ARootPath, LFile),
            'literal-text',
            'User-visible literal can be reviewed for resourcestring extraction.',
            LLineNumber
          );
      end;
    end;
  end;
  ARoot.AddPair('candidateCount', TJSONNumber.Create(LCandidateCount));
  ARoot.AddPair('resourcestringSectionCount', TJSONNumber.Create(LResourceStringCount));
  ARoot.AddPair('findingLimit', TJSONNumber.Create(200));
  ARoot.AddPair('nextAction', 'Review candidates before preparing a transactional extraction.');
end;

function TRadIADelphiEcosystemTool.ExecuteFireDAC(
  const AProject: TRadIAProjectSnapshot
): TRadIAToolResult;
var
  LInventory: TRadIAFireDACInventory;
  LRoot: TJSONObject;
  LScanner: TRadIAFireDACScanner;
begin
  LScanner := TRadIAFireDACScanner.Create(FBoundary);
  try
    if FKind = detFireDACTransactions then
      Exit(TRadIAToolResult.Succeeded(LScanner.AuditTransactions(AProject.RootPath)));
    if FKind = detFireDACConfiguration then
      Exit(TRadIAToolResult.Succeeded(LScanner.InspectConfiguration(AProject.RootPath)));
    if FKind = detFireDACThreadSafety then
      Exit(TRadIAToolResult.Succeeded(LScanner.AnalyzeThreadSafety(AProject.RootPath)));
    LInventory := LScanner.Scan(AProject.RootPath);
    try
      LRoot := TJSONObject.ParseJSONValue(LInventory.ToJson) as TJSONObject;
      if not Assigned(LRoot) then
        Exit(TRadIAToolResult.Failed(
          'inventory_serialization_failed',
          'The FireDAC inventory could not be serialized.'
        ));
      try
        LRoot.AddPair('project', AProject.Name);
        LRoot.AddPair('root', AProject.RootPath);
        Result := TRadIAToolResult.Succeeded(LRoot.ToJSON);
      finally
        LRoot.Free;
      end;
    finally
      LInventory.Free;
    end;
  finally
    LScanner.Free;
  end;
end;

function TRadIADelphiEcosystemTool.Execute(
  const ARequest: TRadIAToolRequest
): TRadIAToolResult;
var
  LFiles: TArray<string>;
  LFindings: TJSONArray;
  LProject: TRadIAProjectSnapshot;
  LRoot: TJSONObject;
begin
  LProject := FWorkspace.GetActiveProject;
  if LProject.RootPath.Trim.IsEmpty or not TDirectory.Exists(LProject.RootPath) then
    Exit(TRadIAToolResult.Failed(
      'project_root_unavailable',
      'No active project root is available.'
    ));
  if FKind in [
    detFireDAC,
    detFireDACProject,
    detFireDACTransactions,
    detFireDACConfiguration,
    detFireDACThreadSafety
  ] then
    Exit(ExecuteFireDAC(LProject));
  LFiles := CollectFiles(LProject.RootPath);
  LRoot := TJSONObject.Create;
  try
    LFindings := TJSONArray.Create;
    LRoot.AddPair('findings', LFindings);
    LRoot.AddPair('project', LProject.Name);
    LRoot.AddPair('root', LProject.RootPath);
    LRoot.AddPair('scannedFileCount', TJSONNumber.Create(Length(LFiles)));
    LRoot.AddPair('truncated', TJSONBool.Create(Length(LFiles) >= CMaximumFiles));
    case FKind of
      detDependencies:
        AnalyzeDependencies(LProject.RootPath, LFiles, LRoot, LFindings);
      detLocalization:
        AnalyzeLocalization(LProject.RootPath, LFiles, LRoot, LFindings);
    end;
    Result := TRadIAToolResult.Succeeded(LRoot.ToJSON);
  finally
    LRoot.Free;
  end;
end;

function TRadIADelphiEcosystemTool.GetDescriptor: TRadIAToolDescriptor;
begin
  case FKind of
    detFireDAC:
      Result := TRadIAToolDescriptor.Create(
        'InspectFireDACUsage',
        '2.0.0',
        'Returns the structured FireDAC project inventory while preserving legacy usage counters.',
        CEmptyInputSchema,
        '{"type":"object"}',
        trReadOnly
      );
    detFireDACProject:
      Result := TRadIAToolDescriptor.Create(
        'InspectFireDACProject',
        '1.0.0',
        'Inventories FireDAC components and relationships in bounded PAS and DFM files without executing SQL.',
        CEmptyInputSchema,
        '{"type":"object"}',
        trReadOnly
      );
    detFireDACTransactions:
      Result := TRadIAToolDescriptor.Create(
        'AuditFireDACTransactions',
        '1.0.0',
        'Audits bounded Pascal transaction flows without executing SQL or connecting to a database.',
        CEmptyInputSchema,
        '{"type":"object"}',
        trReadOnly
      );
    detFireDACConfiguration:
      Result := TRadIAToolDescriptor.Create(
        'InspectFireDACConfiguration',
        '1.0.0',
        'Inspects bounded FireDAC configuration while discarding credentials and absolute paths.',
        CEmptyInputSchema,
        '{"type":"object"}',
        trReadOnly
      );
    detFireDACThreadSafety:
      Result := TRadIAToolDescriptor.Create(
        'AnalyzeFireDACThreadSafety',
        '1.0.0',
        'Finds shared FireDAC components and unsafe UI access in bounded background contexts.',
        CEmptyInputSchema,
        '{"type":"object"}',
        trReadOnly
      );
    detDependencies:
      Result := TRadIAToolDescriptor.Create(
        'DiagnoseDelphiDependencies',
        '1.0.0',
        'Diagnoses Delphi project search paths and dependency manifests without installing anything.',
        CEmptyInputSchema,
        '{"type":"object"}',
        trReadOnly
      );
  else
    Result := TRadIAToolDescriptor.Create(
      'AuditDelphiLocalization',
      '1.0.0',
      'Inventories user-visible Pascal and DFM literals for localization review.',
      CEmptyInputSchema,
      '{"type":"object"}',
      trReadOnly
    );
  end;
end;

constructor TRadIAPrepareLocalizationExtractionTool.Create(
  const AWorkspace: IRadIAWorkspaceFacade;
  const APatches: IRadIAPatchService
);
begin
  inherited Create;
  if not Assigned(AWorkspace) then
    raise EArgumentNilException.Create('AWorkspace');
  if not Assigned(APatches) then
    raise EArgumentNilException.Create('APatches');
  FWorkspace := AWorkspace;
  FPatches := APatches;
end;

function TRadIAPrepareLocalizationExtractionTool.Execute(
  const ARequest: TRadIAToolRequest
): TRadIAToolResult;
var
  LContent: TRadIAEditorContent;
  LImplementationIndex: Integer;
  LInput: TJSONObject;
  LLiteral: string;
  LOriginalToken: string;
  LPatch: TRadIAPatchResult;
  LProposedContent: string;
  LResourceName: string;
  LRoot: TJSONObject;
begin
  LInput := TJSONObject.ParseJSONValue(ARequest.ArgumentsJson) as TJSONObject;
  if not Assigned(LInput) then
    Exit(TRadIAToolResult.Failed('invalid_arguments', 'Arguments must be a JSON object.'));
  try
    LLiteral := LInput.GetValue<string>('literal', '').Trim;
    LResourceName := LInput.GetValue<string>('resourceName', '').Trim;
    if LLiteral.IsEmpty or not TRegEx.IsMatch(LResourceName, '^S[A-Za-z][A-Za-z0-9_]*$') then
      Exit(TRadIAToolResult.Failed(
        'invalid_arguments',
        'literal and a resourceName starting with S are required.'
      ));
    LContent := FWorkspace.GetEditorContent(2 * 1024 * 1024);
    if LContent.Truncated or LContent.FileName.IsEmpty then
      Exit(TRadIAToolResult.Failed(
        'editor_content_unavailable',
        'Open a complete Pascal unit in the editor before preparing extraction.'
      ));
    LOriginalToken := QuotedStr(LLiteral);
    if Pos(LOriginalToken, LContent.Content) = 0 then
      Exit(TRadIAToolResult.Failed('literal_not_found', 'The exact literal was not found in the active unit.'));
    LImplementationIndex := Pos('implementation', LContent.Content.ToLower);
    if LImplementationIndex = 0 then
      Exit(TRadIAToolResult.Failed('implementation_not_found', 'The active file is not a supported Pascal unit.'));
    LProposedContent := LContent.Content;
    Delete(LProposedContent, Pos(LOriginalToken, LProposedContent), LOriginalToken.Length);
    Insert(LResourceName, LProposedContent, Pos(LOriginalToken, LContent.Content));
    Insert(
      sLineBreak + sLineBreak + 'resourcestring' + sLineBreak +
      '  ' + LResourceName + ' = ' + LOriginalToken + ';',
      LProposedContent,
      LImplementationIndex + Length('implementation')
    );
    LPatch := FPatches.Prepare(TRadIAPatchSpec.Create(
      LContent.FileName,
      LContent.Revision,
      LContent.Content,
      LProposedContent
    ));
    if not LPatch.Success then
      Exit(TRadIAToolResult.Failed(LPatch.ErrorCode, LPatch.ErrorMessage));
    LRoot := TJSONObject.Create;
    try
      LRoot.AddPair('previewId', LPatch.Preview.Id);
      LRoot.AddPair('file', LContent.FileName);
      LRoot.AddPair('resourceName', LResourceName);
      LRoot.AddPair('mutationApplied', TJSONBool.Create(False));
      LRoot.AddPair('nextAction', 'Review the preview, then use ApplyPatch with explicit consent.');
      Result := TRadIAToolResult.Succeeded(LRoot.ToJSON);
    finally
      LRoot.Free;
    end;
  finally
    LInput.Free;
  end;
end;

function TRadIAPrepareLocalizationExtractionTool.GetDescriptor: TRadIAToolDescriptor;
const
  CInputSchema =
    '{"type":"object","additionalProperties":false,' +
    '"required":["literal","resourceName"],"properties":{' +
    '"literal":{"type":"string","minLength":1},' +
    '"resourceName":{"type":"string","pattern":"^S[A-Za-z][A-Za-z0-9_]*$"}}}';
begin
  Result := TRadIAToolDescriptor.Create(
    'PrepareLocalizationExtraction',
    '1.0.0',
    'Prepares an immutable patch that moves one active-unit literal to resourcestring.',
    CInputSchema,
    '{"type":"object"}',
    trReadOnly
  );
end;

procedure RegisterRadIADelphiEcosystemTools(
  const ARegistry: IRadIAToolRegistry;
  const AWorkspace: IRadIAWorkspaceFacade;
  const APatches: IRadIAPatchService;
  const ABoundary: IRadIAWorkspaceBoundary
);
begin
  if not Assigned(ARegistry) then
    raise EArgumentNilException.Create('ARegistry');
  ARegistry.RegisterTool(TRadIADelphiEcosystemTool.Create(AWorkspace, ABoundary, detFireDAC));
  ARegistry.RegisterTool(TRadIADelphiEcosystemTool.Create(AWorkspace, ABoundary, detFireDACProject));
  ARegistry.RegisterTool(TRadIADelphiEcosystemTool.Create(
    AWorkspace,
    ABoundary,
    detFireDACTransactions
  ));
  ARegistry.RegisterTool(TRadIADelphiEcosystemTool.Create(
    AWorkspace,
    ABoundary,
    detFireDACConfiguration
  ));
  ARegistry.RegisterTool(TRadIADelphiEcosystemTool.Create(
    AWorkspace,
    ABoundary,
    detFireDACThreadSafety
  ));
  ARegistry.RegisterTool(TRadIADelphiEcosystemTool.Create(AWorkspace, ABoundary, detDependencies));
  ARegistry.RegisterTool(TRadIADelphiEcosystemTool.Create(AWorkspace, ABoundary, detLocalization));
  ARegistry.RegisterTool(TRadIAPrepareLocalizationExtractionTool.Create(AWorkspace, APatches));
end;

end.
