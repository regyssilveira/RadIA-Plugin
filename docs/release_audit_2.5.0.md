# Auditoria da release 2.5.0

| Gate | Resultado |
|---|---|
| Delphi 12 Win32 | Compilação e 1.046 testes aprovados, zero leaks |
| Delphi 13 Win32 | Compilação e 1.046 testes aprovados, zero leaks |
| Delphi 13 IDE64 | Compilação aprovada |
| Web, documentação e lint | 97 + 36 testes e ESLint aprovados |
| Catálogo runtime | 132 ferramentas validadas |
| SonarQube | Quality Gate `OK`, zero issues |
| Distribuição | Somente o instalador visual será publicado |

A release melhora a responsividade do compositor e elimina a dependência obrigatória do npm para
instalar Codex CLI e Claude Code. Todos os canais externos continuam explícitos, consentidos e
obtidos das fontes oficiais; nenhuma CLI de terceiros é incorporada ao instalador. O modo Agent
também permanece utilizável sem projeto aberto e mantém a aprovação do plano visível e acionável.
Pedidos naturais de criação agora extraem nome, destino e plataforma quando disponíveis, e a
permissão **Allow session** é reutilizada entre tools compatíveis da mesma categoria e escopo.
