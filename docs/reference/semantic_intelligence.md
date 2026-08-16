# Inteligência semântica no editor

Esta página separa as capacidades semânticas que o RadIA entrega hoje, a forma de acioná-las e os
limites que não devem ser confundidos com recursos nativos do Delphi.

## Resumo verificável

| Capacidade | Estado atual | Como usar |
|---|---|---|
| Índice semântico Pascal/DFM | Disponível | É iniciado pelo RadIA e usado automaticamente pelas consultas semânticas. |
| Contexto de tipo e membros herdados | Disponível | Peça ao agente para explicar um tipo ou use `/tool GetSemanticContext`. |
| Referências confirmadas | Disponível | Peça “localize as referências de `TSimbolo`” ou use `/tool FindSymbolReferences`. |
| Hierarquia de tipos | Disponível | Peça ancestrais ou descendentes de um tipo ou use `/tool GetTypeHierarchy`. |
| Membros de interface ausentes | Disponível com preview | Peça para implementar os contratos ausentes; o agente usa `PrepareMissingMembers`. |
| Conclusão local após `.` | Disponível no Ghost Text | Solicite Ghost Text após um acesso a membro; uma continuação inequívoca pode ser resolvida localmente. |
| Popup nativo do CodeInsight | Não é substituído | O RadIA não injeta candidatos na lista nativa de completion do Delphi. |
| Refatorações semânticas | Disponível com preview | Peça rename, change signature, extract method ou move type. |
| Navegação para uma ocorrência | Disponível | Depois de uma consulta, o agente usa `NavigateToFile`; a ação abre um arquivo do projeto carregado. |

“Disponível” significa que a capacidade possui implementação conectada à IDE e testes próprios. Não
significa que toda expressão Pascal possível será resolvida. Resultado ambíguo é informado ou segue
para um fallback seguro; não é tratado como certeza.

## Conclusão local e Ghost Text

O fluxo de assistência inline é diferente do popup nativo do CodeInsight:

1. o RadIA captura o contexto autorizado do editor;
2. depois de um acesso a membro, como `Form.Sa`, consulta primeiro o índice local;
3. filtra o prefixo, considera herança, remove duplicidades e limita a lista;
4. se existir uma continuação inequívoca, mostra a sugestão como Ghost Text sem chamar o provider;
5. se o resultado estiver vazio, ambíguo ou indisponível, usa a rota FIM configurada.

Portanto, a conclusão semântica local reduz chamadas de IA em casos determinísticos, mas não estende
nem substitui a lista visual do CodeInsight. Para ativar, abra **Settings > Editor Assistance**, marque
**Enable ghost text (inline completion)** e use **Solicitar sugestão** ou o atalho configurado. Veja
[Assistência inline e FIM](../guides/inline_completion.md).

## Consultas pelo chat ou agente

O usuário pode pedir a operação em linguagem natural. Os nomes abaixo também permitem execução
explícita por `/tool` e ajudam a reconhecer o cartão de consentimento ou o histórico da execução.

| Objetivo | Pedido sugerido | Tool principal | Efeito |
|---|---|---|---|
| Entender um tipo | “Explique `TMinhaClasse`, incluindo membros herdados.” | `GetSemanticContext` | Somente leitura. |
| Localizar usos | “Localize todas as referências de `TMinhaClasse`.” | `FindSymbolReferences` | Somente leitura. |
| Ver herança | “Mostre ancestrais e descendentes de `TMinhaClasse`.” | `GetTypeHierarchy` | Somente leitura. |
| Abrir ocorrência | “Abra a segunda referência encontrada.” | `NavigateToFile` | Navegação reversível na IDE. |
| Implementar contratos | “Implemente os membros de interface ausentes em `TMinhaClasse`.” | `PrepareMissingMembers` | Gera preview; aplicar exige consentimento. |
| Renomear símbolo | “Renomeie `OldName` para `NewName` com preview.” | `PrepareRenameSymbol` | Preview multiarquivo e rollback. |
| Alterar assinatura | “Adicione este parâmetro e atualize as chamadas.” | `PrepareChangeSignature` | Preview multiarquivo e rollback. |

Quando há homônimos, informe também a unit. Referências candidatas não são apresentadas como
confirmadas. Comentários, strings e trechos desativados por diretivas não contam como referências.

## O que `PrepareMissingMembers` cobre

`PrepareMissingMembers` localiza contratos de interfaces ainda não implementados pela classe alvo e
prepara declarações e corpos idempotentes. A preparação não altera arquivos. O patch só é aplicado
depois de revisão e consentimento e pode ser revertido.

A tool não é um gerador genérico para qualquer método imaginado pelo modelo e não substitui o
compilador. Ambiguidade estrutural, arquivo fora do workspace, revisão desatualizada ou contrato já
satisfeito produzem estados distintos em vez de uma escrita silenciosa.

## Provas reproduzíveis e seu alcance

A validação pública usa os seguintes comandos na raiz do repositório:

```powershell
npm run test:semantic-corpus:12
npm run test:semantic-corpus:13
npm run test:semantic-completion:12
npm run test:semantic-completion:13
npm run test:semantic-members:12
npm run test:semantic-members:13
```

O corpus semântico verifica parsing e cobertura exata de tokens sobre fontes RTL/VCL instaladas com
Delphi 12 e 13. O benchmark de completion mede a consulta local do motor por contêiner e prefixo. Ele
não mede a latência ponta a ponta da UI, captura OTA, provider, rede ou modelo. Os probes de membros
compilam casos de linguagem e aplicações VCL; não prometem cobertura de toda biblioteca de terceiros.

Na linha-base validada em 16 de agosto de 2026, os corpora processaram 677 de 677 arquivos no Delphi
12 e 689 de 689 no Delphi 13 com cobertura exata dos tokens. As consultas resolveram 2.000 de 2.000
sites em cada IDE, com p95 local de 0,23 ms e 0,26 ms, respectivamente. Esses números são evidência do
motor no ambiente medido, não uma garantia de latência em qualquer máquina.

## Limites e diagnóstico

- Delphi 12 Win32, Delphi 13 Win32 e Delphi 13 IDE64 formam a matriz suportada.
- Código incompleto, macros complexas, símbolos externos não indexados e tipos ambíguos podem exigir
  contexto adicional ou fallback para o provider.
- O motor semântico funciona fora do processo da IDE; sua indisponibilidade não deve travar o editor.
- Ações de leitura não modificam o projeto. Preparações geram preview; aplicações exigem consentimento.
- Use `/doctor --deep` para verificar o processo semântico e **Show Inline Completion Route Status**
  para entender a última rota do Ghost Text.

Para a lista de todas as tools, consulte [Ferramentas internas](internal_tools_reference.md). Para as
operações transacionais, consulte [Refatoração semântica](../guides/semantic_refactoring.md).
