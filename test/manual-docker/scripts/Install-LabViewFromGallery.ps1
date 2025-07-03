$installScript = "$PSScriptRoot\Install-LabView.ps1"

Set-PSRepository -Name "PSGallery" -InstallationPolicy Trusted
Install-Module -Name LabViewHelpers -Force -Scope CurrentUser

& $installScript 



