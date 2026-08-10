unit RadIA.Core.SkillReplicas;

interface

uses
  System.Generics.Collections,
  RadIA.Core.SkillPortability;

type
  TRadIASkillReplicaState = (
    srsCreate,
    srsUpdate,
    srsUnchanged,
    srsConflict
  );

  TRadIASkillReplicaPlanItem = record
  private
    FArtifact: TRadIACliSkillArtifact;
    FAbsoluteFileName: string;
    FState: TRadIASkillReplicaState;
    FReason: string;
  public
    constructor Create(
      const AArtifact: TRadIACliSkillArtifact;
      const AAbsoluteFileName: string;
      const AState: TRadIASkillReplicaState;
      const AReason: string
    );
    property Artifact: TRadIACliSkillArtifact read FArtifact;
    property AbsoluteFileName: string read FAbsoluteFileName;
    property State: TRadIASkillReplicaState read FState;
    property Reason: string read FReason;
  end;

  TRadIASkillReplicaApplyResult = record
  private
    FCreated: Integer;
    FUpdated: Integer;
    FUnchanged: Integer;
  public
    constructor Create(
      const ACreated: Integer;
      const AUpdated: Integer;
      const AUnchanged: Integer
    );
    property Created: Integer read FCreated;
    property Updated: Integer read FUpdated;
    property Unchanged: Integer read FUnchanged;
  end;

  TRadIASkillReplicaService = class
  private type
    TRadIAOwnedReplica = record
      ExtensionId: string;
      ExecutorId: string;
      RelativeFileName: string;
      Hash: string;
    end;
    TRadIAFileBackup = record
      FileName: string;
      Existed: Boolean;
      Content: TArray<Byte>;
    end;
  private
    FProjectRoot: string;
    function AbsoluteFileName(const ARelativeFileName: string): string;
    procedure AtomicWriteBytes(
      const AFileName: string;
      const AContent: TArray<Byte>
    );
    function BuildOwnedReplica(
      const ASkill: TRadIACanonicalSkill;
      const AItem: TRadIASkillReplicaPlanItem
    ): TRadIAOwnedReplica;
    function FindOwnedReplica(
      const AItems: TArray<TRadIAOwnedReplica>;
      const ARelativeFileName: string;
      out AItem: TRadIAOwnedReplica
    ): Boolean;
    function HashBytes(const ABytes: TArray<Byte>): string;
    function HashFile(const AFileName: string): string;
    function ManifestFileName: string;
    function LoadOwnedReplicas: TArray<TRadIAOwnedReplica>;
    procedure RestoreBackups(const ABackups: TArray<TRadIAFileBackup>);
    procedure SaveOwnedReplicas(const AItems: TArray<TRadIAOwnedReplica>);
    function UpdateOwnedReplicas(
      const AExisting: TArray<TRadIAOwnedReplica>;
      const ASkill: TRadIACanonicalSkill;
      const APlan: TArray<TRadIASkillReplicaPlanItem>
    ): TArray<TRadIAOwnedReplica>;
    procedure ValidateProjectRoot;
  public
    constructor Create(const AProjectRoot: string);
    function BuildPlan(
      const ASkill: TRadIACanonicalSkill;
      const AExecutorIds: TArray<string>
    ): TArray<TRadIASkillReplicaPlanItem>;
    function Apply(
      const ASkill: TRadIACanonicalSkill;
      const AExecutorIds: TArray<string>
    ): TRadIASkillReplicaApplyResult;
    function RemoveOwned(const AExtensionId: string): string;
    class function StateName(const AState: TRadIASkillReplicaState): string;
      static;
    property ProjectRoot: string read FProjectRoot;
  end;

implementation

uses
  System.Classes,
  System.Hash,
  System.IOUtils,
  System.JSON,
  System.SysUtils,
  Winapi.Windows;

{ TRadIASkillReplicaPlanItem }

constructor TRadIASkillReplicaPlanItem.Create(
  const AArtifact: TRadIACliSkillArtifact;
  const AAbsoluteFileName: string;
  const AState: TRadIASkillReplicaState;
  const AReason: string
);
begin
  FArtifact := AArtifact;
  FAbsoluteFileName := AAbsoluteFileName;
  FState := AState;
  FReason := AReason;
end;

{ TRadIASkillReplicaApplyResult }

constructor TRadIASkillReplicaApplyResult.Create(
  const ACreated: Integer;
  const AUpdated: Integer;
  const AUnchanged: Integer
);
begin
  FCreated := ACreated;
  FUpdated := AUpdated;
  FUnchanged := AUnchanged;
