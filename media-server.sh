#!/bin/bash

# ============================================================================
# Media Server Management Script
# Manage your homemade Netflix media server
# ============================================================================

set -e

# Display colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/media"

# ============================================================================
# Utility Functions
# ============================================================================

print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

# ============================================================================
# Prerequisites Check
# ============================================================================

check_prerequisites() {
    print_header "Checking Prerequisites"
    
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed"
        exit 1
    fi
    print_success "Docker is installed"
    
    if ! docker compose version &> /dev/null; then
        print_error "Docker Compose is not installed"
        exit 1
    fi
    print_success "Docker Compose is installed"
    
    if ! docker info &> /dev/null; then
        print_error "Docker daemon is not accessible. Are you in the docker group?"
        exit 1
    fi
    print_success "Docker daemon is accessible"
    
    # Check if network exists
    if ! docker network ls | grep -q media-network; then
        print_warning "Network 'media-network' does not exist. Creating..."
        docker network create media-network
        print_success "Network 'media-network' created"
    else
        print_success "Network 'media-network' exists"
    fi
    
    # Check .env file for ProtonVPN
    if [ ! -f "vpn-stack/protonvpn/.env" ]; then
        print_warning "Missing .env file for ProtonVPN"
        print_info "Copy .env.example to vpn-stack/protonvpn/.env and configure your credentials"
    fi
    
    echo ""
}

# ============================================================================
# Service Management Functions
# ============================================================================

start_all() {
    print_header "Starting All Services"

    # Single compose project (media/docker-compose.yml uses "include:" to pull
    # in protonvpn, qbittorrent and jellyfin). Startup order and health gating
    # (protonvpn -> qbittorrent -> flaresolverr -> prowlarr -> everything else)
    # are enforced natively via depends_on/healthcheck, not by sleeps here.
    print_info "Starting full stack (docker compose up -d)..."
    docker compose up -d
    print_success "All services are started!"

    echo ""
    show_urls
}

stop_all() {
    print_header "Stopping All Services"

    docker compose down

    print_success "All services are stopped"
    echo ""
}

restart_all() {
    print_header "Restarting All Services"

    print_info "Stopping services..."
    docker compose down
    print_success "All services stopped"
    echo ""

    print_info "Starting services..."
    docker compose up -d
    print_success "All services started"

    echo ""
    print_success "Restart completed successfully!"
    echo ""
    check_vpn
    show_urls
}

restart_service() {
    local service=$1
    print_header "Restarting $service"
    
    case $service in
        vpn|protonvpn)
            docker compose restart protonvpn
            ;;
        qbittorrent|qbit)
            docker compose restart qbittorrent
            ;;
        jellyfin|radarr|sonarr|lidarr|bazarr|sabnzbd|prowlarr|flaresolverr|homepage|whisparr|portainer)
            docker compose restart $service
            ;;
        *)
            print_error "Unknown service: $service"
            print_info "Available services: vpn, qbittorrent, jellyfin, radarr, sonarr, lidarr, bazarr, sabnzbd, prowlarr, flaresolverr, homepage, whisparr, portainer"
            return 1
            ;;
    esac
    
    print_success "$service restarted"
    echo ""
}

# ============================================================================
# Diagnostics
# ============================================================================

show_status() {
    print_header "Service Status"
    
    echo -e "\n${YELLOW}Docker Containers:${NC}"
    docker ps -a --filter "name=protonvpn" --filter "name=qbittorrent" --filter "name=jellyfin" \
        --filter "name=radarr" --filter "name=sonarr" --filter "name=lidarr" --filter "name=bazarr" --filter "name=sabnzbd" \
        --filter "name=prowlarr" --filter "name=flaresolverr" --filter "name=homepage" --filter "name=whisparr" \
        --filter "name=portainer" \
        --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    
    echo ""
}

show_logs() {
    local service=$1
    local lines=${2:-50}
    
    print_header "Logs for $service (last $lines lines)"
    
    case $service in
        vpn|protonvpn)
            docker logs --tail $lines protonvpn
            ;;
        qbittorrent|qbit)
            docker logs --tail $lines qbittorrent
            ;;
        jellyfin|radarr|sonarr|lidarr|bazarr|sabnzbd|prowlarr|flaresolverr|homepage|whisparr|portainer)
            docker logs --tail $lines $service
            ;;
        *)
            print_error "Unknown service: $service"
            return 1
            ;;
    esac
}

follow_logs() {
    local service=$1
    
    print_header "Following logs for $service (Ctrl+C to quit)"
    
    case $service in
        vpn|protonvpn)
            docker logs -f protonvpn
            ;;
        qbittorrent|qbit)
            docker logs -f qbittorrent
            ;;
        jellyfin|radarr|sonarr|lidarr|bazarr|sabnzbd|prowlarr|flaresolverr|homepage|whisparr|portainer)
            docker logs -f $service
            ;;
        *)
            print_error "Unknown service: $service"
            return 1
            ;;
    esac
}

check_vpn() {
    print_header "VPN Connection Check"
    
    if ! docker ps | grep -q protonvpn; then
        print_error "ProtonVPN container is not running"
        return 1
    fi
    
    print_info "Checking public IP..."
    local vpn_ip=$(docker exec protonvpn wget -qO- ifconfig.me 2>/dev/null || echo "Error")
    
    if [ "$vpn_ip" != "Error" ]; then
        print_success "VPN IP: $vpn_ip"
    else
        print_error "Unable to retrieve VPN IP"
    fi
    
    print_info "Checking gluetun status..."
    docker exec protonvpn wget -qO- http://localhost:8000/v1/openvpn/status 2>/dev/null || print_warning "Gluetun API not accessible"
    
    echo ""
}

