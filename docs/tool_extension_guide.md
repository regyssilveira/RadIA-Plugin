# Extensões de ferramentas do RadIA

## Objetivo

A API de extensões permite que outro pacote Delphi publique ferramentas no registry agentivo sem
acessar o container interno, a OTA ou o transporte MCP. Toda ferramenta registrada continua passando
pelo mesmo executor de política, consentimento, auditoria, sanitização e cancelamento do RadIA.

A versão atual da API é retornada por `GetRadIAToolExtensionApiVersion` e também está disponível na
constante `CRadIAToolExtensionApiVersion`.

## Contratos públicos

Uma extensão implementa `IRadIAToolExtension` e fornece:

- `TRadIAToolExtensionDescriptor`, com ID, versão, prefixo exclusivo e intervalo de API compatível;
- uma ou mais implementações de `IRadIATool`;
- `RegisterTools`, que entrega as ferramentas ao registrar limitado da extensão.

O host valida todos os descritores antes de alterar o registry. O registro em lote é atômico: nome
inválido, schema inválido, colisão ou duplicidade rejeita o lote inteiro.

O nome de cada ferramenta deve começar com o `ToolPrefix` declarado pela extensão. Isso delimita
ownership e impede que uma extensão remova ferramentas internas ou pertencentes a outro pacote.

## Ciclo de vida obrigatório

O retorno de `RegisterRadIAToolExtension` deve permanecer em uma variável global de interface do
pacote externo:

```pascal
var
  GRegistration: IRadIAToolExtensionRegistration;

initialization
  GRegistration := RegisterRadIAToolExtension(
    TRadIASampleToolExtension.Create
  );

finalization
  GRegistration := nil;
```

Ao liberar o token, o host remove atomicamente somente as ferramentas daquela extensão. O token deve
ser liberado na `finalization` da extensão, antes que sua BPL seja descarregada. Manter referências a
objetos implementados por uma BPL já descarregada é inválido no Delphi.

O pacote externo deve declarar `RadIA` em `requires`. Isso garante que o host esteja inicializado
antes da extensão e que a finalização da extensão ocorra primeiro.

## Segurança

- A extensão não recebe acesso ao registry completo e não pode chamar `Clear`.
- Risco e schemas são obrigatórios e validados pelo registry.
- Ferramentas mutáveis continuam exigindo a política de consentimento do RadIA.
- O `ProjectId` e demais campos de contexto chegam pelo `TRadIAToolRequest`.
- Operações demoradas devem observar `ARequest.CancellationToken`.
- Secrets não devem ser incluídos em resultados, mensagens de erro ou descritores.
- O pacote externo não deve reter interfaces OTA nem componentes VCL além do ciclo documentado pela
  própria API da IDE.

## Exemplo

O diretório `Examples/ToolExtension` contém um pacote independente com a ferramenta somente leitura
`SampleProjectInfo`. Ele usa apenas `RadIA.Core.Extensions` e `RadIA.Core.Tools`, registra a extensão
na inicialização e libera o token na finalização.

Depois de instalar a BPL do exemplo, `SampleProjectInfo` aparece automaticamente no chat agentivo e
em `tools/list` do MCP. Ao descarregar a extensão, a ferramenta deixa o catálogo sem reiniciar o
servidor MCP.

## Compatibilidade

A extensão deve declarar o menor e o maior nível da API que suporta. O registro é recusado quando a
versão corrente não pertence ao intervalo informado. A API de nível 1 é suportada no Delphi 11,
Delphi 12 e Delphi 13, tanto para a IDE Win32 quanto para a IDE64 disponível no Delphi 13.
