#!/usr/bin/env bash
# Desktop Commander Relay Agent Manager
# by amirmohammad katebsaber
# Ubuntu / Debian | Bash 4.4+ | systemd
set -Eeuo pipefail
umask 077

VERSION="2.0.0"
SERVICE_NAME="desktop-commander-relay-agent"
MAIN_SERVICE="desktop-commander-relay-server.service"
RELAY_DIR="${RELAY_DIR:-/opt/desktop-commander-relay-agent}"
RELAY_REPO="${RELAY_REPO:-https://github.com/ErfKS/DesktopCommanderRelay.git}"
CONFIG_DIR="/etc/desktop-commander-relay"
ENV_FILE="${CONFIG_DIR}/agent.env"
STATE_FILE="${CONFIG_DIR}/manager.conf"
UNIT_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
MANAGER_PATH="/usr/local/sbin/dc-relay-agent-manager"
LOG_FILE="/var/log/desktop-commander-relay-manager.log"
DEFAULT_RELAY_WS_URL="${RELAY_WS_URL:-wss://mcp-relay.katebsaber.ir/agent}"
STAGED_REPO=""

if [[ -t 1 && -z "${NO_COLOR:-}" && "${TERM:-}" != "dumb" ]]; then
  RESET=$'\033[0m'; BOLD=$'\033[1m'; DIM=$'\033[2m'
  CYAN=$'\033[38;5;45m'; BLUE=$'\033[38;5;39m'; VIOLET=$'\033[38;5;141m'
  GREEN=$'\033[38;5;82m'; YELLOW=$'\033[38;5;220m'; RED=$'\033[38;5;203m'
else
  RESET=""; BOLD=""; DIM=""; CYAN=""; BLUE=""; VIOLET=""
  GREEN=""; YELLOW=""; RED=""
fi

cleanup() { if [[ -n "$STAGED_REPO" && -d "$STAGED_REPO" ]]; then rm -rf -- "$STAGED_REPO"; fi; }
trap cleanup EXIT

line() { printf '%s\n' "${DIM}  ------------------------------------------------------------------${RESET}"; }
heading() { printf '\n%s%s%s\n' "$CYAN$BOLD" "$*" "$RESET"; }
info() { printf '  %s[i]%s %s\n' "$BLUE" "$RESET" "$*"; }
success() { printf '  %s[+]%s %s\n' "$GREEN" "$RESET" "$*"; }
warning() { printf '  %s[!]%s %s\n' "$YELLOW" "$RESET" "$*" >&2; }
error() { printf '  %s[x]%s %s\n' "$RED" "$RESET" "$*" >&2; }
fail() { error "$*"; exit 1; }

banner() {
  printf '\n%s' "$CYAN"
  cat <<'ART'
      ____            __   __               __
     / __ \___  _____/ /__/ /_____  ____    / /
    / / / / _ \/ ___/ //_/ __/ __ \/ __ \  / /
   / /_/ /  __(__  ) ,< / /_/ /_/ / /_/ / /_/
  /_____/\___/____/_/|_|\__/\____/ .___/ (_)
                                  /_/
ART
  printf '%s' "$RESET"
  printf '    %sDESKTOP COMMANDER  /  RELAY AGENT MANAGER%s\n' "$BOLD" "$RESET"
  printf '    %sv%s   -   by amirmohammad katebsaber%s\n' "$DIM" "$VERSION" "$RESET"
  line
}

need_root() {
  (( EUID == 0 )) || fail "Root access required. Use: sudo bash /path/to/desktop-commander-relay-manager.sh"
}
check_platform() {
  [[ -r /etc/os-release ]] || fail "Cannot identify this Linux distribution."
  # shellcheck disable=SC1091
  . /etc/os-release
  if [[ "${ID:-}" != ubuntu && "${ID:-}" != debian && " ${ID_LIKE:-} " != *" debian "* ]]; then
    fail "Supported operating systems: Ubuntu and Debian."
  fi
  command -v systemctl >/dev/null || fail "systemd is required."
  [[ -d /run/systemd/system ]] || fail "This machine does not appear to be booted with systemd."
}
prepare_log() {
  touch "$LOG_FILE" || fail "Cannot open $LOG_FILE"
  chmod 600 "$LOG_FILE"
}
# Command output is saved to a root-only log. Secrets are never passed as arguments to run_step.
run_step() {
  local label="$1" pid result=0 i=0
  shift
  prepare_log
  printf '\n[%s] %s\n' "$(date -Is)" "$label" >> "$LOG_FILE"
  printf '  %s[>] %-52s%s' "$CYAN" "$label" "$RESET"
  ( "$@" ) >> "$LOG_FILE" 2>&1 &
  pid=$!
  if [[ -t 1 ]]; then
    local frames=('|' '/' '-' '\\')
    while kill -0 "$pid" 2>/dev/null; do
      printf '\b%s' "${frames[i++ % 4]}"
      sleep 0.14
    done
    printf '\b '
  fi
  wait "$pid" || result=$?
  if (( result != 0 )); then
    printf ' %sFAILED%s\n' "$RED" "$RESET"
    tail -n 35 "$LOG_FILE" >&2 || true
    fail "${label} failed (exit ${result}). Log: ${LOG_FILE}"
  fi
  printf ' %sDONE%s\n' "$GREEN" "$RESET"
}

