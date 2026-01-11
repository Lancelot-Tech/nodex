# 🎯 Prowlarr, FlareSolverr and Homepage Configuration

Configuration guide for the newly added services.

## � Root Folder Configuration (Required First Step)

Before adding any movies or TV shows, you **must** configure Root Folders in Radarr, Sonarr, and Whisparr.

### Radarr - Movies Root Folder

1. **Access Radarr**: http://SERVER_IP:7878
2. **Go to**: Settings → Media Management
3. **Click**: "Add Root Folder"
4. **Enter path**: `/films`
   - This is the path inside the Docker container
   - Maps to `/media/$USER/Films` on your host system
5. **Save**: Click the ✓ (check mark)

**Configure Movie Naming** (Recommended):
- ✅ Enable "Rename Movies"
- **Standard Movie Format**: `{Movie Title} ({Release Year})/{Movie Title} ({Release Year}) - {Quality Title}`
- Or simpler: `{Movie Title} ({Release Year})/{Movie Title} ({Release Year})`
- **Movie Folder Format**: `{Movie Title} ({Release Year})`
- This creates clean names like: `The Matrix (1999)/The Matrix (1999).mkv`
- ⚠️ **Important**: Renaming is required for automatic cleanup to work properly!

### Sonarr - TV Shows Root Folder

1. **Access Sonarr**: http://SERVER_IP:8989
2. **Go to**: Settings → Media Management
3. **Click**: "Add Root Folder"
4. **Enter path**: `/series`
   - Maps to `/media/$USER/Séries` on your host system
5. **Save**: Click the ✓ (check mark)

**Optional - Enable Season Folders**:
- In the same Media Management section
- Enable "Season Folders"
- Set "Season Folder Format" to: `Season {season:00}`
- This creates folders like "Season 01", "Season 02", etc.

**Configure Season/Episode Naming** (Recommended):
- ✅ Enable "Rename Episodes"
- **Standard Episode Format**: `{Series Title} - S{season:00}E{episode:00} - {Episode Title}`
- **Season Folder Format**: `Season {season:00}`
- This creates clean names like: `Breaking Bad - S01E01 - Pilot.mkv`

### Whisparr - Adult Content Root Folder

1. **Access Whisparr**: http://SERVER_IP:6969
2. **Go to**: Settings → Media Management
3. **Click**: "Add Root Folder"
4. **Enter path**: `/films` (or create a separate directory if preferred)
5. **Save**: Click the ✓ (check mark)

---
## 🔧 qBittorrent - Download Client Setup

**CRITICAL FIRST STEP** - Configure qBittorrent before adding any downloads.

### 1. Configure Category Paths

1. **Access qBittorrent**: http://SERVER_IP:49893
2. **Login**: `admin` / `adminadmin` (default - change this!)
3. **Options (gear icon) → Downloads**
4. **Important settings**:
   - Default Save Path: `/downloads`
   - ✅ **Use Category paths in Manual Mode** ← **MUST BE ENABLED**
   - Keep incomplete torrents in: `/downloads/incomplete`

5. **Save and close Options**

### 2. Create Categories

**Right-click in the Categories sidebar → Add category**

**For Radarr (Movies)**:
```
Category: radarr
Save path: /downloads/radarr
```

**For Sonarr (TV Shows)**:
```
Category: sonarr  
Save path: /downloads/sonarr
```

**Verification**: Click on a category and verify the save path appears at the bottom of qBittorrent.

---

## 🎨 Radarr & Sonarr - File Naming Configuration

### Why Enable Renaming?

Without renaming enabled:
- ❌ Files keep torrent names: `Movie.Title.2020.1080p.BluRay.x264-GROUP.mkv`
- ❌ Automatic cleanup doesn't work properly
- ❌ Jellyfin has trouble identifying media
- ❌ Files remain in `/downloads/` after import

With renaming enabled:
- ✅ Clean, organized names: `Movie Title (2020).mkv`
- ✅ Automatic cleanup works perfectly
- ✅ Jellyfin identifies everything instantly
- ✅ Files properly removed from `/downloads/`

