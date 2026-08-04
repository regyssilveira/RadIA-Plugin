unit RadIA.Core.DebugTimelineTools;

interface

uses
  RadIA.Core.DebugTimeline,
  RadIA.Core.Tools;

procedure RegisterRadIADebugTimelineTools(
  const ARegistry: IRadIAToolRegistry;
  const ATimeline: IRadIADebugTimeline
);

implementation

uses
  System.JSON,
  System.SysUtils;

type
  TRadIAGetDebugTimelineTool = class(
    TInterfacedObject,
    IRadIATool
  )
  private
    FTimeline: IRadIADebugTimeline;
  public
    constructor Create(const ATimeline: IRadIADebugTimeline);
    function Execute(
      const ARequest: TRadIAToolRequest
    ): TRadIAToolResult;
    function GetDescriptor: TRadIAToolDescriptor;
  end;

const
  CInputSchema =
    '{"type":"object","properties":{' +
    '"sinceSequence":{"type":"integer","minimum":0},' +
    '"maxCount":{"type":"integer","minimum":1,"maximum":500}},' +
    '"additionalProperties":false}';
  COutputSchema =
    '{"type":"object","required":["lastSequence","events"],' +
    '"properties":{"lastSequence":{"type":"integer"},' +
    '"events":{"type":"array"}}}';

constructor TRadIAGetDebugTimelineTool.Create(
  const ATimeline: IRadIADebugTimeline
);
begin
  inherited Create;
  if not Assigned(ATimeline) then
    raise EArgumentNilException.Create('ATimeline');
  FTimeline := ATimeline;
end;

function TRadIAGetDebugTimelineTool.Execute(
  const ARequest: TRadIAToolRequest
): TRadIAToolResult;
var
  LEvent: TRadIADebugEvent;
  LEventJson: TJSONObject;
  LEvents: TJSONArray;
  LJson: TJSONObject;
  LMaxCount: Integer;
  LRoot: TJSONObject;
  LSinceSequence: Int64;
begin
  LJson := TJSONObject.ParseJSONValue(
    ARequest.ArgumentsJson
  ) as TJSONObject;
  if not Assigned(LJson) then
    Exit(TRadIAToolResult.Failed(
      'invalid_request',
      'Timeline arguments must be a valid JSON object.'
    ));
  try
    LSinceSequence := LJson.GetValue<Int64>('sinceSequence', 0);
    LMaxCount := LJson.GetValue<Integer>('maxCount', 100);
    if (LSinceSequence < 0) or
      (LMaxCount < 1) or (LMaxCount > 500) then
      Exit(TRadIAToolResult.Failed(
        'invalid_range',
        'Timeline range is outside the allowed limits.'
      ));
    LRoot := TJSONObject.Create;
    try
      LRoot.AddPair(
        'lastSequence',
        TJSONNumber.Create(FTimeline.GetLastSequence)
      );
      LEvents := TJSONArray.Create;
      for LEvent in FTimeline.ListEvents(
        LSinceSequence,
        LMaxCount
      ) do
      begin
        LEventJson := TJSONObject.Create;
        LEventJson.AddPair(
          'sequence',
          TJSONNumber.Create(LEvent.Sequence)
        );
        LEventJson.AddPair('timestampUtc', LEvent.TimestampUtc);
        LEventJson.AddPair(
          'kind',
          RadIADebugEventKindName(LEvent.Kind)
        );
        LEventJson.AddPair(
          'processId',
          TJSONNumber.Create(LEvent.ProcessId)
        );
        LEventJson.AddPair('state', LEvent.State);
        LEventJson.AddPair('details', LEvent.Details);
        LEvents.AddElement(LEventJson);
      end;
      LRoot.AddPair('events', LEvents);
      Result := TRadIAToolResult.Succeeded(LRoot.ToJSON);
    finally
      LRoot.Free;
    end;
  finally
    LJson.Free;
  end;
end;

function TRadIAGetDebugTimelineTool.GetDescriptor:
  TRadIAToolDescriptor;
begin
  Result := TRadIAToolDescriptor.Create(
    'GetDebugTimeline',
    '1.0.0',
    'Read debugger lifecycle events captured from RAD Studio notifications.',
    CInputSchema,
    COutputSchema,
    trReadOnly
  );
end;

procedure RegisterRadIADebugTimelineTools(
  const ARegistry: IRadIAToolRegistry;
  const ATimeline: IRadIADebugTimeline
);
begin
  if not Assigned(ARegistry) then
    raise EArgumentNilException.Create('ARegistry');
  if not Assigned(ATimeline) then
    raise EArgumentNilException.Create('ATimeline');
  ARegistry.RegisterTool(TRadIAGetDebugTimelineTool.Create(ATimeline));
end;

end.
