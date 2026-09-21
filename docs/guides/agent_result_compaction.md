# Compactação e recuperação de resultados do agente

O RTK interno do RadIA reduz resultados extensos antes da próxima decisão do modelo. Enquanto retido,
o resultado integral é a fonte de verdade e pode ser recuperado sem repetir build, teste, Git ou
outra ferramenta.

## Configuração

Abra **Tools > Options > Rad IA > General / Logs**.

| Perfil | Comportamento |
|---|---|
| `Off` | Envia o resultado integral e desativa envelopes de orçamento. Use para rollback ou diagnóstico. |
| `Conservative` | Padrão recomendado. Compacta resultados elegíveis e preserva uma margem maior de contexto. |
| `Balanced` | Usa o mesmo compactador determinístico e um orçamento menor por etapa antiga. |

**Maximum agent decision context characters** aceita de 16.000 a 1.000.000 caracteres; o padrão é
120.000. `RADIA_RESULT_COMPACTION_PROFILE` pode sobrescrever temporariamente o perfil persistido.

## Regras atuais

- DUnitX remove ANSI, agrupa linhas consecutivas repetidas e preserva início, fim, failures e errors.
- Git diff preserva headers e início/fim de diffs extensos.
- Build preserva errors e fatals e limita mensagens rotineiras.
- Knowledge limita conteúdo extenso, preservando arquivo, score e proveniência.
- Ferramentas sem regra conhecida usam passthrough.
- A projeção só é aplicada quando fica menor que o JSON original.
- Falha de parsing ou validação usa fallback automático para o JSON original.
- Árvores de controles em execução preferem paths semânticos e removem duplicatas nativas quando ambas
  representam o mesmo formulário, sem eliminar a raiz da janela.

## Preservação e recuperação

Resultados integrais são armazenados por sessão e etapa, com SHA-256 e gravação atômica. Cada sessão
mantém os 100 artefatos mais recentes dentro de 64 Mi caracteres; ao atingir um limite, remove os
mais antigos sem bloquear novas execuções. Cada artefato aceita 8 Mi caracteres. Artefatos também
expiram após 14 dias e a limpeza ocorre ao carregar o plugin.

O contexto compactado informa `artifactId`, hash, tamanho e `fullResultAvailable`. O agente pode usar:

- `GetToolResultSummary`, para confirmar hash, tamanho e etapa;
- `GetToolResultRange`, para recuperar até 65.536 caracteres por chamada.

Uma resposta com `hasMore=false` encerra a recuperação daquele intervalo. O RadIA não transforma o
resultado dessa ferramenta em outro artefato e, se o modelo repetir imediatamente a mesma leitura,
devolve uma orientação estruturada para continuar a validação funcional. Uma nova repetição ainda é
interrompida pelo limite de segurança.

As ferramentas respeitam a sessão ativa, rejeitam traversal, spoofing de sessão e ranges inválidos.
Checkpoints, replay, UI e validation gates preservam a referência. Após a retenção remover um
artefato antigo, as ferramentas informam que ele não está mais disponível.

## Métricas e diagnóstico

`/status agent` e `GetRadIAStatus` mostram perfil, recuperação e limite de contexto. O snapshot de
decisão agrega somente contagens, duração e nome da regra; não registra código, prompts, argumentos
ou secrets.

Quando uma execução inicia, aguarda aprovação, termina, pausa ou falha, o log local também recebe um
evento `agentRunSummary`. Ele registra somente o identificador irreversível da execução, estado, motivo
normalizado de parada, duração, decisões, tools, falhas, repetições, recuperações e rejeições de validação.
Tokens aparecem apenas como contadores informados pelo provedor; `usageStatus=unknown` deixa explícito
quando essa informação não existe. Objetivo, prompt, argumentos, resultados, caminhos e identificadores
originais de sessão ou projeto nunca fazem parte desse evento.

Os motivos estáveis distinguem conclusão, aprovação pendente, pausa, cancelamento, decisão ausente ou
parcial, plano inválido, tool vazia, chamada repetida e limites de duração, tokens ou custo. Essa
classificação é independente da mensagem legível apresentada ao usuário.

Os valores incluem `completed`, `awaitingApproval`, `paused`, `cancelled`, `agentReportedFailure`,
`planFailure`, `emptyToolName`, `repeatedToolCall`, `durationLimit`, `tokenBudget` e `costBudget`.

Quando uma chamada idêntica e consecutiva repete uma tool que acabou de retornar sucesso, o runtime
reutiliza a evidência anterior e não executa a tool novamente. O passo auditável informa
`successful_result_already_available`; `suppressedToolCallCount` mede a economia real. Uma chamada que
falhou continua elegível a nova tentativa, e o limite estrito configurado pelo usuário continua prevalecendo.

### Baseline de eficiência

Com o logging habilitado, gere um baseline sanitizado das execuções mais recentes:

```powershell
powershell.exe -ExecutionPolicy Bypass -File scripts\Measure-RadIA.AgentEfficiency.ps1 `
  -LastRuns 100 `
  -PairingKey create-project-delphi13-standard `
  -OutputPath Output\AgentEfficiencyBaseline.json
```

Para comparar outra amostra do mesmo fluxo, provedor, modelo e configuração:

```powershell
powershell.exe -ExecutionPolicy Bypass -File scripts\Measure-RadIA.AgentEfficiency.ps1 `
  -LastRuns 100 `
  -PairingKey create-project-delphi13-standard `
  -BaselinePath Output\AgentEfficiencyBaseline.json `
  -OutputPath Output\AgentEfficiencyCurrent.json
```

O agregador usa somente o último resumo de cada execução, sem exportar `runId` ou caminhos. Ele mede
decisões, tools executadas e suprimidas, repetições recuperadas, duração, latência até a primeira decisão
e tokens reportados. Execuções com `usageStatus=unknown` não entram na média de tokens, evitando apresentar
ausência de medição como zero. `PairingKey` identifica a mesma combinação de cenário, provider, modelo e
configuração; somente seu hash truncado aparece na evidência.

Depois de capturar duas amostras com a mesma chave e o mesmo número de execuções, aplique o gate relativo:

```powershell
powershell.exe -ExecutionPolicy Bypass -File scripts\Test-RadIA.AgentEfficiencyGate.ps1 `
  -BaselinePath Output\AgentEfficiencyBaseline.json `
  -CurrentPath Output\AgentEfficiencyCurrent.json `
  -OutputPath Output\AgentEfficiencyGate.json
```

Por padrão, cada amostra precisa ter pelo menos 20 execuções, responsividade medida em todas elas e uso de
tokens reportado na mesma quantidade não nula. O gate rejeita aumentos superiores a 20% em duração ou
latência da primeira decisão e superiores a 10% em decisões, tools ou tokens. Os limites são parâmetros
explícitos do script; não use chaves diferentes nem reduza a amostra para fazer uma regressão passar.

O benchmark reproduzível é executado com:

```powershell
powershell.exe -ExecutionPolicy Bypass -File scripts\Test-RadIA.ResultCompaction.ps1
```

Evidências históricas de viabilidade permanecem disponíveis no histórico Git e no GitHub Releases.
