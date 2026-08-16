unit RadIA.Tests.RuntimeVclAdapter;

interface

uses
  DUnitX.TestFramework,
  Vcl.Forms;

type
  [TestFixture]
  TTestRadIARuntimeVclAdapter = class
  private
    FRootPath: string;
    FClickObserved: Boolean;
    FForm: TForm;
    procedure ButtonClick(Sender: TObject);
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    [Test]
    procedure AcceptsBoundedDefaults;
    [Test]
    procedure RejectsAdapterFromAnotherSession;
    [Test]
    procedure AcceptsAdapterBoundToRuntimeSession;
    [Test]
    procedure LocatesSessionBoundConnectionFile;
    [Test]
    procedure ClaimsUnboundEndpointForActiveProcessSession;
    [Test]
    procedure RejectsConnectionFileForAnotherSession;
    [Test]
    procedure RejectsInvalidTransportParametersBeforeConnecting;
    [Test]
    procedure DiscoversGraphicControlWithoutWindowHandle;
    [Test]
    procedure InvokesNamedGraphicControlWithoutCoordinates;
    [Test]
    procedure PublishesAndRemovesProcessBoundEndpoint;
  end;

implementation

uses
  System.IOUtils,
  System.SysUtils,
  Winapi.Windows,
  RadIA.Core.RuntimeAutomation,
  RadIA.Core.RuntimeVclAdapter,
  RadIA.OTA.RuntimeVclTransport,
  RadIA.Runtime.VclAdapter,
  RadIA.Runtime.VclServer,
  Vcl.Buttons,
  Vcl.StdCtrls;

function CompleteSession: TRadIARuntimeSessionIdentity;
begin
  Result := TRadIARuntimeSessionIdentity.Create(
    'session-1', 42, Now, 'C:\Workspace\App.exe',
    'C:\Workspace\App.dproj', 'build-1'
  );
end;

procedure TTestRadIARuntimeVclAdapter.Setup;
var
  LButton: TSpeedButton;
  LLabel: TLabel;
begin
  FRootPath := TPath.Combine(
    TPath.GetTempPath,
    'radia-vcl-adapter-' + TGUID.NewGuid.ToString
  );
  TDirectory.CreateDirectory(FRootPath);
  FForm := TForm.Create(nil);
  FForm.Name := 'RuntimeForm';
  LLabel := TLabel.Create(FForm);
  LLabel.Name := 'StatusLabel';
  LLabel.Caption := 'Ready';
  LLabel.Parent := FForm;
  LButton := TSpeedButton.Create(FForm);
  LButton.Name := 'RunButton';
  LButton.Caption := 'Run';
  LButton.Parent := FForm;
  LButton.OnClick := ButtonClick;
  FClickObserved := False;
end;

procedure TTestRadIARuntimeVclAdapter.TearDown;
begin
  FForm.Free;
  if TDirectory.Exists(FRootPath) then
    TDirectory.Delete(FRootPath, True);
end;

procedure TTestRadIARuntimeVclAdapter.ButtonClick(Sender: TObject);
begin
  FClickObserved := Assigned(Sender);
end;

procedure TTestRadIARuntimeVclAdapter.AcceptsAdapterBoundToRuntimeSession;
var
  LIdentity: TRadIARuntimeVclAdapterIdentity;
begin
  LIdentity := TRadIARuntimeVclAdapterIdentity.Create(
    42, 'session-1', '\\.\pipe\RadIA.Runtime.42.test',
    '0123456789abcdef0123456789abcdef', 1
  );
  Assert.IsTrue(LIdentity.IsUsableFor(CompleteSession));
end;

procedure TTestRadIARuntimeVclAdapter.AcceptsBoundedDefaults;
begin
  Assert.IsTrue(TRadIARuntimeVclAdapterLimits.Defaults.IsValid);
end;

procedure TTestRadIARuntimeVclAdapter.RejectsAdapterFromAnotherSession;
var
  LIdentity: TRadIARuntimeVclAdapterIdentity;
begin
  LIdentity := TRadIARuntimeVclAdapterIdentity.Create(
    42, 'session-2', '\\.\pipe\RadIA.Runtime.42.test',
    '0123456789abcdef0123456789abcdef', 1
  );
  Assert.IsFalse(LIdentity.IsUsableFor(CompleteSession));
end;

procedure TTestRadIARuntimeVclAdapter.LocatesSessionBoundConnectionFile;
var
  LIdentity: TRadIARuntimeVclAdapterIdentity;
  LLocator: IRadIARuntimeVclEndpointLocator;
begin
  TFile.WriteAllText(
    TPath.Combine(FRootPath, '42.json'),
    '{"processId":42,"sessionId":"session-1",' +
    '"endpoint":"\\\\.\\pipe\\RadIA.Runtime.42.test",' +
    '"token":"0123456789abcdef0123456789abcdef",' +
    '"protocolVersion":1}',
    TEncoding.UTF8
  );
  LLocator := TRadIARuntimeVclEndpointLocator.Create(FRootPath);
  Assert.IsTrue(LLocator.Locate(CompleteSession, LIdentity));
  Assert.AreEqual<LongWord>(42, LIdentity.ProcessId);
end;

procedure TTestRadIARuntimeVclAdapter.
  ClaimsUnboundEndpointForActiveProcessSession;
var
  LIdentity: TRadIARuntimeVclAdapterIdentity;
  LLocator: IRadIARuntimeVclEndpointLocator;
