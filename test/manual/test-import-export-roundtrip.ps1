# Test Import/Export Round Trip with packages-nipkg section
param(
    [string]$ModulePath = "..\..\LabViewHelpers\NipkgHelper.psm1"
)

# Import the module
Import-Module $ModulePath -Force

Write-Host "Testing Import/Export Round Trip with packages-nipkg section..." -ForegroundColor Cyan

# Create a test snapshot with all sections
$testSnapshot = @{
    feeds = @(
        @{ name = "ni-internal"; uri = "https://niinternal.com/feed" },
        @{ name = "ni-public"; uri = "https://nipublic.com/feed" }
    )
    packages = @(
        @{ name = "labview"; version = "24.5.0" },
        @{ name = "vision"; version = "23.0.0" }
    )
    "packages-nipkg" = @(
        @{ name = "ni-package-manager"; version = "23.8.0" },
        @{ name = "ni-package-manager-core"; version = "23.8.0" },
        @{ name = "ni-package-manager-ui"; version = "23.8.0" }
    )
}

Write-Host "Original snapshot:" -ForegroundColor Yellow
Write-Host "  Feeds: $($testSnapshot.feeds.Count)"
Write-Host "  Packages: $($testSnapshot.packages.Count)"
Write-Host "  NIPKG Packages: $($testSnapshot.'packages-nipkg'.Count)"

# Test export
$exportPath = "test-temp\roundtrip-test.json"
try {
    Write-Host "`nExporting snapshot..." -ForegroundColor Green
    $exportResult = Export-NipkgSnapshotToJson -Snapshot $testSnapshot -OutputPath $exportPath
    
    Write-Host "Export result:"
    Write-Host "  Path: $($exportResult.SnapshotPath)"
    Write-Host "  Feeds: $($exportResult.FeedsCount)"
    Write-Host "  Packages: $($exportResult.PackagesCount)"
    Write-Host "  File size: $($exportResult.FileSizeBytes) bytes"
    
    # Read the raw JSON to verify structure
    Write-Host "`nRaw JSON content:" -ForegroundColor Yellow
    $rawJson = Get-Content -Path $exportPath -Raw
    Write-Host $rawJson
    
    # Test import
    Write-Host "`nImporting snapshot..." -ForegroundColor Green
    $importedSnapshot = Import-NipkgSnapshotFromJson -InputPath $exportPath
    
    Write-Host "Imported snapshot:" -ForegroundColor Yellow
    Write-Host "  Feeds: $($importedSnapshot.feeds.Count)"
    Write-Host "  Packages: $($importedSnapshot.packages.Count)"
    Write-Host "  NIPKG Packages: $($importedSnapshot.'packages-nipkg'.Count)"
    
    # Verify data integrity
    Write-Host "`nVerifying data integrity..." -ForegroundColor Cyan
    
    $success = $true
    
    # Check feeds
    if ($importedSnapshot.feeds.Count -ne $testSnapshot.feeds.Count) {
        Write-Host "FAIL: Feeds count mismatch" -ForegroundColor Red
        $success = $false
    } else {
        for ($i = 0; $i -lt $testSnapshot.feeds.Count; $i++) {
            if ($importedSnapshot.feeds[$i].name -ne $testSnapshot.feeds[$i].name -or
                $importedSnapshot.feeds[$i].uri -ne $testSnapshot.feeds[$i].uri) {
                Write-Host "FAIL: Feed $i data mismatch" -ForegroundColor Red
                $success = $false
            }
        }
    }
    
    # Check packages
    if ($importedSnapshot.packages.Count -ne $testSnapshot.packages.Count) {
        Write-Host "FAIL: Packages count mismatch" -ForegroundColor Red
        $success = $false
    } else {
        for ($i = 0; $i -lt $testSnapshot.packages.Count; $i++) {
            if ($importedSnapshot.packages[$i].name -ne $testSnapshot.packages[$i].name -or
                $importedSnapshot.packages[$i].version -ne $testSnapshot.packages[$i].version) {
                Write-Host "FAIL: Package $i data mismatch" -ForegroundColor Red
                $success = $false
            }
        }
    }
    
    # Check packages-nipkg
    if ($importedSnapshot."packages-nipkg".Count -ne $testSnapshot."packages-nipkg".Count) {
        Write-Host "FAIL: NIPKG packages count mismatch" -ForegroundColor Red
        $success = $false
    } else {
        for ($i = 0; $i -lt $testSnapshot."packages-nipkg".Count; $i++) {
            if ($importedSnapshot."packages-nipkg"[$i].name -ne $testSnapshot."packages-nipkg"[$i].name -or
                $importedSnapshot."packages-nipkg"[$i].version -ne $testSnapshot."packages-nipkg"[$i].version) {
                Write-Host "FAIL: NIPKG package $i data mismatch" -ForegroundColor Red
                $success = $false
            }
        }
    }
    
    if ($success) {
        Write-Host "SUCCESS: Round trip test passed!" -ForegroundColor Green
    } else {
        Write-Host "FAIL: Round trip test failed!" -ForegroundColor Red
    }
    
} catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
}

