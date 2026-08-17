# FireDAC Advisor

O FireDAC Advisor inspeciona a camada de dados do projeto Delphi ativo, produz achados navegáveis
e prepara mudanças revisáveis. A análise é estática por padrão: não abre conexões, não executa SQL
e não devolve senhas, tokens ou connection strings.

## Antes de começar

1. Abra o projeto no Delphi 12 ou 13.
2. Use **Agent + RadIA native** para permitir o encadeamento das tools da IDE.
3. Confirme o projeto ativo e descreva o objetivo, por exemplo: `audite o uso de FireDAC deste
   projeto e priorize os riscos`.
4. Revise cada consentimento antes de consulta local, aplicação ou reversão.

Use `/tools` para confirmar o catálogo da instalação. Os achados também aparecem no painel de
problemas e mantêm arquivo, linha, regra, severidade, confiança e evidência sanitizada.

## Inventário e diagnóstico

`InspectFireDACProject` localiza componentes e relações em PAS e DFM. O relatório consolidado pode
combinar esse inventário com:

- SQL embutido ou selecionado, statements, placeholders e parâmetros;
- transações sem commit ou rollback seguro;
- configuração, `DriverID`, drivers e bibliotecas;
- conexão, dataset, transação ou UI compartilhados entre threads;
- divergências entre tipos FireDAC e um schema SQLite local autorizado.

`InspectFireDACUsage` continua disponível para automações antigas e usa o mesmo inventário. A
análise de SQL nunca executa nem ecoa a consulta. Se um schema real não estiver disponível, a
explicação separa fatos determinísticos, hipóteses e limitações.

## SQL e SQLite local

Para analisar uma consulta, selecione o SQL no editor e peça `analise a seleção FireDAC sem
executar`. Para comparar código e schema, informe um arquivo SQLite dentro do workspace. Leitura de
linhas exige consentimento em cada chamada e aceita somente uma consulta read-only, limitada e
sanitizada; DML, múltiplas instruções, BLOBs e valores sensíveis são rejeitados.

Consulte também [Banco de dados local com segurança](local_database.md).

## Geração e correções

O Advisor pode preparar previews determinísticos de repository, DataModule, query, DTO e fixture
DUnitX. Preparar não escreve arquivos. A criação só ocorre depois da revisão, consentimento e
revalidação do fingerprint; uma reversão é recusada se houver mudança posterior.

Correções automáticas são limitadas a findings comprovados e regras suportadas. O fluxo é:

1. validar o finding;
2. preparar o preview e abrir o Smart Diff;
3. consentir a aplicação;
4. compilar e executar DUnitX;
5. reverter se um gate falhar ou se o usuário solicitar, desde que as precondições permaneçam
   válidas.

As correções determinísticas atuais incluem accessor incompatível de parâmetro e rollback ausente.
Planos de otimização e thread safety não prometem ganho nem aplicam mudanças por conta própria.

## Migração de acesso a dados legado

O fluxo de migração inventaria BDE, ADO e dbExpress, planeja lotes e prepara a substituição por
FireDAC. Cada lote aplicado exige consentimento e só é aceito depois dos gates FireDAC, build e
DUnitX. Se qualquer gate falhar, o lote é revertido e o fonte legado é restaurado.

Consulte [Migração de acesso a dados legado](legacy_data_migration.md).

## Garantias e limites

- Paths permanecem confinados ao projeto ativo.
- Credenciais são removidas de argumentos, resultados, auditoria, grid e CSV.
- Preview obsoleto não sobrescreve edição posterior.
- Análise estática não substitui plano de execução, benchmark, build, testes ou revisão humana.
- Acesso real a banco é restrito ao fluxo SQLite local read-only e sempre requer consentimento.
- Delphi 12 Win32, Delphi 13 Win32 e Delphi 13 IDE64 fazem parte da matriz suportada.

Veja a lista completa de tools na
[referência operacional](../reference/internal_tools_reference.md).
