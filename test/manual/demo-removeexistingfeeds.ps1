#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Demonstrates the new RemoveExistingFeeds parameter in Apply-NipkgSnapshot

.DESCRIPTION
    This script shows how to use the new RemoveExistingFeeds switch parameter
    which was added to the Apply-NipkgSnapshot function.

.NOTES
    The RemoveExistingFeeds parameter will:
    1. Get all currently configured feeds using Get-FeedsInfoFromNipkgCmd
    2. Remove all existing feeds using Remove-Feeds
    3. Then proceed with applying the snapshot feeds normally
    
    Run this from the test/manual directory.
#>

Write-Host "=== Apply-NipkgSnapshot RemoveExistingFeeds Demo ===" -ForegroundColor Cyan

Write-Host "`nNew RemoveExistingFeeds Parameter Usage Examples:" -ForegroundColor Yellow

Write-Host "`n1. Basic usage - remove existing feeds before applying snapshot:" -ForegroundColor Green
Write-Host '   Import-NipkgSnapshotFromJson -InputPath "my-snapshot.json" | Apply-NipkgSnapshot -RemoveExistingFeeds'

Write-Host "`n2. With WhatIf to see what would be removed/added:" -ForegroundColor Green
Write-Host '   Import-NipkgSnapshotFromJson -InputPath "my-snapshot.json" | Apply-NipkgSnapshot -RemoveExistingFeeds -WhatIf'

Write-Host "`n3. Remove existing feeds but only apply feeds (skip packages):" -ForegroundColor Green
Write-Host '   Import-NipkgSnapshotFromJson -InputPath "my-snapshot.json" | Apply-NipkgSnapshot -RemoveExistingFeeds -SkipPackages'

Write-Host "`n4. Remove existing feeds and force package installation:" -ForegroundColor Green
Write-Host '   Import-NipkgSnapshotFromJson -InputPath "my-snapshot.json" | Apply-NipkgSnapshot -RemoveExistingFeeds -Force'

Write-Host "`nOperation Flow with RemoveExistingFeeds:" -ForegroundColor Yellow
Write-Host "Phase 0: Remove existing feeds (if RemoveExistingFeeds is specified)"
Write-Host "Phase 1: Add feeds from snapshot"
Write-Host "Phase 2: Install packages from snapshot"

Write-Host "`nReturn Object includes new FeedsRemoved property:" -ForegroundColor Yellow
Write-Host @"
{
    SnapshotPath: "path/to/snapshot.json"
    FeedsRemoved: 3          # NEW: Number of existing feeds removed
    FeedsTotal: 2            # Number of feeds in snapshot
    FeedsAdded: 2            # Number of snapshot feeds successfully added
    FeedsSkipped: 0          # Number of feeds skipped (WhatIf)
    FeedsFailed: 0           # Number of feeds that failed to add
    PackagesTotal: 15        # Number of packages in snapshot
    PackagesInstalled: 15    # Number of packages successfully installed
    PackagesSkipped: 0       # Number of packages skipped
    PackagesFailed: 0        # Number of packages that failed to install
    Success: true            # Overall operation success
}
"@

Write-Host "`nUse Cases:" -ForegroundColor Yellow
Write-Host "• Clean system state: Remove all feeds before applying known configuration"
Write-Host "• Environment reset: Clear existing feeds and apply standardized snapshot"
Write-Host "• CI/CD scenarios: Ensure clean, reproducible environment state"
Write-Host "• Development: Switch between different feed configurations cleanly"

Write-Host "`nNote: RemoveExistingFeeds is ignored if SkipFeeds is also specified." -ForegroundColor Cyan

# Test importing the module to verify it works from this directory
Write-Host "`n=== Testing Module Import from test/manual directory ===" -ForegroundColor Yellow

try {
    # Get the script directory and navigate to module path
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $moduleDir = Split-Path -Parent (Split-Path -Parent $scriptDir)
    $modulePath = Join-Path $moduleDir "LabViewHelpers\LabViewHelpers.psd1"
    
    Write-Host "Current script directory: $scriptDir" -ForegroundColor Cyan
    Write-Host "Module path: $modulePath" -ForegroundColor Cyan
    
    if (Test-Path $modulePath) {
        Import-Module $modulePath -Force
        Write-Host "✓ Module imported successfully from test/manual directory!" -ForegroundColor Green
        
        # Test the new parameter exists
        $applyFunction = Get-Command Apply-NipkgSnapshot -ErrorAction SilentlyContinue
        if ($applyFunction -and $applyFunction.Parameters.ContainsKey('RemoveExistingFeeds')) {
            Write-Host "✓ RemoveExistingFeeds parameter is available!" -ForegroundColor Green
        } else {
            Write-Host "✗ RemoveExistingFeeds parameter not found" -ForegroundColor Red
        }
    } else {
        Write-Host "✗ Module not found at: $modulePath" -ForegroundColor Red
    }
} catch {
    Write-Host "✗ Error testing module: $($_.Exception.Message)" -ForegroundColor Red
}