### Radarr - Movie Naming

**Settings → Media Management → Movie Naming**

```
✅ Rename Movies

Standard Movie Format:
{Movie Title} ({Release Year})/{Movie Title} ({Release Year}) - {Quality Title}

Movie Folder Format:
{Movie Title} ({Release Year})
```

**Example Result**:
```
/films/The Matrix (1999)/
       The Matrix (1999) - Bluray-1080p.mkv
```

**Simpler Format** (if you don't need quality info):
```
Standard Movie Format:
{Movie Title} ({Release Year})/{Movie Title} ({Release Year})
```

### Sonarr - Series Naming

**Settings → Media Management → Episode Naming**

```
✅ Rename Episodes

Standard Episode Format:
{Series Title} - S{season:00}E{episode:00} - {Episode Title}

Daily Episode Format:
{Series Title} - {Air-Date} - {Episode Title}

Season Folder Format:
Season {season:00}

✅ Season Folders (Enable this!)
```

**Example Result**:
```
/series/Breaking Bad/
       Season 01/
           Breaking Bad - S01E01 - Pilot.mkv
           Breaking Bad - S01E02 - Cat's in the Bag.mkv
       Season 02/
           Breaking Bad - S02E01 - Seven Thirty-Seven.mkv
```

### Apply Naming to Existing Files

If you already imported movies/shows before enabling renaming:

**Radarr**:
1. Movies → Movie Editor (button at top)
2. Select all movies (or specific ones)
3. Click **Organize** → Radarr will rename them

**Sonarr**:
1. Series → Mass Editor
2. Select series
3. **Organize** → Sonarr will rename all episodes

---
## �🔍 Prowlarr - Indexer Manager

Prowlarr centralizes indexer (tracker) management for Radarr and Sonarr.

### Initial Setup

1. **Access Prowlarr**: http://SERVER_IP:9696

2. **Add FlareSolverr** (for trackers with Cloudflare protection)
   - Settings → Indexers → Add FlareSolverr
   - Tags: `flaresolverr`
   - Host: `http://flaresolverr:8191`

3. **Add Indexers**
   - Indexers → Add Indexer
   - Popular examples:
     - YGGtorrent (requires account)
     - 1337x
     - The Pirate Bay
     - RARBG
   - For Cloudflare-protected trackers, add the `flaresolverr` tag

4. **Connect Radarr**
   - Settings → Apps → Add Application → Radarr
   - Sync Level: Full Sync
   - Prowlarr Server: `http://prowlarr:9696`
   - Radarr Server: `http://radarr:7878`
   - API Key: (retrieve from Radarr → Settings → General → API Key)

5. **Connect Sonarr**
   - Settings → Apps → Add Application → Sonarr
   - Sync Level: Full Sync
   - Prowlarr Server: `http://prowlarr:9696`
   - Sonarr Server: `http://sonarr:8989`
   - API Key: (retrieve from Sonarr → Settings → General → API Key)

### Benefits

- ✅ Manage all your indexers in one place
- ✅ Automatic synchronization with Radarr/Sonarr
- ✅ Add an indexer once, it appears everywhere
- ✅ Centralized statistics

## 🔥 FlareSolverr - Cloudflare Proxy

FlareSolverr bypasses Cloudflare protections on certain trackers.

### Configuration

FlareSolverr works automatically in the background. Simply configure it in Prowlarr:

1. In Prowlarr: Settings → Indexers → Add FlareSolverr
2. URL: `http://flaresolverr:8191`
3. Tags: `flaresolverr`
4. Add this tag to indexers that need it

### Testing

API accessible at: http://SERVER_IP:8191

```bash
curl http://localhost:8191/v1
```

## 🏠 Homepage - Dashboard

Homepage is your central dashboard for all your services.

### Access

**URL**: http://SERVER_IP:3000

### Widget Configuration

To display statistics for each service, you need to add API keys:

#### 1. Retrieve API Keys

**Radarr**:
- Radarr → Settings → General → Security → API Key

**Sonarr**:
- Sonarr → Settings → General → Security → API Key

**Prowlarr**:
- Prowlarr → Settings → General → Security → API Key

**Bazarr**:
- Bazarr → Settings → General → Security → API Key

**Sabnzbd**:
- Sabnzbd → Config → General → Security → API Key

**Jellyfin**:
- Dashboard → API Keys → Create New Key

**qBittorrent**:
- Username: `admin`
- Password: your password (default: `adminadmin`)

#### 2. Create a .env file for Homepage (optional)

For better security, create a file with your keys:

```bash
nano ~/media-server/media/docker/appdata/homepage/.env
```

Add:
```env
HOMEPAGE_VAR_HOST_IP=SERVER_IP
HOMEPAGE_VAR_PROWLARR_KEY=your_key
HOMEPAGE_VAR_RADARR_KEY=your_key
HOMEPAGE_VAR_SONARR_KEY=your_key
HOMEPAGE_VAR_BAZARR_KEY=your_key
HOMEPAGE_VAR_SABNZBD_KEY=your_key
HOMEPAGE_VAR_JELLYFIN_KEY=your_key
HOMEPAGE_VAR_QBIT_USER=admin
HOMEPAGE_VAR_QBIT_PASS=your_password
```

Then restart Homepage:
```bash
./media-server.sh restart-service homepage
```

### Customization

Configuration files are in:
`./media/docker/appdata/homepage/`

- `settings.yaml` - General configuration (theme, layout)
- `services.yaml` - Service list
- `widgets.yaml` - System widgets (CPU, RAM, etc.)
- `bookmarks.yaml` - Your bookmarks
3. **Enable Renaming**: Turn on "Rename Movies/Episodes" in Radarr/Sonarr (IMPORTANT!)
4. **Download Clients**: Add qBittorrent in Radarr/Sonarr with category "radarr"/"sonarr" + Enable "Remove Completed"
5. **Prowlarr**: Add your indexers
6. **FlareSolverr**: Configure in Prowlarr
7. **Prowlarr → Radarr/Sonarr**: Synchronize apps
8. **Homepage**: Add API keys for widgets

1. **qBittorrent**: Enable category paths and create radarr/sonarr categories (CRITICAL!)
2. **Root Folders**: Configure `/films` in Radarr and `/series` in Sonarr (REQUIRED!)
3. **Download Clients**: Add qBittorrent in Radarr/Sonarr with category "radarr"/"sonarr"
4. **Prowlarr**: Add your indexers
3. **FlareSolverr**: Configure in Prowlarr
4. **Prowlarr → Radarr/Sonarr**: Synchronize apps
5. **Homepage**: Add API keys for widgets

### Daily Usage

1. **Homepage** (http://SERVER_IP:3000)
   - Overview of your entire system
   - Quick access to all services
   - Resource monitoring

2. **Prowlarr** (http://SERVER_IP:9696)
   - Manual torrent search
   - Indexer management
   - Statistics

3. **Radarr/Sonarr**
   - Add movies/series
   - Indexers are already configured via Prowlarr

## 🔧 Useful Commands

```bash
# View logs
./media-server.sh logs prowlarr
./media-server.sh logs flaresolverr
./media-server.sh logs homepage

# Restart a service
./media-server.sh restart-service prowlarr

# View status
./media-server.sh status

# View all URLs
./media-server.sh urls
```

## 📝 Ports Used

| Service      | Port | URL                      |
|--------------|------|--------------------------|
| Homepage     | 3000 | http://SERVER_IP:3000 |
| Prowlarr     | 9696 | http://SERVER_IP:9696 |
| FlareSolverr | 8191 | http://SERVER_IP:8191 |

## 🎯 Next Steps

1. Configure Prowlarr with your favorite trackers
2. Synchronize with Radarr/Sonarr
3. Customize Homepage with your API keys
4. Enjoy your unified dashboard!

---

**Happy monitoring! 📊**
