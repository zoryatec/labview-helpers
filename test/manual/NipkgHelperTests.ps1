Import-Module -Name $PSScriptRoot/../../LabViewHelpers/LabViewHelpers.psd1 -Force

$nipkgPath = 'C:\Program Files\National Instruments\NI Package Manager\nipkg.exe'
$tempDirectory = "$PSScriptRoot/test-temp"
# Add-FeedDirectories `
#     -FeedsDirectory 'C:\Projects\LabVIEW\ni-labview-2024-x86_24.5.0.49229-0+f77_offline\feeds' `
#     -NipkgCmdPath 'C:\Program Files\National Instruments\NI Package Manager\nipkg.exe'


# Add-FeedDirectories `
#     -FeedsDirectory 'C:\Projects\LabVIEW\ni-labview-2025-community-x86_25.1.3_offline\feeds' `
#     -NipkgCmdPath 'C:\Program Files\National Instruments\NI Package Manager\nipkg.exe'


$feedsInfo = Get-FeedsInfo `
    -NipkgCmdPath $nipkgPath `

$packagesInfo = Get-PackagesInfo `
    -NipkgCmdPath $nipkgPath `
    -Type 'installed' # 'installed' or 'available'

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