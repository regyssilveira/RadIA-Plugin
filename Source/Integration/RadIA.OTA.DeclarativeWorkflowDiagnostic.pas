unit RadIA.OTA.DeclarativeWorkflowDiagnostic;

interface

procedure StartRadIADeclarativeWorkflowDiagnosticIfRequested;

implementation

uses
  System.Classes,
  System.SysUtils,
  RadIA.Core.Container,
  RadIA.Core.DeclarativeWorkflowDiagnostic,
  RadIA.Core.Logger,
  RadIA.Core.Tools;

procedure StartRadIADeclarativeWorkflowDiagnosticIfRequested;
var
  LExecutor: IRadIAToolExecutor;
  LOutputDirectory: string;
  LRegistry: IRadIAToolRegistry;
begin
  LOutputDirectory := Trim(
    GetEnvironmentVariable('RADIA_IDE_SMOKE_DECLARATIVE_WORKFLOW')
  );
  if LOutputDirectory = '' then
    Exit;
  if not TRadIAContainer.TryResolve<IRadIAToolRegistry>(LRegistry) or
    not TRadIAContainer.TryResolve<IRadIAToolExecutor>(LExecutor) then
  begin
    TLogger.Log(
      'Declarative workflow diagnostic services are unavailable.',
      'DeclarativeWorkflowDiagnostic'
    );
    Exit;
  end;
  TThread.CreateAnonymousThread(
    procedure
    begin
      TThread.Sleep(3000);
      try
        RunRadIADeclarativeWorkflowDiagnostic(
          LRegistry,
          LExecutor,
          LOutputDirectory
        );
      except
        on E: Exception do
          TLogger.Log(
            'Declarative workflow diagnostic failed: ' + E.Message,
            'DeclarativeWorkflowDiagnostic'
          );
      end;
    end
  ).Start;
end;

end.
