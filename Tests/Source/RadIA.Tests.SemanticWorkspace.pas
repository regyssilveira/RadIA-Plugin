unit RadIA.Tests.SemanticWorkspace;

interface

implementation

uses
  System.Generics.Collections,
  System.SysUtils,
  DUnitX.TestFramework,
  RadIA.Semantic.Index,
  RadIA.Semantic.Workspace;

type
  TRadIARecordedSemanticRequest = record
    Method: string;
    Parameters: string;
  end;

  TRadIAFakeSemanticRequestClient = class(
    TInterfacedObject,
    IRadIASemanticRequestClient
  )
  private
    FRestartCount: Integer;
    FRestartOnNextRequest: Boolean;
    FRequests: TList<TRadIARecordedSemanticRequest>;
  public
    constructor Create;
    destructor Destroy; override;
    function CountMethod(const AMethod: string): Integer;
    function GetRestartCount: Integer;
    function ParameterAt(const AIndex: Integer): string;
    function Request(
      const AMethod: string;
      const AParameters: string;
      out AResponse: string;
      out AError: string
    ): Boolean;
    procedure RestartOnNextRequest;
  end;

  [TestFixture]
  TRadIASemanticWorkspaceTests = class
  private
    FClient: TRadIAFakeSemanticRequestClient;
    FClientInterface: IRadIASemanticRequestClient;
    FSynchronizer: IRadIASemanticWorkspaceSynchronizer;
    function SampleFiles: TArray<TRadIASemanticWorkspaceFile>;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    [Test]
    procedure IndexesEveryWorkspaceScope;
    [Test]
    procedure SendsOnlyChangedRevisions;
    [Test]
    procedure RemovesUnitsMissingFromSnapshot;
    [Test]
    procedure ReplaysSnapshotAfterEngineRestart;
  end;

{ TRadIAFakeSemanticRequestClient }

constructor TRadIAFakeSemanticRequestClient.Create;
begin
  inherited Create;
  FRequests := TList<TRadIARecordedSemanticRequest>.Create;
end;

destructor TRadIAFakeSemanticRequestClient.Destroy;
begin
  FRequests.Free;
  inherited Destroy;
end;

function TRadIAFakeSemanticRequestClient.CountMethod(
  const AMethod: string
): Integer;
var
  LRequest: TRadIARecordedSemanticRequest;
begin
  Result := 0;
  for LRequest in FRequests do
    if SameText(LRequest.Method, AMethod) then
      Inc(Result);
end;

function TRadIAFakeSemanticRequestClient.GetRestartCount: Integer;
begin
  Result := FRestartCount;
end;

function TRadIAFakeSemanticRequestClient.ParameterAt(
  const AIndex: Integer
): string;
begin
  Result := FRequests[AIndex].Parameters;
end;

function TRadIAFakeSemanticRequestClient.Request(
  const AMethod: string;
  const AParameters: string;
  out AResponse: string;
  out AError: string
): Boolean;
var
  LRequest: TRadIARecordedSemanticRequest;
begin
  if FRestartOnNextRequest then
  begin
    Inc(FRestartCount);
    FRestartOnNextRequest := False;
  end;
  LRequest.Method := AMethod;
  LRequest.Parameters := AParameters;
  FRequests.Add(LRequest);
  AResponse := '{"result":{"changed":true}}';
  AError := '';
  Result := True;
end;

procedure TRadIAFakeSemanticRequestClient.RestartOnNextRequest;
begin
  FRestartOnNextRequest := True;
end;

{ TRadIASemanticWorkspaceTests }

function TRadIASemanticWorkspaceTests.SampleFiles:
  TArray<TRadIASemanticWorkspaceFile>;
begin
  Result := [
    TRadIASemanticWorkspaceFile.Create(
      'project.sample',
      'Project.Sample.pas',
      susProject,
      'project-1',
      'unit Project.Sample; interface implementation end.'
    ),
    TRadIASemanticWorkspaceFile.Create(
      'group.sample',
      'Group.Sample.pas',
      susGroup,
      'group-1',
      'unit Group.Sample; interface implementation end.'
    ),
    TRadIASemanticWorkspaceFile.Create(
      'rtl.system',
      'System.pas',
      susRTL,
      'rtl-1',
      'unit System; interface implementation end.'
    ),
    TRadIASemanticWorkspaceFile.Create(
      'vcl.forms',
      'Vcl.Forms.pas',
      susVCL,
      'vcl-1',
      'unit Vcl.Forms; interface implementation end.'
    )
  ];
