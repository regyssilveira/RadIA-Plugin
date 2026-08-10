# Goal — portabilidade de skills e terminal de alta fidelidade

> **Estado:** em execução no branch `feat/competitive-gap-closure`.
> **Versão de entrega:** será definida pelo comportamento público efetivamente concluído.

## Objetivo

Eliminar as duas lacunas técnicas remanescentes da experiência completa do RadIA:

1. publicar uma skill declarativa em formatos nativos dos CLIs suportados sem duplicação manual;
2. executar shells, CLIs e aplicações TUI no terminal acoplável com emulação VT de alta fidelidade.

O release será apenas preparado neste goal. Publicação, tag, merge ou criação de release exigem uma
autorização posterior e explícita.

## Escopo oficial

- Delphi 12 Win32;
- Delphi 13 Win32;
- Delphi 13 IDE64;
- Codex, Claude Code, Gemini CLI e GitHub Copilot CLI;
- CMD, Windows PowerShell, PowerShell 7, Git Bash e WSL quando disponíveis;
- extensões declarativas locais e pacotes `.radiaext`;
- ConPTY com fallback documentado quando indisponível.

Instalação por marketplace, assinatura comercial, C++Builder e suporte a versões anteriores do
Delphi não fazem parte deste goal.

## Marcos

| Marco | Entrega | Estado |
|---|---|---|
| M0 | Baseline, contratos, matriz de aceite e auditoria documental | Concluído |
| M1 | Modelo canônico e adaptadores de skill por CLI | Concluído |
| M2 | Preview, consentimento, sincronização e remoção no Addon Studio | Concluído |
| M3 | Validação real dos formatos e documentação de portabilidade | Concluído |
| M4 | Interface desacoplada e núcleo VT selecionado | Concluído |
| M5 | Alternate screen, cores, input, mouse, paste, OSC 8 e renderer | Pendente |
| M6 | Matriz real de shells, CLIs e TUIs nos três targets | Pendente |
| M7 | Auditoria final, documentação, Sonar e preparação do release | Pendente |

## Contrato de portabilidade de skills

- O manifesto RadIA é a fonte canônica; arquivos de CLI são réplicas derivadas.
- Cada adaptador declara nome, formato, caminho de destino e capacidade suportada.
- O usuário vê preview de destino, arquivos, conflitos e impacto antes da gravação.
- A operação usa consentimento central e gravação transacional com rollback.
- O RadIA mantém um manifesto de propriedade com hashes para atualizar e remover somente réplicas
  que ele criou.
- Arquivos modificados manualmente nunca são sobrescritos ou removidos silenciosamente.
- Credenciais, tokens, caminhos privados desnecessários e conteúdo fora do pacote não são exportados.
- O diagnóstico diferencia CLI ausente, formato incompatível, conflito, divergência e sucesso.
- Alterações são descobertas sem reiniciar o Delphi.

O M1 introduziu o modelo canônico validado e quatro adaptadores isolados. Eles produzem `SKILL.md`
com frontmatter comum e paths de projeto específicos: `.agents/skills`, `.claude/skills`,
`.gemini/skills` e `.github/skills`. A gravação, sincronização e experiência visual pertencem ao M2
e ainda não são apresentadas ao usuário.

O M3 executou runtimes atuais dos quatro CLIs. Codex e Copilot reconheceram e invocaram a skill;
Gemini listou a skill do projeto; Claude confirmou a descoberta do diretório de skills. As duas
invocações restantes não foram enviadas a modelos porque os runtimes temporários não possuíam login.
Essa limitação de credencial não afeta a validação do formato e está registrada, sem ambiguidade, na
[evidência do M3](skill_portability_m3_evidence.json).

## Contrato do terminal

- Transporte, emulação e renderização possuem interfaces independentes.
- O núcleo VT não expõe tipos de terceiros nas APIs públicas do RadIA.
- O terminal preserva histórico, perfis, jornada compartilhada, consentimento e cancelamento atuais.
- Alternate screen restaura a tela principal ao encerrar.
- Cores ANSI, 256 cores e true color preservam foreground, background e atributos.
- Bracketed paste, teclado e protocolos de mouse só enviam sequências quando o processo os habilita.
- OSC 8 apresenta hyperlinks identificáveis e abertura submetida à política de segurança.
- Resize preserva cursor, regiões, caracteres largos, marcas combinantes e quebras explícitas.
- Fechar aba, painel ou IDE não deixa processo filho, deadlock ou acesso tardio à UI.

O M4 selecionou o núcleo VT nativo existente e o isolou por `IRadIATerminalEmulator`. O frame não
mantém mais uma classe concreta de tela; cria, alimenta, redimensiona, renderiza e limpa somente pelo
contrato. Essa decisão preserva o comportamento comprovado e permite substituir o núcleo sem expor
dependências à VCL, ConPTY ou à API pública.

## Matriz de aceite

| Jornada | Evidência obrigatória |
|---|---|
| Criar uma skill e exportar para um CLI | preview, consentimento, arquivos válidos e reconhecimento sem restart |
| Atualizar uma réplica sem conflito | hash anterior, troca atômica e novo reconhecimento |
| Encontrar uma réplica alterada manualmente | divergência visível e preservação do arquivo |
| Remover uma extensão | somente réplicas pertencentes ao RadIA são removidas |
| Abrir e fechar uma TUI | alternate screen restaurado e processo encerrado |
| Redimensionar uma TUI | layout, cursor, Unicode e regiões continuam válidos |
| Usar paste, mouse e hyperlink | modos negociados, consentimento aplicável e nenhuma entrada espúria |
| Encerrar o Delphi com terminal ativo | nenhum deadlock, crash ou processo órfão |

## Gares obrigatórios por marco

1. testes unitários da área alterada;
2. testes web e documentais quando UI ou documentação mudar;
3. build e testes Delphi proporcionais ao marco;
4. consulta ao SonarQube pela API REST;
5. revisão de trailing whitespace, limite de linha e strings Delphi;
6. atualização simultânea da referência central, guia, hints e tradução;
7. commit em inglês e push do marco comprovado.

## Critério de conclusão

O goal termina somente quando uma skill puder ser criada uma vez e utilizada nos quatro CLIs sem
duplicação manual, e quando o terminal executar a matriz definida com fidelidade e estabilidade nos
três targets Delphi. A ausência de falha não substitui evidência positiva de cada contrato.
