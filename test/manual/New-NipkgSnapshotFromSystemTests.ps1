Import-Module -Name $PSScriptRoot/../../LabViewHelpers/LabViewHelpers.psd1 -Force

$nipkgCmdContainingDir = "C:\\Program Files\\National Instruments\\NI Package Manager"
$nipkgCmdPath = "$nipkgCmdContainingDir\\nipkg.exe"


$tempDirectory = "$PSScriptRoot/test-temp"
$systemSnapshot = "$tempDirectory/system-snapshot.json"

$snapshot = New-NipkgSnapshotFromSystem `
                -NipkgCmdPath $nipkgCmdPath `

Export-NipkgSnapshotToJson -Snapshot $snapshot -OutputPath $systemSnapshot -Verbose

