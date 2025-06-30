#Requires -Version 5.1

Import-Module -Name "$PSScriptRoot\\NipkgHelper.psm1" -Force
Import-Module -Name "$PSScriptRoot\\LabViewConfigHelper.psm1" -Force
Import-Module -Name "$PSScriptRoot\\LabViewCLIConfigHelper.psm1" -Force
function Install-LabView {
    [CmdletBinding()]
param (
    [Parameter()]
    [string] $NipkgCmdPath = 'nipkg'
)

    $packagesInfo = Get-PackagesInfo `
        -NipkgCmdPath $NipkgCmdPath `
        -Type 'available' # 'installed' or 'available'

    Write-Host "Installing programming environments packages..." -ForegroundColor Cyan
    $programingEnvironmentsPackages  = Get-ProgrammingEnvironmentsPackages -PackagesInfo $packagesInfo
    foreach ($package in $programingEnvironmentsPackages) {
        Write-Host "Installing package: $($package.Package) version $($package.Version)"
        & $NipkgCmdPath install "$($package.Package)" --accept-eulas --include-recommended -y  
    }

    Write-Host "Installing drivers packages..." -ForegroundColor Cyan
    $driversPackages  = Get-DriverPackages -PackagesInfo $packagesInfo
    foreach ($package in $driversPackages) {
        Write-Host "Installing package: $($package.Package) version $($package.Version)"
        & $NipkgCmdPath install "$($package.Package)" --accept-eulas --include-recommended -y  
    }

    Write-Host "Installing application packages..." -ForegroundColor Cyan
    $applicationPackages  = Get-ApplicationSoftwarePackages -PackagesInfo $packagesInfo
    foreach ($package in $applicationPackages) {
        Write-Host "Installing package: $($package.Package) version $($package.Version)"
        & $NipkgCmdPath install "$($package.Package)" --accept-eulas --include-recommended -y  
    }

    Write-Host "Installing utilities packages..." -ForegroundColor Cyan
    $utilitiesPackages  = Get-UtilitiesPackages -PackagesInfo $packagesInfo
    foreach ($package in $utilitiesPackages ) {
        Write-Host "Installing package: $($package.Package) version $($package.Version)"
        & $NipkgCmdPath install "$($package.Package)" --accept-eulas --include-recommended -y  
    }
}

function Install-Chocolatey {
    Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072;
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
}

function Install-ChocolateyPackage7zip {
    choco install 7zip -y
}

function Install-Gcd {
[CmdletBinding()]
    param (
        [Parameter()]
        [String]
        $NipkgCmdPath = 'nipkg',
        [Parameter()]
        [String]
        $GcdFeed = 'https://raw.githubusercontent.com/zoryatec/gcd/refs/heads/main/feed'
    )
    & $NipkgCmdPath feed-add $GcdFeed --name=gcd-feed --system
    & $NipkgCmdPath update
    & $NipkgCmdPath install gcd -y

    $gcdCmdContainingDir = "C:\Program Files\gcd"
    $gcdCmdPath = "$gcdCmdContainingDir\\gcd.exe"
    & $gcdCmdPath tools add-to-system-path $gcdCmdContainingDir # add gcd itself
}


function Install-LabViewOffline {
    [CmdletBinding()]
    param (
        [Parameter()]
        [string] $NipkgCmdPath = "C:\\Program Files\\National Instruments\\NI Package Manager\\nipkg.exe",

        [Parameter(Mandatory = $true)]
        [string] $LabViewInstallerDirectory,
        
        [Parameter(Mandatory = $false)]
        [string] $NipkgInstallerPath
    )

    $labViewInstallerPath = "$LabViewInstallerDirectory\\Install.exe"
    $feedsDirectory = "$LabViewInstallerDirectory\\feeds"

    if (Test-Path -Path $NipkgInstallerPath) {
        Install-NipkgManager -InstallerPath $NipkgInstallerPath
    }

    # add test that nipkg is installed
    & $NipkgCmdPath --version

    # Install-Gcd -NipkgCmdPath $NipkgCmdPath

    Add-FeedDirectories `
        -FeedsDirectory $feedsDirectory `
        -NipkgCmdPath $NipkgCmdPath 

    Install-LabView -NipkgCmdPath $NipkgCmdPath
}

