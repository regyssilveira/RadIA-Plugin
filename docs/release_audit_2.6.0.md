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

- [ ] Instalador visual criado e validado.
- [ ] Instalação e atualização validadas no Delphi 12 e 13.
- [ ] Reparo e desinstalação validados.
- [ ] Artefatos e hashes da release conferidos.

## Gate documental

- [ ] Pente-fino PT/EN concluído em todos os arquivos rastreados.
- [ ] Links, versões, descoberta, clareza e mojibake validados.
- [ ] README, manuais, instalação, ferramentas, comandos e notas sincronizados.
