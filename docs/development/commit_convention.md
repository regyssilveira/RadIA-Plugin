# Convenção de Mensagens de Commit

As mensagens de commit do **Rad IA** devem ser escritas sempre em **inglês** e seguir um prefixo semântico que indique o tipo principal da alteração.

Formato recomendado:

```text
<type>: <short description in English>
```

Exemplos:

```text
feat: Add chat welcome quick actions
fix: Prevent chat switching while processing
docs: Document release finalization process
refactor: Simplify provider session handling
```

---

## Prefixos Permitidos

| Prefixo | Uso |
| :--- | :--- |
| `feat` | Adiciona uma nova funcionalidade. |
| `fix` | Corrige um bug ou erro. |
| `docs` | Altera apenas documentação. |
| `style` | Ajusta formatação sem alterar lógica, como espaços, quebras de linha ou pontuação. |
| `refactor` | Melhora a estrutura do código sem adicionar funcionalidade ou corrigir bug. |
| `perf` | Melhora desempenho. |
| `test` | Adiciona ou corrige testes. |
| `build` | Altera sistema de build, empacotamento ou dependências externas. |
| `chore` | Executa tarefas de manutenção sem impacto no código de produção. |

---

## Boas Práticas

* Use frases curtas, no imperativo ou infinitivo natural em inglês.
* Prefira descrever o resultado da alteração, não o processo.
* Use um único prefixo por commit.
* Separe commits por intenção quando a alteração misturar documentação, código e build.
* Evite mensagens genéricas como `fix: adjustments`, `chore: changes` ou `update files`.

Quando uma alteração for ampla, o corpo do commit pode detalhar contexto e impactos, mas o título deve continuar seguindo o formato acima.
