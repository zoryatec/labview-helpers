# Example usage with your LabVIEW config
Import-Module -Name $PSScriptRoot/../../src/LabViewConfigHelper.psm1 -Force


$tempDirectory = "$PSScriptRoot/test-temp"
$sourceConfig = "$PSScriptRoot/test-data/LabVIEW.ini"
$tempConfig = "$tempDirectory/LabVIEW.ini"


New-Item -Path $tempDirectory -ItemType Directory -Force | Out-Null
Copy-Item -Path $sourceConfig -Destination $tempConfig -Force

# Add or modify values
Set-ConfigValue -ConfigPath $tempConfig -Section "LabVIEW" -Key "server.tcp.enabled" -Value "False"
Set-ConfigValue -ConfigPath $tempConfig -Section "LabVIEW" -Key "server.tcp.port" -Value "3363" -CreateIfNotExists

# Get a specific value
$tcpEnabled = Get-ConfigValue -ConfigPath $tempConfig -Section "LabVIEW" -Key "server.tcp.enabled"
Write-Host "TCP Enabled: $tcpEnabled"

# Remove a value
Remove-ConfigValue -ConfigPath $tempConfig -Section "LabVIEW" -Key "LastErrorListSize"

# Show entire config file
Show-ConfigFile -ConfigPath $tempConfig

# Get all values from a specific section
$labviewConfig = Get-AllConfigValues -ConfigPath $tempConfig -Section "LabVIEW"
$labviewConfig["LabVIEW"].Keys | ForEach-Object {
    Write-Host "$_ = $($labviewConfig['LabVIEW'][$_])"
}