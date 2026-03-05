param(
    [string]$Version = "",
    [string]$BuildDir = "flutter_app/build/windows/x64/runner/Release",
    [string]$OutputDir = "dist/windows"
)

$ErrorActionPreference = "Stop"

if (-not $Version) {
    $pubspec = "flutter_app/pubspec.yaml"
    if (-not (Test-Path $pubspec)) {
        throw "Could not resolve version automatically: $pubspec not found"
    }

    $match = Select-String -Path $pubspec -Pattern '^version:\s*([0-9]+\.[0-9]+\.[0-9]+)'
    if (-not $match) {
        throw "Could not resolve version automatically from $pubspec"
    }

    $Version = $match.Matches[0].Groups[1].Value
}

if (-not (Test-Path $BuildDir)) {
    throw "Build directory not found: $BuildDir"
}

$isccCandidates = @(
    "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
    "${env:ProgramFiles}\Inno Setup 6\ISCC.exe"
)

$iscc = $isccCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $iscc) {
    throw "Inno Setup 6 not found. Install it from https://jrsoftware.org/isinfo.php"
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$issFile = Join-Path $scriptDir "BattleLM.iss"
$resolvedBuildDir = (Resolve-Path $BuildDir).Path
$resolvedOutputDir = Join-Path (Get-Location) $OutputDir

New-Item -ItemType Directory -Force -Path $resolvedOutputDir | Out-Null

& $iscc `
  "/DAppVersion=$Version" `
  "/DBuildDir=$resolvedBuildDir" `
  "/DOutputDir=$resolvedOutputDir" `
  $issFile

Write-Host "Installer created in $resolvedOutputDir"
