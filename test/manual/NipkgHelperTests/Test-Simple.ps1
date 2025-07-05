#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Simple test to verify Get-PackageInstallationOrder function works.
#>

# Import the module
Import-Module -Name $PSScriptRoot/../../../LabViewHelpers/LabViewHelpers.psd1 -Force -ErrorAction Stop

Write-Host "Testing Get-PackageInstallationOrder with synthetic data..." -ForegroundColor Cyan

# Create simple test data
$testPackages = @(
    [PSCustomObject]@{
        Package = "base-lib"
        Version = "1.0.0"
        Section = "Libraries"
    },
    [PSCustomObject]@{
        Package = "middle-lib"
        Version = "1.0.0"
        Section = "Libraries"
        Depends = "base-lib"
    },
    [PSCustomObject]@{
        Package = "top-app"
        Version = "1.0.0"
        Section = "Applications"
        Depends = "middle-lib"
        Recommends = "base-lib"
    }
)

Write-Host "Input packages:" -ForegroundColor Yellow
foreach ($pkg in $testPackages) {
    $deps = ""
    if ($pkg.PSObject.Properties.Name -contains 'Depends') { $deps += "Depends: $($pkg.Depends); " }
    if ($pkg.PSObject.Properties.Name -contains 'Recommends') { $deps += "Recommends: $($pkg.Recommends)" }
    if (-not $deps) { $deps = "No dependencies" }
    Write-Host "  $($pkg.Package): $deps" -ForegroundColor White
}

# Test the function
try {
    Write-Host ""
    Write-Host "Running Get-PackageInstallationOrder..." -ForegroundColor Yellow
    $orderedPackages = Get-PackageInstallationOrder -PackagesInfo $testPackages
    
    Write-Host "✓ Success! Installation order:" -ForegroundColor Green
    for ($i = 0; $i -lt $orderedPackages.Count; $i++) {
        Write-Host "  $($i + 1). $($orderedPackages[$i].Package)" -ForegroundColor White
    }
    
    # Verify the order makes sense
    $expectedOrder = @("base-lib", "middle-lib", "top-app")
    $actualOrder = $orderedPackages | ForEach-Object { $_.Package }
    
    if ($actualOrder[0] -eq $expectedOrder[0] -and $actualOrder[-1] -eq $expectedOrder[-1]) {
        Write-Host "✓ Order is correct (dependencies first, dependents last)" -ForegroundColor Green
    } else {
        Write-Host "! Order may need review" -ForegroundColor Yellow
        Write-Host "  Expected first: $($expectedOrder[0]), Actual: $($actualOrder[0])" -ForegroundColor Gray
        Write-Host "  Expected last: $($expectedOrder[-1]), Actual: $($actualOrder[-1])" -ForegroundColor Gray
    }
    
} catch {
    Write-Host "✗ Error: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "Test with empty array..." -ForegroundColor Yellow
try {
    $emptyResult = Get-PackageInstallationOrder -PackagesInfo @()
    if ($emptyResult.Count -eq 0) {
        Write-Host "✓ Empty array handled correctly" -ForegroundColor Green
    } else {
        Write-Host "! Unexpected result for empty array" -ForegroundColor Yellow
    }
} catch {
    Write-Host "✗ Error with empty array: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "Test completed." -ForegroundColor Cyan
