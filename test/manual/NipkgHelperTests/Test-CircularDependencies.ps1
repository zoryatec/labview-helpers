#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Test script for circular dependency handling in Get-PackageInstallationOrder.

.DESCRIPTION
    Tests the Get-PackageInstallationOrder function's ability to handle circular dependencies
    which are common in real-world package systems.
#>

# Import the module
Import-Module -Name $PSScriptRoot/../../../LabViewHelpers/LabViewHelpers.psd1 -Force

Write-Host "====================================================================================" -ForegroundColor Cyan
Write-Host "Testing Circular Dependency Handling" -ForegroundColor Cyan
Write-Host "====================================================================================" -ForegroundColor Cyan
Write-Host ""

# Test 1: Simple circular dependency
Write-Host "Test 1: Simple Circular Dependency" -ForegroundColor Yellow
Write-Host "==================================" -ForegroundColor Yellow

$circularPackages = @(
    [PSCustomObject]@{
        Package = "package-a"
        Version = "1.0.0"
        Section = "Test"
        Depends = "package-b"
    },
    [PSCustomObject]@{
        Package = "package-b"
        Version = "1.0.0"
        Section = "Test"
        Depends = "package-a"
    }
)

Write-Host "Created packages with circular dependency:" -ForegroundColor Cyan
Write-Host "  package-a depends on package-b" -ForegroundColor White
Write-Host "  package-b depends on package-a" -ForegroundColor White
Write-Host ""

# Test without allowing circular dependencies (should fail)
Write-Host "Testing without AllowCircularDependencies (should fail)..." -ForegroundColor Yellow
try {
    $result = Get-PackageInstallationOrder -PackagesInfo $circularPackages
    Write-Host "! Unexpected success - circular dependency not detected" -ForegroundColor Yellow
} catch {
    Write-Host "✓ Expected failure: $($_.Exception.Message)" -ForegroundColor Green
}

Write-Host ""

