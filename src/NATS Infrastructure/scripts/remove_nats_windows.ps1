# remove_nats_windows.ps1
# Full NATS uninstall: stops nats-server, removes the ENTIRE install directory
# (server + CLI + anything else in it) and cleans up the PATH entry.
# This is intentionally a complete wipe -- the installers are per-binary, but removal
# clears the whole directory.

param(
    [string]$InstallDir = "C:\nats"
)

$natsInstallDir = $InstallDir

# Stop any running nats-server processes
$natsProcs = Get-Process -Name "nats-server" -ErrorAction SilentlyContinue
if ($natsProcs) {
    Write-Host "Stopping running nats-server process(es)..."
    $natsProcs | Stop-Process -Force
    Write-Host "Stopped."
} else {
    Write-Host "No running nats-server processes found."
}

# Remove install directory
if (Test-Path $natsInstallDir) {
    Write-Host "Removing $natsInstallDir..."
    Remove-Item -Recurse -Force $natsInstallDir
    Write-Host "Removed."
} else {
    Write-Host "$natsInstallDir not found, skipping."
}

# Clean up User PATH: drop only an exact entry for this InstallDir, leave everything else untouched.
$userPath = [Environment]::GetEnvironmentVariable("PATH", [EnvironmentVariableTarget]::User)
if ($userPath) {
    $normalizedInstallDir = $natsInstallDir.TrimEnd('\')
    $cleanedUserPath = (@($userPath -split ";" | Where-Object { $_ -and ($_.TrimEnd('\') -ne $normalizedInstallDir) })) -join ";"
    if ($cleanedUserPath -ne $userPath) {
        [Environment]::SetEnvironmentVariable("PATH", $cleanedUserPath, [EnvironmentVariableTarget]::User)
        Write-Host "Removed nats entry from User PATH."
    } else {
        Write-Host "No nats entry found in User PATH."
    }
}


Write-Host "NATS uninstall complete."
