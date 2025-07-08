#!/usr/bin/env pwsh
param()

Write-Host "=== Debugging NIPKG Package Filtering ===" -ForegroundColor Cyan

try {
    # Import module
    Import-Module "$PSScriptRoot\..\..\LabViewHelpers\LabViewHelpers.psd1" -Force -Verbose:$false
    
    # Create snapshot from installer
    Write-Host "Creating snapshot from installer..." -ForegroundColor Yellow
    $installerPath = "$PSScriptRoot\..\manual-docker\installers\ni-labview-2025-community-x86_25.1.3_offline"
    $snapshot = New-NipkgSnapshotFromInstaller -InstallerDirectory $installerPath
    
    Write-Host "Testing filter conditions:" -ForegroundColor Yellow
    
    # Test the exact filter condition
    Write-Host "1. Testing exact match filter:" -ForegroundColor Green
    $exactMatch = $snapshot.packages | Where-Object { $_["name"] -eq "ni-package-manager" }
    Write-Host "  Count: $($exactMatch.Count)" -ForegroundColor Gray
    if ($exactMatch.Count -gt 0) {
        $pkg = $exactMatch[0]
        Write-Host "  Type: $($pkg.GetType().Name)" -ForegroundColor Gray
        Write-Host "  Name: '$($pkg["name"])'" -ForegroundColor Gray
        Write-Host "  Version: '$($pkg["version"])'" -ForegroundColor Gray
    }
    
    # Test individual packages
    Write-Host "2. Testing individual packages:" -ForegroundColor Green
    $count = 0
    foreach ($pkg in $snapshot.packages) {
        $count++
        if ($pkg["name"] -eq "ni-package-manager") {
            Write-Host "  Package $count matches!" -ForegroundColor Gray
            Write-Host "    Type: $($pkg.GetType().Name)" -ForegroundColor Gray
            Write-Host "    Name: '$($pkg["name"])'" -ForegroundColor Gray
            Write-Host "    Version: '$($pkg["version"])'" -ForegroundColor Gray
            break
        }
        if ($count -gt 10) {
            Write-Host "  ... (checked first 10 packages)" -ForegroundColor Gray
            break
        }
    }
    
    # Test all NIPKG packages
    Write-Host "3. All NIPKG packages:" -ForegroundColor Green
    $nipkgPackages = $snapshot.packages | Where-Object { $_["name"] -like "*ni-package-manager*" }
    foreach ($pkg in $nipkgPackages) {
        Write-Host "  $($pkg["name"]) = $($pkg["version"])" -ForegroundColor Gray
    }
    
} catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack trace:" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
}

Write-Host "=== Debug Complete ===" -ForegroundColor Cyan
