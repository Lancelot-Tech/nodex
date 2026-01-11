# 🤖 Configuration Automation Guide

This guide explains what can and cannot be automated in the media server setup.

## ⚙️ What CAN Be Automated

### ✅ System Setup
- ✅ Docker installation
- ✅ OpenSSH installation  
- ✅ NoMachine installation
- ✅ System dependencies

**Script**: `./scripts/system-setup.sh`

### ✅ Docker Services
- ✅ Starting/stopping all services
- ✅ Updating Docker images
- ✅ Network creation
- ✅ Volume mounting

**Script**: `./media-server.sh`

## ❌ What CANNOT Be Easily Automated

### Configuration via Web UI (Manual Required)

The following services require **initial configuration through their web interfaces**:

#### 1. **Prowlarr** - Indexer Configuration
- Adding indexers (1337x, YGGtorrent, etc.)
- Configuring FlareSolverr
- Connecting to Radarr/Sonarr/Whisparr
- Setting up tags

**Why**: Indexers require manual selection, credentials, and testing

#### 2. **Radarr/Sonarr/Whisparr** - Media Management
- Adding download clients (qBittorrent)
- Configuring quality profiles
- Setting naming formats
- Retrieving API keys

**Why**: Requires interactive UI decisions and preferences

#### 3. **Jellyfin** - Media Server
- Initial user setup
- Library configuration
- Metadata providers
- Transcoding settings

**Why**: Requires user preferences and media scanning

#### 4. **qBittorrent** - Torrent Client
- Changing default password
- Category configuration
- Download paths

**Why**: Security and personal preferences

## 🔧 Semi-Automated Options

### Using APIs (Advanced)

You can automate some configuration using the *arr APIs, but this requires:

1. **Initial manual setup** to get API keys
2. **Custom scripts** to interact with APIs
3. **Maintenance** when APIs change

Example using curl to add an indexer to Prowlarr:

```bash
API_KEY="your_prowlarr_api_key"
URL="http://192.168.1.17:9696"

curl -X POST "$URL/api/v1/indexer" \
  -H "X-Api-Key: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "1337x",
    "protocol": "torrent",
    "priority": 25,
    "enable": true,
    "tags": [1],
    "fields": [...]
  }'
```

**Complexity**: High - requires understanding of each service's API structure

### Configuration Backup/Restore

A more practical approach is to **backup configurations after initial setup**:

```bash
# Backup all configurations
tar -czf media-server-config-$(date +%Y%m%d).tar.gz \
  media/docker/appdata/prowlarr/config.xml \
  media/docker/appdata/radarr/config.xml \
  media/docker/appdata/sonarr/config.xml \
  media/docker/appdata/whisparr/config.xml \
  media/qbitorrent/qbittorrent/config/qBittorrent/qBittorrent.conf

# Restore configurations
tar -xzf media-server-config-YYYYMMDD.tar.gz
```

## 📝 Recommended Workflow

### First Installation (Manual)
1. Run `./scripts/system-setup.sh` ✅ Automated
2. Run `./media-server.sh start` ✅ Automated  
3. Configure each service via web UI ❌ Manual
4. Test everything works
5. **Backup configurations** ✅ Can be scripted

### After System Reinstall
1. Run `./scripts/system-setup.sh` ✅ Automated
2. **Restore configuration backup** ✅ Automated
3. Run `./media-server.sh start` ✅ Automated
4. Verify services ❌ Manual check

## 🎯 Best Practice: Configuration as Code

While you can't fully automate the initial setup, you can:

1. **Document your settings** in [CONFIGURATION.md](CONFIGURATION.md)
2. **Take screenshots** of important configurations
3. **Export/backup** configurations after setup
4. **Script the restoration** of backed up configs

### Example Backup Script

Create `scripts/backup-configs.sh`:

```bash
#!/bin/bash
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="backups"
BACKUP_FILE="$BACKUP_DIR/media-server-config-$DATE.tar.gz"

mkdir -p $BACKUP_DIR

tar -czf $BACKUP_FILE \
  media/docker/appdata/prowlarr/ \
  media/docker/appdata/radarr/ \
  media/docker/appdata/sonarr/ \
  media/docker/appdata/whisparr/ \
  media/docker/appdata/bazarr/ \
  media/qbitorrent/qbittorrent/config/ \
  --exclude='*/logs/*' \
  --exclude='*/cache/*'

echo "Backup created: $BACKUP_FILE"
```

## 💡 Summary

| Task | Automated? | Tool |
|------|-----------|------|
| System installation | ✅ Yes | `system-setup.sh` |
| Docker services | ✅ Yes | `media-server.sh` |
| Network setup | ✅ Yes | `media-server.sh` |
| Initial web UI config | ❌ No | Manual |
| API keys retrieval | ❌ No | Manual |
| Configuration backup | ✅ Yes | Custom script |
| Configuration restore | ✅ Yes | tar/rsync |

**Bottom line**: Initial configuration requires ~30-60 minutes of manual work, but you can backup everything and restore it in seconds on a fresh install.

---

**Tip**: After your first complete setup, run a backup script and commit the configuration structure (without sensitive data) to your repository for reference.
