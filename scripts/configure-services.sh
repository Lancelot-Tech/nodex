#!/bin/bash
# ============================================================================
# Post-install service configuration, driven entirely through the REST APIs
# exposed by Radarr/Sonarr/Lidarr/Whisparr, qBittorrent and Prowlarr.
# Replaces the manual steps described in CONFIGURATION.md. Safe to re-run:
# every step checks the current state before changing anything.
# ============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
MEDIA_DIR="$REPO_DIR/media"
APPDATA_DIR="$MEDIA_DIR/docker/appdata"

# shellcheck source=lib/tui.sh
source "$SCRIPT_DIR/lib/tui.sh"
# shellcheck source=lib/arr_api.sh
source "$SCRIPT_DIR/lib/arr_api.sh"
# shellcheck source=lib/qbt_api.sh
source "$SCRIPT_DIR/lib/qbt_api.sh"

ensure_gum

QBT_URL="http://localhost:49893"
PROWLARR_URL="http://localhost:9696"
PROWLARR_API_KEY="$(arr_api_key "$APPDATA_DIR/prowlarr/config.xml")"

# name | port | api_prefix | category_field | category_value | root_path | naming_patch
APPS=(
    "Radarr|7878|/api/v3|movieCategory|radarr|/films|{\"renameMovies\":true,\"standardMovieFormat\":\"{Movie Title} ({Release Year})/{Movie Title} ({Release Year}) - {Quality Title}\",\"movieFolderFormat\":\"{Movie Title} ({Release Year})\"}"
    "Sonarr|8989|/api/v3|tvCategory|sonarr|/series|{\"renameEpisodes\":true,\"standardEpisodeFormat\":\"{Series Title} - S{season:00}E{episode:00} - {Episode Title}\",\"seasonFolderFormat\":\"Season {season:00}\"}"
    "Lidarr|8686|/api/v1|musicCategory|lidarr|/music|{\"renameTracks\":true}"
    "Whisparr|6969|/api/v3|movieCategory|whisparr|/films|{\"renameMovies\":true,\"standardMovieFormat\":\"{Movie Title} ({Release Year})/{Movie Title} ({Release Year}) - {Quality Title}\",\"movieFolderFormat\":\"{Movie Title} ({Release Year})\"}"
)

# ============================================================================
# Step 1: qBittorrent credentials + global download settings
# ============================================================================

step_header "Service configuration (qBittorrent, Radarr/Sonarr/Lidarr/Whisparr, Prowlarr)"

info "Connecting to qBittorrent (${QBT_URL})"
QBT_USER="$(ask "qBittorrent WebUI username" "admin")"
QBT_PASSWORD="$(ask_secret "qBittorrent WebUI password")"

QBT_SID="$(qbt_login "$QBT_URL" "$QBT_USER" "$QBT_PASSWORD")"
if [ -z "$QBT_SID" ]; then
    fail "qBittorrent authentication failed. Check the credentials and re-run."
    exit 1
fi
success "Authenticated with qBittorrent"

qbt_set_preferences "$QBT_URL" "$QBT_SID" '{
    "save_path": "/downloads",
    "temp_path_enabled": true,
    "temp_path": "/downloads/incomplete",
    "use_category_paths_in_manual_mode": true
}'
success "qBittorrent download paths configured"

for category in radarr sonarr lidarr whisparr; do
    qbt_ensure_category "$QBT_URL" "$QBT_SID" "$category" "/downloads/${category}"
done
success "qBittorrent categories configured (radarr/sonarr/lidarr/whisparr)"

# ============================================================================
# Step 2: per-app root folder, naming and qBittorrent download client
# ============================================================================

for entry in "${APPS[@]}"; do
    IFS='|' read -r name port api_prefix category_field category_value root_path naming_patch <<< "$entry"
    lower_name="$(echo "$name" | tr '[:upper:]' '[:lower:]')"
    base_url="http://localhost:${port}"
    api_key="$(arr_api_key "$APPDATA_DIR/${lower_name}/config.xml")"

    if [ -z "$api_key" ]; then
        warn "${name}: could not read the API key (missing config.xml?), step skipped"
        continue
    fi

    info "${name}: waiting for it to become available..."
    if ! arr_wait_ready "$base_url" "$api_key" "$api_prefix" 60; then
        warn "${name} is not reachable on ${base_url}, step skipped"
        continue
    fi

    arr_ensure_rootfolder "$base_url" "$api_key" "$api_prefix" "$root_path"
    arr_patch_naming "$base_url" "$api_key" "$api_prefix" "$naming_patch"
    arr_ensure_qbittorrent_client "$base_url" "$api_key" "$api_prefix" \
        "$category_field" "$category_value" "protonvpn" 49893 "$QBT_USER" "$QBT_PASSWORD"

    success "${name}: root folder ${root_path}, renaming and qBittorrent client configured"
done

# ============================================================================
# Step 3: Prowlarr - FlareSolverr proxy + app sync
# ============================================================================

if [ -z "$PROWLARR_API_KEY" ]; then
    warn "Prowlarr: could not read the API key, step skipped"
