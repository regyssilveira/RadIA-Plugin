unit RadIA.Core.JourneyContext;

interface

uses
  System.Generics.Collections;

type
  TRadIAJourneyActivityState = (
    jasIdle,
    jasRunning,
    jasCancellationRequested
  );

  TRadIAJourneyContextSnapshot = record
  private
    FConversationId: string;
    FExecutorId: string;
    FJourneyId: string;
    FProjectId: string;
    FState: TRadIAJourneyActivityState;
  public
    constructor Create(
      const AJourneyId: string;
      const AConversationId: string;
      const AProjectId: string;
      const AExecutorId: string;
      const AState: TRadIAJourneyActivityState = jasIdle
    );
    function IsLinked: Boolean;
    function MatchesProject(const AProjectId: string): Boolean;
    property ConversationId: string read FConversationId;
    property ExecutorId: string read FExecutorId;
    property JourneyId: string read FJourneyId;
    property ProjectId: string read FProjectId;
    property State: TRadIAJourneyActivityState read FState;
  end;

  IRadIAJourneyContextCoordinator = interface
    ['{02631228-4FAE-4787-B9AE-5105720BDFF8}']
    function Activate(
      const AConversationId: string;
      const AProjectId: string;
      const AExecutorId: string
    ): TRadIAJourneyContextSnapshot;
    function Detach(const AConversationId: string): Boolean;
    function SwitchTo(
      const AJourneyId: string;
      const AProjectId: string
    ): Boolean;
    function TryGetActive(
      out ASnapshot: TRadIAJourneyContextSnapshot
    ): Boolean;
    function TryGetForConversation(
      const AConversationId: string;
      out ASnapshot: TRadIAJourneyContextSnapshot
    ): Boolean;
    function TryGetByJourney(
      const AJourneyId: string;
      out ASnapshot: TRadIAJourneyContextSnapshot
    ): Boolean;
    procedure UpdateExecutor(const AExecutorId: string);
    procedure BeginActivity;
    procedure RequestCancellation;
    procedure CompleteActivity;
  end;

  TRadIAJourneyContextCoordinator = class(
    TInterfacedObject,
    IRadIAJourneyContextCoordinator
  )
  private
    FActiveJourneyId: string;
    FByConversation: TDictionary<string, TRadIAJourneyContextSnapshot>;
    FLock: TObject;
    class function CreateJourneyId: string; static;
    class function NormalizeIdentity(const AValue: string): string; static;
    procedure SetActiveState(const AState: TRadIAJourneyActivityState);
  public
    constructor Create;
    destructor Destroy; override;
    function Activate(
      const AConversationId: string;
      const AProjectId: string;
      const AExecutorId: string
    ): TRadIAJourneyContextSnapshot;
    function Detach(const AConversationId: string): Boolean;
    function SwitchTo(
      const AJourneyId: string;
      const AProjectId: string
    ): Boolean;
    function TryGetActive(
      out ASnapshot: TRadIAJourneyContextSnapshot
    ): Boolean;
    function TryGetForConversation(
      const AConversationId: string;
      out ASnapshot: TRadIAJourneyContextSnapshot
    ): Boolean;
    function TryGetByJourney(
      const AJourneyId: string;
      out ASnapshot: TRadIAJourneyContextSnapshot
    ): Boolean;
    procedure UpdateExecutor(const AExecutorId: string);
    procedure BeginActivity;
    procedure RequestCancellation;
    procedure CompleteActivity;
  end;

  TRadIAJourneyContextEnricher = class
  public
    class function EnrichProjectContext(
      const ABaseContext: string;
      const AProjectFolder: string;
      const ACoordinator: IRadIAJourneyContextCoordinator
    ): string; static;
  end;

implementation

uses
  System.SysUtils;

{ TRadIAJourneyContextSnapshot }

constructor TRadIAJourneyContextSnapshot.Create(
  const AJourneyId: string;
  const AConversationId: string;
  const AProjectId: string;
  const AExecutorId: string;
  const AState: TRadIAJourneyActivityState
);
begin
  FJourneyId := Trim(AJourneyId);
  FConversationId := Trim(AConversationId);
  FProjectId := Trim(AProjectId);
  FExecutorId := LowerCase(Trim(AExecutorId));
  FState := AState;
