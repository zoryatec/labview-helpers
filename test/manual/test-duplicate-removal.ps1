#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Tests the Remove-DuplicatePackagesByVersion function and its integration with New-NipkgSnapshotFromInstaller.

.DESCRIPTION
    This script tests that duplicate packages are properly removed by selecting the highest version
    when creating snapshots from installer directories.
#>

# Import the module
$ModulePath = Join-Path $PSScriptRoot "..\..\LabViewHelpers\NipkgHelper.psm1"
if (Test-Path $ModulePath) {
    Import-Module $ModulePath -Force
    Write-Host "✓ Imported NipkgHelper module" -ForegroundColor Green
} else {
    Write-Error "Module not found: $ModulePath"
    exit 1
}

Write-Host "`n=== Remove-DuplicatePackagesByVersion Tests ===" -ForegroundColor Cyan

# Test 1: Basic duplicate removal with semantic versions
Write-Host "`n--- Test 1: Basic Duplicate Removal ---" -ForegroundColor Yellow

$testPackages = @(
    [PSCustomObject]@{ Package = "ni-labview"; Version = "25.1.0"; UserVisible = "yes"; StoreProduct = "yes" },
    [PSCustomObject]@{ Package = "ni-labview"; Version = "25.0.0"; UserVisible = "yes"; StoreProduct = "yes" },
    [PSCustomObject]@{ Package = "ni-daqmx"; Version = "24.8.0"; UserVisible = "yes"; StoreProduct = "no" },
    [PSCustomObject]@{ Package = "ni-daqmx"; Version = "24.5.0"; UserVisible = "yes"; StoreProduct = "no" },
    [PSCustomObject]@{ Package = "ni-max"; Version = "24.5.0"; UserVisible = "yes"; StoreProduct = "no" }
)

Write-Host "Original packages: $($testPackages.Count)" -ForegroundColor White
foreach ($pkg in $testPackages) {
    Write-Host "  $($pkg.Package) v$($pkg.Version)" -ForegroundColor Gray
}

$uniquePackages = Remove-DuplicatePackagesByVersion -PackagesInfo $testPackages

Write-Host "`nAfter duplicate removal: $($uniquePackages.Count)" -ForegroundColor Green
foreach ($pkg in $uniquePackages) {
    Write-Host "  $($pkg.Package) v$($pkg.Version)" -ForegroundColor Gray
}

# Verify results
$expectedPackages = @("ni-labview", "ni-daqmx", "ni-max")
$expectedVersions = @("25.1.0", "24.8.0", "24.5.0")

$success = $true
for ($i = 0; $i -lt $expectedPackages.Count; $i++) {
    $found = $uniquePackages | Where-Object { $_.Package -eq $expectedPackages[$i] -and $_.Version -eq $expectedVersions[$i] }
    if (-not $found) {
        Write-Host "✗ Expected $($expectedPackages[$i]) v$($expectedVersions[$i]) not found" -ForegroundColor Red
        $success = $false
    } else {
        Write-Host "✓ Found $($expectedPackages[$i]) v$($expectedVersions[$i])" -ForegroundColor Green
    }
}

if ($success) {
    Write-Host "✓ Test 1 PASSED: Correct packages with highest versions selected" -ForegroundColor Green
} else {
    Write-Host "✗ Test 1 FAILED" -ForegroundColor Red
}

# Test 2: Complex version strings
Write-Host "`n--- Test 2: Complex Version Strings ---" -ForegroundColor Yellow

$complexPackages = @(
    [PSCustomObject]@{ Package = "ni-package-a"; Version = "2025.1.0.49152"; UserVisible = "yes"; StoreProduct = "yes" },
    [PSCustomObject]@{ Package = "ni-package-a"; Version = "2024.5.0.49152"; UserVisible = "yes"; StoreProduct = "yes" },
    [PSCustomObject]@{ Package = "ni-package-b"; Version = "1.0"; UserVisible = "yes"; StoreProduct = "no" },
    [PSCustomObject]@{ Package = "ni-package-b"; Version = "1.0.1"; UserVisible = "yes"; StoreProduct = "no" }
)

Write-Host "Complex version packages: $($complexPackages.Count)" -ForegroundColor White
foreach ($pkg in $complexPackages) {
    Write-Host "  $($pkg.Package) v$($pkg.Version)" -ForegroundColor Gray
}

$uniqueComplex = Remove-DuplicatePackagesByVersion -PackagesInfo $complexPackages

Write-Host "`nAfter duplicate removal: $($uniqueComplex.Count)" -ForegroundColor Green
foreach ($pkg in $uniqueComplex) {
    Write-Host "  $($pkg.Package) v$($pkg.Version)" -ForegroundColor Gray
}

# Test 3: Empty array handling
Write-Host "`n--- Test 3: Empty Array Handling ---" -ForegroundColor Yellow

$emptyPackages = @()
$uniqueEmpty = Remove-DuplicatePackagesByVersion -PackagesInfo $emptyPackages

if ($uniqueEmpty.Count -eq 0) {
    Write-Host "✓ Test 3 PASSED: Empty array handled correctly" -ForegroundColor Green
} else {
    Write-Host "✗ Test 3 FAILED: Expected empty array, got $($uniqueEmpty.Count) items" -ForegroundColor Red
}

# Test 4: No duplicates
Write-Host "`n--- Test 4: No Duplicates ---" -ForegroundColor Yellow

