#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Tests the Test-NipkgSnapshotCompliance functionality.

.DESCRIPTION
    Tests that Test-NipkgSnapshotCompliance correctly validates system state
    against snapshot requirements with various validation options.
#>

# Import the module
Import-Module -Name $PSScriptRoot/../../../LabViewHelpers/LabViewHelpers.psd1 -Force

Write-Host "====================================================================================" -ForegroundColor Cyan
Write-Host "Testing Snapshot Compliance Validation Functionality" -ForegroundColor Cyan
Write-Host "====================================================================================" -ForegroundColor Cyan
Write-Host ""

$nipkgCmdPath = "C:\Program Files\National Instruments\NI Package Manager\nipkg.exe"

# Test NIPKG availability first
Write-Host "Testing NIPKG availability..." -ForegroundColor Yellow
$nipkgAvailable = Test-NipkgAvailability -NipkgCmdPath $nipkgCmdPath
if (-not $nipkgAvailable) {
    Write-Host "✗ NIPKG is not available. Skipping compliance tests." -ForegroundColor Red
    return
} else {
    Write-Host "✓ NIPKG is available" -ForegroundColor Green
}
Write-Host ""

# Create test snapshots for different scenarios
$tempDir = [System.IO.Path]::GetTempPath()

# Test 1: Create a snapshot of current system state for perfect compliance
Write-Host "Test 1: Perfect Compliance Test" -ForegroundColor Yellow
Write-Host "==============================" -ForegroundColor Yellow

try {
    # Create snapshot from current system
    Write-Host "Creating snapshot from current system state..." -ForegroundColor Cyan
    $currentSnapshot = New-NipkgSnapshotFromSystem -PackageType "installed" -NipkgCmdPath $nipkgCmdPath
    
    # Export to temporary file
    $currentSnapshotPath = Join-Path $tempDir "current-system-snapshot.json"
    Export-NipkgSnapshotToJson -Snapshot $currentSnapshot -OutputPath $currentSnapshotPath
    
    Write-Host "✓ Created snapshot with $($currentSnapshot.feeds.Count) feeds and $($currentSnapshot.packages.Count) packages" -ForegroundColor Green
    
    # Test compliance against itself (should be perfect)
    Write-Host "Testing compliance against current system snapshot..." -ForegroundColor Cyan
    $complianceResult = Test-NipkgSnapshotCompliance -SnapshotPath $currentSnapshotPath -NipkgCmdPath $nipkgCmdPath -Verbose
    
    if ($complianceResult.OverallCompliant) {
        Write-Host "✓ Perfect compliance test PASSED" -ForegroundColor Green
        Write-Host "  Summary: $($complianceResult.Summary)" -ForegroundColor Green
    } else {
        Write-Host "✗ Perfect compliance test FAILED" -ForegroundColor Red
        Write-Host "  Issues: $($complianceResult.TotalIssues)" -ForegroundColor Red
    }
}
catch {
    Write-Host "✗ Perfect compliance test failed with exception: $($_.Exception.Message)" -ForegroundColor Red
}
Write-Host ""

# Test 2: Test with subset of feeds (should have extra feeds)
Write-Host "Test 2: Extra Feeds Non-Compliance Test" -ForegroundColor Yellow
Write-Host "=======================================" -ForegroundColor Yellow

