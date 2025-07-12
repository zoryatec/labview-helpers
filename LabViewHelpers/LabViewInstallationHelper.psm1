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
                SyncNipkgVersion = $false
                ExcludePackages = $ExcludePackages
            }
            
            if ($RemoveExistingFeeds) {
                $applyParams.RemoveExistingFeeds = $false
            }
            
            if ($RemoveSnapshotFeeds) {
                $applyParams.RemoveSnapshotFeeds = $false
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

function Invoke-FileDownload {
    <#
    .SYNOPSIS
        Downloads a file from a URL with progress reporting.

    .DESCRIPTION
        Downloads a file from HTTP/HTTPS URL to a specified local path with progress reporting,
        timeout handling, and validation. Provides detailed progress information during download.

    .PARAMETER Url
        URL of the file to download.

    .PARAMETER OutputPath
        Local file path where the downloaded file will be saved.

    .PARAMETER TimeoutMinutes
        Download timeout in minutes. Defaults to 60 minutes.

    .PARAMETER MinimumFileSizeMB
        Minimum expected file size in MB for validation. Defaults to 1 MB.

    .EXAMPLE
        Invoke-FileDownload -Url "https://example.com/file.iso" -OutputPath "C:\temp\file.iso"

    .EXAMPLE
        Invoke-FileDownload -Url "https://example.com/large-file.iso" -OutputPath "C:\temp\file.iso" -TimeoutMinutes 120 -MinimumFileSizeMB 100

    .NOTES
        Requires internet connectivity and write access to the output directory.
        Progress is reported every 5 seconds during download.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Url,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$OutputPath,

        [Parameter()]
        [ValidateRange(1, 480)]
        [int]$TimeoutMinutes = 60,

        [Parameter()]
        [ValidateRange(0, [int]::MaxValue)]
        [int]$MinimumFileSizeMB = 1
    )
    
    begin {
        Write-Verbose "Starting Invoke-FileDownload operation"
    }
    
    process {
        try {
            # Validate URL format
            try {
                $uri = [System.Uri]$Url
                if (-not ($uri.Scheme -eq 'http' -or $uri.Scheme -eq 'https')) {
                    throw "URL must use HTTP or HTTPS protocol"
                }
            }
            catch {
                throw "Invalid URL format: $Url. Error: $($_.Exception.Message)"
            }
            
            # Create output directory if it doesn't exist
            $outputDirectory = [System.IO.Path]::GetDirectoryName($OutputPath)
            if (-not (Test-Path -Path $outputDirectory)) {
                Write-Information "Creating output directory: $outputDirectory" -InformationAction Continue
                New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
            }
            
            Write-Information "Starting file download..." -InformationAction Continue
            Write-Information "  Source: $Url" -InformationAction Continue
            Write-Information "  Destination: $OutputPath" -InformationAction Continue
            Write-Information "  Timeout: $TimeoutMinutes minutes" -InformationAction Continue
            
            # Download with progress reporting
            $webClient = New-Object System.Net.WebClient
            $webClient.Timeout = $TimeoutMinutes * 60 * 1000  # Convert to milliseconds
            
            # Register progress event
            Register-ObjectEvent -InputObject $webClient -EventName DownloadProgressChanged -Action {
                $Global:DownloadProgress = $Event.SourceEventArgs
            } | Out-Null
            
            try {
                # Start async download
                $downloadTask = $webClient.DownloadFileTaskAsync($Url, $OutputPath)
                
                # Monitor progress
                $lastReportTime = Get-Date
                while (-not $downloadTask.IsCompleted) {
                    Start-Sleep -Milliseconds 1000
                    
                    if ($Global:DownloadProgress -and ((Get-Date) - $lastReportTime).TotalSeconds -ge 5) {
                        $progress = $Global:DownloadProgress
                        $percentComplete = $progress.ProgressPercentage
                        $bytesReceived = $progress.BytesReceived
                        $totalBytes = $progress.TotalBytesToReceive
                        
                        $receivedMB = [math]::Round($bytesReceived / 1MB, 2)
                        $totalMB = [math]::Round($totalBytes / 1MB, 2)
                        
                        Write-Information "  Download progress: $percentComplete% ($receivedMB MB / $totalMB MB)" -InformationAction Continue
                        $lastReportTime = Get-Date
                    }
                    
                    # Check for timeout
                    if ($downloadTask.Wait(1000)) {
                        break
                    }
                }
                
                # Wait for completion and check result
                $downloadTask.Wait()
                if ($downloadTask.IsFaulted) {
                    throw "Download failed: $($downloadTask.Exception.InnerException.Message)"
                }
                
                Write-Information "Download completed successfully" -InformationAction Continue
                
                # Verify file exists and validate size
                if (-not (Test-Path -Path $OutputPath)) {
                    throw "Downloaded file not found at: $OutputPath"
                }
                
                $fileInfo = Get-Item -Path $OutputPath
                $fileSizeMB = [math]::Round($fileInfo.Length / 1MB, 2)
                Write-Information "  Downloaded file size: $fileSizeMB MB" -InformationAction Continue
                
                if ($fileInfo.Length -lt ($MinimumFileSizeMB * 1MB)) {
                    throw "Downloaded file appears to be too small (${fileSizeMB} MB, expected at least ${MinimumFileSizeMB} MB). This may indicate a download error."
                }
                
                return $OutputPath
            }
            finally {
                # Cleanup event registration and web client
                Get-EventSubscriber | Where-Object { $_.SourceObject -eq $webClient } | Unregister-Event
                $webClient.Dispose()
                Remove-Variable -Name DownloadProgress -Scope Global -ErrorAction SilentlyContinue
            }
        }
        catch {
            $errorMessage = "Failed to download file from URL. Error: $($_.Exception.Message)"
            Write-Error -Message $errorMessage -Category ConnectionError
            throw
        }
    }
    
    end {
        Write-Verbose "Completed Invoke-FileDownload operation"
    }
}

