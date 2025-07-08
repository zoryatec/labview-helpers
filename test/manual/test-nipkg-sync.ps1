#!/usr/bin/env pwsh
param()

# Test script for NIPKG sync functionality
Write-Host "=== Testing NIPKG Sync Function ===" -ForegroundColor Cyan

try {
    # Import module
    Import-Module "$PSScriptRoot\..\..\LabViewHelpers\LabViewHelpers.psd1" -Force -Verbose:$false
    
    # Create snapshot from installer
    Write-Host "1. Creating snapshot from installer..." -ForegroundColor Yellow
    $installerPath = "$PSScriptRoot\..\manual-docker\installers\ni-labview-2025-community-x86_25.1.3_offline"
    $snapshot = New-NipkgSnapshotFromInstaller -InstallerDirectory $installerPath
    
    Write-Host "2. Checking NIPKG packages in snapshot..." -ForegroundColor Yellow
    $nipkgPkgs = $snapshot.packages | Where-Object { $_.name -like "*ni-package-manager*" }
    foreach ($pkg in $nipkgPkgs) {
        Write-Host "  $($pkg.name) - $($pkg.version)" -ForegroundColor Gray
    }
    
    Write-Host "3. Testing Sync-NipkgVersionWithSnapshot function..." -ForegroundColor Yellow
    $result = Sync-NipkgVersionWithSnapshot -Snapshot $snapshot -Verbose
    
    Write-Host "4. Sync result:" -ForegroundColor Green
    Write-Host "  VersionChanged: $($result.VersionChanged)" -ForegroundColor Gray
    Write-Host "  OldVersion: $($result.OldVersion)" -ForegroundColor Gray
    Write-Host "  NewVersion: $($result.NewVersion)" -ForegroundColor Gray
    
} catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack trace:" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
}

Write-Host "=== Test Complete ===" -ForegroundColor Cyan
