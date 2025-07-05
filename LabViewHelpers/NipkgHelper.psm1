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
        1. Adding all feeds from the snapshot to NIPKG
        2. Updating the package database
        3. Analyzing current package state vs. snapshot requirements
        4. Installing missing packages, upgrading outdated packages, and downgrading newer packages
        5. Leaving unchanged packages alone
        
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
        # Complete workflow: clean slate approach
        Apply-NipkgSnapshot -SnapshotPath "snapshot.json" -RemoveExistingFeeds -RemoveUnlistedPackages -RemoveSnapshotFeeds

    .NOTES
        This function requires administrator privileges for feed addition and package installation.
        The operation can take significant time depending on the number of packages.
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
        [switch]$RemoveUnlistedPackages
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
                FeedsFailed = 0
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

            # Phase 1: Add feeds
            if (-not $SkipFeeds -and $snapshot.feeds.Count -gt 0) {
                Write-Information "Phase 1: Adding feeds to NIPKG..." -InformationAction Continue
                
                foreach ($feed in $snapshot.feeds) {
                    if ($PSCmdlet.ShouldProcess($feed.name, "Add NIPKG feed")) {
                        try {
                            Write-Verbose "Adding feed: $($feed.name) -> $($feed.uri)"
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
                
                # Process each package in the snapshot in installation order
                Write-Information "Processing $($snapshot.packages.Count) packages in dependency order..." -InformationAction Continue
                
                foreach ($snapshotPackage in $snapshot.packages) {
                    $packageName = $snapshotPackage.name
                    $targetVersion = $snapshotPackage.version
                    
                    # Determine what action is needed for this package
                    $action = "none"
                    $currentVersion = $null
                    
                    if ($installedLookup.ContainsKey($packageName)) {
                        $currentVersion = $installedLookup[$packageName]
                        
                        if ($currentVersion -eq $targetVersion) {
                            # Same version - no action needed
                            $action = "none"
                            Write-Verbose "Package '$packageName' is already at target version ($targetVersion)"
                        }
                        else {
                            $versionComparison = Compare-PackageVersions -Version1 $targetVersion -Version2 $currentVersion
                            
                            if ($versionComparison -gt 0) {
                                # Upgrade needed (target version is higher)
                                $action = "upgrade"
                                Write-Verbose "Package '$packageName' needs upgrade: $currentVersion → $targetVersion"
                            }
                            elseif ($versionComparison -lt 0) {
                                # Downgrade needed (target version is lower)
                                $action = "downgrade"
                                Write-Verbose "Package '$packageName' needs downgrade: $currentVersion → $targetVersion"
                            }
                            else {
                                # Versions are considered equal by our comparison
                                $action = "none"
                                Write-Verbose "Package '$packageName' is already at equivalent version ($currentVersion ≈ $targetVersion)"
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
                        }
                        
                        "install" {
                            if ($PSCmdlet.ShouldProcess("$($packageName) v$($targetVersion)", "Install package")) {
                                try {
                                    $packageSpec = "$($packageName)=$($targetVersion)"
                                    Write-Information "Installing: $($packageName) v$($targetVersion)" -InformationAction Continue
                                    & $NipkgCmdPath install $packageSpec --accept-eulas --include-recommended -y
                                    
                                    if ($LASTEXITCODE -eq 0) {
                                        $results.PackagesInstalled++
                                        Write-Verbose "Successfully installed $($packageName) v$($targetVersion)"
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
                            if ($PSCmdlet.ShouldProcess("$($packageName) v$($currentVersion) → v$($targetVersion)", "Upgrade package")) {
                                try {
                                    $packageSpec = "$($packageName)=$($targetVersion)"
                                    Write-Information "Upgrading: $($packageName) v$($currentVersion) → v$($targetVersion)" -InformationAction Continue
                                    & $NipkgCmdPath install $packageSpec --accept-eulas --include-recommended -y
                                    
                                    if ($LASTEXITCODE -eq 0) {
                                        $results.PackagesUpgraded++
                                        Write-Verbose "Successfully upgraded $($packageName) to v$($targetVersion)"
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
                            if ($PSCmdlet.ShouldProcess("$($packageName) v$($currentVersion) → v$($targetVersion)", "Downgrade package")) {
                                try {
                                    $packageSpec = "$($packageName)=$($targetVersion)"
                                    Write-Information "Downgrading: $($packageName) v$($currentVersion) → v$($targetVersion)" -InformationAction Continue
                                    
                                    # For downgrades, we might need to use --force or uninstall first
                                    & $NipkgCmdPath install $packageSpec --accept-eulas --include-recommended -y --force
                                    
                                    if ($LASTEXITCODE -eq 0) {
                                        $results.PackagesDowngraded++
                                        Write-Verbose "Successfully downgraded $($packageName) to v$($targetVersion)"
                                    } else {
                                        # If direct downgrade fails, try uninstall then install
                                        Write-Verbose "Direct downgrade failed, trying uninstall then install approach"
                                        & $NipkgCmdPath remove $($packageName) -y
                                        
                                        if ($LASTEXITCODE -eq 0) {
                                            & $NipkgCmdPath install $packageSpec --accept-eulas --include-recommended -y
                                            
                                            if ($LASTEXITCODE -eq 0) {
                                                $results.PackagesDowngraded++
                                                Write-Verbose "Successfully downgraded $($packageName) to v$($targetVersion) using uninstall/install"
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
                
            } else {
                Write-Information "Skipping package installation (SkipPackages=$SkipPackages, Package count=$($snapshot.packages.Count))" -InformationAction Continue
            }

            # Phase 3: Remove unlisted packages if requested
            if ($RemoveUnlistedPackages -and -not $SkipPackages) {
                Write-Information "Phase 3: Removing packages not listed in snapshot..." -InformationAction Continue
                
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

            # Phase 4: Remove snapshot feeds if requested
            if ($RemoveSnapshotFeeds -and $snapshotFeedsAdded.Count -gt 0) {
                Write-Information "Phase 4: Removing snapshot feeds after package operations..." -InformationAction Continue
                
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
            Write-Information "Feeds: $($results.FeedsAdded) added, $($results.FeedsSkipped) skipped, $($results.FeedsFailed) failed" -InformationAction Continue
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
            return [PSCustomObject]@{
                SnapshotPath = $SnapshotPath
                FeedsRemoved = $results.FeedsRemoved
                FeedsTotal = $snapshot.feeds.Count
                FeedsAdded = $results.FeedsAdded
                FeedsSkipped = $results.FeedsSkipped
                FeedsFailed = $results.FeedsFailed
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
                Success = ($results.FeedsFailed -eq 0 -and $results.PackagesFailed -eq 0 -and $results.PackagesRemovalFailed -eq 0 -and $results.SnapshotFeedsRemovalFailed -eq 0)
            }
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
        Attempts to parse as System.Version first, falls back to string comparison.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Version1,
        
        [Parameter(Mandatory)]
        [string]$Version2
    )

    try {
        # Try to parse as System.Version for proper semantic versioning
        $v1 = [System.Version]::Parse($Version1)
        $v2 = [System.Version]::Parse($Version2)
        
        return $v1.CompareTo($v2)
    }
    catch {
        # Fall back to string comparison if version parsing fails
        Write-Verbose "Failed to parse versions as System.Version, using string comparison"
        
        if ($Version1 -eq $Version2) {
            return 0
        }
        elseif ($Version1 -gt $Version2) {
            return 1
        }
        else {
            return -1
        }
    }
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
    ,   Compare-PackageVersions