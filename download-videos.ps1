# download-videos-proxy.ps1
# PROXY-ENABLED wrapper for download-videos.ps1
#
# This script loads the proxy configuration and passes it to all download operations.
# It acts as a thin wrapper around the core download logic.

param(
    [string[]]$SearchTerms = @("JOI", "JOI game", "JOI countdown", "JOI instructions"),
    [string]$OutputDir = "public/assets/videos",
    [int]$MaxHeight = 1080,
    [int]$MinPreferredHeight = 720,
    [int]$MaxVideosPerSearch = 5,
    [int]$MaxCandidatesPerSearch = 40,
    [int]$MaxTotalDownloads = 25,
    [string[]]$SearchPlatforms = @("spankbang", "xvideos", "eporner"),
    [switch]$Interactive,
    [switch]$SkipExisting,
    [switch]$AllPlatforms,
    [switch]$UseUrlFile,
    [int]$MaxParallelDownloads = 3,
    [int]$ConcurrentFragments = 4,
    [string]$CookiesFromBrowser = "",
    [string]$Proxy = "",
    [switch]$FastMode,
    [switch]$Simulate,
    [switch]$ShowLogs,
    [switch]$NoManifest
)

# ===== LOAD PROXY CONFIG =====
$_proxyCfg = Join-Path $PSScriptRoot "proxy-config.ps1"
if (Test-Path $_proxyCfg) { 
    . $_proxyCfg 
    if (-not $Proxy -and $ProxyURL) { 
        $Proxy = $ProxyURL 
        if ($Proxy) { Write-Host "✓ Loaded proxy: $Proxy" -ForegroundColor Green }
    }
}

# ===== CONFIGURATION =====
$Categories = @{
    "joi" = @("JOI", "jerk off instruction", "JOI game", "JOI countdown", "JOI challenge")
    "cei" = @("CEI", "cum eating instruction")
    "edging" = @("edging JOI", "edge play", "edging game")
    "countdown" = @("countdown JOI", "cum countdown", "countdown challenge")
    "gentle" = @("gentle JOI", "soft JOI", "sensual JOI")
    "intense" = @("intense JOI", "fast JOI", "hard JOI")
    "pegging" = @("pegging", "strapon", "pegging JOI", "strap-on")
    "rimming" = @("rimjob", "rimming", "rimjob blowjob", "sloppy rimjob", "rim job")
    "lesbian" = @("lesbian", "lesbian JOI", "lesbian kissing", "sloppy kissing", "lesbian instruction")
}

$Platforms = @{
    "pornhub" = @{
        url = "https://www.pornhub.com"
        search = "https://www.pornhub.com/video/search?search={0}"
        enabled = $true
    }
    "xvideos" = @{
        url = "https://www.xvideos.com"
        search = "https://www.xvideos.com/?k={0}"
        enabled = $true
    }
    "spankbang" = @{
        url = "https://spankbang.com"
        search = "https://spankbang.com/s/{0}/"
        enabled = $true
    }
    "xhamster" = @{
        url = "https://xhamster.com"
        search = "https://xhamster.com/search/{0}"
        enabled = $true
    }
    "eporner" = @{
        url = "https://www.eporner.com"
        search = "https://www.eporner.com/search/{0}/"
        enabled = $true
    }
    "redtube" = @{
        url = "https://www.redtube.com"
        search = "https://www.redtube.com/?search={0}"
        enabled = $true
    }
    "youporn" = @{
        url = "https://www.youporn.com"
        search = "https://www.youporn.com/search/?query={0}"
        enabled = $true
    }
    "tube8" = @{
        url = "https://www.tube8.com"
        search = "https://www.tube8.com/searches.html?q={0}"
        enabled = $true
    }
    "hqporner" = @{
        url = "https://hqporner.com"
        search = "https://hqporner.com/?q={0}"
        enabled = $true
    }
    "tnaflix" = @{
        url = "https://www.tnaflix.com"
        search = "https://www.tnaflix.com/search.php?what={0}"
        enabled = $true
    }
}

