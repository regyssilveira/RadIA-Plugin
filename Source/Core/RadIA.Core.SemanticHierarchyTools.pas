unit RadIA.Core.SemanticHierarchyTools;

interface

uses
  RadIA.Core.SemanticQueries,
  RadIA.Core.Tools;

procedure RegisterRadIASemanticHierarchyTools(
  const ARegistry: IRadIAToolRegistry;
  const AService: IRadIASemanticHierarchyService
);

implementation

uses
  System.Generics.Collections,
  System.JSON,
  System.SysUtils;

type
  TRadIAGetTypeHierarchyTool = class(TInterfacedObject, IRadIATool)
  private
    FService: IRadIASemanticHierarchyService;
    function BuildNode(
      const ASymbol: TRadIASemanticLocation;
      const ARelation: string;
      const ADepth: Integer
    ): TJSONObject;
    function BuildExternalNode(
      const AName: string;
      const ADepth: Integer
    ): TJSONObject;
    function CollectAncestors(
      const ASymbol: TRadIASemanticLocation;
      const ASymbols: TArray<TRadIASemanticLocation>;
      const AVisited: TDictionary<string, Boolean>;
      const ANodes: TJSONArray;
      const ADepth: Integer;
      out AError: string
    ): Boolean;
    function CollectDescendants(
      const ASymbol: TRadIASemanticLocation;
      const ASymbols: TArray<TRadIASemanticLocation>;
      const AVisited: TDictionary<string, Boolean>;
      const ANodes: TJSONArray;
      const ADepth: Integer;
      out AError: string
    ): Boolean;
    function DirectlyInheritsFrom(
      const ACandidate: TRadIASemanticLocation;
      const ATarget: TRadIASemanticLocation;
      const ASymbols: TArray<TRadIASemanticLocation>;
      out AError: string
    ): Boolean;
    function ResolveType(
      const AName: string;
      const AUnit: string;
      const ASymbols: TArray<TRadIASemanticLocation>;
      out ASymbol: TRadIASemanticLocation;
      out AError: string
    ): Boolean;
  public
    constructor Create(const AService: IRadIASemanticHierarchyService);
    function Execute(
      const ARequest: TRadIAToolRequest
    ): TRadIAToolResult;
    function GetDescriptor: TRadIAToolDescriptor;
  end;

const
  CInputSchema =
    '{"type":"object","required":["type"],"properties":{' +
    '"type":{"type":"string","minLength":1},"unit":{' +
    '"type":"string"}},"additionalProperties":false}';
  COutputSchema =
    '{"type":"object","required":["target","ancestors",' +
    '"descendants"],"properties":{"target":{"type":"object"},' +
    '"ancestors":{"type":"array"},"descendants":{"type":"array"}}}';

function IdentityOf(const ASymbol: TRadIASemanticLocation): string;
begin
  Result := ASymbol.SymbolId;
  if Result.IsEmpty then
    Result := LowerCase(ASymbol.UnitKey + '|' + ASymbol.Name);
end;

function TRadIAGetTypeHierarchyTool.BuildExternalNode(
  const AName: string;
  const ADepth: Integer
): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('name', AName);
  Result.AddPair('kind', 'external');
  Result.AddPair('relation', 'ancestor');
  Result.AddPair('depth', TJSONNumber.Create(ADepth));
  Result.AddPair('indexed', TJSONBool.Create(False));
end;

function TypeNameMatches(
  const AReference: string;
  const ASymbol: TRadIASemanticLocation
): Boolean;
begin
  Result := SameText(AReference, ASymbol.Name) or
    SameText(AReference, ASymbol.UnitKey + '.' + ASymbol.Name);
end;

function CountNamedTypes(
  const AName: string;
  const ASymbols: TArray<TRadIASemanticLocation>
): Integer;
var
  LSymbol: TRadIASemanticLocation;
begin
  Result := 0;
  for LSymbol in ASymbols do
    if SameText(LSymbol.Name, AName) then
      Inc(Result);
end;

constructor TRadIAGetTypeHierarchyTool.Create(
  const AService: IRadIASemanticHierarchyService
);
begin
  inherited Create;
  if not Assigned(AService) then
    raise EArgumentNilException.Create('AService');
  FService := AService;
end;

