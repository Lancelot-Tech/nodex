#!/bin/bash
# Helpers for the qBittorrent WebUI API (api/v2).

# qbt_login <base_url> <user> <password>
# Prints the full "name=value" session cookie pair on success (the cookie
# name varies by version/config, eg "SID" or "QBT_SID_<port>"), returns
# non-zero on failure. Success is 200 (older versions) or 204 (current).
qbt_login() {
    local base_url="$1" user="$2" password="$3"
    local response cookie

    response="$(curl -fsS -i -X POST "${base_url}/api/v2/auth/login" \
        --data-urlencode "username=${user}" --data-urlencode "password=${password}")"

    if ! echo "$response" | grep -qiE "^HTTP/[0-9.]+ (200|204)"; then
        return 1
    fi

    cookie="$(echo "$response" | grep -i '^set-cookie:' | sed -n 's/^[Ss]et-[Cc]ookie: *\([^;]*\);.*/\1/p')"
    if [ -z "$cookie" ]; then
        return 1
    fi

    echo "$cookie"
}

# qbt_set_preferences <base_url> <cookie> <json>
qbt_set_preferences() {
    local base_url="$1" cookie="$2" json="$3"
    curl -fsS -X POST -b "$cookie" \
        --data-urlencode "json=${json}" \
        "${base_url}/api/v2/app/preferences" > /dev/null
}

# qbt_ensure_category <base_url> <cookie> <name> <save_path>
# Idempotent: creates the category if missing, edits its save path otherwise.
qbt_ensure_category() {
    local base_url="$1" cookie="$2" name="$3" save_path="$4"
    local existing

    existing="$(curl -fsS -b "$cookie" "${base_url}/api/v2/torrents/categories" |
        jq -r --arg n "$name" 'has($n)')"

    if [ "$existing" = "true" ]; then
        curl -fsS -X POST -b "$cookie" \
            --data-urlencode "category=${name}" --data-urlencode "savePath=${save_path}" \
            "${base_url}/api/v2/torrents/editCategory" > /dev/null
    else
        curl -fsS -X POST -b "$cookie" \
            --data-urlencode "category=${name}" --data-urlencode "savePath=${save_path}" \
            "${base_url}/api/v2/torrents/createCategory" > /dev/null
    fi
}
