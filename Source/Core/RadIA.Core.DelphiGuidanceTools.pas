unit RadIA.Core.DelphiGuidanceTools;

interface

uses
  RadIA.Core.DelphiGuidance,
  RadIA.Core.Tools;

procedure RegisterRadIADelphiGuidanceTools(
  const ARegistry: IRadIAToolRegistry;
  const ACatalog: IRadIADelphiGuidanceCatalog
);

implementation

uses
  System.JSON,
  System.SysUtils;

type
  TRadIAGetDelphiGuidanceTool = class(TInterfacedObject, IRadIATool)
  private
    FCatalog: IRadIADelphiGuidanceCatalog;
    function GetDescriptor: TRadIAToolDescriptor;
    function ParseQuery(
      const AArgumentsJson: string
    ): TRadIADelphiGuidanceQuery;
  public
    constructor Create(const ACatalog: IRadIADelphiGuidanceCatalog);
    function Execute(
      const ARequest: TRadIAToolRequest
    ): TRadIAToolResult;
  end;

const
  CGuidanceInputSchema =
    '{"type":"object","properties":{"version":{"type":"string"},' +
    '"framework":{"type":"string"},"architecture":{"type":"string"},' +
    '"topic":{"type":"string"},"id":{"type":"string"},' +
    '"maxCount":{"type":"integer","minimum":1,"maximum":50}},' +
    '"additionalProperties":false}';
  CGuidanceOutputSchema =
    '{"type":"object","required":["schemaVersion","rules"]}';

procedure RegisterRadIADelphiGuidanceTools(
  const ARegistry: IRadIAToolRegistry;
  const ACatalog: IRadIADelphiGuidanceCatalog
);
begin
  if not Assigned(ARegistry) then
    raise EArgumentNilException.Create('ARegistry');
  if not Assigned(ACatalog) then
    raise EArgumentNilException.Create('ACatalog');
  ARegistry.RegisterTool(TRadIAGetDelphiGuidanceTool.Create(ACatalog));
end;

{ TRadIAGetDelphiGuidanceTool }

constructor TRadIAGetDelphiGuidanceTool.Create(
  const ACatalog: IRadIADelphiGuidanceCatalog
);
begin
  inherited Create;
  if not Assigned(ACatalog) then
    raise EArgumentNilException.Create('ACatalog');
  FCatalog := ACatalog;
end;

function TRadIAGetDelphiGuidanceTool.Execute(
  const ARequest: TRadIAToolRequest
): TRadIAToolResult;
var
  LArray: TJSONArray;
  LItem: TJSONObject;
  LRoot: TJSONObject;
  LRule: TRadIADelphiGuidanceRule;
  LRules: TArray<TRadIADelphiGuidanceRule>;
begin
  LRules := FCatalog.Query(ParseQuery(ARequest.ArgumentsJson));
  LRoot := TJSONObject.Create;
  try
    LRoot.AddPair('schemaVersion', TJSONNumber.Create(1));
    LArray := TJSONArray.Create;
    LRoot.AddPair('rules', LArray);
    for LRule in LRules do
    begin
      LItem := TJSONObject.Create;
      LItem.AddPair('schemaVersion', TJSONNumber.Create(LRule.SchemaVersion));
      LItem.AddPair('id', LRule.Id);
      LItem.AddPair('topic', LRule.Topic);
      LItem.AddPair('version', LRule.Version);
      LItem.AddPair('framework', LRule.Framework);
      LItem.AddPair('architecture', LRule.Architecture);
      LItem.AddPair('guidance', LRule.Guidance);
      LItem.AddPair('citation', LRule.Citation);
      LItem.AddPair('source', 'built-in');
      LArray.AddElement(LItem);
    end;
    LRoot.AddPair('count', TJSONNumber.Create(Length(LRules)));
    Result := TRadIAToolResult.Succeeded(LRoot.ToJSON);
  finally
    LRoot.Free;
  end;
end;

function TRadIAGetDelphiGuidanceTool.GetDescriptor:
  TRadIAToolDescriptor;
begin
  Result := TRadIAToolDescriptor.Create(
    'GetDelphiGuidance',
    '1.0',
    'Returns cited Delphi guidance filtered by environment and topic.',
    CGuidanceInputSchema,
    CGuidanceOutputSchema,
    trReadOnly
  );
end;

function TRadIAGetDelphiGuidanceTool.ParseQuery(
  const AArgumentsJson: string
): TRadIADelphiGuidanceQuery;
var
  LJson: TJSONObject;
begin
  LJson := TJSONObject.ParseJSONValue(AArgumentsJson) as TJSONObject;
  if not Assigned(LJson) then
    raise EArgumentException.Create('Guidance arguments must be a JSON object.');
  try
    Result := TRadIADelphiGuidanceQuery.Create(
      LJson.GetValue<string>('version', 'any'),
      LJson.GetValue<string>('framework', 'any'),
      LJson.GetValue<string>('architecture', 'any'),
      LJson.GetValue<string>('topic', ''),
      LJson.GetValue<string>('id', ''),
      LJson.GetValue<Integer>('maxCount', 20)
    );
  finally
    LJson.Free;
  end;
end;

end.
