unit RadIA.Tests.SemanticClient;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TRadIASemanticClientTests = class
  public
    [Test]
    procedure ProbeAcceptsPackagedEngine;
    [Test]
    procedure ProbeReportsMissingEngine;
    [Test]
    procedure DefaultPathUsesPackageDirectory;
    [Test]
    procedure SupervisorKeepsEngineAliveAcrossRequests;
    [Test]
    procedure SupervisorRecoversAfterPackagedEngineCrash;
    [Test]
    procedure SupervisorRestartsAfterTransportFailure;
    [Test]
    procedure SupervisorOpensCircuitAfterRepeatedFailures;
    [Test]
    procedure SupervisorBoundsHungRequests;
    [Test]
    procedure SupervisorRejectsIncompatibleProtocol;
    [Test]
    procedure SupervisorCancelsPendingRequest;
    [Test]
    procedure SupervisorIndexesAndInvalidatesUnits;
    [Test]
    procedure SupervisorFindsReferencesByStableIdentity;
    [Test]
    procedure SupervisorPreparesMissingMembersIdempotently;
  end;

implementation

uses
  System.Diagnostics,
  System.IOUtils,
  System.JSON,
  System.SysUtils,
  Winapi.Windows,
  RadIA.Core.ExternalMcp,
  RadIA.Core.ExternalMcpTransport,
  RadIA.Semantic.Client;

function EncodeJsonString(const AValue: string): string;
var
  LValue: TJSONString;
begin
  LValue := TJSONString.Create(AValue);
  try
    Result := LValue.ToJSON;
  finally
    LValue.Free;
  end;
end;

type
  TRadIAFailOnceSemanticTransport = class(
    TInterfacedObject,
    IRadIAExternalMcpTransport
  )
  private
    FLastError: string;
    FResponse: string;
    FRunning: Boolean;
    FStartCount: Integer;
  public
    function GetLastError: string;
    function GetRunning: Boolean;
    function Receive(
      const ATimeoutMs: Cardinal;
      out AMessage: string
    ): Boolean;
    function Send(const AMessage: string): Boolean;
    function Start(
      const AConfig: TRadIAExternalMcpServerConfig;
      out AError: string
    ): Boolean;
    procedure Stop;
  end;

  TRadIACancellableSemanticTransport = class(
    TInterfacedObject,
    IRadIAExternalMcpTransport
  )
  private
    FLastError: string;
    FInvalidProtocol: Boolean;
    FReceiveCount: Integer;
    FResponse: string;
    FRunning: Boolean;
  public
    function GetLastError: string;
    function GetRunning: Boolean;
    function Receive(
      const ATimeoutMs: Cardinal;
      out AMessage: string
    ): Boolean;
    function Send(const AMessage: string): Boolean;
    function Start(
      const AConfig: TRadIAExternalMcpServerConfig;
      out AError: string
    ): Boolean;
    procedure Stop;
    procedure UseInvalidProtocol;
    property ReceiveCount: Integer read FReceiveCount;
  end;

  TRadIAFailingSemanticTransport = class(
    TInterfacedObject,
    IRadIAExternalMcpTransport
  )
  private
    FLastError: string;
    FResponse: string;
    FRunning: Boolean;
    FStartCount: Integer;
  public
    function GetLastError: string;
    function GetRunning: Boolean;
    function Receive(
      const ATimeoutMs: Cardinal;
      out AMessage: string
    ): Boolean;
    function Send(const AMessage: string): Boolean;
    function Start(
      const AConfig: TRadIAExternalMcpServerConfig;
      out AError: string
    ): Boolean;
    procedure Stop;
    property StartCount: Integer read FStartCount;
  end;

function TRadIACancellableSemanticTransport.GetLastError: string;
begin
  Result := FLastError;
end;

function TRadIACancellableSemanticTransport.GetRunning: Boolean;
begin
  Result := FRunning;
end;

function TRadIACancellableSemanticTransport.Receive(
  const ATimeoutMs: Cardinal;
  out AMessage: string
): Boolean;
begin
  Inc(FReceiveCount);
  AMessage := FResponse;
  FResponse := '';
  Result := AMessage <> '';
end;

function TRadIACancellableSemanticTransport.Send(
  const AMessage: string
): Boolean;
begin
  if AMessage.Contains('"method":"initialize"') then
    if FInvalidProtocol then
      FResponse :=
        '{"id":0,"result":{"name":"RadIA Semantic Engine",' +
        '"protocolVersion":"999.0"}}'
    else
      FResponse :=
        '{"id":0,"result":{"name":"RadIA Semantic Engine",' +
        '"protocolVersion":"1.0"}}';
  Result := True;