show_urls() {
    print_header "Service URLs"
    
    local ip=$(hostname -I | awk '{print $1}')
    
    echo -e "${GREEN}Homepage:${NC}        http://$ip:3000"
    echo -e "${GREEN}Portainer:${NC}       http://$ip:9000"
    echo -e "${GREEN}Jellyfin:${NC}        http://$ip:8096"
    echo -e "${GREEN}qBittorrent:${NC}     http://$ip:49893"
    echo -e "${GREEN}Prowlarr:${NC}        http://$ip:9696"
    echo -e "${GREEN}Radarr:${NC}          http://$ip:7878"
    echo -e "${GREEN}Sonarr:${NC}          http://$ip:8989"
    echo -e "${GREEN}Lidarr:${NC}          http://$ip:8686"
    echo -e "${GREEN}Whisparr:${NC}        http://$ip:6969"
    echo -e "${GREEN}Bazarr:${NC}          http://$ip:6767"
    echo -e "${GREEN}Sabnzbd:${NC}         http://$ip:8080"
    echo -e "${GREEN}FlareSolverr:${NC}    http://$ip:8191"
    
    echo ""
    print_info "Default qBittorrent credentials: admin / adminadmin"
    echo ""
}

diagnostic() {
    print_header "Complete System Diagnostic"
    
    check_prerequisites
    show_status
    check_vpn
    
    print_header "Disk Space Usage"
    df -h /srv/media 2>/dev/null || df -h $HOME 2>/dev/null || print_warning "Unable to check disk space"
    
    echo ""
}

# ============================================================================
# Update Functions
# ============================================================================

update_all() {
    print_header "Updating All Docker Images"
    
    print_info "Stopping services..."
    stop_all
    
    print_info "Downloading new images..."
    docker compose pull
    
    print_info "Restarting services with new images..."
    start_all
    
    print_success "Update complete!"
    echo ""
}

# ============================================================================
# Help Menu
# ============================================================================

show_help() {
    echo -e "${BLUE}Media Server Management Script${NC}"
    echo -e "Manage your homemade Netflix media server"
    echo ""
    echo -e "${YELLOW}Usage:${NC}"
    echo -e "    $0 [command] [options]"
    echo ""
    echo -e "${YELLOW}Commands:${NC}"
    echo -e "    ${GREEN}start${NC}              Start all services"
    echo -e "    ${GREEN}stop${NC}               Stop all services"
    echo -e "    ${GREEN}restart${NC}            Restart all services (safe, respects VPN dependencies)"
    echo -e "    ${GREEN}restart-service${NC}    Restart a specific service"
    echo -e "                         Usage: $0 restart-service <service>"
    echo -e "                         Services: vpn, qbittorrent, jellyfin, radarr, sonarr, lidarr, bazarr,"
    echo -e "                                   sabnzbd, prowlarr, flaresolverr, homepage, whisparr, portainer"
    echo ""
    echo -e "    ${GREEN}status${NC}             Show service status"
    echo -e "    ${GREEN}urls${NC}               Show service access URLs"
    echo -e "    ${GREEN}diagnostic${NC}         Perform a complete diagnostic"
    echo ""
    echo -e "    ${GREEN}logs${NC}               Show logs for a service"
    echo -e "                         Usage: $0 logs <service> [lines]"
    echo -e "    ${GREEN}follow${NC}             Follow logs for a service in real-time"
    echo -e "                         Usage: $0 follow <service>"
    echo ""
    echo -e "    ${GREEN}check-vpn${NC}          Check VPN connection"
    echo -e "    ${GREEN}update${NC}             Update all Docker images"
    echo ""
    echo -e "    ${GREEN}help${NC}               Show this help"
    echo ""
    echo -e "${YELLOW}Examples:${NC}"
    echo -e "    $0 start                        # Start all services"
    echo -e "    $0 restart                      # Safely restart all services"
    echo -e "    $0 restart-service qbittorrent  # Restart qBittorrent"
    echo -e "    $0 logs vpn 100                 # Show last 100 lines of VPN logs"
    echo -e "    $0 follow radarr                # Follow Radarr logs in real-time"
    echo ""
}

# ============================================================================
# Main Entry Point
# ============================================================================

main() {
    if [ $# -eq 0 ]; then
        show_help
        exit 0
    fi
    
    case "$1" in
        start)
            check_prerequisites
            start_all
            ;;
        stop)
            stop_all
            ;;
        restart)
            restart_all
            ;;
        restart-service)
            if [ -z "$2" ]; then
                print_error "Please specify a service"
                print_info "Usage: $0 restart-service <service>"
                exit 1
            fi
            restart_service "$2"
            ;;
        status)
            show_status
            ;;
        urls)
            show_urls
            ;;
        logs)
            if [ -z "$2" ]; then
                print_error "Please specify a service"
                print_info "Usage: $0 logs <service> [lines]"
                exit 1
            fi
            show_logs "$2" "${3:-50}"
            ;;
        follow)
            if [ -z "$2" ]; then
                print_error "Please specify a service"
                print_info "Usage: $0 follow <service>"
                exit 1
            fi
            follow_logs "$2"
            ;;
        check-vpn)
            check_vpn
            ;;
        diagnostic)
            diagnostic
            ;;
        update)
            update_all
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            print_error "Unknown command: $1"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

main "$@"
