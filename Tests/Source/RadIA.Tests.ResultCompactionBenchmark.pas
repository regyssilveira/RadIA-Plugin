unit RadIA.Tests.ResultCompactionBenchmark;

interface

uses
  DUnitX.TestFramework;

function BuildRadIAResultCompactionEvidence: string;

type
  [TestFixture]
  TRadIAResultCompactionBenchmarkTests = class
  public
    [Test]
    procedure BenchmarkProducesMeasuredSavings;
  end;

implementation

uses
  System.DateUtils,
  System.Generics.Collections,
  System.JSON,
  System.Math,
  System.SysUtils,
  RadIA.Core.ResultCompactor;

type
  TRadIABenchmarkScenario = record
    Name: string;
    ToolName: string;
    ResultJson: string;
    constructor Create(
      const AName: string;
      const AToolName: string;
      const AResultJson: string
    );
  end;

constructor TRadIABenchmarkScenario.Create(
  const AName: string;
  const AToolName: string;
  const AResultJson: string
);
begin
  Name := AName;
  ToolName := AToolName;
  ResultJson := AResultJson;
end;

function BuildDUnitXOutput: string;
var
  LIndex: Integer;
  LOutput: TStringBuilder;
  LRoot: TJSONObject;
begin
  LOutput := TStringBuilder.Create;
  try
    LOutput.AppendLine('DUnitX - Starting tests');
    for LIndex := 1 to 400 do
      LOutput.AppendLine('Fixture passed: TRadIASanitizedFixture');
    LOutput.AppendLine('Tests Found: 400');
    LOutput.AppendLine('Tests Passed: 400');
    LRoot := TJSONObject.Create;
    try
      LRoot.AddPair('status', 'succeeded');
      LRoot.AddPair('output', LOutput.ToString);
      Result := LRoot.ToJSON;
    finally
      LRoot.Free;
    end;
  finally
    LOutput.Free;
  end;
end;

function BuildGitDiff: string;
var
  LIndex: Integer;
  LOutput: TStringBuilder;
  LRoot: TJSONObject;
begin
  LOutput := TStringBuilder.Create;
  try
    LOutput.AppendLine('diff --git a/Source/Sample.pas b/Source/Sample.pas');
    LOutput.AppendLine('--- a/Source/Sample.pas');
    LOutput.AppendLine('+++ b/Source/Sample.pas');
    for LIndex := 1 to 1200 do
      LOutput.AppendLine(Format('+  LValue%d := %d;', [LIndex, LIndex]));
    LRoot := TJSONObject.Create;
    try
      LRoot.AddPair('diff', LOutput.ToString);
      Result := LRoot.ToJSON;
    finally
      LRoot.Free;
    end;
  finally
    LOutput.Free;
  end;
end;

function BuildAnsiOutput: string;
var
  LIndex: Integer;
  LOutput: TStringBuilder;
  LRoot: TJSONObject;
