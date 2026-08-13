unit RadIA.Semantic.Index;

interface

uses
  System.Generics.Collections,
  RadIA.Semantic.Parser;

type
  TRadIASemanticUnitScope = (
    susProject,
    susGroup,
    susRTL,
    susVCL
  );

  TRadIASemanticUnitDescriptor = record
  private
    FFileName: string;
    FRevision: Int64;
    FScope: TRadIASemanticUnitScope;
    FUnitKey: string;
  public
    constructor Create(
      const AUnitKey: string;
      const AFileName: string;
      const AScope: TRadIASemanticUnitScope;
      const ARevision: Int64
    );
    property FileName: string read FFileName;
    property Revision: Int64 read FRevision;
    property Scope: TRadIASemanticUnitScope read FScope;
    property UnitKey: string read FUnitKey;
  end;

  TRadIASemanticIndexedSymbol = record
  private
    FAncestorNames: TArray<string>;
    FContainerName: string;
    FFileName: string;
    FKind: TRadIASemanticSymbolKind;
    FLength: Integer;
    FName: string;
    FScope: TRadIASemanticUnitScope;
    FSignature: string;
    FStartOffset: Integer;
    FUnitKey: string;
    FVisibility: TRadIASemanticVisibility;
  public
    constructor Create(
      const AUnit: TRadIASemanticUnitDescriptor;
      const ASymbol: TRadIASemanticSymbol
    );
    property AncestorNames: TArray<string> read FAncestorNames;
    property ContainerName: string read FContainerName;
    property FileName: string read FFileName;
    property Kind: TRadIASemanticSymbolKind read FKind;
    property Length: Integer read FLength;
    property Name: string read FName;
    property Scope: TRadIASemanticUnitScope read FScope;
    property Signature: string read FSignature;
    property StartOffset: Integer read FStartOffset;
    property UnitKey: string read FUnitKey;
    property Visibility: TRadIASemanticVisibility read FVisibility;
  end;

  TRadIASemanticIndexedUnit = class
  private
    FDescriptor: TRadIASemanticUnitDescriptor;
    FSymbols: TArray<TRadIASemanticIndexedSymbol>;
  public
    constructor Create(
      const ADescriptor: TRadIASemanticUnitDescriptor;
      const ASymbols: TArray<TRadIASemanticIndexedSymbol>
    );
    property Descriptor: TRadIASemanticUnitDescriptor read FDescriptor;
    property Symbols: TArray<TRadIASemanticIndexedSymbol> read FSymbols;
  end;

  TRadIASemanticIndex = class
  private
    FByContainer: TObjectDictionary<string, TList<TRadIASemanticIndexedSymbol>>;
    FByName: TObjectDictionary<string, TList<TRadIASemanticIndexedSymbol>>;
    FSymbolCount: Integer;
    FUnits: TObjectDictionary<string, TRadIASemanticIndexedUnit>;
    class function Normalize(const AValue: string): string; static;
    procedure AddLookup(
      const ALookup: TObjectDictionary<string, TList<TRadIASemanticIndexedSymbol>>;
      const AKey: string;
      const ASymbol: TRadIASemanticIndexedSymbol
    );
    procedure AddUnitSymbols(const AUnit: TRadIASemanticIndexedUnit);
    procedure CollectResolvedMembers(
      const AContainerName: string;
      const AVisited: TDictionary<string, Boolean>;
      const AResult: TList<TRadIASemanticIndexedSymbol>
    );
    procedure CollectClassMembers(
      const AContainerName: string;
      const AVisited: TDictionary<string, Boolean>;
      const AResult: TList<TRadIASemanticIndexedSymbol>
    );
    procedure CollectInterfaceRequirements(
      const AContainerName: string;
      const AVisited: TDictionary<string, Boolean>;
      const AResult: TList<TRadIASemanticIndexedSymbol>
    );
    class function MethodKey(
      const ASymbol: TRadIASemanticIndexedSymbol
    ): string; static;
    procedure RemoveLookup(
      const ALookup: TObjectDictionary<string, TList<TRadIASemanticIndexedSymbol>>;
      const AKey: string;
      const AUnitKey: string
    );
    procedure RemoveUnitSymbols(const AUnit: TRadIASemanticIndexedUnit);
    procedure RestoreUnit(
      const ADescriptor: TRadIASemanticUnitDescriptor;
      const ASymbols: TArray<TRadIASemanticIndexedSymbol>
    );
  public
    constructor Create;
    destructor Destroy; override;
    procedure Clear;
    function FindMembers(
      const AContainerName: string
    ): TArray<TRadIASemanticIndexedSymbol>;
    function FindMissingMembers(
      const AContainerName: string
    ): TArray<TRadIASemanticIndexedSymbol>;
    function FindResolvedMembers(
      const AContainerName: string
    ): TArray<TRadIASemanticIndexedSymbol>;
    function FindSymbols(
      const AName: string
    ): TArray<TRadIASemanticIndexedSymbol>;
    function HasUnit(const AUnitKey: string): Boolean;
    function IndexUnit(
      const ADescriptor: TRadIASemanticUnitDescriptor;
      const ASource: string;
      const ADefines: TArray<string>
    ): Boolean;
    function LoadCache(const AFileName: string; out AError: string): Boolean;
    function RemoveUnit(const AUnitKey: string): Boolean;
    procedure SaveCache(const AFileName: string);
    function UnitCount: Integer;
    property SymbolCount: Integer read FSymbolCount;
  end;

