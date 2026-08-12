# Tasks da experiência agentiva Delphi

Esta lista executa o [programa de experiência agentiva Delphi](delphi_agent_experience_plan.md).
Os estados válidos são `pending`, `in_progress`, `blocked` e `completed`. Uma task somente pode ser
marcada como concluída depois que código, testes, documentação e gates aplicáveis forem aprovados.

## Fundação

| ID | Task | Dependências | Estado |
| :--- | :--- | :--- | :--- |
| DX-001 | Definir contratos de perfil, regras, auditoria, diff e evidência | — | completed |
| DX-002 | Criar fixtures Delphi compartilhadas e mocks OTA | DX-001 | completed |
| DX-003 | Atualizar registro, catálogo runtime e testes de catálogo | DX-001 | completed |

## Perfil inteligente do ambiente

| ID | Task | Dependências | Estado |
| :--- | :--- | :--- | :--- |
| DX-101 | Coletar versão, arquitetura, SKU e capacidades da IDE | DX-001 | completed |
| DX-102 | Detectar framework, plataforma e configuração do projeto | DX-101 | completed |
| DX-103 | Inventariar search paths, packages e bibliotecas com limites | DX-101 | completed |
| DX-104 | Registrar `GetDelphiEnvironmentProfile` e sanitizar a resposta | DX-102, DX-103 | completed |
| DX-105 | Validar o perfil nos três targets suportados | DX-104 | completed |

## Conhecimento Delphi curado

| ID | Task | Dependências | Estado |
| :--- | :--- | :--- | :--- |
| DX-201 | Definir schema versionado de regras e política de precedência | DX-001 | completed |
| DX-202 | Criar regras iniciais de linguagem, memória, threads, VCL e FMX | DX-201 | completed |
| DX-203 | Criar regras específicas para Delphi 12, Delphi 13 e IDE64 | DX-201 | completed |
| DX-204 | Implementar consulta por versão, framework, tópico e identificador | DX-202, DX-203 | completed |
| DX-205 | Integrar citações de regras ao contexto e aos resultados do agente | DX-204 | completed |

## Auditor DFM/PAS

| ID | Task | Dependências | Estado |
| :--- | :--- | :--- | :--- |
| DX-301 | Criar parser limitado e seguro de componentes, campos e eventos | DX-002 | completed |
| DX-302 | Detectar handlers ausentes, órfãos ou incompatíveis | DX-301 | completed |
| DX-303 | Detectar componentes, campos, classes e nomes inconsistentes | DX-301 | completed |
| DX-304 | Registrar auditoria somente leitura com severidade e localização | DX-302, DX-303 | completed |
| DX-305 | Preparar correções via patches e transações existentes | DX-304 | completed |
| DX-306 | Validar conflito concorrente, rollback e ausência de falsos positivos | DX-305 | completed |

## Visual Diff do Designer

| ID | Task | Dependências | Estado |
| :--- | :--- | :--- | :--- |
| DX-401 | Definir snapshot visual local, retenção e sanitização | DX-001 | completed |
| DX-402 | Capturar estado anterior e proposto na thread principal da IDE | DX-401 | completed |
| DX-403 | Calcular diff estrutural de componentes, bounds e propriedades | DX-301, DX-402 | completed |
| DX-404 | Renderizar comparação antes/depois na timeline | DX-403 | completed |
| DX-405 | Integrar aceite, rejeição, conflito e limpeza de artefatos | DX-404 | completed |

## Contrato de execução autônoma

| ID | Task | Dependências | Estado |
| :--- | :--- | :--- | :--- |
| DX-501 | Estender limites com arquivos, operações e periodicidade de resumo | DX-001 | completed |
| DX-502 | Definir critérios de conclusão e gates obrigatórios | DX-501 | completed |
| DX-503 | Persistir o contrato nos checkpoints sem ampliar permissões | DX-502 | completed |
| DX-504 | Implementar pausa por ambiguidade e violação de contrato | DX-503 | completed |
| DX-505 | Produzir relatório final com mudanças, build, testes e pendências | DX-504 | completed |

## Modernização incremental

| ID | Task | Dependências | Estado |
| :--- | :--- | :--- | :--- |
| DX-601 | Inventariar BDE, ADO e dbExpress em código, DFM e projeto | DX-304 | completed |
| DX-602 | Classificar riscos e mapear equivalentes FireDAC | DX-601, DX-204 | completed |
| DX-603 | Preparar lotes reversíveis de migração | DX-305, DX-602 | completed |
| DX-604 | Executar build e testes como gates por lote | DX-503, DX-603 | completed |
| DX-605 | Gerar relatório de compatibilidade e ações manuais | DX-604 | completed |
| DX-606 | Estender a jornada para DEXT e decomposição de forms | DX-605 | completed |

## Mentor Delphi

| ID | Task | Dependências | Estado |
| :--- | :--- | :--- | :--- |
| DX-701 | Definir perfis iniciante, transição de linguagem e experiente | DX-201 | completed |
| DX-702 | Criar templates ancorados no código e nas regras aplicáveis | DX-205, DX-701 | completed |
| DX-703 | Implementar explicações de ownership, VCL/FMX, DFM e packages | DX-702 | completed |
| DX-704 | Integrar o mentor ao editor e ao chat sem retenção implícita | DX-703 | completed |

## Segurança corporativa

| ID | Task | Dependências | Estado |
| :--- | :--- | :--- | :--- |
| DX-801 | Inventariar fluxos de dados, armazenamento e retenção por rota | DX-104, DX-503 | completed |
| DX-802 | Documentar credenciais, auditoria, telemetria e exclusão | DX-801 | completed |
| DX-803 | Criar matriz local/remoto e limites das garantias por provider | DX-802 | completed |
| DX-804 | Publicar ficha pt-BR/en-US e integrar aos hubs | DX-803 | completed |

## Benchmark reproduzível

| ID | Task | Dependências | Estado |
| :--- | :--- | :--- | :--- |
| DX-901 | Definir schema de cenário, execução e resultado | DX-001 | completed |
| DX-902 | Criar fixtures para DFM/PAS, Designer, memória e migração | DX-002, DX-901 | completed |
| DX-903 | Criar cenários de build, DUnitX, IDE64, retomada e confinamento | DX-503, DX-901 | completed |
| DX-904 | Implementar runner determinístico sem telemetria | DX-902, DX-903 | completed |
| DX-905 | Gerar relatório comparável de sucesso, tempo, custo e rollback | DX-904 | completed |

## Fechamento

| ID | Task | Dependências | Estado |
| :--- | :--- | :--- | :--- |
| DX-990 | Atualizar UI, hints, traduções, manual e referências centrais | DX-105–DX-905 | completed |
| DX-991 | Executar testes documentais, web e DUnitX | DX-990 | completed |
| DX-992 | Validar builds Delphi 12 Win32, Delphi 13 Win32 e IDE64 | DX-991 | completed |
| DX-993 | Consultar SonarQube pela API REST e resolver causas-raiz | DX-992 | completed |
| DX-994 | Auditar linhas, literais, whitespace, catálogo e evidências | DX-993 | completed |
