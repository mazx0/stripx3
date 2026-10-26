<#
.SYNOPSIS
    Automated 1-click script to stage, commit, and push all project files to GitHub.
#>
[CmdletBinding()]
param (
    [string]$Message = ""
)

$ErrorActionPreference = "Stop"
Set-Location -Path $PSScriptRoot

Write-Host "===================================================" -ForegroundColor Cyan
Write-Host "      StripX v3 - Auto Upload to GitHub           " -ForegroundColor Cyan
Write-Host "===================================================" -ForegroundColor Cyan
Write-Host ""

try {
    # Check git availability
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-Error "Git is not installed or not in PATH. Please install Git from https://git-scm.com/"
    }

    Write-Host "Current status:" -ForegroundColor Yellow
    git status -s
    Write-Host ""

    if ([string]::IsNullOrWhiteSpace($Message)) {
        $inputMsg = Read-Host "Enter commit message (Press Enter for auto timestamp)"
        if ([string]::IsNullOrWhiteSpace($inputMsg)) {
            $Message = "Auto update $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
        } else {
            $Message = $inputMsg
        }
    }

    Write-Host "[1/3] Staging all files..." -ForegroundColor Gray
    git add .

    Write-Host "[2/3] Committing: '$Message'..." -ForegroundColor Gray
    git commit -m "$Message" -q

    Write-Host "[3/3] Pushing to GitHub (origin main)..." -ForegroundColor Gray
    git push origin main

    Write-Host ""
    Write-Host "===================================================" -ForegroundColor Green
    Write-Host "[SUCCESS] All files uploaded to GitHub successfully!" -ForegroundColor Green
    Write-Host "Repository: https://github.com/mazx0/stripx3" -ForegroundColor Green
    Write-Host "===================================================" -ForegroundColor Green
} catch {
    Write-Host ""
    Write-Host "[ERROR] $($_.Exception.Message)" -ForegroundColor Red
}
Write-Host ""
Read-Host "Press Enter to exit"
