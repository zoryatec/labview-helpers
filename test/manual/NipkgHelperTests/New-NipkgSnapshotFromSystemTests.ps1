Import-Module -Name $PSScriptRoot/../../../LabViewHelpers/LabViewHelpers.psd1 -Force



$nipkgCmdContainingDir = "C:\\Program Files\\National Instruments\\NI Package Manager"
$nipkgCmdPath = "$nipkgCmdContainingDir\\nipkg.exe"

$tempDirectory = "$PSScriptRoot/../test-temp"
$systemSnapshot = "$tempDirectory/system-snapshot.json"


# $snapshot = New-SnapshotFromSystem `
#                     -NipkgCmdPath $nipkgCmdPath `
#                     -FilterFunction {  @($input) | & (Get-StoreProductPackages) } `
#                     -IncludeFeeds $true 


$snapshot = New-SnapshotFromSystem `
                    -NipkgCmdPath $nipkgCmdPath `
                    -IncludeFeeds $true 

    
Export-NipkgSnapshotToJson  -Snapshot $snapshot `
                            -OutputPath $systemSnapshot -Verbose

$snapshotRound = Import-NipkgSnapshotFromJson -InputPath $systemSnapshot -Verbose
$snapshotRound
    
