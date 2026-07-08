# launcher.ps1
# Quick launcher for video download tools

param(
    [switch]$Help
)

# Load proxy config
$_proxyCfg = Join-Path $PSScriptRoot "proxy-config.ps1"
if (Test-Path $_proxyCfg) { . $_proxyCfg }
$CurrentProxy = $ProxyURL

function Show-ProxyStatus {
    if ($CurrentProxy) {
        Write-Host "    [Proxy: $CurrentProxy]" -ForegroundColor Yellow
    } else {
        Write-Host "    [Proxy: DISABLED]" -ForegroundColor Gray
    }
}

function Show-LauncherMenu {
    Clear-Host
    Write-Host ""
    Write-Host "  ================================================================" -ForegroundColor Cyan
    Write-Host "                  VIDEO DOWNLOADER LAUNCHER" -ForegroundColor Cyan
    Write-Host "                      Quick Access Menu" -ForegroundColor Cyan
    Write-Host "  ================================================================" -ForegroundColor Cyan
    Show-ProxyStatus
    Write-Host "  ================================================================" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "  Available Tools:" -ForegroundColor Yellow
    Write-Host "  ----------------------------------------------------------------" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  [1] Main Menu Downloader" -ForegroundColor Green
    Write-Host "      Full-featured menu with pornstars and categories" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  [2] PMV Downloader" -ForegroundColor Green
    Write-Host "      Specialized Porn Music Video downloader" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  [3] Original Downloader" -ForegroundColor Green
    Write-Host "      Original download-videos.ps1 script" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  [4] View Documentation" -ForegroundColor Green
    Write-Host "      Open DOWNLOAD_GUIDE.md" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  [5] Configure Proxy / VPN" -ForegroundColor Magenta
    Write-Host "      Set or disable proxy for downloads" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  [6] Quick Download - Sky Bri" -ForegroundColor Magenta
    Write-Host "      Fast download for Sky Bri content" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  [7] Quick Download - PMV" -ForegroundColor Magenta
    Write-Host "      Fast download all PMV sources" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  [8] Quick Download - JOI Games" -ForegroundColor Magenta
    Write-Host "      Fast download JOI game content" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  [9] Update yt-dlp" -ForegroundColor Cyan
    Write-Host "      Update yt-dlp to latest version" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  [Q] Quit" -ForegroundColor Red
    Write-Host ""
}

function Show-Help {
    Write-Host ""
    Write-Host "VIDEO DOWNLOADER LAUNCHER - HELP" -ForegroundColor Yellow
    Write-Host "=================================" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "This launcher provides quick access to all video download tools." -ForegroundColor White
    Write-Host ""
    Write-Host "USAGE:" -ForegroundColor Cyan
    Write-Host "    .\launcher.ps1          # Show interactive menu" -ForegroundColor Gray
    Write-Host "    .\launcher.ps1 -Help    # Show this help" -ForegroundColor Gray
    Write-Host ""
    Write-Host "TOOLS AVAILABLE:" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "1. Main Menu Downloader (download-menu.ps1)" -ForegroundColor Green
    Write-Host "   - Full interactive menu" -ForegroundColor Gray
    Write-Host "   - Download by pornstar or category" -ForegroundColor Gray
    Write-Host "   - Direct URL support" -ForegroundColor Gray
    Write-Host "   - Custom searches" -ForegroundColor Gray
    Write-Host ""
    Write-Host "2. PMV Downloader (pmv-downloader.ps1)" -ForegroundColor Green
    Write-Host "   - Curated PMV sources" -ForegroundColor Gray
    Write-Host "   - PMVHaven playlist support" -ForegroundColor Gray
    Write-Host "   - Multi-platform PMV search" -ForegroundColor Gray
    Write-Host ""
    Write-Host "3. Original Downloader (download-videos.ps1)" -ForegroundColor Green
    Write-Host "   - Legacy downloader script" -ForegroundColor Gray
    Write-Host "   - Command-line focused" -ForegroundColor Gray
    Write-Host ""
    Write-Host "QUICK DOWNLOADS:" -ForegroundColor Cyan
    Write-Host "The launcher includes quick download options that skip the menu" -ForegroundColor Gray
    Write-Host "and immediately start downloading popular content." -ForegroundColor Gray
    Write-Host ""
    Write-Host "REQUIREMENTS:" -ForegroundColor Cyan
    Write-Host "- yt-dlp must be installed" -ForegroundColor Gray
    Write-Host "  Install: winget install yt-dlp" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "For detailed usage, see DOWNLOAD_GUIDE.md" -ForegroundColor Gray
    Write-Host ""
}

