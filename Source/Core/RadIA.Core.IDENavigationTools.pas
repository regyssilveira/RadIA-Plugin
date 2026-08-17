unit RadIA.Core.IDENavigationTools;

interface

uses
  RadIA.Core.IDENavigation,
  RadIA.Core.Tools;

procedure RegisterRadIAIDENavigationTools(
  const ARegistry: IRadIAToolRegistry;
  const ANavigation: IRadIAIDENavigationFacade
);

implementation

uses
  System.JSON,
  System.SysUtils;

type
  TRadIAIDENavigationToolKind = (
    intkListProjectGroupProjects,
    intkGetProjectDependencies,
    intkGetUnitSymbols,
    intkGetEditorSemanticContext,
    intkNavigateToFile,
    intkNavigateToSymbol,
    intkNavigateToDevelopmentSurface,
    intkListIDEActions,
    intkExecuteIDEAction
  );

  TRadIAIDENavigationTool = class(
    TInterfacedObject,
    IRadIATool
  )
  private
    FKind: TRadIAIDENavigationToolKind;
    FNavigation: IRadIAIDENavigationFacade;
    function BuildDescriptor(
      const AName: string;
      const ADescription: string;
      const AInputSchema: string;
      const ARisk: TRadIAToolRisk
    ): TRadIAToolDescriptor;
    function ExecuteGetProjectDependencies: TRadIAToolResult;
    function ExecuteGetUnitSymbols(
      const AArguments: TJSONObject
    ): TRadIAToolResult;
    function ExecuteGetEditorSemanticContext: TRadIAToolResult;
    function ExecuteListIDEActions: TRadIAToolResult;
    function ExecuteListProjectGroupProjects: TRadIAToolResult;
    function ExecuteNavigateToFile(
      const AArguments: TJSONObject
    ): TRadIAToolResult;
    function ExecuteNavigateToSymbol(
      const AArguments: TJSONObject
    ): TRadIAToolResult;
    function ExecuteNavigateToDevelopmentSurface(
      const AArguments: TJSONObject
    ): TRadIAToolResult;
    function ExecuteIDEAction(
      const AArguments: TJSONObject
    ): TRadIAToolResult;
    function GetDescriptor: TRadIAToolDescriptor;
    function GetInteger(
      const AArguments: TJSONObject;
      const AName: string;
      const ADefault: Integer;
      const AMinimum: Integer;
      const AMaximum: Integer
    ): Integer;
    function GetRequiredString(
      const AArguments: TJSONObject;
      const AName: string
    ): string;
    function NavigationResultToToolResult(
      const AResult: TRadIANavigationResult
    ): TRadIAToolResult;
    function StringArrayResult(
      const AName: string;
      const AValues: TArray<string>
    ): TRadIAToolResult;
  public
    constructor Create(
      const AKind: TRadIAIDENavigationToolKind;
      const ANavigation: IRadIAIDENavigationFacade
    );
    function Execute(
      const ARequest: TRadIAToolRequest
    ): TRadIAToolResult;
  end;

const
  CEmptyInputSchema =
    '{"type":"object","additionalProperties":false}';
  CObjectOutputSchema = '{"type":"object"}';
  CSymbolsInputSchema =
    '{"type":"object","properties":{"maxSymbols":{"type":"integer","minimum":1,' +
    '"maximum":5000}},"additionalProperties":false}';
  CNavigateFileInputSchema =
    '{"type":"object","required":["fileName"],"properties":{' +
    '"fileName":{"type":"string","minLength":1},' +
    '"line":{"type":"integer","minimum":1},' +
    '"column":{"type":"integer","minimum":1}},"additionalProperties":false}';
  CSymbolInputSchema =
    '{"type":"object","required":["symbol"],"properties":{' +
    '"symbol":{"type":"string","minLength":1}},"additionalProperties":false}';
  CDevelopmentSurfaceInputSchema =
    '{"type":"object","required":["fileName"],"properties":{' +
    '"fileName":{"type":"string","minLength":1},' +
    '"surface":{"type":"string","enum":["code","design"]},' +
    '"intent":{"type":"string","enum":["inspect-form","edit-layout",' +
    '"edit-properties","create-component","edit-code","implement-event",' +
    '"debug","test"]}},"additionalProperties":false,' +
    '"oneOf":[{"required":["surface"]},{"required":["intent"]}]}';
  CActionInputSchema =
    '{"type":"object","required":["actionName"],"properties":{' +
    '"actionName":{"type":"string","minLength":1}},"additionalProperties":false}';

