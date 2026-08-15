# Matriz automatizada de testes de uso

A matriz de uso valida o RadIA como produto dentro do Delphi, complementando testes unitários e Web.
Ela é obrigatória para toda release e cobre Delphi 12 Win32, Delphi 13 Win32 e Delphi 13 IDE64.

## Camadas

| Camada | Finalidade | Execução |
|---|---|---|
| Integração headless | Contratos de serviços, tools, consentimento e adapters | DUnitX e Node.js, sem abrir a IDE |
| Integração OTA | Package, catálogo, comandos e estado real da IDE | Instância real e descartável do Delphi |
| Ponta a ponta | Jornada completa percebida pelo usuário | Projeto-fixture, UI, build, testes, debug e shutdown |

O manifesto versionado fica em `Tests/Usage/usage-matrix.json`. Cada cenário declara alvos,
quantidade de ciclos, timeout e evidências obrigatórias. O runner não usa coordenadas absolutas nem
provider real no perfil obrigatório.

## Consultar o plano sem abrir o Delphi

```powershell
powershell.exe -ExecutionPolicy Bypass `
  -File scripts\Test-RadIA.UsageMatrix.ps1 `
  -Profile startup `
  -RequirePackageProvenance `
  -PlanOnly
```

`-PlanOnly` valida o manifesto e retorna JSON com todas as combinações que seriam executadas. Não
inicia, instala ou modifica a IDE.

## Executar durante o desenvolvimento

Feche todas as instâncias do Delphi e execute:

```powershell
powershell.exe -ExecutionPolicy Bypass `
  -File scripts\Test-RadIA.UsageMatrix.ps1 `
  -Profile startup
```

O resultado agregado fica em `Output/Validation/UsageMatrix/usage-matrix.json`. Durante o
desenvolvimento, a evidência informa que a origem está suja e que a proveniência do pacote não foi
exigida; esse resultado não autoriza uma release.

## Gate obrigatório de release

Depois dos builds e packages da mesma revisão limpa, execute:

```powershell
powershell.exe -ExecutionPolicy Bypass `
  -File scripts\Test-RadIA.ReleaseUsage.ps1
```

Esse comando compõe, sem opções para pular os gates principais:

1. geração e build de todos os templates suportados no Delphi 12 e 13;
2. operação visual `2 + 3 = 5` na calculadora VCL;
3. execução dos cinco testes DUnitX da calculadora;
4. criação, abertura e navegação imediata de projeto nos três alvos da IDE;
5. matriz de inicialização e encerramento com proveniência do package.

Se `DEXT_ROOT` não estiver configurado, somente os templates DEXT são registrados como
`not-required`; os demais templates e gates continuam obrigatórios. Quando `DEXT_ROOT` existe, os
servidores e endpoints DEXT também são compilados e executados.

## Evidência e falhas

Artefatos ficam em `Output/Validation/ReleaseUsage` e nunca são publicados como assets da release.
Cada resultado registra alvo, arquitetura, duração, status e cauda sanitizada da saída. Uma falha
preserva evidência parcial e bloqueia a publicação; repetir um cenário não converte a primeira falha
em sucesso.

O perfil `startup` comprova package carregado, contrato de tools válido, shutdown limpo e ausência de
processos órfãos. O perfil `release` também executa contratos críticos independentes da IDE. O
primeiro comprova confirmação explícita da rota por intenção, revisão do comando, continuação no chat
e validação do comando pendente pelo host. Novos comportamentos devem acrescentar cenários ao
manifesto e testes de contrato em `Tests/Web/RadIA.UsageMatrix.test.js`.
