# DesktopCommanderRelayAgentInstaller

Automated installer for deploying **Desktop Commander Relay Agents** on fresh Ubuntu/Debian servers.

This installer prepares a server as a remote Desktop Commander device and connects it to a central [DesktopCommanderRelay](https://github.com/ErfKS/DesktopCommanderRelay) server.

> فارسی: [راهنمای فارسی](#راهنمای-فارسی)

---

## English

### Overview

`DesktopCommanderRelayAgentInstaller` automates the installation and configuration of a Desktop Commander Relay Agent on a fresh Ubuntu/Debian server.

It installs and configures:

- Required system packages
- Node.js 20+ when needed
- `@wonderwhy-er/desktop-commander`
- [DesktopCommanderRelay](https://github.com/ErfKS/DesktopCommanderRelay)
- Relay Agent configuration
- A persistent `systemd` service
- Automatic startup after reboot
- Basic Relay connectivity and health checks

The installer does **not** depend on a specific Linux username or home directory.

### Architecture

```text
ChatGPT / GPT Action
        |
        v
DesktopCommanderRelay Server
        |
        | WebSocket /agent
        v
DesktopCommanderRelay Agent
        |
        | stdio
        v
Desktop Commander MCP
        |
        v
Remote Ubuntu/Debian Server
```

Multiple agents can connect to the same Relay server using different `DEVICE_ID` values.

---

## Requirements

Supported operating systems:

- Ubuntu
- Debian
- Debian-based distributions using `systemd`

Other requirements:

- Root or sudo access
- Internet access during installation
- A running DesktopCommanderRelay server
- A valid `AGENT_TOKEN`
- A unique `DEVICE_ID`

The installer automatically installs Node.js if the existing version is missing or older than Node.js 20.

---

## Installation

Clone the repository:

```bash
git clone https://github.com/amirkateb/DesktopCommanderRelayAgentInstaller.git
cd DesktopCommanderRelayAgentInstaller
```

Make the installer executable:

```bash
chmod +x install-desktop-commander-relay-agent.sh
```

Run it:

```bash
sudo ./install-desktop-commander-relay-agent.sh
```

The installer will ask for:

```text
Relay WebSocket URL [wss://mcp-relay.katebsaber.ir/agent]:
AGENT_TOKEN:
Device ID (example: telegram-core):
Device name [telegram-core]:
```

Example:

```text
Relay WebSocket URL:
[Press Enter to use the default]

AGENT_TOKEN:
<your agent token>

Device ID:
telegram-core

Device name:
Telegram Core
```

The `AGENT_TOKEN` is entered silently and is not displayed on the terminal.

---

## Default Relay URL

The default Relay endpoint is:

```text
wss://mcp-relay.katebsaber.ir/agent
```

You can press Enter during installation to use it.

You may also enter a different WebSocket Relay URL.

---

## Device ID

Each connected machine must have a unique Device ID.

Examples:

```text
webdade
home-pc
telegram-core
server-01
production-web
```

Use a short, stable and descriptive identifier.

The installer normalizes Device IDs to a safe format using lowercase letters, numbers, dots, underscores and hyphens.

---

## Runtime Linux User

The installer does not depend on a user such as `pachim`, `ubuntu`, or `root`.

Behavior:

- When executed through `sudo` by a normal user, the service runs as that user.
- When executed directly as `root`, a dedicated system user named `desktop-commander` is created automatically.
- A specific existing Linux user can be selected using `RUN_AS_USER`.

Example:

```bash
sudo env RUN_AS_USER=ubuntu ./install-desktop-commander-relay-agent.sh
```

Or:

```bash
sudo env RUN_AS_USER=deploy ./install-desktop-commander-relay-agent.sh
```

The selected user must already exist.

---

## Installed Paths

By default, the installer uses:

```text
Relay Agent:
/opt/desktop-commander-relay-agent

Configuration:
/etc/desktop-commander-relay/agent.env

systemd service:
/etc/systemd/system/desktop-commander-relay-agent.service
```

The configuration file is protected with restrictive permissions.

---

## Configuration

The generated configuration contains values similar to:

```env
RELAY_WS_URL=wss://mcp-relay.katebsaber.ir/agent
AGENT_TOKEN=YOUR_AGENT_TOKEN
DEVICE_ID=telegram-core
DEVICE_NAME=Telegram Core
DESKTOP_COMMANDER_COMMAND=/usr/bin/desktop-commander
```

The actual path of `desktop-commander` is detected automatically during installation.

Do not commit `AGENT_TOKEN` to Git.

---

## systemd Service

The installer automatically creates and enables:

```text
desktop-commander-relay-agent.service
```

Check its status:

```bash
sudo systemctl status desktop-commander-relay-agent --no-pager -l
```

Restart it:

```bash
sudo systemctl restart desktop-commander-relay-agent
```

Stop it:

```bash
sudo systemctl stop desktop-commander-relay-agent
```

Start it:

```bash
sudo systemctl start desktop-commander-relay-agent
```

Enable automatic startup:

```bash
sudo systemctl enable desktop-commander-relay-agent
```

Follow live logs:

```bash
sudo journalctl -u desktop-commander-relay-agent -f
```

Show recent logs:

```bash
sudo journalctl -u desktop-commander-relay-agent -n 100 --no-pager
```

---

## Expected Successful Log

A successful connection should look similar to:

```text
[agent] local Desktop Commander connected via executable: /usr/bin/desktop-commander
[agent] connecting to relay wss://mcp-relay.katebsaber.ir/agent as 'telegram-core' with 26 tools
[agent] relay connected and authenticated
```

This means:

1. Desktop Commander started successfully.
2. The Relay Agent discovered Desktop Commander tools.
3. The Agent connected to the Relay server.
4. Agent authentication succeeded.

---

## Verify Relay Connectivity

Check the Relay health endpoint:

```bash
curl -fsS https://mcp-relay.katebsaber.ir/healthz
echo
```

If multiple devices are connected, the response may show something similar to:

```json
{
  "ok": true,
  "devices": 3
}
```

The exact response depends on the Relay server version.

---

## Reinstall / Update

Run the installer again:

```bash
sudo ./install-desktop-commander-relay-agent.sh
```

If the Relay Agent directory already contains the expected Git repository, the installer attempts to update it using Git and rebuild the project.

If local modifications prevent a safe fast-forward update, the installer stops instead of overwriting them.

---

## Custom Installation Directory

You can override the default Relay Agent directory:

```bash
sudo env RELAY_DIR=/opt/my-relay-agent \
  ./install-desktop-commander-relay-agent.sh
```

Default:

```text
/opt/desktop-commander-relay-agent
```

---

## Custom Relay Repository

By default, the installer downloads:

```text
https://github.com/ErfKS/DesktopCommanderRelay.git
```

You can override it:

```bash
sudo env RELAY_REPO=https://github.com/USERNAME/DesktopCommanderRelay.git \
  ./install-desktop-commander-relay-agent.sh
```

---

## Custom Relay WebSocket URL

You can predefine the Relay URL:

```bash
sudo env RELAY_WS_URL=wss://relay.example.com/agent \
  ./install-desktop-commander-relay-agent.sh
```

It will be used as the default value during the interactive setup.

---

## Security Notes

The Relay Agent can execute Desktop Commander tools on the target machine. Treat access to it as privileged remote access.

Recommended practices:

- Use a strong and private `AGENT_TOKEN`.
- Never publish the `AGENT_TOKEN`.
- Rotate the token if it is exposed.
- Use `wss://` for Relay connections.
- Run the Agent as a non-root user whenever possible.
- Grant the runtime user access only to directories and commands it actually needs.
- Keep the operating system, Node.js, Desktop Commander and Relay Agent updated.
- Protect the Relay server with proper authentication and firewall rules.
- Use a unique `DEVICE_ID` for every machine.

The generated configuration file is stored with restrictive permissions:

```text
/etc/desktop-commander-relay/agent.env
```

---

## Troubleshooting

### Service is not running

Check:

```bash
sudo systemctl status desktop-commander-relay-agent --no-pager -l
```

Then inspect logs:

```bash
sudo journalctl -u desktop-commander-relay-agent -n 100 --no-pager
```

### Authentication failed

Verify that the Agent and Relay server use the same `AGENT_TOKEN`.

Configuration:

```text
/etc/desktop-commander-relay/agent.env
```

After changing it:

```bash
sudo systemctl restart desktop-commander-relay-agent
```

### Desktop Commander executable not found

Check:

```bash
command -v desktop-commander
```

Reinstall if necessary:

```bash
sudo npm install -g @wonderwhy-er/desktop-commander@latest
```

Then restart:

```bash
sudo systemctl restart desktop-commander-relay-agent
```

### Relay is unreachable

Test:

```bash
curl -I https://mcp-relay.katebsaber.ir
```

And inspect Agent logs:

```bash
sudo journalctl -u desktop-commander-relay-agent -f
```

Check DNS, TLS, firewall and the Relay server itself if the connection cannot be established.

---

## Related Projects

- DesktopCommanderRelay  
  https://github.com/ErfKS/DesktopCommanderRelay

- Desktop Commander MCP  
  https://github.com/wonderwhy-er/DesktopCommanderMCP

- Installer Repository  
  https://github.com/amirkateb/DesktopCommanderRelayAgentInstaller

---

## License

Use the license defined in this repository.

Third-party projects installed by this script remain subject to their own licenses.

---

# راهنمای فارسی

این مخزن یک Installer خودکار برای نصب **Desktop Commander Relay Agent** روی سرورهای Ubuntu و Debian است.

هدف این پروژه این است که یک سرور جدید یا حتی خام را با کمترین تنظیم دستی به یک Device قابل اتصال به DesktopCommanderRelay تبدیل کند.

---

## این اسکریپت چه کاری انجام می‌دهد؟

Installer به‌صورت خودکار:

- پکیج‌های پایه را نصب می‌کند.
- وجود Node.js مناسب را بررسی می‌کند.
- در صورت نیاز Node.js را نصب می‌کند.
- Desktop Commander را نصب می‌کند.
- پروژه DesktopCommanderRelay را دریافت می‌کند.
- Relay Agent را build می‌کند.
- تنظیمات Agent را ایجاد می‌کند.
- سرویس `systemd` می‌سازد.
- سرویس را فعال و اجرا می‌کند.
- اجرای خودکار بعد از reboot را فعال می‌کند.
- وضعیت اتصال Agent و Relay را بررسی می‌کند.

این Installer به هیچ username مشخصی مثل `pachim` وابسته نیست.

---

## معماری

```text
ChatGPT / GPT Action
        |
        v
DesktopCommanderRelay Server
        |
        | WebSocket /agent
        v
DesktopCommanderRelay Agent
        |
        | stdio
        v
Desktop Commander MCP
        |
        v
سرور Ubuntu / Debian
```

چندین سرور می‌توانند با `DEVICE_ID`های متفاوت به یک Relay Server متصل شوند.

---

## پیش‌نیازها

سیستم‌عامل‌های پشتیبانی‌شده:

- Ubuntu
- Debian
- توزیع‌های مبتنی بر Debian که از `systemd` استفاده می‌کنند

همچنین نیاز دارید به:

- دسترسی `root` یا `sudo`
- اینترنت در زمان نصب
- یک DesktopCommanderRelay Server فعال
- `AGENT_TOKEN` معتبر
- یک `DEVICE_ID` یکتا برای دستگاه

اگر Node.js نصب نباشد یا نسخه آن کمتر از 20 باشد، Installer نسخه مناسب را نصب می‌کند.

---

## نصب

ابتدا Repository را clone کنید:

```bash
git clone https://github.com/amirkateb/DesktopCommanderRelayAgentInstaller.git
cd DesktopCommanderRelayAgentInstaller
```

به اسکریپت اجازه اجرا بدهید:

```bash
chmod +x install-desktop-commander-relay-agent.sh
```

سپس اجرا کنید:

```bash
sudo ./install-desktop-commander-relay-agent.sh
```

در حین نصب این موارد از شما پرسیده می‌شود:

```text
Relay WebSocket URL [wss://mcp-relay.katebsaber.ir/agent]:
AGENT_TOKEN:
Device ID (example: telegram-core):
Device name [telegram-core]:
```

مثال:

```text
Relay WebSocket URL:
Enter

AGENT_TOKEN:
توکن Agent

Device ID:
telegram-core

Device name:
Telegram Core
```

مقدار `AGENT_TOKEN` هنگام تایپ روی ترمینال نمایش داده نمی‌شود.

---

## آدرس پیش‌فرض Relay

آدرس پیش‌فرض:

```text
wss://mcp-relay.katebsaber.ir/agent
```

است.

اگر همین Relay را استفاده می‌کنید، هنگام سؤال مربوط به Relay URL فقط Enter بزنید.

---

## Device ID چیست؟

هر دستگاه باید یک شناسه یکتا داشته باشد.

مثال:

```text
webdade
home-pc
telegram-core
server-01
production-web
```

بهتر است Device ID کوتاه، ثابت و قابل تشخیص باشد.

Installer مقدار Device ID را به فرمت امن تبدیل می‌کند.

---

## کاربر لینوکس

Installer به user خاصی وابسته نیست.

رفتار آن به این صورت است:

- اگر با یک user معمولی و `sudo` اجرا شود، سرویس با همان user اجرا خواهد شد.
- اگر مستقیم به‌عنوان `root` اجرا شود، Installer یک system user به نام زیر می‌سازد:

```text
desktop-commander
```

- اگر بخواهید user خاصی را تعیین کنید، می‌توانید از `RUN_AS_USER` استفاده کنید.

مثال:

```bash
sudo env RUN_AS_USER=ubuntu ./install-desktop-commander-relay-agent.sh
```

یا:

```bash
sudo env RUN_AS_USER=deploy ./install-desktop-commander-relay-agent.sh
```

user موردنظر باید از قبل در سیستم وجود داشته باشد.

---

## مسیرهای نصب

مسیر پیش‌فرض Relay Agent:

```text
/opt/desktop-commander-relay-agent
```

فایل تنظیمات:

```text
/etc/desktop-commander-relay/agent.env
```

فایل سرویس systemd:

```text
/etc/systemd/system/desktop-commander-relay-agent.service
```

---

## تنظیمات Agent

فایل تنظیمات تقریباً چنین ساختاری خواهد داشت:

```env
RELAY_WS_URL=wss://mcp-relay.katebsaber.ir/agent
AGENT_TOKEN=YOUR_AGENT_TOKEN
DEVICE_ID=telegram-core
DEVICE_NAME=Telegram Core
DESKTOP_COMMANDER_COMMAND=/usr/bin/desktop-commander
```

مسیر واقعی `desktop-commander` هنگام نصب به‌صورت خودکار تشخیص داده می‌شود.

هیچ‌وقت `AGENT_TOKEN` را داخل Git قرار ندهید.

---

## مدیریت سرویس

وضعیت:

```bash
sudo systemctl status desktop-commander-relay-agent --no-pager -l
```

Restart:

```bash
sudo systemctl restart desktop-commander-relay-agent
```

Stop:

```bash
sudo systemctl stop desktop-commander-relay-agent
```

Start:

```bash
sudo systemctl start desktop-commander-relay-agent
```

فعال‌کردن اجرای خودکار:

```bash
sudo systemctl enable desktop-commander-relay-agent
```

مشاهده زنده لاگ‌ها:

```bash
sudo journalctl -u desktop-commander-relay-agent -f
```

مشاهده 100 خط آخر:

```bash
sudo journalctl -u desktop-commander-relay-agent -n 100 --no-pager
```

---

## خروجی صحیح اتصال

اگر نصب درست انجام شده باشد، در لاگ‌ها باید چیزی مشابه این ببینید:

```text
[agent] local Desktop Commander connected via executable: /usr/bin/desktop-commander
[agent] connecting to relay wss://mcp-relay.katebsaber.ir/agent as 'telegram-core' with 26 tools
[agent] relay connected and authenticated
```

این خروجی یعنی:

1. Desktop Commander درست اجرا شده است.
2. ابزارها شناسایی شده‌اند.
3. Agent به Relay متصل شده است.
4. احراز هویت Agent موفق بوده است.

---

## بررسی Relay

برای بررسی health endpoint:

```bash
curl -fsS https://mcp-relay.katebsaber.ir/healthz
echo
```

اگر چند دستگاه متصل باشند ممکن است خروجی شبیه زیر باشد:

```json
{
  "ok": true,
  "devices": 3
}
```

فرمت دقیق خروجی به نسخه Relay Server بستگی دارد.

---

## نصب مجدد یا Update

کافی است Installer را دوباره اجرا کنید:

```bash
sudo ./install-desktop-commander-relay-agent.sh
```

اگر مسیر Relay از قبل یک Git repository معتبر باشد، Installer تلاش می‌کند repository را update و پروژه را دوباره build کند.

اگر تغییرات محلی باعث شود update امن نباشد، Installer به‌جای overwrite کردن فایل‌ها متوقف خواهد شد.

---

## تغییر مسیر نصب

می‌توانید مسیر پیش‌فرض را تغییر دهید:

```bash
sudo env RELAY_DIR=/opt/my-relay-agent \
  ./install-desktop-commander-relay-agent.sh
```

مسیر پیش‌فرض:

```text
/opt/desktop-commander-relay-agent
```

---

## استفاده از Relay Repository متفاوت

به‌صورت پیش‌فرض از این repository استفاده می‌شود:

```text
https://github.com/ErfKS/DesktopCommanderRelay.git
```

برای تغییر آن:

```bash
sudo env RELAY_REPO=https://github.com/USERNAME/DesktopCommanderRelay.git \
  ./install-desktop-commander-relay-agent.sh
```

---

## تعیین Relay URL از قبل

مثلاً:

```bash
sudo env RELAY_WS_URL=wss://relay.example.com/agent \
  ./install-desktop-commander-relay-agent.sh
```

این مقدار به‌عنوان مقدار پیش‌فرض در Installer نمایش داده خواهد شد.

---

## نکات امنیتی

Relay Agent می‌تواند از طریق Desktop Commander روی سیستم مقصد عملیات انجام دهد. بنابراین باید آن را مانند یک دسترسی Remote با سطح اهمیت بالا در نظر بگیرید.

پیشنهادها:

- از `AGENT_TOKEN` قوی استفاده کنید.
- توکن را عمومی نکنید.
- اگر Token افشا شد، آن را عوض کنید.
- برای اتصال Relay از `wss://` استفاده کنید.
- Agent را تا حد امکان با user غیر root اجرا کنید.
- دسترسی user مربوط به Agent را محدود کنید.
- سیستم‌عامل و Node.js و Desktop Commander و Relay Agent را به‌روز نگه دارید.
- Relay Server را با Authentication و Firewall مناسب محافظت کنید.
- برای هر دستگاه یک `DEVICE_ID` متفاوت استفاده کنید.

فایل حاوی Token در این مسیر قرار می‌گیرد:

```text
/etc/desktop-commander-relay/agent.env
```

و Installer دسترسی آن را محدود می‌کند.

---

## رفع مشکل

### سرویس اجرا نمی‌شود

```bash
sudo systemctl status desktop-commander-relay-agent --no-pager -l
```

سپس:

```bash
sudo journalctl -u desktop-commander-relay-agent -n 100 --no-pager
```

### خطای Authentication

مطمئن شوید `AGENT_TOKEN` روی Agent و Relay Server یکسان است.

فایل تنظیمات:

```text
/etc/desktop-commander-relay/agent.env
```

پس از تغییر:

```bash
sudo systemctl restart desktop-commander-relay-agent
```

### پیدا نشدن Desktop Commander

بررسی کنید:

```bash
command -v desktop-commander
```

در صورت نیاز دوباره نصب کنید:

```bash
sudo npm install -g @wonderwhy-er/desktop-commander@latest
```

و سپس:

```bash
sudo systemctl restart desktop-commander-relay-agent
```

### عدم اتصال به Relay

ابتدا:

```bash
curl -I https://mcp-relay.katebsaber.ir
```

سپس لاگ Agent:

```bash
sudo journalctl -u desktop-commander-relay-agent -f
```

در صورت عدم اتصال، DNS، TLS، Firewall و وضعیت Relay Server را بررسی کنید.

---

## پروژه‌های مرتبط

DesktopCommanderRelay:

```text
https://github.com/ErfKS/DesktopCommanderRelay
```

Desktop Commander MCP:

```text
https://github.com/wonderwhy-er/DesktopCommanderMCP
```

Installer:

```text
https://github.com/amirkateb/DesktopCommanderRelayAgentInstaller
```

---

## License

استفاده از این پروژه تابع License همین repository است.

پروژه‌ها و dependencyهای شخص ثالث نیز تابع License خودشان هستند.
