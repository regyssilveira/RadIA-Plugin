# Benchmark editorial do RTK interno — RadIA 2.3.0

Data da medição: 8 de agosto de 2026.

## Número principal para o artigo

Em dez execuções independentes do benchmark compilado em Release, o RTK interno reduziu um corpus
de resultados de 1.145.022 para 37.630 caracteres: **96,71% de redução**, ou um payload
**30,43 vezes menor**. Pela aproximação explícita de quatro caracteres por token, isso representa
uma queda de 286.256 para 9.408 tokens estimados, economizando aproximadamente 276.848 tokens por
replay do corpus.

No replay A/B do contexto entregue à próxima decisão do agente, mantendo as mesmas sete chamadas de
ferramenta, o tamanho caiu de 1.152.074 para 39.750 caracteres: **96,55% de redução** e um contexto
**28,98 vezes menor**. Não houve aumento de chamadas repetidas.

## Resultados por cenário

| Cenário | Original | Compactado | Redução | Tempo mediano |
|---|---:|---:|---:|---:|
| DUnitX com sucessos repetidos | 16.902 | 178 | 98,95% | 0,144 ms |
| Git diff grande | 29.105 | 14.377 | 50,60% | 1,221 ms |
| DUnitX com ANSI | 10.534 | 91 | 99,14% | 0,082 ms |
| Mensagens estruturadas de build | 23.707 | 4.815 | 79,69% | 0,516 ms |
| Conteúdo grande de conhecimento | 16.103 | 3.960 | 75,41% | 0,062 ms |
| Git diff de 1 MiB | 1.048.622 | 14.160 | 98,65% | 20,745 ms |
| Ferramenta não elegível | 49 | 49 | 0% | 0 ms |

A ferramenta não elegível é um controle negativo: o conteúdo passou sem alterações, confirmando o
comportamento fail-open quando não existe regra segura de compactação.

## Estabilidade das dez execuções

| Métrica | Resultado |
|---|---:|
| Redução mínima, média e máxima do corpus | 96,71% |
| Tempo total mínimo | 21,544 ms |
| Tempo total mediano | 22,732 ms |
| Tempo total médio | 22,920 ms |
| Tempo total máximo | 24,391 ms |
| Mediana do diff de 1 MiB | 20,745 ms |
| Faixa do diff de 1 MiB | 19,589–22,290 ms |
| Aumento de chamadas repetidas | 0% |

## Metodologia reproduzível

- Binário: `RadIATests.exe`, Delphi 13, Win32 Release.
- Máquina: Intel Core i9-13900HX, 24 cores e 32 processadores lógicos.
- Sistema: Windows 11 Pro 64 bits, versão 10.0.26200.
- Amostra: dez processos independentes; uma execução do fixture compilado por processo.
- Corpus: sete fixtures sanitizadas de DUnitX, Git diff, build, conhecimento e passthrough.
- Comparação A/B: mesmas ferramentas e mesmos resultados, alternando apenas a projeção integral ou
  compactada entregue ao contexto decisório.
- Fidelidade: os testes verificam preservação de errors, failures, cabeçalhos e hunks de diff,
  início/fim, proveniência, resultado integral recuperável e rollback `Off`.
- Evidência bruta: `Output/ArticleBenchmarks/ReleaseWin32/run-01.json` até `run-10.json`.

Comando usado em cada processo:

```powershell
Output\37.0\bin\Win32\Release\RadIATests.exe `
  --run:RadIA.Tests.ResultCompactionBenchmark.TRadIAResultCompactionBenchmarkTests.BenchmarkProducesMeasuredSavings `
  --consolemode:Quiet
```

## Como comunicar os números

Use “tokens estimados” quando citar 286.256 → 9.408, pois a conversão usa uma aproximação de quatro
caracteres por token e não o tokenizer de um provedor específico. A economia de caracteres é exata
para o corpus. O benchmark demonstra redução de contexto e custo computacional local; ele não deve
ser apresentado isoladamente como redução garantida da fatura, porque preços, cache e tokenização
dependem do modelo e do provedor.

O corpus é sintético e sanitizado, criado para ser determinístico e auditável. O artigo deve tratar
96,71% como resultado deste benchmark, não como promessa universal para toda sessão real. A proteção
mais importante é arquitetural: o agente recebe a projeção compactada, enquanto o resultado integral
permanece disponível para recuperação por faixa sem repetir a ferramenta.
