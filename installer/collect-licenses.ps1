param([Parameter(Mandatory=$true)][string]$ProjectRoot, [Parameter(Mandatory=$true)][string]$Payload)
$ErrorActionPreference = 'Stop'
$assets = Get-Content -LiteralPath (Join-Path $ProjectRoot 'obj\project.assets.json') -Raw | ConvertFrom-Json
$packageRoots = @($assets.packageFolders.PSObject.Properties.Name)
$licenses = Join-Path $Payload 'Licenses'
New-Item -ItemType Directory -Path $licenses -Force | Out-Null
$inventory = New-Object 'System.Collections.Generic.List[string]'
$inventory.Add('AG Bench - componentes de terceiros')
$inventory.Add('Licencas das dependencias nao sao substituidas pela licenca MIT do aplicativo.')
$inventory.Add('Os componentes MPL-2.0 sao usados sem modificacao. O codigo-fonte e suas versoes estao disponiveis nos repositorios indicados nos metadados de cada pacote.')
$inventory.Add('')
foreach ($entry in $assets.libraries.PSObject.Properties) {
    if ($entry.Value.type -ne 'package') { continue }
    $package = $null
    foreach ($root in $packageRoots) {
        $candidate = Join-Path $root $entry.Value.path
        if (Test-Path -LiteralPath $candidate) { $package = $candidate; break }
    }
    if (-not $package) { throw ('Pacote ausente: ' + $entry.Name) }
    $metadata = Get-ChildItem -LiteralPath $package -Filter '*.nuspec' | Select-Object -First 1
    if (-not $metadata) { continue }
    [xml]$xml = Get-Content -LiteralPath $metadata.FullName -Raw
    $data = $xml.package.metadata
    $packageDir = Join-Path $licenses ($entry.Name.Replace('/', '-'))
    New-Item -ItemType Directory -Path $packageDir -Force | Out-Null
    Copy-Item -LiteralPath $metadata.FullName -Destination (Join-Path $packageDir 'metadata.nuspec')
    foreach ($file in @(Get-ChildItem -LiteralPath $package -Recurse -File | Where-Object { $_.Name -match '(?i)license|licence|copying|copyright|third.?party.?notices|notice\.txt' })) {
        $relative = $file.FullName.Substring($package.Length).TrimStart('\','/')
        $destination = Join-Path $packageDir $relative
        New-Item -ItemType Directory -Path (Split-Path $destination -Parent) -Force | Out-Null
        Copy-Item -LiteralPath $file.FullName -Destination $destination
    }
    $licenseText = if ($data.license) { $data.license.InnerText } else { [string]$data.licenseUrl }
    $inventory.Add($entry.Name + ' | ' + $licenseText + ' | ' + [string]$data.projectUrl)
    if ($data.repository) { $inventory.Add('  Source: ' + $data.repository.url + ' commit=' + $data.repository.commit) }
}
$runtimeConfig = Get-Content -LiteralPath (Join-Path $Payload 'AGBench.runtimeconfig.json') -Raw | ConvertFrom-Json
foreach ($framework in $runtimeConfig.runtimeOptions.includedFrameworks) {
    $id = $framework.name.ToLowerInvariant() + '.runtime.win-x64'
    $pack = $null
    foreach ($root in $packageRoots) {
        $candidate = Join-Path $root ($id + '\' + $framework.version)
        if (Test-Path -LiteralPath $candidate) { $pack = $candidate; break }
    }
    if (-not $pack) { throw ('Licenca do runtime ausente: ' + $id) }
    $destination = Join-Path $licenses ($id + '-' + $framework.version)
    New-Item -ItemType Directory -Path $destination -Force | Out-Null
    $runtimeNotices = @(Get-ChildItem -LiteralPath $pack -File | Where-Object { $_.Name -match '(?i)license|notice|\.nuspec$' })
    if (-not $runtimeNotices.Count) { throw ('Avisos do runtime ausentes: ' + $id) }
    $runtimeNotices | Copy-Item -Destination $destination
    $inventory.Add($id + '/' + $framework.version + ' | MIT e avisos de terceiros | https://github.com/dotnet/runtime ; https://github.com/dotnet/wpf')
}
$inventory.Add('')
$inventory.Add('.NET 8 e Windows Desktop Runtime: componentes Microsoft redistribuidos sem modificacao. Licencas e avisos de terceiros incluidos nas pastas dos runtimes.')
$inventory.Add('PawnIO 2.2.0: instalador oficial redistribuido intacto, assinado por namazso. Instalacao opcional; https://pawnio.eu/ ; https://github.com/namazso/PawnIO.Setup/releases/tag/2.2.0')
$inventory.Add('Permissao de redistribuir o instalador oficial: https://github.com/namazso/PawnIO.Modules/wiki/Using-PawnIO-Modules#licensing-considerations')
$inventory.Add('Drivers seriais de WCH, Silicon Labs, FTDI e Arduino NAO sao redistribuidos neste instalador. Na aba MAKER, use PAGINA OFICIAL para obter o pacote e aceitar a licenca do fabricante. Recursos de deteccao e gerenciamento continuam disponiveis.')
[IO.File]::WriteAllLines((Join-Path $licenses 'THIRD-PARTY-NOTICES.txt'), $inventory, (New-Object Text.UTF8Encoding($false)))
if (Test-Path -LiteralPath (Join-Path $PSScriptRoot 'licenses')) {
    Copy-Item -Path (Join-Path $PSScriptRoot 'licenses\*') -Destination $licenses -Recurse
}
