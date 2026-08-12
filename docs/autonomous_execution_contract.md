# Contrato de execução autônoma

Toda execução nativa iniciada com `/agent run` recebe um contrato local e imutável para aquela sessão.
O contrato complementa os limites de etapas, repetição, duração, tokens, custo e contexto já existentes.

## Limites adicionais

O contrato padrão limita a execução a 32 arquivos afetados e 20 operações mutáveis, produzindo um
resumo a cada cinco etapas. O runtime verifica operações e caminhos conhecidos antes de chamar uma
tool; se uma resposta revelar arquivos adicionais além do limite, a execução também pausa imediatamente.

O resumo periódico registra quantidade de etapas, operações mutáveis, arquivos afetados e última tool.
Ele é armazenado no checkpoint e reaparece depois de `/agent resume`.

## Critérios e gates

O contrato contém critérios de conclusão explícitos e flags para build e testes obrigatórios. No contrato
padrão, qualquer mutação exige um `BuildProject` aprovado depois da última alteração. Jornadas que
habilitam o gate de testes também exigem uma execução DUnitX posterior à mutação. Testes executados e
reprovados sempre bloqueiam a conclusão.

Uma tentativa prematura de concluir retorna ao loop com uma instrução de recuperação. Três tentativas
consecutivas sem cumprir os gates encerram a execução como falha.

## Pausas seguras

O runtime pausa, sem ampliar permissões, quando:

- a próxima operação ou arquivo conhecido excederia o contrato;
- uma tool retorna ambiguidade, solicitação inválida, conflito ou precondição concorrente;
- o usuário solicita pausa.

A retomada carrega limites, critérios, gates, uso acumulado, resumo e etapas diretamente do checkpoint.
Checkpoints antigos sem o novo bloco recebem o contrato padrão; valores ausentes nunca são convertidos em
limites mais amplos.

## Relatório final

Execuções concluídas, canceladas ou com falha incluem `finalReport` no snapshot. O relatório reúne estado,
mensagem, etapas, operações, arquivos afetados, resultado do build, contagens DUnitX e pendências. Essa
evidência usa apenas os resultados de tools já autorizadas e não executa validações adicionais.
