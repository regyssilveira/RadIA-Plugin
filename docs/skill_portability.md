# Publicar uma skill nos CLIs

O RadIA mantém a extensão declarativa como fonte original e publica a mesma skill nos formatos de
projeto reconhecidos por Codex, Claude Code, Gemini CLI e GitHub Copilot CLI.

## Como abrir

1. Abra ou crie um projeto Delphi.
2. Acesse **Tools > Rad IA Extensions... > Addon Studio...**.
3. Escolha **Skill**, preencha ID, nome, descrição e instruções ou um `contentFile` válido.
4. Clique em **Publish skill to CLIs...**.

O botão aparece somente para skills. Seu hint explica que os paths serão apresentados e que haverá
consentimento antes da gravação.

## Preview e destinos

| CLI | Diretório no projeto |
|---|---|
| Codex | `.agents/skills/<skill>/SKILL.md` |
| Claude Code | `.claude/skills/<skill>/SKILL.md` |
| Gemini CLI | `.gemini/skills/<skill>/SKILL.md` |
| GitHub Copilot CLI | `.github/skills/<skill>/SKILL.md` |

Marque os destinos desejados. O preview mostra o path absoluto e um estado:

- `create`: arquivo novo;
- `update`: arquivo ainda corresponde ao último hash criado pelo RadIA;
- `unchanged`: conteúdo já é o esperado;
- `conflict`: arquivo existe, mas não corresponde a uma réplica controlada pelo RadIA.

Um conflito bloqueia a publicação completa. O RadIA nunca sobrescreve silenciosamente conteúdo
criado ou modificado pelo usuário.

## Consentimento, sincronização e remoção

**Publish** solicita consentimento central para a operação estrutural `PublishCliSkill`, indicando
origem, projeto e executores. Os arquivos usam troca atômica e rollback. O manifesto
`.radia/skill-replicas.json` guarda somente extension ID, executor, path e SHA-256; não armazena
prompts, credenciais ou tokens.

Para sincronizar uma alteração, abra novamente a skill e publique os destinos. A mudança é detectada
sem reiniciar o Delphi. **Remove replicas** também exige consentimento e remove somente arquivos que
ainda correspondem aos hashes registrados. Arquivos modificados são preservados.

## Recuperação

| Mensagem | Ação |
|---|---|
| Open or create a project | Abra um `.dproj`; os destinos são relativos ao projeto ativo. |
| Select at least one CLI destination | Marque pelo menos um executor. |
| conflict | Compare o arquivo; renomeie-o ou incorpore manualmente as diferenças. |
| Publishing was not authorized | Repita e autorize a operação no diálogo central. |
| content file was not found | Corrija **Resources folder** e **Content file**. |

Para criar e empacotar a fonte canônica, consulte [Extensões declarativas](declarative_extensions.md).