function Expand-Iso {
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]
        $IsoFilePath,
        [Parameter()]
        [string]    
        $OutputDirectoryPath
    )

    if (-not (Test-Path -Path $IsoFilePath)) {
        throw "ISO file not found: $IsoFilePath"
    }

    if (-not (Test-Path -Path $OutputDirectoryPath)) {
        New-Item -ItemType Directory -Path $OutputDirectoryPath | Out-Null
    }

    Install-Chocolatey
    Install-ChocolateyPackage7zip

    7z x $IsoFilePath -o"$OutputDirectoryPath"
}

function Install-LabViewIso {
    [CmdletBinding()]
    param (
        [Parameter()]
        [string] $NipkgCmdPath = "C:\\Program Files\\National Instruments\\NI Package Manager\\nipkg.exe",

        [Parameter(Mandatory = $true)]
        [string]
        $IsoFilePath,
        
        [Parameter(Mandatory = $false)]
        [string] $NipkgInstallerPath,

        [Parameter(Mandatory = $false)]
        [string] $TemporaryExpandDirectory = "C:\\installer-labview"
    )

    Expand-Iso `
        -IsoFilePath $IsoFilePath `
        -OutputDirectoryPath $TemporaryExpandDirectory

    Install-LabViewOffline `
        -NipkgCmdPath $NipkgCmdPath `
        -LabViewInstallerDirectory $TemporaryExpandDirectory `
        -NipkgInstallerPath $NipkgInstallerPath
}

function Set-LabViewForCi {
    param(
        [Parameter(Mandatory = $true)]
        [string]$LabViewDirectory,

        [Parameter(Mandatory = $false)]
        [string]$LabViewCliDirectory = "C:\\Program Files (x86)\\National Instruments\\Shared\\LabVIEW CLI"
    )

    $labviewConfigPath = Join-Path -Path $LabViewDirectory -ChildPath "LabVIEW.ini"

    $labViewCliConfigPath = Join-Path -Path $LabViewCliDirectory -ChildPath "LabVIEWCLI.ini"

    # enable TCP server
    Set-ConfigValue -ConfigPath $labviewConfigPath -Section "LabVIEW" -Key "server.tcp.enabled" -Value "True" -CreateIfNotExists
    Set-ConfigValue -ConfigPath $labviewConfigPath -Section "LabVIEW" -Key "server.tcp.port" -Value "3363" -CreateIfNotExists

    # ci license 
    Set-ConfigValue -ConfigPath $labviewConfigPath -Section "LabVIEW" -Key "neverShowAddonLicensingStartup" -Value "True" -CreateIfNotExists
    Set-ConfigValue -ConfigPath $labviewConfigPath -Section "LabVIEW" -Key "neverShowLicensingStartupDialog" -Value "True" -CreateIfNotExists
    Set-ConfigValue -ConfigPath $labviewConfigPath -Section "LabVIEW" -Key "ShowWelcomeOnLaunch" -Value "False" -CreateIfNotExists


    #cli config
    Set-LabVIEWCLIConfig -ConfigPath $labViewCliConfigPath -Key "ValidateLabVIEWLicense" -Value FALSE -CreateIfNotExists
}


Export-ModuleMember -Function `
        Install-LabViewOffline `
    ,   Install-Chocolatey `
    ,   Install-ChocolateyPackage7zip `
    ,   Install-Gcd `
    ,   Install-LabView `
    ,   Expand-Iso `
    ,   Install-LabViewIso `
    ,   Set-LabViewForCi
