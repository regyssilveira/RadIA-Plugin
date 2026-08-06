unit RadIA.Core.ProjectTemplateService;

interface

uses
  System.Generics.Collections,
  RadIA.Core.ProjectOpening,
  RadIA.Core.ProjectTemplates,
  RadIA.Core.ProjectTransaction,
  RadIA.Core.Workspace,
  RadIA.Core.WorkspaceBoundary;

type
  TRadIAProjectTemplateOperationResult = record
  private
    FSuccess: Boolean;
    FErrorCode: string;
    FErrorMessage: string;
    FPreviewId: string;
    FDestinationPath: string;
    FPreviewJson: string;
    FCommitted: Boolean;
    FRolledBack: Boolean;
    FOpened: Boolean;
    FProjectFileName: string;
  public
    class function Failed(
      const AErrorCode: string;
      const AErrorMessage: string
    ): TRadIAProjectTemplateOperationResult; static;
    class function Succeeded(
      const APreviewId: string;
      const ADestinationPath: string;
      const APreviewJson: string;
      const ACommitted: Boolean;
      const ARolledBack: Boolean;
      const AOpened: Boolean = False;
      const AProjectFileName: string = ''
    ): TRadIAProjectTemplateOperationResult; static;
    property Success: Boolean read FSuccess;
    property ErrorCode: string read FErrorCode;
    property ErrorMessage: string read FErrorMessage;
    property PreviewId: string read FPreviewId;
    property DestinationPath: string read FDestinationPath;
    property PreviewJson: string read FPreviewJson;
    property Committed: Boolean read FCommitted;
    property RolledBack: Boolean read FRolledBack;
    property Opened: Boolean read FOpened;
    property ProjectFileName: string read FProjectFileName;
  end;

  IRadIAProjectTemplateService = interface
    ['{47008A15-1989-4BBA-A8FD-37D59285F811}']
    function Preview(
      const ARequest: TRadIAProjectTemplateRequest;
      const ADestinationPath: string
    ): TRadIAProjectTemplateOperationResult;
    function Commit(
      const APreviewId: string
    ): TRadIAProjectTemplateOperationResult;
    function Rollback(
      const APreviewId: string
    ): TRadIAProjectTemplateOperationResult;
    function Open(
      const APreviewId: string
    ): TRadIAProjectTemplateOperationResult;
    procedure Clear;
  end;

  IRadIAAuthorizedProjectTemplateService = interface
    ['{8925024F-C881-4195-885A-9A20720950B1}']
    function PreviewAtAuthorizedRoot(
      const ARequest: TRadIAProjectTemplateRequest;
      const AAuthorizedRoot: string;
      const ADestinationPath: string
    ): TRadIAProjectTemplateOperationResult;
  end;

  TRadIAProjectTemplateSession = class
  private
    FRequest: TRadIAProjectTemplateRequest;
    FPreviewId: string;
    FDestinationPath: string;
    FPreviewJson: string;
    FTransaction: TRadIAProjectTemplateTransaction;
    FOpened: Boolean;
  public
    constructor Create(
      const ARequest: TRadIAProjectTemplateRequest;
      const APreviewId: string;
      const ADestinationPath: string;
      const APreviewJson: string
    );
    destructor Destroy; override;
    property Request: TRadIAProjectTemplateRequest read FRequest;
    property PreviewId: string read FPreviewId;
    property DestinationPath: string read FDestinationPath;
    property PreviewJson: string read FPreviewJson;
    property Transaction: TRadIAProjectTemplateTransaction
      read FTransaction write FTransaction;
    property Opened: Boolean read FOpened write FOpened;
  end;

  TRadIAProjectTemplateService = class(
    TInterfacedObject,
    IRadIAProjectTemplateService,
    IRadIAAuthorizedProjectTemplateService
  )
  private
    FWorkspace: IRadIAWorkspaceFacade;
    FBoundary: IRadIAWorkspaceBoundary;
    FOpening: IRadIAProjectOpeningFacade;
    FSessions: TObjectDictionary<string, TRadIAProjectTemplateSession>;
    function GetSession(
      const APreviewId: string
    ): TRadIAProjectTemplateSession;
    procedure StabilizeNewDestinationRollback(
      const ADestinationPath: string
    );
    function CreatePreviewAtRoot(
      const ARequest: TRadIAProjectTemplateRequest;
      const AAuthorizedRoot: string;
      const ADestinationPath: string
    ): TRadIAProjectTemplateOperationResult;
  public
    constructor Create(
      const AWorkspace: IRadIAWorkspaceFacade;
      const ABoundary: IRadIAWorkspaceBoundary;
      const AOpening: IRadIAProjectOpeningFacade
    );
    destructor Destroy; override;
    function Preview(
      const ARequest: TRadIAProjectTemplateRequest;
      const ADestinationPath: string
    ): TRadIAProjectTemplateOperationResult;
    function PreviewAtAuthorizedRoot(
      const ARequest: TRadIAProjectTemplateRequest;
      const AAuthorizedRoot: string;
      const ADestinationPath: string
    ): TRadIAProjectTemplateOperationResult;
    function Commit(
      const APreviewId: string
    ): TRadIAProjectTemplateOperationResult;
    function Rollback(
      const APreviewId: string
    ): TRadIAProjectTemplateOperationResult;
    function Open(
      const APreviewId: string
    ): TRadIAProjectTemplateOperationResult;
    procedure Clear;
  end;

