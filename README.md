# DesktopCommanderRelayAgentInstaller

**Desktop Commander Relay Agent Manager — v2.0.0**  
**by amirmohammad katebsaber**

A colorful, interactive installer and management utility for connecting Ubuntu/Debian machines to a central [DesktopCommanderRelay](https://github.com/ErfKS/DesktopCommanderRelay) server. It installs the relay agent, creates a persistent `systemd` service, and provides guided updates, configuration, logs, health checks, and **optional** `sudo` policy management.

**Languages:** [English](#english) · [فارسی](#راهنمای-فارسی)

> **Important:** This README documents **`desktop-commander-relay-manager.sh` (v2.0.0)**, not the previous one-shot `install-desktop-commander-relay-agent.sh` script. The new manager is available in the [`main` branch](https://github.com/amirkateb/DesktopCommanderRelayAgentInstaller) and can be installed directly from GitHub by cloning the repository or downloading the script.

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
- Update the agent using a staging build and attempt to roll back a deployment that fails its immediate service-start check.
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

After successful installation, the manager is copied to `/usr/local/sbin/dc-relay-agent-manager`. Open its menu from any directory:

```bash
sudo dc-relay-agent-manager
```

**Important:** The script installs the **agent on this machine**. You must also follow the [main relay server configuration](#configure-the-main-relay-server) instructions to register or route requests to the new `DEVICE_ID` where needed.

## Interactive menu

The terminal UI has a banner, colored status indicators, installation-step feedback and an interactive menu. When attached to a capable terminal, it displays a spinner during long operations. Colors may be suppressed with `NO_COLOR=1`.

```text
DESKTOP COMMANDER / RELAY AGENT MANAGER
v2.0.0 — by amirmohammad katebsaber

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

## Update and migration

### Update the installed agent

Use **Menu 2** or:

```bash
sudo dc-relay-agent-manager --update
```

The updater:

1. Reads the existing agent identity, token and runtime account.
2. Updates prerequisites and the global Desktop Commander npm package.
3. Checks the existing Git checkout for tracked local modifications and refuses to overwrite a modified checkout.
4. Clones the configured upstream relay repository into a temporary staging directory, runs `npm ci --no-audit` and `npm run build`, and checks for `dist/agent/index.js`.
5. Replaces the active directory with the newly built revision, writes the environment and service files, and restarts the service.
6. If the **immediate service-start check** fails, attempts to restore the previous source, environment and systemd unit. After a successful update, the previous source directory is retained with a `.previous.*` suffix.

The updater preserves the current `AGENT_TOKEN`, relay URL, device ID/name and service user. **A service becoming active does not prove successful authentication or long-term health**: verify the logs after updating. Also note that upgrading the globally installed npm package is outside the source-directory rollback.

### Updating the manager script itself

**`--update` updates the relay agent and Desktop Commander, not this management Bash script.** To update the manager separately, download a reviewed version from the installer repository and replace only the manager executable:

```bash
curl -fL --proto '=https' --tlsv1.2 \
  https://raw.githubusercontent.com/amirkateb/DesktopCommanderRelayAgentInstaller/main/desktop-commander-relay-manager.sh \
  -o desktop-commander-relay-manager.sh
# Review the downloaded script before installing it as root.
less desktop-commander-relay-manager.sh
sudo install -o root -g root -m 750 desktop-commander-relay-manager.sh \
  /usr/local/sbin/dc-relay-agent-manager
sudo dc-relay-agent-manager --version
```

This updates only the manager command, **not** the installed agent or its configuration. Review upstream changes before running newer code as root. To update the relay agent after that, use `sudo dc-relay-agent-manager --update`.

### Upgrading from the earlier one-shot installer

Older installs used `install-desktop-commander-relay-agent.sh`. The manager recognizes an installation if its usual agent directory, environment file and systemd unit are present. Keep your existing credentials. Launch the new manager and choose **2 — Update** or **3 — Configure**; do not delete existing configuration just to switch installers. If your previous installation used a custom directory, pass the same `RELAY_DIR` override.

If the existing Git checkout has tracked local changes or an unexpected directory layout, the update may refuse to proceed rather than overwriting files. Review the state manually.

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
| Persistent manager executable | `/usr/local/sbin/dc-relay-agent-manager` |
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

**Custom directory caution:** If you install into a non-default `RELAY_DIR`, supply the same override on subsequent manager operations; the v2.0.0 manager's detection uses the active `RELAY_DIR` environment value. Avoid whitespace in custom installation paths.

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

این بخش، راهنمای فارسی **نسخهٔ ۲.۰.۰** ابزار Desktop Commander Relay Agent Manager است. متن‌ها و منوهای **خود اسکریپت انگلیسی** هستند؛ این بخش فقط برای مستندسازی و راهنمای کاربران فارسی‌زبان تهیه شده است.

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

## به‌روزرسانی و مهاجرت از نسخهٔ قدیمی

برای آپدیت:

```bash
sudo dc-relay-agent-manager --update
```

در آپدیت، توکن، شناسه، نام دستگاه، نشانی اتصال و حساب اجرای سرویس حفظ می‌شوند. اسکریپت کد جدید را در مسیر موقت دریافت، وابستگی‌ها را نصب و پروژه را build می‌کند. اگر شروع فوری سرویس جدید ناموفق باشد، تلاش می‌کند کد، فایل تنظیمات و سرویس قبلی را بازگرداند. نسخهٔ قبلی پروژه بعد از آپدیت موفق با پسوند `.previous.*` باقی می‌ماند.

**محدودیت مهم:** فعال شدن اولیهٔ سرویس معادل موفقیت احراز هویت نیست. همچنین بازگردانی پوشهٔ پروژه، لزوماً نسخهٔ پکیج عمومی npm را به عقب برنمی‌گرداند. بعد از آپدیت لاگ‌ها را بررسی کنید.

اگر نسخهٔ قدیمی با نام `install-desktop-commander-relay-agent.sh` نصب شده است و مسیرها استاندارد هستند، نسخهٔ جدید می‌تواند نصب موجود را تشخیص دهد. به‌جای پاک‌کردن فایل‌های قبلی، با منوی **2** یا **3** آن را به‌روزرسانی یا دوباره پیکربندی کنید. اگر مسیر نصب متفاوت بوده، `RELAY_DIR` قبلی را استفاده کنید.

**تفاوت مهم:** دستور `--update`، کد Agent و پکیج Desktop Commander را آپدیت می‌کند؛ **خود فایل Bash مدیریتی به‌طور خودکار از اینترنت به‌روزرسانی نمی‌شود**. برای به‌روزرسانی Manager، نسخهٔ جدید را مستقیماً از GitHub بگیرید، بررسی کنید و سپس در مسیر دستور نصب کنید:

```bash
curl -fL --proto '=https' --tlsv1.2 \
  https://raw.githubusercontent.com/amirkateb/DesktopCommanderRelayAgentInstaller/main/desktop-commander-relay-manager.sh \
  -o desktop-commander-relay-manager.sh
less desktop-commander-relay-manager.sh
sudo install -o root -g root -m 750 desktop-commander-relay-manager.sh \
  /usr/local/sbin/dc-relay-agent-manager
sudo dc-relay-agent-manager --version
```

این کار فقط اسکریپت مدیریتی را جایگزین می‌کند و تنظیمات Agent را پاک نمی‌کند. در صورت نیاز به آپدیت خود Agent، بعد از آن `sudo dc-relay-agent-manager --update` را اجرا کنید.

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
| دستور مدیریتی | `/usr/local/sbin/dc-relay-agent-manager` |
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

در استفاده از `RELAY_DIR` سفارشی، در اجرای‌های بعدی Manager نیز همان متغیر را تعیین کنید؛ نسخهٔ ۲.۰.۰ مسیر سفارشی را برای تشخیص نصب، مستقیماً از متغیر محیطی می‌خواند.

## رفع اشکال

- **سرویس اجرا نمی‌شود:** وضعیت systemd و `journalctl` را بررسی کنید؛ همچنین دسترسی حساب سرویس و فایل build شده را چک کنید.
- **خطای احراز هویت:** مقدار `AGENT_TOKEN` در سرور اصلی و Agent باید یکسان باشد؛ از دستور `--configure` استفاده کنید.
- **سرور اصلی در دسترس نیست:** DNS، گواهی TLS، فایروال، آدرس WebSocket و لاگ هر دو سرویس را بررسی کنید.
- **Desktop Commander پیدا نمی‌شود:** دستور `command -v desktop-commander` را بزنید؛ در صورت نیاز Agent را آپدیت کنید.
- **دستور sudo مسدود است:** وضعیت `blockedCommands` را با منوی 8 بررسی کنید. نبودن دسترسی لینوکس با مسدود بودن دستور در Desktop Commander متفاوت است.
- **دستگاه جدید به‌صورت پیش‌فرض انتخاب نمی‌شود:** `DEVICE_ID` را با `TARGET_DEVICE_ID` سرور اصلی تطبیق دهید یا در درخواست‌ها شناسهٔ دستگاه را صریح بفرستید.
- **آپدیت با خطای Git متوقف می‌شود:** تغییرات محلی را بررسی کنید؛ ابزار برای محافظت از فایل‌های شما تغییرات track شده را بی‌اجازه بازنویسی نمی‌کند.

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

**Desktop Commander Relay Agent Manager v2.0.0**  
**by amirmohammad katebsaber**
