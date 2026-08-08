unit RadIA.Core.DextProjectTemplates;

interface

uses
  RadIA.Core.ApiSpecifications;

type
  TRadIADextGeneratedFile = record
  private
    FRelativePath: string;
    FContent: string;
  public
    constructor Create(
      const ARelativePath: string;
      const AContent: string
    );
    property RelativePath: string read FRelativePath;
    property Content: string read FContent;
  end;

  TRadIADextProjectRenderer = class
  private
    class function BuildControllerUnit(
      const ASpecification: TRadIAApiSpecification
    ): string; static;
    class function BuildDpr(
      const ASpecification: TRadIAApiSpecification
    ): string; static;
    class function BuildDependencyInjectionUnit(
      const ASpecification: TRadIAApiSpecification
    ): string; static;
    class function BuildEndpointsUnit(
      const ASpecification: TRadIAApiSpecification
    ): string; static;
    class function BuildHttpFile(
      const ASpecification: TRadIAApiSpecification
    ): string; static;
    class function BuildReadme(
      const ASpecification: TRadIAApiSpecification
    ): string; static;
    class function BuildServicesUnit(
      const ASpecification: TRadIAApiSpecification
    ): string; static;
    class function BuildStartupUnit(
      const ASpecification: TRadIAApiSpecification
    ): string; static;
    class function HttpAttribute(const AMethod: string): string; static;
    class function ResponseJson(
      const AEndpoint: TRadIAApiEndpoint
    ): string; static;
  public
    class function BuildFiles(
      const ASpecification: TRadIAApiSpecification
    ): TArray<TRadIADextGeneratedFile>; static;
  end;

implementation

uses
  System.Classes,
  System.Generics.Collections,
  System.StrUtils,
  System.SysUtils;

{ TRadIADextGeneratedFile }

constructor TRadIADextGeneratedFile.Create(
  const ARelativePath: string;
  const AContent: string
);
begin
  FRelativePath := ARelativePath;
  FContent := AContent;
end;

{ TRadIADextProjectRenderer }

class function TRadIADextProjectRenderer.BuildControllerUnit(
  const ASpecification: TRadIAApiSpecification
): string;
var
  LBuilder: TStringBuilder;
  LEndpoint: TRadIAApiEndpoint;
  LGroup: string;
  LGroups: TList<string>;
