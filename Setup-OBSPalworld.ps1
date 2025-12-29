<#
.SYNOPSIS
    One-time setup script to configure OBS Studio for streaming Palworld to Twitch.

.DESCRIPTION
    This script creates:
    - OBS configuration directory structure
    - "Palworld" profile with NVENC 1080p60 streaming settings
    - "Palworld" scene collection with game capture and audio sources
    - Twitch streaming service configuration
    - OBS WebSocket configuration for automation

.NOTES
    - Run this script ONCE before streaming
    - OBS must be CLOSED when running this script
    - You will be prompted for your Twitch stream key
#>

param(
    [switch]$Force,  # Force overwrite existing config
    [string]$EnvFile = "$HOME\palworld-obs-streamer-secrets\.env"  # Path to .env file with stream key
)

# Configuration
$OBSConfigPath = "$env:APPDATA\obs-studio"
$ProfileName = "Palworld"
$SceneCollectionName = "Palworld"
$SecretsRepo = "$HOME\palworld-obs-streamer-secrets"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Palworld OBS Streaming Setup" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check if OBS is running
$obsProcess = Get-Process -Name "obs64" -ErrorAction SilentlyContinue
if ($obsProcess) {
    Write-Host "[ERROR] OBS is currently running. Please close OBS and run this script again." -ForegroundColor Red
    exit 1
}

# Check if OBS is installed
$obsExe = "C:\Program Files\obs-studio\bin\64bit\obs64.exe"
if (-not (Test-Path $obsExe)) {
    Write-Host "[ERROR] OBS not found at expected location: $obsExe" -ForegroundColor Red
    Write-Host "Please install OBS Studio first." -ForegroundColor Yellow
    exit 1
}
Write-Host "[OK] OBS installation found" -ForegroundColor Green

# Check for existing config
if ((Test-Path "$OBSConfigPath\basic\profiles\$ProfileName") -and -not $Force) {
    Write-Host "[WARNING] Palworld profile already exists!" -ForegroundColor Yellow
    $response = Read-Host "Overwrite existing config? (y/N)"
    if ($response -ne 'y' -and $response -ne 'Y') {
        Write-Host "Setup cancelled." -ForegroundColor Yellow
        exit 0
    }
}

# Get Twitch stream key (from .env file or prompt)
Write-Host ""
$streamKeyPlain = $null

# Try to read from secrets .env file
if (Test-Path $EnvFile) {
    Write-Host "[OK] Found secrets file: $EnvFile" -ForegroundColor Green
    $envContent = Get-Content $EnvFile
    foreach ($line in $envContent) {
        if ($line -match "^TWITCH_STREAM_KEY=(.+)$") {
            $streamKeyPlain = $Matches[1].Trim()
            Write-Host "[OK] Stream key loaded from .env file" -ForegroundColor Green
            break
        }
    }
}

# If not found in .env, prompt user
if ([string]::IsNullOrWhiteSpace($streamKeyPlain)) {
    Write-Host "Enter your Twitch Stream Key" -ForegroundColor Yellow
    Write-Host "(Find it at: https://dashboard.twitch.tv/settings/stream)" -ForegroundColor Gray
    $streamKey = Read-Host -AsSecureString "Stream Key"
    $streamKeyPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [Runtime.InteropServices.Marshal]::SecureStringToBSTR($streamKey)
    )
}

