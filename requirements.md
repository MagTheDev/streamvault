# StreamVault - Personal Video Archive
## Learning-Focused Requirements Document

## Project Overview
A personal media streaming server with adaptive bitrate streaming and encryption capabilities for archiving family videos and personal content. **Primary goal: Learn Elixir/Phoenix while building a real system.**

**Use Case**: Single-user personal video archive. Store, organize, and stream videos you don't want to lose (family recordings, personal projects, etc.) with secure access from desktop players (mpv, VLC, IINA) and web browsers.

## Technology Stack

### Backend
- **Framework**: Elixir/Phoenix
- **Server**: Cowboy (via Plug)
- **Database**: SQLite3 (via Ecto SQLite3 adapter)
- **Background Jobs**: GenServer-based queue (simple, educational)

### Video Technology
- **Video Codec**: H.264 (libx264)
  - Universal browser support
  - Fast encoding (2-5x realtime)
  - Hardware acceleration everywhere
  - Mature, well-documented
- **Audio Codec**: AAC
  - Universal support (HLS requirement)
  - Excellent quality
  - Native MP4/HLS support
- **Container Format**: MP4
  - Web-friendly
  - Universal playback
- **Streaming Protocol**: HLS (HTTP Live Streaming)
  - Universal support (every browser/device)
  - Native encryption support
  - `.m3u8` manifest files
  - Works with desktop players (mpv, VLC, IINA)

### Video Processing
- **FFmpeg**: Encoding, transcoding, and HLS packaging

### Frontend
- **Video Player**: Video.js (web browser)
- **Desktop Players**: mpv, VLC, IINA (token-based URLs)

## Core Features

### 1. Single-User Authentication
- Simple authentication system (just you)
- Session-based auth for web interface
- Token generation for desktop player access
- No complex user management needed

### 2. Adaptive Bitrate Streaming (ABR)
- Multiple quality levels pre-encoded:
  - **1080p**: 4 Mbps video bitrate, 128 kbps audio
  - **720p**: 2 Mbps video bitrate, 96 kbps audio
  - **480p**: 1 Mbps video bitrate, 64 kbps audio
- Automatic quality switching based on bandwidth
- Segment duration: 4 seconds

### 3. Video Encryption
- **Encryption Method**: AES-128 (HLS native)
- **Key Management**:
  - Unique encryption key per video (16 bytes)
  - Keys stored as plaintext files with restrictive permissions
  - Keys served only to authorized requests (token validation)
- **Segment-level encryption**: Each video segment encrypted by FFmpeg
- **Automatic decryption**: Browser/player handles decryption transparently

**Security Note**: For this learning project, keys are stored as plaintext files with `chmod 600` permissions. This is **not production-ready** but sufficient for learning Elixir's authorization patterns and adequate for a personal single-user system.

### 4. Token-Based Access for Desktop Players
- Generate access tokens for specific videos
- Tokens passed as query parameters in URLs
- Works seamlessly with mpv, VLC, IINA
- Tokens can be permanent or time-limited
- Revocable access (delete token to revoke)

**Token Format:**
```
http://localhost:4000/api/videos/{video_id}/master.m3u8?token={access_token}
```

**Why Tokens:**
- ✅ Simple copy/paste URLs for desktop players
- ✅ No auth headers needed (works out-of-box with mpv/VLC/IINA)
- ✅ Can share video with others temporarily
- ✅ Efficient validation (no password hashing per request)
- ✅ Easy to revoke if compromised

### 5. Background Job Processing
- **GenServer-based encoding queue** - simple, educational, fits single-user use case
- Encoding jobs run in background processes
- Automatic retry on failure (up to 3 attempts)
- Job persistence in SQLite (survives restarts)
- Progress tracking via database status field
- Clean supervision tree

**Why GenServer instead of Oban:**
- ✅ More educational (learn OTP patterns directly)
- ✅ Simpler for single-user case (no complex distributed features needed)
- ✅ SQLite-friendly (no Postgres-specific features)
- ✅ Zero external dependencies
- ✅ Easier to understand and debug
- ✅ Teaches core Elixir/OTP concepts

### 6. Pre-encoding Pipeline
All videos are encoded ahead of time (not on-the-fly):
1. Upload raw video file
2. Create encoding job record in database
3. GenServer worker picks up job
4. Generate unique encryption key (16 random bytes)
5. Encode multiple quality versions with H.264
6. Encrypt all segments with AES-128 (FFmpeg does this)
7. Generate HLS manifests (`.m3u8`)
8. Update job status to complete
9. Store encrypted segments and manifests
10. Clean up temporary files

