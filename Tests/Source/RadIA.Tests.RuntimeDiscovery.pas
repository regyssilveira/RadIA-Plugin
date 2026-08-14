unit RadIA.Tests.RuntimeDiscovery;

interface

uses
  DUnitX.TestFramework,
  RadIA.Core.RuntimeAutomation,
  RadIA.Core.RuntimeDebugSession,
  RadIA.Core.RuntimeScenario,
  RadIA.Core.Tools,
  Vcl.Forms,
  Vcl.StdCtrls;

type
  [TestFixture]
  TTestRadIARuntimeDiscovery = class
  private
    FCoordinator: IRadIARuntimeDebugSessionCoordinator;
    FDiscovery: IRadIARuntimeDiscoveryFacade;
    FActionFacade: IRadIARuntimeActionFacade;
    FButton: TButton;
    FClickCount: Integer;
    FEdit: TEdit;
    FForm: TForm;
    FOwnedForm: TForm;
    FRegistry: IRadIAToolRegistry;
    FScenarioCoordinator: IRadIARuntimeScenarioCoordinator;
    FSession: TRadIARuntimeSessionIdentity;
    function FindLaboratoryWindow(
      out AWindow: TRadIARuntimeWindowSnapshot
    ): Boolean;
    procedure HandleButtonClick(Sender: TObject);
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    [Test]
    procedure DiscoversAuthorizedFormAndControl;
    [Test]
    procedure CapturesAuthorizedFormAsPng;
    [Test]
    procedure ExecutesOnlyAuthorizedRuntimeActions;
    [Test]
    procedure RejectsPasswordRuntimeAction;
    [Test]
    procedure RejectsUnknownOpaqueWindowId;
    [Test]
    procedure ReportsOwnerRelationshipAndExcludesExternalProcesses;
    [Test]
    procedure ScenarioToolsPrepareAndRunReviewedAction;
    [Test]
    procedure ToolsReturnOnlyOpaqueIdentifiers;
  end;

implementation

uses
  System.JSON,
  System.SysUtils,
  Winapi.Windows,
  RadIA.Core.RuntimeDiscoveryTools,
  RadIA.Core.RuntimeScenarioTools,
  RadIA.Core.VisualRuntimeSession,
  RadIA.Core.ToolRegistry,
  RadIA.OTA.RuntimeDiscovery,
  RadIA.OTA.RuntimeProcess;

const
  CTestFormCaption = 'RadIA runtime discovery test form';
  CTestButtonCaption = 'Authorized runtime action';
  CTestOwnedFormCaption = 'RadIA owned runtime test form';
  CTestPasswordValue = 'must-not-be-disclosed';
  CTestEditableValue = 'editable runtime value';
  CTestUpdatedValue = 'updated runtime value';

procedure TTestRadIARuntimeDiscovery.CapturesAuthorizedFormAsPng;
var
  LCapture: TRadIAVisualCapture;
  LCaptureFacade: IRadIARuntimeVisualCaptureFacade;
  LWindow: TRadIARuntimeWindowSnapshot;
begin
  Assert.IsTrue(FindLaboratoryWindow(LWindow));
  Assert.IsTrue(Supports(
    FDiscovery,
    IRadIARuntimeVisualCaptureFacade,
    LCaptureFacade
  ));
  LCapture := LCaptureFacade.CaptureWindow(
    FSession,
    LWindow.WindowId,
    vcpBefore
  );
  Assert.AreEqual('image/png', LCapture.MimeType);
  Assert.AreEqual(FForm.Width, LCapture.Width);
  Assert.AreEqual(FForm.Height, LCapture.Height);
  Assert.IsTrue(Length(LCapture.Bytes) > 8);
  Assert.AreEqual<Integer>($89, LCapture.Bytes[0]);
  Assert.AreEqual<Integer>($50, LCapture.Bytes[1]);
  Assert.AreEqual<Integer>($4E, LCapture.Bytes[2]);
  Assert.AreEqual<Integer>($47, LCapture.Bytes[3]);
end;

function TTestRadIARuntimeDiscovery.FindLaboratoryWindow(
  out AWindow: TRadIARuntimeWindowSnapshot
): Boolean;
var
  LWindow: TRadIARuntimeWindowSnapshot;
