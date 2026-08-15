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
