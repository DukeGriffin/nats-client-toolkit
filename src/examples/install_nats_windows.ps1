<#
.SYNOPSIS
    Installs the latest NATS server release for Windows.
.PARAMETER Arch
    Target architecture: amd64, arm64, or 386. If omitted, you'll be prompted.
.PARAMETER InstallDir
    Directory to install into. Defaults to C:\nats.
#>
[CmdletBinding()]
param(
    [ValidateSet("amd64", "arm64", "386")]
    [string]$Arch,

    [string]$InstallDir = "C:\nats"
)

$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

if (-not $Arch) {
    Write-Host "Select the architecture to install:"
    Write-Host "  1) amd64 (64-bit Intel/AMD - most common)"
    Write-Host "  2) arm64 (64-bit ARM)"
    Write-Host "  3) 386   (32-bit Intel/AMD)"
    $choice = Read-Host "Enter choice [1-3] (default: 1)"
    $Arch = switch ($choice) {
        "2" { "arm64" }
        "3" { "386" }
        default { "amd64" }
    }
}

Write-Host "Fetching latest NATS server release info..."
$release = Invoke-RestMethod -Uri "https://api.github.com/repos/nats-io/nats-server/releases/latest"
$version = $release.tag_name
$assetName = "nats-server-$version-windows-$Arch.zip"
$asset = $release.assets | Where-Object { $_.name -eq $assetName }

if (-not $asset) {
    throw "Could not find asset '$assetName' in release $version."
}

Write-Host "Installing NATS server $version ($Arch)..."

$zipPath = Join-Path $env:TEMP $assetName
Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $zipPath

$extractDir = Join-Path $env:TEMP "nats-extract-$version-$Arch"
if (Test-Path $extractDir) { Remove-Item -Recurse -Force $extractDir }
Expand-Archive -Path $zipPath -DestinationPath $extractDir -Force
Remove-Item $zipPath -Force

# The zip contains a single top-level folder named nats-server-<version>-windows-<arch>
$extractedFolder = Get-ChildItem -Path $extractDir -Directory | Select-Object -First 1

if (Test-Path $InstallDir) {
    Write-Host "Removing existing installation at $InstallDir..."
    Remove-Item -Recurse -Force $InstallDir
}

New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
Copy-Item -Path (Join-Path $extractedFolder.FullName "*") -Destination $InstallDir -Recurse -Force
Remove-Item -Recurse -Force $extractDir

# Update User PATH: drop only an exact prior entry for this InstallDir, then add it back.
# Exact-match (not a wildcard) so unrelated entries are never touched, even if PATH is malformed.
$userPath = [Environment]::GetEnvironmentVariable("PATH", [EnvironmentVariableTarget]::User)
$normalizedInstallDir = $InstallDir.TrimEnd('\')
$pathEntries = @()
if ($userPath) {
    $pathEntries = @($userPath -split ";" | Where-Object { $_ -and ($_.TrimEnd('\') -ne $normalizedInstallDir) })
}
$pathEntries += $normalizedInstallDir
[Environment]::SetEnvironmentVariable("PATH", ($pathEntries -join ";"), [EnvironmentVariableTarget]::User)

Write-Host "NATS server $version ($Arch) installed to $InstallDir"
Write-Host "Open a new terminal for the PATH update to take effect, then run: nats-server -v"
