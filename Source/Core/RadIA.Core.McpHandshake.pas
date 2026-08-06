unit RadIA.Core.McpHandshake;

interface

type
  TRadIAMcpHandshakeResult = record
  private
    FSucceeded: Boolean;
    FProtocolVersion: string;
    FToolCount: Integer;
    FMessage: string;
  public
    constructor Create(
      const ASucceeded: Boolean;
      const AProtocolVersion: string;
      const AToolCount: Integer;
      const AMessage: string
    );
    property Succeeded: Boolean read FSucceeded;
    property ProtocolVersion: string read FProtocolVersion;
    property ToolCount: Integer read FToolCount;
    property Message: string read FMessage;
  end;

  TRadIAMcpHandshake = class
  public
    class function BuildInput: string; static;
    class function ParseOutput(
      const AOutput: string
    ): TRadIAMcpHandshakeResult; static;
  end;

implementation

uses
  System.Classes,
  System.JSON,
  System.SysUtils;

const
  CInitializeId = 1;
  CPingId = 2;
  CToolsListId = 3;
  CMcpProtocolVersion = '2025-06-18';

type
  TRadIAMcpHandshakeAccumulator = record
    HasInitialize: Boolean;
    HasPing: Boolean;
    HasTools: Boolean;
    ProtocolVersion: string;
    ToolCount: Integer;
  end;

procedure ApplyHandshakeResponse(
  const AJson: TJSONObject;
  var AAccumulator: TRadIAMcpHandshakeAccumulator
);
var
  LId: Integer;
  LResult: TJSONObject;
  LTools: TJSONArray;
begin
  LId := AJson.GetValue<Integer>('id', 0);
  if not (AJson.GetValue('result') is TJSONObject) then
    Exit;
  LResult := TJSONObject(AJson.GetValue('result'));
  case LId of
    CInitializeId:
      begin
        AAccumulator.ProtocolVersion :=
          LResult.GetValue<string>('protocolVersion', '');
        AAccumulator.HasInitialize :=
          AAccumulator.ProtocolVersion <> '';
      end;
    CPingId:
      AAccumulator.HasPing := True;
    CToolsListId:
      begin
        AAccumulator.HasTools :=
          LResult.GetValue('tools') is TJSONArray;
        if AAccumulator.HasTools then
        begin
          LTools := TJSONArray(LResult.GetValue('tools'));
          AAccumulator.ToolCount := LTools.Count;
        end;
      end;
  end;
end;

{ TRadIAMcpHandshakeResult }

constructor TRadIAMcpHandshakeResult.Create(
  const ASucceeded: Boolean;
  const AProtocolVersion: string;
  const AToolCount: Integer;
  const AMessage: string
);
begin
  FSucceeded := ASucceeded;
  FProtocolVersion := AProtocolVersion;
  FToolCount := AToolCount;
  FMessage := AMessage;
end;

{ TRadIAMcpHandshake }

class function TRadIAMcpHandshake.BuildInput: string;
begin
  Result :=
    '{"jsonrpc":"2.0","id":1,"method":"initialize","params":' +
    '{"protocolVersion":"' + CMcpProtocolVersion + '","capabilities":{},' +
    '"clientInfo":{"name":"Rad IA Diagnostics","version":"2.0.0"}}}' +
    sLineBreak +
    '{"jsonrpc":"2.0","method":"notifications/initialized","params":{}}' +
    sLineBreak +
    '{"jsonrpc":"2.0","id":2,"method":"ping","params":{}}' +
    sLineBreak +
    '{"jsonrpc":"2.0","id":3,"method":"tools/list","params":{}}' +
    sLineBreak;
end;

class function TRadIAMcpHandshake.ParseOutput(
  const AOutput: string
): TRadIAMcpHandshakeResult;
var
  LAccumulator: TRadIAMcpHandshakeAccumulator;
  LJson: TJSONObject;
  LJsonValue: TJSONValue;
  LLine: string;
  LLines: TStringList;
begin
  LAccumulator := Default(TRadIAMcpHandshakeAccumulator);
  LLines := TStringList.Create;
  try
    LLines.Text := AOutput;
    for LLine in LLines do
    begin
      if Trim(LLine) = '' then
        Continue;
      LJsonValue := TJSONObject.ParseJSONValue(LLine);
      if not (LJsonValue is TJSONObject) then
      begin
        LJsonValue.Free;
        Exit(TRadIAMcpHandshakeResult.Create(False, '', 0, 'Invalid JSON response.'));
      end;
      LJson := TJSONObject(LJsonValue);
      try
        if Assigned(LJson.GetValue('error')) then
          Exit(TRadIAMcpHandshakeResult.Create(False, '', 0, 'The MCP server returned an error.'));
        ApplyHandshakeResponse(LJson, LAccumulator);
      finally
        LJson.Free;
      end;
    end;
  finally
    LLines.Free;
  end;
  if not LAccumulator.HasInitialize or
    not LAccumulator.HasPing or
    not LAccumulator.HasTools then
    Exit(
      TRadIAMcpHandshakeResult.Create(
        False,
        LAccumulator.ProtocolVersion,
        LAccumulator.ToolCount,
        'The MCP handshake response is incomplete.'
      )
    );
  Result := TRadIAMcpHandshakeResult.Create(
    True,
    LAccumulator.ProtocolVersion,
    LAccumulator.ToolCount,
    Format(
      'Handshake succeeded with protocol %s and %d tools.',
      [LAccumulator.ProtocolVersion, LAccumulator.ToolCount]
    )
  );
end;

end.
