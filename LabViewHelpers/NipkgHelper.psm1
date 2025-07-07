#Requires -Version 5.1

<#
.SYNOPSIS
    NI Package Manager (NIPKG) Helper Module

.DESCRIPTION
    Provides comprehensive functions for managing National Instruments packages using NIPKG.
    Supports feed management, package installation, and package information retrieval.
    
    ARCHITECTURE:
    The module uses a modular approach for package information retrieval:
    - Get-NipkgCommandOutput: Executes NIPKG commands and returns raw output
    - ConvertFrom-NipkgOutput: Parses raw NIPKG command output (3+ blank line separators)
    - ConvertFrom-NipkgPackagesFile: Parses NIPKG Packages files (single blank line separators)
    - Get-PackagesInfoFromNipkgCmd: Convenience function combining command execution and parsing
    - Get-PackagesInfoFromPackagesFile: Parses NIPKG feed Packages files
    - New-NipkgSnapshotFromInstaller: Creates snapshots from installer directory structures
    - New-NipkgSnapshotFromSystem: Creates snapshots from current system state
    
    This separation allows for flexible data sources and easier testing.

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

function Get-FeedsInfoFromNipkgCmd {
    <#
    .SYNOPSIS
        Retrieves information about configured NIPKG feeds.

    .DESCRIPTION
        Gets a list of all currently configured package feeds from NI Package Manager,
        including feed names and their associated paths. Can filter feeds by type (local vs online).

    .PARAMETER NipkgCmdPath
        Path to the NIPKG command-line tool. Defaults to 'nipkg' if in PATH.

    .PARAMETER ExcludeLocalFeeds
        Exclude local file system feeds from the results. Only online feeds will be returned.

    .PARAMETER ExcludeOnlineFeeds
        Exclude online feeds from the results. Only local file system feeds will be returned.

    .EXAMPLE
        Get-FeedsInfoFromNipkgCmd

    .EXAMPLE
        Get-FeedsInfoFromNipkgCmd -NipkgCmdPath "C:\Program Files\NI\nipkg.exe"

    .EXAMPLE
        # Get only online feeds
        Get-FeedsInfoFromNipkgCmd -ExcludeLocalFeeds

    .EXAMPLE
        # Get only local feeds
        Get-FeedsInfoFromNipkgCmd -ExcludeOnlineFeeds

    .NOTES
        Returns PSCustomObject with Name, Path, and Type properties for each feed.
        Feed types are determined as follows:
        - Local: file:// paths or local file system paths (C:\, D:\, etc.)
        - Online: http://, https://, ftp://, or other network protocols
        
        If neither ExcludeLocalFeeds nor ExcludeOnlineFeeds is specified, all feeds are returned.
    #>
    [CmdletBinding()]
    param (
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$NipkgCmdPath = "nipkg",

        [Parameter()]
        [switch]$ExcludeLocalFeeds,

        [Parameter()]
        [switch]$ExcludeOnlineFeeds
    )

    begin {
        Write-Verbose "Starting Get-FeedsInfoFromNipkgCmd operation"
        
        # Validate parameter combination
        if ($ExcludeLocalFeeds -and $ExcludeOnlineFeeds) {
            throw "Cannot exclude both local and online feeds. Please specify only one exclusion parameter or none."
        }
    }

    process {
        try {
            Write-Verbose "Executing NIPKG feed-list command"
            $lines = & $NipkgCmdPath feed-list

            if ($LASTEXITCODE -ne 0) {
                throw "NIPKG feed-list command failed with exit code: $LASTEXITCODE"
            }

            $allResults = @()
            
            foreach ($line in $lines) {
                $line = $line.Trim()

                # Parse feed lines - handle both local paths and URIs
                if ($line -match '^(.*\S)\s+(.+)$') {
                    $feedName = $matches[1].Trim()
                    $feedPath = $matches[2].Trim()
                    
                    # Determine feed type based on path
                    $feedType = if (Test-FeedIsLocal -FeedPath $feedPath) { "Local" } else { "Online" }
                    
                    $feedObj = [PSCustomObject]@{
                        Name = $feedName
                        Path = $feedPath
                        Type = $feedType
                    }
                    
                    $allResults += $feedObj
                    
                    Write-Verbose "Found feed: $feedName ($feedType) -> $feedPath"
                }
            }

            Write-Verbose "Retrieved $($allResults.Count) total feeds from NIPKG"

            # Apply filtering based on parameters
            $filteredResults = $allResults
            
            if ($ExcludeLocalFeeds) {
                $filteredResults = $filteredResults | Where-Object { $_.Type -eq "Online" }
                Write-Verbose "Filtered to $($filteredResults.Count) online feeds (excluded local)"
            }
            elseif ($ExcludeOnlineFeeds) {
                $filteredResults = $filteredResults | Where-Object { $_.Type -eq "Local" }
                Write-Verbose "Filtered to $($filteredResults.Count) local feeds (excluded online)"
            }
            else {
                Write-Verbose "Returning all $($filteredResults.Count) feeds (no filtering applied)"
            }

            return $filteredResults
        }
        catch {
            $errorMessage = "Failed to retrieve feeds information from NIPKG. Error: $($_.Exception.Message)"
            Write-Error -Message $errorMessage -Category InvalidOperation -TargetObject $NipkgCmdPath
            throw
        }
    }

    end {
        Write-Verbose "Completed Get-FeedsInfoFromNipkgCmd operation"
    }
}

function Remove-Feeds {
    <#
    .SYNOPSIS
        Removes specified feeds from NI Package Manager.

    .DESCRIPTION
        Removes one or more package feeds from NIPKG configuration based on provided feed information.

    .PARAMETER FeedsInfo
        PSCustomObject containing feed information with Name and Path properties.

    .PARAMETER NipkgCmdPath
        Path to the NIPKG command-line tool. Defaults to 'nipkg' if in PATH.

    .EXAMPLE
        $feeds = Get-FeedsInfoFromNipkgCmd
        Remove-Feeds -FeedsInfo $feeds

    .EXAMPLE
        Remove-Feeds -FeedsInfo $feedsToRemove -NipkgCmdPath "C:\Program Files\NI\nipkg.exe"

    .NOTES
        Use Get-FeedsInfoFromNipkgCmd to get the required FeedsInfo object.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateNotNull()]
        [PSCustomObject]$FeedsInfo,
        
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$NipkgCmdPath = "nipkg"    
    )
    
    begin {
        Write-Verbose "Starting Remove-Feeds operation"
    }
    
    process {
        try {
            foreach ($feed in $FeedsInfo) {
                if ($PSCmdlet.ShouldProcess($feed.Name, "Remove NIPKG feed")) {
                    Write-Verbose "Removing feed: $($feed.Name)"
                    Write-Information "Removing feed: $($feed.Name)" -InformationAction Continue
                    & $NipkgCmdPath feed-remove "$($feed.Name)"
                    
                    if ($LASTEXITCODE -ne 0) {
                        Write-Warning "Failed to remove feed: $($feed.Name)"
                    }
                }
            }
        }
        catch {
            Write-Error "Failed to remove feeds: $_"
            throw
        }
    }
    
    end {
        Write-Verbose "Completed Remove-Feeds operation"
    }
}



function Get-NipkgCommandOutput {
    <#
    .SYNOPSIS
        Executes NIPKG command and returns raw output lines.

    .DESCRIPTION
        Executes the specified NIPKG command and returns the raw output as an array of lines.
        This function handles only command execution, not parsing.

    .PARAMETER Type
        Specifies whether to get 'installed' or 'available' packages.

    .PARAMETER NipkgCmdPath
        Path to the NIPKG command-line tool. Defaults to 'nipkg' if in PATH.

    .EXAMPLE
        $output = Get-NipkgCommandOutput -Type "installed"

    .EXAMPLE
        $output = Get-NipkgCommandOutput -Type "available" -NipkgCmdPath "C:\Program Files\NI\nipkg.exe"

    .NOTES
        Returns an array of strings representing the raw command output.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateSet("installed", "available")]
        [string]$Type,
        
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$NipkgCmdPath = "nipkg" 
    )

    begin {
        Write-Verbose "Starting Get-NipkgCommandOutput operation"
        
        # Check if NIPKG command is available
        try {
            $null = Get-Command $NipkgCmdPath -ErrorAction Stop
        }
        catch {
            throw "NIPKG command not found: $NipkgCmdPath. Please ensure NI Package Manager is installed and accessible."
        }
    }
    
    process {
        try {
            $subCmd = if ($Type -eq "installed") { "info-installed" } else { "info" }
            Write-Verbose "Executing NIPKG command: $NipkgCmdPath $subCmd"
            
            $lines = & $NipkgCmdPath $subCmd
            
            # Handle empty or null output
            if (-not $lines) {
                Write-Warning "NIPKG command returned no output"
                return @()
            }
            
            # Ensure we have an array and filter out any null/empty entries that might cause binding issues
            $filteredLines = @()
            foreach ($line in $lines) {
                if ($null -ne $line) {
                    $filteredLines += $line.ToString()
                }
            }
            
            if ($filteredLines.Count -eq 0) {
                Write-Warning "No valid output lines after filtering"
                return @()
            }
            
            Write-Verbose "Command executed successfully, returned $($filteredLines.Count) valid lines"
            
            return $filteredLines
        }
        catch {
            $errorMessage = "Failed to execute NIPKG command - Type: '$Type', Command: '$NipkgCmdPath'. Error: $($_.Exception.Message)"
            Write-Error -Message $errorMessage -Category InvalidOperation -TargetObject $Type
            throw
        }
    }
    
    end {
        Write-Verbose "Completed Get-NipkgCommandOutput operation"
    }
}

function ConvertFrom-NipkgOutput {
    <#
    .SYNOPSIS
        Parses NIPKG command output into structured package information.

    .DESCRIPTION
        Takes raw NIPKG command output lines and parses them into structured PSCustomObjects
        containing package properties. Handles package separation and key-value parsing.

    .PARAMETER OutputLines
        Array of strings representing the raw NIPKG command output.

    .EXAMPLE
        $output = Get-NipkgCommandOutput -Type "installed"
        $packages = ConvertFrom-NipkgOutput -OutputLines $output

    .EXAMPLE
        $lines = @("Package: example", "Version: 1.0.0", "", "", "", "Package: another", "Version: 2.0.0")
        $packages = ConvertFrom-NipkgOutput -OutputLines $lines

    .NOTES
        Returns an array of PSCustomObjects with package properties parsed from the output.
        Uses 3+ consecutive blank lines as package separators.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [AllowEmptyCollection()]
        [AllowEmptyString()]
        [string[]]$OutputLines
    )

    begin {
        Write-Verbose "Starting ConvertFrom-NipkgOutput operation"
    }
    
    process {
        try {
            # Handle empty input
            if (-not $OutputLines -or $OutputLines.Count -eq 0) {
                Write-Warning "No output lines provided for parsing"
                return @()
            }
            
            # Variables to hold packages
            $packages = @()
            $currentPackage = @()
            $blankLineCount = 0

            Write-Verbose "Processing $($OutputLines.Count) output lines"

            foreach ($line in $OutputLines) {
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

            Write-Verbose "Split output into $($packages.Count) package blocks"

            # Parse each package block into key-value pairs
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
                if ($packageProps.Count -gt 0) {
                    $parsedPackages += [PSCustomObject]$packageProps
                }
            }

            Write-Verbose "Parsed $($parsedPackages.Count) packages from output"
            return $parsedPackages
        }
        catch {
            $errorMessage = "Failed to parse NIPKG output. Error: $($_.Exception.Message)"
            Write-Error -Message $errorMessage -Category InvalidData -TargetObject $OutputLines
            throw
        }
    }
    
    end {
        Write-Verbose "Completed ConvertFrom-NipkgOutput operation"
    }
}

function ConvertFrom-NipkgPackagesFile {
    <#
    .SYNOPSIS
        Parses NIPKG Packages file content into structured package information.

    .DESCRIPTION
        Takes content from NIPKG Packages files and parses it into structured PSCustomObjects.
        This function is specifically designed for NIPKG feed Packages files which use single
        blank line separation between packages (unlike command output which uses 3+ blank lines).

    .PARAMETER OutputLines
        Array of strings representing the content from a NIPKG Packages file.

    .EXAMPLE
        $lines = Get-Content "Packages" -Encoding UTF8
        $packages = ConvertFrom-NipkgPackagesFile -OutputLines $lines

    .NOTES
        Returns an array of PSCustomObjects with package properties parsed from the file content.
        Uses single blank lines as package separators (NIPKG feed file format).
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [AllowEmptyCollection()]
        [AllowEmptyString()]
        [string[]]$OutputLines
    )

    begin {
        Write-Verbose "Starting ConvertFrom-NipkgPackagesFile operation"
    }
    
    process {
        try {
            # Handle empty input
            if (-not $OutputLines -or $OutputLines.Count -eq 0) {
                Write-Warning "No output lines provided for parsing"
                return @()
            }
            
            # Variables to hold packages
            $packages = @()
            $currentPackage = @()

            Write-Verbose "Processing $($OutputLines.Count) output lines"

            foreach ($line in $OutputLines) {
                if ([string]::IsNullOrWhiteSpace($line)) {
                    # Single blank line indicates end of package block in Packages files
                    if ($currentPackage.Count -gt 0) {
                        $packages += ,@($currentPackage)
                        $currentPackage = @()
                    }
                }
                else {
                    # Non-blank line, add to current package
                    $currentPackage += $line
                }
            }

            # Add last package if any lines remain
            if ($currentPackage.Count -gt 0) {
                $packages += ,@($currentPackage)
            }

            Write-Verbose "Split output into $($packages.Count) package blocks"

            # Parse each package block into key-value pairs
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
                if ($packageProps.Count -gt 0) {
                    $parsedPackages += [PSCustomObject]$packageProps
                }
            }

            Write-Verbose "Parsed $($parsedPackages.Count) packages from Packages file"
            return $parsedPackages
        }
        catch {
            $errorMessage = "Failed to parse NIPKG Packages file content. Error: $($_.Exception.Message)"
            Write-Error -Message $errorMessage -Category InvalidData -TargetObject $OutputLines
            throw
        }
    }
    
    end {
        Write-Verbose "Completed ConvertFrom-NipkgPackagesFile operation"
    }
}

