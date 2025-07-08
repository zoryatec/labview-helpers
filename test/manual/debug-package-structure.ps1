#!/usr/bin/env pwsh
param()

Write-Host "=== Debugging Package Structure ===" -ForegroundColor Cyan

try {
    # Import module
    Import-Module "$PSScriptRoot\..\..\LabViewHelpers\LabViewHelpers.psd1" -Force -Verbose:$false
    
    # Create snapshot from installer
    Write-Host "Creating snapshot from installer..." -ForegroundColor Yellow
    $installerPath = "$PSScriptRoot\..\manual-docker\installers\ni-labview-2025-community-x86_25.1.3_offline"
    $snapshot = New-NipkgSnapshotFromInstaller -InstallerDirectory $installerPath
    
    Write-Host "Checking first few packages structure:" -ForegroundColor Yellow
    $firstPackages = $snapshot.packages | Select-Object -First 3
    foreach ($pkg in $firstPackages) {
        Write-Host "Package type: $($pkg.GetType().Name)" -ForegroundColor Gray
        Write-Host "Package properties:" -ForegroundColor Gray
        $pkg | Get-Member -MemberType Properties | ForEach-Object {
            $value = $pkg.($_.Name)
            Write-Host "  $($_.Name) = '$value'" -ForegroundColor Gray
        }
        Write-Host "---" -ForegroundColor Gray
    }
    
    Write-Host "Specifically checking NIPKG packages:" -ForegroundColor Yellow
    $nipkgPkgs = $snapshot.packages | Where-Object { $_.name -eq "ni-package-manager" }
    if ($nipkgPkgs.Count -gt 0) {
        $nipkgPkg = $nipkgPkgs[0]
        Write-Host "ni-package-manager package structure:" -ForegroundColor Green
        Write-Host "  Type: $($nipkgPkg.GetType().Name)" -ForegroundColor Gray
        $nipkgPkg | Get-Member -MemberType Properties | ForEach-Object {
            $value = $nipkgPkg.($_.Name)
            Write-Host "  $($_.Name) = '$value'" -ForegroundColor Gray
        }
    } else {
        Write-Host "No ni-package-manager package found!" -ForegroundColor Red
    }
    
} catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack trace:" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
}

Write-Host "=== Debug Complete ===" -ForegroundColor Cyan
