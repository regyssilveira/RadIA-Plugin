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

  TRadIASemanticReferenceKind = (
    srkDeclaration,
    srkExact,
    srkCandidate
  );

  TRadIASemanticIndexedIdentifier = record
  private
    FColumn: Integer;
    FLength: Integer;
    FLine: Integer;
    FName: string;
    FQualifier: string;
    FStartOffset: Integer;
  public
    constructor Create(
      const AName: string;
      const AQualifier: string;
      const AStartOffset: Integer;
      const ALength: Integer;
      const ALine: Integer;
      const AColumn: Integer
    );
    property Column: Integer read FColumn;
    property Length: Integer read FLength;
    property Line: Integer read FLine;
    property Name: string read FName;
    property Qualifier: string read FQualifier;
    property StartOffset: Integer read FStartOffset;
  end;

  TRadIASemanticReference = record
  private
    FColumn: Integer;
    FFileName: string;
    FKind: TRadIASemanticReferenceKind;
    FLength: Integer;
    FLine: Integer;
    FReason: string;
    FStartOffset: Integer;
    FSymbolId: string;
    FUnitKey: string;
  public
    constructor Create(
      const ASymbolId: string;
      const AUnitKey: string;
      const AFileName: string;
      const AStartOffset: Integer;
      const ALength: Integer;
      const AKind: TRadIASemanticReferenceKind;
      const AReason: string
    );
    function WithPosition(
      const ALine: Integer;
      const AColumn: Integer
    ): TRadIASemanticReference;
    property Column: Integer read FColumn;
    property FileName: string read FFileName;
    property Kind: TRadIASemanticReferenceKind read FKind;
    property Length: Integer read FLength;
    property Line: Integer read FLine;
    property Reason: string read FReason;
    property StartOffset: Integer read FStartOffset;
    property SymbolId: string read FSymbolId;
    property UnitKey: string read FUnitKey;
  end;

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
    FDeclarationSection: TRadIASemanticDeclarationSection;
    FFileName: string;
    FKind: TRadIASemanticSymbolKind;
    FLength: Integer;
    FName: string;
    FScope: TRadIASemanticUnitScope;
    FSignature: string;
    FSymbolId: string;
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
    property DeclarationSection: TRadIASemanticDeclarationSection
      read FDeclarationSection;
    property FileName: string read FFileName;
    property Kind: TRadIASemanticSymbolKind read FKind;
    property Length: Integer read FLength;
    property Name: string read FName;
    property Scope: TRadIASemanticUnitScope read FScope;
    property Signature: string read FSignature;
    property SymbolId: string read FSymbolId;
    property StartOffset: Integer read FStartOffset;
    property UnitKey: string read FUnitKey;
    property Visibility: TRadIASemanticVisibility read FVisibility;
  end;

  TRadIASemanticIndexedUnit = class
  private
    FDescriptor: TRadIASemanticUnitDescriptor;
    FIdentifiers: TArray<TRadIASemanticIndexedIdentifier>;
    FSymbols: TArray<TRadIASemanticIndexedSymbol>;
  public
    constructor Create(
      const ADescriptor: TRadIASemanticUnitDescriptor;
      const ASymbols: TArray<TRadIASemanticIndexedSymbol>;
      const AIdentifiers: TArray<TRadIASemanticIndexedIdentifier>
    );
    property Descriptor: TRadIASemanticUnitDescriptor read FDescriptor;
    property Identifiers: TArray<TRadIASemanticIndexedIdentifier> read FIdentifiers;
    property Symbols: TArray<TRadIASemanticIndexedSymbol> read FSymbols;
  end;

  TRadIASemanticIndex = class
  private
    FByContainer: TObjectDictionary<string, TList<TRadIASemanticIndexedSymbol>>;
    FByIdentity: TObjectDictionary<string, TList<TRadIASemanticIndexedSymbol>>;
    FByName: TObjectDictionary<string, TList<TRadIASemanticIndexedSymbol>>;
    FSymbolCount: Integer;
    FUnits: TObjectDictionary<string, TRadIASemanticIndexedUnit>;
    class function Normalize(const AValue: string): string; static;
    class function BuildSymbolId(
      const AUnitKey: string;
      const ASymbol: TRadIASemanticSymbol
    ): string; static;
    class function CanonicalMethodSignature(
      const AName: string;
      const AContainer: string;
      const ASignature: string
    ): string; static;
    class function BuildIdentifiers(
      const ASource: string;
      const ADefines: TArray<string>
    ): TArray<TRadIASemanticIndexedIdentifier>; static;
    class procedure AdvancePosition(
      const AText: string;
      var ALine: Integer;
      var AColumn: Integer
    ); static;
    function CountDistinctSymbolIds(const AName: string): Integer;
    function CountQualifiedSymbolIds(
      const AName: string;
      const AQualifier: string
    ): Integer;
    function IsDeclaration(
      const AUnit: TRadIASemanticIndexedUnit;
      const AIdentifier: TRadIASemanticIndexedIdentifier;
      const ASymbolId: string
    ): Boolean;
    function IsForeignDeclaration(
      const AUnit: TRadIASemanticIndexedUnit;
      const AIdentifier: TRadIASemanticIndexedIdentifier;
      const ASymbolId: string
    ): Boolean;
    function ClassifyReference(
      const AUnit: TRadIASemanticIndexedUnit;
      const AIdentifier: TRadIASemanticIndexedIdentifier;
      const ATarget: TRadIASemanticIndexedSymbol;
      const ADistinctIds: Integer;
      out AReason: string
    ): TRadIASemanticReferenceKind;
    procedure CollectUnitReferences(
      const AUnit: TRadIASemanticIndexedUnit;
      const ATarget: TRadIASemanticIndexedSymbol;
      const ADistinctIds: Integer;
      const AIncludeCandidates: Boolean;
      const AReferences: TList<TRadIASemanticReference>
    );
    class function QualifierMatches(
      const AQualifier: string;
      const ASymbol: TRadIASemanticIndexedSymbol
    ): Boolean; static;
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
      const ASymbols: TArray<TRadIASemanticIndexedSymbol>;
      const AIdentifiers: TArray<TRadIASemanticIndexedIdentifier>
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
    function CompleteResolvedMembers(
      const AContainerName: string;
      const APrefix: string;
      const AMaxItems: Integer
    ): TArray<TRadIASemanticIndexedSymbol>;
    function FindSymbols(
      const AName: string
    ): TArray<TRadIASemanticIndexedSymbol>;
    function FindSymbolsById(
      const ASymbolId: string
    ): TArray<TRadIASemanticIndexedSymbol>;
    function FindRoutineSymbols(
      const AName: string;
      const AUnitKey: string;
      const AContainer: string;
      const ASignature: string
    ): TArray<TRadIASemanticIndexedSymbol>;
    function FindReferences(
      const ASymbolId: string;
      const AIncludeCandidates: Boolean;
      const AMaxItems: Integer
    ): TArray<TRadIASemanticReference>;
    function ListPublicApiSymbols(
      const AMaxItems: Integer
    ): TArray<TRadIASemanticIndexedSymbol>;
    function ListTypeSymbols(
      const AMaxItems: Integer
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
    function UnitCount: NativeInt;
    property SymbolCount: Integer read FSymbolCount;
  end;

implementation

uses
  System.Generics.Defaults,
  System.IOUtils,
  System.JSON,
  System.SysUtils,
  RadIA.Semantic.Lexer,
  RadIA.Semantic.Preprocessor;

type
  TRadIAIdentifierScanState = record
  private
    FBeforePrevious: TRadIASemanticToken;
    FColumn: Integer;
    FHasBeforePrevious: Boolean;
    FHasPrevious: Boolean;
    FLine: Integer;
    FPrevious: TRadIASemanticToken;
  public
    class function Initialize: TRadIAIdentifierScanState; static;
    procedure AcceptToken(const AToken: TRadIASemanticToken);
    function Qualifier: string;
    procedure ResetHistory;
    property Column: Integer read FColumn write FColumn;
    property Line: Integer read FLine write FLine;
  end;

class function TRadIAIdentifierScanState.Initialize:
  TRadIAIdentifierScanState;
begin
  Result.FHasBeforePrevious := False;
  Result.FHasPrevious := False;
  Result.FLine := 1;
  Result.FColumn := 1;
end;

procedure TRadIAIdentifierScanState.AcceptToken(
  const AToken: TRadIASemanticToken
);
begin
  if FHasPrevious then
  begin
    FBeforePrevious := FPrevious;
    FHasBeforePrevious := True;
  end;
  FPrevious := AToken;
  FHasPrevious := True;
end;

function TRadIAIdentifierScanState.Qualifier: string;
begin
  Result := '';
  if FHasBeforePrevious and FHasPrevious and
    (FPrevious.Kind = stkSymbol) and (FPrevious.Text = '.') and
    (FBeforePrevious.Kind = stkIdentifier) then
    Result := FBeforePrevious.Text;
end;

procedure TRadIAIdentifierScanState.ResetHistory;
begin
  FHasBeforePrevious := False;
  FHasPrevious := False;
end;

procedure ProcessActiveIdentifierToken(
  const AProcessed: TRadIASemanticProcessedToken;
  var AState: TRadIAIdentifierScanState;
  const AIdentifiers: TList<TRadIASemanticIndexedIdentifier>
);
begin
  if AProcessed.Token.Kind = stkIdentifier then
    AIdentifiers.Add(TRadIASemanticIndexedIdentifier.Create(
      AProcessed.Token.Text,
      AState.Qualifier,
      AProcessed.Token.StartOffset,
      AProcessed.Token.Length,
      AState.Line,
      AState.Column
    ));
  if AProcessed.Token.Kind in [
    stkIdentifier,
    stkNumber,
    stkString,
    stkSymbol
  ] then
    AState.AcceptToken(AProcessed.Token);
end;

function CompareReferences(
  const ALeft: TRadIASemanticReference;
  const ARight: TRadIASemanticReference
): Integer;
begin
  Result := CompareText(ALeft.FileName, ARight.FileName);
  if Result = 0 then
    Result := ALeft.StartOffset - ARight.StartOffset;
  if Result = 0 then
    Result := Ord(ALeft.Kind) - Ord(ARight.Kind);
end;

function ComparePublicApiSymbols(
  const ALeft: TRadIASemanticIndexedSymbol;
  const ARight: TRadIASemanticIndexedSymbol
): Integer;
begin
  Result := CompareText(ALeft.FileName, ARight.FileName);
  if Result = 0 then
    Result := ALeft.StartOffset - ARight.StartOffset;
  if Result = 0 then
    Result := CompareText(ALeft.Name, ARight.Name);
end;

const
  CIndexCacheSchemaVersion = '2.1';

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
  LSectionValue: Integer;
  LVisibilityValue: Integer;
begin
  LKindValue := AObject.GetValue<Integer>('kind', -1);
  LSectionValue := AObject.GetValue<Integer>('section', 0);
  LVisibilityValue := AObject.GetValue<Integer>('visibility', -1);
  if (LKindValue < Ord(Low(TRadIASemanticSymbolKind))) or
    (LKindValue > Ord(High(TRadIASemanticSymbolKind))) or
    (LVisibilityValue < Ord(Low(TRadIASemanticVisibility))) or
    (LVisibilityValue > Ord(High(TRadIASemanticVisibility))) or
    (LSectionValue < Ord(Low(TRadIASemanticDeclarationSection))) or
    (LSectionValue > Ord(High(TRadIASemanticDeclarationSection))) then
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
  ).WithAncestors(LAncestorNames).WithDeclarationSection(
    TRadIASemanticDeclarationSection(LSectionValue)
  );
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