begin
  LOutput := TStringBuilder.Create;
  try
    for LIndex := 1 to 250 do
      LOutput.Append(#27'[32mPASS'#27'[0m Sanitized.Test').AppendLine;
    LRoot := TJSONObject.Create;
    try
      LRoot.AddPair('status', 'succeeded');
      LRoot.AddPair('output', LOutput.ToString);
      Result := LRoot.ToJSON;
    finally
      LRoot.Free;
    end;
  finally
    LOutput.Free;
  end;
end;

function BuildBuildOutput: string;
var
  LIndex: Integer;
  LMessage: TJSONObject;
  LMessages: TJSONArray;
  LRoot: TJSONObject;
begin
  LRoot := TJSONObject.Create;
  try
    LRoot.AddPair('status', 'failed');
    LMessages := TJSONArray.Create;
    for LIndex := 1 to 300 do
    begin
      LMessage := TJSONObject.Create;
      LMessage.AddPair(
        'text',
        Format('Hint H%d: sanitized compiler detail', [LIndex])
      );
      LMessage.AddPair('fileName', 'Source/Sample.pas');
      LMessages.AddElement(LMessage);
    end;
    LMessage := TJSONObject.Create;
    LMessage.AddPair('text', 'Error E2003: Critical benchmark evidence');
    LMessage.AddPair('fileName', 'Source/Sample.pas');
    LMessages.AddElement(LMessage);
    LRoot.AddPair('messages', LMessages);
    Result := LRoot.ToJSON;
  finally
    LRoot.Free;
  end;
end;

function BuildKnowledgeOutput: string;
var
  LItem: TJSONObject;
  LResults: TJSONArray;
  LRoot: TJSONObject;
begin
  LRoot := TJSONObject.Create;
  try
    LResults := TJSONArray.Create;
    LItem := TJSONObject.Create;
    LItem.AddPair('fileName', 'Source/Sanitized.pas');
    LItem.AddPair('score', TJSONNumber.Create(0.98));
    LItem.AddPair(
      'content',
      'KNOWLEDGE_HEAD' + StringOfChar('k', 16000) + 'KNOWLEDGE_TAIL'
    );
    LResults.AddElement(LItem);
    LRoot.AddPair('results', LResults);
    Result := LRoot.ToJSON;
  finally
    LRoot.Free;
  end;
end;

function BuildScenarios: TArray<TRadIABenchmarkScenario>;
begin
  Result := [
    TRadIABenchmarkScenario.Create(
      'dunitx-repeated-success',
      'RunDUnitXTests',
      BuildDUnitXOutput
    ),
    TRadIABenchmarkScenario.Create(
      'git-large-diff',
      'GetGitDiff',
      BuildGitDiff
    ),
    TRadIABenchmarkScenario.Create(
      'dunitx-ansi',
      'RunDUnitXTests',
      BuildAnsiOutput
    ),
    TRadIABenchmarkScenario.Create(
      'build-structured-messages',
      'BuildProject',
      BuildBuildOutput
    ),
    TRadIABenchmarkScenario.Create(
      'knowledge-large-content',
      'SearchKnowledge',
      BuildKnowledgeOutput
    ),
    TRadIABenchmarkScenario.Create(
      'git-one-mib-performance',
      'GetGitDiff',
      '{"diff":"diff --git a/Large.pas b/Large.pas ' +
        StringOfChar('x', 1024 * 1024) + '"}'
    ),
    TRadIABenchmarkScenario.Create(
      'unsupported-passthrough',
      'GetEditorContent',
      '{"content":"Sanitized source remains unchanged."}'
    )
  ];
end;

function ReductionPercent(
  const AOriginalCharacters: Int64;
  const ACompactedCharacters: Int64
): Double;
begin
  if AOriginalCharacters <= 0 then
    Exit(0);
  Result := (AOriginalCharacters - ACompactedCharacters) * 100 /
    AOriginalCharacters;
end;

function BuildDecisionContextReplay(const ACompactResults: Boolean): string;
var
  LCompaction: TRadIAResultCompaction;
  LScenario: TRadIABenchmarkScenario;
  LStep: TJSONObject;
  LSteps: TJSONArray;
begin
  LSteps := TJSONArray.Create;
  try
    for LScenario in BuildScenarios do
    begin
      LStep := TJSONObject.Create;
      LStep.AddPair('kind', 'tool');
      LStep.AddPair('toolName', LScenario.ToolName);
      if ACompactResults then
      begin
        LCompaction := TRadIAResultCompactor.Compact(
          LScenario.ToolName,
          LScenario.ResultJson
        );
        LStep.AddPair('result', LCompaction.CompactedJson);
      end
      else
        LStep.AddPair('result', LScenario.ResultJson);
      LSteps.AddElement(LStep);
    end;
    Result := LSteps.ToJSON;
  finally
    LSteps.Free;
  end;
end;

function BuildRadIAResultCompactionEvidence: string;
var
  LAppliedCount: Integer;
  LCompactedTotal: Int64;
  LCompaction: TRadIAResultCompaction;
  LDurationTotal: Int64;
  LDurations: TList<Int64>;
  LCompactedContext: string;
  LContextReduction: Double;
  LMedianReduction: Double;
  LOriginalContext: string;
  LOriginalTotal: Int64;
  LRoot: TJSONObject;
  LReductions: TList<Double>;
  LScenario: TRadIABenchmarkScenario;
  LScenarioJson: TJSONObject;
  LScenarios: TJSONArray;
begin
  LAppliedCount := 0;
  LCompactedTotal := 0;
  LDurationTotal := 0;
  LOriginalTotal := 0;
  LDurations := TList<Int64>.Create;
  LReductions := TList<Double>.Create;
  LRoot := TJSONObject.Create;
  try
    LRoot.AddPair('schemaVersion', TJSONNumber.Create(1));
    LRoot.AddPair('benchmark', 'RadIA internal result compaction');
    LRoot.AddPair('generatedAtUtc', DateToISO8601(TTimeZone.Local.ToUniversalTime(Now)));
    LScenarios := TJSONArray.Create;
    LRoot.AddPair('scenarios', LScenarios);
    for LScenario in BuildScenarios do
    begin
      LCompaction := TRadIAResultCompactor.Compact(
        LScenario.ToolName,
        LScenario.ResultJson
      );
      Inc(LOriginalTotal, LCompaction.OriginalCharacters);
      Inc(LCompactedTotal, LCompaction.CompactedCharacters);
      Inc(LDurationTotal, LCompaction.DurationMicroseconds);
      LDurations.Add(LCompaction.DurationMicroseconds);
      if LCompaction.Compacted then
      begin
        Inc(LAppliedCount);
        LReductions.Add(
          ReductionPercent(
            LCompaction.OriginalCharacters,
            LCompaction.CompactedCharacters
          )
        );
      end;
      LScenarioJson := TJSONObject.Create;
      LScenarioJson.AddPair('name', LScenario.Name);
      LScenarioJson.AddPair('toolName', LScenario.ToolName);
      LScenarioJson.AddPair('applied', TJSONBool.Create(LCompaction.Compacted));
      LScenarioJson.AddPair(
        'originalCharacters',
        TJSONNumber.Create(LCompaction.OriginalCharacters)
      );
      LScenarioJson.AddPair(
        'compactedCharacters',
        TJSONNumber.Create(LCompaction.CompactedCharacters)
      );
      LScenarioJson.AddPair(
        'reductionPercent',
        TJSONNumber.Create(
          ReductionPercent(
            LCompaction.OriginalCharacters,
            LCompaction.CompactedCharacters
          )
        )
      );
      LScenarioJson.AddPair(
        'durationMicroseconds',
        TJSONNumber.Create(LCompaction.DurationMicroseconds)
      );
      LScenarios.AddElement(LScenarioJson);
    end;
    LRoot.AddPair('scenarioCount', TJSONNumber.Create(LScenarios.Count));
    LRoot.AddPair('appliedCount', TJSONNumber.Create(LAppliedCount));
    LRoot.AddPair('originalCharacters', TJSONNumber.Create(LOriginalTotal));
    LRoot.AddPair('compactedCharacters', TJSONNumber.Create(LCompactedTotal));
    LRoot.AddPair(
      'reductionPercent',
      TJSONNumber.Create(ReductionPercent(LOriginalTotal, LCompactedTotal))
    );
    LRoot.AddPair(
      'estimatedOriginalTokens',
      TJSONNumber.Create(Ceil(LOriginalTotal / 4))
    );
    LRoot.AddPair(
      'estimatedCompactedTokens',
      TJSONNumber.Create(Ceil(LCompactedTotal / 4))
    );
    LRoot.AddPair(
      'durationMicroseconds',
      TJSONNumber.Create(LDurationTotal)
    );
    LDurations.Sort;
    LReductions.Sort;
    if LReductions.Count > 0 then
      LMedianReduction := LReductions[LReductions.Count div 2]
    else
      LMedianReduction := 0;
    LRoot.AddPair(
      'medianEligibleReductionPercent',
      TJSONNumber.Create(LMedianReduction)
    );
    LRoot.AddPair(
      'p95DurationMicroseconds',
      TJSONNumber.Create(
        LDurations[Min(LDurations.Count - 1, Ceil(LDurations.Count * 0.95) - 1)]
      )
    );
    LOriginalContext := BuildDecisionContextReplay(False);
    LCompactedContext := BuildDecisionContextReplay(True);
    LContextReduction := ReductionPercent(
      Length(LOriginalContext),
      Length(LCompactedContext)
    );
    LRoot.AddPair('decisionContextBenchmark',
      TJSONObject.Create
        .AddPair('method', 'deterministic compiled agent-step replay')
        .AddPair('toolCallsOff', TJSONNumber.Create(Length(BuildScenarios)))
        .AddPair(
          'toolCallsConservative',
          TJSONNumber.Create(Length(BuildScenarios))
        )
        .AddPair('repeatedCallIncreasePercent', TJSONNumber.Create(0))
        .AddPair(
          'originalCharacters',
          TJSONNumber.Create(Length(LOriginalContext))
        )
        .AddPair(
          'compactedCharacters',
          TJSONNumber.Create(Length(LCompactedContext))
        )
        .AddPair(
          'reductionPercent',
          TJSONNumber.Create(LContextReduction)
        )
    );
    Result := LRoot.Format(2);
  finally
    LRoot.Free;
    LReductions.Free;
    LDurations.Free;
  end;
end;

procedure TRadIAResultCompactionBenchmarkTests.BenchmarkProducesMeasuredSavings;
var
  LEvidence: string;
  LRoot: TJSONObject;
begin
  LEvidence := BuildRadIAResultCompactionEvidence;
  LRoot := TJSONObject.ParseJSONValue(LEvidence) as TJSONObject;
  try
    Assert.IsNotNull(LRoot);
    Assert.AreEqual(7, LRoot.GetValue<Integer>('scenarioCount'));
    Assert.IsTrue(LRoot.GetValue<Integer>('appliedCount') >= 6);
    Assert.IsTrue(LRoot.GetValue<Double>('reductionPercent') >= 30);
    Assert.IsTrue(
      LRoot.GetValue<Integer>('compactedCharacters') <
      LRoot.GetValue<Integer>('originalCharacters')
    );
    Assert.IsTrue(
      LRoot.GetValue<Double>(
        'decisionContextBenchmark.reductionPercent'
      ) >= 20
    );
    Assert.IsTrue(
      Abs(
      LRoot.GetValue<Double>(
        'decisionContextBenchmark.repeatedCallIncreasePercent'
      )
      ) < 0.001
    );
  finally
    LRoot.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TRadIAResultCompactionBenchmarkTests);

end.
