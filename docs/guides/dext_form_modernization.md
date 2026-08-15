# Modernização DEXT e decomposição de forms

Comece pelo relatório de migração legado: todos os lotes devem estar `validated`. Registre evidência
de paridade comportamental do fluxo existente antes de preparar qualquer mudança.

`PrepareDextFormModernization` recebe o relatório, a evidência e os conteúdos propostos. O lote deve
incluir o par DFM/PAS do form, uma fronteira DEXT explícita e ao menos uma responsabilidade extraída
para Presenter, Service ou Controller. A auditoria DFM/PAS precisa passar antes da criação do preview
multiarquivo reversível.

Depois da aplicação consentida, compile e teste o lote. Envie as evidências para
`RecordDextFormModernizationGate`. Se build ou testes falharem, a ferramenta reverte o preview; ambos
precisam passar para registrar o estado `validated`.
