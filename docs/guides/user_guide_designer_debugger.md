# Guia do Form Designer e debugger agentivos

## Timeline orientada a eventos

`GetDebugTimeline` registra notificações da Open Tools API em vez de consultar o debugger
continuamente. Informe o último `sequence` recebido em `sinceSequence` para buscar apenas eventos
novos. Cada item contém `timestampUtc`, `kind`, `processId`, `state` e `details`.

```json
{
  "sinceSequence": 12,
  "maxCount": 100
}
```

A trilha persistente fica em `.radia/debug/timeline.jsonl` no projeto ativo.

## Form Designer

As ferramentas do Designer operam sobre o formulário ativo na IDE. Elas podem consultar
componentes, propriedades, eventos e layout, além de preparar mutações revisáveis.

Exemplos:

- “Liste os componentes e a hierarquia do formulário.”
- “Mostre propriedades publicadas deste botão.”
- “Prepare a alteração do `Caption`, sem aplicar.”
- “Associe este evento a um método existente.”
- “Alinhe os componentes selecionados e mostre o preview.”

Uma mutação valida o formulário, o componente e o valor-base. Se o Designer mudou desde o preview,
a operação é recusada. Alterações devem ocorrer na thread principal da IDE e passar por
consentimento.

## Debugger

As ferramentas do debugger consultam estado, processo, thread, localização atual, breakpoints,
expressões e watches. Ferramentas de controle podem iniciar, continuar, pausar ou encerrar uma
sessão quando o estado da IDE permitir.

Exemplos:

- “Mostre o estado atual do debugger.”
- “Adicione um breakpoint na linha atual.”
- “Avalie `LResult` no frame atual.”
- “Adicione `FClient.Connected` aos watches.”
- “Continue a execução.”

Cada comando possui precondições. Avaliação exige processo pausado e contexto válido; continuar
exige uma sessão ativa; algumas alterações de breakpoint não são aceitas durante transições.

### Breakpoints avançados no Delphi 12 e 13

Antes de configurar um breakpoint avançado, o RadIA executa
`GetAdvancedBreakpointCapabilities`. A matriz efetiva para os dois Delphis suportados é:

| Recurso | Estado | Observação |
|---|---|---|
| Condição | Disponível | Usa a expressão nativa do breakpoint da IDE. |
| Hit count | Disponível | `0` desativa; valores positivos usam o contador nativo. |
| Logpoint | Disponível | Pode registrar mensagem, expressão, resultado e frames sem interromper quando `break=false`. |
| Condição de thread | Disponível | Aceita o identificador ou nome reconhecido pelo debugger. |
| Filtro global de exceções | Indisponível | A OTA não expõe uma API global confiável; o RadIA informa a limitação e não simula o recurso. |

Crie primeiro um breakpoint com `AddBreakpoint`. Depois peça em linguagem natural, por exemplo:

- “Pare nesta linha somente quando `OrderId = 42`.”
- “Ignore as quatro primeiras passagens e pare na quinta.”
- “Registre `Customer.Name` e quatro frames sem interromper.”

`ConfigureBreakpoint` altera apenas os campos pedidos, preserva os demais e retorna
`previousConfiguration`, `inverseTool` e `inverseArguments`. Assim, a mesma ferramenta restaura a
configuração anterior após novo consentimento. `ListBreakpoints` mostra condição, contadores,
ações de log e thread efetivos.

## Segurança

- Comandos de controle e mutação exigem consentimento.
- Resultados são limitados e sanitizados.
- Erros OTA resultam em falha segura, sem repetição automática de comandos.
- O shutdown cancela solicitações pendentes.

Nunca presuma que um comando foi executado: confirme o resultado estruturado e o estado posterior
da IDE.
