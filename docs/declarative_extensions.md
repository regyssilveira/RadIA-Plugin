# Extensões declarativas

O RadIA 2.0 pode carregar comandos, templates, skills e aliases seguros de tools sem recompilar o
plugin ou reiniciar o Delphi. Cada extensão é um manifesto `*.radia.json` armazenado em:

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

## Manifesto versão 3

```json
{
  "schemaVersion": 3,
  "id": "TeamWorkflow",
  "version": "3.0.0",
  "enabled": true,
  "permissions": ["chat.prompt", "tool.alias"],
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
      "instructions": "Review this code using the team conventions:\n\n```pascal\n{code}\n```"
    }
  ],
  "tools": [
    {
      "name": "TeamWorkflowProjectHealth",
      "description": "Inspect project health using the team's published name.",
      "targetTool": "GetProjectHealth"
    }
  ]
}
```

Os exemplos completos estão em `Examples/DeclarativeExtension/team-workflow.radia.json` e
`Examples/DeclarativeExtension/team-tools.radia.json`. Manifestos schema 1 e 2 continuam
compatíveis sem migração.

## Campos e validação

| Campo | Regra |
|---|---|
| `schemaVersion` | `1` para comandos, `2` para templates/skills e `3` para aliases de tools. |
| `id` | Identificador PascalCase alfanumérico e exclusivo. |
| `version` | Versão semântica `major.minor.patch`. |
| `enabled` | Opcional; `false` mantém o manifesto instalado, mas inativo. |
| `permissions` | Deve declarar exatamente `chat.prompt` e/ou `tool.alias`, conforme as capacidades presentes. |
| `commands` | Comandos de prompt; usa o campo `prompt`. |
| `templates` | Templates reutilizáveis; usa o campo `prompt` e requer schema 2. |
| `skills` | Instruções especializadas; usa `instructions` e requer schema 2. |
| `tools` | Aliases de tools internas; requer schema 3, `tool.alias`, `name`, `description` e `targetTool`. |
| limite total | Entre 1 e 100 itens somando commands, templates, skills e tools. |
| `command` | `/` seguido de letras, números ou hífens; máximo de 32 caracteres após a barra. |
| `prompt` | Texto não vazio com até 32.768 caracteres. |

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

O gerenciador visual conclui o ciclo local de instalação, atualização, ativação, diagnóstico e
remoção de manifestos.

## Pacote distribuível `.radiaext`

Para distribuir uma extensão como artefato único, gere um pacote:

```powershell
powershell.exe -ExecutionPolicy Bypass `
  -File scripts\New-RadIA.DeclarativeExtensionPackage.ps1 `
  -ManifestPath Examples\DeclarativeExtension\team-commands.radia.json
```

Esse comando gera um pacote versão 1 sem assinatura. Para produzir um pacote versão 2 assinado,
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

O resultado usa a extensão `.radiaext` e contém exatamente:

- `package.json`, com schema, ID, versão e lista fechada de arquivos;
- `<ExtensionId>.radia.json`, com tamanho e SHA-256 registrados nos metadados.

O gerenciador visual aceita o pacote no mesmo botão **Install / Update...**. Antes de ativar, ele
recusa arquivos extras, nomes duplicados, paths com diretórios ou traversal, entradas acima dos
limites, divergência de ID/versão, tamanho incorreto e SHA-256 inválido. A descompressão também
verifica o tamanho declarado no cabeçalho antes de alocar o conteúdo, reduzindo risco de ZIP bomb.
Depois dessa verificação, o manifesto ainda passa por toda a validação e pelo rollback transacional.

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

O arquivo de confiança tem schema versionado, limite de tamanho, validação de IDs e fingerprints,
rejeição de duplicidades e gravação atômica. Reparse points são recusados para evitar redirecionar
leitura ou substituição do arquivo. Assinatura comprova posse da chave privada correspondente, mas
o usuário continua responsável por validar o fingerprint em um canal confiável. Um catálogo remoto
com cadeia de publicação e revogação distribuída continua sendo uma etapa posterior do M4. O
navegador visual assíncrono, o schema, o transporte HTTPS, o download transacional e a verificação
de pacotes estão descritos em [Catálogo remoto de extensões](extension_catalog.md).
