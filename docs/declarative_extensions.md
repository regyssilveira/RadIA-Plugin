# Extensões declarativas

O RadIA pode carregar comandos, templates, skills, jornadas, políticas, aliases e workflows
seguros de tools sem recompilar o plugin ou reiniciar o Delphi. Cada extensão é um manifesto
`*.radia.json`
armazenado em:

```text
%USERPROFILE%\RadIA\extensions
```

Quando o RadIA utiliza um diretório de dados personalizado, a pasta `extensions` fica dentro dele.
Digite `/extensions reload` para recarregar os arquivos, atualizar o autocomplete e ver o
diagnóstico de cada manifesto. O RadIA também recarrega antes de resolver um comando, portanto um
arquivo adicionado ou removido entra em vigor na própria sessão.

## Gerenciador visual

Abra **Tools > Rad IA Extensions...** para:

- instalar um novo manifesto ou atualizar uma extensão existente;
- habilitar ou desabilitar sem apagar o arquivo;
- recarregar e consultar o diagnóstico de todos os manifestos;
- consultar e revogar publicadores confiáveis;
- remover uma extensão com confirmação explícita.

Instalações, atualizações e mudanças de estado usam gravação atômica. O candidato é validado antes
da ativação e o conjunto completo é recarregado depois da troca. Se houver colisão, manifesto
inválido ou falha de escrita, o RadIA restaura automaticamente a versão anterior. Um chat aberto
atualiza seu catálogo, e chats abertos posteriormente já carregam o novo estado.

### Addon Studio

Use **Addon Studio...** no gerenciador para criar visualmente um comando, skill, alias seguro,
journey ou workflow auditado. O preview valida continuamente a identidade, versão semântica,
namespace, slash command, permissão mínima e JSON dos passos.

Para comandos, skills e journeys, escolha entre **Inline content** e **Content file**; nunca
preencha os dois. **Content file** referencia um arquivo UTF-8 do pacote, por exemplo
`knowledge/team/architecture.md`. **Resources folder** seleciona a raiz local que contém uma ou
mais destas pastas:

- `references`: regras, contratos e documentos consultados pela capacidade;
- `knowledge`: conhecimento compartilhado da equipe ou de um framework;
- `templates`: scaffolds e arquivos estruturais usados pela capacidade;
- `assets`: imagens e artefatos transportados; não podem ser usados diretamente como prompt.

Os botões **Test**, **Install**, **Export...** e **Sign...** usam a mesma pasta selecionada. O teste
instala o pacote em sandbox, e a instalação copia manifesto e recursos como uma única transação.

O botão **Audit** apresenta os limites de execução, a permissão solicitada e a aplicação obrigatória
do consentimento e da auditoria centrais. **Export...** cria um pacote `.radiaext` sem assinatura,
calcula seu SHA-256 e relê o artefato pelo mesmo verificador usado durante a instalação. Se a
verificação falhar, o pacote parcial é removido. Pacotes sem assinatura continuam exigindo
confirmação explícita na instalação.

Use **Sign...** para produzir o pacote assinado sem sair da IDE. O RadIA lista visualmente somente
certificados RSA não expirados que tenham chave privada em `Cert:\CurrentUser\My`, exibindo nome,
validade e thumbprint. Após informar o ID e o nome público do publicador, escolha o destino. O
empacotamento ocorre em background e a chave privada permanece no provedor criptográfico do
Windows. Ao concluir, o RadIA relê o pacote, exige uma assinatura válida e exibe o fingerprint
SHA-256 da chave pública. Se nenhum certificado elegível existir, a tela informa isso sem bloquear
a criação, teste ou exportação sem assinatura.

O instalador entrega o empacotador usado pelo fluxo visual ao lado da BPL, valida seu hash durante
`Install` e `Repair` e o remove durante `Uninstall`.

Antes de instalar, use **Test** para ativar o pacote em um diretório temporário isolado. O teste
executa o parser completo, as regras de permissões, colisões com comandos reservados e o reload
transacional. O relatório mostra quantos comandos, aliases e workflows foram ativados. Nenhuma
extensão instalada é alterada e o diretório temporário é removido ao final. Recursos e
`contentFile` também são verificados. O sandbox valida a
ativação; ele não executa prompts nem ferramentas com efeitos colaterais.

## Manifesto versão 6