end;

{ TRadIASkillReplicaService }

constructor TRadIASkillReplicaService.Create(const AProjectRoot: string);
begin
  inherited Create;
  FProjectRoot := ExcludeTrailingPathDelimiter(TPath.GetFullPath(AProjectRoot));
  ValidateProjectRoot;
end;

function TRadIASkillReplicaService.AbsoluteFileName(
  const ARelativeFileName: string
): string;
begin
  Result := TPath.GetFullPath(TPath.Combine(FProjectRoot, ARelativeFileName));
  if not Result.StartsWith(
    IncludeTrailingPathDelimiter(FProjectRoot),
    True
  ) then
    raise EArgumentException.Create('Skill replica path escapes the project root.');
end;

function TRadIASkillReplicaService.Apply(
  const ASkill: TRadIACanonicalSkill;
  const AExecutorIds: TArray<string>
): TRadIASkillReplicaApplyResult;
var
  LBackups: TArray<TRadIAFileBackup>;
  LBytes: TArray<Byte>;
  LCreated: Integer;
  LExisting: TArray<TRadIAOwnedReplica>;
  LIndex: Integer;
  LItem: TRadIASkillReplicaPlanItem;
  LPlan: TArray<TRadIASkillReplicaPlanItem>;
  LUnchanged: Integer;
  LUpdated: Integer;
begin
  LPlan := BuildPlan(ASkill, AExecutorIds);
  for LItem in LPlan do
    if LItem.State = srsConflict then
      raise EInvalidOpException.Create(
        'Skill replica conflict: ' + LItem.AbsoluteFileName
      );
  SetLength(LBackups, Length(LPlan));
  LCreated := 0;
  LUpdated := 0;
  LUnchanged := 0;
  try
    for LIndex := Low(LPlan) to High(LPlan) do
    begin
      LItem := LPlan[LIndex];
      LBackups[LIndex].FileName := LItem.AbsoluteFileName;
      LBackups[LIndex].Existed := TFile.Exists(LItem.AbsoluteFileName);
      if LBackups[LIndex].Existed then
        LBackups[LIndex].Content := TFile.ReadAllBytes(LItem.AbsoluteFileName);
      case LItem.State of
        srsCreate:
          Inc(LCreated);
        srsUpdate:
          Inc(LUpdated);
        srsUnchanged:
          begin
            Inc(LUnchanged);
            Continue;
          end;
      end;
      LBytes := TEncoding.UTF8.GetBytes(LItem.Artifact.Content);
      AtomicWriteBytes(LItem.AbsoluteFileName, LBytes);
    end;
    LExisting := LoadOwnedReplicas;
    SaveOwnedReplicas(UpdateOwnedReplicas(LExisting, ASkill, LPlan));
  except
    RestoreBackups(LBackups);
    raise;
  end;
  Result := TRadIASkillReplicaApplyResult.Create(
    LCreated,
    LUpdated,
    LUnchanged
  );
end;

procedure TRadIASkillReplicaService.AtomicWriteBytes(
  const AFileName: string;
  const AContent: TArray<Byte>
);
var
  LTemporaryFileName: string;
begin
  TDirectory.CreateDirectory(ExtractFilePath(AFileName));
  LTemporaryFileName := AFileName + '.' +
    TGUID.NewGuid.ToString.Replace('{', '').Replace('}', '') + '.tmp';
  TFile.WriteAllBytes(LTemporaryFileName, AContent);
  if not MoveFileEx(
    PChar(LTemporaryFileName),
    PChar(AFileName),
    MOVEFILE_REPLACE_EXISTING or MOVEFILE_WRITE_THROUGH
  ) then
  begin
    TFile.Delete(LTemporaryFileName);
    RaiseLastOSError;
  end;
end;

function TRadIASkillReplicaService.BuildOwnedReplica(
  const ASkill: TRadIACanonicalSkill;
  const AItem: TRadIASkillReplicaPlanItem
): TRadIAOwnedReplica;
begin
  Result.ExtensionId := ASkill.ExtensionId;
  Result.ExecutorId := AItem.Artifact.ExecutorId;
  Result.RelativeFileName := AItem.Artifact.RelativeFileName;
  Result.Hash := HashBytes(TEncoding.UTF8.GetBytes(AItem.Artifact.Content));
end;