implementation

uses
  System.Classes,
  System.Hash,
  System.IOUtils,
  System.SysUtils;

const
  CInvalidPreview = 'invalid_preview';
  CPreconditionFailed = 'precondition_failed';

{ TRadIAProjectTemplateOperationResult }

class function TRadIAProjectTemplateOperationResult.Failed(
  const AErrorCode: string;
  const AErrorMessage: string
): TRadIAProjectTemplateOperationResult;
begin
  Result.FSuccess := False;
  Result.FErrorCode := AErrorCode;
  Result.FErrorMessage := AErrorMessage;
end;

class function TRadIAProjectTemplateOperationResult.Succeeded(
  const APreviewId: string;
  const ADestinationPath: string;
  const APreviewJson: string;
  const ACommitted: Boolean;
  const ARolledBack: Boolean;
  const AOpened: Boolean;
  const AProjectFileName: string
): TRadIAProjectTemplateOperationResult;
begin
  Result.FSuccess := True;
  Result.FPreviewId := APreviewId;
  Result.FDestinationPath := ADestinationPath;
  Result.FPreviewJson := APreviewJson;
  Result.FCommitted := ACommitted;
  Result.FRolledBack := ARolledBack;
  Result.FOpened := AOpened;
  Result.FProjectFileName := AProjectFileName;
end;

{ TRadIAProjectTemplateSession }

constructor TRadIAProjectTemplateSession.Create(
  const ARequest: TRadIAProjectTemplateRequest;
  const APreviewId: string;
  const ADestinationPath: string;
  const APreviewJson: string
);
begin
  inherited Create;
  FRequest := ARequest;
  FPreviewId := APreviewId;
  FDestinationPath := ADestinationPath;
  FPreviewJson := APreviewJson;
end;

destructor TRadIAProjectTemplateSession.Destroy;
begin
  FTransaction.Free;
  inherited Destroy;
end;

{ TRadIAProjectTemplateService }

procedure TRadIAProjectTemplateService.Clear;
begin
  TMonitor.Enter(FSessions);
  try
    FSessions.Clear;
  finally
    TMonitor.Exit(FSessions);
  end;
end;

function TRadIAProjectTemplateService.Commit(
  const APreviewId: string
): TRadIAProjectTemplateOperationResult;
var
  LEngine: TRadIAProjectTemplateEngine;
  LPlan: TRadIAProjectTemplatePlan;
  LSession: TRadIAProjectTemplateSession;
