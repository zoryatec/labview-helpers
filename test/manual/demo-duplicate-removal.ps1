#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Demonstrates the duplicate removal functionality in New-SnapshotFromInstallerDirectory.

.DESCRIPTION
    This script shows how the New-SnapshotFromInstallerDirectory function automatically removes
    duplicate packages by selecting the highest version before creating snapshots.
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

Write-Host "`n=== Duplicate Removal in New-SnapshotFromInstallerDirectory Demo ===" -ForegroundColor Cyan

Write-Host "`n--- Scenario: Installer with Multiple Package Versions ---" -ForegroundColor Yellow

Write-Host "`nTypical installer scenario:" -ForegroundColor White
Write-Host "• Installer contains multiple feeds" -ForegroundColor Cyan
Write-Host "• Each feed might have different versions of the same package" -ForegroundColor Cyan
Write-Host "• We want only the highest version of each package in our snapshot" -ForegroundColor Cyan

Write-Host "`n--- Example: Simulated Installer Structure ---" -ForegroundColor Yellow

Write-Host "`nImagine an installer with this structure:" -ForegroundColor White
Write-Host "installer/" -ForegroundColor Gray
Write-Host "├── feeds/" -ForegroundColor Gray
Write-Host "│   ├── ni-software-2025/" -ForegroundColor Gray
Write-Host "│   │   └── Packages (contains ni-labview v25.1.0, ni-daqmx v24.8.0)" -ForegroundColor Gray
Write-Host "│   ├── ni-software-2024/" -ForegroundColor Gray
Write-Host "│   │   └── Packages (contains ni-labview v25.0.0, ni-daqmx v24.5.0)" -ForegroundColor Gray
Write-Host "│   └── ni-drivers/" -ForegroundColor Gray
Write-Host "│       └── Packages (contains ni-daqmx v24.8.0, ni-max v24.5.0)" -ForegroundColor Gray
Write-Host "└── bin/" -ForegroundColor Gray
Write-Host "    └── ni-package-manager-packages/" -ForegroundColor Gray
Write-Host "        └── Packages (contains ni-package-manager v25.1.0)" -ForegroundColor Gray

Write-Host "`n--- Before Duplicate Removal ---" -ForegroundColor Yellow

# Simulate what would be collected from all feeds
$simulatedAllPackages = @(
    [PSCustomObject]@{ Package = "ni-labview"; Version = "25.1.0"; UserVisible = "yes"; StoreProduct = "yes"; Section = "Programming Environments" },
    [PSCustomObject]@{ Package = "ni-labview"; Version = "25.0.0"; UserVisible = "yes"; StoreProduct = "yes"; Section = "Programming Environments" },
    [PSCustomObject]@{ Package = "ni-daqmx"; Version = "24.8.0"; UserVisible = "yes"; StoreProduct = "no"; Section = "Drivers" },
    [PSCustomObject]@{ Package = "ni-daqmx"; Version = "24.5.0"; UserVisible = "yes"; StoreProduct = "no"; Section = "Drivers" },
    [PSCustomObject]@{ Package = "ni-daqmx"; Version = "24.8.0"; UserVisible = "yes"; StoreProduct = "no"; Section = "Drivers" }, # Duplicate
    [PSCustomObject]@{ Package = "ni-max"; Version = "24.5.0"; UserVisible = "yes"; StoreProduct = "no"; Section = "Utilities" },
    [PSCustomObject]@{ Package = "ni-package-manager"; Version = "25.1.0"; UserVisible = "no"; StoreProduct = "no"; Section = "Utilities" }
)

Write-Host "Raw packages collected from all feeds: $($simulatedAllPackages.Count)" -ForegroundColor White
$packageCounts = $simulatedAllPackages | Group-Object -Property Package | ForEach-Object { "$($_.Name): $($_.Count) versions" }
foreach ($count in $packageCounts) {
    Write-Host "  $count" -ForegroundColor Gray
}

Write-Host "`n--- After Duplicate Removal ---" -ForegroundColor Yellow

# Apply the duplicate removal function
$uniquePackages = Remove-DuplicatePackagesByVersion -PackagesInfo $simulatedAllPackages

Write-Host "Unique packages after duplicate removal: $($uniquePackages.Count)" -ForegroundColor Green
foreach ($pkg in $uniquePackages | Sort-Object Package) {
    Write-Host "  $($pkg.Package) v$($pkg.Version)" -ForegroundColor Gray
}

