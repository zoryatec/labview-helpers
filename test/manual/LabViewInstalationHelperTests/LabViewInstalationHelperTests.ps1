Import-Module -Name $PSScriptRoot/../../../LabViewHelpers/LabViewHelpers.psd1 -Force


$NipkgCmdPath = "$PSScriptRoot/../../LabViewHelpers/test/manual-docker/nipkg/nipkg.exe"


$nipkgCmdContainingDir = "C:\\Program Files\\National Instruments\\NI Package Manager"
$nipkgCmdPath = "$nipkgCmdContainingDir\\nipkg.exe"


$installerDirectory  = "$PsScriptRoot/../../manual-docker/installers/ni-labview-2025-community-x86_25.1.3_offline"
# $installerDirectory = "C:\Projects\LabVIEW\ni-labview-2024-x86_24.5.0.49229-0+f77_offline"

$nipkgInstallerPath = Join-Path $PSScriptRoot ".." "manual-docker/installer-nipkg/Install.exe"


$tempDirectory = "$PSScriptRoot/../test-temp"
$tempSnapshotFile = "$tempDirectory/installation-snapshot.json"


$installParams = @{
    NipkgCmdPath = $NipkgCmdPath
    LabViewInstallerDirectory = $installerDirectory
    RemoveExistingFeeds = $true
    RemoveSnapshotFeeds = $true
    Simulate = $true
    InstallationSnapshotFile = $tempSnapshotFile
    NipkgInstallerPath = $nipkgInstallerPath
    AcceptEulas = $true
}

Install-PackagesFromInstallerDirectory @installParams