implementation

uses
  System.IOUtils,
  System.JSON,
  System.SysUtils;

const
  CIndexCacheSchemaVersion = '1.0';

function FindStructuralType(
  const AIndex: TRadIASemanticIndex;
  const AName: string;
  out ASymbol: TRadIASemanticIndexedSymbol
): Boolean;
var
  LSymbol: TRadIASemanticIndexedSymbol;
begin
  for LSymbol in AIndex.FindSymbols(AName) do
    if LSymbol.Kind in [sskClass, sskRecord, sskInterface, sskHelper] then
    begin
      ASymbol := LSymbol;
      Exit(True);
    end;
  ASymbol := Default(TRadIASemanticIndexedSymbol);
  Result := False;
end;

function ReadCacheDescriptor(
  const AObject: TJSONObject
): TRadIASemanticUnitDescriptor;
var
  LScopeValue: Integer;
begin
  LScopeValue := AObject.GetValue<Integer>('scope', -1);
  if (LScopeValue < Ord(Low(TRadIASemanticUnitScope))) or
    (LScopeValue > Ord(High(TRadIASemanticUnitScope))) then
    raise EInvalidOpException.Create('Semantic cache scope is invalid.');
  Result := TRadIASemanticUnitDescriptor.Create(
    AObject.GetValue<string>('unitKey', ''),
    AObject.GetValue<string>('fileName', ''),
    TRadIASemanticUnitScope(LScopeValue),
    AObject.GetValue<Int64>('revision', 0)
  );
end;

function ReadCacheParserSymbol(const AObject: TJSONObject): TRadIASemanticSymbol;
var
  LAncestorArray: TJSONArray;
  LAncestorIndex: Integer;
  LAncestorNames: TArray<string>;
  LKindValue: Integer;
  LVisibilityValue: Integer;
begin
  LKindValue := AObject.GetValue<Integer>('kind', -1);
  LVisibilityValue := AObject.GetValue<Integer>('visibility', -1);
  if (LKindValue < Ord(Low(TRadIASemanticSymbolKind))) or
    (LKindValue > Ord(High(TRadIASemanticSymbolKind))) or
    (LVisibilityValue < Ord(Low(TRadIASemanticVisibility))) or
    (LVisibilityValue > Ord(High(TRadIASemanticVisibility))) then
    raise EInvalidOpException.Create('Semantic cache symbol metadata is invalid.');
  LAncestorArray := AObject.GetValue<TJSONArray>('ancestors');
  if Assigned(LAncestorArray) then
  begin
    SetLength(LAncestorNames, LAncestorArray.Count);
    for LAncestorIndex := 0 to LAncestorArray.Count - 1 do
      LAncestorNames[LAncestorIndex] := LAncestorArray[LAncestorIndex].Value;
  end;
  Result := TRadIASemanticSymbol.Create(
    AObject.GetValue<string>('name', ''),
    TRadIASemanticSymbolKind(LKindValue),
    AObject.GetValue<string>('container', ''),
    TRadIASemanticVisibility(LVisibilityValue),
    AObject.GetValue<Integer>('startOffset', 0),
    AObject.GetValue<Integer>('length', 0),
    AObject.GetValue<string>('signature', '')
  ).WithAncestors(LAncestorNames);
