# OpenAPI/Swagger retrofit

Run `InventoryExistingApiRoutes` to review `MapGet`/`MapPost`/`MapPut`/`MapPatch`/`MapDelete` routes
and `HttpGet`/`HttpPost`/`HttpPut`/`HttpPatch`/`HttpDelete` attributes across project units.

Open the unit that implements `ConfigureApplication`, then run `PrepareOpenApiRetrofit` with a title
and version. The tool preserves existing content and prepares a preview that adds OpenAPI dependencies,
options, and `TSwaggerExtensions.UseSwagger`. It rejects incompatible units and existing Swagger setup.

Apply through the generic patch workflow only after reviewing the preview. Then build the project and
verify the Swagger endpoint at runtime.
