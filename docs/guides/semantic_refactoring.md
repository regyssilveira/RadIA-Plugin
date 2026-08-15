# Refatoração semântica segura

O RadIA localiza e renomeia símbolos Delphi pela identidade do índice semântico, não por substituição
textual global. Isso evita alterar comentários, strings, código condicional inativo ou homônimos de
outras units.

## Localizar referências

Peça no chat para localizar os usos de um símbolo ou execute `FindSymbolReferences`. Quando houver
homônimos, informe a unit. O resultado apresenta arquivo, linha e coluna e pode ser aberto com
`NavigateToFile`. Ocorrências incertas são marcadas como candidatas e não são tratadas como exatas.

## Consultar a hierarquia de tipos

Peça no chat pela hierarquia de uma classe, interface, record ou helper, ou execute
`GetTypeHierarchy`. A ferramenta retorna o tipo solicitado, seus ancestrais e descendentes com a
profundidade de cada relação. Tipos herdados de RTL, VCL, FMX ou bibliotecas que não pertencem ao
projeto permanecem visíveis como externos, mesmo quando não estão indexados.

Quando duas units declaram tipos com o mesmo nome, informe `unit`. O RadIA interrompe a consulta em
vez de escolher silenciosamente um homônimo. Essa leitura é segura e não modifica arquivos.

```text
/tool GetTypeHierarchy {"type":"TMainForm","unit":"Main"}
```

## Renomear um símbolo

1. `PrepareRenameSymbol` recebe `symbol`, `newName` e, quando necessário, `unit`.
2. O RadIA rejeita nomes inválidos, palavras reservadas, símbolos ambíguos e referências que mudaram
   depois da indexação.
3. A ferramenta prepara um preview único para todas as units e DFMs confirmadas. Arquivos UTF-8
   fechados também são lidos sem exigir que o usuário os abra manualmente.
4. Revise o preview e aprove `ApplyMultiFilePatch`. A aplicação exige consentimento de escrita
   reversível e revalida o hash de cada arquivo antes de qualquer alteração.
5. Se uma escrita falhar, as anteriores são compensadas. Para desfazer depois da aplicação, use
   `RevertMultiFilePatch`.

DFMs binários não são alterados diretamente em disco. Abra o form no Delphi para disponibilizar sua
representação editável ou converta-o para DFM textual antes da renomeação. O RadIA falha de forma
segura quando não consegue obter conteúdo textual completo.

## Exemplo

```text
/tool PrepareRenameSymbol {"symbol":"SaveButtonClick","newName":"HandleSaveClick","unit":"Main"}
```

O retorno contém `previewId`, arquivos afetados e quantidade de substituições confirmadas. Nenhuma
mutação ocorre durante a preparação.

## Alterar a assinatura de uma rotina

Use `PrepareChangeSignature` quando precisar adicionar, remover, renomear, reordenar ou alterar
parâmetros de uma procedure, function, constructor ou destructor. A ferramenta usa a identidade
canônica da rotina para reunir declaração e implementação e só modifica chamadas que o índice
semântico consegue comprovar.

Informe:

- `symbol`: nome simples da rotina;
- `oldSignature`: assinatura atual completa;
- `newSignature`: assinatura desejada completa;
- `unit` e `container`: filtros recomendados para métodos e homônimos;
- `mappings`: pares `oldName`/`newName` que preservam a identidade de parâmetros renomeados ou
  reordenados;
- `bindings`: pares `parameterName`/`expression` para cada parâmetro novo obrigatório.

```text
/tool PrepareChangeSignature {"symbol":"Execute","unit":"Worker","container":"TWorker","oldSignature":"procedure Execute(const AValue: Integer);","newSignature":"procedure Execute(const AInput: Integer; const ATrace: Boolean);","mappings":[{"oldName":"AValue","newName":"AInput"}],"bindings":[{"parameterName":"ATrace","expression":"False"}]}
```

O resultado é somente um preview multiarquivo. Revise e aprove `ApplyMultiFilePatch`; use
`RevertMultiFilePatch` para desfazer. O RadIA bloqueia a preparação quando encontra referência
ambígua, chamada sem lista explícita de argumentos, argumento removido com possível efeito colateral,
arquivo incompleto, limite de referências ou conteúdo alterado depois da indexação. Nesses casos,
desambigue ou ajuste a chamada indicada e repita a operação; nenhuma alteração parcial é aplicada.

## Extrair um método

Selecione no editor um bloco completo dentro da implementação de um método e peça para extrair esse
bloco, ou execute:

```text
/tool PrepareExtractMethod {"methodName":"CalculateTotal"}
```

O RadIA encontra automaticamente a rotina que contém a seleção, localiza sua declaração na classe e
infere os parâmetros de entrada, `const`, `var` e `out`. A preparação substitui o bloco por uma chamada,
adiciona a declaração junto ao método original e cria a implementação antes dele, sempre em um único
preview transacional. Revise e aprove `ApplyMultiFilePatch`; use `RevertMultiFilePatch` para restaurar
exatamente o conteúdo anterior.

A operação é bloqueada quando a seleção é ambígua, atravessa fluxo de controle, usa `Result`, contém
saídas antecipadas, está fora de um método de classe, depende de tipo local implícito ou quando o nome
solicitado já existe. O bloqueio não modifica o arquivo e informa a precondição que precisa ser corrigida.

## Mover um tipo entre units

Use `PrepareMoveType` para mover uma classe, interface, record ou helper de nível superior para outra
unit já pertencente ao projeto:

```text
/tool PrepareMoveType {"symbol":"TWorker","destinationFile":"D:\Projeto\Worker.pas"}
```

A ferramenta resolve uma identidade semântica única, move a declaração e todas as implementações de
métodos pertencentes ao tipo, transporta dependências de `uses` e atualiza somente consumidores
confirmados pelo índice. O retorno é um preview multiarquivo: a preparação não grava nada. Revise e
aprove `ApplyMultiFilePatch`; use `RevertMultiFilePatch` para restaurar exatamente todos os arquivos.

O RadIA bloqueia tipos associados a DFM ou recursos, buffers incompletos, destino homônimo, rotina local
ambígua, dependência privada da implementação de origem, referência candidata e qualquer ciclo detectado
no grafo completo de `uses` da interface. Corrija a precondição informada e prepare novamente.
