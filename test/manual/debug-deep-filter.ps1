#!/usr/bin/env pwsh
param()

Write-Host "=== Deep Debugging NIPKG Filter Issue ===" -ForegroundColor Cyan

try {
    # Import module
    Import-Module "$PSScriptRoot\..\..\LabViewHelpers\LabViewHelpers.psd1" -Force -Verbose:$false
    
    # Create snapshot from installer
    Write-Host "Creating snapshot from installer..." -ForegroundColor Yellow
    $installerPath = "$PSScriptRoot\..\manual-docker\installers\ni-labview-2025-community-x86_25.1.3_offline"
    $snapshot = New-SnapshotFromInstallerDirectory -InstallerDirectory $installerPath
    
    Write-Host "Testing different filter approaches:" -ForegroundColor Yellow
    
    # Approach 1: Direct exact match 
    Write-Host "1. Direct exact match:" -ForegroundColor Green
    $direct = $snapshot.packages | Where-Object { $_["name"] -eq "ni-package-manager" }
    Write-Host "  Count: $($direct.Count)" -ForegroundColor Gray
    if ($direct.Count -gt 0) {
        foreach ($item in $direct) {
            Write-Host "  Item type: $($item.GetType().FullName)" -ForegroundColor Gray
            Write-Host "  Item value: '$item'" -ForegroundColor Gray
            if ($item -is [System.Collections.Specialized.OrderedDictionary]) {
                Write-Host "    Name: '$($item["name"])'" -ForegroundColor Gray
                Write-Host "    Version: '$($item["version"])'" -ForegroundColor Gray
            }
        }
    }
    
    # Approach 2: Two-step filter 
    Write-Host "2. Two-step filter:" -ForegroundColor Green
    $allNipkg = $snapshot.packages | Where-Object { $_["name"] -like "*ni-package-manager*" }
    $twoStep = $allNipkg | Where-Object { $_["name"] -eq "ni-package-manager" }
    Write-Host "  All NIPKG count: $($allNipkg.Count)" -ForegroundColor Gray
    Write-Host "  Two-step count: $($twoStep.Count)" -ForegroundColor Gray
    if ($twoStep.Count -gt 0) {
        foreach ($item in $twoStep) {
            Write-Host "  Item type: $($item.GetType().FullName)" -ForegroundColor Gray
            if ($item -is [System.Collections.Specialized.OrderedDictionary]) {
                Write-Host "    Name: '$($item["name"])'" -ForegroundColor Gray
                Write-Host "    Version: '$($item["version"])'" -ForegroundColor Gray
            }
        }
    }
    
    # Approach 3: Manual loop
    Write-Host "3. Manual loop:" -ForegroundColor Green
    $manual = @()
    foreach ($pkg in $snapshot.packages) {
        if ($pkg["name"] -eq "ni-package-manager") {
            $manual += $pkg
        }
    }
    Write-Host "  Manual count: $($manual.Count)" -ForegroundColor Gray
    if ($manual.Count -gt 0) {
        foreach ($item in $manual) {
            Write-Host "  Item type: $($item.GetType().FullName)" -ForegroundColor Gray
            if ($item -is [System.Collections.Specialized.OrderedDictionary]) {
                Write-Host "    Name: '$($item["name"])'" -ForegroundColor Gray
                Write-Host "    Version: '$($item["version"])'" -ForegroundColor Gray
            }
        }
    }
    
} catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack trace:" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
}

Write-Host "=== Debug Complete ===" -ForegroundColor Cyan
