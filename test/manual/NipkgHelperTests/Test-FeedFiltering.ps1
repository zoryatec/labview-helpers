#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Test script for the updated Get-FeedsInfoFromNipkgCmd function.

.DESCRIPTION
    Tests the feed filtering functionality with switches to exclude local or online feeds.
#>

# Import the module
Import-Module -Name $PSScriptRoot/../../../LabViewHelpers/LabViewHelpers.psd1 -Force

Write-Host "====================================================================================" -ForegroundColor Cyan
Write-Host "Testing Get-FeedsInfoFromNipkgCmd Feed Filtering" -ForegroundColor Cyan
Write-Host "====================================================================================" -ForegroundColor Cyan
Write-Host ""

$nipkgCmdPath = "C:\Program Files\National Instruments\NI Package Manager\nipkg.exe"

# Test NIPKG availability first
Write-Host "Testing NIPKG availability..." -ForegroundColor Yellow
$nipkgAvailable = Test-NipkgAvailability -NipkgCmdPath $nipkgCmdPath
if (-not $nipkgAvailable) {
    Write-Host "✗ NIPKG is not available. Skipping tests." -ForegroundColor Red
    exit 1
}
Write-Host "✓ NIPKG is available" -ForegroundColor Green
Write-Host ""

# Test 1: Get all feeds (default behavior)
Write-Host "Test 1: Get All Feeds (Default Behavior)" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Yellow

