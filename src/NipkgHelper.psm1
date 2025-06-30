#Requires -Version 5.1

<#
.SYNOPSIS
    NI Package Manager (NIPKG) Helper Module

.DESCRIPTION
    Provides comprehensive functions for managing National Instruments packages using NIPKG.
    Supports feed management, package installation, and package information retrieval.

.NOTES
    File Name      : NipkgHelper.psm1
    Author         : LabVIEW Helpers Team
    Prerequisite   : PowerShell 5.1 or higher, NIPKG installed
    Copyright 2025 : LabVIEW Helpers
#>

function Add-FeedDirectories {
    <#
    .SYNOPSIS
        Adds multiple directory feeds to NI Package Manager.

    .DESCRIPTION
        Scans a parent directory for subdirectories and adds each as a feed to NIPKG.
        Updates the package database after adding all feeds.

    .PARAMETER FeedsDirectory
        Path to the directory containing feed subdirectories.

    .PARAMETER NipkgCmdPath
        Path to the NIPKG command-line tool. Defaults to 'nipkg' if in PATH.

    .EXAMPLE
        Add-FeedDirectories -FeedsDirectory "C:\Installers\feeds"

    .EXAMPLE
        Add-FeedDirectories -FeedsDirectory "C:\feeds" -NipkgCmdPath "C:\Program Files\NI\nipkg.exe"

    .NOTES
        Each subdirectory in the FeedsDirectory will be added as a separate feed.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string]$FeedsDirectory,
        
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$NipkgCmdPath = "nipkg"    
    )

    begin {
        Write-Verbose "Starting Add-FeedDirectories operation"
    }
    
    process {
        try {
            if (-not (Test-Path -LiteralPath $FeedsDirectory)) {
                throw "Feeds directory not found: $FeedsDirectory"
            }

            $directories = Get-ChildItem -Path $FeedsDirectory -Directory -ErrorAction Stop

            if ($directories.Count -eq 0) {
                Write-Warning "No subdirectories found in: $FeedsDirectory"
                return
            }

            Write-Information "Adding $($directories.Count) feed directories..." -InformationAction Continue

            foreach ($dir in $directories) {
                if ($PSCmdlet.ShouldProcess($dir.FullName, "Add NIPKG feed")) {
                    Write-Verbose "Adding feed directory: $($dir.Name)"
                    Write-Information "Adding feed: $($dir.Name)" -InformationAction Continue
                    & $NipkgCmdPath feed-add "$($dir.FullName)"
                    
                    if ($LASTEXITCODE -ne 0) {
                        Write-Warning "Failed to add feed: $($dir.Name)"
                    }
                }
            }

            if ($PSCmdlet.ShouldProcess("NIPKG", "Update package database")) {
                Write-Information "Updating package database..." -InformationAction Continue
                & $NipkgCmdPath update
                
                if ($LASTEXITCODE -eq 0) {
                    Write-Information "Package database updated successfully" -InformationAction Continue
                } else {
                    Write-Warning "Package database update may have failed"
                }
            }
        }
        catch {
            $errorMessage = "Failed to add feed directories - Path: '$FeedsDirectory'. Error: $($_.Exception.Message)"
            Write-Error -Message $errorMessage -Category InvalidOperation -TargetObject $FeedsDirectory
            throw
        }
    }
    
    end {
        Write-Verbose "Completed Add-FeedDirectories operation"
    }
}

function Get-FeedsInfo {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [string]
        $NipkgCmdPath = "nipkg" 
    )

    $lines = & $NipkgCmdPath feed-list

    $results = foreach ($line in $lines) {
        $line = $line.Trim()

        if ($line -match '^(.*\S)\s+([a-zA-Z]:\\.*)$') {
            [PSCustomObject]@{
                Name = $matches[1]
                Path = $matches[2]
            }
        }
    }
    return $results
}

function Remove-Feeds {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [PSCustomObject]
        $FeedsInfo,
        [Parameter(Mandatory = $false)]
        [string]
        $NipkgCmdPath = "nipkg"    
    )
    foreach ($feed in $FeedsInfo) {
        Write-Host "Removing feed: $($feed.Name)"
        & $NipkgCmdPath feed-remove "$($feed.Name)"
    }
}



