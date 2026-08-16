# Modelo de Segurança das Ferramentas Agentivas

## 1. Objetivo

Este modelo protege o usuário, o workspace e o processo `bds.exe` contra ações indevidas,
ambíguas ou executadas com estado desatualizado.

Consentimento não substitui validação técnica. Mesmo uma ação aprovada deve continuar limitada
ao escopo declarado e falhar se suas precondições não forem satisfeitas.

## 2. Níveis de risco

| Nível | Exemplos | Política padrão |
|---|---|---|
| Somente leitura | Ler editor, projeto ou mensagens | Permitir |
| Escrita reversível | Aplicar patch ou inserir texto | Mostrar diff e confirmar |
| Escrita estrutural | Alterar projeto, unit ou form | Confirmar sempre |
| Execução | Build, teste ou processo externo | Confirmar por categoria |
| Destrutiva | Remover unit ou componente | Confirmar sempre e destacar efeito |
| Sensível | Credenciais, configuração global | Negar por padrão |

Uma tool sensível só pode substituir a negação padrão quando seu descritor declara
`ConsentEveryTime`. Nesse caso, cada chamada abre o diálogo e `AllowSession` nunca é reutilizado.

Ferramentas federadas por servidores MCP externos (nome iniciado por `mcp.`) não recebem a
liberação automática de somente leitura. Como o nível de risco delas é declarado pela concessão
configurada, e não pelo próprio RadIA, a primeira chamada sempre abre o diálogo de consentimento.
Escolher `AllowSession` mantém a aprovação válida pelo restante da sessão.

## 3. Decisões de consentimento

- `AllowOnce`: permite apenas a requisição atual.
- `AllowSession`: permite a mesma ferramenta e escopo durante a sessão atual.
- `Deny`: recusa a requisição.
- `Cancel`: encerra o fluxo que originou a requisição.

Permissões de sessão:

- Não sobrevivem ao restart da IDE.
- Não são válidas para outro projeto.
- Não ampliam paths ou efeitos.
- Podem ser revogadas pela UI.
- Não se aplicam automaticamente a ações destrutivas ou sensíveis.

Ferramentas compatíveis compartilham a aprovação somente quando origem, sessão, projeto, escopo e
nível de risco permanecem iguais. Por isso, uma jornada pode pedir uma aprovação para criar o
projeto, outra para abri-lo ou executá-lo e reutilizar cada decisão nas chamadas seguintes da mesma
categoria. Quando o projeto ativo muda, o RadIA solicita uma nova aprovação em vez de transferir
silenciosamente a permissão para o novo workspace.

### Diálogo central e superfícies

Chat, agente nativo, MCP e terminal usam o mesmo provider de consentimento e o mesmo diálogo nativo,
independente do painel que originou a chamada. O diálogo mostra a origem em linguagem humana,
projeto, escopo, risco e argumentos já sanitizados. Fechar ou desacoplar chat ou terminal não fecha
uma solicitação pendente.

Somente um diálogo fica ativo por vez. Solicitações simultâneas aguardam em uma fila limitada pelo
timeout configurado; se a IDE estiver encerrando ou a espera expirar, a decisão é `Cancel`. Nenhuma
solicitação é aprovada automaticamente. Todos os botões e a área de argumentos possuem hints.

## 4. Workspace boundary

Toda operação de arquivo deve:

1. Resolver o caminho absoluto.
2. Determinar a raiz autorizada.
3. Rejeitar parent traversal.
4. Inspecionar symlinks, junctions e reparse points.
5. Revalidar imediatamente antes da mutação.
6. Recusar paths fora do projeto sem consentimento específico.
7. Nunca usar `%USERPROFILE%`, raiz de volume ou diretório amplo como escopo implícito.

Arquivos da IDE e configurações globais são um escopo separado do projeto.

## 5. Precondições de mutação

Uma mutação de editor deve carregar:

- Arquivo alvo.
- Revisão ou hash lido.
- Intervalo esperado.
- Conteúdo original esperado.
- Conteúdo proposto.
- Encoding.
- Line ending.

A aplicação deve ser recusada quando:

- O buffer mudou.
- O trecho original não existe.
- O trecho aparece de forma ambígua.
- O arquivo ativo não corresponde ao alvo.
- O projeto foi fechado.
- A IDE está encerrando.

## 6. Processos externos

Antes de iniciar um processo, o RadIA deve mostrar:

- Executável resolvido.
- Argumentos.
- Diretório de trabalho.
- Categoria da operação.
- Variáveis de ambiente adicionais, com secrets ocultos.

Controles obrigatórios:

- Processo filho associado à sessão.
- Captura separada de stdout e stderr.
- Timeout.
- Cancelamento da árvore de processos quando seguro.
- Diretório de trabalho limitado.
- Ambiente filtrado.
- Nenhum comando por shell quando execução direta for possível.

## 7. Proteção de dados

O redator deve remover ou mascarar:

- API keys.
- OAuth access e refresh tokens.
- AWS access keys e session tokens.
- Authorization headers.
- Cookies.
- Connection strings com senha.
- Valores conhecidos pelo credential store.

Sanitização deve ocorrer antes de:

- Auditoria.
- Exibição de erro.
- Resposta MCP.
- Logs de debug.

## 8. Auditoria

Cada evento deve conter:

- ID do evento.
- ID de correlação.
- Sessão.
- Data e duração.
- Ferramenta e versão.
- Projeto e escopo.
- Risco.
- Argumentos sanitizados.
- Decisão de consentimento.
- Estado final.
- Arquivos ou recursos afetados.
- Mensagem de erro sanitizada.

Estados finais:

- `Succeeded`
- `Denied`
- `Cancelled`
- `Failed`
- `PreconditionFailed`
- `Unsupported`

## 9. MCP local

O servidor MCP deve:

- Escutar somente localmente.
- Preferir named pipe.
- Usar token efêmero quando HTTP for necessário.
- Limitar payload e concorrência.
- Rejeitar requests durante shutdown.
- Não expor configurações ou credenciais de providers.
- Passar todas as chamadas pela mesma policy pipeline.
- Registrar origem e identidade lógica do cliente.
- Propagar `notifications/cancelled` para tokens cooperativos das tools.
- Limitar cada conexão a uma chamada em voo.
- Expor telemetria apenas como contadores sanitizados, sem argumentos, código ou credenciais.

## 10. Form Designer e debugger

Mutações do Designer são estruturais e exigem confirmação.

Controle do debugger e execução da aplicação são classificados como execução. Leituras de locals
podem conter secrets e devem ser sanitizadas antes de chegar a logs ou clientes externos.

### 10.1. Banco SQLite local

A inspeção aceita somente arquivos dentro do workspace. Consultas usam conexão somente leitura,
limites de linhas e colunas, consentimento em toda execução e sanitização antes do grid e do CSV.
DDL, DML, múltiplas instruções, BLOBs e runtimes SQLite fora da instalação confiável do Delphi são
recusados.

## 11. Falha segura

Na dúvida, a operação deve:

- Não alterar estado.
- Retornar erro estruturado.
- Preservar o buffer atual.
- Liberar objetos locais.
- Registrar somente dados sanitizados.
- Não tentar caminhos alternativos mais permissivos.

## 12. Testes obrigatórios

- Negação sem efeitos.
- Timeout do diálogo.
- Revogação da permissão de sessão.
- Path traversal.
- Junction/reparse point.
- Buffer modificado após preview.
- Projeto fechado durante operação.
- Shutdown durante requisição.
- Sanitização de cada tipo de secret.
- Processo externo cancelado.
- Auditoria de sucesso, falha e negação.
