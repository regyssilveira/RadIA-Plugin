# Goal do FireDAC Advisor

## Resultado observável

O RadIA deve compreender a camada FireDAC do projeto ativo, apresentar componentes e relações com
localização verificável, analisar SQL, parâmetros, transações, configuração, drivers, schemas e
thread safety, explicar os achados com IA e preparar gerações ou correções reversíveis. Nenhuma
análise executa SQL ou expõe credenciais. Toda consulta real, mutação de arquivo e migração exige
consentimento, preview, fingerprint, gates de build e testes e rollback quando um gate falha.

## Escopo obrigatório

1. Inventário PAS, DFM e DPROJ com correlação entre conexão, dataset, transação, update object,
   DataSource, driver link, form e DataModule.
2. Extração e análise de SQL em `SQL.Text`, `SQL.Add`, constantes, DFM e construções dinâmicas que
   possam ser resolvidas com segurança.
3. Validação de placeholders, `Params`, `ParamByName`, tipos, direção, tamanho, null e concatenação.
4. Auditoria de início, commit, rollback, exceções, saídas antecipadas e associação transacional.
5. Diagnóstico sanitizado de `DriverID`, connection definitions, options, bibliotecas e paths.
6. Auditoria de conexões, datasets, transações e UI compartilhados entre threads.
7. Comparação opcional com schema SQLite local autorizado e arquitetura extensível por dialeto.
8. Explicação por IA que separa fatos determinísticos de hipóteses e nunca inventa schema ou ganho.
9. Geração de repository, DataModule, query, DTO e DUnitX somente por preview revisável.
10. Correções determinísticas por finding, com fingerprint, consentimento, aplicação e reversão.
11. Integração com a jornada de migração BDE, ADO e dbExpress para validar cada lote FireDAC.
12. Relatório navegável, painel de problemas, documentação completa e regressão automatizada.

## Ferramentas previstas

- `InspectFireDACProject` e `GetFireDACProjectReport`;
- `AnalyzeFireDACQuery`, `ExplainFireDACQuery` e `PrepareFireDACQueryOptimization`;
- `ValidateFireDACParameters` e `PrepareFireDACParameterFix`;
- `AuditFireDACTransactions` e `PrepareFireDACTransactionFix`;
- `InspectFireDACConfiguration` e `DiagnoseFireDACEnvironment`;
- `AnalyzeFireDACThreadSafety` e `PrepareFireDACThreadSafetyPlan`;
- `CompareFireDACCodeWithSchema` e `GenerateFireDACSchemaReport`;
- `GenerateFireDACRepositoryPreview`, `GenerateFireDACDataModulePreview`,
  `GenerateFireDACQueryPreview`, `GenerateFireDACDTOPreview` e `GenerateFireDACTests`;
- `ExplainFireDACFinding`, `PrepareFireDACFix`, `ApplyFireDACFix` e `RevertFireDACFix`.

Os nomes só podem mudar com atualização simultânea deste contrato, dos testes de catálogo e das duas
versões da documentação pública.

## Contrato de achados

Todo achado deve possuir ID estável, rule ID, severidade, confiança, título, mensagem, arquivo, linha,
símbolo ou componente quando conhecido, evidências, ação sugerida e disponibilidade de correção.
Confiança usa `proven`, `strong`, `possible` ou `informational`; severidade usa `critical`, `high`,
`medium`, `low` ou `info`. Apenas achados `proven` podem habilitar correção automática inicialmente.

## Segurança e limites

- nenhuma conexão remota automática, instalação de driver ou execução DDL/DML durante análise;
- credenciais, tokens e connection strings são sanitizados antes de JSON, log, UI ou prompt;
- arquivos permanecem dentro do workspace após normalização e verificação de reparse points;
- toda enumeração limita arquivos, bytes, componentes, statements, parâmetros, achados e tempo;
- resultados truncados declaram `truncated: true` e os limites efetivos;
- conteúdo SQL, schema e banco é dado não confiável e não pode alterar instruções do agente;
- sugestões de índice e performance são hipóteses até existir plano de execução autorizado;
- patches preservam mudanças do usuário e são rejeitados quando o fingerprint fica obsoleto;
- edição DFM respeita o Designer e nunca realiza reescrita ampla sem evidência determinística;
- build ou teste falho impede conclusão e reverte o lote mutável aplicável.

