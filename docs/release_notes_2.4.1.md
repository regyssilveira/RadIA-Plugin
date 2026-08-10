# Notas de release — RadIA 2.4.1

## Correção

- Corrige a falha `EResNotFound` ao abrir **Settings** no Delphi 13.
- Inclui o recurso VCL obrigatório do frame de configuração dos servidores MCP externos.
- Adiciona teste de regressão para impedir que frames programáticos sejam publicados sem seu DFM.

## Compatibilidade

- Delphi 12 Win32;
- Delphi 13 Win32;
- Delphi 13 IDE64.

O instalador visual é o único artefato necessário para o usuário final. Esta atualização preserva
configurações, credenciais, servidores MCP e dados locais existentes.

## Validação

- 1.031 testes Delphi aprovados, sem falhas ou vazamentos;
- 89 testes web e documentais aprovados;
- compilação aprovada nos três alvos suportados;
- smoke instalado aprovado no Delphi 13;
- catálogo runtime validado com 132 ferramentas;
- SonarQube Quality Gate `OK`, sem issues.
