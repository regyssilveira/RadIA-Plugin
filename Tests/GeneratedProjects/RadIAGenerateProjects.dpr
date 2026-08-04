program RadIAGenerateProjects;

{$APPTYPE CONSOLE}

uses
  System.IOUtils,
  System.SysUtils,
  RadIA.Core.ProjectTemplates in
    '..\..\Source\Core\RadIA.Core.ProjectTemplates.pas',
  RadIA.Core.ProjectTransaction in
    '..\..\Source\Core\RadIA.Core.ProjectTransaction.pas';

procedure GenerateProject(
  const ARootPath: string;
  const ADelphiVersion: string;
  const AProjectName: string;
  const AKind: TRadIAProjectTemplateKind
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
    ['Win32']
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
