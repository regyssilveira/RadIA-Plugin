unit RadIA.Core.OpenApiRetrofit;

interface

uses
  System.Generics.Collections,
  RadIA.Core.Patches,
  RadIA.Core.Workspace;

type
  TRadIAExistingApiRoute = record
  private
    FFileName: string;
    FLine: Integer;
    FMethod: string;
    FPath: string;
  public
    constructor Create(
      const AMethod, APath, AFileName: string;
      const ALine: Integer
    );
    property FileName: string read FFileName;
    property Line: Integer read FLine;
    property Method: string read FMethod;
    property Path: string read FPath;
  end;

  TRadIAOpenApiRetrofitResult = record
  private
    FErrorCode: string;
    FErrorMessage: string;
    FPatch: TRadIAPatchResult;
    FSuccess: Boolean;
  public
    class function Failed(const ACode, AMessage: string): TRadIAOpenApiRetrofitResult; static;
    class function Succeeded(const APatch: TRadIAPatchResult): TRadIAOpenApiRetrofitResult; static;
    property ErrorCode: string read FErrorCode;
    property ErrorMessage: string read FErrorMessage;
    property Patch: TRadIAPatchResult read FPatch;
    property Success: Boolean read FSuccess;
  end;

  IRadIAOpenApiRetrofitService = interface
    ['{2D9A61F9-39D6-4E84-A42A-72EC1D9117DF}']
    function InventoryRoutes: TArray<TRadIAExistingApiRoute>;
    function Prepare(const ATitle, AVersion: string): TRadIAOpenApiRetrofitResult;
  end;

  TRadIAOpenApiRetrofitService = class(TInterfacedObject, IRadIAOpenApiRetrofitService)
  private
    FPatchService: IRadIAPatchService;
    FWorkspace: IRadIAWorkspaceFacade;
    function AddOpenApiUses(const AContent: string): string;
    function AddSwaggerConfiguration(
      const AContent, ATitle, AVersion: string
    ): string;
    procedure CollectRoutes(
      const AContent, AFileName: string;
      const ARoutes: TList<TRadIAExistingApiRoute>
    );
  public
    constructor Create(
      const AWorkspace: IRadIAWorkspaceFacade;
      const APatchService: IRadIAPatchService
    );
    function InventoryRoutes: TArray<TRadIAExistingApiRoute>;
    function Prepare(const ATitle, AVersion: string): TRadIAOpenApiRetrofitResult;
  end;

implementation

uses
  System.IOUtils,
  System.RegularExpressions,
  System.SysUtils;

constructor TRadIAExistingApiRoute.Create(
  const AMethod, APath, AFileName: string;
  const ALine: Integer
);
begin
  FMethod := UpperCase(AMethod);
  FPath := APath;
  FFileName := AFileName;
  FLine := ALine;
end;

class function TRadIAOpenApiRetrofitResult.Failed(
  const ACode, AMessage: string
): TRadIAOpenApiRetrofitResult;
begin
  Result.FSuccess := False;
  Result.FErrorCode := ACode;
  Result.FErrorMessage := AMessage;
end;

class function TRadIAOpenApiRetrofitResult.Succeeded(
  const APatch: TRadIAPatchResult
): TRadIAOpenApiRetrofitResult;
begin
  Result.FSuccess := True;
  Result.FPatch := APatch;
end;

constructor TRadIAOpenApiRetrofitService.Create(
  const AWorkspace: IRadIAWorkspaceFacade;
  const APatchService: IRadIAPatchService
);
begin
  inherited Create;
  if not Assigned(AWorkspace) then
    raise EArgumentNilException.Create('AWorkspace');
  if not Assigned(APatchService) then
    raise EArgumentNilException.Create('APatchService');
  FWorkspace := AWorkspace;
  FPatchService := APatchService;
end;

procedure TRadIAOpenApiRetrofitService.CollectRoutes(
  const AContent, AFileName: string;
  const ARoutes: TList<TRadIAExistingApiRoute>
);
var
  LLine: Integer;
  LMatch: TMatch;
  LMethod: string;
begin
  for LMatch in TRegEx.Matches(
    AContent,
    '\bMap(Get|Post|Put|Patch|Delete)\s*\(\s*''([^'']+)''',
    [roIgnoreCase]
  ) do
  begin
    LLine := 1 + TRegEx.Matches(AContent.Substring(0, LMatch.Index), '\r?\n').Count;
    ARoutes.Add(TRadIAExistingApiRoute.Create(
      LMatch.Groups[1].Value,
      LMatch.Groups[2].Value,
      AFileName,
      LLine
    ));
  end;
  for LMatch in TRegEx.Matches(
    AContent,
    '\[Http(Get|Post|Put|Patch|Delete)\s*\(\s*''([^'']+)''\)\]',
    [roIgnoreCase]
  ) do
  begin
    LMethod := LMatch.Groups[1].Value;
    LLine := 1 + TRegEx.Matches(AContent.Substring(0, LMatch.Index), '\r?\n').Count;
    ARoutes.Add(TRadIAExistingApiRoute.Create(
      LMethod,
      LMatch.Groups[2].Value,
      AFileName,
      LLine
    ));
  end;
end;

