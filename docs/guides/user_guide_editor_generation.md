# Guia de Uso: Integração com Editor & Geração de Código

Este guia detalha como utilizar os recursos do **Rad IA** integrados ao editor de código do Embarcadero Delphi, bem como as ferramentas de geração automática de DTOs, documentação e projetos completos.

---

## 1. Ações de Contexto no Editor

O Rad IA conecta-se nativamente ao editor de código do Delphi usando a Open Tools API (OTA). Você pode acionar a inteligência artificial para trechos específicos de código diretamente no editor.

### Como Utilizar:
1. No editor de código da IDE, **selecione** o trecho de código que deseja analisar ou modificar.
2. Clique com o **botão direito** sobre a seleção.
3. No topo do menu pop-up, abra a categoria **Rad IA** e selecione uma das seguintes ações:
   * **Explicar Código Selecionado (`/explain`):** Analisa didaticamente a lógica, explicando o fluxo de execução e a finalidade de algoritmos complexos.
   * **Otimizar/Refatorar (`/refactor`):** Reescreve o código visando performance, legibilidade e aplicação de padrões Clean Code e SOLID.
   * **Localizar Bugs (`/bugs`):** Executa uma varredura em busca de memory leaks (ausência de try..finally), exceções não tratadas e falhas de lógica.
   * **Gerar Testes Unitários (`/test`):** Gera automaticamente classes e métodos de testes estruturados baseados no framework DUnitX.
   * **Criar Implementação a partir de Comentário:** Com o cursor dentro de um método vazio que
     contenha um comentário em linguagem natural, gera diretamente a implementação delimitada.

A criação de implementação é uma ação explícita do editor. Ela aguarda o chat terminar de carregar,
envia a solicitação diretamente ao provider configurado e não cria nem solicita aprovação de um plano,
mesmo quando o modo Agent está habilitado. A implementação substitui somente o método vazio originalmente
capturado. Se esse método mudar enquanto a resposta é gerada, o Rad IA cancela a aplicação sem inserir código
na posição atual do cursor.

> O submenu **Rad IA** é inserido no topo do menu contextual do editor após a IDE montar os itens nativos, mantendo compatibilidade com Delphi 12/13 e com menus adicionados por outros plugins.

---

## 2. Comparador Visual Inteligente (Smart Diff)

Quando você solicita refatorações ou otimizações de código, o Rad IA não altera seu arquivo original imediatamente. Ele apresenta as alterações em uma interface comparativa premium lado a lado.

<p align="center">
  <img src="images/radia_diff_ui_mockup.png" alt="Rad IA Smart Diff UI" width="90%" />
</p>

### Funcionamento e Fluxo:
* **Visualização Lado a Lado**: A janela do Smart Diff exibe o código original à esquerda (com destaque vermelho para deleções) e a proposta de código da IA à direita (com destaque verde para adições).
* **Aceite por bloco**: Cada bloco alterado possui as ações **Aceitar** e **Rejeitar**. O contador
  informa quantos blocos fazem parte da versão que será aplicada.
* **Navegação**: Os botões **Anterior** e **Próximo** percorrem apenas os blocos modificados.
* **Botão [Aplicar Selecionados]**: Aplica ao editor somente a combinação de blocos aceita. Se todos
  forem rejeitados, o botão permanece desabilitado.
* **Segurança**: Caso desista das alterações, basta fechar o painel de comparação. O arquivo original permanecerá intocado.

O Smart Diff sempre inicia com todos os blocos aceitos. Rejeite os blocos que não deseja, revise o
resultado e só então aplique. Se o conteúdo original tiver mudado enquanto a janela estava aberta,
o Rad IA interrompe a aplicação para evitar sobrescrita ou duplicação.

---

## 3. Geração Automática de Documentação XML

O Rad IA permite documentar classes e métodos seguindo o padrão XML padrão do Delphi, alimentando diretamente o recurso **Help Insight** da IDE (exibição de dicas de documentação ao posicionar o mouse sobre um método).

### Como Utilizar:
1. Posicione o cursor sobre o cabeçalho de um método ou propriedade (na interface ou implementation).
2. Clique com o botão direito e escolha **Rad IA -> Documentação XML Automática** (ou digite `/doc` no chat lateral).
3. A IA gerará a estrutura XML e o Rad IA a inserirá logo acima do método correspondente.

