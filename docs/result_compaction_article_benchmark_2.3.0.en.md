# Internal RTK Editorial Benchmark — RadIA 2.3.0

Measurement date: August 8, 2026.

## Main number for the article

In ten independent runs of the benchmark compiled in Release, the internal RTK reduced a corpus
of results from 1,145,022 to 37,630 characters: **96.71% reduction**, or one payload
**30.43 times smaller**. By the explicit approximation of four characters per token, this represents
a drop from 286,256 to an estimated 9,408 tokens, saving approximately 276,848 tokens per
corpus replay.

In the A/B replay of the context delivered to the agent's next decision, keeping the same seven calls
tool, the size dropped from 1,152,074 to 39,750 characters: **96.55% reduction** and a context
**28.98 times smaller**. There was no increase in repeat calls.

## Results by scenario

|Scenario|Original|Compressed|Reduction|Average time|
|---|---:|---:|---:|---:|
|DUnitX with repeated successes| 16.902 | 178 | 98,95% |0.144ms|
|Git big diff| 29.105 | 14.377 | 50,60% |1,221ms|
|DUnitX with ANSI| 10.534 | 91 | 99,14% |0.082ms|
|Structured build messages| 23.707 | 4.815 | 79,69% |0.516ms|
|Great knowledge content| 16.103 | 3.960 | 75,41% |0.062ms|
|1 MiB Git diff| 1.048.622 | 14.160 | 98,65% |20.745ms|
|Ineligible Tool| 49 | 49 | 0% |0 ms|

The ineligible tool is a negative control: the content passed without changes, confirming the
fail-open behavior when there is no safe compression rule.

## Stability of the ten executions

|Metric|Result|
|---|---:|
|Minimum, average and maximum corpus reduction| 96,71% |
|Minimum total time|21.544ms|
|Median total time|22.732ms|
|Average total time|22.920ms|
|Maximum total time|24.391ms|
|Median 1 MiB diff|20.745ms|
|1 MiB diff range|19.589–22.290 ms|
|Increase in repeat calls| 0% |

## Reproducible methodology

- Binary: `RadIATests.exe`, Delphi 13, Win32 Release.
- Machine: Intel Core i9-13900HX, 24 cores and 32 logical processors.
- System: Windows 11 Pro 64 bits, version 10.0.26200.
- Sample: ten independent processes; one execution of the compiled fixture per process.
- Corpus: seven sanitized fixtures of DUnitX, Git diff, build, knowledge and passthrough.
- A/B comparison: same tools and same results, alternating only the full or
compressed delivered to the decision-making context.
- Fidelity: tests check preservation of errors, failures, headers and diff hunks,
start/end, provenance, recoverable full result and rollback `Off`.
- Raw evidence: `Output/ArticleBenchmarks/ReleaseWin32/run-01.json` through `run-10.json`.

Command used in each process:

```powershell
Output\37.0\bin\Win32\Release\RadIATests.exe `
  --run:RadIA.Tests.ResultCompactionBenchmark.TRadIAResultCompactionBenchmarkTests.BenchmarkProducesMeasuredSavings `
  --consolemode:Quiet
```

## How to communicate numbers

Use “estimated tokens” when quoting 286,256 → 9,408, as the conversion uses an approximation of four
characters per token and not a specific provider's tokenizer. The character economy is exact
to the corpus. The benchmark demonstrates reduced context and local computational cost; he shouldn't
be presented in isolation as guaranteed bill reduction, because pricing, caching and tokenization
depend on the model and provider.

The corpus is synthetic and sanitized, created to be deterministic and auditable. The article must address
96.71% as a result of this benchmark, not as a universal promise for every real session. The protection
most important is architectural: the agent receives the compressed projection, while the integral result
remains available for per-track recovery without repeating the tool.