ask() {
  local prompt="$1" fallback="${2:-}" value
  read -r -p "  ${prompt}${fallback:+ [$fallback]}: " value || fail "Input cancelled."
  printf '%s' "${value:-$fallback}"
}
yesno() {
  local reply
  read -r -p "  $1 [y/N]: " reply || return 1
  [[ "$reply" =~ ^([Yy]|[Yy][Ee][Ss])$ ]]
}
press_enter() {
  [[ -t 0 ]] || return 0
  read -r -p "  Press Enter to continue..." _ || true
}

is_installed() { [[ -f "$UNIT_FILE" && -f "$ENV_FILE" && -d "$RELAY_DIR" ]]; }
install_manager_command() {
  local source_path
  source_path="$(readlink -f -- "${BASH_SOURCE[0]}")"
  if [[ -f "$source_path" && "$source_path" != "$MANAGER_PATH" ]]; then
    install -o root -g root -m 750 -- "$source_path" "$MANAGER_PATH"
    success "Management command: sudo dc-relay-agent-manager"
  elif [[ "$source_path" == "$MANAGER_PATH" ]]; then
    chmod 750 "$MANAGER_PATH"
  else
    warning "Cannot create persistent command from standard input. Keep this .sh file."
  fi
}

# Read a systemd EnvironmentFile value without ever sourcing/evaluating it.
read_env() {
  local key="$1"
  [[ -f "$ENV_FILE" ]] || return 1
  python3 - "$ENV_FILE" "$key" <<'PY'
import shlex, sys
path, wanted = sys.argv[1:]
with open(path, encoding="utf-8") as file:
    for line in file:
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        if key.strip() == wanted:
            try:
                parts = shlex.split(value.strip(), comments=False, posix=True)
            except ValueError:
                sys.exit(2)
            if len(parts) == 1:
                sys.stdout.write(parts[0])
                sys.exit(0)
            sys.exit(2)
sys.exit(1)
PY
}
service_user() {
  if [[ -f "$UNIT_FILE" ]]; then
    awk -F= '/^User=/{print $2;exit}' "$UNIT_FILE"
  elif [[ -n "${RUN_AS_USER:-}" ]]; then
    printf '%s' "$RUN_AS_USER"
  elif [[ -n "${SUDO_USER:-}" && "${SUDO_USER}" != root ]]; then
    printf '%s' "$SUDO_USER"
  else
    printf 'desktop-commander'
  fi
}
user_home() {
  local username="$1"
  getent passwd "$username" | cut -d: -f6
}
commander_config() {
  local account home
  account="$(service_user)"
  home="$(user_home "$account")"
  [[ -n "$home" ]] || fail "No home directory found for runtime account: $account"
  printf '%s/.claude-server-commander/config.json' "$home"
}

