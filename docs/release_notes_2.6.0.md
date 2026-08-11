# Notas de release — RadIA 2.6.0

> **Estado:** candidata em validação na branch `develop`; ainda não publicada.

O RadIA 2.6.0 fecha o ciclo de criação de uma aplicação Delphi a partir de linguagem natural. O
cenário de aceite cria uma calculadora VCL sem projeto aberto, preserva destino, nome e plataforma,
solicita aprovação antes de alterar arquivos, abre e compila o projeto, executa testes DUnitX e
valida a interface sob o depurador da IDE.

## Principais entregas

- template determinístico de calculadora VCL com lógica isolada;
- projeto DUnitX companion gerado junto da aplicação;
- cinco testes para soma, subtração, multiplicação, divisão e divisão por zero;
- jornada nativa que infere destino, nome, plataforma e especificação do projeto;
- build da aplicação e dos testes pela integração da IDE;
- execução dos testes gerados por `RunDUnitXTests`;
- depuração com sessão correlacionada, breakpoint, pilha e timeline;
- descoberta segura da janela e de 18 controles da calculadora;
- teste funcional consentido que executa `2 + 3 =` e confirma `5` no visor;
- matriz reproduzível para Delphi 12 Win32, Delphi 13 Win32 e Delphi 13 IDE64.
- catálogo operacional sincronizado com as 132 ferramentas registradas.

## Compatibilidade

- Delphi 12 Athens, IDE Win32;
- Delphi 13, IDE Win32;
- Delphi 13, IDE64;
- projetos gerados para Win32 no cenário de aceite.

## Antes de publicar

A candidata somente será liberada depois de todos os gates da
[auditoria 2.6.0](release_audit_2.6.0.md) estarem aprovados sobre uma árvore limpa.
