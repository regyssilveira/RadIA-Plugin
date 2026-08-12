unit RadIA.Semantic.Parser;

interface

uses
  RadIA.Semantic.Preprocessor;

type
  TRadIASemanticSymbolKind = (
    sskModule,
    sskUnitReference,
    sskClass,
    sskRecord,
    sskInterface,
    sskHelper,
    sskMethod
  );

  TRadIASemanticVisibility = (
    svUnspecified,
    svStrictPrivate,
    svPrivate,
    svStrictProtected,
    svProtected,
    svPublic,
    svPublished
  );

  TRadIASemanticSymbol = record
  private
    FContainerName: string;
    FKind: TRadIASemanticSymbolKind;
    FLength: Integer;
    FName: string;
    FSignature: string;
    FStartOffset: Integer;
    FVisibility: TRadIASemanticVisibility;
  public
    constructor Create(
      const AName: string;
      const AKind: TRadIASemanticSymbolKind;
      const AContainerName: string;
      const AVisibility: TRadIASemanticVisibility;
      const AStartOffset: Integer;
      const ALength: Integer;
      const ASignature: string
    );
    property ContainerName: string read FContainerName;
    property Kind: TRadIASemanticSymbolKind read FKind;
    property Length: Integer read FLength;
    property Name: string read FName;
    property Signature: string read FSignature;
    property StartOffset: Integer read FStartOffset;
    property Visibility: TRadIASemanticVisibility read FVisibility;
  end;

  TRadIASemanticParseResult = record
  private
    FDiagnostics: TArray<string>;
    FSymbols: TArray<TRadIASemanticSymbol>;
  public
    constructor Create(
      const ASymbols: TArray<TRadIASemanticSymbol>;
      const ADiagnostics: TArray<string>
    );
    property Diagnostics: TArray<string> read FDiagnostics;
    property Symbols: TArray<TRadIASemanticSymbol> read FSymbols;
  end;

  TRadIASemanticParser = class
  public
    class function Parse(
      const ASource: string;
      const ADefines: TArray<string>
    ): TRadIASemanticParseResult; static;
    class function SymbolKindName(
      const AKind: TRadIASemanticSymbolKind
    ): string; static;
    class function VisibilityName(
      const AVisibility: TRadIASemanticVisibility
    ): string; static;
  end;

implementation

uses
  System.Generics.Collections,
  System.SysUtils,
  RadIA.Semantic.Lexer;

type
  TRadIASemanticParserWorker = class
  private
    FDiagnostics: TList<string>;
    FIndex: Integer;
    FSource: string;
    FSymbols: TList<TRadIASemanticSymbol>;
    FTokens: TArray<TRadIASemanticToken>;
    function Current: TRadIASemanticToken;
    function IsCurrent(const AText: string): Boolean;
    function IsMethodKeyword: Boolean;
    function IsTypeBoundary: Boolean;
    function ParseQualifiedName: string;
    procedure AddSymbol(
      const AName: string;
      const AKind: TRadIASemanticSymbolKind;
      const AContainer: string;
      const AVisibility: TRadIASemanticVisibility;
      const AStart: Integer;
      const AEnd: Integer;
      const ASignature: string = ''
    );
    procedure Advance;
    procedure ParseMethod(
      const AContainer: string;
      const AVisibility: TRadIASemanticVisibility
    );
    procedure ParseModule;
    procedure ParseTypeDeclaration;
    procedure ParseTypeSection;
    procedure ParseUses;
    function ReadVisibility(
      out AVisibility: TRadIASemanticVisibility
    ): Boolean;
  public
    constructor Create(
      const ASource: string;
      const AProcessed: TRadIASemanticPreprocessResult
    );
    destructor Destroy; override;
    function Execute: TRadIASemanticParseResult;
  end;

constructor TRadIASemanticSymbol.Create(
  const AName: string;
  const AKind: TRadIASemanticSymbolKind;
  const AContainerName: string;
  const AVisibility: TRadIASemanticVisibility;
  const AStartOffset: Integer;
  const ALength: Integer;
  const ASignature: string
);
begin
  FName := AName;
  FKind := AKind;
  FContainerName := AContainerName;
  FVisibility := AVisibility;
  FStartOffset := AStartOffset;
  FLength := ALength;
  FSignature := ASignature;
end;

constructor TRadIASemanticParseResult.Create(
  const ASymbols: TArray<TRadIASemanticSymbol>;
  const ADiagnostics: TArray<string>
);
begin
  FSymbols := Copy(ASymbols);
  FDiagnostics := Copy(ADiagnostics);
end;

constructor TRadIASemanticParserWorker.Create(
  const ASource: string;
  const AProcessed: TRadIASemanticPreprocessResult
);
var
  LFiltered: TList<TRadIASemanticToken>;
  LProcessed: TRadIASemanticProcessedToken;
