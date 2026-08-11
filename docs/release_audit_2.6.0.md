# Auditoria da release 2.6.0

> **Estado:** em andamento. Nenhum item pendente pode ser interpretado como aprovado.

## Gates funcionais

- [x] Prompt completo preserva destino, nome e plataforma e chega à aprovação antes de mutar.
- [x] Calculadora VCL e projeto DUnitX companion são gerados atomicamente.
- [x] Aplicação e testes compilam pela IDE nos três alvos.
- [x] Cinco testes DUnitX gerados passam nos três alvos.
- [x] Depurador fornece sessão, breakpoint, pilha e timeline nos três alvos.
- [x] Cenário visual `2 + 3 = 5` passa nos três alvos.
- [x] Catálogo documental corresponde às 132 ferramentas registradas.
- [ ] Aceite final repetido sobre o commit definitivo da 2.6.0 com `sourceDirty=false`.

## Gates de regressão e qualidade

- [x] Build e 1.047 testes DUnitX completos no Delphi 12 Win32.
- [x] Build e 1.047 testes DUnitX completos no Delphi 13 Win32.
- [x] Build e 1.047 testes DUnitX completos no Delphi 13 IDE64.
- [x] 99 testes Web, ESLint e 38 testes documentais aprovados.
- [ ] SonarQube atual com Quality Gate aprovado e sem novas issues.
- [x] Ausência de vazamentos confirmada nas três suítes DUnitX.

## Gates de distribuição

- [x] Instalador visual criado, validado e mantido sem assinatura conforme a política do projeto.
- [x] Instalação validada no Delphi 12 Win32, Delphi 13 Win32 e Delphi 13 IDE64.
- [x] Reparo e desinstalação validados nos três alvos pelo ciclo automatizado do pacote.
- [ ] Artefatos e hashes da release conferidos.

Evidências reproduzíveis dos ciclos `Uninstall` → `Install` → `Repair` → abertura da IDE:

- `Output/Validation/Release2.6Install/Delphi12-Win32.json`;
- `Output/Validation/Release2.6Install/Delphi13-Win32.json`;
- `Output/Validation/Release2.6Install/Delphi13-IDE64.json`.

Em cada alvo, a BPL instalada apresentou o mesmo SHA-256 da BPL contida no pacote comprovado.
O instalador visual exige confirmação do UAC pelo usuário; essa permissão do Windows não é
automatizada pelo projeto nem pelos testes.

## Gate documental

- [x] Pente-fino PT/EN concluído nos 214 arquivos Markdown rastreados.
- [x] Links, versões, descoberta, clareza e mojibake validados pelos 38 testes documentais.
- [x] README, manuais, instalação, ferramentas, comandos e notas sincronizados.
- [x] Os 49 arquivos JSON rastreados em `docs` foram analisados sintaticamente.

A navegação principal permanece organizada por tarefa. Referências históricas foram concentradas
na seção de planejamento e histórico, sem perder a alcançabilidade dos documentos antigos. A
documentação operacional usa a versão 2.6.0, a matriz Delphi 12/13 e o catálogo gerado de 132
ferramentas.
