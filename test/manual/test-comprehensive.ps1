#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Comprehensive test script for LabViewHelpers NipkgHelper module

.DESCRIPTION
    Tests all the functions in the NipkgHelper module, including the newly added and renamed functions:
    - New-NipkgSnapshotFromSystem
    - Get-PackagesInfoFromNipkgCmd (renamed from Get-PackagesInfoFromFile)
    - Apply-NipkgSnapshot with RemoveExistingFeeds parameter

.NOTES
    Run this from the test/manual directory.
#>

Write-Host "=== LabViewHelpers NipkgHelper Module Comprehensive Test ===" -ForegroundColor Cyan

# Setup paths
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$moduleDir = Split-Path -Parent (Split-Path -Parent $scriptDir)
$modulePath = Join-Path $moduleDir "LabViewHelpers\LabViewHelpers.psd1"

Write-Host "`nTest Environment:" -ForegroundColor Yellow
Write-Host "Script directory: $scriptDir" -ForegroundColor Gray
Write-Host "Module directory: $moduleDir" -ForegroundColor Gray
Write-Host "Module path: $modulePath" -ForegroundColor Gray

$testResults = @{
    ModuleImport = $false
    FunctionExports = $false
    NewFunctions = $false
    RenamedFunctions = $false
    NewParameters = $false
    HelpDocumentation = $false
}