function ReadCacheIdentifiers(
  const AObject: TJSONObject
): TArray<TRadIASemanticIndexedIdentifier>;
var
  LArray: TJSONArray;
  LIndex: Integer;
  LItem: TJSONObject;
begin
  LArray := AObject.GetValue<TJSONArray>('identifiers');
  if not Assigned(LArray) then
    raise EInvalidOpException.Create('Semantic cache unit has no identifier list.');
  SetLength(Result, LArray.Count);
  for LIndex := 0 to LArray.Count - 1 do
  begin
    LItem := LArray[LIndex] as TJSONObject;
    Result[LIndex] := TRadIASemanticIndexedIdentifier.Create(
      LItem.GetValue<string>('name', ''),
      LItem.GetValue<string>('qualifier', ''),
      LItem.GetValue<Integer>('startOffset', 0),
      LItem.GetValue<Integer>('length', 0),
      LItem.GetValue<Integer>('line', 1),
      LItem.GetValue<Integer>('column', 1)
    );
  end;
end;

constructor TRadIASemanticIndexedIdentifier.Create(
  const AName: string;
  const AQualifier: string;
  const AStartOffset: Integer;
  const ALength: Integer;
  const ALine: Integer;
  const AColumn: Integer
);
begin
  FName := AName;
  FQualifier := AQualifier;
  FStartOffset := AStartOffset;
  FLength := ALength;
  FLine := ALine;
  FColumn := AColumn;
