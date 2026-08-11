# Instalador visual e canal de release

O RadIA possui um instalador visual único para Delphi 12 Win32, Delphi 13 Win32 e Delphi 13
IDE64. O assistente detecta as IDEs instaladas, pré-seleciona os targets encontrados e permite
personalizar a seleção.

Cada componente contém o pacote específico daquela combinação e reutiliza
`Install-RadIA.Package.ps1`. O fluxo preserva validação do manifesto, hashes, instalação, reparo e
desinstalação com preservação de dados por padrão.

O instalador visual recusa instalação, reparo e desinstalação enquanto qualquer processo `bds.exe`
estiver aberto. O script interno repete a mesma barreira antes de copiar BPL, DCP, bridge, assets
Web, `WebView2Loader.dll` ou alterar o Registro.

Antes de copiar uma versão, o instalador remove somente a pasta interna do target selecionado,
evitando arquivos residuais de releases anteriores. Uma falha do instalador interno interrompe a
instalação visual e devolve um exit code diferente de zero.

O script do pacote descobre o diretório da IDE nos registros do usuário ou da máquina, valida todos
os assets Web presentes no manifesto, verifica a atualização do `WebView2Loader.dll` e confirma o
registro da BPL após instalar ou reparar. O modo de desinstalação não depende de a IDE continuar
presente no disco e mantém `%APPDATA%\RadIA` salvo, salvo quando a remoção explícita de dados for
solicitada.

## Gerar o instalador

Instale o Inno Setup 6 e gere os três ZIPs Release do mesmo commit. Depois execute:

```powershell
powershell.exe -ExecutionPolicy Bypass `
  -File scripts\New-RadIA.VisualInstaller.ps1
```

O nome do resultado usa a versão de `package.json`. Para obter o caminho atual:

```powershell
$version = (Get-Content package.json -Raw | ConvertFrom-Json).version
$installer = "Output\Installer\RadIA-v$version-Setup.exe"
```
`VisualInstallerEvidence.json` registra versão, tamanho, SHA-256 e o estado Authenticode
informativo.

A evidência de cada release fica em `visual_installer_evidence_<versão>.json`. O estado
`NotSigned` é intencional: o RadIA é aberto, pode ser compilado pelo usuário e não exige
certificado para publicação.

## Validar

O gate valida identidade, versão, tamanho, hash e correspondência do estado Authenticode:

```powershell
powershell.exe -ExecutionPolicy Bypass `
  -File scripts\Test-RadIA.VisualInstaller.ps1
```

## Atualizações do RadIA

O RadIA 2.8.0 não verifica, baixa ou instala novas versões automaticamente. O usuário deve baixar o
instalador da release, fechar todas as instâncias do Delphi e executá-lo manualmente. O script
`New-RadIA.ReleaseChannel.ps1` permanece apenas como preparação técnica para um atualizador futuro;
seu `stable.json` não é consumido pelo produto nem publicado na release atual.

## Pipeline de release

O workflow `.github/workflows/release.yml` executa a cadeia completa em um runner Windows com
Delphi:

1. confirma que a tag é exatamente `v` mais a versão do `package.json`;
2. executa lint, testes Web e auditoria da documentação;
3. recompila os três pacotes Release a partir do commit da tag;
4. confirma que os pacotes compartilham versão, commit limpo e hashes válidos;
5. gera e valida o instalador sem depender de certificado;
6. preserva as evidências no artefato interno da execução e na auditoria versionada;
7. publica somente o instalador para o usuário.

Os três ZIPs continuam sendo gerados temporariamente como entradas verificáveis do instalador.
Eles não são anexados à GitHub Release: o instalador visual é o único artefato de instalação
oferecido ao usuário. Quem preferir compilar ou empacotar manualmente pode usar `build.ps1`. Essa separação evita
downloads técnicos redundantes sem remover a validação individual de versão, arquitetura,
manifesto e SHA-256 feita antes de montar o instalador.

O workflow pode ser acionado manualmente sem publicação para validar a distribuição; uma tag `v*`
publica o release. O contrato do pipeline pode ser auditado localmente com:

```powershell
powershell.exe -ExecutionPolicy Bypass `
  -File scripts\Test-RadIA.ReleasePipeline.ps1
```

Certificado e marketplace não são gates do canal atual. O hash SHA-256 e a origem da release
continuam obrigatórios para verificar os artefatos.