# ===== RUNTIME STATE =====
$script:DownloadLimitEnabled = $MaxTotalDownloads -gt 0
$script:DownloadedThisRun = 0
$script:DownloadAttemptsThisRun = 0
$script:EffectiveMinPreferredHeight = [Math]::Min($MinPreferredHeight, $MaxHeight)

# ===== FUNCTIONS =====

function Show-Banner {
    Write-Host @"

    ╔═══════════════════════════════════════════════════════════╗
    ║         🎮 JOI Game Video Downloader 🎮                  ║
    ║         Multi-Platform Search & Download Tool             ║
    ║         [PROXY-ENABLED MODE]                             ║
    ║                                                           ║
    ║   Supports: PornHub, XVideos, SpankBang, Eporner,        ║
    ║             XHamster, RedTube, YouPorn, HQPorner...      ║
    ║   Resolution: Up to 1080p (auto-fallback to 720p/best)   ║
    ╚═══════════════════════════════════════════════════════════╝
"@ -ForegroundColor Magenta
}

function Test-YtDlp {
    try {
        $version = yt-dlp --version 2>$null
        Write-Host "✓ yt-dlp version $version found" -ForegroundColor Green 
        return $true
    } catch {
        Write-Host "✗ yt-dlp not found!" -ForegroundColor Red
        Write-Host "  Install with: winget install yt-dlp" -ForegroundColor Yellow
        Write-Host "  Or: pip install yt-dlp" -ForegroundColor Yellow
        return $false
    }
}

function Build-YtDlpArgs {
    param(
        [string[]]$BaseArgs,
        [string]$ProxyURL
    )
    $builtArgs = @($BaseArgs)
    if (-not [string]::IsNullOrWhiteSpace($ProxyURL)) {
        $builtArgs += @("--proxy", $ProxyURL)
    }
    return $builtArgs
}

function Test-IsSuccessfulYtDlpExitCode {
    param([int]$ExitCode)

    # yt-dlp can return 101 when --max-downloads stops playlist processing.
    return ($ExitCode -eq 0 -or $ExitCode -eq 101)
}

function Get-CurrentVideoCount {
    param([string]$Path)

    if (-not (Test-Path $Path)) {
        return 0
    }

    return (Get-ChildItem -Path $Path -File -Filter "*.mp4" -ErrorAction SilentlyContinue | Measure-Object).Count
}

function Get-RemainingDownloadBudget {
    if (-not $script:DownloadLimitEnabled) {
        return [int]::MaxValue
    }

    return [Math]::Max(0, ($MaxTotalDownloads - $script:DownloadedThisRun))
}

function Write-BudgetStatus {
    param([string]$Context = "")

    if (-not $script:DownloadLimitEnabled) {
        if ($Context) {
            Write-Host "[Budget] $Context | Remaining: unlimited" -ForegroundColor DarkGray
        } else {
            Write-Host "[Budget] Remaining: unlimited" -ForegroundColor DarkGray
        }
        return
    }

    $remaining = Get-RemainingDownloadBudget
    if ($Context) {
        Write-Host "[Budget] $Context | Remaining: $remaining / $MaxTotalDownloads" -ForegroundColor DarkGray
    } else {
        Write-Host "[Budget] Remaining: $remaining / $MaxTotalDownloads" -ForegroundColor DarkGray
    }
}

function Update-DownloadCounters {
    param(
        [string]$Path,
        [int]$BeforeCount
    )

    $afterCount = Get-CurrentVideoCount -Path $Path
    $newDownloads = [Math]::Max(0, ($afterCount - $BeforeCount))
    $script:DownloadedThisRun += $newDownloads
    return $newDownloads
}

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("INFO", "SUCCESS", "WARN", "ERROR", "DEBUG")]
        [string]$Level = "INFO"
    )

    if ($Level -eq "DEBUG" -and -not $ShowLogs) {
        return
    }

    $timestamp = Get-Date -Format "HH:mm:ss"
    $prefix = "[$timestamp][$Level]"
    $color = switch ($Level) {
        "SUCCESS" { "Green" }
        "WARN" { "Yellow" }
        "ERROR" { "Red" }
        "DEBUG" { "DarkGray" }
        default { "Cyan" }
    }

    Write-Host "$prefix $Message" -ForegroundColor $color
}