function Get-PackagesInfoFromNipkgCmd {
    <#
    .SYNOPSIS
        Retrieves package information from NI Package Manager.

    .DESCRIPTION
        Gets detailed information about either installed or available packages from NIPKG,
        parsing the output into structured PSCustomObject format. This function combines
        command execution and output parsing for convenience.

    .PARAMETER Type
        Specifies whether to get 'installed' or 'available' packages.

    .PARAMETER NipkgCmdPath
        Path to the NIPKG command-line tool. Defaults to 'nipkg' if in PATH.

    .EXAMPLE
        Get-PackagesInfoFromNipkgCmd -Type "installed"

    .EXAMPLE
        Get-PackagesInfoFromNipkgCmd -Type "available" -NipkgCmdPath "C:\Program Files\NI\nipkg.exe"

    .NOTES
        Returns an array of PSCustomObjects with package properties parsed from NIPKG output.
        This function is a convenience wrapper around Get-NipkgCommandOutput and ConvertFrom-NipkgOutput.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateSet("installed", "available")]
        [string]$Type,
        
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$NipkgCmdPath = "nipkg" 
    )

    begin {
        Write-Verbose "Starting Get-PackagesInfoFromNipkgCmd operation"
    }
    
    process {
        try {
            # Get raw command output
            $outputLines = Get-NipkgCommandOutput -Type $Type -NipkgCmdPath $NipkgCmdPath
            
            # Handle empty output
            if (-not $outputLines -or $outputLines.Count -eq 0) {
                Write-Warning "No package information available for type: $Type"
                return @()
            }
            
            # Parse the output into structured format
            $parsedPackages = ConvertFrom-NipkgOutput -OutputLines $outputLines
            
            Write-Verbose "Retrieved and parsed $($parsedPackages.Count) packages"
            return $parsedPackages
        }
        catch {
            $errorMessage = "Failed to get packages info - Type: '$Type'. Error: $($_.Exception.Message)"
            Write-Error -Message $errorMessage -Category InvalidOperation -TargetObject $Type
            throw
        }
    }
    
    end {
        Write-Verbose "Completed Get-PackagesInfoFromNipkgCmd operation"
    }
}

function Get-PackagesInfoFromPackagesFile {
    <#
    .SYNOPSIS
        Retrieves package information from a NIPKG Packages file.

    .DESCRIPTION
        Reads and parses a NIPKG Packages file (typically found in feeds) and converts it into 
        structured PSCustomObject format. This file format is the same as NIPKG command output
        but stored in a file, commonly used in NIPKG feeds and repositories.

    .PARAMETER InputPath
        Path to the NIPKG Packages file to parse.

    .EXAMPLE
        Get-PackagesInfoFromPackagesFile -InputPath "C:\feeds\my-feed\Packages"

    .EXAMPLE
        $packages = Get-PackagesInfoFromPackagesFile -InputPath ".\test-data\Packages"
        $packages | Where-Object { $_.Section -eq "Programming Environments" }

    .NOTES
        Returns an array of PSCustomObjects with package properties parsed from the NIPKG Packages file.
        The file format is the same as 'nipkg info' command output, with packages separated by blank lines
        and properties in key: value format.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string]$InputPath
    )

    begin {
        Write-Verbose "Starting Get-PackagesInfoFromPackagesFile operation"
    }
    
    process {
        try {
            # Validate input file exists
            if (-not (Test-Path -Path $InputPath)) {
                throw "NIPKG Packages file not found: $InputPath"
            }

            Write-Information "Reading NIPKG Packages file..." -InformationAction Continue
            Write-Verbose "Reading file: $InputPath"
            
            # Read file content as array of lines
            $outputLines = Get-Content -Path $InputPath -Encoding UTF8
            Write-Verbose "Read $($outputLines.Count) lines from NIPKG Packages file"
            
            # Parse the output using the specialized Packages file parser
            $parsedPackages = ConvertFrom-NipkgPackagesFile -OutputLines $outputLines
            
            Write-Information "Parsed packages from NIPKG file successfully: $InputPath" -InformationAction Continue
            Write-Verbose "Parsed $($parsedPackages.Count) packages from NIPKG Packages file"
            
            return $parsedPackages
        }
        catch {
            $errorMessage = "Failed to get packages info from NIPKG file - InputPath: '$InputPath'. Error: $($_.Exception.Message)"
            Write-Error -Message $errorMessage -Category InvalidOperation -TargetObject $InputPath
            throw
        }
    }
    
    end {
        Write-Verbose "Completed Get-PackagesInfoFromPackagesFile operation"
    }
}

function Get-DriverPackages {
    <#
    .SYNOPSIS
        Filters package information to return only driver packages.

    .DESCRIPTION
        Filters the provided package information to include only packages in the "Drivers" section.

    .PARAMETER PackagesInfo
        PSCustomObject array containing package information from Get-PackagesInfoFromNipkgCmd.

    .EXAMPLE
        $packages = Get-PackagesInfoFromNipkgCmd -Type "installed"
        Get-DriverPackages -PackagesInfo $packages

    .NOTES
        Returns filtered and sorted package list containing only driver packages.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateNotNull()]
        [PSCustomObject]$PackagesInfo 
    )
    $filteredPackages = $PackagesInfo | Where-Object { $_.Section -eq "Drivers" }
    return $filteredPackages | Sort-Object Package
}

function Get-ProgrammingEnvironmentsPackages {
    <#
    .SYNOPSIS
        Filters package information to return only programming environment packages.

    .DESCRIPTION
        Filters the provided package information to include only packages in the "Programming Environments" section.

    .PARAMETER PackagesInfo
        PSCustomObject array containing package information from Get-PackagesInfoFromNipkgCmd.

    .EXAMPLE
        $packages = Get-PackagesInfoFromNipkgCmd -Type "available"
        Get-ProgrammingEnvironmentsPackages -PackagesInfo $packages

    .NOTES
        Returns filtered and sorted package list containing only programming environment packages.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateNotNull()]
        [PSCustomObject]$PackagesInfo 
    )
    $filteredPackages = $PackagesInfo | Where-Object { $_.Section -eq "Programming Environments" }
    return $filteredPackages | Sort-Object Package
}

function Get-UtilitiesPackages {
    <#
    .SYNOPSIS
        Filters package information to return only utility packages.

    .DESCRIPTION
        Filters the provided package information to include only packages in the "Utilities" section.

    .PARAMETER PackagesInfo
        PSCustomObject array containing package information from Get-PackagesInfoFromNipkgCmd.

    .EXAMPLE
        $packages = Get-PackagesInfoFromNipkgCmd -Type "installed"
        Get-UtilitiesPackages -PackagesInfo $packages

    .NOTES
        Returns filtered and sorted package list containing only utility packages.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateNotNull()]
        [PSCustomObject]$PackagesInfo 
    )
    $filteredPackages = $PackagesInfo | Where-Object { $_.Section -eq "Utilities" }
    return $filteredPackages | Sort-Object Package
}


function Get-ApplicationSoftwarePackages {
    <#
    .SYNOPSIS
        Filters package information to return only application software packages.

    .DESCRIPTION
        Filters the provided package information to include only packages in the "Application Software" section.

    .PARAMETER PackagesInfo
        PSCustomObject array containing package information from Get-PackagesInfoFromNipkgCmd.

    .EXAMPLE
        $packages = Get-PackagesInfoFromNipkgCmd -Type "available"
        Get-ApplicationSoftwarePackages -PackagesInfo $packages

    .NOTES
        Returns filtered and sorted package list containing only application software packages.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateNotNull()]
        [PSCustomObject]$PackagesInfo 
    )
    $filteredPackages = $PackagesInfo | Where-Object { $_.Section -eq "Application Software" }
    return $filteredPackages | Sort-Object Package
}

function Install-NipkgManager {
    <#
    .SYNOPSIS
        Installs NI Package Manager using provided installer.

    .DESCRIPTION
        Executes the NI Package Manager installer with quiet installation parameters,
        accepting EULAs and preventing reboots during installation.

    .PARAMETER InstallerPath
        Path to the NI Package Manager installer executable.

    .EXAMPLE
        Install-NipkgManager -InstallerPath "C:\Installers\nipkg-manager.exe"

    .NOTES
        Installation runs with timeout of 5 minutes and captures exit codes and output.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string]$InstallerPath
    )

    begin {
        Write-Verbose "Starting Install-NipkgManager operation"
    }
    
    process {
        try {
            if (-not (Test-Path -Path $InstallerPath)) {
                throw "Installer not found: $InstallerPath"
            }

            if ($PSCmdlet.ShouldProcess($InstallerPath, "Install NI Package Manager")) {
                Write-Information "Installing NI Package Manager..." -InformationAction Continue
                
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
                Write-Verbose "Starting installer process: $InstallerPath"
                $process.Start()

                # Wait for it to exit
                $process.WaitForExit($timeout)

                # Capture the exit code
                $exitCode = $process.ExitCode

                # Optionally capture output or error text
                $output = $process.StandardOutput.ReadToEnd()
                $errorOutput = $process.StandardError.ReadToEnd()

                # Display results
                Write-Information "Installation completed with exit code: $exitCode" -InformationAction Continue
                Write-Verbose "Installer output: $output"
                
                if ($errorOutput) {
                    Write-Warning "Installer error output: $errorOutput"
                }

                if ($exitCode -ne 0) {
                    Write-Warning "Installation may have failed with exit code: $exitCode"
                }
                
                return [PSCustomObject]@{
                    ExitCode = $exitCode
                    Output = $output
                    ErrorOutput = $errorOutput
                    InstallerPath = $InstallerPath
                }
            }
        }
        catch {
            $errorMessage = "Failed to install NI Package Manager - InstallerPath: '$InstallerPath'. Error: $($_.Exception.Message)"
            Write-Error -Message $errorMessage -Category InvalidOperation -TargetObject $InstallerPath
            throw
        }
    }
    
    end {
        Write-Verbose "Completed Install-NipkgManager operation"
    }
}

function New-NipkgSnapshot {
    <#
    .SYNOPSIS
        Creates a snapshot object from provided NIPKG feeds and packages information.

    .DESCRIPTION
        Formats feeds and packages information from provided PSObjects into a structured object.
        This object can be serialized to JSON or used for other purposes.

    .PARAMETER FeedsInfo
        PSCustomObject containing feed information from Get-FeedsInfoFromNipkgCmd.

    .PARAMETER PackagesInfo
        PSCustomObject containing package information from Get-PackagesInfoFromNipkgCmd.

    .EXAMPLE
        $feeds = Get-FeedsInfoFromNipkgCmd
        $packages = Get-PackagesInfoFromNipkgCmd -Type "installed"
        $snapshot = New-NipkgSnapshot -FeedsInfo $feeds -PackagesInfo $packages

    .NOTES
        Returns a hashtable with:
        - feeds: Array of feeds with name and uri
        - packages: Array of packages with name and version
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateNotNull()]
        [PSCustomObject[]]$FeedsInfo,
        
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateNotNull()]
        [PSCustomObject[]]$PackagesInfo
    )

    begin {
        Write-Verbose "Starting New-NipkgSnapshot operation"
    }
    
    process {
        try {
            Write-Verbose "Formatting feeds information"

            # Order packages for installation, allowing circular dependencies which are common in real systems
            Write-Verbose "Ordering packages for optimal installation sequence..."
            try {
                $filteredPackages = Get-PackageInstallationOrder -PackagesInfo $PackagesInfo -AllowCircularDependencies
                Write-Verbose "Successfully ordered $($filteredPackages.Count) packages (circular dependencies allowed)"
            } catch {
                Write-Warning "Package ordering failed, using original order: $($_.Exception.Message)"
                $filteredPackages = $PackagesInfo
            }
            
            # Filter packages by category
            # $programingEnvironmentsPackages = Get-ProgrammingEnvironmentsPackages -PackagesInfo $PackagesInfo
            # $driversPackages = Get-DriverPackages -PackagesInfo $PackagesInfo
            # $applicationPackages = Get-ApplicationSoftwarePackages -PackagesInfo $PackagesInfo
            # $utilitiesPackages = Get-UtilitiesPackages -PackagesInfo $PackagesInfo

            # $filteredPackages = @($programingEnvironmentsPackages) + @($driversPackages) + @($applicationPackages) + @($utilitiesPackages) | Where-Object { $_ -ne $null }

            Write-Verbose "Filtered packages: $($filteredPackages.Count) total packages from programming environments, drivers, applications, and utilities"
            
            # Convert feeds to desired format
            $feeds = @()
            foreach ($feed in $FeedsInfo) {
                $feeds += [ordered]@{
                    name = $feed.Name
                    uri = $feed.Path
                }
            }
            
            Write-Verbose "Formatting packages information"
            
            # Convert packages to desired format
            $packages = @()
            foreach ($package in $filteredPackages) {
                $packages += [ordered]@{
                    name = $package.Package
                    version = $package.Version
                }
            }
            
            # Create the snapshot object
            $snapshot = @{
                feeds = $feeds
                packages = $packages
            }
            
            Write-Verbose "Snapshot object contains $($feeds.Count) feeds and $($packages.Count) packages"
            
            return $snapshot
        }
        catch {
            $errorMessage = "Failed to create NIPKG snapshot object. Error: $($_.Exception.Message)"
            Write-Error -Message $errorMessage -Category InvalidOperation
            throw
        }
    }
    
    end {
        Write-Verbose "Completed New-NipkgSnapshot operation"
    }
}

function Export-NipkgSnapshotToJson {
    <#
    .SYNOPSIS
        Exports a snapshot object to a JSON file.

    .DESCRIPTION
        Serializes a snapshot object (from New-NipkgSnapshot) to a JSON file.
        Creates the output directory if it doesn't exist.

    .PARAMETER Snapshot
        Hashtable containing the snapshot data to serialize.

    .PARAMETER OutputPath
        Path where the JSON snapshot file will be created.

    .EXAMPLE
        $snapshot = New-NipkgSnapshot -FeedsInfo $feeds -PackagesInfo $packages
        Export-NipkgSnapshotToJson -Snapshot $snapshot -OutputPath "C:\Snapshots\nipkg-snapshot.json"

    .NOTES
        Creates the output directory if it doesn't exist.
        Returns summary information about the exported file.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateNotNull()]
        [hashtable]$Snapshot,
        
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string]$OutputPath
    )

    begin {
        Write-Verbose "Starting Export-NipkgSnapshotToJson operation"
    }
    
    process {
        try {
            if ($PSCmdlet.ShouldProcess($OutputPath, "Export NIPKG snapshot to JSON")) {
                Write-Information "Exporting NIPKG snapshot to JSON..." -InformationAction Continue
                
                # Convert to JSON
                $jsonContent = $Snapshot | ConvertTo-Json -Depth 10 -Compress:$false
                
                # Ensure output directory exists
                $outputDir = Split-Path -Path $OutputPath -Parent
                if ($outputDir -and -not (Test-Path -Path $outputDir)) {
                    Write-Verbose "Creating output directory: $outputDir"
                    New-Item -Path $outputDir -ItemType Directory -Force | Out-Null
                }
                
                # Write JSON to file
                $jsonContent | Out-File -FilePath $OutputPath -Encoding UTF8 -Force
                
                Write-Information "Snapshot exported successfully: $OutputPath" -InformationAction Continue
                
                $feedsCount = if ($Snapshot.feeds) { $Snapshot.feeds.Count } else { 0 }
                $packagesCount = if ($Snapshot.packages) { $Snapshot.packages.Count } else { 0 }
                
                Write-Verbose "Exported snapshot contains $feedsCount feeds and $packagesCount packages"
                
                # Return summary information
                return [PSCustomObject]@{
                    SnapshotPath = $OutputPath
                    FeedsCount = $feedsCount
                    PackagesCount = $packagesCount
                    FileSizeBytes = (Get-Item -Path $OutputPath).Length
                }
            }
        }
        catch {
            $errorMessage = "Failed to export NIPKG snapshot to JSON - OutputPath: '$OutputPath'. Error: $($_.Exception.Message)"
            Write-Error -Message $errorMessage -Category InvalidOperation -TargetObject $OutputPath
            throw
        }
    }
    
    end {
        Write-Verbose "Completed Export-NipkgSnapshotToJson operation"
    }
}

