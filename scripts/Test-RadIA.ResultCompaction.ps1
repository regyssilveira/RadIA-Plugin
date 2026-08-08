param(
  [string]$DelphiVersion = "23.0",
  [string]$EvidencePath = "Output\ResultCompactionEvidence.json",
  [double]$MinimumReductionPercent = 30
)

$ErrorActionPreference = "Stop"

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$resolvedEvidencePath = Join-Path $repositoryRoot $EvidencePath
$previousEvidencePath = $env:RADIA_RESULT_COMPACTION_EVIDENCE_PATH

try {
  $env:RADIA_RESULT_COMPACTION_EVIDENCE_PATH = $resolvedEvidencePath
  & (Join-Path $repositoryRoot "build.ps1") `
    -DelphiVersion $DelphiVersion `
    -Test `
    -NoCoverage
  if ($LASTEXITCODE -ne 0) {
    throw "The Delphi build or test suite failed with exit code $LASTEXITCODE."
  }
}
finally {
  $env:RADIA_RESULT_COMPACTION_EVIDENCE_PATH = $previousEvidencePath
}

if (-not (Test-Path -LiteralPath $resolvedEvidencePath)) {
  throw "Result compaction evidence was not generated: $resolvedEvidencePath"
}

$evidence = Get-Content -LiteralPath $resolvedEvidencePath -Raw | ConvertFrom-Json
if ($evidence.scenarioCount -lt 7) {
  throw "The benchmark did not execute every required scenario."
}
if ($evidence.reductionPercent -lt $MinimumReductionPercent) {
  throw (
    "Measured reduction {0:N2}% is below the required {1:N2}%." -f `
      $evidence.reductionPercent,
      $MinimumReductionPercent
  )
}
if ($evidence.compactedCharacters -ge $evidence.originalCharacters) {
  throw "The compacted benchmark payload is not smaller than the original payload."
}
if ($evidence.medianEligibleReductionPercent -lt $MinimumReductionPercent) {
  throw "Median eligible result reduction is below the required threshold."
}
if ($evidence.p95DurationMicroseconds -ge 50000) {
  throw "Compaction P95 exceeded the 50000 microsecond performance gate."
}
if ($evidence.decisionContextBenchmark.reductionPercent -lt 20) {
  throw "Decision-context reduction is below the required 20 percent."
}
if ($evidence.decisionContextBenchmark.repeatedCallIncreasePercent -ge 5) {
  throw "Repeated tool-call increase reached the maximum allowed 5 percent."
}

Write-Host "Result compaction benchmark passed."
Write-Host ("Original characters:  {0}" -f $evidence.originalCharacters)
Write-Host ("Compacted characters: {0}" -f $evidence.compactedCharacters)
Write-Host ("Measured reduction:    {0:N2}%" -f $evidence.reductionPercent)
Write-Host ("Estimated tokens:      {0} -> {1}" -f `
  $evidence.estimatedOriginalTokens,
  $evidence.estimatedCompactedTokens)
Write-Host ("Compaction time:       {0} microseconds" -f $evidence.durationMicroseconds)
Write-Host ("Median eligible gain: {0:N2}%" -f $evidence.medianEligibleReductionPercent)
Write-Host ("P95 compaction time:  {0} microseconds" -f $evidence.p95DurationMicroseconds)
Write-Host ("Decision context gain: {0:N2}%" -f `
  $evidence.decisionContextBenchmark.reductionPercent)
Write-Host ("Repeated call change:  {0:N2}%" -f `
  $evidence.decisionContextBenchmark.repeatedCallIncreasePercent)
Write-Host ("Evidence:              {0}" -f $resolvedEvidencePath)
