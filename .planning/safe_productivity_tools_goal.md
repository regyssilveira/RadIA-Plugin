# Goal — Ferramentas de Produtividade Seguras

> **Estado:** concluído. **Baseline:** RadIA 2.12.3. **Matriz:** Delphi 12 Win32 e Delphi 13
> Win32/IDE64, com compilação dos targets Win64 aplicáveis.

## Resultado esperado

O RadIA deve gerar documentação de API e mocks para testes sem alterar silenciosamente código
existente. Toda saída deve nascer como preview revisável, permanecer confinada ao projeto ativo e
ser aplicada somente após consentimento explícito.

## Base reutilizada

- índice semântico estrutural e leitura autorizada do workspace;
- previews, fingerprints, consentimento, aplicação transacional e reversão;
- catálogo interno de ferramentas compartilhado por chat e MCP;
- geração e registro seguros de arquivos de projeto;
- build Delphi e runner DUnitX como gates verificáveis.

## Princípios de baixo risco

1. Nenhuma etapa sobrescreve arquivos existentes por padrão.
2. Geração e aplicação são operações separadas.
3. A preview informa paths, conteúdo, origem e fingerprint.
4. Paths permanecem dentro da raiz do projeto ativo.
5. Falha de análise não produz saída parcial tratada como válida.
6. O usuário escolhe explicitamente se um arquivo gerado será registrado no projeto.
7. Reaplicar a mesma operação não duplica arquivos, declarations ou registros no projeto.

## Etapas e gates

| Marco | Entrega | Gate de conclusão |
| :--- | :--- | :--- |
| M0 | contrato, backlog e testes de arquitetura | documentação bilíngue e limites protegidos por testes |
| M1 | inventário da API pública | símbolos públicos exportados com origem, assinatura e visibilidade |
| M2 | preview de `API.md` | Markdown determinístico, paths confinados e nenhuma escrita |
| M3 | aplicação de `API.md` | criação consentida, conflito explícito e reversão verificável |
| M4 | inventário de contratos mockáveis | interfaces e métodos suportados com diagnósticos de limitações |
| M5 | preview de mocks | unit Pascal determinística, isolada e sem registro automático |
| M6 | aplicação opcional de mocks | consentimento, registro opcional, build e DUnitX aprovados |
| M7 | documentação e experiência | catálogo, guias, hints e exemplos bilíngues completos |
| M8 | validação final | Delphi 12/13, testes, Sonar e documentação aprovados |

## Fora do escopo

- alterar assinaturas ou implementações existentes;
- gerar mocks de classes sem contrato estável ou métodos não virtuais por heurística;
- sobrescrever `API.md` ou units de mocks sem revisão explícita;
- executar testes ou builds sem solicitação ou gate previamente aprovado;
- revisão automática ao salvar, Clean Uses e demais itens do backlog recuperado.

## Condição de conclusão

O goal termina quando um usuário consegue selecionar um escopo, revisar e criar um `API.md`
determinístico e gerar mocks compiláveis para contratos suportados, sem qualquer mutação anterior ao
consentimento. Conflitos, símbolos não suportados e arquivos existentes devem produzir diagnóstico
acionável, preservando o projeto original.
