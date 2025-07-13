#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Demonstrates the Type parameter functionality in NIPKG Helper snapshots.

.DESCRIPTION
    This script shows how to use the new Type parameter to create different
    kinds of snapshots with filtered package sets.
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

Write-Host "`n=== NIPKG Snapshot Type Parameter Demo ===" -ForegroundColor Cyan

# Example 1: Creating snapshots with different types
Write-Host "`n--- Example 1: Creating Snapshots with Different Types ---" -ForegroundColor Yellow

# Mock some realistic feed and package data
$feeds = @(
    [PSCustomObject]@{ Name = "ni-software-2025"; Path = "https://download.ni.com/support/nipkg/products/ni-software-2025" }
)

$packages = @(
    [PSCustomObject]@{ Package = "ni-labview-2025-community"; Version = "25.1.0"; UserVisible = "yes"; StoreProduct = "yes"; Section = "Programming Environments" },
    [PSCustomObject]@{ Package = "ni-labview-shared"; Version = "25.1.0"; UserVisible = "no"; StoreProduct = "no"; Section = "Programming Environments" },
    [PSCustomObject]@{ Package = "ni-daqmx"; Version = "24.8.0"; UserVisible = "yes"; StoreProduct = "no"; Section = "Drivers" },
    [PSCustomObject]@{ Package = "ni-max"; Version = "24.5.0"; UserVisible = "yes"; StoreProduct = "no"; Section = "Utilities" }
)

Write-Host "`nOriginal package count: $($packages.Count)" -ForegroundColor White

# Create Full snapshot (default - includes all packages)
$fullSnapshot = New-Snapshot -FeedsInfo $feeds -PackagesInfo $packages -Type "Full"
Write-Host "Full snapshot: $($fullSnapshot.packages.Count) packages, type: $($fullSnapshot.type)" -ForegroundColor Green

# Create UserVisible snapshot (only packages with UserVisible = 'yes')
$userSnapshot = New-Snapshot -FeedsInfo $feeds -PackagesInfo $packages -Type "UserVisible"
Write-Host "UserVisible snapshot: $($userSnapshot.packages.Count) packages, type: $($userSnapshot.type)" -ForegroundColor Green

# Create StoreProduct snapshot (only packages with StoreProduct = 'yes')
$storeSnapshot = New-Snapshot -FeedsInfo $feeds -PackagesInfo $packages -Type "StoreProduct"
Write-Host "StoreProduct snapshot: $($storeSnapshot.packages.Count) packages, type: $($storeSnapshot.type)" -ForegroundColor Green

# Example 2: Export/Import preserves Type
Write-Host "`n--- Example 2: Export/Import Type Preservation ---" -ForegroundColor Yellow

$tempDir = Join-Path $PSScriptRoot "..\test-temp"
if (-not (Test-Path $tempDir)) {
    New-Item -Path $tempDir -ItemType Directory -Force | Out-Null
}

$snapshotPath = Join-Path $tempDir "demo-uservisible-snapshot.json"

# Export UserVisible snapshot
$exportResult = Export-NipkgSnapshotToJson -Snapshot $userSnapshot -OutputPath $snapshotPath
Write-Host "Exported snapshot with type: $($exportResult.Type)" -ForegroundColor Green

# Import it back
$importedSnapshot = Import-NipkgSnapshotFromJson -InputPath $snapshotPath
Write-Host "Imported snapshot with type: $($importedSnapshot.type)" -ForegroundColor Green
Write-Host "Type preserved: $(if ($importedSnapshot.type -eq $userSnapshot.type) { 'Yes ✓' } else { 'No ✗' })" -ForegroundColor $(if ($importedSnapshot.type -eq $userSnapshot.type) { 'Green' } else { 'Red' })

# Clean up
Remove-Item $snapshotPath -Force -ErrorAction SilentlyContinue

# Example 3: Using Type parameter with system snapshots
Write-Host "`n--- Example 3: Function Signatures ---" -ForegroundColor Yellow

Write-Host "`nNew-Snapshot supports Type parameter:" -ForegroundColor White
Write-Host "  New-Snapshot -FeedsInfo `$feeds -PackagesInfo `$packages -Type 'Full'" -ForegroundColor Gray
Write-Host "  New-Snapshot -FeedsInfo `$feeds -PackagesInfo `$packages -Type 'UserVisible'" -ForegroundColor Gray
Write-Host "  New-Snapshot -FeedsInfo `$feeds -PackagesInfo `$packages -Type 'StoreProduct'" -ForegroundColor Gray

Write-Host "`nNew-SnapshotFromInstallerDirectory supports Type parameter:" -ForegroundColor White
Write-Host "  New-SnapshotFromInstallerDirectory -InstallerDirectory 'C:\Installer' -Type 'UserVisible'" -ForegroundColor Gray

Write-Host "`nNew-SnapshotFromSystem supports Type parameter:" -ForegroundColor White
Write-Host "  New-SnapshotFromSystem -PackageType 'installed' -Type 'StoreProduct'" -ForegroundColor Gray

# Example 4: Real-world usage patterns
Write-Host "`n--- Example 4: Real-world Usage Patterns ---" -ForegroundColor Yellow

Write-Host "`nCommon use cases:" -ForegroundColor White
Write-Host "• Full: Complete system backup/restoration" -ForegroundColor Cyan
Write-Host "• UserVisible: End-user software inventory" -ForegroundColor Cyan
Write-Host "• StoreProduct: Commercial software licensing/tracking" -ForegroundColor Cyan

Write-Host "`nExample workflow:" -ForegroundColor White
Write-Host "1. Create UserVisible snapshot for software audit" -ForegroundColor Gray
Write-Host "2. Export to JSON for documentation" -ForegroundColor Gray
Write-Host "3. Use Full snapshot for complete system cloning" -ForegroundColor Gray
Write-Host "4. Use StoreProduct snapshot for license compliance" -ForegroundColor Gray

Write-Host "`n=== Demo Complete ===" -ForegroundColor Cyan
Write-Host "The Type parameter provides flexible filtering for different snapshot needs!" -ForegroundColor Green
