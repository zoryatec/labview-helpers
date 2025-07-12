#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Simple test for the compliance validation functionality.
#>

# Import the module
Import-Module -Name $PSScriptRoot/../../../LabViewHelpers/LabViewHelpers.psd1 -Force

Write-Host "Testing Test-SnapshotCompliance function..." -ForegroundColor Cyan

# Test with minimal snapshot (should show compliance)
$testSnapshot = @{
    feeds = @()
    packages = @()
}

$tempPath = [System.IO.Path]::GetTempFileName() + ".json"
$testSnapshot | ConvertTo-Json | Set-Content -Path $tempPath

try {
    Write-Host "Testing minimal snapshot compliance..." -ForegroundColor Yellow
    $result = Test-SnapshotCompliance -SnapshotPath $tempPath -ValidateFeeds $false -ValidatePackages $false
    
    Write-Host "✓ Function executed successfully" -ForegroundColor Green
    Write-Host "Compliance Result: $($result.OverallCompliant)" -ForegroundColor Green
    Write-Host "Summary: $($result.Summary)" -ForegroundColor Green
}
catch {
    Write-Host "✗ Function failed: $($_.Exception.Message)" -ForegroundColor Red
}
finally {
    if (Test-Path $tempPath) {
        Remove-Item $tempPath -Force
    }
}