function Download-Video {
    param(
        [string]$URL,
        [string]$OutputDir,
        [int]$MaxHeight = 1080,
        [int]$ConcurrentFragments = 4,
        [string]$CookiesFromBrowser = "",
        [string]$Proxy = ""
    )
    
    if (-not (Test-Path $OutputDir)) {
        New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
    }

    if ((Get-RemainingDownloadBudget) -le 0) {
        Write-Host "Global download limit reached for this run. Skipping URL: $URL" -ForegroundColor Yellow
        return $false
    }

    Write-BudgetStatus -Context "Before direct URL request"
    Write-Log "Starting direct URL download for '$URL' into '$OutputDir'" DEBUG
    
    $archivePath = Join-Path $OutputDir ".download-archive.txt"
    $formatString = "bestvideo[height<=$MaxHeight][height>=$script:EffectiveMinPreferredHeight][ext=mp4]+bestaudio[ext=m4a]/bestvideo[height<=$MaxHeight][height>=$script:EffectiveMinPreferredHeight]+bestaudio/best[height<=$MaxHeight][height>=$script:EffectiveMinPreferredHeight]/bestvideo[height<=$MaxHeight][ext=mp4]+bestaudio[ext=m4a]/bestvideo[height<=$MaxHeight]+bestaudio/best[height<=$MaxHeight]/best"
    $beforeCount = Get-CurrentVideoCount -Path $OutputDir
    $script:DownloadAttemptsThisRun++
    Write-Log "Archive: $archivePath" DEBUG
    Write-Log "Format: $formatString" DEBUG
    
    $ytdlpArgs = @(
        "-f", $formatString,
        "--merge-output-format", "mp4",
        "-o", "$OutputDir/%(title)s-%(id)s.%(ext)s",
        "--write-thumbnail",
        "--convert-thumbnails", "jpg",
        "--write-info-json",
        "--restrict-filenames",
        "--no-overwrites",
        "--continue",
        "--concurrent-fragments", $ConcurrentFragments,
        "--fragment-retries", "5",
        "--download-archive", $archivePath,
        "--progress",
        "--newline",
        "--sleep-interval", "2",
        "--max-sleep-interval", "5",
        "--extractor-retries", "2",
        "--retries", "3",
        "--abort-on-unavailable-fragments",
        "--ignore-errors",
        $URL
    )
    
    if (-not [string]::IsNullOrWhiteSpace($CookiesFromBrowser)) {
        $ytdlpArgs += @("--cookies-from-browser", $CookiesFromBrowser)
    }
    
    if (-not [string]::IsNullOrWhiteSpace($Proxy)) {
        $ytdlpArgs += @("--proxy", $Proxy)
    }
    
    try {
        Write-Log "Invoking yt-dlp for direct URL '$URL'" DEBUG
        & yt-dlp @ytdlpArgs
        if (-not (Test-IsSuccessfulYtDlpExitCode -ExitCode $LASTEXITCODE)) {
            throw "yt-dlp exited with code $LASTEXITCODE"
        }
        $newDownloads = Update-DownloadCounters -Path $OutputDir -BeforeCount $beforeCount
        if ($newDownloads -gt 0) {
            Write-Host "Downloaded $newDownloads new video(s). Total this run: $script:DownloadedThisRun" -ForegroundColor Green
            Write-Log "$newDownloads new video(s) added for direct URL '$URL'" SUCCESS
        }
        return $?
    } catch {
        Write-Host "Error: $_" -ForegroundColor Red
        Write-Log "yt-dlp failed for direct URL '$URL': $_" ERROR
        return $false
    }
}