### 7. Video Metadata & Organization
- Title and description for each video
- Upload date tracking
- Original filename preservation
- Encoding status monitoring (pending, encoding, ready, failed)
- Video duration tracking
- Optional tags/categories for organization

## System Architecture

### File Structure
```
priv/
├── keys/
│   └── {video_id}.key          # 16-byte AES keys (chmod 600)
├── static/
│   └── videos/
│       └── {video_id}/
│           ├── master.m3u8     # Quality level selector
│           ├── 1080p.m3u8      # Segment playlist
│           ├── 1080p_000.ts    # Encrypted segments
│           ├── 1080p_001.ts
│           ├── 720p.m3u8
│           ├── 720p_000.ts
│           └── ...
uploads/
└── {video_id}.mp4              # Original uploads (temp, deleted after encoding)
streamvault.db                  # SQLite database file
```

### Database Schema

**Users Table** (single user):
- id (UUID, primary key)
- username (unique, text)
- email (text)
- password_hash (text)
- created_at (datetime)

**Videos Table**:
- id (UUID, primary key)
- title (text, required)
- description (text, nullable)
- status (text: pending, encoding, ready, failed)
- original_filename (text)
- duration_seconds (integer, nullable)
- file_size_bytes (integer, nullable)
- created_at (datetime)
- updated_at (datetime)

**Encoding Jobs Table**:
- id (UUID, primary key)
- video_id (foreign key to videos)
- status (text: queued, processing, completed, failed)
- attempts (integer, default 0)
- max_attempts (integer, default 3)
- error_message (text, nullable)
- started_at (datetime, nullable)
- completed_at (datetime, nullable)
- created_at (datetime)

**Access Tokens Table**:
- id (UUID, primary key)
- video_id (foreign key to videos)
- token (text, unique, indexed)
- description (text, nullable - e.g., "Living Room TV")
- expires_at (datetime, nullable)
- created_at (datetime)
- last_used_at (datetime, nullable)

**Indexes:**
- `access_tokens.token` (unique, for fast validation)
- `encoding_jobs.status` (for queue processing)
- `videos.status` (for filtering by status)

### SQLite Benefits for This Project

**Perfect Fit:**
- Single user = no concurrent write concerns
- Small database (just metadata, not video files)
- Simple backups (copy `.db` file)
- Zero configuration needed
- Cross-platform (works same on macOS/Linux/Windows)
- Fast for read-heavy workloads (which this is)

**Backup Strategy:**
- Database: Copy `streamvault.db` file
- Can use SQLite's backup API for live backups
- Entire application state in one file

### Background Job System Architecture

**Supervision Tree:**
```
Application
├── Repo (SQLite)
├── Endpoint (Phoenix)
├── EncodingQueue (GenServer)
│   └── Supervised by DynamicSupervisor
└── EncodingWorker (GenServer, pooled)
    ├── Worker 1
    └── Worker 2
```

**Job Processing Flow:**
1. Upload creates job record with status "queued"
2. EncodingQueue GenServer polls database for queued jobs
3. Worker GenServer claims job (updates status to "processing")
4. Worker runs FFmpeg encoding
5. Worker updates job status ("completed" or "failed")
6. On failure: increment attempts, requeue if under max_attempts
7. EncodingQueue polls again (every 5 seconds)

**Job Persistence:**
- All job state stored in SQLite
- Survives application restarts
- Failed jobs can be manually retried
- Job history preserved for debugging

**Supervision Strategy:**
- Workers supervised with `:temporary` restart
- If worker crashes, job status remains "processing"
- Separate supervisor process detects stale jobs (no heartbeat for 5 minutes)
- Stale jobs reset to "queued" for retry

## API Endpoints

**Authentication:**
- `POST /api/auth/login` - Login to web interface
- `POST /api/auth/logout` - Logout

**Video Management:**
- `POST /api/videos/upload` - Upload video file (requires auth)
- `GET /api/videos` - List all videos (requires auth)
- `GET /api/videos/:id` - Get video metadata (requires auth)
- `PATCH /api/videos/:id` - Update video metadata (requires auth)
- `DELETE /api/videos/:id` - Delete video and all assets (requires auth)

**Token Management:**
- `POST /api/videos/:id/tokens` - Generate new access token
- `GET /api/tokens` - List all active tokens (requires auth)
- `DELETE /api/tokens/:token` - Revoke token (requires auth)

