unit RadIA.OTA.AgentDiagnostic;

interface

procedure StartRadIAAgentRuntimeDiagnosticIfRequested;

implementation

uses
  System.Classes,
  System.SysUtils,
  RadIA.Core.AgentDiagnostic,
  RadIA.Core.Container,
  RadIA.Core.Logger,
  RadIA.Core.Tools;

procedure StartRadIAAgentRuntimeDiagnosticIfRequested;
var
  LCheckpointDirectory: string;
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
  TThread.CreateAnonymousThread(
    procedure
    begin
      TThread.Sleep(3000);
      try
        RunRadIAAgentRuntimeDiagnostic(
          LToolExecutor,
          LCheckpointDirectory
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
