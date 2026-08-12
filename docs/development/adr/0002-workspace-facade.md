# ADR 0002: Fachada de workspace com serviços segregados

- Status: Aceito
- Data: 2026-08-02

## Contexto

O contrato atual `IRadIAIDEAdapter` atende operações editoriais existentes, mas a evolução agentiva
precisa cobrir projeto, editor, build, debugger e Form Designer. Expandir indefinidamente uma única
interface produziria uma abstração monolítica e difícil de testar.

## Decisão

Será criada uma fachada de workspace que coordena serviços segregados por responsabilidade:

- Estado da IDE.
- Leitura e escrita do editor.
- Leitura e escrita do projeto.
- Build e execução.
- Debugger.
- Form Designer vivo.

As implementações OTA ficarão em `Source/Integration`. O Core dependerá apenas das interfaces.

O contrato atual será preservado durante a migração e adaptado gradualmente. Não haverá uma
substituição ampla em uma única entrega.

## Consequências

### Positivas

- Reduz acoplamento com OTA.
- Permite fakes pequenos e determinísticos.
- Facilita detectar capacidades por versão.
- Evita uma interface com responsabilidades excessivas.
- Permite migração incremental.

### Negativas

- Mais contratos e wiring no container.
- Algumas operações exigirão coordenação entre serviços.
- Haverá período de convivência com o adaptador atual.

## Alternativas rejeitadas

### Expandir `IRadIAIDEAdapter`

Rejeitada por violar segregação de interfaces e concentrar responsabilidades.

### Expor interfaces OTA diretamente às ferramentas

Rejeitada por contaminar o Core, dificultar testes e espalhar diferenças entre versões da IDE.
