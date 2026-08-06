# Instalador visual e canal de release

O RadIA 2.0.0 possui um instalador visual único para Delphi 12 Win32, Delphi 13 Win32 e Delphi 13
IDE64. O assistente detecta as IDEs instaladas, pré-seleciona os targets
encontrados e permite personalizar a seleção.

Cada componente contém o pacote específico daquela combinação e reutiliza
`Install-RadIA.Package.ps1`. Portanto, o fluxo visual mantém as mesmas garantias já usadas na
matriz real: validação integral do manifesto, hashes, instalação, reparo e desinstalação com
preservação de dados por padrão.

## Gerar o instalador

Instale o Inno Setup 6 e gere primeiro os quatro ZIPs Release do mesmo commit. Depois execute:

```powershell
powershell.exe -ExecutionPolicy Bypass `
  -File scripts\New-RadIA.VisualInstaller.ps1
```

O resultado fica em `Output\Installer\RadIA-v2.0.0-Setup.exe`. O arquivo
`VisualInstallerEvidence.json` registra versão, tamanho, SHA-256, estado Authenticode, certificado
e timestamp.

A execução de desenvolvimento comprovada está registrada em
[`visual_installer_evidence_2.0.0.json`](visual_installer_evidence_2.0.0.json). O estado
`NotSigned` é intencionalmente visível e mantém o gate de produção fechado.

Para assinar a versão de produção, informe o thumbprint de um certificado de code signing com
chave privada:

```powershell
powershell.exe -ExecutionPolicy Bypass `
  -File scripts\New-RadIA.VisualInstaller.ps1 `
  -CertificateThumbprint "<THUMBPRINT>"
```

O gerador usa SHA-256, timestamp RFC 3161 e falha se o `SignTool` não conseguir produzir uma
assinatura Authenticode válida.

## Validar

O modo de desenvolvimento valida identidade, versão, tamanho, hash e estado de assinatura:

```powershell
powershell.exe -ExecutionPolicy Bypass `
  -File scripts\Test-RadIA.VisualInstaller.ps1
```

O gate de produção também exige assinatura válida e timestamp:

```powershell
powershell.exe -ExecutionPolicy Bypass `
  -File scripts\Test-RadIA.VisualInstaller.ps1 `
  -RequireSignature
```

## Publicar o canal

O catálogo estável é fail-closed: exige HTTPS e recusa instaladores sem Authenticode válido.

```powershell
powershell.exe -ExecutionPolicy Bypass `
  -File scripts\New-RadIA.ReleaseChannel.ps1 `
  -InstallerPath Output\Installer\RadIA-v2.0.0-Setup.exe `
  -DownloadUrl "https://downloads.example.com/RadIA-v2.0.0-Setup.exe"
```

Somente testes locais podem usar `-AllowUnsignedDevelopment`. Esse parâmetro altera explicitamente
o nome do canal para `development`; ele não consegue gerar um catálogo `stable`.

## Pipeline de release assinada

O workflow `.github/workflows/signed-release.yml` executa a cadeia completa em um runner Windows
com Delphi:

1. confirma que a tag é exatamente `v` mais a versão do `package.json`;
2. executa lint, testes Web e auditoria da documentação;
3. importa temporariamente o PFX e valida chave privada, EKU de code signing e validade;
4. recompila os três pacotes Release a partir do commit da tag;
5. confirma que os pacotes compartilham versão, commit limpo e hashes válidos;
6. gera e valida o instalador com Authenticode e timestamp obrigatórios;
7. cria o catálogo `stable` com a URL HTTPS da GitHub Release;
8. publica artefatos e remove o certificado e o PFX do runner em `always()`.

Configure estes valores no repositório:

- secret `RADIA_SIGNING_PFX_BASE64`: PFX codificado em Base64;
- secret `RADIA_SIGNING_PFX_PASSWORD`: senha do PFX;
- variável opcional `RADIA_TIMESTAMP_URL`: servidor RFC 3161.

Proteja os secrets com acesso mínimo e use aprovação de ambiente para produção. O workflow pode ser
acionado manualmente sem publicação para validar a distribuição; uma tag `v*` publica a release.
O contrato fail-closed do pipeline pode ser auditado localmente com:

```powershell
powershell.exe -ExecutionPolicy Bypass `
  -File scripts\Test-RadIA.ReleasePipeline.ps1
```

## Gate externo restante

O código, o instalador e o catálogo estão preparados, mas a publicação de produção só pode ser
aprovada depois que um certificado de code signing confiável estiver disponível. Não use
certificado autoassinado nem altere o catálogo manualmente para contornar esse gate.
