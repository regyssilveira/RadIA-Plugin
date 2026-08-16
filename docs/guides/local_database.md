# Banco de dados local com segurança

O RadIA pode inspecionar arquivos SQLite do projeto e visualizar consultas somente leitura sem
alterar o banco. A jornada atende diagnóstico e desenvolvimento local; ela não substitui um
administrador de bancos nem conecta servidores externos.

## O que pode ser usado

- arquivos `.db`, `.sqlite` e `.sqlite3` dentro do workspace do projeto ativo;
- descoberta de tabelas, views e colunas;
- uma instrução `SELECT`, `WITH` somente leitura ou `PRAGMA` de metadados por execução;
- até 500 linhas e 128 colunas por resultado;
- grid paginado no chat e cópia de CSV já sanitizado.

## Como usar

Peça ao agente para inspecionar o banco ou acione diretamente:

```text
/tool InspectLocalSQLiteDatabase {"path":"data/app.sqlite"}
/tool PreviewLocalSQLiteQuery {"path":"data/app.sqlite","sql":"SELECT id, name FROM customers","maxRows":100}
```

A inspeção do schema é somente leitura. A consulta sempre mostra o diálogo de consentimento antes
da execução. Revise o arquivo, o SQL e o limite e escolha **Allow once** para continuar.

## Proteções aplicadas

- o caminho deve permanecer dentro do workspace e o arquivo deve ter no máximo 512 MB;
- o SQLite é aberto com `READONLY`, `query_only` e `trusted_schema` desativado;
- DDL, DML, transações, múltiplas instruções, comentários, `ATTACH` e extensões são recusados;
- o runtime SQLite deve ser o distribuído com o Delphi 12 ou 13;
- BLOBs não são materializados e aparecem como marcador;
- colunas com nomes associados a senha, segredo, token, chave de API ou credencial aparecem como
  `[redacted]` no grid e no CSV;
- a cópia do CSV usa somente o resultado sanitizado e não grava arquivos automaticamente.

Se o banco estiver fora do workspace, mova uma cópia de trabalho para o projeto. Para mutações,
servidores remotos ou migrações, use uma ferramenta dedicada fora desta jornada.

Veja também [Ferramentas internas](../reference/internal_tools_reference.md) e
[Modelo de segurança](../reference/tool_security_model.md).

Documentação em inglês: [Safe local database](local_database.en.md).
