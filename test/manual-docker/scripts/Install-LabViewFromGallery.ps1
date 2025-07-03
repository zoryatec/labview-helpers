$installScript = "$PSScriptRoot\Install-LabView.ps1"

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Install-PackageProvider -Name NuGet -Force -Scope CurrentUser
Install-Module -Name LabViewHelpers -Force -Scope CurrentUser

& $installScript 



