# Perfil do ambiente Delphi

`GetDelphiEnvironmentProfile` oferece ao agente um inventário somente leitura e sanitizado da IDE e
do projeto ativos. Use a tool antes de sugerir componentes, APIs ou migrações que dependam da versão,
arquitetura, framework ou bibliotecas disponíveis.

## Como usar

No chat, execute:

```text
/tool GetDelphiEnvironmentProfile
```

O modo agente também pode chamar a tool quando o objetivo depende do ambiente Delphi.

## Dados retornados

- versão, arquitetura e edição da IDE, quando publicada no Registro pelo Delphi;
- capacidades OTA disponíveis;
- projeto, framework, configuração e plataforma-alvo;
- search paths declarados no `.dproj`;
- runtime packages declarados no `.dproj`;
- bibliotecas reconhecidas pelo conteúdo do projeto.

A versão, arquitetura, edição e capacidades têm origem na OTA e na chave-base oficial da IDE. Os
demais campos combinam o snapshot do workspace com leitura limitada do `.dproj` ativo.

## Privacidade e limites

A tool não envia dados por conta própria, não modifica o projeto e não lê arquivos fora do `.dproj`
ativo. Search paths absolutos dentro do projeto são substituídos por `{workspace}`. Caminhos
absolutos externos são representados por `<external>`, evitando exposição de nomes de usuários ou
pastas privadas. Variáveis MSBuild, como `$(BDS)`, permanecem visíveis porque não revelam o caminho
expandido da máquina.

O arquivo de projeto é limitado a 2 MiB e cada coleção retorna no máximo 100 itens únicos. Uma
edição não publicada pelo Delphi aparece como `unknown`; esse valor não deve ser interpretado como
uma edição específica.

## Recuperação

Se o perfil estiver incompleto:

1. confirme que há um projeto Delphi ativo e salvo;
2. confira se o `.dproj` contém `FrameworkType`, search paths e packages esperados;
3. execute `/doctor` para verificar o workspace e o catálogo de tools;
4. use `/status project` para conferir o snapshot ativo.
