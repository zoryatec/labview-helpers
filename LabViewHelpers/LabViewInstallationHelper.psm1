#Requires -Version 5.1

<#
.SYNOPSIS
    LabVIEW Installation Management Module

.DESCRIPTION
    Provides comprehensive functions for automating LabVIEW installation processes.
    Supports offline installations, ISO mounting, package management, and CI/CD configuration.

.NOTES
    File Name      : LabViewInstallationHelper.psm1
    Author         : LabVIEW Helpers Team
    Prerequisite   : PowerShell 5.1 or higher
    Copyright 2025 : LabVIEW Helpers
#>

function Install-LabView {
    <#
    .SYNOPSIS
        Installs LabVIEW packages using NI Package Manager.

    .DESCRIPTION
        Automates the installation of LabVIEW programming environments, drivers, 
        applications, and utilities using NIPKG package manager.

    .PARAMETER NipkgCmdPath
        Path to the NIPKG command-line tool. Defaults to 'nipkg' if in PATH.

    .EXAMPLE
        Install-LabView

    .EXAMPLE
        Install-LabView -NipkgCmdPath "C:\Program Files\National Instruments\NI Package Manager\nipkg.exe"

    .NOTES
        Requires NIPKG to be installed and feeds to be configured.
        Installs packages in order: Programming Environments, Drivers, Applications, Utilities.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$NipkgCmdPath = 'nipkg'
    )
    
    begin {
        Write-Verbose "Starting Install-LabView operation"
    }
    
    process {
        try {

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
        catch {
            $errorMessage = "Failed to install LabVIEW packages. Error: $($_.Exception.Message)"
            Write-Error -Message $errorMessage -Category NotInstalled
            throw
        }
    }
    
    end {
        Write-Verbose "Completed Install-LabView operation"
    }
}

