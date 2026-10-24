param([Parameter(Mandatory=$true)][string]$SetupPath)
$ErrorActionPreference = 'Stop'
$setup = (Resolve-Path -LiteralPath $SetupPath).Path
$registry = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\{C551D064-7E11-4F3A-89C0-32C5FD9B5BE2}_is1'
if (Test-Path $registry) { throw 'Ja existe uma instalacao por usuario. O teste nao vai altera-la.' }
$testRoot = Join-Path $env:TEMP ('AGBench-Installer-Test-' + [guid]::NewGuid().ToString('N'))
$appDir = Join-Path $testRoot 'Aplicativo de teste'
New-Item -ItemType Directory -Path $testRoot -Force | Out-Null
$settingsPath = Join-Path $env:APPDATA 'AGBench\settings.json'
$settingsHash = if (Test-Path -LiteralPath $settingsPath) { (Get-FileHash -LiteralPath $settingsPath).Hash } else { '' }
$uninstaller = Join-Path $appDir 'unins000.exe'
try {
    foreach ($step in @('install','upgrade')) {
        $log = Join-Path $testRoot ($step + '.log')
        $arguments = '/CURRENTUSER /VERYSILENT /SUPPRESSMSGBOXES /NORESTART /NOICONS /TASKS="" /DIR="' + $appDir + '" /LOG="' + $log + '"'
        $process = Start-Process -FilePath $setup -ArgumentList $arguments -WindowStyle Hidden -PassThru -Wait
        if ($process.ExitCode -ne 0) { throw ($step + ' falhou: ' + $process.ExitCode + '. Log: ' + $log) }
        foreach ($file in @('AGBench.exe','AGBench.dll','AGBench.runtimeconfig.json','coreclr.dll','PresentationFramework.dll','dxcompiler.dll','Licenses\THIRD-PARTY-NOTICES.txt','LICENSE-AGBench.txt')) {
            if (-not (Test-Path -LiteralPath (Join-Path $appDir $file))) { throw ('Arquivo nao instalado: ' + $file) }
        }
        $config = Get-Content -LiteralPath (Join-Path $appDir 'AGBench.runtimeconfig.json') -Raw | ConvertFrom-Json
        if (-not $config.runtimeOptions.includedFrameworks) { throw 'Publicacao depende de .NET instalado externamente.' }
        $uninstallEntry = Get-ItemProperty $registry
        if ($uninstallEntry.InstallLocation.TrimEnd('\') -ne $appDir.TrimEnd('\')) { throw 'Registro aponta para outra pasta.' }
        Write-Output ('OK: ' + $step + ' (runtime incluido e desinstalador registrado)')
    }
} finally {
    if (Test-Path -LiteralPath $uninstaller) {
        $process = Start-Process -FilePath $uninstaller -ArgumentList '/VERYSILENT /SUPPRESSMSGBOXES /NORESTART' -WindowStyle Hidden -PassThru -Wait
        if ($process.ExitCode -ne 0) { throw ('Desinstalacao falhou: ' + $process.ExitCode) }
    }
}
if (Test-Path -LiteralPath (Join-Path $appDir 'AGBench.exe')) { throw 'Executavel permaneceu depois da desinstalacao.' }
if (Test-Path $registry) { throw 'Registro de desinstalacao permaneceu.' }
$currentHash = if (Test-Path -LiteralPath $settingsPath) { (Get-FileHash -LiteralPath $settingsPath).Hash } else { '' }
if ($settingsHash -ne $currentHash) { throw 'Configuracoes do usuario foram alteradas.' }
Write-Output 'OK: desinstalacao e preservacao das configuracoes do usuario'
Write-Output ('Logs: ' + $testRoot)
