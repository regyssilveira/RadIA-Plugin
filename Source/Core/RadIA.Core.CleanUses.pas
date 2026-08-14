unit RadIA.Core.CleanUses;

interface

uses
  RadIA.Core.Patches,
  RadIA.Core.SemanticQueries,
  RadIA.Core.Workspace,
  System.Generics.Collections;

type
  TRadIACleanUsesResult = record
  private
    FCandidates: TArray<string>;
    FErrorCode: string;
    FErrorMessage: string;
    FPatch: TRadIAPatchResult;
    FSuccess: Boolean;
  public
    class function Failed(
      const ACode: string;
      const AMessage: string
    ): TRadIACleanUsesResult; static;
    class function Succeeded(
      const ACandidates: TArray<string>;
      const APatch: TRadIAPatchResult
    ): TRadIACleanUsesResult; static;
    property Candidates: TArray<string> read FCandidates;
    property ErrorCode: string read FErrorCode;
    property ErrorMessage: string read FErrorMessage;
    property Patch: TRadIAPatchResult read FPatch;
    property Success: Boolean read FSuccess;
  end;

  IRadIACleanUsesService = interface
    ['{D164F210-E2B7-4E4E-8CB6-C705529E7B50}']
    function Prepare: TRadIACleanUsesResult;
  end;

  TRadIACleanUsesService = class(TInterfacedObject, IRadIACleanUsesService)
  private
    FPatchService: IRadIAPatchService;
    FQueries: IRadIASemanticQueryService;
    FWorkspace: IRadIAWorkspaceFacade;
    function BuildProposedContent(
      const AContent: string;
      const ASymbols: TArray<TRadIASemanticLocation>;
      out ACandidates: TArray<string>
    ): string;
    function BuildCleanClause(
      const AClauseText: string;
      const ABody: string;
      const ADeclarations: TDictionary<string, Boolean>;
      const ACandidates: TList<string>
    ): string;
    function HasInitialization(const AUnitName: string): Boolean;
    function IsUnitUsed(
      const ABody: string;
      const AUnitName: string;
      const ADeclarations: TDictionary<string, Boolean>
    ): Boolean;
  public
    constructor Create(
      const AWorkspace: IRadIAWorkspaceFacade;
      const AQueries: IRadIASemanticQueryService;
      const APatchService: IRadIAPatchService
    );
    function Prepare: TRadIACleanUsesResult;
  end;

implementation

uses
  System.IOUtils,
  System.RegularExpressions,
  System.SysUtils;

class function TRadIACleanUsesResult.Failed(
  const ACode: string;
  const AMessage: string
): TRadIACleanUsesResult;
begin
  Result.FSuccess := False;
  Result.FErrorCode := ACode;
  Result.FErrorMessage := AMessage;
end;

class function TRadIACleanUsesResult.Succeeded(
  const ACandidates: TArray<string>;
  const APatch: TRadIAPatchResult
): TRadIACleanUsesResult;
begin
  Result.FSuccess := True;
  Result.FCandidates := Copy(ACandidates);
  Result.FPatch := APatch;
end;

constructor TRadIACleanUsesService.Create(
  const AWorkspace: IRadIAWorkspaceFacade;
  const AQueries: IRadIASemanticQueryService;
  const APatchService: IRadIAPatchService
);
begin
  inherited Create;
  if not Assigned(AWorkspace) then
    raise EArgumentNilException.Create('AWorkspace');
  if not Assigned(AQueries) then
    raise EArgumentNilException.Create('AQueries');
  if not Assigned(APatchService) then
    raise EArgumentNilException.Create('APatchService');
  FWorkspace := AWorkspace;
  FQueries := AQueries;
  FPatchService := APatchService;
end;

function TRadIACleanUsesService.BuildProposedContent(
  const AContent: string;
  const ASymbols: TArray<TRadIASemanticLocation>;
  out ACandidates: TArray<string>
): string;
var
  LCandidates: TList<string>;
  LBody: string;
  LClause: TMatch;
  LClauseText: string;
  LDeclarations: TDictionary<string, Boolean>;
  LIndex: Integer;
  LNewClause: string;
  LSymbol: TRadIASemanticLocation;
  LUnitFile: string;
