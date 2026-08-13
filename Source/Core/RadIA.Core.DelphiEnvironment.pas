unit RadIA.Core.DelphiEnvironment;

interface

uses
  RadIA.Core.Workspace;

type
  TRadIADelphiEnvironmentProfile = record
  private
    FCapabilities: TArray<string>;
    FConfiguration: string;
    FDefines: TArray<string>;
    FFramework: string;
    FIDEArchitecture: string;
    FIDESKU: string;
    FIDEVersion: string;
    FIncludePaths: TArray<string>;
    FLibraries: TArray<string>;
    FLibraryPaths: TArray<string>;
    FPackages: TArray<string>;
    FProjectName: string;
    FSearchPaths: TArray<string>;
    FTargetPlatform: string;
    FUnitScopes: TArray<string>;
  public
    constructor Create(
      const AIDEVersion: string;
      const AIDEArchitecture: string;
      const AIDESKU: string;
      const AProjectName: string;
      const AFramework: string;
      const AConfiguration: string;
      const ATargetPlatform: string
    );
    procedure SetCollections(
      const ACapabilities: TArray<string>;
      const ASearchPaths: TArray<string>;
      const APackages: TArray<string>;
      const ALibraries: TArray<string>
    );
    procedure SetCompilerCollections(
      const ADefines: TArray<string>;
      const AUnitScopes: TArray<string>;
      const AIncludePaths: TArray<string>;
      const ALibraryPaths: TArray<string>
    );
    property IDEVersion: string read FIDEVersion;
    property IDEArchitecture: string read FIDEArchitecture;
    property IDESKU: string read FIDESKU;
    property ProjectName: string read FProjectName;
    property Framework: string read FFramework;
    property Configuration: string read FConfiguration;
    property TargetPlatform: string read FTargetPlatform;
    property Capabilities: TArray<string> read FCapabilities;
    property Defines: TArray<string> read FDefines;
    property UnitScopes: TArray<string> read FUnitScopes;
    property SearchPaths: TArray<string> read FSearchPaths;
    property IncludePaths: TArray<string> read FIncludePaths;
    property LibraryPaths: TArray<string> read FLibraryPaths;
    property Packages: TArray<string> read FPackages;
    property Libraries: TArray<string> read FLibraries;
  end;

  IRadIADelphiEnvironmentService = interface
    ['{BF310F1E-5ED8-451F-90A9-3E44A1E85AA1}']
    function BuildProfile: TRadIADelphiEnvironmentProfile;
  end;

  TRadIADelphiEnvironmentService = class(
    TInterfacedObject,
    IRadIADelphiEnvironmentService
  )
  private
    FWorkspace: IRadIAWorkspaceFacade;
    function DetectFramework(const AProjectContent: string): string;
    function DetectLibraries(
      const AProjectContent: string
    ): TArray<string>;
    function ExtractPackages(
      const AProjectContent: string
    ): TArray<string>;
    function ExtractCompilerValues(
      const AProjectContent: string;
      const ATagName: string;
      const AConfiguration: string;
      const APlatform: string
    ): TArray<string>;
    function ExtractPaths(
      const AProjectContent: string;
      const AProjectRoot: string;
      const ATagName: string;
      const AConfiguration: string;
      const APlatform: string
    ): TArray<string>;
    function ExtractSearchPaths(
      const AProjectContent: string;
      const AProjectRoot: string;
      const AConfiguration: string;
      const APlatform: string
    ): TArray<string>;
    function ReadProjectContent(const AFileName: string): string;
  public
    constructor Create(const AWorkspace: IRadIAWorkspaceFacade);
    function BuildProfile: TRadIADelphiEnvironmentProfile;
  end;

implementation

uses
  System.Classes,
  System.Generics.Collections,
  System.IOUtils,
  System.Math,
  System.RegularExpressions,
  System.StrUtils,
  System.SysUtils,
  Xml.XMLDoc,
  Xml.XMLIntf;

const
  CMaximumProjectCharacters = 2 * 1024 * 1024;
  CMaximumCollectionItems = 100;

function ExtractTagValues(
  const AContent: string;
  const ATagName: string
): TArray<string>;
var
  LIndex: Integer;
  LMatch: TMatch;
  LMatches: TMatchCollection;
begin
  LMatches := TRegEx.Matches(
    AContent,
    '<' + ATagName + '[^>]*>([^<]*)</' + ATagName + '>',
    [roIgnoreCase]
  );
  SetLength(Result, Min(LMatches.Count, CMaximumCollectionItems));
  for LIndex := Low(Result) to High(Result) do
  begin
    LMatch := LMatches[LIndex];
    Result[LIndex] := Trim(LMatch.Groups[1].Value);
  end;
end;

function JoinValues(const AValues: TArray<string>): string;
var
  LValue: string;