function TRadIAGetTypeHierarchyTool.BuildNode(
  const ASymbol: TRadIASemanticLocation;
  const ARelation: string;
  const ADepth: Integer
): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('name', ASymbol.Name);
  Result.AddPair('kind', ASymbol.Kind);
  Result.AddPair('relation', ARelation);
  Result.AddPair('depth', TJSONNumber.Create(ADepth));
  Result.AddPair('symbolId', ASymbol.SymbolId);
  Result.AddPair('unit', ASymbol.UnitKey);
  Result.AddPair('fileName', ASymbol.FileName);
  Result.AddPair('startOffset', TJSONNumber.Create(ASymbol.StartOffset));
end;

function TRadIAGetTypeHierarchyTool.ResolveType(
  const AName: string;
  const AUnit: string;
  const ASymbols: TArray<TRadIASemanticLocation>;
  out ASymbol: TRadIASemanticLocation;
  out AError: string
): Boolean;
var
  LMatchCount: Integer;
  LSymbol: TRadIASemanticLocation;
begin
  ASymbol := Default(TRadIASemanticLocation);
  AError := '';
  LMatchCount := 0;
  for LSymbol in ASymbols do
    if SameText(LSymbol.Name, AName) and
      (AUnit.IsEmpty or SameText(LSymbol.UnitKey, AUnit) or
      SameText(LSymbol.FileName, AUnit)) then
    begin
      ASymbol := LSymbol;
      Inc(LMatchCount);
    end;
  if LMatchCount = 1 then
    Exit(True);
  if LMatchCount = 0 then
    AError := 'No indexed Delphi type matched the requested name and unit.'
  else
    AError := 'The Delphi type is ambiguous. Specify its unit.';
  Result := False;
end;

function TRadIAGetTypeHierarchyTool.DirectlyInheritsFrom(
  const ACandidate: TRadIASemanticLocation;
  const ATarget: TRadIASemanticLocation;
  const ASymbols: TArray<TRadIASemanticLocation>;
  out AError: string
): Boolean;
var
  LAncestor: string;
begin
  Result := False;
  for LAncestor in ACandidate.AncestorNames do
    if TypeNameMatches(LAncestor, ATarget) then
    begin
      if (Pos('.', LAncestor) = 0) and
        (CountNamedTypes(ATarget.Name, ASymbols) > 1) then
      begin
        AError := 'An unqualified ancestor name matches multiple indexed ' +
          'types. Qualify the ancestor in source before using hierarchy.';
        Exit(False);
      end;
      Exit(True);
    end;
end;

function TRadIAGetTypeHierarchyTool.CollectAncestors(
  const ASymbol: TRadIASemanticLocation;
  const ASymbols: TArray<TRadIASemanticLocation>;
  const AVisited: TDictionary<string, Boolean>;
  const ANodes: TJSONArray;
  const ADepth: Integer;
  out AError: string
): Boolean;
var
  LAncestor: string;
  LAncestorName: string;
  LAncestorSymbol: TRadIASemanticLocation;
  LUnitName: string;
begin
  Result := True;
  for LAncestor in ASymbol.AncestorNames do
  begin
    LAncestorName := LAncestor;
    LUnitName := '';
    if LastDelimiter('.', LAncestor) > 0 then
    begin
      LUnitName := Copy(LAncestor, 1, LastDelimiter('.', LAncestor) - 1);
      LAncestorName := Copy(
        LAncestor,
        LastDelimiter('.', LAncestor) + 1,
        MaxInt
      );
    end;
    if not ResolveType(
      LAncestorName,
      LUnitName,
      ASymbols,
      LAncestorSymbol,
      AError
    ) then
    begin
      if Pos('No indexed', AError) = 1 then
      begin
        AError := '';
        ANodes.AddElement(BuildExternalNode(LAncestor, ADepth));
        Continue;
      end;
      Exit(False);
    end;
    if AVisited.ContainsKey(IdentityOf(LAncestorSymbol)) then
      Continue;
    AVisited.Add(IdentityOf(LAncestorSymbol), True);
    ANodes.AddElement(BuildNode(LAncestorSymbol, 'ancestor', ADepth));
    if not CollectAncestors(
      LAncestorSymbol,
      ASymbols,
      AVisited,
      ANodes,
      ADepth + 1,
      AError
    ) then
      Exit(False);
  end;
end;

function TRadIAGetTypeHierarchyTool.CollectDescendants(
  const ASymbol: TRadIASemanticLocation;
  const ASymbols: TArray<TRadIASemanticLocation>;
  const AVisited: TDictionary<string, Boolean>;
  const ANodes: TJSONArray;
  const ADepth: Integer;
  out AError: string
): Boolean;
var
  LCandidate: TRadIASemanticLocation;
