# generate-manifest.ps1
# Scans public/assets/videos and all subdirectories for .mp4 files
# Generates manifest.json files for each directory for dynamic loading

param(
    [string]$VideoDir = "public/assets/videos"
)

Write-Host "`n🔍 Scanning for videos in $VideoDir..." -ForegroundColor Cyan

function New-Manifest {
    param([string]$Dir)
    
    $mp4Files = Get-ChildItem -Path $Dir -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Extension -ieq '.mp4' -and $_.Name -notmatch '\.(temp|tmp)\.mp4$' }
    
    if ($mp4Files.Count -gt 0) {
        $manifest = @{
            generatedAt = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
            videos = @($mp4Files | ForEach-Object { $_.Name })
        }
        
        $manifestPath = Join-Path $Dir "manifest.json"
        $manifest | ConvertTo-Json -Depth 3 | Set-Content -Path $manifestPath -Encoding UTF8
        
        Write-Host "  ✓ $Dir - $($mp4Files.Count) videos" -ForegroundColor Green
        return $mp4Files.Count
    }
    return 0
}

# Generate manifest for root and all subdirectories
$totalVideos = 0

# Root directory
$totalVideos += New-Manifest -Dir $VideoDir

# Subdirectories
Get-ChildItem -Path $VideoDir -Directory -ErrorAction SilentlyContinue | ForEach-Object {
    $count = New-Manifest -Dir $_.FullName
    $totalVideos += $count
}

# Also generate a master manifest at root level
$allVideos = @()
Get-ChildItem -Path $VideoDir -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Extension -ieq '.mp4' -and $_.Name -notmatch '\.(temp|tmp)\.mp4$' } |
    ForEach-Object {
    $relativePath = $_.FullName.Replace((Resolve-Path $VideoDir).Path, "").TrimStart("\", "/")
    $relativeDir = Split-Path -Path $relativePath -Parent
    if ($null -eq $relativeDir) { $relativeDir = "" }
    $relativeDir = $relativeDir -replace "\\", "/"
    $relativeDir = ($relativeDir -replace '^[\\/]+', '')
    $allVideos += @{
        filename = $_.Name
        path = $relativePath -replace "\\", "/"
        folder = if ([string]::IsNullOrWhiteSpace($relativeDir)) { "" } else { $relativeDir }
    }
}

$masterManifest = @{
    generatedAt = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    totalVideos = $allVideos.Count
    videos = $allVideos
}

$masterManifestPath = Join-Path $VideoDir "master-manifest.json"
$masterManifest | ConvertTo-Json -Depth 4 | Set-Content -Path $masterManifestPath -Encoding UTF8

Write-Host "`n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Green
Write-Host "✓ Generated manifests for $totalVideos total videos" -ForegroundColor Green
Write-Host "  Master manifest: $masterManifestPath" -ForegroundColor Gray
Write-Host "`nRun 'npm run dev' to see all videos in the game!" -ForegroundColor Yellow
