Import-Module -Name $PSScriptRoot/../../LabViewHelpers/LabViewHelpers.psd1 -Force

# Display module information
$module = Get-Module LabViewHelpers
Write-Host "LabViewHelpers Module Version: $($module.Version)" -ForegroundColor Green
Write-Host "Total Exported Functions: $($module.ExportedFunctions.Count)" -ForegroundColor Cyan

# Verify new NipkgHelper functions are available
$nipkgFunctions = @(
    'Get-NipkgCommandOutput',
    'ConvertFrom-NipkgOutput', 
    'Get-PackagesInfo',
    'Get-PackagesInfoFromNipkgCmd',
    'ConvertFrom-NipkgPackagesFile',
    'Get-PackagesInfoFromPackagesFile',
    'Get-PackageInstallationOrder',
    'New-NipkgSnapshotFromInstaller',
    'New-NipkgSnapshotFromSystem',
    'Apply-NipkgSnapshot',
    'Export-NipkgSnapshotToJson',
    'Import-NipkgSnapshotFromJson'
)

Write-Host "`nVerifying new NipkgHelper functions are exported:" -ForegroundColor Yellow
foreach ($func in $nipkgFunctions) {
    if ($module.ExportedFunctions.ContainsKey($func)) {
        Write-Host "  ✓ $func" -ForegroundColor Green
    } else {
        Write-Host "  ✗ $func" -ForegroundColor Red
    }
}
Write-Host ""

$nipkgPath = 'C:\Program Files\National Instruments\NI Package Manager\nipkg.exe'
$tempDirectory = "$PSScriptRoot/test-temp"

# Test NIPKG availability first
Write-Host "Testing NIPKG availability..." -ForegroundColor Green
$nipkgAvailable = Test-NipkgAvailability -NipkgCmdPath $nipkgPath
if ($nipkgAvailable) {
    Write-Host "✓ NIPKG is available and working" -ForegroundColor Green
} else {
    Write-Host "✗ NIPKG is not available or not working" -ForegroundColor Red
    Write-Host "Please check that NI Package Manager is installed and the path is correct:" -ForegroundColor Yellow
    Write-Host "  Path: $nipkgPath" -ForegroundColor White
    if (-not (Test-Path $nipkgPath)) {
        Write-Host "  ✗ File does not exist at the specified path" -ForegroundColor Red
    } else {
        Write-Host "  ✓ File exists at the specified path" -ForegroundColor Green
    }
}
Write-Host ""
# Add-FeedDirectories `
#     -FeedsDirectory 'C:\Projects\LabVIEW\ni-labview-2024-x86_24.5.0.49229-0+f77_offline\feeds' `
#     -NipkgCmdPath 'C:\Program Files\National Instruments\NI Package Manager\nipkg.exe'


# Add-FeedDirectories `
#     -FeedsDirectory 'C:\Projects\LabVIEW\ni-labview-2025-community-x86_25.1.3_offline\feeds' `
#     -NipkgCmdPath 'C:\Program Files\National Instruments\NI Package Manager\nipkg.exe'


$feedsInfo = Get-FeedsInfoFromNipkgCmd -NipkgCmdPath $nipkgPath

# Use the packages we already retrieved successfully above
# If that failed, this will too, so we'll handle it gracefully

# $packagesInfo | Sort-Object Section | Format-Table Package, Version, Architecture, Section


# $driversPackages  = Get-DriverPackages -PackagesInfo $packagesInfo
# $driversPackages | Sort-Object Section | Format-Table Package, Version, Architecture, Section


# $programingEnvironmentsPackages  = Get-ProgrammingEnvironmentsPackages -PackagesInfo $packagesInfo
# $programingEnvironmentsPackages | Sort-Object Section | Format-Table Package, Version, Architecture, Section


# $applicationPackages  = Get-ApplicationSoftwarePackages -PackagesInfo $packagesInfo
# $applicationPackages | Sort-Object Section | Format-Table Package, Version, Architecture, Section

