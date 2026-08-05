unit RadIA.Core.CoverageTools;

interface

uses
  RadIA.Core.Tools,
  RadIA.Core.Workspace,
  RadIA.Core.WorkspaceBoundary;

procedure RegisterRadIACoverageTools(
  const ARegistry: IRadIAToolRegistry;
  const AWorkspace: IRadIAWorkspaceFacade;
  const ABoundary: IRadIAWorkspaceBoundary
);

implementation

uses
  System.IOUtils,
  System.JSON,
  System.SysUtils,
  RadIA.Core.Coverage;

type
  TRadIAGetCoverageSummaryTool = class(TInterfacedObject, IRadIATool)
  private
    FWorkspace: IRadIAWorkspaceFacade;
    FBoundary: IRadIAWorkspaceBoundary;
    function GetReportPath(const AArgumentsJson: string): string;
  public
    constructor Create(
      const AWorkspace: IRadIAWorkspaceFacade;
      const ABoundary: IRadIAWorkspaceBoundary
    );
    function Execute(
      const ARequest: TRadIAToolRequest
    ): TRadIAToolResult;
    function GetDescriptor: TRadIAToolDescriptor;
  end;

const
  CDefaultReportPath = 'Output\Coverage\CodeCoverage_Summary.xml';
  CInputSchema =
    '{"type":"object","properties":{"reportPath":{"type":"string",' +
    '"minLength":1}},"additionalProperties":false}';
  COutputSchema =
    '{"type":"object","required":["reportPath","summary"],"properties":{' +
    '"reportPath":{"type":"string"},"summary":{"type":"object"}}}';

{ TRadIAGetCoverageSummaryTool }

constructor TRadIAGetCoverageSummaryTool.Create(
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

function TRadIAGetCoverageSummaryTool.Execute(
  const ARequest: TRadIAToolRequest
): TRadIAToolResult;
var
  LOutput: TJSONObject;
  LParser: TRadIACoverageSummaryParser;
  LPath: string;
  LProject: TRadIAProjectSnapshot;
  LSummary: TRadIACoverageSummary;
  LSummaryJson: TJSONValue;
  LValidation: TRadIAPathValidation;
  LXml: string;
begin
  LProject := FWorkspace.GetActiveProject;
  if Trim(LProject.RootPath) = '' then
    Exit(TRadIAToolResult.Failed(
      'no_active_project',
      'An active project with a workspace root is required.'
    ));
  try
    LPath := GetReportPath(ARequest.ArgumentsJson);
  except
    on E: EArgumentException do
      Exit(TRadIAToolResult.Failed('invalid_request', E.Message));
  end;
  LValidation := FBoundary.ValidatePath(LProject.RootPath, LPath);
  if not LValidation.Allowed then
    Exit(TRadIAToolResult.Failed(
      LValidation.ErrorCode,
      LValidation.ErrorMessage
    ));
  if not TFile.Exists(LValidation.ResolvedPath) then
    Exit(TRadIAToolResult.Failed(
      'coverage_report_not_found',
      'The coverage report does not exist.'
    ));
  LParser := TRadIACoverageSummaryParser.Create;
  try
    try
      LXml := TFile.ReadAllText(
        LValidation.ResolvedPath,
        TEncoding.Default
      );
      LSummary := LParser.Parse(LXml);
    except
      on E: Exception do
        Exit(TRadIAToolResult.Failed(
          'invalid_coverage_report',
          E.Message
        ));
    end;
  finally
    LParser.Free;
  end;
  LOutput := TJSONObject.Create;
  try
    LOutput.AddPair('reportPath', LValidation.ResolvedPath);
    LSummaryJson := TJSONObject.ParseJSONValue(LSummary.ToJson);
    LOutput.AddPair('summary', LSummaryJson);
    Result := TRadIAToolResult.Succeeded(LOutput.ToJSON);
  finally
    LOutput.Free;
  end;
end;

function TRadIAGetCoverageSummaryTool.GetDescriptor:
  TRadIAToolDescriptor;
begin
  Result := TRadIAToolDescriptor.Create(
    'GetCoverageSummary',
    '1.0.0',
    'Read an authoritative Delphi Code Coverage summary from the workspace.',
    CInputSchema,
    COutputSchema,
    trReadOnly
  );
end;

function TRadIAGetCoverageSummaryTool.GetReportPath(
  const AArgumentsJson: string
): string;
var
  LJson: TJSONObject;
begin
  LJson := TJSONObject.ParseJSONValue(AArgumentsJson) as TJSONObject;
  if not Assigned(LJson) then
    raise EArgumentException.Create(
      'Coverage arguments must be a valid JSON object.'
    );
  try
    Result := Trim(LJson.GetValue<string>('reportPath', CDefaultReportPath));
    if Result = '' then
      raise EArgumentException.Create('Coverage report path cannot be empty.');
  finally
    LJson.Free;
  end;
end;

procedure RegisterRadIACoverageTools(
  const ARegistry: IRadIAToolRegistry;
  const AWorkspace: IRadIAWorkspaceFacade;
  const ABoundary: IRadIAWorkspaceBoundary
);
begin
  if not Assigned(ARegistry) then
    raise EArgumentNilException.Create('ARegistry');
  ARegistry.RegisterTool(
    TRadIAGetCoverageSummaryTool.Create(AWorkspace, ABoundary)
  );
end;

end.
