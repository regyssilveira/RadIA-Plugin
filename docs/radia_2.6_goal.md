# Goal 2.6 — ciclo completo de desenvolvimento

> **Estado:** em execução na branch `develop`.
> **Versão-alvo:** 2.6.0.
> **Matriz:** Delphi 12 Win32 e Delphi 13 Win32/IDE64.

## Resultado obrigatório

A versão 2.6.0 somente estará pronta quando o RadIA conseguir receber um prompt sem projeto aberto e,
com consentimento claro do usuário:

1. inferir ou solicitar apenas os requisitos realmente ausentes;
2. apresentar uma prévia revisável e criar o projeto de forma atômica;
3. abrir o projeto criado na IDE;
4. compilar e corrigir erros a partir das mensagens reais do Delphi;
5. iniciar a aplicação pelo depurador da IDE e observar seu estado;
6. exercitar o cenário funcional principal e registrar o resultado;
7. gerar e executar testes DUnitX relevantes;
8. entregar evidências de build, depuração, comportamento e testes, sem declarar sucesso por texto gerado.

O cenário de aceite mínimo é uma calculadora VCL criada a partir de linguagem natural. O fluxo deve
validar as quatro operações, divisão por zero, compilação da aplicação, execução pelo depurador,
interface funcional e suíte DUnitX sem falhas ou vazamentos.

## Marcos internos

Os marcos abaixo pertencem à mesma versão 2.6.0; não representam releases intermediárias.

| Marco | Entrega | Estado |
|---|---|---|
| M0 | Contratos de sessão, segurança, consentimento e evidência | Pendente |
| M1 | Leitura segura de janelas e controles da aplicação depurada | Pendente |
| M2 | Interação segura e cancelável com controles | Pendente |
| M3 | Reprodução, diagnóstico, correção e revalidação de falhas | Pendente |
| M4 | Calculadora por prompt com build, debug, teste visual e DUnitX | Em execução |
| M5 | Conhecimento semântico aprofundado do projeto Delphi | Pendente |
| M6 | Experiência inline unificada e opções progressivamente reveladas | Pendente |
| M7 | SIXEL no terminal integrado | Pendente |
| M8 | Generalização para os templates suportados | Pendente |
| M9 | Doctor profundo, documentação, matriz final e estabilização | Pendente |

O WebView atual permanece inalterado. C++, Lazarus, marketplace, assinatura e instalação comercial
não fazem parte deste goal.

## Evidência já obtida para M4

O template determinístico de calculadora agora contém lógica isolada e uma suíte DUnitX própria.
O teste `scripts/Test-RadIA.GeneratedProjects.ps1` comprova, por alvo:

- inferência do prompt de calculadora;
- criação transacional da aplicação e do projeto de testes;
- compilação de ambos os projetos;
- execução da interface e resultado `2 + 3 = 5`;
- cinco testes DUnitX cobrindo as quatro operações e divisão por zero;
- relatório estruturado para a matriz de evidências.

Essa evidência ainda não encerra M4. Falta executar o mesmo fluxo por uma sessão real do RadIA dentro
da IDE, iniciar pelo depurador e validar a matriz completa de alvos.

## Gates finais da 2.6.0

- builds e DUnitX do RadIA verdes nos três alvos, sem vazamentos;
- teste completo da calculadora iniciado por prompt nos três alvos;
- aplicação criada aberta, compilada e iniciada pelo depurador da IDE;
- cenário visual e testes unitários aprovados com evidências reproduzíveis;
- testes Web, ESLint e testes documentais aprovados;
- SonarQube com Quality Gate aprovado e sem novas issues;
- instalação, atualização, reparo e desinstalação validados no Delphi 12 e 13;
- documentação PT/EN auditada quanto a versão, links, clareza, localização, mojibake e conteúdo obsoleto;
- `develop` integrada à `main` somente depois de todos os gates.

