# Refatoração semântica segura

O RadIA localiza e renomeia símbolos Delphi pela identidade do índice semântico, não por substituição
textual global. Isso evita alterar comentários, strings, código condicional inativo ou homônimos de
outras units.

## Localizar referências

Peça no chat para localizar os usos de um símbolo ou execute `FindSymbolReferences`. Quando houver
homônimos, informe a unit. O resultado apresenta arquivo, linha e coluna e pode ser aberto com
`NavigateToFile`. Ocorrências incertas são marcadas como candidatas e não são tratadas como exatas.

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
