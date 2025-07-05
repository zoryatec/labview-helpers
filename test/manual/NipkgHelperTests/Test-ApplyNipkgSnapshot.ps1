Import-Module -Name $PSScriptRoot/../../../LabViewHelpers/LabViewHelpers.psd1 -Force


$nipkgCmdContainingDir = "C:\\Program Files\\National Instruments\\NI Package Manager"
$nipkgCmdPath = "$nipkgCmdContainingDir\\nipkg.exe"

$tempDirectory = "$PSScriptRoot/../test-temp"
$systemSnapshot = "$tempDirectory/system-snapshot.json"


$snapshotRepository = "$PSScriptRoot/../../../../nipkg-snapshots"
$snapshotFileName = "labview-24.5.0.json"
$snapshotFilePath = "$snapshotRepository/labview/$snapshotFileName"


$applyParams = @{
    SnapshotPath = $snapshotFilePath
    NipkgCmdPath = $nipkgCmdPath
    Verbose = $true
    ValidateCompliance = $true
}

$applyParams.RemoveExistingFeeds = $true
$applyParams.RemoveSnapshotFeeds = $false
$applyParams.RemoveUnlistedFeeds = $true


Apply-NipkgSnapshot @applyParams