validate_one_line() {
  local label="$1" value="$2"
  [[ "$value" != *$'\n'* && "$value" != *$'\r'* ]] || fail "$label cannot contain line breaks."
}
validate_connection() {
  [[ "$RELAY_WS_URL" =~ ^wss?://[^[:space:]]+$ ]] || fail "Relay URL must start with ws:// or wss:// and contain no spaces."
  [[ "$RELAY_WS_URL" == wss://* ]] || warning "Unencrypted ws:// connections are not recommended."
  [[ -n "$AGENT_TOKEN" ]] || fail "Agent token cannot be empty."
  [[ "$DEVICE_ID" =~ ^[a-z0-9][a-z0-9._-]{0,63}$ ]] || fail "Device ID must start with a-z or 0-9, max 64 chars; use a-z, 0-9, '.', '_' or '-'."
  [[ -n "$DEVICE_NAME" ]] || fail "Device name cannot be empty."
  validate_one_line "Token" "$AGENT_TOKEN"
  validate_one_line "Device name" "$DEVICE_NAME"
  validate_one_line "Relay URL" "$RELAY_WS_URL"
}

show_token_tip() {
  line
  printf '  %sGET YOUR TOKEN FROM THE MAIN RELAY SERVER%s\n' "$BOLD" "$RESET"
  printf '  Run this on the MAIN server (not this agent server):\n\n'
  printf '    %ssudo grep '\''^AGENT_TOKEN='\'' /opt/DesktopCommanderRelay/.env%s\n\n' "$CYAN" "$RESET"
  printf '  Treat the token as a secret. It will be stored in a root-only file.\n'
  line
}
collect_connection() {
  local existing="${1:-no}" default_url="${DEFAULT_RELAY_WS_URL}"
  local default_id="" default_name="" value
  if [[ "$existing" == yes ]]; then
    default_url="$(read_env RELAY_WS_URL || printf '%s' "$DEFAULT_RELAY_WS_URL")"
    default_id="$(read_env DEVICE_ID || true)"
    default_name="$(read_env DEVICE_NAME || true)"
  fi
  printf '\n  %sConnection settings%s\n' "$BOLD" "$RESET"
  RELAY_WS_URL="$(ask 'Relay WebSocket URL' "$default_url")"
  DEVICE_ID="$(ask 'Device ID (e.g. telegram-core)' "$default_id")"
  local entered_id="$DEVICE_ID"
  DEVICE_ID="$(printf '%s' "$DEVICE_ID" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9._-]+/-/g; s/^-+//; s/-+$//')"
  [[ -n "$DEVICE_ID" ]] || fail "Please enter a valid device ID."
  [[ "$DEVICE_ID" == "$entered_id" ]] || warning "Device ID normalized to: $DEVICE_ID"
  DEVICE_NAME="$(ask 'Friendly device name' "${default_name:-$DEVICE_ID}")"
  show_token_tip
  if [[ "$existing" == yes ]]; then
    printf '  Leave the following input empty to KEEP the current token.\n'
  fi
  read -r -s -p '  AGENT_TOKEN (hidden): ' value || fail "Token input cancelled."
  printf '\n'
  value="${value#AGENT_TOKEN=}"
  if [[ -n "$value" ]]; then
    AGENT_TOKEN="$value"
  elif [[ "$existing" == yes ]]; then
    AGENT_TOKEN="$(read_env AGENT_TOKEN || true)"
  else
    AGENT_TOKEN=""
  fi
  validate_connection
  success "Settings validated (token hidden)."
}
env_quote() {
  local escaped="$1"
  escaped="${escaped//\\/\\\\}"
  escaped="${escaped//\"/\\\"}"
  printf '"%s"' "$escaped"
}
write_env() {
  local temp
  mkdir -p "$CONFIG_DIR"
  chmod 700 "$CONFIG_DIR"
  temp="$(mktemp "${CONFIG_DIR}/agent.env.XXXXXXXX")"
  {
    printf 'RELAY_WS_URL=%s\n' "$(env_quote "$RELAY_WS_URL")"
    printf 'AGENT_TOKEN=%s\n' "$(env_quote "$AGENT_TOKEN")"
    printf 'DEVICE_ID=%s\n' "$(env_quote "$DEVICE_ID")"
    printf 'DEVICE_NAME=%s\n' "$(env_quote "$DEVICE_NAME")"
    printf 'DESKTOP_COMMANDER_COMMAND=%s\n' "$(env_quote "$DESKTOP_COMMANDER_BIN")"
  } > "$temp"
  chmod 600 "$temp"
  chown root:root "$temp"
  mv -f "$temp" "$ENV_FILE"
}

ensure_user() {
  local account="$1"
  if ! id "$account" >/dev/null 2>&1; then
    if [[ "$account" == desktop-commander ]]; then
      info "Creating the dedicated Linux service account '$account'..."
      useradd --system --create-home --home-dir /var/lib/desktop-commander --shell /bin/bash "$account"
    else
      fail "Linux account '$account' does not exist."
    fi
  fi
  [[ "$account" != root ]] || fail "Running an agent as root is not allowed by this manager."
  RUN_AS_USER="$account"
  RUN_AS_GROUP="$(id -gn "$account")"
  local home
  home="$(user_home "$account")"
  [[ -d "$home" ]] || fail "Service user home does not exist: $home"
}
ensure_packages() {
  export DEBIAN_FRONTEND=noninteractive
  run_step 'Refreshing package index' apt-get update -y
  run_step 'Installing build dependencies' apt-get install -y ca-certificates curl git build-essential python3
  local need_node=0
  if command -v node >/dev/null 2>&1; then
    if ! node -e 'const [major, minor]=process.versions.node.split(".").map(Number); process.exit(major>22 || (major===22 && minor>=12) ? 0:1)' 2>/dev/null; then
      need_node=1
    fi
  else
    need_node=1
  fi
  if (( need_node )); then
    local node_setup
    node_setup="$(mktemp /tmp/dc-node-setup.XXXXXXXX)"
    run_step 'Downloading Node.js 22 installer' curl -fsSL --retry 3 https://deb.nodesource.com/setup_22.x -o "$node_setup"
    run_step 'Configuring Node.js repository' bash "$node_setup"
    rm -f "$node_setup"
    run_step 'Installing Node.js 22' apt-get install -y nodejs
  fi
  command -v node >/dev/null || fail 'Node.js was not installed.'
  command -v npm >/dev/null || fail 'npm was not installed.'
  NODE_BIN="$(command -v node)"
  run_step 'Installing/updating Desktop Commander' npm install -g @wonderwhy-er/desktop-commander@latest
  DESKTOP_COMMANDER_BIN="$(command -v desktop-commander || true)"
  [[ -n "$DESKTOP_COMMANDER_BIN" ]] || fail 'desktop-commander command is not available on PATH.'
  success "Node $(node --version)  /  npm $(npm --version)"
}

create_staged_repo() {
  local branch="" source_repo="$RELAY_REPO"
  if [[ -e "$RELAY_DIR" && ! -d "$RELAY_DIR/.git" ]]; then
    fail "$RELAY_DIR exists but is not a Git checkout; refusing to overwrite it."
  fi
  if [[ -d "$RELAY_DIR/.git" ]]; then
    if [[ -n "$(git -C "$RELAY_DIR" status --porcelain --untracked-files=no)" ]]; then
      fail "Existing checkout has tracked local changes. Commit/revert them before updating."
    fi
    branch="$(git -C "$RELAY_DIR" symbolic-ref --quiet --short HEAD || true)"
    local original_remote
    original_remote="$(git -C "$RELAY_DIR" remote get-url origin || true)"
    if [[ -n "$original_remote" && "$original_remote" != "$RELAY_REPO" ]]; then
      warning "Existing repository uses a different origin: $original_remote"
      if ! yesno 'Continue with the configured RELAY_REPO instead?'; then
        fail 'Update cancelled to protect the existing checkout.'
      fi
    fi
  fi
  mkdir -p "$(dirname "$RELAY_DIR")"
  STAGED_REPO="$(mktemp -d "${RELAY_DIR}.stage.XXXXXXXX")"
  if [[ -n "$branch" ]]; then
    run_step "Cloning latest relay agent ($branch)" git clone --depth 1 --branch "$branch" "$source_repo" "$STAGED_REPO"
  else
    run_step 'Cloning latest relay agent' git clone --depth 1 "$source_repo" "$STAGED_REPO"
  fi
  run_step 'Installing locked project dependencies' npm --prefix "$STAGED_REPO" ci --no-audit
  run_step 'Building relay agent' npm --prefix "$STAGED_REPO" run build
  [[ -s "$STAGED_REPO/dist/agent/index.js" ]] || fail 'Missing agent build: dist/agent/index.js'
}

write_unit() {
  local tmp description="${DEVICE_NAME//%/%%}"
  # systemd executable arguments should not contain spaces/line breaks here.
  [[ "$RELAY_DIR" != *[[:space:]]* && "$NODE_BIN" != *[[:space:]]* ]] || fail 'Install paths with whitespace are not supported.'
  validate_one_line 'Device name' "$DEVICE_NAME"
  tmp="$(mktemp /etc/systemd/system/dc-relay-agent.XXXXXXXX)"
  cat > "$tmp" <<EOF
[Unit]
Description=Desktop Commander Relay Agent - ${description}
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=${RUN_AS_USER}
Group=${RUN_AS_GROUP}
WorkingDirectory=${RELAY_DIR}
EnvironmentFile=${ENV_FILE}
Environment=PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
ExecStart=${NODE_BIN} ${RELAY_DIR}/dist/agent/index.js
Restart=always
RestartSec=3
KillSignal=SIGTERM
TimeoutStopSec=20

[Install]
WantedBy=multi-user.target
EOF
  chmod 644 "$tmp"
  mv -f "$tmp" "$UNIT_FILE"
}
# Promote a staged build only after a successful npm ci + build.
# If the service fails to start, restore the previous source and settings.
activate_staged_build() {
  local old_dir="" old_env="" old_unit="" current_pid=""
  mkdir -p "$CONFIG_DIR/backups"
  chmod 700 "$CONFIG_DIR/backups"
  local stamp="$(date +%Y%m%d-%H%M%S)-$$"
  if [[ -d "$RELAY_DIR" ]]; then
    old_dir="${RELAY_DIR}.previous.${stamp}"
  fi
  if [[ -f "$ENV_FILE" ]]; then
    old_env="${CONFIG_DIR}/backups/agent.env.${stamp}"
    cp -p -- "$ENV_FILE" "$old_env"
  fi
  if [[ -f "$UNIT_FILE" ]]; then
    old_unit="${CONFIG_DIR}/backups/agent.service.${stamp}"
    cp -p -- "$UNIT_FILE" "$old_unit"
  fi
  if [[ -n "$old_dir" ]]; then
    mv -- "$RELAY_DIR" "$old_dir"
  fi
  if ! mv -- "$STAGED_REPO" "$RELAY_DIR"; then
    [[ -z "$old_dir" ]] || mv -- "$old_dir" "$RELAY_DIR"
    fail 'Unable to activate the new build.'
  fi
  STAGED_REPO=""
  write_env
  write_unit
  systemctl daemon-reload
  systemctl enable "$SERVICE_NAME" >/dev/null
  if systemctl restart "$SERVICE_NAME" && sleep 2 && systemctl is-active --quiet "$SERVICE_NAME"; then
    success "Agent service started: ${SERVICE_NAME}.service"
    if [[ -n "$old_dir" ]]; then
      success "Previous build retained at: $old_dir"
    fi
    return 0
  fi
  warning 'New service did not start. Rolling back the previous installation...'
  systemctl stop "$SERVICE_NAME" >/dev/null 2>&1 || true
  mv -- "$RELAY_DIR" "${RELAY_DIR}.failed.${stamp}" || true
  if [[ -n "$old_dir" ]]; then mv -- "$old_dir" "$RELAY_DIR"; fi
  if [[ -n "$old_env" ]]; then cp -p "$old_env" "$ENV_FILE"; else rm -f "$ENV_FILE"; fi
  if [[ -n "$old_unit" ]]; then cp -p "$old_unit" "$UNIT_FILE"; else rm -f "$UNIT_FILE"; fi
  systemctl daemon-reload
  if [[ -n "$old_dir" ]]; then systemctl restart "$SERVICE_NAME" || true; fi
  fail "Deployment rolled back. Check: journalctl -u ${SERVICE_NAME} -n 80"
}

save_metadata() {
  { printf '# Desktop Commander Relay Manager metadata (no secrets)\n';
    printf 'MANAGER_VERSION=%s\n' "$VERSION";
    printf 'RELAY_REPO=%s\n' "$RELAY_REPO";
    printf 'RELAY_DIR=%s\n' "$RELAY_DIR";
  } > "$STATE_FILE"
  chmod 600 "$STATE_FILE"
}

health_check() {
  local ws base
  ws="$(read_env RELAY_WS_URL || true)"
  [[ -n "$ws" ]] || return 0
  base="${ws%/agent}"
  base="${base/#wss:\/\//https://}"
  base="${base/#ws:\/\//http://}"
  printf '  %sRelay health:%s %s/healthz\n' "$DIM" "$RESET" "$base"
  if curl -fsS --max-time 8 -o /dev/null "${base%/}/healthz"; then
    success 'Main relay HTTP health endpoint is reachable.'
  else
    warning 'Health endpoint could not be reached (the agent may still work).'
  fi
}

sudo_config_status() {
  local cfg="$(commander_config)"
  if [[ ! -f "$cfg" ]]; then
    printf '  %sDesktop Commander config:%s not found yet (%s)\n' "$DIM" "$RESET" "$cfg"
    return 0
  fi
  python3 - "$cfg" <<'PY'
import json,sys
try:
    with open(sys.argv[1]) as f: obj=json.load(f)
    blocked=obj.get('blockedCommands',[])
    if not isinstance(blocked,list): raise ValueError('blockedCommands is not a list')
    print('  Desktop Commander sudo policy: ' + ('BLOCKED' if 'sudo' in blocked else 'UNBLOCKED'))
except (ValueError,OSError,TypeError) as exc:
    print(f'  Desktop Commander config: ERROR - {exc}')
PY
}

# Changes only blockedCommands; backup and atomic replace preserve other settings.
set_sudo_policy() {
  local action="$1" account cfg
  account="$(service_user)"
  cfg="$(commander_config)"
  if [[ ! -f "$cfg" ]]; then
    warning "Config not found: $cfg"
    warning 'Start the agent and let Desktop Commander initialize its config, then retry this menu item.'
    return 1
  fi
  python3 - "$cfg" "$action" <<'PY'
import json, os, shutil, sys, tempfile
from datetime import datetime
from pathlib import Path
p=Path(sys.argv[1]); action=sys.argv[2]
if action not in ('enable','disable'):
    sys.exit('Invalid action')
config=json.loads(p.read_text())
if not isinstance(config, dict):
    sys.exit('Config root must be an object')
blocked=config.get('blockedCommands',[])
if not isinstance(blocked, list) or not all(isinstance(x,str) for x in blocked):
    sys.exit('blockedCommands must be a list of strings')
print('Before:', blocked)
new=[x for x in blocked if x!='sudo'] if action=='enable' else (blocked if 'sudo' in blocked else blocked+['sudo'])
if new != blocked:
    stamp=datetime.now().strftime('%Y%m%d-%H%M%S-%f')
    backup=p.with_name(p.name+'.bak.'+stamp)
    shutil.copy2(p, backup)
    config['blockedCommands']=new
    fd, name=tempfile.mkstemp(prefix='.config.',suffix='.tmp',dir=p.parent)
    try:
        with os.fdopen(fd,'w') as f:
            json.dump(config,f,indent=2,ensure_ascii=False)
            f.write('\n')
            f.flush(); os.fsync(f.fileno())
        stat=p.stat()
        os.chmod(name,stat.st_mode & 0o7777)
        os.chown(name,stat.st_uid,stat.st_gid)
        os.replace(name,p)
    finally:
        if os.path.exists(name): os.unlink(name)
    print('Backup:', backup)
else:
    print('The requested policy is already in effect.')
print('After:', new)
print('sudo command is now ' + ('UNBLOCKED' if action=='enable' else 'BLOCKED') + '.')
PY
  if systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
    if systemctl restart "$SERVICE_NAME"; then
      success 'Agent restarted to apply the sudo policy.'
    else
      warning 'Policy changed, but service restart failed. Check the logs.'
    fi
  fi
  if [[ "$action" == enable ]]; then
    warning "This does NOT grant Linux sudo privileges to '$account'."
    warning 'Linux sudo permissions are configured separately and may require NOPASSWD for a background service.'
  fi
}

sudoers_file() {
  local account="$1"
  [[ "$account" =~ ^[a-z_][a-z0-9_-]*[$]?$ ]] || fail 'Unsupported account name for sudoers management.'
  printf '/etc/sudoers.d/90-dc-relay-agent-%s' "$account"
}
grant_passwordless_sudo() {
  local account filename staging
  account="$(service_user)"
  [[ "$account" != root ]] || fail 'Refusing to modify sudo policy for root.'
  command -v visudo >/dev/null || fail 'visudo is required. Install the sudo package first.'
  printf '\n  %sHIGH-RISK ACTION%s\n' "$RED" "$RESET"
  warning "This grants '$account' PASSWORDLESS ROOT access to the whole server."
  warning 'A remote or compromised agent may then execute arbitrary root commands.'
  warning 'Use a dedicated, restricted account and only enable this when necessary.'
  local typed
  read -r -p '  Type GRANT ROOT to continue: ' typed || return 1
  [[ "$typed" == 'GRANT ROOT' ]] || { warning 'Cancelled.'; return 1; }
  yesno 'Are you sure you want unrestricted Linux sudo access?' || { warning 'Cancelled.'; return 1; }
  filename="$(sudoers_file "$account")"
  staging="$(mktemp /etc/sudoers.d/.dc-relay-XXXXXXXX)"
  printf '%s ALL=(ALL:ALL) NOPASSWD: ALL\n' "$account" > "$staging"
  chmod 440 "$staging"
  if visudo -cf "$staging" >/dev/null; then
    mv -f "$staging" "$filename"
    chmod 440 "$filename"
    success "Passwordless Linux sudo is now configured for '$account'."
  else
    rm -f "$staging"
    fail 'Sudoers validation failed; nothing was changed.'
  fi
}
revoke_passwordless_sudo() {
  local account filename
  account="$(service_user)"
  filename="$(sudoers_file "$account")"
  if [[ ! -f "$filename" ]]; then
    info 'No installer-managed passwordless sudo grant found.'
    return 0
  fi
  if yesno "Delete installer-managed passwordless sudo grant for '$account'?"; then
    rm -f -- "$filename"
    success 'Installer-managed sudoers grant removed. Other sudo rules were not changed.'
  fi
}

sudo_menu() {
  need_root
  local choice account filename
  while true; do
    if ! is_installed; then warning "Install the relay agent before managing its sudo policy."; return 1; fi
    account="$(service_user)"
    filename="$(sudoers_file "$account")"
    heading 'SUDO ACCESS CONTROL'
    info "Runtime account: $account"
    sudo_config_status
    if [[ -f "$filename" ]]; then info 'Installer-managed Linux NOPASSWD grant: present';
    else info 'Installer-managed Linux NOPASSWD grant: absent'; fi
    cat <<'MENU'

    1) Unblock "sudo" in Desktop Commander config
    2) Block "sudo" in Desktop Commander config
    3) Grant Linux passwordless sudo (advanced / dangerous)
    4) Remove installer-managed Linux passwordless sudo grant
    5) Check policy and account permissions
    0) Back to main menu