if ([string]::IsNullOrWhiteSpace($streamKeyPlain)) {
    Write-Host "[ERROR] Stream key cannot be empty!" -ForegroundColor Red
    Write-Host "Either provide a .env file at: $EnvFile" -ForegroundColor Yellow
    Write-Host "Or enter the key when prompted." -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "Creating OBS configuration..." -ForegroundColor Cyan

# ============================================
# Phase 1: Create Directory Structure
# ============================================
Write-Host "  [1/5] Creating directory structure..." -ForegroundColor White

$directories = @(
    "$OBSConfigPath\basic\profiles\$ProfileName",
    "$OBSConfigPath\basic\scenes",
    "$OBSConfigPath\plugin_config\obs-websocket"
)

foreach ($dir in $directories) {
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
}
Write-Host "        Done" -ForegroundColor Green

# ============================================
# Phase 2: Create Profile (basic.ini)
# ============================================
Write-Host "  [2/5] Creating streaming profile..." -ForegroundColor White

$basicIni = @"
[General]
Name=$ProfileName

[Video]
BaseCX=1920
BaseCY=1080
OutputCX=1920
OutputCY=1080
FPSType=1
FPSCommon=60
ColorFormat=NV12
ColorSpace=709
ColorRange=Partial

[Output]
Mode=Advanced

[AdvOut]
TrackIndex=1
RecType=Standard
RecTracks=1
FLVTrack=1
FFOutputToFile=true
FFFormat=
FFFormatMimeType=
FFVEncoderId=0
FFVEncoder=
FFAEncoderId=0
FFAEncoder=
FFAudioMixes=1
VodTrackEnabled=false
Encoder=jim_nvenc
FFRescale=false
RecRescale=false
RecEncoder=none

[Stream1]
IgnoreRecommended=false
VodTrackEnabled=false

[SimpleOutput]
FilePath=
RecFormat=mkv
StreamEncoder=jim_nvenc
StreamAudioEncoder=aac
RecQuality=Stream
RecEncoder=x264
RecAudioEncoder=aac
RecTracks=1

[Hotkeys]
OBSBasic.StartStreaming=
OBSBasic.StopStreaming=
OBSBasic.StartRecording=
OBSBasic.StopRecording=
"@

$basicIniPath = "$OBSConfigPath\basic\profiles\$ProfileName\basic.ini"
Set-Content -Path $basicIniPath -Value $basicIni -Encoding UTF8
Write-Host "        Done" -ForegroundColor Green

# ============================================
# Phase 3: Create Streaming Settings (streamEncoder.json)
# ============================================
Write-Host "  [3/5] Configuring NVENC encoder..." -ForegroundColor White

$streamEncoderJson = @{
    "rate_control" = "CBR"
    "bitrate" = 6000
    "keyint_sec" = 2
    "preset" = "p5"
    "profile" = "high"
    "lookahead" = $true
    "psycho_aq" = $true
    "bf" = 2
    "multipass" = "qres"
} | ConvertTo-Json -Depth 10

$streamEncoderPath = "$OBSConfigPath\basic\profiles\$ProfileName\streamEncoder.json"
Set-Content -Path $streamEncoderPath -Value $streamEncoderJson -Encoding UTF8

# Create service.json for Twitch
$serviceJson = @{
    "settings" = @{
        "key" = $streamKeyPlain
        "server" = "auto"
        "service" = "Twitch"
    }
    "type" = "rtmp_common"
} | ConvertTo-Json -Depth 10

$servicePath = "$OBSConfigPath\basic\profiles\$ProfileName\service.json"
Set-Content -Path $servicePath -Value $serviceJson -Encoding UTF8
Write-Host "        Done" -ForegroundColor Green

# ============================================
# Phase 4: Create Scene Collection
# ============================================
Write-Host "  [4/5] Creating scene collection..." -ForegroundColor White

# Generate UUIDs for sources
$gameCapUuid = [guid]::NewGuid().ToString()
$audioOutUuid = [guid]::NewGuid().ToString()
$audioInUuid = [guid]::NewGuid().ToString()
$sceneUuid = [guid]::NewGuid().ToString()

$sceneCollection = @{
    "current_program_scene" = "Palworld Stream"
    "current_scene" = "Palworld Stream"
    "name" = $SceneCollectionName
    "sources" = @(
        @{
            "balance" = 0.5
            "deinterlace_field_order" = 0
            "deinterlace_mode" = 0
            "enabled" = $true
            "flags" = 0
            "hotkeys" = @{}
            "id" = "game_capture"
            "mixers" = 0
            "monitoring_type" = 0
            "muted" = $false
            "name" = "Palworld Game"
            "prev_ver" = 503316480
            "private_settings" = @{}
            "push-to-mute" = $false
            "push-to-mute-delay" = 0
            "push-to-talk" = $false
            "push-to-talk-delay" = 0
            "settings" = @{
                "capture_mode" = "any_fullscreen"
                "priority" = 1
                "window" = "Palworld:UnrealWindow:Palworld-Win64-Shipping.exe"
            }
            "sync" = 0
            "uuid" = $gameCapUuid
            "versioned_id" = "game_capture"
            "volume" = 1.0
        },
        @{
            "balance" = 0.5
            "deinterlace_field_order" = 0
            "deinterlace_mode" = 0
            "enabled" = $true
            "flags" = 0
            "hotkeys" = @{}
            "id" = "wasapi_output_capture"
            "mixers" = 255
            "monitoring_type" = 0
            "muted" = $false
            "name" = "Desktop Audio"
            "prev_ver" = 503316480
            "private_settings" = @{}
            "push-to-mute" = $false
            "push-to-mute-delay" = 0
            "push-to-talk" = $false
            "push-to-talk-delay" = 0
            "settings" = @{
                "device_id" = "default"
            }
            "sync" = 0
            "uuid" = $audioOutUuid
            "versioned_id" = "wasapi_output_capture"
            "volume" = 1.0
        },
        @{
            "balance" = 0.5
            "deinterlace_field_order" = 0
            "deinterlace_mode" = 0
            "enabled" = $true
            "flags" = 0
            "hotkeys" = @{}
            "id" = "wasapi_input_capture"
            "mixers" = 255
            "monitoring_type" = 0
            "muted" = $false
            "name" = "Microphone"
            "prev_ver" = 503316480
            "private_settings" = @{}
            "push-to-mute" = $false
            "push-to-mute-delay" = 0
            "push-to-talk" = $false
            "push-to-talk-delay" = 0
            "settings" = @{
                "device_id" = "default"
            }
            "sync" = 0
            "uuid" = $audioInUuid
            "versioned_id" = "wasapi_input_capture"
            "volume" = 1.0
        },
        @{
            "balance" = 0.5
            "deinterlace_field_order" = 0
            "deinterlace_mode" = 0
            "enabled" = $true
            "flags" = 0
            "hotkeys" = @{}
            "id" = "scene"
            "mixers" = 0
            "monitoring_type" = 0
            "muted" = $false
            "name" = "Palworld Stream"
            "prev_ver" = 503316480
            "private_settings" = @{}
            "push-to-mute" = $false
            "push-to-mute-delay" = 0
            "push-to-talk" = $false
            "push-to-talk-delay" = 0
            "settings" = @{
                "custom_size" = $false
                "id_counter" = 3
                "items" = @(
                    @{
                        "align" = 5
                        "bounds" = @{
                            "x" = 0.0
                            "y" = 0.0
                        }
                        "bounds_align" = 0
                        "bounds_type" = 0
                        "crop_bottom" = 0
                        "crop_left" = 0
                        "crop_right" = 0
                        "crop_top" = 0
                        "group_item_backup" = $false
                        "hide_transition" = @{}
                        "id" = 1
                        "locked" = $false
                        "name" = "Palworld Game"
                        "pos" = @{
                            "x" = 0.0
                            "y" = 0.0
                        }
                        "private_settings" = @{}
                        "rot" = 0.0
                        "scale" = @{
                            "x" = 1.0
                            "y" = 1.0
                        }
                        "scale_filter" = "disable"
                        "show_transition" = @{}
                        "source_uuid" = $gameCapUuid
                        "visible" = $true
                    }
                )
            }
            "sync" = 0
            "uuid" = $sceneUuid
            "versioned_id" = "scene"
            "volume" = 1.0
        }
    )
    "scene_order" = @(
        @{
            "name" = "Palworld Stream"
        }
    )
}

$sceneCollectionJson = $sceneCollection | ConvertTo-Json -Depth 20
$scenePath = "$OBSConfigPath\basic\scenes\$SceneCollectionName.json"
Set-Content -Path $scenePath -Value $sceneCollectionJson -Encoding UTF8
Write-Host "        Done" -ForegroundColor Green

# ============================================
# Phase 5: Create Global Config
# ============================================
Write-Host "  [5/5] Setting up global config..." -ForegroundColor White

$globalIni = @"
[General]
LastVersion=503316480
FirstRun=false
LastSceneCollection=$SceneCollectionName
LastProfile=$ProfileName

[BasicWindow]
PreviewEnabled=true
AlwaysOnTop=false
SceneDuplicationMode=true
SwapScenesMode=true
SnappingEnabled=true
SnapDistance=10.0
ScreenSnapping=true
SourceSnapping=true
CenterSnapping=false

[Audio]
ChannelSetup=Stereo
SampleRate=48000
"@

$globalIniPath = "$OBSConfigPath\global.ini"
Set-Content -Path $globalIniPath -Value $globalIni -Encoding UTF8
Write-Host "        Done" -ForegroundColor Green

# ============================================
# Summary
# ============================================
Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  Setup Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Created:" -ForegroundColor Cyan
Write-Host "  - Profile: $ProfileName" -ForegroundColor White
Write-Host "  - Scene Collection: $SceneCollectionName" -ForegroundColor White
Write-Host "  - Encoder: NVENC H.264 @ 6000kbps" -ForegroundColor White
Write-Host "  - Resolution: 1920x1080 @ 60fps" -ForegroundColor White
Write-Host "  - Service: Twitch (Auto server)" -ForegroundColor White
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "  1. Launch OBS to verify the configuration" -ForegroundColor White
Write-Host "  2. Start Palworld in fullscreen" -ForegroundColor White
Write-Host "  3. Check that game capture is working" -ForegroundColor White
Write-Host "  4. Click 'Start Streaming' to go live!" -ForegroundColor White
Write-Host ""
Write-Host "Or run: .\StartPalworldStream.ps1" -ForegroundColor Gray
Write-Host ""

# Offer to launch OBS
$launchObs = Read-Host "Launch OBS now? (Y/n)"
if ($launchObs -ne 'n' -and $launchObs -ne 'N') {
    Write-Host "Launching OBS..." -ForegroundColor Cyan
    Start-Process -FilePath $obsExe -ArgumentList "--profile", $ProfileName, "--collection", $SceneCollectionName
}
