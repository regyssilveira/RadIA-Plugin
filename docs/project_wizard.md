# New Project Wizard determinístico

O New Project Wizard do RadIA executa a criação como uma operação em duas fases:

1. gerar e revisar um manifesto determinístico, sem modificar o disco;
2. após aprovação, materializar em staging e publicar a pasta como uma transação.

## Templates

O engine atual possui templates para:

- Console;
- VCL;
- FireMonkey;
- Library;
- Package;
- DUnitX;
- Windows Service.

Cada solicitação contém nome Pascal válido, versão Delphi (`23.0` ou `37.0`) e plataformas
Windows (`Win32`, `Win64` ou ambas). A ordem, caixa e repetição das plataformas são normalizadas.
Para a mesma solicitação, paths, conteúdo, hashes, ID do template e GUID do projeto são idênticos.

## Preview

O preview JSON contém:

- versão do schema;
- ID canônico do template;
- nome e tipo do projeto;
- versão Delphi;
- plataformas;
- path, tamanho UTF-8 e SHA-256 de cada arquivo.

O preview não inclui o conteúdo dos arquivos. A tela `RadIA New Project...`, disponível no menu
Tools/Ferramentas, apresenta esse manifesto antes de habilitar a criação.

## Uso visual sem projeto aberto

1. Abra `Tools > RadIA New Project...`.
2. Informe nome, template, versão Delphi e plataformas.
3. Use `Browse...` para escolher a raiz autorizada.
4. Clique em `Preview` e revise o manifesto.
5. Clique em `Create & Open`.

O campo da raiz é somente leitura: digitar ou receber um path da IA não concede autorização.
Qualquer mudança nas opções invalida o preview anterior. O commit materializa exatamente o
manifesto revisado e abre o `.dproj`; se a abertura falhar, o projeto criado é revertido.

## Tools do Agent Runtime e MCP

O fluxo transacional está disponível no mesmo registro protegido usado pelo modo agente e pelo MCP:

- `PreviewProjectTemplate` valida a solicitação e retorna o manifesto e um `previewId`, sem escrever no disco;
- `CreateProjectFromTemplate` recebe somente o `previewId`, exige consentimento para escrita estrutural e
  publica exatamente o projeto revisado;
- `RevertCreatedProject` recebe o mesmo `previewId` e remove o projeto criado pela transação.
- `OpenCreatedProject` abre o `.dproj` confirmado na thread principal da IDE.
- `ValidateCreatedProject` abre e compila o projeto; em falha, fecha os módulos e executa rollback.

Todas passam pelo executor de políticas, portanto geram auditoria, respeitam consentimento e herdam os
limites de execução. O destino das tools precisa estar dentro da raiz do projeto ativo. A capacidade
de autorizar uma raiz sem projeto aberto é separada e acessível somente pela tela visual após
seleção explícita do usuário.

## Transação de filesystem

Depois da aprovação, os arquivos são gravados em uma pasta irmã temporária com sufixo
`.radia-stage-<GUID>`. A pasta de destino continua intacta e vazia durante essa fase.

O commit usa rename da pasta de staging para o destino. Se uma validação posterior falhar, rollback
remove integralmente o projeto publicado e restaura a pasta vazia quando ela já existia. Destruir
uma transação apenas preparada também remove o staging.

Destinos não vazios, raízes de filesystem, arquivos existentes e paths que escapem do staging são
recusados.

## Estado de integração

Engine, preview, transação, tela visual, opções e seleção autorizada sem projeto ativo estão
implementados. A concessão visual não amplia a autorização das tools.

Além dos testes unitários, `scripts/Test-RadIA.GeneratedProjects.ps1` gera os sete tipos usando o
engine real e compila cada `.dproj`. A matriz vigente abrange Delphi 12 e 13.
