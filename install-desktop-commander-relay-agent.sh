#!/usr/bin/env bash
set -Eeuo pipefail

SERVICE_NAME="desktop-commander-relay-agent"
RELAY_DIR="${RELAY_DIR:-/opt/desktop-commander-relay-agent}"
RELAY_REPO="${RELAY_REPO:-https://github.com/ErfKS/DesktopCommanderRelay.git}"
CONFIG_DIR="/etc/desktop-commander-relay"
ENV_FILE="${CONFIG_DIR}/agent.env"
DEFAULT_RELAY_WS_URL="${RELAY_WS_URL:-wss://mcp-relay.katebsaber.ir/agent}"

info() { printf '\033[1;34m[INFO]\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m[ OK ]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[WARN]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[FAIL]\033[0m %s\n' "$*" >&2; exit 1; }

trap 'die "Installation failed at line $LINENO. Check the output above."' ERR

if [[ "${EUID}" -ne 0 ]]; then
  die "Run this installer as root, for example: sudo bash $0"
fi

source /etc/os-release
case "${ID:-}" in
  ubuntu|debian) ;;
  *)
    case " ${ID_LIKE:-} " in
      *" debian "*) ;;
      *) die "This installer currently supports Ubuntu/Debian systems only." ;;
    esac
    ;;
esac

command -v systemctl >/dev/null 2>&1 || die "systemd is required."

if [[ -n "${RUN_AS_USER:-}" ]]; then
  id "${RUN_AS_USER}" >/dev/null 2>&1 || die "RUN_AS_USER '${RUN_AS_USER}' does not exist."
elif [[ -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]]; then
  RUN_AS_USER="${SUDO_USER}"
else
  RUN_AS_USER="desktop-commander"
  if ! id "${RUN_AS_USER}" >/dev/null 2>&1; then
    info "Creating dedicated system user '${RUN_AS_USER}'..."
    useradd --system --create-home --home-dir "/var/lib/${RUN_AS_USER}" --shell /bin/bash "${RUN_AS_USER}"
  fi
fi

RUN_AS_GROUP="$(id -gn "${RUN_AS_USER}")"

printf '\nDesktop Commander Relay Agent installer\n'
printf '%s\n\n' '----------------------------------------'
printf 'Runtime Linux user: %s\n\n' "${RUN_AS_USER}"

read -r -p "Relay WebSocket URL [${DEFAULT_RELAY_WS_URL}]: " INPUT_RELAY_WS_URL
RELAY_WS_URL="${INPUT_RELAY_WS_URL:-${DEFAULT_RELAY_WS_URL}}"

read -r -s -p "AGENT_TOKEN: " AGENT_TOKEN
printf '\n'
AGENT_TOKEN="${AGENT_TOKEN#AGENT_TOKEN=}"
[[ -n "${AGENT_TOKEN}" ]] || die "AGENT_TOKEN cannot be empty."

read -r -p "Device ID (example: telegram-core): " DEVICE_ID_RAW
[[ -n "${DEVICE_ID_RAW}" ]] || die "Device ID cannot be empty."

DEVICE_ID="$(
  printf '%s' "${DEVICE_ID_RAW}" |
  tr '[:upper:]' '[:lower:]' |
  sed -E 's/[^a-z0-9._-]+/-/g; s/^-+//; s/-+$//'
)"
[[ -n "${DEVICE_ID}" ]] || die "Device ID became empty after normalization."
[[ "${DEVICE_ID}" == "${DEVICE_ID_RAW}" ]] || warn "Device ID normalized to: ${DEVICE_ID}"

read -r -p "Device name [${DEVICE_ID}]: " DEVICE_NAME
DEVICE_NAME="${DEVICE_NAME:-${DEVICE_ID}}"
DEVICE_NAME="${DEVICE_NAME//$'\n'/ }"
DEVICE_NAME="${DEVICE_NAME//$'\r'/ }"