end;

function ReadCacheSymbols(
  const AObject: TJSONObject;
  const ADescriptor: TRadIASemanticUnitDescriptor
): TArray<TRadIASemanticIndexedSymbol>;
var
  LIndex: Integer;
  LParserSymbol: TRadIASemanticSymbol;
  LSymbolArray: TJSONArray;
begin
  LSymbolArray := AObject.GetValue<TJSONArray>('symbols');
  if not Assigned(LSymbolArray) then
    raise EInvalidOpException.Create('Semantic cache unit has no symbols.');
  SetLength(Result, LSymbolArray.Count);
  for LIndex := 0 to LSymbolArray.Count - 1 do
  begin
    LParserSymbol := ReadCacheParserSymbol(LSymbolArray[LIndex] as TJSONObject);
    Result[LIndex] := TRadIASemanticIndexedSymbol.Create(
      ADescriptor,
      LParserSymbol
    );
  end;
end;

constructor TRadIASemanticUnitDescriptor.Create(
  const AUnitKey: string;
  const AFileName: string;
  const AScope: TRadIASemanticUnitScope;
  const ARevision: Int64
);
begin
  FUnitKey := AUnitKey;
  FFileName := AFileName;
  FScope := AScope;
  FRevision := ARevision;
end;

constructor TRadIASemanticIndexedSymbol.Create(
  const AUnit: TRadIASemanticUnitDescriptor;
  const ASymbol: TRadIASemanticSymbol
);
begin
  FUnitKey := AUnit.UnitKey;
  FFileName := AUnit.FileName;
  FScope := AUnit.Scope;
  FName := ASymbol.Name;
  FKind := ASymbol.Kind;
  FContainerName := ASymbol.ContainerName;
  FVisibility := ASymbol.Visibility;
  FStartOffset := ASymbol.StartOffset;
  FLength := ASymbol.Length;
  FSignature := ASymbol.Signature;
  FAncestorNames := Copy(ASymbol.AncestorNames);
end;

constructor TRadIASemanticIndexedUnit.Create(
  const ADescriptor: TRadIASemanticUnitDescriptor;
  const ASymbols: TArray<TRadIASemanticIndexedSymbol>
);
begin
  inherited Create;
  FDescriptor := ADescriptor;
  FSymbols := Copy(ASymbols);
end;

constructor TRadIASemanticIndex.Create;
begin
  inherited Create;
  FUnits := TObjectDictionary<string, TRadIASemanticIndexedUnit>.Create([doOwnsValues]);
  FByName := TObjectDictionary<string, TList<TRadIASemanticIndexedSymbol>>.Create([doOwnsValues]);
  FByContainer := TObjectDictionary<string, TList<TRadIASemanticIndexedSymbol>>.Create([doOwnsValues]);
end;

destructor TRadIASemanticIndex.Destroy;
begin
  FByContainer.Free;
  FByName.Free;
  FUnits.Free;
  inherited Destroy;
end;

class function TRadIASemanticIndex.Normalize(const AValue: string): string;
begin
  Result := LowerCase(Trim(AValue));
end;

procedure TRadIASemanticIndex.AddLookup(
  const ALookup: TObjectDictionary<string, TList<TRadIASemanticIndexedSymbol>>;
  const AKey: string;
  const ASymbol: TRadIASemanticIndexedSymbol
);
var
  LList: TList<TRadIASemanticIndexedSymbol>;
  LNormalized: string;
begin
  LNormalized := Normalize(AKey);
  if LNormalized = '' then
    Exit;
  if not ALookup.TryGetValue(LNormalized, LList) then
  begin
    LList := TList<TRadIASemanticIndexedSymbol>.Create;
    ALookup.Add(LNormalized, LList);
  end;
  LList.Add(ASymbol);
