# Test script to diagnose offline installer issues
param(
    [string]$InstallerDirectory = "c:\Projects\_Repos\labview-helpers\test\manual-docker\installers\ni-labview-2025-community-x86_25.1.3_offline"
)

Import-Module "c:\Projects\_Repos\labview-helpers\LabViewHelpers\LabViewHelpers.psd1" -Force

Write-Host "=== Testing Offline Installer Diagnosis ===" -ForegroundColor Cyan

try {
    # Step 1: Create snapshot from installer
    Write-Host "`n1. Creating snapshot from installer..." -ForegroundColor Yellow
    $snapshot = New-NipkgSnapshotFromInstaller -InstallerDirectory $InstallerDirectory -Verbose
    Write-Host "✓ Snapshot created successfully with $($snapshot.packages.Count) packages" -ForegroundColor Green

    # Step 2: Export snapshot to temporary file
    Write-Host "`n2. Exporting snapshot to file..." -ForegroundColor Yellow
    $snapshotFile = "$env:TEMP\test-labview-snapshot.json"
    Export-NipkgSnapshotToJson -Snapshot $snapshot -OutputPath $snapshotFile -Verbose
    Write-Host "✓ Snapshot exported to: $snapshotFile" -ForegroundColor Green

    # Step 3: Check current NIPKG status
    Write-Host "`n3. Checking current NIPKG configuration..." -ForegroundColor Yellow
    $nipkgCmd = "nipkg"
    
    Write-Host "Current feeds:" -ForegroundColor Cyan
    & $nipkgCmd feed-list
    
    Write-Host "`nCurrent packages (sample):" -ForegroundColor Cyan
    & $nipkgCmd list | Select-Object -First 10

    # Step 4: Try to add the installer feed manually first
    Write-Host "`n4. Testing feed addition..." -ForegroundColor Yellow
    $feedPath = Join-Path $InstallerDirectory "feeds\ni-labview-2025-community-x86"
    if (Test-Path $feedPath) {
        Write-Host "Adding installer feed: $feedPath" -ForegroundColor Cyan
        & $nipkgCmd feed-add "file:///$($feedPath.Replace('\', '/'))" --name="test-labview-feed" --system 2>&1
        
        Write-Host "Updating package list..." -ForegroundColor Cyan
        & $nipkgCmd update 2>&1
        
        Write-Host "Checking if packages are now available:" -ForegroundColor Cyan
        $availablePackages = & $nipkgCmd search ni-labview-2025 2>&1
        if ($availablePackages) {
            Write-Host "✓ Found LabVIEW packages in search:" -ForegroundColor Green
            $availablePackages | Select-Object -First 5 | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
        } else {
            Write-Host "✗ No LabVIEW packages found in search" -ForegroundColor Red
        }
    }

    # Step 5: Test installing a single simple package
    Write-Host "`n5. Testing single package installation..." -ForegroundColor Yellow
    Write-Host "Attempting to install a simple package (ni-euladepot)..." -ForegroundColor Cyan
    $result = & $nipkgCmd install ni-euladepot -y 2>&1
    Write-Host "Installation result:" -ForegroundColor Cyan
    $result

} catch {
    Write-Host "✗ Error occurred: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack trace:" -ForegroundColor Gray
    Write-Host $_.ScriptStackTrace -ForegroundColor Gray
} finally {
    # Cleanup
    Write-Host "`n6. Cleanup..." -ForegroundColor Yellow
    if ($snapshotFile -and (Test-Path $snapshotFile)) {
        Remove-Item $snapshotFile -Force -ErrorAction SilentlyContinue
        Write-Host "✓ Cleaned up temporary snapshot file" -ForegroundColor Green
    }
    
    # Remove the test feed
    try {
        & $nipkgCmd feed-remove test-labview-feed --system 2>&1 | Out-Null
        Write-Host "✓ Cleaned up test feed" -ForegroundColor Green
    } catch {
        Write-Host "Note: Could not remove test feed (may not have been added)" -ForegroundColor Gray
    }
}

Write-Host "`n=== Diagnosis Complete ===" -ForegroundColor Cyan
