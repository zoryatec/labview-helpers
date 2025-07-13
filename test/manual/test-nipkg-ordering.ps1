# Test script to verify that Get-PackageInstallationOrder is being applied correctly in New-Snapshot

Import-Module -Force "../../LabViewHelpers/LabViewHelpers.psd1" -Verbose:$false

Write-Host "=== Testing NIPKG Dependency Ordering in New-Snapshot ===" -ForegroundColor Cyan
Write-Host ""

# Create mock data with dependencies that have a clear order
$mockPackagesInfo = @(
    [PSCustomObject]@{
        Package = "ni-euladepot"
        Version = "25.0.0.49255-0+f103"
        Depends = $null  # No dependencies (should be first)
    },
    [PSCustomObject]@{
        Package = "ni-certificates"
        Version = "24.5.1.49255-0+f103"
        Depends = "ni-euladepot"  # Depends on euladepot (should be second)
    },
    [PSCustomObject]@{
        Package = "ni-package-manager"
        Version = "25.0.0.49255-0+f103"
        Depends = "ni-certificates"  # Depends on certificates (should be last)
    }
)

$mockFeedsInfo = @(
    [PSCustomObject]@{ Name = "test-feed"; Path = "C:\test\feed" }
)

Write-Host "Test: Verifying package ordering in packages-nipkg section..." -ForegroundColor Green

# Create snapshot with the mock data
$testSnapshot = New-Snapshot -FeedsInfo $mockFeedsInfo -PackagesInfo $mockPackagesInfo

Write-Host "✓ Snapshot created successfully!" -ForegroundColor Green
Write-Host "  Packages-NIPKG section contains: $($testSnapshot.'packages-nipkg'.Count) packages"
Write-Host ""

Write-Host "Package order in packages-nipkg section:" -ForegroundColor Yellow
for ($i = 0; $i -lt $testSnapshot.'packages-nipkg'.Count; $i++) {
    $pkg = $testSnapshot.'packages-nipkg'[$i]
    Write-Host "  $($i + 1). $($pkg.name) v$($pkg.version)" -ForegroundColor White
}
Write-Host ""

# Verify expected order
$expectedOrder = @("ni-euladepot", "ni-certificates", "ni-package-manager")
$actualOrder = $testSnapshot.'packages-nipkg' | ForEach-Object { $_.name }

$orderCorrect = $true
for ($i = 0; $i -lt $expectedOrder.Count; $i++) {
    if ($actualOrder[$i] -ne $expectedOrder[$i]) {
        $orderCorrect = $false
        break
    }
}

if ($orderCorrect) {
    Write-Host "✓ Package ordering is correct!" -ForegroundColor Green
    Write-Host "  Expected: $($expectedOrder -join ' → ')" -ForegroundColor White
    Write-Host "  Actual:   $($actualOrder -join ' → ')" -ForegroundColor White
} else {
    Write-Host "✗ Package ordering is incorrect!" -ForegroundColor Red
    Write-Host "  Expected: $($expectedOrder -join ' → ')" -ForegroundColor White
    Write-Host "  Actual:   $($actualOrder -join ' → ')" -ForegroundColor White
}

Write-Host ""
Write-Host "=== Summary ===" -ForegroundColor Cyan
if ($orderCorrect) {
    Write-Host "✓ Get-PackageInstallationOrder is working correctly in New-Snapshot!" -ForegroundColor Green
    Write-Host "✓ Dependencies are ordered for optimal installation sequence" -ForegroundColor Green
} else {
    Write-Host "✗ Package ordering needs to be fixed" -ForegroundColor Red
}
