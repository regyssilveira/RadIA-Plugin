# Instalador visual e canal de release

O RadIA 2.0.0 possui um instalador visual único para Delphi 12 Win32, Delphi 13 Win32 e Delphi 13
IDE64. O assistente detecta as IDEs instaladas, pré-seleciona os targets encontrados e permite
personalizar a seleção.

Cada componente contém o pacote específico daquela combinação e reutiliza
`Install-RadIA.Package.ps1`. O fluxo preserva validação do manifesto, hashes, instalação, reparo e
desinstalação com preservação de dados por padrão.

## Gerar o instalador

Instale o Inno Setup 6 e gere os três ZIPs Release do mesmo commit. Depois execute:

```powershell
powershell.exe -ExecutionPolicy Bypass `
  -File scripts\New-RadIA.VisualInstaller.ps1
```

O resultado fica em `Output\Installer\RadIA-v2.0.0-Setup.exe`.
`VisualInstallerEvidence.json` registra versão, tamanho, SHA-256 e o estado Authenticode
informativo.

A execução comprovada está registrada em
[`visual_installer_evidence_2.0.0.json`](visual_installer_evidence_2.0.0.json). O estado
`NotSigned` é intencional: o RadIA é aberto, pode ser compilado pelo usuário e não exige
certificado para publicação.

## Validar

O gate valida identidade, versão, tamanho, hash e correspondência do estado Authenticode:

```powershell
powershell.exe -ExecutionPolicy Bypass `
  -File scripts\Test-RadIA.VisualInstaller.ps1
```

## Publicar o canal

O catálogo estável exige HTTPS e publica tamanho, SHA-256 e estado Authenticode para verificação:

```powershell
powershell.exe -ExecutionPolicy Bypass `
  -File scripts\New-RadIA.ReleaseChannel.ps1 `
  -InstallerPath Output\Installer\RadIA-v2.0.0-Setup.exe `
  -DownloadUrl (
    "https://github.com/regyssilveira/RadIA-Plugin/releases/" +
    "download/v2.0.0/RadIA-v2.0.0-Setup.exe"
  )
```

## Pipeline de release

O workflow `.github/workflows/release.yml` executa a cadeia completa em um runner Windows com
Delphi:

1. confirma que a tag é exatamente `v` mais a versão do `package.json`;
2. executa lint, testes Web e auditoria da documentação;
3. recompila os três pacotes Release a partir do commit da tag;
4. confirma que os pacotes compartilham versão, commit limpo e hashes válidos;
5. gera e valida o instalador sem depender de certificado;
6. cria o catálogo `stable` com a URL HTTPS da GitHub Release;
7. publica instalador, ZIPs, `SHA256SUMS.txt`, catálogo e evidências.

O workflow pode ser acionado manualmente sem publicação para validar a distribuição; uma tag `v*`
publica o release. O contrato do pipeline pode ser auditado localmente com:

```powershell
powershell.exe -ExecutionPolicy Bypass `
  -File scripts\Test-RadIA.ReleasePipeline.ps1
```

Não existe gate externo de certificado ou marketplace para a versão 2.0.0.
