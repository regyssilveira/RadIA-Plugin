unit RadIA.OTA.ProblemProjector;

interface

uses
  RadIA.Core.Interfaces,
  RadIA.Core.ProblemProjection,
  RadIA.Core.WorkspaceBoundary;

type
  TRadIAOTAProblemProjector = class(
    TInterfacedObject,
    IRadIAProblemProjector
  )
  private
    FBoundary: IRadIAWorkspaceBoundary;
    FIDEAdapter: IRadIAIDEAdapter;
    function ResolveFileName(const AFileName: string): string;
  public
    constructor Create(
      const ABoundary: IRadIAWorkspaceBoundary;
      const AIDEAdapter: IRadIAIDEAdapter
    );
    function ProjectSnapshot(
      const AJson: string;
      out AProjectedCount: Integer;
      out AError: string
    ): Boolean;
  end;

implementation

uses
  System.SysUtils,
  ToolsAPI;

const
  CMessageGroupName = 'RadIA Problems';

constructor TRadIAOTAProblemProjector.Create(
  const ABoundary: IRadIAWorkspaceBoundary;
  const AIDEAdapter: IRadIAIDEAdapter
);
begin
  inherited Create;
  FBoundary := ABoundary;
  FIDEAdapter := AIDEAdapter;
end;

function TRadIAOTAProblemProjector.ProjectSnapshot(
  const AJson: string;
  out AProjectedCount: Integer;
  out AError: string
): Boolean;
var
  LFileName: string;
  LGroup: IOTAMessageGroup;
  LLineReference: Pointer;
  LMessage: string;
  LMessageServices: IOTAMessageServices;
  LProblem: TRadIAProjectedProblem;
  LProblems: TArray<TRadIAProjectedProblem>;
begin
  AProjectedCount := 0;
  AError := '';
  if not TRadIAProblemProjectionParser.Parse(AJson, LProblems, AError) then
    Exit(False);
  if not Supports(
    BorlandIDEServices,
    IOTAMessageServices,
    LMessageServices
  ) then
  begin
    AError := 'Delphi Message View services are unavailable.';
    Exit(False);
  end;
  LGroup := LMessageServices.GetGroup(CMessageGroupName);
  if not Assigned(LGroup) then
    LGroup := LMessageServices.AddMessageGroup(CMessageGroupName);
  if not Assigned(LGroup) then
  begin
    AError := 'The RadIA Problems message group could not be created.';
    Exit(False);
  end;
  LMessageServices.ClearMessageGroup(LGroup);
  for LProblem in LProblems do
  begin
    LFileName := ResolveFileName(LProblem.FileName);
    LMessage := LProblem.Title + ': ' + LProblem.Message;
    LLineReference := nil;
    LMessageServices.AddWideToolMessage(
      LFileName,
      LMessage,
      'RadIA ' + LProblem.Severity,
      LProblem.Line,
      LProblem.Column,
      nil,
      LLineReference,
      LGroup
    );
    Inc(AProjectedCount);
  end;
  LMessageServices.ShowMessageView(LGroup);
  Result := True;
end;

function TRadIAOTAProblemProjector.ResolveFileName(
  const AFileName: string
): string;
var
  LProjectFolder: string;
  LValidation: TRadIAPathValidation;
begin
  Result := '';
  if AFileName.Trim.IsEmpty or not Assigned(FBoundary) or
    not Assigned(FIDEAdapter) then
    Exit;
  LProjectFolder := FIDEAdapter.GetActiveProjectFolder;
  LValidation := FBoundary.ValidatePath(LProjectFolder, AFileName);
  if LValidation.Allowed then
    Result := LValidation.ResolvedPath;
end;

end.