begin
  Result := AContent;
  LCandidates := TList<string>.Create;
  LDeclarations := TDictionary<string, Boolean>.Create;
  try
    LBody := TRegEx.Replace(AContent, '\buses\s+([^;]+);', '', [roIgnoreCase]);
    for LSymbol in ASymbols do
    begin
      LUnitFile := LowerCase(TPath.GetFileNameWithoutExtension(LSymbol.FileName));
      LDeclarations.AddOrSetValue(LUnitFile + '|' + LowerCase(LSymbol.Name), True);
    end;
    for LIndex := TRegEx.Matches(Result, '\buses\s+([^;]+);', [roIgnoreCase]).Count - 1 downto 0 do
    begin
      LClause := TRegEx.Matches(Result, '\buses\s+([^;]+);', [roIgnoreCase])[LIndex];
      LClauseText := LClause.Groups[1].Value;
      if LClauseText.Contains('{$') or
        TRegEx.IsMatch(LClauseText, '\bin\s+', [roIgnoreCase]) then
        Continue;
      LNewClause := BuildCleanClause(
        LClauseText,
        LBody,
        LDeclarations,
        LCandidates
      );
      if LNewClause <> '' then
        Result := Result.Remove(LClause.Index, LClause.Length).Insert(
          LClause.Index,
          LNewClause
        );
    end;
    ACandidates := LCandidates.ToArray;
  finally
    LDeclarations.Free;
    LCandidates.Free;
  end;
end;

function TRadIACleanUsesService.BuildCleanClause(
  const AClauseText: string;
  const ABody: string;
  const ADeclarations: TDictionary<string, Boolean>;
  const ACandidates: TList<string>
): string;
var
  LItem: TMatch;
  LKept: TList<string>;
  LName: string;
begin
  Result := '';
  LKept := TList<string>.Create;
  try
    for LItem in TRegEx.Matches(AClauseText, '[A-Za-z_][A-Za-z0-9_.]*') do
    begin
      LName := LItem.Value;
      if SameText(LName, 'in') or LName.EndsWith('.pas', True) then
        Continue;
      if IsUnitUsed(ABody, LName, ADeclarations) then
        LKept.Add(LName)
      else
        ACandidates.Add(LName);
    end;
    if LKept.Count > 0 then
      Result := 'uses' + sLineBreak + '  ' + string.Join(
        ',' + sLineBreak + '  ',
        LKept.ToArray
      ) + ';';
  finally
    LKept.Free;
  end;
end;

function TRadIACleanUsesService.IsUnitUsed(
  const ABody: string;
  const AUnitName: string;
  const ADeclarations: TDictionary<string, Boolean>
): Boolean;
var
  LIdentifier: TMatch;
begin
  if TRegEx.IsMatch(
    ABody,
    '\b' + TRegEx.Escape(AUnitName) + '\s*\.',
    [roIgnoreCase]
  ) or HasInitialization(AUnitName) then
    Exit(True);
  for LIdentifier in TRegEx.Matches(ABody, '\b[A-Za-z_][A-Za-z0-9_]*\b') do
    if ADeclarations.ContainsKey(
      LowerCase(AUnitName) + '|' + LowerCase(LIdentifier.Value)
    ) then
      Exit(True);
  Result := False;
end;

function TRadIACleanUsesService.HasInitialization(const AUnitName: string): Boolean;
var
  LContent: string;
  LFileName: string;
begin
  Result := True;
  for LFileName in FWorkspace.ListProjectUnits do
    if SameText(TPath.GetFileNameWithoutExtension(LFileName), AUnitName) then
    begin
      if not TFile.Exists(LFileName) then
        Exit;
      LContent := TFile.ReadAllText(LFileName);
      Exit(TRegEx.IsMatch(LContent, '\b(initialization|finalization)\b', [roIgnoreCase]));
    end;
end;

function TRadIACleanUsesService.Prepare: TRadIACleanUsesResult;
var
  LCandidates: TArray<string>;
  LError: string;
  LPatch: TRadIAPatchResult;
  LProposed: string;
  LSnapshot: TRadIAEditorContent;
  LSymbols: TArray<TRadIASemanticLocation>;
begin
  LSnapshot := FWorkspace.GetEditorContent(2 * 1024 * 1024);
  if not LSnapshot.FileName.EndsWith('.pas', True) then
    Exit(TRadIACleanUsesResult.Failed('unsupported_file', 'The active editor is not a Pascal unit.'));
  if not FQueries.ListPublicApiSymbols(LSymbols, LError) then
    Exit(TRadIACleanUsesResult.Failed('semantic_inventory_unavailable', LError));
  LProposed := BuildProposedContent(LSnapshot.Content, LSymbols, LCandidates);
  if Length(LCandidates) = 0 then
    Exit(TRadIACleanUsesResult.Failed('no_safe_candidates', 'No safely removable uses were found.'));
  LPatch := FPatchService.Prepare(TRadIAPatchSpec.Create(
    LSnapshot.FileName,
    LSnapshot.Revision,
    LSnapshot.Content,
    LProposed
  ));
  if not LPatch.Success then
    Exit(TRadIACleanUsesResult.Failed(LPatch.ErrorCode, LPatch.ErrorMessage));
  Result := TRadIACleanUsesResult.Succeeded(LCandidates, LPatch);
end;

end.
