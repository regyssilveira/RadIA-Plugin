# Backlog do RadIA

Este arquivo contém somente trabalho aberto. Histórico, marcos concluídos, métricas e notas de
release não pertencem ao backlog.

O backlog não registra versões, entregas concluídas, evidências ou planos internos.

## Goal ativo: experiência Delphi completa e determinística

Transformar objetivos comuns do programador Delphi em fluxos simples, seguros e verificáveis,
aproveitando as ferramentas existentes antes de ampliar o catálogo.

A única frente aberta é a consolidação da plataforma automatizada de uso. Planos internos de
engenharia permanecem separados da documentação pública.

## Fundação transversal — testes automatizados de uso

- [ ] **Plataforma de integração e ponta a ponta:** automatizar instalação isolada, abertura do
  Delphi, configuração sanitizada, chat, tools, editor, Designer, build, testes, debugger, terminal,
  consentimento e recuperação de falhas nos alvos Delphi 12 e 13.

A plataforma deve possuir três camadas:

1. integração de serviços e adapters sem abrir a IDE;
2. integração OTA carregada em uma instância descartável do Delphi;
3. jornadas de usuário ponta a ponta com projetos-fixture, ações reais e evidências verificáveis.

Gate: uma execução limpa deve instalar o RadIA em ambiente isolado, abrir cada IDE suportada,
executar a matriz crítica, coletar logs, screenshots e resultados estruturados e restaurar o ambiente
sem depender de intervenção humana. Falhas precisam identificar etapa, versão da IDE e artefato de
diagnóstico, sem expor credenciais.

Esse gate integra obrigatoriamente toda release. A publicação deve executar, no mesmo comando e sem
opções de exclusão, a suíte completa de integração e ponta a ponta, a criação e os testes funcionais e
DUnitX da calculadora e a criação, abertura e navegação imediata de projetos. Um desses grupos ausente,
ignorado ou reprovado bloqueia a release.

## Definição de concluído

Cada item precisa de:

- contrato e ameaça documentados antes da implementação;
- suporte comprovado no Delphi 12 e 13, com capacidade indisponível reportada explicitamente;
- testes unitários, integração OTA e cenário ponta a ponta proporcional ao risco;
- cenário automatizado de uso incluído na matriz de regressão para cada comportamento novo;
- preview, consentimento, fingerprint e rollback para qualquer mutação;
- atualização simultânea do manual, referências, hints, traduções e testes documentais;
- build local, DUnitX, lint aplicável e SonarQube aprovados;
- evidência observável do resultado, não apenas existência de classes ou tools.