function Install-Chocolatey {
    <#
    .SYNOPSIS
        Installs Chocolatey package manager on the system.

    .DESCRIPTION
        Downloads and installs the Chocolatey package manager from the official website.
        Sets execution policy and security protocol for the installation process.

    .EXAMPLE
        Install-Chocolatey

    .NOTES
        Requires administrative privileges. Will modify execution policy temporarily.
    #>
    [CmdletBinding()]
    param()
    
    begin {
        Write-Verbose "Starting Install-Chocolatey operation"
    }
    
    process {
        try {
            Write-Information "Installing Chocolatey package manager..." -InformationAction Continue
            Set-ExecutionPolicy Bypass -Scope Process -Force
            [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
            Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
            Write-Information "Chocolatey installed successfully" -InformationAction Continue
        }
        catch {
            $errorMessage = "Failed to install Chocolatey. Error: $($_.Exception.Message)"
            Write-Error -Message $errorMessage -Category NotInstalled
            throw
        }
    }
    
    end {
        Write-Verbose "Completed Install-Chocolatey operation"
    }
}

function Install-ChocolateyPackage7zip {
    <#
    .SYNOPSIS
        Installs 7-Zip using Chocolatey package manager.

    .DESCRIPTION
        Uses Chocolatey to install the 7-Zip compression utility. Requires Chocolatey
        to be already installed on the system.

    .EXAMPLE
        Install-ChocolateyPackage7zip

    .NOTES
        Requires Chocolatey to be installed. Use Install-Chocolatey first if needed.
        Requires administrative privileges.
    #>
    [CmdletBinding()]
    param()
    
    begin {
        Write-Verbose "Starting Install-ChocolateyPackage7zip operation"
    }
    
    process {
        try {
            Write-Information "Installing 7-Zip via Chocolatey..." -InformationAction Continue
            & choco install 7zip -y
            
            if ($LASTEXITCODE -ne 0) {
                throw "Chocolatey installation of 7-Zip failed with exit code: $LASTEXITCODE"
            }
            
            Write-Information "7-Zip installed successfully" -InformationAction Continue
        }
        catch {
            $errorMessage = "Failed to install 7-Zip via Chocolatey. Error: $($_.Exception.Message)"
            Write-Error -Message $errorMessage -Category NotInstalled
            throw
        }
    }
    
    end {
        Write-Verbose "Completed Install-ChocolateyPackage7zip operation"
    }
}

function Install-Gcd {
    <#
    .SYNOPSIS
        Installs the GCD (Generic Configuration Deployer) tool via NIPKG.

    .DESCRIPTION
        Adds the GCD feed to NIPKG, updates the package list, and installs the GCD tool.
        Also adds GCD to the system PATH for global access.

    .PARAMETER NipkgCmdPath
        Path to the NIPKG command-line tool. Defaults to 'nipkg' if in PATH.

    .PARAMETER GcdFeed
        URL of the GCD package feed. Defaults to the official Zoryatec GCD feed.

    .EXAMPLE
        Install-Gcd

    .EXAMPLE
        Install-Gcd -NipkgCmdPath "C:\Program Files\National Instruments\NI Package Manager\nipkg.exe"

    .NOTES
        Requires NIPKG to be installed and administrative privileges.
        Adds GCD to system PATH automatically.
    #>
    [CmdletBinding()]
    param (
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$NipkgCmdPath = 'nipkg',
        
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$GcdFeed = 'https://raw.githubusercontent.com/zoryatec/gcd/refs/heads/main/feed'
    )
    
    begin {
        Write-Verbose "Starting Install-Gcd operation"
    }
    
    process {
        try {
            Write-Information "Adding GCD feed to NIPKG..." -InformationAction Continue
            & $NipkgCmdPath feed-add $GcdFeed --name=gcd-feed --system
            
            Write-Information "Updating NIPKG package list..." -InformationAction Continue
            & $NipkgCmdPath update
            
            Write-Information "Installing GCD package..." -InformationAction Continue
            & $NipkgCmdPath install gcd -y

            $gcdCmdContainingDir = "C:\Program Files\gcd"
            $gcdCmdPath = "$gcdCmdContainingDir\gcd.exe"
            
            if (Test-Path $gcdCmdPath) {
                Write-Information "Adding GCD to system PATH..." -InformationAction Continue
                & $gcdCmdPath tools add-to-system-path $gcdCmdContainingDir
                Write-Information "GCD installed and added to PATH successfully" -InformationAction Continue
            } else {
                Write-Warning "GCD executable not found at expected location: $gcdCmdPath"
            }
        }
        catch {
            $errorMessage = "Failed to install GCD. Error: $($_.Exception.Message)"
            Write-Error -Message $errorMessage -Category NotInstalled
            throw
        }
    }
    
    end {
        Write-Verbose "Completed Install-Gcd operation"
    }
}


function Install-LabViewOffline {
    <#
    .SYNOPSIS
        Performs offline installation of LabVIEW from installer directory.

    .DESCRIPTION
        Installs LabVIEW using offline installer files. Optionally installs NIPKG manager
        first, then adds feeds and performs the LabVIEW installation.

    .PARAMETER NipkgCmdPath
        Path to the NIPKG command-line tool. Defaults to standard installation path.

    .PARAMETER LabViewInstallerDirectory
        Path to the directory containing LabVIEW installer files and feeds.

    .PARAMETER NipkgInstallerPath
        Optional path to NIPKG installer if it needs to be installed first.

    .EXAMPLE
        Install-LabViewOffline -LabViewInstallerDirectory "C:\installers\labview"

    .EXAMPLE
        Install-LabViewOffline -LabViewInstallerDirectory "C:\installers\labview" -NipkgInstallerPath "C:\installers\nipkg\Install.exe"

    .NOTES
        Requires administrative privileges.
        The installer directory must contain a 'feeds' subdirectory with NIPKG feeds.
    #>
    [CmdletBinding()]
    param (
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$NipkgCmdPath = "C:\Program Files\National Instruments\NI Package Manager\nipkg.exe",

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$LabViewInstallerDirectory,
        
        [Parameter()]
        [string]$NipkgInstallerPath
    )
    
    begin {
        Write-Verbose "Starting Install-LabViewOffline operation"
    }
    
    process {
        try {
            if (-not (Test-Path -Path $LabViewInstallerDirectory)) {
                throw "LabVIEW installer directory not found: $LabViewInstallerDirectory"
            }

            $labViewInstallerPath = Join-Path -Path $LabViewInstallerDirectory -ChildPath "Install.exe"
            $feedsDirectory = Join-Path -Path $LabViewInstallerDirectory -ChildPath "feeds"

            if ($NipkgInstallerPath -and (Test-Path -Path $NipkgInstallerPath)) {
                Write-Information "Installing NIPKG manager first..." -InformationAction Continue
                Install-NipkgManager -InstallerPath $NipkgInstallerPath
            }

            # Verify NIPKG is available
            Write-Information "Verifying NIPKG installation..." -InformationAction Continue
            & $NipkgCmdPath --version
            
            if ($LASTEXITCODE -ne 0) {
                throw "NIPKG is not installed or not accessible at: $NipkgCmdPath"
            }

            Write-Information "Adding feed directories..." -InformationAction Continue
            Add-FeedDirectories -FeedsDirectory $feedsDirectory -NipkgCmdPath $NipkgCmdPath 

            Write-Information "Starting LabVIEW installation..." -InformationAction Continue
            Install-LabView -NipkgCmdPath $NipkgCmdPath
            
            Write-Information "LabVIEW offline installation completed successfully" -InformationAction Continue
        }
        catch {
            $errorMessage = "Failed to install LabVIEW offline. Error: $($_.Exception.Message)"
            Write-Error -Message $errorMessage -Category NotInstalled
            throw
        }
    }
    
    end {
        Write-Verbose "Completed Install-LabViewOffline operation"
    }
}

function Expand-Iso {
    <#
    .SYNOPSIS
        Extracts contents of an ISO file to a specified directory.

    .DESCRIPTION
        Uses 7-Zip to extract the contents of an ISO file. Automatically installs
        Chocolatey and 7-Zip if they are not already available.

    .PARAMETER IsoFilePath
        Path to the ISO file to extract.

    .PARAMETER OutputDirectoryPath
        Directory where the ISO contents will be extracted.

    .EXAMPLE
        Expand-Iso -IsoFilePath "C:\labview.iso" -OutputDirectoryPath "C:\temp\labview"

    .NOTES
        Requires administrative privileges for Chocolatey and 7-Zip installation.
        Will install dependencies automatically if not present.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$IsoFilePath,
        
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$OutputDirectoryPath
    )
    
    begin {
        Write-Verbose "Starting Expand-Iso operation"
    }
    
    process {
        try {
            if (-not (Test-Path -Path $IsoFilePath)) {
                throw "ISO file not found: $IsoFilePath"
            }

            if (-not (Test-Path -Path $OutputDirectoryPath)) {
                Write-Information "Creating output directory: $OutputDirectoryPath" -InformationAction Continue
                New-Item -ItemType Directory -Path $OutputDirectoryPath -Force | Out-Null
            }

            # Ensure 7-Zip is available
            $sevenZipPath = Get-Command "7z" -ErrorAction SilentlyContinue
            if (-not $sevenZipPath) {
                Write-Information "7-Zip not found, installing prerequisites..." -InformationAction Continue
                Install-Chocolatey
                Install-ChocolateyPackage7zip
                
                # Refresh PATH to find 7z
                $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
            }

            Write-Information "Extracting ISO file: $IsoFilePath" -InformationAction Continue
            & 7z x $IsoFilePath -o"$OutputDirectoryPath" -y
            
            if ($LASTEXITCODE -ne 0) {
                throw "7-Zip extraction failed with exit code: $LASTEXITCODE"
            }
            
            Write-Information "ISO extraction completed successfully" -InformationAction Continue
        }
        catch {
            $errorMessage = "Failed to expand ISO file. Error: $($_.Exception.Message)"
            Write-Error -Message $errorMessage -Category NotSpecified
            throw
        }
    }
    
    end {
        Write-Verbose "Completed Expand-Iso operation"
    }
}