begin
  LBuilder := TStringBuilder.Create;
  LGroups := TList<string>.Create;
  try
    for LEndpoint in ASpecification.Endpoints do
    begin
      if not LGroups.Contains(LEndpoint.Group) then
        LGroups.Add(LEndpoint.Group);
    end;
    LBuilder.AppendLine('unit ' + ASpecification.ProjectName + '.Controllers;');
    LBuilder.AppendLine;
    LBuilder.AppendLine('interface');
    LBuilder.AppendLine;
    LBuilder.AppendLine('uses');
    LBuilder.AppendLine('  Dext.Web,');
    LBuilder.AppendLine('  ' + ASpecification.ProjectName + '.Services;');
    LBuilder.AppendLine;
    LBuilder.AppendLine('type');
    for LGroup in LGroups do
    begin
      LBuilder.AppendLine('  [ApiController('''')]');
      LBuilder.AppendLine('  T' + LGroup + 'Controller = class');
      LBuilder.AppendLine('  private');
      LBuilder.AppendLine('    FService: IApiService;');
      LBuilder.AppendLine('  public');
      LBuilder.AppendLine('    constructor Create(const AService: IApiService);');
      for LEndpoint in ASpecification.Endpoints do
      begin
        if not SameText(LEndpoint.Group, LGroup) then
          Continue;
        LBuilder.AppendLine(
          '    [' + HttpAttribute(LEndpoint.Method) + '(''' + LEndpoint.Path + ''')]'
        );
        LBuilder.AppendLine(
          '    procedure ' + LEndpoint.Name + '(const AContext: IHttpContext);'
        );
      end;
      LBuilder.AppendLine('  end;');
      LBuilder.AppendLine;
    end;
    LBuilder.AppendLine('implementation');
    LBuilder.AppendLine;
    for LGroup in LGroups do
    begin
      LBuilder.AppendLine(
        'constructor T' + LGroup + 'Controller.Create(const AService: IApiService);'
      );
      LBuilder.AppendLine('begin');
      LBuilder.AppendLine('  inherited Create;');
      LBuilder.AppendLine('  FService := AService;');
      LBuilder.AppendLine('end;');
      LBuilder.AppendLine;
      for LEndpoint in ASpecification.Endpoints do
      begin
        if not SameText(LEndpoint.Group, LGroup) then
          Continue;
        LBuilder.AppendLine(
          'procedure T' + LGroup + 'Controller.' + LEndpoint.Name + '('
        );
        LBuilder.AppendLine('  const AContext: IHttpContext');
        LBuilder.AppendLine(');');
        LBuilder.AppendLine('begin');
        LBuilder.AppendLine(
          '  AContext.Response.Status(' + LEndpoint.StatusCode.ToString + ');'
        );
        LBuilder.AppendLine(
          '  AContext.Response.Json(FService.Execute(''' +
          LEndpoint.Name + '''));'
        );
        LBuilder.AppendLine('end;');
        LBuilder.AppendLine;
      end;
    end;
    LBuilder.AppendLine('initialization');
    for LGroup in LGroups do
      LBuilder.AppendLine('  T' + LGroup + 'Controller.ClassName;');
    LBuilder.AppendLine;
    LBuilder.AppendLine('end.');
    Result := LBuilder.ToString;
  finally
    LGroups.Free;
    LBuilder.Free;
  end;
end;

class function TRadIADextProjectRenderer.BuildDependencyInjectionUnit(
  const ASpecification: TRadIAApiSpecification
): string;
begin
  Result :=
    'unit ' + ASpecification.ProjectName + '.DependencyInjection;' + sLineBreak +
    sLineBreak + 'interface' + sLineBreak + sLineBreak + 'uses' + sLineBreak +
    '  Dext.DI.Interfaces;' + sLineBreak + sLineBreak +
    'procedure AddApplicationServices(const AServices: TDextServices);' +
    sLineBreak + sLineBreak + 'implementation' + sLineBreak + sLineBreak +
    'uses' + sLineBreak + '  Dext,' + sLineBreak + '  ' +
    ASpecification.ProjectName + '.Services;' +
    sLineBreak + sLineBreak +
    'procedure AddApplicationServices(const AServices: TDextServices);' +
    sLineBreak + 'begin' + sLineBreak +
    '  AServices.AddSingleton<IApiService, TApiService>;' + sLineBreak +
    'end;' + sLineBreak + sLineBreak + 'end.' + sLineBreak;
end;

class function TRadIADextProjectRenderer.BuildDpr(
  const ASpecification: TRadIAApiSpecification
): string;
var
  LBuilder: TStringBuilder;
begin
  LBuilder := TStringBuilder.Create;
  try
    LBuilder.AppendLine('program ' + ASpecification.ProjectName + ';');
    LBuilder.AppendLine;
    LBuilder.AppendLine('{$APPTYPE CONSOLE}');
    LBuilder.AppendLine;
    LBuilder.AppendLine('uses');
    LBuilder.AppendLine('  Dext.MM,');
    LBuilder.AppendLine('  System.SysUtils,');
    LBuilder.AppendLine('  Dext,');
    LBuilder.AppendLine('  Dext.Web,');
    LBuilder.AppendLine(
      '  ' + ASpecification.ProjectName + '.Startup in ''' +
      ASpecification.ProjectName + '.Startup.pas'','
    );
    if ASpecification.Style = asMinimal then
    begin
      LBuilder.AppendLine(
        '  ' + ASpecification.ProjectName + '.Endpoints in ''Endpoints\' +
        ASpecification.ProjectName + '.Endpoints.pas'';'
      );
    end
    else
    begin
      LBuilder.AppendLine(
        '  ' + ASpecification.ProjectName + '.Controllers in ''Controllers\' +
        ASpecification.ProjectName + '.Controllers.pas'','
      );
      LBuilder.AppendLine(
        '  ' + ASpecification.ProjectName + '.Services in ''Services\' +
        ASpecification.ProjectName + '.Services.pas'','
      );
      LBuilder.AppendLine(
        '  ' + ASpecification.ProjectName +
        '.DependencyInjection in ''Infrastructure\' +
        ASpecification.ProjectName + '.DependencyInjection.pas'';'
      );
    end;
    LBuilder.AppendLine;
    LBuilder.AppendLine('var');
    LBuilder.AppendLine('  LApplication: IWebApplication;');
    LBuilder.AppendLine('begin');
    LBuilder.AppendLine('  try');
    LBuilder.AppendLine('    LApplication := TDextApplication.Create;');
    LBuilder.AppendLine('    ConfigureApplication(LApplication);');
    LBuilder.AppendLine(
      '    LApplication.Run(' + ASpecification.Port.ToString + ');'
    );
    LBuilder.AppendLine('  except');
    LBuilder.AppendLine('    on E: Exception do');
    LBuilder.AppendLine('    begin');
    LBuilder.AppendLine('      WriteLn(E.ClassName + '': '' + E.Message);');
    LBuilder.AppendLine('      ExitCode := 1;');
    LBuilder.AppendLine('    end;');
    LBuilder.AppendLine('  end;');
    LBuilder.AppendLine('end.');
    Result := LBuilder.ToString;
  finally
    LBuilder.Free;
  end;
