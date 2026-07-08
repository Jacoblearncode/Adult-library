# verify-videos.ps1
# Verifies that public/assets/videos on-disk .mp4 files match master-manifest.json

param(
    [string]$VideoDir = "public/assets/videos"
)

$ErrorActionPreference = 'Stop'

$videoDirPath = Resolve-Path -Path $VideoDir
$root = $videoDirPath.Path
$manifestPath = Join-Path $root "master-manifest.json"

if (-not (Test-Path -Path $manifestPath)) {
    Write-Host "Master manifest not found: $manifestPath" -ForegroundColor Yellow
    Write-Host "Run .\\generate-manifest.ps1 first." -ForegroundColor Yellow
    exit 2
}

$m = Get-Content -Path $manifestPath -Raw | ConvertFrom-Json
$manifestPaths = @($m.videos | ForEach-Object { [string]$_.path })

$diskPaths = Get-ChildItem -Path $root -Recurse -File |
    Where-Object { $_.Extension -ieq '.mp4' -and $_.Name -notmatch '\.(temp|tmp)\.mp4$' } |
    ForEach-Object { ($_.FullName.Replace($root, '') -replace '^[\\/]+','') -replace '\\','/' }

$diskSet = New-Object 'System.Collections.Generic.HashSet[string]'
foreach ($p in $diskPaths) { [void]$diskSet.Add($p) }

$manifestSet = New-Object 'System.Collections.Generic.HashSet[string]'
foreach ($p in $manifestPaths) { if ($p) { [void]$manifestSet.Add($p) } }

$missingInManifest = $diskPaths | Where-Object { -not $manifestSet.Contains($_) }
$extraInManifest = $manifestPaths | Where-Object { $_ -and -not $diskSet.Contains($_) }

Write-Host "Disk mp4 (final): $($diskPaths.Count)"
Write-Host "Manifest entries:  $($manifestPaths.Count)"
Write-Host "Missing in manifest: $($missingInManifest.Count)"
Write-Host "Extra in manifest:   $($extraInManifest.Count)"

if ($missingInManifest.Count -gt 0) {
    Write-Host "\nMissing summary (by top folder):" -ForegroundColor Yellow
    $missingInManifest |
        Group-Object { if ($_ -match '/') { ($_ -split '/')[0] } else { '(root)' } } |
        Sort-Object Count -Descending |
        Select-Object Name,Count |
        Format-Table -AutoSize
}

if ($extraInManifest.Count -gt 0) {
    Write-Host "\nExtra summary (by top folder):" -ForegroundColor Yellow
    $extraInManifest |
        Group-Object { if ($_ -match '/') { ($_ -split '/')[0] } else { '(root)' } } |
        Sort-Object Count -Descending |
        Select-Object Name,Count |
        Format-Table -AutoSize
}

if ($missingInManifest.Count -eq 0 -and $extraInManifest.Count -eq 0) {
    Write-Host "\nOK: master manifest matches disk." -ForegroundColor Green
    exit 0
}

exit 1