begin
  inherited Create;
  FSource := ASource;
  FDiagnostics := TList<string>.Create;
  FSymbols := TList<TRadIASemanticSymbol>.Create;
  LFiltered := TList<TRadIASemanticToken>.Create;
  try
    for LProcessed in AProcessed.Tokens do
      if (LProcessed.Activity <> saInactive) and
        (LProcessed.Token.Kind in [stkIdentifier, stkNumber, stkString, stkSymbol]) then
        LFiltered.Add(LProcessed.Token);
    FTokens := LFiltered.ToArray;
  finally
    LFiltered.Free;
  end;
end;

destructor TRadIASemanticParserWorker.Destroy;
begin
  FSymbols.Free;
  FDiagnostics.Free;
  inherited Destroy;
end;

procedure TRadIASemanticParserWorker.AddSymbol(
  const AName: string;
  const AKind: TRadIASemanticSymbolKind;
  const AContainer: string;
  const AVisibility: TRadIASemanticVisibility;
  const AStart: Integer;
  const AEnd: Integer;
  const ASignature: string
);
begin
  FSymbols.Add(
    TRadIASemanticSymbol.Create(
      AName,
      AKind,
      AContainer,
      AVisibility,
      AStart,
      AEnd - AStart,
      ASignature
    )
  );
end;

procedure TRadIASemanticParserWorker.Advance;
begin
  Inc(FIndex);
end;

function TRadIASemanticParserWorker.Current: TRadIASemanticToken;
begin
  Result := FTokens[FIndex];
end;

function TRadIASemanticParserWorker.Execute: TRadIASemanticParseResult;
begin
  while FIndex < Length(FTokens) do
  begin
    if IsCurrent('unit') or IsCurrent('program') or
      IsCurrent('library') or IsCurrent('package') then
      ParseModule
    else if IsCurrent('uses') then
      ParseUses
    else if IsCurrent('type') then
      ParseTypeSection
    else if IsMethodKeyword then
      ParseMethod('', svUnspecified)
    else
      Advance;
  end;
  Result := TRadIASemanticParseResult.Create(
    FSymbols.ToArray,
    FDiagnostics.ToArray
  );
end;

function TRadIASemanticParserWorker.IsCurrent(const AText: string): Boolean;
begin
  Result := (FIndex < Length(FTokens)) and SameText(Current.Text, AText);
end;

function TRadIASemanticParserWorker.IsMethodKeyword: Boolean;
begin
  Result := IsCurrent('procedure') or IsCurrent('function') or
    IsCurrent('constructor') or IsCurrent('destructor') or
    IsCurrent('operator');
end;

function TRadIASemanticParserWorker.IsTypeBoundary: Boolean;
begin
  Result := IsCurrent('var') or IsCurrent('const') or
    IsCurrent('threadvar') or IsCurrent('resourcestring') or
    IsCurrent('implementation') or IsCurrent('initialization') or
    IsCurrent('finalization') or IsCurrent('uses') or
    IsMethodKeyword;
end;

function TRadIASemanticParserWorker.ParseQualifiedName: string;
begin
  Result := '';
  while FIndex < Length(FTokens) do
  begin
    if Current.Kind <> stkIdentifier then
      Break;
    if Result <> '' then
      Result := Result + '.';
    Result := Result + Current.Text;
    Advance;
    if not IsCurrent('.') then
      Break;
    Advance;
  end;
end;

procedure TRadIASemanticParserWorker.ParseMethod(
  const AContainer: string;
  const AVisibility: TRadIASemanticVisibility
);
var
  LEnd: Integer;
  LName: string;
  LStart: Integer;
begin
  LStart := Current.StartOffset;
  Advance;
  LName := ParseQualifiedName;
  while (FIndex < Length(FTokens)) and not IsCurrent(';') do
    Advance;
  if FIndex < Length(FTokens) then
  begin
    LEnd := Current.StartOffset + Current.Length;
    Advance;
  end
  else
  begin
    LEnd := Length(FSource);
    FDiagnostics.Add(Format('Offset %d: Method declaration is not closed.', [LStart]));
  end;
  if LName = '' then
  begin
    FDiagnostics.Add(Format('Offset %d: Method name is missing.', [LStart]));
    Exit;
  end;
  AddSymbol(
    LName,
    sskMethod,
    AContainer,
    AVisibility,
    LStart,
    LEnd,
    Copy(FSource, LStart + 1, LEnd - LStart)
  );
end;

procedure TRadIASemanticParserWorker.ParseModule;
var
  LName: string;
  LStart: Integer;
begin
  LStart := Current.StartOffset;
  Advance;
  LName := ParseQualifiedName;
  if LName = '' then
    FDiagnostics.Add(Format('Offset %d: Module name is missing.', [LStart]))
  else
    AddSymbol(LName, sskModule, '', svUnspecified, LStart, Current.StartOffset);
end;

procedure TRadIASemanticParserWorker.ParseTypeDeclaration;
var
  LKind: TRadIASemanticSymbolKind;
  LName: string;
  LStart: Integer;
  LVisibility: TRadIASemanticVisibility;
