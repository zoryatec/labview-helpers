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
    'Get-PackagesInfoFromFile'
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


$feedsInfo = Get-FeedsInfo -NipkgCmdPath $nipkgPath

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

# $feedInfo = Get-FeedsInfo `
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
$combinedPackages = Get-PackagesInfo -Type 'installed' -NipkgCmdPath $nipkgPath
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

# Test the new file-based function
Write-Host "Testing Get-PackagesInfoFromFile function..." -ForegroundColor Green

# First, save some raw output to a test file
$testOutputFile = "$tempDirectory\test-nipkg-output.txt"
Write-Host "1. Saving raw NIPKG output to file: $testOutputFile" -ForegroundColor Yellow

try {
    # Save the raw output we got earlier to a file
    $rawOutput | Out-File -FilePath $testOutputFile -Encoding UTF8
    Write-Host "   ✓ Saved $($rawOutput.Count) lines to file" -ForegroundColor Green

    # Test parsing from file
    Write-Host "2. Parsing packages from file..." -ForegroundColor Yellow
    $filePackages = Get-PackagesInfoFromFile -InputPath $testOutputFile
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