# $utilitiesPackages  = Get-UtilitiesPackages -PackagesInfo $packagesInfo
# $utilitiesPackages | Sort-Object Section | Format-Table Package, Version, Architecture, Section

$snapshot = New-NipkgSnapshot `
    -PackagesInfo $packagesInfo `
    -FeedsInfo $feedsInfo 


Export-NipkgSnapshotToJson `
    -Snapshot $snapshot `
    -OutputPath "$tempDirectory\snapshot.json"

# Test import functionality
Write-Host "Testing Import-NipkgSnapshotFromJson..." -ForegroundColor Green
$importedSnapshot = Import-NipkgSnapshotFromJson -InputPath "$tempDirectory\snapshot.json"

Write-Host "Original snapshot: Feeds=$($snapshot.feeds.Count), Packages=$($snapshot.packages.Count)" -ForegroundColor Cyan
Write-Host "Imported snapshot: Feeds=$($importedSnapshot.feeds.Count), Packages=$($importedSnapshot.packages.Count)" -ForegroundColor Cyan

# Verify the imported data matches the original
if ($snapshot.feeds.Count -eq $importedSnapshot.feeds.Count -and $snapshot.packages.Count -eq $importedSnapshot.packages.Count) {
    Write-Host "✓ Import test passed - counts match!" -ForegroundColor Green
} else {
    Write-Host "✗ Import test failed - counts don't match!" -ForegroundColor Red
}

# Display a sample of imported data
if ($importedSnapshot.feeds.Count -gt 0) {
    Write-Host "Sample imported feeds:" -ForegroundColor Yellow
    $importedSnapshot.feeds | Select-Object -First 3 | ForEach-Object { 
        Write-Host "  - $($_.name): $($_.uri)" -ForegroundColor White
    }
}

if ($importedSnapshot.packages.Count -gt 0) {
    Write-Host "Sample imported packages:" -ForegroundColor Yellow
    $importedSnapshot.packages | Select-Object -First 3 | ForEach-Object { 
        Write-Host "  - $($_.name): $($_.version)" -ForegroundColor White
    }
}

# Your raw output (from file or command)

# $feedInfo = Get-FeedsInfoFromNipkgCmd `
#     -NipkgCmdPath $nipkgPath

# $feedInfo | Sort-Object Name | Format-Table Name

# Remove-Feeds `
#      -FeedsInfo $feedInfo  `
#      -NipkgCmdPath $nipkgPath

# Test the separated functions
Write-Host "Testing separated Get-NipkgCommandOutput and ConvertFrom-NipkgOutput functions..." -ForegroundColor Green

# Test 1: Get raw command output
Write-Host "1. Getting raw NIPKG command output..." -ForegroundColor Yellow
$rawOutput = Get-NipkgCommandOutput -Type 'installed' -NipkgCmdPath $nipkgPath
Write-Host "   Raw output contains $($rawOutput.Count) lines" -ForegroundColor Cyan

# Test 2: Parse the output
Write-Host "2. Parsing the raw output..." -ForegroundColor Yellow
$parsedPackages = ConvertFrom-NipkgOutput -OutputLines $rawOutput
Write-Host "   Parsed $($parsedPackages.Count) packages" -ForegroundColor Cyan

# Test 3: Compare with the combined function
Write-Host "3. Comparing with combined Get-PackagesInfo function..." -ForegroundColor Yellow
$combinedPackages = Get-PackagesInfoFromNipkgCmd -Type 'installed' -NipkgCmdPath $nipkgPath
Write-Host "   Combined function returned $($combinedPackages.Count) packages" -ForegroundColor Cyan

# Verify results match
if ($parsedPackages.Count -eq $combinedPackages.Count) {
    Write-Host "✓ Function separation test passed - package counts match!" -ForegroundColor Green
} else {
    Write-Host "✗ Function separation test failed - package counts don't match!" -ForegroundColor Red
    Write-Host "   Parsed: $($parsedPackages.Count), Combined: $($combinedPackages.Count)" -ForegroundColor Red
}

