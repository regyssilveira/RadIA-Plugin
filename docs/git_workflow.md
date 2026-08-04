# Commit Git revisável

O RadIA cria somente commits locais e nunca executa push automaticamente. O fluxo separa leitura,
preview e mutação:

1. `GetGitStatus` mostra alterações limitadas ao projeto ativo.
2. `GetGitDiff` mostra o diff dos paths escolhidos.
3. `PreviewGitCommit` recebe paths explícitos e uma mensagem, sem alterar o index.
4. `CommitChanges` recebe apenas o `previewId`, exige consentimento e cria o commit local.

## Precondições

- É obrigatório existir um projeto Delphi ativo dentro de um work tree Git.
- Todos os paths precisam permanecer dentro da raiz do projeto.
- Não pode haver alterações previamente staged, inclusive fora da subpasta do projeto.
- A mensagem deve ter uma linha e entre 1 e 500 caracteres.
- O preview aceita no máximo 100 paths.
- Alterações tracked, untracked e removidas participam do fingerprint.

O preview contém paths normalizados, mensagem, diff e fingerprint. Arquivos untracked também
aparecem como diff de arquivo novo. Antes do commit, o RadIA recalcula o fingerprint; qualquer
mudança concorrente retorna `precondition_failed`.

## Segurança do index

O RadIA não oferece reset destrutivo, descarte de arquivos, force push ou push. Durante o commit,
somente os paths revisados são adicionados. Se o `git commit` falhar, o RadIA remove do index apenas
esses paths, que não estavam staged antes do fluxo. O conteúdo do working tree não é descartado.

`CommitChanges` possui risco de escrita estrutural e passa pelo mesmo consentimento e audit log das
demais tools agentivas.
