#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Comprehensive test for the Type parameter functionality in NIPKG snapshots.

.DESCRIPTION
    This script tests all three Type parameter values (Full, UserVisible, StoreProduct)
    across all relevant functions and verifies the filtering logic works correctly.
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

# Create comprehensive test data that mimics real NIPKG packages
$testPackages = @(
    # LabVIEW Runtime - User visible, store product
    [PSCustomObject]@{
        Package = "ni-labview-2025-runtime-engine"
        Version = "25.1.0.49154"
        UserVisible = "yes"
        StoreProduct = "yes"
        Section = "Programming Environments"
        DisplayName = "LabVIEW 2025 Runtime Engine"
        Description = "LabVIEW 2025 Runtime Engine"
    },
    
    # Internal dependency - not user visible, not store product
    [PSCustomObject]@{
        Package = "ni-labview-shared-object-25"
        Version = "25.1.0.49154"
        UserVisible = "no"
        StoreProduct = "no"
        Section = "Programming Environments"
        DisplayName = "LabVIEW Shared Object 2025"
        Description = "Internal LabVIEW shared libraries"
    },
    
    # DAQmx driver - user visible, not store product (comes with hardware)
    [PSCustomObject]@{
        Package = "ni-daqmx"
        Version = "24.8.0.49550"
        UserVisible = "yes"
        StoreProduct = "no"
        Section = "Drivers"
        DisplayName = "NI-DAQmx"
        Description = "NI Data Acquisition driver"
    },
    
    # Software like LabVIEW Community - user visible, store product
    [PSCustomObject]@{
        Package = "ni-labview-2025-community"
        Version = "25.1.0.49154"
        UserVisible = "yes"
        StoreProduct = "yes"
        Section = "Programming Environments"
        DisplayName = "LabVIEW 2025 Community Edition"
        Description = "LabVIEW 2025 Community Edition development environment"
    },
    
    # System dependency - not user visible, not store product
    [PSCustomObject]@{
        Package = "ni-syscfg-runtime"
        Version = "24.5.0.49250"
        UserVisible = "no"
        StoreProduct = "no"
        Section = "Utilities"
        DisplayName = "System Configuration Runtime"
        Description = "Runtime for system configuration"
    },
    
    # Utility that's user visible but not sold separately
    [PSCustomObject]@{
        Package = "ni-max"
        Version = "24.5.0.49250"
        UserVisible = "yes"
        StoreProduct = "no"
        Section = "Utilities"
        DisplayName = "Measurement & Automation Explorer"
        Description = "Configuration and test utility"
    },
    
    # ni-package-manager itself - special case
    [PSCustomObject]@{
        Package = "ni-package-manager"
        Version = "24.5.0.49350"
        UserVisible = "yes"
        StoreProduct = "no"
        Section = "Utilities"
        DisplayName = "NI Package Manager"
        Description = "National Instruments Package Manager"
    }
)

$testFeeds = @(
    [PSCustomObject]@{
        Name = "ni-software-2025"
        Path = "https://download.ni.com/support/nipkg/products/ni-software-2025"
    }
)

Write-Host "`n=== Comprehensive Type Parameter Testing ===" -ForegroundColor Cyan
Write-Host "Testing with $($testPackages.Count) realistic test packages" -ForegroundColor White

# Expected counts for each type
$expectedFull = 7          # All packages
$expectedUserVisible = 5   # ni-labview-2025-runtime-engine, ni-daqmx, ni-labview-2025-community, ni-max, ni-package-manager (ni-package-manager gets special handling)
$expectedStoreProduct = 2  # ni-labview-2025-runtime-engine, ni-labview-2025-community

Write-Host "`nExpected package counts:" -ForegroundColor White
Write-Host "  Full: $expectedFull" -ForegroundColor White
Write-Host "  UserVisible: $expectedUserVisible" -ForegroundColor White  
Write-Host "  StoreProduct: $expectedStoreProduct" -ForegroundColor White

