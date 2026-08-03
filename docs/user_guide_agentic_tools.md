# Guia de uso das ferramentas agentivas

## Visão geral

O RadIA pode transformar uma solicitação do chat em chamadas estruturadas de ferramentas da IDE.
Chat e MCP usam o mesmo catálogo, as mesmas políticas de segurança e a mesma auditoria.

Consulte o [catálogo de ferramentas](tool_catalog.md) para nomes, parâmetros e níveis de risco.

## Fluxo de uma operação

1. O usuário descreve o resultado desejado.
2. O RadIA seleciona uma ferramenta compatível com o contexto atual.
3. Operações de leitura são executadas dentro do workspace autorizado.
4. Operações mutáveis exibem escopo, risco e resumo antes da execução.
5. Alterações revisáveis apresentam preview e validam as precondições.
6. O resultado ou erro estruturado retorna ao chat.
7. A decisão e a execução são registradas na auditoria sanitizada.

## Consentimento

- **Allow once:** permite somente a operação apresentada.
- **Allow session:** reutiliza a decisão apenas para a mesma sessão, projeto, ferramenta e escopo.
- **Deny:** recusa a operação sem modificar a IDE ou o workspace.
- **Cancel:** solicita o cancelamento de uma operação em andamento.

Uma autorização não é global. Mudanças de projeto, ferramenta, escopo ou nível de risco podem exigir
novo consentimento. Operações destrutivas nunca reutilizam uma permissão de menor risco.

## Leitura e mutação

Ferramentas de leitura consultam editor, projeto, build, debugger, Designer e conhecimento sem
alterar o estado. Ferramentas mutáveis podem:

- preparar, aplicar e reverter patches no editor;
- adicionar ou remover itens do projeto;
- iniciar ou cancelar builds;
- alterar componentes, propriedades, eventos e layout no Designer;
- controlar execução, breakpoints e watches no debugger.

Patches verificam arquivo, trecho original e hash-base. Se o documento mudou desde o preview, a
aplicação é recusada e deve ser preparada novamente.

## Exemplos de solicitações

- “Liste as units do projeto e indique dependências circulares.”
- “Prepare um patch para extrair este método, mas não aplique ainda.”
- “Compile o projeto ativo e resuma erros e warnings.”
- “Mostre os componentes do formulário ativo.”
- “Adicione um breakpoint nesta linha e mostre o estado do debugger.”
- “Pesquise onde `IRadIAToolRegistry` é implementada no projeto.”

Se faltar um projeto, arquivo, formulário ou sessão de depuração ativa, a ferramenta retorna uma
falha segura e explica a precondição ausente.

## Auditoria e privacidade

A auditoria fica em `%APPDATA%\RadIA\audit\tools.jsonl`. Credenciais e campos sensíveis são
sanitizados antes da gravação. O arquivo registra ferramenta, decisão, escopo e resultado, mas não
deve ser usado para armazenar secrets ou conteúdo integral desnecessário.

Para detalhes de risco e confinamento, consulte o
[modelo de segurança](tool_security_model.md).