begin
  Result := '';
  for LValue in AValues do
  begin
    if Result <> '' then
      Result := Result + ';';
    Result := Result + LValue;
  end;
end;

function UniqueValues(const AValues: TArray<string>): TArray<string>;
var
  LList: TStringList;
  LValue: string;
begin
  LList := TStringList.Create;
  try
    LList.CaseSensitive := False;
    LList.Duplicates := dupIgnore;
    LList.Sorted := True;
    for LValue in AValues do
      if (Trim(LValue) <> '') and
        (LList.Count < CMaximumCollectionItems) then
        LList.Add(Trim(LValue));
    Result := LList.ToStringArray;
  finally
    LList.Free;
  end;
end;

function SanitizeSearchPath(
  const APath: string;
  const AProjectRoot: string
): string;
var
  LExpandedRoot: string;
  LPath: string;
begin
  LPath := Trim(APath);
  if LPath = '' then
    Exit('');
  if ContainsText(LPath, '$(') then
    Exit(LPath);

  LExpandedRoot := IncludeTrailingPathDelimiter(
    TPath.GetFullPath(AProjectRoot)
  );
  if TPath.IsPathRooted(LPath) then
  begin
    LPath := TPath.GetFullPath(LPath);
    if StartsText(LExpandedRoot, LPath) then
      Exit('{workspace}\' + LPath.Substring(Length(LExpandedRoot)));
    Exit('<external>');
  end;
  Result := '{workspace}\' + LPath;
end;

{ TRadIADelphiEnvironmentProfile }

constructor TRadIADelphiEnvironmentProfile.Create(
  const AIDEVersion: string;
  const AIDEArchitecture: string;
  const AIDESKU: string;
  const AProjectName: string;
  const AFramework: string;
  const AConfiguration: string;
  const ATargetPlatform: string
);
begin
  FIDEVersion := AIDEVersion;
  FIDEArchitecture := AIDEArchitecture;
  FIDESKU := AIDESKU;
  FProjectName := AProjectName;
  FFramework := AFramework;
  FConfiguration := AConfiguration;
  FTargetPlatform := ATargetPlatform;
end;

procedure TRadIADelphiEnvironmentProfile.SetCollections(
  const ACapabilities: TArray<string>;
  const ASearchPaths: TArray<string>;
  const APackages: TArray<string>;
  const ALibraries: TArray<string>
);
begin
  FCapabilities := Copy(ACapabilities);
  FSearchPaths := Copy(ASearchPaths);
  FPackages := Copy(APackages);
  FLibraries := Copy(ALibraries);
end;

function ExpandProjectProperties(
  const AValue: string;
  const AProperties: TDictionary<string, string>
): string;
var
  LIndex: Integer;
  LMatch: TMatch;
  LMatches: TMatchCollection;
  LName: string;
  LValue: string;
begin
  Result := AValue;
  LMatches := TRegEx.Matches(Result, '\$\(([^)]+)\)');
  for LIndex := LMatches.Count - 1 downto 0 do
  begin
    LMatch := LMatches[LIndex];
    LName := LMatch.Groups[1].Value;
    if AProperties.TryGetValue(LName, LValue) then
      Result := Result.Remove(LMatch.Index - 1, LMatch.Length).Insert(
        LMatch.Index - 1,
        LValue
      );
  end;
end;

function EvaluateComparison(const AExpression: string): Boolean;
var
  LMatch: TMatch;
begin
  LMatch := TRegEx.Match(
    Trim(AExpression).Trim(['(', ')', ' ']),
    '^''([^'']*)''\s*(==|!=)\s*''([^'']*)''$',
    [roIgnoreCase]
  );
  if not LMatch.Success then
    Exit(False);
  Result := SameText(LMatch.Groups[1].Value, LMatch.Groups[3].Value);
  if LMatch.Groups[2].Value = '!=' then
    Result := not Result;
end;

function EvaluateProjectCondition(
  const ACondition: string;
  const AProperties: TDictionary<string, string>
): Boolean;
var
  LAndExpression: string;
  LAndParts: TArray<string>;
  LExpanded: string;
  LOrExpression: string;
  LOrParts: TArray<string>;
begin
  if Trim(ACondition) = '' then
    Exit(True);
  LExpanded := ExpandProjectProperties(ACondition, AProperties);
  LOrParts := TRegEx.Split(LExpanded, '\s+or\s+', [roIgnoreCase]);
  for LOrExpression in LOrParts do
  begin
    Result := True;
    LAndParts := TRegEx.Split(LOrExpression, '\s+and\s+', [roIgnoreCase]);
    for LAndExpression in LAndParts do
      if not EvaluateComparison(LAndExpression) then
      begin
        Result := False;
        Break;
      end;
    if Result then
      Exit;
  end;
  Result := False;
end;

function BuildProjectProperties(
  const AContent: string;
  const AConfiguration: string;
  const APlatform: string
): TDictionary<string, string>;
var
  LChild: IXMLNode;
  LCondition: string;
  LDocument: IXMLDocument;
  LGroup: IXMLNode;
  LGroupIndex: Integer;
  LNodeIndex: Integer;
  LValue: string;
begin
  Result := TDictionary<string, string>.Create;
  try
    Result.AddOrSetValue('Config', AConfiguration);
    Result.AddOrSetValue('Platform', APlatform);
    Result.AddOrSetValue('Base', 'true');
    Result.AddOrSetValue('Base_' + APlatform, 'true');
    LDocument := LoadXMLData(AContent);
    for LGroupIndex := 0 to LDocument.DocumentElement.ChildNodes.Count - 1 do
    begin
      LGroup := LDocument.DocumentElement.ChildNodes[LGroupIndex];
      if not SameText(LGroup.LocalName, 'PropertyGroup') then
        Continue;
      LCondition := '';
      if LGroup.HasAttribute('Condition') then
        LCondition := LGroup.Attributes['Condition'];
      if not EvaluateProjectCondition(LCondition, Result) then
        Continue;
      for LNodeIndex := 0 to LGroup.ChildNodes.Count - 1 do
      begin
        LChild := LGroup.ChildNodes[LNodeIndex];
        if LChild.NodeType <> ntElement then
          Continue;
        LValue := ExpandProjectProperties(LChild.Text, Result);
        Result.AddOrSetValue(LChild.LocalName, LValue);
      end;
    end;
  except
    Result.Free;
    raise;
  end;
end;

procedure TRadIADelphiEnvironmentProfile.SetCompilerCollections(
  const ADefines: TArray<string>;
  const AUnitScopes: TArray<string>;
  const AIncludePaths: TArray<string>;
  const ALibraryPaths: TArray<string>
);
begin
  FDefines := Copy(ADefines);
  FUnitScopes := Copy(AUnitScopes);
  FIncludePaths := Copy(AIncludePaths);
  FLibraryPaths := Copy(ALibraryPaths);
end;

{ TRadIADelphiEnvironmentService }

constructor TRadIADelphiEnvironmentService.Create(
  const AWorkspace: IRadIAWorkspaceFacade
);
begin
  inherited Create;
  if not Assigned(AWorkspace) then
    raise EArgumentNilException.Create('AWorkspace');
  FWorkspace := AWorkspace;
end;

function TRadIADelphiEnvironmentService.BuildProfile:
  TRadIADelphiEnvironmentProfile;
var
  LContent: string;
  LIDE: TRadIAIDEState;
  LProject: TRadIAProjectSnapshot;
begin
  LIDE := FWorkspace.GetIDEState;
  LProject := FWorkspace.GetActiveProject;
  LContent := ReadProjectContent(LProject.FileName);
  Result := TRadIADelphiEnvironmentProfile.Create(
    LIDE.VersionName,
    LIDE.Platform,
    LIDE.SKU,
    LProject.Name,
    DetectFramework(LContent),
    LProject.Configuration,
    LProject.Platform
  );
  if LContent = '' then
  begin
    Result.SetCollections(LIDE.Capabilities, [], [], []);
    Result.SetCompilerCollections([], [], [], []);
    Exit;
  end;
  Result.SetCollections(
    LIDE.Capabilities,
    ExtractSearchPaths(
      LContent,
      LProject.RootPath,
      LProject.Configuration,
      LProject.Platform
    ),
    ExtractPackages(LContent),
    DetectLibraries(LContent)
  );
  Result.SetCompilerCollections(
    ExtractCompilerValues(
      LContent,
      'DCC_Define',
      LProject.Configuration,
      LProject.Platform
    ),
    ExtractCompilerValues(
      LContent,
      'DCC_Namespace',
      LProject.Configuration,
      LProject.Platform
    ),
    ExtractPaths(
      LContent,
      LProject.RootPath,
      'DCC_IncludePath',
      LProject.Configuration,
      LProject.Platform
    ),
    ExtractPaths(
      LContent,
      LProject.RootPath,
      'DCC_LibraryPath',
      LProject.Configuration,
      LProject.Platform
    )
  );
end;

function TRadIADelphiEnvironmentService.DetectFramework(
  const AProjectContent: string
): string;
var
  LValues: TArray<string>;
begin
  LValues := ExtractTagValues(AProjectContent, 'FrameworkType');
  if Length(LValues) > 0 then
    Exit(LValues[0]);
  if ContainsText(AProjectContent, 'Vcl.Forms') then
    Exit('VCL');
  if ContainsText(AProjectContent, 'FMX.Forms') then
    Exit('FMX');
  Result := 'None';
end;

function TRadIADelphiEnvironmentService.DetectLibraries(
  const AProjectContent: string
): TArray<string>;
var
  LList: TList<string>;
begin
  LList := TList<string>.Create;
  try
    if ContainsText(AProjectContent, 'FireDAC.') then
      LList.Add('FireDAC');
    if ContainsText(AProjectContent, 'Data.Win.ADODB') then
      LList.Add('ADO');
    if ContainsText(AProjectContent, 'Bde.DBTables') then
      LList.Add('BDE');
    if ContainsText(AProjectContent, 'Data.SqlExpr') then
      LList.Add('dbExpress');
    if ContainsText(AProjectContent, 'REST.') then
      LList.Add('REST');
    if ContainsText(AProjectContent, 'DUnitX.') then
      LList.Add('DUnitX');
    Result := UniqueValues(LList.ToArray);
  finally
    LList.Free;
  end;
end;

function TRadIADelphiEnvironmentService.ExtractPackages(
  const AProjectContent: string
): TArray<string>;
var
  LPackage: string;
  LPackages: TArray<string>;
  LResult: TList<string>;
  LTagValues: TArray<string>;
begin
  LTagValues := ExtractTagValues(AProjectContent, 'DCC_UsePackage');
  LPackages := JoinValues(LTagValues).Split([';']);
  LResult := TList<string>.Create;
  try
    for LPackage in LPackages do
      if not ContainsText(LPackage, '$(') then
        LResult.Add(LPackage);
    Result := UniqueValues(LResult.ToArray);
  finally
    LResult.Free;
  end;
end;

function TRadIADelphiEnvironmentService.ExtractCompilerValues(
  const AProjectContent: string;
  const ATagName: string;
  const AConfiguration: string;
  const APlatform: string
): TArray<string>;
var
  LProperties: TDictionary<string, string>;
  LResult: TList<string>;
  LRawValue: string;
  LValue: string;
begin
  LProperties := BuildProjectProperties(
    AProjectContent,
    AConfiguration,
    APlatform
  );
  LResult := TList<string>.Create;
  try
    if not LProperties.TryGetValue(ATagName, LRawValue) then
      LRawValue := '';
    for LValue in LRawValue.Split([';', ',']) do
      if not ContainsText(LValue, '$(') then
        LResult.Add(LValue);
    Result := UniqueValues(LResult.ToArray);
  finally
    LResult.Free;
    LProperties.Free;
  end;
end;

function TRadIADelphiEnvironmentService.ExtractPaths(
  const AProjectContent: string;
  const AProjectRoot: string;
  const ATagName: string;
  const AConfiguration: string;
  const APlatform: string
): TArray<string>;
var
  LIndex: Integer;
  LPath: string;
  LPaths: TArray<string>;
  LProperties: TDictionary<string, string>;
  LRawValue: string;
  LSanitizedPath: string;
  LSanitized: TList<string>;
begin
  LProperties := BuildProjectProperties(
    AProjectContent,
    AConfiguration,
    APlatform
  );
  LSanitized := TList<string>.Create;
  try
    if not LProperties.TryGetValue(ATagName, LRawValue) then
      LRawValue := '';
    LPaths := LRawValue.Split([';']);
    for LPath in LPaths do
    begin
      LSanitizedPath := SanitizeSearchPath(LPath, AProjectRoot);
      if (LSanitizedPath <> '') and
        (LSanitized.Count < CMaximumCollectionItems) then
        LSanitized.Add(LSanitizedPath);
    end;
    Result := UniqueValues(LSanitized.ToArray);
  finally
    LSanitized.Free;
    LProperties.Free;
  end;
  for LIndex := Low(Result) to High(Result) do
    Result[LIndex] := StringReplace(Result[LIndex], '/', '\', [rfReplaceAll]);
end;

function TRadIADelphiEnvironmentService.ExtractSearchPaths(
  const AProjectContent: string;
  const AProjectRoot: string;
  const AConfiguration: string;
  const APlatform: string
): TArray<string>;
begin
  Result := ExtractPaths(
    AProjectContent,
    AProjectRoot,
    'DCC_UnitSearchPath',
    AConfiguration,
    APlatform
  );
end;

function TRadIADelphiEnvironmentService.ReadProjectContent(
  const AFileName: string
): string;
var
  LStream: TFileStream;
  LText: TStringStream;
begin
  Result := '';
  if (Trim(AFileName) = '') or not TFile.Exists(AFileName) then
    Exit;
  LStream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyNone);
  try
    if LStream.Size > CMaximumProjectCharacters then
      raise EInvalidOp.Create('The active Delphi project file exceeds the safe profile limit.');
    LText := TStringStream.Create('', TEncoding.UTF8);
    try
      LText.CopyFrom(LStream, LStream.Size);
      Result := LText.DataString;
    finally
      LText.Free;
    end;
  finally
    LStream.Free;
  end;
end;

end.
