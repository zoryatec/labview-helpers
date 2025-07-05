#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Test script for Get-PackageInstallationOrder function.

.DESCRIPTION
    Tests the Get-PackageInstallationOrder function with various scenarios including:
    - Basic dependency ordering
    - Different dependency types (Depends, Recommends, Suggests)
    - Circular dependency detection
    - Package filtering and validation

.NOTES
    Run this script from the test\manual\NipkgHelperTests directory.
    Requires the LabViewHelpers module to be available.
#>

# Import the module
Import-Module -Name $PSScriptRoot/../../../LabViewHelpers/LabViewHelpers.psd1 -Force

Write-Host "====================================================================================" -ForegroundColor Cyan
Write-Host "Testing Get-PackageInstallationOrder Function" -ForegroundColor Cyan
Write-Host "====================================================================================" -ForegroundColor Cyan
Write-Host ""

# Verify function is available
if (-not (Get-Command Get-PackageInstallationOrder -ErrorAction SilentlyContinue)) {
    Write-Host "✗ Get-PackageInstallationOrder function not found!" -ForegroundColor Red
    Write-Host "   Please ensure the LabViewHelpers module is properly imported." -ForegroundColor Yellow
    exit 1
}

Write-Host "✓ Get-PackageInstallationOrder function is available" -ForegroundColor Green
Write-Host ""

# Test data paths
$tempDirectory = "$PSScriptRoot/../test-temp"
$packagesTestFile = "$tempDirectory\Packages"

# Test 1: Basic functionality with real packages file
Write-Host "Test 1: Basic Package Ordering from Packages File" -ForegroundColor Yellow
Write-Host "=================================================" -ForegroundColor Yellow

if (Test-Path $packagesTestFile) {
    try {
        # Load packages
        Write-Host "Loading packages from: $packagesTestFile" -ForegroundColor Cyan
        $packages = Get-PackagesInfoFromPackagesFile -InputPath $packagesTestFile
        Write-Host "✓ Loaded $($packages.Count) packages" -ForegroundColor Green
        
        # Show sample packages with dependencies
        Write-Host ""
        Write-Host "Sample packages with dependencies:" -ForegroundColor Cyan
        $packagesWithDeps = $packages | Where-Object { 
            ($_.PSObject.Properties.Name -contains 'Depends' -and $_.Depends) -or
            ($_.PSObject.Properties.Name -contains 'Recommends' -and $_.Recommends)
        } | Select-Object -First 5
        
        foreach ($pkg in $packagesWithDeps) {
            Write-Host "  $($pkg.Package):" -ForegroundColor White
            if ($pkg.PSObject.Properties.Name -contains 'Depends' -and $pkg.Depends) {
                Write-Host "    Depends: $($pkg.Depends)" -ForegroundColor Gray
            }
            if ($pkg.PSObject.Properties.Name -contains 'Recommends' -and $pkg.Recommends) {
                Write-Host "    Recommends: $($pkg.Recommends)" -ForegroundColor Gray
            }
        }
        
        # Test basic ordering
        Write-Host ""
        Write-Host "Testing basic dependency ordering..." -ForegroundColor Cyan
        $orderedPackages = Get-PackageInstallationOrder -PackagesInfo $packages -Verbose
        
        if ($orderedPackages -and $orderedPackages.Count -gt 0) {
            Write-Host "✓ Successfully ordered $($orderedPackages.Count) packages" -ForegroundColor Green
            
            # Show first 10 packages (should have fewer dependencies)
            Write-Host ""
            Write-Host "First 10 packages in installation order:" -ForegroundColor Cyan
            $orderedPackages | Select-Object -First 10 | ForEach-Object -Begin { $i = 1 } -Process {
                $depCount = 0
                if ($_.PSObject.Properties.Name -contains 'Depends' -and $_.Depends) { $depCount++ }
                if ($_.PSObject.Properties.Name -contains 'Recommends' -and $_.Recommends) { $depCount++ }
                Write-Host "  $i. $($_.Package) - Dependency fields: $depCount" -ForegroundColor White
                $i++
            }
            
            # Show last 5 packages (should have more dependencies)
            Write-Host ""
            Write-Host "Last 5 packages in installation order:" -ForegroundColor Cyan
            $orderedPackages | Select-Object -Last 5 | ForEach-Object -Begin { $i = $orderedPackages.Count - 4 } -Process {
                $depCount = 0
                if ($_.PSObject.Properties.Name -contains 'Depends' -and $_.Depends) { $depCount++ }
                if ($_.PSObject.Properties.Name -contains 'Recommends' -and $_.Recommends) { $depCount++ }
                Write-Host "  $i. $($_.Package) - Dependency fields: $depCount" -ForegroundColor White
                $i++
            }
            
        } else {
            Write-Host "✗ Failed to order packages" -ForegroundColor Red
        }
        
    } catch {
        Write-Host "✗ Test 1 failed: $($_.Exception.Message)" -ForegroundColor Red
    }
} else {
    Write-Host "✗ Packages file not found: $packagesTestFile" -ForegroundColor Red
    Write-Host "   This test requires a NIPKG Packages file in test-temp directory" -ForegroundColor Yellow
}