# Test with real snapshot data
Write-Host "`n" + "="*60 -ForegroundColor Cyan
Write-Host "Testing with real snapshot data..." -ForegroundColor Cyan

$realSnapshotPath = "test-temp\system-snapshot.json"
if (Test-Path $realSnapshotPath) {
    try {
        Write-Host "Importing real snapshot..." -ForegroundColor Green
        $realSnapshot = Import-NipkgSnapshotFromJson -InputPath $realSnapshotPath
        
        Write-Host "Real snapshot contains:" -ForegroundColor Yellow
        Write-Host "  Feeds: $($realSnapshot.feeds.Count)"
        Write-Host "  Packages: $($realSnapshot.packages.Count)"
        Write-Host "  NIPKG Packages: $($realSnapshot.'packages-nipkg'.Count)"
        
        # Re-export it
        $reExportPath = "test-temp\real-snapshot-reexport.json"
        Write-Host "`nRe-exporting real snapshot..." -ForegroundColor Green
        $reExportResult = Export-NipkgSnapshotToJson -Snapshot $realSnapshot -OutputPath $reExportPath
        
        Write-Host "Re-export completed:" -ForegroundColor Yellow
        Write-Host "  Path: $($reExportResult.SnapshotPath)"
        Write-Host "  File size: $($reExportResult.FileSizeBytes) bytes"
        
        # Import again to verify
        Write-Host "`nRe-importing to verify..." -ForegroundColor Green
        $reImportedSnapshot = Import-NipkgSnapshotFromJson -InputPath $reExportPath
        
        Write-Host "Re-imported snapshot contains:" -ForegroundColor Yellow
        Write-Host "  Feeds: $($reImportedSnapshot.feeds.Count)"
        Write-Host "  Packages: $($reImportedSnapshot.packages.Count)"
        Write-Host "  NIPKG Packages: $($reImportedSnapshot.'packages-nipkg'.Count)"
        
        if ($reImportedSnapshot.feeds.Count -eq $realSnapshot.feeds.Count -and
            $reImportedSnapshot.packages.Count -eq $realSnapshot.packages.Count -and
            $reImportedSnapshot."packages-nipkg".Count -eq $realSnapshot."packages-nipkg".Count) {
            Write-Host "SUCCESS: Real snapshot round trip passed!" -ForegroundColor Green
        } else {
            Write-Host "FAIL: Real snapshot round trip failed!" -ForegroundColor Red
        }
        
    } catch {
        Write-Host "ERROR with real snapshot: $($_.Exception.Message)" -ForegroundColor Red
    }
} else {
    Write-Host "Real snapshot file not found: $realSnapshotPath" -ForegroundColor Yellow
}

Write-Host "`nRound trip testing completed." -ForegroundColor Cyan