function TRadIASkillReplicaService.BuildPlan(
  const ASkill: TRadIACanonicalSkill;
  const AExecutorIds: TArray<string>
): TArray<TRadIASkillReplicaPlanItem>;
var
  LAdapter: IRadIACliSkillAdapter;
  LArtifact: TRadIACliSkillArtifact;
  LExistingHash: string;
  LFileName: string;
  LIndex: Integer;
  LNewHash: string;
  LOwned: TRadIAOwnedReplica;
  LOwnedItems: TArray<TRadIAOwnedReplica>;
  LState: TRadIASkillReplicaState;
begin
  LOwnedItems := LoadOwnedReplicas;
  SetLength(Result, Length(AExecutorIds));
  for LIndex := Low(AExecutorIds) to High(AExecutorIds) do
  begin
    if not TRadIACliSkillAdapterRegistry.TryGet(
      AExecutorIds[LIndex],
      LAdapter
    ) then
      raise EArgumentException.Create(
        'Unsupported skill executor: ' + AExecutorIds[LIndex]
      );
    LArtifact := LAdapter.CreateArtifact(ASkill);
    LFileName := AbsoluteFileName(LArtifact.RelativeFileName);
    LNewHash := HashBytes(TEncoding.UTF8.GetBytes(LArtifact.Content));
    if not TFile.Exists(LFileName) then
      LState := srsCreate
    else
    begin
      LExistingHash := HashFile(LFileName);
      if SameText(LExistingHash, LNewHash) then
        LState := srsUnchanged
      else if FindOwnedReplica(LOwnedItems, LArtifact.RelativeFileName, LOwned) and
        SameText(LExistingHash, LOwned.Hash) then
        LState := srsUpdate
      else
        LState := srsConflict;
    end;
    Result[LIndex] := TRadIASkillReplicaPlanItem.Create(
      LArtifact,
      LFileName,
      LState,
      StateName(LState)
    );
  end;
end;

function TRadIASkillReplicaService.FindOwnedReplica(
  const AItems: TArray<TRadIAOwnedReplica>;
  const ARelativeFileName: string;
  out AItem: TRadIAOwnedReplica
): Boolean;
var
  LItem: TRadIAOwnedReplica;
begin
  for LItem in AItems do
    if SameText(LItem.RelativeFileName, ARelativeFileName) then
    begin
      AItem := LItem;
      Exit(True);
    end;
  Result := False;
end;

function TRadIASkillReplicaService.HashBytes(
  const ABytes: TArray<Byte>
): string;
var
  LByte: Byte;
  LHash: TBytes;
  LStream: TBytesStream;
begin
  Result := '';
  LStream := TBytesStream.Create(ABytes);
  try
    LHash := THashSHA2.GetHashBytes(LStream);
  finally
    LStream.Free;
  end;
  for LByte in LHash do
    Result := Result + Format('%.2x', [LByte]);
end;

function TRadIASkillReplicaService.HashFile(const AFileName: string): string;
begin
  Result := HashBytes(TFile.ReadAllBytes(AFileName));
end;

function TRadIASkillReplicaService.LoadOwnedReplicas:
  TArray<TRadIAOwnedReplica>;
var
  LArray: TJSONArray;
  LIndex: Integer;
  LJson: TJSONValue;
  LObject: TJSONObject;
begin
  SetLength(Result, 0);
  if not TFile.Exists(ManifestFileName) then
    Exit;
  LJson := TJSONObject.ParseJSONValue(
    TFile.ReadAllText(ManifestFileName, TEncoding.UTF8)
  );
  try
    if not (LJson is TJSONObject) then
      raise EInvalidOpException.Create('Skill replica ownership manifest is invalid.');
    LArray := TJSONObject(LJson).GetValue<TJSONArray>('replicas');
    if not Assigned(LArray) then
      Exit;
    SetLength(Result, LArray.Count);
    for LIndex := 0 to LArray.Count - 1 do
    begin
      if not (LArray.Items[LIndex] is TJSONObject) then
        raise EInvalidOpException.Create('Skill replica entry is invalid.');
      LObject := TJSONObject(LArray.Items[LIndex]);
      Result[LIndex].ExtensionId := LObject.GetValue<string>('extensionId');
      Result[LIndex].ExecutorId := LObject.GetValue<string>('executorId');
      Result[LIndex].RelativeFileName := LObject.GetValue<string>('path');
      Result[LIndex].Hash := LObject.GetValue<string>('sha256');
    end;
  finally
    LJson.Free;
  end;
end;

