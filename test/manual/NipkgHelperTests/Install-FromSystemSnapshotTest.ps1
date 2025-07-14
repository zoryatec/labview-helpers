Import-Module -Name $PSScriptRoot/../../../LabViewHelpers/LabViewHelpers.psd1 -Force


$nipkgCmdContainingDir = "C:\\Program Files\\National Instruments\\NI Package Manager"
$nipkgCmdPath = "$nipkgCmdContainingDir\\nipkg.exe"

$tempDirectory = "$PSScriptRoot/../test-temp"
$systemSnapshot = "$tempDirectory/system-snapshot.json"


$snapshotRepository = "$PSScriptRoot/../../../../nipkg-snapshots"
$snapshotFileName = "labview-24.5.0.json"
$snapshotFilePath = "$snapshotRepository/labview/$snapshotFileName"


$snapshot = Import-NipkgSnapshotFromJson `
    InputPath $snapshotFilePath


$installParams = @{
    NipkgCmdPath = $NipkgCmdPath
    $Snapshot = $snapshot
    RemoveExistingFeeds = $false
    Simulate = $true
    NipkgInstallerPath = $nipkgInstallerPath
    AcceptEulas = $true
}

Install-PackagesFromSystemSnapshot @installParams