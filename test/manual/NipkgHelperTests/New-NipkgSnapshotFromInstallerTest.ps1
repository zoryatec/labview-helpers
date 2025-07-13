Import-Module -Name $PSScriptRoot/../../../LabViewHelpers/LabViewHelpers.psd1 -Force

$nipkgCmdContainingDir = "C:\\Program Files\\National Instruments\\NI Package Manager"
$nipkgCmdPath = "$nipkgCmdContainingDir\\nipkg.exe"

$tempDirectory = "$PSScriptRoot/../test-temp"
$installerSnapshotPath = "$tempDirectory/installer-snapshot.json"

$LabViewInstallerDirectory  = "$PsScriptRoot/../../manual-docker/installers/ni-labview-2025-community-x86_25.1.3_offline"
# $LabViewInstallerDirectory = "C:\Projects\LabVIEW\ni-labview-2024-x86_24.5.0.49229-0+f77_offline"

# Simple lambda-like filtering - store products AND application software
$installerSnapshot = New-SnapshotFromInstallerDirectory `
    -InstallerDirectory $LabViewInstallerDirectory -Verbose `
    -FilterFunction { 
        $packages = @($input)  # Collect input once
        Write-Host "Input packages: $($packages.Count)"
        $result = $packages | Where-Object { $_.StoreProduct -eq 'yes'} | Where-Object{ $_.Section -eq 'Application Software' }
        Write-Host "Filtered packages: $($result.Count)"
        $result
    }
Export-NipkgSnapshotToJson -Snapshot $installerSnapshot -OutputPath $installerSnapshotPath -Verbose

# Test the chaining to see what's happening
function Test-FilterChaining {
    param($packages)
    
    Write-Host "Original package count: $($packages.Count)"
    
    # Test individual filters
    $storeProducts = $packages | Get-StoreProductPackages
    Write-Host "Store products: $($storeProducts.Count)"
    
    $appSoftware = $packages | Get-ApplicationSoftwarePackages
    Write-Host "Application software: $($appSoftware.Count)"
    
    # Test chained
    $chained = $packages | Get-StoreProductPackages | Get-ApplicationSoftwarePackages
    Write-Host "Chained (store + app): $($chained.Count)"
    
    return $chained
}

# Uncomment to test with your packages
# $testResult = Test-FilterChaining -packages $uniquePackages
