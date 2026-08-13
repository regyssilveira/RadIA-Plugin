unit RadIA.Tests.SemanticMembers;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TRadIASemanticMemberServiceTests = class
  public
    [Test]
    procedure PreparesPatchFromSemanticPreview;
    [Test]
    procedure ReturnsSuccessfulNoChangeIdempotently;
    [Test]
    procedure RejectsStaleEditorRevisionBeforeCallingEngine;
    [Test]
    procedure RegistersReadOnlyToolWithApplyPatchHandoff;
  end;

implementation

uses
  System.SysUtils,
  RadIA.Core.DelphiEnvironment,
  RadIA.Core.Patches,
  RadIA.Core.SemanticMembers,
  RadIA.Core.SemanticMemberTools,
  RadIA.Core.ToolRegistry,
  RadIA.Core.Tools,
  RadIA.Core.Workspace,
  RadIA.Semantic.Workspace;

type
  TRadIASemanticRequestClientMock = class(
    TInterfacedObject,
    IRadIASemanticRequestClient
  )
  private
    FChanged: Boolean;
    FRequestCount: Integer;
  public
    constructor Create(const AChanged: Boolean);
    function GetRestartCount: Integer;
    function Request(
      const AMethod: string;
      const AParameters: string;
      out AResponse: string;
      out AError: string
    ): Boolean;
    property RequestCount: Integer read FRequestCount;
  end;

  TRadIASemanticEnvironmentMock = class(
    TInterfacedObject,
    IRadIADelphiEnvironmentService
  )
  public
    function BuildProfile: TRadIADelphiEnvironmentProfile;
  end;

  TRadIASemanticMutationMock = class(
    TInterfacedObject,
    IRadIAEditorMutationFacade
  )
  private
    FRevision: string;
    FSource: string;
  public
    constructor Create(const ASource: string; const ARevision: string);
    function ApplyContent(
      const AFileName: string;
      const AExpectedRevision: string;
      const ANewContent: string;
      out AAppliedRevision: string
    ): Boolean;
    function ReadContent(
      const AFileName: string;
      const AMaxCharacters: Integer
    ): TRadIAEditorContent;
  end;

  TRadIASemanticPatchServiceMock = class(
    TInterfacedObject,
    IRadIAPatchService
  )
  private
    FPrepareCount: Integer;
  public
    function Apply(const APreviewId: string): TRadIAPatchResult;
    procedure Clear;
    function Prepare(const ASpec: TRadIAPatchSpec): TRadIAPatchResult;
    function Revert(const APreviewId: string): TRadIAPatchResult;
    property PrepareCount: Integer read FPrepareCount;
  end;

constructor TRadIASemanticRequestClientMock.Create(
  const AChanged: Boolean
);
begin
  inherited Create;
  FChanged := AChanged;
end;

function TRadIASemanticRequestClientMock.GetRestartCount: Integer;
begin
  Result := 0;
end;

function TRadIASemanticRequestClientMock.Request(
  const AMethod: string;
  const AParameters: string;
  out AResponse: string;
  out AError: string
): Boolean;
begin
  Inc(FRequestCount);
  AError := '';
  if FChanged then
    AResponse :=
      '{"result":{"changed":true,"missingCount":2,' +
      '"proposedSource":"unit Sample; interface implementation end.",' +
      '"errorMessage":""}}'
  else
    AResponse :=
      '{"result":{"changed":false,"missingCount":0,' +
      '"proposedSource":"","errorMessage":""}}';
  Result := SameText(AMethod, 'prepareMissingMembers') and
    AParameters.Contains('"container":"TWorker"');
end;

function TRadIASemanticEnvironmentMock.BuildProfile:
  TRadIADelphiEnvironmentProfile;
begin
  Result := TRadIADelphiEnvironmentProfile.Create(
    '23.0',
    'Win32',
    'Professional',
    'Sample',
    'VCL',
    'Debug',
    'Win32'
  );
  Result.SetCompilerCollections(['DEBUG'], nil, nil, nil);
end;

constructor TRadIASemanticMutationMock.Create(
  const ASource: string;
  const ARevision: string
);
begin
  inherited Create;
  FSource := ASource;
  FRevision := ARevision;
end;

function TRadIASemanticMutationMock.ApplyContent(
  const AFileName: string;
  const AExpectedRevision: string;
  const ANewContent: string;
  out AAppliedRevision: string
): Boolean;
begin
  AAppliedRevision := FRevision;
  Result := False;
end;

function TRadIASemanticMutationMock.ReadContent(
  const AFileName: string;
  const AMaxCharacters: Integer
): TRadIAEditorContent;
begin
  Result := TRadIAEditorContent.Create(
    'Sample',
    AFileName,
    FSource,
    FRevision,
    Length(FSource),
    False
  );
end;

function TRadIASemanticPatchServiceMock.Apply(
  const APreviewId: string
): TRadIAPatchResult;
begin
  Result := TRadIAPatchResult.Failed('not_used', APreviewId);
end;

procedure TRadIASemanticPatchServiceMock.Clear;
begin
  FPrepareCount := 0;
end;

function TRadIASemanticPatchServiceMock.Prepare(
  const ASpec: TRadIAPatchSpec
): TRadIAPatchResult;
var
  LPreview: TRadIAPatchPreview;
begin
  Inc(FPrepareCount);
  LPreview := TRadIAPatchPreview.Create(
    'semantic-preview',
    ASpec,
    ASpec.OriginalText,
    ASpec.ReplacementText,
    'revision-2',
    Now + 1
  );
  Result := TRadIAPatchResult.Succeeded(LPreview);
