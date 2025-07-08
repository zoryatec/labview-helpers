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

    .PARAMETER InstallationSnapshotFile
        Optional path to save the installation snapshot file.

    .PARAMETER RemoveExistingFeeds
        Remove all existing feeds from the system before applying the installer feeds.

    .PARAMETER RemoveSnapshotFeeds
        Remove the installer feeds from the system after package installation is complete.
        This is useful when you want to install packages from the installer but don't want
        to keep those feeds permanently in the system.

    .PARAMETER ExcludePackages
        Array of package names to exclude from installation. These packages will be skipped even 
        if they are present in the installer snapshot. Useful for avoiding problematic packages 
        or when certain packages should not be installed in specific environments.

    .EXAMPLE
        Install-LabViewOffline -LabViewInstallerDirectory "C:\installers\labview"

    .EXAMPLE
        Install-LabViewOffline -LabViewInstallerDirectory "C:\installers\labview" -NipkgInstallerPath "C:\installers\nipkg\Install.exe"

    .EXAMPLE
        Install-LabViewOffline -LabViewInstallerDirectory "C:\installers\labview" -RemoveSnapshotFeeds

    .EXAMPLE
        Install-LabViewOffline -LabViewInstallerDirectory "C:\installers\labview" -RemoveExistingFeeds -RemoveSnapshotFeeds

    .EXAMPLE
        Install-LabViewOffline -LabViewInstallerDirectory "C:\installers\labview" -ExcludePackages @("problematic-package", "optional-driver")

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
        [string]$NipkgInstallerPath,

        [Parameter()]
        [string]$InstallationSnapshotFile,

        [Parameter()]
        [switch]$RemoveExistingFeeds,

        [Parameter()]
        [switch]$RemoveSnapshotFeeds,

        [Parameter()]
        [string[]]$ExcludePackages = @()
    )
    
    begin {
        Write-Verbose "Starting Install-LabViewOffline operation"
    }
    
    process {
        try {
            if (-not (Test-Path -Path $LabViewInstallerDirectory)) {
                throw "LabVIEW installer directory not found: $LabViewInstallerDirectory"
            }


            if ($NipkgInstallerPath -and (Test-Path -Path $NipkgInstallerPath)) {
                Write-Information "Installing NIPKG manager first..." -InformationAction Continue
                Install-NipkgManager -InstallerPath $NipkgInstallerPath
            }

            if ([string]::IsNullOrEmpty($InstallationSnapshotFile)) {
                $InstallationSnapshotFile  =  New-TemporaryFile 
            }
            $installerSnapshot = New-NipkgSnapshotFromInstaller -InstallerDirectory $LabViewInstallerDirectory -Verbose
            Export-NipkgSnapshotToJson -Snapshot $installerSnapshot -OutputPath $InstallationSnapshotFile -Verbose
            
            # Build parameters for Apply-NipkgSnapshot
            $applyParams = @{
                SnapshotPath = $InstallationSnapshotFile
                NipkgCmdPath = $NipkgCmdPath
                Verbose = $true
                ValidateCompliance = $true
                UseBatchInstallation = $true
                SyncNipkgVersion = $true
                ExcludePackages = $ExcludePackages
            }
            
            if ($RemoveExistingFeeds) {
                $applyParams.RemoveExistingFeeds = $true
            }
            
            if ($RemoveSnapshotFeeds) {
                $applyParams.RemoveSnapshotFeeds = $true
            }
            
            Apply-NipkgSnapshot @applyParams

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

    .PARAMETER RemoveExistingFeeds
        Remove all existing feeds from the system before applying the installer feeds.

    .PARAMETER RemoveSnapshotFeeds
        Remove the installer feeds from the system after package installation is complete.
        This is useful when you want to install packages from the installer but don't want
        to keep those feeds permanently in the system.

    .PARAMETER RemoveIsoFile
        Remove the ISO file immediately after successful extraction to free up disk space.
        This is especially useful for large ISO files (40GB+) to prevent disk space issues.

    .PARAMETER RemoveTemporaryDirectory
        Remove the temporary extraction directory after installation completes.
        This happens regardless of installation success or failure.

    .EXAMPLE
        Install-LabViewIso -IsoFilePath "C:\labview.iso"

    .EXAMPLE
        Install-LabViewIso -IsoFilePath "C:\labview.iso" -NipkgInstallerPath "C:\nipkg\Install.exe" -TemporaryExpandDirectory "D:\temp"

    .EXAMPLE
        Install-LabViewIso -IsoFilePath "C:\labview.iso" -RemoveSnapshotFeeds

    .EXAMPLE
        Install-LabViewIso -IsoFilePath "C:\labview.iso" -RemoveExistingFeeds -RemoveSnapshotFeeds

    .EXAMPLE
        Install-LabViewIso -IsoFilePath "C:\labview.iso" -RemoveIsoFile -RemoveTemporaryDirectory

    .EXAMPLE
        Install-LabViewIso -IsoFilePath "C:\labview.iso" -RemoveExistingFeeds -RemoveSnapshotFeeds -RemoveIsoFile -RemoveTemporaryDirectory

    .NOTES
        Requires administrative privileges and sufficient disk space for extraction.
        Temporary directory will be created if it doesn't exist.
        Cleanup operations in finally block ensure temporary files are removed even on failure.
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
        [string]$TemporaryExpandDirectory = "C:\installer-labview",

        [Parameter()]
        [switch]$RemoveExistingFeeds,

        [Parameter()]
        [switch]$RemoveSnapshotFeeds,

        [Parameter()]
        [switch]$RemoveIsoFile,

        [Parameter()]
        [switch]$RemoveTemporaryDirectory
    )
    
    begin {
        Write-Verbose "Starting Install-LabViewIso operation"
    }
    
    process {
        try {
            Write-Information "Starting LabVIEW installation from ISO: $IsoFilePath" -InformationAction Continue
            
            Write-Information "Step 1: Extracting ISO file..." -InformationAction Continue
            Expand-Iso -IsoFilePath $IsoFilePath -OutputDirectoryPath $TemporaryExpandDirectory

            # Remove ISO file immediately after extraction if requested to free up disk space
            if ($RemoveIsoFile -and (Test-Path $IsoFilePath)) {
                try {
                    Write-Information "Removing ISO file to free up disk space: $IsoFilePath" -InformationAction Continue
                    Remove-Item -Path $IsoFilePath -Force
                    Write-Verbose "Successfully removed ISO file after extraction"
                }
                catch {
                    Write-Warning "Failed to remove ISO file after extraction: $($_.Exception.Message)"
                }
            }

            Write-Information "Step 2: Installing LabVIEW from extracted files..." -InformationAction Continue
            
            # Build parameters for Install-LabViewOffline
            $installParams = @{
                NipkgCmdPath = $NipkgCmdPath
                LabViewInstallerDirectory = $TemporaryExpandDirectory
            }
            
            if ($NipkgInstallerPath) {
                $installParams.NipkgInstallerPath = $NipkgInstallerPath
            }
            
            if ($RemoveExistingFeeds) {
                $installParams.RemoveExistingFeeds = $true
            }
            
            if ($RemoveSnapshotFeeds) {
                $installParams.RemoveSnapshotFeeds = $true
            }
            
            Install-LabViewOffline @installParams
            
            Write-Information "LabVIEW ISO installation completed successfully" -InformationAction Continue
        }
        catch {
            $errorMessage = "Failed to install LabVIEW from ISO. Error: $($_.Exception.Message)"
            Write-Error -Message $errorMessage -Category NotInstalled
            throw
        }
        finally {
            # Perform cleanup operations if requested
            Write-Verbose "Performing cleanup operations..."
            
            # Remove temporary directory if requested
            if ($RemoveTemporaryDirectory -and (Test-Path $TemporaryExpandDirectory)) {
                try {
                    Write-Information "Removing temporary directory: $TemporaryExpandDirectory" -InformationAction Continue
                    Remove-Item -Path $TemporaryExpandDirectory -Recurse -Force
                    Write-Verbose "Successfully removed temporary directory"
                }
                catch {
                    Write-Warning "Failed to remove temporary directory: $($_.Exception.Message)"
                }
            }
            elseif (Test-Path $TemporaryExpandDirectory) {
                Write-Verbose "Temporary directory remains at: $TemporaryExpandDirectory"
            }
            
            # Remove ISO file if it still exists (in case extraction failed and RemoveIsoFile was requested)
            if ($RemoveIsoFile -and (Test-Path $IsoFilePath)) {
                try {
                    Write-Information "Removing remaining ISO file: $IsoFilePath" -InformationAction Continue
                    Remove-Item -Path $IsoFilePath -Force
                    Write-Verbose "Successfully removed remaining ISO file"
                }
                catch {
                    Write-Warning "Failed to remove remaining ISO file: $($_.Exception.Message)"
                }
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
    ,   Expand-Iso `
    ,   Install-LabViewIso `
    ,   Set-LabViewForCi