### Exemplo de Saída:
```pascal
/// <summary>
///   Calcula o total de vendas do período aplicando descontos e impostos locais.
/// </summary>
/// <param name="AStartDate">Data de início da apuração</param>
/// <param name="AEndDate">Data final da apuração</param>
/// <returns>Valor total calculado em moeda corrente</returns>
function CalculatePeriodTotal(const AStartDate, AEndDate: TDateTime): Currency;
```

---

## 4. Conversor de DTO e Modelos

Escrever classes de transferência de dados (DTOs) ou mapeamentos ORM manualmente a partir de payloads JSON ou tabelas de bancos de dados consome muito tempo. O Rad IA automatiza isso.

### Como Utilizar:
1. Cole o payload JSON ou o script DDL SQL no chat lateral.
2. Utilize o comando barra `/dto [formato]` (ex: `/dto vanilla` ou `/dto dext`).
3. Formatos Suportados:
   * **Vanilla Delphi**: Classes puras Pascal com getters/seters convencionais e propriedades.
   * **DEXT ORM**: Modelagem de entidades prontas para persistência usando atributos do framework DEXT.
   * **TMS Aurelius**: Classes mapeadas usando atributos específicos do framework Aurelius.
   * **REST.Json**: Classes com anotações de conversão do framework nativo REST de manipulação de JSON do Delphi.

---

## 5. Geração de Projetos Delphi Inteiros via Prompt

Uma das ferramentas mais poderosas do Rad IA é a habilidade de estruturar e salvar um projeto Delphi do zero a partir de uma descrição textual informal no chat.

### Como utilizar

O fluxo funciona mesmo quando o Delphi foi aberto sem projeto. Um pedido natural como **“faça uma
calculadora básica”** ou **“crie uma calculadora com operações básicas em VCL”** inicia
automaticamente a jornada guiada de criação. O RadIA pergunta somente os dados ausentes — nome,
pasta de destino e plataforma — antes de apresentar o plano para aprovação.

1. No chat lateral do Rad IA, solicite a criação de um projeto. Exemplo:
   > *"Gere um projeto de console que consuma uma API de clima e salve as informações em arquivos JSON locais."*
   *(Você também pode utilizar o comando barra `/createproject` ou `/createprojectarch` para estruturas seguindo Clean Architecture).*
2. A IA processará a requisição e retornará a lista completa de arquivos estruturados (projeto `.dpr`,
   configurações `.dproj`, unidades de lógica `.pas` e telas `.dfm`). Para calculadoras VCL, o
   compositor nativo já fornece visor, teclado e operações básicas funcionais.
   Se o pedido mencionar histórico, a especificação inclui esse recurso explicitamente e o projeto
   recebe uma lista ordenada de operações e a ação **Clear history**.
3. O Rad IA exibirá um painel com estilo *glassmorphism* contendo a lista dos arquivos gerados.
4. **Fluxo de Gravação**:
   * Clique em **Criar Projeto e Abrir na IDE** na UI do chat.
   * Um diálogo nativo do Windows será exibido para você selecionar a pasta de destino.

> [!IMPORTANT]
> **Gravação Segura de Projetos:**
> Por medidas de segurança e para evitar sobregravações acidentais de código existente, a pasta selecionada para a geração do projeto **deve estar totalmente vazia**. O Rad IA bloqueará o processo de gravação física no disco caso a pasta possua quaisquer outros arquivos.

5. **Abertura e validação na IDE**: após a gravação, o RadIA abre o `.dproj`, confere estruturalmente
   os requisitos, compila pelo próprio Delphi e corrige erros dentro dos limites aprovados. O aplicativo
   só é iniciado quando o usuário pede explicitamente execução ou validação funcional. A conclusão
   distingue criação, build e eventual resultado runtime.

O CLI externo não precisa localizar `msbuild` no `PATH` para esse fluxo. A criação, o build e a
execução opcional são conduzidos pelas ferramentas nativas do RadIA. Quando um CLI participa da análise, o
chat mostra uma atividade expansível com etapa atual, tempo decorrido e saída técnica.

Links de projeto abrem o arquivo na IDE. Links web são enviados ao navegador padrão e nunca
substituem a superfície principal do chat; assim, o usuário não fica preso em uma página sem
controle de retorno.

Ao navegar para um símbolo, o RadIA consulta primeiro o índice estrutural do projeto, incluindo outras
units e membros herdados. Se o índice estiver indisponível ou não localizar o nome, a navegação volta ao
scanner limitado da unit ativa. A operação continua confinada aos projetos carregados na IDE.
