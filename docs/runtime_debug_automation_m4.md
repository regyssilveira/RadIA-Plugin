# M4 — Diagnóstico, correção e repetição

## Entrega

O `/journey debug` agora orienta explicitamente o ciclo completo: compilar, iniciar a depuração,
preparar e autorizar um cenário runtime, reproduzir a falha, capturar evidências, revisar a
correção, recompilar, repetir o mesmo cenário e comparar os resultados.

Duas ferramentas fecham a trilha de prova:

- `CaptureRuntimeEvidence` registra sessão, projeto, executável, build, resultado do cenário,
  último evento correlacionado, pilha e até dez expressões;
- `CompareRuntimeEvidence` exige uma evidência de falha e outra de verificação, provenientes do
  mesmo projeto, mas de sessões e builds diferentes.

As evidências recebem identificador opaco, fingerprint SHA-256 e redação de dados sensíveis.
Elas permanecem somente em memória nesta etapa. Persistência versionada e repetição em dez ciclos
pertencem ao M5.

## Critério de comparação

O resultado `fixed` só é emitido quando:

1. a primeira evidência pertence à fase `failure` e contém uma exceção;
2. a segunda pertence à fase `verification`;
3. projeto é o mesmo, mas sessão e build são diferentes;
4. o cenário de verificação termina com sucesso;
5. a verificação não contém nova exceção.

Caso essas precondições não sejam atendidas, o resultado é `notComparable`; se forem atendidas,
mas a falha continuar, o resultado é `stillFailing`.

## Segurança e consentimento

- captura e comparação são somente leitura;
- a execução do cenário continua exigindo consentimento em toda tentativa;
- a correção continua usando preview e consentimento das ferramentas de patch existentes;
- nenhuma evidência lê campos de senha, e resultados de expressões passam pelo redator;
- a comparação não aplica nem aprova alterações automaticamente.

## Evidência automatizada

- catálogo verificável com 106 ferramentas;
- testes de captura sanitizada, pilha, expressões e comparação entre builds;
- teste de exposição do último evento correlacionado;
- integração das evidências ao snapshot de validação do modo agente;
- Delphi 12 Win32, Delphi 13 Win32 e Delphi 13 IDE64: 798/798 testes por alvo, sem falhas,
  erros, ignorados ou vazamentos;
- SonarQube: quality gate aprovado, cobertura nova de 82,3%, duplicação nova de 0,99504% e
  zero issues; métricas globais com cobertura de 82,7%, duplicação de 2,1% e ratings A.

## Pendência de aceite

O contrato e a orquestração do M4 estão implementados. O aceite operacional ainda requer executar
o laboratório dentro de cada host real — Delphi 12 Win32, Delphi 13 Win32 e Delphi 13 IDE64 —,
aplicar uma correção revisada e obter `fixed` ao repetir exatamente o mesmo cenário.

Depois desse aceite, o M5 deve versionar a regressão, executar dez ciclos por alvo e fechar o gate.
