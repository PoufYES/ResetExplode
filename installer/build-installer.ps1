param(
    [string]$DotnetPath = 'dotnet',
    [string]$IsccPath = '',
    [string]$WorkDirectory = (Join-Path $env:TEMP 'AGBench-installer-build')
)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$projectRoot = Split-Path $PSScriptRoot -Parent
$project = Join-Path $projectRoot 'AGBench.csproj'
[xml]$projectXml = Get-Content -LiteralPath $project
$version = [string]$projectXml.Project.PropertyGroup.Version
if ($version -notmatch '^\d+\.\d+\.\d+$') { throw 'Versao do projeto invalida.' }
if (-not $IsccPath) {
    $IsccPath = @(
        (Join-Path $env:LOCALAPPDATA 'Programs\Inno Setup 6\ISCC.exe'),
        (Join-Path ${env:ProgramFiles(x86)} 'Inno Setup 6\ISCC.exe'),
        (Join-Path $env:ProgramFiles 'Inno Setup 6\ISCC.exe')
    ) | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
}
if (-not $IsccPath) { throw 'Instale o Inno Setup 6 (ISCC.exe).' }
$payload = Join-Path $WorkDirectory ('payload-' + [guid]::NewGuid().ToString('N'))
$prerequisites = Join-Path $WorkDirectory 'prerequisites'
New-Item -ItemType Directory -Path $payload,$prerequisites -Force | Out-Null
$pawnio = Join-Path $prerequisites 'PawnIO_setup.exe'
$pawnioHash = '1F519A22E47187F70A1379A48CA604981C4FCF694F4E65B734AAA74A9FBA3032'
if (-not (Test-Path -LiteralPath $pawnio)) {
    Invoke-WebRequest 'https://github.com/namazso/PawnIO.Setup/releases/download/2.2.0/PawnIO_setup.exe' -OutFile $pawnio
}
if ((Get-FileHash -LiteralPath $pawnio -Algorithm SHA256).Hash -ne $pawnioHash) { throw 'Hash do PawnIO nao confere.' }
if ((Get-AuthenticodeSignature -LiteralPath $pawnio).Status -ne 'Valid') { throw 'Assinatura do PawnIO nao e valida.' }
try {
    # Native compiler warnings on stderr must not abort a successful publish in Windows PowerShell.
    $ErrorActionPreference = 'Continue'
    & $DotnetPath publish $project -c Release -r win-x64 --self-contained true '-p:PublishSingleFile=false' '-p:PublishTrimmed=false' '-p:BundleSerialDrivers=false' '-p:DebugType=None' '-p:DebugSymbols=false' -o $payload --nologo
    if ($LASTEXITCODE -ne 0) { throw 'Falha no dotnet publish.' }
    $ErrorActionPreference = 'Stop'
    if (-not (Test-Path -LiteralPath (Join-Path $payload 'AGBench.exe'))) { throw 'Executavel nao gerado.' }
    if (-not (Test-Path -LiteralPath (Join-Path $payload 'coreclr.dll'))) { throw 'Runtime .NET nao incluido.' }
    Copy-Item -LiteralPath (Join-Path $projectRoot 'LICENSE') -Destination (Join-Path $payload 'LICENSE-AGBench.txt')
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'INSTALACAO.txt') -Destination (Join-Path $payload 'LEIA-ME.txt')
    & (Join-Path $PSScriptRoot 'collect-licenses.ps1') -ProjectRoot $projectRoot -Payload $payload
    $ErrorActionPreference = 'Continue'
    & $IsccPath ('/DPayloadDir=' + $payload) ('/DPrerequisiteDir=' + $prerequisites) ('/DAppVersion=' + $version) (Join-Path $PSScriptRoot 'AGBench.iss')
    if ($LASTEXITCODE -ne 0) { throw 'Falha no compilador do instalador.' }
    $ErrorActionPreference = 'Stop'
    $output = Join-Path $projectRoot ('release\AGBench-' + $version + '-Setup-x64.exe')
    $hash = (Get-FileHash -LiteralPath $output -Algorithm SHA256).Hash.ToLowerInvariant()
    [IO.File]::WriteAllText($output + '.sha256', $hash + '  ' + [IO.Path]::GetFileName($output) + "`r`n", [Text.Encoding]::ASCII)
    Write-Output ('PRONTO: ' + $output)
} finally {
    $ErrorActionPreference = 'Stop'
    # Staging is private to this build. Keep it for installer verification; no user data is copied.
}
