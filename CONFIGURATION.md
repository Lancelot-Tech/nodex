# Service Configuration

Most of what used to require manual clicking through each web UI is now handled by `scripts/configure-services.sh`. This document covers what that script does, and the few steps that still require manual input (they need an external account, a personal decision, or interactive UI work that has no API equivalent).

## Run the automated configuration

```bash
./scripts/configure-services.sh
```

Requirements: the stack must already be running (`docker compose up -d` / `./media-server.sh start`), and you'll need your qBittorrent WebUI credentials (the script prompts for them; nothing is persisted to disk).

The script is idempotent — re-run it any time after changing a setting; it only updates what differs from the desired state.

### What it configures automatically

**qBittorrent**
- Default save path (`/downloads`) and incomplete-torrents path (`/downloads/incomplete`)
- "Use category paths in Manual Mode"
- Categories `radarr`, `sonarr`, `lidarr`, `whisparr`, each saving to its own subfolder under `/downloads`

**Radarr / Sonarr / Lidarr / Whisparr**
- Root folder (`/films`, `/series`, `/music`)
- Renaming (movie/episode/track format and folder format)
- qBittorrent as the download client, pointed at the right category, with "Remove Completed Downloads" enabled so files are cleaned up from `/downloads` once imported

**Prowlarr**
- FlareSolverr registered as an indexer proxy, tagged `flaresolverr`
- Application sync to Radarr, Sonarr, Lidarr and Whisparr (full sync, with each app's API key and base URL)

## What still requires manual setup

### 1. Add indexers in Prowlarr

This needs an account/credentials for private trackers and a personal choice of which public trackers to use, so there's no sensible way to script it.

1. Open Prowlarr (`http://SERVER_IP:9696`) → **Indexers → Add Indexer**
2. Pick the trackers you want (e.g. 1337x, YGGtorrent, Uindex)
3. **If the tracker is behind Cloudflare**: add the `flaresolverr` tag in the indexer's **Tags** field, then **Test**. The tag must match exactly — `configure-services.sh` already tagged the FlareSolverr proxy with `flaresolverr`, and an indexer is only routed through the proxy if it carries the same tag (an indexer proxy with an empty tag list applies to **no** indexer, not to all of them — this is a common point of confusion).
4. Some search results returned by meta-search indexers (e.g. Knaben, Uindex) reference I2P-network trackers (hostnames ending in `.i2p`). A "Name does not resolve" error mentioning a `.i2p` host during a test or search is expected and harmless — it just means that one sample result isn't reachable from the regular internet; it's not a DNS or stack misconfiguration.

### 2. Jellyfin: libraries and hardware acceleration

- **Libraries**: Dashboard → Libraries → Add Media Library, pointing at `/films`, `/series`, `/music`.
- **Hardware acceleration**: the compose file already passes through the Intel GPU (`/dev/dri`) so Jellyfin *can* transcode in hardware, but it still needs to be turned on once: Dashboard → Playback → Transcoding → set **Hardware acceleration** to `VAAPI`, and select `/dev/dri/renderD128` as the device. Without this, Jellyfin falls back to software (CPU) transcoding, which is dramatically heavier (one 4K transcode can pin multiple CPU cores).

### 3. Homepage dashboard widgets (optional)

`scripts/configure-services.sh` doesn't touch Homepage. The dashboard already lists every container with live status (via the Docker integration in `media/docker/appdata/homepage/docker.yaml`), but per-service stat widgets (queue size, disk usage, etc.) need each service's API key:

1. Get the API key: in each app, **Settings → General → Security → API Key** (Sabnzbd: **Config → General**; qBittorrent has no API key, it uses your WebUI username/password; Jellyfin: **Dashboard → API Keys → Create New Key**).
2. Add the relevant `widgets:` block to the corresponding entry in `media/docker/appdata/homepage/services.yaml`. See the [Homepage widgets reference](https://gethomepage.dev/widgets/services/) for the field names per service.

## Reference

| Service     | Where the API key lives                                              |
|-------------|------------------------------------------------------------------------|
| Radarr/Sonarr/Lidarr/Whisparr/Prowlarr | `media/docker/appdata/<service>/config.xml` (`<ApiKey>`) |
| Bazarr      | `media/docker/appdata/bazarr/config/config.yaml` (`auth: apikey:`)   |
| qBittorrent | No API key — authenticates with WebUI username/password               |

```bash
# Quick way to read any *arr app's API key from the shell
grep -o "<ApiKey>[^<]*</ApiKey>" media/docker/appdata/radarr/config.xml
```

## Useful commands

```bash
./media-server.sh logs prowlarr          # last 50 lines
./media-server.sh follow radarr          # real-time logs
./media-server.sh restart-service radarr
./media-server.sh status
./media-server.sh urls
```
