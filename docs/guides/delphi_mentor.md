# Mentor Delphi

O Mentor Delphi adapta a explicação ao nível do usuário sem transformar código do projeto em material
didático persistente. Selecione um trecho no editor e peça a explicação no chat ou execute
`ExplainSelectedDelphiCode` com um dos perfis:

- `beginner`: apresenta sintaxe, ownership, comportamento em runtime e um próximo passo seguro;
- `cross-language`: compara o trecho com conceitos de linguagens gerenciadas e destaca diferenças;
- `experienced`: concentra-se em contratos, lifetime, framework, compilador e trade-offs.

A resposta identifica ownership, VCL/FMX, vínculo DFM/FMX e packages, anexando regras curadas com
citações estáveis. A seleção é limitada a 12.000 caracteres, usada somente na resposta corrente e
nunca gravada pelo Mentor (`retained: false`).

Sem seleção, a ferramenta recusa a execução em vez de capturar implicitamente o arquivo inteiro. O
perfil é informado a cada chamada; ele não cria histórico nem preferência oculta.