try {
    $allFeeds = Get-FeedsInfoFromNipkgCmd -NipkgCmdPath $nipkgCmdPath
    Write-Host "✓ Retrieved $($allFeeds.Count) total feeds" -ForegroundColor Green
    
    # Count feed types
    $localCount = ($allFeeds | Where-Object { $_.Type -eq "Local" }).Count
    $onlineCount = ($allFeeds | Where-Object { $_.Type -eq "Online" }).Count
    
    Write-Host "  Local feeds: $localCount" -ForegroundColor Cyan
    Write-Host "  Online feeds: $onlineCount" -ForegroundColor Cyan
    
    # Show sample feeds
    Write-Host ""
    Write-Host "Sample feeds:" -ForegroundColor Cyan
    $allFeeds | Select-Object -First 5 | ForEach-Object {
        $typeColor = if ($_.Type -eq "Local") { "White" } else { "Yellow" }
        Write-Host "  [$($_.Type)] $($_.Name)" -ForegroundColor $typeColor
        Write-Host "    $($_.Path)" -ForegroundColor Gray
    }
    
} catch {
    Write-Host "✗ Failed to get all feeds: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""

# Test 2: Get only online feeds
Write-Host "Test 2: Get Only Online Feeds" -ForegroundColor Yellow
Write-Host "=============================" -ForegroundColor Yellow

try {
    $onlineFeeds = Get-FeedsInfoFromNipkgCmd -NipkgCmdPath $nipkgCmdPath -ExcludeLocalFeeds
    Write-Host "✓ Retrieved $($onlineFeeds.Count) online feeds" -ForegroundColor Green
    
    # Verify all returned feeds are online
    $localFeedsFound = ($onlineFeeds | Where-Object { $_.Type -eq "Local" }).Count
    if ($localFeedsFound -eq 0) {
        Write-Host "✓ All returned feeds are online (no local feeds found)" -ForegroundColor Green
    } else {
        Write-Host "✗ Found $localFeedsFound local feeds in online-only results!" -ForegroundColor Red
    }
    
    # Show online feeds
    if ($onlineFeeds.Count -gt 0) {
        Write-Host ""
        Write-Host "Online feeds:" -ForegroundColor Cyan
        $onlineFeeds | ForEach-Object {
            Write-Host "  $($_.Name)" -ForegroundColor Yellow
            Write-Host "    $($_.Path)" -ForegroundColor Gray
        }
    } else {
        Write-Host "  No online feeds configured" -ForegroundColor Gray
    }
    
} catch {
    Write-Host "✗ Failed to get online feeds: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""

# Test 3: Get only local feeds
Write-Host "Test 3: Get Only Local Feeds" -ForegroundColor Yellow
Write-Host "============================" -ForegroundColor Yellow

try {
    $localFeeds = Get-FeedsInfoFromNipkgCmd -NipkgCmdPath $nipkgCmdPath -ExcludeOnlineFeeds
    Write-Host "✓ Retrieved $($localFeeds.Count) local feeds" -ForegroundColor Green
    
    # Verify all returned feeds are local
    $onlineFeedsFound = ($localFeeds | Where-Object { $_.Type -eq "Online" }).Count
    if ($onlineFeedsFound -eq 0) {
        Write-Host "✓ All returned feeds are local (no online feeds found)" -ForegroundColor Green
    } else {
        Write-Host "✗ Found $onlineFeedsFound online feeds in local-only results!" -ForegroundColor Red
    }
    
    # Show local feeds
    if ($localFeeds.Count -gt 0) {
        Write-Host ""
        Write-Host "Local feeds:" -ForegroundColor Cyan
        $localFeeds | Select-Object -First 10 | ForEach-Object {
            Write-Host "  $($_.Name)" -ForegroundColor White
            Write-Host "    $($_.Path)" -ForegroundColor Gray
        }
        
        if ($localFeeds.Count -gt 10) {
            Write-Host "  ... and $($localFeeds.Count - 10) more local feeds" -ForegroundColor Gray
        }
    } else {
        Write-Host "  No local feeds configured" -ForegroundColor Gray
    }
    
} catch {
    Write-Host "✗ Failed to get local feeds: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""

# Test 4: Test parameter validation (should fail)
Write-Host "Test 4: Parameter Validation (Both Exclusions)" -ForegroundColor Yellow
Write-Host "===============================================" -ForegroundColor Yellow

try {
    $invalidResult = Get-FeedsInfoFromNipkgCmd -NipkgCmdPath $nipkgCmdPath -ExcludeLocalFeeds -ExcludeOnlineFeeds
    Write-Host "✗ Unexpected success - should have failed with both exclusions!" -ForegroundColor Red
} catch {
    Write-Host "✓ Expected failure: $($_.Exception.Message)" -ForegroundColor Green
}

Write-Host ""

# Test 5: Verify feed type detection worked correctly
Write-Host "Test 5: Feed Type Detection Verification" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Yellow

if ($allFeeds.Count -gt 0) {
    Write-Host "Verifying feed type detection from actual feeds:" -ForegroundColor Cyan
    
    # Check for expected patterns in actual feeds
    $localFeedsFound = $allFeeds | Where-Object { $_.Type -eq "Local" }
    $onlineFeedsFound = $allFeeds | Where-Object { $_.Type -eq "Online" }
    
    Write-Host "Feed type analysis:" -ForegroundColor Cyan
    Write-Host "  Total feeds: $($allFeeds.Count)" -ForegroundColor White
    Write-Host "  Local feeds: $($localFeedsFound.Count)" -ForegroundColor White
    Write-Host "  Online feeds: $($onlineFeedsFound.Count)" -ForegroundColor White
    
    # Show sample local feeds
    if ($localFeedsFound.Count -gt 0) {
        Write-Host ""
        Write-Host "Sample local feed paths:" -ForegroundColor Cyan
        $localFeedsFound | Select-Object -First 3 | ForEach-Object {
            Write-Host "  ✓ $($_.Path)" -ForegroundColor Green
        }
    }
    
    # Show sample online feeds  
    if ($onlineFeedsFound.Count -gt 0) {
        Write-Host ""
        Write-Host "Sample online feed paths:" -ForegroundColor Cyan
        $onlineFeedsFound | Select-Object -First 3 | ForEach-Object {
            Write-Host "  ✓ $($_.Path)" -ForegroundColor Green
        }
    }
    
    # Verify expected patterns
    $httpsFeeds = $allFeeds | Where-Object { $_.Path -like "https://*" }
    $httpFeeds = $allFeeds | Where-Object { $_.Path -like "http://*" }
    $driveFeeds = $allFeeds | Where-Object { $_.Path -match "^[A-Z]:\\" }
    
    Write-Host ""
    Write-Host "Pattern verification:" -ForegroundColor Cyan
    Write-Host "  HTTPS feeds: $($httpsFeeds.Count) (should be Online)" -ForegroundColor White
    Write-Host "  HTTP feeds: $($httpFeeds.Count) (should be Online)" -ForegroundColor White
    Write-Host "  Drive letter feeds: $($driveFeeds.Count) (should be Local)" -ForegroundColor White
    
    # Check if HTTPS feeds are correctly marked as Online
    $httpsCorrect = ($httpsFeeds | Where-Object { $_.Type -eq "Online" }).Count
    if ($httpsCorrect -eq $httpsFeeds.Count) {
        Write-Host "  ✓ All HTTPS feeds correctly marked as Online" -ForegroundColor Green
    } else {
        Write-Host "  ✗ Some HTTPS feeds incorrectly marked as Local" -ForegroundColor Red
    }
    
    # Check if drive letter feeds are correctly marked as Local
    $driveCorrect = ($driveFeeds | Where-Object { $_.Type -eq "Local" }).Count
    if ($driveCorrect -eq $driveFeeds.Count) {
        Write-Host "  ✓ All drive letter feeds correctly marked as Local" -ForegroundColor Green
    } else {
        Write-Host "  ✗ Some drive letter feeds incorrectly marked as Online" -ForegroundColor Red
    }
    
} else {
    Write-Host "No feeds available for type detection verification" -ForegroundColor Gray
}

Write-Host ""

# Summary
Write-Host "====================================================================================" -ForegroundColor Cyan
Write-Host "Feed Filtering Tests Completed" -ForegroundColor Cyan
Write-Host "====================================================================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "USAGE EXAMPLES:" -ForegroundColor Yellow
Write-Host ""
Write-Host "# Get all feeds (default):" -ForegroundColor White
Write-Host '$feeds = Get-FeedsInfoFromNipkgCmd' -ForegroundColor Gray
Write-Host ""
Write-Host "# Get only online feeds:" -ForegroundColor White
Write-Host '$onlineFeeds = Get-FeedsInfoFromNipkgCmd -ExcludeLocalFeeds' -ForegroundColor Gray
Write-Host ""
Write-Host "# Get only local feeds:" -ForegroundColor White
Write-Host '$localFeeds = Get-FeedsInfoFromNipkgCmd -ExcludeOnlineFeeds' -ForegroundColor Gray
Write-Host ""
Write-Host "# Each feed object now has Name, Path, and Type properties" -ForegroundColor White
Write-Host '$feeds | Format-Table Name, Type, Path' -ForegroundColor Gray
Write-Host ""