begin
  LName := Current.Text;
  LStart := Current.StartOffset;
  Advance;
  if not IsCurrent('=') then
  begin
    FDiagnostics.Add(Format('Offset %d: Type declaration has no equals sign.', [LStart]));
    Exit;
  end;
  Advance;
  if IsCurrent('packed') then
    Advance;
  if IsCurrent('class') then
    LKind := sskClass
  else if IsCurrent('record') then
    LKind := sskRecord
  else if IsCurrent('interface') or IsCurrent('dispinterface') then
    LKind := sskInterface
  else
    Exit;
  Advance;
  if IsCurrent('helper') then
  begin
    LKind := sskHelper;
    Advance;
  end;
  AddSymbol(LName, LKind, '', svUnspecified, LStart, LStart + Length(LName));
  LVisibility := svUnspecified;
  while FIndex < Length(FTokens) do
  begin
    if IsCurrent('end') then
    begin
      Advance;
      if IsCurrent(';') then
        Advance;
      Exit;
    end;
    if ReadVisibility(LVisibility) then
      Continue;
    if IsCurrent('class') and
      (FIndex + 1 < Length(FTokens)) and
      (SameText(FTokens[FIndex + 1].Text, 'procedure') or
       SameText(FTokens[FIndex + 1].Text, 'function')) then
      Advance;
    if IsMethodKeyword then
      ParseMethod(LName, LVisibility)
    else
      Advance;
  end;
  FDiagnostics.Add(Format('Offset %d: Type declaration is not closed.', [LStart]));
end;

procedure TRadIASemanticParserWorker.ParseTypeSection;
begin
  Advance;
  while FIndex < Length(FTokens) do
  begin
    if IsTypeBoundary then
      Exit;
    if (Current.Kind = stkIdentifier) and
      (FIndex + 1 < Length(FTokens)) and
      (FTokens[FIndex + 1].Text = '=') then
      ParseTypeDeclaration
    else
      Advance;
  end;
end;

procedure TRadIASemanticParserWorker.ParseUses;
var
  LName: string;
  LStart: Integer;
begin
  Advance;
  while FIndex < Length(FTokens) do
  begin
    if IsCurrent(';') then
    begin
      Advance;
      Exit;
    end;
    if Current.Kind = stkIdentifier then
    begin
      LStart := Current.StartOffset;
      LName := ParseQualifiedName;
      if not SameText(LName, 'in') then
        AddSymbol(
          LName,
          sskUnitReference,
          '',
          svUnspecified,
          LStart,
          LStart + Length(LName)
        );
    end
    else
      Advance;
  end;
  FDiagnostics.Add('Uses clause is not closed.');
end;

function TRadIASemanticParserWorker.ReadVisibility(
  out AVisibility: TRadIASemanticVisibility
): Boolean;
begin
  Result := True;
  if IsCurrent('private') then
    AVisibility := svPrivate
  else if IsCurrent('protected') then
    AVisibility := svProtected
  else if IsCurrent('public') then
    AVisibility := svPublic
  else if IsCurrent('published') then
    AVisibility := svPublished
  else if IsCurrent('strict') and (FIndex + 1 < Length(FTokens)) and
    SameText(FTokens[FIndex + 1].Text, 'private') then
  begin
    AVisibility := svStrictPrivate;
    Advance;
  end
  else if IsCurrent('strict') and (FIndex + 1 < Length(FTokens)) and
    SameText(FTokens[FIndex + 1].Text, 'protected') then
  begin
    AVisibility := svStrictProtected;
    Advance;
  end
  else
    Exit(False);
  Advance;
end;

class function TRadIASemanticParser.Parse(
  const ASource: string;
  const ADefines: TArray<string>
): TRadIASemanticParseResult;
var
  LPreprocessed: TRadIASemanticPreprocessResult;
  LWorker: TRadIASemanticParserWorker;
begin
  LPreprocessed := TRadIASemanticPreprocessor.Process(ASource, ADefines);
  LWorker := TRadIASemanticParserWorker.Create(ASource, LPreprocessed);
  try
    Result := LWorker.Execute;
  finally
    LWorker.Free;
  end;
end;

class function TRadIASemanticParser.SymbolKindName(
  const AKind: TRadIASemanticSymbolKind
): string;
begin
  case AKind of
    sskModule: Result := 'module';
    sskUnitReference: Result := 'unit-reference';
    sskClass: Result := 'class';
    sskRecord: Result := 'record';
    sskInterface: Result := 'interface';
    sskHelper: Result := 'helper';
  else
    Result := 'method';
  end;
end;

class function TRadIASemanticParser.VisibilityName(
  const AVisibility: TRadIASemanticVisibility
): string;
begin
  case AVisibility of
    svStrictPrivate: Result := 'strict-private';
    svPrivate: Result := 'private';
    svStrictProtected: Result := 'strict-protected';
    svProtected: Result := 'protected';
    svPublic: Result := 'public';
    svPublished: Result := 'published';
  else
    Result := 'unspecified';
  end;
end;

end.
