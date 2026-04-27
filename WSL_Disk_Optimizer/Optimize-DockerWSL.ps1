<#
.SYNOPSIS
    A toolkit to optimize Docker Desktop and WSL performance on Windows.
.DESCRIPTION
    Provides an interactive menu to:
    1. Compact the Docker WSL virtual disk to reclaim space.
    2. Add Windows Defender exclusions to improve I/O speed (with warnings).
    3. Generate an optimized .wslconfig file for resource management (with warnings).
    4. Revert system-level optimizations.
#>

# 1. Auto-Elevate to Administrator
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    try {
        Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
        Exit
    } catch {
        Write-Host "Failed to elevate privileges. Please right-click and 'Run as Administrator'." -ForegroundColor Red
        Pause
        Exit
    }
}

# Helper Function: Locate VHDX
function Get-VhdxPath {
    $dataPath = "$env:LOCALAPPDATA\Docker\wsl\data\ext4.vhdx"
    $mainPath = "$env:LOCALAPPDATA\Docker\wsl\main\ext4.vhdx"
    
    if (Test-Path $dataPath) { return $dataPath }
    if (Test-Path $mainPath) { return $mainPath }
    
    Write-Host "Could not find standard Docker disks." -ForegroundColor Yellow
    $custom = Read-Host "Enter the full path to your ext4.vhdx file"
    if (Test-Path $custom) { return $custom }
    
    Write-Host "File not found." -ForegroundColor Red
    return $null
}

# Feature 1: Compact Disk
function Optimize-DiskSpace {
    $vhdxPath = Get-VhdxPath
    if (-not $vhdxPath) { return }

    $sizeBefore = (Get-Item $vhdxPath).Length

    Write-Host "`nStopping Docker Desktop and WSL..." -ForegroundColor Cyan
    Get-Process "Docker Desktop" -ErrorAction SilentlyContinue | Stop-Process -Force
    wsl --shutdown
    Start-Sleep -Seconds 3

    Write-Host "Compacting Virtual Disk (this may take a few minutes)..." -ForegroundColor Cyan
    $diskpartScript = "$env:TEMP\compact_vdisk.txt"
    @"
select vdisk file="$vhdxPath"
attach vdisk readonly
compact vdisk
detach vdisk
"@ | Out-File -FilePath $diskpartScript -Encoding ASCII

    $diskpartOutput = diskpart /s $diskpartScript
    Remove-Item $diskpartScript

    $sizeAfter = (Get-Item $vhdxPath).Length
    $savedGB = [math]::Round(($sizeBefore - $sizeAfter) / 1GB, 2)
    $afterGB = [math]::Round($sizeAfter / 1GB, 2)

    Write-Host "`n========================================================" -ForegroundColor Green
    Write-Host "New Virtual Disk Size : $afterGB GB"
    Write-Host "Total Space Reclaimed : $savedGB GB" -ForegroundColor Green
    Write-Host "========================================================"
}

# Feature 2: Defender Exclusions
function Optimize-Defender {
    Write-Host "`n========================================================" -ForegroundColor Yellow
    Write-Host "             SECURITY WARNING: DEFENDER                 " -ForegroundColor Yellow
    Write-Host "========================================================" -ForegroundColor Yellow
    Write-Host "Excluding your Docker virtual disk and background processes"
    Write-Host "means Windows Defender will NOT scan them for malware."
    Write-Host "If a container is compromised or you download a malicious"
    Write-Host "image, Defender will not intervene. This drastically"
    Write-Host "improves I/O speed but reduces system security."
    Write-Host "========================================================"
    
    $confirm = Read-Host "Do you understand the risks and wish to proceed? (Y/N)"
    if ($confirm -notmatch '^[Yy]$') { 
        Write-Host "Skipping Defender optimization." -ForegroundColor Cyan
        return 
    }

    $vhdxPath = Get-VhdxPath
    if (-not $vhdxPath) { return }

    Write-Host "`nAdding Windows Defender Exclusions..." -ForegroundColor Cyan
    
    try {
        Add-MpPreference -ExclusionPath $vhdxPath
        Write-Host "[OK] Excluded VHDX: $vhdxPath" -ForegroundColor Green

        Add-MpPreference -ExclusionProcess "com.docker.backend.exe"
        Add-MpPreference -ExclusionProcess "wsl.exe"
        Write-Host "[OK] Excluded Processes: com.docker.backend.exe, wsl.exe" -ForegroundColor Green
        
        Write-Host "Defender exclusions applied successfully." -ForegroundColor Green
    } catch {
        Write-Host "Failed to add exclusions. Ensure Windows Defender is active." -ForegroundColor Red
    }
}

