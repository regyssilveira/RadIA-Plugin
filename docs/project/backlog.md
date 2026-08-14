# Backlog do RadIA

Este arquivo contém somente trabalho aberto. Histórico, marcos concluídos, métricas e notas de
release não pertencem ao backlog.

## Pendências recuperadas e revalidadas

Os itens abaixo existiam no backlog anterior à reorganização documental de 12 de agosto de 2026 e
continuam abertos após auditoria do código atual. Eles não possuem versão comprometida; a ordem de
execução deve ser definida por ganho verificável, esforço e dependências.

| Área | Resultado aberto | Estado atual verificável | Critério de conclusão |
|---|---|---|---|
| Assistência de código | Clean Uses | Não há analisador dedicado para detectar e preparar a remoção segura de units não utilizadas. | Uma preview considera símbolos, condicionais e escopos do projeto, aplica com consentimento e preserva o build. |
| APIs existentes | Retrofit OpenAPI/Swagger | Swagger é gerado para novos projetos DEXT, mas projetos existentes não possuem jornada de retrofit. | A jornada inventaria rotas existentes, prepara a especificação e aplica integração revisável sem recriar o projeto. |
| Modernização | Adoção de DEXT e decomposição de forms | A migração para FireDAC e o plano posterior existem; a ferramenta não executa DEXT nem decomposição. | Uma jornada aplica etapas reversíveis, comprova paridade e separa responsabilidades sem quebrar DFM/PAS. |
| Concorrência | Assistente de threads e PPL | Há orientação genérica, sem auditor ou jornada específica para modernizar rotinas síncronas. | A jornada detecta riscos, prepara alterações seguras e valida acesso à VCL, cancelamento e tratamento de exceções. |
| Produtividade | Wizard de internacionalização | Existe infraestrutura interna de localização, mas não um wizard para projetos do usuário. | O wizard inventaria strings, prepara recursos e alterações revisáveis e preserva o idioma padrão. |

A auditoria DFM/PAS e a migração determinística de BDE, ADO e dbExpress para FireDAC não retornam a
esta lista porque já estão implementadas. O item de modernização registra apenas o trabalho residual
de adoção de DEXT e decomposição efetiva de forms.

O backlog não registra versões, entregas concluídas, evidências ou ideias ainda não aprovadas. A
direção de longo prazo fica no [roadmap](roadmap.md).