function Import-NipkgSnapshotFromJson {
    <#
    .SYNOPSIS
        Imports a NIPKG snapshot from a JSON file.

    .DESCRIPTION
        Reads and parses a JSON snapshot file created by Export-NipkgSnapshotToJson.
        Returns the snapshot object with feeds and packages information.

    .PARAMETER InputPath
        Path to the JSON snapshot file to import.

    .EXAMPLE
        $snapshot = Import-NipkgSnapshotFromJson -InputPath "C:\Snapshots\nipkg-snapshot.json"

    .EXAMPLE
        $snapshot = Import-NipkgSnapshotFromJson -InputPath "C:\Snapshots\snapshot.json"
        Write-Host "Imported $($snapshot.packages.Count) packages and $($snapshot.feeds.Count) feeds"

    .NOTES
        Returns a hashtable with:
        - feeds: Array of feeds with name and uri properties
        - packages: Array of packages with name and version properties
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string]$InputPath
    )

    begin {
        Write-Verbose "Starting Import-NipkgSnapshotFromJson operation"
    }
    
    process {
        try {
            # Validate input file exists
            if (-not (Test-Path -Path $InputPath)) {
                throw "Snapshot file not found: $InputPath"
            }

            Write-Information "Importing NIPKG snapshot from JSON..." -InformationAction Continue
            Write-Verbose "Reading JSON file: $InputPath"
            
            # Read and parse JSON content
            $jsonContent = Get-Content -Path $InputPath -Raw -Encoding UTF8
            $snapshotData = $jsonContent | ConvertFrom-Json
            
            # Validate JSON structure
            if (-not $snapshotData) {
                throw "Invalid or empty JSON content"
            }
            
            # Convert back to hashtable format
            $snapshot = @{
                feeds = @()
                packages = @()
            }
            
            # Process feeds if they exist
            if ($snapshotData.feeds) {
                Write-Verbose "Processing $($snapshotData.feeds.Count) feeds"
                foreach ($feed in $snapshotData.feeds) {
                    $snapshot.feeds += [ordered]@{
                        name = $feed.name
                        uri = $feed.uri
                    }
                }
            }
            
            # Process packages if they exist
            if ($snapshotData.packages) {
                Write-Verbose "Processing $($snapshotData.packages.Count) packages"
                foreach ($package in $snapshotData.packages) {
                    $snapshot.packages += [ordered]@{
                        name = $package.name
                        version = $package.version
                    }
                }
            }
            
            Write-Information "Snapshot imported successfully: $InputPath" -InformationAction Continue
            Write-Verbose "Imported snapshot contains $($snapshot.feeds.Count) feeds and $($snapshot.packages.Count) packages"
            
            return $snapshot
        }
        catch {
            $errorMessage = "Failed to import NIPKG snapshot from JSON - InputPath: '$InputPath'. Error: $($_.Exception.Message)"
            Write-Error -Message $errorMessage -Category InvalidOperation -TargetObject $InputPath
            throw
        }
    }
    
    end {
        Write-Verbose "Completed Import-NipkgSnapshotFromJson operation"
    }
}

function Test-NipkgAvailability {
    <#
    .SYNOPSIS
        Tests if NI Package Manager is available and accessible.

    .DESCRIPTION
        Checks if the NIPKG command is available and can be executed.
        This is useful for troubleshooting connection issues.

    .PARAMETER NipkgCmdPath
        Path to the NIPKG command-line tool. Defaults to 'nipkg' if in PATH.

    .EXAMPLE
        Test-NipkgAvailability

    .EXAMPLE
        Test-NipkgAvailability -NipkgCmdPath "C:\Program Files\NI\nipkg.exe"

    .NOTES
        Returns $true if NIPKG is available, $false otherwise.
    #>
    [CmdletBinding()]
    param (
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$NipkgCmdPath = "nipkg" 
    )

    begin {
        Write-Verbose "Starting Test-NipkgAvailability operation"
    }
    
    process {
        try {
            # Test if command exists
            $command = Get-Command $NipkgCmdPath -ErrorAction Stop
            Write-Verbose "NIPKG command found at: $($command.Source)"
            
            # Test if command can execute (try getting version)
            $versionOutput = & $NipkgCmdPath --version 2>&1
            
            if ($LASTEXITCODE -eq 0) {
                Write-Information "NIPKG is available and working" -InformationAction Continue
                Write-Verbose "NIPKG version output: $versionOutput"
                return $true
            } else {
                Write-Warning "NIPKG command exists but failed to execute properly (exit code: $LASTEXITCODE)"
                Write-Verbose "NIPKG error output: $versionOutput"
                return $false
            }
        }
        catch {
            Write-Warning "NIPKG command not found or not accessible: $NipkgCmdPath"
            Write-Verbose "Error details: $($_.Exception.Message)"
            return $false
        }
    }
    
    end {
        Write-Verbose "Completed Test-NipkgAvailability operation"
    }
}

function New-NipkgSnapshotFromInstaller {
    <#
    .SYNOPSIS
        Creates a NIPKG snapshot from an installer directory structure.

    .DESCRIPTION
        Scans an installer directory for feeds and packages, then creates a snapshot object
        containing all available feeds and packages from the installer. This is useful for
        creating snapshots from offline installers before installation.

    .PARAMETER InstallerDirectory
        Path to the installer directory containing the feeds subdirectory.

    .PARAMETER IncludeFeeds
        Whether to include feed information in the snapshot. Defaults to $true.

    .EXAMPLE
        $snapshot = New-NipkgSnapshotFromInstaller -InstallerDirectory "C:\Installers\ni-labview-2025-community-x86_25.1.3_offline"

    .EXAMPLE
        $snapshot = New-NipkgSnapshotFromInstaller -InstallerDirectory ".\installers\labview-2025" -IncludeFeeds $false

    .NOTES
        Returns a hashtable with:
        - feeds: Array of feeds with name and uri (if IncludeFeeds is true)
        - packages: Array of packages with name and version from all feeds
        
        The function looks for a 'feeds' subdirectory and scans all subdirectories for Packages files.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string]$InstallerDirectory,
        
        [Parameter()]
        [bool]$IncludeFeeds = $true
    )

    begin {
        Write-Verbose "Starting New-NipkgSnapshotFromInstaller operation"
    }
    
    process {
        try {
            # Validate installer directory exists
            if (-not (Test-Path -Path $InstallerDirectory -PathType Container)) {
                throw "Installer directory not found: $InstallerDirectory"
            }

            Write-Information "Scanning installer directory for feeds and packages..." -InformationAction Continue
            Write-Verbose "Installer directory: $InstallerDirectory"

            # Look for feeds directory
            $feedsDirectory = Join-Path -Path $InstallerDirectory -ChildPath "feeds"
            if (-not (Test-Path -Path $feedsDirectory -PathType Container)) {
                throw "Feeds directory not found in installer: $feedsDirectory"
            }

            Write-Verbose "Found feeds directory: $feedsDirectory"

            # Get all feed subdirectories
            $feedSubdirectories = Get-ChildItem -Path $feedsDirectory -Directory -ErrorAction Stop
            
            if ($feedSubdirectories.Count -eq 0) {
                Write-Warning "No feed subdirectories found in: $feedsDirectory"
                return @{
                    feeds = @()
                    packages = @()
                }
            }

            Write-Information "Found $($feedSubdirectories.Count) feed(s) in installer" -InformationAction Continue

            # Initialize collections
            $allPackages = @()
            $allFeeds = @()

            # Process each feed subdirectory
            foreach ($feedDir in $feedSubdirectories) {
                Write-Verbose "Processing feed: $($feedDir.Name)"
                
                # Look for Packages file in this feed
                $packagesFile = Join-Path -Path $feedDir.FullName -ChildPath "Packages"
                
                if (Test-Path -Path $packagesFile -PathType Leaf) {
                    Write-Information "Processing packages from feed: $($feedDir.Name)" -InformationAction Continue
                    
                    try {
                        # Parse packages from this feed
                        $feedPackages = Get-PackagesInfoFromPackagesFile -InputPath $packagesFile
                        Write-Verbose "Found $($feedPackages.Count) packages in feed: $($feedDir.Name)"
                        
                        # Add packages to the combined collection
                        $allPackages += $feedPackages
                        
                        # Add feed information if requested
                        if ($IncludeFeeds) {
                            $feedInfo = [PSCustomObject]@{
                                Name = $feedDir.Name
                                Path = $feedDir.FullName
                            }
                            $allFeeds += $feedInfo
                        }
                    }
                    catch {
                        Write-Warning "Failed to parse packages from feed '$($feedDir.Name)': $($_.Exception.Message)"
                    }
                } else {
                    Write-Warning "No Packages file found in feed directory: $($feedDir.FullName)"
                }
            }

            Write-Information "Successfully processed installer: $($allFeeds.Count) feeds, $($allPackages.Count) total packages" -InformationAction Continue

            $snapshot = New-NipkgSnapshot -FeedsInfo $allFeeds -PackagesInfo $allPackages
            
            Write-Verbose "Created snapshot with $($snapshot.feeds.Count) feeds and $($snapshot.packages.Count) packages"
            
            return $snapshot
        }
        catch {
            $errorMessage = "Failed to create snapshot from installer - InstallerDirectory: '$InstallerDirectory'. Error: $($_.Exception.Message)"
            Write-Error -Message $errorMessage -Category InvalidOperation -TargetObject $InstallerDirectory
            throw
        }
    }
    
    end {
        Write-Verbose "Completed New-NipkgSnapshotFromInstaller operation"
    }
}

function New-NipkgSnapshotFromSystem {
    <#
    .SYNOPSIS
        Creates a NIPKG snapshot from the current system state.

    .DESCRIPTION
        Creates a snapshot by capturing the current NIPKG configuration including configured feeds
        and installed packages. This function combines Get-FeedsInfoFromNipkgCmd, Get-PackagesInfo, 
        and New-NipkgSnapshot to create a complete system state snapshot.

    .PARAMETER PackageType
        Specifies whether to capture 'installed' or 'available' packages. Defaults to 'installed'.

    .PARAMETER NipkgCmdPath
        Path to the NIPKG command-line tool. Defaults to 'nipkg' if in PATH.

    .PARAMETER IncludeFeeds
        Whether to include current feed configuration in the snapshot. Defaults to $true.

    .EXAMPLE
        $snapshot = New-NipkgSnapshotFromSystem

    .EXAMPLE
        $snapshot = New-NipkgSnapshotFromSystem -PackageType "installed" -IncludeFeeds $true

    .EXAMPLE
        $snapshot = New-NipkgSnapshotFromSystem -PackageType "available" -NipkgCmdPath "C:\Program Files\NI\nipkg.exe"

    .NOTES
        Returns a hashtable with:
        - feeds: Array of current feeds with name and uri (if IncludeFeeds is true)
        - packages: Array of packages with name and version based on PackageType
        
        This function is useful for creating backups of the current system state or 
        for creating snapshots to replicate on other systems.
    #>
    [CmdletBinding()]
    param (
        [Parameter()]
        [ValidateSet("installed", "available")]
        [string]$PackageType = "installed",
        
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$NipkgCmdPath = "nipkg",
        
        [Parameter()]
        [bool]$IncludeFeeds = $true
    )

    begin {
        Write-Verbose "Starting New-NipkgSnapshotFromSystem operation"
    }
    
    process {
        try {
            Write-Information "Creating NIPKG snapshot from current system state..." -InformationAction Continue
            Write-Verbose "Package type: $PackageType, Include feeds: $IncludeFeeds"

            # Initialize collections
            $feedsInfo = @()
            $packagesInfo = @()

            # Get current feeds if requested
            if ($IncludeFeeds) {
                Write-Information "Retrieving current feed configuration..." -InformationAction Continue
                Write-Verbose "Getting feeds info from NIPKG command"
                
                try {
                    $feedsInfo = Get-FeedsInfoFromNipkgCmd -NipkgCmdPath $NipkgCmdPath -ExcludeLocalFeeds
                    Write-Verbose "Retrieved $($feedsInfo.Count) feeds from system"
                    Write-Information "Found $($feedsInfo.Count) configured feed(s)" -InformationAction Continue
                }
                catch {
                    Write-Warning "Failed to retrieve feeds information: $($_.Exception.Message)"
                    $feedsInfo = @()
                }
            } else {
                Write-Information "Skipping feed configuration (IncludeFeeds=$IncludeFeeds)" -InformationAction Continue
            }

            # Get packages information
            Write-Information "Retrieving $PackageType packages information..." -InformationAction Continue
            Write-Verbose "Getting packages info for type: $PackageType"
            
            try {
                $packagesInfo = Get-PackagesInfoFromNipkgCmd -Type $PackageType -NipkgCmdPath $NipkgCmdPath
                Write-Verbose "Retrieved $($packagesInfo.Count) packages from system"
                Write-Information "Found $($packagesInfo.Count) $PackageType package(s)" -InformationAction Continue
            }
            catch {
                Write-Error "Failed to retrieve packages information: $($_.Exception.Message)"
                throw
            }

            # Create the snapshot using the retrieved information
            Write-Information "Creating snapshot object..." -InformationAction Continue
            Write-Verbose "Creating snapshot with $($feedsInfo.Count) feeds and $($packagesInfo.Count) packages"
            
            $snapshot = New-NipkgSnapshot -FeedsInfo $feedsInfo -PackagesInfo $packagesInfo
            
            Write-Information "System snapshot created successfully" -InformationAction Continue
            Write-Verbose "Snapshot contains $($snapshot.feeds.Count) feeds and $($snapshot.packages.Count) packages"
            
            return $snapshot
        }
        catch {
            $errorMessage = "Failed to create system snapshot - PackageType: '$PackageType'. Error: $($_.Exception.Message)"
            Write-Error -Message $errorMessage -Category InvalidOperation -TargetObject $PackageType
            throw
        }
    }
    
    end {
        Write-Verbose "Completed New-NipkgSnapshotFromSystem operation"
    }
}