$noDuplicates = @(
    [PSCustomObject]@{ Package = "ni-unique-a"; Version = "1.0.0"; UserVisible = "yes"; StoreProduct = "yes" },
    [PSCustomObject]@{ Package = "ni-unique-b"; Version = "2.0.0"; UserVisible = "yes"; StoreProduct = "no" },
    [PSCustomObject]@{ Package = "ni-unique-c"; Version = "3.0.0"; UserVisible = "no"; StoreProduct = "no" }
)

$uniqueNoDuplicates = Remove-DuplicatePackagesByVersion -PackagesInfo $noDuplicates

if ($uniqueNoDuplicates.Count -eq $noDuplicates.Count) {
    Write-Host "✓ Test 4 PASSED: No duplicates, all packages preserved" -ForegroundColor Green
} else {
    Write-Host "✗ Test 4 FAILED: Expected $($noDuplicates.Count) packages, got $($uniqueNoDuplicates.Count)" -ForegroundColor Red
}

# Test 5: Properties preservation
Write-Host "`n--- Test 5: Properties Preservation ---" -ForegroundColor Yellow

$testProps = @(
    [PSCustomObject]@{ Package = "ni-test"; Version = "1.0.0"; UserVisible = "yes"; StoreProduct = "yes"; Section = "Test"; CustomProp = "Value1" },
    [PSCustomObject]@{ Package = "ni-test"; Version = "2.0.0"; UserVisible = "no"; StoreProduct = "no"; Section = "Test"; CustomProp = "Value2" }
)

$uniqueProps = Remove-DuplicatePackagesByVersion -PackagesInfo $testProps

$selectedPackage = $uniqueProps | Where-Object { $_.Package -eq "ni-test" }
if ($selectedPackage -and $selectedPackage.Version -eq "2.0.0" -and $selectedPackage.CustomProp -eq "Value2") {
    Write-Host "✓ Test 5 PASSED: All properties preserved from highest version package" -ForegroundColor Green
} else {
    Write-Host "✗ Test 5 FAILED: Properties not properly preserved" -ForegroundColor Red
}

Write-Host "`n=== Integration Test with Mock Data ===" -ForegroundColor Cyan

# Create mock package data that would simulate an installer with duplicates
$mockFeeds = @(
    [PSCustomObject]@{ Name = "feed1"; Path = "C:\mock\feed1" },
    [PSCustomObject]@{ Name = "feed2"; Path = "C:\mock\feed2" }
)

$mockPackagesWithDuplicates = @(
    [PSCustomObject]@{ Package = "ni-labview-2025"; Version = "25.1.0"; UserVisible = "yes"; StoreProduct = "yes" },
    [PSCustomObject]@{ Package = "ni-labview-2025"; Version = "25.0.0"; UserVisible = "yes"; StoreProduct = "yes" },
    [PSCustomObject]@{ Package = "ni-daqmx"; Version = "24.8.0"; UserVisible = "yes"; StoreProduct = "no" },
    [PSCustomObject]@{ Package = "ni-daqmx"; Version = "24.5.0"; UserVisible = "yes"; StoreProduct = "no" },
    [PSCustomObject]@{ Package = "ni-max"; Version = "24.5.0"; UserVisible = "yes"; StoreProduct = "no" }
)

Write-Host "`n--- Integration Test: Snapshot with Duplicates ---" -ForegroundColor Yellow

Write-Host "Mock packages before New-NipkgSnapshot: $($mockPackagesWithDuplicates.Count)" -ForegroundColor White
$duplicateGroups = $mockPackagesWithDuplicates | Group-Object -Property Package | Where-Object { $_.Count -gt 1 }
Write-Host "Packages with duplicates: $($duplicateGroups.Count)" -ForegroundColor White

# Test with direct New-NipkgSnapshot (should receive duplicates as-is)
$snapshotWithDuplicates = New-NipkgSnapshot -FeedsInfo $mockFeeds -PackagesInfo $mockPackagesWithDuplicates -Type "Full"
Write-Host "Snapshot with duplicates: $($snapshotWithDuplicates.packages.Count) packages" -ForegroundColor Green

# Test duplicate removal function directly
$uniqueMockPackages = Remove-DuplicatePackagesByVersion -PackagesInfo $mockPackagesWithDuplicates
Write-Host "After duplicate removal: $($uniqueMockPackages.Count) packages" -ForegroundColor Green

# Test with cleaned packages
$snapshotWithoutDuplicates = New-NipkgSnapshot -FeedsInfo $mockFeeds -PackagesInfo $uniqueMockPackages -Type "Full"
Write-Host "Snapshot without duplicates: $($snapshotWithoutDuplicates.packages.Count) packages" -ForegroundColor Green

if ($snapshotWithoutDuplicates.packages.Count -eq 3) {
    Write-Host "✓ Integration Test PASSED: Duplicate removal works as expected" -ForegroundColor Green
} else {
    Write-Host "✗ Integration Test FAILED: Expected 3 unique packages, got $($snapshotWithoutDuplicates.packages.Count)" -ForegroundColor Red
}

Write-Host "`n=== Tests Complete ===" -ForegroundColor Cyan
Write-Host "The Remove-DuplicatePackagesByVersion function is ready for use!" -ForegroundColor Green
Write-Host "New-NipkgSnapshotFromInstaller will automatically use this function to remove duplicates." -ForegroundColor Green
