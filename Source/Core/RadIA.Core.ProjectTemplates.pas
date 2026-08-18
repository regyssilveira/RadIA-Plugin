unit RadIA.Core.ProjectTemplates;

interface

type
  TRadIAProjectTemplateKind = (
    ptkConsole,
    ptkVcl,
    ptkFmx,
    ptkLibrary,
    ptkPackage,
    ptkDUnitX,
    ptkService,
    ptkDextMinimalApi,
    ptkDextControllerApi
  );

  TRadIAProjectTemplateRequest = record
  private
    FProjectName: string;
    FKind: TRadIAProjectTemplateKind;
    FDelphiVersion: string;
    FPlatforms: TArray<string>;
    FSpecificationJson: string;
  public
    constructor Create(
      const AProjectName: string;
      const AKind: TRadIAProjectTemplateKind;
      const ADelphiVersion: string;
      const APlatforms: TArray<string>;
      const ASpecificationJson: string = ''
    );
    property ProjectName: string read FProjectName;
    property Kind: TRadIAProjectTemplateKind read FKind;
    property DelphiVersion: string read FDelphiVersion;
    property Platforms: TArray<string> read FPlatforms;
    property SpecificationJson: string read FSpecificationJson;
  end;

  TRadIAProjectTemplateFile = record
  private
    FRelativePath: string;
    FContent: string;
  public
    constructor Create(
      const ARelativePath: string;
      const AContent: string
    );
    property RelativePath: string read FRelativePath;
    property Content: string read FContent;
  end;

  TRadIAProjectTemplatePlan = class
  private
    FTemplateId: string;
    FProjectName: string;
    FKind: TRadIAProjectTemplateKind;
    FDelphiVersion: string;
    FPlatforms: TArray<string>;
    FFiles: TArray<TRadIAProjectTemplateFile>;
    FSpecificationJson: string;
  public
    constructor Create(
      const ATemplateId: string;
      const ARequest: TRadIAProjectTemplateRequest;
      const AFiles: TArray<TRadIAProjectTemplateFile>
    );
    function PreviewJson: string;
    property Files: TArray<TRadIAProjectTemplateFile> read FFiles;
  end;

  TRadIAProjectTemplateEngine = class
  private
    procedure ValidateDelphiVersion(
      const ADelphiVersion: string
    );
    procedure ValidatePlatforms(
      const APlatforms: TArray<string>
    );
    procedure ValidateProjectName(
      const AProjectName: string
    );
    procedure ValidateRequest(
      const ARequest: TRadIAProjectTemplateRequest
    );
    function BuildTemplateId(
      const ARequest: TRadIAProjectTemplateRequest
    ): string;
    function BuildProjectGuid(const ATemplateId: string): string;
    function BuildProjectConfigurationGroups(
      const ARequest: TRadIAProjectTemplateRequest
    ): string;
    function BuildProjectItems(
      const ARequest: TRadIAProjectTemplateRequest;
      const AMainSource: string
    ): string;
    function BuildProjectExtensions(
      const ARequest: TRadIAProjectTemplateRequest;
      const AMainSource: string
    ): string;
    function BuildProjectFile(
      const ARequest: TRadIAProjectTemplateRequest;
      const ATemplateId: string;
      const AMainSource: string
    ): string;
    function BuildFiles(
      const ARequest: TRadIAProjectTemplateRequest;
      const ATemplateId: string
    ): TArray<TRadIAProjectTemplateFile>;
    function BuildVclCalculatorFiles(
      const ARequest: TRadIAProjectTemplateRequest;
      const ATemplateId: string
    ): TArray<TRadIAProjectTemplateFile>;
    function BuildCalculatorTestProjectFile(
      const ARequest: TRadIAProjectTemplateRequest;
      const ATemplateId: string
    ): string;
    function BuildCalculatorApplicationProjectFile(
      const ARequest: TRadIAProjectTemplateRequest;
      const ATemplateId: string;
      const AMainSource: string
    ): string;
    function BuildCalculatorButtons: string;
    function IncludesCalculatorTests(
      const ARequest: TRadIAProjectTemplateRequest
    ): Boolean;
    function IncludesCalculatorHistory(
      const ARequest: TRadIAProjectTemplateRequest
    ): Boolean;
    function IsVclCalculator(
      const ARequest: TRadIAProjectTemplateRequest
    ): Boolean;
  public
    function BuildPlan(
      const ARequest: TRadIAProjectTemplateRequest
    ): TRadIAProjectTemplatePlan;
  end;

function RadIAProjectTemplateKindName(
  const AKind: TRadIAProjectTemplateKind
): string;

implementation

uses
  System.Classes,
  System.Hash,
  System.JSON,
  System.StrUtils,
  System.SysUtils,
  RadIA.Core.ApiSpecifications,
  RadIA.Core.DextProjectTemplates;

function RadIAProjectTemplateKindName(
  const AKind: TRadIAProjectTemplateKind
): string;
begin
  case AKind of
    ptkConsole:
      Result := 'console';
    ptkVcl:
      Result := 'vcl';
    ptkFmx:
      Result := 'fmx';
    ptkLibrary:
      Result := 'library';
    ptkPackage:
      Result := 'package';
    ptkDUnitX:
      Result := 'dunitx';
    ptkService:
      Result := 'service';
    ptkDextMinimalApi:
      Result := 'dext-minimal-api';
    ptkDextControllerApi:
      Result := 'dext-controller-api';
  else
    Result := 'unknown';
  end;
end;

{ TRadIAProjectTemplateRequest }

constructor TRadIAProjectTemplateRequest.Create(
  const AProjectName: string;
  const AKind: TRadIAProjectTemplateKind;
  const ADelphiVersion: string;
  const APlatforms: TArray<string>;
  const ASpecificationJson: string
);
var
  LIndex: Integer;
  LPlatform: string;
  LPlatformList: TStringList;
begin
  FProjectName := AProjectName;
  FKind := AKind;
  FDelphiVersion := ADelphiVersion;
  FSpecificationJson := ASpecificationJson;
  LPlatformList := TStringList.Create;
  try
    LPlatformList.CaseSensitive := False;
    LPlatformList.Duplicates := dupIgnore;
    LPlatformList.Sorted := True;
    for LPlatform in APlatforms do
    begin
      if SameText(LPlatform, 'Win32') then
        LPlatformList.Add('Win32')
      else if SameText(LPlatform, 'Win64') then
        LPlatformList.Add('Win64')
      else
        LPlatformList.Add(LPlatform);
    end;
    SetLength(FPlatforms, LPlatformList.Count);
    for LIndex := 0 to LPlatformList.Count - 1 do
      FPlatforms[LIndex] := LPlatformList[LIndex];
  finally
    LPlatformList.Free;
  end;
end;

{ TRadIAProjectTemplateFile }

constructor TRadIAProjectTemplateFile.Create(
  const ARelativePath: string;
  const AContent: string
);
begin
  FRelativePath := ARelativePath;
  FContent := AContent;
end;

{ TRadIAProjectTemplatePlan }

constructor TRadIAProjectTemplatePlan.Create(
  const ATemplateId: string;
  const ARequest: TRadIAProjectTemplateRequest;
  const AFiles: TArray<TRadIAProjectTemplateFile>
);
begin
  inherited Create;
  FTemplateId := ATemplateId;
  FProjectName := ARequest.ProjectName;
  FKind := ARequest.Kind;
  FDelphiVersion := ARequest.DelphiVersion;
  FPlatforms := Copy(ARequest.Platforms);
  FFiles := Copy(AFiles);
  FSpecificationJson := ARequest.SpecificationJson;
end;

function TRadIAProjectTemplatePlan.PreviewJson: string;
var
  LCompanionTestProject: string;
  LFeatures: TJSONValue;
  LFile: TRadIAProjectTemplateFile;
  LFileJson: TJSONObject;
  LFiles: TJSONArray;
  LPlatform: string;
  LPlatforms: TJSONArray;
  LRoot: TJSONObject;
  LSpecification: TJSONObject;
