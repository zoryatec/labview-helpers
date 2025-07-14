Import-Module -Name $PSScriptRoot/../../../LabViewHelpers/LabViewHelpers.psd1 -Force


$nipkgCmdContainingDir = "C:\\Program Files\\National Instruments\\NI Package Manager"
$nipkgCmdPath = "$nipkgCmdContainingDir\\nipkg.exe"

$tempDirectory = "$PSScriptRoot/../test-temp"
$systemSnapshot = "$tempDirectory/system-snapshot.json"


$snapshotRepository = "$PSScriptRoot/../../../../nipkg-snapshots"
$snapshotFileName = "labview-24.5.0.json"
$snapshotFilePath = "$snapshotRepository/labview/$snapshotFileName"

$nipkgInstallerPath = Join-Path $PSScriptRoot ".." "manual-docker/installer-nipkg/Install.exe"

$snapshot = Import-NipkgSnapshotFromJson  -InputPath $snapshotFilePath


Install-PackagesFromSystemSnapshot `
    -NipkgCmdPath $nipkgCmdPath `
    -Snapshot $snapshot `
    -RemoveExistingFeeds:$true `
    -Simulate:$false `
    -AcceptEulas:$true `
    -FilterFunction { @($input) | & (Get-StoreProductPackages) }