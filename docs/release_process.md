# Processo de Finalização de Release

Este documento descreve o fluxo recomendado para finalizar uma release do **Rad IA** com `develop`,
`main` e tags sincronizadas.

> [!IMPORTANT]
> A tag deve ser criada somente depois que `main` estiver atualizado com o mesmo commit validado em `develop`.

---

## 1. Conferir Estado Inicial

Antes de preparar a release, confirme que a branch de trabalho está limpa e sincronizada:

```powershell
git status --short --branch
git fetch --all --tags
git tag --sort=-v:refname
```

Use a última tag publicada para definir a próxima versão. Exemplo: se a última tag for `v0.0.17`, a
próxima release será `v0.0.18`.

Branches de trabalho devem seguir a [Convenção de Nomes de Branch](branch_convention.md).

---

## 2. Atualizar Versão e Documentação

Atualize todos os pontos públicos e técnicos que exibem a versão da release:

* `RadIA.rc`: `FILEVERSION`, `PRODUCTVERSION`, `FileVersion` e `ProductVersion`.
* `Source/Integration/RadIA.OTA.Register.pas`: versão exibida no About da IDE.
* `package.json`: campo `version`.
* `README.md` e `README.en.md`: resumo das funcionalidades relevantes.
* `docs/features.md` e `docs/features.en.md`: catálogo de recursos.
* `docs/backlog.md` e `docs/backlog.en.md`: histórico técnico da release.
* `docs/roadmap.md` e `docs/roadmap.en.md`: valor entregue na release.

As entradas de backlog e roadmap devem ser adicionadas acima da última versão publicada, mantendo a ordem decrescente.

---

## 3. Validar Build e Frontend

Execute as validações antes de qualquer merge:

```powershell
npx eslint
powershell.exe -ExecutionPolicy Bypass -File build.ps1 -DelphiVersion "23.0"
```

Quando houver necessidade de validar testes unitários:

```powershell
powershell.exe -ExecutionPolicy Bypass -File build.ps1 -DelphiVersion "23.0" -Test
```

Execute também a análise e aguarde o resultado do Quality Gate da análise exata:

```powershell
powershell.exe -ExecutionPolicy Bypass -File run-sonar-analysis.ps1 `
  -Test `
  -DelphiVersion "37.0" `
  -QualityGate
```

O comando termina com erro se o processamento do SonarQube falhar, exceder o timeout ou se qualquer
condição do Quality Gate estiver reprovada. Não prepare merge, tag ou pacote de release nesse estado.

O workflow `SonarQube release gate` repete essa barreira em pull requests para `develop` e `main`, nos
pushes dessas branches e em toda tag `v*`. O runner Windows self-hosted deve possuir o label
`radia-delphi`, Delphi 13 e `sonar-scanner`; configure `SONAR_TOKEN` como secret e `SONAR_HOST_URL`
como variável do repositório. Configure o job como status check obrigatório nas regras de proteção de
`develop` e `main`.

Warnings conhecidos podem ser aceitos somente quando não correspondem a uma condição reprovada do
Quality Gate e devem ser citados no resumo final.

---

## 4. Commitar e Publicar a Branch de Trabalho

Com as validações concluídas, crie o commit de preparação da release e publique a branch:

```powershell
git add README.md README.en.md RadIA.rc package.json docs
git add Source/Integration/RadIA.OTA.Register.pas
git commit -m "chore: Prepare v0.0.18 release"
git push origin <branch-de-trabalho>
```

Ajuste a mensagem e a versão conforme a release real. Mensagens de commit devem seguir a
[Convenção de Mensagens de Commit](commit_convention.md).

---

## 5. Merge em Develop

Atualize `develop` a partir da branch de trabalho:

```powershell
git checkout develop
git pull --ff-only origin develop
git merge --ff-only <branch-de-trabalho>
git push origin develop
```

Se o fast-forward não for possível, investigue antes de continuar. Não crie tag enquanto `develop` e
a branch de trabalho estiverem divergentes.

---

## 6. Merge de Develop em Main

Depois de `develop` publicado, avance `main`:

```powershell
git checkout main
git pull --ff-only origin main
git merge --ff-only develop
git push origin main
```

Neste ponto, `main`, `develop` e a branch de trabalho devem apontar para o mesmo commit de release.

---

## 7. Criar e Publicar a Tag

Crie uma tag anotada a partir de `main`:

```powershell
git tag -a v0.0.18 -m "v0.0.18"
git push origin v0.0.18
```

Confirme o resultado:

```powershell
git status --short --branch
git log --oneline --decorate -5
git ls-remote --tags origin v0.0.18
```

---

## 8. Limpar Branch de Trabalho

Somente remova a branch de trabalho quando ela estiver mergeada e sincronizada local/remoto:

```powershell
git merge-base --is-ancestor <branch-de-trabalho> develop
git merge-base --is-ancestor <branch-de-trabalho> main
git branch -d <branch-de-trabalho>
git push origin --delete <branch-de-trabalho>
git checkout develop
```

---

## Evidência reproduzível dos pacotes

Cada pacote registra no `manifest.json` o `sourceCommit` Git de 40 caracteres e
`sourceDirty: false`. O build com `-Package` falha se houver alteração rastreada ainda não
commitada. Isso impede atribuir um artefato a um commit diferente do código empacotado.

Depois de gerar os três ZIPs, execute:

```powershell
powershell.exe -ExecutionPolicy Bypass `
  -File scripts\New-RadIA.ReleaseEvidence.ps1
```

