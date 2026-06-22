#!/bin/bash
# Generic REST helpers for the Servarr family (Radarr/Sonarr/Lidarr/Whisparr).
# All of them expose the same kind of API (v3, except Lidarr which is v1),
# authenticated with a per-instance API key stored in plain text in their
# config.xml, readable straight from the bind-mounted appdata volume.

# arr_api_key <config_xml_path>
arr_api_key() {
    local config_xml="$1"
    grep -o "<ApiKey>[^<]*</ApiKey>" "$config_xml" 2>/dev/null | sed -e 's/<ApiKey>//' -e 's/<\/ApiKey>//'
}

# arr_wait_ready <base_url> <api_key> <api_path_prefix eg /api/v3> [timeout_seconds]
arr_wait_ready() {
    local base_url="$1" api_key="$2" api_prefix="$3" timeout="${4:-90}" elapsed=0
    while [ "$elapsed" -lt "$timeout" ]; do
        if curl -fsS -o /dev/null -H "X-Api-Key: ${api_key}" "${base_url}${api_prefix}/system/status"; then
            return 0
        fi
        sleep 3
        elapsed=$((elapsed + 3))
    done
    return 1
}

# arr_ensure_rootfolder <base_url> <api_key> <api_prefix> <path>
# Idempotent: does nothing if a root folder with this exact path already exists.
arr_ensure_rootfolder() {
    local base_url="$1" api_key="$2" api_prefix="$3" path="$4"
    local existing
    existing="$(curl -fsS -H "X-Api-Key: ${api_key}" "${base_url}${api_prefix}/rootfolder" |
        jq -r --arg p "$path" 'map(select(.path == $p)) | length')"

    if [ "$existing" != "0" ]; then
        return 0
    fi

    curl -fsS -X POST -H "X-Api-Key: ${api_key}" -H "Content-Type: application/json" \
        -d "$(jq -n --arg p "$path" '{path: $p}')" \
        "${base_url}${api_prefix}/rootfolder" > /dev/null
}

# arr_patch_naming <base_url> <api_key> <api_prefix> <json_patch>
# json_patch: a JSON object of the fields to overlay onto the current naming config.
arr_patch_naming() {
    local base_url="$1" api_key="$2" api_prefix="$3" patch="$4"
    local current id merged

    current="$(curl -fsS -H "X-Api-Key: ${api_key}" "${base_url}${api_prefix}/config/naming")"
    id="$(echo "$current" | jq -r '.id')"
    merged="$(echo "$current" | jq --argjson p "$patch" '. + $p')"

    curl -fsS -X PUT -H "X-Api-Key: ${api_key}" -H "Content-Type: application/json" \
        -d "$merged" "${base_url}${api_prefix}/config/naming/${id}" > /dev/null
}

# arr_ensure_qbittorrent_client <base_url> <api_key> <api_prefix> <category_field> <category_value>
#                                <qbt_host> <qbt_port> <qbt_user> <qbt_password>
# Idempotent: updates the existing "qBittorrent" download client if one with that
# name exists, creates it otherwise.
arr_ensure_qbittorrent_client() {
    local base_url="$1" api_key="$2" api_prefix="$3" category_field="$4" category_value="$5"
    local qbt_host="$6" qbt_port="$7" qbt_user="$8" qbt_password="$9"

    local fields
    fields="$(jq -n \
        --arg host "$qbt_host" --argjson port "$qbt_port" \
        --arg user "$qbt_user" --arg pass "$qbt_password" \
        --arg catfield "$category_field" --arg catvalue "$category_value" '
        [
            {name: "host", value: $host},
            {name: "port", value: $port},
            {name: "useSsl", value: false},
            {name: "username", value: $user},
            {name: "password", value: $pass},
            {name: $catfield, value: $catvalue},
            {name: "initialState", value: 0}
        ]')"

    local payload
    payload="$(jq -n --argjson fields "$fields" '{
        enable: true,
        protocol: "torrent",
        priority: 1,
        removeCompletedDownloads: true,
        removeFailedDownloads: true,
        name: "qBittorrent",
        implementation: "QBittorrent",
        implementationName: "qBittorrent",
        configContract: "QBittorrentSettings",
        fields: $fields,
        tags: []
    }')"

    local existing_id
    existing_id="$(curl -fsS -H "X-Api-Key: ${api_key}" "${base_url}${api_prefix}/downloadclient" |
        jq -r 'map(select(.implementation == "QBittorrent")) | .[0].id // empty')"

    if [ -n "$existing_id" ]; then
        payload="$(echo "$payload" | jq --argjson id "$existing_id" '. + {id: $id}')"
        curl -fsS -X PUT -H "X-Api-Key: ${api_key}" -H "Content-Type: application/json" \
            -d "$payload" "${base_url}${api_prefix}/downloadclient/${existing_id}" > /dev/null
    else
        curl -fsS -X POST -H "X-Api-Key: ${api_key}" -H "Content-Type: application/json" \
            -d "$payload" "${base_url}${api_prefix}/downloadclient" > /dev/null
    fi
}
