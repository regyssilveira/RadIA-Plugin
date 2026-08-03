# ADR 0003: implementação independente das referências do AEFOS

## Status

Aceita.

## Contexto

O AEFOS foi analisado como referência de capacidades de produto, incluindo integração com IDE,
chat, ferramentas agentivas, contexto de projeto e automação. O objetivo da análise foi identificar
problemas que também fazem sentido para o RadIA, não reutilizar sua implementação.

Código, recursos, textos, prompts, schemas, nomes internos, layouts, protocolos privados e decisões
não públicas do AEFOS não fazem parte da base do RadIA.

## Decisão

A evolução agentiva do RadIA usa contratos e implementações próprios:

- `IRadIAToolRegistry` é independente de transporte;
- a fachada OTA converte interfaces da IDE em snapshots do domínio RadIA;
- consentimento, auditoria e workspace boundary pertencem ao pipeline do RadIA;
- patches usam revisão SHA-256 e previews próprios;
- MCP traduz o registry interno para JSON-RPC sem adotar contratos privados de terceiros;
- Designer, debugger e conhecimento são implementados sobre APIs Delphi e estruturas próprias;
- a API de extensões possui versionamento e lifecycle definidos pelo RadIA.

Somente ideias funcionais de alto nível podem orientar priorização. Uma contribuição derivada de
referência externa deve ser reescrita a partir dos requisitos e validada pelos testes do RadIA.

## Controles

- Código ativo não pode importar units, namespaces ou binários do AEFOS.
- Recursos visuais e textos não podem ser copiados.
- Prompts e schemas hardcoded devem ser escritos especificamente para o RadIA.
- Dependências novas precisam constar explicitamente nos projetos e documentos de arquitetura.
- Revisões devem comparar a mudança com os contratos públicos do RadIA, não com fontes externas.
- Testes precisam usar fixtures e fakes próprios.

## Evidência atual

- Nenhuma referência a `AEFOS` existe em `Source`, `Tests` ou `Examples`.
- As units agentivas seguem o namespace `RadIA.*`.
- Os contratos centrais estão documentados nos ADRs e na arquitetura agentiva.
- O pacote compila sem incluir diretórios, bibliotecas ou artefatos do AEFOS.

## Consequências

A implementação pode diferir intencionalmente da referência e exigir mais trabalho de engenharia,
mas permanece auditável, testável, redistribuível e alinhada à arquitetura do RadIA.