end;

function TRadIACancellableSemanticTransport.Start(
  const AConfig: TRadIAExternalMcpServerConfig;
  out AError: string
): Boolean;
begin
  FLastError := '';
  FRunning := True;
  AError := '';
  Result := True;
end;

procedure TRadIACancellableSemanticTransport.Stop;
begin
  FRunning := False;
end;

procedure TRadIACancellableSemanticTransport.UseInvalidProtocol;
begin
  FInvalidProtocol := True;
end;

procedure TRadIASemanticClientTests.SupervisorRecoversAfterPackagedEngineCrash;
var
  LDocument: TJSONObject;
  LError: string;
  LPath: string;
  LProcess: THandle;
  LProcessId: Cardinal;
  LResponse: string;
  LResult: TJSONObject;
  LSupervisor: TRadIASemanticEngineSupervisor;
begin
  LPath := TPath.Combine(
    ExtractFilePath(ParamStr(0)),
    'RadIA.Semantic.Engine.exe'
  );
  LSupervisor := TRadIASemanticEngineSupervisor.Create(LPath, 2000);
  try
    Assert.IsTrue(
      LSupervisor.Request('indexStatus', '{}', LResponse, LError),
      LError
    );
    LDocument := TJSONObject.ParseJSONValue(LResponse) as TJSONObject;
    try
      Assert.IsNotNull(LDocument);
      LResult := LDocument.GetValue<TJSONObject>('result');
      Assert.IsNotNull(LResult);
      LProcessId := LResult.GetValue<Cardinal>('processId', 0);
      Assert.IsTrue(LProcessId > 0);
    finally
      LDocument.Free;
    end;
    LProcess := OpenProcess(
      PROCESS_TERMINATE or SYNCHRONIZE,
      False,
      LProcessId
    );
    Assert.IsTrue(LProcess <> 0);
    try
      Assert.IsTrue(TerminateProcess(LProcess, 197));
      Assert.AreEqual(
        Cardinal(WAIT_OBJECT_0),
        WaitForSingleObject(LProcess, 2000)
      );
    finally
      CloseHandle(LProcess);
    end;
    Assert.IsTrue(
      LSupervisor.Request(
        'tokenize',
        '{"source":"unit Recovered;"}',
        LResponse,
        LError
      ),
      LError
    );
    Assert.Contains(LResponse, '"tokens"');
    Assert.AreEqual(1, LSupervisor.RestartCount);
  finally
    LSupervisor.Free;
  end;
end;

function TRadIAFailingSemanticTransport.GetLastError: string;
begin
  Result := FLastError;
end;

function TRadIAFailingSemanticTransport.GetRunning: Boolean;
begin
  Result := FRunning;
end;

function TRadIAFailingSemanticTransport.Receive(
  const ATimeoutMs: Cardinal;
  out AMessage: string
): Boolean;
begin
  AMessage := FResponse;
  FResponse := '';
  Result := AMessage <> '';
end;

function TRadIAFailingSemanticTransport.Send(
  const AMessage: string
): Boolean;
begin
  if AMessage.Contains('"method":"initialize"') then
  begin
    FResponse :=
      '{"id":0,"result":{"name":"RadIA Semantic Engine",' +
      '"protocolVersion":"1.0"}}';
    Exit(True);
  end;
  FLastError := 'Simulated persistent process failure.';
  FRunning := False;
  Result := False;
end;

function TRadIAFailingSemanticTransport.Start(
  const AConfig: TRadIAExternalMcpServerConfig;
  out AError: string
): Boolean;
begin
  Inc(FStartCount);
  FLastError := '';
  FRunning := True;
  AError := '';
  Result := True;
end;

procedure TRadIAFailingSemanticTransport.Stop;
begin
  FRunning := False;
end;

function TRadIAFailOnceSemanticTransport.GetLastError: string;
begin
  Result := FLastError;
end;

function TRadIAFailOnceSemanticTransport.GetRunning: Boolean;
begin
  Result := FRunning;
end;

function TRadIAFailOnceSemanticTransport.Receive(
  const ATimeoutMs: Cardinal;
  out AMessage: string
): Boolean;
begin
  AMessage := FResponse;
  FResponse := '';
  Result := AMessage <> '';
end;

