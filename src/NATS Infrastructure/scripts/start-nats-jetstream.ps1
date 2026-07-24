<#
.SYNOPSIS
    Starts nats-server with JetStream enabled.
.DESCRIPTION
    JetStream is built into the nats-server binary but OFF by default -- it is enabled
    at RUNTIME, not by a separate install. This starts the server with JetStream on.

    Two CONFIG modes (pick one):
      * Flag mode (default): -js with -StoreDir / -Port / -MonitorPort below.
      * Config-file mode (-ConfigFile): runs `nats-server -c <file>`, so every option
        comes from the file (see nats-jetstream.conf). Use once you outgrow the flags.

    Two RUN modes:
      * Foreground (default): the server runs attached and streams its log to this
        console; press Ctrl+C to stop. Best for running by hand / debugging.
      * Detached (-Detached): launches the server as a HIDDEN background process and
        returns immediately (prints its PID). This is the mode the Start VIs use -- it
        does not block and shows no window.
.PARAMETER ServerExe
    Optional full path to nats-server.exe. If omitted (default), the script uses
    `nats-server` from PATH -- refreshed from the registry first, so a server installed
    after this host process started (e.g. LabVIEW) is found without a restart.
    Set this only if the server isn't on PATH or you installed it somewhere custom.
.PARAMETER StoreDir
    JetStream file-storage directory (created if missing). Flag mode only. If empty
    (the default), uses a "data" folder beside the resolved nats-server.exe -- e.g.
    C:\nats\data for the standard install, or <your-install-dir>\data for a custom one.
.PARAMETER Port
    Client (NATS protocol) port. Flag mode only. Default 4222.
.PARAMETER MonitorPort
    HTTP monitoring port (/varz, /jsz, /healthz). Flag mode only. Default 8222.
.PARAMETER ServerName
    Optional server name reported in INFO/monitoring. Flag mode only.
.PARAMETER ConfigFile
    Path to a nats-server config file. When given, the flag parameters are ignored and
    the server runs with `-c <ConfigFile>`.
.PARAMETER Detached
    Launch the server hidden, in the background, and return immediately (non-blocking).
    Use this from the Start VIs. Omit it to run in the foreground for interactive debugging.
#>
[CmdletBinding()]
param(
    [string]$ServerExe = "",
    [string]$StoreDir = "",
    [int]$Port = 4222,
    [int]$MonitorPort = 8222,
    [string]$ServerName,
    [string]$ConfigFile,
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

# Build the argument list for the chosen CONFIG mode.
if ($ConfigFile) {
    if (-not (Test-Path $ConfigFile)) { throw "Config file not found: $ConfigFile" }
    $natsArgs = @("-c", $ConfigFile)
    $modeDesc = "config file: $ConfigFile (ports & store_dir come from the file)"
} else {
    # Empty StoreDir defaults to a "data" folder beside the resolved nats-server.exe.
    if ([string]::IsNullOrWhiteSpace($StoreDir)) { $StoreDir = Join-Path (Split-Path -Parent $exe) "data" }
    if (-not (Test-Path $StoreDir)) { New-Item -ItemType Directory -Path $StoreDir -Force | Out-Null }
    $natsArgs = @("-js", "-sd", $StoreDir, "-p", "$Port", "-m", "$MonitorPort")
    if ($ServerName) { $natsArgs += @("-n", $ServerName) }
    $modeDesc = "flags: $($natsArgs -join ' ')"
}

if ($Detached) {
    # Background + hidden + non-blocking -- the mode the Start VIs use.
    # Start-Process does NOT auto-quote array args, so quote any that contain spaces
    # (e.g. a config path or store dir under "...\NATS Infrastructure\..."). Without
    # this the path gets split and the server exits instantly.
    $argLine = ($natsArgs | ForEach-Object { if ($_ -match '\s') { '"' + $_ + '"' } else { $_ } }) -join ' '
    $proc = Start-Process -FilePath $exe -ArgumentList $argLine -WindowStyle Hidden -PassThru
    Start-Sleep -Milliseconds 700
    if ($proc.HasExited) {
        throw "nats-server exited immediately (exit code $($proc.ExitCode)). Re-run without -Detached to see the error (usually a port already in use or a bad config/path)."
    }
    Write-Host "nats-server started (detached, hidden). PID: $($proc.Id)"
    Write-Host "  $modeDesc"
    if (-not $ConfigFile) { Write-Host "  monitoring: http://localhost:$MonitorPort/jsz" }
    return
}

# Foreground (default) -- visible log, blocks until Ctrl+C. Best for manual debugging.
Write-Host "Starting nats-server with JetStream enabled (foreground; Ctrl+C to stop):"
Write-Host "  binary : $exe"
Write-Host "  $modeDesc"
if (-not $ConfigFile) {
    Write-Host "  client : nats://localhost:$Port"
    Write-Host "  monitor: http://localhost:$MonitorPort  (try /varz and /jsz)"
}
Write-Host "  verify (needs the nats CLI): nats server check jetstream  |  nats stream ls"
Write-Host ""

& $exe @natsArgs