[[ "${RELAY_WS_URL}" =~ ^wss?:// ]] || die "RELAY_WS_URL must start with ws:// or wss://"

info "Installing base packages..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y ca-certificates curl git build-essential

need_node=0
if ! command -v node >/dev/null 2>&1; then
  need_node=1
else
  NODE_MAJOR="$(node -p 'process.versions.node.split(".")[0]' 2>/dev/null || echo 0)"
  (( NODE_MAJOR >= 20 )) || need_node=1
fi

if (( need_node == 1 )); then
  info "Installing Node.js 22..."
  curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
  apt-get install -y nodejs
fi

NODE_BIN="$(command -v node || true)"
NPM_BIN="$(command -v npm || true)"
[[ -n "${NODE_BIN}" && -n "${NPM_BIN}" ]] || die "Node.js/npm installation failed."
NODE_MAJOR="$(node -p 'process.versions.node.split(".")[0]')"
(( NODE_MAJOR >= 20 )) || die "Node.js 20+ is required; found $(node -v)."
ok "Node.js $(node -v), npm $(npm -v)"

info "Installing/updating Desktop Commander globally..."
npm install -g @wonderwhy-er/desktop-commander@latest

DESKTOP_COMMANDER_BIN="$(command -v desktop-commander || true)"
[[ -n "${DESKTOP_COMMANDER_BIN}" ]] || die "desktop-commander was installed but is not on PATH."
ok "Desktop Commander: ${DESKTOP_COMMANDER_BIN}"

info "Installing DesktopCommanderRelay agent into ${RELAY_DIR}..."
if [[ -d "${RELAY_DIR}/.git" ]]; then
  git -C "${RELAY_DIR}" remote set-url origin "${RELAY_REPO}"
  git -C "${RELAY_DIR}" fetch --prune origin
  git -C "${RELAY_DIR}" pull --ff-only
elif [[ -e "${RELAY_DIR}" ]]; then
  die "${RELAY_DIR} exists but is not a git checkout. Move/remove it or set RELAY_DIR."
else
  git clone --depth 1 "${RELAY_REPO}" "${RELAY_DIR}"
fi

cd "${RELAY_DIR}"
npm ci
npm run build
[[ -f "${RELAY_DIR}/dist/agent/index.js" ]] || die "Relay agent build output is missing."

mkdir -p "${CONFIG_DIR}"
chmod 700 "${CONFIG_DIR}"

env_quote() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  printf '"%s"' "${s}"
}

{
  printf 'RELAY_WS_URL=%s\n' "$(env_quote "${RELAY_WS_URL}")"
  printf 'AGENT_TOKEN=%s\n' "$(env_quote "${AGENT_TOKEN}")"
  printf 'DEVICE_ID=%s\n' "$(env_quote "${DEVICE_ID}")"
  printf 'DEVICE_NAME=%s\n' "$(env_quote "${DEVICE_NAME}")"
  printf 'DESKTOP_COMMANDER_COMMAND=%s\n' "$(env_quote "${DESKTOP_COMMANDER_BIN}")"
} > "${ENV_FILE}"

chown root:root "${ENV_FILE}"
chmod 600 "${ENV_FILE}"

SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
cat > "${SERVICE_FILE}" <<EOF
[Unit]
Description=Desktop Commander Relay Agent - ${DEVICE_NAME}
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

chmod 644 "${SERVICE_FILE}"

info "Enabling and starting ${SERVICE_NAME}..."
systemctl daemon-reload
systemctl enable "${SERVICE_NAME}" >/dev/null
systemctl restart "${SERVICE_NAME}"

sleep 3

if systemctl is-active --quiet "${SERVICE_NAME}"; then
  ok "Service is active."
else
  systemctl status "${SERVICE_NAME}" --no-pager -l || true
  journalctl -u "${SERVICE_NAME}" -n 80 --no-pager || true
  die "Service did not start successfully."
fi

printf '\n=== Installation summary ===\n'
printf 'Device ID:       %s\n' "${DEVICE_ID}"
printf 'Device name:     %s\n' "${DEVICE_NAME}"
printf 'Runtime user:    %s\n' "${RUN_AS_USER}"
printf 'Relay directory: %s\n' "${RELAY_DIR}"
printf 'Config file:     %s\n' "${ENV_FILE}"
printf 'Service:         %s.service\n' "${SERVICE_NAME}"
printf 'DC command:      %s\n' "${DESKTOP_COMMANDER_BIN}"

HEALTH_BASE="${RELAY_WS_URL%/agent}"
HEALTH_BASE="${HEALTH_BASE/#wss:\/\//https://}"
HEALTH_BASE="${HEALTH_BASE/#ws:\/\//http://}"

printf '\n'
info "Relay health check: ${HEALTH_BASE}/healthz"
if curl -fsS --max-time 10 "${HEALTH_BASE}/healthz"; then
  printf '\n'
  ok "Relay health endpoint is reachable."
else
  warn "Service is running, but the public health endpoint could not be verified."
fi

printf '\nRecent agent logs:\n'
journalctl -u "${SERVICE_NAME}" -n 25 --no-pager || true

printf '\n'
ok "Installation complete."
printf 'Useful commands:\n'
printf '  systemctl status %s --no-pager -l\n' "${SERVICE_NAME}"
printf '  journalctl -u %s -f\n' "${SERVICE_NAME}"
printf '  systemctl restart %s\n' "${SERVICE_NAME}"
