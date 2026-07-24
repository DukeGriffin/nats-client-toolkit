<#
.SYNOPSIS
    Installs the latest NATS server release for Windows.
.DESCRIPTION
    Places nats-server.exe into the install directory and adds it to PATH.
    NON-DESTRUCTIVE: it manages only nats-server.exe and never wipes the directory,
    so it coexists with the NATS CLI (nats.exe, via install_nats_cli_windows.ps1) or
    anything else installed there. Re-running it just replaces nats-server.exe.
    To remove NATS entirely (server + CLI), use remove_nats_windows.ps1.
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

# The release publishes a SHA256SUMS file -- verify the download against it before
# extracting or running anything. Fail closed if it's missing or doesn't match.
$sumsAsset = $release.assets | Where-Object { $_.name -eq "SHA256SUMS" }
if (-not $sumsAsset) {
    throw "Release $version has no SHA256SUMS asset; refusing to install unverified. Install nats-server manually instead."
}

Write-Host "Installing NATS server $version ($Arch)..."

$zipPath = Join-Path $env:TEMP $assetName
Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $zipPath

# Verify SHA-256 against the published checksum before touching the payload.
# Download the sums file and read it as text. IWR's in-memory .Content is a byte
# array for octet-stream responses, which breaks line parsing.
$sumsPath = Join-Path $env:TEMP "$assetName.SHA256SUMS"
Invoke-WebRequest -Uri $sumsAsset.browser_download_url -OutFile $sumsPath
$expected = $null
foreach ($line in (Get-Content -Path $sumsPath)) {
    $parts = $line.Trim() -split '\s+', 2
    if ($parts.Count -eq 2 -and $parts[1].Trim() -eq $assetName) { $expected = $parts[0].Trim().ToLower(); break }
}
Remove-Item $sumsPath -Force -ErrorAction SilentlyContinue
if (-not $expected) {
    Remove-Item $zipPath -Force
    throw "No checksum entry for '$assetName' in SHA256SUMS; refusing to install."
}
$actual = (Get-FileHash -Path $zipPath -Algorithm SHA256).Hash.ToLower()
if ($actual -ne $expected) {
    Remove-Item $zipPath -Force
    throw "SHA-256 mismatch for '$assetName': expected $expected, got $actual. Download may be corrupt or tampered -- aborting."
}
Write-Host "SHA-256 verified ($actual)."

$extractDir = Join-Path $env:TEMP "nats-extract-$version-$Arch"
if (Test-Path $extractDir) { Remove-Item -Recurse -Force $extractDir }
Expand-Archive -Path $zipPath -DestinationPath $extractDir -Force
Remove-Item $zipPath -Force

# Locate the server binary in the extracted archive (zip nests it in a versioned folder).
$serverExe = Get-ChildItem -Path $extractDir -Recurse -Filter "nats-server.exe" | Select-Object -First 1
if (-not $serverExe) {
    Remove-Item -Recurse -Force $extractDir
    throw "nats-server.exe not found in the downloaded archive."
}

# Non-destructive install: ensure the dir exists and place ONLY nats-server.exe.
# We do NOT wipe $InstallDir -- the NATS CLI (nats.exe) or other tools may share it.
New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
Copy-Item -Path $serverExe.FullName -Destination (Join-Path $InstallDir "nats-server.exe") -Force
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