**Video Streaming (token-protected):**
- `GET /api/videos/:id/master.m3u8?token=xyz` - Master HLS manifest
- `GET /api/videos/:id/:quality.m3u8?token=xyz` - Quality-specific playlist
- `GET /api/videos/:id/key?token=xyz` - Decryption key
- `GET /api/videos/:id/:quality/:segment?token=xyz` - Video segment

**Job Management (web interface):**
- `GET /api/jobs` - List encoding jobs (requires auth)
- `POST /api/jobs/:id/retry` - Manually retry failed job (requires auth)
- `DELETE /api/jobs/:id` - Delete job record (requires auth)

## Authentication & Authorization

### Web Interface Authentication
- Simple login form (username/password)
- Session-based authentication (Phoenix sessions)
- Session expires after inactivity (configurable)
- All management endpoints require valid session

### Desktop Player Authentication
- Generate access token via web interface
- Token embedded in video URL
- Token validated on every streaming request
- Tokens can be:
  - **Permanent**: Never expire (good for personal devices)
  - **Time-limited**: Expire after X hours/days (good for sharing)
  - **Revocable**: Delete token to immediately revoke access

### Token Validation Flow
1. Request arrives with `?token=xyz` parameter
2. Look up token in SQLite database
3. Check if token exists and hasn't expired
4. Check if token is for the requested video
5. Update `last_used_at` timestamp
6. Allow or deny request

### Security Considerations
- Single user means simpler security model
- Main threats: unauthorized access if tokens leak
- Mitigations:
  - Use HTTPS in production (prevents token interception)
  - Generate strong random tokens (32+ bytes)
  - Time-limit tokens when sharing
  - Monitor `last_used_at` for suspicious activity
  - Easy to revoke compromised tokens

## Encoding Specifications

### FFmpeg Workflow

**Key Generation:**
- Generate 16-byte random key using OpenSSL
- Store with restrictive permissions (chmod 600)
- One key per video

**Key Info File Format:**
- Line 1: Key URI (where player fetches key)
- Line 2: Path to key file (for FFmpeg to read)
- Line 3: IV in hex (optional, omit for random IV per segment)

**Encoding Parameters:**
- **1080p**: H.264 @ 4 Mbps, AAC @ 128 kbps, 1920x1080
- **720p**: H.264 @ 2 Mbps, AAC @ 96 kbps, 1280x720
- **480p**: H.264 @ 1 Mbps, AAC @ 64 kbps, 854x480

**FFmpeg Preset**: `medium` (balance speed/quality)

**HLS Settings:**
- Segment duration: 4 seconds
- Playlist type: VOD (video on demand)
- Encryption: AES-128 per segment

**Master Playlist:**
- Lists all available quality levels
- Generated programmatically in Elixir
- Includes bandwidth and resolution metadata

### Quality Targets
| Resolution | Video Bitrate | Audio Bitrate | Expected Encode Speed | File Size (10 min) |
|------------|--------------|---------------|----------------------|-------------------|
| 1080p      | 4 Mbps       | 128 kbps      | 2-3x realtime        | ~300 MB           |
| 720p       | 2 Mbps       | 96 kbps       | 3-4x realtime        | ~150 MB           |
| 480p       | 1 Mbps       | 64 kbps       | 4-5x realtime        | ~75 MB            |

**Storage Estimate**: 3x original file size for all qualities combined

## Background Job Processing Details

### EncodingQueue GenServer
- **Responsibility**: Poll database for queued jobs, dispatch to workers
- **Polling interval**: 5 seconds
- **State**: List of active worker PIDs
- **Concurrency limit**: 1-2 workers (CPU intensive)

### EncodingWorker GenServer
- **Responsibility**: Execute FFmpeg encoding for one job
- **Lifecycle**: Started per job, terminates when done
- **State**: Current job_id, video_id, start_time
- **Heartbeat**: Updates job record every 30 seconds while processing
- **Error handling**: Catches FFmpeg failures, updates job status

### Job Retry Logic
- Max attempts: 3
- On failure: increment `attempts` counter
- If `attempts < max_attempts`: reset status to "queued"
- If `attempts >= max_attempts`: set status to "failed", store error
- Exponential backoff optional (delay retry by `2^attempts` minutes)

### Stale Job Recovery
- Separate supervisor process runs every minute
- Finds jobs with status "processing" and no heartbeat for 5+ minutes
- Resets these jobs to "queued" (worker likely crashed)
- Ensures jobs don't get stuck forever

