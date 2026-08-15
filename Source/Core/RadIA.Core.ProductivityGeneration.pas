unit RadIA.Core.ProductivityGeneration;

interface

uses
  RadIA.Core.GeneratedArtifacts,
  RadIA.Core.SemanticQueries,
  RadIA.Core.Workspace;

type
  IRadIAProductivityGenerationService = interface
    ['{9816DCB0-ECE0-42B0-9E13-AE835F90F912}']
    function PrepareApiDocumentation(
      const ARelativeFileName: string
    ): TRadIAGeneratedArtifactResult;
    function PrepareMockUnit(
      const AInterfaceName: string;
      const AUnitName: string;
      const ARelativeDirectory: string;
      const ARegisterInProject: Boolean
    ): TRadIAGeneratedArtifactResult;
  end;

  TRadIAProductivityGenerationService = class(
    TInterfacedObject,
    IRadIAProductivityGenerationService
  )
  private
    FArtifacts: IRadIAGeneratedArtifactService;
    FQueries: IRadIASemanticQueryService;
    FWorkspace: IRadIAWorkspaceFacade;
    function BuildApiMarkdown(
      const ASymbols: TArray<TRadIASemanticLocation>
    ): string;
    function BuildMockContent(
      const AInterface: TRadIASemanticLocation;
      const AMembers: TArray<TRadIASemanticLocation>;
      const AUnitName: string
    ): string;
    function FilterMockableMembers(
      const AMembers: TArray<TRadIASemanticLocation>
    ): TArray<TRadIASemanticLocation>;
    function MockClassName(const AInterfaceName: string): string;
    function QualifyImplementationSignature(
      const ASignature: string;
      const AClassName: string
    ): string;
    function ValidateUnitName(const AUnitName: string): Boolean;
  public
    constructor Create(
      const AWorkspace: IRadIAWorkspaceFacade;
      const AQueries: IRadIASemanticQueryService;
      const AArtifacts: IRadIAGeneratedArtifactService
    );
    function PrepareApiDocumentation(
      const ARelativeFileName: string
    ): TRadIAGeneratedArtifactResult;
    function PrepareMockUnit(
      const AInterfaceName: string;
      const AUnitName: string;
      const ARelativeDirectory: string;
      const ARegisterInProject: Boolean
    ): TRadIAGeneratedArtifactResult;
  end;

implementation

uses
  System.Character,
  System.Classes,
  System.Generics.Collections,
  System.IOUtils,
  System.SysUtils;

function TRadIAProductivityGenerationService.BuildApiMarkdown(
  const ASymbols: TArray<TRadIASemanticLocation>
): string;
var
  LCurrentFile: string;
  LProject: TRadIAProjectSnapshot;
  LStrings: TStringList;
  LSymbol: TRadIASemanticLocation;
begin
  LProject := FWorkspace.GetActiveProject;
  LStrings := TStringList.Create;
  try
    LStrings.LineBreak := sLineBreak;
    LStrings.Add('# ' + LProject.Name + ' API');
    LStrings.Add('');
    LStrings.Add('Generated from the indexed public Delphi API.');
    LStrings.Add('');
    LCurrentFile := '';
    for LSymbol in ASymbols do
    begin
      if not SameText(LCurrentFile, LSymbol.FileName) then
      begin
        LCurrentFile := LSymbol.FileName;
        LStrings.Add('## ' + TPath.GetFileName(LCurrentFile));
        LStrings.Add('');
      end;
      if LSymbol.Kind = 'module' then
        Continue;
      if LSymbol.ContainerName = '' then
        LStrings.Add('### ' + LSymbol.Name)
      else
        LStrings.Add('#### ' + LSymbol.ContainerName + '.' + LSymbol.Name);
      LStrings.Add('');
      LStrings.Add('- Kind: `' + LSymbol.Kind + '`');
      LStrings.Add('- Visibility: `' + LSymbol.Visibility + '`');
      if LSymbol.Signature <> '' then
      begin
        LStrings.Add('');
        LStrings.Add('```pascal');
        LStrings.Add(LSymbol.Signature);
        LStrings.Add('```');
      end;
      LStrings.Add('');
    end;
    Result := LStrings.Text;
  finally
    LStrings.Free;
  end;
