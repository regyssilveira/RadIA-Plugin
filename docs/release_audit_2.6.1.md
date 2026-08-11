# Auditoria da release 2.6.1

> **Estado:** aprovada em 11 de agosto de 2026 para a correção da issue #17.

## Gates funcionais

- [x] O provider Claude nativo omite `temperature` nos payloads enviados à API Anthropic.
- [x] A aba Claude mostra o campo **Temperature** desabilitado para evitar configuração enganosa.
- [x] A documentação de configurações explica que Claude 5 rejeita parâmetros de amostragem
  não padrão.
- [x] O catálogo operacional permanece sincronizado com as 132 ferramentas registradas.

## Gates de regressão e qualidade

- [x] `npm run test:docs`: 38 testes documentais aprovados.
- [x] `build.ps1 -DelphiVersion "37.0" -Test`: build, cobertura e 1.047 testes aprovados.
- [x] Teste de regressão cobre a ausência de `temperature` no payload Claude.
- [x] Nenhuma alteração de contrato foi feita para Gemini, OpenAI, Ollama ou providers compatíveis
  com OpenAI.

## Gate documental

- [x] `settings_reference.md` e `settings_reference.en.md` descrevem o comportamento do Claude 5.
- [x] As notas de release e esta auditoria existem em português e inglês.
- [x] Os hubs principais apontam para a release 2.6.1.
