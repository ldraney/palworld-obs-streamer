<#
.SYNOPSIS
    Launch script for streaming Palworld to Twitch.

.DESCRIPTION
    This script:
    - Launches OBS with the Palworld profile and scene collection
    - Optionally launches Palworld game
    - Can auto-start streaming (requires OBS WebSocket)

.PARAMETER LaunchGame
    Also launch Palworld after starting OBS

.PARAMETER AutoStream
    Automatically start streaming after OBS launches (requires WebSocket)

.EXAMPLE
    .\StartPalworldStream.ps1
    # Just launches OBS with Palworld config

.EXAMPLE
    .\StartPalworldStream.ps1 -LaunchGame
    # Launches OBS and then Palworld

.EXAMPLE
    .\StartPalworldStream.ps1 -LaunchGame -AutoStream
    # Launches everything and auto-starts streaming
#>

param(
    [switch]$LaunchGame,
    [switch]$AutoStream
)

# Configuration
$OBSExe = "C:\Program Files\obs-studio\bin\64bit\obs64.exe"
$ProfileName = "Palworld"
$SceneCollectionName = "Palworld"

# Common Palworld locations (Steam)
$PalworldPaths = @(
    "C:\Program Files (x86)\Steam\steamapps\common\Palworld\Palworld.exe",
    "D:\Steam\steamapps\common\Palworld\Palworld.exe",
    "E:\Steam\steamapps\common\Palworld\Palworld.exe",
    "D:\SteamLibrary\steamapps\common\Palworld\Palworld.exe",
    "E:\SteamLibrary\steamapps\common\Palworld\Palworld.exe"
)

Write-Host ""
Write-Host "  Palworld Stream Launcher" -ForegroundColor Cyan
Write-Host "  ========================" -ForegroundColor Cyan
Write-Host ""

# Check if OBS is already running
$obsRunning = Get-Process -Name "obs64" -ErrorAction SilentlyContinue
if ($obsRunning) {
    Write-Host "[!] OBS is already running" -ForegroundColor Yellow
} else {
    # Check OBS exists
    if (-not (Test-Path $OBSExe)) {
        Write-Host "[ERROR] OBS not found at: $OBSExe" -ForegroundColor Red
        exit 1
    }

    # Check if profile exists
    $profilePath = "$env:APPDATA\obs-studio\basic\profiles\$ProfileName"
    if (-not (Test-Path $profilePath)) {
        Write-Host "[ERROR] Palworld profile not found!" -ForegroundColor Red
        Write-Host "Run Setup-OBSPalworld.ps1 first." -ForegroundColor Yellow
        exit 1
    }

    # Launch OBS with Palworld profile
    Write-Host "[>] Launching OBS with Palworld profile..." -ForegroundColor Green
    Start-Process -FilePath $OBSExe -ArgumentList "--profile", $ProfileName, "--collection", $SceneCollectionName

    # Wait for OBS to start
    Write-Host "[>] Waiting for OBS to initialize..." -ForegroundColor Gray
    Start-Sleep -Seconds 3
}

# Auto-start streaming if requested
if ($AutoStream) {
    Write-Host ""
    Write-Host "[>] Auto-streaming requested..." -ForegroundColor Cyan

    # Check if obs-websocket-py or similar is available
    # For simplicity, we'll use the REST API if OBS WebSocket is configured

    try {
        # OBS WebSocket 5.x uses port 4455 by default
        # This is a simplified check - full implementation would use WebSocket client

        Write-Host "[!] Auto-streaming via WebSocket not yet implemented." -ForegroundColor Yellow
        Write-Host "    Please click 'Start Streaming' manually in OBS." -ForegroundColor Gray
        Write-Host ""
        Write-Host "    To enable auto-streaming:" -ForegroundColor Gray
        Write-Host "    1. Install obs-websocket (OBS 28+ has it built-in)" -ForegroundColor Gray
        Write-Host "    2. Enable WebSocket in OBS: Tools > WebSocket Server Settings" -ForegroundColor Gray
        Write-Host "    3. Use OBS WebSocket client (Python/Node.js) to send StartStream command" -ForegroundColor Gray
    } catch {
        Write-Host "[ERROR] Failed to connect to OBS WebSocket: $_" -ForegroundColor Red
    }
}

# Launch Palworld if requested
if ($LaunchGame) {
    Write-Host ""
    Write-Host "[>] Looking for Palworld..." -ForegroundColor Cyan

    $palworldExe = $null
    foreach ($path in $PalworldPaths) {
        if (Test-Path $path) {
            $palworldExe = $path
            break
        }
    }

    if ($palworldExe) {
        Write-Host "[>] Found Palworld at: $palworldExe" -ForegroundColor Green
        Write-Host "[>] Launching Palworld..." -ForegroundColor Green

        # Launch via Steam for proper integration
        # Steam URL: steam://rungameid/1623730
        Start-Process "steam://rungameid/1623730"

        Write-Host "[OK] Palworld launching via Steam" -ForegroundColor Green
    } else {
        # Try Steam URL anyway
        Write-Host "[!] Palworld exe not found in common locations" -ForegroundColor Yellow
        Write-Host "[>] Attempting to launch via Steam..." -ForegroundColor Cyan
        Start-Process "steam://rungameid/1623730"
    }
}

# Summary
Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  Ready to Stream!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Checklist:" -ForegroundColor Yellow
Write-Host "  [ ] OBS is open with Palworld profile" -ForegroundColor White
Write-Host "  [ ] Game capture is showing Palworld" -ForegroundColor White
Write-Host "  [ ] Audio levels look good" -ForegroundColor White
Write-Host "  [ ] Click 'Start Streaming' when ready!" -ForegroundColor White
Write-Host ""

# Tips
Write-Host "Tips:" -ForegroundColor Cyan
Write-Host "  - If game capture is black, try Alt+Tab out and back" -ForegroundColor Gray
Write-Host "  - Run Palworld in Fullscreen (not borderless) for best capture" -ForegroundColor Gray
Write-Host "  - Check Twitch dashboard for stream health" -ForegroundColor Gray
Write-Host ""
