unit RadIA.UI.SkillPortabilityForm;

interface

uses
  Vcl.Forms,
  RadIA.Core.SkillPortability;

procedure ShowRadIASkillPortability(
  AOwner: TForm;
  const AProjectRoot: string;
  const ASkill: TRadIACanonicalSkill
);

implementation

uses
  System.Classes,
  System.Generics.Collections,
  System.JSON,
  System.SysUtils,
  ToolsAPI,
  Vcl.CheckLst,
  Vcl.Controls,
  Vcl.StdCtrls,
  RadIA.Core.Container,
  RadIA.Core.SkillReplicas,
  RadIA.Core.ToolSecurity,
  RadIA.Core.Tools,
  RadIA.Core.Version;

type
  TRadIASkillPortabilityForm = class(TForm)
  private
    FApplyButton: TButton;
    FDestinations: TCheckListBox;
    FPreview: TMemo;
    FProjectRoot: string;
    FSkill: TRadIACanonicalSkill;
    FStatus: TLabel;
    function Authorize(
      const AOperation: string;
      const AExecutorIds: TArray<string>
    ): Boolean;
    procedure ApplyClick(Sender: TObject);
    function ArgumentsJson(
      const AOperation: string;
      const AExecutorIds: TArray<string>
    ): string;
    procedure DestinationClick(Sender: TObject);
    function ExecutorIds: TArray<string>;
    procedure RefreshPreview;
    procedure RemoveClick(Sender: TObject);
  protected
    procedure CreateWnd; override;
  public
    constructor Create(
      AOwner: TComponent;
      const AProjectRoot: string;
      const ASkill: TRadIACanonicalSkill
    ); reintroduce;
  end;

procedure ShowRadIASkillPortability(
  AOwner: TForm;
  const AProjectRoot: string;
  const ASkill: TRadIACanonicalSkill
);
var
  LForm: TRadIASkillPortabilityForm;
begin
  LForm := TRadIASkillPortabilityForm.Create(AOwner, AProjectRoot, ASkill);
  try
    LForm.ShowModal;
  finally
    LForm.Free;
  end;
end;

constructor TRadIASkillPortabilityForm.Create(
  AOwner: TComponent;
  const AProjectRoot: string;
  const ASkill: TRadIACanonicalSkill
);
var
  LButton: TButton;
  LIndex: Integer;
  LLabel: TLabel;
