Import-Module -Name $PSScriptRoot/../../LabViewHelpers/LabViewHelpers.psd1 -Force


$NipkgCmdPath = "$PSScriptRoot/../../LabViewHelpers/test/manual-docker/nipkg/nipkg.exe"


$nipkgCmdContainingDir = "C:\\Program Files\\National Instruments\\NI Package Manager"
$nipkgCmdPath = "$nipkgCmdContainingDir\\nipkg.exe"


$installerDirectory = Join-Path $PSScriptRoot ".." "manual-docker/installers/ni-labview-2025-community-x86_25.1.3_offline"
$nipkgInstallerPath = Join-Path $PSScriptRoot ".." "manual-docker/installer-nipkg/Install.exe"


$tempDirectory = "$PSScriptRoot/test-temp"
$tempSnapshotFile = "$tempDirectory/installation-snapshot.json"
Install-LabViewOffline `
    -LabViewInstallerDirectory $installerDirectory `
    -NipkgCmdPath $nipkgCmdPath `
    -NipkgInstallerPath $nipkgInstallerPath `
    -InstallationSnapshotFile $tempSnapshotFile