procedure RegisterRadIAIDENavigationTools(
  const ARegistry: IRadIAToolRegistry;
  const ANavigation: IRadIAIDENavigationFacade
);
var
  LKind: TRadIAIDENavigationToolKind;
begin
  if not Assigned(ARegistry) then
    raise EArgumentNilException.Create('ARegistry');
  if not Assigned(ANavigation) then
    raise EArgumentNilException.Create('ANavigation');
  for LKind := Low(TRadIAIDENavigationToolKind) to
    High(TRadIAIDENavigationToolKind) do
    ARegistry.RegisterTool(
      TRadIAIDENavigationTool.Create(LKind, ANavigation)
    );
end;

{ TRadIAIDENavigationTool }

constructor TRadIAIDENavigationTool.Create(
  const AKind: TRadIAIDENavigationToolKind;
  const ANavigation: IRadIAIDENavigationFacade
);
begin
  inherited Create;
  if not Assigned(ANavigation) then
    raise EArgumentNilException.Create('ANavigation');
  FKind := AKind;
  FNavigation := ANavigation;
end;

function TRadIAIDENavigationTool.BuildDescriptor(
  const AName: string;
  const ADescription: string;
  const AInputSchema: string;
  const ARisk: TRadIAToolRisk
): TRadIAToolDescriptor;
begin
  Result := TRadIAToolDescriptor.Create(
    AName,
    '1.0',
    ADescription,
    AInputSchema,
    CObjectOutputSchema,
    ARisk
  );
end;

function TRadIAIDENavigationTool.Execute(
  const ARequest: TRadIAToolRequest
): TRadIAToolResult;
var
  LArguments: TJSONValue;
begin
  LArguments := TJSONObject.ParseJSONValue(ARequest.ArgumentsJson);
  try
    try
      if not (LArguments is TJSONObject) then
        Exit(
          TRadIAToolResult.Failed(
            'invalid_arguments',
            'Tool arguments must be a JSON object.'
          )
        );
      case FKind of
        intkListProjectGroupProjects:
          Result := ExecuteListProjectGroupProjects;
        intkGetProjectDependencies:
          Result := ExecuteGetProjectDependencies;
        intkGetUnitSymbols:
          Result := ExecuteGetUnitSymbols(TJSONObject(LArguments));
        intkGetEditorSemanticContext:
          Result := ExecuteGetEditorSemanticContext;
        intkNavigateToFile:
          Result := ExecuteNavigateToFile(TJSONObject(LArguments));
        intkNavigateToSymbol:
          Result := ExecuteNavigateToSymbol(TJSONObject(LArguments));
        intkNavigateToDevelopmentSurface:
          Result := ExecuteNavigateToDevelopmentSurface(
            TJSONObject(LArguments)
          );
        intkListIDEActions:
          Result := ExecuteListIDEActions;
        intkExecuteIDEAction:
          Result := ExecuteIDEAction(TJSONObject(LArguments));
      else
        Result := TRadIAToolResult.Failed(
          'unsupported_tool',
          'IDE navigation tool kind is not supported.'
        );
      end;
    except
      on E: EArgumentException do
        Result := TRadIAToolResult.Failed(
          'invalid_arguments',
          E.Message
        );
    end;
  finally
    LArguments.Free;
  end;
end;

function TRadIAIDENavigationTool.ExecuteGetEditorSemanticContext:
  TRadIAToolResult;
var
  LRoot: TJSONObject;
begin
  LRoot := TJSONObject.Create;
  try
    LRoot.AddPair(
      'context',
      FNavigation.GetEditorSemanticContext
    );
    Result := TRadIAToolResult.Succeeded(LRoot.ToJSON);
  finally
    LRoot.Free;
  end;
end;

function TRadIAIDENavigationTool.ExecuteGetProjectDependencies:
  TRadIAToolResult;
begin
  Result := StringArrayResult(
    'dependencies',
    FNavigation.GetProjectDependencies
  );
end;

function TRadIAIDENavigationTool.ExecuteGetUnitSymbols(
  const AArguments: TJSONObject
): TRadIAToolResult;
var
  LArray: TJSONArray;
  LItem: TJSONObject;
  LRoot: TJSONObject;
  LSymbol: TRadIAUnitSymbol;
