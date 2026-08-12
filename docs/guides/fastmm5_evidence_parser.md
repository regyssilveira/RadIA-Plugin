# Coleta e interpretação dos logs FastMM5

O RadIA converte o texto do FastMM5 em evidência JSON limitada e adequada ao chat e ao MCP. O parser
reconhece:

- leaks com tamanho, classe e número de alocação;
- double free e use-after-free;
- corrupção de header e footer;
- frames com endereço normalizado, módulo, rotina, arquivo e linha;
- fingerprints estáveis que não dependem do endereço carregado do processo.

`ParseMemoryDiagnosticLog` aceita somente logs dentro do workspace ativo. O limite configurado é
aplicado durante a leitura, antes de carregar o arquivo inteiro, e o resultado informa `truncated`
quando dados foram descartados. Cada evento aceita no máximo 100 frames e cada resultado, no máximo
1.000 eventos.

O coletor recebe tanto o arquivo de log quanto fragmentos de `OutputDebugString`; os dois canais usam
o mesmo parser. O arquivo é a fonte principal, enquanto a saída do debugger permite recuperar
eventos quando a gravação em disco estiver indisponível.

Exemplo:

```text
/tool ParseMemoryDiagnosticLog {"logPath":"D:\\Projeto\\.radia\\memory\\session.log"}
```

O caminho passa pelas fronteiras de segurança do workspace e nunca permite leitura arbitrária fora
do projeto ativo.