begin
  LCompanionTestProject := '';
  LRoot := TJSONObject.Create;
  try
    LRoot.AddPair('schemaVersion', TJSONNumber.Create(1));
    LRoot.AddPair('templateId', FTemplateId);
    LRoot.AddPair('projectName', FProjectName);
    LRoot.AddPair('template', RadIAProjectTemplateKindName(FKind));
    LRoot.AddPair('delphiVersion', FDelphiVersion);
    if FSpecificationJson <> '' then
    begin
      LSpecification := TJSONObject.ParseJSONValue(
        FSpecificationJson
      ) as TJSONObject;
      try
        if Assigned(LSpecification) and
          SameText(
            LSpecification.GetValue<string>('kind', ''),
            'calculator'
          ) then
        begin
          LRoot.AddPair(
            'creationProfile',
            LSpecification.GetValue<string>(
              'creationProfile',
              'essential'
            )
          );
          LFeatures := LSpecification.GetValue('features');
          if Assigned(LFeatures) then
            LRoot.AddPair('features', LFeatures.Clone as TJSONValue);
        end;
      finally
        LSpecification.Free;
      end;
    end;
    LPlatforms := TJSONArray.Create;
    LRoot.AddPair('platforms', LPlatforms);
    for LPlatform in FPlatforms do
      LPlatforms.Add(LPlatform);
    LFiles := TJSONArray.Create;
    LRoot.AddPair('files', LFiles);
    for LFile in FFiles do
    begin
      LFileJson := TJSONObject.Create;
      LFileJson.AddPair('path', LFile.RelativePath);
      LFileJson.AddPair(
        'size',
        TJSONNumber.Create(Length(TEncoding.UTF8.GetBytes(LFile.Content)))
      );
      LFileJson.AddPair(
        'sha256',
        LowerCase(THashSHA2.GetHashString(LFile.Content))
      );
      LFiles.AddElement(LFileJson);
      if EndsText('Tests.dproj', LFile.RelativePath) then
        LCompanionTestProject := LFile.RelativePath;
    end;
    if LCompanionTestProject <> '' then
    begin
      LRoot.AddPair('companionTestProject', LCompanionTestProject);
      LRoot.AddPair(
        'companionTestExecutable',
        'bin\$(Platform)\$(Config)\' +
        ChangeFileExt(LCompanionTestProject, '.exe')
      );
    end;
    Result := LRoot.ToJSON;
  finally
    LRoot.Free;
  end;
end;

{ TRadIAProjectTemplateEngine }

function TRadIAProjectTemplateEngine.BuildFiles(
  const ARequest: TRadIAProjectTemplateRequest;
  const ATemplateId: string
): TArray<TRadIAProjectTemplateFile>;
var
  LDextFile: TRadIADextGeneratedFile;
  LDextFiles: TArray<TRadIADextGeneratedFile>;
  LDextIndex: Integer;
  LDextSpecification: TRadIAApiSpecification;
  LMainSource: string;
  LProjectContent: string;
  LProjectName: string;
