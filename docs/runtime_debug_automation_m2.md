# M2 — Descoberta runtime segura

> **Estado:** implementação e testes automatizados concluídos; validação dentro da IDE pendente.
> **Goal:** [Reprodução autônoma de falhas runtime](runtime_debug_automation_plan.md).

## Entregas

- correlação do processo pela combinação PID, instante de criação e caminho do executável;
- inclusão restrita ao processo depurado e aos descendentes criados durante a sessão;
- descoberta de janelas de nível superior, proprietário e controles VCL com janela própria;
- identificadores opacos por sessão, sem expor ou aceitar `HWND`;
- árvore de controles com classe, texto sanitizado, caminho hierárquico, estado e capacidades;
- leitura de texto protegida por timeout para não bloquear quando a aplicação estiver pausada;
- redação obrigatória do conteúdo de campos de senha;
- rejeição de sessão alterada, janela externa e identificador desconhecido.

## Ferramentas

| Ferramenta | Uso |
|---|---|
| `GetRuntimeWindows` | Lista somente as janelas do processo autorizado e de seus descendentes. |
| `GetRuntimeControlTree` | Retorna a árvore sanitizada de uma janela identificada pelo ID opaco. |

As duas ferramentas obtêm a sessão atual diretamente do coordenador. O chamador não informa PID,
executável nem handle, portanto não consegue ampliar o escopo autorizado pelos argumentos.

## Capacidades informadas

| Capacidade | Controles reconhecidos |
|---|---|
| `invoke` | botões com janela própria |
| `setValue` | editores e memos com janela própria |
| `select` | combos e listas com janela própria |
| `close` | janelas de nível superior |

Uma capacidade apenas descreve uma ação possível. A execução continua bloqueada até M3, quando
prévia, consentimento, limites e parada de emergência serão aplicados.

## Limitações intencionais

- controles gráficos sem `HWND` ainda não aparecem na árvore;
- não há automação por coordenadas globais;
- não são aceitos handles fornecidos pelo modelo ou pelo usuário;
- Automation ID e diagnóstico de seletores ambíguos serão aprofundados antes da execução M3;
- a descoberta não clica, fecha nem altera qualquer controle.

## Evidências automatizadas

- formulário e botão autorizados são encontrados com IDs opacos;
- relação entre janela proprietária e janela pertencente é preservada;
- todos os resultados pertencem ao processo autorizado;
- um ID opaco desconhecido é rejeitado;
- nenhum JSON retorna `handle` ou `HWND`;
- campo de senha retorna somente `[redacted]`;
- catálogo verificável contém 100 ferramentas.

## Evidência ainda pendente

O aceite final exige executar a aplicação-laboratório dentro dos três hosts suportados e localizar o
formulário principal, o formulário-alvo e os controles de abrir e cancelar. A validação deve incluir
uma janela externa para comprovar sua exclusão no ambiente real da IDE.

## O que falta para o goal

- evidência M0–M2 dentro dos três hosts;
- M3: execução declarativa limitada;
- M4: ciclo de diagnóstico, correção e repetição;
- M5: regressão, evidências e hardening.