function TRadIAFailOnceSemanticTransport.Send(
  const AMessage: string
): Boolean;
begin
  if AMessage.Contains('"method":"initialize"') then
  begin
    FResponse :=
      '{"id":0,"result":{"name":"RadIA Semantic Engine",' +
      '"protocolVersion":"1.0"}}';
    Exit(True);
  end;
  if FStartCount = 1 then
  begin
    FLastError := 'Simulated process failure.';
    FRunning := False;
    Exit(False);
  end;
  FResponse := '{"id":1,"result":{"tokens":[]}}';
  Result := True;
end;

function TRadIAFailOnceSemanticTransport.Start(
  const AConfig: TRadIAExternalMcpServerConfig;
  out AError: string
): Boolean;
begin
  Inc(FStartCount);
  FLastError := '';
  FRunning := True;
  AError := '';
  Result := True;
end;

procedure TRadIAFailOnceSemanticTransport.Stop;
begin
  FRunning := False;
end;

procedure TRadIASemanticClientTests.ProbeAcceptsPackagedEngine;
var
  LPath: string;
  LResult: TRadIASemanticEngineProbe;
begin
  LPath := TPath.Combine(
    ExtractFilePath(ParamStr(0)),
    'RadIA.Semantic.Engine.exe'
  );
  LResult := TRadIASemanticEngineClient.Probe(LPath);
  Assert.IsTrue(LResult.Ready, LResult.ErrorMessage);
  Assert.AreEqual('RadIA Semantic Engine', LResult.Name);
  Assert.AreEqual('1.0', LResult.ProtocolVersion);
end;

procedure TRadIASemanticClientTests.ProbeReportsMissingEngine;
var
  LResult: TRadIASemanticEngineProbe;
begin
  LResult := TRadIASemanticEngineClient.Probe(
    TPath.Combine(TPath.GetTempPath, 'missing-semantic-engine.exe')
  );
  Assert.IsFalse(LResult.Ready);
  Assert.IsTrue(LResult.ErrorMessage.Contains('was not found'));
end;

procedure TRadIASemanticClientTests.SupervisorKeepsEngineAliveAcrossRequests;
var
  LError: string;
  LPath: string;
  LResponse: string;
  LSupervisor: TRadIASemanticEngineSupervisor;
begin
  LPath := TPath.Combine(
    ExtractFilePath(ParamStr(0)),
    'RadIA.Semantic.Engine.exe'
  );
  LSupervisor := TRadIASemanticEngineSupervisor.Create(LPath);
  try
    Assert.IsTrue(
      LSupervisor.Request(
        'tokenize',
        '{"source":"unit Sample;"}',
        LResponse,
        LError
      ),
      LError
    );
    Assert.Contains(LResponse, '"tokens"');
    Assert.IsTrue(
      LSupervisor.Request(
        'preprocess',
        '{"source":"{$IFDEF DEBUG}On{$ENDIF}","defines":["DEBUG"]}',
        LResponse,
        LError
      ),
      LError
    );
    Assert.Contains(LResponse, '"activity":"active"');
    Assert.IsTrue(
      LSupervisor.Request(
        'parse',
        '{"source":"unit ProtocolSample; interface implementation end."}',
        LResponse,
        LError
      ),
      LError
    );
    Assert.Contains(LResponse, '"name":"ProtocolSample"');
    Assert.AreEqual(0, LSupervisor.RestartCount);
  finally
    LSupervisor.Free;
  end;
end;

procedure TRadIASemanticClientTests.SupervisorRestartsAfterTransportFailure;
var
  LDiagnostics: TJSONObject;
  LError: string;
  LPath: string;
  LResponse: string;
  LSupervisor: TRadIASemanticEngineSupervisor;
  LTransport: IRadIAExternalMcpTransport;
begin
  LPath := TPath.Combine(
    ExtractFilePath(ParamStr(0)),
    'RadIA.Semantic.Engine.exe'
  );
  LTransport := TRadIAFailOnceSemanticTransport.Create;
  LSupervisor := TRadIASemanticEngineSupervisor.Create(
    LPath,
    5000,
    LTransport
  );
  try
    Assert.IsTrue(
      LSupervisor.Request('tokenize', '{"source":""}', LResponse, LError),
      LError
    );
    Assert.Contains(LResponse, '"tokens"');
    Assert.AreEqual(1, LSupervisor.RestartCount);
    LDiagnostics := TJSONObject.ParseJSONValue(
      LSupervisor.GetDiagnosticsJson
    ) as TJSONObject;
    try
      Assert.AreEqual(1, LDiagnostics.GetValue<Integer>('requestCount'));
      Assert.AreEqual(0, LDiagnostics.GetValue<Integer>('failureCount'));
      Assert.AreEqual(1, LDiagnostics.GetValue<Integer>('restartCount'));
      Assert.IsFalse(LDiagnostics.GetValue<Boolean>('circuitOpen'));
    finally
      LDiagnostics.Free;
    end;
  finally
    LSupervisor.Free;
  end;