end;

constructor TRadIASemanticReference.Create(
  const ASymbolId: string;
  const AUnitKey: string;
  const AFileName: string;
  const AStartOffset: Integer;
  const ALength: Integer;
  const AKind: TRadIASemanticReferenceKind;
  const AReason: string
);
begin
  FSymbolId := ASymbolId;
  FUnitKey := AUnitKey;
  FFileName := AFileName;
  FStartOffset := AStartOffset;
  FLength := ALength;
  FKind := AKind;
  FReason := AReason;
end;

function TRadIASemanticReference.WithPosition(
  const ALine: Integer;
  const AColumn: Integer
): TRadIASemanticReference;
begin
  Result := Self;
  Result.FLine := ALine;
  Result.FColumn := AColumn;
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
  FDeclarationSection := ASymbol.DeclarationSection;
  FVisibility := ASymbol.Visibility;
  FStartOffset := ASymbol.StartOffset;
  FLength := ASymbol.Length;
  FSignature := ASymbol.Signature;
  FSymbolId := TRadIASemanticIndex.BuildSymbolId(AUnit.UnitKey, ASymbol);
  FAncestorNames := Copy(ASymbol.AncestorNames);
end;

constructor TRadIASemanticIndexedUnit.Create(
  const ADescriptor: TRadIASemanticUnitDescriptor;
  const ASymbols: TArray<TRadIASemanticIndexedSymbol>;
  const AIdentifiers: TArray<TRadIASemanticIndexedIdentifier>
);
begin
  inherited Create;
  FDescriptor := ADescriptor;
  FSymbols := Copy(ASymbols);
  FIdentifiers := Copy(AIdentifiers);