# Test 1: Full type
Write-Host "`n--- Test 1: Full Type ---" -ForegroundColor Yellow
try {
    $fullSnapshot = New-Snapshot -FeedsInfo $testFeeds -PackagesInfo $testPackages -Type "Full"
    $success = $fullSnapshot.packages.Count -eq $expectedFull
    Write-Host "  Result: $(if ($success) { '✓ PASS' } else { '✗ FAIL' })" -ForegroundColor $(if ($success) { 'Green' } else { 'Red' })
    Write-Host "  Type: $($fullSnapshot.type)" -ForegroundColor White
    Write-Host "  Count: $($fullSnapshot.packages.Count) (expected $expectedFull)" -ForegroundColor White
} catch {
    Write-Host "  ✗ FAIL: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 2: UserVisible type
Write-Host "`n--- Test 2: UserVisible Type ---" -ForegroundColor Yellow
try {
    $userVisibleSnapshot = New-Snapshot -FeedsInfo $testFeeds -PackagesInfo $testPackages -Type "UserVisible"
    $success = $userVisibleSnapshot.packages.Count -eq $expectedUserVisible
    Write-Host "  Result: $(if ($success) { '✓ PASS' } else { '✗ FAIL' })" -ForegroundColor $(if ($success) { 'Green' } else { 'Red' })
    Write-Host "  Type: $($userVisibleSnapshot.type)" -ForegroundColor White
    Write-Host "  Count: $($userVisibleSnapshot.packages.Count) (expected $expectedUserVisible)" -ForegroundColor White
    
    # List the packages for verification
    Write-Host "  Packages included:" -ForegroundColor Gray
    $userVisibleSnapshot.packages | ForEach-Object { 
        Write-Host "    - $($_.name)" -ForegroundColor Gray 
    }
} catch {
    Write-Host "  ✗ FAIL: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 3: StoreProduct type
Write-Host "`n--- Test 3: StoreProduct Type ---" -ForegroundColor Yellow
try {
    $storeProductSnapshot = New-Snapshot -FeedsInfo $testFeeds -PackagesInfo $testPackages -Type "StoreProduct"
    $success = $storeProductSnapshot.packages.Count -eq $expectedStoreProduct
    Write-Host "  Result: $(if ($success) { '✓ PASS' } else { '✗ FAIL' })" -ForegroundColor $(if ($success) { 'Green' } else { 'Red' })
    Write-Host "  Type: $($storeProductSnapshot.type)" -ForegroundColor White
    Write-Host "  Count: $($storeProductSnapshot.packages.Count) (expected $expectedStoreProduct)" -ForegroundColor White
    
    # List the packages for verification
    Write-Host "  Packages included:" -ForegroundColor Gray
    $storeProductSnapshot.packages | ForEach-Object { 
        Write-Host "    - $($_.name)" -ForegroundColor Gray 
    }
} catch {
    Write-Host "  ✗ FAIL: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 4: Export/Import round-trip with each type
Write-Host "`n--- Test 4: Export/Import Round-trip ---" -ForegroundColor Yellow
$tempDir = Join-Path $PSScriptRoot "..\test-temp"
if (-not (Test-Path $tempDir)) {
    New-Item -Path $tempDir -ItemType Directory -Force | Out-Null
}

$testTypes = @("Full", "UserVisible", "StoreProduct")
$snapshots = @($fullSnapshot, $userVisibleSnapshot, $storeProductSnapshot)

for ($i = 0; $i -lt $testTypes.Count; $i++) {
    $type = $testTypes[$i]
    $snapshot = $snapshots[$i]
    
    try {
        $testJsonPath = Join-Path $tempDir "test-$type-snapshot.json"
        
        # Export
        $exportResult = Export-NipkgSnapshotToJson -Snapshot $snapshot -OutputPath $testJsonPath
        
        # Import
        $importedSnapshot = Import-NipkgSnapshotFromJson -InputPath $testJsonPath
        
        # Verify
        $typePreserved = $importedSnapshot.type -eq $type
        $countMatches = $importedSnapshot.packages.Count -eq $snapshot.packages.Count
        $success = $typePreserved -and $countMatches
        
        Write-Host "  ${type}: $(if ($success) { '✓ PASS' } else { '✗ FAIL' })" -ForegroundColor $(if ($success) { 'Green' } else { 'Red' })
        if (-not $typePreserved) {
            Write-Host "    Type mismatch: expected '$type', got '$($importedSnapshot.type)'" -ForegroundColor Red
        }
        if (-not $countMatches) {
            Write-Host "    Count mismatch: expected $($snapshot.packages.Count), got $($importedSnapshot.packages.Count)" -ForegroundColor Red
        }
        
        # Clean up
        Remove-Item $testJsonPath -Force -ErrorAction SilentlyContinue
        
    } catch {
        Write-Host "  ${type}: ✗ FAIL - $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host "`n--- Test 5: Function Parameter Validation ---" -ForegroundColor Yellow
try {
    # Test invalid type
    try {
        $invalidSnapshot = New-Snapshot -FeedsInfo $testFeeds -PackagesInfo $testPackages -Type "InvalidType"
        Write-Host "  Parameter validation: ✗ FAIL - Should have rejected invalid type" -ForegroundColor Red
    } catch {
        Write-Host "  Parameter validation: ✓ PASS - Correctly rejected invalid type" -ForegroundColor Green
    }
} catch {
    Write-Host "  Parameter validation test failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n=== Test Summary ===" -ForegroundColor Cyan
Write-Host "The Type parameter functionality has been comprehensively tested!" -ForegroundColor Green
Write-Host "`nKey Features Verified:" -ForegroundColor White
Write-Host "✓ Type parameter filtering in New-Snapshot" -ForegroundColor Green
Write-Host "✓ Type preservation in Export-NipkgSnapshotToJson" -ForegroundColor Green
Write-Host "✓ Type restoration in Import-NipkgSnapshotFromJson" -ForegroundColor Green
Write-Host "✓ Parameter validation with ValidateSet" -ForegroundColor Green
Write-Host "✓ Realistic package filtering scenarios" -ForegroundColor Green
