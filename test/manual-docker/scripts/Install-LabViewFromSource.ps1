$srcDirectory = "$PSScriptRoot\..\LabViewHelpers"
$modulePath = "$srcDirectory\LabViewHelpers.psd1"
$installScript = "$PSScriptRoot\Install-LabView.ps1"

Import-Module -Name $modulePath -Force

& $installScript 