MENU
    read -r -p '  Select: ' choice || return 0
    case "$choice" in
      1) set_sudo_policy enable || true; press_enter ;;
      2) set_sudo_policy disable || true; press_enter ;;
      3) grant_passwordless_sudo || true; press_enter ;;
      4) revoke_passwordless_sudo; press_enter ;;
      5) sudo_config_status; id "$account"; if command -v sudo >/dev/null; then sudo -l -U "$account" || true; fi; press_enter ;;
      0) return 0 ;;
      *) warning 'Invalid choice.' ;;
    esac
  done
}

show_summary() {
  local account id name commit
  account="$(service_user)"
  id="$(read_env DEVICE_ID || printf 'unknown')"
  name="$(read_env DEVICE_NAME || printf 'unknown')"
  commit="$(git -C "$RELAY_DIR" rev-parse --short HEAD 2>/dev/null || printf 'unknown')"
  heading 'INSTALLATION SUMMARY'
  printf '  %-22s %s\n' 'Device ID' "$id" 'Device name' "$name" 'Runtime account' "$account" \
    'Git revision' "$commit" 'Project directory' "$RELAY_DIR" 'Agent config' "$ENV_FILE" \
    'Agent service' "$SERVICE_NAME.service" 'Manager command' 'sudo dc-relay-agent-manager'
  if systemctl is-active --quiet "$SERVICE_NAME"; then success 'Agent service is ACTIVE.'
  else warning 'Agent service is not active.'; fi
  sudo_config_status
  health_check
}

