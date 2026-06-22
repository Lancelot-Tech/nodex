#!/bin/bash
# ============================================================================
# Media Server Installer
# Interactive, idempotent setup for a fresh machine. Safe to re-run: every
# step checks the current state of the system before doing anything and
# skips what is already configured.
# ============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
MEDIA_DIR="$REPO_DIR/media"

# shellcheck source=lib/tui.sh
source "$SCRIPT_DIR/lib/tui.sh"
# shellcheck source=lib/env_file.sh
source "$SCRIPT_DIR/lib/env_file.sh"
# shellcheck source=lib/mounts.sh
source "$SCRIPT_DIR/lib/mounts.sh"

ENV_FILE="$MEDIA_DIR/.env"
PROTONVPN_ENV_FILE="$MEDIA_DIR/vpn-stack/protonvpn/.env"

if [ "$EUID" -eq 0 ]; then
    echo "Do not run this script as root. Use a regular user with sudo access."
    exit 1
fi

# ============================================================================
# Step 0: bootstrap gum
# ============================================================================

ensure_gum

# ============================================================================
# Step 1: welcome
# ============================================================================

step_header "Media Server Installer"
gum style --foreground 250 \
"This script idempotently configures:

  - Docker, Docker Compose, OpenSSH, Tailscale
  - Permanent mount points for the Films / Series / Music disks
  - ProtonVPN credentials and the shared configuration (media/.env)
  - The Docker network and ordered service startup
  - The initial launch of the full stack

You can re-run this script at any time: anything already configured
will be detected and left untouched."
echo ""
if ! confirm "Continue?"; then
    exit 0
fi

# ============================================================================
# Step 2: system packages
# ============================================================================

step_header "System packages"

if command -v docker &> /dev/null; then
    success "Docker already installed ($(docker --version | cut -d' ' -f3))"
else
    spin "Installing Docker..." bash -c '
        sudo apt update -qq
        sudo apt install -y -qq ca-certificates curl gnupg lsb-release
        sudo install -m 0755 -d /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        sudo chmod a+r /etc/apt/keyrings/docker.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        sudo apt update -qq
        sudo apt install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        sudo usermod -aG docker "$USER"
    '
    success "Docker installed"
    warn "Log out and back in for the docker group membership to take effect"
fi

if docker compose version &> /dev/null; then
    success "Docker Compose available ($(docker compose version --short))"
else
    fail "The Docker Compose plugin was not found"
    exit 1
fi

if command -v sshd &> /dev/null; then
    success "OpenSSH Server already installed"
else
    spin "Installing OpenSSH Server..." sudo apt install -y -qq openssh-server
    sudo systemctl enable --now ssh
    success "OpenSSH Server installed and started"
fi

spin "Installing utilities (curl, jq, git, htop, tree, unzip, rsync)..." \
    sudo apt install -y -qq curl wget git nano htop net-tools tree unzip jq rsync

success "Utilities installed"

info "Raising inotify limits for Docker..."
if ! grep -q "fs.inotify.max_user_watches" /etc/sysctl.conf 2>/dev/null; then
    echo "fs.inotify.max_user_watches=524288" | sudo tee -a /etc/sysctl.conf > /dev/null
    sudo sysctl -p > /dev/null
fi
success "System configuration applied"

# ============================================================================
# Step 3: Tailscale (mandatory)
# ============================================================================

step_header "Tailscale (required)"

gum style --foreground 250 "Tailscale is the chosen solution for remote access to the server.
This step is required for this setup."
echo ""

if ! command -v tailscale &> /dev/null; then
    spin "Installing Tailscale..." bash -c 'curl -fsSL https://tailscale.com/install.sh | sh'
    success "Tailscale installed"
else
    success "Tailscale already installed"
fi

if sudo tailscale status &> /dev/null; then
    success "Tailscale already connected ($(sudo tailscale ip -4 2>/dev/null))"