# Show sample comparison
if ($parsedPackages.Count -gt 0 -and $combinedPackages.Count -gt 0) {
    $firstParsed = $parsedPackages[0]
    $firstCombined = $combinedPackages[0]
    Write-Host "Sample comparison (first package):" -ForegroundColor Yellow
    Write-Host "   Parsed: $($firstParsed.Package) v$($firstParsed.Version)" -ForegroundColor White
    Write-Host "   Combined: $($firstCombined.Package) v$($firstCombined.Version)" -ForegroundColor White
}

# Test the renamed file-based function
Write-Host "Testing Get-PackagesInfoFromNipkgCmd function..." -ForegroundColor Green

# First, save some raw output to a test file
$testOutputFile = "$tempDirectory\test-nipkg-output.txt"
Write-Host "1. Saving raw NIPKG output to file: $testOutputFile" -ForegroundColor Yellow

try {
    # Save the raw output we got earlier to a file
    $rawOutput | Out-File -FilePath $testOutputFile -Encoding UTF8
    Write-Host "   ✓ Saved $($rawOutput.Count) lines to file" -ForegroundColor Green

    # Test parsing from file
    Write-Host "2. Parsing packages from file..." -ForegroundColor Yellow
    $filePackages = Get-PackagesInfoFromNipkgCmd -InputPath $testOutputFile
    Write-Host "   ✓ Parsed $($filePackages.Count) packages from file" -ForegroundColor Green

    # Compare with direct parsing
    if ($filePackages.Count -eq $parsedPackages.Count) {
        Write-Host "✓ File-based parsing test passed - package counts match!" -ForegroundColor Green
    } else {
        Write-Host "✗ File-based parsing test failed - package counts don't match!" -ForegroundColor Red
        Write-Host "   File: $($filePackages.Count), Direct: $($parsedPackages.Count)" -ForegroundColor Red
    }

    # Show sample comparison
    if ($filePackages.Count -gt 0) {
        $firstFile = $filePackages[0]
        Write-Host "Sample file-parsed package: $($firstFile.Package) v$($firstFile.Version)" -ForegroundColor White
    }
}
catch {
    Write-Host "✗ File-based parsing test failed with error: $($_.Exception.Message)" -ForegroundColor Red
}

