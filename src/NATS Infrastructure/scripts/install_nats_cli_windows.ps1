<#
.SYNOPSIS
    Installs the latest NATS CLI (`nats`) release for Windows.
.DESCRIPTION
    Companion to install_nats_windows.ps1. The `nats` CLI (nats-io/natscli) is the
    reference client and the recommended test/verification tool for this toolkit
    (nats stream/consumer/kv/object, nats pub/sub/req, nats bench, trace, etc.).
    It is a SEPARATE download from nats-server.

    Installs into the same directory as the server (C:\nats by default) so both
    `nats-server` and `nats` share one PATH entry. NON-destructive: it manages only
    nats.exe and never wipes the directory, so it and the server installer coexist and
    can be run in any order without clobbering each other. To remove NATS entirely
    (server + CLI), use remove_nats_windows.ps1.
.PARAMETER Arch
    Target architecture: amd64, arm64, or 386. If omitted, you'll be prompted.
.PARAMETER InstallDir
    Directory to install into. Defaults to C:\nats (shared with the server).
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

Write-Host "Fetching latest NATS CLI release info..."
$release = Invoke-RestMethod -Uri "https://api.github.com/repos/nats-io/natscli/releases/latest"
$tag = $release.tag_name
# The CLI asset filename strips the leading 'v' from the tag (e.g. tag v0.4.0 -> nats-0.4.0-...).
$version = $tag.TrimStart("v")
$assetName = "nats-$version-windows-$Arch.zip"
$asset = $release.assets | Where-Object { $_.name -eq $assetName }

if (-not $asset) {
    throw "Could not find asset '$assetName' in release $tag."
}

# The release publishes a SHA256SUMS file -- verify the download against it before
# extracting or running anything. Fail closed if it's missing or doesn't match.
$sumsAsset = $release.assets | Where-Object { $_.name -eq "SHA256SUMS" }
if (-not $sumsAsset) {
    throw "Release $tag has no SHA256SUMS asset; refusing to install unverified. Install the nats CLI manually instead."
}

Write-Host "Installing NATS CLI $tag ($Arch)..."

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

$extractDir = Join-Path $env:TEMP "natscli-extract-$version-$Arch"
if (Test-Path $extractDir) { Remove-Item -Recurse -Force $extractDir }
Expand-Archive -Path $zipPath -DestinationPath $extractDir -Force
Remove-Item $zipPath -Force

# The CLI zip may place nats.exe at the root or inside a folder -- locate it either way.
$natsExe = Get-ChildItem -Path $extractDir -Recurse -Filter "nats.exe" | Select-Object -First 1
if (-not $natsExe) {
    Remove-Item -Recurse -Force $extractDir
    throw "nats.exe not found in the downloaded archive."
}
# Non-destructive: ensure the dir exists and place ONLY nats.exe (never touch other
# tools' files, e.g. nats-server.exe, that may share this directory).
New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
Copy-Item -Path $natsExe.FullName -Destination (Join-Path $InstallDir "nats.exe") -Force
Remove-Item -Recurse -Force $extractDir

# Update User PATH: drop only an exact prior entry for this InstallDir, then add it back.
# Idempotent, so running this before/after the server installer is safe.
$userPath = [Environment]::GetEnvironmentVariable("PATH", [EnvironmentVariableTarget]::User)
$normalizedInstallDir = $InstallDir.TrimEnd('\')
$pathEntries = @()
if ($userPath) {
    $pathEntries = @($userPath -split ";" | Where-Object { $_ -and ($_.TrimEnd('\') -ne $normalizedInstallDir) })
}
$pathEntries += $normalizedInstallDir
[Environment]::SetEnvironmentVariable("PATH", ($pathEntries -join ";"), [EnvironmentVariableTarget]::User)

Write-Host "NATS CLI $tag ($Arch) installed to $InstallDir"
Write-Host "Open a new terminal for the PATH update to take effect, then run: nats --version"