begin
  Result := False;
  for LWindow in FDiscovery.GetWindows(FSession) do
    if SameText(LWindow.Text, CTestFormCaption) then
    begin
      AWindow := LWindow;
      Exit(True);
    end;
end;

procedure TTestRadIARuntimeDiscovery.DiscoversAuthorizedFormAndControl;
var
  LControl: TRadIARuntimeControlSnapshot;
  LFoundButton: Boolean;
  LFoundPassword: Boolean;
  LWindow: TRadIARuntimeWindowSnapshot;
begin
  Assert.IsTrue(FindLaboratoryWindow(LWindow));
  Assert.AreEqual(GetCurrentProcessId, LWindow.ProcessId);
  Assert.AreEqual(NativeInt(64), Length(LWindow.WindowId));

  LFoundButton := False;
  LFoundPassword := False;
  for LControl in FDiscovery.GetControlTree(
    FSession,
    LWindow.WindowId
  ) do
    if SameText(LControl.Text, CTestButtonCaption) then
    begin
      LFoundButton := True;
      Assert.Contains(LControl.ClassName, 'Button');
      Assert.Contains(LControl.Path, 'Button');
      Assert.IsTrue(racInvoke in LControl.State.Capabilities);
      Assert.AreEqual(NativeInt(64), Length(LControl.ControlId));
    end
    else if SameText(LControl.Text, '[redacted]') then
    begin
      LFoundPassword := True;
      Assert.IsTrue(racSetValue in LControl.State.Capabilities);
    end;
  Assert.IsTrue(LFoundButton);
  Assert.IsTrue(LFoundPassword);
end;

procedure TTestRadIARuntimeDiscovery.ExecutesOnlyAuthorizedRuntimeActions;
var
  LAction: TRadIARuntimeScenarioAction;
  LButtonId: string;
  LControl: TRadIARuntimeControlSnapshot;
  LEditId: string;
  LResult: TRadIARuntimeActionResult;
  LWindow: TRadIARuntimeWindowSnapshot;
begin
  Assert.IsTrue(FindLaboratoryWindow(LWindow));
  LButtonId := '';
  LEditId := '';
  for LControl in FDiscovery.GetControlTree(
    FSession,
    LWindow.WindowId
  ) do
  begin
    if SameText(LControl.Text, CTestButtonCaption) then
      LButtonId := LControl.ControlId;
    if SameText(LControl.Text, CTestEditableValue) then
      LEditId := LControl.ControlId;
  end;
  Assert.AreEqual(NativeInt(64), Length(LButtonId));
  Assert.AreEqual(NativeInt(64), Length(LEditId));

  LAction := TRadIARuntimeScenarioAction.Create(
    rakInvoke,
    TRadIARuntimeSelector.Create(LButtonId, '', '', '', ''),
    '',
    1000
  );
  LResult := FActionFacade.ExecuteAction(FSession, LAction);
  Assert.IsTrue(LResult.Success);
  Application.ProcessMessages;
  Assert.AreEqual(1, FClickCount);

  LAction := TRadIARuntimeScenarioAction.Create(
    rakSetValue,
    TRadIARuntimeSelector.Create(LEditId, '', '', '', ''),
    CTestUpdatedValue,
    1000
  );
  LResult := FActionFacade.ExecuteAction(FSession, LAction);
  Assert.IsTrue(LResult.Success);
  Assert.AreEqual(CTestUpdatedValue, FEdit.Text);
end;

procedure TTestRadIARuntimeDiscovery.HandleButtonClick(Sender: TObject);
begin
  Inc(FClickCount);
end;

procedure TTestRadIARuntimeDiscovery.RejectsUnknownOpaqueWindowId;
begin
  Assert.WillRaise(
    procedure
    begin
      FDiscovery.GetControlTree(
        FSession,
        StringOfChar('0', 64)
      );
    end,
    EArgumentException
  );
end;

procedure TTestRadIARuntimeDiscovery.RejectsPasswordRuntimeAction;
var
  LAction: TRadIARuntimeScenarioAction;
  LControl: TRadIARuntimeControlSnapshot;
  LPasswordId: string;
  LResult: TRadIARuntimeActionResult;
  LWindow: TRadIARuntimeWindowSnapshot;