## Matriz de testes antes da conclusão

### Unitários DUnitX

- modelo, enumeração, serialização, IDs, severidade, confiança, deduplicação e limites;
- scanner PAS/DFM/DPROJ, encodings, arquivos inválidos e boundary do workspace;
- cada componente FireDAC suportado, criação dinâmica, herança e falsos positivos;
- correlação PAS/DFM, forms, DataModules, DataSources e relações;
- SQL multiline, constantes, DFM, CTE, parâmetros, casts, comentários e dialetos;
- parâmetros ausentes, extras, tipos, direção, tamanho, null e fluxo condicional;
- transações corretas, rollback/commit ausentes, exceções, saídas, delegação e savepoints;
- configuração, drivers, options, paths, duplicação e sanitização de segredos;
- threads, tasks, anonymous methods, conexão local/compartilhada e sincronização VCL;
- schema, tipos, nullable, BLOB, colunas sensíveis e divergências com código;
- geração, nomenclatura, memória, imports, sete parâmetros, 120 caracteres e literais Delphi;
- preview, fingerprint, consentimento, aplicação, conflito, rollback e falha de gate.

### Contrato, segurança e integração

- descriptors, schemas JSON, risco, consentimento, catálogo e documentação de toda tool;
- senha em DFM/Params, token, connection string, traversal, reparse point e prompt injection;
- SQL mutável, múltiplas instruções, comentários, timeout, excesso, BLOB, HTML e CSV injection;
- scanner + semântica, PAS + DFM, schema + SQL, finding + preview e patch + gates;
- migração legado + auditoria FireDAC + build + DUnitX + rollback.

### E2E na IDE

1. inventário navegável sem mutação;
2. análise do SQL selecionado sem execução;
3. credencial detectada sem vazamento;
4. transação insegura localizada;
5. conexão compartilhada entre threads localizada;
6. schema SQLite, consulta consentida, grid e CSV sanitizados;
7. rejeição de DML sem alteração do banco;
8. preview de repository negado sem criar arquivos;
9. repository aplicado, compilado e testado;
10. falha de build com rollback;
11. correção de parâmetro com Smart Diff e gates;
12. rejeição de preview obsoleto;
13. migração ADO para FireDAC validada por lote;
14. falha de gate de migração com rollback;
15. troca e reabertura de projetos sem contexto obsoleto;
16. shutdown durante análise sem deadlock, AV ou thread retida.

Todos os cenários aplicáveis devem ser comprovados no Delphi 12 e 13. Execução real de banco começa
restrita a SQLite local read-only; PostgreSQL, SQL Server, MySQL/MariaDB, Oracle e Firebird entram como
dialetos de análise sem conexão automática.

## Definição de pronto

- todas as ferramentas do escopo estão implementadas, registradas, navegáveis e documentadas;
- análise distingue evidência determinística, hipótese e limitação;
- nenhuma credencial ou conteúdo executável atravessa fronteiras sem sanitização;
- toda mutação possui preview, consentimento, fingerprint, aplicação e rollback comprovados;
- unitários, contratos, segurança, integração e os 16 E2E estão verdes;
- builds Delphi 12 e 13, DUnitX, testes Web, ESLint e SonarQube estão aprovados;
- zero leak, deadlock, AV, trailing whitespace, linha nova acima de 120 caracteres ou literal inválida;
- manual, guia, referências, hints, catálogos, traduções, roadmap, backlog e testes documentais estão
  sincronizados;
- o relatório final prova requisito por requisito e não usa a existência de classes como evidência.
