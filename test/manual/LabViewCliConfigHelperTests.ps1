# Example usage with your LabVIEW CLI config
Import-Module -Name $PSScriptRoot/../../src/LabViewCLIConfigHelper.psm1 -Force

$tempDirectory = "$PSScriptRoot/test-temp"
$sourceConfig = "$PSScriptRoot/test-data/LabVIEWCLI.ini"
$tempConfig = "$tempDirectory/LabVIEWCLI.ini"

New-Item -Path $tempDirectory -ItemType Directory -Force | Out-Null
Copy-Item -Path $sourceConfig -Destination $tempConfig -Force

# Add or modify values
Set-LabVIEWCLIConfig -ConfigPath $tempConfig -Key "OpenAppReferenceTimeoutInSecond" -Value "180"
Set-LabVIEWCLIConfig -ConfigPath $tempConfig -Key "DefaultPortNumber" -Value "3364" -CreateIfNotExists
Set-LabVIEWCLIConfig -ConfigPath $tempConfig -Key "ValidateLabVIEWLicense" -Value FALSE

# Get a specific value
$timeout = Get-LabVIEWCLIConfig -ConfigPath $tempConfig -Key "OpenAppReferenceTimeoutInSecond"
Write-Host "Timeout: $timeout"

# Remove a value
Remove-LabVIEWCLIConfig -ConfigPath $tempConfig -Key "PingDelay"

# Show entire config file
Show-LabVIEWCLIConfig -ConfigPath $tempConfig

# Get all values
$allConfig = Get-AllLabVIEWCLIConfig -ConfigPath $tempConfig
$allConfig.Keys | ForEach-Object {
    Write-Host "$_ = $($allConfig[$_])"
}
