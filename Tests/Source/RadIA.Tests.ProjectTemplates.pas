unit RadIA.Tests.ProjectTemplates;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TTestRadIAProjectTemplates = class
  public
    [Test]
    procedure TestAllTemplateKindsProduceProjectFile;
    [Test]
    procedure TestSameRequestProducesIdenticalPreview;
    [Test]
    procedure TestPreviewContainsHashesWithoutFileContent;
    [Test]
    procedure TestRejectsInvalidProjectName;
    [Test]
    procedure TestRejectsUnsupportedDelphiVersion;
    [Test]
    procedure TestRejectsUnsupportedPlatform;
    [Test]
    procedure TestServiceTemplateContainsServiceContract;
    [Test]
    procedure TestTransactionStagesCommitsAndRollsBack;
    [Test]
    procedure TestPreparedTransactionCleansStagingOnDestroy;
    [Test]
    procedure TestCalculatorCompositionContainsFunctionalVclInterface;
  end;

implementation

uses
  System.IOUtils,
  System.SysUtils,
  RadIA.Core.ProjectTemplates,
  RadIA.Core.ProjectTransaction;

procedure TTestRadIAProjectTemplates.
  TestCalculatorCompositionContainsFunctionalVclInterface;
var
  LEngine: TRadIAProjectTemplateEngine;
  LFile: TRadIAProjectTemplateFile;
  LFoundDfm: Boolean;
  LFoundSource: Boolean;
  LPlan: TRadIAProjectTemplatePlan;
begin
  LEngine := TRadIAProjectTemplateEngine.Create;
  try
    LPlan := LEngine.BuildPlan(
      TRadIAProjectTemplateRequest.Create(
        'CalculatorApp',
        ptkVcl,
        '37.0',
        ['Win32'],
        '{"schemaVersion":1,"kind":"calculator"}'
      )
    );
    try
      LFoundDfm := False;
      LFoundSource := False;
      for LFile in LPlan.Files do
      begin
        if SameText(LFile.RelativePath, 'MainForm.dfm') then
        begin
          LFoundDfm := True;
          Assert.Contains(LFile.Content, 'object Display: TEdit');
          Assert.Contains(LFile.Content, 'object EqualsButton: TButton');
          Assert.Contains(LFile.Content, 'OnClick = EqualsClick');
        end;
        if SameText(LFile.RelativePath, 'MainForm.pas') then
        begin
          LFoundSource := True;
          Assert.Contains(LFile.Content, 'procedure TRadIAMainForm.DigitClick');
          Assert.Contains(LFile.Content, 'procedure TRadIAMainForm.OperatorClick');
          Assert.Contains(LFile.Content, 'Cannot divide by zero');
        end;
      end;
      Assert.IsTrue(LFoundDfm);
      Assert.IsTrue(LFoundSource);
    finally
      LPlan.Free;
    end;
  finally
    LEngine.Free;
  end;
end;

procedure TTestRadIAProjectTemplates.TestAllTemplateKindsProduceProjectFile;
var
  LEngine: TRadIAProjectTemplateEngine;
  LFile: TRadIAProjectTemplateFile;
  LHasProjectFile: Boolean;
  LKind: TRadIAProjectTemplateKind;
  LPlan: TRadIAProjectTemplatePlan;
  LRequest: TRadIAProjectTemplateRequest;
  LSpecificationJson: string;
