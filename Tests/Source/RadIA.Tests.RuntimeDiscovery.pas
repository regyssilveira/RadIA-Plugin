unit RadIA.Tests.RuntimeDiscovery;

interface

uses
  DUnitX.TestFramework,
  RadIA.Core.RuntimeAutomation,
  RadIA.Core.RuntimeDebugSession,
  RadIA.Core.Tools,
  Vcl.Forms;

type
  [TestFixture]
  TTestRadIARuntimeDiscovery = class
  private
    FCoordinator: IRadIARuntimeDebugSessionCoordinator;
    FDiscovery: IRadIARuntimeDiscoveryFacade;
    FForm: TForm;
    FOwnedForm: TForm;
    FRegistry: IRadIAToolRegistry;
    FSession: TRadIARuntimeSessionIdentity;
    function FindLaboratoryWindow(
      out AWindow: TRadIARuntimeWindowSnapshot
    ): Boolean;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    [Test]
    procedure DiscoversAuthorizedFormAndControl;
    [Test]
    procedure RejectsUnknownOpaqueWindowId;
    [Test]
    procedure ReportsOwnerRelationshipAndExcludesExternalProcesses;
    [Test]
    procedure ToolsReturnOnlyOpaqueIdentifiers;
  end;

implementation

uses
  System.SysUtils,
  Vcl.StdCtrls,
  Winapi.Windows,
  RadIA.Core.RuntimeDiscoveryTools,
  RadIA.Core.ToolRegistry,
  RadIA.OTA.RuntimeDiscovery,
  RadIA.OTA.RuntimeProcess;

const
  CTestFormCaption = 'RadIA runtime discovery test form';
  CTestButtonCaption = 'Authorized runtime action';
  CTestOwnedFormCaption = 'RadIA owned runtime test form';
  CTestPasswordValue = 'must-not-be-disclosed';

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
  Assert.AreEqual(64, Length(LWindow.WindowId));

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
      Assert.AreEqual(64, Length(LControl.ControlId));
    end
    else if SameText(LControl.Text, '[redacted]') then
    begin
      LFoundPassword := True;
      Assert.IsTrue(racSetValue in LControl.State.Capabilities);
    end;
  Assert.IsTrue(LFoundButton);
  Assert.IsTrue(LFoundPassword);
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

procedure TTestRadIARuntimeDiscovery.
  ReportsOwnerRelationshipAndExcludesExternalProcesses;
var
  LMainWindow: TRadIARuntimeWindowSnapshot;
  LOwnedWindow: TRadIARuntimeWindowSnapshot;
  LWindow: TRadIARuntimeWindowSnapshot;
begin
  LMainWindow := Default(TRadIARuntimeWindowSnapshot);
  LOwnedWindow := Default(TRadIARuntimeWindowSnapshot);
  for LWindow in FDiscovery.GetWindows(FSession) do
  begin
    Assert.AreEqual(GetCurrentProcessId, LWindow.ProcessId);
    if SameText(LWindow.Text, CTestFormCaption) then
      LMainWindow := LWindow;
    if SameText(LWindow.Text, CTestOwnedFormCaption) then
      LOwnedWindow := LWindow;
  end;

  Assert.AreEqual(64, Length(LMainWindow.WindowId));
  Assert.AreEqual(64, Length(LOwnedWindow.WindowId));
  Assert.AreEqual(LMainWindow.WindowId, LOwnedWindow.OwnerId);
end;

procedure TTestRadIARuntimeDiscovery.Setup;
var
  LBuildId: string;
  LButton: TButton;
  LCreatedAtUtc: TDateTime;
  LEdit: TEdit;
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
  FRegistry := TRadIAToolRegistry.Create;
  RegisterRadIARuntimeDiscoveryTools(
    FRegistry,
    FCoordinator,
    FDiscovery
  );

  FForm := TForm.Create(nil);
  FForm.Caption := CTestFormCaption;
  FForm.Width := 420;
  FForm.Height := 180;
  LButton := TButton.Create(FForm);
  LButton.Parent := FForm;
  LButton.Caption := CTestButtonCaption;
  LButton.Left := 40;
  LButton.Top := 40;
  LButton.Width := 240;
  LEdit := TEdit.Create(FForm);
  LEdit.Parent := FForm;
  LEdit.PasswordChar := '*';
  LEdit.Text := CTestPasswordValue;
  LEdit.Left := 40;
  LEdit.Top := 80;
  LEdit.Width := 240;
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
  FDiscovery := nil;
  FCoordinator := nil;
  FForm.Free;
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