install_agent() {
  need_root; check_platform
  banner
  if is_installed; then
    warning 'An installation is already present. Choose Update or Reconfigure from the menu.'
    return 0
  fi
  heading 'NEW AGENT SETUP  /  1 OF 4: RUNTIME ACCOUNT'
  local proposed
  proposed="$(service_user)"
  RUN_AS_USER="$(ask 'Linux account for the agent' "$proposed")"
  [[ "$RUN_AS_USER" != root ]] || fail "Running an agent as root is not allowed."
  heading '2 OF 4: RELAY CONNECTION'
  collect_connection no
  heading '3 OF 4: REVIEW'
  printf '  %-20s %s\n' 'Run as' "$RUN_AS_USER" 'Relay URL' "$RELAY_WS_URL" \
    'Device ID' "$DEVICE_ID" 'Device name' "$DEVICE_NAME" 'Token' '[hidden]'
  yesno 'Install and start the service with these settings?' || { warning 'Installation cancelled.'; return 0; }
  heading '4 OF 4: INSTALLING'
  ensure_user "$RUN_AS_USER"
  ensure_packages
  create_staged_repo
  activate_staged_build
  save_metadata
  install_manager_command
  show_summary
  heading 'OPTIONAL: ENABLE SUDO COMMAND'
  warning 'Unblocking sudo allows Desktop Commander to request sudo; it does not grant operating-system privileges.'
  if yesno 'Unblock sudo in Desktop Commander after installation?'; then
    set_sudo_policy enable || true
  else
    info 'Desktop Commander sudo policy was left unchanged.'
  fi
  show_main_server_guide
  success 'Installation workflow completed.'
}