function Apply-NipkgSnapshot {
    <#
    .SYNOPSIS
        Applies a NIPKG snapshot using declarative package management.

    .DESCRIPTION
        Imports a NIPKG snapshot from JSON and applies it to the system using a declarative approach:
        1. Analyzing current feed state vs. snapshot requirements and only adding missing feeds
        2. Updating the package database if any feeds were added
        3. Analyzing current package state vs. snapshot requirements
        4. Installing missing packages, upgrading outdated packages, and downgrading newer packages
        5. Leaving unchanged feeds and packages alone
        
        The function compares the current system state with the snapshot and only performs
        necessary actions, making it safe to run multiple times (idempotent).

    .PARAMETER SnapshotPath
        Path to the JSON snapshot file created by Export-NipkgSnapshotToJson.

    .PARAMETER NipkgCmdPath
        Path to the NIPKG command-line tool. Defaults to 'nipkg' if in PATH.

    .PARAMETER SkipFeeds
        Skip adding feeds from the snapshot (only manage packages).

    .PARAMETER SkipPackages
        Skip managing packages from the snapshot (only add feeds).

    .PARAMETER Force
        Force operations even if they might cause issues (used for downgrades).

    .PARAMETER RemoveExistingFeeds
        Remove all existing feeds from the system before applying the snapshot feeds.

    .PARAMETER RemoveSnapshotFeeds
        Remove the snapshot feeds from the system after package operations are complete.
        This is useful when you want to install packages from specific feeds but don't want
        to keep those feeds permanently in the system.

    .PARAMETER RemoveUnlistedPackages
        Remove packages that are currently installed but not listed in the snapshot.
        This ensures the system matches exactly what is defined in the snapshot by
        removing any extra packages. Use with caution as this can remove important packages.

    .PARAMETER RemoveUnlistedFeeds
        Remove feeds that are currently configured but not listed in the snapshot.
        This ensures the feed configuration matches exactly what is defined in the snapshot by
        removing any extra feeds. Use with caution as this can remove important feeds.

    .PARAMETER ValidateCompliance
        Validate that the system state matches the snapshot after all operations are complete.
        Provides detailed compliance reporting and can optionally fail the operation if 
        the system is not compliant.

    .PARAMETER FailOnNonCompliance
        When ValidateCompliance is enabled, throw an error if the system is not compliant
        with the snapshot. Useful for CI/CD pipelines where compliance is required.

    .PARAMETER AllowExtraFeeds
        When ValidateCompliance is enabled, allow extra feeds beyond those in the snapshot.
        If false, extra feeds cause non-compliance. Defaults to $false.

    .PARAMETER AllowExtraPackages
        When ValidateCompliance is enabled, allow extra packages beyond those in the snapshot.
        If false, extra packages cause non-compliance. Defaults to $false.

    .PARAMETER LockDuringInstallation
        Lock each package after it is successfully installed, upgraded, downgraded, or if it's already 
        at the correct version to prevent later packages in the snapshot from modifying it. This ensures 
        that the installation order is strictly maintained and packages cannot be automatically upgraded 
        or downgraded by dependency resolution of subsequent packages. All locked packages are 
        automatically unlocked at the end of the installation process. Use this when package 
        installation order is critical.

    .PARAMETER UseBatchInstallation
        Install all packages in a single batch operation instead of one-by-one. This allows NIPKG 
        to resolve version conflicts and dependencies across the entire snapshot, which can solve 
        compatibility issues that occur with individual package installation. When enabled, 
        LockDuringInstallation is automatically disabled as it's incompatible with batch operations.

    .EXAMPLE
        Apply-NipkgSnapshot -SnapshotPath "C:\Snapshots\my-snapshot.json"

    .EXAMPLE
        Apply-NipkgSnapshot -SnapshotPath "snapshot.json" -NipkgCmdPath "C:\Program Files\NI\nipkg.exe" -Force

    .EXAMPLE
        # Only add feeds, don't install packages
        Apply-NipkgSnapshot -SnapshotPath "snapshot.json" -SkipPackages

    .EXAMPLE
        # Remove existing feeds before applying snapshot
        Apply-NipkgSnapshot -SnapshotPath "snapshot.json" -RemoveExistingFeeds

    .EXAMPLE
        # Remove snapshot feeds after installation
        Apply-NipkgSnapshot -SnapshotPath "snapshot.json" -RemoveSnapshotFeeds

    .EXAMPLE
        # Remove packages not in snapshot (exact match)
        Apply-NipkgSnapshot -SnapshotPath "snapshot.json" -RemoveUnlistedPackages

    .EXAMPLE
        # Remove feeds not in snapshot (exact match)
        Apply-NipkgSnapshot -SnapshotPath "snapshot.json" -RemoveUnlistedFeeds

    .EXAMPLE
        # Validate compliance after applying snapshot
        Apply-NipkgSnapshot -SnapshotPath "snapshot.json" -ValidateCompliance

    .EXAMPLE
        # Fail if system is not compliant (for CI/CD)
        Apply-NipkgSnapshot -SnapshotPath "snapshot.json" -ValidateCompliance -FailOnNonCompliance

    .EXAMPLE
        # Allow extra packages in development environment
        Apply-NipkgSnapshot -SnapshotPath "snapshot.json" -ValidateCompliance -AllowExtraPackages $true

    .EXAMPLE
        # Lock packages during installation to prevent dependency conflicts
        Apply-NipkgSnapshot -SnapshotPath "snapshot.json" -LockDuringInstallation

    .EXAMPLE
        # Use batch installation to resolve version conflicts
        Apply-NipkgSnapshot -SnapshotPath "snapshot.json" -UseBatchInstallation

    .EXAMPLE
        # Complete workflow: clean slate approach
        Apply-NipkgSnapshot -SnapshotPath "snapshot.json" -RemoveExistingFeeds -RemoveUnlistedPackages -RemoveUnlistedFeeds -RemoveSnapshotFeeds

    .NOTES
        This function requires administrator privileges for feed addition and package installation.
        The operation can take significant time depending on the number of packages.
        
        By default, packages are installed individually with hardcoded flags (--allow-downgrade --allow-uninstall --install-also-upgrades)
        to give NIPKG maximum flexibility in resolving dependencies while maintaining strict installation order.
        The --include-recommended flag is NOT used to prevent automatic installation of dependencies
        that should be installed in the intended order.
        
        Use -UseBatchInstallation when encountering version conflicts or complex dependency chains that
        require NIPKG to resolve conflicts across the entire snapshot as a single operation.
        
        When LockDuringInstallation is enabled, packages are locked after each successful installation,
        upgrade, downgrade, or if they're already at the correct version, using 'nipkg lock <package-name>' 
        to prevent later packages from modifying them through dependency resolution. This ensures strict 
        package installation order is maintained. All locked packages are automatically unlocked at the 
        end of the process using 'nipkg unlock <package-name>'. Note: LockDuringInstallation is 
        incompatible with UseBatchInstallation.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string]$SnapshotPath,
        
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$NipkgCmdPath = "nipkg",
        
        [Parameter()]
        [switch]$SkipFeeds,
        
        [Parameter()]
        [switch]$SkipPackages,
        
        [Parameter()]
        [switch]$Force,
        
        [Parameter()]
        [switch]$RemoveExistingFeeds,
        
        [Parameter()]
        [switch]$RemoveSnapshotFeeds,
        
        [Parameter()]
        [switch]$RemoveUnlistedPackages,
        
        [Parameter()]
        [switch]$RemoveUnlistedFeeds,
        
        [Parameter()]
        [switch]$ValidateCompliance,
        
        [Parameter()]
        [switch]$FailOnNonCompliance,
        
        [Parameter()]
        [bool]$AllowExtraFeeds = $false,
        
        [Parameter()]
        [bool]$AllowExtraPackages = $false,
        
        [Parameter()]
        [switch]$LockDuringInstallation,
        
        [Parameter()]
        [switch]$UseBatchInstallation
    )

    begin {
        Write-Verbose "Starting Apply-NipkgSnapshot operation"
        
        # Check if NIPKG command is available
        # try {
        #     $null = Get-Command $NipkgCmdPath -ErrorAction Stop
        # }
        # catch {
        #     throw "NIPKG command not found: $NipkgCmdPath. Please ensure NI Package Manager is installed and accessible."
        # }
    }
    
    process {
        try {
            # Import the snapshot
            Write-Information "Importing NIPKG snapshot..." -InformationAction Continue
            $snapshot = Import-NipkgSnapshotFromJson -InputPath $SnapshotPath
            
            Write-Information "Snapshot contains $($snapshot.feeds.Count) feeds and $($snapshot.packages.Count) packages" -InformationAction Continue

            $results = @{
                FeedsRemoved = 0
                FeedsAdded = 0
                FeedsSkipped = 0
                FeedsUnchanged = 0
                FeedsFailed = 0
                FeedsUnlistedRemoved = 0
                FeedsUnlistedRemovalFailed = 0
                SnapshotFeedsRemoved = 0
                SnapshotFeedsRemovalFailed = 0
                PackagesInstalled = 0
                PackagesUpgraded = 0
                PackagesDowngraded = 0
                PackagesSkipped = 0
                PackagesFailed = 0
                PackagesUnchanged = 0
                PackagesRemoved = 0
                PackagesRemovalFailed = 0
            }

            # Track feeds added from the snapshot for potential removal later
            $snapshotFeedsAdded = @()
            
            # Track packages locked during installation for unlocking at the end
            $packagesLocked = @()

            # Phase 0: Remove existing feeds if requested
            if ($RemoveExistingFeeds -and -not $SkipFeeds) {
                Write-Information "Phase 0: Removing existing feeds from NIPKG..." -InformationAction Continue
                
                try {
                    # Get current feeds
                    $existingFeeds = Get-FeedsInfoFromNipkgCmd -NipkgCmdPath $NipkgCmdPath
                    
                    if ($existingFeeds -and $existingFeeds.Count -gt 0) {
                        Write-Information "Found $($existingFeeds.Count) existing feed(s) to remove" -InformationAction Continue
                        
                        if ($PSCmdlet.ShouldProcess("$($existingFeeds.Count) existing feeds", "Remove existing NIPKG feeds")) {
                            Remove-Feeds -FeedsInfo $existingFeeds -NipkgCmdPath $NipkgCmdPath
                            $results.FeedsRemoved = $existingFeeds.Count
                            Write-Information "Removed $($existingFeeds.Count) existing feed(s)" -InformationAction Continue
                        }
                    } else {
                        Write-Information "No existing feeds found to remove" -InformationAction Continue
                    }
                }
                catch {
                    Write-Warning "Failed to remove existing feeds: $($_.Exception.Message)"
                    # Continue with the rest of the operation even if feed removal fails
                }
            }

            # Phase 1: Add feeds (declarative approach)
            if (-not $SkipFeeds -and $snapshot.feeds.Count -gt 0) {
                Write-Information "Phase 1: Processing feeds in declarative mode..." -InformationAction Continue
                
                # Get currently configured feeds
                Write-Information "Retrieving currently configured feeds..." -InformationAction Continue
                try {
                    $currentFeeds = Get-FeedsInfoFromNipkgCmd -NipkgCmdPath $NipkgCmdPath
                    Write-Verbose "Found $($currentFeeds.Count) currently configured feeds"
                }
                catch {
                    Write-Warning "Failed to get current feeds list: $($_.Exception.Message)"
                    $currentFeeds = @()
                }
                
                # Create lookup table for current feeds (by name and path)
                $currentFeedsLookup = @{}
                foreach ($currentFeed in $currentFeeds) {
                    # Create a key combining name and normalized path for comparison
                    $normalizedPath = $currentFeed.Path -replace '\\', '/' -replace '/$', ''
                    $lookupKey = "$($currentFeed.Name)|$normalizedPath"
                    $currentFeedsLookup[$lookupKey] = $currentFeed
                }
                
                Write-Information "Processing $($snapshot.feeds.Count) feeds from snapshot..." -InformationAction Continue
                
                foreach ($feed in $snapshot.feeds) {
                    # Normalize the snapshot feed URI for comparison
                    $normalizedUri = $feed.uri -replace '\\', '/' -replace '/$', ''
                    $feedLookupKey = "$($feed.name)|$normalizedUri"
                    
                    # Check if this feed already exists with the same name and URI
                    if ($currentFeedsLookup.ContainsKey($feedLookupKey)) {
                        $results.FeedsUnchanged++
                        Write-Verbose "Feed '$($feed.name)' already exists with URI '$($feed.uri)' - skipping"
                        Write-Information "Skipping feed '$($feed.name)' - already configured" -InformationAction Continue
                        
                        # Still track it as a snapshot feed in case we need to remove it later
                        $snapshotFeedsAdded += $feed
                    }
                    else {
                        # Check if a feed with the same name but different URI exists
                        $existingFeedWithSameName = $currentFeeds | Where-Object { $_.Name -eq $feed.name }
                        if ($existingFeedWithSameName) {
                            Write-Warning "Feed with name '$($feed.name)' already exists but with different URI: '$($existingFeedWithSameName.Path)' vs '$($feed.uri)'"
                        }
                        
                        # Feed doesn't exist - add it
                        if ($PSCmdlet.ShouldProcess($feed.name, "Add NIPKG feed")) {
                            try {
                                Write-Verbose "Adding new feed: $($feed.name) -> $($feed.uri)"
                                Write-Information "Adding feed: $($feed.name)" -InformationAction Continue
                                
                                & $NipkgCmdPath feed-add "$($feed.uri)"
                                
                                if ($LASTEXITCODE -eq 0) {
                                    $results.FeedsAdded++
                                    $snapshotFeedsAdded += $feed
                                    Write-Verbose "Successfully added feed: $($feed.name)"
                                } else {
                                    $results.FeedsFailed++
                                    Write-Warning "Failed to add feed '$($feed.name)' (exit code: $LASTEXITCODE)"
                                }
                            }
                            catch {
                                $results.FeedsFailed++
                                Write-Warning "Failed to add feed '$($feed.name)': $($_.Exception.Message)"
                            }
                        } else {
                            $results.FeedsSkipped++
                        }
                    }
                }

                # Update package database after adding feeds
                if ($results.FeedsAdded -gt 0) {
                    if ($PSCmdlet.ShouldProcess("NIPKG", "Update package database")) {
                        Write-Information "Updating package database..." -InformationAction Continue
                        & $NipkgCmdPath update
                        
                        if ($LASTEXITCODE -eq 0) {
                            Write-Information "Package database updated successfully" -InformationAction Continue
                        } else {
                            Write-Warning "Package database update may have failed (exit code: $LASTEXITCODE)"
                        }
                    }
                }
            } else {
                Write-Information "Skipping feed addition (SkipFeeds=$SkipFeeds, Feed count=$($snapshot.feeds.Count))" -InformationAction Continue
            }

            # Phase 2: Install packages (declarative approach)
            if (-not $SkipPackages -and $snapshot.packages.Count -gt 0) {
                Write-Information "Phase 2: Processing packages in installation order..." -InformationAction Continue
                
                # Get currently installed packages
                Write-Information "Retrieving currently installed packages..." -InformationAction Continue
                try {
                    $installedPackages = Get-PackagesInfoFromNipkgCmd -Type "installed" -NipkgCmdPath $NipkgCmdPath
                    Write-Verbose "Found $($installedPackages.Count) currently installed packages"
                }
                catch {
                    Write-Warning "Failed to get installed packages list: $($_.Exception.Message)"
                    $installedPackages = @()
                }
                
                # Create lookup table for installed packages
                $installedLookup = @{}
                foreach ($pkg in $installedPackages) {
                    $installedLookup[$pkg.Package] = $pkg.Version
                }
                
                # Disable locking if batch installation is requested (incompatible modes)
                if ($UseBatchInstallation -and $LockDuringInstallation) {
                    Write-Warning "LockDuringInstallation is incompatible with UseBatchInstallation - disabling locking"
                    $LockDuringInstallation = $false
                }
                
                if ($UseBatchInstallation) {
                    # Batch installation approach - let NIPKG resolve all conflicts
                    Write-Information "Using batch installation mode to resolve version conflicts..." -InformationAction Continue
                    
                    # Build package specifications for all packages
                    $packageSpecs = @()
                    foreach ($snapshotPackage in $snapshot.packages) {
                        $packageSpecs += "$($snapshotPackage.name)=$($snapshotPackage.version)"
                    }
                    
                    Write-Information "Installing $($packageSpecs.Count) packages in batch mode..." -InformationAction Continue
                    Write-Information "Package specifications: $($packageSpecs -join ', ')" -InformationAction Continue
                    
                    if ($PSCmdlet.ShouldProcess("$($packageSpecs.Count) packages", "Batch install packages")) {
                        try {
                            # Install all packages in one command - let NIPKG resolve conflicts
                            & $NipkgCmdPath install $packageSpecs --accept-eulas -y --allow-downgrade --allow-uninstall --install-also-upgrades
                            
                            if ($LASTEXITCODE -eq 0) {
                                $results.PackagesInstalled = $packageSpecs.Count
                                Write-Information "Successfully installed $($packageSpecs.Count) packages in batch mode" -InformationAction Continue
                            } else {
                                $results.PackagesFailed = $packageSpecs.Count
                                Write-Warning "Batch installation failed (exit code: $LASTEXITCODE)"
                            }
                        }
                        catch {
                            $results.PackagesFailed = $packageSpecs.Count
                            Write-Warning "Exception during batch installation: $($_.Exception.Message)"
                        }
                    } else {
                        $results.PackagesSkipped = $packageSpecs.Count
                    }
                } else {
                    # Individual package installation approach (existing logic)
                    Write-Information "Using individual package installation mode..." -InformationAction Continue
                    Write-Information "Processing $($snapshot.packages.Count) packages in dependency order..." -InformationAction Continue
                    Write-Warning "Using strict installation order to prevent dependency conflicts - packages will be installed one by one without automatic recommended packages" -WarningAction Continue
                    
                    foreach ($snapshotPackage in $snapshot.packages) {
                    $packageName = $snapshotPackage.name
                    $targetVersion = $snapshotPackage.version
                    
                    # Check if package is already installed at the correct version before processing
                    # This prevents unnecessary work and avoids issues with packages that were auto-installed
                    $currentlyInstalled = $false
                    $currentInstalledVersion = $null
                    
                    try {
                        # Re-check current installation status for this specific package
                        $checkResult = & $NipkgCmdPath info-installed $packageName 2>$null
                        if ($LASTEXITCODE -eq 0 -and $checkResult) {
                            # Parse the output to get the installed version - preserve full version string
                            $versionLine = $checkResult | Where-Object { $_ -match "Version:\s*(.+)" }
                            if ($versionLine) {
                                # Extract the full version string using regex to preserve all version components
                                if ($versionLine -match "Version:\s*(.+)") {
                                    $currentInstalledVersion = $matches[1]
                                    $currentlyInstalled = $true
                                    Write-Verbose "Current status check: $packageName is installed at version $currentInstalledVersion"
                                }
                            }
                        }
                    }
                    catch {
                        Write-Verbose "Failed to check current status for $packageName : $($_.Exception.Message)"
                    }
                    
                    # Determine what action is needed for this package
                    $action = "none"
                    
                    if ($currentlyInstalled) {
                        if ($currentInstalledVersion -eq $targetVersion) {
                            # Exact version match - no action needed
                            $action = "none"
                            Write-Verbose "Package '$packageName' is already at target version ($targetVersion)"
                        }
                        else {
                            $versionComparison = Compare-PackageVersions -Version1 $targetVersion -Version2 $currentInstalledVersion
                            
                            if ($versionComparison -gt 0) {
                                # Upgrade needed (target version is higher)
                                $action = "upgrade"
                                Write-Verbose "Package '$packageName' needs upgrade: $currentInstalledVersion -> $targetVersion"
                            }
                            elseif ($versionComparison -lt 0) {
                                # Downgrade needed (target version is lower)
                                $action = "downgrade"
                                Write-Verbose "Package '$packageName' needs downgrade: $currentInstalledVersion -> $targetVersion"
                            }
                            else {
                                # Versions are considered equal by our comparison
                                $action = "none"
                                Write-Verbose "Package '$packageName' is already at equivalent version ($currentInstalledVersion = $targetVersion)"
                            }
                        }
                    }
                    else {
                        # Package not installed - needs installation
                        $action = "install"
                        Write-Verbose "Package '$packageName' is not installed, needs installation (version $targetVersion)"
                    }
                    
                    # Perform the required action
                    switch ($action) {
                        "none" {
                            $results.PackagesUnchanged++
                            Write-Verbose "Skipping '$packageName' - already at correct version ($targetVersion)"
                            
                            # Lock unchanged packages if requested to prevent later packages from modifying them
                            if ($LockDuringInstallation) {
                                Write-Verbose "Locking unchanged package $($packageName) to prevent modifications by later packages"
                                & $NipkgCmdPath lock $packageName
                                if ($LASTEXITCODE -eq 0) {
                                    Write-Verbose "Successfully locked unchanged package $($packageName)"
                                    $packagesLocked += $packageName
                                } else {
                                    Write-Warning "Failed to lock unchanged package $($packageName) (exit code: $LASTEXITCODE)"
                                }
                            }
                        }
                        
                        "install" {
                            if ($PSCmdlet.ShouldProcess("$($packageName) v$($targetVersion)", "Install package")) {
                                try {
                                    $packageSpec = "$($packageName)=$($targetVersion)"
                                    Write-Information "Installing: $($packageName) v$($targetVersion)" -InformationAction Continue
                                    
                                    # Install with strict control to maintain package installation order
                                    # Use flags to allow NIPKG flexibility in resolving dependencies while maintaining order
                                    & $NipkgCmdPath install $packageSpec --accept-eulas -y --allow-downgrade --allow-uninstall --install-also-upgrades
                                    
                                    if ($LASTEXITCODE -eq 0) {
                                        $results.PackagesInstalled++
                                        Write-Verbose "Successfully installed $($packageName) v$($targetVersion)"
                                        
                                        # Lock the package if requested to prevent later packages from modifying it
                                        if ($LockDuringInstallation) {
                                            Write-Verbose "Locking package $($packageName) to prevent modifications by later packages"
                                            & $NipkgCmdPath lock $packageName
                                            if ($LASTEXITCODE -eq 0) {
                                                Write-Verbose "Successfully locked package $($packageName)"
                                                $packagesLocked += $packageName
                                            } else {
                                                Write-Warning "Failed to lock package $($packageName) (exit code: $LASTEXITCODE)"
                                            }
                                        }
                                    } else {
                                        $results.PackagesFailed++
                                        Write-Warning "Failed to install $($packageName) v$($targetVersion) (exit code: $LASTEXITCODE)"
                                    }
                                }
                                catch {
                                    $results.PackagesFailed++
                                    Write-Warning "Exception installing $($packageName) v$($targetVersion): $($_.Exception.Message)"
                                }
                            } else {
                                $results.PackagesSkipped++
                            }
                        }
                        
                        "upgrade" {
                            if ($PSCmdlet.ShouldProcess("$($packageName) v$($currentInstalledVersion) -> v$($targetVersion)", "Upgrade package")) {
                                try {
                                    $packageSpec = "$($packageName)=$($targetVersion)"
                                    Write-Information "Upgrading: $($packageName) v$($currentInstalledVersion) -> v$($targetVersion)" -InformationAction Continue
                                    
                                    # Upgrade with strict control - no automatic recommended packages
                                    & $NipkgCmdPath install $packageSpec --accept-eulas -y --allow-downgrade --allow-uninstall --install-also-upgrades
                                    
                                    if ($LASTEXITCODE -eq 0) {
                                        $results.PackagesUpgraded++
                                        Write-Verbose "Successfully upgraded $($packageName) to v$($targetVersion)"
                                        
                                        # Lock the package if requested to prevent later packages from modifying it
                                        if ($LockDuringInstallation) {
                                            Write-Verbose "Locking package $($packageName) to prevent modifications by later packages"
                                            & $NipkgCmdPath lock $packageName
                                            if ($LASTEXITCODE -eq 0) {
                                                Write-Verbose "Successfully locked package $($packageName)"
                                                $packagesLocked += $packageName
                                            } else {
                                                Write-Warning "Failed to lock package $($packageName) (exit code: $LASTEXITCODE)"
                                            }
                                        }
                                    } else {
                                        $results.PackagesFailed++
                                        Write-Warning "Failed to upgrade $($packageName) to v$($targetVersion) (exit code: $LASTEXITCODE)"
                                    }
                                }
                                catch {
                                    $results.PackagesFailed++
                                    Write-Warning "Exception upgrading $($packageName) to v$($targetVersion): $($_.Exception.Message)"
                                }
                            } else {
                                $results.PackagesSkipped++
                            }
                        }
                        
                        "downgrade" {
                            if ($PSCmdlet.ShouldProcess("$($packageName) v$($currentInstalledVersion) -> v$($targetVersion)", "Downgrade package")) {
                                try {
                                    $packageSpec = "$($packageName)=$($targetVersion)"
                                    Write-Information "Downgrading: $($packageName) v$($currentInstalledVersion) -> v$($targetVersion)" -InformationAction Continue
                                    
                                    # For downgrades, use all flags for maximum flexibility
                                    & $NipkgCmdPath install $packageSpec --accept-eulas -y --allow-downgrade --allow-uninstall --install-also-upgrades
                                    
                                    if ($LASTEXITCODE -eq 0) {
                                        $results.PackagesDowngraded++
                                        Write-Verbose "Successfully downgraded $($packageName) to v$($targetVersion)"
                                        
                                        # Lock the package if requested to prevent later packages from modifying it
                                        if ($LockDuringInstallation) {
                                            Write-Verbose "Locking package $($packageName) to prevent modifications by later packages"
                                            & $NipkgCmdPath lock $packageName
                                            if ($LASTEXITCODE -eq 0) {
                                                Write-Verbose "Successfully locked package $($packageName)"
                                                $packagesLocked += $packageName
                                            } else {
                                                Write-Warning "Failed to lock package $($packageName) (exit code: $LASTEXITCODE)"
                                            }
                                        }
                                    } else {
                                        # If direct downgrade fails, try uninstall then install
                                        Write-Verbose "Direct downgrade failed, trying uninstall then install approach"
                                        & $NipkgCmdPath remove $($packageName) -y
                                        
                                        if ($LASTEXITCODE -eq 0) {
                                            & $NipkgCmdPath install $packageSpec --accept-eulas -y --allow-downgrade --allow-uninstall --install-also-upgrades
                                            
                                            if ($LASTEXITCODE -eq 0) {
                                                $results.PackagesDowngraded++
                                                Write-Verbose "Successfully downgraded $($packageName) to v$($targetVersion) using uninstall/install"
                                                
                                                # Lock the package if requested to prevent later packages from modifying it
                                                if ($LockDuringInstallation) {
                                                    Write-Verbose "Locking package $($packageName) to prevent modifications by later packages"
                                                    & $NipkgCmdPath lock $packageName
                                                    if ($LASTEXITCODE -eq 0) {
                                                        Write-Verbose "Successfully locked package $($packageName)"
                                                        $packagesLocked += $packageName
                                                    } else {
                                                        Write-Warning "Failed to lock package $($packageName) (exit code: $LASTEXITCODE)"
                                                    }
                                                }
                                            } else {
                                                $results.PackagesFailed++
                                                Write-Warning "Failed to downgrade $($packageName) to v$($targetVersion) even after uninstall/install (exit code: $LASTEXITCODE)"
                                            }
                                        } else {
                                            $results.PackagesFailed++
                                            Write-Warning "Failed to uninstall $($packageName) for downgrade (exit code: $LASTEXITCODE)"
                                        }
                                    }
                                }
                                catch {
                                    $results.PackagesFailed++
                                    Write-Warning "Exception downgrading $($packageName) to v$($targetVersion): $($_.Exception.Message)"
                                }
                            } else {
                                $results.PackagesSkipped++
                            }
                        }
                    }
                }
                } # End of individual package installation mode
                
            } else {
                Write-Information "Skipping package installation (SkipPackages=$SkipPackages, Package count=$($snapshot.packages.Count))" -InformationAction Continue
            }

            # Phase 3: Remove unlisted feeds if requested
            if ($RemoveUnlistedFeeds -and -not $SkipFeeds) {
                Write-Information "Phase 3: Removing feeds not listed in snapshot..." -InformationAction Continue
                
                # Get current feeds (refresh the list in case it changed during feed addition)
                try {
                    $currentConfiguredFeeds = Get-FeedsInfoFromNipkgCmd -NipkgCmdPath $NipkgCmdPath
                    Write-Verbose "Found $($currentConfiguredFeeds.Count) currently configured feeds for unlisted feed removal"
                }
                catch {
                    Write-Warning "Failed to get current configured feeds for unlisted removal: $($_.Exception.Message)"
                    $currentConfiguredFeeds = @()
                }
                
                if ($currentConfiguredFeeds.Count -gt 0) {
                    # Create a set of feed names and URIs from the snapshot for quick lookup
                    $snapshotFeedLookup = @{}
                    foreach ($snapshotFeed in $snapshot.feeds) {
                        # Use same normalization as in Phase 1
                        $normalizedUri = $snapshotFeed.uri -replace '\\', '/' -replace '/$', ''
                        $feedLookupKey = "$($snapshotFeed.name)|$normalizedUri"
                        $snapshotFeedLookup[$feedLookupKey] = $true
                    }
                    
                    # Find feeds that are configured but not in the snapshot
                    $feedsToRemove = @()
                    foreach ($configuredFeed in $currentConfiguredFeeds) {
                        $normalizedPath = $configuredFeed.Path -replace '\\', '/' -replace '/$', ''
                        $currentFeedKey = "$($configuredFeed.Name)|$normalizedPath"
                        
                        if (-not $snapshotFeedLookup.ContainsKey($currentFeedKey)) {
                            $feedsToRemove += $configuredFeed
                        }
                    }
                    
                    if ($feedsToRemove.Count -gt 0) {
                        Write-Information "Found $($feedsToRemove.Count) unlisted feeds to remove" -InformationAction Continue
                        Write-Warning "About to remove $($feedsToRemove.Count) feeds not listed in snapshot. This could remove important system feeds!" -WarningAction Continue
                        
                        foreach ($feedToRemove in $feedsToRemove) {
                            if ($PSCmdlet.ShouldProcess("$($feedToRemove.Name) -> $($feedToRemove.Path)", "Remove unlisted feed")) {
                                try {
                                    Write-Information "Removing unlisted feed: $($feedToRemove.Name) -> $($feedToRemove.Path)" -InformationAction Continue
                                    & $NipkgCmdPath feed-remove "$($feedToRemove.Name)"
                                    
                                    if ($LASTEXITCODE -eq 0) {
                                        $results.FeedsUnlistedRemoved++
                                        Write-Verbose "Successfully removed unlisted feed $($feedToRemove.Name)"
                                    } elseif ($LASTEXITCODE -eq -125079) {
                                        # Feed doesn't exist or is not enabled - this can happen if:
                                        # 1. Feed was already removed by a previous operation
                                        # 2. Feed is disabled
                                        # 3. Feed path no longer exists
                                        # We'll treat this as a successful removal since the goal is achieved
                                        $results.FeedsUnlistedRemoved++
                                        Write-Verbose "Feed '$($feedToRemove.Name)' was already removed or not enabled - goal achieved"
                                    } else {
                                        $results.FeedsUnlistedRemovalFailed++
                                        Write-Warning "Failed to remove unlisted feed '$($feedToRemove.Name)' (exit code: $LASTEXITCODE)"
                                    }
                                }
                                catch {
                                    $results.FeedsUnlistedRemovalFailed++
                                    Write-Warning "Exception removing unlisted feed $($feedToRemove.Name): $($_.Exception.Message)"
                                }
                            } else {
                                Write-Verbose "Skipped removal of unlisted feed: $($feedToRemove.Name)"
                            }
                        }
                    } else {
                        Write-Information "No unlisted feeds found to remove" -InformationAction Continue
                    }
                } else {
                    Write-Information "No configured feeds found for unlisted feed removal" -InformationAction Continue
                }
            } elseif ($RemoveUnlistedFeeds -and $SkipFeeds) {
                Write-Information "Skipping unlisted feed removal (SkipFeeds=True)" -InformationAction Continue
            }

            # Phase 4: Remove unlisted packages if requested
            if ($RemoveUnlistedPackages -and -not $SkipPackages) {
                Write-Information "Phase 4: Removing packages not listed in snapshot..." -InformationAction Continue
                
                # Get current installed packages (refresh the list in case it changed during installation)
                try {
                    $currentInstalledPackages = Get-PackagesInfoFromNipkgCmd -Type "installed" -NipkgCmdPath $NipkgCmdPath
                    Write-Verbose "Found $($currentInstalledPackages.Count) currently installed packages for unlisted package removal"
                }
                catch {
                    Write-Warning "Failed to get current installed packages for unlisted removal: $($_.Exception.Message)"
                    $currentInstalledPackages = @()
                }
                
                if ($currentInstalledPackages.Count -gt 0) {
                    # Create a set of package names from the snapshot for quick lookup
                    $snapshotPackageNames = @{}
                    foreach ($pkg in $snapshot.packages) {
                        $snapshotPackageNames[$pkg.name] = $true
                    }
                    
                    # Find packages that are installed but not in the snapshot
                    $packagesToRemove = @()
                    foreach ($installedPkg in $currentInstalledPackages) {
                        if (-not $snapshotPackageNames.ContainsKey($installedPkg.Package)) {
                            $packagesToRemove += $installedPkg
                        }
                    }
                    
                    if ($packagesToRemove.Count -gt 0) {
                        Write-Information "Found $($packagesToRemove.Count) unlisted packages to remove" -InformationAction Continue
                        Write-Warning "About to remove $($packagesToRemove.Count) packages not listed in snapshot. This could remove important system packages!" -WarningAction Continue
                        
                        foreach ($packageToRemove in $packagesToRemove) {
                            if ($PSCmdlet.ShouldProcess("$($packageToRemove.Package) v$($packageToRemove.Version)", "Remove unlisted package")) {
                                try {
                                    Write-Information "Removing unlisted package: $($packageToRemove.Package) v$($packageToRemove.Version)" -InformationAction Continue
                                    & $NipkgCmdPath remove $($packageToRemove.Package) -y
                                    
                                    if ($LASTEXITCODE -eq 0) {
                                        $results.PackagesRemoved++
                                        Write-Verbose "Successfully removed unlisted package $($packageToRemove.Package)"
                                    } else {
                                        $results.PackagesRemovalFailed++
                                        Write-Warning "Failed to remove unlisted package $($packageToRemove.Package) (exit code: $LASTEXITCODE)"
                                    }
                                }
                                catch {
                                    $results.PackagesRemovalFailed++
                                    Write-Warning "Exception removing unlisted package $($packageToRemove.Package): $($_.Exception.Message)"
                                }
                            } else {
                                Write-Verbose "Skipped removal of unlisted package: $($packageToRemove.Package)"
                            }
                        }
                    } else {
                        Write-Information "No unlisted packages found to remove" -InformationAction Continue
                    }
                } else {
                    Write-Information "No installed packages found for unlisted package removal" -InformationAction Continue
                }
            } elseif ($RemoveUnlistedPackages -and $SkipPackages) {
                Write-Information "Skipping unlisted package removal (SkipPackages=True)" -InformationAction Continue
            }

            # Phase 5: Remove snapshot feeds if requested
            if ($RemoveSnapshotFeeds -and $snapshotFeedsAdded.Count -gt 0) {
                Write-Information "Phase 5: Removing snapshot feeds after package operations..." -InformationAction Continue
                
                if ($PSCmdlet.ShouldProcess("$($snapshotFeedsAdded.Count) snapshot feeds", "Remove snapshot feeds")) {
                    try {
                        # Convert snapshot feeds to the format expected by Remove-Feeds
                        $feedsToRemove = $snapshotFeedsAdded | ForEach-Object {
                            [PSCustomObject]@{
                                name = $_.name
                                uri = $_.uri
                                enabled = $true
                            }
                        }
                        
                        Write-Information "Removing $($feedsToRemove.Count) snapshot feed(s)" -InformationAction Continue
                        Remove-Feeds -FeedsInfo $feedsToRemove -NipkgCmdPath $NipkgCmdPath
                        $results.SnapshotFeedsRemoved = $feedsToRemove.Count
                        Write-Information "Successfully removed $($feedsToRemove.Count) snapshot feed(s)" -InformationAction Continue
                    }
                    catch {
                        $results.SnapshotFeedsRemovalFailed = $snapshotFeedsAdded.Count
                        Write-Warning "Failed to remove snapshot feeds: $($_.Exception.Message)"
                        # Continue - this is not a critical failure
                    }
                }
            } elseif ($RemoveSnapshotFeeds -and $snapshotFeedsAdded.Count -eq 0) {
                Write-Information "No snapshot feeds were added, nothing to remove" -InformationAction Continue
            }

            # Summary
            Write-Information "Snapshot application completed" -InformationAction Continue
            if ($results.FeedsRemoved -gt 0) {
                Write-Information "Existing feeds removed: $($results.FeedsRemoved)" -InformationAction Continue
            }
            Write-Information "Feeds: $($results.FeedsAdded) added, $($results.FeedsUnchanged) unchanged, $($results.FeedsUnlistedRemoved) unlisted removed, $($results.FeedsSkipped) skipped, $($results.FeedsFailed) failed" -InformationAction Continue
            if ($results.FeedsUnlistedRemovalFailed -gt 0) {
                Write-Information "Unlisted feed removal failures: $($results.FeedsUnlistedRemovalFailed)" -InformationAction Continue
            }
            if ($results.SnapshotFeedsRemoved -gt 0) {
                Write-Information "Snapshot feeds removed: $($results.SnapshotFeedsRemoved)" -InformationAction Continue
            }
            if ($results.SnapshotFeedsRemovalFailed -gt 0) {
                Write-Information "Snapshot feeds removal failed: $($results.SnapshotFeedsRemovalFailed)" -InformationAction Continue
            }
            Write-Information "Packages: $($results.PackagesInstalled) installed, $($results.PackagesUpgraded) upgraded, $($results.PackagesDowngraded) downgraded, $($results.PackagesUnchanged) unchanged, $($results.PackagesRemoved) removed, $($results.PackagesSkipped) skipped, $($results.PackagesFailed) failed" -InformationAction Continue
            if ($results.PackagesRemovalFailed -gt 0) {
                Write-Information "Package removal failures: $($results.PackagesRemovalFailed)" -InformationAction Continue
            }

            # Return detailed results
            $applyResult = [PSCustomObject]@{
                SnapshotPath = $SnapshotPath
                FeedsRemoved = $results.FeedsRemoved
                FeedsTotal = $snapshot.feeds.Count
                FeedsAdded = $results.FeedsAdded
                FeedsUnchanged = $results.FeedsUnchanged
                FeedsUnlistedRemoved = $results.FeedsUnlistedRemoved
                FeedsSkipped = $results.FeedsSkipped
                FeedsFailed = $results.FeedsFailed
                FeedsUnlistedRemovalFailed = $results.FeedsUnlistedRemovalFailed
                SnapshotFeedsRemoved = $results.SnapshotFeedsRemoved
                SnapshotFeedsRemovalFailed = $results.SnapshotFeedsRemovalFailed
                PackagesTotal = $snapshot.packages.Count
                PackagesInstalled = $results.PackagesInstalled
                PackagesUpgraded = $results.PackagesUpgraded
                PackagesDowngraded = $results.PackagesDowngraded
                PackagesUnchanged = $results.PackagesUnchanged
                PackagesRemoved = $results.PackagesRemoved
                PackagesSkipped = $results.PackagesSkipped
                PackagesFailed = $results.PackagesFailed
                PackagesRemovalFailed = $results.PackagesRemovalFailed
                Success = ($results.FeedsFailed -eq 0 -and $results.PackagesFailed -eq 0 -and $results.PackagesRemovalFailed -eq 0 -and $results.SnapshotFeedsRemovalFailed -eq 0 -and $results.FeedsUnlistedRemovalFailed -eq 0)
                ComplianceValidated = $false
                SystemCompliant = $null
                ComplianceSummary = "Compliance validation not requested"
                ComplianceIssues = $null
            }

            # Unlock packages that were locked during installation
            if ($LockDuringInstallation -and $packagesLocked.Count -gt 0) {
                Write-Information "Unlocking $($packagesLocked.Count) packages that were locked during installation..." -InformationAction Continue
                
                foreach ($packageToUnlock in $packagesLocked) {
                    try {
                        Write-Verbose "Unlocking package: $packageToUnlock"
                        & $NipkgCmdPath unlock $packageToUnlock
                        if ($LASTEXITCODE -eq 0) {
                            Write-Verbose "Successfully unlocked package $packageToUnlock"
                        } else {
                            Write-Warning "Failed to unlock package $packageToUnlock (exit code: $LASTEXITCODE)"
                        }
                    }
                    catch {
                        Write-Warning "Exception unlocking package $packageToUnlock : $($_.Exception.Message)"
                    }
                }
                
                Write-Information "Package unlocking completed" -InformationAction Continue
            }

            # Phase 6: Validate compliance if requested
            if ($ValidateCompliance) {
                Write-Information "Phase 6: Validating system compliance with snapshot..." -InformationAction Continue
                
                try {
                    $complianceResult = Test-NipkgSnapshotCompliance -SnapshotPath $SnapshotPath -NipkgCmdPath $NipkgCmdPath -ValidateFeeds (-not $SkipFeeds) -ValidatePackages (-not $SkipPackages) -AllowExtraFeeds $AllowExtraFeeds -AllowExtraPackages $AllowExtraPackages -FailOnNonCompliance:$FailOnNonCompliance
                    
                    # Add compliance information to the results
                    $applyResult.ComplianceValidated = $true
                    $applyResult.SystemCompliant = $complianceResult.OverallCompliant
                    $applyResult.ComplianceSummary = $complianceResult.Summary
                    $applyResult.ComplianceIssues = $complianceResult.TotalIssues
                    $applyResult | Add-Member -MemberType NoteProperty -Name "ComplianceReport" -Value $complianceResult -Force
                    
                    if ($complianceResult.OverallCompliant) {
                        Write-Information "[OK] System is compliant with snapshot" -InformationAction Continue
                    } else {
                        Write-Warning "[ERROR] System is not fully compliant with snapshot"
                        $warningMessage = [string]::Concat("Compliance issues found: ", $complianceResult.TotalIssues)
                        Write-Warning $warningMessage
                        # Note: If FailOnNonCompliance was set, Test-NipkgSnapshotCompliance would have already thrown
                    }
                }
                catch {
                    if ($_.Exception.Message -like "*not compliant*") {
                        # This is expected when FailOnNonCompliance is true
                        throw
                    } else {
                        Write-Warning "Failed to validate compliance: $($_.Exception.Message)"
                        # Add compliance failure info to results
                        $applyResult.ComplianceValidated = $false
                        $applyResult.SystemCompliant = $null
                        $applyResult.ComplianceSummary = "Validation failed: $($_.Exception.Message)"
                        $applyResult.ComplianceIssues = $null
                    }
                }
            }

            return $applyResult
        }
        catch {
            $errorMessage = "Failed to apply NIPKG snapshot - SnapshotPath: '$SnapshotPath'. Error: $($_.Exception.Message)"
            Write-Error -Message $errorMessage -Category InvalidOperation -TargetObject $SnapshotPath
            throw
        }
    }
    
    end {
        Write-Verbose "Completed Apply-NipkgSnapshot operation"
    }
}