### Job Monitoring
- Web interface shows:
  - All jobs with status and timestamps
  - Current encoding progress (which quality being processed)
  - Error messages for failed jobs
  - Retry button for failed jobs
- Real-time updates via Phoenix LiveView (optional enhancement)

## Frontend Integration

### Web Interface Requirements
- Video library page (grid/list view of all videos)
- Video upload form with drag-and-drop
- Video player page with Video.js
- Job queue monitoring:
  - Current encoding jobs
  - Recently completed jobs
  - Failed jobs with errors
  - Manual retry button
- Token management interface:
  - Generate new tokens
  - View active tokens with last used timestamp
  - Copy token URLs to clipboard
  - Revoke tokens
- Video editing (update title/description)
- Encoding status indicators

### Video Player (Web)
- Video.js with HLS support
- Automatic quality switching
- Playback controls (play, pause, seek, volume)
- Quality selector (manual override)
- Fullscreen support
- Keyboard shortcuts

### Desktop Player Integration
- Display token URL in web interface
- One-click copy to clipboard
- QR code generation (optional, for mobile devices)
- Instructions for mpv/VLC/IINA usage
- Token description field (e.g., "Living Room TV")

### User Experience Goals
- Upload should be drag-and-drop simple
- Encoding progress visible in real-time
- Easy token generation (one click → copy URL)
- Video library should load quickly
- Search/filter videos by title
- Sort by upload date, duration, etc.

## Performance Considerations

### SQLite Performance
- Fast for single-user workloads
- Reads are concurrent (multiple readers)
- Writes are serialized (but not a bottleneck here)
- Adequate for thousands of videos
- Entire database in memory possible (PRAGMA cache_size)
- WAL mode for better concurrency

### Encoding Performance
- H.264 encoding speed: 2-5x realtime
- Single quality: 2-5 minutes per 10 minutes of video
- All qualities: ~15 minutes total (sequential), ~5 minutes (parallel)
- CPU-intensive: consider encoding during off-hours for large batches
- GenServer concurrency limit prevents CPU overload

### Serving Performance
- Static file serving is lightweight
- Phoenix handles small-scale streaming well
- Segments are cacheable (immutable once created)
- For production: nginx reverse proxy or CDN

### Storage Optimization
- H.264 offers good compression
- Plan for ~3x original file size
- Example: 100GB of source video → ~300GB total storage
- Segment files (`.ts`) are already compressed
- Consider periodic cleanup of failed/abandoned uploads

## Development Setup

### Prerequisites
- Elixir 1.14+ and Erlang/OTP 25+
- SQLite3 (usually pre-installed on macOS/Linux)
- FFmpeg with libx264 and AAC encoder
- Node.js (for frontend assets)

### FFmpeg Installation
**macOS**: `brew install ffmpeg`  
**Ubuntu/Debian**: `sudo apt install ffmpeg`  
**Verify**: `ffmpeg -codecs | grep h264` and `ffmpeg -codecs | grep aac`

### Phoenix Project Setup
- Initialize Phoenix project with `--database sqlite3`
- Add Ecto SQLite3 adapter dependency
- Configure SQLite database path
- Set up database migrations
- Create required directories (`priv/keys`, `uploads`, etc.)
- Set file permissions

### Required Dependencies
- `ecto_sqlite3` - SQLite adapter for Ecto
- `bcrypt_elixir` - Password hashing
- Standard Phoenix dependencies

### Environment Configuration
- SQLite database path (default: `streamvault.db`)
- Secret key base
- Upload size limits
- FFmpeg binary path (if not in PATH)
- Session timeout duration
- Encoding worker concurrency (1-2)

### Development Workflow
1. `mix ecto.setup` - Creates SQLite database and runs migrations
2. `mix phx.server` - Start server (port 4000)
3. Navigate to `http://localhost:4000`
4. Create initial user account
5. Upload test video
6. Monitor encoding in job queue
7. Play video when ready

**SQLite Advantages in Development:**
- No separate database server to start
- Database is just a file (easy to reset/backup)
- Same codebase works on any OS
- Can inspect database with `sqlite3 streamvault.db`
- Fast iteration cycle

## Deployment Considerations

### Development Environment
- HTTP is fine for local network
- Single server setup
- Local file storage
- Simple session-based auth
- SQLite database in project directory

### Production/Remote Access (Optional)
- **HTTPS required** (tokens in URLs visible in logs)
- Nginx reverse proxy recommended
- Consider VPN instead of exposing to internet
- Regular database backups (copy `.db` file)
- Storage backup strategy (videos are irreplaceable family content!)
- Monitor disk space usage
- Set up systemd service for auto-restart
- Log rotation
- SQLite WAL mode for better reliability