function Download-FromSearchTerms {
    param(
        [string[]]$SearchTerms,
        [string[]]$PlatsformsToUse,
        [int]$MaxVideos,
        [string]$OutputPath,
        [string]$Proxy = ""
    )
    
    if (-not (Test-Path $OutputPath)) {
        New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
    }

    $archivePath = Join-Path $OutputPath ".download-archive.txt"
    $formatString = "bestvideo[height<=$MaxHeight][height>=$script:EffectiveMinPreferredHeight][ext=mp4]+bestaudio[ext=m4a]/bestvideo[height<=$MaxHeight][height>=$script:EffectiveMinPreferredHeight]+bestaudio/best[height<=$MaxHeight][height>=$script:EffectiveMinPreferredHeight]/bestvideo[height<=$MaxHeight][ext=mp4]+bestaudio[ext=m4a]/bestvideo[height<=$MaxHeight]+bestaudio/best[height<=$MaxHeight]/best"
    
    foreach ($term in $SearchTerms) {
        if ((Get-RemainingDownloadBudget) -le 0) {
            Write-Host "`nReached global download limit for this run. Stopping search." -ForegroundColor Yellow
            break
        }

        Write-Host "`n🔍 Searching: '$term'" -ForegroundColor Cyan
        Write-BudgetStatus -Context "Before search term '$term'"
        Write-Log "Starting search term '$term' for output '$OutputPath'" DEBUG
        
        foreach ($platform in $PlatsformsToUse) {
            if ((Get-RemainingDownloadBudget) -le 0) {
                Write-Host "Reached global download limit for this run. Stopping search." -ForegroundColor Yellow
                break
            }

            if ($Platforms[$platform].enabled) {
                $searchUrl = $Platforms[$platform].search -f [uri]::EscapeDataString($term)
                $remainingBudget = Get-RemainingDownloadBudget
                $downloadCapForThisSearch = [Math]::Min($MaxVideos, $remainingBudget)

                if ($downloadCapForThisSearch -le 0) {
                    Write-Host "Reached global download limit for this run. Stopping search." -ForegroundColor Yellow
                    break
                }

                $searchDepthForThisSearch = [Math]::Max($MaxCandidatesPerSearch, $downloadCapForThisSearch)
                
                Write-Host "   ➜ $platform (depth: $searchDepthForThisSearch, cap: $downloadCapForThisSearch)" -ForegroundColor Yellow
                Write-BudgetStatus -Context "Before $platform request"
                Write-Log "Search URL: $searchUrl" DEBUG
                Write-Log "Candidate depth: $searchDepthForThisSearch; download cap: $downloadCapForThisSearch; archive: $archivePath" DEBUG
                $beforeCount = Get-CurrentVideoCount -Path $OutputPath
                $script:DownloadAttemptsThisRun++
                
                $ytdlpArgs = @(
                    $searchUrl,
                    "--max-downloads", $downloadCapForThisSearch,
                    "--playlist-end", $searchDepthForThisSearch,
                    "-f", $formatString,
                    "--merge-output-format", "mp4",
                    "-o", "$OutputPath/%(title)s-%(id)s.%(ext)s",
                    "--write-thumbnail",
                    "--convert-thumbnails", "jpg",
                    "--write-info-json",
                    "--restrict-filenames",
                    "--no-overwrites",
                    "--continue",
                    "--concurrent-fragments", $ConcurrentFragments,
                    "--fragment-retries", "5",
                    "--retries", "3",
                    "--extractor-retries", "2",
                    "--abort-on-unavailable-fragments",
                    "--download-archive", $archivePath,
                    "--sleep-interval", "2",
                    "--max-sleep-interval", "5",
                    "--ignore-errors"
                )

                if ($Simulate) {
                    $ytdlpArgs += "--simulate"
                }

                if (-not [string]::IsNullOrWhiteSpace($CookiesFromBrowser)) {
                    $ytdlpArgs += @("--cookies-from-browser", $CookiesFromBrowser)
                }
                
                if (-not [string]::IsNullOrWhiteSpace($Proxy)) {
                    $ytdlpArgs += @("--proxy", $Proxy)
                }
                
                try {
                    Write-Log "Invoking yt-dlp for '$term' on '$platform'" DEBUG
                    & yt-dlp @ytdlpArgs
                    if (-not (Test-IsSuccessfulYtDlpExitCode -ExitCode $LASTEXITCODE)) {
                        throw "yt-dlp exited with code $LASTEXITCODE"
                    }
                    $newDownloads = Update-DownloadCounters -Path $OutputPath -BeforeCount $beforeCount
                    if ($newDownloads -gt 0) {
                        Write-Host "      Downloaded $newDownloads new video(s). Total this run: $script:DownloadedThisRun" -ForegroundColor Green
                        Write-Log "$newDownloads new video(s) added for '$term' on '$platform'" SUCCESS
                    }
                } catch {
                    Write-Host "   ✗ Error on $platform : $_" -ForegroundColor Red
                    Write-Log "yt-dlp failed for '$term' on '$platform': $_" ERROR
                }
            }
        }
    }
    
    Write-Host "`n✓ Search complete!" -ForegroundColor Green
}

