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
    ptkService
  );

  TRadIAProjectTemplateRequest = record
  private
    FProjectName: string;
    FKind: TRadIAProjectTemplateKind;
    FDelphiVersion: string;
    FPlatforms: TArray<string>;
  public
    constructor Create(
      const AProjectName: string;
      const AKind: TRadIAProjectTemplateKind;
      const ADelphiVersion: string;
      const APlatforms: TArray<string>
    );
    property ProjectName: string read FProjectName;
    property Kind: TRadIAProjectTemplateKind read FKind;
    property DelphiVersion: string read FDelphiVersion;
    property Platforms: TArray<string> read FPlatforms;
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
  System.SysUtils;

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
  else
    Result := 'unknown';
  end;
end;

{ TRadIAProjectTemplateRequest }

constructor TRadIAProjectTemplateRequest.Create(
  const AProjectName: string;
  const AKind: TRadIAProjectTemplateKind;
  const ADelphiVersion: string;
  const APlatforms: TArray<string>
);
var
  LIndex: Integer;
  LPlatform: string;
  LPlatformList: TStringList;
begin
  FProjectName := AProjectName;
  FKind := AKind;
  FDelphiVersion := ADelphiVersion;
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
end;

function TRadIAProjectTemplatePlan.PreviewJson: string;
var
  LFile: TRadIAProjectTemplateFile;
  LFileJson: TJSONObject;
  LFiles: TJSONArray;
  LPlatform: string;
  LPlatforms: TJSONArray;
  LRoot: TJSONObject;
begin
  LRoot := TJSONObject.Create;
  try
    LRoot.AddPair('schemaVersion', TJSONNumber.Create(1));
    LRoot.AddPair('templateId', FTemplateId);
    LRoot.AddPair('projectName', FProjectName);
    LRoot.AddPair('template', RadIAProjectTemplateKindName(FKind));
    LRoot.AddPair('delphiVersion', FDelphiVersion);
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
  LMainSource: string;
  LProjectName: string;
begin
  LProjectName := ARequest.ProjectName;
  if ARequest.Kind = ptkPackage then
    LMainSource := LProjectName + '.dpk'
  else
    LMainSource := LProjectName + '.dpr';

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
    '    <DelphiLibraryPath>$(BDSLIB)\$(Platform)\release' +
    '</DelphiLibraryPath>' + sLineBreak +
    '    <DCC_UnitSearchPath>$(BDSLIB)\$(Platform)\release' +
    '</DCC_UnitSearchPath>' + sLineBreak +
    '    <DCC_Namespace>System;Xml;Data;Datasnap;Web;Soap;Vcl;' +
    'FMX</DCC_Namespace>' + sLineBreak +
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
      '    <DCCReference Include="Tests.Sample.pas" />' + sLineBreak;
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
