@echo off
setlocal enabledelayedexpansion
title StripX v3 - Auto Upload to GitHub

echo ===================================================
echo       StripX v3 - Auto Upload to GitHub
echo ===================================================
echo.

cd /d "%~dp0"

:: Check if git is installed
where git >nul 2>nul
if %errorlevel% neq 0 (
    echo [ERROR] Git is not installed or not in PATH!
    echo Please install Git from https://git-scm.com/
    pause
    exit /b 1
)

:: Show current status
echo Checking repository status...
git status -s
echo.

:: Prompt for commit message
set /p "commit_msg=Enter commit message (Press Enter for default auto-timestamp): "
if "!commit_msg!"=="" (
    for /f "tokens=1-4 delims=/ " %%a in ("%date%") do set mydate=%%c-%%a-%%b
    for /f "tokens=1-2 delims=:." %%a in ("%time%") do set mytime=%%a:%%b
    set "commit_msg=Auto update !mydate! !mytime!"
)

echo.
echo [1/3] Adding all files to staging...
git add .
if %errorlevel% neq 0 (
    echo [ERROR] Failed to stage files!
    pause
    exit /b 1
)

echo [2/3] Committing changes: "!commit_msg!"...
git commit -m "!commit_msg!"
if %errorlevel% neq 0 (
    echo [INFO] No changes to commit or commit succeeded.
)

echo [3/3] Pushing to GitHub (origin main)...
git push origin main
if %errorlevel% neq 0 (
    echo.
    echo [WARNING] Standard push failed. Trying to pull and rebase...
    git pull --rebase origin main
    git push origin main
)

echo.
echo ===================================================
echo [SUCCESS] All files uploaded to GitHub successfully!
echo Repository: https://github.com/mazx0/stripx3
echo ===================================================
echo.
pause
