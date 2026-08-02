@echo off
REM One-click launcher for Stash + the downloader tool.
REM Edit STASH_EXE below once to match where you installed Stash.

set STASH_EXE=D:\Stash\stash-win.exe
set REPO_DIR=%~dp0
set DOWNLOADER_DIR=%REPO_DIR%tools\downloader

echo Starting Stash...
start "Stash" "%STASH_EXE%"

echo Starting downloader app...
start "Library Downloader" cmd /k "cd /d "%DOWNLOADER_DIR%" && python app.py"

REM Give both servers a moment to come up before opening browser tabs.
timeout /t 3 /nobreak >nul

start "" "http://localhost:9999"
start "" "http://localhost:5050"

echo Both apps are starting in their own windows. You can close this one.