```json
{
  "schemaVersion": 6,
  "id": "TeamWorkflow",
  "version": "5.0.0",
  "enabled": true,
  "permissions": ["chat.prompt", "tool.alias", "tool.workflow"],
  "templates": [
    {
      "name": "Team fix plan",
      "description": "Create a fix plan using the team checkpoints.",
      "command": "/team-plan",
      "prompt": "Create a reviewed implementation plan for: {argument}"
    }
  ],
  "skills": [
    {
      "name": "Team Delphi style",
      "description": "Apply the team's Delphi conventions.",
      "command": "/team-style",
      "contentFile": "knowledge/team/delphi-style.md"
    }
  ],
  "journeys": [
    {
      "name": "Team release",
      "description": "Run the team's release gates.",
      "command": "/team-release",
      "objective": "Inspect health, validate targets, review the diff, and prepare a local commit preview."
    }
  ],
  "policies": [
    {
      "name": "Team architecture",
      "description": "Review using the shared architecture policy.",
      "command": "/team-architecture",
      "instructions": "Review API stability, ownership, thread safety, testability, and Delphi compatibility."
    }
  ],
  "tools": [
    {
      "name": "TeamWorkflowProjectHealth",
      "description": "Inspect project health using the team's published name.",
      "targetTool": "GetProjectHealth"
    }
  ],
  "workflows": [
    {
      "name": "TeamWorkflowInspection",
      "description": "Collect the IDE and project state through audited tools.",
      "steps": [
        {"tool": "GetIDEState", "arguments": {}},
        {"tool": "GetActiveProject", "arguments": {}}
      ]
    }
  ]
}
```

Os exemplos completos estão em `Examples/DeclarativeExtension/team-workflow.radia.json`,
`Examples/DeclarativeExtension/team-tools.radia.json` e
`Examples/DeclarativeExtension/team-journeys.radia.json`. O workflow completo está em
`Examples/DeclarativeExtension/team-tool-workflow.radia.json`. O pacote com conhecimento externo
usa `Examples/DeclarativeExtension/team-knowledge.radia.json` e a raiz
`Examples/DeclarativeExtension/team-knowledge-resources`. Manifestos schema 1–5 continuam
compatíveis sem migração.

## Campos e validação

| Campo | Regra |
|---|---|
| `schemaVersion` | `1` comandos, `2` templates/skills, `3` aliases, `4` jornadas/políticas, `5` workflows e `6` conteúdo em arquivos. |
| `id` | Identificador PascalCase alfanumérico e exclusivo. |
| `version` | Versão semântica `major.minor.patch`. |
| `enabled` | Opcional; `false` mantém o manifesto instalado, mas inativo. |
| `permissions` | Deve declarar exatamente `chat.prompt`, `tool.alias` e/ou `tool.workflow`, conforme as capacidades. |
| `commands` | Comandos de prompt; usa o campo `prompt`. |
| `templates` | Templates reutilizáveis; usa o campo `prompt` e requer schema 2. |
| `skills` | Instruções especializadas; usa `instructions` e requer schema 2. |
| `journeys` | Receitas agentivas; usa `objective`, ativa o Agent Runtime e requer schema 4. |
| `policies` | Políticas explícitas de prompt; usa `instructions` e requer schema 4. |
| `tools` | Aliases de tools internas; requer schema 3, `tool.alias`, `name`, `description` e `targetTool`. |
| `workflows` | Sequência de 1–16 tools internas com argumentos JSON fixos; requer schema 5 e `tool.workflow`. |
| `contentFile` | Alternativa aos campos inline; requer schema 6 e caminho em `references/`, `templates/` ou `knowledge/`. |
| limite total | Entre 1 e 100 itens somando todas as capacidades. |
| `command` | `/` seguido de letras, números ou hífens; máximo de 32 caracteres após a barra. |
| conteúdo | Campo inline ou `contentFile` UTF-8, nunca ambos; resultado limitado a 32.768 bytes/caracteres. |

Comandos internos, templates do usuário e comandos de outra extensão não podem ser substituídos.
Arquivos inválidos não carregam parcialmente: o diagnóstico indica `loaded`, `disabled` ou
`rejected`, preservando o catálogo anterior às entradas daquele arquivo.

## Variáveis de prompt

- `{code}`: seleção ativa; quando vazia, usa a unit ativa.
- `{argument}`: texto digitado após o comando.
- `{specification}` e `{stacktrace}`: aliases compatíveis com os templates internos.