else
    info "Starting Tailscale authentication. Open the displayed link in a browser"
    info "(signing in with GitHub is available on the Tailscale login page)."
    sudo tailscale up --accept-routes &
    TS_PID=$!

    while ! sudo tailscale status &> /dev/null; do
        sleep 2
        if ! kill -0 "$TS_PID" 2> /dev/null; then
            break
        fi
    done
    wait "$TS_PID" 2> /dev/null

    if sudo tailscale status &> /dev/null; then
        success "Tailscale connected ($(sudo tailscale ip -4 2>/dev/null))"
    else
        fail "Tailscale failed to connect. Re-run this script to try again."
        exit 1
    fi
fi

# ============================================================================
# Step 4: storage wizard (Films / Series / Music)
# ============================================================================

step_header "Storage: Films, Series, Music"

gum style --foreground 250 "Each disk is permanently mounted via /etc/fstab,
under /srv/media/<Name>. This avoids the duplicate-mount issue
(Films1, Series1...) caused by the desktop's automatic mounting."
echo ""

declare -A MOUNT_TARGETS=(
    [Films]="/srv/media/Films"
    [Series]="/srv/media/Series"
    [Music]="/srv/media/Music"
)

for name in Films Series Music; do
    target="${MOUNT_TARGETS[$name]}"

    if mountpoint_configured "$target"; then
        success "$name already mounted on $target"
        continue
    fi

    info "Configuring $name -> $target"
    candidates="$(list_candidate_partitions)"

    if [ -z "$candidates" ]; then
        warn "No available partition found for $name. Connect the disk and re-run this script."
        continue
    fi

    selection="$(echo "$candidates" | choose "Select the partition for $name")"
    if [ -z "$selection" ]; then
        warn "$name skipped (no selection)"
        continue
    fi
    device="$(echo "$selection" | awk '{print $1}')"

    if configure_mount "$name" "$device" "$target"; then
        success "$name mounted on $target"
    else
        fail "Failed to mount $name"
    fi
done

# Offer migration from the old desktop-automount locations, never destructive.
CURRENT_USER="$(id -un)"
offer_migration "/run/media/$CURRENT_USER/Films" "${MOUNT_TARGETS[Films]}"
offer_migration "/run/media/$CURRENT_USER/Séries" "${MOUNT_TARGETS[Series]}"
offer_migration "/run/media/$CURRENT_USER/Music" "${MOUNT_TARGETS[Music]}"

# ============================================================================
# Step 5: media/.env + ProtonVPN credentials
# ============================================================================

step_header "Shared configuration (media/.env)"

CURRENT_PUID="$(id -u)"
CURRENT_PGID="$(id -g)"
CURRENT_TZ="$(timedatectl show -p Timezone --value 2> /dev/null || echo "Europe/Paris")"
CURRENT_DOCKER_GID="$(getent group docker | cut -d: -f3)"

PUID_VAL="$(env_get "$ENV_FILE" PUID "$CURRENT_PUID")"
PGID_VAL="$(env_get "$ENV_FILE" PGID "$CURRENT_PGID")"
TZ_VAL="$(env_get "$ENV_FILE" TZ "$CURRENT_TZ")"
DOCKER_GID_VAL="$(env_get "$ENV_FILE" DOCKER_GID "$CURRENT_DOCKER_GID")"

env_set "$ENV_FILE" PUID "$PUID_VAL"
env_set "$ENV_FILE" PGID "$PGID_VAL"
env_set "$ENV_FILE" TZ "$TZ_VAL"
env_set "$ENV_FILE" DOCKER_GID "$DOCKER_GID_VAL"
env_set "$ENV_FILE" MEDIA_FILMS_PATH "${MOUNT_TARGETS[Films]}"
env_set "$ENV_FILE" MEDIA_SERIES_PATH "${MOUNT_TARGETS[Series]}"
env_set "$ENV_FILE" MEDIA_MUSIC_PATH "${MOUNT_TARGETS[Music]}"

success "media/.env up to date (PUID=$PUID_VAL, PGID=$PGID_VAL, TZ=$TZ_VAL)"

echo ""
EXISTING_VPN_USER="$(env_get "$PROTONVPN_ENV_FILE" USER "")"

if [ -n "$EXISTING_VPN_USER" ]; then
    success "ProtonVPN credentials already configured for $EXISTING_VPN_USER"
    if confirm "Change ProtonVPN credentials?"; then
        EXISTING_VPN_USER=""
    fi