function Test-NipkgSnapshotCompliance {
    <#
    .SYNOPSIS
        Validates that the current system state matches the desired snapshot state.

    .DESCRIPTION
        Compares the current NIPKG configuration (feeds and/or packages) against a snapshot
        to verify compliance. This function is useful for validating that Apply-NipkgSnapshot
        achieved the desired state or for ongoing compliance monitoring.

    .PARAMETER SnapshotPath
        Path to the JSON snapshot file to validate against.

    .PARAMETER NipkgCmdPath
        Path to the NIPKG command-line tool. Defaults to 'nipkg' if in PATH.

    .PARAMETER ValidateFeeds
        Whether to validate feed configuration compliance. Defaults to $true.

    .PARAMETER ValidatePackages
        Whether to validate package installation compliance. Defaults to $true.

    .PARAMETER FailOnNonCompliance
        Whether to throw an error if the system is not compliant. If false, returns
        compliance status without failing. Defaults to $false.

    .PARAMETER AllowExtraFeeds
        Allow extra feeds beyond those in the snapshot. If false, extra feeds cause
        non-compliance. Defaults to $false.

    .PARAMETER AllowExtraPackages
        Allow extra packages beyond those in the snapshot. If false, extra packages cause
        non-compliance. Defaults to $false.

    .EXAMPLE
        Test-NipkgSnapshotCompliance -SnapshotPath "snapshot.json"

    .EXAMPLE
        # Validate only packages, allow extra feeds
        Test-NipkgSnapshotCompliance -SnapshotPath "snapshot.json" -ValidateFeeds $false -AllowExtraFeeds $true

    .EXAMPLE
        # Strict validation - fail build if not compliant
        Test-NipkgSnapshotCompliance -SnapshotPath "snapshot.json" -FailOnNonCompliance

    .EXAMPLE
        # Validate feeds only with custom NIPKG path
        Test-NipkgSnapshotCompliance -SnapshotPath "snapshot.json" -ValidatePackages $false -NipkgCmdPath "C:\Program Files\NI\nipkg.exe"

    .NOTES
        Returns a compliance report object with detailed information about differences.
        Can be used in CI/CD pipelines to ensure environment consistency.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string]$SnapshotPath,
        
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$NipkgCmdPath = "nipkg",
        
        [Parameter()]
        [bool]$ValidateFeeds = $true,
        
        [Parameter()]
        [bool]$ValidatePackages = $true,
        
        [Parameter()]
        [switch]$FailOnNonCompliance,
        
        [Parameter()]
        [bool]$AllowExtraFeeds = $false,
        
        [Parameter()]
        [bool]$AllowExtraPackages = $false
    )

    begin {
        Write-Verbose "Starting Test-NipkgSnapshotCompliance operation"
    }
    
    process {
        try {
            # Import the snapshot
            Write-Information "Importing snapshot for compliance validation..." -InformationAction Continue
            $snapshot = Import-NipkgSnapshotFromJson -InputPath $SnapshotPath
            
            Write-Verbose "Snapshot contains $($snapshot.feeds.Count) feeds and $($snapshot.packages.Count) packages"

            # Initialize compliance report
            $complianceReport = [PSCustomObject]@{
                SnapshotPath = $SnapshotPath
                ValidationTime = Get-Date
                OverallCompliant = $true
                FeedsCompliant = $true
                PackagesCompliant = $true
                FeedsValidated = $ValidateFeeds
                PackagesValidated = $ValidatePackages
                MissingFeeds = @()
                ExtraFeeds = @()
                MismatchedFeeds = @()
                MissingPackages = @()
                ExtraPackages = @()
                WrongVersionPackages = @()
                TotalIssues = 0
                Summary = ""
            }

            # Validate feeds if requested
            if ($ValidateFeeds) {
                Write-Information "Validating feed compliance..." -InformationAction Continue
                
                try {
                    $currentFeeds = Get-FeedsInfoFromNipkgCmd -NipkgCmdPath $NipkgCmdPath
                    Write-Verbose "Found $($currentFeeds.Count) currently configured feeds"
                }
                catch {
                    Write-Warning "Failed to get current feeds for validation: $($_.Exception.Message)"
                    $currentFeeds = @()
                    $complianceReport.FeedsCompliant = $false
                    $complianceReport.OverallCompliant = $false
                }
                
                # Create lookup tables for comparison
                $currentFeedsLookup = @{}
                $currentFeedsByName = @{}
                foreach ($feed in $currentFeeds) {
                    $normalizedPath = $feed.Path -replace '\\', '/' -replace '/$', ''
                    $feedKey = [string]::Concat($feed.Name, "|", $normalizedPath)
                    $currentFeedsLookup[$feedKey] = $feed
                    $currentFeedsByName[$feed.Name] = $feed
                }
                
                $snapshotFeedsLookup = @{}
                $snapshotFeedsByName = @{}
                foreach ($feed in $snapshot.feeds) {
                    $normalizedUri = $feed.uri -replace '\\', '/' -replace '/$', ''
                    $feedKey = [string]::Concat($feed.name, "|", $normalizedUri)
                    $snapshotFeedsLookup[$feedKey] = $feed
                    $snapshotFeedsByName[$feed.name] = $feed
                }
                
                # Check for missing feeds (in snapshot but not in current system)
                foreach ($snapshotFeed in $snapshot.feeds) {
                    $normalizedUri = $snapshotFeed.uri -replace '\\', '/' -replace '/$', ''
                    $feedKey = [string]::Concat($snapshotFeed.name, "|", $normalizedUri)
                    
                    if (-not $currentFeedsLookup.ContainsKey($feedKey)) {
                        # Pre-calculate values for the custom object
                        $feedNotConfiguredText = "Feed not configured"
                        $uriMismatchText = "URI mismatch"
                        $issueText = $feedNotConfiguredText
                        $actualUriValue = $null
                        if ($currentFeedsByName.ContainsKey($snapshotFeed.name)) {
                            $issueText = $uriMismatchText
                            $actualUriValue = $currentFeedsByName[$snapshotFeed.name].Path
                        }

                        $complianceReport.MissingFeeds += [PSCustomObject]@{
                            Name = $snapshotFeed.name
                            ExpectedUri = $snapshotFeed.uri
                            ActualUri = $actualUriValue
                            Issue = $issueText
                        }
                        $complianceReport.FeedsCompliant = $false
                        $complianceReport.OverallCompliant = $false
                    }
                }
                
                # Check for extra feeds (in current system but not in snapshot) if not allowed
                if (-not $AllowExtraFeeds) {
                    foreach ($currentFeed in $currentFeeds) {
                        $normalizedPath = $currentFeed.Path -replace '\\', '/' -replace '/$', ''
                        $feedKey = [string]::Concat($currentFeed.Name, "|", $normalizedPath)
                        
                        if (-not $snapshotFeedsLookup.ContainsKey($feedKey)) {
                            $extraFeedIssueText = "Extra feed not in snapshot"
                            $complianceReport.ExtraFeeds += [PSCustomObject]@{
                                Name = $currentFeed.Name
                                Uri = $currentFeed.Path
                                Issue = $extraFeedIssueText
                            }
                            $complianceReport.FeedsCompliant = $false
                            $complianceReport.OverallCompliant = $false
                        }
                    }
                }
                
                Write-Verbose "Feed validation complete. Missing: $($complianceReport.MissingFeeds.Count), Extra: $($complianceReport.ExtraFeeds.Count)"
            }

            # Validate packages if requested
            if ($ValidatePackages) {
                Write-Information "Validating package compliance..." -InformationAction Continue
                
                try {
                    $installedPackages = Get-PackagesInfoFromNipkgCmd -Type "installed" -NipkgCmdPath $NipkgCmdPath
                    Write-Verbose "Found $($installedPackages.Count) currently installed packages"
                }
                catch {
                    Write-Warning "Failed to get installed packages for validation: $($_.Exception.Message)"
                    $installedPackages = @()
                    $complianceReport.PackagesCompliant = $false
                    $complianceReport.OverallCompliant = $false
                }
                
                # Create lookup tables for comparison
                $installedLookup = @{
                }
                foreach ($pkg in $installedPackages) {
                    $installedLookup[$pkg.Package] = $pkg.Version
                }
                
                $snapshotPackageLookup = @{
                }
                foreach ($pkg in $snapshot.packages) {
                    $snapshotPackageLookup[$pkg.name] = $pkg.version
                }
                
                # Check for missing packages (in snapshot but not installed)
                foreach ($snapshotPackage in $snapshot.packages) {
                    if (-not $installedLookup.ContainsKey($snapshotPackage.name)) {
                        $complianceReport.MissingPackages += [PSCustomObject]@{
                            Name = $snapshotPackage.name
                            ExpectedVersion = $snapshotPackage.version
                            Issue = "Package not installed"
                        }
                        $complianceReport.PackagesCompliant = $false
                        $complianceReport.OverallCompliant = $false
                    }
                    else {
                        # Check version compliance
                        $installedVersion = $installedLookup[$snapshotPackage.name]
                        if ($installedVersion -ne $snapshotPackage.version) {
                            $versionComparison = Compare-PackageVersions -Version1 $snapshotPackage.version -Version2 $installedVersion
                            
                            if ($versionComparison -ne 0) {
                                # Pre-calculate the issue description
                                $issueDescription = if ($versionComparison -gt 0) { "Version too low" } else { "Version too high" }
                                
                                $complianceReport.WrongVersionPackages += [PSCustomObject]@{
                                    Name = $snapshotPackage.name
                                    ExpectedVersion = $snapshotPackage.version
                                    ActualVersion = $installedVersion
                                    Issue = $issueDescription
                                }
                                $complianceReport.PackagesCompliant = $false
                                $complianceReport.OverallCompliant = $false
                            }
                        }
                    }
                }
                
                # Check for extra packages (installed but not in snapshot) if not allowed
                if (-not $AllowExtraPackages) {
                    foreach ($installedPkg in $installedPackages) {
                        if (-not $snapshotPackageLookup.ContainsKey($installedPkg.Package)) {
                            $complianceReport.ExtraPackages += [PSCustomObject]@{
                                Name = $installedPkg.Package
                                Version = $installedPkg.Version
                                Issue = "Extra package not in snapshot"
                            }
                            $complianceReport.PackagesCompliant = $false
                            $complianceReport.OverallCompliant = $false
                        }
                    }
                }
                
                Write-Verbose "Package validation complete. Missing: $($complianceReport.MissingPackages.Count), Wrong version: $($complianceReport.WrongVersionPackages.Count), Extra: $($complianceReport.ExtraPackages.Count)"
            }

            # Calculate total issues and generate summary
            $complianceReport.TotalIssues = $complianceReport.MissingFeeds.Count + $complianceReport.ExtraFeeds.Count + 
                                           $complianceReport.MissingPackages.Count + $complianceReport.ExtraPackages.Count + 
                                           $complianceReport.WrongVersionPackages.Count

            # Generate summary
            $summaryParts = @()
            if ($ValidateFeeds) {
                if ($complianceReport.FeedsCompliant) {
                    $summaryParts += "Feeds: COMPLIANT"
                } else {
                    $issueCount = $complianceReport.MissingFeeds.Count + $complianceReport.ExtraFeeds.Count
                    $summary = [string]::Concat("Feeds: NON-COMPLIANT (", $issueCount, " issues)")
                    $summaryParts += $summary
                }
            }
            
            if ($ValidatePackages) {
                if ($complianceReport.PackagesCompliant) {
                    $summaryParts += "Packages: COMPLIANT"
                } else {
                    $issueCount = $complianceReport.MissingPackages.Count + $complianceReport.ExtraPackages.Count + $complianceReport.WrongVersionPackages.Count
                    $summary = [string]::Concat("Packages: NON-COMPLIANT (", $issueCount, " issues)")
                    $summaryParts += $summary
                }
            }
            
            $complianceReport.Summary = $summaryParts -join ", "

            # Output compliance status
            if ($complianceReport.OverallCompliant) {
                Write-Information "[OK] System is COMPLIANT with snapshot" -InformationAction Continue
                Write-Information $complianceReport.Summary -InformationAction Continue
            } else {
                Write-Warning "[ERROR] System is NOT COMPLIANT with snapshot"
                Write-Warning $complianceReport.Summary
                $warningMessage = [string]::Concat("Total issues found: ", $complianceReport.TotalIssues)
                Write-Warning $warningMessage
                
                # Output detailed issues
                if ($complianceReport.MissingFeeds.Count -gt 0) {
                    $feedNames = $complianceReport.MissingFeeds.Name -join ', '
                    $warningMessage = [string]::Concat("Missing feeds: ", $feedNames)
                    Write-Warning $warningMessage
                }
                if ($complianceReport.ExtraFeeds.Count -gt 0) {
                    $feedNames = $complianceReport.ExtraFeeds.Name -join ', '
                    $warningMessage = [string]::Concat("Extra feeds: ", $feedNames)
                    Write-Warning $warningMessage
                }
                if ($complianceReport.MissingPackages.Count -gt 0) {
                    $packageNames = $complianceReport.MissingPackages.Name -join ', '
                    $warningMessage = [string]::Concat("Missing packages: ", $packageNames)
                    Write-Warning $warningMessage
                }
                if ($complianceReport.WrongVersionPackages.Count -gt 0) {
                    $packageNames = $complianceReport.WrongVersionPackages.Name -join ', '
                    $warningMessage = [string]::Concat("Wrong version packages: ", $packageNames)
                    Write-Warning $warningMessage
                }
                if ($complianceReport.ExtraPackages.Count -gt 0) {
                    $packageNames = $complianceReport.ExtraPackages.Name -join ', '
                    $warningMessage = [string]::Concat("Extra packages: ", $packageNames)
                    Write-Warning $warningMessage
                }
            }

            # Fail if requested and non-compliant
            if ($FailOnNonCompliance -and -not $complianceReport.OverallCompliant) {
                $errorMessage = [string]::Concat("System is not compliant with snapshot '", $SnapshotPath, "'. ", $complianceReport.TotalIssues, " issues found. ", $complianceReport.Summary)
                Write-Error -Message $errorMessage -Category InvalidData -TargetObject $SnapshotPath
                throw $errorMessage
            }

            return $complianceReport
        }
        catch {
            if ($_.Exception.Message -notlike "*not compliant*") {
                $errorMessage = "Failed to validate snapshot compliance - SnapshotPath: '$SnapshotPath'. Error: $($_.Exception.Message)"
                Write-Error -Message $errorMessage -Category InvalidOperation -TargetObject $SnapshotPath
            }
            throw
        }
    }
    
    end {
        Write-Verbose "Completed Test-NipkgSnapshotCompliance operation"
    }
}

