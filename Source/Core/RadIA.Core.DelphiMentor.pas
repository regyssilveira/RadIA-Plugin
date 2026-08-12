unit RadIA.Core.DelphiMentor;

interface

uses
  RadIA.Core.DelphiGuidance,
  RadIA.Core.Tools,
  RadIA.Core.Workspace;

type
  TRadIADelphiMentorProfile = (dmpBeginner, dmpCrossLanguage, dmpExperienced);

  TRadIADelphiMentorLesson = record
  private
    FProfile: TRadIADelphiMentorProfile;
    FFramework: string;
    FTopics: TArray<string>;
    FExplanationTemplate: string;
    FRules: TArray<TRadIADelphiGuidanceRule>;
  public
    constructor Create(
      const AProfile: TRadIADelphiMentorProfile;
      const AFramework: string;
      const ATopics: TArray<string>;
      const AExplanationTemplate: string;
      const ARules: TArray<TRadIADelphiGuidanceRule>
    );
    property Profile: TRadIADelphiMentorProfile read FProfile;
    property Framework: string read FFramework;
    property Topics: TArray<string> read FTopics;
    property ExplanationTemplate: string read FExplanationTemplate;
    property Rules: TArray<TRadIADelphiGuidanceRule> read FRules;
  end;

  TRadIADelphiMentor = class
  private
    FCatalog: IRadIADelphiGuidanceCatalog;
    function DetectFramework(const ACode: string): string;
    function DetectTopics(const ACode: string): TArray<string>;
    function TemplateFor(const AProfile: TRadIADelphiMentorProfile): string;
  public
    constructor Create(const ACatalog: IRadIADelphiGuidanceCatalog);
    function BuildLesson(
      const AProfile: TRadIADelphiMentorProfile;
      const ACode: string;
      const AVersion: string
    ): TRadIADelphiMentorLesson;
  end;

procedure RegisterRadIADelphiMentorTool(
  const ARegistry: IRadIAToolRegistry;
  const AWorkspace: IRadIAWorkspaceFacade;
  const ACatalog: IRadIADelphiGuidanceCatalog
);

function RadIADelphiMentorProfileName(
  const AProfile: TRadIADelphiMentorProfile
): string;

implementation

uses
  System.Generics.Collections,
  System.JSON,
  System.StrUtils,
  System.SysUtils;

type
  TRadIADelphiMentorTool = class(TInterfacedObject, IRadIATool)
  private
    FMentor: TRadIADelphiMentor;
    FWorkspace: IRadIAWorkspaceFacade;
    function GetDescriptor: TRadIAToolDescriptor;
    function ParseProfile(const AValue: string): TRadIADelphiMentorProfile;
  public
    constructor Create(
      const AWorkspace: IRadIAWorkspaceFacade;
      const ACatalog: IRadIADelphiGuidanceCatalog
    );
    destructor Destroy; override;
    function Execute(const ARequest: TRadIAToolRequest): TRadIAToolResult;
  end;

const
  CMaxSelectionCharacters = 12000;
  CMentorInputSchema =
    '{"type":"object","required":["profile"],"properties":{' +
    '"profile":{"type":"string","enum":["beginner",' +
    '"cross-language","experienced"]}},"additionalProperties":false}';
  CMentorOutputSchema =
    '{"type":"object","required":["profile","framework","topics",' +
    '"explanationTemplate","rules","retained"]}';

constructor TRadIADelphiMentorLesson.Create(
  const AProfile: TRadIADelphiMentorProfile;
  const AFramework: string;
  const ATopics: TArray<string>;
  const AExplanationTemplate: string;
  const ARules: TArray<TRadIADelphiGuidanceRule>
);
begin
  FProfile := AProfile;
  FFramework := AFramework;
  FTopics := Copy(ATopics);
  FExplanationTemplate := AExplanationTemplate;
  FRules := Copy(ARules);
end;

constructor TRadIADelphiMentor.Create(
  const ACatalog: IRadIADelphiGuidanceCatalog
);
begin
  inherited Create;
  if not Assigned(ACatalog) then
    raise EArgumentNilException.Create('ACatalog');
  FCatalog := ACatalog;
end;

function TRadIADelphiMentor.DetectFramework(const ACode: string): string;
begin
  if ContainsText(ACode, 'FMX.') or ContainsText(ACode, 'TForm3D') then
    Exit('FMX');
  if ContainsText(ACode, 'Vcl.') or ContainsText(ACode, 'TForm') or
    ContainsText(ACode, '{$R *.dfm}') then
    Exit('VCL');
  Result := 'any';
end;

function TRadIADelphiMentor.DetectTopics(
  const ACode: string
): TArray<string>;
var
  LTopics: TList<string>;
begin
  LTopics := TList<string>.Create;
  try
    if ContainsText(ACode, '.Create') or ContainsText(ACode, '.Free') or
      ContainsText(ACode, 'try') and ContainsText(ACode, 'finally') then
      LTopics.Add('ownership');
    if ContainsText(ACode, '{$R *.dfm}') or ContainsText(ACode, '{$R *.fmx}') then
      LTopics.Add('form-resource');
    if ContainsText(ACode, 'package ') or ContainsText(ACode, 'requires') or
      ContainsText(ACode, 'contains') then
      LTopics.Add('package');
    if DetectFramework(ACode) <> 'any' then
      LTopics.Add(LowerCase(DetectFramework(ACode)));
    if LTopics.Count = 0 then
      LTopics.Add('language');
    Result := LTopics.ToArray;
  finally
    LTopics.Free;
  end;
end;

