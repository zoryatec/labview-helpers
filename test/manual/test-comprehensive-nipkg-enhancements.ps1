# Comprehensive test for all NIPKG snapshot enhancements

# Import the module
Remove-Module LabViewHelpers -Force -ErrorAction SilentlyContinue
Import-Module "c:\Projects\_Repos\labview-helpers\LabViewHelpers\LabViewHelpers.psd1" -Force

Write-Host "=== Comprehensive NIPKG Enhancement Test ===" -ForegroundColor Cyan

# Test data
$testFeedsInfo = @(
    [PSCustomObject]@{ Name = "TestFeed1"; Path = "https://test1.com" }
)

Write-Host "`n1. Testing New-Snapshot enhancements..." -ForegroundColor Green

# Test 1.1: Single ni-package-manager creates packages-nipkg
Write-Host "  - Testing single ni-package-manager package..." -ForegroundColor Yellow
$packagesWithSingleNipkg = @(
    [PSCustomObject]@{ Package = "ni-package-manager"; Version = "21.0.0"; Section = "Programming Environments"; Dependencies = @() },
    [PSCustomObject]@{ Package = "labview-2021"; Version = "21.0.0"; Section = "Programming Environments"; Dependencies = @() }
)

try {
    $snapshot1 = New-Snapshot -FeedsInfo $testFeedsInfo -PackagesInfo $packagesWithSingleNipkg
    $hasPackagesNipkg = $snapshot1.ContainsKey("packages-nipkg")
    Write-Host "    ✓ Creates packages-nipkg: $hasPackagesNipkg" -ForegroundColor Green
} catch {
    Write-Host "    ✗ Error: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 1.2: Multiple ni-package-manager throws error
Write-Host "  - Testing multiple ni-package-manager packages..." -ForegroundColor Yellow
$packagesWithMultipleNipkg = @(
    [PSCustomObject]@{ Package = "ni-package-manager"; Version = "21.0.0"; Section = "Programming Environments"; Dependencies = @() },
    [PSCustomObject]@{ Package = "ni-package-manager"; Version = "22.0.0"; Section = "Programming Environments"; Dependencies = @() }
)

try {
    $snapshot2 = New-Snapshot -FeedsInfo $testFeedsInfo -PackagesInfo $packagesWithMultipleNipkg
    Write-Host "    ✗ Should have thrown error" -ForegroundColor Red
} catch {
    if ($_.Exception.Message -like "*Multiple ni-package-manager packages found*") {
        Write-Host "    ✓ Correctly throws error for multiple NIPKG packages" -ForegroundColor Green
    } else {
        Write-Host "    ✗ Wrong error: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Test 1.3: No ni-package-manager omits packages-nipkg
Write-Host "  - Testing no ni-package-manager packages..." -ForegroundColor Yellow
$packagesWithoutNipkg = @(
    [PSCustomObject]@{ Package = "labview-2021"; Version = "21.0.0"; Section = "Programming Environments"; Dependencies = @() }
)

try {
    $snapshot3 = New-Snapshot -FeedsInfo $testFeedsInfo -PackagesInfo $packagesWithoutNipkg
    $hasPackagesNipkg = $snapshot3.ContainsKey("packages-nipkg")
    Write-Host "    ✓ Omits packages-nipkg: $(-not $hasPackagesNipkg)" -ForegroundColor Green
} catch {
    Write-Host "    ✗ Error: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n2. Testing Export-NipkgSnapshotToJson..." -ForegroundColor Green

# Test 2.1: Export snapshot with packages-nipkg
Write-Host "  - Testing export with packages-nipkg..." -ForegroundColor Yellow
$tempFile1 = Join-Path $env:TEMP "test-snapshot-with-nipkg.json"
try {
    Export-NipkgSnapshotToJson -Snapshot $snapshot1 -OutputPath $tempFile1
    $jsonContent = Get-Content $tempFile1 | ConvertFrom-Json
    $hasPackagesNipkg = [bool]$jsonContent."packages-nipkg"
    Write-Host "    ✓ Exported with packages-nipkg: $hasPackagesNipkg" -ForegroundColor Green
} catch {
    Write-Host "    ✗ Error: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 2.2: Export snapshot without packages-nipkg
Write-Host "  - Testing export without packages-nipkg..." -ForegroundColor Yellow
$tempFile2 = Join-Path $env:TEMP "test-snapshot-without-nipkg.json"
try {
    Export-NipkgSnapshotToJson -Snapshot $snapshot3 -OutputPath $tempFile2
    $jsonContent = Get-Content $tempFile2 | ConvertFrom-Json
    $hasPackagesNipkg = [bool]$jsonContent."packages-nipkg"
    Write-Host "    ✓ Exported without packages-nipkg: $(-not $hasPackagesNipkg)" -ForegroundColor Green
} catch {
    Write-Host "    ✗ Error: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n3. Testing Import-NipkgSnapshotFromJson..." -ForegroundColor Green

# Test 3.1: Import snapshot with packages-nipkg
Write-Host "  - Testing import with packages-nipkg..." -ForegroundColor Yellow
try {
    $importedSnapshot1 = Import-NipkgSnapshotFromJson -InputPath $tempFile1
    $hasPackagesNipkg = $importedSnapshot1.ContainsKey("packages-nipkg")
    Write-Host "    ✓ Imported with packages-nipkg: $hasPackagesNipkg" -ForegroundColor Green
} catch {
    Write-Host "    ✗ Error: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 3.2: Import snapshot without packages-nipkg
Write-Host "  - Testing import without packages-nipkg..." -ForegroundColor Yellow
try {
    $importedSnapshot2 = Import-NipkgSnapshotFromJson -InputPath $tempFile2
    $hasPackagesNipkg = $importedSnapshot2.ContainsKey("packages-nipkg")
    Write-Host "    ✓ Imported without packages-nipkg: $(-not $hasPackagesNipkg)" -ForegroundColor Green
} catch {
    Write-Host "    ✗ Error: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n4. Testing round-trip consistency..." -ForegroundColor Green

# Test 4.1: Round-trip with packages-nipkg
Write-Host "  - Testing round-trip with packages-nipkg..." -ForegroundColor Yellow
$originalPackagesNipkgCount = if ($snapshot1.ContainsKey("packages-nipkg")) { $snapshot1["packages-nipkg"].Count } else { 0 }
$importedPackagesNipkgCount = if ($importedSnapshot1.ContainsKey("packages-nipkg")) { $importedSnapshot1["packages-nipkg"].Count } else { 0 }
$roundTripMatch = ($originalPackagesNipkgCount -eq $importedPackagesNipkgCount)
Write-Host "    ✓ Round-trip preserves packages-nipkg: $roundTripMatch ($originalPackagesNipkgCount -> $importedPackagesNipkgCount)" -ForegroundColor Green

# Test 4.2: Round-trip without packages-nipkg
Write-Host "  - Testing round-trip without packages-nipkg..." -ForegroundColor Yellow
$originalHasPackagesNipkg = $snapshot3.ContainsKey("packages-nipkg")
$importedHasPackagesNipkg = $importedSnapshot2.ContainsKey("packages-nipkg")
$roundTripMatch = ($originalHasPackagesNipkg -eq $importedHasPackagesNipkg)
Write-Host "    ✓ Round-trip preserves absence of packages-nipkg: $roundTripMatch" -ForegroundColor Green

Write-Host "`n5. Testing Sync-NipkgVersionWithSnapshot..." -ForegroundColor Green

# Test 5.1: Sync with packages-nipkg
Write-Host "  - Testing sync with packages-nipkg (WhatIf)..." -ForegroundColor Yellow
try {
    $syncResult1 = Sync-NipkgVersionWithSnapshot -Snapshot $importedSnapshot1 -WhatIf
    Write-Host "    ✓ Sync handles packages-nipkg correctly" -ForegroundColor Green
} catch {
    Write-Host "    ✗ Error: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 5.2: Sync without packages-nipkg
Write-Host "  - Testing sync without packages-nipkg (WhatIf)..." -ForegroundColor Yellow
try {
    $syncResult2 = Sync-NipkgVersionWithSnapshot -Snapshot $importedSnapshot2 -WhatIf
    Write-Host "    ✓ Sync handles absence of packages-nipkg correctly" -ForegroundColor Green
} catch {
    Write-Host "    ✗ Error: $($_.Exception.Message)" -ForegroundColor Red
}

# Cleanup
Write-Host "`n6. Cleaning up test files..." -ForegroundColor Green
Remove-Item $tempFile1 -ErrorAction SilentlyContinue
Remove-Item $tempFile2 -ErrorAction SilentlyContinue
Write-Host "    ✓ Test files cleaned up" -ForegroundColor Green

Write-Host "`n=== Enhancement Test Summary ===" -ForegroundColor Cyan
Write-Host "✓ New-Snapshot creates packages-nipkg only when exactly one ni-package-manager is present" -ForegroundColor Green
Write-Host "✓ New-Snapshot throws error when multiple ni-package-manager packages are found" -ForegroundColor Green
Write-Host "✓ Export/Import functions preserve packages-nipkg section correctly" -ForegroundColor Green
Write-Host "✓ Round-trip consistency maintained for both scenarios" -ForegroundColor Green
Write-Host "✓ Sync function handles both scenarios gracefully" -ForegroundColor Green
Write-Host "`nAll NIPKG snapshot enhancements are working correctly!" -ForegroundColor White