begin
  inherited CreateNew(AOwner);
  FProjectRoot := AProjectRoot;
  FSkill := ASkill;
  Caption := RadIAVersionedCaption('Rad IA - Publish skill to CLIs');
  Position := poOwnerFormCenter;
  BorderStyle := bsSizeable;
  ClientWidth := 760;
  ClientHeight := 540;
  Constraints.MinWidth := 680;
  Constraints.MinHeight := 480;

  LLabel := TLabel.Create(Self);
  LLabel.Parent := Self;
  LLabel.SetBounds(12, 12, 736, 34);
  LLabel.AutoSize := False;
  LLabel.WordWrap := True;
  LLabel.Caption :=
    'Select project destinations, review every full path, then publish. ' +
    'Files changed outside RadIA are preserved as conflicts.';

  FDestinations := TCheckListBox.Create(Self);
  FDestinations.Parent := Self;
  FDestinations.SetBounds(12, 54, 200, 388);
  FDestinations.Anchors := [akLeft, akTop, akBottom];
  FDestinations.Items.Add('Codex');
  FDestinations.Items.Add('Claude Code');
  FDestinations.Items.Add('Gemini CLI');
  FDestinations.Items.Add('GitHub Copilot CLI');
  for LIndex := 0 to FDestinations.Items.Count - 1 do
    FDestinations.Checked[LIndex] := True;
  FDestinations.OnClickCheck := DestinationClick;
  FDestinations.Hint :=
    'Each checked item publishes to that CLI project-scoped skills directory.';
  FDestinations.ShowHint := True;

  FPreview := TMemo.Create(Self);
  FPreview.Parent := Self;
  FPreview.SetBounds(224, 54, 524, 388);
  FPreview.Anchors := [akLeft, akTop, akRight, akBottom];
  FPreview.ReadOnly := True;
  FPreview.ScrollBars := ssBoth;
  FPreview.WordWrap := False;
  FPreview.Hint :=
    'Exact destinations and create, update, unchanged, or conflict state.';
  FPreview.ShowHint := True;

  FStatus := TLabel.Create(Self);
  FStatus.Parent := Self;
  FStatus.SetBounds(12, 450, 736, 34);
  FStatus.Anchors := [akLeft, akRight, akBottom];
  FStatus.AutoSize := False;
  FStatus.WordWrap := True;

  LButton := TButton.Create(Self);
  LButton.Parent := Self;
  LButton.SetBounds(12, 496, 132, 28);
  LButton.Anchors := [akLeft, akBottom];
  LButton.Caption := 'Remove replicas';
  LButton.Hint := 'Remove only unchanged files recorded as owned by RadIA.';
  LButton.ShowHint := True;
  LButton.OnClick := RemoveClick;

  FApplyButton := TButton.Create(Self);
  FApplyButton.Parent := Self;
  FApplyButton.SetBounds(524, 496, 108, 28);
  FApplyButton.Anchors := [akRight, akBottom];
  FApplyButton.Caption := 'Publish';
  FApplyButton.Hint :=
    'Request central consent and atomically publish the selected replicas.';
  FApplyButton.ShowHint := True;
  FApplyButton.OnClick := ApplyClick;

  LButton := TButton.Create(Self);
  LButton.Parent := Self;
  LButton.SetBounds(640, 496, 108, 28);
  LButton.Anchors := [akRight, akBottom];
  LButton.Caption := 'Close';
  LButton.ModalResult := mrClose;

  RefreshPreview;
end;

procedure TRadIASkillPortabilityForm.ApplyClick(Sender: TObject);
var
  LIds: TArray<string>;
  LMessage: string;
  LResult: TRadIASkillReplicaApplyResult;
  LService: TRadIASkillReplicaService;
begin
  LIds := ExecutorIds;
  if (Length(LIds) = 0) or not Authorize('publish', LIds) then
  begin
    FStatus.Caption := 'Publishing was not authorized.';
    Exit;
  end;
  LService := TRadIASkillReplicaService.Create(FProjectRoot);
  try
    try
      LResult := LService.Apply(FSkill, LIds);
      LMessage := Format(
        'Published. Created: %d; updated: %d; unchanged: %d.',
        [LResult.Created, LResult.Updated, LResult.Unchanged]
      );
    except
      on E: Exception do
        FStatus.Caption := 'Publishing failed: ' + E.Message;
    end;
  finally
    LService.Free;
  end;
  RefreshPreview;
  if LMessage <> '' then
    FStatus.Caption := LMessage;
end;

function TRadIASkillPortabilityForm.ArgumentsJson(
  const AOperation: string;
  const AExecutorIds: TArray<string>
): string;
var
  LArray: TJSONArray;
  LExecutorId: string;
  LRoot: TJSONObject;
begin
  LRoot := TJSONObject.Create;
  try
    LRoot.AddPair('operation', AOperation);
    LRoot.AddPair('extensionId', FSkill.ExtensionId);
    LRoot.AddPair('projectRoot', FProjectRoot);
    LArray := TJSONArray.Create;
    LRoot.AddPair('executors', LArray);
    for LExecutorId in AExecutorIds do
      LArray.Add(LExecutorId);
    Result := LRoot.ToJSON;
  finally
    LRoot.Free;
  end;
end;

function TRadIASkillPortabilityForm.Authorize(
  const AOperation: string;
  const AExecutorIds: TArray<string>
): Boolean;
var
  LAuthorization: IRadIAToolAuthorizationPolicy;
  LDecision: TRadIAConsentDecision;
  LDescriptor: TRadIAToolDescriptor;
  LRequest: TRadIAToolRequest;
