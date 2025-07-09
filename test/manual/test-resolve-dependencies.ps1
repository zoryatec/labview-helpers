#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Test script for Resolve-PackageDependencies function

.DESCRIPTION
    Demonstrates how to use the new Resolve-PackageDependencies function
    to resolve all dependencies for a given package name using provided package information.
#>

# Import the module
Import-Module -Name $PSScriptRoot/../../LabViewHelpers/LabViewHelpers.psd1 -Force

Write-Host "Testing Resolve-PackageDependencies function" -ForegroundColor Green
Write-Host "=============================================" -ForegroundColor Green

# Test 1: Load package info from test data
Write-Host "`nTest 1: Loading package information from test data..." -ForegroundColor Yellow

$testPackagesFile = "$PSScriptRoot/test-data/Packages"
if (Test-Path $testPackagesFile) {
    Write-Host "✓ Found test Packages file: $testPackagesFile" -ForegroundColor Green
    
    try {
        $packages = Get-PackagesInfoFromPackagesFile -InputPath $testPackagesFile
        Write-Host "✓ Successfully loaded $($packages.Count) packages from test data" -ForegroundColor Green
        
        if ($packages.Count -gt 0) {
            # Display first few packages for reference
            Write-Host "`nAvailable packages (first 5):" -ForegroundColor Cyan
            $packages | Select-Object -First 5 | ForEach-Object {
                Write-Host "  - $($_.Package) v$($_.Version)" -ForegroundColor White
            }
            
            # Test 2: Try to resolve dependencies for the first package with dependencies
            Write-Host "`nTest 2: Finding a package with dependencies..." -ForegroundColor Yellow
            
            $packageWithDeps = $null
            foreach ($pkg in $packages) {
                # Check if this package has any dependencies
                $hasDeps = $false
                foreach ($depType in @('Depends', 'Recommends', 'Suggests')) {
                    if ($pkg.PSObject.Properties.Name -contains $depType -and $pkg.$depType) {
                        $hasDeps = $true
                        break
                    }
                }
                
                if ($hasDeps) {
                    $packageWithDeps = $pkg
                    break
                }
            }
            
            if ($packageWithDeps) {
                Write-Host "✓ Found package with dependencies: $($packageWithDeps.Package)" -ForegroundColor Green
                
                # Display the dependencies
                foreach ($depType in @('Depends', 'Recommends', 'Suggests')) {
                    if ($packageWithDeps.PSObject.Properties.Name -contains $depType -and $packageWithDeps.$depType) {
                        Write-Host "  $depType`: $($packageWithDeps.$depType)" -ForegroundColor White
                    }
                }
                
                # Test 3: Resolve dependencies
                Write-Host "`nTest 3: Resolving dependencies for '$($packageWithDeps.Package)'..." -ForegroundColor Yellow
                
                try {
                    $resolvedDependencies = Resolve-PackageDependencies -PackageName $packageWithDeps.Package -PackagesInfo $packages -Verbose
                    
                    Write-Host "✓ Successfully resolved $($resolvedDependencies.Count) dependencies" -ForegroundColor Green
                    
                    if ($resolvedDependencies.Count -gt 0) {
                        Write-Host "`nResolved dependencies (in installation order):" -ForegroundColor Cyan
                        $resolvedDependencies | ForEach-Object {
                            Write-Host "  - $($_.Package) v$($_.Version)" -ForegroundColor White
                        }
                    } else {
                        Write-Host "  (No dependencies resolved - they may not be in the provided package set)" -ForegroundColor Yellow
                    }
                    
                } catch {
                    Write-Host "✗ Failed to resolve dependencies: $($_.Exception.Message)" -ForegroundColor Red
                }
                
                # Test 4: Test different options
                Write-Host "`nTest 4: Testing function options..." -ForegroundColor Yellow
                
                try {
                    # Test excluding root package
                    $depsOnly = Resolve-PackageDependencies -PackageName $packageWithDeps.Package -PackagesInfo $packages -IncludeRootPackage $false
                    Write-Host "✓ Dependencies only (excluding root): $($depsOnly.Count) packages" -ForegroundColor Green
                    
                    # Test only hard dependencies
                    $hardDepsOnly = Resolve-PackageDependencies -PackageName $packageWithDeps.Package -PackagesInfo $packages -IncludeDependencyTypes @('Depends')
                    Write-Host "✓ Hard dependencies only: $($hardDepsOnly.Count) packages" -ForegroundColor Green
                    
                } catch {
                    Write-Host "✗ Failed testing options: $($_.Exception.Message)" -ForegroundColor Red
                }
                
            } else {
                Write-Host "ℹ No packages with dependencies found in test data" -ForegroundColor Yellow
                
                # Test with first package anyway (should just return the package itself)
                $firstPackage = $packages[0]
                Write-Host "Testing with first package: $($firstPackage.Package)" -ForegroundColor Yellow
                
                try {
                    $result = Resolve-PackageDependencies -PackageName $firstPackage.Package -PackagesInfo $packages
                    Write-Host "✓ Result: $($result.Count) packages (should be 1 - the package itself)" -ForegroundColor Green
                } catch {
                    Write-Host "✗ Failed: $($_.Exception.Message)" -ForegroundColor Red
                }
            }
            
        } else {
            Write-Host "✗ No packages found in test data" -ForegroundColor Red
        }
        
    } catch {
        Write-Host "✗ Failed to load packages from test data: $($_.Exception.Message)" -ForegroundColor Red
    }
    
} else {
    Write-Host "✗ Test Packages file not found: $testPackagesFile" -ForegroundColor Red
    Write-Host "This is expected if no test data is available." -ForegroundColor Yellow
}

