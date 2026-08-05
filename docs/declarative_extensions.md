# Extensões declarativas

O RadIA 2.0 pode carregar comandos de chat sem recompilar o plugin ou reiniciar o Delphi. Cada
extensão é um manifesto `*.radia.json` armazenado em:

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

## Manifesto versão 1

```json
{
  "schemaVersion": 1,
  "id": "TeamCommands",
  "version": "1.0.0",
  "enabled": true,
  "permissions": ["chat.prompt"],
  "commands": [
    {
      "name": "Team review",
      "description": "Review selected Delphi code using the team policy.",
      "command": "/team-review",
      "prompt": "Review this Delphi code:\n\n```pascal\n{code}\n```"
    }
  ]
}
```

O exemplo completo está em `Examples/DeclarativeExtension`.

## Campos e validação

| Campo | Regra |
|---|---|
| `schemaVersion` | Deve ser `1`. |
| `id` | Identificador PascalCase alfanumérico e exclusivo. |
| `version` | Versão semântica `major.minor.patch`. |
| `enabled` | Opcional; `false` mantém o manifesto instalado, mas inativo. |
| `permissions` | Nesta versão deve conter somente `chat.prompt`. |
| `commands` | Entre 1 e 100 comandos; o manifesto é rejeitado atomicamente se um for inválido. |
| `command` | `/` seguido de letras, números ou hífens; máximo de 32 caracteres após a barra. |
| `prompt` | Texto não vazio com até 32.768 caracteres. |

Comandos internos, templates do usuário e comandos de outra extensão não podem ser substituídos.
Arquivos inválidos não carregam parcialmente: o diagnóstico indica `loaded`, `disabled` ou
`rejected`, preservando o catálogo anterior às entradas daquele arquivo.

## Variáveis de prompt

- `{code}`: seleção ativa; quando vazia, usa a unit ativa.
- `{argument}`: texto digitado após o comando.
- `{specification}` e `{stacktrace}`: aliases compatíveis com os templates internos.

## Limites de segurança

A extensão declarativa versão 1 somente expande um prompt quando o usuário escolhe ou digita seu
comando. Ela não executa scripts, tools, processos, escrita ou operações da OTA. Permissões
adicionais são recusadas. Tools avançadas continuam disponíveis pela API BPL descrita no
[guia de extensões](tool_extension_guide.md) e passam pela política central de risco e consentimento.

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
com cadeia de publicação e revogação distribuída continua sendo uma etapa posterior do M4. A
fundação segura de schema, HTTPS, download transacional e verificação de pacotes está descrita em
[Catálogo remoto de extensões](extension_catalog.md); o navegador visual ainda está em integração.
