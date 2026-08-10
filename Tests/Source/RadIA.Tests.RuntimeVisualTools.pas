unit RadIA.Tests.RuntimeVisualTools;

interface

uses
  DUnitX.TestFramework,
  RadIA.Core.RuntimeAutomation,
  RadIA.Core.RuntimeDebugSession,
  RadIA.Core.Tools,
  RadIA.Core.VisualRuntimeSession;

type
  TRadIAFakeRuntimeVisualCaptureFacade = class(
    TInterfacedObject,
    IRadIARuntimeVisualCaptureFacade
  )
  public
    function CaptureWindow(
      const ASession: TRadIARuntimeSessionIdentity;
      const AWindowId: string;
      const APhase: TRadIAVisualCapturePhase
    ): TRadIAVisualCapture;
  end;

  [TestFixture]
  TRadIARuntimeVisualToolsTests = class
  private
    FCoordinator: IRadIARuntimeDebugSessionCoordinator;
    FRegistry: IRadIAToolRegistry;
    FVisualSession: IRadIAVisualRuntimeSession;
    function ExecuteCapture(const APhase: string): TRadIAToolResult;
  public
    [Setup]
    procedure Setup;
    [Test]
    procedure CapturesBeforeAndAfterIntoOneSession;
    [Test]
    procedure RequiresAnActiveRuntimeDebugSession;
    [Test]
    procedure CaptureIsSensitiveAndAlwaysRequiresConsent;
  end;

implementation

uses
  System.DateUtils,
  System.SysUtils,
  RadIA.Core.RuntimeVisualTools,
  RadIA.Core.ToolRegistry;

const
  CWindowId =
    '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef';

function TRadIAFakeRuntimeVisualCaptureFacade.CaptureWindow(
  const ASession: TRadIARuntimeSessionIdentity;
  const AWindowId: string;
  const APhase: TRadIAVisualCapturePhase
): TRadIAVisualCapture;
var
  LBytes: TArray<Byte>;
begin
  LBytes := [137, 80, 78, 71];
  Result := TRadIAVisualCapture.Create(
    TGUID.NewGuid.ToString,
    ASession.ProcessId,
    AWindowId,
    APhase,
    TRadIAVisualCaptureContent.Create('image/png', 640, 480, LBytes),
    TTimeZone.Local.ToUniversalTime(Now)
  );
end;

procedure TRadIARuntimeVisualToolsTests.
  CaptureIsSensitiveAndAlwaysRequiresConsent;
var
  LDescriptor: TRadIAToolDescriptor;
begin
  LDescriptor := FRegistry.Resolve('CaptureRuntimeVisual').Descriptor;
  Assert.AreEqual(trSensitive, LDescriptor.Risk);
  Assert.IsTrue(LDescriptor.ConsentEveryTime);
  Assert.IsFalse(LDescriptor.Idempotent);
end;

procedure TRadIARuntimeVisualToolsTests.
  CapturesBeforeAndAfterIntoOneSession;
var
  LResult: TRadIAToolResult;
  LSessionId: string;
  LSnapshot: TRadIAVisualSessionSnapshot;
begin
  LSessionId := FCoordinator.BeginSession('C:\Tests\RuntimeLab.dproj');
  Assert.IsTrue(FCoordinator.AttachProcess(
    LSessionId,
    42,
    EncodeDateTime(2026, 8, 10, 12, 0, 0, 0),
    'C:\Tests\RuntimeLab.exe',
    'build-1'
  ));
  LResult := ExecuteCapture('before');
  Assert.IsTrue(LResult.Success, LResult.ErrorMessage);
  Assert.Contains(LResult.ContentJson, '"phase":"before"');
  LResult := ExecuteCapture('after');
  Assert.IsTrue(LResult.Success, LResult.ErrorMessage);
  Assert.IsTrue(FVisualSession.TryGetSnapshot(LSnapshot));
  Assert.AreEqual(vssCompleted, LSnapshot.State);
  Assert.AreEqual<Integer>(2, Length(LSnapshot.Captures));
  Assert.AreEqual(vcpBefore, LSnapshot.Captures[0].Phase);
  Assert.AreEqual(vcpAfter, LSnapshot.Captures[1].Phase);
end;

function TRadIARuntimeVisualToolsTests.ExecuteCapture(
  const APhase: string
): TRadIAToolResult;
begin
  Result := FRegistry.Resolve('CaptureRuntimeVisual').Execute(
    TRadIAToolRequest.Create(
      'CaptureRuntimeVisual',
      Format('{"windowId":"%s","phase":"%s"}', [CWindowId, APhase]),
      TGUID.NewGuid.ToString
    )
  );
end;

procedure TRadIARuntimeVisualToolsTests.
  RequiresAnActiveRuntimeDebugSession;
var
  LResult: TRadIAToolResult;
begin
  LResult := ExecuteCapture('before');
  Assert.IsFalse(LResult.Success);
  Assert.AreEqual('runtime_session_unavailable', LResult.ErrorCode);
end;

procedure TRadIARuntimeVisualToolsTests.Setup;
begin
  FCoordinator := TRadIARuntimeDebugSessionCoordinator.Create;
  FRegistry := TRadIAToolRegistry.Create;
  FVisualSession := TRadIAVisualRuntimeSession.Create;
  RegisterRadIARuntimeVisualTools(
    FRegistry,
    FCoordinator,
    TRadIAFakeRuntimeVisualCaptureFacade.Create,
    FVisualSession
  );
end;

initialization
  TDUnitX.RegisterTestFixture(TRadIARuntimeVisualToolsTests);

end.