end;

procedure TRadIASemanticIndex.AddUnitSymbols(
  const AUnit: TRadIASemanticIndexedUnit
);
var
  LSymbol: TRadIASemanticIndexedSymbol;
begin
  for LSymbol in AUnit.Symbols do
  begin
    AddLookup(FByName, LSymbol.Name, LSymbol);
    AddLookup(FByContainer, LSymbol.ContainerName, LSymbol);
    Inc(FSymbolCount);
  end;
end;

procedure TRadIASemanticIndex.CollectResolvedMembers(
  const AContainerName: string;
  const AVisited: TDictionary<string, Boolean>;
  const AResult: TList<TRadIASemanticIndexedSymbol>
);
var
  LAncestorName: string;
  LContainerKey: string;
  LMember: TRadIASemanticIndexedSymbol;
  LTypeSymbol: TRadIASemanticIndexedSymbol;
begin
  LContainerKey := Normalize(AContainerName);
  if (LContainerKey = '') or AVisited.ContainsKey(LContainerKey) then
    Exit;
  AVisited.Add(LContainerKey, True);
  for LTypeSymbol in FindSymbols(AContainerName) do
    if LTypeSymbol.Kind in [sskClass, sskRecord, sskInterface, sskHelper] then
      for LAncestorName in LTypeSymbol.AncestorNames do
        CollectResolvedMembers(LAncestorName, AVisited, AResult);
  for LMember in FindMembers(AContainerName) do
    AResult.Add(LMember);
end;

procedure TRadIASemanticIndex.CollectClassMembers(
  const AContainerName: string;
  const AVisited: TDictionary<string, Boolean>;
  const AResult: TList<TRadIASemanticIndexedSymbol>
);
var
  LAncestorSymbol: TRadIASemanticIndexedSymbol;
  LAncestorName: string;
  LContainerKey: string;
  LMember: TRadIASemanticIndexedSymbol;
  LTypeSymbol: TRadIASemanticIndexedSymbol;
begin
  LContainerKey := Normalize(AContainerName);
  if (LContainerKey = '') or AVisited.ContainsKey(LContainerKey) then
    Exit;
  AVisited.Add(LContainerKey, True);
  if not FindStructuralType(Self, AContainerName, LTypeSymbol) then
    Exit;
  for LMember in FindMembers(AContainerName) do
    AResult.Add(LMember);
  for LAncestorName in LTypeSymbol.AncestorNames do
    if FindStructuralType(Self, LAncestorName, LAncestorSymbol) and
      (LAncestorSymbol.Kind <> sskInterface) then
      CollectClassMembers(LAncestorName, AVisited, AResult);
end;

procedure TRadIASemanticIndex.CollectInterfaceRequirements(
  const AContainerName: string;
  const AVisited: TDictionary<string, Boolean>;
  const AResult: TList<TRadIASemanticIndexedSymbol>
);
var
  LAncestorName: string;
  LContainerKey: string;
  LMember: TRadIASemanticIndexedSymbol;
  LTypeSymbol: TRadIASemanticIndexedSymbol;
begin
  LContainerKey := Normalize(AContainerName);
  if (LContainerKey = '') or AVisited.ContainsKey(LContainerKey) then
    Exit;
  AVisited.Add(LContainerKey, True);
  if not FindStructuralType(Self, AContainerName, LTypeSymbol) then
    Exit;
  if LTypeSymbol.Kind = sskInterface then
    for LMember in FindMembers(AContainerName) do
      AResult.Add(LMember);
  for LAncestorName in LTypeSymbol.AncestorNames do
    CollectInterfaceRequirements(LAncestorName, AVisited, AResult);
end;

class function TRadIASemanticIndex.MethodKey(
  const ASymbol: TRadIASemanticIndexedSymbol
): string;
var
  LCharacter: Char;