begin
  LEngine := TRadIAProjectTemplateEngine.Create;
  try
    for LKind := Low(TRadIAProjectTemplateKind) to
      High(TRadIAProjectTemplateKind) do
    begin
      if LKind in [ptkDextMinimalApi, ptkDextControllerApi] then
        LSpecificationJson :=
          '{"schemaVersion":1,"endpoints":[{"name":"Health",' +
          '"group":"System","method":"GET","path":"/health"}]}'
      else
        LSpecificationJson := '';
      LRequest := TRadIAProjectTemplateRequest.Create(
        'SampleProject',
        LKind,
        '37.0',
        ['Win32', 'Win64'],
        LSpecificationJson
      );
      LPlan := LEngine.BuildPlan(LRequest);
      try
        Assert.IsTrue(Length(LPlan.Files) >= 2);
        LHasProjectFile := False;
        for LFile in LPlan.Files do
        begin
          if SameText(LFile.RelativePath, 'SampleProject.dproj') then
          begin
            LHasProjectFile := True;
            Assert.Contains(LFile.Content, '<ProjectGuid>');
            Assert.Contains(LFile.Content, '<TargetedPlatforms>3');
            Assert.Contains(
              LFile.Content,
              '<DCC_ForceExecute>true</DCC_ForceExecute>'
            );
            Assert.Contains(
              LFile.Content,
              '<DCC_UnitSearchPath>$(BDSLIB)\$(Platform)\release'
            );
            Assert.Contains(
              LFile.Content,
              '<DelphiLibraryPath>$(BDSLIB)\$(Platform)\release'
            );
            Assert.Contains(
              LFile.Content,
              '<PropertyGroup Condition="&apos;$(Config)&apos;==&apos;Base&apos;'
            );
            Assert.Contains(
              LFile.Content,
              '<Base_Win32>true</Base_Win32>'
            );
            Assert.Contains(
              LFile.Content,
              '<Cfg_1_Win32>true</Cfg_1_Win32>'
            );
            Assert.Contains(
              LFile.Content,
              '<DCC_Define>DEBUG;$(DCC_Define)</DCC_Define>'
            );
            Assert.Contains(
              LFile.Content,
              '<DCC_DebugDCUs>true</DCC_DebugDCUs>'
            );
            Assert.Contains(
              LFile.Content,
              '<DCC_Optimize>false</DCC_Optimize>'
            );
            Assert.Contains(
              LFile.Content,
              '<DCC_GenerateStackFrames>true</DCC_GenerateStackFrames>'
            );
            Assert.Contains(
              LFile.Content,
              '<DCC_DebugInformation>2</DCC_DebugInformation>'
            );
            Assert.Contains(
              LFile.Content,
              '<DCC_LocalDebugSymbols>true</DCC_LocalDebugSymbols>'
            );
            Assert.Contains(
              LFile.Content,
              '<DCC_DebugInfoInExe>true</DCC_DebugInfoInExe>'
            );
            Assert.Contains(
              LFile.Content,
              '<DCC_RemoteDebug>true</DCC_RemoteDebug>'
            );
            Assert.Contains(
              LFile.Content,
              '<Cfg_2_Win32>true</Cfg_2_Win32>'
            );
            Assert.Contains(
              LFile.Content,
              '<BuildConfiguration Include="Debug">'
            );
            Assert.Contains(
              LFile.Content,
              '<ProjectFileVersion>12</ProjectFileVersion>'
            );
          end;
        end;
        Assert.IsTrue(LHasProjectFile);
      finally
        LPlan.Free;
      end;
    end;
  finally
    LEngine.Free;
  end;
end;

procedure TTestRadIAProjectTemplates.TestPreviewContainsHashesWithoutFileContent;
var
  LEngine: TRadIAProjectTemplateEngine;
  LPlan: TRadIAProjectTemplatePlan;
  LPreview: string;
begin
  LEngine := TRadIAProjectTemplateEngine.Create;
  try
    LPlan := LEngine.BuildPlan(
      TRadIAProjectTemplateRequest.Create(
        'ConsoleProject',
        ptkConsole,
        '37.0',
        ['Win32']
      )
    );
    try
      LPreview := LPlan.PreviewJson;
      Assert.Contains(LPreview, '"sha256"');
      Assert.Contains(LPreview, '"path":"ConsoleProject.dpr"');
      Assert.DoesNotContain(LPreview, 'Hello from ConsoleProject');
    finally
      LPlan.Free;
    end;
  finally
    LEngine.Free;
  end;
end;

procedure TTestRadIAProjectTemplates.TestRejectsInvalidProjectName;
var
  LEngine: TRadIAProjectTemplateEngine;
begin
  LEngine := TRadIAProjectTemplateEngine.Create;
  try
    Assert.WillRaise(
      procedure
      var
        LPlan: TRadIAProjectTemplatePlan;
      begin
        LPlan := LEngine.BuildPlan(
          TRadIAProjectTemplateRequest.Create(
            '..\Unsafe',
            ptkConsole,
            '37.0',
            ['Win32']
          )
        );
        LPlan.Free;
      end,
      EArgumentException
    );
  finally
    LEngine.Free;
  end;
