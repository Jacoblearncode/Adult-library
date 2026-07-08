# download-center.ps1
# Unified entrypoint for all download workflows.

param(
    [ValidateSet("menu", "online", "pmv", "verify", "manifest")]
    [string]$Mode = "menu",
    [string[]]$SearchTerms = @("JOI", "JOI game", "JOI countdown", "JOI instructions"),
    [int]$MaxVideosPerSearch = 5,
    [switch]$AllPlatforms,
    [switch]$UseUrlFile,
    [string[]]$SearchPlatforms = @("spankbang", "xvideos", "eporner"),
    [string]$Proxy = "",
    [string]$CookiesFromBrowser = "",
    [switch]$Simulate,
    [switch]$ShowLogs,
    [switch]$NoManifest
)

$ErrorActionPreference = "Stop"

function Invoke-LocalScript {
    param(
        [string]$ScriptName,
        [hashtable]$Parameters = @{}
    )

    $scriptPath = Join-Path $PSScriptRoot $ScriptName
    if (-not (Test-Path $scriptPath)) {
        throw "Required script not found: $scriptPath"
    }

    & $scriptPath @Parameters
}

function Start-InteractiveMenu {
    while ($true) {
        Clear-Host
        Write-Host ""
        Write-Host "====================================================" -ForegroundColor Cyan
        Write-Host "            JOI GAME DOWNLOAD CONTROL" -ForegroundColor Cyan
        Write-Host "====================================================" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "[1] Online Download (recommended default)" -ForegroundColor Green
        Write-Host "[2] Advanced Category/Pornstar Menu" -ForegroundColor Green
        Write-Host "[3] PMV Downloader" -ForegroundColor Green
        Write-Host "[4] Verify Downloaded Videos" -ForegroundColor Yellow
        Write-Host "[5] Regenerate Manifest" -ForegroundColor Yellow
        Write-Host "[Q] Quit" -ForegroundColor Red
        Write-Host ""

        $choice = Read-Host "Choose an option"
        switch ($choice.ToUpperInvariant()) {
            "1" {
                $dlParams = @{
                    SearchTerms = $SearchTerms
                    MaxVideosPerSearch = $MaxVideosPerSearch
                    SearchPlatforms = $SearchPlatforms
                }
                if ($AllPlatforms) { $dlParams.AllPlatforms = $true }
                if ($UseUrlFile) { $dlParams.UseUrlFile = $true }
                if ($Proxy) { $dlParams.Proxy = $Proxy }
                if ($CookiesFromBrowser) { $dlParams.CookiesFromBrowser = $CookiesFromBrowser }
                if ($Simulate) { $dlParams.Simulate = $true }
                if ($ShowLogs) { $dlParams.ShowLogs = $true }
                if ($NoManifest) { $dlParams.NoManifest = $true }

                Invoke-LocalScript -ScriptName "download-videos.ps1" -Parameters $dlParams
                Read-Host "Press Enter to return to menu" | Out-Null
            }
            "2" {
                $menuParams = @{}
                if ($Proxy) { $menuParams.Proxy = $Proxy }
                if ($CookiesFromBrowser) { $menuParams.CookiesFromBrowser = $CookiesFromBrowser }
                if ($Simulate) { $menuParams.Simulate = $true }
                if ($ShowLogs) { $menuParams.ShowLogs = $true }
                Invoke-LocalScript -ScriptName "download-menu.ps1" -Parameters $menuParams
            }
            "3" {
                $pmvParams = @{}
                if ($Proxy) { $pmvParams.Proxy = $Proxy }
                if ($CookiesFromBrowser) { $pmvParams.CookiesFromBrowser = $CookiesFromBrowser }
                if ($Simulate) { $pmvParams.Simulate = $true }
                if ($ShowLogs) { $pmvParams.ShowLogs = $true }
                if ($NoManifest) { $pmvParams.NoManifest = $true }
                Invoke-LocalScript -ScriptName "pmv-downloader.ps1" -Parameters $pmvParams
                Read-Host "Press Enter to return to menu" | Out-Null
            }
            "4" {
                Invoke-LocalScript -ScriptName "verify-videos.ps1"
                Read-Host "Press Enter to return to menu" | Out-Null
            }
            "5" {
                Invoke-LocalScript -ScriptName "generate-manifest.ps1"
                Read-Host "Press Enter to return to menu" | Out-Null
            }
            "Q" { return }
            default {
                Write-Host "Invalid choice. Try again." -ForegroundColor Red
                Start-Sleep -Milliseconds 700
            }
        }
    }
}

switch ($Mode) {
    "menu" {
        Start-InteractiveMenu
    }
    "online" {
        $dlParams = @{
            SearchTerms = $SearchTerms
            MaxVideosPerSearch = $MaxVideosPerSearch
            SearchPlatforms = $SearchPlatforms
        }
        if ($AllPlatforms) { $dlParams.AllPlatforms = $true }
        if ($UseUrlFile) { $dlParams.UseUrlFile = $true }
        if ($Proxy) { $dlParams.Proxy = $Proxy }
        if ($CookiesFromBrowser) { $dlParams.CookiesFromBrowser = $CookiesFromBrowser }
        if ($Simulate) { $dlParams.Simulate = $true }
        if ($ShowLogs) { $dlParams.ShowLogs = $true }
        if ($NoManifest) { $dlParams.NoManifest = $true }
        Invoke-LocalScript -ScriptName "download-videos.ps1" -Parameters $dlParams
    }
    "pmv" {
        $pmvParams = @{}
        if ($Proxy) { $pmvParams.Proxy = $Proxy }
        if ($CookiesFromBrowser) { $pmvParams.CookiesFromBrowser = $CookiesFromBrowser }
        if ($Simulate) { $pmvParams.Simulate = $true }
        if ($ShowLogs) { $pmvParams.ShowLogs = $true }
        if ($NoManifest) { $pmvParams.NoManifest = $true }
        Invoke-LocalScript -ScriptName "pmv-downloader.ps1" -Parameters $pmvParams
    }
    "verify" {
        Invoke-LocalScript -ScriptName "verify-videos.ps1"
    }
    "manifest" {
        Invoke-LocalScript -ScriptName "generate-manifest.ps1"
    }
}