try {
    # Test 1: Module Import
    Write-Host "`n=== Test 1: Module Import ===" -ForegroundColor Yellow
    if (Test-Path $modulePath) {
        Import-Module $modulePath -Force
        Write-Host "✓ Module imported successfully" -ForegroundColor Green
        $testResults.ModuleImport = $true
    } else {
        Write-Host "✗ Module not found at: $modulePath" -ForegroundColor Red
        throw "Module file not found"
    }

    # Test 2: Function Exports
    Write-Host "`n=== Test 2: Function Exports ===" -ForegroundColor Yellow
    $module = Get-Module LabViewHelpers
    $expectedFunctions = @(
        'Add-FeedDirectories',
        'Test-NipkgAvailability',
        'Get-NipkgCommandOutput',
        'ConvertFrom-NipkgOutput',
        'ConvertFrom-NipkgPackagesFile',
        'Get-PackagesInfoFromNipkgCmd',
        'Get-PackagesInfoFromPackagesFile',
        'Get-DriverPackages',
        'Get-ProgrammingEnvironmentsPackages',
        'Get-UtilitiesPackages',
        'Get-ApplicationSoftwarePackages',
        'Get-FeedsInfoFromNipkgCmd',
        'Remove-Feeds',
        'Install-NipkgManager',
        'New-NipkgSnapshot',
        'New-NipkgSnapshotFromInstaller',
        'New-NipkgSnapshotFromSystem',
        'Export-NipkgSnapshotToJson',
        'Import-NipkgSnapshotFromJson',
        'Apply-NipkgSnapshot'
    )

    $missingFunctions = @()
    foreach ($func in $expectedFunctions) {
        if (Get-Command $func -ErrorAction SilentlyContinue) {
            Write-Host "✓ $func" -ForegroundColor Green
        } else {
            Write-Host "✗ $func" -ForegroundColor Red
            $missingFunctions += $func
        }
    }

    if ($missingFunctions.Count -eq 0) {
        Write-Host "✓ All expected functions exported successfully" -ForegroundColor Green
        $testResults.FunctionExports = $true
    } else {
        Write-Host "✗ Missing functions: $($missingFunctions -join ', ')" -ForegroundColor Red
    }

    # Test 3: New Functions
    Write-Host "`n=== Test 3: New Functions ===" -ForegroundColor Yellow
    $newFunctions = @('New-NipkgSnapshotFromSystem')
    
    foreach ($func in $newFunctions) {
        $command = Get-Command $func -ErrorAction SilentlyContinue
        if ($command) {
            Write-Host "✓ New function $func exists" -ForegroundColor Green
            
            # Check parameters
            $params = $command.Parameters.Keys
            Write-Host "  Parameters: $($params -join ', ')" -ForegroundColor Gray
        } else {
            Write-Host "✗ New function $func missing" -ForegroundColor Red
        }
    }
    $testResults.NewFunctions = $true

    # Test 4: Renamed Functions
    Write-Host "`n=== Test 4: Renamed Functions ===" -ForegroundColor Yellow
    
    # Check that Get-PackagesInfoFromNipkgCmd exists (renamed from Get-PackagesInfoFromFile)
    if (Get-Command Get-PackagesInfoFromNipkgCmd -ErrorAction SilentlyContinue) {
        Write-Host "✓ Get-PackagesInfoFromNipkgCmd exists (renamed from Get-PackagesInfoFromFile)" -ForegroundColor Green
        $testResults.RenamedFunctions = $true
    } else {
        Write-Host "✗ Get-PackagesInfoFromNipkgCmd missing" -ForegroundColor Red
    }
    
    # Check that old function name doesn't exist
    if (-not (Get-Command Get-PackagesInfoFromFile -ErrorAction SilentlyContinue)) {
        Write-Host "✓ Old function name Get-PackagesInfoFromFile properly removed" -ForegroundColor Green
    } else {
        Write-Host "⚠ Old function name Get-PackagesInfoFromFile still exists" -ForegroundColor Yellow
    }

    # Test 5: New Parameters
    Write-Host "`n=== Test 5: New Parameters ===" -ForegroundColor Yellow
    
    # Test RemoveExistingFeeds parameter in Apply-NipkgSnapshot
    $applyFunction = Get-Command Apply-NipkgSnapshot
    if ($applyFunction.Parameters.ContainsKey('RemoveExistingFeeds')) {
        $param = $applyFunction.Parameters['RemoveExistingFeeds']
        Write-Host "✓ RemoveExistingFeeds parameter exists in Apply-NipkgSnapshot" -ForegroundColor Green
        Write-Host "  Type: $($param.ParameterType)" -ForegroundColor Gray
        Write-Host "  Switch: $($param.ParameterType -eq [switch])" -ForegroundColor Gray
        $testResults.NewParameters = $true
    } else {
        Write-Host "✗ RemoveExistingFeeds parameter missing from Apply-NipkgSnapshot" -ForegroundColor Red
    }

    # Test 6: Help Documentation
    Write-Host "`n=== Test 6: Help Documentation ===" -ForegroundColor Yellow
    
    # Test help for new function
    $help = Get-Help New-NipkgSnapshotFromSystem -ErrorAction SilentlyContinue
    if ($help -and $help.synopsis) {
        Write-Host "✓ New-NipkgSnapshotFromSystem has help documentation" -ForegroundColor Green
    } else {
        Write-Host "✗ New-NipkgSnapshotFromSystem missing help documentation" -ForegroundColor Red
    }
    
    # Test help for renamed function
    $help = Get-Help Get-PackagesInfoFromNipkgCmd -ErrorAction SilentlyContinue
    if ($help -and $help.synopsis) {
        Write-Host "✓ Get-PackagesInfoFromNipkgCmd has help documentation" -ForegroundColor Green
    } else {
        Write-Host "✗ Get-PackagesInfoFromNipkgCmd missing help documentation" -ForegroundColor Red
    }
    
    # Test help for new parameter
    $help = Get-Help Apply-NipkgSnapshot -Parameter RemoveExistingFeeds -ErrorAction SilentlyContinue
    if ($help) {
        Write-Host "✓ RemoveExistingFeeds parameter documented in Apply-NipkgSnapshot help" -ForegroundColor Green
        $testResults.HelpDocumentation = $true
    } else {
        Write-Host "✗ RemoveExistingFeeds parameter missing from Apply-NipkgSnapshot help" -ForegroundColor Red
    }

    # Test Summary
    Write-Host "`n=== Test Summary ===" -ForegroundColor Yellow
    $passedTests = ($testResults.Values | Where-Object { $_ -eq $true }).Count
    $totalTests = $testResults.Count
    
    Write-Host "Passed: $passedTests/$totalTests tests" -ForegroundColor $(if ($passedTests -eq $totalTests) { 'Green' } else { 'Yellow' })
    
    foreach ($test in $testResults.GetEnumerator()) {
        $status = if ($test.Value) { '✓' } else { '✗' }
        $color = if ($test.Value) { 'Green' } else { 'Red' }
        Write-Host "$status $($test.Key)" -ForegroundColor $color
    }
    
    if ($passedTests -eq $totalTests) {
        Write-Host "`n🎉 All tests passed! The LabViewHelpers module is ready for use." -ForegroundColor Green
    } else {
        Write-Host "`n⚠ Some tests failed. Please review the issues above." -ForegroundColor Yellow
    }

} catch {
    Write-Host "✗ Test suite failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Full error: $($_.Exception)" -ForegroundColor Red
}