O comando exige os três pacotes da versão declarada em `package.json`, expande e valida cada um,
confirma versão, configuração, plataforma, commit comum e árvore limpa, calcula hashes SHA-256
independentes e grava `Output\ReleaseEvidence.json`.

## Evidência do smoke na IDE

Execute cada smoke com `-EvidencePath` para vincular os ciclos reais ao ZIP publicado, ao
`sourceCommit` e à BPL instalada:

```powershell
powershell.exe -ExecutionPolicy Bypass `
  -File scripts\Test-RadIA.IDESmoke.ps1 `
  -DelphiVersion "37.0" `
  -Cycles 10 `
  -ExerciseDocking `
  -ExercisePackageLifecycle `
  -UpgradeFromPackagePath `
    "Output\Packages\RadIA-v1.0.0-Delphi-37.0-Win32-Release.zip" `
  -EvidencePath "Output\Validation\Delphi13-Win32.json"
```

Acrescente `-IDE64` para o Delphi 13 IDE64. A geração da evidência é *fail-closed*: o comando
recusa `-SkipPackageHashCheck`, pacote ausente, hash divergente, árvore suja no manifesto ou BPL
instalada diferente da BPL contida no ZIP comprovado. Feche todas as instâncias da IDE antes da
instalação e do smoke; o script também recusa executar quando o target já está aberto.

`-ExercisePackageLifecycle` executa `Uninstall`, `Install` e `Repair` a partir do ZIP comprovado
antes de cada abertura da IDE, preservando os dados do usuário. O ciclo só prossegue quando o
instalador valida novamente manifesto, hashes, registro, BPL, DCP, bridge e assets Web.

`-UpgradeFromPackagePath` acrescenta uma migração real entre versões. O smoke valida o pacote de
origem, instala a versão anterior, aplica o ZIP atual, executa o reparo e registra versão e SHA-256
de origem na evidência. O parâmetro exige `-ExercisePackageLifecycle`.

O resumo versionado da matriz 2.0.0 está em `ide_smoke_evidence_2.0.0.json`. Ele registra os hashes
dos ZIPs e BPLs, os 10 ciclos aprovados por target, a faixa de duração, o catálogo de 130 tools,
docking nativo, restauração do desktop e ausência de processos órfãos.

Depois de gerar os três arquivos em `Output\Validation`, consolide a prova oficial com:

```powershell
powershell.exe -ExecutionPolicy Bypass `
  -File scripts\New-RadIA.IDESmokeEvidence.ps1
