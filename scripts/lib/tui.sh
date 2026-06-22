#!/bin/bash
# Thin wrappers around gum (https://github.com/charmbracelet/gum) used by
# scripts/install.sh for a modern, interactive CLI experience.
# Source this file after ensure_gum has been called.

GUM_BIN="${GUM_BIN:-gum}"

# ensure_gum
# Installs gum via the official Charm apt repository if it is not already
# present. This is the only step of the installer that runs before a
# styled UI is available, so it uses plain echo.
ensure_gum() {
    if command -v gum &> /dev/null; then
        return 0
    fi

    echo "Installing gum (CLI interface)..."
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://repo.charm.sh/apt/gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/charm.gpg
    echo "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" | \
        sudo tee /etc/apt/sources.list.d/charm.list > /dev/null
    sudo apt update
    sudo apt install -y gum
}

step_header() {
    clear
    gum style \
        --border normal --margin "1" --padding "1 2" --border-foreground 245 \
        "$1"
}

info() {
    gum style --foreground 67 "  $1"
}

success() {
    gum style --foreground 36 "  [OK] $1"
}

warn() {
    gum style --foreground 178 "  [WARN] $1"
}

fail() {
    gum style --foreground 131 "  [ERROR] $1"
}

spin() {
    local title="$1"
    shift
    gum spin --spinner dot --title "$title" -- "$@"
}

confirm() {
    gum confirm "$1"
}

ask() {
    local prompt="$1" default="${2:-}"
    gum input --placeholder "$prompt" --value "$default"
}

ask_secret() {
    local prompt="$1"
    gum input --password --placeholder "$prompt"
}

choose() {
    local prompt="$1"
    shift
    gum choose --header "$prompt" "$@"
}