begin
  Assert.IsTrue(FindLaboratoryWindow(LWindow));
  LPasswordId := '';
  for LControl in FDiscovery.GetControlTree(
    FSession,
    LWindow.WindowId
  ) do
    if SameText(LControl.Text, '[redacted]') then
      LPasswordId := LControl.ControlId;
  Assert.AreEqual(NativeInt(64), Length(LPasswordId));
  LAction := TRadIARuntimeScenarioAction.Create(
    rakSetValue,
    TRadIARuntimeSelector.Create(LPasswordId, '', '', '', ''),
    'new-secret',
    1000
  );
  LResult := FActionFacade.ValidateAction(FSession, LAction);
  Assert.IsFalse(LResult.Success);
  Assert.AreEqual('sensitive_runtime_target', LResult.ErrorCode);
end;

procedure TTestRadIARuntimeDiscovery.
  ReportsOwnerRelationshipAndExcludesExternalProcesses;
var
  LMainWindow: TRadIARuntimeWindowSnapshot;
  LOwnedWindow: TRadIARuntimeWindowSnapshot;
  LWindow: TRadIARuntimeWindowSnapshot;
begin
  LMainWindow := Default(TRadIARuntimeWindowSnapshot);
  LOwnedWindow := Default(TRadIARuntimeWindowSnapshot);
  FForm.Enabled := False;
  try
    for LWindow in FDiscovery.GetWindows(FSession) do
    begin
      Assert.AreEqual(GetCurrentProcessId, LWindow.ProcessId);
      if SameText(LWindow.Text, CTestFormCaption) then
        LMainWindow := LWindow;
      if SameText(LWindow.Text, CTestOwnedFormCaption) then
        LOwnedWindow := LWindow;
    end;
  finally
    FForm.Enabled := True;
  end;

  Assert.AreEqual(NativeInt(64), Length(LMainWindow.WindowId));
  Assert.AreEqual(NativeInt(64), Length(LOwnedWindow.WindowId));
  Assert.AreEqual(LMainWindow.WindowId, LOwnedWindow.OwnerId);
  Assert.IsTrue(LOwnedWindow.Modal);
end;

procedure TTestRadIARuntimeDiscovery.
  ScenarioToolsPrepareAndRunReviewedAction;
var
  LButtonId: string;
  LButtonPath: string;
  LControl: TRadIARuntimeControlSnapshot;
  LJson: TJSONObject;
  LPrepare: TRadIAToolResult;
  LPreviewId: string;
  LRun: TRadIAToolResult;
  LWindow: TRadIARuntimeWindowSnapshot;
begin
  Assert.IsTrue(FindLaboratoryWindow(LWindow));
  LButtonId := '';
  LButtonPath := '';
  for LControl in FDiscovery.GetControlTree(
    FSession,
    LWindow.WindowId
  ) do
    if SameText(LControl.Text, CTestButtonCaption) then
    begin
      LButtonId := LControl.ControlId;
      LButtonPath := LControl.Path;
    end;
  Assert.AreEqual(NativeInt(64), Length(LButtonId));
  LPrepare := FRegistry.Resolve('PrepareRuntimeScenario').Execute(
    TRadIAToolRequest.Create(
      'PrepareRuntimeScenario',
      '{"name":"Invoke authorized test button",' +
      '"limits":{"maxActions":1,"maxDurationMs":5000,' +
      '"maxRepetitions":1},"actions":[{"kind":"invoke",' +
      '"selector":{"className":"TButton","text":"' +
      CTestButtonCaption + '","parentPath":"' + LButtonPath +
      '"},"timeoutMs":1000}]}',
      'runtime-scenario-prepare-test'
    )
  );
  Assert.IsTrue(LPrepare.Success);
  LJson := TJSONObject.ParseJSONValue(
    LPrepare.ContentJson
  ) as TJSONObject;
  try
    Assert.IsNotNull(LJson);
    LPreviewId := LJson.GetValue<string>('previewId', '');
  finally
    LJson.Free;
  end;
  LRun := FRegistry.Resolve('RunRuntimeScenario').Execute(
    TRadIAToolRequest.Create(
      'RunRuntimeScenario',
      '{"previewId":"' + LPreviewId + '"}',
      'runtime-scenario-run-test'
    )
  );
  Assert.IsTrue(LRun.Success);
  Application.ProcessMessages;
  Assert.AreEqual(1, FClickCount);
  Assert.Contains(LRun.ContentJson, '"state":"succeeded"');
