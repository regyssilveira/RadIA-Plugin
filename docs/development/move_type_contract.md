# Contrato de refatoração Move Type

Este contrato define quando o RadIA pode mover um tipo Delphi entre units sem alterar silenciosamente
seu significado. A operação é preparada por `PrepareMoveType` e nunca grava arquivos durante a análise.

## Escopo suportado

- classe, interface, record ou helper declarado no nível superior de uma unit do projeto;
- identidade única comprovada pelo índice semântico;
- unit de origem e unit de destino existentes e pertencentes ao projeto ativo;
- declaração completa do tipo e implementações de seus métodos no mesmo arquivo de origem;
- atualização das cláusulas `uses` comprovadamente necessárias na origem, no destino e nos consumidores;
- preview multiarquivo, fingerprint por arquivo, consentimento central, compensação e rollback.

O nome do tipo e sua identidade permanecem iguais. Renomear e mover são operações distintas; quando as
duas forem necessárias, conclua e valide uma antes de preparar a outra.

## Precondições obrigatórias

1. Os buffers envolvidos precisam estar completos e corresponder à revisão indexada.
2. A declaração deve possuir início e fim estruturais inequívocos.
3. Cada implementação movida deve pertencer à mesma identidade canônica do tipo.
4. Dependências usadas pela declaração devem estar disponíveis na `interface` do destino.
5. Dependências usadas somente pelas implementações devem permanecer na `implementation` do destino.
6. A remoção do tipo não pode deixar referências privadas da origem inacessíveis.
7. A alteração das cláusulas `uses` não pode introduzir ciclo entre interfaces.
8. Nenhuma referência confirmada pode ficar dependente apenas da unit de origem depois da mudança.

Se uma dessas provas estiver ausente ou ambígua, a preparação falha sem produzir alteração parcial.

## Casos bloqueados

- forms, frames ou data modules associados a DFM;
- tipos aninhados, anônimos ou condicionais cuja extensão não possa ser delimitada;
- tipos ligados a `{$R}`, `{$RESOURCE}` ou outro artefato que precise migrar junto;
- implementações espalhadas por include files ou arquivos que não possam ser lidos integralmente;
- acesso a símbolos privados da unit de origem;
- helpers cujo tipo-alvo deixaria de estar visível no destino;
- destino com tipo homônimo ou ciclo de interface;
- referência candidata, identidade duplicada ou índice desatualizado.

O retorno deve explicar o bloqueio, os arquivos envolvidos e a ação necessária para tornar a operação
segura. O usuário nunca precisa descobrir a causa consultando o código-fonte do plugin.

## Transação e consentimento

`PrepareMoveType` retorna somente um `previewId`, o resumo de dependências e a lista de arquivos. O
usuário revisa o diff e autoriza `ApplyMultiFilePatch`. A aplicação revalida todas as revisões antes da
primeira escrita; uma falha compensa arquivos já alterados. `RevertMultiFilePatch` restaura o conteúdo
anterior enquanto o preview permanecer válido.

## Evidência mínima

- testes do delimitador estrutural para classe, interface, record e helper;
- teste multiarquivo com origem, destino e consumidor;
- rejeição comprovada de DFM, dependência privada, ciclo e revisão obsoleta;
- aplicação e rollback com igualdade exata dos arquivos originais;
- build e testes no Delphi 12 e 13;
- cenário de integração registrado no gate indivisível de release.