function Test-FeedIsLocal {
    <#
    .SYNOPSIS
        Tests whether a feed path represents a local or online feed.

    .DESCRIPTION
        Determines if a feed path is local (file system) or online (network) based on the URI scheme or path format.

    .PARAMETER FeedPath
        The feed path/URI to test.

    .NOTES
        Returns $true for local feeds, $false for online feeds.
        Local feeds include:
        - file:// URIs
        - Windows drive paths (C:\, D:\, etc.)
        - UNC paths (\\server\share)
        - Relative paths
        
        Online feeds include:
        - http://, https:// URIs
        - ftp://, ftps:// URIs
        - Other network protocols
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$FeedPath
    )

    if ([string]::IsNullOrWhiteSpace($FeedPath)) {
        return $false
    }

    $FeedPath = $FeedPath.Trim()

    # Check for online protocols
    $onlineProtocols = @('http://', 'https://', 'ftp://', 'ftps://', 'sftp://')
    foreach ($protocol in $onlineProtocols) {
        if ($FeedPath.StartsWith($protocol, [System.StringComparison]::OrdinalIgnoreCase)) {
            return $false
        }
    }

    # Check for file:// protocol (local)
    if ($FeedPath.StartsWith('file://', [System.StringComparison]::OrdinalIgnoreCase)) {
        return $true
    }

    # Check for Windows drive letters (C:\, D:\, etc.)
    if ($FeedPath -match '^[a-zA-Z]:\\') {
        return $true
    }

    # Check for UNC paths (\\server\share)
    if ($FeedPath.StartsWith('\\')) {
        return $true
    }

    # Check for relative paths or paths without protocol
    # If it doesn't start with a protocol, assume it's local
    if (-not ($FeedPath -match '^[a-zA-Z][a-zA-Z0-9+.-]*://')) {
        return $true
    }

    # Default to online for unknown protocols
    return $false
}