begin
  TMonitor.Enter(FSessions);
  try
    LSession := GetSession(APreviewId);
    if not Assigned(LSession) then
      Exit(TRadIAProjectTemplateOperationResult.Failed(
        CInvalidPreview,
        'Project template preview was not found.'
      ));
    if Assigned(LSession.Transaction) then
      Exit(TRadIAProjectTemplateOperationResult.Failed(
        CPreconditionFailed,
        'Project template preview was already committed.'
      ));

    LEngine := TRadIAProjectTemplateEngine.Create;
    try
      LPlan := LEngine.BuildPlan(LSession.Request);
      try
        LSession.Transaction := TRadIAProjectTemplateTransaction.Create;
        try
          LSession.Transaction.Prepare(
            LPlan,
            LSession.DestinationPath
          );
          LSession.Transaction.Commit;
        except
          FreeAndNil(LSession.FTransaction);
          raise;
        end;
      finally
        LPlan.Free;
      end;
    finally
      LEngine.Free;
    end;
    Result := TRadIAProjectTemplateOperationResult.Succeeded(
      LSession.PreviewId,
      LSession.DestinationPath,
      LSession.PreviewJson,
      True,
      False,
      False,
      ''
    );
  finally
    TMonitor.Exit(FSessions);
  end;
end;

constructor TRadIAProjectTemplateService.Create(
  const AWorkspace: IRadIAWorkspaceFacade;
  const ABoundary: IRadIAWorkspaceBoundary;
  const AOpening: IRadIAProjectOpeningFacade
);
begin
  inherited Create;
  if not Assigned(AWorkspace) then
    raise EArgumentNilException.Create('AWorkspace');
  if not Assigned(ABoundary) then
    raise EArgumentNilException.Create('ABoundary');
  if not Assigned(AOpening) then
    raise EArgumentNilException.Create('AOpening');
  FWorkspace := AWorkspace;
  FBoundary := ABoundary;
  FOpening := AOpening;
  FSessions := TObjectDictionary<
    string,
    TRadIAProjectTemplateSession
  >.Create(
    [doOwnsValues]
  );
end;

function TRadIAProjectTemplateService.Open(
  const APreviewId: string
): TRadIAProjectTemplateOperationResult;
var
  LProjectFileName: string;
  LSession: TRadIAProjectTemplateSession;
begin
  TMonitor.Enter(FSessions);
  try
    LSession := GetSession(APreviewId);
    if not Assigned(LSession) then
      Exit(TRadIAProjectTemplateOperationResult.Failed(
        CInvalidPreview,
        'Project template preview was not found.'
      ));
    if not Assigned(LSession.Transaction) or
      (LSession.Transaction.State <> ptsCommitted) then
      Exit(TRadIAProjectTemplateOperationResult.Failed(
        CPreconditionFailed,
        'Project must be committed before it can be opened.'
      ));
    LProjectFileName := TPath.Combine(
      LSession.DestinationPath,
      LSession.Request.ProjectName + '.dproj'
    );
    if not FOpening.OpenProject(LProjectFileName) then
      Exit(TRadIAProjectTemplateOperationResult.Failed(
        'project_open_failed',
        'The Delphi IDE could not open the generated project.'
      ));
    LSession.Opened := True;
    Result := TRadIAProjectTemplateOperationResult.Succeeded(
      LSession.PreviewId,
      LSession.DestinationPath,
      LSession.PreviewJson,
      True,
      False,
      True,
      LProjectFileName
    );
  finally
    TMonitor.Exit(FSessions);
  end;
end;

destructor TRadIAProjectTemplateService.Destroy;
begin
  FSessions.Free;
  inherited Destroy;
end;

function TRadIAProjectTemplateService.GetSession(
  const APreviewId: string
): TRadIAProjectTemplateSession;
begin
  Result := nil;
  if Trim(APreviewId) <> '' then
    FSessions.TryGetValue(
      APreviewId,
      Result
    );
end;

function TRadIAProjectTemplateService.Preview(
  const ARequest: TRadIAProjectTemplateRequest;
  const ADestinationPath: string
): TRadIAProjectTemplateOperationResult;
var
  LProject: TRadIAProjectSnapshot;
begin
  LProject := FWorkspace.GetActiveProject;
  if LProject.RootPath = '' then
    Exit(TRadIAProjectTemplateOperationResult.Failed(
      CPreconditionFailed,
      'An active project is required to authorize the workspace root.'
    ));
  Result := CreatePreviewAtRoot(
    ARequest,
    LProject.RootPath,
    ADestinationPath
  );
end;

function TRadIAProjectTemplateService.PreviewAtAuthorizedRoot(
  const ARequest: TRadIAProjectTemplateRequest;
  const AAuthorizedRoot: string;
  const ADestinationPath: string
): TRadIAProjectTemplateOperationResult;
begin
  Result := CreatePreviewAtRoot(
    ARequest,
    AAuthorizedRoot,
    ADestinationPath
  );
