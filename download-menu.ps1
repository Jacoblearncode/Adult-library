# download-menu.ps1
# Enhanced menu-driven video downloader with pornstar and category support
#
# SUPPORTED PLATFORMS (14 sites):
#   - Mainstream: PornHub, XVideos, XNXX, SpankBang, XHamster
#   - Network Sites: RedTube, Tube8, YouPorn, EPorner, TXXX
#   - Specialty: Rule34, HypnoTube, PornHat, Beeg
#   - Direct URLs: PMVHaven (add URLs to category direct_urls array)
#
# NOTE: For Patreon/OnlyFans content, you must have a valid subscription.
#       There is no ethical or legal way to bypass paywalls.

param(
    [string]$OutputDir = "public/assets/videos",
    [int]$MaxHeight = 1080,
    [int]$MinPreferredHeight = 720,
    [int]$MaxVideosPerSearch = 10,
    [int]$MaxCandidatesPerSearch = 40,
    [int]$MaxTotalDownloads = 0,
    [int]$MaxParallelDownloads = 3,
    [int]$ConcurrentFragments = 4,
    [string]$CookiesFromBrowser = "",
    [string]$Proxy = "",
    [switch]$Simulate,
    [switch]$ShowLogs
)

# Load proxy config (set $ProxyURL in proxy-config.ps1)
$_proxyCfg = Join-Path $PSScriptRoot "proxy-config.ps1"
if (Test-Path $_proxyCfg) { . $_proxyCfg }
if (-not $Proxy -and $ProxyURL) { $Proxy = $ProxyURL }

# ===== CONFIGURATION =====

# Pornstar profiles with optimized search terms
$Pornstars = @{
    "sky_bri" = @{
        name = "Sky Bri"
        searches = @("Sky Bri", "Sky Bri blowjob", "Sky Bri POV", "Sky Bri JOI")
        platforms = @("pornhub", "spankbang", "xvideos")
    }
    "meana_wolf" = @{
        name = "Meana Wolf"
        searches = @("Meana Wolf", "Meana Wolf JOI", "Meana Wolf mommy", "Meana Wolf taboo")
        platforms = @("pornhub", "spankbang")
    }
    "jewelz_blu" = @{
        name = "Jewelz Blu"
        searches = @("Jewelz Blu blowjob", "Jewelz Blu", "Jewelz Blu POV", "Jewelz Blu deepthroat")
        platforms = @("pornhub", "spankbang", "xvideos")
    }
    "kendra_sunderland" = @{
        name = "Kendra Sunderland"
        searches = @("Kendra Sunderland", "Kendra Sunderland blowjob", "Kendra Sunderland POV")
        platforms = @("pornhub", "spankbang", "xvideos")
    }
    "lena_paul" = @{
        name = "Lena Paul"
        searches = @("Lena Paul", "Lena Paul POV", "Lena Paul blowjob")
        platforms = @("pornhub", "spankbang", "xvideos")
    }
    "gabbie_carter" = @{
        name = "Gabbie Carter"
        searches = @("Gabbie Carter", "Gabbie Carter POV", "Gabbie Carter blowjob")
        platforms = @("pornhub", "spankbang", "xvideos")
    }
    "jessica_starling" = @{
        name = "Jessica Starling"
        searches = @("Jessica Starling", "Jessica Starling JOI", "Jessica Starling CEI")
        platforms = @("pornhub", "spankbang")
    }
    "larkin_love" = @{
        name = "Larkin Love"
        searches = @("Larkin Love", "Larkin Love JOI", "Larkin Love taboo")
        platforms = @("pornhub", "spankbang")
    }
    "alexa_pearl" = @{
        name = "Alexa Pearl"
        searches = @("Alexa Pearl", "Alexa Pearl JOI", "Alexa Pearl blowjob")
        platforms = @("pornhub", "spankbang", "xvideos")
    }
    "dani_daniels" = @{
        name = "Dani Daniels"
        searches = @("Dani Daniels", "Dani Daniels JOI", "Dani Daniels POV")
        platforms = @("pornhub", "spankbang", "xvideos")
    }
    "dainty_wilder" = @{
        name = "Dainty Wilder"
        searches = @("Dainty Wilder", "Dainty Wilder JOI", "Dainty Wilder POV")
        platforms = @("pornhub", "spankbang")
    }
    "lillie_nue" = @{
        name = "Lillie Nue"
        searches = @("Lillie Nue", "Lillie Nue JOI", "Lillie Nue POV")
        platforms = @("pornhub", "spankbang")
    }
    "sweetie_fox" = @{
        name = "Sweetie Fox"
        searches = @("Sweetie Fox", "Sweetie Fox JOI", "Sweetie Fox POV")
        platforms = @("pornhub", "spankbang")
    }
    "wettmelons" = @{
        name = "WettMelons"
        searches = @("WettMelons", "Wettmelons JOI", "Wettmelons PMV")
        platforms = @("pornhub", "spankbang", "eporner")
    }
    "pimpbunny" = @{
        name = "Pimpbunny"
        searches = @("Pimpbunny", "Pimpbunny JOI", "Pimpbunny POV")
        platforms = @("pornhub", "spankbang")
    }
    "tara_tainton" = @{
        name = "Tara Tainton"
        searches = @("Tara Tainton", "Tara Tainton JOI", "Tara Tainton POV")
        platforms = @("pornhub", "spankbang", "xvideos")
    }
}

