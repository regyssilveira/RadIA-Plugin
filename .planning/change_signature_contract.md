# Contrato de Change Signature semântico

## Resultado observável

`PrepareChangeSignature` recebe a identidade inequívoca de uma rotina Delphi e a assinatura desejada,
calcula todas as declarações, implementações e chamadas afetadas e produz um único preview
multiarquivo. Nenhum arquivo é alterado durante a preparação. A aplicação usa
`ApplyMultiFilePatch`; a reversão usa `RevertMultiFilePatch`.

## Escopo Delphi obrigatório

- procedures, functions, constructors, destructors, métodos de classe e operadores;
- rotinas globais, métodos de classe/record/interface e implementações correspondentes;
- parâmetros `const`, `var`, `out`, `[Ref]`, sem modificador e com valor padrão;
- grupos como `const A, B: Integer`, arrays abertos, generics e tipos qualificados;
- adição, remoção, renomeação e reordenação de parâmetros;
- alteração de modificador, tipo, valor padrão, tipo de retorno e calling convention;
- chamadas posicionais, parâmetros nomeados e chamadas herdadas resolvidas pelo índice;
- overloads, forward declarations, interface/implementation e métodos implementando interfaces;
- handlers vinculados por DFM, preservando compatibilidade do tipo de evento.

## Contrato de entrada

- `symbol`: nome da rotina.
- `unit`: unit obrigatória quando houver homônimos.
- `container`: tipo contêiner quando houver métodos homônimos na mesma unit.
- `signature`: assinatura Delphi completa desejada, sem corpo.
- `argumentBindings`: valor explícito para cada parâmetro novo que não possua default.

O preview retorna identidade, assinatura anterior e nova, alterações classificadas, chamadas
reescritas, arquivos, diagnósticos, capacidade e próximo passo.

## Invariantes de segurança

1. A identidade vem do índice semântico; busca textual não escolhe overloads.
2. Toda ocorrência precisa ter offsets, revisão e classificação confirmadas.
3. Declaração e implementação precisam permanecer equivalentes após normalização.
4. Um parâmetro removido não pode possuir argumento com efeito colateral sem confirmação explícita.
5. Um parâmetro novo exige default aplicável ou binding explícito por chamada.
6. Parâmetros nomeados são mapeados por identidade anterior, não por posição.
7. Alterações em métodos virtuais, override, interface ou event handler incluem toda a família ou
   falham com diagnóstico acionável.
8. Diretivas condicionais, macros, código gerado, assembly e sintaxe não compreendida interrompem a
   preparação; nenhuma edição parcial é permitida.
9. O conteúdo é revalidado contra a revisão indexada antes de preparar e antes de aplicar.
10. A aplicação é atômica, exige consentimento de escrita estrutural e possui rollback verificável.

## Modelo de ameaças

| Ameaça | Tratamento obrigatório |
|---|---|
| Overload incorreto | identidade completa, container, unit e assinatura atual |
| Chamada dinâmica ou indireta | reportar como não comprovada e bloquear mutação automática |
| Argumento removido com efeito colateral | bloquear ou exigir binding de preservação explícito |
| Divergência interface/implementation | falhar antes de criar preview |
| Hierarquia incompleta | consultar `GetTypeHierarchy` e bloquear quando um membro externo puder participar |
| DFM incompatível | validar assinatura do evento e incluir o DFM no preview quando necessário |
| Arquivo alterado após indexação | fingerprint por arquivo e reindexação orientada |
| Código condicional | exigir a mesma identidade em todas as configurações comprovadas |
| Encoding ou DFM binário | preservar encoding; exigir DFM textual/editável |
| Aplicação parcial | transação multiarquivo com compensação e evidência de rollback |

## Evidência de conclusão

- testes do parser de assinatura e argumentos, inclusive nesting de generics e anonymous methods;
- integração headless com múltiplas units, overload, interface, herança e DFM;
- integração OTA preparando, aplicando, compilando e revertendo um fixture no Delphi 12 e 13;
- cenário automatizado de uso incluído no gate integrado;
- builds, DUnitX, documentação, catálogo e Sonar aprovados.