update_agent() {
  need_root; check_platform
  is_installed || fail 'Agent is not installed. Choose Install first.'
  heading 'SAFE AGENT UPDATE'
  info 'Your existing agent.env token, device identity and service user will be preserved.'
  local before after
  before="$(git -C "$RELAY_DIR" rev-parse --short HEAD 2>/dev/null || true)"
  RUN_AS_USER="$(service_user)"
  ensure_user "$RUN_AS_USER"
  RELAY_WS_URL="$(read_env RELAY_WS_URL)"
  AGENT_TOKEN="$(read_env AGENT_TOKEN)"
  DEVICE_ID="$(read_env DEVICE_ID)"
  DEVICE_NAME="$(read_env DEVICE_NAME)"
  validate_connection
  yesno 'Download, build and deploy the latest agent and Desktop Commander?' || { warning 'Update cancelled.'; return 0; }
  ensure_packages
  create_staged_repo
  activate_staged_build
  save_metadata
  install_manager_command
  after="$(git -C "$RELAY_DIR" rev-parse --short HEAD)"
  success "Relay agent revision: ${before:-none} -> ${after}"
  show_summary
}

reconfigure_agent() {
  need_root; check_platform
  is_installed || fail 'Agent is not installed.'
  heading 'RECONFIGURE AGENT'
  collect_connection yes
  local account prior prior_unit node_current
  account="$(service_user)"
  ensure_user "$account"
  node_current="$(command -v node || true)"
  DESKTOP_COMMANDER_BIN="$(read_env DESKTOP_COMMANDER_COMMAND || command -v desktop-commander || true)"
  [[ -n "$DESKTOP_COMMANDER_BIN" && -x "$DESKTOP_COMMANDER_BIN" ]] || fail 'Desktop Commander executable is missing. Update the agent first.'
  [[ -n "$node_current" ]] || fail 'Node.js executable is missing. Update the agent first.'
  NODE_BIN="$node_current"
  yesno 'Save and apply these new connection settings?' || { warning 'No settings were changed.'; return 0; }
  prior="$(mktemp "${CONFIG_DIR}/agent.env.previous.XXXXXXXX")"
  cp -p "$ENV_FILE" "$prior"
  prior_unit="$(mktemp "${CONFIG_DIR}/agent.unit.previous.XXXXXXXX")"
  cp -p "$UNIT_FILE" "$prior_unit"
  write_env
  write_unit
  systemctl daemon-reload
  if systemctl restart "$SERVICE_NAME" && sleep 2 && systemctl is-active --quiet "$SERVICE_NAME"; then
    mv "$prior" "${CONFIG_DIR}/agent.env.backup.$(date +%Y%m%d-%H%M%S)-$$"
    mv "$prior_unit" "${CONFIG_DIR}/agent.unit.backup.$(date +%Y%m%d-%H%M%S)-$$"
    success 'Settings saved and agent restarted.' 
  else
    cp -p "$prior" "$ENV_FILE"
    cp -p "$prior_unit" "$UNIT_FILE"
    rm -f "$prior" "$prior_unit"
    systemctl daemon-reload
    systemctl restart "$SERVICE_NAME" || true
    fail 'Reconfiguration failed. Previous settings restored.'
  fi
  show_summary
}

