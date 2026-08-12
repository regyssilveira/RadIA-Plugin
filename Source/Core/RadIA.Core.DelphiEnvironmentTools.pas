unit RadIA.Core.DelphiEnvironmentTools;

interface

uses
  RadIA.Core.DelphiEnvironment,
  RadIA.Core.Tools;

procedure RegisterRadIADelphiEnvironmentTools(
  const ARegistry: IRadIAToolRegistry;
  const AService: IRadIADelphiEnvironmentService
);

implementation

uses
  System.JSON,
  System.SysUtils;

type
  TRadIAGetDelphiEnvironmentProfileTool = class(
    TInterfacedObject,
    IRadIATool
  )
  private
    FService: IRadIADelphiEnvironmentService;
    procedure AddStringArray(
      const ARoot: TJSONObject;
      const AName: string;
      const AValues: TArray<string>
    );
    function GetDescriptor: TRadIAToolDescriptor;
  public
    constructor Create(const AService: IRadIADelphiEnvironmentService);
    function Execute(
      const ARequest: TRadIAToolRequest
    ): TRadIAToolResult;
  end;

const
  CEmptyInputSchema =
    '{"type":"object","additionalProperties":false}';
  CProfileOutputSchema =
    '{"type":"object","required":["ide","project","capabilities",' +
    '"searchPaths","packages","libraries"]}';

procedure RegisterRadIADelphiEnvironmentTools(
  const ARegistry: IRadIAToolRegistry;
  const AService: IRadIADelphiEnvironmentService
);
begin
  if not Assigned(ARegistry) then
    raise EArgumentNilException.Create('ARegistry');
  if not Assigned(AService) then
    raise EArgumentNilException.Create('AService');
  ARegistry.RegisterTool(
    TRadIAGetDelphiEnvironmentProfileTool.Create(AService)
  );
end;

{ TRadIAGetDelphiEnvironmentProfileTool }

constructor TRadIAGetDelphiEnvironmentProfileTool.Create(
  const AService: IRadIADelphiEnvironmentService
);
begin
  inherited Create;
  if not Assigned(AService) then
    raise EArgumentNilException.Create('AService');
  FService := AService;
end;

procedure TRadIAGetDelphiEnvironmentProfileTool.AddStringArray(
  const ARoot: TJSONObject;
  const AName: string;
  const AValues: TArray<string>
);
var
  LArray: TJSONArray;
  LValue: string;
begin
  LArray := TJSONArray.Create;
  ARoot.AddPair(AName, LArray);
  for LValue in AValues do
    LArray.Add(LValue);
end;

function TRadIAGetDelphiEnvironmentProfileTool.Execute(
  const ARequest: TRadIAToolRequest
): TRadIAToolResult;
var
  LIDE: TJSONObject;
  LProfile: TRadIADelphiEnvironmentProfile;
  LProject: TJSONObject;
  LRoot: TJSONObject;
begin
  LProfile := FService.BuildProfile;
  LRoot := TJSONObject.Create;
  try
    LIDE := TJSONObject.Create;
    LIDE.AddPair('version', LProfile.IDEVersion);
    LIDE.AddPair('architecture', LProfile.IDEArchitecture);
    LIDE.AddPair('sku', LProfile.IDESKU);
    LIDE.AddPair('source', 'ota');
    LRoot.AddPair('ide', LIDE);

    LProject := TJSONObject.Create;
    LProject.AddPair('name', LProfile.ProjectName);
    LProject.AddPair('framework', LProfile.Framework);
    LProject.AddPair('configuration', LProfile.Configuration);
    LProject.AddPair('targetPlatform', LProfile.TargetPlatform);
    LProject.AddPair('source', 'workspace-and-dproj');
    LRoot.AddPair('project', LProject);

    AddStringArray(LRoot, 'capabilities', LProfile.Capabilities);
    AddStringArray(LRoot, 'searchPaths', LProfile.SearchPaths);
    AddStringArray(LRoot, 'packages', LProfile.Packages);
    AddStringArray(LRoot, 'libraries', LProfile.Libraries);
    Result := TRadIAToolResult.Succeeded(LRoot.ToJSON);
  finally
    LRoot.Free;
  end;
end;

function TRadIAGetDelphiEnvironmentProfileTool.GetDescriptor:
  TRadIAToolDescriptor;
begin
  Result := TRadIAToolDescriptor.Create(
    'GetDelphiEnvironmentProfile',
    '1.0',
    'Returns a sanitized profile of the active Delphi IDE and project.',
    CEmptyInputSchema,
    CProfileOutputSchema,
    trReadOnly
  );
end;

end.
