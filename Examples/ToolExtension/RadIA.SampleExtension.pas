unit RadIA.SampleExtension;

interface

implementation

uses
  System.JSON,
  RadIA.Core.Extensions,
  RadIA.Core.Tools;

type
  TRadIASampleProjectInfoTool = class(
    TInterfacedObject,
    IRadIATool
  )
  private
    FDescriptor: TRadIAToolDescriptor;
  public
    constructor Create;
    function GetDescriptor: TRadIAToolDescriptor;
    function Execute(
      const ARequest: TRadIAToolRequest
    ): TRadIAToolResult;
  end;

  TRadIASampleToolExtension = class(
    TInterfacedObject,
    IRadIAToolExtension
  )
  private
    FDescriptor: TRadIAToolExtensionDescriptor;
  public
    constructor Create;
    function GetDescriptor: TRadIAToolExtensionDescriptor;
    procedure RegisterTools(
      const ARegistrar: IRadIAToolExtensionRegistrar
    );
  end;

var
  GRegistration: IRadIAToolExtensionRegistration;

{ TRadIASampleProjectInfoTool }

constructor TRadIASampleProjectInfoTool.Create;
begin
  inherited Create;
  FDescriptor := TRadIAToolDescriptor.Create(
    'SampleProjectInfo',
    '1.0.0',
    'Returns the project identity supplied by the secure RadIA pipeline.',
    '{"type":"object","additionalProperties":false}',
    '{"type":"object","required":["projectId"]}',
    trReadOnly
  );
end;

function TRadIASampleProjectInfoTool.Execute(
  const ARequest: TRadIAToolRequest
): TRadIAToolResult;
var
  LResult: TJSONObject;
begin
  LResult := TJSONObject.Create;
  try
    LResult.AddPair('projectId', ARequest.ProjectId);
    Result := TRadIAToolResult.Succeeded(LResult.ToJSON);
  finally
    LResult.Free;
  end;
end;

function TRadIASampleProjectInfoTool.GetDescriptor:
  TRadIAToolDescriptor;
begin
  Result := FDescriptor;
end;

{ TRadIASampleToolExtension }

constructor TRadIASampleToolExtension.Create;
begin
  inherited Create;
  FDescriptor := TRadIAToolExtensionDescriptor.Create(
    'SampleExtension',
    '1.0.0',
    'Sample',
    CRadIAToolExtensionApiVersion,
    CRadIAToolExtensionApiVersion
  );
end;

function TRadIASampleToolExtension.GetDescriptor:
  TRadIAToolExtensionDescriptor;
begin
  Result := FDescriptor;
end;

procedure TRadIASampleToolExtension.RegisterTools(
  const ARegistrar: IRadIAToolExtensionRegistrar
);
begin
  ARegistrar.AddTool(TRadIASampleProjectInfoTool.Create);
end;

initialization
  GRegistration := RegisterRadIAToolExtension(
    TRadIASampleToolExtension.Create
  );

finalization
  GRegistration := nil;

end.
