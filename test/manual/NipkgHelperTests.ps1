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

New-NipkgSnapshot `
    -PackagesInfo $packagesInfo `
    -FeedsInfo $feedsInfo `
    -OutputPath "$tempDirectory\snapshot.json" 


# Your raw output (from file or command)

# $feedInfo = Get-FeedsInfo `
#     -NipkgCmdPath $nipkgPath

# $feedInfo | Sort-Object Name | Format-Table Name

# Remove-Feeds `
#      -FeedsInfo $feedInfo  `
#      -NipkgCmdPath $nipkgPath