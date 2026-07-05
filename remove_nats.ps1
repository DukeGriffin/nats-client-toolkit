# uninstall_nats.ps1
# Removes NATS server binary and cleans up PATH entries

$natsInstallDir = "C:\nats"

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

# Clean up User PATH entries pointing to nats
$userPath = [Environment]::GetEnvironmentVariable("PATH", [EnvironmentVariableTarget]::User)
if ($userPath) {
    $cleanedUserPath = (($userPath -split ";") | Where-Object { $_ -notlike "*\nats*" }) -join ";"
    if ($cleanedUserPath -ne $userPath) {
        [Environment]::SetEnvironmentVariable("PATH", $cleanedUserPath, [EnvironmentVariableTarget]::User)
        Write-Host "Removed nats entry from User PATH."
    } else {
        Write-Host "No nats entry found in User PATH."
    }
}


Write-Host "NATS uninstall complete."