# ===== MAIN =====

Show-Banner

Write-Log "Detailed logging enabled." DEBUG

if (-not (Test-YtDlp)) { exit 1 }

if ($UseUrlFile -and (Test-Path "urls.txt")) {
    Write-Host "`n📋 Found URLs in urls.txt — downloading..." -ForegroundColor Cyan
    $urls = Get-Content "urls.txt" | Where-Object { $_ -match "^https?://" }
    Write-BudgetStatus -Context "Before URL file batch"

    if ($script:DownloadLimitEnabled) {
        $remainingBudget = Get-RemainingDownloadBudget
        if ($remainingBudget -lt $urls.Count) {
            Write-Host "Global cap active. Limiting URL file batch from $($urls.Count) to $remainingBudget" -ForegroundColor Yellow
            $urls = $urls | Select-Object -First $remainingBudget
        }
    }

    foreach ($url in $urls) {
        Download-Video -URL $url -OutputDir $OutputDir -Proxy $Proxy
    }
} elseif ($Interactive) {
    # Simplified interactive mode
    Write-Host "`n🎬 Interactive Mode" -ForegroundColor Magenta
    $selectedPlatforms = @("pornhub", "spankbang", "xvideos")
    Download-FromSearchTerms -SearchTerms $SearchTerms -PlatsformsToUse $selectedPlatforms -MaxVideos $MaxVideosPerSearch -OutputPath $OutputDir -Proxy $Proxy
} else {
    # Default search
    $selectedPlatforms = if ($AllPlatforms) { $Platforms.Keys | Sort-Object } else { $SearchPlatforms }
    Download-FromSearchTerms -SearchTerms $SearchTerms -PlatsformsToUse $selectedPlatforms -MaxVideos $MaxVideosPerSearch -OutputPath $OutputDir -Proxy $Proxy
}

Write-Host "`n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Green
Write-Host "✓ Downloads saved to: $OutputDir" -ForegroundColor Green
Write-Host "Attempts this run: $script:DownloadAttemptsThisRun" -ForegroundColor Gray
Write-Host "New videos downloaded: $script:DownloadedThisRun" -ForegroundColor Green
if ($script:DownloadLimitEnabled) {
    Write-Host "Global cap: $MaxTotalDownloads | Remaining: $(Get-RemainingDownloadBudget)" -ForegroundColor Yellow
} else {
    Write-Host "Global cap: disabled (unlimited)" -ForegroundColor Yellow
}
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Green

Write-Log "Run complete. Attempts: $script:DownloadAttemptsThisRun; new downloads: $script:DownloadedThisRun; output: $OutputDir" INFO

# Auto-generate manifests if new videos were downloaded (skip in simulate or when NoManifest requested)
if (-not $Simulate -and -not $NoManifest -and $script:DownloadedThisRun -gt 0) {
    $genPath = Join-Path $PSScriptRoot "generate-manifest.ps1"
    if (Test-Path $genPath) {
        Write-Host "\nRegenerating manifests..." -ForegroundColor Cyan
        Write-Log "Regenerating manifests via '$genPath' for '$OutputDir'" DEBUG
        try {
            & $genPath -VideoDir $OutputDir
            Write-Host "✓ Manifest regeneration complete." -ForegroundColor Green
            Write-Log "Manifest regeneration completed for '$OutputDir'" SUCCESS
        } catch {
            Write-Host "✗ Manifest regeneration failed: $_" -ForegroundColor Red
            Write-Log "Manifest regeneration failed for '$OutputDir': $_" ERROR
        }
    } else {
        Write-Host "generate-manifest.ps1 not found; skipping manifest regeneration." -ForegroundColor Yellow
        Write-Log "generate-manifest.ps1 not found at '$genPath'" WARN
    }
}