### SQLite Production Considerations
- Use WAL (Write-Ahead Logging) mode for better concurrency
- Set appropriate cache size (PRAGMA cache_size)
- Regular VACUUM to reclaim space
- Database file permissions (chmod 600)
- Backup strategy: periodic copies of `.db` file
- Consider SQLite backup API for live backups
- Location: place database on SSD for better performance

### Backup Strategy (Critical for Personal Archive)
- **SQLite Database**: Copy `streamvault.db` file regularly
- **Video segments**: Sync to external drive or cloud storage
- **Encryption keys**: Back up entire `priv/keys/` directory
- **Original uploads**: Optionally keep originals before deletion
- Test restoration process periodically
- Automate backups (cron job or systemd timer)

### Security Hardening (Production)
- Change default admin password immediately
- Use strong random session secret
- Enable HTTPS/TLS
- Set secure cookie flags
- Rate limit token validation
- Monitor access logs for suspicious patterns
- Consider encrypted filesystem for video storage
- Regular security updates
- SQLite database file permissions (chmod 600)

## Learning Objectives

By building this project, you'll learn:

### Elixir/Phoenix Fundamentals
- Phoenix routing and controllers
- File uploads with Plug.Upload
- Serving static and dynamic files
- Ecto schemas, changesets, associations
- Database queries and migrations
- Form handling and validation
- Working with SQLite in Elixir

### OTP/Concurrency Patterns
- GenServer behavior and state management
- Supervision trees and fault tolerance
- Process lifecycle and monitoring
- Inter-process communication
- Background job processing patterns
- Worker pools and concurrency limits
- Process registration and discovery

### System Integration
- Executing external commands (FFmpeg)
- File system operations
- Path management and security
- Environment configuration
- Error handling patterns
- Logging and debugging
- Long-running task management

### Web Development
- HTTP streaming protocols (HLS)
- Authentication and authorization
- Session management
- Token-based access control
- Content-Type headers
- Range requests (video seeking)
- File download/upload handling

### Security Concepts
- Password hashing (bcrypt)
- Token generation (secure random)
- File permission management
- Session security
- Input validation
- HTTPS/TLS basics

### Database Design
- Schema design for SQLite
- Migrations and versioning
- Indexes for performance
- Foreign keys and cascading deletes
- Transaction handling
- Query optimization

## Future Enhancements (Post-Learning)

### Background Job Improvements
- Parallel quality encoding (spawn 3 workers per job)
- Progress percentage tracking
- ETA estimation
- Pause/resume encoding
- Priority queue (urgent vs normal)
- Scheduled encoding (encode during off-hours)

### Security Improvements
- Two-factor authentication
- Encrypted key storage (master key + per-video keys)
- Audit logs (who accessed what, when)
- Automatic token expiration policies
- IP whitelisting for admin interface

### Feature Additions
- Video thumbnails (extract from encoding)
- Preview/scrubbing timeline
- Subtitle support (WebVTT upload)
- Multiple audio tracks
- Video collections/playlists
- Tags and categories
- Full-text search
- Video notes/annotations
- Share links (time-limited public access)
- 4K quality tier
- Progress tracking (resume playback)
- Watch history

### Advanced Encoding
- Hardware-accelerated encoding (NVENC, QuickSync)
- VP9 or AV1 codec (better compression)
- HDR support
- Variable bitrate (VBR) optimization
- Two-pass encoding for better quality

### Infrastructure Improvements
- Object storage integration (S3, Backblaze B2)
- CDN for faster streaming
- Multiple encoding profiles
- Automatic backup to cloud
- Mobile app for remote access
- Batch upload processing
- Video conversion (MOV → MP4, etc.)
- Duplicate detection
- Migrate to Postgres if scaling beyond single-user

### User Experience
- Progressive web app (PWA)
- Offline viewing (download to device)
- Chromecast/AirPlay support
- Watch party (synchronized viewing)
- Video statistics (watch count, duration)
- Recently uploaded section
- Favorites/starred videos
- Phoenix LiveView for real-time updates

## Success Criteria

