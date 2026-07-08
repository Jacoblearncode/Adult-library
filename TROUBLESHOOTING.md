# 🔧 TROUBLESHOOTING GUIDE

## Common Issues and Solutions

### 1. "yt-dlp not found" Error

**Problem**: The script says yt-dlp is not installed or not found.

**Solutions**:
```powershell
# Try these in order:

# Option 1: Install via winget (recommended)
winget install yt-dlp

# Option 2: Install via pip
pip install yt-dlp

# Option 3: Install via scoop
scoop install yt-dlp

# Option 4: Download manually
# Visit: https://github.com/yt-dlp/yt-dlp/releases
# Download yt-dlp.exe and place it in your PATH
```

**Verify installation**:
```powershell
yt-dlp --version
```

---

### 2. Downloads Failing / Access Denied

**Problem**: Videos fail to download with "access denied" or "not available" errors.

**Solutions**:
```powershell
# Option 1: Use browser cookies (most effective)
.\download-menu.ps1 -CookiesFromBrowser "chrome"
# or "firefox", "edge", "safari"

# Option 2: Update yt-dlp
yt-dlp -U
# or
winget upgrade yt-dlp

# Option 3: Try a different platform
# If Pornhub fails, try XVideos or SpankBang
```

---

### 3. "Script Execution Disabled" Error

**Problem**: PowerShell says scripts are disabled.

**Solution**:
```powershell
# Run PowerShell as Administrator, then:
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser

# Or run the script with bypass:
powershell -ExecutionPolicy Bypass -File .\launcher.ps1
```

---

### 4. Downloads Are Very Slow

**Problem**: Downloads are taking too long.

**Solutions**:
```powershell
# Option 1: Reduce parallel downloads
.\download-menu.ps1 -MaxParallelDownloads 1

# Option 2: Reduce video quality
.\download-menu.ps1 -MaxHeight 720

# Option 3: Reduce fragments
.\download-menu.ps1 -ConcurrentFragments 2

# Option 4: Check your internet connection
# Run: speedtest-cli or visit speedtest.net
```

---

### 5. "Video Already Downloaded" Messages

**Problem**: Script says videos are already downloaded but you can't find them.

**Explanation**: This is NORMAL behavior - the `.download-archive.txt` file tracks downloaded videos to prevent duplicates.

**To re-download**:
```powershell
# Option 1: Delete the archive file
Remove-Item "public\assets\videos\.download-archive.txt"

# Option 2: Manually remove specific entries from the file
notepad "public\assets\videos\.download-archive.txt"
```

---

### 6. PMVHaven Downloads Not Working

**Problem**: PMVHaven links fail to download.

**Solutions**:
```powershell
# Option 1: Use browser cookies (required for PMVHaven)
.\pmv-downloader.ps1 -CookiesFromBrowser "chrome"

# Option 2: Try direct video URLs instead of playlists
# Copy individual video URLs from PMVHaven

# Option 3: Login to PMVHaven in your browser first
# Then use cookies from that browser
```

---

### 7. Out of Disk Space

**Problem**: Downloads fail due to insufficient disk space.

**Solutions**:
```powershell
# Check available space
Get-PSDrive C | Select-Object Used,Free

# Option 1: Change output directory to a drive with more space
.\download-menu.ps1 -OutputDir "E:\Videos"

# Option 2: Delete old/unwanted videos
# Option 3: Reduce video quality to save space
.\download-menu.ps1 -MaxHeight 720
```

---

### 8. Rate Limiting / IP Ban

**Problem**: Getting "Too many requests" or temporary bans.

**Solutions**:
```powershell
# Option 1: Use longer sleep intervals
# Edit download-menu.ps1, increase sleep intervals:
# --sleep-interval 5
# --max-sleep-interval 10

# Option 2: Reduce parallel downloads
.\download-menu.ps1 -MaxParallelDownloads 1

# Option 3: Wait a few hours before trying again

# Option 4: Use a VPN
# The scripts don't detect rate limits automatically yet
```

---

### 9. Videos Download But Won't Play

**Problem**: Downloaded videos won't play in your video player.

**Solutions**:
```powershell
# Option 1: Install VLC Media Player (plays everything)
# Download from: https://www.videolan.org/

# Option 2: Install K-Lite Codec Pack
# Download from: https://codecguide.com/download_kl.htm

# Option 3: Try a different format
# Edit the script to use:
# -f "best[ext=mp4]/best"
```

---

### 10. Thumbnails Not Downloading

**Problem**: Videos download but thumbnails are missing.

**Solution**:
```powershell
# This is usually because the source doesn't have thumbnails
# The script tries to download them with:
# --write-thumbnail
# --convert-thumbnails jpg

# To verify, check if .jpg files exist next to .mp4 files
# If not, the source didn't provide thumbnails
```

---

### 11. Metadata/Info Files Not Creating

**Problem**: `.info.json` files are not being created.

**Solution**:
```powershell
# Verify the script includes:
# --write-info-json

# Check if the files are being created but not visible:
Get-ChildItem "public\assets\videos" -Recurse -Filter "*.info.json"

# If truly missing, add the flag explicitly when running yt-dlp
```

---

### 12. "Cannot Find Path" Errors

**Problem**: Script can't find files or folders.

**Solutions**:
```powershell
# Option 1: Run from the correct directory
cd D:\JOI_game
.\launcher.ps1

# Option 2: Check folder permissions
# Right-click folder → Properties → Security

# Option 3: Run PowerShell as Administrator
```

