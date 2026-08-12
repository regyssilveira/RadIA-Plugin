# Programa de experiência agentiva Delphi

## Objetivo

Evoluir o RadIA em nove entregas integradas que tornem a assistência Delphi visual, semanticamente
segura, consciente do ambiente, adequada à modernização de legado e comprovável por evidências
reproduzíveis. Este documento é um plano de execução; somente capacidades registradas no catálogo
runtime e aprovadas nos respectivos gates podem ser descritas como disponíveis.

## Princípios de execução

1. Reutilizar workspace OTA, transações, consentimento, auditoria, checkpoints e conhecimento local.
2. Manter toda mutação confinada ao projeto e protegida por preview, fingerprint e rollback.
3. Não capturar código, telas ou metadados silenciosamente.
4. Entregar documentação pt-BR/en-US, hints e testes junto de cada comportamento visível.
5. Validar Delphi 12 Win32, Delphi 13 Win32 e Delphi 13 IDE64 antes da conclusão.

## Fases e critérios de aceite

### E1 — Perfil inteligente do ambiente Delphi

Entregar `GetDelphiEnvironmentProfile` com IDE, arquitetura, projeto, framework, configuração,
plataforma, search paths, packages e bibliotecas detectadas. A resposta deve indicar a origem de
cada dado, limitar coleções, não incluir segredos e permanecer somente leitura.

Aceite: contratos unitários, resposta sanitizada e smoke nos três targets suportados.

### E2 — Conhecimento Delphi curado e versionado

Entregar regras carregadas sob demanda por versão, framework e assunto, com identificador estável,
fonte, aplicabilidade e orientação curta. Regras organizacionais devem poder complementar, mas não
sobrescrever silenciosamente, as regras de segurança do produto.

Aceite: consulta determinística, fallback por versão e citações de regra no resultado do agente.

### E3 — Auditor bidirecional DFM/PAS

Analisar pares `.pas`/`.dfm` sem alterar arquivos e detectar handlers ausentes ou incompatíveis,
componentes e campos inconsistentes, classes desconhecidas, nomes duplicados e referências órfãs.
Correções devem ser preparadas como patches ou transações existentes.

Aceite: fixtures positivas e negativas, zero falso positivo nas fixtures oficiais e correção com
preview, conflito concorrente e rollback.

### E4 — Visual Diff do Form Designer

Capturar estados autorizado anterior e proposto, gerar diff estrutural e visual e apresentá-los na
mesma etapa da timeline. Imagens devem permanecer locais e obedecer à retenção configurada.

Aceite: criação, remoção, propriedade e layout comparáveis; rejeição não altera o Designer.

### E5 — Contrato de execução autônoma

Estender os budgets atuais com critérios de conclusão, gates obrigatórios, limites de arquivos e
operações, política de pausa e resumo periódico. Retomada deve preservar os limites originais.

Aceite: parada determinística em cada limite, pausa diante de ambiguidade e relatório final com
evidências de build, testes e mudanças.

### E6 — Modernização incremental de legado

Entregar jornada de inventário, riscos, lotes reversíveis e validação para BDE, ADO e dbExpress em
direção a FireDAC, com extensão posterior para DEXT e decomposição de forms.

Aceite: nenhuma reescrita total automática; cada lote compila ou é revertido e mantém relatório de
compatibilidade e pendências manuais.

### E7 — Mentor Delphi

Entregar explicações orientadas ao nível do usuário sobre linguagem, ownership, VCL/FMX, DFM,
projetos e packages, sempre ancoradas no código selecionado e nas regras curadas aplicáveis.

Aceite: perfis iniciante, migrando de outra linguagem e experiente; nenhum conteúdo do projeto é
persistido como material didático sem consentimento.

### E8 — Ficha corporativa de segurança

Documentar o fluxo de dados por rota: provider remoto, endpoint compatível, CLI, MCP e execução
local. Incluir armazenamento, retenção, exclusão, credenciais, auditoria, telemetria e limites das
garantias que dependem do fornecedor escolhido.

Aceite: versão pt-BR/en-US, links centrais válidos e testes documentais.

### E9 — Benchmark Delphi reproduzível

Publicar cenários versionados para consistência DFM/PAS, Designer, memória, migração, DUnitX,
builds, IDE64, retomada e confinamento. Medir sucesso, duração, intervenções, rollback e custo quando
disponível, sem transformar resultados locais em telemetria.

Aceite: runner determinístico, schema versionado, fixtures sem credenciais e relatório comparável.

## Ordem de entrega

| Onda | Entregas | Dependência principal |
| :--- | :--- | :--- |
| 1 | E1 e E2 | Workspace e conhecimento existentes |
| 2 | E3 e E4 | Perfil, Designer e transações |
| 3 | E5 | Runtime, checkpoints e evidências |
| 4 | E6 e E7 | Perfil, regras e auditor DFM/PAS |
| 5 | E8 e E9 | Contratos estabilizados das ondas anteriores |

## Gate de conclusão do programa

- Catálogo runtime e referência de tools sincronizados.
- Documentação central, manual, guias, hints e traduções atualizados.
- Testes documentais, web e DUnitX aprovados.
- Builds aprovados no Delphi 12 Win32, Delphi 13 Win32 e Delphi 13 IDE64.
- SonarQube consultado exclusivamente pela API REST e Quality Gate aprovado.
- Nenhuma linha acima de 120 caracteres, literal acima de 255 caracteres ou trailing whitespace.
