unit RadIA.Core.DeclarativeWorkflowDiagnostic;

interface

uses
  RadIA.Core.Tools;

procedure RunRadIADeclarativeWorkflowDiagnostic(
  const ARegistry: IRadIAToolRegistry;
  const AExecutor: IRadIAToolExecutor;
  const AOutputDirectory: string
);

implementation

uses
  System.IOUtils,
  System.JSON,
  System.SysUtils,
  RadIA.Core.DeclarativeExtensions,
  RadIA.Core.DeclarativeTools;

const
  CDiagnosticWorkflowName = 'RadIADiagnosticInspection';
  CDiagnosticManifest =
    '{"schemaVersion":5,"id":"RadIADiagnostic","version":"1.0.0",' +
    '"permissions":["tool.workflow"],"workflows":[{' +
    '"name":"RadIADiagnosticInspection",' +
    '"description":"Exercise audited IDE diagnostics.",' +
    '"steps":[{"tool":"GetIDEState","arguments":{}},' +
    '{"tool":"GetInstallationHealth","arguments":{}}]}]}';

procedure WriteEvidence(
  const AFileName: string;
  const ADescriptor: TRadIAToolDescriptor;
  const AResult: TRadIAToolResult
);
var
  LRoot: TJSONObject;
begin
  LRoot := TJSONObject.Create;
  try
    LRoot.AddPair('schemaVersion', TJSONNumber.Create(1));
    LRoot.AddPair('manifestLoaded', TJSONBool.Create(True));
    LRoot.AddPair('workflowRegistered', TJSONBool.Create(True));
    LRoot.AddPair('workflowExecuted', TJSONBool.Create(AResult.Success));
    LRoot.AddPair('workflowName', ADescriptor.Name);
    LRoot.AddPair('risk', RadIAToolRiskName(ADescriptor.Risk));
    LRoot.AddPair(
      'timeoutMs',
      TJSONNumber.Create(Integer(ADescriptor.TimeoutMs))
    );
    LRoot.AddPair(
      'idempotent',
      TJSONBool.Create(ADescriptor.Idempotent)
    );
    LRoot.AddPair('stepCount', TJSONNumber.Create(2));
    LRoot.AddPair(
      'firstStepPresent',
      TJSONBool.Create(AResult.ContentJson.Contains('"index":1'))
    );
    LRoot.AddPair(
      'secondStepPresent',
      TJSONBool.Create(AResult.ContentJson.Contains('"index":2'))
    );
    if not AResult.Success then
    begin
      LRoot.AddPair('errorCode', AResult.ErrorCode);
      LRoot.AddPair('errorMessage', AResult.ErrorMessage);
    end;
    TFile.WriteAllText(AFileName, LRoot.ToJSON, TEncoding.UTF8);
  finally
    LRoot.Free;
  end;
end;

procedure RunRadIADeclarativeWorkflowDiagnostic(
  const ARegistry: IRadIAToolRegistry;
  const AExecutor: IRadIAToolExecutor;
  const AOutputDirectory: string
);
var
  LBinder: TRadIADeclarativeToolBinder;
  LDescriptor: TRadIAToolDescriptor;
  LEvidenceFileName: string;
  LExtensionDirectory: string;
  LManager: TRadIADeclarativeExtensionManager;
  LRequest: TRadIAToolRequest;
  LResult: TRadIAToolResult;
  LTool: IRadIATool;
begin
  if not Assigned(ARegistry) then
    raise EArgumentNilException.Create('ARegistry');
  if not Assigned(AExecutor) then
    raise EArgumentNilException.Create('AExecutor');
  if Trim(AOutputDirectory) = '' then
    raise EArgumentException.Create('Diagnostic output directory is required.');

  LExtensionDirectory := TPath.Combine(
    TPath.GetFullPath(AOutputDirectory),
    'Extensions'
  );
  ForceDirectories(LExtensionDirectory);
  TFile.WriteAllText(
    TPath.Combine(LExtensionDirectory, 'diagnostic.radia.json'),
    CDiagnosticManifest,
    TEncoding.UTF8
  );
  LManager := TRadIADeclarativeExtensionManager.Create(
    LExtensionDirectory
  );
  LBinder := TRadIADeclarativeToolBinder.Create(ARegistry, AExecutor);
  try
    LManager.Reload([]);
    if Length(LManager.GetWorkflows) <> 1 then
      raise EInvalidOpException.Create(
        'Diagnostic workflow manifest did not load.'
      );
    LBinder.Reload([], LManager.GetWorkflows);
    if not ARegistry.TryResolve(CDiagnosticWorkflowName, LTool) then
      raise EInvalidOpException.Create(
        'Diagnostic workflow was not registered.'
      );
    LDescriptor := LTool.Descriptor;
    LRequest := TRadIAToolRequest.Create(
      CDiagnosticWorkflowName,
      '{}',
      'ide-smoke-declarative-workflow',
      'ide-smoke',
      'declarative-workflow',
      '',
      'diagnostic'
    );
    LResult := AExecutor.Execute(LRequest);
    LEvidenceFileName := TPath.Combine(
      TPath.GetFullPath(AOutputDirectory),
      'declarative-workflow.json'
    );
    WriteEvidence(LEvidenceFileName, LDescriptor, LResult);
  finally
    LBinder.Free;
    LManager.Free;
  end;
end;

end.
