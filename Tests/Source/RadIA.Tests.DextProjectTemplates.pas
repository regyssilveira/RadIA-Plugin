unit RadIA.Tests.DextProjectTemplates;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TTestRadIADextProjectTemplates = class
  public
    [Test]
    procedure MinimalTemplateGeneratesDirectMappings;
    [Test]
    procedure ControllerTemplateGeneratesGroupedControllers;
    [Test]
    procedure TemplatePreviewChangesWithSpecification;
  end;

implementation

uses
  System.SysUtils,
  RadIA.Core.ProjectTemplates;

const
  CMinimalSpecification =
    '{"schemaVersion":1,"port":8081,"endpoints":[' +
    '{"name":"Health","group":"System","method":"GET",' +
    '"path":"/health","statusCode":200},' +
    '{"name":"SubmitReading","group":"Readings","method":"POST",' +
    '"path":"/readings","statusCode":202}]}';

function FindFile(
  const APlan: TRadIAProjectTemplatePlan;
  const APath: string
): string;
var
  LFile: TRadIAProjectTemplateFile;
begin
  for LFile in APlan.Files do
  begin
    if SameText(LFile.RelativePath, APath) then
      Exit(LFile.Content);
  end;
  Assert.Fail('Generated file not found: ' + APath);
  Result := '';
end;

procedure TTestRadIADextProjectTemplates.ControllerTemplateGeneratesGroupedControllers;
var
  LEngine: TRadIAProjectTemplateEngine;
  LPlan: TRadIAProjectTemplatePlan;
begin
  LEngine := TRadIAProjectTemplateEngine.Create;
  try
    LPlan := LEngine.BuildPlan(
      TRadIAProjectTemplateRequest.Create(
        'TelemetryApi',
        ptkDextControllerApi,
        '37.0',
        ['Win32'],
        CMinimalSpecification
      )
    );
    try
      Assert.Contains(
        FindFile(LPlan, 'Controllers\TelemetryApi.Controllers.pas'),
        'TReadingsController = class'
      );
      Assert.Contains(
        FindFile(LPlan, 'Controllers\TelemetryApi.Controllers.pas'),
        '[HttpPost(''/readings'')]'
      );
      Assert.Contains(
        FindFile(LPlan, 'TelemetryApi.Startup.pas'),
        'AApplication.Services.AddControllers'
      );
    finally
      LPlan.Free;
    end;
  finally
    LEngine.Free;
  end;
end;

procedure TTestRadIADextProjectTemplates.MinimalTemplateGeneratesDirectMappings;
var
  LEngine: TRadIAProjectTemplateEngine;
  LPlan: TRadIAProjectTemplatePlan;
begin
  LEngine := TRadIAProjectTemplateEngine.Create;
  try
    LPlan := LEngine.BuildPlan(
      TRadIAProjectTemplateRequest.Create(
        'TelemetryApi',
        ptkDextMinimalApi,
        '37.0',
        ['Win32'],
        CMinimalSpecification
      )
    );
    try
      Assert.Contains(
        FindFile(LPlan, 'Endpoints\TelemetryApi.Endpoints.pas'),
        'ABuilder.MapEndpoint(''POST'', ''/readings'''
      );
      Assert.Contains(
        FindFile(LPlan, 'TelemetryApi.dproj'),
        '$(DEXT_ROOT)\Output\37.0_$(Platform)_$(Config)'
      );
      Assert.Contains(LPlan.PreviewJson, '"template":"dext-minimal-api"');
    finally
      LPlan.Free;
    end;
  finally
    LEngine.Free;
  end;
end;

procedure TTestRadIADextProjectTemplates.TemplatePreviewChangesWithSpecification;
var
  LEngine: TRadIAProjectTemplateEngine;
  LFirst: TRadIAProjectTemplatePlan;
  LSecond: TRadIAProjectTemplatePlan;
begin
  LEngine := TRadIAProjectTemplateEngine.Create;
  try
    LFirst := LEngine.BuildPlan(
      TRadIAProjectTemplateRequest.Create(
        'DynamicApi', ptkDextMinimalApi, '37.0', ['Win32'],
        CMinimalSpecification
      )
    );
    try
      LSecond := LEngine.BuildPlan(
        TRadIAProjectTemplateRequest.Create(
          'DynamicApi', ptkDextMinimalApi, '37.0', ['Win32'],
          CMinimalSpecification.Replace('/readings', '/events')
        )
      );
      try
        Assert.AreNotEqual(LFirst.PreviewJson, LSecond.PreviewJson);
      finally
        LSecond.Free;
      end;
    finally
      LFirst.Free;
    end;
  finally
    LEngine.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestRadIADextProjectTemplates);

end.
