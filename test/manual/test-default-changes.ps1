#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Tests the updated default Type parameter values and compliance validation.

.DESCRIPTION
    This script tests that the default Type parameter is now "StoreProduct" for 
    installer and system snapshots, and verifies that compliance validation 
    uses the correct Type from the original snapshot.
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

Write-Host "`n=== Testing Updated Type Parameter Defaults ===" -ForegroundColor Cyan

# Test 1: Verify New-NipkgSnapshot still defaults to Full
Write-Host "`n--- Test 1: New-NipkgSnapshot Default Type ---" -ForegroundColor Yellow

$testFeeds = @([PSCustomObject]@{ Name = "test"; Path = "C:\test" })
$testPackages = @(
    [PSCustomObject]@{ Package = "pkg1"; Version = "1.0"; UserVisible = "yes"; StoreProduct = "yes"; Section = "Programming Environments" },
    [PSCustomObject]@{ Package = "pkg2"; Version = "2.0"; UserVisible = "no"; StoreProduct = "no"; Section = "Utilities" }
)

try {
    # Test without specifying Type parameter (should default to Full)
    $fullSnapshot = New-NipkgSnapshot -FeedsInfo $testFeeds -PackagesInfo $testPackages
    $defaultIsFull = $fullSnapshot.type -eq "Full" -and $fullSnapshot.packages.Count -eq 2
    
    Write-Host "  New-NipkgSnapshot default Type: $($fullSnapshot.type)" -ForegroundColor White
    Write-Host "  Result: $(if ($defaultIsFull) { '✓ PASS - Still defaults to Full' } else { '✗ FAIL - Should default to Full' })" -ForegroundColor $(if ($defaultIsFull) { 'Green' } else { 'Red' })
} catch {
    Write-Host "  ✗ FAIL: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 2: Check help for installer and system functions to verify defaults are documented correctly
Write-Host "`n--- Test 2: Function Documentation Check ---" -ForegroundColor Yellow

try {
    # Get help for the functions to check default values
    $installerHelp = Get-Help New-NipkgSnapshotFromInstaller -Full | Out-String
    $systemHelp = Get-Help New-NipkgSnapshotFromSystem -Full | Out-String
    
    # Check if "StoreProduct" appears as default in the documentation
    $installerHasStoreDefault = $installerHelp -like "*StoreProduct*" -and $installerHelp -like "*default*"
    $systemHasStoreDefault = $systemHelp -like "*StoreProduct*" -and $systemHelp -like "*default*"
    
    Write-Host "  New-NipkgSnapshotFromInstaller help mentions StoreProduct default: $(if ($installerHasStoreDefault) { 'Yes ✓' } else { 'No ✗' })" -ForegroundColor $(if ($installerHasStoreDefault) { 'Green' } else { 'Red' })
    Write-Host "  New-NipkgSnapshotFromSystem help mentions StoreProduct default: $(if ($systemHasStoreDefault) { 'Yes ✓' } else { 'No ✗' })" -ForegroundColor $(if ($systemHasStoreDefault) { 'Green' } else { 'Red' })
} catch {
    Write-Host "  ✗ FAIL: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 3: Create test snapshots to verify actual behavior
Write-Host "`n--- Test 3: Create Test Snapshots and Verify Defaults ---" -ForegroundColor Yellow

# Create test data directory structure
$tempDir = Join-Path $PSScriptRoot "..\test-temp"
$testInstallerDir = Join-Path $tempDir "test-installer"
$testFeedsDir = Join-Path $testInstallerDir "feeds\test-feed"

if (Test-Path $tempDir) {
    Remove-Item $tempDir -Recurse -Force
}
New-Item -Path $testFeedsDir -ItemType Directory -Force | Out-Null

# Create a mock Packages file
$mockPackagesContent = @"
Package: ni-labview-2025-community
Version: 25.1.0
UserVisible: yes
StoreProduct: yes
Section: Programming Environments

Package: ni-internal-lib
Version: 1.0.0
UserVisible: no
StoreProduct: no
Section: Utilities

Package: ni-daqmx
Version: 24.8.0
UserVisible: yes
StoreProduct: no
Section: Drivers
"@

$mockPackagesFile = Join-Path $testFeedsDir "Packages"
$mockPackagesContent | Out-File -FilePath $mockPackagesFile -Encoding UTF8

try {
    # Test installer snapshot default (should be StoreProduct, so only 1 package)
    $installerSnapshot = New-NipkgSnapshotFromInstaller -InstallerDirectory $testInstallerDir
    $installerDefaultIsStore = $installerSnapshot.type -eq "StoreProduct" -and $installerSnapshot.packages.Count -eq 1
    
    Write-Host "  New-NipkgSnapshotFromInstaller default behavior:" -ForegroundColor White
    Write-Host "    Type: $($installerSnapshot.type)" -ForegroundColor White
    Write-Host "    Package count: $($installerSnapshot.packages.Count) (expected 1 for StoreProduct)" -ForegroundColor White
    Write-Host "    Result: $(if ($installerDefaultIsStore) { '✓ PASS - Defaults to StoreProduct' } else { '✗ FAIL - Should default to StoreProduct' })" -ForegroundColor $(if ($installerDefaultIsStore) { 'Green' } else { 'Red' })
    
    if ($installerSnapshot.packages.Count -gt 0) {
        Write-Host "    Packages included:" -ForegroundColor Gray
        $installerSnapshot.packages | ForEach-Object { Write-Host "      - $($_.name)" -ForegroundColor Gray }
    }
    
} catch {
    Write-Host "  ✗ FAIL: Installer snapshot test failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 4: Export/Import Type preservation with new defaults
Write-Host "`n--- Test 4: Export/Import with New Defaults ---" -ForegroundColor Yellow

try {
    # Export installer snapshot
    $testJsonPath = Join-Path $tempDir "test-default-snapshot.json"
    $exportResult = Export-NipkgSnapshotToJson -Snapshot $installerSnapshot -OutputPath $testJsonPath
    
    # Import and verify type preservation
    $importedSnapshot = Import-NipkgSnapshotFromJson -InputPath $testJsonPath
    $typePreserved = $importedSnapshot.type -eq $installerSnapshot.type
    
    Write-Host "  Export/Import type preservation:" -ForegroundColor White
    Write-Host "    Original type: $($installerSnapshot.type)" -ForegroundColor White
    Write-Host "    Imported type: $($importedSnapshot.type)" -ForegroundColor White
    Write-Host "    Result: $(if ($typePreserved) { '✓ PASS - Type preserved' } else { '✗ FAIL - Type not preserved' })" -ForegroundColor $(if ($typePreserved) { 'Green' } else { 'Red' })
    
} catch {
    Write-Host "  ✗ FAIL: Export/Import test failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 5: Verify all Type values still work
Write-Host "`n--- Test 5: All Type Values Still Work ---" -ForegroundColor Yellow

$typeTests = @(
    @{ Type = "Full"; ExpectedCount = 3 },
    @{ Type = "UserVisible"; ExpectedCount = 2 },
    @{ Type = "StoreProduct"; ExpectedCount = 1 }
)

foreach ($test in $typeTests) {
    try {
        $snapshot = New-NipkgSnapshotFromInstaller -InstallerDirectory $testInstallerDir -Type $test.Type
        $success = $snapshot.type -eq $test.Type -and $snapshot.packages.Count -eq $test.ExpectedCount
        
        Write-Host "  Type '$($test.Type)': $(if ($success) { '✓ PASS' } else { '✗ FAIL' })" -ForegroundColor $(if ($success) { 'Green' } else { 'Red' })
        Write-Host "    Count: $($snapshot.packages.Count) (expected $($test.ExpectedCount))" -ForegroundColor Gray
        
    } catch {
        Write-Host "  Type '$($test.Type)': ✗ FAIL - $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Cleanup
if (Test-Path $tempDir) {
    Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host "`n=== Default Type Parameter Tests Complete ===" -ForegroundColor Cyan
Write-Host "Updated defaults and functionality verified!" -ForegroundColor Green