fi

if [ -z "$EXISTING_VPN_USER" ]; then
    info "Get your OpenVPN credentials at https://account.protonvpn.com/account#openvpn"
    info "Append +pmp to your username to enable port forwarding."
    vpn_user="$(ask "ProtonVPN username (with +pmp)")"
    vpn_password="$(ask_secret "ProtonVPN password")"
    env_set "$PROTONVPN_ENV_FILE" USER "$vpn_user"
    env_set "$PROTONVPN_ENV_FILE" PASSWORD "$vpn_password"
    success "ProtonVPN credentials saved"
fi

# ============================================================================
# Step 6: Docker network
# ============================================================================

step_header "Docker network"

if docker network ls --format '{{.Name}}' | grep -qx media-network; then
    success "Network 'media-network' already exists"
else
    docker network create media-network > /dev/null
    success "Network 'media-network' created"
fi

# ============================================================================
# Step 7: systemd unit for ordered boot startup
# ============================================================================

step_header "Startup on boot"

DOCKER_BIN="$(command -v docker)"
UNIT_FILE="/etc/systemd/system/media-server.service"
UNIT_CONTENT="[Unit]
Description=Media server docker stack
Requires=docker.service
After=docker.service network-online.target
Wants=network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=${MEDIA_DIR}
ExecStart=${DOCKER_BIN} compose up -d
ExecStop=${DOCKER_BIN} compose down
TimeoutStartSec=300

[Install]
WantedBy=multi-user.target
"

if [ -f "$UNIT_FILE" ] && [ "$(cat "$UNIT_FILE")" = "$UNIT_CONTENT" ]; then
    success "systemd unit already up to date"
else
    echo "$UNIT_CONTENT" | sudo tee "$UNIT_FILE" > /dev/null
    sudo systemctl daemon-reload
    success "systemd unit installed"
fi

if systemctl is-enabled media-server.service &> /dev/null; then
    success "Startup on boot already enabled"
else
    sudo systemctl enable media-server.service > /dev/null
    success "Startup on boot enabled"
fi

# ============================================================================
# Step 8: first start
# ============================================================================

step_header "Starting services"

wait_healthy() {
    local container="$1" timeout="${2:-90}" elapsed=0 status
    while [ "$elapsed" -lt "$timeout" ]; do
        status="$(docker inspect --format '{{.State.Health.Status}}' "$container" 2> /dev/null || echo "missing")"
        if [ "$status" = "healthy" ]; then
            return 0
        fi
        sleep 3
        elapsed=$((elapsed + 3))
    done
    return 1
}

(cd "$MEDIA_DIR" && spin "Starting the stack (docker compose up -d)..." docker compose up -d)

for container in protonvpn qbittorrent flaresolverr prowlarr; do
    if spin "Waiting for $container to become healthy..." bash -c "$(declare -f wait_healthy); wait_healthy $container 120"; then
        success "$container is healthy"
    else
        fail "$container did not become healthy in time. Check: docker logs $container"
    fi
done

success "Stack started"

# ============================================================================
# Step 9: summary
# ============================================================================

step_header "Installation complete"

IP="$(hostname -I | awk '{print $1}')"
TS_IP="$(sudo tailscale ip -4 2> /dev/null || echo "n/a")"

gum style --foreground 250 "Local access:
  Homepage     http://$IP:3000
  Jellyfin     http://$IP:8096
  qBittorrent  http://$IP:49893
  Prowlarr     http://$IP:9696
  Radarr       http://$IP:7878
  Sonarr       http://$IP:8989
  Lidarr       http://$IP:8686
  Bazarr       http://$IP:6767
  Whisparr     http://$IP:6969
  Sabnzbd      http://$IP:8080
  FlareSolverr http://$IP:8191
  Portainer    http://$IP:9000

Access via Tailscale: http://$TS_IP:<port>

Remaining manual steps: see CONFIGURATION.md
(Prowlarr configuration, download clients, root folders,
and Jellyfin libraries)."

echo ""
success "Installation complete. Re-run this script at any time to adjust the configuration."
