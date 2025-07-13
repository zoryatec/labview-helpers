# Test script for verifying error handling when multiple ni-package-manager packages are found

# Import the module
Remove-Module LabViewHelpers -Force -ErrorAction SilentlyContinue
Import-Module "c:\Projects\_Repos\labview-helpers\LabViewHelpers\LabViewHelpers.psd1" -Force

Write-Host "=== Testing Multiple ni-package-manager Error Handling ===" -ForegroundColor Cyan

# Test 1: Single ni-package-manager package (should work)
Write-Host "`nTest 1: Single ni-package-manager package (should succeed)" -ForegroundColor Green

$testFeedsInfo = @(
    [PSCustomObject]@{ Name = "TestFeed1"; Path = "https://test1.com" }
)

$testPackagesInfo = @(
    [PSCustomObject]@{ Package = "ni-package-manager"; Version = "21.0.0"; Section = "Programming Environments"; Dependencies = @() },
    [PSCustomObject]@{ Package = "labview-2021"; Version = "21.0.0"; Section = "Programming Environments"; Dependencies = @() },
    [PSCustomObject]@{ Package = "ni-visa"; Version = "21.0.0"; Section = "Drivers"; Dependencies = @() }
)

try {
    $snapshot = New-Snapshot -FeedsInfo $testFeedsInfo -PackagesInfo $testPackagesInfo -Verbose
    if ($snapshot.ContainsKey("packages-nipkg")) {
        Write-Host "✓ PASS: Single ni-package-manager created packages-nipkg section" -ForegroundColor Green
        Write-Host "  packages-nipkg contains $($snapshot["packages-nipkg"].Count) packages" -ForegroundColor Gray
    } else {
        Write-Host "✗ FAIL: Single ni-package-manager should have created packages-nipkg section" -ForegroundColor Red
    }
} catch {
    Write-Host "✗ FAIL: Single ni-package-manager should not throw error: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 2: Multiple ni-package-manager packages (should throw error)
Write-Host "`nTest 2: Multiple ni-package-manager packages (should throw error)" -ForegroundColor Green

$testPackagesInfoMultiple = @(
    [PSCustomObject]@{ Package = "ni-package-manager"; Version = "21.0.0"; Section = "Programming Environments"; Dependencies = @() },
    [PSCustomObject]@{ Package = "ni-package-manager"; Version = "22.0.0"; Section = "Programming Environments"; Dependencies = @() },
    [PSCustomObject]@{ Package = "labview-2021"; Version = "21.0.0"; Section = "Programming Environments"; Dependencies = @() }
)

try {
    $snapshot = New-Snapshot -FeedsInfo $testFeedsInfo -PackagesInfo $testPackagesInfoMultiple -Verbose
    Write-Host "✗ FAIL: Multiple ni-package-manager packages should have thrown an error" -ForegroundColor Red
} catch {
    if ($_.Exception.Message -like "*Multiple ni-package-manager packages found*") {
        Write-Host "✓ PASS: Multiple ni-package-manager packages correctly threw error" -ForegroundColor Green
        Write-Host "  Error message: $($_.Exception.Message)" -ForegroundColor Gray
    } else {
        Write-Host "✗ FAIL: Wrong error message: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Test 3: No ni-package-manager packages (should work without packages-nipkg)
Write-Host "`nTest 3: No ni-package-manager packages (should succeed without packages-nipkg)" -ForegroundColor Green

$testPackagesInfoNone = @(
    [PSCustomObject]@{ Package = "labview-2021"; Version = "21.0.0"; Section = "Programming Environments"; Dependencies = @() },
    [PSCustomObject]@{ Package = "ni-visa"; Version = "21.0.0"; Section = "Drivers"; Dependencies = @() }
)

try {
    $snapshot = New-Snapshot -FeedsInfo $testFeedsInfo -PackagesInfo $testPackagesInfoNone -Verbose
    if (-not $snapshot.ContainsKey("packages-nipkg")) {
        Write-Host "✓ PASS: No ni-package-manager correctly omitted packages-nipkg section" -ForegroundColor Green
    } else {
        Write-Host "✗ FAIL: No ni-package-manager should not create packages-nipkg section" -ForegroundColor Red
    }
} catch {
    Write-Host "✗ FAIL: No ni-package-manager should not throw error: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 4: Edge case - three ni-package-manager packages (should throw error)
Write-Host "`nTest 4: Three ni-package-manager packages (should throw error)" -ForegroundColor Green

$testPackagesInfoThree = @(
    [PSCustomObject]@{ Package = "ni-package-manager"; Version = "20.0.0"; Section = "Programming Environments"; Dependencies = @() },
    [PSCustomObject]@{ Package = "ni-package-manager"; Version = "21.0.0"; Section = "Programming Environments"; Dependencies = @() },
    [PSCustomObject]@{ Package = "ni-package-manager"; Version = "22.0.0"; Section = "Programming Environments"; Dependencies = @() },
    [PSCustomObject]@{ Package = "labview-2021"; Version = "21.0.0"; Section = "Programming Environments"; Dependencies = @() }
)

try {
    $snapshot = New-Snapshot -FeedsInfo $testFeedsInfo -PackagesInfo $testPackagesInfoThree -Verbose
    Write-Host "✗ FAIL: Three ni-package-manager packages should have thrown an error" -ForegroundColor Red
} catch {
    if ($_.Exception.Message -like "*Multiple ni-package-manager packages found*" -and $_.Exception.Message -like "*3 instances*") {
        Write-Host "✓ PASS: Three ni-package-manager packages correctly threw error" -ForegroundColor Green
        Write-Host "  Error message: $($_.Exception.Message)" -ForegroundColor Gray
    } else {
        Write-Host "✗ FAIL: Wrong error message for three packages: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host "`n=== Test Summary ===" -ForegroundColor Cyan
Write-Host "All tests completed. Check results above for PASS/FAIL status." -ForegroundColor White