status_agent() {
  heading 'AGENT STATUS'
  if ! is_installed; then
    warning 'Agent is not fully installed on this server.'
    [[ -f "$UNIT_FILE" ]] && systemctl status "$SERVICE_NAME" --no-pager -l || true
    return 0
  fi
  show_summary
  printf '\n'
  systemctl status "$SERVICE_NAME" --no-pager -l || true
}
logs_agent() {
  heading 'RECENT SERVICE LOGS (LAST 50 LINES)'
  journalctl -u "$SERVICE_NAME" -n 50 --no-pager -o short-iso || true
}
follow_logs() {
  heading 'LIVE SERVICE LOGS  /  CTRL+C TO STOP'
  journalctl -u "$SERVICE_NAME" -f -n 20 || true
}
restart_agent() {
  need_root
  [[ -f "$UNIT_FILE" ]] || fail 'Agent service is not installed.'
  run_step 'Restarting relay agent service' systemctl restart "$SERVICE_NAME"
  if systemctl is-active --quiet "$SERVICE_NAME"; then success 'Agent is active.';
  else warning 'Agent is not active; inspect its logs.'; fi
}
show_main_server_guide() {
  heading 'MAIN RELAY SERVER  /  POST-INSTALL GUIDE'
  printf '  %sThese commands run on your MAIN RELAY server, not on this agent.%s\n' "$BOLD" "$RESET"
  printf '\n  %sSTEP 1  Retrieve the shared agent token%s\n' "$CYAN" "$RESET"
  printf '    sudo grep '\''^AGENT_TOKEN='\'' /opt/DesktopCommanderRelay/.env\n'
  printf '\n  %sSTEP 2  Edit the main server environment/configuration%s\n' "$CYAN" "$RESET"
  printf '    sudo nano /opt/DesktopCommanderRelay/.env\n'
  printf '\n    Set TARGET_DEVICE_ID to the new agent ID ONLY if you want to\n'
  printf '    make it the default target for calls without an explicit device_id.\n'
  printf '    The friendly DEVICE_NAME is set on the agent, not registered here.\n'
  printf '    To permit Action process tools on this device, you may also need\n'
  printf '    ACTION_SANDBOX_DEVICE_IDS (comma-separated device IDs).\n'
  printf '    Enable this only when remote process execution is intended.\n'
  if [[ -f "$ENV_FILE" ]]; then
    local current_device
    current_device="$(read_env DEVICE_ID || true)"
    [[ -z "$current_device" ]] || printf '    Example: TARGET_DEVICE_ID=%s\n' "$current_device"
  fi
  printf '\n  %sSTEP 3  Restart the main relay service%s\n' "$CYAN" "$RESET"
  printf '    sudo systemctl restart desktop-commander-relay-server.service\n'
  printf '\n  %sSTEP 4  Verify the connection%s\n' "$CYAN" "$RESET"
  printf '    sudo systemctl status desktop-commander-relay-server.service\n'
  printf '    sudo journalctl -u desktop-commander-relay-server.service -n 50 --no-pager\n'
  printf '\n  On THIS agent server:\n'
  printf '    sudo systemctl status desktop-commander-relay-agent.service\n'
  printf '    sudo journalctl -u desktop-commander-relay-agent.service -f\n'
  line
}