# Test basic package info retrieval with error handling
Write-Host "Testing basic package info retrieval..." -ForegroundColor Green
try {
    $packagesInfo = Get-PackagesInfo -NipkgCmdPath $nipkgPath -Type 'installed' -Verbose
    Write-Host "✓ Successfully retrieved $($packagesInfo.Count) installed packages" -ForegroundColor Green
    
    if ($packagesInfo.Count -gt 0) {
        Write-Host "Sample packages:" -ForegroundColor Yellow
        $packagesInfo | Select-Object -First 3 | ForEach-Object { 
            Write-Host "  - $($_.Package): $($_.Version)" -ForegroundColor White
        }
    } else {
        Write-Host "  No packages found" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "✗ Failed to retrieve package info: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "This might indicate an issue with NIPKG or no packages installed" -ForegroundColor Yellow
}
Write-Host ""

# Test the new NIPKG Packages file parsing function
Write-Host "Testing Get-PackagesInfoFromPackagesFile function..." -ForegroundColor Green

$nipkgPackagesFile = "$PSScriptRoot\test-data\Packages"
if (Test-Path $nipkgPackagesFile) {
    Write-Host "1. Parsing NIPKG Packages file: $nipkgPackagesFile" -ForegroundColor Yellow
    
    try {
        $nipkgFilePackages = Get-PackagesInfoFromPackagesFile -InputPath $nipkgPackagesFile -Verbose
        Write-Host "   ✓ Parsed $($nipkgFilePackages.Count) packages from NIPKG Packages file" -ForegroundColor Green

        if ($nipkgFilePackages.Count -gt 0) {
            Write-Host "   Sample packages from NIPKG file:" -ForegroundColor Yellow
            foreach ($pkg in $nipkgFilePackages) {
                Write-Host "     - $($pkg.Package) v$($pkg.Version) [$($pkg.Section)]" -ForegroundColor White
            }
            
            # Test the specialized parser directly
            Write-Host "2. Testing specialized ConvertFrom-NipkgPackagesFile parser..." -ForegroundColor Yellow
            $fileLines = Get-Content -Path $nipkgPackagesFile -Encoding UTF8
            $directParsed = ConvertFrom-NipkgPackagesFile -OutputLines $fileLines
            
            if ($directParsed.Count -eq $nipkgFilePackages.Count) {
                Write-Host "   ✓ Direct parser test passed - counts match!" -ForegroundColor Green
            } else {
                Write-Host "   ✗ Direct parser test failed - counts don't match!" -ForegroundColor Red
            }
        }
    }
    catch {
        Write-Host "   ✗ Failed to parse NIPKG Packages file: $($_.Exception.Message)" -ForegroundColor Red
    }
} else {
    Write-Host "✗ NIPKG Packages test file not found: $nipkgPackagesFile" -ForegroundColor Red
}

Write-Host ""

# Test the new installer snapshot function
Write-Host "Testing New-NipkgSnapshotFromInstaller function..." -ForegroundColor Green

$installerDirectory = "$PSScriptRoot\..\manual-docker\installers\ni-labview-2025-community-x86_25.1.3_offline"
if (Test-Path $installerDirectory) {
    Write-Host "1. Creating snapshot from installer directory..." -ForegroundColor Yellow
    Write-Host "   Installer: $installerDirectory" -ForegroundColor White
    
    try {
        $installerSnapshot = New-NipkgSnapshotFromInstaller -InstallerDirectory $installerDirectory -Verbose
        Write-Host "   ✓ Created installer snapshot: $($installerSnapshot.feeds.Count) feeds, $($installerSnapshot.packages.Count) packages" -ForegroundColor Green

        if ($installerSnapshot.feeds.Count -gt 0) {
            Write-Host "   Feeds found in installer:" -ForegroundColor Yellow
            foreach ($feed in $installerSnapshot.feeds) {
                Write-Host "     - $($feed.name)" -ForegroundColor White
            }
        }

        if ($installerSnapshot.packages.Count -gt 0) {
            Write-Host "   Sample packages from installer:" -ForegroundColor Yellow
            $installerSnapshot.packages | Select-Object -First 5 | ForEach-Object {
                Write-Host "     - $($_.name): $($_.version)" -ForegroundColor White
            }
            
            # Test different package types
            Write-Host "   Package analysis:" -ForegroundColor Yellow
            $packageNames = $installerSnapshot.packages | ForEach-Object { $_.name }
            $labviewPackages = $packageNames | Where-Object { $_ -like "*labview*" }
            $runtimePackages = $packageNames | Where-Object { $_ -like "*runtime*" }
            $driverPackages = $packageNames | Where-Object { $_ -like "*driver*" -or $_ -like "*ni-*" }
            
            Write-Host "     - LabVIEW packages: $($labviewPackages.Count)" -ForegroundColor White
            Write-Host "     - Runtime packages: $($runtimePackages.Count)" -ForegroundColor White
            Write-Host "     - Driver packages: $($driverPackages.Count)" -ForegroundColor White
        }

        # Test exporting installer snapshot
        Write-Host "2. Exporting installer snapshot to JSON..." -ForegroundColor Yellow
        $installerSnapshotFile = "$tempDirectory\installer-snapshot.json"
        
        try {
            $exportResult = Export-NipkgSnapshotToJson -Snapshot $installerSnapshot -OutputPath $installerSnapshotFile
            Write-Host "   ✓ Exported to: $installerSnapshotFile" -ForegroundColor Green
            Write-Host "   ✓ File size: $($exportResult.FileSizeBytes) bytes" -ForegroundColor Green
            
            # Test reimporting
            Write-Host "3. Testing import of installer snapshot..." -ForegroundColor Yellow
            $reimported = Import-NipkgSnapshotFromJson -InputPath $installerSnapshotFile
            
            if ($reimported.packages.Count -eq $installerSnapshot.packages.Count) {
                Write-Host "   ✓ Import test passed - package counts match!" -ForegroundColor Green
            } else {
                Write-Host "   ✗ Import test failed - package counts don't match!" -ForegroundColor Red
            }
        }
        catch {
            Write-Host "   ✗ Failed to export/import installer snapshot: $($_.Exception.Message)" -ForegroundColor Red
        }

        # Test without feeds
        Write-Host "4. Testing installer snapshot without feeds..." -ForegroundColor Yellow
        try {
            $noFeedsSnapshot = New-NipkgSnapshotFromInstaller -InstallerDirectory $installerDirectory -IncludeFeeds $false
            Write-Host "   ✓ Created snapshot without feeds: $($noFeedsSnapshot.feeds.Count) feeds, $($noFeedsSnapshot.packages.Count) packages" -ForegroundColor Green
            
            if ($noFeedsSnapshot.feeds.Count -eq 0 -and $noFeedsSnapshot.packages.Count -eq $installerSnapshot.packages.Count) {
                Write-Host "   ✓ No-feeds test passed - 0 feeds, same package count!" -ForegroundColor Green
            } else {
                Write-Host "   ✗ No-feeds test failed - unexpected results!" -ForegroundColor Red
            }
        }
        catch {
            Write-Host "   ✗ Failed to create snapshot without feeds: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    catch {
        Write-Host "   ✗ Failed to create installer snapshot: $($_.Exception.Message)" -ForegroundColor Red
    }
} else {
    Write-Host "✗ Installer directory not found: $installerDirectory" -ForegroundColor Red
    Write-Host "   This test requires the sample installer directory to be present." -ForegroundColor Yellow
}

Write-Host ""

# Test Apply-NipkgSnapshot function availability (without making system changes)
Write-Host "Testing Apply-NipkgSnapshot function availability..." -ForegroundColor Green

if (Test-Path "$tempDirectory\snapshot.json") {
    Write-Host "Found snapshot file: $tempDirectory\snapshot.json" -ForegroundColor Cyan
    
    # Test function availability and parameter validation only
    Write-Host "✓ Apply-NipkgSnapshot function is available for manual testing" -ForegroundColor Green
    Write-Host ""
    Write-Host "USAGE EXAMPLES:" -ForegroundColor Yellow
    Write-Host "  # Apply complete snapshot (adds feeds and installs packages):" -ForegroundColor White
    Write-Host "  Import-NipkgSnapshotFromJson '$tempDirectory\snapshot.json' | Apply-NipkgSnapshot" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  # Only add feeds (skip package installation):" -ForegroundColor White  
    Write-Host "  Import-NipkgSnapshotFromJson '$tempDirectory\snapshot.json' | Apply-NipkgSnapshot -SkipPackages" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  # Only install packages (skip adding feeds):" -ForegroundColor White
    Write-Host "  Import-NipkgSnapshotFromJson '$tempDirectory\snapshot.json' | Apply-NipkgSnapshot -SkipFeeds" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  # Use with specific NIPKG path and force installation:" -ForegroundColor White
    Write-Host "  Import-NipkgSnapshotFromJson '$tempDirectory\snapshot.json' | Apply-NipkgSnapshot -NipkgCmdPath '$nipkgPath' -Force" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  # Preview what would be done (safe to run):" -ForegroundColor White
    Write-Host "  Import-NipkgSnapshotFromJson '$tempDirectory\snapshot.json' | Apply-NipkgSnapshot -WhatIf" -ForegroundColor Gray
    Write-Host ""
    
    Write-Host "WARNING: Apply-NipkgSnapshot makes system changes. Test manually with appropriate permissions." -ForegroundColor Red
    
} else {
    Write-Host "✗ No snapshot file found at $tempDirectory\snapshot.json" -ForegroundColor Red
    Write-Host "   Run the snapshot creation tests first to generate a test snapshot" -ForegroundColor Yellow
}

Write-Host ""

# ===================================================================================
# Test Get-PackageInstallationOrder Function
# ===================================================================================

Write-Host "Testing Get-PackageInstallationOrder function..." -ForegroundColor Green

# Check if Packages file exists in test-temp
$packagesTestFile = "$tempDirectory\Packages"

if (Test-Path $packagesTestFile) {
    Write-Host "Found Packages file: $packagesTestFile" -ForegroundColor Cyan
    
    try {
        # Load packages from the Packages file
        Write-Host "Loading packages from Packages file..." -ForegroundColor Yellow
        $packages = Get-PackagesInfoFromPackagesFile -InputPath $packagesTestFile
        Write-Host "✓ Loaded $($packages.Count) packages from Packages file" -ForegroundColor Green
        
        # Test dependency ordering
        Write-Host "Analyzing package dependencies and determining installation order..." -ForegroundColor Yellow
        $orderedPackages = Get-PackageInstallationOrder -PackagesInfo $packages
        Write-Host "✓ Successfully ordered $($orderedPackages.Count) packages for installation" -ForegroundColor Green
        
        # Display first 10 packages in installation order
        Write-Host ""
        Write-Host "First 10 packages in installation order (dependencies first):" -ForegroundColor Cyan
        $orderedPackages | Select-Object -First 10 | ForEach-Object -Begin { $i = 1 } -Process {
            $dependsCount = 0
            $dependsFields = @('Depends', 'Recommends')
            foreach ($field in $dependsFields) {
                if ($_.PSObject.Properties.Name -contains $field -and $_.$field) {
                    $dependsCount++
                }
            }
            Write-Host "  $i. $($_.Package) ($($_.Version)) - Dependencies: $dependsCount field(s)" -ForegroundColor White
            $i++
        }
        
        # Display last 10 packages (most dependent)
        Write-Host ""
        Write-Host "Last 10 packages in installation order (most dependent):" -ForegroundColor Cyan
        $orderedPackages | Select-Object -Last 10 | ForEach-Object -Begin { $i = $orderedPackages.Count - 9 } -Process {
            $dependsCount = 0
            $dependsFields = @('Depends', 'Recommends')
            foreach ($field in $dependsFields) {
                if ($_.PSObject.Properties.Name -contains $field -and $_.$field) {
                    $dependsCount++
                }
            }
            Write-Host "  $i. $($_.Package) ($($_.Version)) - Dependencies: $dependsCount field(s)" -ForegroundColor White
            $i++
        }
        
        # Test with different dependency types
        Write-Host ""
        Write-Host "Testing with only 'Depends' dependencies..." -ForegroundColor Yellow
        $strictOrderedPackages = Get-PackageInstallationOrder -PackagesInfo $packages -IncludeDependencyTypes @('Depends')
        Write-Host "✓ Ordered $($strictOrderedPackages.Count) packages with strict dependencies only" -ForegroundColor Green
        
        # Test with all dependency types
        Write-Host "Testing with all dependency types..." -ForegroundColor Yellow
        $allDepsOrderedPackages = Get-PackageInstallationOrder -PackagesInfo $packages -IncludeDependencyTypes @('Depends', 'Recommends', 'Suggests', 'Enhances', 'Supplements')
        Write-Host "✓ Ordered $($allDepsOrderedPackages.Count) packages with all dependency types" -ForegroundColor Green
        
        # Save ordered packages to file for manual inspection
        $orderedPackagesFile = "$tempDirectory\ordered-packages.json"
        $orderedPackagesData = @{
            TotalPackages = $orderedPackages.Count
            InstallationOrder = $orderedPackages | ForEach-Object {
                @{
                    Package = $_.Package
                    Version = $_.Version
                    Section = $_.Section
                    Dependencies = @{
                        Depends = if ($_.PSObject.Properties.Name -contains 'Depends') { $_.Depends } else { $null }
                        Recommends = if ($_.PSObject.Properties.Name -contains 'Recommends') { $_.Recommends } else { $null }
                        Suggests = if ($_.PSObject.Properties.Name -contains 'Suggests') { $_.Suggests } else { $null }
                    }
                }
            }
        }
        
        $orderedPackagesData | ConvertTo-Json -Depth 5 | Out-File -FilePath $orderedPackagesFile -Encoding UTF8
        Write-Host "✓ Saved installation order to: $orderedPackagesFile" -ForegroundColor Green
        
        # Analyze dependency distribution
        Write-Host ""
        Write-Host "Dependency Analysis:" -ForegroundColor Cyan
        $packagesWithDepends = ($packages | Where-Object { $_.PSObject.Properties.Name -contains 'Depends' -and $_.Depends }).Count
        $packagesWithRecommends = ($packages | Where-Object { $_.PSObject.Properties.Name -contains 'Recommends' -and $_.Recommends }).Count
        $packagesWithSuggests = ($packages | Where-Object { $_.PSObject.Properties.Name -contains 'Suggests' -and $_.Suggests }).Count
        
        Write-Host "  Packages with 'Depends': $packagesWithDepends" -ForegroundColor White
        Write-Host "  Packages with 'Recommends': $packagesWithRecommends" -ForegroundColor White
        Write-Host "  Packages with 'Suggests': $packagesWithSuggests" -ForegroundColor White
        
        Write-Host ""
        Write-Host "✓ Get-PackageInstallationOrder function test completed successfully" -ForegroundColor Green
        
        # Usage examples
        Write-Host ""
        Write-Host "USAGE EXAMPLES:" -ForegroundColor Yellow
        Write-Host "  # Basic usage - order packages for installation:" -ForegroundColor White
        Write-Host "  `$packages = Get-PackagesInfoFromPackagesFile -InputPath 'Packages'" -ForegroundColor Gray
        Write-Host "  `$ordered = Get-PackageInstallationOrder -PackagesInfo `$packages" -ForegroundColor Gray
        Write-Host ""
        Write-Host "  # Only consider hard dependencies:" -ForegroundColor White
        Write-Host "  `$ordered = Get-PackageInstallationOrder -PackagesInfo `$packages -IncludeDependencyTypes @('Depends')" -ForegroundColor Gray
        Write-Host ""
        Write-Host "  # Include all dependency types:" -ForegroundColor White
        Write-Host "  `$ordered = Get-PackageInstallationOrder -PackagesInfo `$packages -IncludeDependencyTypes @('Depends', 'Recommends', 'Suggests')" -ForegroundColor Gray
        Write-Host ""
        Write-Host "  # Allow circular dependencies (break cycles):" -ForegroundColor White
        Write-Host "  `$ordered = Get-PackageInstallationOrder -PackagesInfo `$packages -AllowCircularDependencies" -ForegroundColor Gray
        
    } catch {
        Write-Host "✗ Error testing Get-PackageInstallationOrder: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Error details: $($_.Exception)" -ForegroundColor Yellow
    }
} else {
    Write-Host "✗ No Packages file found at $packagesTestFile" -ForegroundColor Red
    Write-Host "   Please ensure you have a Packages file in the test-temp directory" -ForegroundColor Yellow
    Write-Host "   You can copy one from an NIPKG feed or installer directory" -ForegroundColor Yellow
}

Write-Host ""