function TRadIASkillReplicaService.ManifestFileName: string;
begin
  Result := TPath.Combine(FProjectRoot, '.radia\skill-replicas.json');
end;

function TRadIASkillReplicaService.RemoveOwned(
  const AExtensionId: string
): string;
var
  LFileName: string;
  LItem: TRadIAOwnedReplica;
  LItems: TArray<TRadIAOwnedReplica>;
  LKept: TList<TRadIAOwnedReplica>;
  LPreserved: Integer;
  LRemoved: Integer;
begin
  LItems := LoadOwnedReplicas;
  LKept := TList<TRadIAOwnedReplica>.Create;
  try
    LPreserved := 0;
    LRemoved := 0;
    for LItem in LItems do
      if not SameText(LItem.ExtensionId, Trim(AExtensionId)) then
        LKept.Add(LItem)
      else
      begin
        LFileName := AbsoluteFileName(LItem.RelativeFileName);
        if not TFile.Exists(LFileName) then
          Continue;
        if SameText(HashFile(LFileName), LItem.Hash) then
        begin
          TFile.Delete(LFileName);
          Inc(LRemoved);
        end
        else
        begin
          LKept.Add(LItem);
          Inc(LPreserved);
        end;
      end;
    SaveOwnedReplicas(LKept.ToArray);
    Result := Format(
      'Removed: %d. Preserved because modified: %d.',
      [LRemoved, LPreserved]
    );
  finally
    LKept.Free;
  end;
end;

procedure TRadIASkillReplicaService.RestoreBackups(
  const ABackups: TArray<TRadIAFileBackup>
);
var
  LBackup: TRadIAFileBackup;
begin
  for LBackup in ABackups do
    if LBackup.FileName <> '' then
      if LBackup.Existed then
        AtomicWriteBytes(LBackup.FileName, LBackup.Content)
      else if TFile.Exists(LBackup.FileName) then
        TFile.Delete(LBackup.FileName);
end;

procedure TRadIASkillReplicaService.SaveOwnedReplicas(
  const AItems: TArray<TRadIAOwnedReplica>
);
var
  LArray: TJSONArray;
  LBytes: TArray<Byte>;
  LItem: TRadIAOwnedReplica;
  LRoot: TJSONObject;
begin
  LRoot := TJSONObject.Create;
  try
    LRoot.AddPair('schemaVersion', TJSONNumber.Create(1));
    LArray := TJSONArray.Create;
    LRoot.AddPair('replicas', LArray);
    for LItem in AItems do
      LArray.AddElement(
        TJSONObject.Create
          .AddPair('extensionId', LItem.ExtensionId)
          .AddPair('executorId', LItem.ExecutorId)
          .AddPair('path', LItem.RelativeFileName)
          .AddPair('sha256', LItem.Hash)
      );
    LBytes := TEncoding.UTF8.GetBytes(LRoot.Format(2));
    AtomicWriteBytes(ManifestFileName, LBytes);
  finally
    LRoot.Free;
  end;
end;

class function TRadIASkillReplicaService.StateName(
  const AState: TRadIASkillReplicaState
): string;
begin
  case AState of
    srsCreate:
      Result := 'create';
    srsUpdate:
      Result := 'update';
    srsUnchanged:
      Result := 'unchanged';
    srsConflict:
      Result := 'conflict: existing content is not owned by RadIA';
  else
    Result := 'unknown';
  end;
end;

function TRadIASkillReplicaService.UpdateOwnedReplicas(
  const AExisting: TArray<TRadIAOwnedReplica>;
  const ASkill: TRadIACanonicalSkill;
  const APlan: TArray<TRadIASkillReplicaPlanItem>
): TArray<TRadIAOwnedReplica>;
var
  LExisting: TRadIAOwnedReplica;
  LItem: TRadIASkillReplicaPlanItem;
  LList: TList<TRadIAOwnedReplica>;
begin
  LList := TList<TRadIAOwnedReplica>.Create;
  try
    for LExisting in AExisting do
      if not SameText(LExisting.ExtensionId, ASkill.ExtensionId) then
        LList.Add(LExisting);
    for LItem in APlan do
      LList.Add(BuildOwnedReplica(ASkill, LItem));
    Result := LList.ToArray;
  finally
    LList.Free;
  end;
end;

procedure TRadIASkillReplicaService.ValidateProjectRoot;
begin
  if not TDirectory.Exists(FProjectRoot) then
    raise EArgumentException.Create('Skill replica project root does not exist.');
end;

end.