end;

function TRadIAJourneyContextSnapshot.IsLinked: Boolean;
begin
  Result := (JourneyId <> '') and (ConversationId <> '') and
    (ProjectId <> '');
end;

function TRadIAJourneyContextSnapshot.MatchesProject(
  const AProjectId: string
): Boolean;
begin
  Result := (ProjectId <> '') and SameText(ProjectId, Trim(AProjectId));
end;

{ TRadIAJourneyContextCoordinator }

constructor TRadIAJourneyContextCoordinator.Create;
begin
  inherited Create;
  FLock := TObject.Create;
  FByConversation := TDictionary<string, TRadIAJourneyContextSnapshot>.Create;
end;

destructor TRadIAJourneyContextCoordinator.Destroy;
begin
  FByConversation.Free;
  FLock.Free;
  inherited Destroy;
end;

class function TRadIAJourneyContextCoordinator.CreateJourneyId: string;
var
  LGuid: TGUID;
begin
  CreateGUID(LGuid);
  Result := LGuid.ToString.Replace('{', '').Replace('}', '').ToLower;
end;

class function TRadIAJourneyContextCoordinator.NormalizeIdentity(
  const AValue: string
): string;
begin
  Result := LowerCase(Trim(AValue));
end;

function TRadIAJourneyContextCoordinator.Activate(
  const AConversationId: string;
  const AProjectId: string;
  const AExecutorId: string
): TRadIAJourneyContextSnapshot;
var
  LConversationId: string;
  LProjectId: string;
begin
  LConversationId := NormalizeIdentity(AConversationId);
  LProjectId := Trim(AProjectId);
  if LConversationId = '' then
    raise EArgumentException.Create('The conversation id is required.');
  if LProjectId = '' then
    raise EArgumentException.Create('The project id is required.');
  TMonitor.Enter(FLock);
  try
    if not FByConversation.TryGetValue(LConversationId, Result) or
      not Result.MatchesProject(LProjectId) then
      Result := TRadIAJourneyContextSnapshot.Create(
        CreateJourneyId,
        LConversationId,
        LProjectId,
        AExecutorId,
        jasIdle
      )
    else if not SameText(Result.ExecutorId, AExecutorId) then
      Result := TRadIAJourneyContextSnapshot.Create(
        Result.JourneyId,
        Result.ConversationId,
        Result.ProjectId,
        AExecutorId,
        Result.State
      );
    FByConversation.AddOrSetValue(LConversationId, Result);
    FActiveJourneyId := Result.JourneyId;
  finally
    TMonitor.Exit(FLock);
  end;
end;

function TRadIAJourneyContextCoordinator.Detach(
  const AConversationId: string
): Boolean;
var
  LConversationId: string;
  LSnapshot: TRadIAJourneyContextSnapshot;
begin
  LConversationId := NormalizeIdentity(AConversationId);
  TMonitor.Enter(FLock);
  try
    Result := FByConversation.TryGetValue(LConversationId, LSnapshot);
    if not Result then
      Exit;
    FByConversation.Remove(LConversationId);
    if SameText(FActiveJourneyId, LSnapshot.JourneyId) then
      FActiveJourneyId := '';
  finally
    TMonitor.Exit(FLock);
  end;
end;

function TRadIAJourneyContextCoordinator.SwitchTo(
  const AJourneyId: string;
  const AProjectId: string
): Boolean;
var
  LSnapshot: TRadIAJourneyContextSnapshot;
begin
  Result := False;
  TMonitor.Enter(FLock);
  try
    for LSnapshot in FByConversation.Values do
      if SameText(LSnapshot.JourneyId, Trim(AJourneyId)) and
        LSnapshot.MatchesProject(AProjectId) then
      begin
        FActiveJourneyId := LSnapshot.JourneyId;
        Exit(True);
      end;
  finally
    TMonitor.Exit(FLock);
  end;
end;

function TRadIAJourneyContextCoordinator.TryGetActive(
  out ASnapshot: TRadIAJourneyContextSnapshot
): Boolean;
var
  LSnapshot: TRadIAJourneyContextSnapshot;
