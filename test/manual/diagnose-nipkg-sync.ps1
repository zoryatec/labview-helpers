#!/usr/bin/env pwsh
param()

# Diagnostic script for NIPKG sync troubleshooting
Write-Host "=== NIPKG Sync Diagnostic ===" -ForegroundColor Cyan

try {
    # Import module
    Import-Module "$PSScriptRoot\..\..\LabViewHelpers\LabViewHelpers.psd1" -Force -Verbose:$false
    
    Write-Host "1. Current NIPKG version:" -ForegroundColor Yellow
    $nipkgVersion = & nipkg --version
    Write-Host "  $nipkgVersion" -ForegroundColor White
    
    Write-Host "`n2. Currently installed NIPKG packages:" -ForegroundColor Yellow
    $installedNipkg = & nipkg list-installed | Where-Object { $_ -like "*ni-package-manager*" }
    foreach ($pkg in $installedNipkg) {
        Write-Host "  $pkg" -ForegroundColor White
    }
    
    Write-Host "`n3. Available NIPKG packages in feeds:" -ForegroundColor Yellow
    $availableNipkg = & nipkg search ni-package-manager
    $limitedResults = $availableNipkg | Select-Object -Last 10
    foreach ($pkg in $limitedResults) {
        Write-Host "  $pkg" -ForegroundColor White
    }
    Write-Host "  (showing last 10 results)" -ForegroundColor Gray
    
    Write-Host "`n4. Active feeds:" -ForegroundColor Yellow
    $feeds = & nipkg feed-list
    foreach ($feed in $feeds) {
        Write-Host "  $feed" -ForegroundColor White
    }
    
    Write-Host "`n5. Testing snapshot creation and sync..." -ForegroundColor Yellow
    $installerPath = "$PSScriptRoot\..\manual-docker\installers\ni-labview-2025-community-x86_25.1.3_offline"
    
    if (Test-Path $installerPath) {
        Write-Host "  Creating snapshot from installer..." -ForegroundColor Gray
        $snapshot = New-SnapshotFromInstallerDirectory -InstallerDirectory $installerPath
        
        Write-Host "  NIPKG packages in snapshot:" -ForegroundColor Gray
        $nipkgPkgs = $snapshot.packages | Where-Object { $_.name -like "*ni-package-manager*" }
        foreach ($pkg in $nipkgPkgs) {
            Write-Host "    $($pkg.name) - $($pkg.version)" -ForegroundColor White
        }
        
        Write-Host "  Testing sync operation..." -ForegroundColor Gray
        $result = Sync-NipkgVersionWithSnapshot -Snapshot $snapshot -Verbose
        
        Write-Host "  Sync result:" -ForegroundColor Gray
        Write-Host "    VersionChanged: $($result.VersionChanged)" -ForegroundColor White
        Write-Host "    OldVersion: $($result.OldVersion)" -ForegroundColor White
        Write-Host "    NewVersion: $($result.NewVersion)" -ForegroundColor White
    } else {
        Write-Host "  Installer not found at: $installerPath" -ForegroundColor Red
    }
    
    Write-Host "`n6. Dependency check for target version..." -ForegroundColor Yellow
    $targetVersion = "25.0.0.49256-0+f104"
    Write-Host "  Checking dependencies for ni-package-manager=$targetVersion" -ForegroundColor Gray
    
    try {
        $deps = & nipkg get-dependencies "ni-package-manager=$targetVersion" 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  Dependencies:" -ForegroundColor Gray
            foreach ($dep in $deps) {
                Write-Host "    $dep" -ForegroundColor White
            }
        } else {
            Write-Host "  Failed to get dependencies: $deps" -ForegroundColor Red
        }
    } catch {
        Write-Host "  Error getting dependencies: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Write-Host "`n7. Attempting manual install test..." -ForegroundColor Yellow
    Write-Host "  Testing: nipkg install ni-package-manager=$targetVersion --accept-eulas -y --allow-downgrade --allow-uninstall" -ForegroundColor Gray
    
    $installOutput = & nipkg install "ni-package-manager=$targetVersion" --accept-eulas -y --allow-downgrade --allow-uninstall 2>&1
    Write-Host "  Exit code: $LASTEXITCODE" -ForegroundColor $(if ($LASTEXITCODE -eq 0) { "Green" } else { "Red" })
    
    if ($installOutput) {
        Write-Host "  Output:" -ForegroundColor Gray
        foreach ($line in $installOutput) {
            Write-Host "    $line" -ForegroundColor White
        }
    }
    
} catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack trace:" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
}

Write-Host "`n=== Diagnostic Complete ===" -ForegroundColor Cyan
