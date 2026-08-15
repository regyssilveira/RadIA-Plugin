# Documentação de API e mocks seguros

O RadIA gera `API.md` e units de mocks a partir do índice semântico local. A geração sempre começa
com uma preview somente leitura: nenhum arquivo é criado e nenhuma unit é registrada nessa etapa.

## Gerar `API.md`

1. Confirme que o projeto ativo foi indexado pelo motor semântico.
2. Execute `PrepareApiDocumentation`; `fileName` é opcional e usa `API.md` por padrão.
3. Revise path, conteúdo e SHA-256 retornados.
4. Execute `ApplyGeneratedArtifact` com o `previewId` somente depois da revisão e do consentimento.
5. Use `RevertGeneratedArtifact` para remover o arquivo enquanto ele permanecer inalterado.

O documento inclui somente símbolos indexados do projeto. RTL, VCL, referências de units e membros
privados não entram no inventário. A ordenação por arquivo e posição torna a saída reproduzível.

## Gerar uma unit de mock

1. Escolha uma interface indexada, como `IOrderService`.
2. Execute `PrepareMockUnit` informando `interfaceName` e um `unitName` Pascal válido.
3. Opcionalmente informe `relativeDirectory`; o padrão é `Tests`.
4. Mantenha `registerInProject` como `false` para criar a unit sem alterar o projeto, ou escolha
   `true` depois de revisar que ela deve participar do build.
5. Revise o conteúdo e aplique a mesma preview com `ApplyGeneratedArtifact`.

O mock herda de `TInterfacedObject`, implementa os métodos resolvidos da interface e gera corpos que
lançam `ENotImplemented`. Isso mantém a intenção explícita: o usuário deve completar o comportamento
do double antes de usá-lo em testes.

## Garantias e recuperação

- arquivos existentes nunca são sobrescritos;
- paths fora da raiz do projeto são rejeitados;
- previews expiram e não podem ser aplicadas duas vezes;
- a escrita usa staging e publicação atômica;
- registro no projeto é opcional e acontece somente depois da criação do arquivo;
- falha de registro remove o arquivo recém-criado;
- reversão é bloqueada se o usuário modificar o artefato depois da aplicação.

Essas ferramentas não modificam assinaturas, implementations, DFM ou outras units existentes.