Write-Host "`n--- Type Filtering with Duplicates ---" -ForegroundColor Yellow

Write-Host "`nWhen combined with Type parameter:" -ForegroundColor White

# Simulate what New-SnapshotFromInstallerDirectory would do with different Type values
$mockFeeds = @([PSCustomObject]@{ Name = "installer-feeds"; Path = "C:\mock\installer" })

# Full snapshot (with duplicate removal)
$fullSnapshot = New-Snapshot -FeedsInfo $mockFeeds -PackagesInfo $uniquePackages -Type "Full"
Write-Host "Full snapshot: $($fullSnapshot.packages.Count) packages" -ForegroundColor Green

# UserVisible snapshot (with duplicate removal)
$userSnapshot = New-Snapshot -FeedsInfo $mockFeeds -PackagesInfo $uniquePackages -Type "UserVisible"
Write-Host "UserVisible snapshot: $($userSnapshot.packages.Count) packages" -ForegroundColor Green

# StoreProduct snapshot (with duplicate removal)
$storeSnapshot = New-Snapshot -FeedsInfo $mockFeeds -PackagesInfo $uniquePackages -Type "StoreProduct"
Write-Host "StoreProduct snapshot: $($storeSnapshot.packages.Count) packages" -ForegroundColor Green

Write-Host "`n--- Benefits of Duplicate Removal ---" -ForegroundColor Yellow

Write-Host "`nKey benefits:" -ForegroundColor White
Write-Host "✓ Ensures only the latest version of each package" -ForegroundColor Green
Write-Host "✓ Prevents installation conflicts from multiple versions" -ForegroundColor Green
Write-Host "✓ Reduces snapshot size and complexity" -ForegroundColor Green
Write-Host "✓ Improves installation reliability" -ForegroundColor Green
Write-Host "✓ Maintains semantic version ordering" -ForegroundColor Green

Write-Host "`n--- Function Usage ---" -ForegroundColor Yellow

Write-Host "`nThe Remove-DuplicatePackagesByVersion function:" -ForegroundColor White
Write-Host "• Groups packages by name" -ForegroundColor Cyan
Write-Host "• Compares versions using semantic versioning when possible" -ForegroundColor Cyan
Write-Host "• Falls back to string comparison for non-semantic versions" -ForegroundColor Cyan
Write-Host "• Preserves all properties from the highest version package" -ForegroundColor Cyan
Write-Host "• Handles empty arrays gracefully" -ForegroundColor Cyan

Write-Host "`nIntegration with New-SnapshotFromInstallerDirectory:" -ForegroundColor White
Write-Host "• Automatically called before creating snapshots" -ForegroundColor Cyan
Write-Host "• Works with all Type parameter values" -ForegroundColor Cyan
Write-Host "• Provides verbose logging of duplicate removal process" -ForegroundColor Cyan
Write-Host "• Reports how many duplicates were removed" -ForegroundColor Cyan

Write-Host "`n--- Example Usage Patterns ---" -ForegroundColor Yellow

Write-Host "`nTypical workflows:" -ForegroundColor White

Write-Host "`n1. Create installer snapshot without duplicates:" -ForegroundColor Cyan
Write-Host "   `$snapshot = New-SnapshotFromInstallerDirectory -InstallerDirectory 'C:\Installer'" -ForegroundColor Gray
Write-Host "   # Automatically removes duplicates, selects highest versions" -ForegroundColor Gray

Write-Host "`n2. Create user-visible snapshot from installer:" -ForegroundColor Cyan
Write-Host "   `$snapshot = New-SnapshotFromInstallerDirectory -InstallerDirectory 'C:\Installer' -Type 'UserVisible'" -ForegroundColor Gray
Write-Host "   # Removes duplicates, then filters to user-visible packages" -ForegroundColor Gray

Write-Host "`n3. Manual duplicate removal:" -ForegroundColor Cyan
Write-Host "   `$packages = Get-PackagesInfoFromPackagesFile -InputPath 'Packages'" -ForegroundColor Gray
Write-Host "   `$unique = Remove-DuplicatePackagesByVersion -PackagesInfo `$packages" -ForegroundColor Gray
Write-Host "   # Use when you need explicit control over the process" -ForegroundColor Gray

Write-Host "`n=== Demo Complete ===" -ForegroundColor Cyan
Write-Host "Duplicate removal ensures clean, reliable snapshots from installers!" -ForegroundColor Green