end;

function TRadIAProjectTemplateService.CreatePreviewAtRoot(
  const ARequest: TRadIAProjectTemplateRequest;
  const AAuthorizedRoot: string;
  const ADestinationPath: string
): TRadIAProjectTemplateOperationResult;
var
  LEngine: TRadIAProjectTemplateEngine;
  LPlan: TRadIAProjectTemplatePlan;
  LPreviewId: string;
  LPreviewJson: string;
  LSession: TRadIAProjectTemplateSession;
  LValidation: TRadIAPathValidation;
begin
  LValidation := FBoundary.ValidatePath(
    AAuthorizedRoot,
    ADestinationPath
  );
  if not LValidation.Allowed then
    Exit(TRadIAProjectTemplateOperationResult.Failed(
      LValidation.ErrorCode,
      LValidation.ErrorMessage
    ));
  LEngine := TRadIAProjectTemplateEngine.Create;
  try
    LPlan := LEngine.BuildPlan(ARequest);
    try
      LPreviewJson := LPlan.PreviewJson;
      LPreviewId := LowerCase(
        THashSHA2.GetHashString(
          LValidation.ResolvedPath + '|' + LPreviewJson + '|' +
          TGUID.NewGuid.ToString
        )
      );
    finally
      LPlan.Free;
    end;
  finally
    LEngine.Free;
  end;
  LSession := TRadIAProjectTemplateSession.Create(
    ARequest,
    LPreviewId,
    LValidation.ResolvedPath,
    LPreviewJson
  );
  TMonitor.Enter(FSessions);
  try
    try
      FSessions.Add(LPreviewId, LSession);
    except
      LSession.Free;
      raise;
    end;
  finally
    TMonitor.Exit(FSessions);
  end;
  Result := TRadIAProjectTemplateOperationResult.Succeeded(
    LPreviewId,
    LValidation.ResolvedPath,
    LPreviewJson,
    False,
    False,
    False,
    ''
  );
end;

function TRadIAProjectTemplateService.Rollback(
  const APreviewId: string
): TRadIAProjectTemplateOperationResult;
var
  LDestinationExisted: Boolean;
  LSession: TRadIAProjectTemplateSession;
begin
  TMonitor.Enter(FSessions);
  try
    LSession := GetSession(APreviewId);
    if not Assigned(LSession) then
      Exit(TRadIAProjectTemplateOperationResult.Failed(
        CInvalidPreview,
        'Project template preview was not found.'
      ));
    if not Assigned(LSession.Transaction) then
      Exit(TRadIAProjectTemplateOperationResult.Failed(
        CPreconditionFailed,
        'Project template preview has not been committed.'
      ));
    if LSession.Opened then
    begin
      if not FOpening.CloseProject(
        TPath.Combine(
          LSession.DestinationPath,
          LSession.Request.ProjectName + '.dproj'
        )
      ) then
        Exit(TRadIAProjectTemplateOperationResult.Failed(
          'project_close_failed',
          'The generated project could not be closed before rollback.'
        ));
      LSession.Opened := False;
    end;
    LDestinationExisted := LSession.Transaction.DestinationExisted;
    LSession.Transaction.Rollback;
    if not LDestinationExisted then
      StabilizeNewDestinationRollback(LSession.DestinationPath);
    Result := TRadIAProjectTemplateOperationResult.Succeeded(
      LSession.PreviewId,
      LSession.DestinationPath,
      LSession.PreviewJson,
      False,
      True,
      False,
      ''
    );
  finally
    TMonitor.Exit(FSessions);
  end;
end;

procedure TRadIAProjectTemplateService.StabilizeNewDestinationRollback(
  const ADestinationPath: string
);
var
  LAttempt: Integer;
begin
  for LAttempt := 1 to 3 do
  begin
    if TDirectory.Exists(ADestinationPath) then
      TDirectory.Delete(ADestinationPath, True);
    TThread.Sleep(100);
  end;
  if TDirectory.Exists(ADestinationPath) then
    TDirectory.Delete(ADestinationPath, True);
end;

end.
