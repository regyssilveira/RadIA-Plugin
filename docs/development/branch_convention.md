# Convenção de Nomes de Branch

As branches do **Rad IA** devem seguir uma estrutura simples, previsível e compatível com convenções amplamente adotadas, como Conventional Branch.

Formato recomendado:

```text
<tipo>/<descricao-curta>
```

Exemplos:

```text
feat/chat-welcome-actions
fix/editor-selection-bug
docs/release-process
refactor/provider-session-handling
```

---

## Regras Gerais

* Use letras minúsculas.
* Use palavras curtas em inglês.
* Separe palavras com hífen (`-`).
* Use barra (`/`) somente entre o tipo e a descrição.
* Evite acentos, espaços, underline e caracteres especiais.
* Mantenha a descrição objetiva e relacionada ao objetivo principal da branch.

---

## Prefixos Permitidos

| Prefixo | Uso | Exemplo |
| :--- | :--- | :--- |
| `feat/` ou `feature/` | Novas funcionalidades. | `feat/user-authentication` |
| `fix/` ou `bugfix/` | Correção de bugs ou falhas. | `fix/login-error` |
| `hotfix/` | Correções urgentes aplicadas diretamente em produção. | `hotfix/payment-failure` |
| `refactor/` | Melhorias de código que não adicionam funcionalidade nem corrigem bug. | `refactor/search-optimization` |
| `docs/` | Alterações exclusivas na documentação. | `docs/update-readme` |
| `test/` | Adição ou correção de testes. | `test/api-coverage` |
| `chore/` | Tarefas de manutenção ou configuração. | `chore/update-dependencies` |

---

## Boas Práticas

* Escolha o prefixo pelo objetivo principal da branch.
* Prefira uma branch por intenção de trabalho.
* Evite nomes genéricos como `fix/adjustments`, `feat/new-stuff` ou `chore/misc`.
* Quando houver issue ou tarefa rastreável, o identificador pode ser incluído ao final: `fix/editor-selection-bug-123`.
* O prefixo da branch não obriga todos os commits a terem o mesmo prefixo, mas a história fica mais clara quando ambos estão alinhados.
