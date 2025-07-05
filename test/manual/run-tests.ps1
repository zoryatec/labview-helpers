#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Test runner for LabViewHelpers module

.DESCRIPTION
    Runs all the manual tests for the LabViewHelpers module from the test/manual directory.

.PARAMETER TestName
    Specific test to run. Options: 'comprehensive', 'removeexistingfeeds', 'removesnapshotfeeds', 'installfunctions', 'demo', 'all'

.EXAMPLE
    .\run-tests.ps1
    Runs all tests from the test/manual directory

.EXAMPLE
    .\run-tests.ps1 -TestName comprehensive
    Runs only the comprehensive test

.EXAMPLE
    .\run-tests.ps1 -TestName removesnapshotfeeds
    Runs the RemoveSnapshotFeeds test

.EXAMPLE
    .\run-tests.ps1 -TestName demo
    Runs the demo scripts

.NOTES
    This script should be run from the test/manual directory:
    cd test/manual
    .\run-tests.ps1
#>

param(
    [Parameter()]
    [ValidateSet('comprehensive', 'removeexistingfeeds', 'removesnapshotfeeds', 'installfunctions', 'demo', 'all')]
    [string]$TestName = 'all'
)

# We're running from test/manual directory
$testDir = $PSScriptRoot
$currentLocation = Get-Location

Write-Host "=== LabViewHelpers Test Runner ===" -ForegroundColor Cyan
Write-Host "Current location: $currentLocation" -ForegroundColor Gray
Write-Host "Script location: $testDir" -ForegroundColor Gray

# Verify we have the test files
$requiredFiles = @(
    'test-comprehensive.ps1',
    'test-removeexistingfeeds.ps1',
    'test-removesnapshotfeeds.ps1',
    'test-install-functions-feedmanagement.ps1',
    'demo-removeexistingfeeds.ps1',
    'demo-removesnapshotfeeds.ps1'
)

$missingFiles = @()
foreach ($file in $requiredFiles) {
    $filePath = Join-Path $testDir $file
    if (-not (Test-Path $filePath)) {
        $missingFiles += $file
    }
}

if ($missingFiles.Count -gt 0) {
    Write-Host "✗ Missing test files: $($missingFiles -join ', ')" -ForegroundColor Red
    Write-Host "Please ensure you're running this from the test/manual directory." -ForegroundColor Yellow
    exit 1
}

try {
    switch ($TestName) {
        'comprehensive' {
            Write-Host "`nRunning comprehensive tests..." -ForegroundColor Yellow
            & (Join-Path $testDir "test-comprehensive.ps1")
        }
        'removeexistingfeeds' {
            Write-Host "`nRunning RemoveExistingFeeds tests..." -ForegroundColor Yellow
            & (Join-Path $testDir "test-removeexistingfeeds.ps1")
        }
        'removesnapshotfeeds' {
            Write-Host "`nRunning RemoveSnapshotFeeds tests..." -ForegroundColor Yellow
            & (Join-Path $testDir "test-removesnapshotfeeds.ps1")
        }
        'installfunctions' {
            Write-Host "`nRunning Install Functions Feed Management tests..." -ForegroundColor Yellow
            & (Join-Path $testDir "test-install-functions-feedmanagement.ps1")
        }
        'demo' {
            Write-Host "`nRunning demo scripts..." -ForegroundColor Yellow
            & (Join-Path $testDir "demo-removeexistingfeeds.ps1")
            Write-Host "`n--- RemoveSnapshotFeeds Demo ---" -ForegroundColor Magenta
            & (Join-Path $testDir "demo-removesnapshotfeeds.ps1")
        }
        'all' {
            Write-Host "`nRunning all tests..." -ForegroundColor Yellow
            
            Write-Host "`n--- Comprehensive Test ---" -ForegroundColor Magenta
            & (Join-Path $testDir "test-comprehensive.ps1")
            
            Write-Host "`n--- RemoveExistingFeeds Test ---" -ForegroundColor Magenta
            & (Join-Path $testDir "test-removeexistingfeeds.ps1")
            
            Write-Host "`n--- RemoveSnapshotFeeds Test ---" -ForegroundColor Magenta
            & (Join-Path $testDir "test-removesnapshotfeeds.ps1")
            
            Write-Host "`n--- Install Functions Feed Management Test ---" -ForegroundColor Magenta
            & (Join-Path $testDir "test-install-functions-feedmanagement.ps1")
            
            Write-Host "`n--- RemoveExistingFeeds Demo ---" -ForegroundColor Magenta
            & (Join-Path $testDir "demo-removeexistingfeeds.ps1")
            
            Write-Host "`n--- RemoveSnapshotFeeds Demo ---" -ForegroundColor Magenta
            & (Join-Path $testDir "demo-removesnapshotfeeds.ps1")
        }
    }
    
    Write-Host "`n=== Test Run Complete ===" -ForegroundColor Cyan
} catch {
    Write-Host "✗ Test run failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