# Feature 3: WSL Config Generator
function Optimize-WslConfig {
    Write-Host "`n========================================================" -ForegroundColor Yellow
    Write-Host "            WORKLOAD & NETWORK WARNING                  " -ForegroundColor Yellow
    Write-Host "========================================================" -ForegroundColor Yellow
    Write-Host "1. Hard RAM Limits: Prevents Windows starvation but risks"
    Write-Host "   Out-Of-Memory (OOM) crashes if you run exceptionally"
    Write-Host "   heavy container workloads."
    Write-Host "2. Mirrored Networking: Improves localhost routing but"
    Write-Host "   can break existing custom network bridges that rely"
    Write-Host "   on WSL's default NAT IP architecture."
    Write-Host "========================================================"
    
    $confirm = Read-Host "Do you understand the risks and wish to proceed? (Y/N)"
    if ($confirm -notmatch '^[Yy]$') { 
        Write-Host "Skipping .wslconfig optimization." -ForegroundColor Cyan
        return 
    }

    $configPath = "$env:USERPROFILE\.wslconfig"
    
    $totalRamGB = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB)
    $wslMem = [math]::Max(2, [math]::Round($totalRamGB / 2))
    
    $totalCores = (Get-CimInstance Win32_Processor | Measure-Object -Property NumberOfLogicalProcessors -Sum).Sum
    $wslCores = [math]::Max(2, $totalCores - 2)

    Write-Host "`nGenerating $configPath" -ForegroundColor Cyan
    
    $configContent = @"
[wsl2]
# Automatically calculated limits to prevent Windows starvation
memory=${wslMem}GB
processors=${wslCores}
pageReporting=true

# Windows 11 Mirrored Networking (Improves network throughput and port binding)
networkingMode=mirrored
dnsTunneling=true
"@

    $configContent | Out-File -FilePath $configPath -Encoding UTF8
    Write-Host "[OK] Created .wslconfig with $wslMem GB RAM and $wslCores Cores allocation." -ForegroundColor Green
    Write-Host "Restarting WSL to apply changes..." -ForegroundColor Cyan
    wsl --shutdown
    Start-Sleep -Seconds 2
}

# Feature 4: Revert Optimizations
function Revert-Optimizations {
    Write-Host "`n========================================================" -ForegroundColor Magenta
    Write-Host "               REVERTING OPTIMIZATIONS                  " -ForegroundColor Magenta
    Write-Host "========================================================" -ForegroundColor Magenta
    
    $vhdxPath = Get-VhdxPath
    if ($vhdxPath) {
        try {
            Remove-MpPreference -ExclusionPath $vhdxPath -ErrorAction SilentlyContinue
            Write-Host "[OK] Removed Defender exclusion for VHDX." -ForegroundColor Green
        } catch { }
    }

    try {
        Remove-MpPreference -ExclusionProcess "com.docker.backend.exe" -ErrorAction SilentlyContinue
        Remove-MpPreference -ExclusionProcess "wsl.exe" -ErrorAction SilentlyContinue
        Write-Host "[OK] Removed Defender exclusions for processes." -ForegroundColor Green
    } catch { }

    $configPath = "$env:USERPROFILE\.wslconfig"
    if (Test-Path $configPath) {
        Remove-Item $configPath -Force
        Write-Host "[OK] Deleted .wslconfig file." -ForegroundColor Green
        Write-Host "Restarting WSL to apply default settings..." -ForegroundColor Cyan
        wsl --shutdown
    } else {
        Write-Host "[INFO] No .wslconfig file found to delete." -ForegroundColor Yellow
    }
    
    Write-Host "Revert complete." -ForegroundColor Green
}

# Main Menu Loop
while ($true) {
    Clear-Host
    Write-Host "========================================================" -ForegroundColor Cyan
    Write-Host "          Docker Janitor - Windows Toolkit           " -ForegroundColor Cyan
    Write-Host "========================================================" -ForegroundColor Cyan
    Write-Host "1. Compact WSL Virtual Disk (Reclaim Space)"
    Write-Host "2. Apply Defender Exclusions (Boost I/O Speed)"
    Write-Host "3. Optimize .wslconfig (Resource & Network Mgmt)"
    Write-Host "4. Apply All Optimizations"
    Write-Host "5. Undo / Revert Optimizations"
    Write-Host "6. Start Docker Desktop"
    Write-Host "7. Exit"
    Write-Host "========================================================"
    
    $choice = Read-Host "Select an option (1-7)"
    
    switch ($choice) {
        '1' { Optimize-DiskSpace; Pause }
        '2' { Optimize-Defender; Pause }
        '3' { Optimize-WslConfig; Pause }
        '4' { 
            Optimize-DiskSpace
            Optimize-Defender
            Optimize-WslConfig
            Pause 
        }
        '5' { Revert-Optimizations; Pause }
        '6' {
            Write-Host "Starting Docker Desktop..." -ForegroundColor Cyan
            $dockerExe = "C:\Program Files\Docker\Docker\Docker Desktop.exe"
            if (Test-Path $dockerExe) { Start-Process $dockerExe }
            else { Write-Host "Could not find Docker Desktop.exe" -ForegroundColor Yellow }
            Pause
        }
        '7' { Exit }
        default { Write-Host "Invalid selection." -ForegroundColor Red; Start-Sleep -Seconds 1 }
    }
}