end;

procedure TRadIASemanticWorkspaceTests.Setup;
begin
  FClient := TRadIAFakeSemanticRequestClient.Create;
  FClientInterface := FClient;
  FSynchronizer := TRadIASemanticWorkspaceSynchronizer.Create(
    FClientInterface
  );
end;

procedure TRadIASemanticWorkspaceTests.TearDown;
begin
  FSynchronizer := nil;
  FClientInterface := nil;
  FClient := nil;
end;

procedure TRadIASemanticWorkspaceTests.IndexesEveryWorkspaceScope;
var
  LError: string;
  LFiles: TArray<TRadIASemanticWorkspaceFile>;
begin
  LFiles := SampleFiles;
  Assert.IsTrue(FSynchronizer.Synchronize(LFiles, ['DEBUG'], LError), LError);
  Assert.AreEqual(4, FClient.CountMethod('indexUnit'));
  Assert.Contains(FClient.ParameterAt(0), '"scope":"project"');
  Assert.Contains(FClient.ParameterAt(1), '"scope":"group"');
  Assert.Contains(FClient.ParameterAt(2), '"scope":"rtl"');
  Assert.Contains(FClient.ParameterAt(3), '"scope":"vcl"');
  Assert.Contains(FClient.ParameterAt(0), '"DEBUG"');
end;

procedure TRadIASemanticWorkspaceTests.SendsOnlyChangedRevisions;
var
  LError: string;
  LFiles: TArray<TRadIASemanticWorkspaceFile>;
begin
  LFiles := SampleFiles;
  Assert.IsTrue(FSynchronizer.Synchronize(LFiles, nil, LError), LError);
  Assert.IsTrue(FSynchronizer.Synchronize(LFiles, nil, LError), LError);
  Assert.AreEqual(4, FClient.CountMethod('indexUnit'));
  LFiles[0] := TRadIASemanticWorkspaceFile.Create(
    'project.sample',
    'Project.Sample.pas',
    susProject,
    'project-2',
    'unit Project.Sample; interface const Changed = True; implementation end.'
  );
  Assert.IsTrue(FSynchronizer.Synchronize(LFiles, nil, LError), LError);
  Assert.AreEqual(5, FClient.CountMethod('indexUnit'));
end;

procedure TRadIASemanticWorkspaceTests.RemovesUnitsMissingFromSnapshot;
var
  LError: string;
  LFiles: TArray<TRadIASemanticWorkspaceFile>;
begin
  LFiles := SampleFiles;
  Assert.IsTrue(FSynchronizer.Synchronize(LFiles, nil, LError), LError);
  SetLength(LFiles, 3);
  Assert.IsTrue(FSynchronizer.Synchronize(LFiles, nil, LError), LError);
  Assert.AreEqual(1, FClient.CountMethod('removeUnit'));
  Assert.Contains(FClient.ParameterAt(4), '"unitKey":"vcl.forms"');
end;

procedure TRadIASemanticWorkspaceTests.ReplaysSnapshotAfterEngineRestart;
var
  LError: string;
  LFiles: TArray<TRadIASemanticWorkspaceFile>;
begin
  LFiles := SampleFiles;
  Assert.IsTrue(FSynchronizer.Synchronize(LFiles, nil, LError), LError);
  LFiles[0] := TRadIASemanticWorkspaceFile.Create(
    'project.sample',
    'Project.Sample.pas',
    susProject,
    'project-2',
    'unit Project.Sample; interface implementation end.'
  );
  FClient.RestartOnNextRequest;
  Assert.IsTrue(FSynchronizer.Synchronize(LFiles, nil, LError), LError);
  Assert.AreEqual(9, FClient.CountMethod('indexUnit'));
end;

initialization
  TDUnitX.RegisterTestFixture(TRadIASemanticWorkspaceTests);

end.
