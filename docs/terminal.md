# Terminal acoplável

O RadIA 2.0 inclui um terminal nativo acoplável à IDE. Abra-o em **Tools/Ferramentas > Rad IA
Terminal**. A janela usa o mesmo mecanismo de docking do chat, portanto posição, tamanho e
visibilidade acompanham o desktop do Delphi.

## Recursos

- perfis para Windows PowerShell e Command Prompt;
- diretório de trabalho automático na pasta do projeto Delphi ativo;
- captura incremental e simultânea de stdout e stderr;
- botão **Stop** que encerra toda a árvore de processos;
- timeout máximo de 30 minutos por comando;
- histórico persistente dos últimos 200 comandos;
- reutilização de comandos pelo seletor de histórico;
- snippets para build do Delphi 13, testes, `git status` e `git diff --check`;
- saída monoespaçada com código de saída e estado final.

## Fluxo de uso

1. Abra um projeto na IDE.
2. Abra **Rad IA Terminal**.
3. Escolha PowerShell ou Command Prompt.
4. Digite um comando ou selecione um snippet.
5. Clique em **Run**.
6. Use **Stop** para cancelar o processo e seus subprocessos.

O terminal executa exatamente o comando informado pelo usuário. Ele não habilita automaticamente
permissões de agente ou opções autônomas dos CLIs. O histórico é salvo localmente em
`%APPDATA%\RadIA\terminal-history.json` e não contém stdout, stderr, tokens ou credenciais — apenas
perfil, comando, horário e código de saída.

## Encerramento seguro

Cada execução recebe um Job Object do Windows com encerramento em cascata. Ao cancelar, fechar o
painel, descarregar o plugin ou encerrar a IDE, o RadIA finaliza o processo principal e todos os
filhos. Atualizações da interface são enfileiradas na thread principal e descartadas se o painel já
tiver sido destruído.