end;

constructor TRadIASemanticIndex.Create;
begin
  inherited Create;
  FUnits := TObjectDictionary<string, TRadIASemanticIndexedUnit>.Create([doOwnsValues]);
  FByName := TObjectDictionary<string, TList<TRadIASemanticIndexedSymbol>>.Create([doOwnsValues]);
  FByContainer := TObjectDictionary<string, TList<TRadIASemanticIndexedSymbol>>.Create([doOwnsValues]);
  FByIdentity := TObjectDictionary<string, TList<TRadIASemanticIndexedSymbol>>.Create([doOwnsValues]);
end;

destructor TRadIASemanticIndex.Destroy;
begin
  FByIdentity.Free;
  FByContainer.Free;
  FByName.Free;
  FUnits.Free;
  inherited Destroy;
end;

class function TRadIASemanticIndex.Normalize(const AValue: string): string;
begin
  Result := LowerCase(Trim(AValue));
end;

class function TRadIASemanticIndex.BuildSymbolId(
  const AUnitKey: string;
  const ASymbol: TRadIASemanticSymbol
): string;
const
  CFNVOffsetBasis: UInt64 = 14695981039346656037;
  CFNVPrime: UInt64 = 1099511628211;
var
  LByte: Byte;
  LCanonical: string;
  LHash: UInt64;
begin
  if ASymbol.Kind = sskMethod then
    LCanonical := CanonicalMethodSignature(
      ASymbol.Name,
      ASymbol.ContainerName,
      ASymbol.Signature
    )
  else
    LCanonical := Normalize(ASymbol.Signature);
  LCanonical := Normalize(AUnitKey) + '|' +
    Normalize(ASymbol.ContainerName) + '|' +
    IntToStr(Ord(ASymbol.Kind)) + '|' +
    Normalize(ASymbol.Name) + '|' + LCanonical;
  LHash := CFNVOffsetBasis;
  for LByte in TEncoding.UTF8.GetBytes(LCanonical) do
  begin
    LHash := LHash xor LByte;
    LHash := LHash * CFNVPrime;
  end;
  Result := 'sym-' + LowerCase(IntToHex(LHash, 16));
end;

class function TRadIASemanticIndex.CanonicalMethodSignature(
  const AName: string;
  const AContainer: string;
  const ASignature: string
): string;
var
  LCharacter: Char;
  LQualifiedName: string;
