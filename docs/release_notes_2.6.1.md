# Notas de release — RadIA 2.6.1

> **Estado:** preparada em 11 de agosto de 2026 para corrigir a issue #17.

O RadIA 2.6.1 é uma release patch focada no provider Anthropic Claude. Ela remove parâmetros de
amostragem incompatíveis com os modelos Claude 5 e alinha a tela de configuração ao comportamento
real da API.

## Correções

- o provider Claude nativo deixou de enviar `temperature` no payload da API;
- o campo **Temperature** da aba Claude agora aparece desabilitado como valor local legado;
- a referência de configurações documenta que Claude 5 não recebe `temperature`, `top_p` ou `top_k`;
- teste de regressão garante que payloads Claude não incluem `temperature`.

## Compatibilidade

- Delphi 13 validado com build, cobertura e testes;
- catálogo operacional preservado com 132 ferramentas;
- comportamento dos demais providers não foi alterado.

## Validação da release

- `npm run test:docs`: 38 testes aprovados;
- `build.ps1 -DelphiVersion "37.0" -Test`: 1.039 testes instrumentados e 8 testes externos
  aprovados, totalizando 1.047 testes.
