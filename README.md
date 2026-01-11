<div align="center">

# 🎬 Homemade Netflix Media Server

**Complete automated media server with VPN protection**

[![Docker](https://img.shields.io/badge/Docker-2496ED?style=for-the-badge&logo=docker&logoColor=white)](https://www.docker.com/)
[![Jellyfin](https://img.shields.io/badge/Jellyfin-00A4DC?style=for-the-badge&logo=jellyfin&logoColor=white)](https://jellyfin.org/)
[![ProtonVPN](https://img.shields.io/badge/ProtonVPN-56B366?style=for-the-badge&logo=protonvpn&logoColor=white)](https://protonvpn.com/)
[![Linux](https://img.shields.io/badge/Linux-FCC624?style=for-the-badge&logo=linux&logoColor=black)](https://www.linux.org/)

**[🚀 Quick Start](#-quick-start)** • **[📖 Configuration](CONFIGURATION.md)** • **[🔧 Troubleshooting](#-troubleshooting)**

<img src="https://img.shields.io/badge/11_Services-Running-success?style=flat-square" alt="Services" />
<img src="https://img.shields.io/badge/VPN-Protected-blue?style=flat-square" alt="VPN" />
<img src="https://img.shields.io/badge/Automated-Management-orange?style=flat-square" alt="Automated" />

</div>

---

## 📋 Table of Contents

- [Overview](#-overview)
- [Prerequisites](#-prerequisites)
- [Quick Start](#-quick-start)
- [Services](#-services)
- [Configuration](#-configuration)
- [Management](#-management)
- [Remote Access (iOS/Android)](#-remote-access-iosandroid)
- [Architecture](#️-architecture)
- [Troubleshooting](#-troubleshooting)
- [Resources](#-resources)

## 🎯 Overview

<div align="center">

### 🌟 A complete personal Netflix alternative with automation and VPN protection

</div>

This project provides a **fully automated media server infrastructure** with:

<table>
<tr>
<td width="50%">

**📺 Media Management**
- 🎬 **Jellyfin** - Stream movies & TV shows
- 🎥 **Radarr** - Auto movie management
- 📺 **Sonarr** - Auto TV show management
- 🔞 **Whisparr** - Adult content manager
- 💬 **Bazarr** - Auto subtitle download

</td>
<td width="50%">

**⚡ Download & Tools**
- 🔒 **qBittorrent** + VPN protection
- 🔍 **Prowlarr** - Indexer manager
- 📰 **Sabnzbd** - Usenet client
- 🛡️ **FlareSolverr** - Cloudflare bypass
- 🏠 **Homepage** - Unified dashboard
- 🐳 **Portainer** - Docker management

</td>
</tr>
</table>

**[⬆️ Back to top](#-homemade-netflix-media-server)**

---

## ✅ Prerequisites

<table>
<tr>
<td>

### 💻 System Requirements

- 🐧 **OS**: Linux (Debian/Ubuntu recommended)
- 🐳 **Docker**: Docker + Docker Compose
- 🔐 **VPN**: ProtonVPN account ([Get one here](https://protonvpn.com/))
- 💾 **Storage**: Sufficient disk space for media

</td>
<td>

### ⚡ One-Click Setup

```bash
./scripts/system-setup.sh
```

**Installs:**
- ✅ Docker & Docker Compose
- ✅ OpenSSH Server
- ✅ NoMachine (remote desktop)
- ✅ All dependencies

</td>
</tr>
</table>

**[⬆️ Back to top](#-homemade-netflix-media-server)**

---

## 🚀 Quick Start

> **⏱️ Setup Time**: ~10 minutes • **Difficulty**: Easy

### 1️⃣ Clone and Configure

```bash
git clone <your-repo>
cd netflix
```

### 2️⃣ Configure ProtonVPN

```bash
cp media/qbitorrent/protonvpn/.env.example media/qbitorrent/protonvpn/.env
nano media/qbitorrent/protonvpn/.env
```

<div align="center">

📝 **Get your credentials**: [ProtonVPN OpenVPN Settings](https://account.protonvpn.com/account#openvpn)

</div>

```env
USER=your_username+pmp
PASSWORD=your_password
```

> ⚠️ **Important**: Add `+pmp` after your username to enable port forwarding

### 3️⃣ Create Docker Network

```bash
docker network create media-network
```

### 4️⃣ Start All Services

```bash
./media-server.sh start
```

<div align="center">

⏳ **Starting services...** VPN connection takes ~10 seconds

</div>

### 5️⃣ Access Services

```bash
./media-server.sh urls
```

<div align="center">

🎉 **Success!** Your media server is now running!

**Next**: [📖 Configure your services](CONFIGURATION.md)

</div>

**[⬆️ Back to top](#-homemade-netflix-media-server)**

---

## 🎬 Services

<div align="center">

### All services accessible via web browser 🌐

</div>

| Service | Port | URL | Description |
|:--------|:----:|:----|:------------|
| Homepage | 3000 | http://SERVER_IP:3000 | Dashboard |
| Portainer | 9000 | http://SERVER_IP:9000 | Docker UI |
| Jellyfin | 8096 | http://SERVER_IP:8096 | Media Server |
| qBittorrent | 49893 | http://SERVER_IP:49893 | Torrent Client |
| Prowlarr | 9696 | http://SERVER_IP:9696 | Indexer Manager |
| Radarr | 7878 | http://SERVER_IP:7878 | Movies |
| Sonarr | 8989 | http://SERVER_IP:8989 | TV Shows |
| Whisparr | 6969 | http://SERVER_IP:6969 | Adult Content |
| Bazarr | 6767 | http://SERVER_IP:6767 | Subtitles |
| Sabnzbd | 8080 | http://SERVER_IP:8080 | Usenet |
| FlareSolverr | 8191 | http://SERVER_IP:8191 | Cloudflare Proxy |

### 🔐 Default Credentials

<div align="center">

| Service | Username | Password | Action |
|:--------|:---------|:---------|:-------|
| qBittorrent | `admin` | `adminadmin` (default) | ⚠️ **CHANGE IMMEDIATELY** |
| Portainer | - | - | Set on first access |

</div>

**[⬆️ Back to top](#-homemade-netflix-media-server)**

---

## ⚙️ Configuration

### Manual Configuration Required

Initial setup of Radarr/Sonarr/Prowlarr/Whisparr **must be done through their web interfaces**. 

**[📖 Complete Configuration Guide](CONFIGURATION.md)**

#### Quick Configuration Steps:

**1. Prowlarr** (http://SERVER_IP:9696)
- Add FlareSolverr: `http://localhost:8191` with tag `cloudflare`
- Add indexers with tag `cloudflare` if Cloudflare protected
- Settings → Apps → Add Radarr/Sonarr/Whisparr

**2. Radarr/Sonarr/Whisparr**
- Get API keys: Settings → General → Security → API Key
- Add qBittorrent: Host `SERVER_IP:49893`, Enable "Remove Completed"
- Configure root folders: `/films` or `/series`

**3. Connect to Prowlarr**
- Prowlarr Server: `http://SERVER_IP:9696`
- Radarr Server: `http://radarr:7878` + API Key
- Sonarr Server: `http://sonarr:8989` + API Key

**4. Jellyfin**
- Add libraries: `/films` and `/series`

**[⬆️ Back to top](#-homemade-netflix-media-server)**

---

## 🎮 Management

<details>
<summary><b>🚀 Service Control</b></summary>

```bash
./media-server.sh start                    # Start all services
./media-server.sh stop                     # Stop all services
./media-server.sh restart                  # Restart all services
./media-server.sh restart-service radarr   # Restart specific service
```

</details>

<details>
<summary><b>📊 Status & Diagnostics</b></summary>

```bash
./media-server.sh status        # Show all service status
./media-server.sh diagnostic    # Complete system diagnostic
./media-server.sh check-vpn     # Verify VPN connection
./media-server.sh urls          # Display all service URLs
```

</details>

<details>
<summary><b>📝 Logs</b></summary>

```bash
./media-server.sh logs radarr          # Last 50 lines
./media-server.sh logs vpn 100         # Last 100 lines
./media-server.sh follow prowlarr      # Real-time logs (Ctrl+C to exit)
```

</details>

<details>
<summary><b>🔄 Updates</b></summary>

```bash
./media-server.sh update        # Update all Docker images
./media-server.sh help          # Show all available commands
```

</details>

**[⬆️ Back to top](#-homemade-netflix-media-server)**

---

## 📱 Remote Access (iOS/Android)

Access your media server from anywhere using VPN and mobile apps.

### 🔐 Step 1: Setup VPN Access

To securely access your server from outside your home network, use a VPN solution:

#### Option A: Tailscale (Recommended - Easy)

**Install on your server:**
```bash
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up
```

**Install on mobile:**
- iOS: [Tailscale App Store](https://apps.apple.com/app/tailscale/id1470499037)
- Android: [Tailscale Play Store](https://play.google.com/store/apps/details?id=com.tailscale.ipn)

**Benefits:**
- ✅ Zero configuration
- ✅ Automatic NAT traversal
- ✅ Free for personal use (up to 100 devices)
- ✅ Works everywhere

#### Option B: WireGuard (Advanced)

**Install on your server:**
```bash
sudo apt install wireguard
# Configuration required - see WireGuard documentation
```

**Benefits:**
- ✅ Self-hosted (no third party)
- ✅ Very fast
- ✅ Port forwarding required

### 📺 Step 2: Mobile Apps

#### Jellyfin - Media Streaming

**iOS:**
- [Jellyfin App Store](https://apps.apple.com/app/jellyfin-mobile/id1480192618)
- Alternative: [Swiftfin](https://apps.apple.com/app/swiftfin/id1604098728) (Native SwiftUI)

**Android:**
- [Jellyfin Play Store](https://play.google.com/store/apps/details?id=org.jellyfin.mobile)

**Configuration:**
1. Open Jellyfin app
2. Add Server
3. Enter your Tailscale IP: `http://100.x.x.x:8096`
4. Or your server's local IP if on same network: `http://SERVER_IP:8096`
5. Login with your Jellyfin credentials

#### LunaSea - *arr Management Dashboard

**Manage Radarr, Sonarr, Prowlarr from your phone:**

- iOS: [LunaSea App Store](https://apps.apple.com/app/lunasea/id1496797802)
- Android: [LunaSea Play Store](https://play.google.com/store/apps/details?id=app.lunasea.lunasea)

**Configuration:**
1. Open LunaSea
2. Add services (Radarr, Sonarr, etc.)
3. Host: Your Tailscale IP or local IP
4. API Keys: Get from each service (Settings → General → API Key)

#### nzb360 - Alternative (Android Only)

- Android: [nzb360 Play Store](https://play.google.com/store/apps/details?id=com.kevinforeman.nzb360)
- Paid app (~$5) but very polished

### 🌐 Step 3: Access URLs

**On Tailscale network:**
```
Jellyfin:    http://100.x.x.x:8096
Radarr:      http://100.x.x.x:7878
Sonarr:      http://100.x.x.x:8989
Prowlarr:    http://100.x.x.x:9696
Homepage:    http://100.x.x.x:3000
```

**Find your Tailscale IP:**
```bash
tailscale ip -4
```

### 🔒 Security Tips

- ✅ Use Tailscale/WireGuard - never expose ports directly to internet
- ✅ Change default passwords (qBittorrent!)
- ✅ Enable authentication in all services
- ✅ Keep your server updated: `./media-server.sh update`
- ❌ Don't use port forwarding for media services (security risk)

### 📖 Recommended Setup

1. **Install Tailscale** on server and all devices
2. **Install Jellyfin app** on phone/tablet for streaming
3. **Install LunaSea** for managing downloads on-the-go
4. **Add movies/shows** from anywhere!

**[⬆️ Back to top](#-homemade-netflix-media-server)**

---

## 🏗️ Architecture

<div align="center">

```mermaid
graph TD
    A[User] -->|Browse| B[Jellyfin]
    A -->|Configure| C[Homepage Dashboard]
    C --> D[Radarr]
    C --> E[Sonarr]
    C --> F[Prowlarr]
    D -->|Download| G[qBittorrent]
    E -->|Download| G
    F -->|Search| H[Indexers]
    G -->|Protected by| I[ProtonVPN]
    F -->|Protected by| I
    G -->|Save to| J[/films or /series]
    B -->|Stream from| J
```

</div>

### 🔒 VPN Protection

Services using VPN (`network_mode: "container:protonvpn"`):
- ✅ qBittorrent - All torrent traffic protected
- ✅ Prowlarr - All indexer searches protected
- ✅ FlareSolverr - Cloudflare bypass protected

**Benefits:**

<table>
<tr>
<td>🛡️</td>
<td><b>Protected IP</b><br/>All torrent traffic hidden</td>
<td>⚡</td>
<td><b>Kill Switch</b><br/>Auto-disconnect if VPN fails</td>
<td>🌍</td>
<td><b>Geo-Unlock</b><br/>Access blocked content</td>
</tr>
</table>

### Volume Mappings & Workflow

```
1. qBittorrent downloads → /downloads/radarr or /downloads/sonarr
2. Radarr/Sonarr imports → /films or /series
3. Files in /downloads automatically removed after import ✅
```

**Media paths:**
- `/media/$USER/Films` → `/films`
- `/media/$USER/Séries` → `/series`
- `/home/$USER/Documents` → `/downloads` (temporary)

**[⬆️ Back to top](#-homemade-netflix-media-server)**

---

## 🔧 Troubleshooting

### VPN Issues
```bash
./media-server.sh check-vpn
./media-server.sh logs vpn
```

### Service Down After VPN Restart
```bash
./media-server.sh restart
```

Or manually:
```bash
cd media/qbitorrent/qbittorrent && docker compose down && docker compose up -d
cd ../../ && docker compose down prowlarr flaresolverr && docker compose up -d prowlarr flaresolverr
```

### Permission Issues
```bash
sudo chown -R $USER:$USER /media/$USER/Films /media/$USER/Séries
```

### Network Issues
```bash
docker network create media-network
```

**[⬆️ Back to top](#-homemade-netflix-media-server)**

---

## 📝 File Structure

```
netflix/
├── media-server.sh              # Main management script
├── README.md                    # This file
├── CONFIGURATION.md             # Detailed guide
├── QUICKSTART.md               # Quick start
├── scripts/
│   └── system-setup.sh         # System installation
└── media/
    ├── docker-compose.yml       # Main services
    ├── jellyfin/
    │   └── docker-compose-jellyfin.yml
    └── qbitorrent/
        ├── protonvpn/
        │   ├── docker-compose.yml
        │   └── .env            # ⚠️ Your credentials
        └── qbittorrent/
            └── docker-compose.yml
```

**[⬆️ Back to top](#-homemade-netflix-media-server)**

---

## 🔒 Security

- ✅ Change default passwords
- ✅ Use VPN for torrents
- ✅ Never commit `.env` files
- ✅ Update regularly: `./media-server.sh update`
- ✅ Configure firewall
- ✅ Limit Portainer access

**[⬆️ Back to top](#-homemade-netflix-media-server)**

---

## 📚 Resources

- [Prowlarr Wiki](https://wiki.servarr.com/prowlarr)
- [Radarr Wiki](https://wiki.servarr.com/radarr)
- [Sonarr Wiki](https://wiki.servarr.com/sonarr)
- [Jellyfin Docs](https://jellyfin.org/docs/)
- [TRaSH Guides](https://trash-guides.info/)

---

<div align="center">

## 🎉 Happy Streaming!

**Made with ❤️ for the self-hosting community**

[![Docker](https://img.shields.io/badge/Powered_by-Docker-2496ED?style=flat-square&logo=docker)](https://www.docker.com/)
[![VPN](https://img.shields.io/badge/Protected_by-ProtonVPN-56B366?style=flat-square&logo=protonvpn)](https://protonvpn.com/)

**[⬆️ Back to Top](#-homemade-netflix-media-server)**

🍿 **Enjoy your movies and shows!**

</div>
