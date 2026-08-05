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

Esta é a primeira entrega do M4. Instalação visual, assinatura de pacotes, atualização e remoção
guiadas ainda fazem parte das próximas etapas do gerenciador de extensões.
