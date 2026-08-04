# Operações estruturais de projeto

O RadIA pode criar units, forms VCL e forms FMX, bem como retirar um arquivo do projeto ativo.
Essas operações seguem preview, consentimento, auditoria e reversão.

## Criação de unit ou form

1. `PrepareAddProjectFile` recebe `unitName`, `kind` (`unit`, `vclForm` ou `fmxForm`) e
   `relativeDirectory`.
2. O resultado mostra todos os paths, conteúdos e hashes, sem escrever no disco.
3. `ApplyProjectFileChange` recebe o `previewId`.
4. O RadIA grava os arquivos em staging, publica todos e somente então registra o `.pas` no projeto.
5. `RevertProjectFileChange` desregistra o `.pas` e remove somente os arquivos criados pela própria
   transação.

Os arquivos não são abertos automaticamente, evitando mudança de foco durante uma execução do agente.

## Retirada de arquivo do projeto

1. `PrepareRemoveProjectFile` recebe `fileName`.
2. `ApplyProjectFileChange` desregistra o arquivo do projeto.
3. O arquivo permanece no disco.
4. `RevertProjectFileChange` registra o mesmo arquivo novamente.

Esse fluxo não oferece exclusão física genérica. Apagar um arquivo preexistente exige uma operação
destrutiva explícita, que não é inferida a partir de “remover do projeto”.

## Garantias

- paths confinados à raiz do projeto ativo;
- nenhum overwrite de arquivo existente;
- criação física antes do registro OTA;
- limpeza integral quando o registro falha;
- remoção lógica antes de qualquer eventual limpeza de disco;
- execução OTA sincronizada com a thread principal da IDE.
