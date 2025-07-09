# Test script to verify that packages-nipkg section is always created
Import-Module -Force "../../LabViewHelpers/LabViewHelpers.psd1" -Verbose

Write-Host "=== Testing that packages-nipkg section is always created ===" -ForegroundColor Cyan

# Test 1: Mock data without any ni-package-manager packages
Write-Host "Test 1: Creating snapshot without ni-package-manager packages..." -ForegroundColor Yellow

$mockFeeds = @(
    [PSCustomObject]@{ Name = "test-feed"; Path = "C:\feeds\test" }
)

$mockPackages = @(
    [PSCustomObject]@{ Package = "some-driver"; Version = "1.0.0"; Section = "Drivers" }
    [PSCustomObject]@{ Package = "labview-runtime"; Version = "25.0.0"; Section = "Programming Environments" }
    [PSCustomObject]@{ Package = "some-utility"; Version = "2.1.0"; Section = "Utilities" }
)

Write-Host "Creating snapshot with $($mockPackages.Count) non-NIPKG packages..."
$snapshot1 = New-NipkgSnapshot -FeedsInfo $mockFeeds -PackagesInfo $mockPackages

Write-Host "Snapshot contains:"
Write-Host "  Feeds: $($snapshot1.feeds.Count)"
Write-Host "  Packages: $($snapshot1.packages.Count)"
Write-Host "  Packages-nipkg: $($snapshot1.'packages-nipkg'.Count)"

if ($snapshot1.'packages-nipkg'.Count -gt 0) {
    Write-Host "OK packages-nipkg section created with $($snapshot1.'packages-nipkg'.Count) packages" -ForegroundColor Green
    Write-Host "Packages in packages-nipkg:"
    $snapshot1.'packages-nipkg' | ForEach-Object { Write-Host "    - $($_.name) v$($_.version)" }
} else {
    Write-Host "ERROR: packages-nipkg section is empty!" -ForegroundColor Red
}

# Test 2: Mock data with ni-package-manager packages
Write-Host "`nTest 2: Creating snapshot with ni-package-manager packages..." -ForegroundColor Yellow

$mockPackages2 = @(
    [PSCustomObject]@{ Package = "system-windows-x64"; Version = "22.8.0.49255-0+f103"; Section = "Utilities" }
    [PSCustomObject]@{ Package = "ni-package-manager-deployment-support"; Version = "22.8.0.49255-0+f103"; Section = "Utilities" }
    [PSCustomObject]@{ Package = "ni-package-manager-upgrader"; Version = "22.8.0.49255-0+f103"; Section = "Utilities" }
    [PSCustomObject]@{ Package = "ni-package-manager"; Version = "22.8.0.49255-0+f103"; Section = "Utilities" }
    [PSCustomObject]@{ Package = "some-other-package"; Version = "1.5.0"; Section = "Drivers" }
)

Write-Host "Creating snapshot with $($mockPackages2.Count) packages including NIPKG..."
$snapshot2 = New-NipkgSnapshot -FeedsInfo $mockFeeds -PackagesInfo $mockPackages2

Write-Host "Snapshot contains:"
Write-Host "  Feeds: $($snapshot2.feeds.Count)"
Write-Host "  Packages: $($snapshot2.packages.Count)"
Write-Host "  Packages-nipkg: $($snapshot2.'packages-nipkg'.Count)"

if ($snapshot2.'packages-nipkg'.Count -gt 0) {
    Write-Host "OK packages-nipkg section created with $($snapshot2.'packages-nipkg'.Count) packages" -ForegroundColor Green
    Write-Host "Packages in packages-nipkg:"
    $snapshot2.'packages-nipkg' | ForEach-Object { Write-Host "    - $($_.name) v$($_.version)" }
} else {
    Write-Host "ERROR: packages-nipkg section is empty!" -ForegroundColor Red
}

# Test 3: Real system snapshot
Write-Host "`nTest 3: Creating snapshot from test data..." -ForegroundColor Yellow

if (Test-Path "test-temp\system-snapshot.json") {
    $existingSnapshot = Import-NipkgSnapshotFromJson -InputPath "test-temp\system-snapshot.json"
    Write-Host "Loaded existing snapshot:"
    Write-Host "  Feeds: $($existingSnapshot.feeds.Count)"
    Write-Host "  Packages: $($existingSnapshot.packages.Count)"
    Write-Host "  Packages-nipkg: $($existingSnapshot.'packages-nipkg'.Count)"
    
    if ($existingSnapshot.'packages-nipkg'.Count -gt 0) {
        Write-Host "OK existing snapshot already has packages-nipkg section" -ForegroundColor Green
    } else {
        Write-Host "NOTICE: existing snapshot does not have packages-nipkg section (expected for older snapshots)" -ForegroundColor Yellow
    }
}

Write-Host "`n=== Summary ===" -ForegroundColor Cyan
Write-Host "All new snapshots should have packages-nipkg sections:"
Write-Host "  Test 1 (no NIPKG packages): $($snapshot1.'packages-nipkg'.Count -gt 0)"
Write-Host "  Test 2 (with NIPKG packages): $($snapshot2.'packages-nipkg'.Count -gt 0)"

if ($snapshot1.'packages-nipkg'.Count -gt 0 -and $snapshot2.'packages-nipkg'.Count -gt 0) {
    Write-Host "SUCCESS: All new snapshots now include packages-nipkg section!" -ForegroundColor Green
} else {
    Write-Host "FAILURE: Some snapshots missing packages-nipkg section!" -ForegroundColor Red
}
