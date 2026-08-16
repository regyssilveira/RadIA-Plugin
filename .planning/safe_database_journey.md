# Contrato da jornada segura de banco de dados

## Resultado para o usuário

O RadIA abre somente um banco SQLite localizado dentro do workspace ativo, apresenta tabelas e
colunas, executa consultas de leitura revisadas e mostra o resultado em uma grade paginada. O
resultado pode ser copiado como CSV já sanitizado, sem gravar arquivos ou expor campos sensíveis.

## Limites de segurança

- o arquivo deve existir, ter extensão `.db`, `.sqlite` ou `.sqlite3` e permanecer dentro do
  workspace após normalização e verificação de reparse points;
- a conexão usa `SQLITE_OPEN_READONLY`, `PRAGMA query_only=ON` e `trusted_schema=OFF`;
- somente uma instrução `SELECT`, `WITH ... SELECT` ou PRAGMA de metadados é aceita;
- comentários, múltiplas instruções, anexação de bancos, extensões, transações, DDL e DML são
  rejeitados antes do prepare e novamente pelo `sqlite3_stmt_readonly`;
- consultas têm no máximo 32 KiB, retornam de 1 a 500 linhas e não materializam BLOBs;
- colunas com nomes associados a senha, segredo, token, credencial ou autorização são substituídas
  por `[redacted]` tanto na grade quanto no CSV;
- a biblioteca SQLite deve vir do diretório do processo do Delphi ou do toolchain Embarcadero
  configurado; o workspace e o diretório atual nunca participam da descoberta da DLL;
- nenhuma credencial, conexão remota, escrita, exportação em disco ou SQL arbitrário entra nesta
  entrega.

## Ferramentas

1. `InspectLocalSQLiteDatabase`: valida o arquivo e retorna tabelas, views e colunas sem executar SQL
   fornecido pelo usuário.
2. `PreviewLocalSQLiteQuery`: valida e executa uma consulta read-only com limite estrito, retorna
   linhas sanitizadas e CSV sanitizado para cópia.

## Ameaças e controles

| Ameaça | Controle obrigatório |
|---|---|
| DLL planting | carregamento somente por caminho absoluto confiável |
| escape do workspace | `IRadIAWorkspaceBoundary` e bloqueio de reparse point |
| mutação por SQL disfarçado | conexão read-only, query-only, política léxica e `stmt_readonly` |
| segunda instrução oculta | rejeição de `;` intermediário e validação do tail do prepare |
| vazamento de segredo | mascaramento por nome de coluna antes de serializar ou exportar |
| consumo excessivo | tamanho de SQL, quantidade de objetos, colunas, linhas e bytes limitados |
| injeção na WebView | renderização exclusiva com `textContent` e DOM criado pelo host |

## Gate determinístico

- fixture local com schema, view, valores nulos, Unicode, BLOB e uma coluna sensível;
- schema lido sem alteração do arquivo;
- `SELECT` e CTE retornam dados, respeitam limite e indicam truncamento;
- DDL, DML, ATTACH, PRAGMA mutável, comentários, segunda instrução e arquivo externo são bloqueados;
- grade usa paginação no cliente, não `innerHTML`, e o CSV nunca contém o segredo original;
- DUnitX no Delphi 12 e 13, testes Web, catálogo, documentação, build e Sonar aprovados.
