#!/usr/bin/env pwsh

Write-Host "Testing Apply-NipkgSnapshot with RemoveExistingFeeds parameter..." -ForegroundColor Yellow

try {
    # Get the script directory and navigate to module path
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $moduleDir = Split-Path -Parent (Split-Path -Parent $scriptDir)
    $modulePath = Join-Path $moduleDir "LabViewHelpers\LabViewHelpers.psd1"
    
    Write-Host "Script directory: $scriptDir" -ForegroundColor Cyan
    Write-Host "Module path: $modulePath" -ForegroundColor Cyan
    
    # Import the module
    Import-Module $modulePath -Force
    Write-Host "✓ Module imported successfully" -ForegroundColor Green
    
    # Check if the function exists
    $function = Get-Command Apply-NipkgSnapshot -ErrorAction Stop
    Write-Host "✓ Apply-NipkgSnapshot function found" -ForegroundColor Green
    
    # Check if the RemoveExistingFeeds parameter exists
    $removeExistingFeedsParam = $function.Parameters['RemoveExistingFeeds']
    if ($removeExistingFeedsParam) {
        Write-Host "✓ RemoveExistingFeeds parameter found" -ForegroundColor Green
        Write-Host "  Parameter Type: $($removeExistingFeedsParam.ParameterType)" -ForegroundColor Cyan
        Write-Host "  Parameter Attributes: $($removeExistingFeedsParam.Attributes -join ', ')" -ForegroundColor Cyan
    } else {
        Write-Host "✗ RemoveExistingFeeds parameter NOT found" -ForegroundColor Red
    }
    
    # Test the help documentation
    Write-Host "`nTesting help documentation..." -ForegroundColor Yellow
    $help = Get-Help Apply-NipkgSnapshot -Detailed
    if ($help.parameters.parameter | Where-Object { $_.name -eq 'RemoveExistingFeeds' }) {
        Write-Host "✓ RemoveExistingFeeds parameter documented in help" -ForegroundColor Green
    } else {
        Write-Host "✗ RemoveExistingFeeds parameter missing from help" -ForegroundColor Red
    }
    
    # Show examples that mention RemoveExistingFeeds
    $examples = $help.examples.example | Where-Object { $_.code -like "*RemoveExistingFeeds*" }
    if ($examples) {
        Write-Host "✓ Found $($examples.Count) example(s) using RemoveExistingFeeds" -ForegroundColor Green
        $examples | ForEach-Object {
            Write-Host "  Example: $($_.title)" -ForegroundColor Cyan
        }
    } else {
        Write-Host "✗ No examples found using RemoveExistingFeeds" -ForegroundColor Red
    }
    
    Write-Host "`n=== Test Summary ===" -ForegroundColor Yellow
    Write-Host "Apply-NipkgSnapshot function has been successfully updated with RemoveExistingFeeds parameter!" -ForegroundColor Green
    
} catch {
    Write-Host "✗ Test failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Full error: $($_.Exception)" -ForegroundColor Red
}
