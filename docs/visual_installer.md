# Instalador visual e canal de release

O RadIA 2.0.0 possui um instalador visual único para Delphi 11 Win32, Delphi 12 Win32, Delphi 13
Win32 e Delphi 13 IDE64. O assistente detecta as IDEs instaladas, pré-seleciona os targets
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

## Gate externo restante

O código, o instalador e o catálogo estão preparados, mas a publicação de produção só pode ser
aprovada depois que um certificado de code signing confiável estiver disponível. Não use
certificado autoassinado nem altere o catálogo manualmente para contornar esse gate.