begin
  LRoot := TJSONObject.Create;
  try
    LArray := TJSONArray.Create;
    LRoot.AddPair('symbols', LArray);
    for LSymbol in FNavigation.GetUnitSymbols(
      GetInteger(AArguments, 'maxSymbols', 500, 1, 5000)
    ) do
    begin
      LItem := TJSONObject.Create;
      LItem.AddPair('kind', LSymbol.Kind);
      LItem.AddPair('name', LSymbol.Name);
      LItem.AddPair('line', TJSONNumber.Create(LSymbol.Line));
      LArray.AddElement(LItem);
    end;
    Result := TRadIAToolResult.Succeeded(LRoot.ToJSON);
  finally
    LRoot.Free;
  end;
end;

function TRadIAIDENavigationTool.ExecuteIDEAction(
  const AArguments: TJSONObject
): TRadIAToolResult;
begin
  Result := NavigationResultToToolResult(
    FNavigation.ExecuteIDEAction(
      GetRequiredString(AArguments, 'actionName')
    )
  );
end;

function TRadIAIDENavigationTool.ExecuteListIDEActions:
  TRadIAToolResult;
var
  LAction: TRadIAIDEAction;
  LArray: TJSONArray;
  LItem: TJSONObject;
  LRoot: TJSONObject;
begin
  LRoot := TJSONObject.Create;
  try
    LArray := TJSONArray.Create;
    LRoot.AddPair('actions', LArray);
    for LAction in FNavigation.ListIDEActions do
    begin
      LItem := TJSONObject.Create;
      LItem.AddPair('name', LAction.Name);
      LItem.AddPair('caption', LAction.Caption);
      LItem.AddPair('enabled', TJSONBool.Create(LAction.Enabled));
      LArray.AddElement(LItem);
    end;
    Result := TRadIAToolResult.Succeeded(LRoot.ToJSON);
  finally
    LRoot.Free;
  end;
end;

function TRadIAIDENavigationTool.ExecuteListProjectGroupProjects:
  TRadIAToolResult;
begin
  Result := StringArrayResult(
    'projects',
    FNavigation.ListProjectGroupProjects
  );
end;

function TRadIAIDENavigationTool.ExecuteNavigateToFile(
  const AArguments: TJSONObject
): TRadIAToolResult;
begin
  Result := NavigationResultToToolResult(
    FNavigation.NavigateToFile(
      GetRequiredString(AArguments, 'fileName'),
      GetInteger(AArguments, 'line', 1, 1, MaxInt),
      GetInteger(AArguments, 'column', 1, 1, MaxInt)
    )
  );
end;

function TRadIAIDENavigationTool.ExecuteNavigateToSymbol(
  const AArguments: TJSONObject
): TRadIAToolResult;
begin
  Result := NavigationResultToToolResult(
    FNavigation.NavigateToSymbol(
      GetRequiredString(AArguments, 'symbol')
    )
  );
end;

function TRadIAIDENavigationTool.ExecuteNavigateToDevelopmentSurface(
  const AArguments: TJSONObject
): TRadIAToolResult;
var
  LIntent: TRadIADevelopmentIntent;
  LIntentValue: string;
  LSurface: string;
  LSurfaceKind: TRadIADevelopmentSurface;
begin
  LSurface := '';
  if Assigned(AArguments.GetValue('surface')) then
    LSurface := GetRequiredString(AArguments, 'surface');
  if LSurface <> '' then
  begin
    if SameText(LSurface, 'code') then
      LSurfaceKind := dsCode
    else if SameText(LSurface, 'design') then
      LSurfaceKind := dsDesign
    else
      raise EArgumentException.Create(
        'Argument "surface" must be "code" or "design".'
      );
  end
  else
  begin
    LIntentValue := GetRequiredString(AArguments, 'intent');
    if not TryParseRadIADevelopmentIntent(LIntentValue, LIntent) then
      raise EArgumentException.Create(
        'Argument "intent" is not a supported development intent.'
      );
    LSurfaceKind := RadIADevelopmentIntentSurface(LIntent);
  end;
  Result := NavigationResultToToolResult(
    FNavigation.NavigateToDevelopmentSurface(
      GetRequiredString(AArguments, 'fileName'),
      LSurfaceKind
    )
  );
end;

function TRadIAIDENavigationTool.GetDescriptor:
  TRadIAToolDescriptor;
