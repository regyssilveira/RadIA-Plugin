# ADR 0001: Registro interno de ferramentas independente de transporte

- Status: Aceito
- Data: 2026-08-02

## Contexto

O RadIA precisa oferecer capacidades agentivas ao chat nativo e a clientes externos. Implementar
essas capacidades diretamente no chat ou no servidor MCP duplicaria schemas, validações, políticas
e auditoria.

## Decisão

Será criado um registro interno de ferramentas no Core.

O chat, MCP e futuros adaptadores serão consumidores desse registro. Ferramentas serão descritas
por contratos próprios do RadIA e não conhecerão detalhes de UI, WebView2 ou transporte.

O executor central será responsável por:

- Resolver a ferramenta.
- Validar entrada.
- Verificar capacidade da IDE.
- Aplicar políticas.
- Solicitar consentimento.
- Executar.
- Sanitizar resultado.
- Registrar auditoria.

## Consequências

### Positivas

- Uma única implementação por ferramenta.
- Segurança consistente.
- Testabilidade sem IDE ou MCP.
- Evolução independente dos providers.
- MCP pode ser adicionado ou removido sem afetar o chat.

### Negativas

- Exige schemas e tipos intermediários.
- Adiciona uma camada antes das chamadas OTA.
- Requer versionamento disciplinado dos contratos.

## Alternativas rejeitadas

### Ferramentas implementadas diretamente no MCP

Rejeitada porque acopla o produto ao protocolo e impede reutilização limpa pelo chat.

### Chamadas OTA diretamente no Presenter

Rejeitada porque mistura UI, threading, segurança e regras de workspace.
