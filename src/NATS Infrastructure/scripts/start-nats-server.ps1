<#
.SYNOPSIS
    Starts nats-server (Core NATS only -- no JetStream).
.DESCRIPTION
    Basic server start. For the persistence layer (streams/KV/Object) use
    start-nats-jetstream.ps1 instead.

    Uses `nats-server` from PATH by default -- refreshed from the registry first, so a
    server installed after this host process started (e.g. LabVIEW) is found without a
    restart. Pass -ServerExe to point at a specific binary instead.

    Run modes:
      * Foreground (default): attached, streams the log; Ctrl+C to stop. For debugging.
      * Detached (-Detached): hidden background process, returns immediately (prints PID).
        This is the mode the Start VI uses -- non-blocking, no window.
.PARAMETER ServerExe
    Optional full path to nats-server.exe. Omit to use `nats-server` from PATH
    (refreshed from the registry). Set it only for a non-PATH / custom install location.
.PARAMETER Port
    Client (NATS protocol) port. Default 4222.
.PARAMETER MonitorPort
    HTTP monitoring port (/varz, /healthz). Default 8222.
.PARAMETER ServerName
    Optional server name reported in INFO/monitoring.
.PARAMETER Detached
    Launch the server hidden, in the background, and return immediately (non-blocking).
    Use this from the Start VI. Omit it to run in the foreground for interactive debugging.
#>
[CmdletBinding()]
param(
    [string]$ServerExe = "",
    [int]$Port = 4222,
    [int]$MonitorPort = 8222,
    [string]$ServerName,
    [switch]$Detached
)

$ErrorActionPreference = "Stop"

# Refresh PATH from the registry (Machine + User) so a server installed after this
# host process launched -- e.g. from within LabVIEW -- is visible without a restart.
$machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
$userPath    = [Environment]::GetEnvironmentVariable("Path", "User")
$env:Path = (@($machinePath, $userPath) | Where-Object { $_ }) -join ";"

# Resolve the server binary: an explicit -ServerExe wins; otherwise use PATH.
if ($ServerExe) {
    if (-not (Test-Path $ServerExe)) { throw "nats-server.exe not found at '$ServerExe'." }
    $exe = $ServerExe
} else {
    $cmd = Get-Command "nats-server" -ErrorAction SilentlyContinue
    if (-not $cmd) {
        throw "nats-server not found on PATH (after refreshing from the registry). Install it (install_nats_windows.ps1) or pass -ServerExe with an explicit path."
    }
    $exe = $cmd.Source
}

$natsArgs = @("-p", "$Port", "-m", "$MonitorPort")
if ($ServerName) { $natsArgs += @("-n", $ServerName) }

if ($Detached) {
    # Background + hidden + non-blocking -- the mode the Start VI uses.
    # Start-Process does NOT auto-quote array args, so quote any that contain spaces.
    $argLine = ($natsArgs | ForEach-Object { if ($_ -match '\s') { '"' + $_ + '"' } else { $_ } }) -join ' '
    $proc = Start-Process -FilePath $exe -ArgumentList $argLine -WindowStyle Hidden -PassThru
    Start-Sleep -Milliseconds 700
    if ($proc.HasExited) {
        throw "nats-server exited immediately (exit code $($proc.ExitCode)). Re-run without -Detached to see the error (usually a port already in use)."
    }
    Write-Host "nats-server started (detached, hidden). PID: $($proc.Id)"
    Write-Host "  binary : $exe"
    Write-Host "  flags  : $($natsArgs -join ' ')"
    Write-Host "  monitoring: http://localhost:$MonitorPort/healthz"
    return
}

# Foreground (default) -- visible log, blocks until Ctrl+C. Best for manual debugging.
Write-Host "Starting nats-server (Core NATS, foreground; Ctrl+C to stop):"
Write-Host "  binary : $exe"
Write-Host "  client : nats://localhost:$Port"
Write-Host "  monitor: http://localhost:$MonitorPort  (try /varz and /healthz)"
Write-Host ""

& $exe @natsArgs
