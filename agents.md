# Regras e Diretrizes para Agentes de IA (LLMs) no Rad IA

Este arquivo define as regras técnicas, restrições do compilador Delphi (Object Pascal) e padrões de codificação que todo Agente de IA (LLM/Copilot) deve seguir estritamente ao trabalhar nesta base de código.

---

## 1. Diretrizes de Idioma e Padrões de Projeto

*   **Comunicação (AI & Humans):** Toda conversa, explicações de código, descrições de pull requests e documentação de tarefas devem ser escritas em **Português do Brasil (pt-BR)**.
*   **Mensagens de Commit:** Todos os commits devem ser escritos em **Inglês (en-US)** seguindo o padrão documentado em `docs/commit_convention.md`.
*   **Nomes de Branch:** Todas as branches devem seguir o padrão `<tipo>/<descricao-curta>` documentado em `docs/branch_convention.md`.
*   **Código Fonte (Codebase):** Todo o código fonte, incluindo classes, métodos, records, variáveis, enums, comentários internos, esquemas de dados, bem como **prompts e templates de IA hardcoded** (por exemplo, prompt padrão de sistema ou templates Pascal embutidos) devem ser escritos **100% em Inglês (en-US)**.
*   **Arquitetura:** Siga rigorosamente os princípios **SOLID**, **Clean Code**, **DRY** (Don't Repeat Yourself) e **KISS** (Keep It Simple, Stupid).
*   **Documentação como parte do produto:** Toda alteração visível ao usuário deve atualizar, no mesmo
    trabalho, a referência central, o guia de uso aplicável, os hints da interface, a tradução existente
    e os testes documentais. Uma funcionalidade não está concluída enquanto seu uso exigir consulta ao
    código-fonte, roadmap ou histórico. Siga `docs/documentation_policy.md`.

---

## 2. Restrições do Compilador Delphi (Object Pascal)

Para evitar quebras de build, observe atentamente as seguintes limitações do compilador:

### 2.1 Limite de 255 Elementos em Strings Literais (Erro E2056)
*   **A Regra:** Nenhuma literal de string delimitada por aspas simples (`'...'`) pode exceder **255 caracteres** em uma única expressão contínua.
*   **Solução:** Se precisar declarar strings longas (como prompts, payloads ou textos longos), divida a string em múltiplos blocos menores e utilize o operador de concatenação `+`.
*   **Exemplo Incorreto (Gera E2056):**
    ```pascal
    LPrompt := 'Esta é uma string excessivamente longa criada por um agente de IA que não se atentou ao limite que o compilador do Delphi impõe para literais de string em uma única declaração contínua de caracteres, ultrapassando facilmente os duzentos e cinquenta e cinco caracteres permitidos na linha...';
    ```
*   **Exemplo Correto (Compila com sucesso):**
    ```pascal
    LPrompt := 'Esta é uma string excessivamente longa criada por um agente de IA que se atentou ao limite ' +
               'que o compilador do Delphi impõe para literais de string em uma única declaração contínua, ' +
               'dividindo o texto com operadores de concatenação para respeitar o limite máximo.';
    ```

### 2.2 Gerenciamento Manual de Memória (Memory Leaks)
*   **A Regra:** O Delphi não possui Garbage Collector (GC) tradicional para objetos (apenas para strings, interfaces e arrays dinâmicos).
*   **Solução:** Sempre que instanciar um objeto localmente, proteja a sua liberação usando um bloco `try..finally` imediatamente após a criação, liberando o objeto no bloco `finally`.
*   **Boas Práticas:** Preferencialmente use o método `.Free` para liberar instâncias locais. Use `FreeAndNil(LObject)` apenas quando a variável puder ser consultada após a liberação.
*   **Exemplo Correto:**
    ```pascal
    LList := TList<string>.Create;
    try
      LList.Add('Item');
      // processamento...
    finally
      LList.Free;
    end;
    ```

### 2.3 Referências Circulares entre Units (Erro F2047)
*   **A Regra:** Duas units não podem fazer referência mútua na seção de `interface`.
*   **Solução:** Se a `UnitA` precisa de tipos da `UnitB`, e a `UnitB` precisa de tipos da `UnitA`, pelo menos uma das referências deve ser colocada na seção `implementation` da unit, nunca na `interface`.

### 2.4 Declaração de Variáveis Locais
*   **A Regra:** Por padrão, declare variáveis locais na seção `var` no cabeçalho do método/função.
*   **Delphi Moderno (10.3+):** Variáveis inline (`var LVar := 10;`) são suportadas pelo compilador dcc32/dcc64 moderno. Contudo, mantenha consistência com a assinatura ao redor no código. Para declarações tradicionais em bloco, garanta que todas estejam no escopo `var` antes do `begin`.

### 2.5 Indexação de Strings (1-Based)
*   **A Regra:** Em Object Pascal para Desktop (VCL), strings são indexadas a partir de 1.
*   **Solução:** Para percorrer os caracteres de uma string de forma segura e compatível, utilize `Low(S)` e `High(S)`.
    ```pascal
    for I := Low(LStr) to High(LStr) do
      ProcessChar(LStr[I]);
    ```

### 2.6 Limite de Parâmetros em Rotinas e Métodos
*   **A Regra:** Nenhuma função ou procedimento (rotina/método) deve possuir mais de **7 parâmetros** em sua assinatura, evitando a violação de acoplamento do SonarQube (`community-delphi:TooManyParameters`).
*   **Solução:** Se um método precisar receber 8 ou mais parâmetros, agrupe-os logicamente em um `record` com um construtor de inicialização `Create` (ou use um objeto de parâmetros).
*   **Exemplo:**
    ```pascal
    TRadIAOAuthParams = record
      AuthUrl: string;
      TokenUrl: string;
      ClientId: string;
      ClientSecret: string;
      Port: Word;
      constructor Create(const AAuthUrl, ATokenUrl, AClientId, AClientSecret: string; const APort: Word);
    end;
    ```

### 2.7 Diretrizes contra Code Smells Comuns (Linter & SonarQube)
Para evitar alertas e manter o dashboard do SonarQube com nota máxima de qualidade, siga estas práticas ao criar e modificar código Object Pascal:

*   **Evite imports na Interface (ImportSpecificity & UnusedImport):** Sempre que possível, coloque as units na cláusula `uses` da seção `implementation`. Declare imports na seção `interface` apenas quando os tipos declarados neles forem estritamente necessários na assinatura pública da unit (como tipos de parâmetros de métodos públicos ou classes ancestrais).
*   **Encapsulamento de Campos de Classe (PublicField):** NUNCA declare campos de variáveis diretamente na seção `public` de uma classe. Mantenha os campos na seção `private` ou `protected` (iniciando com o prefixo `F`) e exponha-os publicamente usando propriedades (`property`).
*   **Tratamento de Rotinas Vazias (EmptyRoutine):** Evite declarar procedimentos ou funções sem código interno (`begin end;`). Se um método precisar ficar vazio por imposição de herança ou callback visual da VCL, adicione um comentário detalhando o motivo (ex: `// Propositalmente vazio para callback...`) ou uma instrução inócua simples (ex: `if True then ;`).
*   **Redução de Complexidade Cognitiva (CognitiveComplexityRoutine):** Mantenha o fluxo de controle de qualquer rotina o mais simples possível. Evite aninhamentos profundos de condicionais (`if`, `try`, `except` e laços `for/while` aninhados). O limite de complexidade cognitiva por rotina é **15**. Se ultrapassar esse limite, refatore a lógica dividindo-a em métodos auxiliares menores com responsabilidade única (*Extract Method*).

---

## 3. Convenções de Nomenclatura (Style Guide)

Siga o padrão clássico de estilo Pascal do Delphi:

| Elemento | Convenção de Prefixo | Exemplo |
| :--- | :--- | :--- |
| **Classes** | Prefixo `T` | `TPromptTemplateManager` |
| **Interfaces** | Prefixo `I` | `IProviderClient` |
| **Records** | Prefixo `T` | `TPromptTemplate` |
| **Campos Privados** | Prefixo `F` | `FTemplates` |
| **Argumentos / Parâmetros** | Prefixo `A` | `const AName: string` |
| **Variáveis Locais** | Prefixo `L` | `LTemplate: TPromptTemplate` |
| **Tipos Genéricos** | Prefixo `T` | `TList<T>` |

### 3.1 Regra de Prefixo do Projeto (RadIA)

*   **Regra Geral:** Toda interface ou classe de domínio que faz parte da lógica central, utilitários, infraestrutura ou UI própria do Rad IA deve incluir o prefixo `RadIA` após o prefixo do tipo (`T` ou `I`).
    *   **Interfaces:** `IRadIA<Nome>` (ex: `IRadIAService`, `IRadIATextNormalizer`).
    *   **Classes:** `TRadIA<Nome>` (ex: `TRadIAService`, `TRadIATextNormalizer`).
*   **Sem Exceções:** Todo o código ativo do Rad IA está totalmente aderente a esta regra de prefixos.

### 3.2 Padrão de Nomenclatura de Arquivos

*   **Regra Geral:** Todos os arquivos de código-fonte (`.pas`) e layouts da interface (`.dfm`) do Rad IA devem seguir o padrão de nomenclatura de namespace em caixa alta/baixa iniciando com `RadIA.`:
    *   Formato: `RadIA.<Modulo>.<NomeDaUnit>.pas`
    *   Exemplos de subdiretórios e namespaces:
        *   **Core (Domínio Central):** `RadIA.Core.<NomeDaUnit>.pas` (ex: [RadIA.Core.Interfaces.pas](file:///d:/Projetos/PluginDelphiIA/Source/Core/RadIA.Core.Interfaces.pas))
        *   **Integration (IDE / Open Tools API):** `RadIA.OTA.<NomeDaUnit>.pas` (ex: [RadIA.OTA.Helper.pas](file:///d:/Projetos/PluginDelphiIA/Source/Integration/RadIA.OTA.Helper.pas))
        *   **Providers (Modelos de IA):** `RadIA.Provider.<Provedor>.pas` (ex: `RadIA.Provider.Gemini.pas`)
        *   **UI (Telas, Frames, Presenters):** `RadIA.UI.<NomeDaTela>.pas` (ex: `RadIA.UI.ChatPresenter.pas`)
*   Nenhum arquivo físico de código fonte ou de layout deve ser criado sem obedecer a esse formato prefixado por `RadIA.`.

### 3.3 Prevenção contra Espaços em Branco Finais (Trailing Whitespaces)

*   **A Regra:** Nenhum arquivo editado ou criado por Agente de IA deve conter espaços em branco adicionais ao final de qualquer linha (trailing whitespaces).
*   **Procedimento de Prevenção:** Antes de finalizar e commitar qualquer alteração, o Agente de IA deve inspecionar e limpar proativamente espaços em branco no final de linhas nos arquivos modificados. Se houver um script utilitário de limpeza (como `scratch/trim-whitespaces.ps1`), ele deve ser executado para garantir conformidade completa antes da build final.

### 3.4 Limite de Comprimento de Linhas (120 caracteres)

*   **A Regra:** Nenhuma linha de código fonte em qualquer arquivo (especialmente arquivos `.pas` e `.js`/`.ts`) deve ultrapassar o limite de **120 caracteres** para evitar alertas e falhas de qualidade no SonarQube.
*   **Solução:** Se uma linha for exceder 120 caracteres, divida a instrução em múltiplas linhas, utilizando quebras apropriadas, endentação correspondente ou operadores de concatenação quando aplicável.
*   **Exemplo Incorreto:**
    ```pascal
    LResult := TSomeVeryLongClassName.Create(LSomeVeryLongParameterName, LAnotherExtremelyLongParameterNameWithDetailedMeaning);
    ```
*   **Exemplo Correto:**
    ```pascal
    LResult := TSomeVeryLongClassName.Create(
      LSomeVeryLongParameterName,
      LAnotherExtremelyLongParameterNameWithDetailedMeaning
    );
    ```

---

## 4. Segurança em Threads (Thread Safety na IDE)

O Rad IA funciona acoplado ao processo principal da IDE do Delphi (`bds.exe`).
*   Qualquer operação demorada (como requisições HTTP às APIs de IA) deve ser executada de forma **assíncrona em background threads**.
*   **Acesso à UI:** Modificações na interface gráfica (VCL/Edge WebView2) a partir de threads secundárias devem obrigatoriamente ser envolvidas em `TThread.Synchronize` ou `TThread.Queue`.
    ```pascal
    TThread.Queue(nil,
      procedure
      begin
        FWebBrowser.Navigate(LUrl);
      end);
    ```

## 5. Ferramentas de Build e Validação

Antes de entregar qualquer tarefa ou código modificado, execute os seguintes passos de validação:

1.  **Executar Build Local:** Execute o arquivo `build.ps1` no PowerShell selecionando a versão apropriada do Delphi para garantir que o pacote principal compila sem erros de sintaxe ou regressões.
    ```powershell
    # Exemplo especificando a versão 12 Athens
    powershell.exe -ExecutionPolicy Bypass -File build.ps1 -DelphiVersion "23.0"
    ```
2.  **Verificar Testes Unitários:** Os testes são omitidos por padrão. Para compilar e rodar a suíte de testes `RadIATests.exe` (DUnitX), passe o parâmetro `-Test`. Certifique-se de que 100% dos testes passem e nenhum vazamento de memória seja detectado.
    ```powershell
    # Exemplo compilando e executando testes
    powershell.exe -ExecutionPolicy Bypass -File build.ps1 -DelphiVersion "23.0" -Test
    ```
3.  **Lint do Frontend (Se aplicável):** Se houver modificações na parte web/UI localizados em `Source/UI/Web`, execute o ESLint na raiz do projeto:
    ```bash
    npx eslint
    ```
    Nenhum erro de linting deve ser deixado para trás.

---

## 6. Ciclo de Vida e Gerenciamento de WebView2 (TEdgeBrowser) no Shutdown

O Rad IA roda acoplado ao processo da IDE (`bds.exe`). A integração com a WebView2 (`TEdgeBrowser`) exige cuidados extremos no encerramento da IDE para evitar deadlocks COM e Access Violations em `rtl290.bpl`:

### 6.1 Instanciação com Owner nulo (`nil`)
*   **Regra:** Qualquer componente `TEdgeBrowser` (ou descendente que faça interface COM com WebView2) criado dinamicamente deve ser instanciado passando `nil` como Owner em vez de `Self` ou do Parent Form/Frame.
*   **Exemplo:**
    ```pascal
    EdgeBrowser := TEdgeBrowser.Create(nil); // Correto: evita destruicao automatica forçada pela VCL
    ```
*   **Por que:** Se for criado com `Self` (o Frame/Form) como Owner, o destrutor ancestral da VCL (`inherited Destroy`) forçará a liberação síncrona do componente. No shutdown da IDE, o loop de mensagens da thread principal está desativando e chamadas de destruição COM síncronas travam a IDE por tempo indeterminado ou geram crash.

### 6.2 Supressão do `.Free` no Shutdown da IDE
*   **Regra:** Nos destrutores (`Destroy`) e manipuladores de janela (`DestroyWnd`), verifique sempre a flag global `GIsShuttingDown`. Se for `True`, **NUNCA** chame `.Free` em instâncias de `TEdgeBrowser`. Apenas defina `Parent := nil` se necessário e ignore a liberação manual.
*   **Por que:** No shutdown da IDE, o próprio Windows cuidará de desalocar os handles, a memória do processo principal `bds.exe` e todos os subprocessos filhos `msedgewebview2.exe` de forma robusta e instantânea. Chamar o destrutor do WebView2 ativamente nesse estágio causa travamento de até 1 minuto.
*   **Exemplo de Destruição Correta:**
    ```pascal
    if not GIsShuttingDown then
    begin
      if Assigned(EdgeBrowser) then
        FreeAndNil(EdgeBrowser);
    end
    else
    begin
      if Assigned(EdgeBrowser) then
        EdgeBrowser.Parent := nil; // Desassocia visualmente sem chamar Free
    end;
    ```

### 6.3 Pinning da BPL do Plugin
*   **Regra:** O plugin incrementa a contagem de referência do módulo BPL no construtor do Wizard (`TRadIAWizard.Create`) via `GetModuleHandleEx` e decrementa no `Destroy` apenas se `not GIsShuttingDown`.
*   **Por que:** Isso garante que o código executável da BPL permaneça mapeado na memória física do Delphi mesmo se a IDE fechar enquanto houver threads assíncronas de background finalizando suas operações de rede, evitando Access Violations por endereços de memória inválidos.

---

## 7. Integração e Validação do SonarQube

*   **A Regra:** NUNCA use subagentes de navegador, ferramentas de visualização de páginas web ou leitores de HTML para interagir com o SonarQube local ou para verificar o status de qualidade do código.
*   **A Abordagem:** Qualquer consulta a relatórios, métricas ou issues do SonarQube deve ser executada exclusivamente por meio de chamadas à **API REST local do SonarQube** (usando PowerShell ou requisições HTTP). Utilize as chaves/tokens de autenticação definidos com segurança no arquivo `.env` ou na pasta de rascunhos (scratch).

### 7.1 Proibição de Bypasses e Supressões (NOSONAR)
*   **A Regra:** É terminantemente **PROIBIDO** o uso de comentários de supressão como `// NOSONAR` ou `{NOSONAR}` em qualquer arquivo do projeto para ocultar alertas do SonarQube.
*   **Por que:** Ocultar problemas arquiteturais ou de nomenclatura quebra as diretrizes do *Clean Code* e introduz a regra penalizadora `community-delphi:NoSonar`, multiplicando as advertências. O Agente deve sempre **resolver a causa raiz** (renomeando a variável adequadamente, excluindo o código morto ou fatiando o método), mesmo que isso exija refatoração de componentes visuais `.dfm` ou a criação de *wrappers* nativos.