end;

procedure TRadIASemanticClientTests.SupervisorBoundsHungRequests;
var
  LElapsed: TStopwatch;
  LError: string;
  LPath: string;
  LResponse: string;
  LSupervisor: TRadIASemanticEngineSupervisor;
  LTransport: IRadIAExternalMcpTransport;
begin
  LPath := TPath.Combine(
    ExtractFilePath(ParamStr(0)),
    'RadIA.Semantic.Engine.exe'
  );
  LTransport := TRadIACancellableSemanticTransport.Create;
  LSupervisor := TRadIASemanticEngineSupervisor.Create(
    LPath,
    50,
    LTransport
  );
  try
    LElapsed := TStopwatch.StartNew;
    Assert.IsFalse(
      LSupervisor.Request('tokenize', '{}', LResponse, LError)
    );
    LElapsed.Stop;
    Assert.Contains(LError, 'timed out');
    Assert.IsTrue(LElapsed.ElapsedMilliseconds < 1000);
    Assert.AreEqual(1, LSupervisor.RestartCount);
  finally
    LSupervisor.Free;
  end;
end;

procedure TRadIASemanticClientTests.SupervisorRejectsIncompatibleProtocol;
var
  LError: string;
  LPath: string;
  LResponse: string;
  LSupervisor: TRadIASemanticEngineSupervisor;
  LTransport: IRadIAExternalMcpTransport;
  LTransportObject: TRadIACancellableSemanticTransport;
begin
  LPath := TPath.Combine(
    ExtractFilePath(ParamStr(0)),
    'RadIA.Semantic.Engine.exe'
  );
  LTransportObject := TRadIACancellableSemanticTransport.Create;
  LTransportObject.UseInvalidProtocol;
  LTransport := LTransportObject;
  LSupervisor := TRadIASemanticEngineSupervisor.Create(
    LPath,
    50,
    LTransport
  );
  try
    Assert.IsFalse(
      LSupervisor.Request('tokenize', '{}', LResponse, LError)
    );
    Assert.Contains(LError, 'protocol is incompatible');
    Assert.AreEqual(1, LSupervisor.RestartCount);
  finally
    LSupervisor.Free;
  end;
end;

procedure TRadIASemanticClientTests.
  SupervisorOpensCircuitAfterRepeatedFailures;
var
  LDiagnostics: TJSONObject;
  LError: string;
  LPath: string;
  LResponse: string;
  LSupervisor: TRadIASemanticEngineSupervisor;
  LTransport: IRadIAExternalMcpTransport;
  LTransportObject: TRadIAFailingSemanticTransport;
begin
  LPath := TPath.Combine(
    ExtractFilePath(ParamStr(0)),
    'RadIA.Semantic.Engine.exe'
  );
  LTransportObject := TRadIAFailingSemanticTransport.Create;
  LTransport := LTransportObject;
  LSupervisor := TRadIASemanticEngineSupervisor.Create(
    LPath,
    5000,
    LTransport
  );
  try
    Assert.IsFalse(LSupervisor.Request('tokenize', '{}', LResponse, LError));
    Assert.IsFalse(LSupervisor.Request('tokenize', '{}', LResponse, LError));
    Assert.IsFalse(LSupervisor.Request('tokenize', '{}', LResponse, LError));
    Assert.AreEqual(6, LTransportObject.StartCount);
    Assert.IsFalse(LSupervisor.Request('tokenize', '{}', LResponse, LError));
    Assert.Contains(LError, 'bounded fallback');
    Assert.AreEqual(6, LTransportObject.StartCount);
    LDiagnostics := TJSONObject.ParseJSONValue(
      LSupervisor.GetDiagnosticsJson
    ) as TJSONObject;
    try
      Assert.AreEqual(4, LDiagnostics.GetValue<Integer>('requestCount'));
      Assert.AreEqual(3, LDiagnostics.GetValue<Integer>('failureCount'));
      Assert.AreEqual(3, LDiagnostics.GetValue<Integer>('restartCount'));
      Assert.IsTrue(LDiagnostics.GetValue<Boolean>('circuitOpen'));
      Assert.Contains(
        LDiagnostics.GetValue<string>('lastError'),
        'bounded fallback'
      );
    finally
      LDiagnostics.Free;
    end;
  finally
    LSupervisor.Free;
  end;