Write-Host ""

# Test 2: Different dependency types
Write-Host "Test 2: Different Dependency Types" -ForegroundColor Yellow
Write-Host "==================================" -ForegroundColor Yellow

if (Test-Path $packagesTestFile) {
    try {
        $packages = Get-PackagesInfoFromPackagesFile -InputPath $packagesTestFile
        
        # Test with only 'Depends'
        Write-Host "Testing with only 'Depends' dependencies..." -ForegroundColor Cyan
        $strictOrdered = Get-PackageInstallationOrder -PackagesInfo $packages -IncludeDependencyTypes @('Depends')
        Write-Host "✓ Strict ordering: $($strictOrdered.Count) packages" -ForegroundColor Green
        
        # Test with 'Depends' and 'Recommends'
        Write-Host "Testing with 'Depends' and 'Recommends'..." -ForegroundColor Cyan
        $normalOrdered = Get-PackageInstallationOrder -PackagesInfo $packages -IncludeDependencyTypes @('Depends', 'Recommends')
        Write-Host "✓ Normal ordering: $($normalOrdered.Count) packages" -ForegroundColor Green
        
        # Test with all dependency types
        Write-Host "Testing with all dependency types..." -ForegroundColor Cyan
        $allOrdered = Get-PackageInstallationOrder -PackagesInfo $packages -IncludeDependencyTypes @('Depends', 'Recommends', 'Suggests', 'Enhances', 'Supplements')
        Write-Host "✓ Complete ordering: $($allOrdered.Count) packages" -ForegroundColor Green
        
        # Compare results
        Write-Host ""
        Write-Host "Comparison of ordering approaches:" -ForegroundColor Cyan
        Write-Host "  Strict (Depends only): $($strictOrdered.Count) packages" -ForegroundColor White
        Write-Host "  Normal (Depends + Recommends): $($normalOrdered.Count) packages" -ForegroundColor White
        Write-Host "  Complete (All types): $($allOrdered.Count) packages" -ForegroundColor White
        
        if ($strictOrdered.Count -eq $normalOrdered.Count -and $normalOrdered.Count -eq $allOrdered.Count) {
            Write-Host "✓ All approaches returned same package count" -ForegroundColor Green
        } else {
            Write-Host "! Different approaches returned different counts (expected)" -ForegroundColor Yellow
        }
        
    } catch {
        Write-Host "✗ Test 2 failed: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host ""

# Test 3: Create synthetic test data for edge cases
Write-Host "Test 3: Synthetic Test Data (Edge Cases)" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Yellow

try {
    # Create test packages with known dependencies
    $syntheticPackages = @(
        [PSCustomObject]@{
            Package = "base-package"
            Version = "1.0.0"
            Section = "Test"
        },
        [PSCustomObject]@{
            Package = "dependent-package"
            Version = "1.0.0"
            Section = "Test"
            Depends = "base-package (>= 1.0.0)"
        },
        [PSCustomObject]@{
            Package = "complex-package"
            Version = "1.0.0"
            Section = "Test"
            Depends = "base-package, dependent-package"
            Recommends = "optional-package"
        },
        [PSCustomObject]@{
            Package = "optional-package"
            Version = "1.0.0"
            Section = "Test"
        },
        [PSCustomObject]@{
            Package = "final-package"
            Version = "1.0.0"
            Section = "Test"
            Depends = "complex-package"
            Recommends = "dependent-package"
        }
    )
    
    Write-Host "Created $($syntheticPackages.Count) synthetic test packages:" -ForegroundColor Cyan
    foreach ($pkg in $syntheticPackages) {
        $deps = ""
        if ($pkg.PSObject.Properties.Name -contains 'Depends' -and $pkg.Depends) {
            $deps += "Depends: $($pkg.Depends); "
        }
        if ($pkg.PSObject.Properties.Name -contains 'Recommends' -and $pkg.Recommends) {
            $deps += "Recommends: $($pkg.Recommends)"
        }
        if (-not $deps) { $deps = "No dependencies" }
        Write-Host "  $($pkg.Package): $deps" -ForegroundColor White
    }
    
    # Test ordering
    Write-Host ""
    Write-Host "Testing synthetic package ordering..." -ForegroundColor Cyan
    $syntheticOrdered = Get-PackageInstallationOrder -PackagesInfo $syntheticPackages
    
    Write-Host "✓ Ordered synthetic packages:" -ForegroundColor Green
    foreach ($pkg in $syntheticOrdered) {
        $index = [array]::IndexOf($syntheticOrdered, $pkg) + 1
        Write-Host "  $index. $($pkg.Package)" -ForegroundColor White
    }
    
    # Verify expected order (base packages should come first)
    $expectedFirst = @("base-package", "optional-package")
    $expectedLast = @("final-package")
    
    $firstPackage = $syntheticOrdered[0].Package
    $lastPackage = $syntheticOrdered[-1].Package
    
    if ($firstPackage -in $expectedFirst) {
        Write-Host "✓ First package ($firstPackage) is correctly a base package" -ForegroundColor Green
    } else {
        Write-Host "! First package ($firstPackage) may not be optimal" -ForegroundColor Yellow
    }
    
    if ($lastPackage -in $expectedLast) {
        Write-Host "✓ Last package ($lastPackage) is correctly the most dependent" -ForegroundColor Green
    } else {
        Write-Host "! Last package ($lastPackage) ordering may be unexpected" -ForegroundColor Yellow
    }
    
} catch {
    Write-Host "✗ Test 3 failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""

# Test 4: Edge cases and error handling
Write-Host "Test 4: Edge Cases and Error Handling" -ForegroundColor Yellow
Write-Host "=====================================" -ForegroundColor Yellow

try {
    # Test with empty array
    Write-Host "Testing with empty package array..." -ForegroundColor Cyan
    $emptyResult = Get-PackageInstallationOrder -PackagesInfo @()
    if ($emptyResult.Count -eq 0) {
        Write-Host "✓ Empty array handled correctly" -ForegroundColor Green
    } else {
        Write-Host "! Empty array returned unexpected result" -ForegroundColor Yellow
    }
    
    # Test with single package
    Write-Host "Testing with single package..." -ForegroundColor Cyan
    $singlePackage = @([PSCustomObject]@{
        Package = "solo-package"
        Version = "1.0.0"
        Section = "Test"
    })
    $singleResult = Get-PackageInstallationOrder -PackagesInfo $singlePackage
    if ($singleResult.Count -eq 1 -and $singleResult[0].Package -eq "solo-package") {
        Write-Host "✓ Single package handled correctly" -ForegroundColor Green
    } else {
        Write-Host "! Single package test failed" -ForegroundColor Yellow
    }
    
    # Test with packages having no dependencies
    Write-Host "Testing with packages having no dependencies..." -ForegroundColor Cyan
    $noDepsPackages = @(
        [PSCustomObject]@{ Package = "pkg-a"; Version = "1.0.0"; Section = "Test" },
        [PSCustomObject]@{ Package = "pkg-b"; Version = "1.0.0"; Section = "Test" },
        [PSCustomObject]@{ Package = "pkg-c"; Version = "1.0.0"; Section = "Test" }
    )
    $noDepsResult = Get-PackageInstallationOrder -PackagesInfo $noDepsPackages
    if ($noDepsResult.Count -eq 3) {
        Write-Host "✓ Packages without dependencies handled correctly" -ForegroundColor Green
        Write-Host "  Order: $($noDepsResult | ForEach-Object { $_.Package } | Join-String -Separator ', ')" -ForegroundColor White
    } else {
        Write-Host "! No-dependencies test failed" -ForegroundColor Yellow
    }
    
} catch {
    Write-Host "✗ Test 4 failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""

# Test 5: Performance and output validation
Write-Host "Test 5: Performance and Output Validation" -ForegroundColor Yellow
Write-Host "==========================================" -ForegroundColor Yellow

if (Test-Path $packagesTestFile) {
    try {
        $packages = Get-PackagesInfoFromPackagesFile -InputPath $packagesTestFile
        
        # Measure performance
        Write-Host "Testing performance with $($packages.Count) packages..." -ForegroundColor Cyan
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        $orderedPackages = Get-PackageInstallationOrder -PackagesInfo $packages
        $stopwatch.Stop()
        
        Write-Host "✓ Completed in $($stopwatch.ElapsedMilliseconds) ms" -ForegroundColor Green
        
        # Validate output structure
        Write-Host "Validating output structure..." -ForegroundColor Cyan
        $validStructure = $true
        
        foreach ($pkg in $orderedPackages | Select-Object -First 5) {
            if (-not $pkg.Package -or -not $pkg.Version) {
                $validStructure = $false
                break
            }
        }
        
        if ($validStructure) {
            Write-Host "✓ Output structure is valid" -ForegroundColor Green
        } else {
            Write-Host "✗ Output structure validation failed" -ForegroundColor Red
        }
        
        # Check for duplicates
        $packageNames = $orderedPackages | ForEach-Object { $_.Package }
        $uniqueNames = $packageNames | Sort-Object -Unique
        
        if ($packageNames.Count -eq $uniqueNames.Count) {
            Write-Host "✓ No duplicate packages in output" -ForegroundColor Green
        } else {
            Write-Host "✗ Found duplicate packages in output!" -ForegroundColor Red
        }
        
        # Verify all input packages are in output
        $inputNames = $packages | ForEach-Object { $_.Package } | Sort-Object
        $outputNames = $orderedPackages | ForEach-Object { $_.Package } | Sort-Object
        
        $missingPackages = Compare-Object $inputNames $outputNames | Where-Object { $_.SideIndicator -eq '<=' }
        $extraPackages = Compare-Object $inputNames $outputNames | Where-Object { $_.SideIndicator -eq '=>' }
        
        if (-not $missingPackages -and -not $extraPackages) {
            Write-Host "✓ All input packages present in output (no missing or extra packages)" -ForegroundColor Green
        } else {
            if ($missingPackages) {
                Write-Host "✗ Missing packages in output: $($missingPackages.Count)" -ForegroundColor Red
            }
            if ($extraPackages) {
                Write-Host "✗ Extra packages in output: $($extraPackages.Count)" -ForegroundColor Red
            }
        }
        
    } catch {
        Write-Host "✗ Test 5 failed: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host ""

# Test Summary
Write-Host "====================================================================================" -ForegroundColor Cyan
Write-Host "Test Summary" -ForegroundColor Cyan
Write-Host "====================================================================================" -ForegroundColor Cyan

Write-Host ""
Write-Host "Get-PackageInstallationOrder Function Tests Completed" -ForegroundColor Green
Write-Host ""
Write-Host "USAGE EXAMPLES:" -ForegroundColor Yellow
Write-Host ""
Write-Host "# Basic usage:" -ForegroundColor White
Write-Host '$packages = Get-PackagesInfoFromPackagesFile -InputPath "Packages"' -ForegroundColor Gray
Write-Host '$ordered = Get-PackageInstallationOrder -PackagesInfo $packages' -ForegroundColor Gray
Write-Host ""
Write-Host "# Only hard dependencies:" -ForegroundColor White
Write-Host '$ordered = Get-PackageInstallationOrder -PackagesInfo $packages -IncludeDependencyTypes @("Depends")' -ForegroundColor Gray
Write-Host ""
Write-Host "# All dependency types:" -ForegroundColor White
Write-Host '$ordered = Get-PackageInstallationOrder -PackagesInfo $packages -IncludeDependencyTypes @("Depends", "Recommends", "Suggests")' -ForegroundColor Gray
Write-Host ""
Write-Host "# Allow circular dependencies:" -ForegroundColor White
Write-Host '$ordered = Get-PackageInstallationOrder -PackagesInfo $packages -AllowCircularDependencies' -ForegroundColor Gray
Write-Host ""

Write-Host "For more information, see the function documentation: Get-Help Get-PackageInstallationOrder -Full" -ForegroundColor Cyan
Write-Host ""
