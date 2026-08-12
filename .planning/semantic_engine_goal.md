# Goal RadIA 2.10.0 — Motor Semântico Estrutural

> **Estado:** em execução. **Baseline:** RadIA 2.9.0. **Matriz:** Delphi 12 Win32 e Delphi 13
> Win32/IDE64, com compilação dos targets Win64 aplicáveis.

## Resultado esperado

O RadIA deve compreender declarações, símbolos, tipos, herança, interfaces e visibilidade entre as
units do projeto, RTL e VCL. O motor complementa o CodeInsight; não o substitui. O contexto limitado
existente permanece como fallback quando o processo auxiliar estiver indisponível.

## Base reutilizada da 2.9.0

- perfil sanitizado do ambiente Delphi e search paths básicos;
- contexto compartilhado do editor e Ghost Text;
- preview, consentimento, undo, rollback e evidências agentivas;
- auditoria DFM/PAS, Mentor Delphi e `/doctor --deep` como consumidores futuros.

A auditoria DFM/PAS continua especializada. Seu parser por linhas não é tratado como parser Pascal
geral nem como prova de resolução entre units.

## Arquitetura obrigatória

1. O motor roda fora do `bds.exe` em um processo supervisionado.
2. A integração OTA captura buffers e aplica edições, mas não decide o significado dos símbolos.
3. O protocolo local é versionado, cancelável e possui timeout e reinício controlado.
4. Tokens e nós preservam offsets do buffer original.
5. Condições não resolvidas são diagnosticadas; o motor nunca escolhe silenciosamente um ramo.
6. Toda mutação usa preview, consentimento e validação otimista do buffer.

## Etapas e gates

| Marco | Entrega | Gate de conclusão |
| :--- | :--- | :--- |
| M0 | contrato, protocolo, métricas e planejamento | backlog e documentação bilíngue aprovados |
| M1 | perfil efetivo Delphi 12/13 | defines, scopes, includes, library e search paths reproduzíveis |
| M2 | processo externo, lexer e pré-processador | crash isolado, cancelamento e offsets exatos no corpus |
| M3 | parser estrutural | declarações modernas e erros parciais sem perda silenciosa da unit |
| M4 | índice incremental | projeto, grupo, RTL e VCL consultáveis com invalidação por unit |
| M5 | implementar membros ausentes | preview idempotente, undo único e compilação com Delphi 12/13 |
| M6 | consumidores existentes | agente, navegação, Ghost Text e DFM/PAS usam o índice com fallback |
| M7 | completion resolvida e diagnóstico | resposta local cancelável e `/doctor --deep` acionável |
| M8 | candidato de release | matriz, DUnitX, corpus, Sonar, instalador e documentação aprovados |

## Métricas mínimas

- nenhuma falha do motor derruba ou bloqueia a IDE;
- 100% dos tokens do corpus preservam cobertura e offsets do texto original;
- pelo menos 99% das units RTL/VCL suportadas passam pelo parser sem erro estrutural fatal;
- consultas aquecidas de símbolo e membros possuem meta de até 50 ms;
- a ação de membros ausentes é idempotente e gera código compilável nos dois Delphis;
- cache corrompido é descartado e reconstruído sem intervenção manual.

## Fora do escopo

- Delphi 11, C++, Lazarus e leitura de DCU;
- substituição integral do CodeInsight;
- type checker completo ou interpretação profunda de todos os corpos;
- refatorações universais e marketplace.

## Condição de conclusão

O goal termina somente quando um usuário consegue indexar um projeto real, navegar e completar com
resolução estrutural, implementar uma interface ausente com código compilável e diagnosticar o
motor no Delphi 12 e 13. Build, testes, corpus, Sonar, documentação e instalação devem produzir
evidência reproduzível.
