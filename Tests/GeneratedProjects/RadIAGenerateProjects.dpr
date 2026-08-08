program RadIAGenerateProjects;

{$APPTYPE CONSOLE}

uses
  System.IOUtils,
  System.SysUtils,
  RadIA.Core.ApiSpecifications in
    '..\..\Source\Core\RadIA.Core.ApiSpecifications.pas',
  RadIA.Core.DextProjectTemplates in
    '..\..\Source\Core\RadIA.Core.DextProjectTemplates.pas',
  RadIA.Core.ProjectTemplates in
    '..\..\Source\Core\RadIA.Core.ProjectTemplates.pas',
  RadIA.Core.ProjectTransaction in
    '..\..\Source\Core\RadIA.Core.ProjectTransaction.pas';

procedure GenerateProject(
  const ARootPath: string;
  const ADelphiVersion: string;
  const AProjectName: string;
  const AKind: TRadIAProjectTemplateKind;
  const ASpecificationJson: string = ''
);
var
  LEngine: TRadIAProjectTemplateEngine;
  LPlan: TRadIAProjectTemplatePlan;
  LRequest: TRadIAProjectTemplateRequest;
  LTransaction: TRadIAProjectTemplateTransaction;
begin
  LRequest := TRadIAProjectTemplateRequest.Create(
    AProjectName,
    AKind,
    ADelphiVersion,
    ['Win32'],
    ASpecificationJson
  );
  LEngine := TRadIAProjectTemplateEngine.Create;
  try
    LPlan := LEngine.BuildPlan(LRequest);
    try
      LTransaction := TRadIAProjectTemplateTransaction.Create;
      try
        LTransaction.Prepare(
          LPlan,
          TPath.Combine(ARootPath, AProjectName)
        );
        LTransaction.Commit;
      finally
        LTransaction.Free;
      end;
    finally
      LPlan.Free;
    end;
  finally
    LEngine.Free;
  end;
end;

procedure Run;
var
  LDelphiVersion: string;
  LRootPath: string;
begin
  if ParamCount <> 2 then
    raise EArgumentException.Create(
      'Usage: RadIAGenerateProjects <rootPath> <delphiVersion>'
    );
  LRootPath := TPath.GetFullPath(ParamStr(1));
  LDelphiVersion := ParamStr(2);
  TDirectory.CreateDirectory(LRootPath);
  GenerateProject(LRootPath, LDelphiVersion, 'ConsoleApp', ptkConsole);
  GenerateProject(LRootPath, LDelphiVersion, 'VclApp', ptkVcl);
  GenerateProject(LRootPath, LDelphiVersion, 'FmxApp', ptkFmx);
  GenerateProject(LRootPath, LDelphiVersion, 'LibraryApp', ptkLibrary);
  GenerateProject(LRootPath, LDelphiVersion, 'PackageApp', ptkPackage);
  GenerateProject(LRootPath, LDelphiVersion, 'DUnitXApp', ptkDUnitX);
  GenerateProject(LRootPath, LDelphiVersion, 'ServiceApp', ptkService);
  GenerateProject(
    LRootPath,
    LDelphiVersion,
    'DextMinimalApi',
    ptkDextMinimalApi,
    '{"schemaVersion":1,"port":8081,"enableCors":true,"endpoints":[' +
    '{"name":"Health","group":"System","method":"GET",' +
    '"path":"/health"},{"name":"SubmitReading","group":"Readings",' +
    '"method":"POST","path":"/readings","statusCode":202}]}'
  );
  GenerateProject(
    LRootPath,
    LDelphiVersion,
    'DextControllerApi',
    ptkDextControllerApi,
    '{"schemaVersion":1,"port":8082,"enableSwagger":true,' +
    '"endpoints":[{"name":"Health","group":"System",' +
    '"method":"GET","path":"/health"},{"name":"CreateBooking",' +
    '"group":"Bookings","method":"POST","path":"/bookings",' +
    '"statusCode":201}]}'
  );
end;

begin
  try
    Run;
  except
    on E: Exception do
    begin
      Writeln(E.ClassName + ': ' + E.Message);
      ExitCode := 1;
    end;
  end;
end.