end;

function TRadIASemanticPatchServiceMock.Revert(
  const APreviewId: string
): TRadIAPatchResult;
begin
  Result := TRadIAPatchResult.Failed('not_used', APreviewId);
end;

function CreateService(
  const AClient: IRadIASemanticRequestClient;
  const AMutation: IRadIAEditorMutationFacade;
  const APatchService: IRadIAPatchService
): IRadIASemanticMemberService;
begin
  Result := TRadIASemanticMemberService.Create(
    AClient,
    TRadIASemanticEnvironmentMock.Create,
    AMutation,
    APatchService
  );
end;

procedure TRadIASemanticMemberServiceTests.PreparesPatchFromSemanticPreview;
var
  LClient: TRadIASemanticRequestClientMock;
  LClientRef: IRadIASemanticRequestClient;
  LPatch: TRadIASemanticPatchServiceMock;
  LPatchRef: IRadIAPatchService;
  LResult: TRadIASemanticMemberPreviewResult;
  LService: IRadIASemanticMemberService;
begin
  LClient := TRadIASemanticRequestClientMock.Create(True);
  LClientRef := LClient;
  LPatch := TRadIASemanticPatchServiceMock.Create;
  LPatchRef := LPatch;
  LService := CreateService(
    LClientRef,
    TRadIASemanticMutationMock.Create('original source', 'revision-1'),
    LPatchRef
  );
  LResult := LService.PrepareMissingMembers(
    'Sample.pas',
    'revision-1',
    'TWorker'
  );
  Assert.IsTrue(LResult.Success, LResult.ErrorMessage);
  Assert.IsTrue(LResult.Changed);
  Assert.AreEqual(2, LResult.MissingCount);
  Assert.AreEqual(1, LClient.RequestCount);
  Assert.AreEqual(1, LPatch.PrepareCount);
  Assert.AreEqual('semantic-preview', LResult.PatchResult.Preview.Id);
end;

procedure TRadIASemanticMemberServiceTests.
  ReturnsSuccessfulNoChangeIdempotently;
var
  LPatch: TRadIASemanticPatchServiceMock;
  LPatchRef: IRadIAPatchService;
  LResult: TRadIASemanticMemberPreviewResult;
  LService: IRadIASemanticMemberService;
begin
  LPatch := TRadIASemanticPatchServiceMock.Create;
  LPatchRef := LPatch;
  LService := CreateService(
    TRadIASemanticRequestClientMock.Create(False),
    TRadIASemanticMutationMock.Create('complete source', 'revision-1'),
    LPatchRef
  );
  LResult := LService.PrepareMissingMembers(
    'Sample.pas',
    'revision-1',
    'TWorker'
  );
  Assert.IsTrue(LResult.Success);
  Assert.IsFalse(LResult.Changed);
  Assert.AreEqual(0, LResult.MissingCount);
  Assert.AreEqual(0, LPatch.PrepareCount);
end;

procedure TRadIASemanticMemberServiceTests.
  RejectsStaleEditorRevisionBeforeCallingEngine;
var
  LClient: TRadIASemanticRequestClientMock;
  LClientRef: IRadIASemanticRequestClient;
  LResult: TRadIASemanticMemberPreviewResult;
  LService: IRadIASemanticMemberService;
begin
  LClient := TRadIASemanticRequestClientMock.Create(True);
  LClientRef := LClient;
  LService := CreateService(
    LClientRef,
    TRadIASemanticMutationMock.Create('source', 'current-revision'),
    TRadIASemanticPatchServiceMock.Create
  );
  LResult := LService.PrepareMissingMembers(
    'Sample.pas',
    'stale-revision',
    'TWorker'
  );
  Assert.IsFalse(LResult.Success);
  Assert.AreEqual('precondition_failed', LResult.ErrorCode);
  Assert.AreEqual(0, LClient.RequestCount);
end;

procedure TRadIASemanticMemberServiceTests.
  RegistersReadOnlyToolWithApplyPatchHandoff;
var
  LRegistry: IRadIAToolRegistry;
  LResult: TRadIAToolResult;
  LService: IRadIASemanticMemberService;
  LTool: IRadIATool;
begin
  LService := CreateService(
    TRadIASemanticRequestClientMock.Create(True),
    TRadIASemanticMutationMock.Create('source', 'revision-1'),
    TRadIASemanticPatchServiceMock.Create
  );
  LRegistry := TRadIAToolRegistry.Create;
  RegisterRadIASemanticMemberTools(LRegistry, LService);
  LTool := LRegistry.Resolve('PrepareMissingMembers');
  Assert.AreEqual(trReadOnly, LTool.Descriptor.Risk);
  Assert.IsTrue(LTool.Descriptor.Idempotent);
  LResult := LTool.Execute(TRadIAToolRequest.Create(
    'PrepareMissingMembers',
    '{"targetFile":"Sample.pas","baseRevision":"revision-1",' +
    '"container":"TWorker"}',
    'semantic-test'
  ));
  Assert.IsTrue(LResult.Success, LResult.ErrorMessage);
  Assert.Contains(LResult.ContentJson, '"previewId":"semantic-preview"');
  Assert.Contains(LResult.ContentJson, '"changed":true');
end;

initialization
  TDUnitX.RegisterTestFixture(TRadIASemanticMemberServiceTests);

end.