end;

procedure TRadIASemanticClientTests.SupervisorCancelsPendingRequest;
var
  LError: string;
  LPath: string;
  LResponse: string;
  LSupervisor: TRadIASemanticEngineSupervisor;
  LTransport: IRadIAExternalMcpTransport;
  LTransportObject: TRadIACancellableSemanticTransport;
begin
  LPath := TPath.Combine(
    ExtractFilePath(ParamStr(0)),
    'RadIA.Semantic.Engine.exe'
  );
  LTransportObject := TRadIACancellableSemanticTransport.Create;
  LTransport := LTransportObject;
  LSupervisor := TRadIASemanticEngineSupervisor.Create(
    LPath,
    5000,
    LTransport
  );
  try
    Assert.IsFalse(LSupervisor.RequestCancelable(
      'completeResolvedMembers',
      '{"container":"TForm","prefix":"Sa"}',
      function: Boolean
      begin
        Result := LTransportObject.ReceiveCount >= 3;
      end,
      LResponse,
      LError
    ));
    Assert.Contains(LError, 'cancelled');
    Assert.IsFalse(LTransportObject.GetRunning);
  finally
    LSupervisor.Free;
  end;
end;

procedure TRadIASemanticClientTests.SupervisorIndexesAndInvalidatesUnits;
var
  LError: string;
  LPath: string;
  LResponse: string;
  LSupervisor: TRadIASemanticEngineSupervisor;
begin
  LPath := TPath.Combine(
    ExtractFilePath(ParamStr(0)),
    'RadIA.Semantic.Engine.exe'
  );
  LSupervisor := TRadIASemanticEngineSupervisor.Create(LPath);
  try
    Assert.IsTrue(LSupervisor.Request(
      'indexUnit',
      '{"unitKey":"sample","fileName":"Sample.pas",' +
      '"scope":"project","revision":1,"source":' +
      '"unit Sample; interface type TBaseWorker = class ' +
      'procedure Reset; end; TWorker = class(TBaseWorker) ' +
      'procedure Execute; end; implementation end."}',
      LResponse,
      LError
    ), LError);
    Assert.Contains(LResponse, '"changed":true');
    Assert.IsTrue(LSupervisor.Request(
      'findMembers',
      '{"container":"TWorker"}',
      LResponse,
      LError
    ), LError);
    Assert.Contains(LResponse, '"name":"Execute"');
    Assert.IsTrue(LSupervisor.Request(
      'findResolvedMembers',
      '{"container":"TWorker"}',
      LResponse,
      LError
    ), LError);
    Assert.Contains(LResponse, '"name":"Reset"');
    Assert.IsTrue(LSupervisor.Request(
      'removeUnit',
      '{"unitKey":"sample"}',
      LResponse,
      LError
    ), LError);
    Assert.Contains(LResponse, '"symbolCount":0');
  finally
    LSupervisor.Free;
  end;
end;

procedure TRadIASemanticClientTests.
  SupervisorFindsReferencesByStableIdentity;
var
  LDocument: TJSONObject;
  LError: string;
  LPath: string;
  LResponse: string;
  LResult: TJSONObject;
  LSymbolId: string;
  LSymbols: TJSONArray;
  LSupervisor: TRadIASemanticEngineSupervisor;
begin
  LPath := TPath.Combine(
    ExtractFilePath(ParamStr(0)),
    'RadIA.Semantic.Engine.exe'
  );
  LSupervisor := TRadIASemanticEngineSupervisor.Create(LPath);
  try
    Assert.IsTrue(LSupervisor.Request(
      'indexUnit',
      '{"unitKey":"sample","fileName":"Sample.pas",' +
      '"scope":"project","revision":1,"source":' +
      '"unit Sample; interface type TWorker = class end; ' +
      'implementation procedure Use(AWorker: TWorker); begin end; end."}',
      LResponse,
      LError
    ), LError);
    Assert.IsTrue(LSupervisor.Request(
      'findSymbols',
      '{"name":"TWorker"}',
      LResponse,
      LError
    ), LError);
    LDocument := TJSONObject.ParseJSONValue(LResponse) as TJSONObject;
    try
      LResult := LDocument.GetValue<TJSONObject>('result');
      LSymbols := LResult.GetValue<TJSONArray>('symbols');
      LSymbolId := (LSymbols[0] as TJSONObject).GetValue<string>('symbolId');
    finally
      LDocument.Free;
    end;
    Assert.IsTrue(LSupervisor.Request(
      'findReferences',
      '{"symbolId":' + EncodeJsonString(LSymbolId) + '}',
      LResponse,
      LError
    ), LError);
    Assert.Contains(LResponse, '"status":"resolved"');
    Assert.Contains(LResponse, '"referenceCount":2');
    Assert.Contains(LResponse, '"kind":"declaration"');
    Assert.Contains(LResponse, '"kind":"exact"');
  finally
    LSupervisor.Free;
  end;