begin
  Result := False;
  if not TRadIAContainer.TryResolve<IRadIAToolAuthorizationPolicy>(
    LAuthorization
  ) then
    Exit;
  LRequest := TRadIAToolRequest.Create(
    'PublishCliSkill',
    ArgumentsJson(AOperation, AExecutorIds),
    TGUID.NewGuid.ToString,
    'addon-studio',
    'skill-portability',
    FProjectRoot,
    FProjectRoot
  );
  LDescriptor := TRadIAToolDescriptor.Create(
    'PublishCliSkill',
    '1.0.0',
    'Publishes or removes project-scoped CLI skill replicas.',
    '{"type":"object"}',
    '{"type":"object"}',
    trStructuralWrite
  ).WithConsentEveryTime;
  LDecision := LAuthorization.Authorize(LRequest, LDescriptor);
  Result := LDecision in [cdAllowOnce, cdAllowSession];
end;

procedure TRadIASkillPortabilityForm.CreateWnd;
var
  LThemingServices: IOTAIDEThemingServices;
begin
  inherited CreateWnd;
  if Supports(
    BorlandIDEServices,
    IOTAIDEThemingServices,
    LThemingServices
  ) and LThemingServices.IDEThemingEnabled then
    LThemingServices.ApplyTheme(Self);
end;

procedure TRadIASkillPortabilityForm.DestinationClick(Sender: TObject);
begin
  RefreshPreview;
end;

function TRadIASkillPortabilityForm.ExecutorIds: TArray<string>;
const
  CIds: array[0..3] of string = ('codex', 'claude', 'gemini', 'copilot');
var
  LIds: TList<string>;
  LIndex: Integer;
begin
  LIds := TList<string>.Create;
  try
    for LIndex := Low(CIds) to High(CIds) do
      if FDestinations.Checked[LIndex] then
        LIds.Add(CIds[LIndex]);
    Result := LIds.ToArray;
  finally
    LIds.Free;
  end;
end;

procedure TRadIASkillPortabilityForm.RefreshPreview;
var
  LIds: TArray<string>;
  LHasConflict: Boolean;
  LItem: TRadIASkillReplicaPlanItem;
  LService: TRadIASkillReplicaService;
begin
  LIds := ExecutorIds;
  LHasConflict := False;
  FPreview.Clear;
  FApplyButton.Enabled := Length(LIds) > 0;
  if Length(LIds) = 0 then
  begin
    FStatus.Caption := 'Select at least one CLI destination.';
    Exit;
  end;
  LService := TRadIASkillReplicaService.Create(FProjectRoot);
  try
    try
      FPreview.Lines.Add('Project: ' + FProjectRoot);
      FPreview.Lines.Add('Skill: ' + FSkill.Name);
      FPreview.Lines.Add('');
      for LItem in LService.BuildPlan(FSkill, LIds) do
      begin
        FPreview.Lines.Add(
          '[' + TRadIASkillReplicaService.StateName(LItem.State) + '] ' +
          LItem.AbsoluteFileName
        );
        LHasConflict := LHasConflict or (LItem.State = srsConflict);
      end;
      FApplyButton.Enabled := not LHasConflict;
      if LHasConflict then
        FStatus.Caption :=
          'Resolve every conflict before publishing. No file was changed.'
      else
      FStatus.Caption := 'Preview refreshed. No file was changed.';
    except
      on E: Exception do
      begin
        FApplyButton.Enabled := False;
        FStatus.Caption := 'Preview failed: ' + E.Message;
      end;
    end;
  finally
    LService.Free;
  end;
end;

procedure TRadIASkillPortabilityForm.RemoveClick(Sender: TObject);
var
  LMessage: string;
  LService: TRadIASkillReplicaService;
begin
  if not Authorize('remove', []) then
  begin
    FStatus.Caption := 'Removal was not authorized.';
    Exit;
  end;
  LService := TRadIASkillReplicaService.Create(FProjectRoot);
  try
    try
      LMessage := LService.RemoveOwned(FSkill.ExtensionId);
    except
      on E: Exception do
        FStatus.Caption := 'Removal failed: ' + E.Message;
    end;
  finally
    LService.Free;
  end;
  RefreshPreview;
  if LMessage <> '' then
    FStatus.Caption := LMessage;
end;

end.
