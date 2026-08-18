# Jornadas Delphi ponta a ponta

As jornadas transformam tools isoladas em fluxos completos executados pelo Agent Runtime. Toda
jornada apresenta um plano antes da primeira mutação, usa o consentimento central, registra
checkpoints e mantém diffs, build, testes, debugger e Git observáveis no chat.

Digite `/journey` para listar as receitas disponíveis.

Você pode informar tudo no comando ou iniciar apenas com o nome da jornada. Quando faltar um dado,
o RadIA mantém a jornada ativa, pergunta um item por vez e incorpora cada resposta ao mesmo
contexto. A execução do agente começa somente depois da coleta. Use `/journey cancel` para abandonar
a coleta e descartar o que foi informado; trocar de chat fica bloqueado enquanto ela estiver ativa.

Cada receita aceita contexto opcional depois do comando, por exemplo:

```text
/journey create aplicativo VCL de estoque com FireDAC e SQLite
/journey dext-minimal
/journey dext-controllers project=BookingApi destination=D:\Projects platform=Win64 port=8080 health=/health endpoints="GET /bookings/{id} group=Bookings status=200 purpose=GetBooking"
/journey fix-build preserve a API pública da unit CustomerService
/journey debug Access Violation ao fechar o formulário de pedidos
/journey modernize reduzir acoplamento sem alterar as interfaces públicas
/journey migrate substituir uma camada ADO por FireDAC em lotes reversíveis
```

O contexto é limitado a 4.000 caracteres e anexado ao objetivo estruturado. Ele não altera as
regras de consentimento nem substitui a revisão do plano.

O contrato completo da classificação local e suas proteções está em
[Roteamento de intenção](../reference/intent_routing.md).

Cada receita possui quatro fases obrigatórias. Cada fase define o trabalho esperado e a evidência
que deve aparecer na timeline. A execução também recebe três critérios de conclusão; o agente não
deve declarar sucesso apenas porque produziu uma resposta textual.

| Comando | Objetivo |
|---|---|
| `/journey create [requisitos]` | Criar, organizar, documentar, compilar e explicar um projeto Delphi. |
| `/journey dext-minimal [endpoints]` | Criar e validar um servidor DEXT com rotas diretas. |
| `/journey dext-controllers [endpoints]` | Criar e validar um servidor DEXT organizado por controllers. |
| `/journey fix-build [restrições]` | Diagnosticar erros, aplicar correção mínima e recompilar. |
| `/journey tests [foco]` | Identificar lacunas, criar testes DUnitX e executar a validação. |
| `/journey debug [sintoma]` | Reproduzir uma falha, coletar evidências, corrigir e validar. |
| `/journey modernize [escopo]` | Modernizar units, forms, packages e dependências em lotes validados. |
| `/journey migrate [padrão legado]` | Migrar um padrão delimitado com baseline, transação e rollback. |
| `/journey release [escopo]` | Verificar gates, diff e preparar preview de commit. |

### Recomendação por intenção a partir da conversa

Não é obrigatório conhecer os comandos de jornada. Pedidos naturais de criação, correção de build,
execução de testes ou diagnóstico mostram primeiro um cartão de recomendação. Ele informa intenção,
nível de confiança, motivo e comando proposto, sem mudar o modo nem executar uma tool.

- **Use recommended route** confirma a jornada proposta.
- **Review command** coloca o comando no compositor para edição.
- **Continue as chat** mantém a rota atual e envia o pedido como conversa comum.

Para frases como **“faça uma calculadora básica”** ou **“crie uma calculadora VCL em
D:\Projetos\Calculadora”**, o RadIA extrai caminhos Windows absolutos, infere o nome pelo destino ou
tipo da aplicação e assume Win32 quando a plataforma não é informada. Somente dados realmente
ausentes geram perguntas depois que o usuário confirma a recomendação. Após a aprovação do plano, o
fluxo cria os arquivos apenas na raiz autorizada, abre o projeto na IDE, compila, executa e registra
as evidências de validação. O painel permanece aberto durante a transição e mostra o andamento ao
usuário.