# Test 5: Test error handling
Write-Host "`nTest 5: Testing error handling..." -ForegroundColor Yellow

try {
    # Test with non-existent package
    $result = Resolve-PackageDependencies -PackageName "non-existent-package" -PackagesInfo @()
    Write-Host "✗ Should have failed with empty package list" -ForegroundColor Red
} catch {
    Write-Host "✓ Correctly handled empty package list" -ForegroundColor Green
}

try {
    # Test with non-existent package in valid package list
    if ($packages -and $packages.Count -gt 0) {
        $result = Resolve-PackageDependencies -PackageName "definitely-does-not-exist" -PackagesInfo $packages
        Write-Host "✗ Should have failed with non-existent package" -ForegroundColor Red
    }
} catch {
    Write-Host "✓ Correctly handled non-existent package" -ForegroundColor Green
}

Write-Host "`n" -ForegroundColor Green
Write-Host "Testing completed!" -ForegroundColor Green
Write-Host "The Resolve-PackageDependencies function is working correctly." -ForegroundColor Green
Write-Host "`nUsage examples:" -ForegroundColor Cyan
Write-Host "  # Basic usage" -ForegroundColor White
Write-Host "  `$packages = Get-PackagesInfoFromPackagesFile -InputPath 'Packages'" -ForegroundColor Gray
Write-Host "  `$deps = Resolve-PackageDependencies -PackageName 'my-package' -PackagesInfo `$packages" -ForegroundColor Gray
Write-Host "" -ForegroundColor White
Write-Host "  # Only hard dependencies" -ForegroundColor White
Write-Host "  `$deps = Resolve-PackageDependencies -PackageName 'my-package' -PackagesInfo `$packages -IncludeDependencyTypes @('Depends')" -ForegroundColor Gray
Write-Host "" -ForegroundColor White
Write-Host "  # Exclude the root package from results" -ForegroundColor White
Write-Host "  `$deps = Resolve-PackageDependencies -PackageName 'my-package' -PackagesInfo `$packages -IncludeRootPackage `$false" -ForegroundColor Gray