begin
  ASnapshot := Default(TRadIAJourneyContextSnapshot);
  TMonitor.Enter(FLock);
  try
    for LSnapshot in FByConversation.Values do
      if SameText(LSnapshot.JourneyId, FActiveJourneyId) then
      begin
        ASnapshot := LSnapshot;
        Exit(True);
      end;
    Result := False;
  finally
    TMonitor.Exit(FLock);
  end;
end;

function TRadIAJourneyContextCoordinator.TryGetForConversation(
  const AConversationId: string;
  out ASnapshot: TRadIAJourneyContextSnapshot
): Boolean;
begin
  TMonitor.Enter(FLock);
  try
    Result := FByConversation.TryGetValue(
      NormalizeIdentity(AConversationId),
      ASnapshot
    );
    if not Result then
      ASnapshot := Default(TRadIAJourneyContextSnapshot);
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure TRadIAJourneyContextCoordinator.UpdateExecutor(
  const AExecutorId: string
);
var
  LSnapshot: TRadIAJourneyContextSnapshot;
begin
  if not TryGetActive(LSnapshot) then
    Exit;
  Activate(
    LSnapshot.ConversationId,
    LSnapshot.ProjectId,
    AExecutorId
  );
end;

function TRadIAJourneyContextCoordinator.TryGetByJourney(
  const AJourneyId: string;
  out ASnapshot: TRadIAJourneyContextSnapshot
): Boolean;
var
  LSnapshot: TRadIAJourneyContextSnapshot;
begin
  ASnapshot := Default(TRadIAJourneyContextSnapshot);
  TMonitor.Enter(FLock);
  try
    for LSnapshot in FByConversation.Values do
      if SameText(LSnapshot.JourneyId, Trim(AJourneyId)) then
      begin
        ASnapshot := LSnapshot;
        Exit(True);
      end;
    Result := False;
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure TRadIAJourneyContextCoordinator.SetActiveState(
  const AState: TRadIAJourneyActivityState
);
var
  LSnapshot: TRadIAJourneyContextSnapshot;
  LUpdatedSnapshot: TRadIAJourneyContextSnapshot;
begin
  TMonitor.Enter(FLock);
  try
    for LSnapshot in FByConversation.Values do
      if SameText(LSnapshot.JourneyId, FActiveJourneyId) then
      begin
        LUpdatedSnapshot := TRadIAJourneyContextSnapshot.Create(
          LSnapshot.JourneyId,
          LSnapshot.ConversationId,
          LSnapshot.ProjectId,
          LSnapshot.ExecutorId,
          AState
        );
        FByConversation.AddOrSetValue(
          LUpdatedSnapshot.ConversationId,
          LUpdatedSnapshot
        );
        Exit;
      end;
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure TRadIAJourneyContextCoordinator.BeginActivity;
begin
  SetActiveState(jasRunning);
end;

procedure TRadIAJourneyContextCoordinator.RequestCancellation;
begin
  SetActiveState(jasCancellationRequested);
end;

procedure TRadIAJourneyContextCoordinator.CompleteActivity;
begin
  SetActiveState(jasIdle);
end;

class function TRadIAJourneyContextEnricher.EnrichProjectContext(
  const ABaseContext: string;
  const AProjectFolder: string;
  const ACoordinator: IRadIAJourneyContextCoordinator
): string;
var
  LActivity: string;
  LSnapshot: TRadIAJourneyContextSnapshot;
begin
  Result := ABaseContext;
  if not Assigned(ACoordinator) or
    not ACoordinator.TryGetActive(LSnapshot) or
    not SameFileName(ExtractFileDir(LSnapshot.ProjectId), AProjectFolder) then
    Exit;
  case LSnapshot.State of
    jasRunning:
      LActivity := 'running';
    jasCancellationRequested:
      LActivity := 'cancelling';
  else
    LActivity := 'idle';
  end;
  Result := Result + sLineBreak +
    'Journey: ' + LSnapshot.JourneyId + sLineBreak +
    'Conversation: ' + LSnapshot.ConversationId + sLineBreak +
    'Executor: ' + LSnapshot.ExecutorId + sLineBreak +
    'Activity: ' + LActivity;
end;

end.