else
    info "Prowlarr: waiting for it to become available..."
    if arr_wait_ready "$PROWLARR_URL" "$PROWLARR_API_KEY" "/api/v1" 60; then
        # An indexerproxy with an empty "tags" array applies to NO indexer (not
        # "all indexers" as one might expect). Indexers must carry the same
        # tag as the proxy to be routed through it.
        flaresolverr_tag_id="$(curl -fsS -H "X-Api-Key: ${PROWLARR_API_KEY}" "${PROWLARR_URL}/api/v1/tag" |
            jq -r '.[] | select(.label == "flaresolverr") | .id')"

        if [ -z "$flaresolverr_tag_id" ]; then
            flaresolverr_tag_id="$(curl -fsS -X POST -H "X-Api-Key: ${PROWLARR_API_KEY}" -H "Content-Type: application/json" \
                -d '{"label":"flaresolverr"}' "${PROWLARR_URL}/api/v1/tag" | jq -r '.id')"
        fi

        existing_proxy_id="$(curl -fsS -H "X-Api-Key: ${PROWLARR_API_KEY}" "${PROWLARR_URL}/api/v1/indexerproxy" |
            jq -r 'map(select(.implementation == "FlareSolverr")) | .[0].id // empty')"

        proxy_payload="$(jq -n --argjson tag "$flaresolverr_tag_id" '{
            name: "FlareSolverr",
            implementation: "FlareSolverr",
            implementationName: "FlareSolverr",
            configContract: "FlareSolverrSettings",
            fields: [
                {name: "host", value: "http://localhost:8191/"},
                {name: "requestTimeout", value: 55}
            ],
            tags: [$tag]
        }')"

        if [ -n "$existing_proxy_id" ]; then
            proxy_payload="$(echo "$proxy_payload" | jq --argjson id "$existing_proxy_id" '. + {id: $id}')"
            curl -fsS -X PUT -H "X-Api-Key: ${PROWLARR_API_KEY}" -H "Content-Type: application/json" \
                -d "$proxy_payload" "${PROWLARR_URL}/api/v1/indexerproxy/${existing_proxy_id}" > /dev/null
            success "Prowlarr: FlareSolverr proxy already configured ('flaresolverr' tag verified)"
        else
            curl -fsS -X POST -H "X-Api-Key: ${PROWLARR_API_KEY}" -H "Content-Type: application/json" \
                -d "$proxy_payload" "${PROWLARR_URL}/api/v1/indexerproxy" > /dev/null
            success "Prowlarr: FlareSolverr proxy added with the 'flaresolverr' tag"
        fi

        for entry in "${APPS[@]}"; do
            IFS='|' read -r name port _ _ _ _ _ <<< "$entry"
            lower_name="$(echo "$name" | tr '[:upper:]' '[:lower:]')"
            app_api_key="$(arr_api_key "$APPDATA_DIR/${lower_name}/config.xml")"

            if [ -z "$app_api_key" ]; then
                continue
            fi

            payload="$(jq -n \
                --arg name "$name" --arg impl "$name" --arg contract "${name}Settings" \
                --arg prowlarrUrl "http://protonvpn:9696" \
                --arg baseUrl "http://${lower_name}:${port}" \
                --arg apiKey "$app_api_key" '{
                name: $name,
                implementation: $impl,
                implementationName: $impl,
                configContract: $contract,
                syncLevel: "fullSync",
                fields: [
                    {name: "prowlarrUrl", value: $prowlarrUrl},
                    {name: "baseUrl", value: $baseUrl},
                    {name: "apiKey", value: $apiKey}
                ],
                tags: []
            }')"

            existing_id="$(curl -fsS -H "X-Api-Key: ${PROWLARR_API_KEY}" "${PROWLARR_URL}/api/v1/applications" |
                jq -r --arg n "$name" 'map(select(.name == $n)) | .[0].id // empty')"

            if [ -n "$existing_id" ]; then
                payload="$(echo "$payload" | jq --argjson id "$existing_id" '. + {id: $id}')"
                curl -fsS -X PUT -H "X-Api-Key: ${PROWLARR_API_KEY}" -H "Content-Type: application/json" \
                    -d "$payload" "${PROWLARR_URL}/api/v1/applications/${existing_id}" > /dev/null
            else
                curl -fsS -X POST -H "X-Api-Key: ${PROWLARR_API_KEY}" -H "Content-Type: application/json" \
                    -d "$payload" "${PROWLARR_URL}/api/v1/applications" > /dev/null
            fi
            success "Prowlarr: sync with ${name} configured"
        done
    else
        warn "Prowlarr is not reachable on ${PROWLARR_URL}, step skipped"
    fi
fi

step_header "Configuration complete"
gum style --foreground 250 "Remaining manual steps (require external accounts/credentials):

  - Add your indexers in Prowlarr (Indexers -> Add Indexer)
  - Tag Cloudflare-protected indexers with the 'flaresolverr' tag
  - Add API keys in Homepage if you want the stats widgets

Everything else (root folders, renaming, qBittorrent categories, download
client, Prowlarr -> Radarr/Sonarr/Lidarr/Whisparr sync, FlareSolverr proxy)
is now configured automatically."