function Compare-PackageVersions {
    <#
    .SYNOPSIS
        Compares two package version strings.

    .DESCRIPTION
        Compares two version strings and returns:
        - 1 if Version1 is greater than Version2
        - 0 if versions are equal
        - -1 if Version1 is less than Version2

    .PARAMETER Version1
        First version string to compare.

    .PARAMETER Version2
        Second version string to compare.

    .EXAMPLE
        Compare-PackageVersions -Version1 "2.0.0" -Version2 "1.0.0"
        Returns: 1 (Version1 is greater)

    .EXAMPLE
        Compare-PackageVersions -Version1 "1.0.0" -Version2 "1.0.0"
        Returns: 0 (versions are equal)

    .NOTES
        Handles NIPKG version formats including build metadata (e.g., 24.0.0.49212-0+f60).
        Attempts to parse as System.Version first, then strips build metadata and retries.
        Falls back to string comparison as last resort.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Version1,
        
        [Parameter(Mandatory)]
        [string]$Version2
    )

    begin {
        Write-Verbose "Starting Compare-PackageVersions operation"
        Write-Verbose "Comparing versions: '$Version1' vs '$Version2'"
    }
    
    process {
        # Quick equality check first
        if ($Version1 -eq $Version2) {
            Write-Verbose "Versions are identical strings"
            return 0
        }
        
        try {
            # Try to parse as System.Version first (works for standard formats)
            $v1 = [System.Version]::Parse($Version1)
            $v2 = [System.Version]::Parse($Version2)
            
            Write-Verbose "Successfully parsed as System.Version"
            return $v1.CompareTo($v2)
        }
        catch {
            Write-Verbose "Failed to parse as System.Version: $($_.Exception.Message)"
            
            # Strip build metadata (+xxx) and pre-release info (-xxx) for NIPKG versions
            $cleanVersion1 = $Version1 -replace '\+.*$', '' -replace '-.*$', ''
            $cleanVersion2 = $Version2 -replace '\+.*$', '' -replace '-.*$', ''
            
            Write-Verbose "Cleaned versions: '$cleanVersion1' vs '$cleanVersion2'"
            
            try {
                $v1 = [System.Version]::Parse($cleanVersion1)
                $v2 = [System.Version]::Parse($cleanVersion2)
                
                Write-Verbose "Successfully parsed cleaned versions as System.Version"
                $result = $v1.CompareTo($v2)
                
                # If core versions are equal, compare the original strings to handle pre-release/build info
                if ($result -eq 0 -and $Version1 -ne $Version2) {
                    Write-Verbose "Core versions equal, comparing full version strings"
                    if ($Version1 -gt $Version2) {
                        return 1
                    } else {
                        return -1
                    }
                }
                
                return $result
            }
            catch {
                # Fall back to string comparison if all version parsing fails
                Write-Verbose "Failed to parse cleaned versions, using string comparison"
                
                if ($Version1 -gt $Version2) {
                    return 1
                }
                else {
                    return -1
                }
            }
        }
    }
    
    end {
        Write-Verbose "Completed Compare-PackageVersions operation"
    }
}