installation_guide() {
  banner
  heading 'QUICK START  /  UBUNTU & DEBIAN'
  cat <<'GUIDE'
  1. Copy the script to your NEW AGENT server.
  2. Start the interactive installer:

       chmod +x desktop-commander-relay-manager.sh
       sudo ./desktop-commander-relay-manager.sh

  3. Choose "Install a new relay agent".
  4. Select the Linux account for the service (e.g. pachim).
  5. Set the Relay WebSocket URL, device ID and device name.
  6. Retrieve AGENT_TOKEN on the MAIN relay server.
  7. Paste that token into the hidden installer prompt.
  8. Review the details and confirm installation.
  9. Choose whether to unblock the "sudo" command.
 10. Register the new device on the main relay if required.
 11. Use the installed manager any time:

       sudo dc-relay-agent-manager

  Useful non-interactive commands:

       sudo dc-relay-agent-manager --update
       sudo dc-relay-agent-manager --status
       sudo dc-relay-agent-manager --logs
       sudo dc-relay-agent-manager --restart
       sudo dc-relay-agent-manager --guide

  Important security notes:
    * AGENT_TOKEN is never printed by the manager.
    * agent.env is stored at /etc/desktop-commander-relay/agent.env
      with owner root and mode 0600.
    * The Desktop Commander blockedCommands setting is separate
      from the Linux sudoers policy.
    * Never grant passwordless sudo to an internet-exposed agent
      unless you fully understand the consequences.
    * Updating fetches latest repository code, rebuilds in staging,
      and retains an older build for rollback.
GUIDE
  show_main_server_guide
}

uninstall_agent() {
  need_root
  heading 'UNINSTALL RELAY AGENT'
  warning 'Uninstall will disable the agent and remove its service unit.'
  warning 'Config, token, repository, backups and sudoers permissions are NOT deleted.'
  local phrase
  read -r -p '  Type UNINSTALL to confirm: ' phrase || return 0
  [[ "$phrase" == UNINSTALL ]] || { warning 'Uninstall cancelled.'; return 0; }
  systemctl disable --now "$SERVICE_NAME" >/dev/null 2>&1 || true
  rm -f -- "$UNIT_FILE"
  systemctl daemon-reload
  success 'Agent unit removed and disabled. Repository, config and sudoers retained.'
  info "To reinstall, run: sudo $MANAGER_PATH --install"
}

show_menu() {
  need_root; check_platform
  local choice
  while true; do
    banner
    if is_installed && systemctl is-active --quiet "$SERVICE_NAME"; then
      printf '    %sSTATUS: INSTALLED / RUNNING%s\n' "$GREEN" "$RESET"
    elif is_installed; then
      printf '    %sSTATUS: INSTALLED / NOT RUNNING%s\n' "$YELLOW" "$RESET"
    else
      printf '    %sSTATUS: NOT INSTALLED%s\n' "$DIM" "$RESET"
    fi
    cat <<'MENU'

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
MENU
    line
    read -r -p '  Choose an option [0-11]: ' choice || { printf '\n'; return 0; }
    case "$choice" in
      1) install_agent; press_enter ;;
      2) update_agent; press_enter ;;
      3) reconfigure_agent; press_enter ;;
      4) status_agent; press_enter ;;
      5) restart_agent; press_enter ;;
      6) logs_agent; press_enter ;;
      7) follow_logs; press_enter ;;
      8) sudo_menu ;;
      9) show_main_server_guide; press_enter ;;
      10) installation_guide; press_enter ;;
      11) uninstall_agent; press_enter ;;
      0) printf '  Goodbye!\n'; return 0 ;;
      *) warning 'Please choose a valid menu option.'; sleep 0.5 ;;
    esac
  done
}

usage() {
  cat <<'HELP'
Desktop Commander Relay Agent Manager
by amirmohammad katebsaber

Usage:
  sudo bash desktop-commander-relay-manager.sh [OPTION]
  sudo dc-relay-agent-manager [OPTION]   # after installation

Options:
  (none), --menu         Interactive management menu
  --install              Install relay agent (guided)
  --update               Update relay agent and Desktop Commander (guided confirmation)
  --configure            Change token, WebSocket URL and device identity
  --status               Show status and connection health
  --restart              Restart agent service
  --logs                 Print the latest 50 service log lines
  --follow-logs          Follow logs (Ctrl+C to exit)
  --sudo                 Manage Desktop Commander and Linux sudo policies
  --main-relay           Main relay server setup commands
  --guide                Full setup walkthrough
  --uninstall            Uninstall service only, preserve all data
  --version              Print manager version
  -h, --help             Show this help

Environment overrides (advanced):
  RELAY_DIR=/opt/desktop-commander-relay-agent
  RELAY_REPO=https://github.com/ErfKS/DesktopCommanderRelay.git
  RELAY_WS_URL=wss://mcp-relay.katebsaber.ir/agent
  RUN_AS_USER=pachim

This manager does not print AGENT_TOKEN, and it does not self-update
from an unverified URL. Use a newer script file to update the manager.
HELP
}

case "${1:---menu}" in
  --menu) show_menu ;;
  --install) install_agent ;;
  --update) update_agent ;;
  --configure) reconfigure_agent ;;
  --status) status_agent ;;
  --restart) restart_agent ;;
  --logs) logs_agent ;;
  --follow-logs) follow_logs ;;
  --sudo) sudo_menu ;;
  --main-relay) show_main_server_guide ;;
  --guide) installation_guide ;;
  --uninstall) uninstall_agent ;;
  --version) printf '%s\n' "$VERSION" ;;
  -h|--help) usage ;;
  *) usage; exit 2 ;;
esac