```

O consolidador falha se qualquer target, ciclo, upgrade, modo do lifecycle, hash, commit, docking ou
contagem de tools divergir dos pacotes e da evidência de release. O JSON versionado nunca deve ser
montado ou ajustado manualmente.

### Jornada contínua de desenvolvimento

Use `Test-RadIA.KnowledgeNotifierSmoke.ps1` para comprovar, em um projeto descartável, criação,
Designer, edição, falha e correção de compilação, testes, breakpoint, call stack, timeline, revisão
Git e encerramento da IDE. Execute o comando com `23.0`, `37.0` e novamente com `37.0 -IDE64`,
sempre com a árvore rastreada limpa e um `EvidencePath` diferente:

```powershell
powershell.exe -ExecutionPolicy Bypass `
  -File scripts\Test-RadIA.KnowledgeNotifierSmoke.ps1 `
  -DelphiVersion "23.0" `
  -ExerciseDebugger `
  -ExerciseCorrection `
  -ExerciseGit `
  -EvidencePath `
    "Output\Validation\ContinuousJourney\Delphi12-Win32.json"
```

O debugger usa o projeto VCL criado na própria jornada, preparado no workspace descartável para
terminar naturalmente. Depois de inspecionar o breakpoint, o smoke o remove, usa
`ContinueDebugging`, aceita a transição assíncrona inicial da OTA e exige que a IDE retorne ao estado
sem processo dentro do limite antes de continuar com os
testes e a revisão Git. Em caso de falha, ele tenta fechar normalmente a IDE
descartável e, após o timeout configurado, encerra somente a instância que ele próprio iniciou. Isso
evita deixar uma sessão em `[Stopping]` e preserva a falha original para diagnóstico.

### Gate integrado de encerramento

Depois da jornada contínua, execute dez ciclos no mesmo commit limpo para cada target. O smoke deve
ativar terminal, completion inline, revisão por bloco e retomada persistida do agente:

```powershell
powershell.exe -ExecutionPolicy Bypass `
  -File scripts\Test-RadIA.IDESmoke.ps1 `
  -DelphiVersion "23.0" `
  -Cycles 10 `
  -ExerciseTerminal `
  -ExerciseInlineCompletion `
  -ExerciseInlineReview `
  -ExerciseAgentRuntime `
  -EvidencePath "Output\Validation\LeadershipClosure\Delphi12-Win32.json"
```

Repita com `37.0` para Win32 e com `37.0 -IDE64`, alterando o nome da evidência. Em seguida, execute
o servidor MCP real somente após consentimento explícito e consolide a matriz:

```powershell
powershell.exe -ExecutionPolicy Bypass `
  -File scripts\Test-RadIA.ExternalMcpRealServer.ps1 `
  -Consent `
  -EvidencePath `
    "docs\competitive_gap_phase_6_real_server_evidence_2.3.1.json"

powershell.exe -ExecutionPolicy Bypass `
  -File scripts\New-RadIA.LeadershipClosureEvidence.ps1
```

O consolidador falha se as três jornadas, os 30 ciclos ou o MCP autorizado não pertencerem à mesma
versão e ao mesmo commit limpo. Ele também exige build, testes, debugger, Git, terminal, FIM, revisão
no gutter, persistência do agente e encerramento sem processos descendentes em todos os targets.
O aceite visual ativa o `TEditControl`, solicita seu repaint nativo e somente passa quando o callback
OTA real confirma que a completion e as revisões chegaram ao ciclo de pintura.

### Evidência visual do terminal

Use `-TerminalEvidencePath` com `-ExerciseTerminal` para abrir a superfície VCL real e validar
geometria, controles essenciais, perfis, paleta de comandos, entrada, saída e navegação por Tab:

```powershell
powershell.exe -ExecutionPolicy Bypass `
  -File scripts\Test-RadIA.IDESmoke.ps1 `
  -DelphiVersion "37.0" `
  -Cycles 1 `
  -ExerciseTerminal `
  -SkipPackageHashCheck `
  -TerminalEvidencePath "Output\Validation\Terminal\Delphi13-Win32.json"
```

Depois dos três targets suportados, consolide a matriz fail-closed:

```powershell
powershell.exe -ExecutionPolicy Bypass `
  -File scripts\New-RadIA.TerminalEvidence.ps1
```

O resultado versionado fica em `terminal_smoke_evidence_2.0.0.json`.

### Evidência visual do Ghost Text

Use `-InlineCompletionEvidencePath` com `-ExerciseInlineCompletion` para comprovar separadamente a
captura de uma unit real, a preparação local e a pintura OTA. Essa evidência exige fonte rastreada
limpa, mas pode usar `-SkipPackageHashCheck`, pois não substitui a proveniência do pacote:

