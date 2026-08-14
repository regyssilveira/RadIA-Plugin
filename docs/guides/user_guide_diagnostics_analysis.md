# Guia de Uso: Diagnóstico de Erros & Análise de Código

Este guia detalha como utilizar as ferramentas avançadas do **Rad IA** para localizar e depurar erros de compilação, analisar stack traces de exceções e realizar análises estáticas de qualidade e segurança em seu código Object Pascal.

---

## Saúde consolidada do projeto

Digite `/health` para abrir um cartão com score de 0 a 100 e riscos priorizados da IDE, compilador,
último build, última execução DUnitX e conhecimento local. Quando houver uma correção conhecida,
**Preparar ação** coloca a jornada recomendada no campo do chat. O RadIA não executa a jornada
automaticamente: você pode revisar, complementar ou apagar o comando antes de enviá-lo.

## 1. Depurador de Compilação (Smart Build Debugger)

Muitas vezes, erros apontados pelo compilador do Delphi (DCC) são enigmáticos ou difíceis de rastrear na primeira leitura (por exemplo, erros de sintaxe decorrentes de declarações incorretas de tipos ou literais de string que violam o limite de 255 caracteres). O Rad IA integra-se à janela de mensagens da IDE para ajudar.

### Como Utilizar:
1. Compile seu projeto na IDE (`Ctrl + F9` ou `Shift + F9`).
2. Se houver falhas, navegue até a aba **Messages** (na parte inferior da IDE do Delphi).
3. Clique com o **botão direito sobre a linha do erro de compilação**.
4. No menu suspenso, selecione **Rad IA: Explicar e Corrigir Erro**.
5. O Rad IA abrirá o chat lateral enviando automaticamente o código de erro, a mensagem do compilador e o trecho de código da linha afetada.
6. A IA explicará a causa raiz do erro de compilação e sugerirá o código corrigido pronto para ser aplicado.

---

## 2. Assistente de Stack Trace

Depurar erros ocorridos em ambiente de homologação ou produção baseando-se apenas em relatórios textuais de exceções é exaustivo. O Rad IA possui um assistente contextual dedicado para decodificar esses dados.

### Como Utilizar:
1. Abra na IDE o arquivo `.pas` (unit) onde o stack trace aponta que o erro ocorreu.
2. Na caixa de texto do chat do Rad IA, digite `/stacktrace` seguido do log de erro. Exemplo:
   > `/stacktrace EAccessViolation em TInvoiceService.ProcessInvoice na linha 122`
   *(Você também pode colar o stack trace completo gerado por ferramentas como **MadExcept** ou **EurekaLog**).*

O comando usa `AnalyzeProjectStackTrace` antes da análise textual. A ferramenta reconhece traces Delphi,
MadExcept e EurekaLog, correlaciona frames com todas as units do projeto e retorna arquivo, linha, método e
confiança. Quando solicitado, o agente usa esse destino com `NavigateToFile`; a importação não altera código.
3. O Rad IA capturará o código da unit ativa aberta no editor, enviará à IA juntamente com a pilha de chamadas informada e solicitará o cruzamento de dados.
4. A IA analisará o código correspondente às linhas apontadas no log e retornará um parecer técnico indicando onde a falha (ponteiro nulo, estouro de índice de array, etc.) ocorreu e como corrigi-la.

---

## 3. Analisador de Memory Leaks e Anti-patterns

O gerenciamento de memória em Delphi para plataformas desktop é manual. A ausência de blocos de proteção `try..finally` é o maior fator causador de memory leaks (vazamentos de memória). O Rad IA permite auditar seu código estaticamente para evitar que esses problemas cheguem à produção.

### Como Utilizar:
1. Abra o arquivo Pascal que deseja auditar no editor.
2. Para analisar a unit inteira: digite `/bugs` no chat lateral (ou use o atalho de teclado `Ctrl + Shift + B`).
3. Para analisar apenas um bloco: selecione o trecho do código, clique com o botão direito e escolha **Rad IA -> Localizar Bugs**.
4. A IA fará uma varredura estática focando em:
   * **Memory Leaks**: Instanciações locais de classes (como `TList<T>`, `TStringList`, objetos de conexão) que não possuem um correspondente bloco `try..finally` garantindo sua liberação (`.Free`).
   * **Tratamento de Exceções**: Blocos `try..except` vazios ou genéricos demais que silenciam erros graves do sistema.
   * **Regras de SOLID e Clean Code**: Código excessivamente acoplado, métodos com linhas de código excessivas ou classes com multiplas responsabilidades.
5. As sugestões de refatorações serão exibidas no painel de chat, permitindo a comparação no *Smart Diff* para aplicação direta.

> [!WARNING]
> **Limitações da Análise Estática de Memória:**
> A verificação de memory leaks realizada pela IA no comando `/bugs` é uma **análise estática e estrutural de código**. Ela busca padrões sintáticos suspeitos (como a ausência de blocos `try..finally`). Isso **não substitui** os mecanismos dinâmicos de teste de execução do Delphi. É altamente recomendado manter o `ReportMemoryLeaksOnShutdown := True` ativado em modo de debug na sua aplicação ou usar ferramentas de perfilamento (como FastMM4, MadExcept ou EurekaLog) para a validação em runtime.