# Content categories with optimized search terms and direct URLs for reference
$Categories = @{
    "pmv" = @{
        name = "PMV (Porn Music Videos)"
        searches = @("PMV", "PMV compilation", "PMV hypno", "best PMV", "PMV blowjob", "PMV JOI", "eythanol", "pmv eythanol", "eythanol pmv")
        direct_urls = @(
            "https://www.xvideos.com/video.udpkbdfeb95/the_only_pmv_you_ll_ever_need"
        )
        platforms = @("pornhub", "spankbang", "xvideos")
    }
    "pmv_joi_challenges" = @{ # New category for PMV JOI action-based challenges with direct URLs
        name = "PMV JOI Challenges (Action-Based)"
        searches = @("PMV JOI challenge", "PMV goonstick", "PMV instructions", "PMV metronome", "PMV stroke challenge")
        direct_urls = @(
            "https://pmvhaven.com/video/pmv-challenge_6877a052e3e9e8f256d4d462",
            "https://pmvhaven.com/video/pmv-goonstick_6980ee229a0480cbe7170221",
            "https://pmvhaven.com/video/pmv-goonstick_698b4bcd60a6c357a0855f8e"
        )
        platforms = @("pornhub", "spankbang", "xvideos")
    }
    "futa_oral" = @{ # New category for Futanari oral content with optimized search terms
        name = "Futa Oral/Blowjob"
        searches = @("futa oral", "futa blowjob", "futa POV", "futa deepthroat", "futanari blowjob")
        platforms = @("pornhub", "spankbang", "xvideos")
    }
    "joi_game" = @{
        name = "JOI Games & Interactive"
        searches = @("JOI game", "JOI challenge", "JOI countdown", "interactive JOI", "JOI instructions", "joi")
        platforms = @("pornhub", "spankbang", "xvideos")
    }
    "cei" = @{
        name = "CEI (Cum Eating Instructions)"
        searches = @("CEI", "cum eating instruction", "CEI JOI", "femdom CEI")
        platforms = @("pornhub", "spankbang")
    }
    "ahegao" = @{
        name = "Ahegao/Egirl"
        searches = @("ahegao", "egirl JOI", "ahegao blowjob", "ahegao POV")
        platforms = @("pornhub", "spankbang", "xvideos")
    }
    "3d_hentai" = @{
        name = "3D Hentai/Animated"
        searches = @("3D hentai", "3D compilation", "3D porn", "3D animation", "hentai 3D POV")
        platforms = @("pornhub", "spankbang", "xvideos")
    }
    "blowjob" = @{
        name = "Blowjob Compilation"
        searches = @("blowjob compilation", "deepthroat", "POV blowjob", "sloppy blowjob")
        platforms = @("pornhub", "spankbang", "xvideos")
    }
    "edging" = @{
        name = "Edging & Tease"
        searches = @("edging JOI", "tease and denial", "edging game", "edge challenge")
        platforms = @("pornhub", "spankbang")
    }
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
    "xnxx" = @{
        url = "https://www.xnxx.com"
        search = "https://www.xnxx.com/search/{0}"
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
    "redtube" = @{
        url = "https://www.redtube.com"
        search = "https://www.redtube.com/?search={0}"
        enabled = $true
    }
    "tube8" = @{
        url = "https://www.tube8.com"
        search = "https://www.tube8.com/searches.html?q={0}"
        enabled = $true
    }
    "youporn" = @{
        url = "https://www.youporn.com"
        search = "https://www.youporn.com/search/?query={0}"
        enabled = $true
    }
    "eporner" = @{
        url = "https://www.eporner.com"
        search = "https://www.eporner.com/search/{0}/"
        enabled = $true
    }
    "rule34" = @{
        url = "https://rule34.xxx"
        search = "https://rule34.xxx/index.php?page=post&s=list&tags={0}"
        enabled = $true
    }
    "hypnotube" = @{
        url = "https://hypnotube.com"
        search = "https://hypnotube.com/search/{0}/"
        enabled = $true
    }
    "txxx" = @{
        url = "https://www.txxx.com"
        search = "https://www.txxx.com/search/{0}/"
        enabled = $true
    }
    "pornhat" = @{
        url = "https://www.pornhat.com"
        search = "https://www.pornhat.com/search/{0}/"
        enabled = $true
    }
    "beeg" = @{
        url = "https://beeg.com"
        search = "https://beeg.com/section/search/{0}/"
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
    Clear-Host
    Write-Host ""
    Write-Host "  ===================================================================" -ForegroundColor Magenta
    Write-Host "          ENHANCED JOI GAME VIDEO DOWNLOADER" -ForegroundColor Magenta
    Write-Host "           Pornstar & Category-Based Download System" -ForegroundColor Magenta
    Write-Host "  ===================================================================" -ForegroundColor Magenta
    Write-Host ""
    Write-Host "  Features:" -ForegroundColor Yellow
    Write-Host "    - Download by Pornstar (Sky Bri, Meana Wolf, etc.)" -ForegroundColor Gray
    Write-Host "    - Download by Category (PMV, Futa, JOI Games, etc.)" -ForegroundColor Gray
    Write-Host "    - Direct URL support (PMVHaven, etc.)" -ForegroundColor Gray
    Write-Host "    - 14+ Platforms: PornHub, XVideos, XNXX, SpankBang," -ForegroundColor Gray
    Write-Host "      RedTube, Tube8, YouPorn, Rule34, HypnoTube, Beeg..." -ForegroundColor Gray
    Write-Host ""
}

function Test-YtDlp {
    try {
        $version = yt-dlp --version 2>$null
        Write-Host "  yt-dlp version $version found" -ForegroundColor Green 
        return $true
    } catch {
        Write-Host "ERROR: yt-dlp not found!" -ForegroundColor Red
        Write-Host "  Install with: winget install yt-dlp" -ForegroundColor Yellow
        Write-Host "  Or: pip install yt-dlp" -ForegroundColor Yellow
        return $false
    }
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
            Write-Host "  [Budget] $Context | Remaining: unlimited" -ForegroundColor DarkGray
        } else {
            Write-Host "  [Budget] Remaining: unlimited" -ForegroundColor DarkGray
        }
        return
    }

    $remaining = Get-RemainingDownloadBudget
    if ($Context) {
        Write-Host "  [Budget] $Context | Remaining: $remaining / $MaxTotalDownloads" -ForegroundColor DarkGray
    } else {
        Write-Host "  [Budget] Remaining: $remaining / $MaxTotalDownloads" -ForegroundColor DarkGray
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

function Show-MainMenu {
    Write-Host ""
    Write-Host "  ======================= MAIN MENU =======================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  [1] Download by Pornstar" -ForegroundColor Cyan
    Write-Host "  [2] Download by Category" -ForegroundColor Cyan
    Write-Host "  [3] Download from Direct URLs" -ForegroundColor Cyan
    Write-Host "  [4] Download from URL File (urls.txt)" -ForegroundColor Cyan
    Write-Host "  [5] Custom Search" -ForegroundColor Cyan
    Write-Host "  [6] Settings" -ForegroundColor Cyan
    Write-Host "  [Q] Quit" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  =========================================================" -ForegroundColor Cyan
    Write-Host ""
}

function Show-PornstarMenu {
    Write-Host ""
    Write-Host "  ============== SELECT PORNSTAR ==============" -ForegroundColor Yellow
    Write-Host "" -ForegroundColor Yellow
    
    $index = 1
    $pornstarList = @()
    foreach ($key in $Pornstars.Keys | Sort-Object) {
        $star = $Pornstars[$key]
        $pornstarList += $key
        Write-Host ("  [{0}] {1}" -f $index, $star.name) -ForegroundColor Yellow
        $index++
    }
    
    Write-Host "" -ForegroundColor Yellow
    Write-Host "  [A] Download ALL Pornstars" -ForegroundColor Green
    Write-Host "  [B] Back to Main Menu" -ForegroundColor Red
    Write-Host "" -ForegroundColor Yellow
    Write-Host "  =============================================" -ForegroundColor Yellow
    Write-Host ""
    
    return $pornstarList
}

function Show-CategoryMenu {
    Write-Host ""
    Write-Host "  ============== SELECT CATEGORY ==============" -ForegroundColor Cyan
    Write-Host "" -ForegroundColor Cyan
    
    $index = 1
    $categoryList = @()
    foreach ($key in $Categories.Keys | Sort-Object) {
        $cat = $Categories[$key]
        $categoryList += $key
        Write-Host ("  [{0}] {1}" -f $index, $cat.name) -ForegroundColor Cyan
        $index++
    }
    
    Write-Host "" -ForegroundColor Cyan
    Write-Host "  [A] Download ALL Categories" -ForegroundColor Green
    Write-Host "  [B] Back to Main Menu" -ForegroundColor Red
    Write-Host "" -ForegroundColor Cyan
    Write-Host "  =============================================" -ForegroundColor Cyan
    Write-Host ""
    
    return $categoryList
}

function Get-DownloadSettings {
    Write-Host ""
    Write-Host "  --- Download Settings ---" -ForegroundColor Yellow
    
    $maxVids = Read-Host "Max videos per search (current: $MaxVideosPerSearch)"
    if ($maxVids) { $script:MaxVideosPerSearch = [int]$maxVids }

    $maxCandidates = Read-Host "Search depth / candidates per search (current: $MaxCandidatesPerSearch)"
    if ($maxCandidates) { $script:MaxCandidatesPerSearch = [int]$maxCandidates }

    $maxTotal = Read-Host "Global download cap per run (0 = unlimited, current: $MaxTotalDownloads)"
    if ($maxTotal -ne "") {
        $script:MaxTotalDownloads = [int]$maxTotal
        $script:DownloadLimitEnabled = $script:MaxTotalDownloads -gt 0
    }

    $minPreferred = Read-Host "Preferred minimum resolution (current: $MinPreferredHeight)"
    if ($minPreferred) {
        $script:MinPreferredHeight = [int]$minPreferred
    }
    
    $maxHeight = Read-Host "Max resolution (480/720/1080, current: $MaxHeight)"
    if ($maxHeight) { $script:MaxHeight = [int]$maxHeight }

    $script:EffectiveMinPreferredHeight = [Math]::Min($script:MinPreferredHeight, $script:MaxHeight)
    
    $parallel = Read-Host "Parallel downloads (1-5, current: $MaxParallelDownloads)"
    if ($parallel) { $script:MaxParallelDownloads = [int]$parallel }
    
    Write-Host "  Settings updated!" -ForegroundColor Green
    Start-Sleep -Seconds 1
}

function Download-FromSearchTerms {
    param(
        [string[]]$SearchTerms,
        [string[]]$Platforms,
        [int]$MaxVideos,
        [string]$OutputSubDir = ""
    )
    
    $outputPath = if ($OutputSubDir) { Join-Path $OutputDir $OutputSubDir } else { $OutputDir }
    
    if (-not (Test-Path $outputPath)) {
        New-Item -ItemType Directory -Path $outputPath -Force | Out-Null
    }
    
    $archivePath = Join-Path $OutputDir ".download-archive.txt"
    
    Write-Host "" 
    Write-Host "  >> Starting download..." -ForegroundColor Green
    Write-Host "   Output: $outputPath" -ForegroundColor Gray
    Write-Host "   Terms: $($SearchTerms -join ', ')" -ForegroundColor Gray
    Write-Host "   Platforms: $($Platforms -join ', ')" -ForegroundColor Gray
    Write-Host ""
    Write-Log "Starting search batch for output '$outputPath'" DEBUG
    Write-Log "Search terms: $($SearchTerms -join ', ')" DEBUG
    Write-Log "Platforms: $($Platforms -join ', ')" DEBUG

    $formatString = "bestvideo[height<=$MaxHeight][height>=$script:EffectiveMinPreferredHeight][ext=mp4]+bestaudio[ext=m4a]/bestvideo[height<=$MaxHeight][height>=$script:EffectiveMinPreferredHeight]+bestaudio/best[height<=$MaxHeight][height>=$script:EffectiveMinPreferredHeight]/bestvideo[height<=$MaxHeight][ext=mp4]+bestaudio[ext=m4a]/bestvideo[height<=$MaxHeight]+bestaudio/best[height<=$MaxHeight]/best"

    foreach ($term in $SearchTerms) {
        if ((Get-RemainingDownloadBudget) -le 0) {
            Write-Host "  Reached global download limit for this run. Stopping search batch." -ForegroundColor Yellow
            break
        }

        Write-Host "  Searching for: '$term'..." -ForegroundColor Cyan
        Write-BudgetStatus -Context "Before search term '$term'"

        foreach ($platform in $Platforms) {
            if ((Get-RemainingDownloadBudget) -le 0) {
                Write-Host "  Reached global download limit for this run. Stopping search batch." -ForegroundColor Yellow
                break
            }

            if ($Platforms -contains $platform -and $script:Platforms[$platform].enabled) {
                $searchUrl = $script:Platforms[$platform].search -f [uri]::EscapeDataString($term)
                $remainingBudget = Get-RemainingDownloadBudget
                $downloadCapForThisSearch = [Math]::Min($MaxVideos, $remainingBudget)

                if ($downloadCapForThisSearch -le 0) {
                    Write-Host "  Reached global download limit for this run. Stopping search batch." -ForegroundColor Yellow
                    break
                }

                $searchDepthForThisSearch = [Math]::Max($MaxCandidatesPerSearch, $downloadCapForThisSearch)

                Write-Host "   -> $platform : $searchUrl" -ForegroundColor Yellow
                Write-Host "      Candidate depth: $searchDepthForThisSearch | Download cap: $downloadCapForThisSearch" -ForegroundColor DarkGray
                Write-BudgetStatus -Context "Before $platform request"
                Write-Log "Search URL: $searchUrl" DEBUG
                Write-Log "Candidate depth: $searchDepthForThisSearch; download cap: $downloadCapForThisSearch; archive: $archivePath" DEBUG

                $beforeCount = Get-CurrentVideoCount -Path $outputPath
                $script:DownloadAttemptsThisRun++

                $ytdlpArgs = @(
                    $searchUrl,
                    "--max-downloads", $downloadCapForThisSearch,
                    "--playlist-end", $searchDepthForThisSearch,
                    "-f", $formatString,
                    "--merge-output-format", "mp4",
                    "-o", "$outputPath/%(title)s-%(id)s.%(ext)s",
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
                    "--ignore-errors",
                    "--sleep-interval", "2",
                    "--max-sleep-interval", "5"
                )

                if ($Simulate) { $ytdlpArgs += "--simulate" }
                if ($CookiesFromBrowser) { $ytdlpArgs += @("--cookies-from-browser", $CookiesFromBrowser) }
                if ($Proxy) { $ytdlpArgs += @("--proxy", $Proxy) }

                try {
                    Write-Log "Invoking yt-dlp for search term '$term' on '$platform'" DEBUG
                    & yt-dlp @ytdlpArgs
                        if ($LASTEXITCODE -ne 0) {
                            throw "yt-dlp exited with code $LASTEXITCODE"
                        }
                    $newDownloads = Update-DownloadCounters -Path $outputPath -BeforeCount $beforeCount
                    if ($newDownloads -gt 0) {
                        Write-Host "      Downloaded $newDownloads new video(s). Total this run: $script:DownloadedThisRun" -ForegroundColor Green
                        Write-Log "$newDownloads new video(s) added for '$term' on '$platform'" SUCCESS
                    }
                } catch {
                    $errMsg = $_ | Out-String
                    Write-Host ("   ERROR on {0}: {1}" -f $platform, $errMsg) -ForegroundColor Red
                    Write-Log ("yt-dlp failed for '{0}' on '{1}': {2}" -f $term, $platform, $errMsg) ERROR
                }
            }
        }
    }
    
    Write-Host "  Download batch complete!" -ForegroundColor Green
}

function Download-FromDirectURLs {
    param(
        [string[]]$URLs,
        [string]$OutputSubDir = ""
    )
    
    $outputPath = if ($OutputSubDir) { Join-Path $OutputDir $OutputSubDir } else { $OutputDir }
    
    if (-not (Test-Path $outputPath)) {
        New-Item -ItemType Directory -Path $outputPath -Force | Out-Null
    }
    
    $archivePath = Join-Path $OutputDir ".download-archive.txt"
    $formatString = "bestvideo[height<=$MaxHeight][height>=$script:EffectiveMinPreferredHeight][ext=mp4]+bestaudio[ext=m4a]/bestvideo[height<=$MaxHeight][height>=$script:EffectiveMinPreferredHeight]+bestaudio/best[height<=$MaxHeight][height>=$script:EffectiveMinPreferredHeight]/bestvideo[height<=$MaxHeight][ext=mp4]+bestaudio[ext=m4a]/bestvideo[height<=$MaxHeight]+bestaudio/best[height<=$MaxHeight]/best"
    
    Write-Host ""
    Write-Host "  >> Downloading from direct URLs..." -ForegroundColor Green
    Write-BudgetStatus -Context "Before direct URL batch"
    Write-Log "Starting direct URL batch for output '$outputPath'" DEBUG

    $remainingBudget = Get-RemainingDownloadBudget
    if ($remainingBudget -le 0) {
        Write-Host "  Global download limit reached for this run. Skipping direct URLs." -ForegroundColor Yellow
        return
    }

    if ($script:DownloadLimitEnabled -and $URLs.Count -gt $remainingBudget) {
        Write-Host "  Limiting direct URL batch from $($URLs.Count) to $remainingBudget due to global cap." -ForegroundColor Yellow
        $URLs = $URLs | Select-Object -First $remainingBudget
    }
    
    foreach ($url in $URLs) {
        if ((Get-RemainingDownloadBudget) -le 0) {
            Write-Host "  Reached global download limit for this run. Stopping direct URL batch." -ForegroundColor Yellow
            break
        }

        Write-Host "   -> $url" -ForegroundColor Cyan
        Write-BudgetStatus -Context "Before direct URL request"
        Write-Log "Direct URL target: $url" DEBUG
        $beforeCount = Get-CurrentVideoCount -Path $outputPath
        $script:DownloadAttemptsThisRun++
        
        $ytdlpArgs = @(
            $url,
            "-f", $formatString,
            "--merge-output-format", "mp4",
            "-o", "$outputPath/%(title)s-%(id)s.%(ext)s",
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
            "--ignore-errors"
        )
        
        if ($Simulate) { $ytdlpArgs += "--simulate" }
        if ($CookiesFromBrowser) { $ytdlpArgs += @("--cookies-from-browser", $CookiesFromBrowser) }
        if ($Proxy) { $ytdlpArgs += @("--proxy", $Proxy) }
        
        try {
            Write-Log "Invoking yt-dlp for direct URL $url" DEBUG
            & yt-dlp @ytdlpArgs
                if ($LASTEXITCODE -ne 0) {
                    throw "yt-dlp exited with code $LASTEXITCODE"
                }
            $newDownloads = Update-DownloadCounters -Path $outputPath -BeforeCount $beforeCount
            if ($newDownloads -gt 0) {
                Write-Host "      Downloaded $newDownloads new video(s). Total this run: $script:DownloadedThisRun" -ForegroundColor Green
                Write-Log "$newDownloads new video(s) added for direct URL $url" SUCCESS
            }
        } catch {
            $errMsg = $_ | Out-String
            Write-Host "   ✗ Error: $errMsg" -ForegroundColor Red
            Write-Log ("yt-dlp failed for direct URL {0}: {1}" -f $url, $errMsg) ERROR
        }
    }
    
    Write-Host "`n✓ Direct URL downloads complete!" -ForegroundColor Green
}

function Download-FromUrlFile {
    param([string]$FilePath = "urls.txt")
    
    if (-not (Test-Path $FilePath)) {
        Write-Host "ERROR: File not found: $FilePath" -ForegroundColor Red
        return
    }
    
    $urls = Get-Content $FilePath | Where-Object { $_ -match "^https?://" }
    
    if ($urls.Count -eq 0) {
        Write-Host "ERROR: No valid URLs found in $FilePath" -ForegroundColor Red
        return
    }
    
    Write-Host "Found $($urls.Count) URLs in $FilePath" -ForegroundColor Green
    Download-FromDirectURLs -URLs $urls
}

# ===== MAIN PROGRAM =====

Show-Banner

if (-not (Test-YtDlp)) {
    Write-Host "`nPlease install yt-dlp first!" -ForegroundColor Red
    exit 1
}

$running = $true

while ($running) {
    Show-MainMenu
    $choice = Read-Host "Select an option"
    
    switch ($choice) {
        "1" {
            # Pornstar selection with back navigation
            while ($true) {
                $pornstarList = Show-PornstarMenu
                $selection = (Read-Host "Select pornstar (1-$($pornstarList.Count), A, or B)").Trim().ToUpper()

                if ($selection -eq "B") { break }

                if ($selection -eq "A") {
                    Write-Host "  WARNING: This will download videos from ALL pornstars!" -ForegroundColor Yellow
                    Write-Host "  [Y] Start download" -ForegroundColor Green
                    Write-Host "  [B] Back" -ForegroundColor Red
                    $confirm = (Read-Host "Choice").Trim().ToUpper()
                    if ($confirm -eq "B") { continue }
                    if ($confirm -ne "Y") {
                        Write-Host "  Cancelled. Returning to pornstar menu..." -ForegroundColor Yellow
                        Start-Sleep -Seconds 1
                        continue
                    }

                    foreach ($key in $Pornstars.Keys) {
                        $star = $Pornstars[$key]
                        Write-Host ""
                        Write-Host "  ======================================" -ForegroundColor Magenta
                        Write-Host "  Downloading: $($star.name)" -ForegroundColor Magenta
                        Write-Host "  ======================================" -ForegroundColor Magenta
                        Download-FromSearchTerms -SearchTerms $star.searches -Platforms $star.platforms -MaxVideos $MaxVideosPerSearch -OutputSubDir "pornstars/$key"
                    }

                    Write-Host "`n`nPress any key to continue..." -ForegroundColor Gray
                    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                    break
                }

                [int]$parsedSelection = 0
                if ([int]::TryParse($selection, [ref]$parsedSelection)) {
                    $index = $parsedSelection - 1
                    if ($index -ge 0 -and $index -lt $pornstarList.Count) {
                        $key = $pornstarList[$index]
                        $star = $Pornstars[$key]

                        Write-Host ""
                        Write-Host "  Selected: $($star.name)" -ForegroundColor Magenta
                        Write-Host "  [Y] Start download" -ForegroundColor Green
                        Write-Host "  [B] Back" -ForegroundColor Red
                        $confirm = (Read-Host "Choice").Trim().ToUpper()
                        if ($confirm -eq "B") { continue }
                        if ($confirm -ne "Y") {
                            Write-Host "  Cancelled. Returning to pornstar menu..." -ForegroundColor Yellow
                            Start-Sleep -Seconds 1
                            continue
                        }

                        Write-Host ""
                        Write-Host "  ======================================" -ForegroundColor Magenta
                        Write-Host "  Downloading: $($star.name)" -ForegroundColor Magenta
                        Write-Host "  ======================================" -ForegroundColor Magenta
                        Download-FromSearchTerms -SearchTerms $star.searches -Platforms $star.platforms -MaxVideos $MaxVideosPerSearch -OutputSubDir "pornstars/$key"

                        Write-Host "`n`nPress any key to continue..." -ForegroundColor Gray
                        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                        break
                    }
                }

                Write-Host "  Invalid option. Please try again." -ForegroundColor Red
                Start-Sleep -Seconds 1
            }
        }
        
        "2" {
            # Category selection with back navigation
            while ($true) {
                $categoryList = Show-CategoryMenu
                $selection = (Read-Host "Select category (1-$($categoryList.Count), A, or B)").Trim().ToUpper()

                if ($selection -eq "B") { break }

                if ($selection -eq "A") {
                    Write-Host "  WARNING: This will download videos from ALL categories!" -ForegroundColor Yellow
                    Write-Host "  [Y] Start download" -ForegroundColor Green
                    Write-Host "  [B] Back" -ForegroundColor Red
                    $confirm = (Read-Host "Choice").Trim().ToUpper()
                    if ($confirm -eq "B") { continue }
                    if ($confirm -ne "Y") {
                        Write-Host "  Cancelled. Returning to category menu..." -ForegroundColor Yellow
                        Start-Sleep -Seconds 1
                        continue
                    }

                    foreach ($key in $Categories.Keys) {
                        $cat = $Categories[$key]
                        Write-Host ""
                        Write-Host "  ======================================" -ForegroundColor Cyan
                        Write-Host "  Downloading: $($cat.name)" -ForegroundColor Cyan
                        Write-Host "  ======================================" -ForegroundColor Cyan

                        # Download from searches
                        Download-FromSearchTerms -SearchTerms $cat.searches -Platforms $cat.platforms -MaxVideos $MaxVideosPerSearch -OutputSubDir "categories/$key"

                        # Download direct URLs if any
                        if ($cat.direct_urls -and $cat.direct_urls.Count -gt 0) {
                            Download-FromDirectURLs -URLs $cat.direct_urls -OutputSubDir "categories/$key"
                        }
                    }

                    Write-Host "`n`nPress any key to continue..." -ForegroundColor Gray
                    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                    break
                }

                [int]$parsedSelection = 0
                if ([int]::TryParse($selection, [ref]$parsedSelection)) {
                    $index = $parsedSelection - 1
                    if ($index -ge 0 -and $index -lt $categoryList.Count) {
                        $key = $categoryList[$index]
                        $cat = $Categories[$key]

                        Write-Host ""
                        Write-Host "  Selected: $($cat.name)" -ForegroundColor Cyan
                        Write-Host "  [Y] Start download" -ForegroundColor Green
                        Write-Host "  [B] Back" -ForegroundColor Red
                        $confirm = (Read-Host "Choice").Trim().ToUpper()
                        if ($confirm -eq "B") { continue }
                        if ($confirm -ne "Y") {
                            Write-Host "  Cancelled. Returning to category menu..." -ForegroundColor Yellow
                            Start-Sleep -Seconds 1
                            continue
                        }

                        Write-Host "`n════════════════════════════════════════" -ForegroundColor Cyan
                        Write-Host "  Downloading: $($cat.name)" -ForegroundColor Cyan
                        Write-Host "════════════════════════════════════════" -ForegroundColor Cyan

                        # Download from searches
                        Download-FromSearchTerms -SearchTerms $cat.searches -Platforms $cat.platforms -MaxVideos $MaxVideosPerSearch -OutputSubDir "categories/$key"

                        # Download direct URLs if any
                        if ($cat.direct_urls -and $cat.direct_urls.Count -gt 0) {
                            Download-FromDirectURLs -URLs $cat.direct_urls -OutputSubDir "categories/$key"
                        }

                        Write-Host "`n`nPress any key to continue..." -ForegroundColor Gray
                        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                        break
                    }
                }

                Write-Host "  Invalid option. Please try again." -ForegroundColor Red
                Start-Sleep -Seconds 1
            }
        }
        
        "3" {
            # Direct URLs
            Write-Host ""
            Write-Host "  Enter video URLs (one per line, empty line to finish):" -ForegroundColor Cyan
            $urls = @()
            while ($true) {
                $url = Read-Host "URL"
                if ([string]::IsNullOrWhiteSpace($url)) { break }
                $urls += $url.Trim()
            }
            
            if ($urls.Count -gt 0) {
                Download-FromDirectURLs -URLs $urls
                Write-Host "`n`nPress any key to continue..." -ForegroundColor Gray
                $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            }
        }
        
        "4" {
            # From URL file
            Download-FromUrlFile -FilePath "urls.txt"
            Write-Host "`n`nPress any key to continue..." -ForegroundColor Gray
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }
        
        "5" {
            # Custom search with step-back options
            while ($true) {
                Write-Host ""
                Write-Host "  Custom Search" -ForegroundColor Cyan
                Write-Host "  Type B to go back at any step." -ForegroundColor Gray
                $customTerms = Read-Host "Enter search terms (comma-separated)"

                if ([string]::IsNullOrWhiteSpace($customTerms)) {
                    Write-Host "  Search terms cannot be empty." -ForegroundColor Red
                    Start-Sleep -Seconds 1
                    continue
                }

                if ($customTerms.Trim().ToUpper() -eq "B") { break }

                $terms = $customTerms -split "," | ForEach-Object { $_.Trim() } | Where-Object { $_ }

                while ($true) {
                    $platformChoice = (Read-Host "Platforms (1=pornhub, 2=xvideos, 3=spankbang, A=all, B=back, comma-separated)").Trim().ToUpper()

                    if ($platformChoice -eq "B") { break }

                    $selectedPlatforms = @()
                    if ($platformChoice -eq "A") {
                        $selectedPlatforms = @("pornhub", "xvideos", "spankbang")
                    }
                    else {
                        $platformMap = @{ "1" = "pornhub"; "2" = "xvideos"; "3" = "spankbang" }
                        foreach ($p in ($platformChoice -split ",")) {
                            $trimmed = $p.Trim()
                            if ($platformMap.ContainsKey($trimmed)) {
                                $selectedPlatforms += $platformMap[$trimmed]
                            }
                        }
                    }

                    $selectedPlatforms = $selectedPlatforms | Select-Object -Unique
                    if ($selectedPlatforms.Count -eq 0) {
                        Write-Host "  Invalid platform selection. Try again or enter B to go back." -ForegroundColor Red
                        continue
                    }

                    Write-Host "  [Y] Start download" -ForegroundColor Green
                    Write-Host "  [B] Back" -ForegroundColor Red
                    $confirm = (Read-Host "Choice").Trim().ToUpper()
                    if ($confirm -eq "B") { continue }
                    if ($confirm -ne "Y") {
                        Write-Host "  Cancelled. Returning to custom search menu..." -ForegroundColor Yellow
                        Start-Sleep -Seconds 1
                        continue
                    }

                    Download-FromSearchTerms -SearchTerms $terms -Platforms $selectedPlatforms -MaxVideos $MaxVideosPerSearch -OutputSubDir "custom"
                    Write-Host "`n`nPress any key to continue..." -ForegroundColor Gray
                    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                    break
                }

                break
            }
        }
        
        "6" {
            # Settings
            Get-DownloadSettings
        }
        
        "Q" {
            Write-Host "  Goodbye!" -ForegroundColor Green
            $running = $false
        }
        
        default {
            Write-Host "  Invalid option. Please try again." -ForegroundColor Red
            Start-Sleep -Seconds 1
        }
    }
}

Write-Host ""
Write-Host "  ================= Download Summary ================" -ForegroundColor Cyan
Write-Host "  Download attempts this run: $script:DownloadAttemptsThisRun" -ForegroundColor Gray
Write-Host "  New videos downloaded: $script:DownloadedThisRun" -ForegroundColor Green
if ($script:DownloadLimitEnabled) {
    Write-Host "  Global cap: $MaxTotalDownloads | Remaining: $(Get-RemainingDownloadBudget)" -ForegroundColor Yellow
} else {
    Write-Host "  Global cap: disabled (unlimited)" -ForegroundColor Yellow
}
Write-Host "  ================================================" -ForegroundColor Cyan
# Auto-generate manifests if new videos were downloaded (skip in simulate)
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
            $errMsg = $_ | Out-String
            Write-Host ("✗ Manifest regeneration failed: {0}" -f $errMsg) -ForegroundColor Red
            Write-Log ("Manifest regeneration failed for '{0}': {1}" -f $OutputDir, $errMsg) ERROR
        }
    } else {
        Write-Host "generate-manifest.ps1 not found; skipping manifest regeneration." -ForegroundColor Yellow
        Write-Log "generate-manifest.ps1 not found at '$genPath'" WARN
    }
}
