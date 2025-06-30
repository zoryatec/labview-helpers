Import-Module -Name "$PSScriptRoot/NipkgHelper.psm1" -Force

$nipkgPath = 'C:\Program Files\National Instruments\NI Package Manager\nipkg.exe'
# Add-FeedDirectories `
#     -FeedsDirectory 'C:\Projects\LabVIEW\ni-labview-2024-x86_24.5.0.49229-0+f77_offline\feeds' `
#     -NipkgCmdPath 'C:\Program Files\National Instruments\NI Package Manager\nipkg.exe'


# Add-FeedDirectories `
#     -FeedsDirectory 'C:\Projects\LabVIEW\ni-labview-2025-community-x86_25.1.3_offline\feeds' `
#     -NipkgCmdPath 'C:\Program Files\National Instruments\NI Package Manager\nipkg.exe'



$packagesInfo = Get-PackagesInfo `
    -NipkgCmdPath $nipkgPath `
    -Type 'available' # 'installed' or 'available'

# $packagesInfo | Sort-Object Section | Format-Table Package, Version, Architecture, Section


$driversPackages  = Get-DriverPackages -PackagesInfo $packagesInfo
$driversPackages | Sort-Object Section | Format-Table Package, Version, Architecture, Section


$programingEnvironmentsPackages  = Get-ProgrammingEnvironmentsPackages -PackagesInfo $packagesInfo
$programingEnvironmentsPackages | Sort-Object Section | Format-Table Package, Version, Architecture, Section


$applicationPackages  = Get-ApplicationSoftwarePackages -PackagesInfo $packagesInfo
$applicationPackages | Sort-Object Section | Format-Table Package, Version, Architecture, Section

$utilitiesPackages  = Get-UtilitiesPackages -PackagesInfo $packagesInfo
$utilitiesPackages | Sort-Object Section | Format-Table Package, Version, Architecture, Section


# Your raw output (from file or command)

# $feedInfo = Get-FeedsInfo `
#     -NipkgCmdPath $nipkgPath

# $feedInfo | Sort-Object Name | Format-Table Name

# Remove-Feeds `
#      -FeedsInfo $feedInfo  `
#      -NipkgCmdPath $nipkgPath