end;

function TRadIAProductivityGenerationService.FilterMockableMembers(
  const AMembers: TArray<TRadIASemanticLocation>
): TArray<TRadIASemanticLocation>;
var
  LMember: TRadIASemanticLocation;
  LMembers: TList<TRadIASemanticLocation>;
  LSignature: string;
begin
  LMembers := TList<TRadIASemanticLocation>.Create;
  try
    for LMember in AMembers do
    begin
      LSignature := Trim(LMember.Signature);
      if not SameText(LMember.Kind, 'method') then
        Continue;
      if not (LSignature.StartsWith('procedure ', True) or
        LSignature.StartsWith('function ', True)) then
        Continue;
      LMembers.Add(LMember);
    end;
    Result := LMembers.ToArray;
  finally
    LMembers.Free;
  end;
end;

function TRadIAProductivityGenerationService.BuildMockContent(
  const AInterface: TRadIASemanticLocation;
  const AMembers: TArray<TRadIASemanticLocation>;
  const AUnitName: string
): string;
var
  LClassName: string;
  LMember: TRadIASemanticLocation;
  LStrings: TStringList;
  LUsesUnit: string;
begin
  LClassName := MockClassName(AInterface.Name);
  LUsesUnit := TPath.GetFileNameWithoutExtension(AInterface.FileName);
  LStrings := TStringList.Create;
  try
    LStrings.LineBreak := sLineBreak;
    LStrings.Add('unit ' + AUnitName + ';');
    LStrings.Add('');
    LStrings.Add('interface');
    LStrings.Add('');
    LStrings.Add('uses');
    LStrings.Add('  System.SysUtils,');
    LStrings.Add('  ' + LUsesUnit + ';');
    LStrings.Add('');
    LStrings.Add('type');
    LStrings.Add('  ' + LClassName + ' = class(TInterfacedObject, ' +
      AInterface.Name + ')');
    LStrings.Add('  public');
    for LMember in AMembers do
      LStrings.Add('    ' + LMember.Signature);
    LStrings.Add('  end;');
    LStrings.Add('');
    LStrings.Add('implementation');
    LStrings.Add('');
    for LMember in AMembers do
    begin
      LStrings.Add(QualifyImplementationSignature(
        LMember.Signature,
        LClassName
      ));
      LStrings.Add('begin');
      LStrings.Add(
        '  raise ENotImplemented.Create(''Not implemented by generated mock.'');'
      );
      LStrings.Add('end;');
      LStrings.Add('');
    end;
    LStrings.Add('end.');
    Result := LStrings.Text;
  finally
    LStrings.Free;
  end;
end;

constructor TRadIAProductivityGenerationService.Create(
  const AWorkspace: IRadIAWorkspaceFacade;
  const AQueries: IRadIASemanticQueryService;
  const AArtifacts: IRadIAGeneratedArtifactService
);
begin
  inherited Create;
  if not Assigned(AWorkspace) then
    raise EArgumentNilException.Create('AWorkspace');
  if not Assigned(AQueries) then
    raise EArgumentNilException.Create('AQueries');
  if not Assigned(AArtifacts) then
    raise EArgumentNilException.Create('AArtifacts');
  FWorkspace := AWorkspace;
  FQueries := AQueries;
  FArtifacts := AArtifacts;
end;

function TRadIAProductivityGenerationService.MockClassName(
  const AInterfaceName: string
): string;
begin
  if (Length(AInterfaceName) > 1) and
    (AInterfaceName[Low(AInterfaceName)] = 'I') then
    Result := 'TRadIAMock' + Copy(AInterfaceName, 2, MaxInt)
  else
    Result := 'TRadIAMock' + AInterfaceName;
end;

function TRadIAProductivityGenerationService.PrepareApiDocumentation(
  const ARelativeFileName: string
): TRadIAGeneratedArtifactResult;
var
  LError: string;
  LSymbols: TArray<TRadIASemanticLocation>;