end;

procedure TTestRadIARuntimeDiscovery.Setup;
var
  LBuildId: string;
  LCreatedAtUtc: TDateTime;
  LPasswordEdit: TEdit;
  LExecutablePath: string;
  LSessionId: string;
begin
  Assert.IsTrue(
    TryGetRadIARuntimeProcessIdentity(
      GetCurrentProcessId,
      LExecutablePath,
      LCreatedAtUtc
    )
  );
  LBuildId := GetRadIARuntimeBuildId(LExecutablePath);
  FCoordinator := TRadIARuntimeDebugSessionCoordinator.Create;
  LSessionId := FCoordinator.BeginSession(
    'C:\Workspace\RuntimeDiscoveryTests.dproj'
  );
  Assert.IsTrue(
    FCoordinator.AttachProcess(
      LSessionId,
      GetCurrentProcessId,
      LCreatedAtUtc,
      LExecutablePath,
      LBuildId
    )
  );
  FSession := FCoordinator.GetCurrentSession;
  FDiscovery := TRadIAWindowsRuntimeDiscoveryFacade.Create;
  Assert.IsTrue(Supports(
    FDiscovery,
    IRadIARuntimeActionFacade,
    FActionFacade
  ));
  FRegistry := TRadIAToolRegistry.Create;
  FScenarioCoordinator := TRadIARuntimeScenarioCoordinator.Create(
    FActionFacade
  );
  RegisterRadIARuntimeDiscoveryTools(
    FRegistry,
    FCoordinator,
    FDiscovery
  );
  RegisterRadIARuntimeScenarioTools(
    FRegistry,
    FCoordinator,
    FScenarioCoordinator
  );

  FForm := TForm.Create(nil);
  FForm.Caption := CTestFormCaption;
  FForm.Width := 420;
  FForm.Height := 180;
  FClickCount := 0;
  FButton := TButton.Create(FForm);
  FButton.Parent := FForm;
  FButton.Caption := CTestButtonCaption;
  FButton.Left := 40;
  FButton.Top := 20;
  FButton.Width := 240;
  FButton.OnClick := HandleButtonClick;
  FEdit := TEdit.Create(FForm);
  FEdit.Parent := FForm;
  FEdit.Text := CTestEditableValue;
  FEdit.Left := 40;
  FEdit.Top := 60;
  FEdit.Width := 240;
  LPasswordEdit := TEdit.Create(FForm);
  LPasswordEdit.Parent := FForm;
  LPasswordEdit.PasswordChar := '*';
  LPasswordEdit.Text := CTestPasswordValue;
  LPasswordEdit.Left := 40;
  LPasswordEdit.Top := 100;
  LPasswordEdit.Width := 240;
  FForm.Show;
  FOwnedForm := TForm.Create(nil);
  FOwnedForm.Caption := CTestOwnedFormCaption;
  FOwnedForm.Width := 320;
  FOwnedForm.Height := 140;
  FOwnedForm.Show;
  SetWindowLongPtr(
    FOwnedForm.Handle,
    GWLP_HWNDPARENT,
    FForm.Handle
  );
  Application.ProcessMessages;
end;

procedure TTestRadIARuntimeDiscovery.TearDown;
begin
  FOwnedForm.Free;
  FRegistry := nil;
  FScenarioCoordinator := nil;
  FActionFacade := nil;
  FDiscovery := nil;
  FCoordinator := nil;
  FForm.Free;
  FButton := nil;
  FEdit := nil;
end;

procedure TTestRadIARuntimeDiscovery.ToolsReturnOnlyOpaqueIdentifiers;
var
  LResult: TRadIAToolResult;
begin
  LResult := FRegistry.Resolve('GetRuntimeWindows').Execute(
    TRadIAToolRequest.Create(
      'GetRuntimeWindows',
      '{}',
      'runtime-discovery-test'
    )
  );

  Assert.IsTrue(LResult.Success);
  Assert.Contains(LResult.ContentJson, CTestFormCaption);
  Assert.AreEqual(0, Pos('"handle"', LowerCase(LResult.ContentJson)));
  Assert.AreEqual(0, Pos('"hwnd"', LowerCase(LResult.ContentJson)));
end;

initialization
  TDUnitX.RegisterTestFixture(TTestRadIARuntimeDiscovery);

end.