begin
  TFile.WriteAllText(
    TPath.Combine(FRootPath, '42.json'),
    '{"processId":42,"sessionId":"",' +
    '"endpoint":"\\\\.\\pipe\\RadIA.Runtime.42.test",' +
    '"token":"0123456789abcdef0123456789abcdef",' +
    '"protocolVersion":1}',
    TEncoding.UTF8
  );
  LLocator := TRadIARuntimeVclEndpointLocator.Create(FRootPath);
  Assert.IsTrue(LLocator.Locate(CompleteSession, LIdentity));
  Assert.AreEqual('session-1', LIdentity.SessionId);
end;

procedure TTestRadIARuntimeVclAdapter.
  RejectsConnectionFileForAnotherSession;
var
  LIdentity: TRadIARuntimeVclAdapterIdentity;
  LLocator: IRadIARuntimeVclEndpointLocator;
begin
  TFile.WriteAllText(
    TPath.Combine(FRootPath, '42.json'),
    '{"processId":42,"sessionId":"session-2",' +
    '"endpoint":"\\\\.\\pipe\\RadIA.Runtime.42.test",' +
    '"token":"0123456789abcdef0123456789abcdef",' +
    '"protocolVersion":1}',
    TEncoding.UTF8
  );
  LLocator := TRadIARuntimeVclEndpointLocator.Create(FRootPath);
  Assert.IsFalse(LLocator.Locate(CompleteSession, LIdentity));
end;

procedure TTestRadIARuntimeVclAdapter.
  RejectsInvalidTransportParametersBeforeConnecting;
var
  LIdentity: TRadIARuntimeVclAdapterIdentity;
  LResult: TRadIARuntimeVclTransportResult;
  LTransport: IRadIARuntimeVclTransport;
begin
  LIdentity := TRadIARuntimeVclAdapterIdentity.Create(
    42, 'session-1', '\\.\pipe\RadIA.Runtime.42.test',
    '0123456789abcdef0123456789abcdef', 1
  );
  LTransport := TRadIARuntimeVclNamedPipeTransport.Create;
  LResult := LTransport.Send(
    LIdentity, 'discover', '{invalid',
    TRadIARuntimeVclAdapterLimits.Defaults
  );
  Assert.IsFalse(LResult.Success);
  Assert.AreEqual('runtime_vcl_invalid_parameters', LResult.ErrorCode);
end;

procedure TTestRadIARuntimeVclAdapter.
  DiscoversGraphicControlWithoutWindowHandle;
var
  LAdapter: TRadIARuntimeVclControlAdapter;
  LFound: Boolean;
  LSnapshot: TRadIARuntimeControlSnapshot;
begin
  LAdapter := TRadIARuntimeVclControlAdapter.Create;
  try
    LFound := False;
    for LSnapshot in LAdapter.Discover(
      CompleteSession,
      TRadIARuntimeVclAdapterLimits.Defaults
    ) do
      if LSnapshot.Path.EndsWith('/StatusLabel') then
      begin
        LFound := True;
        Assert.AreEqual('TLabel', LSnapshot.ClassName);
        Assert.AreEqual('Ready', LSnapshot.Text);
      end;
    Assert.IsTrue(LFound);
  finally
    LAdapter.Free;
  end;
end;

procedure TTestRadIARuntimeVclAdapter.
  InvokesNamedGraphicControlWithoutCoordinates;
var
  LAction: TRadIARuntimeScenarioAction;
  LAdapter: TRadIARuntimeVclControlAdapter;
  LResult: TRadIARuntimeActionResult;
begin
  LAction := TRadIARuntimeScenarioAction.Create(
    rakInvoke,
    TRadIARuntimeSelector.Create('', 'TSpeedButton', 'RunButton', '', ''),
    '',
    1000
  );
  LAdapter := TRadIARuntimeVclControlAdapter.Create;
  try
    LResult := LAdapter.Execute(
      CompleteSession,
      LAction,
      TRadIARuntimeVclAdapterLimits.Defaults
    );
    Assert.IsTrue(LResult.Success);
    Assert.IsTrue(FClickObserved);
  finally
    LAdapter.Free;
  end;
end;

procedure TTestRadIARuntimeVclAdapter.
  PublishesAndRemovesProcessBoundEndpoint;
var
  LIdentity: TRadIARuntimeVclAdapterIdentity;
  LLocator: IRadIARuntimeVclEndpointLocator;
  LServer: TRadIARuntimeVclServer;
  LSession: TRadIARuntimeSessionIdentity;
begin
  LSession := TRadIARuntimeSessionIdentity.Create(
    'server-test-session',
    GetCurrentProcessId,
    Now,
    ParamStr(0),
    ParamStr(0),
    'server-test-build'
  );
  LServer := TRadIARuntimeVclServer.Create;
  try
    LServer.Start;
    LLocator := TRadIARuntimeVclEndpointLocator.Create;
    Assert.IsTrue(LLocator.Locate(LSession, LIdentity));
    Assert.AreEqual(LServer.Endpoint, LIdentity.Endpoint);
  finally
    LServer.Free;
  end;
  LLocator := TRadIARuntimeVclEndpointLocator.Create;
  Assert.IsFalse(LLocator.Locate(LSession, LIdentity));
end;

initialization
  TDUnitX.RegisterTestFixture(TTestRadIARuntimeVclAdapter);

end.