## Tools declarativas e limites de segurança

A extensão declarativa somente expande um prompt ou instrução quando o usuário escolhe ou digita
seu comando. O schema 3 também pode publicar um alias para uma tool interna já registrada. O alias:

- deve iniciar com o `id` da extensão, evitando apropriação do namespace global;
- não pode apontar para outro alias declarativo, impedindo cadeias e ciclos;
- herda schema de entrada/saída, risco, timeout e idempotência da tool de destino;
- passa pela mesma política central de consentimento e auditoria usada pelo chat e MCP;
- é removido imediatamente quando a extensão é desabilitada, removida ou recarregada;
- não executa scripts ou binários arbitrários e não amplia as permissões da tool de destino.

Targets inexistentes, colisões ou falhas de registro produzem o diagnóstico `runtime-rejected` e
preservam o conjunto anterior de aliases. Tools avançadas com implementação própria continuam
disponíveis pela API BPL descrita no [guia de extensões](tool_extension_guide.md).

## Workflows declarativos

Um workflow schema 5 registra uma nova tool no namespace da extensão. Ele não executa texto como
código: cada etapa referencia uma tool interna existente e um objeto JSON fixo de argumentos.

- o nome deve começar com o `id` da extensão;
- são permitidas de 1 a 16 etapas;
- aliases e workflows declarativos não podem ser targets, impedindo cadeias e ciclos;
- o risco visível do workflow é o maior risco entre as etapas;
- timeout e idempotência são derivados dos descritores reais;
- cada etapa volta a passar pelo policy executor, consentimento e auditoria centrais;
- a primeira falha interrompe o restante, e resultados agregados são limitados a 1 MiB UTF-16;
- cancelamento, sessão, projeto, origem e escopo são propagados para todas as etapas.

Assim, equipes podem publicar automações repetíveis sem conceder acesso a shell, PowerShell,
executáveis ou uma segunda política de permissões.

A matriz funcional versionada está em
[`declarative_workflow_smoke_evidence_2.0.0.json`](declarative_workflow_smoke_evidence_2.0.0.json).
Ela comprova hot-load, registro no catálogo compartilhado e execução auditada de duas etapas no
Delphi 12 Win32, Delphi 13 Win32 e Delphi 13 IDE64.

## Jornadas, políticas e credenciais

Uma entrada de `journeys` inicia uma execução real no Agent Runtime. O RadIA acrescenta ao objetivo
os gates obrigatórios de inspeção, plano revisável, consentimento central, auditoria, preview,
rollback, build e testes. A receita compartilhada não consegue conceder permissões adicionais nem
desativar esses gates.

Uma entrada de `policies` expande as instruções somente quando o usuário escolhe seu comando.
Argumentos opcionais são limitados a 4.000 caracteres. O schema 4 rejeita, em qualquer nível,
campos chamados `apiKey`, `credential`, `password`, `secret` ou `token`. Credenciais continuam nas
configurações protegidas de cada instalação e nunca devem fazer parte de manifestos ou pacotes.

O gerenciador visual conclui o ciclo local de instalação, atualização, ativação, diagnóstico e
remoção de manifestos.

## Pacote distribuível `.radiaext`

Para distribuir uma extensão como artefato único, gere um pacote:

```powershell
powershell.exe -ExecutionPolicy Bypass `
  -File scripts\New-RadIA.DeclarativeExtensionPackage.ps1 `
  -ManifestPath Examples\DeclarativeExtension\team-commands.radia.json
```

O empacotador aceita manifestos dos schemas 1 a 6, inclusive aliases, jornadas, políticas e
workflows auditados.

Para incluir recursos, informe a raiz que contém as pastas permitidas:

```powershell
powershell.exe -ExecutionPolicy Bypass `
  -File scripts\New-RadIA.DeclarativeExtensionPackage.ps1 `
  -ManifestPath .\TeamKnowledge.radia.json `
  -ResourcesPath .\extension-content
```

O mesmo parâmetro pode ser combinado com a assinatura. No Addon Studio, use **Resources folder**;
não é necessário executar o script manualmente.

Sem recursos, esse comando gera um pacote versão 1 sem assinatura. Para produzir um pacote versão
2 assinado,
use um certificado RSA de pelo menos 2.048 bits, com chave privada disponível em
`Cert:\CurrentUser\My`:

```powershell
powershell.exe -ExecutionPolicy Bypass `
  -File scripts\New-RadIA.DeclarativeExtensionPackage.ps1 `
  -ManifestPath Examples\DeclarativeExtension\team-commands.radia.json `
  -SigningCertificateThumbprint "THUMBPRINT_DO_CERTIFICADO" `
  -PublisherId "empresa.produto" `
  -PublisherName "Nome verificável do publicador"
```