begin
  case FKind of
    intkListProjectGroupProjects:
      Result := BuildDescriptor(
        'ListProjectGroupProjects',
        'Lists every project in the active Delphi project group.',
        CEmptyInputSchema,
        trReadOnly
      );
    intkGetProjectDependencies:
      Result := BuildDescriptor(
        'GetProjectDependencies',
        'Lists project dependencies configured by the active project group.',
        CEmptyInputSchema,
        trReadOnly
      );
    intkGetUnitSymbols:
      Result := BuildDescriptor(
        'GetUnitSymbols',
        'Lists declarations and source lines from the active unit.',
        CSymbolsInputSchema,
        trReadOnly
      );
    intkGetEditorSemanticContext:
      Result := BuildDescriptor(
        'GetEditorSemanticContext',
        'Returns the active unit, symbol, imports, and nearby declarations.',
        CEmptyInputSchema,
        trReadOnly
      );
    intkNavigateToFile:
      Result := BuildDescriptor(
        'NavigateToFile',
        'Opens a source file owned by an open project and selects a position.',
        CNavigateFileInputSchema,
        trReadOnly
      );
    intkNavigateToSymbol:
      Result := BuildDescriptor(
        'NavigateToSymbol',
        'Moves the active editor to a declared symbol.',
        CSymbolInputSchema,
        trReadOnly
      );
    intkNavigateToDevelopmentSurface:
      Result := BuildDescriptor(
        'NavigateToDevelopmentSurface',
        'Activates Code or Design from an explicit surface or development intent.',
        CDevelopmentSurfaceInputSchema,
        trReadOnly
      );
    intkListIDEActions:
      Result := BuildDescriptor(
        'ListIDEActions',
        'Lists available IDE actions from the safe allowlist.',
        CEmptyInputSchema,
        trReadOnly
      );
    intkExecuteIDEAction:
      Result := BuildDescriptor(
        'ExecuteIDEAction',
        'Executes a consented IDE action from the safe allowlist.',
        CActionInputSchema,
        trExecution
      );
  else
    Result := Default(TRadIAToolDescriptor);
  end;
end;

function TRadIAIDENavigationTool.GetInteger(
  const AArguments: TJSONObject;
  const AName: string;
  const ADefault: Integer;
  const AMinimum: Integer;
  const AMaximum: Integer
): Integer;
var
  LValue: TJSONValue;
begin
  LValue := AArguments.GetValue(AName);
  if not Assigned(LValue) then
    Exit(ADefault);
  if not (LValue is TJSONNumber) then
    raise EArgumentException.CreateFmt(
      'Argument "%s" must be an integer.',
      [AName]
    );
  Result := TJSONNumber(LValue).AsInt;
  if (Result < AMinimum) or (Result > AMaximum) then
    raise EArgumentOutOfRangeException.CreateFmt(
      'Argument "%s" is outside the supported range.',
      [AName]
    );
end;

function TRadIAIDENavigationTool.GetRequiredString(
  const AArguments: TJSONObject;
  const AName: string
): string;
var
  LValue: TJSONValue;
begin
  LValue := AArguments.GetValue(AName);
  if not (LValue is TJSONString) then
    raise EArgumentException.CreateFmt(
      'Argument "%s" must be a string.',
      [AName]
    );
  Result := Trim(LValue.Value);
  if Result = '' then
    raise EArgumentException.CreateFmt(
      'Argument "%s" is required.',
      [AName]
    );
end;

function TRadIAIDENavigationTool.NavigationResultToToolResult(
  const AResult: TRadIANavigationResult
): TRadIAToolResult;
var
  LJson: TJSONObject;
begin
  if not AResult.Success then
    Exit(
      TRadIAToolResult.Failed(
        'navigation_failed',
        AResult.Message
      )
    );
  LJson := TJSONObject.Create;
  try
    LJson.AddPair('fileName', AResult.FileName);
    LJson.AddPair('line', TJSONNumber.Create(AResult.Line));
    LJson.AddPair('column', TJSONNumber.Create(AResult.Column));
    LJson.AddPair('message', AResult.Message);
    Result := TRadIAToolResult.Succeeded(LJson.ToJSON);
  finally
    LJson.Free;
  end;
end;

function TRadIAIDENavigationTool.StringArrayResult(
  const AName: string;
  const AValues: TArray<string>
): TRadIAToolResult;
var
  LArray: TJSONArray;
  LRoot: TJSONObject;
  LValue: string;
begin
  LRoot := TJSONObject.Create;
  try
    LArray := TJSONArray.Create;
    LRoot.AddPair(AName, LArray);
    for LValue in AValues do
      LArray.Add(LValue);
    Result := TRadIAToolResult.Succeeded(LRoot.ToJSON);
  finally
    LRoot.Free;
  end;
end;

end.
