# Retrofit OpenAPI/Swagger

Execute `InventoryExistingApiRoutes` para revisar rotas `MapGet`/`MapPost`/`MapPut`/`MapPatch`/
`MapDelete` e atributos `HttpGet`/`HttpPost`/`HttpPut`/`HttpPatch`/`HttpDelete` nas units do projeto.

Abra a unit que implementa `ConfigureApplication` e execute `PrepareOpenApiRetrofit` com título e
versão. A ferramenta preserva o conteúdo existente e prepara um preview que adiciona as dependências
OpenAPI, as opções e `TSwaggerExtensions.UseSwagger`. Ela rejeita units incompatíveis e projetos que
já configuram Swagger.

Aplique pelo fluxo genérico de patches somente depois de revisar o preview. Em seguida, compile o
projeto e verifique o endpoint Swagger em runtime.