O script não exporta nem grava a chave privada: a assinatura RSA-SHA256 é produzida diretamente pelo
provedor criptográfico do Windows. O terminal exibe o fingerprint SHA-256 da chave pública; o
publicador deve divulgá-lo por um canal independente para que o usuário possa compará-lo.

O resultado usa a extensão `.radiaext` e contém uma lista fechada formada por:

- `package.json`, com schema, ID, versão e lista fechada de arquivos;
- `<ExtensionId>.radia.json`, com tamanho e SHA-256 registrados nos metadados;
- opcionalmente até 128 recursos sob `references/`, `templates/`, `knowledge/` ou `assets/`.

Pacotes sem recursos usam envelope v1 quando não assinados e v2 quando assinados. Pacotes com
recursos usam envelope v3, assinado ou não; quando há assinatura, ela cobre também caminho,
tamanho e SHA-256 de cada arquivo. Cada entrada pode ter até 1 MiB, o total descompactado é limitado
a 16 MiB, o arquivo ZIP é limitado a 20 MiB e os paths declarados têm no máximo 240 caracteres.

O gerenciador visual aceita o pacote no mesmo botão **Install / Update...**. Antes de ativar, ele
recusa arquivos extras, nomes duplicados, paths fora das quatro raízes permitidas ou com traversal,
reparse points, entradas acima dos limites, divergência de ID/versão, tamanho incorreto e SHA-256
inválido. A descompressão também
verifica o tamanho declarado no cabeçalho antes de alocar o conteúdo, reduzindo risco de ZIP bomb.
Depois dessa verificação, o manifesto e seus recursos passam pela ativação transacional. Atualizar
substitui integralmente o conjunto anterior, removendo recursos obsoletos. Se o novo manifesto não
conseguir carregar seu `contentFile` ou qualquer validação falhar, o RadIA restaura o manifesto e
os recursos anteriores. Remover a extensão também remove sua pasta em `.resources/<ExtensionId>`.

### Integridade e identidade

SHA-256 comprova que o conteúdo recebido corresponde aos metadados do pacote, mas não identifica
quem o publicou. Portanto, `.radiaext` versão 1 não deve ser descrito como “assinado”. Na instalação,
o RadIA mostra um aviso explícito e permite somente aquela instalação, sem criar confiança
persistente.

O pacote versão 2 assina schema, identidade e versão da extensão, nome e hash do manifesto e
identidade, nome e chave RSA do publicador. O RadIA valida a assinatura com Windows CNG antes de
mostrar qualquer consentimento. Na primeira instalação, exibe nome, ID e fingerprint SHA-256 da
chave. Se o usuário confirmar, a confiança é persistida em:

```text
%USERPROFILE%\RadIA\trusted-extension-publishers.json
```

Instalações posteriores do mesmo ID e da mesma chave são reconhecidas automaticamente. A troca de
chave para um ID já conhecido produz um alerta destacado e exige nova decisão. Use
**Tools > Rad IA Extensions... > Trusted publishers...** para consultar fingerprints e revogar
confiança. A revogação impede novas instalações; ela não remove extensões que já foram instaladas.

No envelope v3, a mesma identidade RSA pode assinar pacotes com recursos; todos os arquivos entram
no payload assinado. Um pacote v3 sem publicador continua oferecendo integridade, mas exige a mesma
confirmação explícita aplicada ao envelope v1.

O arquivo de confiança tem schema versionado, limite de tamanho, validação de IDs e fingerprints,
rejeição de duplicidades e gravação atômica. Reparse points são recusados para evitar redirecionar
leitura ou substituição do arquivo. Assinatura comprova posse da chave privada correspondente, mas
o usuário continua responsável por validar o fingerprint em um canal confiável. Um catálogo remoto
com cadeia de publicação e revogação distribuída continua sendo uma etapa posterior do M4. O
navegador visual assíncrono, o schema, o transporte HTTPS, o download transacional e a verificação
de pacotes estão descritos em [Catálogo remoto de extensões](extension_catalog.md).