function Install-LabViewIso {
    <#
    .SYNOPSIS
        Installs LabVIEW from an ISO file.

    .DESCRIPTION
        Extracts a LabVIEW ISO file and performs offline installation. Combines
        ISO extraction and offline installation in a single operation.

    .PARAMETER NipkgCmdPath
        Path to the NIPKG command-line tool. Defaults to standard installation path.

    .PARAMETER IsoFilePath
        Path to the LabVIEW ISO file to install from.

    .PARAMETER NipkgInstallerPath
        Optional path to NIPKG installer if it needs to be installed first.

    .PARAMETER TemporaryExpandDirectory
        Directory to temporarily extract ISO contents. Defaults to C:\installer-labview.

    .EXAMPLE
        Install-LabViewIso -IsoFilePath "C:\labview.iso"

    .EXAMPLE
        Install-LabViewIso -IsoFilePath "C:\labview.iso" -NipkgInstallerPath "C:\nipkg\Install.exe" -TemporaryExpandDirectory "D:\temp"

    .NOTES
        Requires administrative privileges and sufficient disk space for extraction.
        Temporary directory will be created if it doesn't exist.
    #>
    [CmdletBinding()]
    param (
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$NipkgCmdPath = "C:\Program Files\National Instruments\NI Package Manager\nipkg.exe",

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$IsoFilePath,
        
        [Parameter()]
        [string]$NipkgInstallerPath,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$TemporaryExpandDirectory = "C:\installer-labview"
    )
    
    begin {
        Write-Verbose "Starting Install-LabViewIso operation"
    }
    
    process {
        try {
            Write-Information "Starting LabVIEW installation from ISO: $IsoFilePath" -InformationAction Continue
            
            Write-Information "Step 1: Extracting ISO file..." -InformationAction Continue
            Expand-Iso -IsoFilePath $IsoFilePath -OutputDirectoryPath $TemporaryExpandDirectory

            Write-Information "Step 2: Installing LabVIEW from extracted files..." -InformationAction Continue
            Install-LabViewOffline -NipkgCmdPath $NipkgCmdPath -LabViewInstallerDirectory $TemporaryExpandDirectory -NipkgInstallerPath $NipkgInstallerPath
            
            Write-Information "LabVIEW ISO installation completed successfully" -InformationAction Continue
        }
        catch {
            $errorMessage = "Failed to install LabVIEW from ISO. Error: $($_.Exception.Message)"
            Write-Error -Message $errorMessage -Category NotInstalled
            throw
        }
        finally {
            # Optional: Clean up temporary directory
            if (Test-Path $TemporaryExpandDirectory) {
                Write-Verbose "Temporary directory remains at: $TemporaryExpandDirectory"
            }
        }
    }
    
    end {
        Write-Verbose "Completed Install-LabViewIso operation"
    }
}

