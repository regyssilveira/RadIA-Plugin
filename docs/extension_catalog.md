# Catálogo remoto de extensões

O RadIA possui uma camada segura para descobrir e baixar extensões declarativas a partir de um
catálogo remoto. O catálogo é uma fonte de metadados; ele não concede confiança automaticamente ao
publicador. Todo artefato distribuído pelo catálogo precisa continuar sendo um pacote `.radiaext`
assinado: envelope v2 para manifesto sem recursos ou v3 quando transporta referências,
conhecimento, templates ou assets.

## Schema versão 1

```json
{
  "schemaVersion": 1,
  "name": "Catálogo da equipe",
  "extensions": [
    {
      "id": "TeamCommands",
      "name": "Comandos da equipe",
      "description": "Prompts revisados e mantidos pela equipe.",
      "version": "1.2.0",
      "package": {
        "url": "https://extensions.example.com/TeamCommands-1.2.0.radiaext",
        "size": 2048,
        "sha256": "HASH_SHA256_DE_64_CARACTERES"
      },
      "publisher": {
        "id": "empresa.time",
        "name": "Empresa — Time Delphi",
        "fingerprint": "FINGERPRINT_SHA256_DE_64_CARACTERES"
      }
    }
  ]
}
```

O documento tem limite de 1 MiB e pode conter até 500 extensões. IDs precisam ser PascalCase,
versões usam `major.minor.patch`, hashes e fingerprints são hexadecimais SHA-256 e URLs precisam ser
HTTPS absolutas sem credenciais ou fragmentos. IDs duplicados são rejeitados considerando
maiúsculas e minúsculas equivalentes.

## Download e verificação

O cliente do catálogo:

1. aceita somente HTTPS e desabilita redirects automáticos;
2. limita catálogo a 1 MiB e pacote a 20 MiB durante o próprio streaming;
3. confere tamanho e SHA-256 anunciados;
4. abre o pacote com o verificador `.radiaext`, incluindo lista fechada, ZIP bomb, paths, manifesto
   e assinatura RSA-SHA256;
5. exige pacote v2 ou v3 assinado;
6. compara ID, versão, ID do publicador e fingerprint com a entrada do catálogo;
7. valida em arquivo temporário e somente então faz a troca atômica do destino;
8. preserva um arquivo anterior quando download ou validação falha.

Mesmo depois dessas verificações, um publicador desconhecido passa pelo consentimento de primeiro
uso do gerenciador. Um catálogo adulterado não consegue transformar uma chave desconhecida em chave
confiável.

## Uso no gerenciador

1. Abra **Tools > Rad IA Extensions...**.
2. Clique em **Browse catalog...**.
3. Informe a URL HTTPS do catálogo e clique em **Load catalog**.
4. Use a busca para filtrar por nome, ID, descrição ou publicador.
5. Selecione uma extensão e clique em **Download**.
6. Revise a identidade e o fingerprint do publicador no consentimento de primeiro uso.

O catálogo e os pacotes são baixados em background, sem bloquear a thread visual da IDE. A URL é
lembrada em `%USERPROFILE%\RadIA\extension-catalog.json`; credenciais em URL são recusadas e não são
armazenadas. O pacote só segue para a instalação compartilhada depois de todas as verificações,
portanto o fluxo local e o remoto aplicam a mesma política de confiança.
