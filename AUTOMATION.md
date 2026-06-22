# Automation Overview

This project automates essentially the entire setup — system packages, storage, the Docker stack, and the per-service configuration (root folders, renaming, download clients, indexer proxy, app sync) that used to require clicking through every web UI by hand.

## What's automated

### `scripts/install.sh` — system and stack bootstrap

- Docker, Docker Compose plugin, OpenSSH server, system utilities
- Tailscale installation and mandatory login
- inotify limits for Docker
- Permanent `/etc/fstab` mount points for Films, Series, Music (independent from desktop auto-mount, which is what caused the old "Films1 / Series1" duplicate-mount issue)
- Shared configuration (`media/.env`: PUID/PGID, timezone, Docker group GID, storage paths)
- ProtonVPN credentials
- The `media-network` Docker network
- A `systemd` unit (`media-server.service`) that brings the stack up automatically, in the right order, on every boot
- The first `docker compose up -d`, with health-check waiting

Idempotent: every step checks current state first and skips what's already done. Safe to re-run after a config change or a partial failure.

### `scripts/configure-services.sh` — application configuration via REST APIs

Once the stack is running, this script talks directly to the REST APIs exposed by Radarr, Sonarr, Lidarr, Whisparr, qBittorrent and Prowlarr — the same APIs their own web UIs use — to apply the configuration described in [CONFIGURATION.md](CONFIGURATION.md):

- qBittorrent: download paths, "use category paths in manual mode", per-app categories
- Radarr/Sonarr/Lidarr/Whisparr: root folder, file renaming, qBittorrent as download client
- Prowlarr: FlareSolverr indexer proxy (tagged `flaresolverr`), full sync to all four *arr apps

It authenticates against each app using the API key already present in its `config.xml` (generated automatically on first boot — no manual step needed to obtain it), and against qBittorrent using the WebUI credentials you provide when the script runs. Like `install.sh`, it's idempotent: it reads current state via `GET` before writing anything via `POST`/`PUT`, so re-running it after you tweak a setting in the UI won't fight you — it just reconciles drift.

Implementation: `scripts/lib/arr_api.sh` (Radarr/Sonarr/Lidarr/Whisparr/Prowlarr REST helpers) and `scripts/lib/qbt_api.sh` (qBittorrent WebUI API helpers).

### `media-server.sh` — day-to-day operations

Starting, stopping, restarting, checking status, tailing logs, and updating images. See [README.md](README.md#management).

## What's still manual, and why

| Task | Why it isn't scripted |
|------|------------------------|
| Adding indexers in Prowlarr | Requires personal choice of trackers and, for private trackers, an external account/credentials |
| Tagging Cloudflare-protected indexers with `flaresolverr` | Tied to which indexers you add above |
| Jellyfin libraries and hardware-acceleration toggle | One-time interactive setup; the GPU device passthrough itself is already in `media/jellyfin/docker-compose-jellyfin.yml` |
| Homepage per-service stat widgets | Optional, cosmetic, and needs you to choose which stats matter to you |
| Quality profiles, indexer scoring, custom formats | Personal preference, not configuration with a single "correct" value to set |

These either need an external account, a personal judgment call, or genuinely interactive UI flow (a quality-profile editor, for instance) — there's no API call that substitutes for "decide what you want."

## Configuration backup

The configuration `configure-services.sh` writes lives in `media/docker/appdata/<service>/`. To snapshot it:

```bash
DATE=$(date +%Y%m%d_%H%M%S)
mkdir -p backups
tar -czf "backups/media-server-config-$DATE.tar.gz" \
  media/docker/appdata/prowlarr/ \
  media/docker/appdata/radarr/ \
  media/docker/appdata/sonarr/ \
  media/docker/appdata/lidarr/ \
  media/docker/appdata/whisparr/ \
  media/docker/appdata/bazarr/ \
  media/vpn-stack/qbittorrent/config/ \
  --exclude='*/logs/*' --exclude='*/cache/*'
```

Restore with `tar -xzf <archive>` from the repo root, then `./media-server.sh restart`.

## Recommended workflow

**First installation**
1. `./scripts/install.sh` — system, storage, Tailscale, Docker stack
2. `./scripts/configure-services.sh` — root folders, renaming, qBittorrent, Prowlarr sync
3. Add indexers in Prowlarr, tag the Cloudflare-protected ones, set up Jellyfin libraries
4. Back up configuration

**After a reinstall**
1. `./scripts/install.sh` — idempotent, skips what's already configured
2. Restore the configuration backup, or re-run `./scripts/configure-services.sh` if starting from scratch
3. Verify services are healthy: `./media-server.sh status`
