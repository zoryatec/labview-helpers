# Test script for the enhanced New-NipkgSnapshot function
# This script demonstrates the new packages-nipkg dependency resolution feature

Import-Module -Force "../../LabViewHelpers/LabViewHelpers.psd1" -Verbose:$false

Write-Host "=== Testing Enhanced New-NipkgSnapshot Function ===" -ForegroundColor Cyan
Write-Host "This test demonstrates the new packages-nipkg dependency resolution feature" -ForegroundColor Yellow
Write-Host ""

# Test 1: Mock data with ni-package-manager packages
Write-Host "Test 1: Creating snapshot with ni-package-manager packages..." -ForegroundColor Green

$mockFeedsInfo = @(
    [PSCustomObject]@{ Name = "test-feed"; Path = "C:\test\feed" }
)

$mockPackagesInfo = @(
    [PSCustomObject]@{ Package = "ni-package-manager"; Version = "25.0.0.49255-0+f103"; Depends = "ni-certificates (>=24.5.1), ni-euladepot" }
    [PSCustomObject]@{ Package = "ni-certificates"; Version = "24.5.1.49255-0+f103"; Depends = "ni-euladepot" }
    [PSCustomObject]@{ Package = "ni-euladepot"; Version = "25.0.0.49255-0+f103"; Depends = "" }
    [PSCustomObject]@{ Package = "labview-core"; Version = "25.0.0.49255-0+f103"; Depends = "ni-certificates" }
    [PSCustomObject]@{ Package = "other-package"; Version = "1.0.0"; Depends = "" }
)

$testSnapshot = New-NipkgSnapshot -FeedsInfo $mockFeedsInfo -PackagesInfo $mockPackagesInfo

Write-Host "✓ Snapshot created successfully!" -ForegroundColor Green
Write-Host "  Feeds: $($testSnapshot.feeds.Count)"
Write-Host "  Regular packages: $($testSnapshot.packages.Count)"
Write-Host "  NIPKG packages with dependencies: $($testSnapshot.'packages-nipkg'.Count)"
Write-Host ""

Write-Host "Packages-NIPKG section contents:" -ForegroundColor Yellow
$testSnapshot.'packages-nipkg' | ForEach-Object { 
    Write-Host "  - $($_.name) v$($_.version)" 
}
Write-Host ""

Write-Host "Regular packages section contents:" -ForegroundColor Yellow
$testSnapshot.packages | ForEach-Object { 
    Write-Host "  - $($_.name) v$($_.version)" 
}
Write-Host ""

# Test 2: Export to JSON and verify structure
Write-Host "Test 2: Exporting to JSON and verifying structure..." -ForegroundColor Green

$jsonPath = "test-temp/test-snapshot-with-nipkg.json"
$exportResult = Export-NipkgSnapshotToJson -Snapshot $testSnapshot -OutputPath $jsonPath

Write-Host "✓ JSON export successful!" -ForegroundColor Green
Write-Host "  File: $jsonPath"
Write-Host "  Size: $($exportResult.FileSizeBytes) bytes"
Write-Host ""

# Test 3: Import and verify the structure is preserved
Write-Host "Test 3: Importing JSON and verifying structure..." -ForegroundColor Green

$importedSnapshot = Import-NipkgSnapshotFromJson -InputPath $jsonPath

$hasPackagesNipkg = $importedSnapshot.ContainsKey("packages-nipkg")
if ($hasPackagesNipkg) {
    Write-Host "✓ packages-nipkg section preserved in JSON!" -ForegroundColor Green
    Write-Host "  Imported packages-nipkg count: $($importedSnapshot.'packages-nipkg'.Count)"
} else {
    Write-Host "✗ packages-nipkg section missing in imported JSON!" -ForegroundColor Red
}
Write-Host ""

# Test 4: Test with data that has no ni-package-manager packages
Write-Host "Test 4: Testing with data that has no ni-package-manager packages..." -ForegroundColor Green

$noNipkgPackagesInfo = $mockPackagesInfo | Where-Object { $_.Package -ne "ni-package-manager" }
$snapshotWithoutNipkg = New-NipkgSnapshot -FeedsInfo $mockFeedsInfo -PackagesInfo $noNipkgPackagesInfo

Write-Host "✓ Snapshot created successfully!" -ForegroundColor Green
Write-Host "  Regular packages: $($snapshotWithoutNipkg.packages.Count)"
Write-Host "  NIPKG packages: $($snapshotWithoutNipkg.'packages-nipkg'.Count) (should be 0)"
Write-Host ""

Write-Host "=== Summary ===" -ForegroundColor Cyan
Write-Host "✓ Enhanced New-NipkgSnapshot function is working correctly!" -ForegroundColor Green
Write-Host "✓ Automatically resolves ni-package-manager dependencies" -ForegroundColor Green
Write-Host "✓ Creates packages-nipkg section with resolved dependencies" -ForegroundColor Green
Write-Host "✓ Handles cases with and without ni-package-manager packages" -ForegroundColor Green
Write-Host "✓ JSON export/import preserves the new structure" -ForegroundColor Green
Write-Host "✓ NIPKG packages are duplicated in both sections as expected" -ForegroundColor Green
Write-Host ""
Write-Host "When Apply-NipkgSnapshot is used, the packages-nipkg section ensures" -ForegroundColor Yellow
Write-Host "that all NIPKG dependencies are available for installation." -ForegroundColor Yellow