end;

class function TRadIADextProjectRenderer.BuildEndpointsUnit(
  const ASpecification: TRadIAApiSpecification
): string;
var
  LBuilder: TStringBuilder;
  LEndpoint: TRadIAApiEndpoint;
begin
  LBuilder := TStringBuilder.Create;
  try
    LBuilder.AppendLine('unit ' + ASpecification.ProjectName + '.Endpoints;');
    LBuilder.AppendLine;
    LBuilder.AppendLine('interface');
    LBuilder.AppendLine;
    LBuilder.AppendLine('uses');
    LBuilder.AppendLine('  Dext.Web.Interfaces;');
    LBuilder.AppendLine;
    LBuilder.AppendLine('procedure MapEndpoints(const ABuilder: IApplicationBuilder);');
    LBuilder.AppendLine;
    LBuilder.AppendLine('implementation');
    LBuilder.AppendLine;
    LBuilder.AppendLine('procedure MapEndpoints(const ABuilder: IApplicationBuilder);');
    LBuilder.AppendLine('begin');
    for LEndpoint in ASpecification.Endpoints do
    begin
      LBuilder.AppendLine(
        '  ABuilder.MapEndpoint(''' + LEndpoint.Method + ''', ''' +
        LEndpoint.Path + ''','
      );
      LBuilder.AppendLine('    procedure(AContext: IHttpContext)');
      LBuilder.AppendLine('    begin');
      LBuilder.AppendLine(
        '      AContext.Response.Status(' + LEndpoint.StatusCode.ToString + ');'
      );
      LBuilder.AppendLine(
        '      AContext.Response.Json(''' + ResponseJson(LEndpoint) + ''');'
      );
      LBuilder.AppendLine('    end');
      LBuilder.AppendLine('  );');
    end;
    LBuilder.AppendLine('end;');
    LBuilder.AppendLine;
    LBuilder.AppendLine('end.');
    Result := LBuilder.ToString;
  finally
    LBuilder.Free;
  end;
end;

class function TRadIADextProjectRenderer.BuildFiles(
  const ASpecification: TRadIAApiSpecification
): TArray<TRadIADextGeneratedFile>;
var
  LControllerPath: string;
begin
  if ASpecification.Style = asMinimal then
  begin
    SetLength(Result, 7);
    Result[2] := TRadIADextGeneratedFile.Create(
      'Endpoints\' + ASpecification.ProjectName + '.Endpoints.pas',
      BuildEndpointsUnit(ASpecification)
    );
  end
  else
  begin
    SetLength(Result, 9);
    LControllerPath := 'Controllers\' + ASpecification.ProjectName +
      '.Controllers.pas';
    Result[2] := TRadIADextGeneratedFile.Create(
      LControllerPath,
      BuildControllerUnit(ASpecification)
    );
    Result[7] := TRadIADextGeneratedFile.Create(
      'Services\' + ASpecification.ProjectName + '.Services.pas',
      BuildServicesUnit(ASpecification)
    );
    Result[8] := TRadIADextGeneratedFile.Create(
      'Infrastructure\' + ASpecification.ProjectName +
      '.DependencyInjection.pas',
      BuildDependencyInjectionUnit(ASpecification)
    );
  end;
  Result[0] := TRadIADextGeneratedFile.Create(
    ASpecification.ProjectName + '.dpr',
    BuildDpr(ASpecification)
  );
  Result[1] := TRadIADextGeneratedFile.Create(
    ASpecification.ProjectName + '.Startup.pas',
    BuildStartupUnit(ASpecification)
  );
  Result[3] := TRadIADextGeneratedFile.Create(
    'Contracts\' + ASpecification.ProjectName + '.Contracts.pas',
    'unit ' + ASpecification.ProjectName + '.Contracts;' + sLineBreak +
    sLineBreak + 'interface' + sLineBreak + sLineBreak +
    'implementation' + sLineBreak + sLineBreak + 'end.' + sLineBreak
  );
  Result[4] := TRadIADextGeneratedFile.Create(
    'appsettings.json',
    '{' + sLineBreak + '  "server": {' + sLineBreak +
    '    "port": ' + ASpecification.Port.ToString + sLineBreak +
    '  }' + sLineBreak + '}' + sLineBreak
  );
  Result[5] := TRadIADextGeneratedFile.Create(
    ASpecification.ProjectName + '.http',
    BuildHttpFile(ASpecification)
  );
  Result[6] := TRadIADextGeneratedFile.Create(
    'README.md',
    BuildReadme(ASpecification)
  );
end;

class function TRadIADextProjectRenderer.BuildServicesUnit(
  const ASpecification: TRadIAApiSpecification
): string;
begin
  Result :=
    'unit ' + ASpecification.ProjectName + '.Services;' + sLineBreak +
    sLineBreak + 'interface' + sLineBreak + sLineBreak + 'type' + sLineBreak +
    '  IApiService = interface' + sLineBreak +
    '    [''{B2D698AF-7927-4EB2-AC84-FC24C92CA52B}'']' + sLineBreak +
    '    function Execute(const AEndpointName: string): string;' + sLineBreak +
    '  end;' + sLineBreak + sLineBreak +
    '  TApiService = class(TInterfacedObject, IApiService)' + sLineBreak +
    '  public' + sLineBreak +
    '    function Execute(const AEndpointName: string): string;' + sLineBreak +
    '  end;' + sLineBreak + sLineBreak + 'implementation' + sLineBreak +
    sLineBreak + 'function TApiService.Execute(' + sLineBreak +
    '  const AEndpointName: string' + sLineBreak + '): string;' + sLineBreak +
    'begin' + sLineBreak +
    '  Result := ''{"endpoint":"'' + AEndpointName + ''","status":"ok"}'';' +
    sLineBreak + 'end;' + sLineBreak + sLineBreak + 'end.' + sLineBreak;
end;

class function TRadIADextProjectRenderer.BuildHttpFile(
  const ASpecification: TRadIAApiSpecification
): string;
var
  LBuilder: TStringBuilder;
  LEndpoint: TRadIAApiEndpoint;
begin
  LBuilder := TStringBuilder.Create;
  try
    LBuilder.AppendLine('@host = http://localhost:' + ASpecification.Port.ToString);
    LBuilder.AppendLine;
    for LEndpoint in ASpecification.Endpoints do
    begin
      LBuilder.AppendLine('### ' + LEndpoint.Name);
      LBuilder.AppendLine(LEndpoint.Method + ' {{host}}' + LEndpoint.Path);
      if MatchText(LEndpoint.Method, ['POST', 'PUT', 'PATCH']) then
      begin
        LBuilder.AppendLine('Content-Type: application/json');
        LBuilder.AppendLine;
        LBuilder.AppendLine('{}');
      end;
      LBuilder.AppendLine;
    end;
    Result := LBuilder.ToString;
  finally
    LBuilder.Free;
  end;
end;

class function TRadIADextProjectRenderer.BuildReadme(
  const ASpecification: TRadIAApiSpecification
): string;
var
  LBuilder: TStringBuilder;
  LEndpoint: TRadIAApiEndpoint;
  LStyle: string;
begin
  if ASpecification.Style = asMinimal then
    LStyle := 'Minimal API'
  else
    LStyle := 'Controllers';
  LBuilder := TStringBuilder.Create;
  try
    LBuilder.AppendLine('# ' + ASpecification.ProjectName);
    LBuilder.AppendLine;
    LBuilder.AppendLine('Generated DEXT ' + LStyle + ' server.');
    LBuilder.AppendLine;
    LBuilder.AppendLine('## Run');
    LBuilder.AppendLine;
    LBuilder.AppendLine('Build and run the project in Delphi, then use `' +
      ASpecification.ProjectName + '.http` to call the API.');
    LBuilder.AppendLine;
    LBuilder.AppendLine('Default URL: `http://localhost:' +
      ASpecification.Port.ToString + '`.');
    LBuilder.AppendLine;
    LBuilder.AppendLine('## Endpoints');
    LBuilder.AppendLine;
    for LEndpoint in ASpecification.Endpoints do
      LBuilder.AppendLine('- `' + LEndpoint.Method + ' ' + LEndpoint.Path +
        '` — ' + LEndpoint.Name);
    Result := LBuilder.ToString;
  finally
    LBuilder.Free;
  end;
end;

class function TRadIADextProjectRenderer.BuildStartupUnit(
  const ASpecification: TRadIAApiSpecification
): string;
var
  LBuilder: TStringBuilder;
begin
  LBuilder := TStringBuilder.Create;
  try
    LBuilder.AppendLine('unit ' + ASpecification.ProjectName + '.Startup;');
    LBuilder.AppendLine;
    LBuilder.AppendLine('interface');
    LBuilder.AppendLine;
    LBuilder.AppendLine('uses');
    LBuilder.AppendLine('  Dext.Web;');
    LBuilder.AppendLine;
    LBuilder.AppendLine(
      'procedure ConfigureApplication(const AApplication: IWebApplication);'
    );
    LBuilder.AppendLine;
    LBuilder.AppendLine('implementation');
    LBuilder.AppendLine;
    LBuilder.AppendLine('uses');
    if ASpecification.Style = asMinimal then
      LBuilder.AppendLine('  ' + ASpecification.ProjectName + '.Endpoints;')
    else if ASpecification.EnableSwagger then
    begin
      LBuilder.AppendLine('  Dext.OpenAPI.Generator,');
      LBuilder.AppendLine('  Dext.OpenAPI.Types,');
      LBuilder.AppendLine('  Dext.Swagger.Middleware,');
      LBuilder.AppendLine('  ' + ASpecification.ProjectName + '.DependencyInjection;');
    end
    else
      LBuilder.AppendLine('  ' + ASpecification.ProjectName + '.DependencyInjection;');
    LBuilder.AppendLine;
    LBuilder.AppendLine(
      'procedure ConfigureApplication(const AApplication: IWebApplication);'
    );
    if (ASpecification.Style = asControllers) and
      ASpecification.EnableSwagger then
    begin
      LBuilder.AppendLine('var');
      LBuilder.AppendLine('  LOptions: TOpenAPIOptions;');
    end;
    LBuilder.AppendLine('begin');
    if ASpecification.EnableLogging then
      LBuilder.AppendLine('  AApplication.Builder.UseHttpLogging;');
    if ASpecification.EnableCors then
    begin
      LBuilder.AppendLine('  AApplication.Builder.UseCors(');
      LBuilder.AppendLine(
        '    CorsOptions.AllowAnyOrigin.AllowAnyMethod.AllowAnyHeader'
      );
      LBuilder.AppendLine('  );');
    end;
    if ASpecification.Style = asMinimal then
      LBuilder.AppendLine('  MapEndpoints(AApplication.Builder);')
    else
    begin
      LBuilder.AppendLine('  AddApplicationServices(AApplication.Services);');
      LBuilder.AppendLine('  AApplication.Services.AddControllers;');
      LBuilder.AppendLine('  AApplication.MapControllers;');
      if ASpecification.EnableSwagger then
      begin
        LBuilder.AppendLine('  LOptions := TOpenAPIOptions.Default;');
        LBuilder.AppendLine(
          '  LOptions.Title := ''' + ASpecification.ProjectName + ' API'';'
        );
        LBuilder.AppendLine('  LOptions.Version := ''1.0.0'';');
        LBuilder.AppendLine(
          '  TSwaggerExtensions.UseSwagger(AApplication.Builder, LOptions);'
        );
      end;
    end;
    LBuilder.AppendLine('end;');
    LBuilder.AppendLine;
    LBuilder.AppendLine('end.');
    Result := LBuilder.ToString;
  finally
    LBuilder.Free;
  end;
end;

class function TRadIADextProjectRenderer.HttpAttribute(
  const AMethod: string
): string;
begin
  if SameText(AMethod, 'GET') then
    Exit('HttpGet');
  if SameText(AMethod, 'POST') then
    Exit('HttpPost');
  if SameText(AMethod, 'PUT') then
    Exit('HttpPut');
  if SameText(AMethod, 'PATCH') then
    Exit('HttpPatch');
  Result := 'HttpDelete';
end;

class function TRadIADextProjectRenderer.ResponseJson(
  const AEndpoint: TRadIAApiEndpoint
): string;
begin
  Result := '{"endpoint":"' + AEndpoint.Name + '","status":"ok"}';
end;

end.
