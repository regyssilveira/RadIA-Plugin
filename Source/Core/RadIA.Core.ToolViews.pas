unit RadIA.Core.ToolViews;

interface

uses
  RadIA.Core.Tools;

type
  TRadIAToolViewKind = (
    tvkDetails,
    tvkExplorer,
    tvkEditorNavigation,
    tvkDiff,
    tvkActivity
  );

  TRadIAToolViewIntent = record
  private
    FKind: TRadIAToolViewKind;
    FAction: string;
    FSourceTool: string;
  public
    constructor Create(
      const AKind: TRadIAToolViewKind;
      const AAction: string;
      const ASourceTool: string
    );
    function KindName: string;
    property Kind: TRadIAToolViewKind read FKind;
    property Action: string read FAction;
    property SourceTool: string read FSourceTool;
  end;

  IRadIAToolViewResolver = interface
    ['{20CD41CE-AFF5-4537-AD4A-B0C1FBAD8B76}']
    function Resolve(
      const AToolName: string
    ): TRadIAToolViewIntent;
    function Attach(
      const AToolName: string;
      const AResult: TRadIAToolResult
    ): TRadIAToolResult;
  end;

  TRadIAToolViewResolver = class(
    TInterfacedObject,
    IRadIAToolViewResolver
  )
  private
    function IsActivityTool(const AToolName: string): Boolean;
    function IsDiffTool(const AToolName: string): Boolean;
    function IsExplorerTool(const AToolName: string): Boolean;
  public
    function Resolve(
      const AToolName: string
    ): TRadIAToolViewIntent;
    function Attach(
      const AToolName: string;
      const AResult: TRadIAToolResult
    ): TRadIAToolResult;
  end;

implementation

uses
  System.JSON,
  System.StrUtils,
  System.SysUtils,
  RadIA.Core.Problems;

{ TRadIAToolViewIntent }

constructor TRadIAToolViewIntent.Create(
  const AKind: TRadIAToolViewKind;
  const AAction: string;
  const ASourceTool: string
);
begin
  FKind := AKind;
  FAction := AAction;
  FSourceTool := ASourceTool;
end;

function TRadIAToolViewIntent.KindName: string;
begin
  case Kind of
    tvkDetails:
      Result := 'details';
    tvkExplorer:
      Result := 'explorer';
    tvkEditorNavigation:
      Result := 'editor_navigation';
    tvkDiff:
      Result := 'diff';
    tvkActivity:
      Result := 'activity';
  else
    Result := 'details';
  end;
end;

{ TRadIAToolViewResolver }

function TRadIAToolViewResolver.Attach(
  const AToolName: string;
  const AResult: TRadIAToolResult
): TRadIAToolResult;
var
  LIntent: TRadIAToolViewIntent;
  LPair: TJSONPair;
  LRoot: TJSONObject;
  LProblems: TJSONArray;
  LValue: TJSONValue;
  LView: TJSONObject;
begin
  Result := AResult;
  if not AResult.Success then
    Exit;
  LValue := TJSONObject.ParseJSONValue(AResult.ContentJson);
  try
    if not (LValue is TJSONObject) then
      Exit;
    LRoot := TJSONObject(LValue);
    if not Assigned(LRoot.GetValue('_radiaView')) then
    begin
      LIntent := Resolve(AToolName);
      LView := TJSONObject.Create;
      LView.AddPair('version', TJSONNumber.Create(1));
      LView.AddPair('kind', LIntent.KindName);
      LView.AddPair('action', LIntent.Action);
      LView.AddPair('sourceTool', LIntent.SourceTool);
      LRoot.AddPair('_radiaView', LView);
    end;
    LPair := LRoot.RemovePair('_radiaProblems');
    LPair.Free;
    LProblems := TRadIAProblemExtractor.Extract(AToolName, LRoot);
    LRoot.AddPair('_radiaProblems', LProblems);
    Result := TRadIAToolResult.Succeeded(
      LRoot.ToJSON,
      AResult.Truncated
    );
  finally
    LValue.Free;
  end;
end;

function TRadIAToolViewResolver.IsActivityTool(
  const AToolName: string
): Boolean;
begin
  Result :=
    ContainsText(AToolName, 'Build') or
    ContainsText(AToolName, 'Debug') or
    ContainsText(AToolName, 'DUnitX') or
    ContainsText(AToolName, 'Test') or
    ContainsText(AToolName, 'Timeline');
end;

function TRadIAToolViewResolver.IsDiffTool(
  const AToolName: string
): Boolean;
begin
  Result :=
    StartsText('Prepare', AToolName) or
    StartsText('Preview', AToolName) or
    SameText(AToolName, 'GetGitDiff');
end;

function TRadIAToolViewResolver.IsExplorerTool(
  const AToolName: string
): Boolean;
begin
  Result :=
    ContainsText(AToolName, 'Project') or
    ContainsText(AToolName, 'UnitSymbols') or
    ContainsText(AToolName, 'IDEState') or
    ContainsText(AToolName, 'OpenFiles') or
    ContainsText(AToolName, 'FormComponents');
end;

function TRadIAToolViewResolver.Resolve(
  const AToolName: string
): TRadIAToolViewIntent;
begin
  if StartsText('Navigate', AToolName) then
    Exit(
      TRadIAToolViewIntent.Create(
        tvkEditorNavigation,
        'focus_editor',
        AToolName
      )
    );
  if IsDiffTool(AToolName) then
    Exit(
      TRadIAToolViewIntent.Create(
        tvkDiff,
        'show_diff',
        AToolName
      )
    );
  if IsActivityTool(AToolName) then
    Exit(
      TRadIAToolViewIntent.Create(
        tvkActivity,
        'show_activity',
        AToolName
      )
    );
  if IsExplorerTool(AToolName) then
    Exit(
      TRadIAToolViewIntent.Create(
        tvkExplorer,
        'show_explorer',
        AToolName
      )
    );
  Result := TRadIAToolViewIntent.Create(
    tvkDetails,
    'show_details',
    AToolName
  );
end;

end.
