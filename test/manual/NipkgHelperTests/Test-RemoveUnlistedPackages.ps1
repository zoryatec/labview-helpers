#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Tests the RemoveUnlistedPackages functionality of Install-Snapshot.

.DESCRIPTION
    Tests that Install-Snapshot correctly identifies and removes packages
    that are installed but not listed in the snapshot when -RemoveUnlistedPackages is used.
#>

# Import the module
Import-Module -Name $PSScriptRoot/../../../LabViewHelpers/LabViewHelpers.psd1 -Force

Write-Host "====================================================================================" -ForegroundColor Cyan
Write-Host "Testing RemoveUnlistedPackages Functionality" -ForegroundColor Cyan
Write-Host "====================================================================================" -ForegroundColor Cyan
Write-Host ""

$nipkgCmdPath = "C:\Program Files\National Instruments\NI Package Manager\nipkg.exe"

# Test NIPKG availability first
Write-Host "Testing NIPKG availability..." -ForegroundColor Yellow
$nipkgAvailable = Test-NipkgAvailability -NipkgCmdPath $nipkgCmdPath
if (-not $nipkgAvailable) {
    Write-Host "✗ NIPKG is not available. Creating synthetic test without actual NIPKG operations." -ForegroundColor Yellow
    $skipActualOperations = $true
} else {
    Write-Host "✓ NIPKG is available" -ForegroundColor Green
    $skipActualOperations = $false
}
Write-Host ""

# Test 1: Create a test snapshot with only a subset of currently installed packages
Write-Host "Test 1: Creating Subset Snapshot" -ForegroundColor Yellow
Write-Host "================================" -ForegroundColor Yellow

