# DesktopCommanderRelayAgentInstaller

**Desktop Commander Relay Agent Manager — v2.1.0**  
**by amirmohammad katebsaber**

A colorful, interactive installer and management utility for connecting Ubuntu/Debian machines to a central [DesktopCommanderRelay](https://github.com/ErfKS/DesktopCommanderRelay) server. It installs the relay agent, creates a persistent `systemd` service, and provides guided updates, configuration, logs, health checks, and **optional** `sudo` policy management.

**Languages:** [English](#english) · [فارسی](#راهنمای-فارسی)

> **Important:** This README documents **`desktop-commander-relay-manager.sh` (v2.1.0)**, not the older one-shot `install-desktop-commander-relay-agent.sh` script. The commands below use the [repository](https://github.com/amirkateb/DesktopCommanderRelayAgentInstaller). **To obtain v2.1.0 from GitHub, first publish the updated script to the `main` branch**; otherwise GitHub returns whichever version is currently published there.

---

# English

## Contents

- [Overview and architecture](#overview-and-architecture)
- [Requirements](#requirements)
- [Quick installation](#quick-installation)
- [Interactive menu](#interactive-menu)
- [First-run setup](#first-run-setup)
- [Configure the main relay server](#configure-the-main-relay-server)
- [Managing sudo access](#managing-sudo-access)
- [Automatic permission repair](#automatic-permission-repair)
- [Update and migration](#update-and-migration)
- [Command-line reference](#command-line-reference)
- [Files and directories](#files-and-directories)
- [Advanced installation options](#advanced-installation-options)
- [Verification and troubleshooting](#verification-and-troubleshooting)
- [Uninstall and security](#uninstall-and-security)

## Overview and architecture

The manager can:

- Install system dependencies, Git, Python 3 and build tools.
- Install a suitable Node.js runtime (**22.12 or newer** is required; if missing or too old, the manager installs Node.js 22 from NodeSource).
- Install or update `@wonderwhy-er/desktop-commander` from npm.
- Clone and build the [DesktopCommanderRelay](https://github.com/ErfKS/DesktopCommanderRelay) agent from source.
- Create and enable the `desktop-commander-relay-agent.service` systemd unit.
- Configure a relay WebSocket URL, shared token, unique device ID and friendly device name.
- Show installation status, Git revision, recent/live logs and a best-effort relay HTTP health check.
- Update the agent using a staged build, check runtime-user permissions before activation, and attempt rollback if deployment fails.
- Repair Desktop Commander npm package permissions and the relay agent build automatically after npm installs, updates or rollback.
- Install `dc-relay-agent-manager` immediately in `/usr/local/bin` (with compatibility link in `/usr/local/sbin`) even if the agent installation later fails.
- Detect an existing installation location from its systemd unit for safe migration.
- Manage Desktop Commander's `sudo` block setting separately from actual Linux `sudo` privileges.
- Print the commands needed on the **main relay server** without changing that separate machine.

```text
ChatGPT / GPT Action / Relay Client
                |
                v
     DesktopCommanderRelay Server
                |
                | WebSocket /agent (wss:// preferred)
                v
        DesktopCommanderRelay Agent
                |
                | stdio
                v
         Desktop Commander MCP
                |
                v
       Ubuntu / Debian Agent Host
```

Multiple machines can connect to the same relay with **different `DEVICE_ID` values**. A friendly `DEVICE_NAME` is configured locally on each agent.

## Requirements

| Requirement | Details |
|---|---|
| OS | Ubuntu, Debian or compatible Debian-based system using `systemd` |
| Privileges | Root or a user permitted to run the manager with `sudo` |
| Connectivity | Internet access for packages, npm and Git; network access to the main relay |
| Runtime | Bash 4.4+, Python 3, Node.js 22.12+ (the installer provisions required packages) |
| Main server | A running DesktopCommanderRelay instance |
| Credentials | The same valid `AGENT_TOKEN` configured on the main server |
| Identity | A unique, stable `DEVICE_ID` for each agent |

`systemd` must be running; a container or environment without an active systemd instance is not supported by this script.

### Runtime account

The manager **does not run the agent as root**. By default:

- If started with `sudo` by a normal user, it proposes that user as the service account.
- If started directly as root and no account is supplied, it proposes a dedicated `desktop-commander` system account and can create it automatically, with home `/var/lib/desktop-commander`.
- You can select an existing account during installation or set `RUN_AS_USER` explicitly.

For example:

```bash
sudo env RUN_AS_USER=ubuntu ./desktop-commander-relay-manager.sh --install
```

The selected user must exist, unless it is the automatically created `desktop-commander` account. Choose the runtime account carefully because its home directory contains the Desktop Commander configuration and its Linux permissions determine what remote operations can do.

## Quick installation

Run the commands below **on the new Ubuntu/Debian agent server**, not on the central relay server.

### Method 1 — Clone directly from GitHub (recommended)

```bash
git clone https://github.com/amirkateb/DesktopCommanderRelayAgentInstaller.git
cd DesktopCommanderRelayAgentInstaller
chmod +x desktop-commander-relay-manager.sh
sudo ./desktop-commander-relay-manager.sh
```

The interactive menu opens. Select **1 — Install a new relay agent**. To start the installation wizard immediately, replace the last command with:

```bash
sudo ./desktop-commander-relay-manager.sh --install
```

If the repository was already cloned, update its `main` branch first (`git pull --ff-only`) after reviewing local changes.

### Method 2 — Download the script directly (no Git clone)

```bash
curl -fL --proto '=https' --tlsv1.2 \
  https://raw.githubusercontent.com/amirkateb/DesktopCommanderRelayAgentInstaller/main/desktop-commander-relay-manager.sh \
  -o desktop-commander-relay-manager.sh
chmod +x desktop-commander-relay-manager.sh
sudo ./desktop-commander-relay-manager.sh
```

Alternatively, with `wget`:

```bash
wget -O desktop-commander-relay-manager.sh \
  https://raw.githubusercontent.com/amirkateb/DesktopCommanderRelayAgentInstaller/main/desktop-commander-relay-manager.sh
chmod +x desktop-commander-relay-manager.sh
sudo ./desktop-commander-relay-manager.sh
```

These commands download the **current script from the public `main` branch**. Review the file before executing it with `sudo` (for example, `less desktop-commander-relay-manager.sh`). For more reproducible installations, download a reviewed tag or commit-specific version rather than the moving `main` branch.

### After installation

The manager is now installed **as soon as the new script is run with root privileges**, before the agent install/update starts. Its main path is `/usr/local/bin/dc-relay-agent-manager`; the old `/usr/local/sbin/dc-relay-agent-manager` path is maintained as a compatibility symlink. Even if the agent update fails, the manager command remains available. Open its menu from any directory:

```bash
sudo dc-relay-agent-manager
```

**Important:** The script installs the **agent on this machine**. You must also follow the [main relay server configuration](#configure-the-main-relay-server) instructions to register or route requests to the new `DEVICE_ID` where needed.

## Interactive menu

The terminal UI has a banner, colored status indicators, installation-step feedback and an interactive menu. When attached to a capable terminal, it displays a spinner during long operations. Colors may be suppressed with `NO_COLOR=1`.

```text
DESKTOP COMMANDER / RELAY AGENT MANAGER
v2.1.0 — by amirmohammad katebsaber

 1)  Install a new relay agent
 2)  Update agent + Desktop Commander
 3)  Configure relay connection / device identity
 4)  Agent status + health check
 5)  Restart agent service
 6)  Recent service logs
 7)  Follow live logs
 8)  Sudo access management
 9)  Main relay server setup instructions
10)  Installation & command-line guide
11)  Uninstall service (preserve data)
12)  Repair Desktop Commander & agent permissions
 0)  Exit
```

**Option 8 — Sudo access management** has its own submenu:

```text
1) Unblock "sudo" in Desktop Commander config
2) Block "sudo" in Desktop Commander config
3) Grant Linux passwordless sudo (advanced / dangerous)
4) Remove installer-managed Linux passwordless sudo grant
5) Check policy and account permissions
0) Back to main menu
```

## First-run setup

The installer guides you through **four phases**:

1. **Runtime account:** choose the existing Linux user that will run the agent.
2. **Relay connection:** enter the WebSocket URL, device ID, friendly name and shared token.
3. **Review:** confirm the settings; the token is hidden.
4. **Installation:** install dependencies, stage and build the agent, write the environment file and service, and start it.

Typical values:

```text
Linux account for the agent [your-current-user]: pachim
Relay WebSocket URL [wss://mcp-relay.katebsaber.ir/agent]:
Device ID (e.g. telegram-core): telegram-core
Friendly device name [telegram-core]: Telegram Core
AGENT_TOKEN (hidden):
```

Press **Enter** for a suggested default. Device IDs are normalized to lowercase with letters, digits, `.`, `_` and `-`; they must be unique per machine and no longer than 64 characters. Avoid reusing another device's ID.

For the token, first run this command **on the main relay server**:

```bash
sudo grep '^AGENT_TOKEN=' /opt/DesktopCommanderRelay/.env
```

Copy the token value into the new agent's hidden prompt. The manager also accepts the pasted `AGENT_TOKEN=` prefix and removes it. Keep the token private; the `grep` output is sensitive.

After installation the manager asks:

```text
Unblock sudo in Desktop Commander after installation? [y/N]:
```

Answer **Yes** only if you intend to permit the Desktop Commander `sudo` command. This does **not** automatically provide Linux root privileges; see [Managing sudo access](#managing-sudo-access). The manager then displays the main-server post-installation guide.

## Configure the main relay server

**All commands in this section run on the MAIN relay server, not the new agent server.** The manager does not remotely edit the main server.

### 1. Obtain the shared token

```bash
sudo grep '^AGENT_TOKEN=' /opt/DesktopCommanderRelay/.env
```

The main server and all agents using its shared-token configuration need matching tokens. Do not publish the token or include it in Git.

### 2. Review the relay environment

```bash
sudo nano /opt/DesktopCommanderRelay/.env
```

**Device identity:** The new agent announces its `DEVICE_ID` and `DEVICE_NAME` when connecting. You generally do **not** need to add a new friendly-name entry to this `.env` file.

**Default target (optional):** To route requests that omit an explicit `device_id` to this agent, set:

```dotenv
TARGET_DEVICE_ID=telegram-core
```

Replace `telegram-core` with the **actual normalized device ID** printed by the agent. If you manage multiple devices using explicit `device_id` arguments, you do not need to change the default for every new server.

**Process execution allowlist (optional, security-sensitive):** If your relay's Action API requires `ACTION_SANDBOX_DEVICE_IDS` to authorize process execution on a device, review that variable and add the new ID only when appropriate. Preserve existing IDs; the variable is a comma-separated allowlist, not a security sandbox. Confirm how it behaves in your version of [DesktopCommanderRelay](https://github.com/ErfKS/DesktopCommanderRelay).

### 3. Restart the main relay

```bash
sudo systemctl restart desktop-commander-relay-server.service
sudo systemctl status desktop-commander-relay-server.service --no-pager -l
```

### 4. Check both ends

**Main relay server:**

```bash
sudo journalctl -u desktop-commander-relay-server.service -n 50 --no-pager
```

**New agent server:**

```bash
sudo systemctl status desktop-commander-relay-agent.service --no-pager -l
sudo journalctl -u desktop-commander-relay-agent.service -f
```

To check the example relay's HTTP endpoint (not a substitute for checking WebSocket authentication):

```bash
curl -fsS https://mcp-relay.katebsaber.ir/healthz
```

The result depends on the relay version. A successful HTTP check shows network reachability; it does **not** by itself prove the agent authenticated.

## Managing sudo access

The manager distinguishes **two independent permission layers**.

### A. Desktop Commander command policy

The Desktop Commander configuration is read from the **runtime user's home**, at:

```text
~/.claude-server-commander/config.json
```

For a runtime account named `pachim`, the usual path is:

```text
/home/pachim/.claude-server-commander/config.json
```

Choosing **Yes** after installation, or **Menu 8 → 1**, removes the exact string `"sudo"` from the `blockedCommands` JSON array. It keeps other blocked commands and unrelated settings, makes a timestamped backup such as `config.json.bak.YYYYMMDD-HHMMSS-...`, writes the file atomically and tries to restart an active agent service.

**Menu 8 → 2** adds `"sudo"` back to the blocked list. If the Desktop Commander configuration file has not yet been generated, the manager does **not** invent a new file; start the agent and retry.

**Unblocking `sudo` is not equivalent to granting Linux root access.** A non-interactive service might still fail to use `sudo` if the account lacks permission or requires an interactive password.

### B. Linux sudoers privileges — high risk

For a service user that legitimately requires elevated operations, **Menu 8 → 3** offers a *separate*, explicit option to create:

```text
/etc/sudoers.d/90-dc-relay-agent-<runtime-user>
```

The rule grants the selected account **unrestricted passwordless sudo** (`NOPASSWD: ALL`). The manager displays a warning, requires you to type `GRANT ROOT`, asks for a second confirmation and validates the rule using `visudo`.

**Security warning:** Combining remote process execution with unrestricted passwordless sudo can effectively give a remote actor full root access to the agent machine. Prefer carefully scoped permissions. This option is **never activated merely by answering Yes to the post-install Desktop Commander sudo question**.

**Menu 8 → 4** removes only the sudoers file managed by this installer. It does **not** revoke permissions supplied by other `/etc/sudoers` or `/etc/sudoers.d/` rules. **Menu 8 → 5** displays the Desktop Commander policy and Linux account permission information.


## Automatic permission repair

**New in v2.1.0:** The previous updater used `mktemp -d` to create a staging directory, which starts with mode `0700`. Moving that directory into the active agent location without fixing its permissions could prevent a non-root systemd service from reading `dist/agent/index.js`. Separately, global `npm install -g` could leave Desktop Commander files inaccessible to the service user. Both paths are now covered.

Permission checks run automatically:

1. **After global npm install:** discover the npm package root (`npm root -g`, with common-path fallbacks), repair traversal permissions on the npm scope directory if required, and run `chmod -R a+rX` on the `@wonderwhy-er/desktop-commander` package.
2. **Fix the MCP executable:** set mode `755` on the installed `dist/index.js` and the resolved `desktop-commander` executable.
3. **Before deployment:** make the staged agent directory traversable and the `dist/` and `node_modules/` runtime assets readable/traversable. Test actual access with `runuser -u <service-user>`; do **not** change permissions on `.git` recursively.
4. **Before service restart:** repeat permission checks on the active directory. If activation fails, restore the previous source/config/unit, recheck permissions on the restored build, and attempt to restart it.
5. **During manual repair:** restart the service and display its status plus the last 25 journal lines.

Run manually at any time with **Menu 12** or:

```bash
sudo dc-relay-agent-manager --repair-permissions
```

If the new manager has not yet been installed as a command, run:

```bash
sudo bash ./desktop-commander-relay-manager.sh --repair-permissions
```

The repair is deliberately scoped to the npm package and agent runtime assets. It **does not** add Linux sudoers privileges, unblock the `sudo` command, modify the shared relay token or delete existing configuration.

**Equivalent manual repair for the standard Ubuntu npm path** (useful if the manager cannot run):

```bash
sudo bash -c '
set -e
PKG="/usr/lib/node_modules/@wonderwhy-er/desktop-commander"
SERVICE="desktop-commander-relay-agent.service"
test -d "$PKG" || { echo "Package not found: $PKG"; exit 1; }
chmod -R a+rX "$PKG"
chmod 755 "$PKG/dist/index.js"
AGENT_USER=$(systemctl show "$SERVICE" -p User --value)
AGENT_USER=${AGENT_USER:-root}
runuser -u "$AGENT_USER" -- test -r "$PKG/package.json"
runuser -u "$AGENT_USER" -- test -x /usr/bin/desktop-commander
systemctl restart "$SERVICE"
sleep 3
systemctl --no-pager --full status "$SERVICE"
journalctl -u "$SERVICE" -n 25 --no-pager
'
```

That manual command assumes `/usr/lib/node_modules` and `/usr/bin/desktop-commander`. If npm installed elsewhere or the relay checkout itself has directory mode `0700`, use the manager's automatic repair instead.

## Update and migration

### Update the installed agent

Use **Menu 2** or:

```bash
sudo dc-relay-agent-manager --update
```

The updater:

1. Reads the existing `agent.env` without evaluating it and preserves the token, device identity, relay URL, runtime account and any additional environment entries.
2. Detects the existing agent directory from `WorkingDirectory=` in the installed systemd unit (unless `RELAY_DIR` is explicitly supplied), including installations created by the older installer.
3. Updates prerequisites and the globally installed Desktop Commander package, **then repairs its permissions**.
4. Checks the existing Git checkout for tracked local modifications and refuses to overwrite those changes. It downloads a fresh build into a staging directory, runs `npm ci --no-audit` and `npm run build`, and confirms `dist/agent/index.js` exists.
5. Fixes staged-directory and runtime-asset permissions **before** deployment; verifies that the actual non-root service user can read/execute the required paths.
6. Backs up the previous unit, agent environment and source checkout. Promotes the new build, repairs permissions again, reloads systemd and restarts.
7. If activation or the immediate service-start check fails, attempts to restore the previous source, token/config and unit and repairs the restored build's permissions before restarting it. Failed builds remain under `.failed.*` for diagnosis.

**Important limitation:** A service becoming active does not prove successful authentication. Inspect `journalctl` for the relay-authenticated message. Global npm package versions are not rolled back automatically. If your first deployment had other custom modifications outside the standard directories, back them up separately.

### Updating the manager script itself

**`--update` updates the relay agent and global Desktop Commander package, not the management Bash script itself.** To upgrade the manager, download a reviewed version from the installer repository and invoke it as root; it will install itself to `/usr/local/bin/dc-relay-agent-manager` immediately:

```bash
curl -fL --proto '=https' --tlsv1.2 \
  https://raw.githubusercontent.com/amirkateb/DesktopCommanderRelayAgentInstaller/main/desktop-commander-relay-manager.sh \
  -o desktop-commander-relay-manager.sh
less desktop-commander-relay-manager.sh # Review before running as root.
sudo bash ./desktop-commander-relay-manager.sh --version # Displays the downloaded version (no installation).
sudo bash ./desktop-commander-relay-manager.sh --menu # Registers the command immediately.
sudo dc-relay-agent-manager --version
```

If upgrading from a cloned repository, use `git pull --ff-only` and run the updated script. Only after uploading the **v2.1.0** version to the repository will the URL above fetch v2.1.0. To update the relay agent itself afterward, run `sudo dc-relay-agent-manager --update`.

**If you need to repair an existing server immediately using the downloaded ZIP (before publishing to GitHub):** extract the two files on the agent server, then run:

```bash
sudo bash ./desktop-commander-relay-manager.sh --repair-permissions
sudo dc-relay-agent-manager --update
```

The first command registers the manager and repairs the current installation without updating its packages. The second command starts the normal update wizard. Do not run both simultaneously.

### Upgrading from the earlier one-shot installer

Older installs used `install-desktop-commander-relay-agent.sh` and sometimes contained an agent directory that only root could enter. v2.1.0 reads the existing systemd unit and config to detect the original installation directory and service user. It does not require you to remove or recreate the old agent. Use the updated management script and choose **2 — Update**, or run the new script with `--install` to enter the migration/update flow when an existing installation is detected. Keep the original token unchanged.

```bash
# From an already cloned and updated installer repository:
git pull --ff-only
sudo bash ./desktop-commander-relay-manager.sh --update
# If the previous attempt left the agent stopped:
sudo dc-relay-agent-manager --repair-permissions
sudo dc-relay-agent-manager --status
```

For installations with an unusual directory layout or a custom systemd unit, inspect the path first (`systemctl cat desktop-commander-relay-agent`) and provide `RELAY_DIR` explicitly if auto-detection does not match. The script will not overwrite a checkout with tracked local modifications.

## Command-line reference

After installation:

| Command | Action |
|---|---|
| `sudo dc-relay-agent-manager` | Open the interactive menu |
| `sudo dc-relay-agent-manager --install` | Guided new installation |
| `sudo dc-relay-agent-manager --update` | Update agent and global Desktop Commander package |
| `sudo dc-relay-agent-manager --configure` | Change relay URL, token, device ID or name |
| `sudo dc-relay-agent-manager --status` | Display service status and health information |
| `sudo dc-relay-agent-manager --restart` | Restart the agent service |
| `sudo dc-relay-agent-manager --logs` | Show recent agent logs |
| `sudo dc-relay-agent-manager --follow-logs` | Follow live logs (Ctrl+C to exit) |
| `sudo dc-relay-agent-manager --sudo` | Open the sudo policy submenu |
| `sudo dc-relay-agent-manager --repair-permissions` | Repair npm/agent permissions, restart, show logs |
| `sudo dc-relay-agent-manager --main-relay` | Show main relay setup steps |
| `sudo dc-relay-agent-manager --guide` | Show built-in installation guide |
| `sudo dc-relay-agent-manager --uninstall` | Disable and remove service only |
| `sudo dc-relay-agent-manager --version` | Show manager version |
| `sudo dc-relay-agent-manager --help` | Show CLI help |

You may also call the downloaded `.sh` file directly with any of the same flags.

## Files and directories

| Purpose | Default location |
|---|---|
| Relay agent Git checkout/build | `/opt/desktop-commander-relay-agent` |
| Agent configuration (`AGENT_TOKEN` included) | `/etc/desktop-commander-relay/agent.env` |
| Manager state/metadata | `/etc/desktop-commander-relay/manager.conf` |
| Agent systemd unit | `/etc/systemd/system/desktop-commander-relay-agent.service` |
| Persistent manager executable | `/usr/local/bin/dc-relay-agent-manager` (legacy symlink in `/usr/local/sbin`) |
| Manager operation log | `/var/log/desktop-commander-relay-manager.log` |
| Desktop Commander JSON policy | `<runtime-user-home>/.claude-server-commander/config.json` |
| Backup files from updates | `/etc/desktop-commander-relay/backups/` and `<agent-directory>.previous.*` |
| Installer-managed sudoers file (if explicitly granted) | `/etc/sudoers.d/90-dc-relay-agent-<runtime-user>` |

The environment file and manager log are protected with restrictive permissions. Do **not** upload `agent.env`, token output, private logs or sudoers files to public repositories.

Typical agent environment (illustrative; replace placeholders):

```dotenv
RELAY_WS_URL="wss://mcp-relay.katebsaber.ir/agent"
AGENT_TOKEN="YOUR_PRIVATE_AGENT_TOKEN"
DEVICE_ID="telegram-core"
DEVICE_NAME="Telegram Core"
DESKTOP_COMMANDER_COMMAND="/usr/bin/desktop-commander"
```

The actual Desktop Commander executable path is detected automatically. The manager writes the values with quoting suitable for a systemd EnvironmentFile.

## Advanced installation options

The manager accepts environment overrides:

```bash
sudo env RUN_AS_USER=deploy \
  RELAY_DIR=/opt/my-relay-agent \
  RELAY_REPO=https://github.com/ErfKS/DesktopCommanderRelay.git \
  RELAY_WS_URL=wss://relay.example.com/agent \
  ./desktop-commander-relay-manager.sh --install
```

| Variable | Purpose |
|---|---|
| `RUN_AS_USER` | Preferred existing Linux service user |
| `RELAY_DIR` | Agent source/build directory |
| `RELAY_REPO` | Git URL for the upstream relay project |
| `RELAY_WS_URL` | Default URL offered by the connection wizard |
| `NO_COLOR=1` | Suppress ANSI terminal colors |

**Custom directory caution:** If you install into a non-default `RELAY_DIR`, supply the same override on subsequent manager operations; the v2.1.0 manager's detection uses the active `RELAY_DIR` environment value. Avoid whitespace in custom installation paths.

## Verification and troubleshooting

### Common commands on the agent server

```bash
sudo systemctl status desktop-commander-relay-agent.service --no-pager -l
sudo systemctl restart desktop-commander-relay-agent.service
sudo systemctl stop desktop-commander-relay-agent.service
sudo systemctl start desktop-commander-relay-agent.service
sudo systemctl enable desktop-commander-relay-agent.service
sudo journalctl -u desktop-commander-relay-agent.service -n 100 --no-pager
sudo journalctl -u desktop-commander-relay-agent.service -f
```

Typical successful agent log messages can resemble:

```text
[agent] local Desktop Commander connected via executable: /usr/bin/desktop-commander
[agent] connecting to relay wss://mcp-relay.katebsaber.ir/agent as 'telegram-core' with 26 tools
[agent] relay connected and authenticated
```

Log wording and tool count vary by version; look for a confirmed authenticated connection, not just a running systemd process.

| Problem | What to check |
|---|---|
| `AGENT_TOKEN` authentication failure | Ensure token on the main relay and in `/etc/desktop-commander-relay/agent.env` matches; reconfigure and restart |
| Relay unreachable | Check DNS, firewall, TLS certificate and WebSocket `wss://.../agent` URL; test `/healthz` and read both services' logs |
| Agent service fails to start | Check `systemctl status`, `journalctl`, runtime-user permissions, Node.js and the built `dist/agent/index.js` file |
| `desktop-commander` not found | Run `command -v desktop-commander`; choose update to reinstall/update the npm package if needed |
| `sudo` still rejected by Desktop Commander | Check **Menu 8 → 5**, inspect runtime-user JSON config and restart the agent; ensure config exists |
| Linux `sudo` asks for a password | Desktop Commander command policy and Linux sudoers are separate; review account privileges before considering any elevated grant |
| Existing checkout modified | `git -C /opt/desktop-commander-relay-agent status`; review changes before proceeding, do not overwrite blindly |
| New device not chosen by default | Verify `DEVICE_ID` on agent and optional `TARGET_DEVICE_ID` on main relay, or supply explicit `device_id` in the client call |
| Update succeeded but agent is not authenticated | The immediate startup check is not an authentication test; inspect agent and main-server logs |

To change connection settings safely:

```bash
sudo dc-relay-agent-manager --configure
```

For an existing installation, leave the hidden token field **empty** to retain the current token. The manager attempts to restore prior configuration if its immediate restart check fails.

## Uninstall and security

Use **Menu 11** or:

```bash
sudo dc-relay-agent-manager --uninstall
```

You must type `UNINSTALL` to confirm. This **disables the agent and removes only the systemd service unit**. It intentionally leaves the repository, token and configuration, logs, backups, manager command, and any Linux sudoers privileges in place. Review and remove these separately if you intend a complete cleanup.

Recommended protections:

- Treat an authenticated relay agent as a privileged remote-access endpoint.
- Keep `AGENT_TOKEN` secret and rotate it if exposed.
- Prefer `wss://` over unencrypted `ws://`.
- Use unique device IDs, a non-root runtime account and least-privilege file access.
- Avoid unrestricted passwordless `sudo`, particularly alongside remote process-execution tools.
- Restrict access to the main relay with authentication, network controls and firewall rules.
- Inspect upstream code and package updates before deploying to production.
- Back up important settings before upgrades; the manager's rollback check is limited to immediate startup.

### Related repositories

- [DesktopCommanderRelay](https://github.com/ErfKS/DesktopCommanderRelay)
- [Desktop Commander MCP](https://github.com/wonderwhy-er/DesktopCommanderMCP)
- [DesktopCommanderRelayAgentInstaller](https://github.com/amirkateb/DesktopCommanderRelayAgentInstaller)

### License

Refer to the license included in this installer repository. Upstream projects and dependencies are governed by their respective licenses.

---

# راهنمای فارسی

این بخش، راهنمای فارسی **نسخهٔ ۲.۱.۰** ابزار Desktop Commander Relay Agent Manager است. متن‌ها و منوهای **خود اسکریپت انگلیسی** هستند؛ این بخش فقط برای مستندسازی و راهنمای کاربران فارسی‌زبان تهیه شده است.

## معرفی و قابلیت‌های نسخهٔ جدید

این ابزار سرور Ubuntu یا Debian را به یک عامل (Agent) متصل به DesktopCommanderRelay تبدیل می‌کند. علاوه بر نصب اولیه، منوی مدیریتی تعاملی، نمایش وضعیت سرویس، مشاهدهٔ لاگ‌ها، تغییر اطلاعات اتصال، به‌روزرسانی و مدیریت اختیاری `sudo` را ارائه می‌دهد.

برخلاف اسکریپت یک‌بارهٔ قبلی، نسخهٔ جدید می‌تواند بعد از نصب نیز از طریق دستور `dc-relay-agent-manager` اجرا شود. فایل جدید **`desktop-commander-relay-manager.sh`** است؛ نام فایل قدیمی `install-desktop-commander-relay-agent.sh` بود.

در مراحل نصب، ابزار بسته‌های لازم را بررسی می‌کند، در صورت نیاز Node.js نسخهٔ مناسب (**۲۲.۱۲ یا بالاتر**) را نصب می‌کند، Desktop Commander را از npm می‌گیرد، پروژهٔ Relay را دریافت و build می‌کند، فایل تنظیمات Agent و سرویس `systemd` را می‌سازد و سرویس را اجرا می‌کند.

## پیش‌نیازها

- سرور Ubuntu، Debian یا توزیع سازگار با Debian و دارای `systemd` فعال
- دسترسی `root` یا امکان اجرای دستورهای `sudo`
- اینترنت برای نصب پکیج‌ها، دریافت پروژه و npm
- دسترسی شبکه به سرور اصلی Relay
- توکن معتبر `AGENT_TOKEN` و شناسهٔ یکتای `DEVICE_ID`

عامل با **کاربر غیرروت** اجرا می‌شود. اگر فایل را با `sudo` از حساب عادی اجرا کنید، همان حساب به‌عنوان کاربر پیشنهادی نمایش داده می‌شود. در اجرای مستقیم توسط root، حساب اختصاصی `desktop-commander` پیشنهاد می‌شود و در صورت نیاز ساخته خواهد شد. امکان تعیین حساب موجود دیگر با `RUN_AS_USER` نیز وجود دارد.

## نصب مستقیم روی سرور جدید از GitHub

تمام دستورهای این بخش را روی **سرور جدیدی که می‌خواهید به Relay متصل شود** اجرا کنید، نه سرور اصلی Relay.

### روش اول — دریافت مخزن با Git (پیشنهادی)

```bash
git clone https://github.com/amirkateb/DesktopCommanderRelayAgentInstaller.git
cd DesktopCommanderRelayAgentInstaller
chmod +x desktop-commander-relay-manager.sh
sudo ./desktop-commander-relay-manager.sh
```

پس از نمایش منوی انگلیسی، گزینهٔ **1 — Install a new relay agent** را انتخاب کنید. اگر می‌خواهید بدون بازکردن منوی اصلی وارد مراحل نصب شوید، دستور آخر را به شکل زیر اجرا کنید:

```bash
sudo ./desktop-commander-relay-manager.sh --install
```

فایل `desktop-commander-relay-manager.sh` در شاخهٔ `main` مخزن [DesktopCommanderRelayAgentInstaller](https://github.com/amirkateb/DesktopCommanderRelayAgentInstaller) قرار دارد. برای دریافت تغییرات در یک clone موجود می‌توانید بعد از بررسی تغییرات محلی از `git pull --ff-only` استفاده کنید.

### روش دوم — دانلود مستقیم اسکریپت با curl یا wget

بدون نیاز به clone کردن کل مخزن:

```bash
curl -fL --proto '=https' --tlsv1.2 \
  https://raw.githubusercontent.com/amirkateb/DesktopCommanderRelayAgentInstaller/main/desktop-commander-relay-manager.sh \
  -o desktop-commander-relay-manager.sh
chmod +x desktop-commander-relay-manager.sh
sudo ./desktop-commander-relay-manager.sh
```

یا با `wget`:

```bash
wget -O desktop-commander-relay-manager.sh \
  https://raw.githubusercontent.com/amirkateb/DesktopCommanderRelayAgentInstaller/main/desktop-commander-relay-manager.sh
chmod +x desktop-commander-relay-manager.sh
sudo ./desktop-commander-relay-manager.sh
```

چون فایل از شاخهٔ `main` دریافت می‌شود، ممکن است در آینده تغییر کند؛ پیش از اجرای دستور با `sudo`، محتوای آن را بررسی کنید. برای نصب کاملاً قابل تکرار بهتر است نسخه‌ای با tag یا commit مشخص دریافت کنید.

### اجرای منو پس از نصب

پس از نصب موفق، دستور مدیریتی زیر از هر مسیری قابل اجراست:

```bash
sudo dc-relay-agent-manager
```

**یادآوری:** نصب Agent روی سرور جدید، جایگزین تنظیم سرور اصلی نیست. در بخش [تنظیم سرور اصلی بعد از نصب](#تنظیم-سرور-اصلی-بعد-از-نصب) مراحل اتصال و انتخاب `DEVICE_ID` توضیح داده شده است.

## مراحل راه‌اندازی

نصاب چهار مرحله دارد:

1. **Runtime account:** انتخاب حساب لینوکسی که Agent با آن اجرا می‌شود.
2. **Relay connection:** واردکردن URL، شناسهٔ دستگاه، نام نمایشی و توکن.
3. **Review:** بررسی تنظیمات و تأیید (توکن نمایش داده نمی‌شود).
4. **Installation:** نصب وابستگی‌ها، build پروژه و راه‌اندازی سرویس.

نشانی پیش‌فرض Relay:

```text
wss://mcp-relay.katebsaber.ir/agent
```

مثال:

```text
Linux account: pachim
Relay WebSocket URL: wss://mcp-relay.katebsaber.ir/agent
Device ID: telegram-core
Friendly device name: Telegram Core
AGENT_TOKEN: [hidden]
```

شناسهٔ دستگاه باید یکتا باشد. حروف بزرگ در شناسه به حروف کوچک تبدیل می‌شوند و کاراکترهای نامعتبر به شکل ایمن نرمال‌سازی می‌شوند. هنگام درج توکن، مقدار آن در ترمینال دیده نمی‌شود.

## دریافت توکن از سرور اصلی

**روی سرور اصلی Relay** (نه سرور جدید)، اجرا کنید:

```bash
sudo grep '^AGENT_TOKEN=' /opt/DesktopCommanderRelay/.env
```

مقدار توکن را در سؤال مخفی نصب وارد کنید. این مقدار محرمانه است و نباید در GitHub یا پیام‌های عمومی منتشر شود.

## تنظیم سرور اصلی بعد از نصب

پس از نصب Agent، روی **سرور اصلی** فایل تنظیمات را باز کنید:

```bash
sudo nano /opt/DesktopCommanderRelay/.env
```

هر Agent هنگام اتصال، شناسهٔ خود یعنی `DEVICE_ID` و نام نمایشی `DEVICE_NAME` را معرفی می‌کند. معمولاً برای نام نمایشی لازم نیست ورودی مستقلی در فایل `.env` سرور اصلی ایجاد شود.

اگر می‌خواهید درخواست‌های بدون `device_id` به دستگاه جدید ارسال شوند، متناسب با شناسهٔ واقعی آن مقدار زیر را تنظیم کنید:

```dotenv
TARGET_DEVICE_ID=telegram-core
```

اگر چند سرور دارید و هر درخواست `device_id` مشخص دارد، تغییر شناسهٔ پیش‌فرض برای هر دستگاه جدید ضروری نیست.

در صورت نیاز به اجرای پردازش از طریق Action، تنظیم `ACTION_SANDBOX_DEVICE_IDS` را نیز با توجه به نسخهٔ سرور Relay بررسی کنید. این گزینه یک **فهرست مجوز** است، نه محیط ایزولهٔ امنیتی؛ دستگاه جدید را فقط در صورت نیاز و با حفظ شناسه‌های قبلی به آن اضافه کنید.

برای اعمال تغییرات **روی سرور اصلی**:

```bash
sudo systemctl restart desktop-commander-relay-server.service
sudo systemctl status desktop-commander-relay-server.service --no-pager -l
sudo journalctl -u desktop-commander-relay-server.service -n 50 --no-pager
```

برای بررسی **روی سرور جدید**:

```bash
sudo systemctl status desktop-commander-relay-agent.service --no-pager -l
sudo journalctl -u desktop-commander-relay-agent.service -f
```

بررسی HTTP سرور نمونه:

```bash
curl -fsS https://mcp-relay.katebsaber.ir/healthz
```

موفقیت بررسی HTTP به‌تنهایی نشانهٔ احراز هویت درست Agent نیست؛ لاگ سرویس را نیز بررسی کنید.

## معرفی کامل منوی اصلی

| گزینه | کاربرد |
|---:|---|
| `1` | نصب Agent جدید |
| `2` | به‌روزرسانی Agent و Desktop Commander |
| `3` | تغییر URL، توکن، شناسه و نام دستگاه |
| `4` | وضعیت سرویس، شناسه و Git revision و بررسی سلامت Relay |
| `5` | ریستارت سرویس Agent |
| `6` | مشاهدهٔ لاگ‌های اخیر |
| `7` | مشاهدهٔ لحظه‌ای لاگ‌ها |
| `8` | مدیریت دسترسی `sudo` |
| `9` | راهنمای تنظیم سرور اصلی |
| `10` | راهنمای نصب و دستورات خط فرمان |
| `11` | حذف سرویس با حفظ فایل‌ها و تنظیمات |
| `12` | ترمیم خودکار مجوزهای Desktop Commander و Agent، ریستارت و مشاهدهٔ لاگ‌ها |
| `0` | خروج |

## مدیریت دسترسی sudo

**دو نوع دسترسی کاملاً متفاوت وجود دارد.**

**نوع اول — اجازهٔ درخواست دستور sudo در Desktop Commander:** پس از نصب پرسیده می‌شود که آیا می‌خواهید `sudo` از فهرست `blockedCommands` حذف شود یا خیر. انتخاب `Yes`، فقط همین مقدار را از فایل تنظیمات مربوط به **حساب اجراکنندهٔ Agent** برمی‌دارد و سایر تنظیمات را دست‌نخورده می‌گذارد. پیش از تغییر، نسخهٔ پشتیبان زمان‌دار ایجاد می‌شود.

برای مثال اگر حساب اجراکننده `pachim` باشد:

```text
/home/pachim/.claude-server-commander/config.json
```

برای فعال‌سازی یا مسدودسازی مجدد از **منوی 8 → گزینهٔ 1 یا 2** استفاده کنید. اگر فایل JSON هنوز ساخته نشده است، ابتدا اجازه دهید Agent و Desktop Commander راه‌اندازی شوند و سپس دوباره اقدام کنید.

**نوع دوم — مجوز واقعی sudo در لینوکس:** برداشتن `sudo` از `blockedCommands` به‌تنهایی سطح دسترسی لینوکس را افزایش نمی‌دهد. گزینهٔ **8 → 3** به‌صورت جداگانه و تنها با دو تأیید صریح، می‌تواند برای حساب Agent مجوز `NOPASSWD: ALL` بسازد. این انتخاب **دسترسی بدون رمز و نامحدود روت** می‌دهد و بسیار پرخطر است؛ با فعال‌کردن دسترسی اجرای پردازش از راه دور، خطر به‌مراتب بیشتر می‌شود. استفاده از مجوزهای محدودتر توصیه می‌شود.

فایل قابل ایجاد:

```text
/etc/sudoers.d/90-dc-relay-agent-<runtime-user>
```

گزینهٔ **8 → 4** فقط فایل sudoers ساخته‌شده توسط همین نصب‌کننده را حذف می‌کند و مجوزهای دیگری را که به کاربر داده‌اید تغییر نمی‌دهد. گزینهٔ **8 → 5** وضعیت مجوزها را نشان می‌دهد.


## ترمیم مجوزهای دسترسی (جدید در نسخهٔ ۲.۱)

یکی از دلایل خطای آپدیت نسخهٔ قبلی این بود که پوشهٔ موقت با `mktemp -d` و مجوز `700` ساخته می‌شد و بعد از انتقال به مسیر نصب، حساب غیرروت سرویس نمی‌توانست فایل‌های Agent را بخواند. همچنین پس از اجرای `npm install -g` ممکن بود پکیج Desktop Commander دسترسی خواندن/اجرا برای کاربر سرویس نداشته باشد.

در نسخهٔ ۲.۱ این اقدامات به‌صورت خودکار انجام می‌شوند:

1. تشخیص مسیر واقعی پکیج Desktop Commander با `npm root -g`، اصلاح مجوز ورود به پوشهٔ والد در صورت نیاز و ترمیم دسترسی پکیج با `chmod -R a+rX`.
2. اعمال مجوز `755` روی `dist/index.js` و فایل اجرایی `desktop-commander`.
3. اصلاح مجوز پوشهٔ موقت و مسیرهای `dist` و `node_modules` در Agent **پیش از جایگزینی نسخه**.
4. تست مجوزها از دید **حساب واقعی سرویس** با `runuser`، نه فقط حساب `root`.
5. تکرار کنترل مجوزها پیش از ریستارت و حتی پس از بازگردانی نسخهٔ قبلی، همراه با نمایش وضعیت سرویس و ۲۵ خط آخر لاگ هنگام ترمیم دستی.

برای ترمیم مستقل از آپدیت از **گزینهٔ ۱۲ منو** یا این دستور استفاده کنید:

```bash
sudo dc-relay-agent-manager --repair-permissions
```

اگر دستور مدیریتی هنوز ایجاد نشده است:

```bash
sudo bash ./desktop-commander-relay-manager.sh --repair-permissions
```

این عملیات **به هیچ عنوان** مجوز `NOPASSWD` لینوکس ایجاد نمی‌کند و مقدار `AGENT_TOKEN` را تغییر نمی‌دهد. مجوزهای مخزن `.git` نیز به‌شکل بازگشتی عمومی نمی‌شوند. دستور دستی مربوط به نصب‌های استاندارد Ubuntu در بخش [English / Automatic permission repair](#automatic-permission-repair) هم درج شده است.

## به‌روزرسانی و مهاجرت از نسخهٔ قدیمی

برای آپدیت:

```bash
sudo dc-relay-agent-manager --update
```

در آپدیت، توکن، شناسه، نام دستگاه، نشانی اتصال، حساب اجرای سرویس و تنظیمات اضافی موجود در `agent.env` حفظ می‌شوند. این نسخه مسیر قبلی نصب را از `WorkingDirectory` فایل سرویس تشخیص می‌دهد، فایل‌های جدید را در مسیر موقت build می‌کند و **قبل از شروع سرویس** دسترسی حساب اجرای Agent را به‌صورت واقعی آزمایش می‌کند. اگر فعال‌سازی شکست بخورد، پوشهٔ قبلی و فایل‌های سرویس و تنظیمات را بازمی‌گرداند و دسترسی‌ها را دوباره ترمیم می‌کند.

**محدودیت:** شروع اولیهٔ سرویس به‌تنهایی احراز هویت را تضمین نمی‌کند؛ لاگ‌ها را هم بررسی کنید. نسخهٔ سراسری npm در rollback به نسخهٔ قبلی بازنمی‌گردد. همچنین تغییرات محلی track شده در مخزن Agent بدون اجازه بازنویسی نمی‌شوند.

**برای مهاجرت از نصب‌کنندهٔ قدیمی:** ابتدا نسخهٔ جدید فایل مدیریتی را از GitHub دریافت کنید (پس از انتشار آن در شاخهٔ `main`) یا از فایل ZIP همین نسخه استفاده کنید. اجرای اسکریپت جدید به‌صورت روت، دستور مدیریتی را **قبل از نصب یا آپدیت Agent** در `/usr/local/bin` نصب می‌کند؛ در نتیجه شکست آپدیت، این دستور را حذف نمی‌کند. سپس آپدیت را اجرا کنید:

```bash
git clone https://github.com/amirkateb/DesktopCommanderRelayAgentInstaller.git
cd DesktopCommanderRelayAgentInstaller
sudo bash ./desktop-commander-relay-manager.sh --update
sudo dc-relay-agent-manager --repair-permissions
```

اگر مخزن را قبلاً دریافت کرده‌اید، به‌جای `git clone` وارد پوشه شوید و پس از بررسی تغییرات، `git pull --ff-only` بزنید. راه نصب مستقیم با `curl` و `wget` نیز در بخش [نصب مستقیم روی سرور جدید از GitHub](#نصب-مستقیم-روی-سرور-جدید-از-github) وجود دارد.

**آپدیت خود Manager با آپدیت Agent متفاوت است.** `--update` کد Agent و پکیج Desktop Commander را ارتقا می‌دهد. برای دریافت نسخهٔ جدید فایل Bash مدیریتی، از دستور زیر استفاده کنید:

```bash
curl -fL --proto '=https' --tlsv1.2 \
  https://raw.githubusercontent.com/amirkateb/DesktopCommanderRelayAgentInstaller/main/desktop-commander-relay-manager.sh \
  -o desktop-commander-relay-manager.sh
less desktop-commander-relay-manager.sh
sudo bash ./desktop-commander-relay-manager.sh --menu
sudo dc-relay-agent-manager --version
```

**توجه:** تا زمانی که اسکریپت جدید نسخهٔ ۲.۱.۰ را در GitHub منتشر نکرده باشید، URL بالا نسخهٔ قدیمیِ موجود در شاخهٔ `main` را تحویل می‌دهد.

**رفع فوری مشکل با فایل ZIP قبل از Push به GitHub:** هر دو فایل را از ZIP خارج کنید، به سرور منتقل کنید و در همان پوشه این دستورات را اجرا کنید:

```bash
sudo bash ./desktop-commander-relay-manager.sh --repair-permissions
sudo dc-relay-agent-manager --update
```

دستور اول Manager را ثبت و مجوزهای نصب فعلی را ترمیم می‌کند؛ دستور دوم مراحل آپدیت عادی را آغاز می‌کند. این دو عملیات را هم‌زمان اجرا نکنید.

## دستورات کاربردی

```bash
sudo dc-relay-agent-manager --install
sudo dc-relay-agent-manager --update
sudo dc-relay-agent-manager --configure
sudo dc-relay-agent-manager --status
sudo dc-relay-agent-manager --restart
sudo dc-relay-agent-manager --logs
sudo dc-relay-agent-manager --follow-logs
sudo dc-relay-agent-manager --sudo
sudo dc-relay-agent-manager --repair-permissions
sudo dc-relay-agent-manager --main-relay
sudo dc-relay-agent-manager --guide
sudo dc-relay-agent-manager --uninstall
sudo dc-relay-agent-manager --version
sudo dc-relay-agent-manager --help
```

دستورات مستقیم `systemd`:

```bash
sudo systemctl status desktop-commander-relay-agent.service --no-pager -l
sudo systemctl restart desktop-commander-relay-agent.service
sudo systemctl stop desktop-commander-relay-agent.service
sudo systemctl start desktop-commander-relay-agent.service
sudo systemctl enable desktop-commander-relay-agent.service
sudo journalctl -u desktop-commander-relay-agent.service -n 100 --no-pager
sudo journalctl -u desktop-commander-relay-agent.service -f
```

## مسیرهای نصب و تنظیمات پیشرفته

| محتوا | مسیر پیش‌فرض |
|---|---|
| کد Agent | `/opt/desktop-commander-relay-agent` |
| تنظیمات و توکن | `/etc/desktop-commander-relay/agent.env` |
| متادیتای Manager | `/etc/desktop-commander-relay/manager.conf` |
| سرویس | `/etc/systemd/system/desktop-commander-relay-agent.service` |
| دستور مدیریتی | `/usr/local/bin/dc-relay-agent-manager` (سازگاری با مسیر `/usr/local/sbin` حفظ می‌شود) |
| لاگ Manager | `/var/log/desktop-commander-relay-manager.log` |
| فایل Desktop Commander | `<home>/.claude-server-commander/config.json` |

نمونهٔ تنظیم متغیرهای اختیاری هنگام نصب:

```bash
sudo env RUN_AS_USER=deploy \
  RELAY_DIR=/opt/my-relay-agent \
  RELAY_REPO=https://github.com/ErfKS/DesktopCommanderRelay.git \
  RELAY_WS_URL=wss://relay.example.com/agent \
  ./desktop-commander-relay-manager.sh --install
```

نسخهٔ ۲.۱.۰ مسیر نصب موجود را از `WorkingDirectory` سرویس systemd تشخیص می‌دهد؛ اگر `RELAY_DIR` را صریحاً تعریف کنید، همان مقدار اولویت خواهد داشت.

## رفع اشکال

- **سرویس اجرا نمی‌شود یا بعد از آپدیت rollback شده است:** ابتدا `sudo dc-relay-agent-manager --repair-permissions` را اجرا کنید و سپس وضعیت `systemd` و `journalctl` را بررسی کنید. اگر فرمان نصب نشده است، فایل جدید `.sh` را با `sudo bash` اجرا کنید.
- **خطای احراز هویت:** مقدار `AGENT_TOKEN` در سرور اصلی و Agent باید یکسان باشد؛ از دستور `--configure` استفاده کنید.
- **سرور اصلی در دسترس نیست:** DNS، گواهی TLS، فایروال، آدرس WebSocket و لاگ هر دو سرویس را بررسی کنید.
- **Desktop Commander پیدا نمی‌شود یا خطای `EACCES/Permission denied` دارد:** دستور `command -v desktop-commander` را بررسی کنید و گزینهٔ ۱۲ را اجرا کنید. فایل اجرایی و مسیر پکیج npm ممکن است نیاز به ترمیم داشته باشند.
- **دستور sudo مسدود است:** وضعیت `blockedCommands` را با منوی 8 بررسی کنید. نبودن دسترسی لینوکس با مسدود بودن دستور در Desktop Commander متفاوت است.
- **دستگاه جدید به‌صورت پیش‌فرض انتخاب نمی‌شود:** `DEVICE_ID` را با `TARGET_DEVICE_ID` سرور اصلی تطبیق دهید یا در درخواست‌ها شناسهٔ دستگاه را صریح بفرستید.
- **آپدیت با خطای Git متوقف می‌شود:** تغییرات محلی را بررسی کنید؛ ابزار برای محافظت از فایل‌های شما تغییرات track شده را بی‌اجازه بازنویسی نمی‌کند.
- **دستور `sudo dc-relay-agent-manager` پیدا نمی‌شود:** نسخهٔ ۲.۱ را یک بار با `sudo bash ./desktop-commander-relay-manager.sh --menu` اجرا کنید؛ دستور جدید در `/usr/local/bin` ثبت و مسیر قدیمی در `/usr/local/sbin` به آن متصل می‌شود.

## حذف و نکات امنیتی

برای حذف سرویس:

```bash
sudo dc-relay-agent-manager --uninstall
```

پس از نوشتن عبارت تأیید `UNINSTALL`، فقط سرویس systemd غیرفعال و حذف می‌شود؛ کد، توکن، تنظیمات، نسخه‌های پشتیبان، ابزار مدیریتی و **مجوزهای sudoers** باقی می‌مانند. اگر پاک‌سازی کامل مدنظر است، این موارد را جداگانه و با دقت مدیریت کنید.

توکن را محرمانه نگه دارید؛ اتصال `wss://` را ترجیح دهید؛ برای هر دستگاه شناسهٔ یکتا تعیین کنید؛ تا حد امکان Agent را با حساب غیرروت اجرا کنید؛ و از فعال‌سازی دسترسی بدون رمز روت مگر در صورت ضرورت واقعی خودداری کنید.

## پروژه‌های مرتبط و مجوز

- [DesktopCommanderRelay](https://github.com/ErfKS/DesktopCommanderRelay)
- [Desktop Commander MCP](https://github.com/wonderwhy-er/DesktopCommanderMCP)
- [DesktopCommanderRelayAgentInstaller](https://github.com/amirkateb/DesktopCommanderRelayAgentInstaller)

مجوز استفاده از کد این مخزن مطابق فایل License خود آن است. پروژه‌ها و وابستگی‌های ثالث تابع مجوزهای خودشان هستند.

---

**Desktop Commander Relay Agent Manager v2.1.0**  
**by amirmohammad katebsaber**