function TRadIAOpenApiRetrofitService.InventoryRoutes: TArray<TRadIAExistingApiRoute>;
var
  LFileName: string;
  LRoutes: TList<TRadIAExistingApiRoute>;
begin
  LRoutes := TList<TRadIAExistingApiRoute>.Create;
  try
    for LFileName in FWorkspace.ListProjectUnits do
      if TFile.Exists(LFileName) and LFileName.EndsWith('.pas', True) then
        CollectRoutes(TFile.ReadAllText(LFileName), LFileName, LRoutes);
    Result := LRoutes.ToArray;
  finally
    LRoutes.Free;
  end;
end;

function TRadIAOpenApiRetrofitService.AddOpenApiUses(const AContent: string): string;
var
  LMatch: TMatch;
begin
  Result := AContent;
  LMatch := TRegEx.Match(Result, '\bimplementation\s+uses\s+', [roIgnoreCase]);
  if LMatch.Success then
    Exit(Result.Insert(
      LMatch.Index + LMatch.Length,
      'Dext.OpenAPI.Generator,' + sLineBreak + '  Dext.OpenAPI.Types,' + sLineBreak +
      '  Dext.Swagger.Middleware,' + sLineBreak + '  '
    ));
  LMatch := TRegEx.Match(Result, '\bimplementation\b', [roIgnoreCase]);
  if LMatch.Success then
    Result := Result.Insert(
      LMatch.Index + LMatch.Length,
      sLineBreak + sLineBreak + 'uses' + sLineBreak + '  Dext.OpenAPI.Generator,' + sLineBreak +
      '  Dext.OpenAPI.Types,' + sLineBreak + '  Dext.Swagger.Middleware;' + sLineBreak
    );
end;

function TRadIAOpenApiRetrofitService.AddSwaggerConfiguration(
  const AContent, ATitle, AVersion: string
): string;
var
  LBegin: TMatch;
  LHeader: TMatch;
begin
  Result := AContent;
  LHeader := TRegEx.Match(
    Result,
    '(procedure\s+ConfigureApplication\s*\([^;]+;\s*)(begin)',
    [roIgnoreCase]
  );
  if not LHeader.Success then
    Exit('');
  Result := Result.Remove(LHeader.Groups[2].Index, LHeader.Groups[2].Length).Insert(
    LHeader.Groups[2].Index,
    'var' + sLineBreak + '  LOpenApiOptions: TOpenAPIOptions;' + sLineBreak + 'begin'
  );
  LBegin := TRegEx.Match(
    Result,
    'procedure\s+ConfigureApplication\s*\([^;]+;[\s\S]*?\bbegin\b',
    [roIgnoreCase]
  );
  Result := Result.Insert(
    LBegin.Index + LBegin.Length,
    sLineBreak + '  LOpenApiOptions := TOpenAPIOptions.Default;' + sLineBreak +
    '  LOpenApiOptions.Title := ''' + ATitle.Replace('''', '''''') + ''';' + sLineBreak +
    '  LOpenApiOptions.Version := ''' + AVersion.Replace('''', '''''') + ''';' + sLineBreak +
    '  TSwaggerExtensions.UseSwagger(AApplication.Builder, LOpenApiOptions);'
  );
end;

function TRadIAOpenApiRetrofitService.Prepare(
  const ATitle, AVersion: string
): TRadIAOpenApiRetrofitResult;
var
  LPatch: TRadIAPatchResult;
  LProposed: string;
  LSnapshot: TRadIAEditorContent;
begin
  if ATitle.Trim.IsEmpty or AVersion.Trim.IsEmpty then
    Exit(TRadIAOpenApiRetrofitResult.Failed('invalid_metadata', 'Title and version are required.'));
  LSnapshot := FWorkspace.GetEditorContent(2 * 1024 * 1024);
  if not LSnapshot.FileName.EndsWith('.pas', True) then
    Exit(TRadIAOpenApiRetrofitResult.Failed('unsupported_file', 'Open the DEXT startup unit first.'));
  if not LSnapshot.Content.Contains('IWebApplication') or
    not LSnapshot.Content.Contains('ConfigureApplication') then
    Exit(TRadIAOpenApiRetrofitResult.Failed('startup_not_detected', 'The active unit is not a DEXT startup unit.'));
  if LSnapshot.Content.Contains('TSwaggerExtensions.UseSwagger') then
    Exit(TRadIAOpenApiRetrofitResult.Failed('already_configured', 'Swagger is already configured.'));
  LProposed := AddSwaggerConfiguration(AddOpenApiUses(LSnapshot.Content), ATitle.Trim, AVersion.Trim);
  if LProposed.IsEmpty then
    Exit(TRadIAOpenApiRetrofitResult.Failed('unsupported_startup_shape', 'ConfigureApplication was not recognized.'));
  LPatch := FPatchService.Prepare(TRadIAPatchSpec.Create(
    LSnapshot.FileName,
    LSnapshot.Revision,
    LSnapshot.Content,
    LProposed
  ));
  if not LPatch.Success then
    Exit(TRadIAOpenApiRetrofitResult.Failed(LPatch.ErrorCode, LPatch.ErrorMessage));
  Result := TRadIAOpenApiRetrofitResult.Succeeded(LPatch);
end;

end.