begin
  if not FQueries.ListPublicApiSymbols(LSymbols, LError) then
    Exit(TRadIAGeneratedArtifactResult.Failed(
      'semantic_inventory_unavailable',
      LError
    ));
  if Length(LSymbols) = 0 then
    Exit(TRadIAGeneratedArtifactResult.Failed(
      'public_api_not_found',
      'No indexed public project API is available.'
    ));
  Result := FArtifacts.Prepare(
    ARelativeFileName,
    BuildApiMarkdown(LSymbols),
    False
  );
end;

function TRadIAProductivityGenerationService.PrepareMockUnit(
  const AInterfaceName: string;
  const AUnitName: string;
  const ARelativeDirectory: string;
  const ARegisterInProject: Boolean
): TRadIAGeneratedArtifactResult;
var
  LError: string;
  LInterface: TRadIASemanticLocation;
  LMembers: TArray<TRadIASemanticLocation>;
  LPath: string;
  LSymbol: TRadIASemanticLocation;
  LSymbols: TArray<TRadIASemanticLocation>;
begin
  if not ValidateUnitName(AUnitName) then
    Exit(TRadIAGeneratedArtifactResult.Failed(
      'invalid_unit_name',
      'Generated mock unit name must be a valid Pascal unit name.'
    ));
  if not FQueries.FindSymbols(AInterfaceName, LSymbols, LError) then
    Exit(TRadIAGeneratedArtifactResult.Failed(
      'semantic_inventory_unavailable',
      LError
    ));
  LInterface := Default(TRadIASemanticLocation);
  for LSymbol in LSymbols do
    if SameText(LSymbol.Name, AInterfaceName) and
      SameText(LSymbol.Kind, 'interface') then
    begin
      LInterface := LSymbol;
      Break;
    end;
  if LInterface.Name = '' then
    Exit(TRadIAGeneratedArtifactResult.Failed(
      'unsupported_contract',
      'The selected symbol is not an indexed Delphi interface.'
    ));
  if not FQueries.FindResolvedMembers(
    AInterfaceName,
    LMembers,
    LError
  ) then
    Exit(TRadIAGeneratedArtifactResult.Failed(
      'semantic_inventory_unavailable',
      LError
    ));
  LMembers := FilterMockableMembers(LMembers);
  if Length(LMembers) = 0 then
    Exit(TRadIAGeneratedArtifactResult.Failed(
      'unsupported_contract',
      'The selected interface has no mockable methods.'
    ));
  LPath := TPath.Combine(ARelativeDirectory, AUnitName + '.pas');
  Result := FArtifacts.Prepare(
    LPath,
    BuildMockContent(LInterface, LMembers, AUnitName),
    ARegisterInProject
  );
end;

function TRadIAProductivityGenerationService.QualifyImplementationSignature(
  const ASignature: string;
  const AClassName: string
): string;
var
  LNamePosition: Integer;
  LPrefixLength: Integer;
  LSignature: string;
begin
  LSignature := Trim(ASignature);
  if LSignature.StartsWith('procedure ', True) then
    LPrefixLength := Length('procedure ')
  else if LSignature.StartsWith('function ', True) then
    LPrefixLength := Length('function ')
  else
    Exit(LSignature);
  LNamePosition := LPrefixLength + 1;
  Result := Copy(LSignature, 1, LPrefixLength) + AClassName + '.' +
    Copy(LSignature, LNamePosition, MaxInt);
end;

function TRadIAProductivityGenerationService.ValidateUnitName(
  const AUnitName: string
): Boolean;
var
  LCharacter: Char;
  LIndex: Integer;
begin
  Result := (AUnitName <> '') and (Length(AUnitName) <= 128) and
    (AUnitName[Low(AUnitName)].IsLetter or
    (AUnitName[Low(AUnitName)] = '_'));
  if not Result then
    Exit;
  if AUnitName.EndsWith('.') or AUnitName.Contains('..') then
    Exit(False);
  for LIndex := Low(AUnitName) to High(AUnitName) do
  begin
    LCharacter := AUnitName[LIndex];
    if not (LCharacter.IsLetterOrDigit or CharInSet(LCharacter, ['_', '.'])) then
      Exit(False);
  end;
end;

end.