end;

procedure TRadIASemanticClientTests.
  SupervisorPreparesMissingMembersIdempotently;
const
  CContractSource =
    'unit Contracts; interface type IWorker = interface ' +
    'procedure Execute(const AValue: Integer); function Ready: Boolean; ' +
    'end; implementation end.';
  CWorkerSource =
    'unit Worker; interface uses Contracts; type TWorker = ' +
    'class(TInterfacedObject, IWorker) end; implementation end.';
var
  LDocument: TJSONObject;
  LError: string;
  LParameters: TJSONObject;
  LPath: string;
  LProposedSource: string;
  LResponse: string;
  LResult: TJSONObject;
  LSupervisor: TRadIASemanticEngineSupervisor;
begin
  LPath := TPath.Combine(
    ExtractFilePath(ParamStr(0)),
    'RadIA.Semantic.Engine.exe'
  );
  LSupervisor := TRadIASemanticEngineSupervisor.Create(LPath);
  try
    Assert.IsTrue(LSupervisor.Request(
      'indexUnit',
      '{"unitKey":"contracts","fileName":"Contracts.pas",' +
      '"scope":"group","revision":1,"source":' +
      EncodeJsonString(CContractSource) + '}',
      LResponse,
      LError
    ), LError);
    Assert.IsTrue(LSupervisor.Request(
      'indexUnit',
      '{"unitKey":"worker","fileName":"Worker.pas",' +
      '"scope":"project","revision":1,"source":' +
      EncodeJsonString(CWorkerSource) + '}',
      LResponse,
      LError
    ), LError);
    LParameters := TJSONObject.Create;
    try
      LParameters.AddPair('source', CWorkerSource);
      LParameters.AddPair('container', 'TWorker');
      LParameters.AddPair('defines', TJSONArray.Create);
      Assert.IsTrue(LSupervisor.Request(
        'prepareMissingMembers',
        LParameters.ToJSON,
        LResponse,
        LError
      ), LError);
    finally
      LParameters.Free;
    end;
    LDocument := TJSONObject.ParseJSONValue(LResponse) as TJSONObject;
    try
      Assert.IsNotNull(LDocument);
      LResult := LDocument.GetValue<TJSONObject>('result');
      Assert.IsTrue(LResult.GetValue<Boolean>('changed'));
      Assert.AreEqual(2, LResult.GetValue<Integer>('missingCount'));
      LProposedSource := LResult.GetValue<string>('proposedSource');
      Assert.Contains(LProposedSource, 'procedure TWorker.Execute');
      Assert.Contains(LProposedSource, 'function TWorker.Ready');
    finally
      LDocument.Free;
    end;
    LParameters := TJSONObject.Create;
    try
      LParameters.AddPair('source', LProposedSource);
      LParameters.AddPair('container', 'TWorker');
      LParameters.AddPair('defines', TJSONArray.Create);
      Assert.IsTrue(LSupervisor.Request(
        'indexUnit',
        '{"unitKey":"worker","fileName":"Worker.pas",' +
        '"scope":"project","revision":2,"source":' +
        EncodeJsonString(LProposedSource) + '}',
        LResponse,
        LError
      ), LError);
      Assert.IsTrue(LSupervisor.Request(
        'prepareMissingMembers',
        LParameters.ToJSON,
        LResponse,
        LError
      ), LError);
    finally
      LParameters.Free;
    end;
    Assert.Contains(LResponse, '"changed":false');
    Assert.Contains(LResponse, '"missingCount":0');
  finally
    LSupervisor.Free;
  end;
end;

procedure TRadIASemanticClientTests.DefaultPathUsesPackageDirectory;
begin
  Assert.IsTrue(
    TRadIASemanticEngineClient.DefaultExecutablePath.EndsWith(
      'RadIA.Semantic.Engine.exe'
    )
  );
end;

initialization
  TDUnitX.RegisterTestFixture(TRadIASemanticClientTests);

end.
