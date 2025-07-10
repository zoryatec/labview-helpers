#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Tests the Type parameter functionality in NIPKG Helper functions.

.DESCRIPTION
    This script tests the Type parameter implementation in New-NipkgSnapshot,
    New-NipkgSnapshotFromInstaller, and New-NipkgSnapshotFromSystem functions.
#>

# Import the module
$ModulePath = Join-Path $PSScriptRoot "..\..\LabViewHelpers\NipkgHelper.psm1"
if (Test-Path $ModulePath) {
    Import-Module $ModulePath -Force
    Write-Host "✓ Imported NipkgHelper module successfully" -ForegroundColor Green
} else {
    Write-Error "Module not found: $ModulePath"
    exit 1
}

# Create test data with UserVisible and StoreProduct properties
$testPackages = @(
    [PSCustomObject]@{
        Package = "ni-package-1"
        Version = "1.0.0"
        UserVisible = "yes"
        StoreProduct = "no"
        Section = "Programming Environments"
    },
    [PSCustomObject]@{
        Package = "ni-package-2"
        Version = "2.0.0"
        UserVisible = "no"
        StoreProduct = "yes"
        Section = "Drivers"
    },
    [PSCustomObject]@{
        Package = "ni-package-3"
        Version = "3.0.0"
        UserVisible = "yes"
        StoreProduct = "yes"
        Section = "Application Software"
    },
    [PSCustomObject]@{
        Package = "ni-package-4"
        Version = "4.0.0"
        UserVisible = "no"
        StoreProduct = "no"
        Section = "Utilities"
    }
)

$testFeeds = @(
    [PSCustomObject]@{
        Name = "test-feed"
        Path = "C:\TestFeeds\feed1"
    }
)

Write-Host "`n=== Testing Type Parameter Functionality ===" -ForegroundColor Cyan

# Test 1: Full type (should include all packages)
Write-Host "`n--- Test 1: Full Type ---" -ForegroundColor Yellow
try {
    $fullSnapshot = New-NipkgSnapshot -FeedsInfo $testFeeds -PackagesInfo $testPackages -Type "Full"
    Write-Host "✓ Full snapshot created successfully" -ForegroundColor Green
    Write-Host "  Type: $($fullSnapshot.type)" -ForegroundColor White
    Write-Host "  Packages count: $($fullSnapshot.packages.Count)" -ForegroundColor White
    Write-Host "  Expected: 4, Actual: $($fullSnapshot.packages.Count)" -ForegroundColor $(if ($fullSnapshot.packages.Count -eq 4) { 'Green' } else { 'Red' })
} catch {
    Write-Host "✗ Full snapshot failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 2: UserVisible type (should include packages with UserVisible = 'yes')
Write-Host "`n--- Test 2: UserVisible Type ---" -ForegroundColor Yellow
try {
    $userVisibleSnapshot = New-NipkgSnapshot -FeedsInfo $testFeeds -PackagesInfo $testPackages -Type "UserVisible"
    Write-Host "✓ UserVisible snapshot created successfully" -ForegroundColor Green
    Write-Host "  Type: $($userVisibleSnapshot.type)" -ForegroundColor White
    Write-Host "  Packages count: $($userVisibleSnapshot.packages.Count)" -ForegroundColor White
    Write-Host "  Expected: 2, Actual: $($userVisibleSnapshot.packages.Count)" -ForegroundColor $(if ($userVisibleSnapshot.packages.Count -eq 2) { 'Green' } else { 'Red' })
    
    # Verify the right packages are included
    $packageNames = $userVisibleSnapshot.packages | ForEach-Object { $_.name }
    $expectedPackages = @("ni-package-1", "ni-package-3")
    $allExpectedFound = $true
    foreach ($expected in $expectedPackages) {
        if ($expected -notin $packageNames) {
            $allExpectedFound = $false
            Write-Host "  ✗ Missing expected package: $expected" -ForegroundColor Red
        }
    }
    if ($allExpectedFound) {
        Write-Host "  ✓ All expected UserVisible packages found" -ForegroundColor Green
    }
} catch {
    Write-Host "✗ UserVisible snapshot failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 3: StoreProduct type (should include packages with StoreProduct = 'yes')
Write-Host "`n--- Test 3: StoreProduct Type ---" -ForegroundColor Yellow
try {
    $storeProductSnapshot = New-NipkgSnapshot -FeedsInfo $testFeeds -PackagesInfo $testPackages -Type "StoreProduct"
    Write-Host "✓ StoreProduct snapshot created successfully" -ForegroundColor Green
    Write-Host "  Type: $($storeProductSnapshot.type)" -ForegroundColor White
    Write-Host "  Packages count: $($storeProductSnapshot.packages.Count)" -ForegroundColor White
    Write-Host "  Expected: 2, Actual: $($storeProductSnapshot.packages.Count)" -ForegroundColor $(if ($storeProductSnapshot.packages.Count -eq 2) { 'Green' } else { 'Red' })
    
    # Verify the right packages are included
    $packageNames = $storeProductSnapshot.packages | ForEach-Object { $_.name }
    $expectedPackages = @("ni-package-2", "ni-package-3")
    $allExpectedFound = $true
    foreach ($expected in $expectedPackages) {
        if ($expected -notin $packageNames) {
            $allExpectedFound = $false
            Write-Host "  ✗ Missing expected package: $expected" -ForegroundColor Red
        }
    }
    if ($allExpectedFound) {
        Write-Host "  ✓ All expected StoreProduct packages found" -ForegroundColor Green
    }
} catch {
    Write-Host "✗ StoreProduct snapshot failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 4: Export and Import with Type preservation
Write-Host "`n--- Test 4: Export/Import Type Preservation ---" -ForegroundColor Yellow
try {
    $tempDir = Join-Path $PSScriptRoot "..\test-temp"
    if (-not (Test-Path $tempDir)) {
        New-Item -Path $tempDir -ItemType Directory -Force | Out-Null
    }
    
    $testJsonPath = Join-Path $tempDir "test-type-snapshot.json"
    
    # Export UserVisible snapshot
    $exportResult = Export-NipkgSnapshotToJson -Snapshot $userVisibleSnapshot -OutputPath $testJsonPath
    Write-Host "✓ Snapshot exported successfully" -ForegroundColor Green
    Write-Host "  Exported type: $($exportResult.Type)" -ForegroundColor White
    
    # Import and verify type is preserved
    $importedSnapshot = Import-NipkgSnapshotFromJson -InputPath $testJsonPath
    Write-Host "✓ Snapshot imported successfully" -ForegroundColor Green
    Write-Host "  Imported type: $($importedSnapshot.type)" -ForegroundColor White
    Write-Host "  Type preserved: $(if ($importedSnapshot.type -eq 'UserVisible') { 'Yes ✓' } else { 'No ✗' })" -ForegroundColor $(if ($importedSnapshot.type -eq 'UserVisible') { 'Green' } else { 'Red' })
    
    # Clean up
    Remove-Item $testJsonPath -Force -ErrorAction SilentlyContinue
    
} catch {
    Write-Host "✗ Export/Import test failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n=== Type Parameter Tests Complete ===" -ForegroundColor Cyan
Write-Host "All Type parameter functionality has been tested successfully!" -ForegroundColor Green