```powershell
powershell.exe -ExecutionPolicy Bypass `
  -File scripts\Test-RadIA.IDESmoke.ps1 `
  -DelphiVersion "37.0" `
  -Cycles 1 `
  -ExerciseInlineCompletion `
  -SkipPackageHashCheck `
  -InlineCompletionEvidencePath `
    "Output\Validation\InlineCompletion\Delphi13-Win32.json"
```

Depois dos três targets suportados, consolide a matriz visual fail-closed:

```powershell
powershell.exe -ExecutionPolicy Bypass `
  -File scripts\New-RadIA.InlineCompletionEvidence.ps1
```

O resultado versionado atual fica em `inline_completion_smoke_evidence_2.3.1.json`. Além da
preparação e pintura, cada target deve comprovar preview sem escrita, aceite real, restauração por
um único undo e rejeição sem alterar o buffer. A evidência registra somente flags, hashes e nomes de
arquivo, nunca o conteúdo do código ou da sugestão.

### Evidência visual da revisão inline

Use `-InlineReviewEvidencePath` com `-ExerciseInlineReview` para comprovar, em uma unit real,
publicação pelo MCP, pintura OTA, correspondência da revisão, rejeição e bloqueio de uma revisão
obsoleta:

```powershell
powershell.exe -ExecutionPolicy Bypass `
  -File scripts\Test-RadIA.IDESmoke.ps1 `
  -DelphiVersion "37.0" `
  -Cycles 1 `
  -ExerciseInlineReview `
  -SkipPackageHashCheck `
  -InlineReviewEvidencePath `
    "Output\Validation\InlineReview\Delphi13-Win32.json"
```

Execute o smoke para Delphi 12 Win32, Delphi 13 Win32 e Delphi 13 IDE64. Depois, consolide a
matriz fail-closed:

```powershell
powershell.exe -ExecutionPolicy Bypass `
  -File scripts\New-RadIA.InlineReviewEvidence.ps1
```

O resultado versionado fica em `inline_review_smoke_evidence_2.0.0.json`.

### Evidência da jornada do runtime agentivo

Use `-ExerciseAgentRuntime` para executar aprovação, tool somente leitura, pausa, persistência,
retomada em nova instância e conclusão sem provider externo:

```powershell
powershell.exe -ExecutionPolicy Bypass `
  -File scripts\Test-RadIA.IDESmoke.ps1 `
  -DelphiVersion "37.0" `
  -Cycles 1 `
  -ExerciseAgentRuntime `
  -SkipPackageHashCheck `
  -AgentRuntimeEvidencePath `
    "Output\Validation\AgentRuntime\Delphi13-Win32.json"
```

Consolide os três targets suportados com:

```powershell
powershell.exe -ExecutionPolicy Bypass `
  -File scripts\New-RadIA.AgentRuntimeEvidence.ps1
```

O resultado versionado fica em `agent_runtime_smoke_evidence_2.0.0.json`.

### Evidência de workflows declarativos

Use `-ExerciseDeclarativeWorkflow` para carregar um manifesto schema 5 dentro da IDE, registrar o
workflow no catálogo compartilhado e executar duas etapas pelo policy executor:

```powershell
powershell.exe -ExecutionPolicy Bypass `
  -File scripts\Test-RadIA.IDESmoke.ps1 `
  -DelphiVersion "37.0" `
  -Cycles 1 `
  -ExerciseDeclarativeWorkflow `
  -SkipPackageHashCheck `
  -DeclarativeWorkflowEvidencePath `
    "Output\Validation\DeclarativeWorkflow\Delphi13-Win32.json"
```

Depois dos três targets suportados, consolide a matriz fail-closed:

```powershell
powershell.exe -ExecutionPolicy Bypass `
  -File scripts\New-RadIA.DeclarativeWorkflowEvidence.ps1
```

O resultado versionado fica em `declarative_workflow_smoke_evidence_2.0.0.json`.
O gate exige exatamente os três targets suportados, 130 ferramentas e o workflow
`RadIADiagnosticInspection` carregado, registrado e executado por hot reload. A evidência também
confirma a classificação `readOnly` e a conclusão das duas etapas do workflow.