begin
  Result := True;
  for LCandidate in ASymbols do
  begin
    if AVisited.ContainsKey(IdentityOf(LCandidate)) then
      Continue;
    if not DirectlyInheritsFrom(LCandidate, ASymbol, ASymbols, AError) then
    begin
      if not AError.IsEmpty then
        Exit(False);
      Continue;
    end;
    AVisited.Add(IdentityOf(LCandidate), True);
    ANodes.AddElement(BuildNode(LCandidate, 'descendant', ADepth));
    if not CollectDescendants(
      LCandidate,
      ASymbols,
      AVisited,
      ANodes,
      ADepth + 1,
      AError
    ) then
      Exit(False);
  end;
end;

function TRadIAGetTypeHierarchyTool.Execute(
  const ARequest: TRadIAToolRequest
): TRadIAToolResult;
var
  LAncestors: TJSONArray;
  LArguments: TJSONObject;
  LDescendants: TJSONArray;
  LError: string;
  LOutput: TJSONObject;
  LSymbol: TRadIASemanticLocation;
  LSymbols: TArray<TRadIASemanticLocation>;
  LTypeName: string;
  LUnitName: string;
  LVisited: TDictionary<string, Boolean>;
begin
  LArguments := TJSONObject.ParseJSONValue(ARequest.ArgumentsJson) as TJSONObject;
  if not Assigned(LArguments) then
    Exit(TRadIAToolResult.Failed(
      'invalid_request',
      'Type hierarchy arguments must be a JSON object.'
    ));
  try
    LTypeName := Trim(LArguments.GetValue<string>('type', ''));
    LUnitName := Trim(LArguments.GetValue<string>('unit', ''));
    if LTypeName.IsEmpty then
      Exit(TRadIAToolResult.Failed('invalid_type', 'A Delphi type is required.'));
    if not FService.ListTypeSymbols(LSymbols, LError) then
      Exit(TRadIAToolResult.Failed('semantic_query_failed', LError));
    if not ResolveType(LTypeName, LUnitName, LSymbols, LSymbol, LError) then
      Exit(TRadIAToolResult.Failed('type_not_resolved', LError));
    LOutput := TJSONObject.Create;
    try
      LOutput.AddPair('target', BuildNode(LSymbol, 'target', 0));
      LAncestors := TJSONArray.Create;
      LDescendants := TJSONArray.Create;
      LOutput.AddPair('ancestors', LAncestors);
      LOutput.AddPair('descendants', LDescendants);
      LVisited := TDictionary<string, Boolean>.Create;
      try
        LVisited.Add(IdentityOf(LSymbol), True);
        if not CollectAncestors(
          LSymbol,
          LSymbols,
          LVisited,
          LAncestors,
          1,
          LError
        ) then
          Exit(TRadIAToolResult.Failed('ambiguous_hierarchy', LError));
        LVisited.Clear;
        LVisited.Add(IdentityOf(LSymbol), True);
        if not CollectDescendants(
          LSymbol,
          LSymbols,
          LVisited,
          LDescendants,
          1,
          LError
        ) then
          Exit(TRadIAToolResult.Failed('ambiguous_hierarchy', LError));
      finally
        LVisited.Free;
      end;
      LOutput.AddPair('typeCount', TJSONNumber.Create(Length(LSymbols)));
      Result := TRadIAToolResult.Succeeded(LOutput.ToJSON);
    finally
      LOutput.Free;
    end;
  finally
    LArguments.Free;
  end;
end;

function TRadIAGetTypeHierarchyTool.GetDescriptor: TRadIAToolDescriptor;
begin
  Result := TRadIAToolDescriptor.Create(
    'GetTypeHierarchy',
    '1.0.0',
    'Returns indexed Delphi ancestors and descendants without changing code.',
    CInputSchema,
    COutputSchema,
    trReadOnly
  ).WithExecutionOptions(10000, True);
end;

procedure RegisterRadIASemanticHierarchyTools(
  const ARegistry: IRadIAToolRegistry;
  const AService: IRadIASemanticHierarchyService
);
begin
  if not Assigned(ARegistry) then
    raise EArgumentNilException.Create('ARegistry');
  ARegistry.RegisterTool(TRadIAGetTypeHierarchyTool.Create(AService));
end;

end.
