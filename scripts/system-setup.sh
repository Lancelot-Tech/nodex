#!/bin/bash

# ============================================================================
# System Setup Script for Media Server
# For Debian/Ubuntu systems
# ============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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
# Check if running as root
# ============================================================================

if [ "$EUID" -eq 0 ]; then
    print_error "Please do not run this script as root. Run as normal user with sudo privileges."
    exit 1
fi

print_header "Media Server System Setup"
echo ""
print_info "This script will install:"
echo "  - Docker & Docker Compose"
echo "  - OpenSSH Server"
echo "  - NoMachine (Remote Desktop)"
echo "  - System dependencies"
echo ""
read -p "Continue? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 0
fi

# ============================================================================
# Update system
# ============================================================================

print_header "Updating system packages"
sudo apt update
sudo apt upgrade -y
print_success "System updated"
echo ""

# ============================================================================
# Install Docker
# ============================================================================

print_header "Installing Docker"

if command -v docker &> /dev/null; then
    print_warning "Docker already installed"
    docker --version
else
    # Install Docker
    sudo apt install -y ca-certificates curl gnupg lsb-release
    
    # Add Docker's official GPG key
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg
    
    # Set up the repository
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
      sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Install Docker Engine
    sudo apt update
    sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    # Add user to docker group
    sudo usermod -aG docker $USER
    
    print_success "Docker installed"
    print_warning "You need to log out and log back in for group changes to take effect"
fi

echo ""

# ============================================================================
# Verify Docker Compose
# ============================================================================

print_header "Verifying Docker Compose"

if docker compose version &> /dev/null; then
    print_success "Docker Compose is available"
    docker compose version
else
    print_error "Docker Compose plugin not found"
    exit 1
fi

echo ""

# ============================================================================
# Install OpenSSH Server
# ============================================================================

print_header "Installing OpenSSH Server"

if command -v sshd &> /dev/null; then
    print_warning "OpenSSH Server already installed"
else
    sudo apt install -y openssh-server
    sudo systemctl enable ssh
    sudo systemctl start ssh
    print_success "OpenSSH Server installed and started"
fi

# Get IP address for SSH info
IP=$(hostname -I | awk '{print $1}')
print_info "SSH access: ssh $USER@$IP"

echo ""

# ============================================================================
# Install NoMachine
# ============================================================================

print_header "Installing NoMachine"

if command -v /usr/NX/bin/nxserver &> /dev/null; then
    print_warning "NoMachine already installed"
else
    # Download NoMachine
    NOMACHINE_VERSION="8.14.2_1"
    NOMACHINE_DEB="nomachine_${NOMACHINE_VERSION}_amd64.deb"
    
    print_info "Downloading NoMachine..."
    cd /tmp
    wget -q "https://download.nomachine.com/download/${NOMACHINE_VERSION}/Linux/${NOMACHINE_DEB}"
    
    # Install NoMachine
    sudo dpkg -i "$NOMACHINE_DEB" || sudo apt-get install -f -y
    
    # Clean up
    rm "$NOMACHINE_DEB"
    
    print_success "NoMachine installed"
    print_info "NoMachine server runs on port 4000"
    print_info "Download client from: https://www.nomachine.com/download"
fi

echo ""

# ============================================================================
# Install additional utilities
# ============================================================================

print_header "Installing additional utilities"

sudo apt install -y \
    curl \
    wget \
    git \
    nano \
    htop \
    net-tools \
    tree \
    unzip

print_success "Utilities installed"
echo ""

# ============================================================================
# System configuration
# ============================================================================

print_header "System Configuration"

# Increase inotify limits for file watching
print_info "Increasing inotify limits for Docker..."
echo "fs.inotify.max_user_watches=524288" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

print_success "System configured"
echo ""

# ============================================================================
# Summary
# ============================================================================

print_header "Installation Complete!"

echo ""
echo -e "${GREEN}Installed:${NC}"
echo "  ✓ Docker $(docker --version | cut -d' ' -f3)"
echo "  ✓ Docker Compose $(docker compose version --short)"
echo "  ✓ OpenSSH Server"
echo "  ✓ NoMachine"
echo "  ✓ System utilities"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "  1. Log out and log back in (for Docker group)"
echo "  2. Configure ProtonVPN credentials"
echo "  3. Run: ./media-server.sh start"
echo ""
echo -e "${BLUE}Access Information:${NC}"
echo "  SSH:       ssh $USER@$IP"
echo "  NoMachine: nx://$IP:4000"
echo ""
print_warning "IMPORTANT: You MUST log out and log back in for Docker permissions to work!"
echo ""