### Evidência do conhecimento semântico

Use `-ExerciseKnowledge` para abrir um projeto real, indexá-lo com o provider local e validar busca,
origem, navegação, métricas, leitura e isolamento:

```powershell
powershell.exe -ExecutionPolicy Bypass `
  -File scripts\Test-RadIA.IDESmoke.ps1 `
  -DelphiVersion "37.0" `
  -Cycles 1 `
  -ExerciseKnowledge `
  -SkipPackageHashCheck `
  -KnowledgeEvidencePath "Output\Validation\Knowledge\Delphi13-Win32.json"
```

Depois dos três targets suportados, consolide a matriz fail-closed:

```powershell
powershell.exe -ExecutionPolicy Bypass `
  -File scripts\New-RadIA.KnowledgeEvidence.ps1
```

O resultado versionado fica em `knowledge_smoke_evidence_2.0.0.json`.
O gate exige exatamente Delphi 12 Win32, Delphi 13 Win32 e Delphi 13 IDE64, todos com 111
ferramentas, provider `local-hash-v1`, acerto vetorial, origem, navegação, leitura do documento,
métricas do índice e isolamento do workspace.

### Evidência de instalação e primeiro valor

Use `-ExerciseFirstValue` para consultar o diagnóstico pós-instalação e executar a primeira tool:

```powershell
powershell.exe -ExecutionPolicy Bypass `
  -File scripts\Test-RadIA.IDESmoke.ps1 `
  -DelphiVersion "37.0" `
  -Cycles 1 `
  -ExerciseFirstValue `
  -SkipPackageHashCheck `
  -FirstValueEvidencePath "Output\Validation\FirstValue\Delphi13-Win32.json"
```

Depois dos três targets suportados, consolide a matriz fail-closed:

```powershell
powershell.exe -ExecutionPolicy Bypass `
  -File scripts\New-RadIA.FirstValueEvidence.ps1
```

O resultado versionado fica em `first_value_smoke_evidence_2.0.0.json`.

### Instalador visual e canal de release

Depois que os três ZIPs forem aprovados, gere o instalador único:

```powershell
powershell.exe -ExecutionPolicy Bypass `
  -File scripts\New-RadIA.VisualInstaller.ps1

powershell.exe -ExecutionPolicy Bypass `
  -File scripts\Test-RadIA.VisualInstaller.ps1
```

Publique o catálogo depois que o executável e seu SHA-256 estiverem disponíveis em HTTPS:

```powershell
powershell.exe -ExecutionPolicy Bypass `
  -File scripts\New-RadIA.ReleaseChannel.ps1 `
  -InstallerPath Output\Installer\RadIA-v2.2.0-Setup.exe `
  -DownloadUrl "https://downloads.example.com/RadIA-v2.2.0-Setup.exe"
```

O catálogo `stable` exige HTTPS e registra hash e estado Authenticode. O fluxo completo está em
[Instalador visual e canal de release](visual_installer.md).

O workflow `RadIA release` automatiza a mesma sequência para tags `v*`, sem dependência de
certificado. Recomenda-se proteger a execução com aprovação de ambiente.

---

## Checklist Final

* Versão atualizada em código, metadados e documentação.
* `npx eslint` executado.
* `npm run test:web` e `npm run test:docs` executados.
* Build Delphi executado com sucesso.
* Análise exata aprovada pelo SonarQube Quality Gate.
* Status check `Build, analyze, and enforce Quality Gate` obrigatório e aprovado.
* Pacotes Release internos gerados para Delphi 12 Win32, Delphi 13 Win32 e Delphi 13 IDE64.
* Instalador visual, SHA-256 e catálogo estável HTTPS publicados.
* Validação positiva e negativa executada para cada pacote.
* Os três ZIPs internos validados e consumidos pelo instalador, sem publicação redundante.
* Evidência JSON de dez ciclos reais gerada para cada combinação suportada.
* Nenhum processo ou discovery MCP órfão após os smokes.
* Branch de trabalho publicada.
* `develop` atualizado e publicado.
* `main` atualizado e publicado.
* Tag anotada criada a partir de `main` e publicada.
* Branch de trabalho removida local/remoto depois do merge.
