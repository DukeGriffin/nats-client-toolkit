# NATS Infrastructure

Windows helpers to install, start/stop, uninstall, and health-check a local
`nats-server` for use with this toolkit.

This is a **convenience / operations layer**, separate from the NATS client API
(pub/sub, JetStream, KV, Object Store). Security-sensitive deployments can skip it
entirely and install/run `nats-server` through their own vetted process.

All server-lifecycle logic lives in PowerShell scripts under [`scripts/`](scripts);
the LabVIEW VIs are thin wrappers that invoke them via **System Exec** (or, for
health, a plain HTTP GET). Keeping the logic in scripts makes it auditable and
runnable/debuggable by hand.

---

## Components

### VIs
| VI | Purpose | Backing script |
|---|---|---|
| `NATS Server Install Windows.vi` | Download + install the latest `nats-server` | `scripts/install_nats_windows.ps1` |
| `NATS Server Start Windows.vi` | Start Core-NATS server (no JetStream) | `scripts/start-nats-server.ps1` |
| `NATS Server Stop Windows.vi` | Stop the running server | (kills `nats-server.exe`) |
| `NATS Server Remove Windows.vi` | Stop and fully uninstall | `scripts/remove_nats_windows.ps1` |
| `Query Server Health.vi` | GET `/healthz` on the monitoring port | (no script; LabVIEW HTTP client) |

Scripts available to back additional VIs you may wire up:
- `scripts/install_nats_cli_windows.ps1` - installs the `nats` CLI (the reference client / test-verification tool).
- `scripts/start-nats-jetstream.ps1` - starts the server with JetStream enabled (flags **or** a config file).
- `scripts/nats-jetstream.conf` - a documented starter JetStream server config.

### Scripts (`scripts/`)
| Script | What it does | Key parameters |
|---|---|---|
| `install_nats_windows.ps1` | Installs the latest `nats-server` (checksum-verified) | `-Arch` (amd64/arm64/386), `-InstallDir` (default `C:\nats`) |
| `install_nats_cli_windows.ps1` | Installs the latest `nats` CLI (checksum-verified) | `-Arch`, `-InstallDir` (default `C:\nats`) |
| `remove_nats_windows.ps1` | Stops the server and deletes the whole install dir + PATH entry | `-InstallDir` (default `C:\nats`) |
| `start-nats-server.ps1` | Starts Core NATS (no JetStream) | `-ServerExe`, `-Port` (4222), `-MonitorPort` (8222), `-ServerName`, `-Detached` |
| `start-nats-jetstream.ps1` | Starts with JetStream (flags or config file) | `-ServerExe`, `-StoreDir`, `-Port`, `-MonitorPort`, `-ServerName`, `-ConfigFile`, `-Detached` |

---

## VI -> System Exec command templates

Format strings for LabVIEW's Format Into String, fed to System Exec. `%s` = path
(quoted), `%d` = integer. The first `%s` is always the full path to the script
(build it from the calling VI's directory + `scripts\<name>.ps1`).

**Install server**
```
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%s" -Arch %s -InstallDir "%s"
```
**Install CLI**
```
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%s" -Arch %s -InstallDir "%s"
```
**Remove (full uninstall)**
```
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%s" -InstallDir "%s"
```
**Start server (Core NATS)**
```
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%s" -Detached -Port %d -MonitorPort %d
```
**Start JetStream (flags)**
```
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%s" -Detached -StoreDir "%s" -Port %d -MonitorPort %d
```
**Start JetStream (config file)**
```
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%s" -Detached -ConfigFile "%s"
```
Add `-ServerExe "%s"` to any start command to force a specific binary; omit it to use
`nats-server` from PATH. If Port/MonitorPort are string controls, use `%s` not `%d`.

---

## Key behaviors and decisions

**Install locations & PATH**
- Default install dir is `C:\nats`; the `nats-server` and `nats` binaries live there together.
- Installers add the dir to the **User PATH**. A process only reads PATH at launch, so a
  server installed after LabVIEW started is not on LabVIEW's inherited PATH. The **start
  scripts work around this by refreshing PATH from the registry** before resolving the
  binary, so a fresh install is found without restarting LabVIEW.

**Installs are per-binary; remove is a full wipe**
- `install_nats_windows.ps1` places only `nats-server.exe`; `install_nats_cli_windows.ps1`
  places only `nats.exe`. Neither wipes the directory, so they coexist and can run in any
  order without clobbering each other.
- `remove_nats_windows.ps1` deletes the **entire** install dir (server + CLI + JetStream
  data if stored there) and removes the PATH entry - a deliberate complete uninstall.

**Download integrity**
- Both installers download the release's `SHA256SUMS`, verify the zip's SHA-256 against it,
  and **fail closed** (abort, delete) on a missing checksum or mismatch - before extracting
  or running anything. HTTPS/TLS 1.2 is enforced for the download.
- Limitation: binary and checksum come from the same GitHub release, so this catches
  corruption/MITM but not a fully compromised release. For higher assurance, install
  `nats-server` manually through a vetted process.

**Starting the server**
- Binary resolution: explicit `-ServerExe` wins; otherwise `nats-server` from the
  (registry-refreshed) PATH; clear error if neither is found.
- **`-Detached`** (used by the VIs): launches hidden + non-blocking, returns immediately,
  prints the PID, and **fails fast** (throws with the exit code) if the server dies on
  launch - so a port conflict / bad path surfaces as a real error instead of a silent
  no-launch. Arguments containing spaces are quoted (required for `Start-Process`).
- **Foreground** (omit `-Detached`): attached, streams the log, Ctrl+C to stop. Use this
  by hand to debug a start failure.
- JetStream store dir: an empty `-StoreDir` defaults to a `data` folder next to the
  resolved `nats-server.exe`. With `-ConfigFile`, ports and store_dir come from the file.

**Health check**
- `Query Server Health.vi` does an HTTP GET to `http://<host>:<monitorPort>/healthz` and
  checks for HTTP 200 / `{"status":"ok"}`. The monitoring endpoints are **unauthenticated**
  HTTP (no cookie/username/password needed), and require the server to be started with
  `-m <port>` (the start scripts do). `/jsz` confirms JetStream is enabled.

**JetStream**
- JetStream is built into the `nats-server` binary (no separate install); it is enabled at
  runtime via `-js` (flag mode) or a `jetstream { }` block (config mode). See
  `scripts/nats-jetstream.conf` for the documented config options.

---

## Manual use / debugging

- **See why a start failed:** run the start script **without** `-Detached` in a terminal to
  view the server log:
  ```
  powershell -ExecutionPolicy Bypass -File ".\scripts\start-nats-jetstream.ps1" -StoreDir C:\nats\data
  ```
- **Validate a config file** (no launch): `nats-server -c scripts\nats-jetstream.conf -t`
- **Verify from a second client:** install the `nats` CLI and use `nats server check jetstream`,
  `nats stream ls`, `nats pub`/`nats sub`, or `nats-server -DV` to trace every wire frame.

---

## Requirements & conventions

- Windows with **Windows PowerShell 5.1** (`powershell.exe`); no extra modules.
- Internet access to GitHub for the install scripts (release download + `SHA256SUMS`).
- Scripts are launched with `-NoProfile -ExecutionPolicy Bypass`.
