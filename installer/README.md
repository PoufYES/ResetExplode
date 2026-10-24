# Instalador do AG Bench

O produto neste repositório é o **AG Bench**. O pacote gerado é
`release/AGBench-0.16.0-Setup-x64.exe`: distribua somente esse executável.
O arquivo `.sha256` ao lado é opcional, para conferir a integridade.

## Instalação

- Windows 10 1809 ou posterior / Windows 11, x64.
- Instalação padrão em `Program Files\AG Bench`, com elevação de administrador,
  atalhos, registro em Aplicativos instalados e desinstalador.
- .NET 8 e Windows Desktop Runtime incluídos: não exigem download no destino.
- PawnIO 2.2.0 oficial incluído, opcional e instalado apenas quando ausente.
  O build confere SHA-256 e assinatura Authenticode desse pré-requisito.
- Drivers seriais proprietários não são embutidos no pacote de distribuição.
  A aba MAKER preserva detecção, gerenciamento e acesso ao fabricante.
- Integrações opcionais (iCUE, OpenRGB, SignalRGB, jogos) precisam dos respectivos
  programas. Downloads, winget e serviços online continuam exigindo internet.
- Desinstalar preserva `%AppData%\AGBench` e o PawnIO, compartilhado com outros programas.
- O instalador não inclui configurações, chaves de API nem histórico do computador de build.

O instalador do AG Bench não possui assinatura digital de editor. O Windows pode
exibir um aviso de reputação. O PawnIO incluído mantém sua assinatura original.

## Recriar

Requer .NET SDK 8 e Inno Setup 6. A publicação é self-contained, sem trimming,
para preservar reflexão, WPF, bibliotecas de hardware e dependências nativas.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File installer\build-installer.ps1
```

É possível informar `-DotnetPath`, `-IsccPath` e `-WorkDirectory`. O build usa
staging exclusivo em `%TEMP%\AGBench-installer-build`; a pasta `release` recebe
somente o instalador final e seu hash. As licenças e metadados das dependências
são coletados dos pacotes NuGet restaurados, incluindo os runtimes.

## Verificar

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File installer\test-installer.ps1 -SetupPath release\AGBench-0.16.0-Setup-x64.exe
```

O teste faz instalação, atualização e desinstalação em pasta temporária usando
`/CURRENTUSER`, sem instalar PawnIO, criar atalhos ou executar benchmarks.
Recusa substituir uma instalação por usuário já existente. O fluxo normal do
instalador é por máquina e solicita administrador; o app sempre mantém sua
exigência de elevação para ler sensores de baixo nível.

O teste local não substitui testes com GPUs, sensores e versões de Windows diferentes.
