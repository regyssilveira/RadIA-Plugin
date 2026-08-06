unit RadIA.OTA.DebugTimelineStore;

interface

uses
  RadIA.Core.DebugTimeline,
  RadIA.Core.Workspace,
  RadIA.Core.WorkspaceBoundary;

type
  TRadIAOTADebugTimelineStore = class(
    TInterfacedObject,
    IRadIADebugTimelineStore
  )
  private
    FWorkspace: IRadIAWorkspaceFacade;
    FBoundary: IRadIAWorkspaceBoundary;
  public
    constructor Create(
      const AWorkspace: IRadIAWorkspaceFacade;
      const ABoundary: IRadIAWorkspaceBoundary
    );
    procedure Append(const AEvent: TRadIADebugEvent);
  end;

implementation

uses
  System.Classes,
  System.IOUtils,
  System.JSON,
  System.SysUtils;

constructor TRadIAOTADebugTimelineStore.Create(
  const AWorkspace: IRadIAWorkspaceFacade;
  const ABoundary: IRadIAWorkspaceBoundary
);
begin
  inherited Create;
  if not Assigned(AWorkspace) then
    raise EArgumentNilException.Create('AWorkspace');
  if not Assigned(ABoundary) then
    raise EArgumentNilException.Create('ABoundary');
  FWorkspace := AWorkspace;
  FBoundary := ABoundary;
end;

procedure TRadIAOTADebugTimelineStore.Append(
  const AEvent: TRadIADebugEvent
);
var
  LDirectory: string;
  LFilePath: string;
  LJson: TJSONObject;
  LMode: Word;
  LProject: TRadIAProjectSnapshot;
  LStream: TFileStream;
  LText: TBytes;
  LValidation: TRadIAPathValidation;
begin
  LProject := FWorkspace.GetActiveProject;
  if Trim(LProject.RootPath) = '' then
    Exit;
  LFilePath := TPath.Combine(
    LProject.RootPath,
    '.radia\debug\timeline.jsonl'
  );
  LValidation := FBoundary.ValidatePath(
    LProject.RootPath,
    LFilePath
  );
  if not LValidation.Allowed then
    Exit;
  LFilePath := LValidation.ResolvedPath;
  LDirectory := ExtractFileDir(LFilePath);
  TDirectory.CreateDirectory(LDirectory);
  LJson := TJSONObject.Create;
  try
    LJson.AddPair(
      'sequence',
      TJSONNumber.Create(AEvent.Sequence)
    );
    LJson.AddPair('timestampUtc', AEvent.TimestampUtc);
    LJson.AddPair('kind', RadIADebugEventKindName(AEvent.Kind));
    LJson.AddPair(
      'processId',
      TJSONNumber.Create(AEvent.ProcessId)
    );
    LJson.AddPair('state', AEvent.State);
    LJson.AddPair('details', AEvent.Details);
    LText := TEncoding.UTF8.GetBytes(
      LJson.ToJSON + sLineBreak
    );
  finally
    LJson.Free;
  end;
  if TFile.Exists(LFilePath) then
    LMode := fmOpenReadWrite or fmShareDenyWrite
  else
    LMode := fmCreate or fmShareDenyWrite;
  LStream := TFileStream.Create(LFilePath, LMode);
  try
    LStream.Seek(0, soEnd);
    if Length(LText) > 0 then
      LStream.WriteBuffer(LText[0], Length(LText));
  finally
    LStream.Free;
  end;
end;

end.
