# Compactação e recuperação de resultados do agente

O RTK interno do RadIA reduz resultados extensos antes da próxima decisão do modelo. O resultado
integral continua sendo a fonte de verdade e pode ser recuperado sem repetir build, teste, Git ou
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

## Preservação e recuperação

Resultados integrais são armazenados por sessão e etapa, com SHA-256 e gravação atômica. Cada sessão
aceita no máximo 100 artefatos e 64 Mi caracteres; cada artefato aceita 8 Mi caracteres. Artefatos
expiram após 14 dias e a limpeza ocorre ao carregar o plugin.

O contexto compactado informa `artifactId`, hash, tamanho e `fullResultAvailable`. O agente pode usar:

- `GetToolResultSummary`, para confirmar hash, tamanho e etapa;
- `GetToolResultRange`, para recuperar até 65.536 caracteres por chamada.

As ferramentas respeitam a sessão ativa, rejeitam traversal, spoofing de sessão e ranges inválidos.
Checkpoints, replay, UI e validation gates preservam o resultado integral.

## Métricas e diagnóstico

`/status agent` e `GetRadIAStatus` mostram perfil, recuperação e limite de contexto. O snapshot de
decisão agrega somente contagens, duração e nome da regra; não registra código, prompts, argumentos
ou secrets.

O benchmark reproduzível é executado com:

```powershell
powershell.exe -ExecutionPolicy Bypass -File scripts\Test-RadIA.ResultCompaction.ps1
```

Consulte a [evidência de viabilidade 2.3.0](result_compaction_release_audit_2.3.0.md).