---

### 13. Scripts Don't Show Colored Text

**Problem**: Menu looks ugly without colors.

**Solutions**:
```powershell
# Option 1: Use Windows Terminal (recommended)
# Install from Microsoft Store

# Option 2: Use PowerShell 7+
winget install Microsoft.PowerShell

# Option 3: Enable ANSI colors in PowerShell 5.1
# This is usually already enabled on Windows 10+
```

---

### 14. Menu Doesn't Accept Input

**Problem**: Can't type in the menu or it doesn't respond.

**Solutions**:
```powershell
# Option 1: Make sure PowerShell window is focused
# Click on the window before typing

# Option 2: Run in a new PowerShell window
powershell -NoExit -File .\launcher.ps1

# Option 3: Use the batch file launcher
.\START_HERE.bat
```

---

### 15. "Unexpected Token" or Syntax Errors

**Problem**: PowerShell shows syntax errors.

**Solutions**:
```powershell
# Option 1: Check PowerShell version (need 5.1+)
$PSVersionTable.PSVersion

# Option 2: Update PowerShell
winget install Microsoft.PowerShell

# Option 3: Re-download the scripts (might be corrupted)
```

---

## Advanced Troubleshooting

### Enable Logging for Debugging

```powershell
# Run with detailed logging
.\download-menu.ps1 -ShowLogs -Verbose

# Check yt-dlp logs
# Logs are saved in: public/assets/videos/.logs/
Get-Content "public\assets\videos\.logs\*.log"
```

### Test yt-dlp Manually

```powershell
# Test with a single video
yt-dlp --verbose "https://www.pornhub.com/view_video.php?viewkey=65eb49680d674"

# Test with cookies
yt-dlp --cookies-from-browser chrome "URL_HERE"

# Test search
yt-dlp --max-downloads 1 "https://www.pornhub.com/video/search?search=JOI"
```

### Check System Requirements

```powershell
# PowerShell version (need 5.1 or higher)
$PSVersionTable.PSVersion

# .NET Framework (need 4.5+)
Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full"

# Available disk space
Get-PSDrive C | Select-Object Used,Free

# Internet connection
Test-NetConnection -ComputerName google.com
```

---

## Error Messages Explained

### "HTTP Error 403: Forbidden"
- **Meaning**: Access denied by the website
- **Solution**: Use `-CookiesFromBrowser` parameter

### "HTTP Error 429: Too Many Requests"
- **Meaning**: Rate limited by the website
- **Solution**: Wait and reduce parallel downloads

### "ERROR: Unable to download JSON metadata"
- **Meaning**: Video doesn't exist or is private
- **Solution**: Check the URL is correct

### "ERROR: This video is not available"
- **Meaning**: Video was removed or is geo-blocked
- **Solution**: Try a VPN or different video

### "WARNING: video doesn't have subtitles"
- **Meaning**: Just a warning, not an error
- **Solution**: Ignore it

---

## Performance Optimization

### For Faster Downloads

```powershell
# Increase concurrent fragments (use with caution)
.\download-menu.ps1 -ConcurrentFragments 8

# Increase parallel downloads (if you have fast internet)
.\download-menu.ps1 -MaxParallelDownloads 5

# Lower quality for faster downloads
.\download-menu.ps1 -MaxHeight 480
```

### For Better Quality

```powershell
# Maximum quality
.\download-menu.ps1 -MaxHeight 1080

# Reduce downloads to avoid rate limiting
.\download-menu.ps1 -MaxParallelDownloads 1 -ConcurrentFragments 2
```

---

## Platform-Specific Issues

### Pornhub
- Often requires cookies for download
- Use: `-CookiesFromBrowser "chrome"`

### XVideos
- Usually works without cookies
- Good fallback option

### SpankBang
- Works well most of the time
- Sometimes has rate limits

### PMVHaven
- **Always requires cookies**
- Login in browser first, then use cookies

---

## Getting Help

1. **Read the documentation**:
   - `QUICK_REFERENCE.md` - Quick start
   - `DOWNLOAD_GUIDE.md` - Detailed guide
   - `SUMMARY.md` - Overview

2. **Check yt-dlp documentation**:
   - https://github.com/yt-dlp/yt-dlp

3. **Test with simulation mode**:
   ```powershell
   .\download-menu.ps1 -Simulate
   ```

4. **Update everything**:
   ```powershell
   yt-dlp -U
   winget upgrade --all
   ```

---

## Known Limitations

1. **PMVHaven playlists**: May not work directly, use individual video URLs
2. **Private videos**: Cannot download without account access
3. **Geo-blocked content**: May require VPN
4. **Live streams**: Not supported
5. **Age-restricted content**: May require cookies from logged-in browser

---

## Prevention Tips

1. ✅ Keep yt-dlp updated: `yt-dlp -U`
2. ✅ Don't delete `.download-archive.txt` (prevents duplicates)
3. ✅ Use browser cookies for protected content
4. ✅ Start with small batches to test
5. ✅ Monitor disk space regularly
6. ✅ Use `-Simulate` flag to test before downloading
7. ✅ Read the error messages - they're usually helpful!

---

**Still Having Issues?**

Try running in simulate mode first:
```powershell
.\download-menu.ps1 -Simulate
```

This will show what would be downloaded without actually downloading anything.