begin
  Result := '';
  for LCharacter in LowerCase(ASymbol.Signature) do
    if not CharInSet(LCharacter, [#9, #10, #13, ' ']) then
      Result := Result + LCharacter;
end;

procedure TRadIASemanticIndex.RemoveLookup(
  const ALookup: TObjectDictionary<string, TList<TRadIASemanticIndexedSymbol>>;
  const AKey: string;
  const AUnitKey: string
);
var
  LIndex: Integer;
  LList: TList<TRadIASemanticIndexedSymbol>;
  LNormalized: string;
begin
  LNormalized := Normalize(AKey);
  if not ALookup.TryGetValue(LNormalized, LList) then
    Exit;
  for LIndex := LList.Count - 1 downto 0 do
    if SameText(LList[LIndex].UnitKey, AUnitKey) then
      LList.Delete(LIndex);
  if LList.Count = 0 then
    ALookup.Remove(LNormalized);
end;

procedure TRadIASemanticIndex.RemoveUnitSymbols(
  const AUnit: TRadIASemanticIndexedUnit
);
var
  LSymbol: TRadIASemanticIndexedSymbol;
begin
  for LSymbol in AUnit.Symbols do
  begin
    RemoveLookup(FByName, LSymbol.Name, LSymbol.UnitKey);
    RemoveLookup(FByContainer, LSymbol.ContainerName, LSymbol.UnitKey);
    Dec(FSymbolCount);
  end;
end;

procedure TRadIASemanticIndex.Clear;
begin
  FByContainer.Clear;
  FByName.Clear;
  FUnits.Clear;
  FSymbolCount := 0;
end;

function TRadIASemanticIndex.FindMembers(
  const AContainerName: string
): TArray<TRadIASemanticIndexedSymbol>;
var
  LList: TList<TRadIASemanticIndexedSymbol>;
begin
  if FByContainer.TryGetValue(Normalize(AContainerName), LList) then
    Result := LList.ToArray
  else
    Result := nil;
end;

function TRadIASemanticIndex.FindMissingMembers(
  const AContainerName: string
): TArray<TRadIASemanticIndexedSymbol>;
var
  LImplemented: TDictionary<string, Boolean>;
  LMembers: TList<TRadIASemanticIndexedSymbol>;
  LMissing: TList<TRadIASemanticIndexedSymbol>;
  LRequirements: TList<TRadIASemanticIndexedSymbol>;
  LSymbol: TRadIASemanticIndexedSymbol;
  LVisited: TDictionary<string, Boolean>;
begin
  LImplemented := TDictionary<string, Boolean>.Create;
  LMembers := TList<TRadIASemanticIndexedSymbol>.Create;
  LMissing := TList<TRadIASemanticIndexedSymbol>.Create;
  LRequirements := TList<TRadIASemanticIndexedSymbol>.Create;
  LVisited := TDictionary<string, Boolean>.Create;
  try
    CollectClassMembers(AContainerName, LVisited, LMembers);
    for LSymbol in LMembers do
      LImplemented.AddOrSetValue(MethodKey(LSymbol), True);
    LVisited.Clear;
    CollectInterfaceRequirements(AContainerName, LVisited, LRequirements);
    for LSymbol in LRequirements do
      if not LImplemented.ContainsKey(MethodKey(LSymbol)) then
      begin
        LMissing.Add(LSymbol);
        LImplemented.AddOrSetValue(MethodKey(LSymbol), True);
      end;
    Result := LMissing.ToArray;
  finally
    LVisited.Free;
    LRequirements.Free;
    LMissing.Free;
    LMembers.Free;
    LImplemented.Free;
  end;
end;

function TRadIASemanticIndex.FindResolvedMembers(
  const AContainerName: string
): TArray<TRadIASemanticIndexedSymbol>;
var
  LResult: TList<TRadIASemanticIndexedSymbol>;
  LVisited: TDictionary<string, Boolean>;
begin
  LResult := TList<TRadIASemanticIndexedSymbol>.Create;
  LVisited := TDictionary<string, Boolean>.Create;
  try
    CollectResolvedMembers(AContainerName, LVisited, LResult);
    Result := LResult.ToArray;
  finally
    LVisited.Free;
    LResult.Free;
  end;
end;

function TRadIASemanticIndex.FindSymbols(
  const AName: string
): TArray<TRadIASemanticIndexedSymbol>;
var
  LList: TList<TRadIASemanticIndexedSymbol>;
begin
  if FByName.TryGetValue(Normalize(AName), LList) then
    Result := LList.ToArray
  else
    Result := nil;
end;

function TRadIASemanticIndex.HasUnit(const AUnitKey: string): Boolean;
begin
  Result := FUnits.ContainsKey(Normalize(AUnitKey));
end;

function TRadIASemanticIndex.IndexUnit(
  const ADescriptor: TRadIASemanticUnitDescriptor;
  const ASource: string;
  const ADefines: TArray<string>
): Boolean;
var
  LExisting: TRadIASemanticIndexedUnit;
  LIndex: Integer;
  LParsed: TRadIASemanticParseResult;
  LSymbols: TArray<TRadIASemanticIndexedSymbol>;
  LUnit: TRadIASemanticIndexedUnit;
  LUnitKey: string;
begin
  LUnitKey := Normalize(ADescriptor.UnitKey);
  if LUnitKey = '' then
    raise EArgumentException.Create('Unit key cannot be empty.');
  if FUnits.TryGetValue(LUnitKey, LExisting) and
    (ADescriptor.Revision <= LExisting.Descriptor.Revision) then
    Exit(False);

  LParsed := TRadIASemanticParser.Parse(ASource, ADefines);
  SetLength(LSymbols, Length(LParsed.Symbols));
  for LIndex := 0 to High(LParsed.Symbols) do
    LSymbols[LIndex] := TRadIASemanticIndexedSymbol.Create(
      ADescriptor,
      LParsed.Symbols[LIndex]
    );
  LUnit := TRadIASemanticIndexedUnit.Create(ADescriptor, LSymbols);
  try
    if FUnits.TryGetValue(LUnitKey, LExisting) then
    begin
      RemoveUnitSymbols(LExisting);
      FUnits.Remove(LUnitKey);
    end;
    FUnits.Add(LUnitKey, LUnit);
    AddUnitSymbols(LUnit);
    LUnit := nil;
  finally
    LUnit.Free;
  end;
  Result := True;
end;

procedure TRadIASemanticIndex.RestoreUnit(
  const ADescriptor: TRadIASemanticUnitDescriptor;
  const ASymbols: TArray<TRadIASemanticIndexedSymbol>
);
var
  LUnit: TRadIASemanticIndexedUnit;
  LUnitKey: string;
begin
  LUnitKey := Normalize(ADescriptor.UnitKey);
  if (LUnitKey = '') or FUnits.ContainsKey(LUnitKey) then
    raise EInvalidOpException.Create('Semantic cache contains an invalid unit key.');
  LUnit := TRadIASemanticIndexedUnit.Create(ADescriptor, ASymbols);
  try
    FUnits.Add(LUnitKey, LUnit);
    AddUnitSymbols(LUnit);
    LUnit := nil;
  finally
    LUnit.Free;
  end;
end;

function TRadIASemanticIndex.LoadCache(
  const AFileName: string;
  out AError: string
): Boolean;
var
  LDescriptor: TRadIASemanticUnitDescriptor;
  LDocument: TJSONObject;
  LIndex: Integer;
  LItem: TJSONObject;
  LSymbols: TArray<TRadIASemanticIndexedSymbol>;
  LUnitArray: TJSONArray;
begin
  AError := '';
  Clear;
  if Trim(AFileName) = '' then
  begin
    AError := 'Semantic cache file name cannot be empty.';
    Exit(False);
  end;
  if not TFile.Exists(AFileName) then
    Exit(True);
  try
    LDocument := TJSONObject.ParseJSONValue(
      TFile.ReadAllText(AFileName, TEncoding.UTF8)
    ) as TJSONObject;
    try
      if not Assigned(LDocument) or
        (LDocument.GetValue<string>('schemaVersion', '') <>
         CIndexCacheSchemaVersion) then
        raise EInvalidOpException.Create('Semantic cache schema is invalid.');
      LUnitArray := LDocument.GetValue<TJSONArray>('units');
      if not Assigned(LUnitArray) then
        raise EInvalidOpException.Create('Semantic cache has no unit list.');
      for LIndex := 0 to LUnitArray.Count - 1 do
      begin
        LItem := LUnitArray[LIndex] as TJSONObject;
        LDescriptor := ReadCacheDescriptor(LItem);
        LSymbols := ReadCacheSymbols(LItem, LDescriptor);
        RestoreUnit(LDescriptor, LSymbols);
      end;
    finally
      LDocument.Free;
    end;
    Result := True;
  except
    on E: Exception do
    begin
      Clear;
      AError := E.Message;
      TFile.Delete(AFileName);
      Result := False;
    end;
  end;
end;

function TRadIASemanticIndex.RemoveUnit(const AUnitKey: string): Boolean;
var
  LUnit: TRadIASemanticIndexedUnit;
  LUnitKey: string;
begin
  LUnitKey := Normalize(AUnitKey);
  Result := FUnits.TryGetValue(LUnitKey, LUnit);
  if not Result then
    Exit;
  RemoveUnitSymbols(LUnit);
  FUnits.Remove(LUnitKey);
end;

procedure TRadIASemanticIndex.SaveCache(const AFileName: string);
var
  LAncestor: string;
  LAncestors: TJSONArray;
  LDocument: TJSONObject;
  LPair: TPair<string, TRadIASemanticIndexedUnit>;
  LSymbol: TRadIASemanticIndexedSymbol;
  LSymbolItem: TJSONObject;
  LSymbols: TJSONArray;
  LTargetDirectory: string;
  LTemporaryFile: string;
  LUnitItem: TJSONObject;
  LUnits: TJSONArray;
begin
  if Trim(AFileName) = '' then
    raise EArgumentException.Create('Semantic cache file name cannot be empty.');
  LDocument := TJSONObject.Create;
  try
    LDocument.AddPair('schemaVersion', CIndexCacheSchemaVersion);
    LUnits := TJSONArray.Create;
    for LPair in FUnits do
    begin
      LUnitItem := TJSONObject.Create;
      LUnitItem.AddPair('unitKey', LPair.Value.Descriptor.UnitKey);
      LUnitItem.AddPair('fileName', LPair.Value.Descriptor.FileName);
      LUnitItem.AddPair(
        'scope',
        TJSONNumber.Create(Ord(LPair.Value.Descriptor.Scope))
      );
      LUnitItem.AddPair(
        'revision',
        TJSONNumber.Create(LPair.Value.Descriptor.Revision)
      );
      LSymbols := TJSONArray.Create;
      for LSymbol in LPair.Value.Symbols do
      begin
        LSymbolItem := TJSONObject.Create;
        LSymbolItem.AddPair('name', LSymbol.Name);
        LSymbolItem.AddPair('kind', TJSONNumber.Create(Ord(LSymbol.Kind)));
        LSymbolItem.AddPair('container', LSymbol.ContainerName);
        LSymbolItem.AddPair(
          'visibility',
          TJSONNumber.Create(Ord(LSymbol.Visibility))
        );
        LSymbolItem.AddPair(
          'startOffset',
          TJSONNumber.Create(LSymbol.StartOffset)
        );
        LSymbolItem.AddPair('length', TJSONNumber.Create(LSymbol.Length));
        LSymbolItem.AddPair('signature', LSymbol.Signature);
        LAncestors := TJSONArray.Create;
        for LAncestor in LSymbol.AncestorNames do
          LAncestors.Add(LAncestor);
        LSymbolItem.AddPair('ancestors', LAncestors);
        LSymbols.AddElement(LSymbolItem);
      end;
      LUnitItem.AddPair('symbols', LSymbols);
      LUnits.AddElement(LUnitItem);
    end;
    LDocument.AddPair('units', LUnits);
    LTargetDirectory := ExtractFileDir(AFileName);
    if LTargetDirectory <> '' then
      TDirectory.CreateDirectory(LTargetDirectory);
    LTemporaryFile := AFileName + '.tmp';
    TFile.WriteAllText(LTemporaryFile, LDocument.ToJSON, TEncoding.UTF8);
    if TFile.Exists(AFileName) then
      TFile.Delete(AFileName);
    TFile.Move(LTemporaryFile, AFileName);
  finally
    LDocument.Free;
  end;
end;

function TRadIASemanticIndex.UnitCount: Integer;
begin
  Result := FUnits.Count;
end;

end.
