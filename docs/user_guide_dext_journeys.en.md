# DEXT server journeys

RadIA can create a buildable DEXT server from a list of endpoints. Both journeys use the same
versioned specification, show a preview before writing, create files atomically, open the project,
and require build validation.

## Choose a journey

- `/journey dext-minimal`: use it for small APIs or services with direct routes. It produces Startup,
  contracts, and mappings under `Endpoints`.
- `/journey dext-controllers`: use it for APIs grouped by responsibility and ready to grow. It
  produces Startup, contracts, and actions grouped in controllers.

Examples:

```text
/journey dext-minimal telemetry server with GET /health and POST /readings
/journey dext-controllers booking API with GET /bookings/{id} and POST /bookings
```

RadIA confirms the name, destination, Delphi version, platforms, port, and the HTTP method, path,
Pascal name, group, response status, and purpose of every endpoint. The contract accepts `GET`,
`POST`, `PUT`, `PATCH`, and `DELETE`; it assumes neither CRUD nor a specific domain.

## Generated files

The minimal journey generates the project, `Startup`, `Contracts`, `Endpoints`, `appsettings.json`,
an `.http` file, and a README. The controller journey replaces direct mappings with a grouped
controller unit and enables Swagger by default.

Initial handlers return functional JSON and identify the executed endpoint. They provide a buildable
base; business rules, authentication, and persistence are added only when approved requirements
include them.

## DEXT dependency

DEXT must be available on the IDE Library Path or through the `DEXT_ROOT` environment variable. With
`DEXT_ROOT`, the project looks for DCUs under
`%DEXT_ROOT%\Output\<BDS>_<Platform>_<Config>`. The generator never stores the private path of the
machine that created the project.

## Validation and recovery

After preview and consent, RadIA creates and opens the project. `ValidateCreatedProject` performs a
real build; a compiler failure rolls back files created by that operation. The journey must also
start the server and verify `/health` before reporting success. A missing dependency, unavailable
DEXT target, or blocked port is reported as a specific external blocker.

The `<Project>.http` file contains ready-to-run calls for every requested endpoint.