begin
  Result := '';
  for LCharacter in LowerCase(ASignature) do
    if not CharInSet(LCharacter, [#9, #10, #13, ' ']) then
      Result := Result + LCharacter;
  LQualifiedName := Normalize(AContainer) + '.' + Normalize(AName);
  if not AContainer.IsEmpty then
    Result := StringReplace(
      Result,
      LQualifiedName,
      Normalize(AName),
      [rfReplaceAll]
    );
end;

class function TRadIASemanticIndex.BuildIdentifiers(
  const ASource: string;
  const ADefines: TArray<string>
): TArray<TRadIASemanticIndexedIdentifier>;
var
  LIdentifiers: TList<TRadIASemanticIndexedIdentifier>;
  LPreprocessed: TRadIASemanticPreprocessResult;
  LProcessed: TRadIASemanticProcessedToken;
  LState: TRadIAIdentifierScanState;
begin
  LState := TRadIAIdentifierScanState.Initialize;
  LPreprocessed := TRadIASemanticPreprocessor.Process(ASource, ADefines);
  LIdentifiers := TList<TRadIASemanticIndexedIdentifier>.Create;
  try
    for LProcessed in LPreprocessed.Tokens do
    begin
      if LProcessed.Activity <> saInactive then
        ProcessActiveIdentifierToken(LProcessed, LState, LIdentifiers)
      else
        LState.ResetHistory;
      AdvancePosition(
        LProcessed.Token.Text,
        LState.FLine,
        LState.FColumn
      );
    end;
    Result := LIdentifiers.ToArray;
  finally
    LIdentifiers.Free;
  end;
end;

class procedure TRadIASemanticIndex.AdvancePosition(
  const AText: string;
  var ALine: Integer;
  var AColumn: Integer
);
var
  LCharacter: Char;
begin
  for LCharacter in AText do
    if LCharacter = #10 then
    begin
      Inc(ALine);
      AColumn := 1;
    end
    else if LCharacter <> #13 then
      Inc(AColumn);
end;

function TRadIASemanticIndex.CountDistinctSymbolIds(
  const AName: string
): Integer;
var
  LSeen: TDictionary<string, Boolean>;
  LSymbol: TRadIASemanticIndexedSymbol;
begin
  Result := 0;
  LSeen := TDictionary<string, Boolean>.Create;
  try
    for LSymbol in FindSymbols(AName) do
      if not LSeen.ContainsKey(LSymbol.SymbolId) then
      begin
        LSeen.Add(LSymbol.SymbolId, True);
        Inc(Result);
      end;
  finally
    LSeen.Free;
  end;
end;

function TRadIASemanticIndex.CountQualifiedSymbolIds(
  const AName: string;
  const AQualifier: string
): Integer;
var
  LSeen: TDictionary<string, Boolean>;
  LSymbol: TRadIASemanticIndexedSymbol;
begin
  Result := 0;
  LSeen := TDictionary<string, Boolean>.Create;
  try
    for LSymbol in FindSymbols(AName) do
      if QualifierMatches(AQualifier, LSymbol) and
        not LSeen.ContainsKey(LSymbol.SymbolId) then
      begin
        LSeen.Add(LSymbol.SymbolId, True);
        Inc(Result);
      end;
  finally
    LSeen.Free;
  end;
end;

function TRadIASemanticIndex.IsDeclaration(
  const AUnit: TRadIASemanticIndexedUnit;
  const AIdentifier: TRadIASemanticIndexedIdentifier;
  const ASymbolId: string
): Boolean;
var
  LSymbol: TRadIASemanticIndexedSymbol;
begin
  for LSymbol in AUnit.Symbols do
    if SameText(LSymbol.SymbolId, ASymbolId) and
      (LSymbol.StartOffset = AIdentifier.StartOffset) then
      Exit(True);
  Result := False;
end;

function TRadIASemanticIndex.IsForeignDeclaration(
  const AUnit: TRadIASemanticIndexedUnit;
  const AIdentifier: TRadIASemanticIndexedIdentifier;
  const ASymbolId: string
): Boolean;
var
  LSymbol: TRadIASemanticIndexedSymbol;
begin
  for LSymbol in AUnit.Symbols do
    if (LSymbol.StartOffset = AIdentifier.StartOffset) and
      not SameText(LSymbol.SymbolId, ASymbolId) then
      Exit(True);
  Result := False;
end;

function TRadIASemanticIndex.ClassifyReference(
  const AUnit: TRadIASemanticIndexedUnit;
  const AIdentifier: TRadIASemanticIndexedIdentifier;
  const ATarget: TRadIASemanticIndexedSymbol;
  const ADistinctIds: Integer;
  out AReason: string
): TRadIASemanticReferenceKind;
var
  LQualifiedIds: Integer;
begin
  if IsDeclaration(AUnit, AIdentifier, ATarget.SymbolId) then
  begin
    AReason := 'declaration';
    Exit(srkDeclaration);
  end;
  if AIdentifier.Qualifier.IsEmpty then
  begin
    if ADistinctIds = 1 then
    begin
      AReason := 'unique-symbol';
      Exit(srkExact);
    end;
    AReason := 'ambiguous-short-name';
    Exit(srkCandidate);
  end;
  LQualifiedIds := CountQualifiedSymbolIds(
    ATarget.Name,
    AIdentifier.Qualifier
  );
  if QualifierMatches(AIdentifier.Qualifier, ATarget) and
    (LQualifiedIds = 1) then
  begin
    AReason := 'qualified-symbol';
    Exit(srkExact);
  end;
  AReason := 'ambiguous-qualified-name';
  Result := srkCandidate;
end;

procedure TRadIASemanticIndex.CollectUnitReferences(
  const AUnit: TRadIASemanticIndexedUnit;
  const ATarget: TRadIASemanticIndexedSymbol;
  const ADistinctIds: Integer;
  const AIncludeCandidates: Boolean;
  const AReferences: TList<TRadIASemanticReference>
);
var
  LIdentifier: TRadIASemanticIndexedIdentifier;
  LKind: TRadIASemanticReferenceKind;
  LReason: string;
begin
  for LIdentifier in AUnit.Identifiers do
  begin
    if not SameText(LIdentifier.Name, ATarget.Name) then
      Continue;
    if IsForeignDeclaration(AUnit, LIdentifier, ATarget.SymbolId) then
      Continue;
    LKind := ClassifyReference(
      AUnit,
      LIdentifier,
      ATarget,
      ADistinctIds,
      LReason
    );
    if (LKind = srkCandidate) and not AIncludeCandidates then
      Continue;
    AReferences.Add(
      TRadIASemanticReference.Create(
        ATarget.SymbolId,
        AUnit.Descriptor.UnitKey,
        AUnit.Descriptor.FileName,
        LIdentifier.StartOffset,
        LIdentifier.Length,
        LKind,
        LReason
      ).WithPosition(LIdentifier.Line, LIdentifier.Column)
    );
  end;
end;

class function TRadIASemanticIndex.QualifierMatches(
  const AQualifier: string;
  const ASymbol: TRadIASemanticIndexedSymbol
): Boolean;
var
  LDelimiter: Integer;
  LShortUnit: string;
begin
  if AQualifier.IsEmpty then
    Exit(False);
  if SameText(AQualifier, ASymbol.ContainerName) or
    SameText(AQualifier, ASymbol.UnitKey) then
    Exit(True);
  LDelimiter := LastDelimiter('.', ASymbol.UnitKey);
  if LDelimiter > 0 then
    LShortUnit := Copy(ASymbol.UnitKey, LDelimiter + 1, MaxInt)
  else
    LShortUnit := ASymbol.UnitKey;
  Result := SameText(AQualifier, LShortUnit);
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
    AddLookup(FByIdentity, LSymbol.SymbolId, LSymbol);
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
    RemoveLookup(FByIdentity, LSymbol.SymbolId, LSymbol.UnitKey);
    Dec(FSymbolCount);
  end;
end;

procedure TRadIASemanticIndex.Clear;
begin
  FByIdentity.Clear;
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

function TRadIASemanticIndex.CompleteResolvedMembers(
  const AContainerName: string;
  const APrefix: string;
  const AMaxItems: Integer
): TArray<TRadIASemanticIndexedSymbol>;
var
  LCandidate: TRadIASemanticIndexedSymbol;
  LKey: string;
  LLimit: Integer;
  LPrefix: string;
  LResult: TList<TRadIASemanticIndexedSymbol>;
  LSeen: TDictionary<string, Boolean>;
begin
  LLimit := AMaxItems;
  if LLimit < 1 then
    LLimit := 1
  else if LLimit > 100 then
    LLimit := 100;
  LPrefix := Normalize(APrefix);
  LResult := TList<TRadIASemanticIndexedSymbol>.Create;
  LSeen := TDictionary<string, Boolean>.Create;
  try
    for LCandidate in FindResolvedMembers(AContainerName) do
    begin
      if (LPrefix <> '') and
        not Normalize(LCandidate.Name).StartsWith(LPrefix) then
        Continue;
      LKey := MethodKey(LCandidate);
      if LSeen.ContainsKey(LKey) then
        Continue;
      LSeen.Add(LKey, True);
      LResult.Add(LCandidate);
      if LResult.Count >= LLimit then
        Break;
    end;
    Result := LResult.ToArray;
  finally
    LSeen.Free;
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

function TRadIASemanticIndex.FindSymbolsById(
  const ASymbolId: string
): TArray<TRadIASemanticIndexedSymbol>;
var
  LList: TList<TRadIASemanticIndexedSymbol>;
begin
  if FByIdentity.TryGetValue(Normalize(ASymbolId), LList) then
    Result := LList.ToArray
  else
    Result := nil;
end;

function TRadIASemanticIndex.FindRoutineSymbols(
  const AName: string;
  const AUnitKey: string;
  const AContainer: string;
  const ASignature: string
): TArray<TRadIASemanticIndexedSymbol>;
var
  LCandidate: TRadIASemanticIndexedSymbol;
  LExpectedSignature: string;
  LResult: TList<TRadIASemanticIndexedSymbol>;
begin
  LExpectedSignature := CanonicalMethodSignature(
    AName,
    AContainer,
    ASignature
  );
  LResult := TList<TRadIASemanticIndexedSymbol>.Create;
  try
    for LCandidate in FindSymbols(AName) do
      if (LCandidate.Kind = sskMethod) and
        (AUnitKey.IsEmpty or SameText(LCandidate.UnitKey, AUnitKey)) and
        (AContainer.IsEmpty or SameText(LCandidate.ContainerName, AContainer)) and
        (ASignature.IsEmpty or SameText(
          CanonicalMethodSignature(
            LCandidate.Name,
            LCandidate.ContainerName,
            LCandidate.Signature
          ),
          LExpectedSignature
        )) then
        LResult.Add(LCandidate);
    Result := LResult.ToArray;
  finally
    LResult.Free;
  end;
end;

function TRadIASemanticIndex.FindReferences(
  const ASymbolId: string;
  const AIncludeCandidates: Boolean;
  const AMaxItems: Integer
): TArray<TRadIASemanticReference>;
var
  LDistinctIds: Integer;
  LLimit: Integer;
  LPair: TPair<string, TRadIASemanticIndexedUnit>;
  LReferences: TList<TRadIASemanticReference>;
  LSymbols: TArray<TRadIASemanticIndexedSymbol>;
  LTarget: TRadIASemanticIndexedSymbol;
begin
  LSymbols := FindSymbolsById(ASymbolId);
  if Length(LSymbols) = 0 then
    Exit(nil);
  LTarget := LSymbols[0];
  LLimit := AMaxItems;
  if LLimit < 1 then
    LLimit := 1
  else if LLimit > 1000 then
    LLimit := 1000;
  LDistinctIds := CountDistinctSymbolIds(LTarget.Name);
  LReferences := TList<TRadIASemanticReference>.Create;
  try
    for LPair in FUnits do
      CollectUnitReferences(
        LPair.Value,
        LTarget,
        LDistinctIds,
        AIncludeCandidates,
        LReferences
      );
    LReferences.Sort(
      TComparer<TRadIASemanticReference>.Construct(CompareReferences)
    );
    if LReferences.Count > LLimit then
      LReferences.Count := LLimit;
    Result := LReferences.ToArray;
  finally
    LReferences.Free;
  end;
end;

function TRadIASemanticIndex.ListPublicApiSymbols(
  const AMaxItems: Integer
): TArray<TRadIASemanticIndexedSymbol>;
var
  LLimit: Integer;
  LList: TList<TRadIASemanticIndexedSymbol>;
  LPair: TPair<string, TRadIASemanticIndexedUnit>;
  LSymbol: TRadIASemanticIndexedSymbol;
begin
  LLimit := AMaxItems;
  if LLimit < 1 then
    LLimit := 1
  else if LLimit > 5000 then
    LLimit := 5000;
  LList := TList<TRadIASemanticIndexedSymbol>.Create;
  try
    for LPair in FUnits do
    begin
      if LPair.Value.Descriptor.Scope <> susProject then
        Continue;
      for LSymbol in LPair.Value.Symbols do
      begin
        if LSymbol.Kind = sskUnitReference then
          Continue;
        if (LSymbol.Kind = sskMethod) and not (
          LSymbol.Visibility in [svPublic, svPublished]
        ) then
          Continue;
        LList.Add(LSymbol);
      end;
    end;
    LList.Sort(
      TComparer<TRadIASemanticIndexedSymbol>.Construct(
        ComparePublicApiSymbols
      )
    );
    if LList.Count > LLimit then
      LList.Count := LLimit;
    Result := LList.ToArray;
  finally
    LList.Free;
  end;
end;

function TRadIASemanticIndex.ListTypeSymbols(
  const AMaxItems: Integer
): TArray<TRadIASemanticIndexedSymbol>;
var
  LLimit: Integer;
  LList: TList<TRadIASemanticIndexedSymbol>;
  LPair: TPair<string, TRadIASemanticIndexedUnit>;
  LSymbol: TRadIASemanticIndexedSymbol;
begin
  LLimit := AMaxItems;
  if LLimit < 1 then
    LLimit := 1
  else if LLimit > 5000 then
    LLimit := 5000;
  LList := TList<TRadIASemanticIndexedSymbol>.Create;
  try
    for LPair in FUnits do
      if LPair.Value.Descriptor.Scope = susProject then
        for LSymbol in LPair.Value.Symbols do
          if LSymbol.Kind in [sskClass, sskRecord, sskInterface, sskHelper] then
            LList.Add(LSymbol);
    LList.Sort(
      TComparer<TRadIASemanticIndexedSymbol>.Construct(
        ComparePublicApiSymbols
      )
    );
    if LList.Count > LLimit then
      LList.Count := LLimit;
    Result := LList.ToArray;
  finally
    LList.Free;
  end;
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
  LIdentifiers: TArray<TRadIASemanticIndexedIdentifier>;
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
  LIdentifiers := BuildIdentifiers(ASource, ADefines);
  LUnit := TRadIASemanticIndexedUnit.Create(
    ADescriptor,
    LSymbols,
    LIdentifiers
  );
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
  const ASymbols: TArray<TRadIASemanticIndexedSymbol>;
  const AIdentifiers: TArray<TRadIASemanticIndexedIdentifier>
);
var
  LUnit: TRadIASemanticIndexedUnit;
  LUnitKey: string;
begin
  LUnitKey := Normalize(ADescriptor.UnitKey);
  if (LUnitKey = '') or FUnits.ContainsKey(LUnitKey) then
    raise EInvalidOpException.Create('Semantic cache contains an invalid unit key.');
  LUnit := TRadIASemanticIndexedUnit.Create(
    ADescriptor,
    ASymbols,
    AIdentifiers
  );
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
  LIdentifiers: TArray<TRadIASemanticIndexedIdentifier>;
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
        LIdentifiers := ReadCacheIdentifiers(LItem);
        RestoreUnit(LDescriptor, LSymbols, LIdentifiers);
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
  LIdentifier: TRadIASemanticIndexedIdentifier;
  LIdentifierItem: TJSONObject;
  LIdentifiers: TJSONArray;
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
          'section',
          TJSONNumber.Create(Ord(LSymbol.DeclarationSection))
        );
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
      LIdentifiers := TJSONArray.Create;
      for LIdentifier in LPair.Value.Identifiers do
      begin
        LIdentifierItem := TJSONObject.Create;
        LIdentifierItem.AddPair('name', LIdentifier.Name);
        LIdentifierItem.AddPair('qualifier', LIdentifier.Qualifier);
        LIdentifierItem.AddPair(
          'startOffset',
          TJSONNumber.Create(LIdentifier.StartOffset)
        );
        LIdentifierItem.AddPair(
          'length',
          TJSONNumber.Create(LIdentifier.Length)
        );
        LIdentifierItem.AddPair(
          'line',
          TJSONNumber.Create(LIdentifier.Line)
        );
        LIdentifierItem.AddPair(
          'column',
          TJSONNumber.Create(LIdentifier.Column)
        );
        LIdentifiers.AddElement(LIdentifierItem);
      end;
      LUnitItem.AddPair('identifiers', LIdentifiers);
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

function TRadIASemanticIndex.UnitCount: NativeInt;
begin
  Result := FUnits.Count;
end;

end.
