#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Example of using Apply-NipkgSnapshot with compliance validation.

.DESCRIPTION
    Demonstrates the new validation features in Apply-NipkgSnapshot.
#>

# Import the module
Import-Module -Name $PSScriptRoot/../../../LabViewHelpers/LabViewHelpers.psd1 -Force

Write-Host "====================================================================================" -ForegroundColor Cyan
Write-Host "Apply-NipkgSnapshot with Compliance Validation Examples" -ForegroundColor Cyan
Write-Host "====================================================================================" -ForegroundColor Cyan
Write-Host ""

$nipkgCmdPath = "C:\Program Files\National Instruments\NI Package Manager\nipkg.exe"

# Test NIPKG availability first
Write-Host "Testing NIPKG availability..." -ForegroundColor Yellow
$nipkgAvailable = Test-NipkgAvailability -NipkgCmdPath $nipkgCmdPath
if (-not $nipkgAvailable) {
    Write-Host "✗ NIPKG is not available. Creating examples without actual execution." -ForegroundColor Yellow
    $testMode = $true
} else {
    Write-Host "✓ NIPKG is available" -ForegroundColor Green
    $testMode = $false
}
Write-Host ""

# Create a minimal snapshot for testing
$tempDir = [System.IO.Path]::GetTempPath()
$testSnapshot = @{
    feeds = @()
    packages = @()
}
$snapshotPath = Join-Path $tempDir "test-snapshot.json"
$testSnapshot | ConvertTo-Json | Set-Content -Path $snapshotPath

Write-Host "Example 1: Basic snapshot application with compliance validation" -ForegroundColor Yellow
Write-Host "================================================================" -ForegroundColor Yellow
Write-Host ""
Write-Host "Command:" -ForegroundColor Cyan
Write-Host "Apply-NipkgSnapshot -SnapshotPath 'snapshot.json' -ValidateCompliance" -ForegroundColor Gray
Write-Host ""

if (-not $testMode) {
    try {
        $result = Apply-NipkgSnapshot -SnapshotPath $snapshotPath -ValidateCompliance -WhatIf
        Write-Host "✓ WhatIf execution successful" -ForegroundColor Green
        Write-Host "Compliance validated: $($result.ComplianceValidated)" -ForegroundColor Green
        Write-Host "System compliant: $($result.SystemCompliant)" -ForegroundColor Green
        Write-Host "Compliance summary: $($result.ComplianceSummary)" -ForegroundColor Green
    }
    catch {
        Write-Host "✗ Example failed: $($_.Exception.Message)" -ForegroundColor Red
    }
} else {
    Write-Host "⚠ NIPKG not available - showing expected output:" -ForegroundColor Yellow
    Write-Host "✓ System is compliant with snapshot" -ForegroundColor Green
    Write-Host "ComplianceValidated: True" -ForegroundColor Green
    Write-Host "SystemCompliant: True" -ForegroundColor Green
}
Write-Host ""

Write-Host "Example 2: Strict validation for CI/CD (fail on non-compliance)" -ForegroundColor Yellow
Write-Host "================================================================" -ForegroundColor Yellow
Write-Host ""
Write-Host "Command:" -ForegroundColor Cyan
Write-Host "Apply-NipkgSnapshot -SnapshotPath 'snapshot.json' -ValidateCompliance -FailOnNonCompliance" -ForegroundColor Gray
Write-Host ""
Write-Host "This would throw an exception if the system is not compliant after application." -ForegroundColor Gray
Write-Host ""

Write-Host "Example 3: Development environment (allow extra packages)" -ForegroundColor Yellow
Write-Host "========================================================" -ForegroundColor Yellow
Write-Host ""
Write-Host "Command:" -ForegroundColor Cyan
Write-Host "Apply-NipkgSnapshot -SnapshotPath 'snapshot.json' -ValidateCompliance -AllowExtraPackages `$true" -ForegroundColor Gray
Write-Host ""
Write-Host "This allows developers to have additional packages installed beyond the snapshot." -ForegroundColor Gray
Write-Host ""

Write-Host "Example 4: Feeds-only validation" -ForegroundColor Yellow
Write-Host "===============================" -ForegroundColor Yellow
Write-Host ""
Write-Host "Command:" -ForegroundColor Cyan
Write-Host "Apply-NipkgSnapshot -SnapshotPath 'snapshot.json' -SkipPackages -ValidateCompliance" -ForegroundColor Gray
Write-Host ""
Write-Host "This only sets up feeds and validates feed configuration compliance." -ForegroundColor Gray
Write-Host ""

# Cleanup
if (Test-Path $snapshotPath) {
    Remove-Item $snapshotPath -Force
}

Write-Host "====================================================================================" -ForegroundColor Cyan
Write-Host "Key Benefits of Compliance Validation:" -ForegroundColor Cyan
Write-Host "====================================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "✓ Verify snapshot application was successful" -ForegroundColor Green
Write-Host "✓ Detect configuration drift in environments" -ForegroundColor Green
Write-Host "✓ Enforce strict compliance in CI/CD pipelines" -ForegroundColor Green
Write-Host "✓ Flexible validation options for different scenarios" -ForegroundColor Green
Write-Host "✓ Detailed reporting of compliance issues" -ForegroundColor Green
Write-Host ""
Write-Host "Return Object Properties:" -ForegroundColor White
Write-Host "- ComplianceValidated: Whether validation was performed" -ForegroundColor Gray
Write-Host "- SystemCompliant: Whether system matches snapshot" -ForegroundColor Gray
Write-Host "- ComplianceSummary: Summary of compliance status" -ForegroundColor Gray
Write-Host "- ComplianceIssues: Number of issues found" -ForegroundColor Gray
Write-Host "- ComplianceReport: Detailed compliance report object" -ForegroundColor Gray