if ($Help) {
    Show-Help
    exit 0
}

function Manage-ProxyConfig {
    Clear-Host
    Write-Host ""
    Write-Host "  PROXY / VPN CONFIGURATION" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Current Proxy: " -ForegroundColor Yellow -NoNewline
    if ($CurrentProxy) {
        Write-Host $CurrentProxy -ForegroundColor Green
    } else {
        Write-Host "DISABLED (connecting directly)" -ForegroundColor Gray
    }
    Write-Host ""
    Write-Host "  [1] Set SOCKS5 proxy (port 1080)" -ForegroundColor Cyan
    Write-Host "  [2] Set HTTP proxy (port 8080)" -ForegroundColor Cyan
    Write-Host "  [3] Set custom proxy URL" -ForegroundColor Cyan
    Write-Host "  [4] Disable proxy" -ForegroundColor Cyan
    Write-Host "  [5] Back to main menu" -ForegroundColor Red
    Write-Host ""
    
    $selection = Read-Host "  Select an option"
    
    switch ($selection) {
        "1" {
            Write-Host ""
            Write-Host "  Setting SOCKS5 proxy..." -ForegroundColor Yellow
            $content = '$ProxyURL = "socks5://127.0.0.1:1080"'
            $cfgPath = Join-Path $PSScriptRoot "proxy-config.ps1"
            Set-Content -Path $cfgPath -Value $content -Encoding UTF8 -Force
            $script:CurrentProxy = "socks5://127.0.0.1:1080"
            Write-Host "  OK - Proxy saved. Restart downloads to apply." -ForegroundColor Green
        }
        "2" {
            Write-Host ""
            Write-Host "  Setting HTTP proxy..." -ForegroundColor Yellow
            $content = '$ProxyURL = "http://127.0.0.1:8080"'
            $cfgPath = Join-Path $PSScriptRoot "proxy-config.ps1"
            Set-Content -Path $cfgPath -Value $content -Encoding UTF8 -Force
            $script:CurrentProxy = "http://127.0.0.1:8080"
            Write-Host "  OK - Proxy saved. Restart downloads to apply." -ForegroundColor Green
        }
        "3" {
            Write-Host ""
            $url = Read-Host "  Enter proxy URL"
            if ($url) {
                $content = '$ProxyURL = "' + $url + '"'
                $cfgPath = Join-Path $PSScriptRoot "proxy-config.ps1"
                Set-Content -Path $cfgPath -Value $content -Encoding UTF8 -Force
                $script:CurrentProxy = $url
                Write-Host "  OK - Proxy saved. Restart downloads to apply." -ForegroundColor Green
            }
        }
        "4" {
            Write-Host ""
            Write-Host "  Disabling proxy..." -ForegroundColor Yellow
            $content = '$ProxyURL = ""'
            $cfgPath = Join-Path $PSScriptRoot "proxy-config.ps1"
            Set-Content -Path $cfgPath -Value $content -Encoding UTF8 -Force
            $script:CurrentProxy = ""
            Write-Host "  OK - Proxy disabled. Restart downloads to apply." -ForegroundColor Green
        }
        "5" {
            return
        }
    }
    
    Write-Host ""
    Read-Host "  Press Enter to continue"
}

if ($Help) {
    Show-Help
    exit 0
}

$running = $true