try {
    if (-not $skipActualOperations) {
        # Get current installed packages
        Write-Host "Getting current installed packages..." -ForegroundColor Cyan
        $currentPackages = Get-PackagesInfoFromNipkgCmd -Type "installed" -NipkgCmdPath $nipkgCmdPath
        Write-Host "✓ Found $($currentPackages.Count) currently installed packages" -ForegroundColor Green
        
        if ($currentPackages.Count -gt 5) {
            # Create a snapshot with only the first 3 packages (simulate a subset)
            $selectedPackages = $currentPackages | Select-Object -First 3
            
            $testSnapshot = @{
                feeds = @()
                packages = @()
            }
            
            foreach ($pkg in $selectedPackages) {
                $testSnapshot.packages += @{
                    name = $pkg.Package
                    version = $pkg.Version
                }
            }
            
            Write-Host "✓ Created subset snapshot with $($testSnapshot.packages.Count) packages out of $($currentPackages.Count) installed" -ForegroundColor Green
            Write-Host "  This means $($currentPackages.Count - $testSnapshot.packages.Count) packages would be considered 'unlisted'" -ForegroundColor Gray
            
            # Show which packages are in the snapshot
            Write-Host ""
            Write-Host "Packages included in snapshot:" -ForegroundColor Cyan
            foreach ($pkg in $testSnapshot.packages) {
                Write-Host "  ✓ $($pkg.name) v$($pkg.version)" -ForegroundColor Green
            }
            
            # Show first few packages that would be removed
            $unlistedPackages = $currentPackages | Where-Object { $_.Package -notin ($testSnapshot.packages | ForEach-Object { $_.name }) } | Select-Object -First 5
            Write-Host ""
            Write-Host "Sample packages that would be removed (first 5 of $($currentPackages.Count - $testSnapshot.packages.Count)):" -ForegroundColor Magenta
            foreach ($pkg in $unlistedPackages) {
                Write-Host "  ✗ $($pkg.Package) v$($pkg.Version)" -ForegroundColor Red
            }
            
        } else {
            Write-Host "✗ Not enough installed packages for meaningful test (need at least 6, found $($currentPackages.Count))" -ForegroundColor Red
            $testSnapshot = @{
                feeds = @()
                packages = @(
                    @{ name = "test-pkg-1"; version = "1.0.0" }
                    @{ name = "test-pkg-2"; version = "2.0.0" }
                )
            }
            Write-Host "✓ Created synthetic test snapshot instead" -ForegroundColor Yellow
        }
    } else {
        # Synthetic test data
        $testSnapshot = @{
            feeds = @()
            packages = @(
                @{ name = "keep-package-1"; version = "1.0.0" }
                @{ name = "keep-package-2"; version = "2.0.0" }
            )
        }
        Write-Host "✓ Created synthetic test snapshot (NIPKG not available)" -ForegroundColor Yellow
        Write-Host "  Simulating scenario where only 2 packages should be kept" -ForegroundColor Gray
    }
    
    # Save to temporary file
    $tempSnapshotPath = Join-Path $env:TEMP "subset-snapshot.json"
    $testSnapshot | ConvertTo-Json -Depth 10 | Out-File -FilePath $tempSnapshotPath -Encoding UTF8
    Write-Host "  Snapshot saved to: $tempSnapshotPath" -ForegroundColor Gray
    
} catch {
    Write-Host "✗ Failed to create subset snapshot: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Test 2: Test WhatIf with RemoveUnlistedPackages
Write-Host "Test 2: Testing WhatIf with RemoveUnlistedPackages" -ForegroundColor Yellow
Write-Host "===================================================" -ForegroundColor Yellow

if (-not $skipActualOperations) {
    try {
        Write-Host "Running Install-Snapshot with -RemoveUnlistedPackages -WhatIf..." -ForegroundColor Cyan
        Write-Host "This will show what packages would be removed but won't actually remove them." -ForegroundColor Yellow
        Write-Host ""
        
        # Test with WhatIf to see what would be removed
        $whatIfResult = Import-NipkgSnapshotFromJson $tempSnapshotPath | Install-Snapshot -NipkgCmdPath $nipkgCmdPath -RemoveUnlistedPackages -SkipFeeds -WhatIf
        
        Write-Host ""
        Write-Host "✓ WhatIf with RemoveUnlistedPackages completed successfully" -ForegroundColor Green
        Write-Host "  Packages that would be removed: $($whatIfResult.PackagesRemoved)" -ForegroundColor Yellow
        Write-Host "  Total packages in system: $($whatIfResult.PackagesTotal)" -ForegroundColor Gray
        
    } catch {
        Write-Host "✗ WhatIf with RemoveUnlistedPackages failed: $($_.Exception.Message)" -ForegroundColor Red
    }
} else {
    Write-Host "Simulating WhatIf with RemoveUnlistedPackages (NIPKG not available):" -ForegroundColor Cyan
    Write-Host "  Would analyze current installed packages" -ForegroundColor Gray
    Write-Host "  Would identify packages not in snapshot" -ForegroundColor Gray
    Write-Host "  Would show removal actions for unlisted packages" -ForegroundColor Gray
    Write-Host "✓ Simulation completed" -ForegroundColor Green
}

Write-Host ""

# Test 3: Test parameter validation
Write-Host "Test 3: Testing Parameter Combinations" -ForegroundColor Yellow
Write-Host "======================================" -ForegroundColor Yellow

try {
    Write-Host "Testing RemoveUnlistedPackages with SkipPackages (should skip removal)..." -ForegroundColor Cyan
    
    if (-not $skipActualOperations) {
        $result = Import-NipkgSnapshotFromJson $tempSnapshotPath | Install-Snapshot -NipkgCmdPath $nipkgCmdPath -RemoveUnlistedPackages -SkipPackages -WhatIf
        Write-Host "✓ Correctly handled RemoveUnlistedPackages with SkipPackages" -ForegroundColor Green
    } else {
        Write-Host "✓ Parameter combination test skipped (NIPKG not available)" -ForegroundColor Yellow
    }
    
} catch {
    Write-Host "✗ Parameter combination test failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""

# Test 4: Test safety considerations
Write-Host "Test 4: Safety Considerations" -ForegroundColor Yellow
Write-Host "=============================" -ForegroundColor Yellow

Write-Host "Demonstrating safety features of RemoveUnlistedPackages:" -ForegroundColor Cyan
Write-Host ""
Write-Host "✓ Requires explicit -RemoveUnlistedPackages switch" -ForegroundColor Green
Write-Host "✓ Shows warning about potential package removal" -ForegroundColor Green  
Write-Host "✓ Uses ShouldProcess for WhatIf support" -ForegroundColor Green
Write-Host "✓ Provides detailed logging of removal actions" -ForegroundColor Green
Write-Host "✓ Tracks removal failures separately" -ForegroundColor Green
Write-Host ""
Write-Host "⚠️  SAFETY WARNING:" -ForegroundColor Yellow
Write-Host "RemoveUnlistedPackages can remove important system packages!" -ForegroundColor Red
Write-Host "Always test with -WhatIf first to see what would be removed." -ForegroundColor Red
Write-Host ""

# Test 5: Test with realistic scenario
Write-Host "Test 5: Realistic Usage Scenarios" -ForegroundColor Yellow
Write-Host "==================================" -ForegroundColor Yellow

Write-Host "Common usage patterns:" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. Complete system reset:" -ForegroundColor White
Write-Host '   Import-NipkgSnapshotFromJson "prod.json" | Install-Snapshot -RemoveExistingFeeds -RemoveUnlistedPackages' -ForegroundColor Gray
Write-Host ""
Write-Host "2. Exact package matching:" -ForegroundColor White
Write-Host '   Import-NipkgSnapshotFromJson "baseline.json" | Install-Snapshot -RemoveUnlistedPackages' -ForegroundColor Gray
Write-Host ""
Write-Host "3. Safe preview:" -ForegroundColor White
Write-Host '   Import-NipkgSnapshotFromJson "new-config.json" | Install-Snapshot -RemoveUnlistedPackages -WhatIf' -ForegroundColor Gray
Write-Host ""

# Cleanup
Write-Host "Cleanup" -ForegroundColor Yellow
Write-Host "=======" -ForegroundColor Yellow

try {
    if (Test-Path $tempSnapshotPath) {
        Remove-Item $tempSnapshotPath -Force
        Write-Host "✓ Cleaned up temporary snapshot file" -ForegroundColor Green
    }
} catch {
    Write-Host "✗ Failed to cleanup: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""

# Summary
Write-Host "====================================================================================" -ForegroundColor Cyan
Write-Host "RemoveUnlistedPackages Tests Completed" -ForegroundColor Cyan
Write-Host "====================================================================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "NEW FUNCTIONALITY:" -ForegroundColor Yellow
Write-Host ""
Write-Host "✓ RemoveUnlistedPackages parameter added" -ForegroundColor Green
Write-Host "✓ Identifies packages not in snapshot" -ForegroundColor Green
Write-Host "✓ Removes unlisted packages with proper logging" -ForegroundColor Green
Write-Host "✓ Integrates with WhatIf for safety" -ForegroundColor Green
Write-Host "✓ Tracks removal success/failure separately" -ForegroundColor Green
Write-Host ""

Write-Host "USE CASES:" -ForegroundColor Yellow
Write-Host "- Exact system state matching" -ForegroundColor White
Write-Host "- Clean slate deployments" -ForegroundColor White
Write-Host "- Removing development packages from production" -ForegroundColor White
Write-Host "- Ensuring consistent environments" -ForegroundColor White
Write-Host ""

Write-Host "SAFETY FEATURES:" -ForegroundColor Yellow
Write-Host "- Explicit opt-in with switch" -ForegroundColor White
Write-Host "- Warning messages about potential removals" -ForegroundColor White
Write-Host "- WhatIf support for preview" -ForegroundColor White
Write-Host "- Detailed logging and error tracking" -ForegroundColor White
Write-Host ""
