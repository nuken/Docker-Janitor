<#
.SYNOPSIS
    Compacts the Docker Desktop WSL virtual disk to reclaim host disk space.
.DESCRIPTION
    This script gracefully shuts down Docker and WSL, locates the ext4.vhdx file 
    (checking both 'data' and 'main' directories), uses diskpart to compact it, 
    reports the space saved, and restarts Docker.
#>

# 1. Auto-Elevate to Administrator
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    # We are not admin, so relaunch the script with Admin privileges
    try {
        Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
        Exit # Close this non-admin window
    } catch {
        Write-Host "Failed to elevate privileges. Please right-click and 'Run as Administrator'." -ForegroundColor Red
        Pause
        Exit
    }
}

Clear-Host
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "           Docker Janitor - WSL Disk Optimizer          " -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "This script will shut down WSL, compress your Docker virtual disk,"
Write-Host "and reclaim lost space on your Windows host."
Write-Host ""
Pause

# 2. Locate the Virtual Disk (Checking multiple default locations)
$dataPath = "$env:LOCALAPPDATA\Docker\wsl\data\ext4.vhdx"
$mainPath = "$env:LOCALAPPDATA\Docker\wsl\main\ext4.vhdx"
$vhdxPath = ""

if (Test-Path $dataPath) {
    Write-Host "Found Docker disk in \data\ directory." -ForegroundColor Green
    $vhdxPath = $dataPath
} elseif (Test-Path $mainPath) {
    Write-Host "Found Docker disk in \main\ directory." -ForegroundColor Green
    $vhdxPath = $mainPath
} else {
    Write-Host "Could not find the standard Docker disks at:" -ForegroundColor Yellow
    Write-Host " - $dataPath" -ForegroundColor Yellow
    Write-Host " - $mainPath" -ForegroundColor Yellow
    $vhdxPath = Read-Host "`nPlease enter the full custom path to your ext4.vhdx file"
    
    if (-not (Test-Path $vhdxPath)) {
        Write-Host "File not found. Exiting script." -ForegroundColor Red
        Exit
    }
}

# 3. Calculate starting size
$sizeBefore = (Get-Item $vhdxPath).Length

# 4. Stop Docker and WSL
Write-Host "`n[1/4] Stopping Docker Desktop..." -ForegroundColor Cyan
Get-Process "Docker Desktop" -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 3

Write-Host "[2/4] Shutting down WSL backend..." -ForegroundColor Cyan
wsl --shutdown
Start-Sleep -Seconds 3

# 5. Create and run Diskpart script
Write-Host "[3/4] Compacting Virtual Disk. Please wait, this may take a few minutes..." -ForegroundColor Cyan

$diskpartScript = "$env:TEMP\compact_vdisk.txt"
@"
select vdisk file="$vhdxPath"
attach vdisk readonly
compact vdisk
detach vdisk
"@ | Out-File -FilePath $diskpartScript -Encoding ASCII

# Run diskpart silently
$diskpartOutput = diskpart /s $diskpartScript
Remove-Item $diskpartScript

# 6. Calculate Space Saved
$sizeAfter = (Get-Item $vhdxPath).Length
$savedGB = [math]::Round(($sizeBefore - $sizeAfter) / 1GB, 2)
$afterGB = [math]::Round($sizeAfter / 1GB, 2)

Write-Host "`n[4/4] Restarting Docker Desktop..." -ForegroundColor Cyan
$dockerExe = "C:\Program Files\Docker\Docker\Docker Desktop.exe"
if (Test-Path $dockerExe) {
    Start-Process $dockerExe
} else {
    Write-Host "Could not automatically restart Docker. Please start it from your Start Menu." -ForegroundColor Yellow
}

# 7. Final Report
Write-Host "`n========================================================" -ForegroundColor Green
Write-Host "                  COMPACTION COMPLETE!                  " -ForegroundColor Green
Write-Host "========================================================" -ForegroundColor Green
Write-Host "New Virtual Disk Size : $afterGB GB"
Write-Host "Total Space Reclaimed : $savedGB GB" -ForegroundColor Green
Write-Host "========================================================"
Write-Host ""
Pause