try {
    # Create a snapshot with only first 3 feeds
    $currentFeeds = Get-FeedsInfoFromNipkgCmd -NipkgCmdPath $nipkgCmdPath
    if ($currentFeeds.Count -gt 3) {
        $subsetFeeds = $currentFeeds | Select-Object -First 3
        $subsetSnapshot = New-NipkgSnapshot -FeedsInfo $subsetFeeds -PackagesInfo @()
        
        $subsetSnapshotPath = Join-Path $tempDir "subset-feeds-snapshot.json"
        Export-NipkgSnapshotToJson -Snapshot $subsetSnapshot -OutputPath $subsetSnapshotPath
        
        Write-Host "✓ Created subset snapshot with $($subsetSnapshot.feeds.Count) feeds (vs $($currentFeeds.Count) actual)" -ForegroundColor Green
        
        # Test compliance (should fail due to extra feeds)
        Write-Host "Testing compliance with extra feeds not allowed..." -ForegroundColor Cyan
        $complianceResult = Test-NipkgSnapshotCompliance -SnapshotPath $subsetSnapshotPath -NipkgCmdPath $nipkgCmdPath -ValidatePackages $false -AllowExtraFeeds $false
        
        if (-not $complianceResult.OverallCompliant -and $complianceResult.ExtraFeeds.Count -gt 0) {
            Write-Host "✓ Extra feeds non-compliance test PASSED" -ForegroundColor Green
            Write-Host "  Found $($complianceResult.ExtraFeeds.Count) extra feeds as expected" -ForegroundColor Green
        } else {
            Write-Host "✗ Extra feeds non-compliance test FAILED" -ForegroundColor Red
        }
        
        # Test compliance with extra feeds allowed (should pass)
        Write-Host "Testing compliance with extra feeds allowed..." -ForegroundColor Cyan
        $complianceResult2 = Test-NipkgSnapshotCompliance -SnapshotPath $subsetSnapshotPath -NipkgCmdPath $nipkgCmdPath -ValidatePackages $false -AllowExtraFeeds $true
        
        if ($complianceResult2.FeedsCompliant) {
            Write-Host "✓ Allow extra feeds test PASSED" -ForegroundColor Green
        } else {
            Write-Host "✗ Allow extra feeds test FAILED" -ForegroundColor Red
        }
    } else {
        Write-Host "⚠ Not enough feeds to test extra feeds scenario (need >3, have $($currentFeeds.Count))" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "✗ Extra feeds test failed with exception: $($_.Exception.Message)" -ForegroundColor Red
}
Write-Host ""

# Test 3: Test FailOnNonCompliance option
Write-Host "Test 3: Fail on Non-Compliance Test" -ForegroundColor Yellow
Write-Host "===================================" -ForegroundColor Yellow

try {
    # Create a fake snapshot with non-existent package
    $fakeSnapshot = @{
        feeds = @()
        packages = @(
            @{ name = "fake-non-existent-package-12345"; version = "1.0.0" }
        )
    }
    
    $fakeSnapshotPath = Join-Path $tempDir "fake-snapshot.json"
    Export-NipkgSnapshotToJson -Snapshot $fakeSnapshot -OutputPath $fakeSnapshotPath
    
    Write-Host "✓ Created fake snapshot with non-existent package" -ForegroundColor Green
    
    # Test without FailOnNonCompliance (should return non-compliant but not throw)
    Write-Host "Testing without FailOnNonCompliance..." -ForegroundColor Cyan
    $complianceResult = Test-NipkgSnapshotCompliance -SnapshotPath $fakeSnapshotPath -NipkgCmdPath $nipkgCmdPath -ValidateFeeds $false
    
    if (-not $complianceResult.OverallCompliant -and $complianceResult.MissingPackages.Count -gt 0) {
        Write-Host "✓ Non-compliance detection PASSED (no exception thrown)" -ForegroundColor Green
        Write-Host "  Missing packages: $($complianceResult.MissingPackages.Count)" -ForegroundColor Green
    } else {
        Write-Host "✗ Non-compliance detection FAILED" -ForegroundColor Red
    }
    
    # Test with FailOnNonCompliance (should throw exception)
    Write-Host "Testing with FailOnNonCompliance..." -ForegroundColor Cyan
    try {
        $complianceResult2 = Test-NipkgSnapshotCompliance -SnapshotPath $fakeSnapshotPath -NipkgCmdPath $nipkgCmdPath -ValidateFeeds $false -FailOnNonCompliance
        Write-Host "✗ FailOnNonCompliance test FAILED (no exception thrown)" -ForegroundColor Red
    }
    catch {
        if ($_.Exception.Message -like "*not compliant*") {
            Write-Host "✓ FailOnNonCompliance test PASSED (exception thrown as expected)" -ForegroundColor Green
            Write-Host "  Exception: $($_.Exception.Message)" -ForegroundColor Green
        } else {
            Write-Host "✗ FailOnNonCompliance test FAILED (wrong exception)" -ForegroundColor Red
            Write-Host "  Exception: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}
catch {
    Write-Host "✗ Fail on non-compliance test failed with exception: $($_.Exception.Message)" -ForegroundColor Red
}
Write-Host ""

# Test 4: Test validation options (feeds only, packages only)
Write-Host "Test 4: Validation Options Test" -ForegroundColor Yellow
Write-Host "==============================" -ForegroundColor Yellow

try {
    # Use the current system snapshot
    if (Test-Path $currentSnapshotPath) {
        # Test feeds only validation
        Write-Host "Testing feeds-only validation..." -ForegroundColor Cyan
        $feedsOnlyResult = Test-NipkgSnapshotCompliance -SnapshotPath $currentSnapshotPath -NipkgCmdPath $nipkgCmdPath -ValidatePackages $false
        
        if ($feedsOnlyResult.FeedsValidated -and -not $feedsOnlyResult.PackagesValidated) {
            Write-Host "✓ Feeds-only validation PASSED" -ForegroundColor Green
        } else {
            Write-Host "✗ Feeds-only validation FAILED" -ForegroundColor Red
        }
        
        # Test packages only validation
        Write-Host "Testing packages-only validation..." -ForegroundColor Cyan
        $packagesOnlyResult = Test-NipkgSnapshotCompliance -SnapshotPath $currentSnapshotPath -NipkgCmdPath $nipkgCmdPath -ValidateFeeds $false
        
        if (-not $packagesOnlyResult.FeedsValidated -and $packagesOnlyResult.PackagesValidated) {
            Write-Host "✓ Packages-only validation PASSED" -ForegroundColor Green
        } else {
            Write-Host "✗ Packages-only validation FAILED" -ForegroundColor Red
        }
    } else {
        Write-Host "⚠ Current system snapshot not available for validation options test" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "✗ Validation options test failed with exception: $($_.Exception.Message)" -ForegroundColor Red
}
Write-Host ""

# Cleanup
Write-Host "Cleanup" -ForegroundColor Yellow
Write-Host "=======" -ForegroundColor Yellow

$tempFiles = @($currentSnapshotPath, $subsetSnapshotPath, $fakeSnapshotPath)
foreach ($file in $tempFiles) {
    if ($file -and (Test-Path $file)) {
        try {
            Remove-Item $file -Force
            Write-Host "✓ Cleaned up $([System.IO.Path]::GetFileName($file))" -ForegroundColor Green
        }
        catch {
            Write-Host "⚠ Failed to clean up $([System.IO.Path]::GetFileName($file))" -ForegroundColor Yellow
        }
    }
}

Write-Host ""
Write-Host "====================================================================================" -ForegroundColor Cyan
Write-Host "Snapshot Compliance Tests Completed" -ForegroundColor Cyan
Write-Host "====================================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "KEY FEATURES TESTED:" -ForegroundColor White
Write-Host "✓ Perfect compliance validation" -ForegroundColor Green
Write-Host "✓ Extra feeds detection and control" -ForegroundColor Green
Write-Host "✓ Missing packages detection" -ForegroundColor Green
Write-Host "✓ FailOnNonCompliance option" -ForegroundColor Green
Write-Host "✓ Selective validation (feeds/packages)" -ForegroundColor Green
Write-Host ""
Write-Host "USAGE EXAMPLES:" -ForegroundColor White
Write-Host "# Basic compliance check" -ForegroundColor Gray
Write-Host "Test-NipkgSnapshotCompliance -SnapshotPath 'snapshot.json'" -ForegroundColor Gray
Write-Host ""
Write-Host "# Strict validation for CI/CD" -ForegroundColor Gray
Write-Host "Test-NipkgSnapshotCompliance -SnapshotPath 'snapshot.json' -FailOnNonCompliance" -ForegroundColor Gray
Write-Host ""
Write-Host "# Allow extra packages in development" -ForegroundColor Gray
Write-Host "Test-NipkgSnapshotCompliance -SnapshotPath 'snapshot.json' -AllowExtraPackages `$true" -ForegroundColor Gray