begin
  LProjectName := ARequest.ProjectName;
  if ARequest.Kind = ptkPackage then
    LMainSource := LProjectName + '.dpk'
  else
    LMainSource := LProjectName + '.dpr';

  if ARequest.Kind in [ptkDextMinimalApi, ptkDextControllerApi] then
  begin
    if ARequest.Kind = ptkDextMinimalApi then
      LDextSpecification := TRadIAApiSpecificationParser.Parse(
        LProjectName,
        asMinimal,
        ARequest.SpecificationJson
      )
    else
      LDextSpecification := TRadIAApiSpecificationParser.Parse(
        LProjectName,
        asControllers,
        ARequest.SpecificationJson
      );
    LDextFiles := TRadIADextProjectRenderer.BuildFiles(LDextSpecification);
    SetLength(Result, Length(LDextFiles));
    LDextIndex := 0;
    for LDextFile in LDextFiles do
    begin
      Result[LDextIndex] := TRadIAProjectTemplateFile.Create(
        LDextFile.RelativePath,
        LDextFile.Content
      );
      Inc(LDextIndex);
    end;
    Result := Result + [
      TRadIAProjectTemplateFile.Create(
        LProjectName + '.dproj',
        BuildProjectFile(ARequest, ATemplateId, LMainSource)
      )
    ];
    Exit;
  end;

  if IsVclCalculator(ARequest) then
  begin
    Result := BuildVclCalculatorFiles(ARequest, ATemplateId);
    if IncludesCalculatorTests(ARequest) then
      LProjectContent := BuildCalculatorApplicationProjectFile(
        ARequest,
        ATemplateId,
        LMainSource
      )
    else
      LProjectContent := BuildProjectFile(
        ARequest,
        ATemplateId,
        LMainSource
      );
    Result := Result + [
      TRadIAProjectTemplateFile.Create(
        LProjectName + '.dproj',
        LProjectContent
      )
    ];
    Exit;
  end;

  case ARequest.Kind of
    ptkConsole:
      Result := [
        TRadIAProjectTemplateFile.Create(
          LMainSource,
          'program ' + LProjectName + ';' + sLineBreak + sLineBreak +
          '{$APPTYPE CONSOLE}' + sLineBreak + sLineBreak +
          'begin' + sLineBreak +
          '  Writeln(''Hello from ' + LProjectName + '.'');' + sLineBreak +
          '  Readln;' + sLineBreak +
          'end.' + sLineBreak
        )
      ];
    ptkVcl:
      Result := [
        TRadIAProjectTemplateFile.Create(
          LMainSource,
          'program ' + LProjectName + ';' + sLineBreak + sLineBreak +
          'uses' + sLineBreak +
          '  Vcl.Forms,' + sLineBreak +
           '  MainForm in ''MainForm.pas'' {RadIAMainForm};' + sLineBreak +
           sLineBreak +
           'begin' + sLineBreak +
          '  Application.Initialize;' + sLineBreak +
          '  Application.MainFormOnTaskbar := True;' + sLineBreak +
          '  Application.CreateForm(TRadIAMainForm, RadIAMainForm);' +
          sLineBreak +
          '  Application.Run;' + sLineBreak +
          'end.' + sLineBreak
        ),
        TRadIAProjectTemplateFile.Create(
          'MainForm.pas',
          'unit MainForm;' + sLineBreak + sLineBreak +
          'interface' + sLineBreak + sLineBreak +
          'uses' + sLineBreak +
           '  System.Classes,' + sLineBreak +
           '  Vcl.Controls,' + sLineBreak +
          '  Vcl.Forms,' + sLineBreak +
          '  Vcl.StdCtrls;' + sLineBreak + sLineBreak +
          'type' + sLineBreak +
          '  TRadIAMainForm = class(TForm)' + sLineBreak +
          '  end;' + sLineBreak + sLineBreak +
          'var' + sLineBreak +
          '  RadIAMainForm: TRadIAMainForm;' + sLineBreak + sLineBreak +
          'implementation' + sLineBreak + sLineBreak +
          '{$R *.dfm}' + sLineBreak + sLineBreak +
          'end.' + sLineBreak
        ),
        TRadIAProjectTemplateFile.Create(
          'MainForm.dfm',
          'object RadIAMainForm: TRadIAMainForm' + sLineBreak +
          '  Left = 0' + sLineBreak +
          '  Top = 0' + sLineBreak +
          '  Caption = ''' + LProjectName + '''' + sLineBreak +
          '  ClientHeight = 480' + sLineBreak +
          '  ClientWidth = 720' + sLineBreak +
          'end' + sLineBreak
        )
      ];
    ptkFmx:
      Result := [
        TRadIAProjectTemplateFile.Create(
          LMainSource,
          'program ' + LProjectName + ';' + sLineBreak + sLineBreak +
          'uses' + sLineBreak +
          '  System.StartUpCopy,' + sLineBreak +
          '  FMX.Forms,' + sLineBreak +
           '  MainForm in ''MainForm.pas'' {RadIAMainForm};' + sLineBreak +
           sLineBreak +
           'begin' + sLineBreak +
          '  Application.Initialize;' + sLineBreak +
          '  Application.CreateForm(TRadIAMainForm, RadIAMainForm);' +
          sLineBreak +
          '  Application.Run;' + sLineBreak +
          'end.' + sLineBreak
        ),
        TRadIAProjectTemplateFile.Create(
          'MainForm.pas',
          'unit MainForm;' + sLineBreak + sLineBreak +
          'interface' + sLineBreak + sLineBreak +
          'uses' + sLineBreak +
          '  System.Classes,' + sLineBreak +
          '  FMX.Controls,' + sLineBreak +
          '  FMX.Forms;' + sLineBreak + sLineBreak +
          'type' + sLineBreak +
          '  TRadIAMainForm = class(TForm)' + sLineBreak +
          '  end;' + sLineBreak + sLineBreak +
          'var' + sLineBreak +
          '  RadIAMainForm: TRadIAMainForm;' + sLineBreak + sLineBreak +
          'implementation' + sLineBreak + sLineBreak +
          '{$R *.fmx}' + sLineBreak + sLineBreak +
          'end.' + sLineBreak
        ),
        TRadIAProjectTemplateFile.Create(
          'MainForm.fmx',
          'object RadIAMainForm: TRadIAMainForm' + sLineBreak +
          '  Caption = ''' + LProjectName + '''' + sLineBreak +
          '  ClientHeight = 480.000000000000000000' + sLineBreak +
          '  ClientWidth = 720.000000000000000000' + sLineBreak +
          'end' + sLineBreak
        )
      ];
    ptkLibrary:
      Result := [
        TRadIAProjectTemplateFile.Create(
          LMainSource,
          'library ' + LProjectName + ';' + sLineBreak + sLineBreak +
           'uses' + sLineBreak +
           '  System.SysUtils,' + sLineBreak +
           '  System.Classes;' + sLineBreak + sLineBreak +
           'begin' + sLineBreak +
          'end.' + sLineBreak
        )
      ];
    ptkPackage:
      Result := [
         TRadIAProjectTemplateFile.Create(
           LMainSource,
           'package ' + LProjectName + ';' + sLineBreak + sLineBreak +
           'requires' + sLineBreak +
          '  rtl;' + sLineBreak + sLineBreak +
          'end.' + sLineBreak
        )
      ];
    ptkDUnitX:
      Result := [
        TRadIAProjectTemplateFile.Create(
          LMainSource,
          'program ' + LProjectName + ';' + sLineBreak + sLineBreak +
          '{$APPTYPE CONSOLE}' + sLineBreak + sLineBreak +
          'uses' + sLineBreak +
          '  DUnitX.Loggers.Console,' + sLineBreak +
          '  DUnitX.Loggers.XML.NUnit,' + sLineBreak +
          '  DUnitX.TestFramework,' + sLineBreak +
          '  Tests.Sample in ''Tests.Sample.pas'';' + sLineBreak +
          sLineBreak +
          'var' + sLineBreak +
          '  Runner: ITestRunner;' + sLineBreak +
          'begin' + sLineBreak +
          '  TDUnitX.CheckCommandLine;' + sLineBreak +
          '  Runner := TDUnitX.CreateRunner;' + sLineBreak +
          '  Runner.AddLogger(TDUnitXConsoleLogger.Create(True));' +
          sLineBreak +
          '  Runner.AddLogger(TDUnitXXMLNUnitFileLogger.Create(' +
          sLineBreak +
          '    TDUnitX.Options.XMLOutputFile));' +
          sLineBreak +
          '  System.ExitCode := Ord(not Runner.Execute.AllPassed);' +
          sLineBreak +
          'end.' + sLineBreak
        ),
        TRadIAProjectTemplateFile.Create(
          'Tests.Sample.pas',
          'unit Tests.Sample;' + sLineBreak + sLineBreak +
          'interface' + sLineBreak + sLineBreak +
          'uses' + sLineBreak +
          '  DUnitX.TestFramework;' + sLineBreak + sLineBreak +
          'type' + sLineBreak +
          '  [TestFixture]' + sLineBreak +
          '  TRadIASampleTests = class' + sLineBreak +
          '  public' + sLineBreak +
          '    [Test]' + sLineBreak +
          '    procedure SamplePasses;' + sLineBreak +
          '  end;' + sLineBreak + sLineBreak +
          'implementation' + sLineBreak + sLineBreak +
          'procedure TRadIASampleTests.SamplePasses;' + sLineBreak +
          'begin' + sLineBreak +
          '  Assert.IsTrue(True);' + sLineBreak +
          'end;' + sLineBreak + sLineBreak +
          'initialization' + sLineBreak +
          '  TDUnitX.RegisterTestFixture(TRadIASampleTests);' +
          sLineBreak + sLineBreak +
          'end.' + sLineBreak
        )
      ];
    ptkService:
      Result := [
        TRadIAProjectTemplateFile.Create(
          LMainSource,
          'program ' + LProjectName + ';' + sLineBreak + sLineBreak +
          'uses' + sLineBreak +
          '  Vcl.SvcMgr,' + sLineBreak +
          '  MainService in ''MainService.pas'' ' +
          '{RadIAService: TService};' + sLineBreak + sLineBreak +
          '{$R *.RES}' + sLineBreak + sLineBreak +
          'begin' + sLineBreak +
          '  if not Application.DelayInitialize or ' +
          'Application.Installing then' + sLineBreak +
          '    Application.Initialize;' + sLineBreak +
          '  Application.CreateForm(TRadIAService, RadIAService);' +
          sLineBreak +
          '  Application.Run;' + sLineBreak +
          'end.' + sLineBreak
        ),
        TRadIAProjectTemplateFile.Create(
          'MainService.pas',
          'unit MainService;' + sLineBreak + sLineBreak +
          'interface' + sLineBreak + sLineBreak +
          'uses' + sLineBreak +
          '  System.Classes,' + sLineBreak +
          '  Winapi.Windows,' + sLineBreak +
          '  Vcl.SvcMgr;' + sLineBreak + sLineBreak +
          'type' + sLineBreak +
          '  TRadIAService = class(TService)' + sLineBreak +
          '  public' + sLineBreak +
          '    function GetServiceController: TServiceController; override;' +
          sLineBreak +
          '  end;' + sLineBreak + sLineBreak +
          'var' + sLineBreak +
          '  RadIAService: TRadIAService;' + sLineBreak + sLineBreak +
          'implementation' + sLineBreak + sLineBreak +
          '{$R *.dfm}' + sLineBreak + sLineBreak +
          'procedure ServiceController(CtrlCode: DWord); stdcall;' +
          sLineBreak +
          'begin' + sLineBreak +
          '  RadIAService.Controller(CtrlCode);' + sLineBreak +
          'end;' + sLineBreak + sLineBreak +
          'function TRadIAService.GetServiceController: ' +
          'TServiceController;' + sLineBreak +
          'begin' + sLineBreak +
          '  Result := ServiceController;' + sLineBreak +
          'end;' + sLineBreak + sLineBreak +
          'end.' + sLineBreak
        ),
        TRadIAProjectTemplateFile.Create(
          'MainService.dfm',
          'object RadIAService: TRadIAService' + sLineBreak +
          '  DisplayName = ''' + LProjectName + '''' + sLineBreak +
          '  Height = 150' + sLineBreak +
          '  Width = 215' + sLineBreak +
          'end' + sLineBreak
        )
      ];
  else
    Result := [];
  end;

  Result := Result + [
    TRadIAProjectTemplateFile.Create(
      LProjectName + '.dproj',
      BuildProjectFile(ARequest, ATemplateId, LMainSource)
    )
  ];
end;

function TRadIAProjectTemplateEngine.IsVclCalculator(
  const ARequest: TRadIAProjectTemplateRequest
): Boolean;
var
  LJson: TJSONObject;
begin
  Result := False;
  if (ARequest.Kind <> ptkVcl) or
    ARequest.SpecificationJson.Trim.IsEmpty then
    Exit;
  LJson := TJSONObject.ParseJSONValue(
    ARequest.SpecificationJson
  ) as TJSONObject;
  try
    Result := Assigned(LJson) and
      SameText(LJson.GetValue<string>('kind', ''), 'calculator');
  finally
    LJson.Free;
  end;
end;

function TRadIAProjectTemplateEngine.IncludesCalculatorTests(
  const ARequest: TRadIAProjectTemplateRequest
): Boolean;
var
  LFeature: TJSONValue;
  LFeatures: TJSONArray;
  LJson: TJSONObject;
  LProfile: string;
begin
  Result := False;
  LJson := TJSONObject.ParseJSONValue(
    ARequest.SpecificationJson
  ) as TJSONObject;
  try
    if not Assigned(LJson) then
      Exit;
    LProfile := LJson.GetValue<string>(
      'creationProfile',
      'essential'
    );
    if SameText(LProfile, 'complete') then
      Exit(True);
    if not SameText(LProfile, 'custom') then
      Exit;
    LFeatures := LJson.GetValue<TJSONArray>('optionalFeatures');
    if not Assigned(LFeatures) then
      Exit;
    for LFeature in LFeatures do
    begin
      if SameText(LFeature.Value, 'dunitx') then
        Exit(True);
    end;
  finally
    LJson.Free;
  end;
end;

function TRadIAProjectTemplateEngine.IncludesCalculatorHistory(
  const ARequest: TRadIAProjectTemplateRequest
): Boolean;
var
  LFeatures: TJSONObject;
  LHistory: TJSONObject;
  LJson: TJSONObject;
begin
  Result := False;
  LJson := TJSONObject.ParseJSONValue(
    ARequest.SpecificationJson
  ) as TJSONObject;
  try
    if not Assigned(LJson) then
      Exit;
    LFeatures := LJson.GetValue('features') as TJSONObject;
    if not Assigned(LFeatures) then
      Exit;
    LHistory := LFeatures.GetValue('operationHistory') as TJSONObject;
    Result := Assigned(LHistory) and
      LHistory.GetValue<Boolean>('enabled', False);
  finally
    LJson.Free;
  end;
end;

function TRadIAProjectTemplateEngine.BuildVclCalculatorFiles(
  const ARequest: TRadIAProjectTemplateRequest;
  const ATemplateId: string
): TArray<TRadIAProjectTemplateFile>;
var
  LDfm: string;
  LEqualsImplementation: string;
  LHistoryDfm: string;
  LHistoryPrivate: string;
  LHistoryPublished: string;
  LHistoryWidth: Integer;
  LProjectName: string;
  LSource: string;
begin
  LProjectName := ARequest.ProjectName;
  LHistoryPublished := '';
  LHistoryPrivate := '';
  LHistoryDfm := '';
  LHistoryWidth := 260;
  if IncludesCalculatorHistory(ARequest) then
  begin
    LHistoryWidth := 520;
    LHistoryPublished :=
      '    ClearHistoryButton: TButton;' + sLineBreak +
      '    HistoryStatus: TEdit;' + sLineBreak +
      '    OperationHistory: TListBox;' + sLineBreak +
      '    procedure ClearHistoryClick(Sender: TObject);' + sLineBreak;
    LHistoryPrivate :=
      '    procedure AddHistoryEntry(' + sLineBreak +
      '      const ALeft: Double;' + sLineBreak +
      '      const AOperator: string;' + sLineBreak +
      '      const ARight, AResult: Double' + sLineBreak +
      '    );' + sLineBreak;
    LEqualsImplementation :=
      'procedure TRadIAMainForm.AddHistoryEntry(' + sLineBreak +
      '  const ALeft: Double;' + sLineBreak +
      '  const AOperator: string;' + sLineBreak +
      '  const ARight, AResult: Double' + sLineBreak +
      ');' + sLineBreak +
      'begin' + sLineBreak +
      '  HistoryStatus.Text := Format(''%g %s %g = %g'', [' +
      'ALeft, AOperator, ARight, AResult]);' + sLineBreak +
      '  OperationHistory.Items.Add(HistoryStatus.Text);' + sLineBreak +
      'end;' + sLineBreak + sLineBreak +
      'procedure TRadIAMainForm.ClearHistoryClick(Sender: TObject);' + sLineBreak +
      'begin' + sLineBreak +
      '  OperationHistory.Clear;' + sLineBreak +
      '  HistoryStatus.Clear;' + sLineBreak +
      'end;' + sLineBreak + sLineBreak +
      'procedure TRadIAMainForm.EqualsClick(Sender: TObject);' + sLineBreak +
      'var' + sLineBreak +
      '  LLeft: Double;' + sLineBreak +
      '  LOperator: string;' + sLineBreak +
      '  LRight: Double;' + sLineBreak +
      'begin' + sLineBreak +
      '  if FPendingOperator = '''' then' + sLineBreak +
      '    Exit;' + sLineBreak +
      '  LLeft := FAccumulator;' + sLineBreak +
      '  LOperator := FPendingOperator;' + sLineBreak +
      '  LRight := CurrentValue;' + sLineBreak +
      '  try' + sLineBreak +
      '    ApplyPendingOperator;' + sLineBreak +
      '    Display.Text := FloatToStr(FAccumulator);' + sLineBreak +
      '    AddHistoryEntry(LLeft, LOperator, LRight, FAccumulator);' + sLineBreak +
      '    FPendingOperator := '''';' + sLineBreak +
      '    FNewEntry := True;' + sLineBreak +
      '  except' + sLineBreak +
      '    on E: EDivByZero do' + sLineBreak +
      '    begin' + sLineBreak +
      '      Display.Text := ''Cannot divide by zero'';' + sLineBreak +
      '      FPendingOperator := '''';' + sLineBreak +
      '      FNewEntry := True;' + sLineBreak +
      '    end;' + sLineBreak +
      '  end;' + sLineBreak +
      'end;' + sLineBreak + sLineBreak;
    LHistoryDfm :=
      '  object OperationHistory: TListBox' + sLineBreak +
      '    Left = 276' + sLineBreak +
      '    Top = 16' + sLineBreak +
      '    Width = 228' + sLineBreak +
      '    Height = 225' + sLineBreak +
      '    ItemHeight = 15' + sLineBreak +
      '    TabOrder = 18' + sLineBreak +
      '  end' + sLineBreak +
      '  object HistoryStatus: TEdit' + sLineBreak +
      '    Left = 276' + sLineBreak +
      '    Top = 249' + sLineBreak +
      '    Width = 228' + sLineBreak +
      '    Height = 23' + sLineBreak +
      '    ReadOnly = True' + sLineBreak +
      '    TabOrder = 19' + sLineBreak +
      '  end' + sLineBreak +
      '  object ClearHistoryButton: TButton' + sLineBreak +
      '    Left = 276' + sLineBreak +
      '    Top = 281' + sLineBreak +
      '    Width = 228' + sLineBreak +
      '    Height = 33' + sLineBreak +
      '    Caption = ''Clear history''' + sLineBreak +
      '    TabOrder = 20' + sLineBreak +
      '    OnClick = ClearHistoryClick' + sLineBreak +
      '  end' + sLineBreak;
  end
  else
    LEqualsImplementation :=
      'procedure TRadIAMainForm.EqualsClick(Sender: TObject);' + sLineBreak +
      'begin' + sLineBreak +
      '  try' + sLineBreak +
      '    ApplyPendingOperator;' + sLineBreak +
      '    Display.Text := FloatToStr(FAccumulator);' + sLineBreak +
      '    FPendingOperator := '''';' + sLineBreak +
      '    FNewEntry := True;' + sLineBreak +
      '  except' + sLineBreak +
      '    on E: EDivByZero do' + sLineBreak +
      '    begin' + sLineBreak +
      '      Display.Text := ''Cannot divide by zero'';' + sLineBreak +
      '      FPendingOperator := '''';' + sLineBreak +
      '      FNewEntry := True;' + sLineBreak +
      '    end;' + sLineBreak +
      '  end;' + sLineBreak +
      'end;' + sLineBreak + sLineBreak;
  LSource :=
    'unit MainForm;' + sLineBreak + sLineBreak +
    'interface' + sLineBreak + sLineBreak +
    'uses' + sLineBreak +
    '  System.Classes,' + sLineBreak +
    '  System.SysUtils,' + sLineBreak +
    '  CalculatorEngine,' + sLineBreak +
    '  Vcl.Controls,' + sLineBreak +
    '  Vcl.Forms,' + sLineBreak +
    '  Vcl.StdCtrls;' + sLineBreak + sLineBreak +
    'type' + sLineBreak +
    '  TRadIAMainForm = class(TForm)' + sLineBreak +
    '  published' + sLineBreak +
    '    AddButton: TButton;' + sLineBreak +
    '    ClearButton: TButton;' + sLineBreak +
    '    DecimalButton: TButton;' + sLineBreak +
    '    Display: TEdit;' + sLineBreak +
    '    DivideButton: TButton;' + sLineBreak +
    '    EightButton: TButton;' + sLineBreak +
    '    EqualsButton: TButton;' + sLineBreak +
    '    FiveButton: TButton;' + sLineBreak +
    '    FourButton: TButton;' + sLineBreak +
    '    MultiplyButton: TButton;' + sLineBreak +
    '    NineButton: TButton;' + sLineBreak +
    '    OneButton: TButton;' + sLineBreak +
    '    SevenButton: TButton;' + sLineBreak +
    '    SixButton: TButton;' + sLineBreak +
    '    SubtractButton: TButton;' + sLineBreak +
    '    ThreeButton: TButton;' + sLineBreak +
    '    TwoButton: TButton;' + sLineBreak +
    '    ZeroButton: TButton;' + sLineBreak +
    LHistoryPublished +
    '    procedure ClearClick(Sender: TObject);' + sLineBreak +
    '    procedure DigitClick(Sender: TObject);' + sLineBreak +
    '    procedure EqualsClick(Sender: TObject);' + sLineBreak +
    '    procedure OperatorClick(Sender: TObject);' + sLineBreak +
    '  private' + sLineBreak +
    '    FAccumulator: Double;' + sLineBreak +
    '    FNewEntry: Boolean;' + sLineBreak +
    '    FPendingOperator: string;' + sLineBreak +
    LHistoryPrivate +
    '    function CurrentValue: Double;' + sLineBreak +
    '    procedure ApplyPendingOperator;' + sLineBreak +
    '  end;' + sLineBreak + sLineBreak +
    'var' + sLineBreak +
    '  RadIAMainForm: TRadIAMainForm;' + sLineBreak + sLineBreak +
    'implementation' + sLineBreak + sLineBreak +
    '{$R *.dfm}' + sLineBreak + sLineBreak +
    'function TRadIAMainForm.CurrentValue: Double;' + sLineBreak +
    'begin' + sLineBreak +
    '  if not TryStrToFloat(Display.Text, Result) then' + sLineBreak +
    '    Result := 0;' + sLineBreak +
    'end;' + sLineBreak + sLineBreak +
    'procedure TRadIAMainForm.ApplyPendingOperator;' + sLineBreak +
    'var' + sLineBreak +
    '  LValue: Double;' + sLineBreak +
    'begin' + sLineBreak +
    '  LValue := CurrentValue;' + sLineBreak +
    '  if FPendingOperator <> '''' then' + sLineBreak +
    '    FAccumulator := TRadIACalculatorMath.Calculate(' + sLineBreak +
    '      FAccumulator, LValue, FPendingOperator);' + sLineBreak +
    'end;' + sLineBreak + sLineBreak +
    'procedure TRadIAMainForm.ClearClick(Sender: TObject);' + sLineBreak +
    'begin' + sLineBreak +
    '  FAccumulator := 0;' + sLineBreak +
    '  FPendingOperator := '''';' + sLineBreak +
    '  FNewEntry := True;' + sLineBreak +
    '  Display.Text := ''0'';' + sLineBreak +
    'end;' + sLineBreak + sLineBreak +
    'procedure TRadIAMainForm.DigitClick(Sender: TObject);' + sLineBreak +
    'var' + sLineBreak +
    '  LCaption: string;' + sLineBreak +
    'begin' + sLineBreak +
    '  LCaption := TButton(Sender).Caption;' + sLineBreak +
    '  if LCaption = ''.'' then' + sLineBreak +
    '    LCaption := FormatSettings.DecimalSeparator;' + sLineBreak +
    '  if FNewEntry then' + sLineBreak +
    '  begin' + sLineBreak +
    '    Display.Text := ''0'';' + sLineBreak +
    '    FNewEntry := False;' + sLineBreak +
    '  end;' + sLineBreak +
    '  if LCaption = FormatSettings.DecimalSeparator then' + sLineBreak +
    '  begin' + sLineBreak +
    '    if Pos(LCaption, Display.Text) = 0 then' + sLineBreak +
    '      Display.Text := Display.Text + LCaption;' + sLineBreak +
    '  end' + sLineBreak +
    '  else if Display.Text = ''0'' then' + sLineBreak +
    '    Display.Text := LCaption' + sLineBreak +
    '  else' + sLineBreak +
    '    Display.Text := Display.Text + LCaption;' + sLineBreak +
    'end;' + sLineBreak + sLineBreak +
    'procedure TRadIAMainForm.OperatorClick(Sender: TObject);' + sLineBreak +
    'begin' + sLineBreak +
    '  FAccumulator := CurrentValue;' + sLineBreak +
    '  FPendingOperator := TButton(Sender).Caption;' + sLineBreak +
    '  FNewEntry := True;' + sLineBreak +
    'end;' + sLineBreak + sLineBreak +
    LEqualsImplementation +
    'end.' + sLineBreak;
  LDfm :=
    'object RadIAMainForm: TRadIAMainForm' + sLineBreak +
    '  Left = 0' + sLineBreak +
    '  Top = 0' + sLineBreak +
    '  Caption = ''' + LProjectName + '''' + sLineBreak +
    '  ClientHeight = 330' + sLineBreak +
    '  ClientWidth = ' + LHistoryWidth.ToString + sLineBreak +
    '  Position = poScreenCenter' + sLineBreak +
    '  object Display: TEdit' + sLineBreak +
    '    Left = 16' + sLineBreak +
    '    Top = 16' + sLineBreak +
    '    Width = 228' + sLineBreak +
    '    Height = 32' + sLineBreak +
    '    Alignment = taRightJustify' + sLineBreak +
    '    ReadOnly = True' + sLineBreak +
    '    TabOrder = 0' + sLineBreak +
    '    Text = ''0''' + sLineBreak +
    '  end' + sLineBreak +
    BuildCalculatorButtons +
    LHistoryDfm +
    'end' + sLineBreak;
  Result := [
    TRadIAProjectTemplateFile.Create(
      LProjectName + '.dpr',
      'program ' + LProjectName + ';' + sLineBreak + sLineBreak +
      'uses' + sLineBreak +
      '  Vcl.Forms,' + sLineBreak +
      '  MainForm in ''MainForm.pas'' {RadIAMainForm};' + sLineBreak +
      sLineBreak +
      'begin' + sLineBreak +
      '  Application.Initialize;' + sLineBreak +
      '  Application.MainFormOnTaskbar := True;' + sLineBreak +
      '  Application.CreateForm(TRadIAMainForm, RadIAMainForm);' +
      sLineBreak +
      '  Application.MainForm.Show;' + sLineBreak +
      '  Application.Run;' + sLineBreak +
      'end.' + sLineBreak
    ),
    TRadIAProjectTemplateFile.Create('MainForm.pas', LSource),
    TRadIAProjectTemplateFile.Create('MainForm.dfm', LDfm),
    TRadIAProjectTemplateFile.Create(
      'CalculatorEngine.pas',
      'unit CalculatorEngine;' + sLineBreak + sLineBreak +
      'interface' + sLineBreak + sLineBreak +
      'type' + sLineBreak +
      '  TRadIACalculatorMath = class sealed' + sLineBreak +
      '  public' + sLineBreak +
      '    class function Calculate(' + sLineBreak +
      '      const ALeft, ARight: Double;' + sLineBreak +
      '      const AOperator: string' + sLineBreak +
      '    ): Double; static;' + sLineBreak +
      '  end;' + sLineBreak + sLineBreak +
      'implementation' + sLineBreak + sLineBreak +
      'uses' + sLineBreak +
      '  System.SysUtils;' + sLineBreak + sLineBreak +
      'class function TRadIACalculatorMath.Calculate(' + sLineBreak +
      '  const ALeft, ARight: Double;' + sLineBreak +
      '  const AOperator: string' + sLineBreak +
      '): Double;' + sLineBreak +
      'begin' + sLineBreak +
      '  if AOperator = ''+'' then' + sLineBreak +
      '    Result := ALeft + ARight' + sLineBreak +
      '  else if AOperator = ''-'' then' + sLineBreak +
      '    Result := ALeft - ARight' + sLineBreak +
      '  else if AOperator = ''*'' then' + sLineBreak +
      '    Result := ALeft * ARight' + sLineBreak +
      '  else if AOperator = ''/'' then' + sLineBreak +
      '  begin' + sLineBreak +
      '    if ARight = 0 then' + sLineBreak +
      '      raise EDivByZero.Create(''Division by zero.'');' + sLineBreak +
      '    Result := ALeft / ARight;' + sLineBreak +
      '  end' + sLineBreak +
      '  else' + sLineBreak +
      '    raise EArgumentException.Create(''Unsupported operator.'');' + sLineBreak +
      'end;' + sLineBreak + sLineBreak +
      'end.' + sLineBreak
    )
  ];
  if not IncludesCalculatorTests(ARequest) then
    Exit;
  Result := Result + [
    TRadIAProjectTemplateFile.Create(
      LProjectName + 'Tests.dpr',
      'program ' + LProjectName + 'Tests;' + sLineBreak + sLineBreak +
      '{$APPTYPE CONSOLE}' + sLineBreak + sLineBreak +
      'uses' + sLineBreak +
      '  DUnitX.Loggers.Console,' + sLineBreak +
      '  DUnitX.Loggers.XML.NUnit,' + sLineBreak +
      '  DUnitX.TestFramework,' + sLineBreak +
      '  Tests.CalculatorEngine in ''Tests.CalculatorEngine.pas'';' + sLineBreak +
      sLineBreak +
      'var' + sLineBreak +
      '  Runner: ITestRunner;' + sLineBreak +
      'begin' + sLineBreak +
      '  TDUnitX.CheckCommandLine;' + sLineBreak +
      '  Runner := TDUnitX.CreateRunner;' + sLineBreak +
      '  Runner.AddLogger(TDUnitXConsoleLogger.Create(True));' + sLineBreak +
      '  Runner.AddLogger(TDUnitXXMLNUnitFileLogger.Create(' + sLineBreak +
      '    TDUnitX.Options.XMLOutputFile));' + sLineBreak +
      '  System.ExitCode := Ord(not Runner.Execute.AllPassed);' + sLineBreak +
      'end.' + sLineBreak
    ),
    TRadIAProjectTemplateFile.Create(
      'Tests.CalculatorEngine.pas',
      'unit Tests.CalculatorEngine;' + sLineBreak + sLineBreak +
      'interface' + sLineBreak + sLineBreak +
      'uses' + sLineBreak +
      '  DUnitX.TestFramework;' + sLineBreak + sLineBreak +
      'type' + sLineBreak +
      '  [TestFixture]' + sLineBreak +
      '  TRadIACalculatorTests = class' + sLineBreak +
      '  public' + sLineBreak +
      '    [TestCase(''Add'', ''7,5,+,12'')]' + sLineBreak +
      '    [TestCase(''Subtract'', ''7,5,-,2'')]' + sLineBreak +
      '    [TestCase(''Multiply'', ''7,5,*,35'')]' + sLineBreak +
      '    [TestCase(''Divide'', ''10,5,/,2'')]' + sLineBreak +
      '    procedure Calculates(' + sLineBreak +
      '      const ALeft, ARight: Double;' + sLineBreak +
      '      const AOperator: string;' + sLineBreak +
      '      const AExpected: Double' + sLineBreak +
      '    );' + sLineBreak +
      '    [Test]' + sLineBreak +
      '    procedure RejectsDivisionByZero;' + sLineBreak +
      '  end;' + sLineBreak + sLineBreak +
      'implementation' + sLineBreak + sLineBreak +
      'uses' + sLineBreak +
      '  System.SysUtils,' + sLineBreak +
      '  CalculatorEngine;' + sLineBreak + sLineBreak +
      'procedure TRadIACalculatorTests.Calculates(' + sLineBreak +
      '  const ALeft, ARight: Double;' + sLineBreak +
      '  const AOperator: string;' + sLineBreak +
      '  const AExpected: Double' + sLineBreak +
      ');' + sLineBreak +
      'begin' + sLineBreak +
      '  Assert.AreEqual(' + sLineBreak +
      '    AExpected,' + sLineBreak +
      '    TRadIACalculatorMath.Calculate(ALeft, ARight, AOperator)' + sLineBreak +
      '  );' + sLineBreak +
      'end;' + sLineBreak + sLineBreak +
      'procedure TRadIACalculatorTests.RejectsDivisionByZero;' + sLineBreak +
      'begin' + sLineBreak +
      '  Assert.WillRaise(' + sLineBreak +
      '    procedure' + sLineBreak +
      '    begin' + sLineBreak +
      '      TRadIACalculatorMath.Calculate(1, 0, ''/'');' + sLineBreak +
      '    end,' + sLineBreak +
      '    EDivByZero' + sLineBreak +
      '  );' + sLineBreak +
      'end;' + sLineBreak + sLineBreak +
      'initialization' + sLineBreak +
      '  TDUnitX.RegisterTestFixture(TRadIACalculatorTests);' + sLineBreak +
      sLineBreak +
      'end.' + sLineBreak
    ),
    TRadIAProjectTemplateFile.Create(
      LProjectName + 'Tests.dproj',
      BuildCalculatorTestProjectFile(ARequest, ATemplateId)
    )
  ];
end;

function TRadIAProjectTemplateEngine.BuildCalculatorTestProjectFile(
  const ARequest: TRadIAProjectTemplateRequest;
  const ATemplateId: string
): string;
var
  LTestRequest: TRadIAProjectTemplateRequest;
begin
  LTestRequest := TRadIAProjectTemplateRequest.Create(
    ARequest.ProjectName + 'Tests',
    ptkDUnitX,
    ARequest.DelphiVersion,
    ARequest.Platforms
  );
  Result := BuildProjectFile(
    LTestRequest,
    ATemplateId + '-tests',
    ARequest.ProjectName + 'Tests.dpr'
  );
  Result := StringReplace(
    Result,
    'Tests.Sample.pas',
    'Tests.CalculatorEngine.pas',
    [rfReplaceAll]
  );
end;

function TRadIAProjectTemplateEngine.BuildCalculatorApplicationProjectFile(
  const ARequest: TRadIAProjectTemplateRequest;
  const ATemplateId: string;
  const AMainSource: string
): string;
const
  CImportMarker =
    '  <Import Project="$(BDS)\Bin\CodeGear.Delphi.Targets" ';
var
  LBuildTarget: string;
  LMarkerIndex: Integer;
begin
  Result := BuildProjectFile(ARequest, ATemplateId, AMainSource);
  LMarkerIndex := Pos(CImportMarker, Result);
  if LMarkerIndex = 0 then
    raise EInvalidOpException.Create(
      'The generated project import marker was not found.'
    );
  LBuildTarget :=
    '  <Target Name="RadIABuildCompanionTests" AfterTargets="Build">' +
    sLineBreak +
    '    <MSBuild Projects="' + ARequest.ProjectName + 'Tests.dproj" ' +
    'Targets="Build" Properties="Config=$(Config);Platform=$(Platform)" />' +
    sLineBreak +
    '  </Target>' + sLineBreak;
  Insert(LBuildTarget, Result, LMarkerIndex);
end;

function TRadIAProjectTemplateEngine.BuildCalculatorButtons: string;
const
  CButtonCaptions: array[0..16] of string = (
    'C', '/', '*', '-',
    '7', '8', '9', '+',
    '4', '5', '6', '=',
    '1', '2', '3', '.',
    '0'
  );
  CButtonNames: array[0..16] of string = (
    'ClearButton', 'DivideButton', 'MultiplyButton', 'SubtractButton',
    'SevenButton', 'EightButton', 'NineButton', 'AddButton',
    'FourButton', 'FiveButton', 'SixButton', 'EqualsButton',
    'OneButton', 'TwoButton', 'ThreeButton', 'DecimalButton',
    'ZeroButton'
  );
var
  LCaption: string;
  LColumn: Integer;
  LHandler: string;
  LIndex: Integer;
  LRow: Integer;
  LWidth: Integer;
begin
  Result := '';
  for LIndex := Low(CButtonCaptions) to High(CButtonCaptions) do
  begin
    LCaption := CButtonCaptions[LIndex];
    LColumn := LIndex mod 4;
    LRow := LIndex div 4;
    LWidth := 52;
    if LIndex = High(CButtonCaptions) then
      LWidth := 228;
    if LCaption = 'C' then
      LHandler := 'ClearClick'
    else if LCaption = '=' then
      LHandler := 'EqualsClick'
    else if CharInSet(LCaption[1], ['+', '-', '*', '/']) then
      LHandler := 'OperatorClick'
    else
      LHandler := 'DigitClick';
    Result := Result +
      '  object ' + CButtonNames[LIndex] + ': TButton' + sLineBreak +
      '    Left = ' + (16 + LColumn * 57).ToString + sLineBreak +
      '    Top = ' + (64 + LRow * 49).ToString + sLineBreak +
      '    Width = ' + LWidth.ToString + sLineBreak +
      '    Height = 44' + sLineBreak +
      '    Caption = ''' + LCaption + '''' + sLineBreak +
      '    TabOrder = ' + (LIndex + 1).ToString + sLineBreak +
      '    OnClick = ' + LHandler + sLineBreak +
      '  end' + sLineBreak;
  end;
end;

function TRadIAProjectTemplateEngine.BuildPlan(
  const ARequest: TRadIAProjectTemplateRequest
): TRadIAProjectTemplatePlan;
var
  LTemplateId: string;
begin
  ValidateRequest(ARequest);
  LTemplateId := BuildTemplateId(ARequest);
  Result := TRadIAProjectTemplatePlan.Create(
    LTemplateId,
    ARequest,
    BuildFiles(ARequest, LTemplateId)
  );
end;

function TRadIAProjectTemplateEngine.BuildProjectConfigurationGroups(
  const ARequest: TRadIAProjectTemplateRequest
): string;
var
  LPlatform: string;
begin
  Result :=
    '  <PropertyGroup Condition="&apos;$(Config)&apos;==&apos;Base&apos; or ' +
    '&apos;$(Base)&apos;!=&apos;&apos;">' + sLineBreak +
    '    <Base>true</Base>' + sLineBreak +
    '  </PropertyGroup>' + sLineBreak;
  for LPlatform in ARequest.Platforms do
    Result := Result +
      '  <PropertyGroup Condition="(&apos;$(Platform)&apos;==&apos;' +
      LPlatform + '&apos; and &apos;$(Base)&apos;==&apos;true&apos;) or ' +
      '&apos;$(Base_' + LPlatform + ')&apos;!=&apos;&apos;">' + sLineBreak +
      '    <Base_' + LPlatform + '>true</Base_' + LPlatform + '>' +
      sLineBreak +
      '    <CfgParent>Base</CfgParent>' + sLineBreak +
      '    <Base>true</Base>' + sLineBreak +
      '  </PropertyGroup>' + sLineBreak;
  Result := Result +
    '  <PropertyGroup Condition="&apos;$(Config)&apos;==&apos;Debug&apos; or ' +
    '&apos;$(Cfg_1)&apos;!=&apos;&apos;">' + sLineBreak +
    '    <Cfg_1>true</Cfg_1>' + sLineBreak +
    '    <CfgParent>Base</CfgParent>' + sLineBreak +
    '    <Base>true</Base>' + sLineBreak +
    '  </PropertyGroup>' + sLineBreak;
  for LPlatform in ARequest.Platforms do
    Result := Result +
      '  <PropertyGroup Condition="(&apos;$(Platform)&apos;==&apos;' +
      LPlatform + '&apos; and &apos;$(Cfg_1)&apos;==&apos;true&apos;) or ' +
      '&apos;$(Cfg_1_' + LPlatform + ')&apos;!=&apos;&apos;">' + sLineBreak +
      '    <Cfg_1_' + LPlatform + '>true</Cfg_1_' + LPlatform + '>' +
      sLineBreak +
      '    <CfgParent>Cfg_1</CfgParent>' + sLineBreak +
      '    <Cfg_1>true</Cfg_1>' + sLineBreak +
      '    <Base>true</Base>' + sLineBreak +
      '  </PropertyGroup>' + sLineBreak;
  Result := Result +
    '  <PropertyGroup Condition="&apos;$(Config)&apos;==&apos;Release&apos; or ' +
    '&apos;$(Cfg_2)&apos;!=&apos;&apos;">' + sLineBreak +
    '    <Cfg_2>true</Cfg_2>' + sLineBreak +
    '    <CfgParent>Base</CfgParent>' + sLineBreak +
    '    <Base>true</Base>' + sLineBreak +
    '  </PropertyGroup>' + sLineBreak;
  for LPlatform in ARequest.Platforms do
    Result := Result +
      '  <PropertyGroup Condition="(&apos;$(Platform)&apos;==&apos;' +
      LPlatform + '&apos; and &apos;$(Cfg_2)&apos;==&apos;true&apos;) or ' +
      '&apos;$(Cfg_2_' + LPlatform + ')&apos;!=&apos;&apos;">' + sLineBreak +
      '    <Cfg_2_' + LPlatform + '>true</Cfg_2_' + LPlatform + '>' +
      sLineBreak +
      '    <CfgParent>Cfg_2</CfgParent>' + sLineBreak +
      '    <Cfg_2>true</Cfg_2>' + sLineBreak +
      '    <Base>true</Base>' + sLineBreak +
      '  </PropertyGroup>' + sLineBreak;
end;

function TRadIAProjectTemplateEngine.BuildProjectFile(
  const ARequest: TRadIAProjectTemplateRequest;
  const ATemplateId: string;
  const AMainSource: string
): string;
var
  LAppType: string;
  LFrameworkType: string;
  LPlatform: string;
  LTargetedPlatforms: Integer;
  LUnitSearchPath: string;
begin
  LFrameworkType := 'None';
  LAppType := 'Application';
  if ARequest.Kind = ptkVcl then
    LFrameworkType := 'VCL'
  else if ARequest.Kind = ptkService then
    LFrameworkType := 'VCL'
  else if ARequest.Kind = ptkFmx then
    LFrameworkType := 'FMX'
  else if ARequest.Kind = ptkLibrary then
    LAppType := 'Library'
  else if ARequest.Kind = ptkPackage then
    LAppType := 'Package';

  LTargetedPlatforms := 0;
  for LPlatform in ARequest.Platforms do
  begin
    if SameText(LPlatform, 'Win32') then
      LTargetedPlatforms := LTargetedPlatforms or 1
    else if SameText(LPlatform, 'Win64') then
      LTargetedPlatforms := LTargetedPlatforms or 2;
  end;
  LUnitSearchPath := '$(BDS)\lib\$(Platform)\release';
  if ARequest.Kind = ptkDUnitX then
    LUnitSearchPath := LUnitSearchPath + ';$(BDS)\source\DUnitX';
  if ARequest.Kind in [ptkDextMinimalApi, ptkDextControllerApi] then
    LUnitSearchPath := LUnitSearchPath +
      ';$(DEXT_ROOT)\Output\' + ARequest.DelphiVersion +
      '_$(Platform)_$(Config)';

  Result :=
    '<Project xmlns="http://schemas.microsoft.com/developer/msbuild/2003" ' +
    'InitialTargets="RadIACreateOutputDirectories">' +
    sLineBreak +
    '  <PropertyGroup>' + sLineBreak +
    '    <ProjectGuid>' + BuildProjectGuid(ATemplateId) +
    '</ProjectGuid>' + sLineBreak +
    '    <ProjectVersion>20.3</ProjectVersion>' + sLineBreak +
    '    <FrameworkType>' + LFrameworkType + '</FrameworkType>' +
    sLineBreak +
    '    <MainSource>' + AMainSource + '</MainSource>' + sLineBreak +
    '    <Base>True</Base>' + sLineBreak +
    '    <Config Condition="''$(Config)''==''''">Debug</Config>' +
    sLineBreak +
    '    <Platform Condition="''$(Platform)''==''''">' +
    ARequest.Platforms[0] + '</Platform>' + sLineBreak +
    '    <TargetedPlatforms>' + IntToStr(LTargetedPlatforms) +
    '</TargetedPlatforms>' + sLineBreak +
    '    <AppType>' + LAppType + '</AppType>' + sLineBreak +
    '    <ProjectName Condition="''$(ProjectName)''==''''">' +
    ARequest.ProjectName + '</ProjectName>' + sLineBreak +
    '  </PropertyGroup>' + sLineBreak +
    BuildProjectConfigurationGroups(ARequest) +
    '  <PropertyGroup Condition="&apos;$(Base)&apos;!=&apos;&apos;">' +
    sLineBreak +
    '    <DCC_DcuOutput>.\$(Platform)\$(Config)</DCC_DcuOutput>' +
    sLineBreak +
    '    <DCC_ExeOutput>.\bin\$(Platform)\$(Config)</DCC_ExeOutput>' +
    sLineBreak +
    '    <DCC_ForceExecute>true</DCC_ForceExecute>' + sLineBreak +
    '    <DelphiLibraryPath>$(BDS)\lib\$(Platform)\release' +
    '</DelphiLibraryPath>' + sLineBreak +
    '    <DCC_UnitSearchPath>' + LUnitSearchPath +
    '</DCC_UnitSearchPath>' + sLineBreak +
    '    <DCC_Namespace>System;Xml;Data;Datasnap;Web;Soap;Vcl;' +
    'FMX</DCC_Namespace>' + sLineBreak +
    '  </PropertyGroup>' + sLineBreak +
    '  <PropertyGroup Condition="&apos;$(Cfg_1)&apos;!=&apos;&apos;">' +
    sLineBreak +
    '    <DCC_Define>DEBUG;$(DCC_Define)</DCC_Define>' + sLineBreak +
    '    <DCC_DebugDCUs>true</DCC_DebugDCUs>' + sLineBreak +
    '    <DCC_Optimize>false</DCC_Optimize>' + sLineBreak +
    '    <DCC_GenerateStackFrames>true</DCC_GenerateStackFrames>' +
    sLineBreak +
    '    <DCC_DebugInformation>2</DCC_DebugInformation>' + sLineBreak +
    '    <DCC_LocalDebugSymbols>true</DCC_LocalDebugSymbols>' + sLineBreak +
    '    <DCC_DebugInfoInExe>true</DCC_DebugInfoInExe>' + sLineBreak +
    '    <DCC_RemoteDebug>true</DCC_RemoteDebug>' + sLineBreak +
    '  </PropertyGroup>' + sLineBreak +
    BuildProjectItems(ARequest, AMainSource) +
    BuildProjectExtensions(ARequest, AMainSource) +
    '  <Target Name="RadIACreateOutputDirectories">' + sLineBreak +
    '    <MakeDir Directories="$(DCC_DcuOutput);$(DCC_ExeOutput)" />' +
    sLineBreak +
    '  </Target>' + sLineBreak +
    '  <Import Project="$(BDS)\Bin\CodeGear.Delphi.Targets" ' +
    'Condition="Exists(''$(BDS)\Bin\CodeGear.Delphi.Targets'')" />' +
    sLineBreak +
    '</Project>' + sLineBreak;
end;

function TRadIAProjectTemplateEngine.BuildProjectItems(
  const ARequest: TRadIAProjectTemplateRequest;
  const AMainSource: string
): string;
begin
  Result :=
    '  <ItemGroup>' + sLineBreak +
    '    <DelphiCompile Include="' + AMainSource + '">' + sLineBreak +
    '      <MainSource>MainSource</MainSource>' + sLineBreak +
    '    </DelphiCompile>' + sLineBreak;
  if ARequest.Kind in [ptkVcl, ptkFmx, ptkService] then
  begin
    if ARequest.Kind = ptkService then
      Result := Result +
        '    <DCCReference Include="MainService.pas">' + sLineBreak +
        '      <Form>RadIAService</Form>' + sLineBreak
    else
      Result := Result +
        '    <DCCReference Include="MainForm.pas">' + sLineBreak +
        '      <Form>RadIAMainForm</Form>' + sLineBreak;
    if ARequest.Kind in [ptkVcl, ptkService] then
      Result := Result + '      <FormType>dfm</FormType>' + sLineBreak;
    Result := Result + '    </DCCReference>' + sLineBreak;
  end
  else if ARequest.Kind = ptkDUnitX then
    Result := Result +
      '    <DCCReference Include="Tests.Sample.pas" />' + sLineBreak
  else if ARequest.Kind = ptkDextMinimalApi then
    Result := Result +
      '    <DCCReference Include="' + ARequest.ProjectName +
      '.Startup.pas" />' + sLineBreak +
      '    <DCCReference Include="Endpoints\' + ARequest.ProjectName +
      '.Endpoints.pas" />' + sLineBreak +
      '    <DCCReference Include="Contracts\' + ARequest.ProjectName +
      '.Contracts.pas" />' + sLineBreak
  else if ARequest.Kind = ptkDextControllerApi then
    Result := Result +
      '    <DCCReference Include="' + ARequest.ProjectName +
      '.Startup.pas" />' + sLineBreak +
      '    <DCCReference Include="Controllers\' + ARequest.ProjectName +
      '.Controllers.pas" />' + sLineBreak +
      '    <DCCReference Include="Contracts\' + ARequest.ProjectName +
      '.Contracts.pas" />' + sLineBreak +
      '    <DCCReference Include="Services\' + ARequest.ProjectName +
      '.Services.pas" />' + sLineBreak +
      '    <DCCReference Include="Infrastructure\' + ARequest.ProjectName +
      '.DependencyInjection.pas" />' + sLineBreak;
  Result := Result +
    '    <BuildConfiguration Include="Base">' + sLineBreak +
    '      <Key>Base</Key>' + sLineBreak +
    '    </BuildConfiguration>' + sLineBreak +
    '    <BuildConfiguration Include="Debug">' + sLineBreak +
    '      <Key>Cfg_1</Key>' + sLineBreak +
    '      <CfgParent>Base</CfgParent>' + sLineBreak +
    '    </BuildConfiguration>' + sLineBreak +
    '    <BuildConfiguration Include="Release">' + sLineBreak +
    '      <Key>Cfg_2</Key>' + sLineBreak +
    '      <CfgParent>Base</CfgParent>' + sLineBreak +
    '    </BuildConfiguration>' + sLineBreak +
    '  </ItemGroup>' + sLineBreak;
end;

function TRadIAProjectTemplateEngine.BuildProjectExtensions(
  const ARequest: TRadIAProjectTemplateRequest;
  const AMainSource: string
): string;
var
  LPlatform: string;
  LProjectType: string;
begin
  LProjectType := 'Application';
  if ARequest.Kind = ptkLibrary then
    LProjectType := 'Library'
  else if ARequest.Kind = ptkPackage then
    LProjectType := 'Package';
  Result :=
    '  <ProjectExtensions>' + sLineBreak +
    '    <Borland.Personality>Delphi.Personality.12</Borland.Personality>' +
    sLineBreak +
    '    <Borland.ProjectType>' + LProjectType + '</Borland.ProjectType>' +
    sLineBreak +
    '    <BorlandProject>' + sLineBreak +
    '      <Delphi.Personality>' + sLineBreak +
    '        <Source>' + sLineBreak +
    '          <Source Name="MainSource">' + AMainSource + '</Source>' +
    sLineBreak +
    '        </Source>' + sLineBreak +
    '      </Delphi.Personality>' + sLineBreak +
    '      <Platforms>' + sLineBreak;
  for LPlatform in ARequest.Platforms do
    Result := Result +
      '        <Platform value="' + LPlatform + '">' +
      LowerCase(BoolToStr(SameText(LPlatform, ARequest.Platforms[0]), True)) +
      '</Platform>' + sLineBreak;
  Result := Result +
    '      </Platforms>' + sLineBreak +
    '    </BorlandProject>' + sLineBreak +
    '    <ProjectFileVersion>12</ProjectFileVersion>' + sLineBreak +
    '  </ProjectExtensions>' + sLineBreak;
end;

function TRadIAProjectTemplateEngine.BuildProjectGuid(
  const ATemplateId: string
): string;
var
  LHash: string;
begin
  LHash := UpperCase(THashSHA2.GetHashString(ATemplateId));
  Result := '{' +
    Copy(LHash, 1, 8) + '-' +
    Copy(LHash, 9, 4) + '-' +
    Copy(LHash, 13, 4) + '-' +
    Copy(LHash, 17, 4) + '-' +
    Copy(LHash, 21, 12) + '}';
end;

function TRadIAProjectTemplateEngine.BuildTemplateId(
  const ARequest: TRadIAProjectTemplateRequest
): string;
var
  LPlatform: string;
  LPlatforms: string;
begin
  LPlatforms := '';
  for LPlatform in ARequest.Platforms do
  begin
    if LPlatforms <> '' then
      LPlatforms := LPlatforms + ',';
    LPlatforms := LPlatforms + LowerCase(LPlatform);
  end;
  Result := LowerCase(
    ARequest.ProjectName + '|' +
    RadIAProjectTemplateKindName(ARequest.Kind) + '|' +
    ARequest.DelphiVersion + '|' +
    LPlatforms
  );
  if ARequest.SpecificationJson <> '' then
    Result := Result + '|' + LowerCase(
      THashSHA2.GetHashString(ARequest.SpecificationJson)
    );
end;

procedure TRadIAProjectTemplateEngine.ValidateDelphiVersion(
  const ADelphiVersion: string
);
begin
  if not MatchText(ADelphiVersion, ['23.0', '37.0']) then
    raise EArgumentException.Create(
      'Project template supports Delphi 12 (BDS 23.0) and Delphi 13 (BDS 37.0).'
    );
end;

procedure TRadIAProjectTemplateEngine.ValidatePlatforms(
  const APlatforms: TArray<string>
);
var
  LPlatform: string;
begin
  if Length(APlatforms) = 0 then
    raise EArgumentException.Create(
      'Project template requires at least one platform.'
    );
  for LPlatform in APlatforms do
  begin
    if not SameText(LPlatform, 'Win32') and
      not SameText(LPlatform, 'Win64') then
      raise EArgumentException.Create(
        'Project template supports only Win32 and Win64.'
      );
  end;
end;

procedure TRadIAProjectTemplateEngine.ValidateProjectName(
  const AProjectName: string
);
var
  LChar: Char;
  LIndex: Integer;
begin
  if (Length(AProjectName) < 1) or (Length(AProjectName) > 64) then
    raise EArgumentException.Create(
      'Project name must contain between 1 and 64 characters.'
    );
  for LIndex := Low(AProjectName) to High(AProjectName) do
  begin
    LChar := AProjectName[LIndex];
    if (LIndex = Low(AProjectName)) and
      not CharInSet(LChar, ['A'..'Z', 'a'..'z', '_']) then
      raise EArgumentException.Create(
        'Project name must start with a letter or underscore.'
      );
    if (LIndex > Low(AProjectName)) and
      not CharInSet(LChar, ['A'..'Z', 'a'..'z', '0'..'9', '_']) then
      raise EArgumentException.Create(
        'Project name contains unsupported characters.'
      );
  end;
end;

procedure TRadIAProjectTemplateEngine.ValidateRequest(
  const ARequest: TRadIAProjectTemplateRequest
);
begin
  ValidateProjectName(ARequest.ProjectName);
  ValidateDelphiVersion(ARequest.DelphiVersion);
  ValidatePlatforms(ARequest.Platforms);
end;

end.
