unit RadIA.Semantic.Client;

interface

type
  TRadIASemanticEngineProbe = record
  private
    FErrorMessage: string;
    FName: string;
    FProtocolVersion: string;
    FReady: Boolean;
  public
    constructor Create(
      const AReady: Boolean;
      const AName: string;
      const AProtocolVersion: string;
      const AErrorMessage: string
    );
    property ErrorMessage: string read FErrorMessage;
    property Name: string read FName;
    property ProtocolVersion: string read FProtocolVersion;
    property Ready: Boolean read FReady;
  end;

  TRadIASemanticEngineClient = class
  public
    class function DefaultExecutablePath: string; static;
    class function Probe(
      const AExecutablePath: string;
      const ATimeoutMs: Cardinal = 5000
    ): TRadIASemanticEngineProbe; static;
  end;

implementation

uses
  System.Classes,
  System.IOUtils,
  System.JSON,
  System.SyncObjs,
  System.SysUtils,
  Winapi.Windows,
  RadIA.Core.AgentExecutors,
  RadIA.Core.CliProcess;

type
  TRadIASemanticProbeState = class
  private
    FCompleted: TEvent;
    FResult: TRadIACliProcessResult;
    FStdErr: string;
    FStdOut: string;
  public
    constructor Create;
    destructor Destroy; override;
    procedure AppendError(const AText: string);
    procedure AppendOutput(const AText: string);
    procedure Complete(const AResult: TRadIACliProcessResult);
    property Completed: TEvent read FCompleted;
    property Result: TRadIACliProcessResult read FResult;
    property StdErr: string read FStdErr;
    property StdOut: string read FStdOut;
  end;

const
  CInitializeRequest = '{"id":1,"method":"initialize","params":{}}';
  CShutdownRequest = '{"id":2,"method":"shutdown","params":{}}';

{ TRadIASemanticEngineProbe }

constructor TRadIASemanticEngineProbe.Create(
  const AReady: Boolean;
  const AName: string;
  const AProtocolVersion: string;
  const AErrorMessage: string
);
begin
  FReady := AReady;
  FName := AName;
  FProtocolVersion := AProtocolVersion;
  FErrorMessage := AErrorMessage;
end;

{ TRadIASemanticProbeState }

constructor TRadIASemanticProbeState.Create;
begin
  inherited Create;
  FCompleted := TEvent.Create(nil, True, False, '');
end;

destructor TRadIASemanticProbeState.Destroy;
begin
  FCompleted.Free;
  inherited Destroy;
end;

procedure TRadIASemanticProbeState.AppendError(const AText: string);
begin
  FStdErr := FStdErr + AText;
end;

procedure TRadIASemanticProbeState.AppendOutput(const AText: string);
begin
  FStdOut := FStdOut + AText;
end;

procedure TRadIASemanticProbeState.Complete(
  const AResult: TRadIACliProcessResult
);
begin
  FResult := AResult;
  FCompleted.SetEvent;
end;

function ParseProbeOutput(
  const AOutput: string
): TRadIASemanticEngineProbe;
var
  LDocument: TJSONObject;
  LLines: TStringList;
  LResult: TJSONObject;
begin
  LLines := TStringList.Create;
  try
    LLines.Text := AOutput;
    if LLines.Count = 0 then
      Exit(TRadIASemanticEngineProbe.Create(
        False,
        '',
        '',
        'The semantic engine returned no handshake response.'
      ));
    LDocument := TJSONObject.ParseJSONValue(LLines[0]) as TJSONObject;
    try
      if not Assigned(LDocument) then
        Exit(TRadIASemanticEngineProbe.Create(
          False,
          '',
          '',
          'The semantic engine returned an invalid handshake response.'
        ));
      LResult := LDocument.GetValue<TJSONObject>('result');
      if not Assigned(LResult) then
        Exit(TRadIASemanticEngineProbe.Create(
          False,
          '',
          '',
          'The semantic engine rejected the handshake.'
        ));
      Result := TRadIASemanticEngineProbe.Create(
        LResult.GetValue<string>('protocolVersion', '') = '1.0',
        LResult.GetValue<string>('name', ''),
        LResult.GetValue<string>('protocolVersion', ''),
        ''
      );
      if not Result.Ready then
        Result := TRadIASemanticEngineProbe.Create(
          False,
          Result.Name,
          Result.ProtocolVersion,
          'The semantic engine protocol is incompatible.'
        );
    finally
      LDocument.Free;
    end;
  finally
    LLines.Free;
  end;
end;

{ TRadIASemanticEngineClient }

class function TRadIASemanticEngineClient.DefaultExecutablePath: string;
var
  LBuffer: array[0..MAX_PATH] of Char;
begin
  if GetModuleFileName(HInstance, LBuffer, Length(LBuffer)) = 0 then
    Exit('');
  Result := TPath.Combine(
    ExtractFilePath(LBuffer),
    'RadIA.Semantic.Engine.exe'
  );
end;

class function TRadIASemanticEngineClient.Probe(
  const AExecutablePath: string;
  const ATimeoutMs: Cardinal
): TRadIASemanticEngineProbe;
var
  LInput: string;
  LInvocation: TRadIACliInvocation;
  LSession: IRadIACliProcessSession;
  LState: TRadIASemanticProbeState;
begin
  if not TFile.Exists(AExecutablePath) then
    Exit(TRadIASemanticEngineProbe.Create(
      False,
      '',
      '',
      'RadIA.Semantic.Engine.exe was not found.'
    ));
  LState := TRadIASemanticProbeState.Create;
  try
    LInput := CInitializeRequest + sLineBreak + CShutdownRequest + sLineBreak;
    LInvocation := TRadIACliInvocation.Create(
      AExecutablePath,
      nil,
      ExtractFilePath(AExecutablePath),
      'jsonl'
    );
    LSession := TRadIACliProcessRunner.StartWithInput(
      LInvocation,
      LInput,
      ATimeoutMs,
      procedure(AText: string)
      begin
        LState.AppendOutput(AText);
      end,
      procedure(AText: string)
      begin
        LState.AppendError(AText);
      end,
      procedure(AResult: TRadIACliProcessResult)
      begin
        LState.Complete(AResult);
      end
    );
    if LState.Completed.WaitFor(ATimeoutMs + 1000) <> wrSignaled then
    begin
      LSession.Cancel;
      LState.Completed.WaitFor(1000);
      Exit(TRadIASemanticEngineProbe.Create(
        False,
        '',
        '',
        'The semantic engine handshake timed out.'
      ));
    end;
    if not LState.Result.Succeeded then
      Exit(TRadIASemanticEngineProbe.Create(
        False,
        '',
        '',
        Trim(LState.StdErr)
      ));
    Result := ParseProbeOutput(LState.StdOut);
  finally
    LState.Free;
  end;
end;

end.
