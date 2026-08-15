# Ficha corporativa de segurança

Esta ficha descreve o comportamento do RadIA. Retenção, treinamento, residência e exclusão do serviço
escolhido pertencem ao fornecedor ou à infraestrutura da organização e exigem verificação contratual.

## Matriz de fluxo por rota

| Rota | Destino e dados | Armazenamento local | Garantia do RadIA | Limite externo |
|---|---|---|---|---|
| Provider remoto nativo | API HTTPS; prompt, histórico limitado e contexto autorizado | configurações, credencial DPAPI e auditoria sanitizada | consentimento, redaction e limites antes do envio | retenção, treinamento, residência, logs e exclusão do provider |
| Endpoint compatível | URL HTTPS definida pelo usuário; mesmo envelope nativo | mesmos dados da rota nativa | valida URL, aplica policy e não copia chaves para telemetria | identidade, operação e política do endpoint |
| CLI externo | processo local, que pode chamar serviços próprios; objetivo e contexto | executor, ID externo, projeto e modelo; sem token, prompt ou saída bruta no vínculo | diretório limitado, timeout, cancelamento e saída limitada | autenticação, histórico, telemetria e exclusão do CLI |
| MCP local/externo | servidor configurado; argumentos autorizados por chamada | configuração protegida e auditoria sanitizada | policy central, consentimento, payload limitado e cancelamento | tratamento realizado pelo servidor MCP |
| Provider local | processo ou endpoint local/interno; prompt e contexto autorizado | índices, configurações e auditoria locais | não inicia envio a provider de nuvem nesta rota | outra máquina ainda implica tráfego de rede interno |

## Armazenamento, retenção e exclusão

- credenciais usam DPAPI do usuário Windows e armazenamento no Registro;
- auditoria sanitizada fica em `%APPDATA%\RadIA\audit\tools.jsonl`;
- índices reconstruíveis ficam em `%APPDATA%\RadIA\Knowledge`;
- histórico aprovado só entra no conhecimento quando a opção explícita está ativa;
- previews, checkpoints, evidências e capturas seguem os limites de seus guias.

O RadIA não promete uma retenção corporativa única. A organização define prazo, backup e descarte. Para
excluir dados locais, feche todas as IDEs, preserve evidências obrigatórias e remova os artefatos aplicáveis.
Excluir uma credencial também exige revogação no provider. Desvincular uma sessão CLI não apaga dados do CLI.

## Credenciais, auditoria e telemetria

O redator mascara API keys, tokens OAuth/AWS, headers de autorização, cookies e connection strings com senha
antes de auditoria, logs e respostas MCP. A auditoria registra correlação, origem, tool, risco, decisão,
estado e recursos afetados com argumentos e erros sanitizados.

O RadIA não envia telemetria própria contendo código, prompts ou credenciais. Contadores sanitizados podem
existir localmente. Providers, CLIs, endpoints e servidores MCP podem ter telemetria própria; o RadIA não
consegue desativá-la ou auditá-la universalmente.

## Checklist de aprovação

1. Classifique o código e escolha uma rota permitida.
2. Confirme contrato, região, retenção, treinamento e exclusão do destino.
3. Use menor privilégio e defina rotação e revogação de credenciais.
4. Defina retenção e descarte para auditoria, conhecimento, checkpoints e evidências.
5. Valide consentimento, confinamento, redaction e resposta a incidentes.

Veja [Modelo de segurança](tool_security_model.md), [Compliance](../development/compliance.md),
[Executores CLI](../guides/cli_executors.md) e [Integração MCP](../guides/mcp_integration_guide.md).
