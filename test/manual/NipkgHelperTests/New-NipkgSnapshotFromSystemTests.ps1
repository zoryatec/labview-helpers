Import-Module -Name $PSScriptRoot/../../../LabViewHelpers/LabViewHelpers.psd1 -Force

Write-Host "====================================================================================" -ForegroundColor Cyan
Write-Host "Testing New-SnapshotFromSystem Function" -ForegroundColor Cyan
Write-Host "====================================================================================" -ForegroundColor Cyan
Write-Host ""

$nipkgCmdContainingDir = "C:\\Program Files\\National Instruments\\NI Package Manager"
$nipkgCmdPath = "$nipkgCmdContainingDir\\nipkg.exe"

$tempDirectory = "$PSScriptRoot/../test-temp"
$systemSnapshot = "$tempDirectory/system-snapshot.json"

# Test NIPKG availability first
Write-Host "Testing NIPKG availability..." -ForegroundColor Yellow
$nipkgAvailable = Test-NipkgAvailability -NipkgCmdPath $nipkgCmdPath
if ($nipkgAvailable) {
    Write-Host "✓ NIPKG is available and working" -ForegroundColor Green
} else {
    Write-Host "✗ NIPKG is not available or not working" -ForegroundColor Red
    Write-Host "Please check that NI Package Manager is installed and the path is correct:" -ForegroundColor Yellow
    Write-Host "  Path: $nipkgCmdPath" -ForegroundColor White
    exit 1
}

Write-Host ""
Write-Host "Creating system snapshot..." -ForegroundColor Yellow

try {
    $snapshot = New-SnapshotFromSystem `
                    -NipkgCmdPath $nipkgCmdPath `
                    -PackageType "installed" `
                    -IncludeFeeds $true

    Write-Host "✓ Successfully created system snapshot" -ForegroundColor Green
    Write-Host "  Feeds: $($snapshot.feeds.Count)" -ForegroundColor White
    Write-Host "  Packages: $($snapshot.packages.Count)" -ForegroundColor White

    Write-Host ""
    Write-Host "Exporting snapshot to JSON..." -ForegroundColor Yellow
    
    $exportResult = Export-NipkgSnapshotToJson -Snapshot $snapshot -OutputPath $systemSnapshot -Verbose
    
    Write-Host "✓ Successfully exported system snapshot" -ForegroundColor Green
    Write-Host "  File: $systemSnapshot" -ForegroundColor White
    Write-Host "  Size: $($exportResult.FileSizeBytes) bytes" -ForegroundColor White
    
    # Display sample content
    if ($snapshot.feeds.Count -gt 0) {
        Write-Host ""
        Write-Host "Sample feeds:" -ForegroundColor Cyan
        $snapshot.feeds | Select-Object -First 3 | ForEach-Object {
            Write-Host "  - $($_.name): $($_.uri)" -ForegroundColor White
        }
    }
    
    if ($snapshot.packages.Count -gt 0) {
        Write-Host ""
        Write-Host "Sample packages:" -ForegroundColor Cyan
        $snapshot.packages | Select-Object -First 5 | ForEach-Object {
            Write-Host "  - $($_.name): $($_.version)" -ForegroundColor White
        }
    }
    
} catch {
    Write-Host "✗ Error creating system snapshot: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Host "Error details:" -ForegroundColor Yellow
    Write-Host $_.Exception.ToString() -ForegroundColor Gray
    exit 1
}

Write-Host ""
Write-Host "System snapshot test completed successfully!" -ForegroundColor Green

