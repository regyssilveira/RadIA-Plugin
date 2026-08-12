# Orientação Delphi curada

O RadIA inclui um catálogo local e versionado de regras Delphi para complementar o contexto do agente
com cuidados aplicáveis à versão da IDE, ao framework e à arquitetura ativos. As regras são somente
leitura, não fazem consultas externas e usam citações estáveis no formato
`[radia-delphi:<identificador>@<versão-do-schema>]`.

## Uso

O serviço de chat acrescenta automaticamente até seis regras compatíveis ao prompt do sistema. Para
consultar o catálogo diretamente, execute:

```text
/tool GetDelphiGuidance
```

A tool aceita os filtros opcionais `version`, `framework`, `architecture`, `topic` e `id`. `maxCount`
limita o resultado entre 1 e 50 regras. Valores vazios ou `any` não restringem a consulta.

```json
{
  "version": "13",
  "framework": "vcl",
  "architecture": "ide64",
  "topic": "threads",
  "maxCount": 10
}
```

## Cobertura inicial

O catálogo cobre indexação de strings, ciclo de vida de objetos, acesso à UI em threads, ownership de
componentes, serviços de plataforma FMX, compatibilidade com Delphi 12 e 13, segurança de ponteiros na
IDE64, consistência entre DFM e Pascal, imports e limite de parâmetros.

## Versão, ordem e precedência

- `schemaVersion` define o contrato de cada regra; a versão inicial é `1`.
- Regras aplicáveis são ordenadas por prioridade decrescente e, em empate, por identificador.
- Uma consulta por `id` seleciona exatamente uma regra compatível.
- Regras específicas de versão, framework ou arquitetura complementam as regras gerais.
- O catálogo embutido é a fonte autoritativa nesta versão. Extensões organizacionais ainda não são
  carregadas e não devem reutilizar o namespace de citações embutido.

Quando uma regra influenciar uma resposta, o agente deve preservar a citação correspondente. A citação
permite localizar o identificador e a versão do contrato sem expor caminhos locais.

## Recuperação

Se nenhuma regra for retornada, confira os seletores com `GetDelphiEnvironmentProfile` e repita a
consulta sem `topic` ou `id`. Uma falha ao montar o perfil não interrompe o chat: a orientação adicional
é omitida e o evento é registrado no log do serviço.
