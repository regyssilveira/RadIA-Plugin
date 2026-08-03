# Guia do Form Designer e debugger agentivos

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

## Segurança

- Comandos de controle e mutação exigem consentimento.
- Resultados são limitados e sanitizados.
- Erros OTA resultam em falha segura, sem repetição automática de comandos.
- O shutdown cancela solicitações pendentes.

Nunca presuma que um comando foi executado: confirme o resultado estruturado e o estado posterior
da IDE.
