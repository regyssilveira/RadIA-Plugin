# Diff visual do Form Designer

O RadIA captura snapshots estruturais locais do form ativo e compara um estado anterior com um estado
proposto. A comparação foi desenhada para aparecer como uma única etapa antes/depois na timeline do
agente, sem persistir conteúdo do projeto nem alterar o Designer ao aceitar ou rejeitar a revisão.

## Fluxo

1. Com o form aberto, execute `CaptureDesignerVisualSnapshot` antes da proposta.
2. Faça ou prepare a alteração autorizada pelas tools do Designer.
3. Execute `CaptureDesignerVisualSnapshot` novamente.
4. Passe os dois identificadores para `CompareDesignerVisualSnapshots`.
5. Revise `changes` e decida com `DecideDesignerVisualDiff`.
6. Ao terminar, execute `ClearDesignerVisualDiffArtifacts`.

A comparação informa componentes criados e removidos, mudança de classe ou parent, movimento,
redimensionamento, seleção e alterações nas propriedades permitidas `Caption`, `Text`, `Align`,
`Visible`, `Enabled` e `TabOrder`. Cada mudança contém os objetos `before` e `after`, prontos para a
timeline renderizar lado a lado.

## Retenção e privacidade

- snapshots e comparações permanecem somente na memória do processo da IDE;
- no máximo 20 snapshots e 20 comparações são mantidos; o mais antigo é descartado primeiro;
- cada captura contém no máximo 1.000 componentes;
- caminhos de arquivos, código Pascal, conteúdo DFM e propriedades fora da allowlist não são copiados;
- esta versão não grava capturas raster em disco nem envia imagens automaticamente a providers.

O Form Designer é consultado na thread principal pela fachada OTA. Chamadas iniciadas em background são
sincronizadas antes de ler componentes e propriedades.

## Decisão e conflitos

Uma comparação começa em `prepared` e só pode receber uma decisão: `accepted` ou `rejected`. Repetir a
decisão produz conflito e não muda o Designer. A decisão registra `designerMutated=false`: aplicar ou
reverter a alteração real continua sendo responsabilidade das tools transacionais que originaram a
proposta. Assim, rejeitar a comparação por si só nunca escreve no form.

Se um snapshot tiver expirado pela retenção, pertencer a outro form ou tiver sido limpo, gere duas novas
capturas a partir do estado atual.
