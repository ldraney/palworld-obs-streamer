# Palworld OBS Streamer

## Project Overview
PowerShell scripts to automate OBS Studio configuration for streaming Palworld to Twitch.

## Target Configuration
- **Platform:** Windows 10/11 with PowerShell
- **OBS Installation:** `C:\Program Files\obs-studio`
- **OBS Config Location:** `%APPDATA%\obs-studio`
- **GPU:** NVIDIA (using NVENC encoder)
- **Streaming Service:** Twitch

## Stream Settings
- Resolution: 1920x1080
- Framerate: 60 FPS
- Encoder: NVENC H.264 (`jim_nvenc`)
- Bitrate: 6000 kbps (CBR)
- Keyframe Interval: 2 seconds
- Preset: Quality

## Project Structure
```
palworld-obs-streamer/
├── CLAUDE.md              # This file - project documentation
├── Setup-OBSPalworld.ps1  # One-time setup script
├── StartPalworldStream.ps1 # Daily launch script
└── config/                # OBS config templates (optional)
```

## Scripts

### Setup-OBSPalworld.ps1
One-time setup script that:
1. Creates OBS config directory structure
2. Creates "Palworld" profile with NVENC streaming settings
3. Creates "Palworld" scene collection with game capture
4. Configures Twitch as streaming service
5. Prompts user for Twitch stream key
6. Enables OBS WebSocket for automation

### StartPalworldStream.ps1
Daily use script that:
1. Launches OBS with Palworld profile and scene
2. Optionally auto-starts streaming via WebSocket
3. Can launch Palworld game

## OBS Config File Locations
- Profile settings: `%APPDATA%\obs-studio\basic\profiles\Palworld\basic.ini`
- Scene collection: `%APPDATA%\obs-studio\basic\scenes\Palworld.json`
- WebSocket config: `%APPDATA%\obs-studio\plugin_config\obs-websocket\config.json`
- Global config: `%APPDATA%\obs-studio\global.ini`

## Key OBS INI Settings for NVENC Streaming
```ini
[Output]
Mode=Advanced

[AdvOut]
Encoder=jim_nvenc
RateControl=CBR
Bitrate=6000
KeyframeIntervalSec=2
NVENCPreset=Quality
Profile=high
LookAhead=true
PsychVisualTuning=true
BFrames=2

[Video]
BaseCX=1920
BaseCY=1080
OutputCX=1920
OutputCY=1080
FPSType=1
FPSCommon=60
```

## Development Notes
- Use PowerShell 5.1+ (comes with Windows)
- OBS must be closed when modifying config files
- Test with OBS's "Settings" dialog to verify changes
- Stream key is stored in service.json (standard OBS behavior)

## Rollback
If something goes wrong, delete `%APPDATA%\obs-studio` and OBS will recreate defaults on next launch.
