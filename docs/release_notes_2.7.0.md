# Notas de release - RadIA 2.7.0

> **Estado:** liberada em 11 de agosto de 2026.

RadIA 2.7.0 fecha uma baseline funcional determinística para a experiência completa no Delphi 12 e
13. A release não substitui o WebView, não inclui C++ ou Lazarus e não adiciona instalação comercial.
O catálogo desta versão documenta 132 ferramentas internas.

## Criação de projetos

- prompts naturais em português e inglês inferem Console, VCL, FMX, Library, Package, DUnitX e
  Windows Service;
- dados ausentes continuam sendo coletados antes do preview e do consentimento;
- a matriz preserva a geração e compilação dos 11 projetos certificados e os cinco testes da
  calculadora VCL.

## Code, Design e revisão

- intenções de layout, propriedades, inspeção e componentes ativam Design;
- intenções de código, eventos, debug e testes ativam Code;
- navegação inválida falha de forma estruturada e o cancelamento não executa a ação;
- a revisão por bloco permite solicitar alterações com comentário pelo gutter, menu ou tool;
- o comentário não modifica o buffer, permanece consultável e bloqueia Apply até ser resolvido.

## Evidência

A [auditoria da release](release_audit_2.7.0.md) registra os requisitos aprovados e as matrizes
reproduzíveis para Delphi 12 Win32, Delphi 13 Win32 e Delphi 13 IDE64.