end;

procedure TTestRadIAProjectTemplates.TestRejectsUnsupportedDelphiVersion;
var
  LEngine: TRadIAProjectTemplateEngine;
begin
  LEngine := TRadIAProjectTemplateEngine.Create;
  try
    Assert.WillRaise(
      procedure
      var
        LPlan: TRadIAProjectTemplatePlan;
      begin
        LPlan := LEngine.BuildPlan(
          TRadIAProjectTemplateRequest.Create(
            'UnsupportedVersion',
            ptkConsole,
            '22.0',
            ['Win32']
          )
        );
        LPlan.Free;
      end,
      EArgumentException
    );
  finally
    LEngine.Free;
  end;
end;

procedure TTestRadIAProjectTemplates.TestRejectsUnsupportedPlatform;
var
  LEngine: TRadIAProjectTemplateEngine;
begin
  LEngine := TRadIAProjectTemplateEngine.Create;
  try
    Assert.WillRaise(
      procedure
      var
        LPlan: TRadIAProjectTemplatePlan;
      begin
        LPlan := LEngine.BuildPlan(
          TRadIAProjectTemplateRequest.Create(
            'UnsupportedPlatform',
            ptkConsole,
            '37.0',
            ['Linux64']
          )
        );
        LPlan.Free;
      end,
      EArgumentException
    );
  finally
    LEngine.Free;
  end;
end;

procedure TTestRadIAProjectTemplates.TestSameRequestProducesIdenticalPreview;
var
  LEngine: TRadIAProjectTemplateEngine;
  LFile: TRadIAProjectTemplateFile;
  LFirstPlan: TRadIAProjectTemplatePlan;
  LRequest: TRadIAProjectTemplateRequest;
  LSecondRequest: TRadIAProjectTemplateRequest;
  LSecondPlan: TRadIAProjectTemplatePlan;
begin
  LEngine := TRadIAProjectTemplateEngine.Create;
  try
    LRequest := TRadIAProjectTemplateRequest.Create(
      'DeterministicProject',
      ptkVcl,
      '37.0',
      ['Win64', 'Win32']
    );
    LSecondRequest := TRadIAProjectTemplateRequest.Create(
      'DeterministicProject',
      ptkVcl,
      '37.0',
      ['win32', 'WIN64', 'Win32']
    );
    LFirstPlan := LEngine.BuildPlan(LRequest);
    try
      LSecondPlan := LEngine.BuildPlan(LSecondRequest);
      try
        Assert.AreEqual(
          LFirstPlan.PreviewJson,
          LSecondPlan.PreviewJson
        );
        for LFile in LFirstPlan.Files do
        begin
          if SameText(
            LFile.RelativePath,
            'DeterministicProject.dproj'
          ) then
            Assert.Contains(
              LFile.Content,
              '{4D5AB449-CA65-C005-2F4D-FB0DE5D94B8A}'
            );
        end;
      finally
        LSecondPlan.Free;
      end;
    finally
      LFirstPlan.Free;
    end;
  finally
    LEngine.Free;
  end;
end;

procedure TTestRadIAProjectTemplates.TestServiceTemplateContainsServiceContract;
var
  LEngine: TRadIAProjectTemplateEngine;
  LFile: TRadIAProjectTemplateFile;
  LFoundServiceUnit: Boolean;
  LPlan: TRadIAProjectTemplatePlan;
begin
  LEngine := TRadIAProjectTemplateEngine.Create;
  try
    LPlan := LEngine.BuildPlan(
      TRadIAProjectTemplateRequest.Create(
        'BackgroundWorker',
        ptkService,
        '37.0',
        ['Win64']
      )
    );
    try
      LFoundServiceUnit := False;
      for LFile in LPlan.Files do
      begin
        if not SameText(LFile.RelativePath, 'MainService.pas') then
          Continue;
        LFoundServiceUnit := True;
        Assert.Contains(LFile.Content, 'TRadIAService = class(TService)');
        Assert.Contains(LFile.Content, 'GetServiceController');
      end;
      Assert.IsTrue(LFoundServiceUnit);
      Assert.Contains(LPlan.PreviewJson, '"template":"service"');
    finally
      LPlan.Free;
    end;
  finally
    LEngine.Free;
  end;