✅ Single user can login to web interface  
✅ Upload videos via drag-and-drop  
✅ GenServer-based encoding queue processes jobs  
✅ Background encoding with 3 quality levels  
✅ H.264/AAC in MP4 container  
✅ HLS adaptive streaming works in browser  
✅ AES-128 encryption on all segments  
✅ Generate access tokens for videos  
✅ Desktop players (mpv/VLC/IINA) stream via token URLs  
✅ Token revocation works immediately  
✅ Video library shows all uploaded videos  
✅ Job queue monitoring (pending/processing/completed/failed)  
✅ Manual retry for failed encoding jobs  
✅ Update video metadata (title, description)  
✅ Delete videos and cleanup all assets  
✅ Smooth playback with quality switching  
✅ Proper error handling and retry logic  
✅ Understanding of Elixir/Phoenix and OTP patterns  
✅ SQLite integration working smoothly  

## Example Usage Scenarios

### Scenario 1: Upload Family Video
1. Login to web interface
2. Drag-and-drop family reunion video
3. Enter title "Family Reunion 2024"
4. Video uploads, encoding job created
5. GenServer worker picks up job and starts encoding
6. Monitor encoding progress in job queue page
7. Once ready, watch in browser or generate token for TV

### Scenario 2: Watch on Living Room TV
1. Open video in web library
2. Click "Generate Token" → "Living Room TV"
3. Copy token URL to clipboard
4. On TV media player (IINA), paste URL
5. Video plays with automatic quality selection
6. Token remains valid until manually revoked

### Scenario 3: Share with Family Member
1. Select video to share
2. Generate time-limited token (expires in 7 days)
3. Send token URL to family member via email/text
4. They watch in their preferred player
5. After 7 days, token expires automatically

### Scenario 4: Handle Encoding Failure
1. Upload video, encoding starts
2. Encoding fails (corrupt file, FFmpeg error)
3. Job shows as "failed" with error message
4. Review error in job queue page
5. Fix issue (re-upload better file)
6. Or click "Retry" to attempt encoding again

### Scenario 5: Organize Video Library
1. Browse all uploaded videos
2. Search for "birthday" in titles
3. Edit video metadata to add description
4. Delete old test videos
5. Review storage usage statistics
6. Check encoding job history

## Glossary

- **Token**: Secure random string granting access to specific video
- **HLS**: HTTP Live Streaming - Apple's streaming protocol
- **Manifest**: Playlist file listing video segments (`.m3u8`)
- **Segment**: Small video chunk (typically 4 seconds, `.ts` file)
- **ABR**: Adaptive Bitrate - automatic quality switching
- **VOD**: Video On Demand - pre-encoded content
- **Codec**: Compression algorithm (H.264 for video, AAC for audio)
- **Container**: File format (MP4, WebM, etc.)
- **Transcoding**: Converting video to different format/quality
- **FFmpeg**: Command-line video processing tool
- **GenServer**: Elixir generic server behavior for stateful processes
- **Supervision Tree**: OTP pattern for process fault tolerance
- **SQLite**: Serverless, file-based SQL database
- **WAL**: Write-Ahead Logging - SQLite mode for better concurrency

## Resources

### Elixir/Phoenix
- [Elixir Getting Started Guide](https://elixir-lang.org/getting-started/introduction.html)
- [Phoenix Framework Guides](https://hexdocs.pm/phoenix/overview.html)
- [GenServer Documentation](https://hexdocs.pm/elixir/GenServer.html)
- [Ecto Query Guide](https://hexdocs.pm/ecto/Ecto.Query.html)
- [Ecto SQLite3 Adapter](https://hexdocs.pm/ecto_sqlite3/)

### OTP Patterns
- [Learn You Some Erlang (OTP)](https://learnyousomeerlang.com/what-is-otp)
- [Elixir School - OTP Concurrency](https://elixirschool.com/en/lessons/advanced/otp_concurrency)
- [Designing Elixir Systems with OTP](https://pragprog.com/titles/jgotp/designing-elixir-systems-with-otp/)

### Video Streaming
- [FFmpeg Documentation](https://ffmpeg.org/documentation.html)
- [HLS Specification RFC 8216](https://datatracker.ietf.org/doc/html/rfc8216)
- [Video.js Documentation](https://docs.videojs.com/)
- [HLS Authoring Specification](https://developer.apple.com/documentation/http_live_streaming)

### SQLite
- [SQLite Documentation](https://sqlite.org/docs.html)
- [SQLite WAL Mode](https://sqlite.org/wal.html)
- [When to Use SQLite](https://sqlite.org/whentouse.html)

### Security
- [Phoenix Security Guide](https://hexdocs.pm/phoenix/security.html)
- [OWASP Authentication Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Authentication_Cheat_Sheet.html)
