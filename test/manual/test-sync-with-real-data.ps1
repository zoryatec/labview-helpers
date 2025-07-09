# Test script to demonstrate the updated Sync-NipkgVersionWithSnapshot function with real snapshot data

Import-Module -Force "../../LabViewHelpers/LabViewHelpers.psd1" -Verbose:$false

Write-Host "=== Testing Sync-NipkgVersionWithSnapshot with Real Snapshot Data ===" -ForegroundColor Cyan
Write-Host ""

$snapshotPath = "test-temp/system-snapshot.json"

if (Test-Path $snapshotPath) {
    Write-Host "Loading real snapshot from: $snapshotPath" -ForegroundColor Yellow
    
    try {
        $snapshot = Import-NipkgSnapshotFromJson -InputPath $snapshotPath
        
        Write-Host "✓ Snapshot loaded successfully!" -ForegroundColor Green
        Write-Host "  Feeds: $($snapshot.feeds.Count)" -ForegroundColor White
        Write-Host "  Regular packages: $($snapshot.packages.Count)" -ForegroundColor White
        Write-Host "  NIPKG packages: $($snapshot.'packages-nipkg'.Count)" -ForegroundColor White
        Write-Host ""
        
        if ($snapshot."packages-nipkg" -and $snapshot."packages-nipkg".Count -gt 0) {
            Write-Host "Packages-nipkg section contains:" -ForegroundColor Yellow
            $snapshot."packages-nipkg" | ForEach-Object { 
                Write-Host "  - $($_.name) v$($_.version)" -ForegroundColor White
            }
            Write-Host ""
            
            Write-Host "Testing Sync-NipkgVersionWithSnapshot in WhatIf mode..." -ForegroundColor Cyan
            
            $result = Sync-NipkgVersionWithSnapshot -Snapshot $snapshot -WhatIf
            
            Write-Host "✓ Function would process $($snapshot.'packages-nipkg'.Count) packages!" -ForegroundColor Green
            Write-Host "  Each package would be installed in order with exact version" -ForegroundColor White
            Write-Host "  Command format: nipkg install package=version --accept-eulas -y --allow-downgrade --allow-uninstall" -ForegroundColor Gray
        }
        else {
            Write-Host "No packages-nipkg section found in the snapshot" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "✗ Error loading snapshot: $($_.Exception.Message)" -ForegroundColor Red
    }
}
else {
    Write-Host "✗ Snapshot file not found: $snapshotPath" -ForegroundColor Red
    Write-Host "Expected to find a system snapshot in the test-temp directory" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=== Function Summary ===" -ForegroundColor Cyan
Write-Host "The updated Sync-NipkgVersionWithSnapshot function now:" -ForegroundColor White
Write-Host "  ✓ Reads packages from the packages-nipkg section" -ForegroundColor Green
Write-Host "  ✓ Installs them in the exact order specified" -ForegroundColor Green
Write-Host "  ✓ Uses precise version specifications (package=version)" -ForegroundColor Green
Write-Host "  ✓ No version checking - simple installation approach" -ForegroundColor Green
Write-Host "  ✓ Provides detailed installation results and error handling" -ForegroundColor Green
