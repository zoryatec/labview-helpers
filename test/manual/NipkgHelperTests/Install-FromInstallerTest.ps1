Import-Module -Name $PSScriptRoot/../../../LabViewHelpers/LabViewHelpers.psd1 -Force

$nipkgCmdContainingDir = "C:\\Program Files\\National Instruments\\NI Package Manager"
$nipkgCmdPath = "$nipkgCmdContainingDir\\nipkg.exe"

$tempDirectory = "$PSScriptRoot/../test-temp"
$installerSnapshotPath = "$tempDirectory/installer-snapshot.json"

$LabViewInstallerDirectory  = "$PsScriptRoot/../../manual-docker/installers/ni-labview-2025-community-x86_25.1.3_offline"

$installerSnapshot = New-NipkgSnapshotFromInstaller -InstallerDirectory $LabViewInstallerDirectory -Verbose
Export-NipkgSnapshotToJson -Snapshot $installerSnapshot -OutputPath $installerSnapshotPath -Verbose



$applyParams = @{
    SnapshotPath = $installerSnapshotPath
    NipkgCmdPath = $nipkgCmdPath
    Verbose = $true
    ValidateCompliance = $true
    UseBatchInstallation = $true
    SyncNipkgVersion = $true
    ExcludePackages = $ExcludePackages
}

if ($RemoveExistingFeeds) {
    $applyParams.RemoveExistingFeeds = $false
}

if ($RemoveSnapshotFeeds) {
    $applyParams.RemoveSnapshotFeeds = $false
}

Apply-NipkgSnapshot @applyParams

