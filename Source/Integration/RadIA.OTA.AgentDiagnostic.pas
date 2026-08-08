unit RadIA.OTA.AgentDiagnostic;

interface

procedure StartRadIAAgentRuntimeDiagnosticIfRequested;

implementation

uses
  System.Classes,
  System.SysUtils,
  RadIA.Core.AgentDiagnostic,
  RadIA.Core.AgentResultStore,
  RadIA.Core.Container,
  RadIA.Core.Logger,
  RadIA.Core.ResultCompactor,
  RadIA.Core.Tools;

procedure StartRadIAAgentRuntimeDiagnosticIfRequested;
var
  LCheckpointDirectory: string;
  LResultCompactor: IRadIAResultCompactor;
  LResultStore: IRadIAAgentResultStore;
  LToolExecutor: IRadIAToolExecutor;
begin
  LCheckpointDirectory := Trim(
    GetEnvironmentVariable('RADIA_IDE_SMOKE_AGENT_RUNTIME')
  );
  if LCheckpointDirectory = '' then
    Exit;
  if not TRadIAContainer.TryResolve<IRadIAToolExecutor>(LToolExecutor) then
  begin
    TLogger.Log(
      'Agent runtime diagnostic failed: tool executor is unavailable.',
      'AgentDiagnostic'
    );
    Exit;
  end;
  if not TRadIAContainer.TryResolve<IRadIAResultCompactor>(LResultCompactor) or
    not TRadIAContainer.TryResolve<IRadIAAgentResultStore>(LResultStore) then
  begin
    TLogger.Log(
      'Agent runtime diagnostic failed: RTK services are unavailable.',
      'AgentDiagnostic'
    );
    Exit;
  end;
  TThread.CreateAnonymousThread(
    procedure
    begin
      TThread.Sleep(3000);
      try
        RunRadIAAgentRuntimeDiagnostic(
          LToolExecutor,
          LCheckpointDirectory,
          LResultCompactor,
          LResultStore
        );
      except
        on E: Exception do
          TLogger.Log(
            'Agent runtime diagnostic failed: ' + E.Message,
            'AgentDiagnostic'
          );
      end;
    end
  ).Start;
end;

end.
