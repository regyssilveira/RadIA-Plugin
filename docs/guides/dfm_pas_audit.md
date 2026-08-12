# Auditoria de consistência DFM/PAS

O RadIA compara o form ativo com sua unit Pascal sem carregar componentes nem modificar arquivos. A
auditoria identifica divergências que normalmente causam erros de streaming, handlers desconectados ou
campos incompatíveis no Form Designer.

## Executar a auditoria

Abra o form no Designer e execute:

```text
/tool AuditActiveDfmPasConsistency
```

Cada achado contém código estável, severidade, arquivo (`dfm` ou `pas`), linha, nome e mensagem. A
versão atual detecta:

- classe raiz diferente entre DFM e Pascal;
- componente sem campo Pascal ou campo com classe diferente;
- campo de componente sem objeto correspondente no DFM;
- evento apontando para método ausente;
- assinatura incompatível nos eventos de notificação comuns;
- método que parece ser handler de componente, mas não está associado no DFM.

O parser é deliberadamente limitado: lê no máximo 2 MiB por arquivo e produz até 500 achados. Ele não
instancia o form, não executa código e não interpreta propriedades arbitrárias.

## Preparar uma correção

As correções automáticas estão restritas aos casos determinísticos `missing_event_handler` e
`missing_component_field`. Para preparar uma preview:

```text
/tool PrepareDfmPasAuditFix
```

Informe `findingCode` e `name` exatamente como retornados pela auditoria. A tool cria uma preview no
serviço de patches, mas não altera o arquivo. Revise e aplique com `ApplyPatch`; reverta com
`RevertPatch`.

Se o buffer mudar após a preview, a aplicação falha com `precondition_failed` e nenhuma alteração é
feita. Classes divergentes, handlers incompatíveis e itens órfãos exigem decisão humana e não recebem
correção automática.

## Recuperação

- `form_unavailable`: abra um form no Designer.
- `resource_limit`: reduza o tamanho do DFM ou da unit para menos de 2 MiB.
- `fix_unavailable`: execute novamente a auditoria e confira código e nome; o achado pode não ser
  corrigível automaticamente.
- `precondition_failed`: o buffer mudou; descarte a preview e prepare outra a partir do estado atual.
