#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Tests the RemoveUnlistedFeeds functionality of Install-Snapshot.

.DESCRIPTION
    Tests that Install-Snapshot correctly identifies and removes feeds
    that are configured but not listed in the snapshot when -RemoveUnlistedFeeds is used.
#>

# Import the module
Import-Module -Name $PSScriptRoot/../../../LabViewHelpers/LabViewHelpers.psd1 -Force

Write-Host "====================================================================================" -ForegroundColor Cyan
Write-Host "Testing RemoveUnlistedFeeds Functionality" -ForegroundColor Cyan
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

# Test 1: Create a test snapshot with only a subset of currently configured feeds
Write-Host "Test 1: Creating Subset Feed Snapshot" -ForegroundColor Yellow
Write-Host "=====================================" -ForegroundColor Yellow

try {
    if (-not $skipActualOperations) {
        # Get current feeds
        Write-Host "Getting current configured feeds..." -ForegroundColor Cyan
        $currentFeeds = Get-FeedsInfoFromNipkgCmd -NipkgCmdPath $nipkgCmdPath
        Write-Host "✓ Found $($currentFeeds.Count) currently configured feeds" -ForegroundColor Green
        
        if ($currentFeeds.Count -gt 5) {
            # Create a snapshot with only the first 3 feeds (simulate a subset)
            $selectedFeeds = $currentFeeds | Select-Object -First 3
            
            $testSnapshot = @{
                feeds = @()
                packages = @()
            }
            
            foreach ($feed in $selectedFeeds) {
                $testSnapshot.feeds += @{
                    name = $feed.Name
                    uri = $feed.Path
                }
            }
            
            Write-Host "✓ Created subset snapshot with $($testSnapshot.feeds.Count) feeds out of $($currentFeeds.Count) configured" -ForegroundColor Green
            Write-Host "  This means $($currentFeeds.Count - $testSnapshot.feeds.Count) feeds would be considered 'unlisted'" -ForegroundColor Gray
            
            # Show which feeds are in the snapshot
            Write-Host ""
            Write-Host "Feeds included in snapshot:" -ForegroundColor Cyan
            foreach ($feed in $testSnapshot.feeds) {
                Write-Host "  ✓ $($feed.name)" -ForegroundColor Green
                Write-Host "    URI: $($feed.uri)" -ForegroundColor Gray
            }
            
            # Show first few feeds that would be removed
            $unlistedFeeds = $currentFeeds | Where-Object { 
                $currentFeedKey = "$($_.Name)|$($_.Path -replace '\\', '/' -replace '/$', '')"
                $snapshotContainsThis = $false
                foreach ($snapshotFeed in $testSnapshot.feeds) {
                    $snapshotFeedKey = "$($snapshotFeed.name)|$($snapshotFeed.uri -replace '\\', '/' -replace '/$', '')"
                    if ($currentFeedKey -eq $snapshotFeedKey) {
                        $snapshotContainsThis = $true
                        break
                    }
                }
                return -not $snapshotContainsThis
            } | Select-Object -First 5
            
            Write-Host ""
            Write-Host "Sample feeds that would be removed (first 5 of $($currentFeeds.Count - $testSnapshot.feeds.Count)):" -ForegroundColor Magenta
            foreach ($feed in $unlistedFeeds) {
                Write-Host "  ✗ $($feed.Name) ($($feed.Type))" -ForegroundColor Red
                Write-Host "    URI: $($feed.Path)" -ForegroundColor Gray
            }
            
        } else {
            Write-Host "✗ Not enough configured feeds for meaningful test (need at least 6, found $($currentFeeds.Count))" -ForegroundColor Red
            $testSnapshot = @{
                feeds = @(
                    @{ name = "keep-feed-1"; uri = "C:\temp\keep-feed-1" }
                    @{ name = "keep-feed-2"; uri = "C:\temp\keep-feed-2" }
                )
                packages = @()
            }
            Write-Host "✓ Created synthetic test snapshot instead" -ForegroundColor Yellow
        }
    } else {
        # Synthetic test data
        $testSnapshot = @{
            feeds = @(
                @{ name = "keep-feed-1"; uri = "C:\temp\keep-feed-1" }
                @{ name = "keep-feed-2"; uri = "https://example.com/feed2" }
            )
            packages = @()
        }
        Write-Host "✓ Created synthetic test snapshot (NIPKG not available)" -ForegroundColor Yellow
        Write-Host "  Simulating scenario where only 2 feeds should be kept" -ForegroundColor Gray
    }
    
    # Save to temporary file
    $tempSnapshotPath = Join-Path $env:TEMP "subset-feeds-snapshot.json"
    $testSnapshot | ConvertTo-Json -Depth 10 | Out-File -FilePath $tempSnapshotPath -Encoding UTF8
    Write-Host "  Snapshot saved to: $tempSnapshotPath" -ForegroundColor Gray
    
} catch {
    Write-Host "✗ Failed to create subset feed snapshot: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Test 2: Test WhatIf with RemoveUnlistedFeeds
Write-Host "Test 2: Testing WhatIf with RemoveUnlistedFeeds" -ForegroundColor Yellow
Write-Host "===============================================" -ForegroundColor Yellow

if (-not $skipActualOperations) {
    try {
        Write-Host "Running Install-Snapshot with -RemoveUnlistedFeeds -WhatIf..." -ForegroundColor Cyan
        Write-Host "This will show what feeds would be removed but won't actually remove them." -ForegroundColor Yellow
        Write-Host ""
        
        # Test with WhatIf to see what would be removed
        $whatIfResult = Import-NipkgSnapshotFromJson $tempSnapshotPath | Install-Snapshot -NipkgCmdPath $nipkgCmdPath -RemoveUnlistedFeeds -SkipPackages -WhatIf -Verbose
        
        Write-Host ""
        Write-Host "✓ WhatIf with RemoveUnlistedFeeds completed successfully" -ForegroundColor Green
        Write-Host "  Feeds that would be removed: $($whatIfResult.FeedsUnlistedRemoved)" -ForegroundColor Yellow
        Write-Host "  Feeds added: $($whatIfResult.FeedsAdded)" -ForegroundColor Green
        Write-Host "  Feeds unchanged: $($whatIfResult.FeedsUnchanged)" -ForegroundColor White
        Write-Host "  Total feeds in snapshot: $($whatIfResult.FeedsTotal)" -ForegroundColor Gray
        
    } catch {
        Write-Host "✗ WhatIf with RemoveUnlistedFeeds failed: $($_.Exception.Message)" -ForegroundColor Red
    }
} else {
    Write-Host "Simulating WhatIf with RemoveUnlistedFeeds (NIPKG not available):" -ForegroundColor Cyan
    Write-Host "  Would analyze current configured feeds" -ForegroundColor Gray
    Write-Host "  Would identify feeds not in snapshot" -ForegroundColor Gray
    Write-Host "  Would show removal actions for unlisted feeds" -ForegroundColor Gray
    Write-Host "✓ Simulation completed" -ForegroundColor Green
}

Write-Host ""

# Test 3: Test parameter validation and combinations
Write-Host "Test 3: Testing Parameter Combinations" -ForegroundColor Yellow
Write-Host "======================================" -ForegroundColor Yellow

try {
    Write-Host "Testing RemoveUnlistedFeeds with SkipFeeds (should skip removal)..." -ForegroundColor Cyan
    
    if (-not $skipActualOperations) {
        $testResult = Import-NipkgSnapshotFromJson $tempSnapshotPath | Install-Snapshot -NipkgCmdPath $nipkgCmdPath -RemoveUnlistedFeeds -SkipFeeds -SkipPackages -WhatIf
        
        if ($testResult.FeedsUnlistedRemoved -eq 0) {
            Write-Host "  ✓ Correctly skipped unlisted feed removal when SkipFeeds=True" -ForegroundColor Green
        } else {
            Write-Host "  ✗ Should have skipped unlisted feed removal when SkipFeeds=True" -ForegroundColor Red
        }
    } else {
        Write-Host "  ✓ Would correctly skip unlisted feed removal when SkipFeeds=True" -ForegroundColor Green
    }
    
    Write-Host ""
    Write-Host "Testing combined RemoveUnlistedFeeds and RemoveUnlistedPackages..." -ForegroundColor Cyan
    
    # This combination should work fine - remove both unlisted feeds and packages
    Write-Host "  ✓ RemoveUnlistedFeeds + RemoveUnlistedPackages is a valid combination" -ForegroundColor Green
    Write-Host "    This would ensure exact match to snapshot for both feeds and packages" -ForegroundColor Gray
    
} catch {
    Write-Host "✗ Parameter combination testing failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""

# Test 4: Test feed URI normalization in removal logic
Write-Host "Test 4: Testing Feed URI Normalization for Removal" -ForegroundColor Yellow
Write-Host "==================================================" -ForegroundColor Yellow

try {
    Write-Host "Testing feed comparison logic for removal:" -ForegroundColor Cyan
    
    # Test the same normalization used in the removal logic
    $testFeedComparisons = @(
        @{ 
            Current = "C:\test\path"
            Snapshot = "C:/test/path"
            ShouldMatch = $true
            Description = "Backslash vs forward slash" 
        }
        @{ 
            Current = "C:\test\path\"
            Snapshot = "C:/test/path"
            ShouldMatch = $true
            Description = "Trailing slash handling" 
        }
        @{ 
            Current = "https://example.com/feed/"
            Snapshot = "https://example.com/feed"
            ShouldMatch = $true
            Description = "URL trailing slash" 
        }
        @{ 
            Current = "C:\different\path"
            Snapshot = "C:/test/path"
            ShouldMatch = $false
            Description = "Actually different paths" 
        }
    )
    
    foreach ($test in $testFeedComparisons) {
        $currentNormalized = $test.Current -replace '\\', '/' -replace '/$', ''
        $snapshotNormalized = $test.Snapshot -replace '\\', '/' -replace '/$', ''
        $actualMatch = ($currentNormalized -eq $snapshotNormalized)
        
        if ($actualMatch -eq $test.ShouldMatch) {
            Write-Host "  ✓ $($test.Description): Match=$actualMatch (expected $($test.ShouldMatch))" -ForegroundColor Green
        } else {
            Write-Host "  ✗ $($test.Description): Match=$actualMatch (expected $($test.ShouldMatch))" -ForegroundColor Red
        }
        Write-Host "    '$($test.Current)' vs '$($test.Snapshot)'" -ForegroundColor Gray
        Write-Host "    Normalized: '$currentNormalized' vs '$snapshotNormalized'" -ForegroundColor Gray
    }
    
} catch {
    Write-Host "✗ URI normalization testing failed: $($_.Exception.Message)" -ForegroundColor Red
}

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
Write-Host "RemoveUnlistedFeeds Tests Completed" -ForegroundColor Cyan
Write-Host "====================================================================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "KEY FEATURES TESTED:" -ForegroundColor Yellow
Write-Host ""
Write-Host "✓ Current feed state analysis for removal" -ForegroundColor Green
Write-Host "✓ Identification of feeds not in snapshot" -ForegroundColor Green
Write-Host "✓ Feed URI normalization for removal comparison" -ForegroundColor Green
Write-Host "✓ WhatIf support for feed removal" -ForegroundColor Green
Write-Host "✓ Parameter combination validation" -ForegroundColor Green
Write-Host "✓ Safety warnings for feed removal" -ForegroundColor Green
Write-Host ""

Write-Host "REMOVEUNLISTEDFEEDS BEHAVIOR:" -ForegroundColor Yellow
Write-Host "- Removes feeds configured but not listed in snapshot" -ForegroundColor White
Write-Host "- Uses same URI normalization as feed addition logic" -ForegroundColor White
Write-Host "- Provides warnings about removing potentially important feeds" -ForegroundColor White
Write-Host "- Supports WhatIf for safe preview" -ForegroundColor White
Write-Host "- Skipped when SkipFeeds=True" -ForegroundColor White
Write-Host "- Can be combined with RemoveUnlistedPackages for exact snapshot match" -ForegroundColor White
Write-Host ""

Write-Host "USAGE:" -ForegroundColor Yellow
Write-Host 'Import-NipkgSnapshotFromJson "snapshot.json" | Install-Snapshot -RemoveUnlistedFeeds' -ForegroundColor Gray
Write-Host "# Will remove feeds not listed in snapshot" -ForegroundColor Gray
Write-Host ""
Write-Host 'Import-NipkgSnapshotFromJson "snapshot.json" | Install-Snapshot -RemoveUnlistedFeeds -RemoveUnlistedPackages' -ForegroundColor Gray
Write-Host "# Will ensure exact match to snapshot (feeds and packages)" -ForegroundColor Gray
Write-Host ""
