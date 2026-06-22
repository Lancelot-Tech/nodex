#!/bin/bash
# Idempotent helpers to read/write KEY=VALUE pairs in a .env file.
# Usage: source this file, then call env_get/env_set.

# env_get <file> <key> [default]
env_get() {
    local file="$1" key="$2" default="${3:-}"
    if [ -f "$file" ]; then
        local line
        line="$(grep -E "^${key}=" "$file" | tail -n1)"
        if [ -n "$line" ]; then
            echo "${line#${key}=}"
            return 0
        fi
    fi
    echo "$default"
}

# env_set <file> <key> <value>
# Upserts KEY=VALUE: replaces the existing line if present, appends otherwise.
# Creates the file (and parent directory) if it does not exist yet.
env_set() {
    local file="$1" key="$2" value="$3"

    mkdir -p "$(dirname "$file")"
    touch "$file"

    if grep -qE "^${key}=" "$file"; then
        local tmp
        tmp="$(mktemp)"
        awk -v k="$key" -v v="$value" -F= '
            BEGIN { OFS="=" }
            $1 == k { $0 = k "=" v }
            { print }
        ' "$file" > "$tmp"
        mv "$tmp" "$file"
    else
        echo "${key}=${value}" >> "$file"
    fi
}