function Set-LabViewForCi {
    <#
    .SYNOPSIS
        Configures LabVIEW for CI/CD environments.

    .DESCRIPTION
        Applies configuration settings to LabVIEW and LabVIEW CLI to make them suitable
        for automated CI/CD environments. Enables TCP server, disables interactive dialogs,
        and configures licensing for automated builds.

    .PARAMETER LabViewDirectory
        Path to the LabVIEW installation directory containing LabVIEW.ini.

    .PARAMETER LabViewCliDirectory
        Path to the LabVIEW CLI directory. Defaults to standard installation path.

    .EXAMPLE
        Set-LabViewForCi -LabViewDirectory "C:\Program Files\National Instruments\LabVIEW 2025"

    .EXAMPLE
        Set-LabViewForCi -LabViewDirectory "C:\Program Files\National Instruments\LabVIEW 2025" -LabViewCliDirectory "C:\Custom\LabVIEW CLI"

    .NOTES
        Modifies LabVIEW.ini and LabVIEWCLI.ini configuration files.
        Creates configuration entries if they don't exist.
        Requires write access to configuration files.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$LabViewDirectory,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$LabViewCliDirectory = "C:\Program Files (x86)\National Instruments\Shared\LabVIEW CLI"
    )
    
    begin {
        Write-Verbose "Starting Set-LabViewForCi operation"
    }
    
    process {
        try {
            if (-not (Test-Path -Path $LabViewDirectory)) {
                throw "LabVIEW directory not found: $LabViewDirectory"
            }

            $labviewConfigPath = Join-Path -Path $LabViewDirectory -ChildPath "LabVIEW.ini"
            $labViewCliConfigPath = Join-Path -Path $LabViewCliDirectory -ChildPath "LabVIEWCLI.ini"

            Write-Information "Configuring LabVIEW for CI/CD environment..." -InformationAction Continue

            # Enable TCP server for remote control
            Write-Verbose "Enabling TCP server on port 3363"
            Set-ConfigValue -ConfigPath $labviewConfigPath -Section "LabVIEW" -Key "server.tcp.enabled" -Value "True" -CreateIfNotExists
            Set-ConfigValue -ConfigPath $labviewConfigPath -Section "LabVIEW" -Key "server.tcp.port" -Value "3363" -CreateIfNotExists

            # Disable interactive licensing dialogs
            Write-Verbose "Disabling licensing dialogs"
            Set-ConfigValue -ConfigPath $labviewConfigPath -Section "LabVIEW" -Key "neverShowAddonLicensingStartup" -Value "True" -CreateIfNotExists
            Set-ConfigValue -ConfigPath $labviewConfigPath -Section "LabVIEW" -Key "neverShowLicensingStartupDialog" -Value "True" -CreateIfNotExists
            Set-ConfigValue -ConfigPath $labviewConfigPath -Section "LabVIEW" -Key "ShowWelcomeOnLaunch" -Value "False" -CreateIfNotExists

            # Configure CLI for automated operation
            Write-Verbose "Configuring LabVIEW CLI settings"
            Set-LabVIEWCLIConfig -ConfigPath $labViewCliConfigPath -Key "ValidateLabVIEWLicense" -Value "FALSE" -CreateIfNotExists
            
            Write-Information "LabVIEW CI/CD configuration completed successfully" -InformationAction Continue
        }
        catch {
            $errorMessage = "Failed to configure LabVIEW for CI. Error: $($_.Exception.Message)"
            Write-Error -Message $errorMessage -Category NotSpecified
            throw
        }
    }
    
    end {
        Write-Verbose "Completed Set-LabViewForCi operation"
    }
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
