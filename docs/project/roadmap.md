# Roadmap do RadIA

O roadmap descreve direção, não histórico de versões. Entregas publicadas são documentadas no
[GitHub Releases](https://github.com/regyssilveira/RadIA-Plugin/releases); trabalho executável fica
no [backlog](backlog.md).

## Agora — motor semântico estrutural

O ciclo atual transforma o contexto limitado do editor em compreensão estrutural reproduzível para
Delphi 12 e 13:

1. processo externo supervisionado e perfil efetivo do compilador;
2. lexer, pré-processador e parser tolerante a código incompleto;
3. índice incremental de projeto, grupo, RTL e VCL;
4. navegação, contexto do agente e Ghost Text baseados no mesmo índice;
5. implementação segura de membros ausentes;
6. completion resolvida e diagnóstico pelo `/doctor --deep`.

O motor complementa o CodeInsight e mantém o contexto atual como fallback. Delphi 11, C++, Lazarus
e leitura de DCU estão fora deste ciclo.

## Depois — consolidar a experiência completa

Após o motor semântico estar estável, as prioridades são:

- usar resolução estrutural para Clean Uses, revisão no save e geração de mocks;
- correlacionar stack traces entre units e importar evidências de MadExcept/EurekaLog;
- ampliar modernizações guiadas e reversíveis de aplicações existentes;
- simplificar operação de cache, diagnóstico e manutenção da instalação.

Novas frentes só recebem versão quando possuem escopo, evidência e critérios de conclusão aprovados.