function TRadIADelphiMentor.TemplateFor(
  const AProfile: TRadIADelphiMentorProfile
): string;
begin
  case AProfile of
    dmpBeginner:
      Result := 'Explain syntax first, then ownership, runtime behavior, and one safe next step.';
    dmpCrossLanguage:
      Result := 'Compare the selected construct with familiar managed-language concepts and ' +
        'highlight Delphi ownership and framework differences.';
  else
    Result := 'Explain contracts, lifetime, framework integration, compiler constraints, and tradeoffs concisely.';
  end;
end;

function TRadIADelphiMentor.BuildLesson(
  const AProfile: TRadIADelphiMentorProfile;
  const ACode: string;
  const AVersion: string
): TRadIADelphiMentorLesson;
var
  LFramework: string;
  LRules: TArray<TRadIADelphiGuidanceRule>;
begin
  if Trim(ACode) = '' then
    raise EArgumentException.Create('Selected Delphi code must not be empty.');
  if Length(ACode) > CMaxSelectionCharacters then
    raise EArgumentOutOfRangeException.Create('Selected Delphi code exceeds 12000 characters.');
  LFramework := DetectFramework(ACode);
  LRules := FCatalog.Query(TRadIADelphiGuidanceQuery.Create(
    AVersion,
    LFramework,
    'any',
    '',
    '',
    6
  ));
  Result := TRadIADelphiMentorLesson.Create(
    AProfile,
    LFramework,
    DetectTopics(ACode),
    TemplateFor(AProfile),
    LRules
  );
end;

function RadIADelphiMentorProfileName(
  const AProfile: TRadIADelphiMentorProfile
): string;
begin
  case AProfile of
    dmpBeginner: Result := 'beginner';
    dmpCrossLanguage: Result := 'cross-language';
  else
    Result := 'experienced';
  end;
end;

procedure RegisterRadIADelphiMentorTool(
  const ARegistry: IRadIAToolRegistry;
  const AWorkspace: IRadIAWorkspaceFacade;
  const ACatalog: IRadIADelphiGuidanceCatalog
);
begin
  if not Assigned(ARegistry) then
    raise EArgumentNilException.Create('ARegistry');
  ARegistry.RegisterTool(TRadIADelphiMentorTool.Create(AWorkspace, ACatalog));
end;

constructor TRadIADelphiMentorTool.Create(
  const AWorkspace: IRadIAWorkspaceFacade;
  const ACatalog: IRadIADelphiGuidanceCatalog
);
begin
  inherited Create;
  if not Assigned(AWorkspace) then
    raise EArgumentNilException.Create('AWorkspace');
  FWorkspace := AWorkspace;
  FMentor := TRadIADelphiMentor.Create(ACatalog);
end;

destructor TRadIADelphiMentorTool.Destroy;
begin
  FMentor.Free;
  inherited;
end;

function TRadIADelphiMentorTool.ParseProfile(
  const AValue: string
): TRadIADelphiMentorProfile;
begin
  if SameText(AValue, 'beginner') then
    Exit(dmpBeginner);
  if SameText(AValue, 'cross-language') then
    Exit(dmpCrossLanguage);
  if SameText(AValue, 'experienced') then
    Exit(dmpExperienced);
  raise EArgumentException.Create('Mentor profile is invalid.');
end;

function TRadIADelphiMentorTool.Execute(
  const ARequest: TRadIAToolRequest
): TRadIAToolResult;
var
  LArray: TJSONArray;
  LItem: TJSONObject;
  LJson: TJSONObject;
  LLesson: TRadIADelphiMentorLesson;
  LProfile: TRadIADelphiMentorProfile;
  LRoot: TJSONObject;
  LRule: TRadIADelphiGuidanceRule;
  LSelection: TRadIAEditorSelection;
  LTopic: string;
begin
  LJson := TJSONObject.ParseJSONValue(ARequest.ArgumentsJson) as TJSONObject;
  if not Assigned(LJson) then
    Exit(TRadIAToolResult.Failed('invalid_arguments', 'Arguments must be a JSON object.'));
  try
    LProfile := ParseProfile(LJson.GetValue<string>('profile', ''));
  finally
    LJson.Free;
  end;
  LSelection := FWorkspace.GetEditorSelection;
  try
    LLesson := FMentor.BuildLesson(
      LProfile,
      LSelection.Content,
      FWorkspace.GetIDEState.VersionName
    );
  except
    on E: Exception do
      Exit(TRadIAToolResult.Failed('mentor_context_unavailable', E.Message));
  end;
  LRoot := TJSONObject.Create;
  try
    LRoot.AddPair('profile', RadIADelphiMentorProfileName(LLesson.Profile));
    LRoot.AddPair('framework', LLesson.Framework);
    LRoot.AddPair('explanationTemplate', LLesson.ExplanationTemplate);
    LRoot.AddPair('retained', TJSONBool.Create(False));
    LArray := TJSONArray.Create;
    LRoot.AddPair('topics', LArray);
    for LTopic in LLesson.Topics do
      LArray.Add(LTopic);
    LArray := TJSONArray.Create;
    LRoot.AddPair('rules', LArray);
    for LRule in LLesson.Rules do
    begin
      LItem := TJSONObject.Create;
      LItem.AddPair('guidance', LRule.Guidance);
      LItem.AddPair('citation', LRule.Citation);
      LArray.AddElement(LItem);
    end;
    Result := TRadIAToolResult.Succeeded(LRoot.ToJSON);
  finally
    LRoot.Free;
  end;
end;

function TRadIADelphiMentorTool.GetDescriptor: TRadIAToolDescriptor;
begin
  Result := TRadIAToolDescriptor.Create(
    'ExplainSelectedDelphiCode',
    '1.0.0',
    'Builds a level-aware explanation anchored to selected Delphi code and cited rules.',
    CMentorInputSchema,
    CMentorOutputSchema,
    trReadOnly
  );
end;

end.