O tipo também é inferido sem exigir o comando: Console, VCL, FireMonkey/FMX, Library/DLL, Package/BPL,
DUnitX ou Windows Service. Os termos equivalentes em português e inglês são aceitos. Se o pedido não
identificar um desses tipos com segurança, o RadIA pergunta qual template usar antes do preview.

Para uma calculadora VCL genérica, a jornada usa o perfil `essential`: cria somente a aplicação,
abre o projeto e conclui o primeiro build. Depois do build, o RadIA apresenta escolhas explícitas
para manter o projeto como está, adicionar DUnitX ou solicitar outros incrementos. Somente após essa
escolha o perfil `complete`, ou `custom` com `dunitx`, inclui `companionTestProject` e
`companionTestExecutable`, compila a suíte companion e executa os testes com `RunDUnitXTests`.

Quando o pedido inclui **histórico de operações**, **lista de cálculos** ou expressão equivalente,
esse requisito é preservado na especificação estruturada e no preview. A calculadora gerada registra
cada operação concluída em ordem e oferece **Clear history**. A jornada só pode concluir depois de
executar cálculos reais, conferir o histórico e verificar sua limpeza; um build verde, isoladamente,
não atende esse pedido.

Se a pasta de destino já existir, a execução informa o conflito e mantém a jornada aguardando outro
destino. A resposta seguinte substitui somente o caminho: tipo do projeto, plataforma, nome e requisitos
funcionais — inclusive o histórico — continuam no objetivo. O cartão de recomendação é consumido
visualmente no primeiro clique para não sugerir que a mesma ação ainda está disponível. Ao receber o
novo caminho, o chat confirma imediatamente a retomada e move o plano recuperado para o final da
conversa, onde a nova aprovação permanece visível.

## Como a execução funciona

1. O comando ativa visualmente o modo agente quando necessário.
2. O RadIA converte a receita em um objetivo estruturado.
3. O modelo produz um plano revisável; nenhuma tool é executada antes da aprovação.
4. Cada operação passa por risco, consentimento, workspace boundary, sanitização e auditoria.
5. O usuário pode pausar, editar o plano, repetir uma etapa, retomar ou cancelar.
6. O resultado mostra evidências e riscos restantes, não apenas uma resposta textual.

O catálogo `/journey` informa a quantidade de fases e critérios. No início da execução, o objetivo
enviado ao Agent Runtime enumera as fases na ordem, a evidência exigida em cada uma e os critérios
finais. O contexto digitado pelo usuário aparece separado e não consegue remover esses gates.

Na jornada de criação, referências externas só são analisadas quando o usuário autoriza o path ou
URL. O plano registra licença e proveniência, justifica dependências, prefere recursos adequados da
RTL, organiza units reutilizáveis, atualiza o `.dproj`, produz documentação aplicável e usa os
diagnósticos reais do compilador como feedback para a próxima correção revisada.

As receitas não concedem permissões extras. A jornada de release prepara um preview local, mas não
faz push nem publica artefatos sem uma instrução explícita do usuário.

## Quando usar

- Use **create** quando a intenção inclui um projeto novo, estrutura, abertura e primeiro build.
- Use **fix-build** quando há mensagens reais do compilador e a correção precisa ser mínima.
- Use **tests** para ampliar cobertura sem misturar refatorações não relacionadas.
- Use **debug** quando a causa exige estado de execução, breakpoints, stack, watches ou avaliação.
- Use **modernize** para evoluir estrutura e práticas preservando comportamento e contratos públicos.
- Use **migrate** para substituir tecnologia legada em lotes independentes e reversíveis.

Para BDE, ADO e dbExpress, a jornada `migrate` usa o
[fluxo dedicado de migração para FireDAC](legacy_data_migration.md): inventário, risco, preview por
arquivo, build, testes e reversão obrigatória quando um gate falha. DEXT e decomposição de forms só
entram no plano posterior à estabilização dos lotes FireDAC.
- Use **release** antes de uma entrega para reunir gates técnicos e revisar o escopo do commit.