function Get-PackageInstallationOrder {
    <#
    .SYNOPSIS
        Sorts packages into correct installation order based on dependencies.

    .DESCRIPTION
        Analyzes package dependencies from NIPKG Packages file data and returns packages
        in the correct installation order. Ensures that all dependencies are installed
        with exact versions before dependent packages, preventing NIPKG from selecting
        random compatible versions during installation.

    .PARAMETER PackagesInfo
        Array of package objects from Get-PackagesInfoFromPackagesFile containing
        package information including dependencies.

    .PARAMETER IncludeDependencyTypes
        Array of dependency types to consider for ordering. Valid values are:
        'Depends', 'Recommends', 'Suggests', 'Enhances', 'Supplements'.
        Defaults to @('Depends', 'Recommends') for critical dependencies.

    .PARAMETER AllowCircularDependencies
        Allow circular dependencies by breaking cycles at arbitrary points.
        If false, throws an error when circular dependencies are detected.

    .EXAMPLE
        $packages = Get-PackagesInfoFromPackagesFile -InputPath "C:\feeds\Packages"
        $orderedPackages = Get-PackageInstallationOrder -PackagesInfo $packages

    .EXAMPLE
        # Include all dependency types for ordering
        $packages = Get-PackagesInfoFromPackagesFile -InputPath ".\Packages"
        $orderedPackages = Get-PackageInstallationOrder -PackagesInfo $packages -IncludeDependencyTypes @('Depends', 'Recommends', 'Suggests')

    .EXAMPLE
        # Only consider hard dependencies
        $orderedPackages = Get-PackageInstallationOrder -PackagesInfo $packages -IncludeDependencyTypes @('Depends')

    .NOTES
        Returns packages ordered from least dependent (no dependencies) to most dependent.
        Packages with the same dependency level are sorted alphabetically by package name.
        
        The function performs topological sorting on the dependency graph to ensure
        that all dependencies are installed before their dependents.
        
        Dependency strings are parsed to extract package names and version constraints.
        Only packages present in the input list are considered for ordering.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [AllowEmptyCollection()]
        [PSCustomObject[]]$PackagesInfo,
        
        [Parameter()]
        [ValidateSet('Depends', 'Recommends', 'Suggests', 'Enhances', 'Supplements')]
        [string[]]$IncludeDependencyTypes = @('Depends', 'Recommends'),
        
        [Parameter()]
        [switch]$AllowCircularDependencies
    )

    begin {
        Write-Verbose "Starting Get-PackageInstallationOrder operation"
    }
    
    process {
        try {
            if (-not $PackagesInfo -or $PackagesInfo.Count -eq 0) {
                Write-Warning "No packages provided for ordering"
                return @()
            }

            Write-Information "Analyzing dependencies for $($PackagesInfo.Count) packages..." -InformationAction Continue
            Write-Verbose "Including dependency types: $($IncludeDependencyTypes -join ', ')"

            # Create a lookup table for packages by name
            $packageLookup = @{}
            foreach ($package in $PackagesInfo) {
                $packageLookup[$package.Package] = $package
            }

            # Parse dependencies for each package
            $dependencyGraph = @{}
            $allPackageNames = @($PackagesInfo | ForEach-Object { $_.Package })

            foreach ($package in $PackagesInfo) {
                $packageName = $package.Package
                $dependencies = @()

                # Extract dependencies from all specified dependency types
                foreach ($depType in $IncludeDependencyTypes) {
                    if ($package.PSObject.Properties.Name -contains $depType -and $package.$depType) {
                        $depString = $package.$depType
                        $parsedDeps = Get-ParsedDependencies -DependencyString $depString -AvailablePackages $allPackageNames
                        $dependencies += $parsedDeps
                    }
                }

                $dependencyGraph[$packageName] = @{
                    Package = $package
                    Dependencies = $dependencies | Sort-Object -Unique
                    Visited = $false
                    InStack = $false
                }

                Write-Verbose "Package '$packageName' depends on: $($dependencies -join ', ')"
            }

            Write-Verbose "Built dependency graph for $($dependencyGraph.Count) packages"

            # Perform topological sort using DFS
            $sortedPackages = @()
            $visitStack = @()

            foreach ($packageName in $dependencyGraph.Keys) {
                if (-not $dependencyGraph[$packageName].Visited) {
                    $result = Invoke-TopologicalSort -DependencyGraph $dependencyGraph -PackageName $packageName -SortedList ([ref]$sortedPackages) -VisitStack ([ref]$visitStack) -AllowCircular $AllowCircularDependencies
                    
                    if (-not $result.Success) {
                        if ($AllowCircularDependencies) {
                            Write-Warning "Circular dependency detected: $($result.ErrorMessage). Continuing with partial ordering."
                        } else {
                            throw "Circular dependency detected: $($result.ErrorMessage)"
                        }
                    }
                }
            }

            # Return the packages in installation order (DFS post-order is correct)
            # Dependencies are added first, then dependents
            
            Write-Information "Successfully ordered $($sortedPackages.Count) packages for installation" -InformationAction Continue
            Write-Verbose "Installation order: $($sortedPackages | ForEach-Object { $_.Package } | Join-String -Separator ', ')"

            return $sortedPackages
        }
        catch {
            $errorMessage = "Failed to determine package installation order. Error: $($_.Exception.Message)"
            Write-Error -Message $errorMessage -Category InvalidOperation -TargetObject $PackagesInfo
            throw
        }
    }
    
    end {
        Write-Verbose "Completed Get-PackageInstallationOrder operation"
    }
}

function Get-ParsedDependencies {
    <#
    .SYNOPSIS
        Parses NIPKG dependency strings into package names.

    .DESCRIPTION
        Internal helper function that parses NIPKG dependency strings and extracts
        package names that are available in the provided package list.

    .PARAMETER DependencyString
        The dependency string from a NIPKG package (e.g., "pkg1 (>= 1.0), pkg2, pkg3 | pkg4").

    .PARAMETER AvailablePackages
        Array of available package names to filter dependencies against.

    .NOTES
        Handles various NIPKG dependency formats:
        - Simple: "package-name"
        - Versioned: "package-name (>= 1.0.0)"
        - Multiple: "pkg1, pkg2, pkg3"
        - Alternatives: "pkg1 | pkg2 | pkg3" (returns first available)
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$DependencyString,
        
        [Parameter(Mandatory)]
        [string[]]$AvailablePackages
    )

    $dependencies = @()
    
    if ([string]::IsNullOrWhiteSpace($DependencyString)) {
        return $dependencies
    }

    # Split by comma for multiple dependencies
    $depParts = $DependencyString -split ','
    
    foreach ($depPart in $depParts) {
        $depPart = $depPart.Trim()
        
        # Skip empty parts
        if ([string]::IsNullOrWhiteSpace($depPart)) {
            continue
        }
        
        # Handle alternative dependencies (pkg1 | pkg2 | pkg3)
        if ($depPart -match '\|') {
            $alternatives = $depPart -split '\|'
            foreach ($alt in $alternatives) {
                $altTrimmed = $alt.Trim()
                if ([string]::IsNullOrWhiteSpace($altTrimmed)) {
                    continue
                }
                $cleanAlt = Get-CleanPackageName -PackageSpec $altTrimmed
                if ($cleanAlt -and $cleanAlt -in $AvailablePackages) {
                    $dependencies += $cleanAlt
                    break  # Only take the first available alternative
                }
            }
        } else {
            # Single dependency
            $cleanDep = Get-CleanPackageName -PackageSpec $depPart
            if ($cleanDep -and $cleanDep -in $AvailablePackages) {
                $dependencies += $cleanDep
            }
        }
    }

    return $dependencies
}

function Get-CleanPackageName {
    <#
    .SYNOPSIS
        Extracts clean package name from package specification.

    .DESCRIPTION
        Internal helper function that removes version constraints and other
        specifications from package names.

    .PARAMETER PackageSpec
        Package specification that may include version constraints.

    .NOTES
        Handles formats like:
        - "package-name"
        - "package-name (>= 1.0.0)"
        - "package-name (<< 2.0)"
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$PackageSpec
    )

    if ([string]::IsNullOrWhiteSpace($PackageSpec)) {
        return $null
    }

    # Remove version constraints in parentheses
    $cleanName = $PackageSpec -replace '\s*\([^)]*\)\s*', ''
    
    # Remove any remaining whitespace
    $cleanName = $cleanName.Trim()
    
    # Return null if empty after cleaning
    if ([string]::IsNullOrWhiteSpace($cleanName)) {
        return $null
    }

    return $cleanName
}

function Invoke-TopologicalSort {
    <#
    .SYNOPSIS
        Performs depth-first search topological sorting.

    .DESCRIPTION
        Internal helper function that performs DFS-based topological sorting
        to determine dependency order.

    .PARAMETER DependencyGraph
        Hashtable representing the dependency graph.

    .PARAMETER PackageName
        Current package name being processed.

    .PARAMETER SortedList
        Reference to the sorted list being built.

    .PARAMETER VisitStack
        Reference to the current visit stack for cycle detection.

    .PARAMETER AllowCircular
        Whether to allow circular dependencies.

    .NOTES
        Returns a result object with Success boolean and ErrorMessage if applicable.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [hashtable]$DependencyGraph,
        
        [Parameter(Mandatory)]
        [string]$PackageName,
        
        [Parameter(Mandatory)]
        [ref]$SortedList,
        
        [Parameter(Mandatory)]
        [ref]$VisitStack,
        
        [Parameter()]
        [bool]$AllowCircular = $false
    )

    $node = $DependencyGraph[$PackageName]
    
    # Check for circular dependency
    if ($node.InStack) {
        $cycleStart = $VisitStack.Value.IndexOf($PackageName)
        $cycle = $VisitStack.Value[$cycleStart..($VisitStack.Value.Count - 1)] + @($PackageName)
        return @{
            Success = $false
            ErrorMessage = "Circular dependency detected: $($cycle -join ' -> ')"
        }
    }

    # Skip if already visited
    if ($node.Visited) {
        return @{ Success = $true }
    }

    # Mark as in current path and add to stack
    $node.InStack = $true
    $VisitStack.Value += $PackageName

    # Visit all dependencies first
    foreach ($depName in $node.Dependencies) {
        if ($DependencyGraph.ContainsKey($depName)) {
            $result = Invoke-TopologicalSort -DependencyGraph $DependencyGraph -PackageName $depName -SortedList $SortedList -VisitStack $VisitStack -AllowCircular $AllowCircular
            
            if (-not $result.Success -and -not $AllowCircular) {
                return $result
            }
        }
    }

    # Mark as visited and remove from current path
    $node.Visited = $true
    $node.InStack = $false
    $VisitStack.Value = $VisitStack.Value[0..($VisitStack.Value.Count - 2)]  # Remove last element

    # Add to sorted list (will be reversed later)
    $SortedList.Value += $node.Package

    return @{ Success = $true }
}

Export-ModuleMember -Function `
        Add-FeedDirectories `
    ,   Test-NipkgAvailability `
    ,   Get-NipkgCommandOutput `
    ,   ConvertFrom-NipkgOutput `
    ,   ConvertFrom-NipkgPackagesFile `
    ,   Get-PackagesInfoFromNipkgCmd `
    ,   Get-PackagesInfoFromPackagesFile `
    ,   Get-PackageInstallationOrder `
    ,   Get-DriverPackages `
    ,   Get-ProgrammingEnvironmentsPackages `
    ,   Get-UtilitiesPackages `
    ,   Get-ApplicationSoftwarePackages `
    ,   Get-FeedsInfoFromNipkgCmd `
    ,   Remove-Feeds `
    ,   Install-NipkgManager `
    ,   New-NipkgSnapshot `
    ,   New-NipkgSnapshotFromInstaller `
    ,   New-NipkgSnapshotFromSystem `
    ,   Export-NipkgSnapshotToJson `
    ,   Import-NipkgSnapshotFromJson `
    ,   Apply-NipkgSnapshot `
    ,   Compare-PackageVersions `
    ,   Test-NipkgSnapshotCompliance