function Get-PackagesInfo {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateSet("installed", "available")]
        [string]
        $Type,
        [Parameter(Mandatory = $false)]
        [string]
        $NipkgCmdPath = "nipkg" 
    )

    $subCmd = if ($Type -eq "installed") { "info-installed" } else { "info" }
    $lines = & $NipkgCmdPath $subCmd
    # Variables to hold packages
    $packages = @()
    $currentPackage = @()
    $blankLineCount = 0

    foreach ($line in $lines) {
        if ([string]::IsNullOrWhiteSpace($line)) {
            # Increment count for blank lines
            $blankLineCount++
            # If 3 or more consecutive blank lines, start a new package block
            if ($blankLineCount -ge 3) {
                if ($currentPackage.Count -gt 0) {
                    $packages += ,@($currentPackage)
                    $currentPackage = @()
                }
                # Reset blank line count after splitting
                $blankLineCount = 0
            }
        }
        else {
            # Non-blank line, reset blank line count and add to current package
            $blankLineCount = 0
            $currentPackage += $line
        }
    }

    # Add last package if any lines remain
    if ($currentPackage.Count -gt 0) {
        $packages += ,@($currentPackage)
    }


    ## 🛠️ Step 3: Parse each package block into key-value pairs


    $parsedPackages = @()

    foreach ($packageLines in $packages) {
        $packageProps = @{}
        foreach ($line in $packageLines) {
            # Split on first colon
            $key, $value = $line -split ":\s*", 2
            if ($key -and $value) {
                $packageProps[$key] = $value
            }
        }
        $parsedPackages += [PSCustomObject]$packageProps
    }

    return $parsedPackages
}

function Get-DriverPackages {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [PSCustomObject]
        $PackagesInfo 
    )
    $filteredPackages = $PackagesInfo | Where-Object { $_.Section -eq "Drivers" }
    return $filteredPackages | Sort-Object Package
}

function Get-ProgrammingEnvironmentsPackages {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [PSCustomObject]
        $PackagesInfo 
    )
    $filteredPackages = $PackagesInfo | Where-Object { $_.Section -eq "Programming Environments" }
    return $filteredPackages | Sort-Object Package
}

function Get-UtilitiesPackages {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [PSCustomObject]
        $PackagesInfo 
    )
    $filteredPackages = $PackagesInfo | Where-Object { $_.Section -eq "Utilities" }
    return $filteredPackages | Sort-Object Package
}


function Get-ApplicationSoftwarePackages {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [PSCustomObject]
        $PackagesInfo 
    )
    $filteredPackages = $PackagesInfo | Where-Object { $_.Section -eq "Application Software" }
    return $filteredPackages | Sort-Object Package
}

function Install-NipkgManager {
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]
        $InstallerPath
    )

    # & $InstallerPath `
    #     --quiet `
    #     --accept-eulas `
    #     --prevent-reboot
    $timeout = 300000  # 5 minutes

    # Set up the process start info
    $process = New-Object System.Diagnostics.Process
    $process.StartInfo.FileName = $InstallerPath
    $process.StartInfo.Arguments = "--quiet --accept-eulas --prevent-reboot"
    $process.StartInfo.RedirectStandardOutput = $true
    $process.StartInfo.RedirectStandardError = $true
    $process.StartInfo.UseShellExecute = $false
    $process.StartInfo.CreateNoWindow = $false

    # Start the process
    $process.Start()

    # Wait for it to exit
    $process.WaitForExit($timeout)

    # Capture the exit code
    $exitCode = $process.ExitCode

    # Optionally capture output or error text
    $output = $process.StandardOutput.ReadToEnd()
    $errorOutput = $process.StandardError.ReadToEnd()

    # Display results
    Write-Host "Exit Code: $exitCode"
    Write-Host "Output: $output"
    Write-Host "Error Output: $errorOutput"
}

Export-ModuleMember -Function `
        Add-FeedDirectories `
    ,   Get-PackagesInfo `
    ,   Get-DriverPackages `
    ,   Get-ProgrammingEnvironmentsPackages `
    ,   Get-UtilitiesPackages `
    ,   Get-ApplicationSoftwarePackages `
    ,   Get-FeedsInfo `
    ,   Remove-Feeds `
    ,   Install-NipkgManager