# Test with allowing circular dependencies (should succeed)
Write-Host "Testing with AllowCircularDependencies (should succeed)..." -ForegroundColor Yellow
try {
    $result = Get-PackageInstallationOrder -PackagesInfo $circularPackages -AllowCircularDependencies
    Write-Host "✓ Success with circular dependencies allowed" -ForegroundColor Green
    Write-Host "  Installation order:" -ForegroundColor Cyan
    for ($i = 0; $i -lt $result.Count; $i++) {
        Write-Host "    $($i + 1). $($result[$i].Package)" -ForegroundColor White
    }
} catch {
    Write-Host "✗ Unexpected failure: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""

# Test 2: Real-world scenario (NI Vision packages)
Write-Host "Test 2: Real-world NI Vision Circular Dependency" -ForegroundColor Yellow
Write-Host "================================================" -ForegroundColor Yellow

$niVisionPackages = @(
    [PSCustomObject]@{
        Package = "ni-vision-common-resources"
        Version = "25.0.0"
        Section = "Drivers"
        Depends = "ni-vision-common-labview-support"
    },
    [PSCustomObject]@{
        Package = "ni-vision-common-labview-support"
        Version = "25.0.0"
        Section = "Programming Environments"
        Depends = "ni-vision-common-resources"
    },
    [PSCustomObject]@{
        Package = "ni-vision-development-module"
        Version = "25.0.0"
        Section = "Programming Environments"
        Depends = "ni-vision-common-resources, ni-vision-common-labview-support"
    }
)

Write-Host "Created NI Vision packages with known circular dependency:" -ForegroundColor Cyan
Write-Host "  ni-vision-common-resources ↔ ni-vision-common-labview-support" -ForegroundColor White
Write-Host "  ni-vision-development-module depends on both" -ForegroundColor White
Write-Host ""

try {
    $niResult = Get-PackageInstallationOrder -PackagesInfo $niVisionPackages -AllowCircularDependencies
    Write-Host "✓ Successfully handled NI Vision circular dependency" -ForegroundColor Green
    Write-Host "  Installation order:" -ForegroundColor Cyan
    for ($i = 0; $i -lt $niResult.Count; $i++) {
        Write-Host "    $($i + 1). $($niResult[$i].Package)" -ForegroundColor White
    }
} catch {
    Write-Host "✗ Failed to handle NI Vision scenario: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""

# Test 3: Complex dependency chain with cycle
Write-Host "Test 3: Complex Dependency Chain with Cycle" -ForegroundColor Yellow
Write-Host "===========================================" -ForegroundColor Yellow

$complexPackages = @(
    [PSCustomObject]@{
        Package = "base-lib"
        Version = "1.0.0"
        Section = "Libraries"
    },
    [PSCustomObject]@{
        Package = "util-lib"
        Version = "1.0.0"
        Section = "Libraries"
        Depends = "base-lib"
    },
    [PSCustomObject]@{
        Package = "core-a"
        Version = "1.0.0"
        Section = "Core"
        Depends = "util-lib, core-b"
    },
    [PSCustomObject]@{
        Package = "core-b"
        Version = "1.0.0"
        Section = "Core"
        Depends = "util-lib, core-a"
    },
    [PSCustomObject]@{
        Package = "application"
        Version = "1.0.0"
        Section = "Applications"
        Depends = "core-a, core-b"
    }
)

Write-Host "Created complex scenario:" -ForegroundColor Cyan
Write-Host "  base-lib (no deps)" -ForegroundColor White
Write-Host "  util-lib → base-lib" -ForegroundColor White
Write-Host "  core-a ↔ core-b (circular, both depend on util-lib)" -ForegroundColor White
Write-Host "  application → core-a, core-b" -ForegroundColor White
Write-Host ""

try {
    $complexResult = Get-PackageInstallationOrder -PackagesInfo $complexPackages -AllowCircularDependencies
    Write-Host "✓ Successfully handled complex scenario" -ForegroundColor Green
    Write-Host "  Installation order:" -ForegroundColor Cyan
    for ($i = 0; $i -lt $complexResult.Count; $i++) {
        Write-Host "    $($i + 1). $($complexResult[$i].Package)" -ForegroundColor White
    }
    
    # Verify base packages come first
    $firstPackage = $complexResult[0].Package
    $lastPackage = $complexResult[-1].Package
    
    if ($firstPackage -eq "base-lib") {
        Write-Host "✓ Base package correctly ordered first" -ForegroundColor Green
    } else {
        Write-Host "! Base package not first (got: $firstPackage)" -ForegroundColor Yellow
    }
    
    if ($lastPackage -eq "application") {
        Write-Host "✓ Application correctly ordered last" -ForegroundColor Green
    } else {
        Write-Host "! Application not last (got: $lastPackage)" -ForegroundColor Yellow
    }
    
} catch {
    Write-Host "✗ Failed complex scenario: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""

# Test 4: Test the updated New-NipkgSnapshot function
Write-Host "Test 4: New-NipkgSnapshot with Circular Dependencies" -ForegroundColor Yellow
Write-Host "====================================================" -ForegroundColor Yellow

$fakeFeed = @([PSCustomObject]@{
    Name = "test-feed"
    Path = "file:///test"
})

Write-Host "Testing New-NipkgSnapshot with circular dependency packages..." -ForegroundColor Cyan

try {
    $snapshot = New-NipkgSnapshot -FeedsInfo $fakeFeed -PackagesInfo $circularPackages
    Write-Host "✓ New-NipkgSnapshot successfully handled circular dependencies" -ForegroundColor Green
    Write-Host "  Snapshot contains $($snapshot.packages.Count) packages" -ForegroundColor White
} catch {
    Write-Host "✗ New-NipkgSnapshot failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "====================================================================================" -ForegroundColor Cyan
Write-Host "Circular Dependency Tests Completed" -ForegroundColor Cyan
Write-Host "====================================================================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "KEY POINTS:" -ForegroundColor Yellow
Write-Host "• Circular dependencies are common in real package systems" -ForegroundColor White
Write-Host "• Use -AllowCircularDependencies to handle them gracefully" -ForegroundColor White
Write-Host "• The function will break cycles at arbitrary points but maintain overall order" -ForegroundColor White
Write-Host "• Updated New-NipkgSnapshot now automatically allows circular dependencies" -ForegroundColor White
Write-Host ""
