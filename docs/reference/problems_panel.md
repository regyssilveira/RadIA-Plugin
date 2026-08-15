# Painel de problemas

O painel **Problems** reúne, em uma única lista, achados produzidos pelas ferramentas do RadIA. Ele
evita que o usuário precise procurar diagnósticos em respostas extensas ou conhecer o nome de cada
ferramenta interna.

## Quando é preenchido

O painel é atualizado depois que uma ferramenta conclui com sucesso e devolve um achado acionável.
As fontes atualmente normalizadas são:

| Área | Exemplos de origem |
|---|---|
| Build | erros, warnings e mensagens estruturadas do compilador |
| Testes | casos DUnitX com estado `failed` ou `error` |
| Cobertura | diagnósticos das ferramentas de cobertura |
| Memória | eventos e vazamentos encontrados pelo FastMM5 |
| DFM/PAS | inconsistências entre formulário, componentes, eventos e unit Pascal |
| Threads | acesso inseguro à VCL, cancelamento e tratamento de exceções |
| Revisão | achados de análise estática e revisão de código |
| Geral | riscos e diagnósticos que não pertencem às áreas anteriores |

Casos aprovados do DUnitX não aparecem como problemas. Achados repetidos usam um identificador
determinístico e são atualizados sem duplicar a lista. Cada resposta de ferramenta é limitada a 200
problemas para manter a interface responsiva.

## Como usar

1. Clique em **Problems** no cabeçalho do chat. O contador indica quantos achados foram coletados.
2. Filtre por **Severity** ou **Area** para reduzir a lista.
3. Use **Open source** quando o achado indicar um arquivo. O RadIA solicita a navegação pelo contrato
   seguro da IDE e valida se o arquivo pertence ao projeto aberto.
4. Use **Review action** para colocar a jornada ou comando recomendado no campo de mensagem. A ação
   fica visível para revisão e não é executada automaticamente.
5. Use **Clear** para descartar somente os achados coletados no chat atual.

O painel é lateral em janelas amplas e vira uma sobreposição em larguras menores. Fechá-lo não apaga
os achados. Limpar a conversa ou trocar de sessão limpa a coleção associada à conversa anterior.

## Severidades

| Severidade | Significado |
|---|---|
| Critical | estado que impede a continuidade segura, como fatal do compilador |
| Error | falha confirmada, teste reprovado ou vazamento |
| Warning | risco ou condição que merece revisão |
| Information | diagnóstico útil sem falha confirmada |

O painel não modifica código, não inicia build e não aceita consentimento em nome do usuário. A
navegação continua sujeita à política das ferramentas; comandos recomendados são apenas preparados
no compositor.

