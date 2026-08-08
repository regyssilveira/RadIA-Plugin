# Jornadas de servidores DEXT

O RadIA pode criar um servidor DEXT compilável a partir de uma lista de endpoints. As duas jornadas
usam a mesma especificação versionada, mostram um preview antes da escrita, criam os arquivos de
forma atômica, abrem o projeto e exigem validação de build.

## Escolha da jornada

- `/journey dext-minimal`: use em APIs pequenas ou serviços com rotas diretas. Produz Startup,
  contracts e mapeamentos em `Endpoints`.
- `/journey dext-controllers`: use em APIs organizadas por grupos e preparadas para crescer. Produz
  Startup, contracts e actions agrupadas em controllers.

Exemplos:

```text
/journey dext-minimal servidor de telemetria com GET /health e POST /readings
/journey dext-controllers API de reservas com GET /bookings/{id} e POST /bookings
```

O RadIA confirma nome, destino, Delphi, plataformas, porta e, para cada endpoint, método HTTP,
caminho, nome Pascal, grupo, status de resposta e finalidade. O contrato aceita `GET`, `POST`,
`PUT`, `PATCH` e `DELETE`; ele não pressupõe CRUD nem um domínio específico.

## Arquivos gerados

A jornada minimal gera o projeto, `Startup`, `Contracts`, `Endpoints`, `appsettings.json`, um arquivo
`.http` e um README. A jornada com controllers substitui os mapeamentos diretos por uma unit de
controllers agrupados e habilita Swagger por padrão.

Os handlers iniciais retornam JSON funcional e identificam o endpoint executado. Eles constituem
uma base compilável; regras de negócio, autenticação e persistência só são adicionadas quando fizerem
parte dos requisitos aprovados.

## Dependência DEXT

O DEXT deve estar disponível na Library Path da IDE ou pela variável de ambiente `DEXT_ROOT`. Quando
`DEXT_ROOT` é usada, o projeto procura DCUs em
`%DEXT_ROOT%\Output\<BDS>_<Platform>_<Config>`. O gerador nunca grava o caminho particular da máquina
que criou o projeto.

## Validação e recuperação

Após o preview e o consentimento, o RadIA cria e abre o projeto. `ValidateCreatedProject` executa o
build real; uma falha de compilação reverte os arquivos criados pela mesma operação. A jornada ainda
deve iniciar o servidor e verificar `/health` antes de declarar sucesso. Dependência ausente, target
DEXT indisponível ou porta bloqueada são informados como bloqueios externos específicos.

O arquivo `<Projeto>.http` contém chamadas prontas para todos os endpoints solicitados.