function Install-FromInstallerIsoWithDownload {
    <#
    .SYNOPSIS
        Downloads and installs LabVIEW from an ISO file URL.

    .DESCRIPTION
        Downloads a LabVIEW ISO file from a URL to a temporary directory and then performs
        offline installation using Install-LabViewIso. Provides progress reporting during
        download and handles cleanup of downloaded files.

    .PARAMETER IsoUrl
        URL of the LabVIEW ISO file to download and install.

    .PARAMETER NipkgCmdPath
        Path to the NIPKG command-line tool. Defaults to standard installation path.

    .PARAMETER NipkgInstallerPath
        Optional path to NIPKG installer if it needs to be installed first.

    .PARAMETER TemporaryDownloadDirectory
        Directory to download the ISO file. Defaults to system temp directory with unique subfolder.

    .PARAMETER TemporaryExpandDirectory
        Directory to temporarily extract ISO contents. Defaults to C:\installer-labview.

    .PARAMETER RemoveExistingFeeds
        Remove all existing feeds from the system before applying the installer feeds.

    .PARAMETER RemoveSnapshotFeeds
        Remove the installer feeds from the system after package installation is complete.

    .PARAMETER RemoveDownloadedFiles
        Remove the downloaded ISO file and download directory after installation completes.
        Defaults to $true to save disk space.

    .PARAMETER RemoveTemporaryDirectory
        Remove the temporary extraction directory after installation completes.

    .PARAMETER TimeoutMinutes
        Download timeout in minutes. Defaults to 60 minutes for large ISO files.

    .EXAMPLE
        Install-FromInstallerIsoWithDownload -IsoUrl "https://example.com/labview-2024.iso"

    .EXAMPLE
        Install-FromInstallerIsoWithDownload -IsoUrl "https://example.com/labview-2024.iso" -RemoveDownloadedFiles -RemoveTemporaryDirectory

    .EXAMPLE
        Install-FromInstallerIsoWithDownload -IsoUrl "https://example.com/labview-2024.iso" -TemporaryDownloadDirectory "D:\temp\downloads" -TimeoutMinutes 120

    .NOTES
        Requires administrative privileges and sufficient disk space for download and extraction.
        Large ISO files (40GB+) require significant temporary disk space.
        Progress reporting shows download progress and file sizes.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$IsoUrl,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$NipkgCmdPath = "C:\Program Files\National Instruments\NI Package Manager\nipkg.exe",
        
        [Parameter()]
        [string]$NipkgInstallerPath,

        [Parameter()]
        [string]$TemporaryDownloadDirectory,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$TemporaryExpandDirectory = "C:\installer-labview",

        [Parameter()]
        [switch]$RemoveExistingFeeds,

        [Parameter()]
        [switch]$RemoveSnapshotFeeds,

        [Parameter()]
        [switch]$RemoveDownloadedFiles = $true,

        [Parameter()]
        [switch]$RemoveTemporaryDirectory,

        [Parameter()]
        [ValidateRange(1, 480)]
        [int]$TimeoutMinutes = 60
    )
    
    begin {
        Write-Verbose "Starting Install-FromInstallerIsoWithDownload operation"
        
        # Generate unique temporary download directory if not provided
        if ([string]::IsNullOrEmpty($TemporaryDownloadDirectory)) {
            $tempGuid = [System.Guid]::NewGuid().ToString("N").Substring(0, 8)
            $TemporaryDownloadDirectory = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath "labview-iso-download-$tempGuid"
        }
    }
    
    process {
        $downloadedIsoPath = $null
        
        try {
            Write-Information "Starting LabVIEW installation from ISO URL: $IsoUrl" -InformationAction Continue
            
            # Create download directory
            if (-not (Test-Path -Path $TemporaryDownloadDirectory)) {
                Write-Information "Creating download directory: $TemporaryDownloadDirectory" -InformationAction Continue
                New-Item -ItemType Directory -Path $TemporaryDownloadDirectory -Force | Out-Null
            }
            
            # Generate ISO filename from URL
            $uri = [System.Uri]$IsoUrl
            $isoFileName = [System.IO.Path]::GetFileName($uri.LocalPath)
            if ([string]::IsNullOrEmpty($isoFileName) -or -not $isoFileName.EndsWith('.iso', [System.StringComparison]::OrdinalIgnoreCase)) {
                $isoFileName = "labview-installer-$(Get-Date -Format 'yyyyMMdd-HHmmss').iso"
                Write-Verbose "Generated ISO filename: $isoFileName"
            }
            
            $downloadedIsoPath = Join-Path -Path $TemporaryDownloadDirectory -ChildPath $isoFileName
            
            Write-Information "Step 1: Downloading ISO file..." -InformationAction Continue
            
            # Download the ISO file using the dedicated download function
            $downloadedIsoPath = Invoke-FileDownload -Url $IsoUrl -OutputPath $downloadedIsoPath -TimeoutMinutes $TimeoutMinutes -MinimumFileSizeMB 1
            
            Write-Information "Step 2: Installing LabVIEW from downloaded ISO..." -InformationAction Continue
            
            # Build parameters for Install-LabViewIso
            $installParams = @{
                NipkgCmdPath = $NipkgCmdPath
                IsoFilePath = $downloadedIsoPath
                TemporaryExpandDirectory = $TemporaryExpandDirectory
                RemoveIsoFile = $RemoveDownloadedFiles  # Remove ISO after extraction if cleanup requested
                RemoveTemporaryDirectory = $RemoveTemporaryDirectory
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
            
            # Install using existing function
            Install-LabViewIso @installParams
            
            Write-Information "LabVIEW installation from downloaded ISO completed successfully" -InformationAction Continue
        }
        catch {
            $errorMessage = "Failed to download and install LabVIEW from ISO URL. Error: $($_.Exception.Message)"
            Write-Error -Message $errorMessage -Category NotInstalled
            throw
        }
        finally {
            # Perform cleanup operations if requested
            if ($RemoveDownloadedFiles) {
                Write-Verbose "Performing download cleanup operations..."
                
                # Remove downloaded ISO file if it still exists
                if ($downloadedIsoPath -and (Test-Path $downloadedIsoPath)) {
                    try {
                        Write-Information "Removing downloaded ISO file: $downloadedIsoPath" -InformationAction Continue
                        Remove-Item -Path $downloadedIsoPath -Force
                        Write-Verbose "Successfully removed downloaded ISO file"
                    }
                    catch {
                        Write-Warning "Failed to remove downloaded ISO file: $($_.Exception.Message)"
                    }
                }
                
                # Remove download directory if empty
                if ((Test-Path $TemporaryDownloadDirectory)) {
                    try {
                        $remainingFiles = Get-ChildItem -Path $TemporaryDownloadDirectory -Force
                        if ($remainingFiles.Count -eq 0) {
                            Write-Information "Removing empty download directory: $TemporaryDownloadDirectory" -InformationAction Continue
                            Remove-Item -Path $TemporaryDownloadDirectory -Force
                            Write-Verbose "Successfully removed download directory"
                        }
                        else {
                            Write-Verbose "Download directory not empty, keeping: $TemporaryDownloadDirectory"
                        }
                    }
                    catch {
                        Write-Warning "Failed to remove download directory: $($_.Exception.Message)"
                    }
                }
            }
            elseif ($downloadedIsoPath -and (Test-Path $downloadedIsoPath)) {
                Write-Verbose "Downloaded ISO file remains at: $downloadedIsoPath"
            }
        }
    }
    
    end {
        Write-Verbose "Completed Install-FromInstallerIsoWithDownload operation"
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
    ,   Invoke-FileDownload `
    ,   Install-FromInstallerIsoWithDownload `
    ,   Set-LabViewForCi