while ($running) {
    Show-LauncherMenu
    $choice = Read-Host "Select an option"
    
    switch ($choice) {
        "1" {
            Write-Host "`n🎮 Launching Main Menu Downloader..." -ForegroundColor Green
            Start-Sleep -Seconds 1
            try {
                & ".\download-menu.ps1" -Proxy $CurrentProxy
                if (-not $?) {
                    Write-Host "`n✗ download-menu.ps1 exited with errors (exit code $LASTEXITCODE)" -ForegroundColor Red
                    Read-Host "Press Enter to continue"
                }
            } catch {
                Write-Host "`n✗ Exception running download-menu.ps1: $_" -ForegroundColor Red
                Read-Host "Press Enter to continue"
            }
        }
        
        "2" {
            Write-Host "`n🎵 Launching PMV Downloader..." -ForegroundColor Green
            Start-Sleep -Seconds 1
            try {
                & ".\pmv-downloader.ps1" -Proxy $CurrentProxy
                if (-not $?) {
                    Write-Host "`n✗ pmv-downloader.ps1 exited with errors (exit code $LASTEXITCODE)" -ForegroundColor Red
                    Read-Host "Press Enter to continue"
                }
            } catch {
                Write-Host "`n✗ Exception running pmv-downloader.ps1: $_" -ForegroundColor Red
                Read-Host "Press Enter to continue"
            }
        }
        
        "3" {
            Write-Host "`n📜 Launching Original Downloader..." -ForegroundColor Green
            Start-Sleep -Seconds 1
            try {
                & ".\download-videos.ps1" -Interactive -Proxy $CurrentProxy
                if (-not $?) {
                    Write-Host "`n✗ download-videos.ps1 exited with errors (exit code $LASTEXITCODE)" -ForegroundColor Red
                    Read-Host "Press Enter to continue"
                }
            } catch {
                Write-Host "`n✗ Exception running download-videos.ps1: $_" -ForegroundColor Red
                Read-Host "Press Enter to continue"
            }
        }
        
        "4" {
            Write-Host "`n📖 Opening Documentation..." -ForegroundColor Green
            if (Test-Path "DOWNLOAD_GUIDE.md") {
                notepad "DOWNLOAD_GUIDE.md"
            } else {
                Write-Host "✗ DOWNLOAD_GUIDE.md not found!" -ForegroundColor Red
            }
        }
        
        "5" {
            Manage-ProxyConfig
        }
        
        "6" {
            Write-Host "`n⚡ Quick Download: Sky Bri" -ForegroundColor Magenta
            Write-Host "   This will download Sky Bri content to public/assets/videos/pornstars/sky_bri/" -ForegroundColor Gray
            $confirm = Read-Host "Continue? (y/n)"
            
            if ($confirm -eq "y") {
                $outputDir = "public/assets/videos/pornstars/sky_bri"
                $searches = @("Sky Bri", "Sky Bri blowjob", "Sky Bri POV")
                $skyBriDownloadFailed = $false
                
                foreach ($term in $searches) {
                    Write-Host "`n🔍 Searching: $term" -ForegroundColor Cyan
                    
                    $searchUrl = "https://www.pornhub.com/video/search?search=" + [uri]::EscapeDataString($term)
                    
                    $ytdlpArgs = @(
                        $searchUrl,
                        "--max-downloads", "5",
                        "-f", "bestvideo[height<=1080][ext=mp4]+bestaudio[ext=m4a]/best",
                        "--merge-output-format", "mp4",
                        "-o", "$outputDir/%(title)s-%(id)s.%(ext)s",
                        "--write-thumbnail",
                        "--convert-thumbnails", "jpg",
                        "--write-info-json",
                        "--restrict-filenames",
                        "--no-overwrites",
                        "--download-archive", "public/assets/videos/.download-archive.txt",
                        "--ignore-errors"
                    )
                    
                    if ($CurrentProxy) { $ytdlpArgs += @("--proxy", $CurrentProxy) }
                    
                    & yt-dlp @ytdlpArgs
                    if ($LASTEXITCODE -ne 0) {
                        Write-Host "✗ yt-dlp exited with code $LASTEXITCODE for '$term'" -ForegroundColor Red
                        $skyBriDownloadFailed = $true
                    }
                }
                
                if ($skyBriDownloadFailed) {
                    Write-Host "`n⚠ Sky Bri download finished with errors." -ForegroundColor Yellow
                } else {
                    Write-Host "`n✓ Sky Bri download complete!" -ForegroundColor Green
                }
                Write-Host "`nPress any key to continue..." -ForegroundColor Gray
                $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            }
        }
        
        "7" {
            Write-Host "`n⚡ Quick Download: All PMV Sources" -ForegroundColor Magenta
            Write-Host "   This will download curated PMVs and search results" -ForegroundColor Gray
            $confirm = Read-Host "Continue? (y/n)"
            
            if ($confirm -eq "y") {
                Write-Host "`n🎵 Launching PMV Downloader in AUTO mode..." -ForegroundColor Green
                Start-Sleep -Seconds 1
                
                try {
                    & ".\pmv-downloader.ps1" -Proxy $CurrentProxy
                    if (-not $?) {
                        Write-Host "`n✗ pmv-downloader.ps1 exited with errors (exit code $LASTEXITCODE)" -ForegroundColor Red
                        Read-Host "Press Enter to continue"
                    }
                } catch {
                    Write-Host "`n✗ Exception running pmv-downloader.ps1: $_" -ForegroundColor Red
                    Read-Host "Press Enter to continue"
                }
            }
        }
        
        "8" {
            Write-Host "`n⚡ Quick Download: JOI Games" -ForegroundColor Magenta
            Write-Host "   This will download JOI game content" -ForegroundColor Gray
            $confirm = Read-Host "Continue? (y/n)"
            
            if ($confirm -eq "y") {
                $joiGamesDownloadFailed = $false
                $outputDir = "public/assets/videos/categories/joi_game"
                $searches = @("JOI game", "JOI challenge", "JOI countdown", "interactive JOI")
                
                foreach ($term in $searches) {
                    Write-Host "`n🔍 Searching: $term" -ForegroundColor Cyan
                    
                    $searchUrl = "https://www.pornhub.com/video/search?search=" + [uri]::EscapeDataString($term)
                    
                    $ytdlpArgs = @(
                        $searchUrl,
                        "--max-downloads", "5",
                        "-f", "bestvideo[height<=1080][ext=mp4]+bestaudio[ext=m4a]/best",
                        "--merge-output-format", "mp4",
                        "-o", "$outputDir/%(title)s-%(id)s.%(ext)s",
                        "--write-thumbnail",
                        "--convert-thumbnails", "jpg",
                        "--write-info-json",
                        "--restrict-filenames",
                        "--no-overwrites",
                        "--download-archive", "public/assets/videos/.download-archive.txt",
                        "--ignore-errors"
                    )
                    
                    if ($CurrentProxy) { $ytdlpArgs += @("--proxy", $CurrentProxy) }
                    
                    & yt-dlp @ytdlpArgs
                    if ($LASTEXITCODE -ne 0) {
                        Write-Host "✗ yt-dlp exited with code $LASTEXITCODE for '$term'" -ForegroundColor Red
                        $joiGamesDownloadFailed = $true
                    }
                }
                
                if ($joiGamesDownloadFailed) {
                    Write-Host "`n⚠ JOI Games download finished with errors." -ForegroundColor Yellow
                } else {
                    Write-Host "`n✓ JOI Games download complete!" -ForegroundColor Green
                }
                Write-Host "`nPress any key to continue..." -ForegroundColor Gray
                $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            }
        }
        
        "9" {
            Write-Host "`n🔧 Updating yt-dlp..." -ForegroundColor Cyan
            try {
                & yt-dlp -U
                Write-Host "`n✓ yt-dlp update complete!" -ForegroundColor Green
            } catch {
                Write-Host "`n✗ Update failed. Try: winget upgrade yt-dlp" -ForegroundColor Red
            }
            Write-Host "`nPress any key to continue..." -ForegroundColor Gray
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }
        
        "Q" {
            Write-Host "`n👋 Goodbye!" -ForegroundColor Green
            $running = $false
        }
        
        default {
            Write-Host "`n✗ Invalid option. Please try again." -ForegroundColor Red
            Start-Sleep -Seconds 1
        }
    }
}