end;

procedure TTestRadIAProjectTemplates.TestPreparedTransactionCleansStagingOnDestroy;
var
  LDestination: string;
  LEngine: TRadIAProjectTemplateEngine;
  LPlan: TRadIAProjectTemplatePlan;
  LRoot: string;
  LStagingPath: string;
  LTransaction: TRadIAProjectTemplateTransaction;
begin
  LRoot := TPath.Combine(
    TPath.GetTempPath,
    'radia-project-stage-' +
    TGUID.NewGuid.ToString.Replace('{', '').Replace('}', '')
  );
  LDestination := TPath.Combine(LRoot, 'PreparedProject');
  LEngine := TRadIAProjectTemplateEngine.Create;
  try
    LPlan := LEngine.BuildPlan(
      TRadIAProjectTemplateRequest.Create(
        'PreparedProject',
        ptkConsole,
        '37.0',
        ['Win32']
      )
    );
    try
      LTransaction := TRadIAProjectTemplateTransaction.Create;
      LTransaction.Prepare(LPlan, LDestination);
      LStagingPath := LTransaction.StagingPath;
      Assert.IsTrue(TDirectory.Exists(LStagingPath));
      LTransaction.Free;
      Assert.IsFalse(TDirectory.Exists(LStagingPath));
      Assert.IsFalse(TDirectory.Exists(LDestination));
    finally
      LPlan.Free;
    end;
  finally
    LEngine.Free;
    if TDirectory.Exists(LRoot) then
      TDirectory.Delete(LRoot, True);
  end;
end;

procedure TTestRadIAProjectTemplates.TestTransactionStagesCommitsAndRollsBack;
var
  LDestination: string;
  LEngine: TRadIAProjectTemplateEngine;
  LPlan: TRadIAProjectTemplatePlan;
  LRoot: string;
  LStagingPath: string;
  LTransaction: TRadIAProjectTemplateTransaction;
begin
  LRoot := TPath.Combine(
    TPath.GetTempPath,
    'radia-project-transaction-' +
    TGUID.NewGuid.ToString.Replace('{', '').Replace('}', '')
  );
  LDestination := TPath.Combine(LRoot, 'TransactionalProject');
  TDirectory.CreateDirectory(LDestination);
  LEngine := TRadIAProjectTemplateEngine.Create;
  try
    LPlan := LEngine.BuildPlan(
      TRadIAProjectTemplateRequest.Create(
        'TransactionalProject',
        ptkVcl,
        '37.0',
        ['Win32', 'Win64']
      )
    );
    try
      LTransaction := TRadIAProjectTemplateTransaction.Create;
      try
        LTransaction.Prepare(LPlan, LDestination);
        LStagingPath := LTransaction.StagingPath;
        Assert.AreEqual(ptsPrepared, LTransaction.State);
        Assert.IsTrue(TDirectory.Exists(LStagingPath));
        Assert.AreEqual<Integer>(
          0,
          Length(TDirectory.GetFileSystemEntries(LDestination))
        );

        LTransaction.Commit;

        Assert.AreEqual(ptsCommitted, LTransaction.State);
        Assert.IsFalse(TDirectory.Exists(LStagingPath));
        Assert.IsTrue(
          TFile.Exists(
            TPath.Combine(LDestination, 'TransactionalProject.dproj')
          )
        );

        LTransaction.Rollback;

        Assert.AreEqual(ptsRolledBack, LTransaction.State);
        Assert.IsTrue(TDirectory.Exists(LDestination));
        Assert.AreEqual<Integer>(
          0,
          Length(TDirectory.GetFileSystemEntries(LDestination))
        );
      finally
        LTransaction.Free;
      end;
    finally
      LPlan.Free;
    end;
  finally
    LEngine.Free;
    if TDirectory.Exists(LRoot) then
      TDirectory.Delete(LRoot, True);
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestRadIAProjectTemplates);

end.
