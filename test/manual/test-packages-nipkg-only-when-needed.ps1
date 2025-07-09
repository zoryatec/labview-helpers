# Test script to verify packages-nipkg section is only created when ni-package-manager is present
# This script validates the enhanced logic for New-NipkgSnapshot, Export-NipkgSnapshotToJson, and Import-NipkgSnapshotFromJson

param(
    [string]$ModulePath = "..\..\LabViewHelpers\LabViewHelpers.psd1",
    [string]$TestOutputPath = ".\test-temp"
)

# Ensure test output directory exists
if (-not (Test-Path $TestOutputPath)) {
    New-Item -Path $TestOutputPath -ItemType Directory -Force | Out-Null
}

Write-Host "=== Testing packages-nipkg Section Logic ===" -ForegroundColor Cyan

try {
    # Import the module
    Import-Module $ModulePath -Force
    Write-Host "Module imported successfully" -ForegroundColor Green

    # Test data: feeds (same for both tests)
    $testFeeds = @(
        [PSCustomObject]@{ Name = "ni-feed-1"; Path = "https://feed1.example.com" },
        [PSCustomObject]@{ Name = "ni-feed-2"; Path = "https://feed2.example.com" }
    )

    Write-Host "`n--- TEST 1: No ni-package-manager package present ---" -ForegroundColor Yellow
    
    # Test packages WITHOUT ni-package-manager
    $packagesWithoutNipkg = @(
        [PSCustomObject]@{ Package = "labview-runtime"; Version = "2024.5.0" },
        [PSCustomObject]@{ Package = "ni-visa"; Version = "24.5.0" },
        [PSCustomObject]@{ Package = "ni-driver-framework"; Version = "24.5.0" }
    )

    # Create snapshot without ni-package-manager
    Write-Host "Creating snapshot without ni-package-manager package..."
    $snapshotWithoutNipkg = New-NipkgSnapshot -FeedsInfo $testFeeds -PackagesInfo $packagesWithoutNipkg
    
    # Verify packages-nipkg section is NOT present
    if ($snapshotWithoutNipkg.ContainsKey("packages-nipkg")) {
        Write-Host "FAIL: packages-nipkg section should NOT be present when no ni-package-manager package exists" -ForegroundColor Red
        Write-Host "Snapshot keys: $($snapshotWithoutNipkg.Keys -join ', ')" -ForegroundColor Red
        $testFailed = $true
    } else {
        Write-Host "PASS: packages-nipkg section correctly omitted when no ni-package-manager package" -ForegroundColor Green
    }

    # Test export/import round-trip for snapshot without packages-nipkg
    $exportPath1 = Join-Path $TestOutputPath "snapshot-without-nipkg.json"
    Write-Host "Exporting snapshot without packages-nipkg to: $exportPath1"
    $exportResult1 = Export-NipkgSnapshotToJson -Snapshot $snapshotWithoutNipkg -OutputPath $exportPath1
    Write-Host "Export result: $($exportResult1.FeedsCount) feeds, $($exportResult1.PackagesCount) packages, $($exportResult1.NipkgPackagesCount) NIPKG packages"

    Write-Host "Importing snapshot back from JSON..."
    $importedSnapshot1 = Import-NipkgSnapshotFromJson -InputPath $exportPath1
    
    # Verify imported snapshot also doesn't have packages-nipkg section
    if ($importedSnapshot1.ContainsKey("packages-nipkg")) {
        Write-Host "FAIL: Imported snapshot should NOT have packages-nipkg section" -ForegroundColor Red
        $testFailed = $true
    } else {
        Write-Host "PASS: Imported snapshot correctly omits packages-nipkg section" -ForegroundColor Green
    }

    Write-Host "`n--- TEST 2: ni-package-manager package present ---" -ForegroundColor Yellow
    
    # Test packages WITH ni-package-manager
    $packagesWithNipkg = @(
        [PSCustomObject]@{ Package = "labview-runtime"; Version = "2024.5.0" },
        [PSCustomObject]@{ Package = "ni-package-manager"; Version = "24.5.0" },
        [PSCustomObject]@{ Package = "ni-visa"; Version = "24.5.0" },
        [PSCustomObject]@{ Package = "ni-driver-framework"; Version = "24.5.0" }
    )

    # Create snapshot with ni-package-manager
    Write-Host "Creating snapshot with ni-package-manager package..."
    $snapshotWithNipkg = New-NipkgSnapshot -FeedsInfo $testFeeds -PackagesInfo $packagesWithNipkg
    
    # Verify packages-nipkg section IS present and contains packages
    if (-not $snapshotWithNipkg.ContainsKey("packages-nipkg")) {
        Write-Host "FAIL: packages-nipkg section should be present when ni-package-manager package exists" -ForegroundColor Red
        $testFailed = $true
    } elseif ($snapshotWithNipkg."packages-nipkg".Count -eq 0) {
        Write-Host "FAIL: packages-nipkg section should contain packages when ni-package-manager package exists" -ForegroundColor Red
        $testFailed = $true
    } else {
        Write-Host "PASS: packages-nipkg section correctly present with $($snapshotWithNipkg.'packages-nipkg'.Count) packages" -ForegroundColor Green
        Write-Host "NIPKG packages: $($snapshotWithNipkg.'packages-nipkg' | ForEach-Object { "$($_.name)=$($_.version)" } | Join-String -Separator ', ')"
    }

    # Test export/import round-trip for snapshot with packages-nipkg
    $exportPath2 = Join-Path $TestOutputPath "snapshot-with-nipkg.json"
    Write-Host "Exporting snapshot with packages-nipkg to: $exportPath2"
    $exportResult2 = Export-NipkgSnapshotToJson -Snapshot $snapshotWithNipkg -OutputPath $exportPath2
    Write-Host "Export result: $($exportResult2.FeedsCount) feeds, $($exportResult2.PackagesCount) packages, $($exportResult2.NipkgPackagesCount) NIPKG packages"

    Write-Host "Importing snapshot back from JSON..."
    $importedSnapshot2 = Import-NipkgSnapshotFromJson -InputPath $exportPath2
    
    # Verify imported snapshot has packages-nipkg section with same count
    if (-not $importedSnapshot2.ContainsKey("packages-nipkg")) {
        Write-Host "FAIL: Imported snapshot should have packages-nipkg section" -ForegroundColor Red
        $testFailed = $true
    } elseif ($importedSnapshot2."packages-nipkg".Count -ne $snapshotWithNipkg."packages-nipkg".Count) {
        Write-Host "FAIL: Imported snapshot packages-nipkg count mismatch. Expected: $($snapshotWithNipkg.'packages-nipkg'.Count), Got: $($importedSnapshot2.'packages-nipkg'.Count)" -ForegroundColor Red
        $testFailed = $true
    } else {
        Write-Host "PASS: Imported snapshot correctly preserves packages-nipkg section with $($importedSnapshot2.'packages-nipkg'.Count) packages" -ForegroundColor Green
    }

    Write-Host "`n--- TEST 3: Sync function with no packages-nipkg section ---" -ForegroundColor Yellow
    
    # Test Sync-NipkgVersionWithSnapshot with snapshot that has no packages-nipkg section
    Write-Host "Testing Sync-NipkgVersionWithSnapshot with snapshot without packages-nipkg..."
    $syncResult1 = Sync-NipkgVersionWithSnapshot -Snapshot $importedSnapshot1 -WhatIf
    
    if ($syncResult1.PackagesInstalled -ne 0 -or $syncResult1.PackagesFailed -ne 0) {
        Write-Host "FAIL: Sync should install 0 packages when no packages-nipkg section exists" -ForegroundColor Red
        $testFailed = $true
    } else {
        Write-Host "PASS: Sync correctly handles missing packages-nipkg section" -ForegroundColor Green
    }

    Write-Host "`n--- TEST 4: Verify JSON content ---" -ForegroundColor Yellow
    
    # Check the actual JSON content to ensure packages-nipkg is only present when expected
    $jsonContent1 = Get-Content $exportPath1 -Raw | ConvertFrom-Json
    $jsonContent2 = Get-Content $exportPath2 -Raw | ConvertFrom-Json
    
    $hasPackagesNipkgProperty1 = $null -ne $jsonContent1.PSObject.Properties["packages-nipkg"]
    $hasPackagesNipkgProperty2 = $null -ne $jsonContent2.PSObject.Properties["packages-nipkg"]
    
    if ($hasPackagesNipkgProperty1) {
        Write-Host "FAIL: JSON without ni-package-manager should not have packages-nipkg property" -ForegroundColor Red
        $testFailed = $true
    } else {
        Write-Host "PASS: JSON without ni-package-manager correctly omits packages-nipkg property" -ForegroundColor Green
    }
    
    if (-not $hasPackagesNipkgProperty2) {
        Write-Host "FAIL: JSON with ni-package-manager should have packages-nipkg property" -ForegroundColor Red
        $testFailed = $true
    } else {
        Write-Host "PASS: JSON with ni-package-manager correctly includes packages-nipkg property" -ForegroundColor Green
    }

    Write-Host "`n=== Test Summary ===" -ForegroundColor Cyan
    if ($testFailed) {
        Write-Host "Some tests FAILED. Please review the issues above." -ForegroundColor Red
        exit 1
    } else {
        Write-Host "All tests PASSED! The packages-nipkg section logic is working correctly." -ForegroundColor Green
        Write-Host "- packages-nipkg section is only created when ni-package-manager package is present" -ForegroundColor Green
        Write-Host "- Export/import preserves the presence or absence of packages-nipkg section" -ForegroundColor Green
        Write-Host "- Sync function correctly handles missing packages-nipkg section" -ForegroundColor Green
        exit 0
    }
}
catch {
    Write-Host "Test execution failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack trace: $($_.ScriptStackTrace)" -ForegroundColor Red
    exit 1
}
finally {
    # Clean up
    Remove-Module LabViewHelpers -ErrorAction SilentlyContinue
}
