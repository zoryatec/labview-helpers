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

function ConvertTo-PackageSpecifications {
    <#
    .SYNOPSIS
        Converts package definitions to NIPKG package specifications.

    .DESCRIPTION
        Validates package definitions and converts them to package specifications
        in the format "package=version" for use with NIPKG commands.

    .PARAMETER PackageDefinitions
        Array of PSCustomObjects containing package information with Package and Version properties.

    .EXAMPLE
        $packages = @(
            [PSCustomObject]@{ Package = "ni-labview-2025"; Version = "25.1.3" }
            [PSCustomObject]@{ Package = "ni-vision-runtime"; Version = "2025.1.0" }
        )
        $specs = ConvertTo-PackageSpecifications -PackageDefinitions $packages

    .NOTES
        Returns array of package specifications in "package=version" format.
        Invalid package definitions are skipped with warnings.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [PSCustomObject[]]$PackageDefinitions
    )

    $packageSpecs = @()
    
    foreach ($packageDef in $PackageDefinitions) {
        # Validate package definition
        if (-not $packageDef.Package) {
            Write-Warning "Package definition missing 'Package' property, skipping"
            continue
        }
        
        if (-not $packageDef.Version) {
            Write-Warning "Package definition for '$($packageDef.Package)' missing 'Version' property, skipping"
            continue
        }
        
        $packageName = $packageDef.Package
        $packageVersion = $packageDef.Version
        $packageSpec = "$packageName=$packageVersion"
        
        $packageSpecs += $packageSpec
        Write-Verbose "Added package specification: $packageSpec"
    }
    
    return $packageSpecs
}

function Install-Packages {
    <#
    .SYNOPSIS
        Installs packages using NI Package Manager with configurable options.

    .DESCRIPTION
        A reusable function that installs packages from the pipeline using NIPKG with support
        for all standard installation options. Each package definition should contain Package
        and Version properties. This function provides a consistent interface for package
        installation across different scenarios.

    .PARAMETER PackageDefinitions
        Array of PSCustomObjects containing package information with Package and Version properties.
        Accepts input from the pipeline.

    .PARAMETER NipkgCmdPath
        Path to the NIPKG command-line tool. Defaults to 'nipkg' if in PATH.

    .PARAMETER AcceptEulas
        Automatically accept End User License Agreements during installation.

    .PARAMETER Yes
        Automatically answer 'yes' to all prompts during installation.

    .PARAMETER Simulate
        Perform a simulation of the installation without actually installing packages.

    .PARAMETER ForceLocked
        Force installation even if packages are locked.

    .PARAMETER VerboseOutput
        Enable verbose output from NIPKG command.

    .PARAMETER AllowDowngrade
        Allow downgrading packages to older versions if necessary.

    .PARAMETER AllowUninstall
        Allow uninstalling packages during dependency resolution.

    .PARAMETER InstallAlsoUpgrades
        Also install available upgrades for existing packages.

    .PARAMETER IncludeRecommended
        Include recommended packages during installation.

    .EXAMPLE
        $packages = @(
            [PSCustomObject]@{ Package = "ni-labview-2025"; Version = "25.1.3" }
            [PSCustomObject]@{ Package = "ni-vision-runtime"; Version = "2025.1.0" }
        )
        Install-Packages -PackageDefinitions $packages -AcceptEulas -Yes

    .EXAMPLE
        # Install packages with all options enabled
        Install-Packages -PackageDefinitions $packages -NipkgCmdPath "C:\Program Files\NI\nipkg.exe" -AcceptEulas -Yes -AllowDowngrade -AllowUninstall -InstallAlsoUpgrades

    .EXAMPLE
        # Simulate installation to see what would happen
        Install-Packages -PackageDefinitions $packages -Simulate -VerboseOutput

    .NOTES
        Returns installation results with success/failure status for each package.
        This function is designed to be reusable across different installation scenarios.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PSCustomObject[]]$PackageDefinitions,
        
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$NipkgCmdPath = "nipkg",
        
        [Parameter()]
        [switch]$AcceptEulas,
        
        [Parameter()]
        [switch]$Yes,
        
        [Parameter()]
        [switch]$Simulate,
        
        [Parameter()]
        [switch]$ForceLocked,
        
        [Parameter()]
        [switch]$VerboseOutput,
        
        [Parameter()]
        [switch]$AllowDowngrade,
        
        [Parameter()]
        [switch]$AllowUninstall,
        
        [Parameter()]
        [switch]$InstallAlsoUpgrades,
        
        [Parameter()]
        [switch]$IncludeRecommended
    )

    begin {
        try {
            $null = Get-Command $NipkgCmdPath -ErrorAction Stop
        }
        catch {
            throw "NIPKG command not found: $NipkgCmdPath. Please ensure NI Package Manager is installed and accessible."
        }
    }
    
    process {
        if (-not $PackageDefinitions -or $PackageDefinitions.Count -eq 0) {
            Write-Warning "No package definitions provided, skipping installation"
            return
        }
        
        $packageSpecs = ConvertTo-PackageSpecifications -PackageDefinitions $PackageDefinitions
        
        if ($packageSpecs.Count -eq 0) {
            Write-Warning "No valid package definitions found, skipping installation"
            return
        }
        
        Write-Information "Installing $($packageSpecs.Count) packages in batch mode..." -InformationAction Continue
        Write-Information "Package specifications: $($packageSpecs -join ', ')" -InformationAction Continue
        
        $arguments = @("install") + $packageSpecs
        
        if ($AcceptEulas) { $arguments += "--accept-eulas" }
        if ($Yes) { $arguments += "-y" }
        if ($Simulate) { $arguments += "--simulate" }
        if ($ForceLocked) { $arguments += "--force-locked" }
        if ($VerboseOutput) { $arguments += "--verbose" }
        if ($AllowDowngrade) { $arguments += "--allow-downgrade" }
        if ($AllowUninstall) { $arguments += "--allow-uninstall" }
        if ($InstallAlsoUpgrades) { $arguments += "--install-also-upgrades" }
        if ($IncludeRecommended) { $arguments += "--include-recommended" }
        
        & $NipkgCmdPath @arguments 2>&1

        $exitCode = $LASTEXITCODE 
        switch ($exitCode) {
            0 {
                Write-Information "Successfully installed $($packageSpecs.Count) packages"
            }
            -125071 {
                Write-Warning "Installation completed successfully but requires system restart (exit code: $exitCode)"
            }
            default {
                throw "Batch installation failed with exit code: $exitCode"
            }
        }
    }
    
    end {
    }
}

function Add-FeedDirectories {
    <#
    .SYNOPSIS
        Adds multiple directory feeds to NI Package Manager.

    .DESCRIPTION
        Scans a parent directory for subdirectories and adds each as a feed to NIPKG.
        Updates the package database after adding all feeds. Feed names are generated
        from folder names using ConvertTo-FeedName to ensure compatibility with feed
        naming requirements.

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
        Feed names are automatically generated from folder names using ConvertTo-FeedName
        which replaces dots (.) with underscores (_) for compatibility.
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
                    # Convert folder name to valid feed name
                    $feedName = ConvertTo-FeedName -FolderName $dir.Name
                    Write-Verbose "Adding feed directory: $($dir.Name) as feed name: $feedName"
                    Write-Information "Adding feed: $feedName (from folder: $($dir.Name))" -InformationAction Continue
                    & $NipkgCmdPath feed-add "$($dir.FullName)" --name="$feedName"
                    
                    if ($LASTEXITCODE -ne 0) {
                        Write-Warning "Failed to add feed: $feedName"
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

function Get-FeedDefinitionsFromSystem {
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
        Get-FeedDefinitionsFromSystem

    .EXAMPLE
        Get-FeedDefinitionsFromSystem -NipkgCmdPath "C:\Program Files\NI\nipkg.exe"

    .EXAMPLE
        # Get only online feeds
        Get-FeedDefinitionsFromSystem -ExcludeLocalFeeds

    .EXAMPLE
        # Get only local feeds
        Get-FeedDefinitionsFromSystem -ExcludeOnlineFeeds

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
        Write-Verbose "Starting Get-FeedDefinitionsFromSystem operation"
        
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
        Write-Verbose "Completed Get-FeedDefinitionsFromSystem operation"
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
        $feeds = Get-FeedDefinitionsFromSystem
        Remove-Feeds -FeedsInfo $feeds

    .EXAMPLE
        Remove-Feeds -FeedsInfo $feedsToRemove -NipkgCmdPath "C:\Program Files\NI\nipkg.exe"

    .NOTES
        Use Get-FeedDefinitionsFromSystem to get the required FeedsInfo object.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
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
        
        When exactly one ni-package-manager package is found in the PackagesInfo, the function 
        automatically resolves all its dependencies using Resolve-PackageDependencies and creates 
        a separate packages-nipkg section containing these dependencies ordered for installation 
        using Get-PackageInstallationOrder. This ensures that NIPKG package dependencies are 
        properly tracked and can be installed in the correct order when applying snapshots.
        
        If more than one ni-package-manager package is found, the function will throw an error
        and stop processing, as only exactly one ni-package-manager package is allowed per snapshot.

    .PARAMETER FeedsInfo
        PSCustomObject containing feed information from Get-FeedDefinitionsFromSystem.

    .PARAMETER PackagesInfo
        PSCustomObject containing package information from Get-PackagesInfoFromNipkgCmd.

    .PARAMETER Type
        Specifies the type of snapshot to create. Valid values are:
        - Full: Include all packages (default behavior)
        - UserVisible: Include only packages where UserVisible is 'yes'
        - StoreProduct: Include only packages where StoreProduct is 'yes'

    .EXAMPLE
        $feeds = Get-FeedDefinitionsFromSystem
        $packages = Get-PackagesInfoFromNipkgCmd -Type "installed"
        $snapshot = New-NipkgSnapshot -FeedsInfo $feeds -PackagesInfo $packages

    .EXAMPLE
        # Create snapshot with only user-visible packages
        $snapshot = New-NipkgSnapshot -FeedsInfo $feeds -PackagesInfo $packages -Type "UserVisible"

    .EXAMPLE
        # Create snapshot with only store products
        $snapshot = New-NipkgSnapshot -FeedsInfo $feeds -PackagesInfo $packages -Type "StoreProduct"

    .NOTES
        Returns a hashtable with:
        - type: Snapshot type (Full, UserVisible, or StoreProduct)
        - feeds: Array of feeds with name and uri
        - packages: Array of packages with name and version (filtered based on Type)
        - packages-nipkg: Array of ni-package-manager packages and their resolved dependencies ordered for installation (only present when exactly one ni-package-manager package is found)
        
        The packages-nipkg section includes all dependencies for the ni-package-manager package
        found in the PackagesInfo, ordered for optimal installation sequence. This ensures that 
        when snapshots are applied, all NIPKG dependencies are available for installation in the
        correct order. NIPKG packages will also appear in the regular packages section 
        (duplicated), which is expected behavior.
        
        If more than one ni-package-manager package is found in the input, an error will be
        thrown and processing will stop.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [AllowEmptyCollection()]
        [PSCustomObject[]]$FeedsInfo,
        
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateNotNull()]
        [PSCustomObject[]]$PackagesInfo,
        
        [Parameter()]
        [ValidateSet("Full", "UserVisible", "StoreProduct")]
        [string]$Type = "Full"
    )

    begin {
        Write-Verbose "Starting New-NipkgSnapshot operation"
    }
    
    process {
        try {
            Write-Verbose "Formatting feeds information"

            # Check for multiple ni-package-manager packages BEFORE ordering/filtering
            Write-Verbose "Checking for multiple ni-package-manager packages in input..."
            $nipkgPackagesInInput = $PackagesInfo | Where-Object { 
                $_.Package -eq "ni-package-manager"
            }
            
            if ($nipkgPackagesInInput.Count -gt 1) {
                $errorMessage = "Multiple ni-package-manager packages found ($($nipkgPackagesInInput.Count) instances). Only exactly one ni-package-manager package is allowed per snapshot. Found packages: $($nipkgPackagesInInput | ForEach-Object { "$($_.Package) v$($_.Version)" } | Join-String -Separator ', ')"
                Write-Error -Message $errorMessage -Category InvalidData
                throw $errorMessage
            }

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
            
            # Apply type-based filtering
            Write-Verbose "Applying snapshot type filtering: $Type"
            $originalCount = $filteredPackages.Count
            
            switch ($Type) {
                "UserVisible" {
                    $filteredPackages = $filteredPackages | Where-Object { $_.UserVisible -eq 'yes' }
                    Write-Verbose "Filtered to UserVisible packages: $($filteredPackages.Count) (was $originalCount)"
                }
                "StoreProduct" {
                    $filteredPackages = $filteredPackages | Where-Object { $_.StoreProduct -eq 'yes' }
                    Write-Verbose "Filtered to StoreProduct packages: $($filteredPackages.Count) (was $originalCount)"
                }
                "Full" {
                    Write-Verbose "Using all packages (Full type): $($filteredPackages.Count)"
                }
                default {
                    Write-Warning "Unknown snapshot type '$Type', using Full type"
                }
            }
            
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
            
            # Resolve dependencies for ni-package-manager and create packages-nipkg section
            Write-Verbose "Resolving dependencies for ni-package-manager packages..."
            $packagesNipkg = @()
            
            # Find ni-package-manager packages in the filtered packages (already validated above)
            $nipkgPackages = $filteredPackages | Where-Object { 
                $_.Package -eq "ni-package-manager"
            }
            
            if ($nipkgPackages.Count -eq 1) {
                Write-Verbose "Found exactly one ni-package-manager package"
                
                foreach ($nipkgPackage in $nipkgPackages) {
                    try {
                        Write-Verbose "Resolving dependencies for ni-package-manager package: $($nipkgPackage.Package) v$($nipkgPackage.Version)"
                        
                        # Resolve all dependencies for this ni-package-manager package
                        $resolvedDependencies = Resolve-PackageDependencies -PackageName $nipkgPackage.Package -PackagesInfo $PackagesInfo -IncludeRootPackage $true -AllowCircularDependencies $true
                        
                        Write-Verbose "Resolved $($resolvedDependencies.Count) dependencies for $($nipkgPackage.Package)"
                        
                        # Apply installation order to the resolved dependencies
                        try {
                            Write-Verbose "Ordering resolved dependencies for optimal installation sequence..."
                            $orderedDependencies = Get-PackageInstallationOrder -PackagesInfo $resolvedDependencies -AllowCircularDependencies
                            Write-Verbose "Successfully ordered $($orderedDependencies.Count) dependencies (circular dependencies allowed)"
                        }
                        catch {
                            Write-Warning "Dependency ordering failed for $($nipkgPackage.Package), using original order: $($_.Exception.Message)"
                            $orderedDependencies = $resolvedDependencies
                        }
                        
                        # Add ordered dependencies to packages-nipkg section
                        foreach ($dependency in $orderedDependencies) {
                            # Check if not already added (avoid duplicates)
                            $existingPackage = $packagesNipkg | Where-Object { $_.name -eq $dependency.Package }
                            if (-not $existingPackage) {
                                $packagesNipkg += [ordered]@{
                                    name = $dependency.Package
                                    version = $dependency.Version
                                }
                            }
                        }
                    }
                    catch {
                        Write-Warning "Failed to resolve dependencies for ni-package-manager package '$($nipkgPackage.Package)': $($_.Exception.Message)"
                        # Still add the ni-package-manager package itself even if dependency resolution fails
                        $existingPackage = $packagesNipkg | Where-Object { $_.name -eq $nipkgPackage.Package }
                        if (-not $existingPackage) {
                            $packagesNipkg += [ordered]@{
                                name = $nipkgPackage.Package
                                version = $nipkgPackage.Version
                            }
                        }
                    }
                }
                
                Write-Verbose "Created packages-nipkg section with $($packagesNipkg.Count) package(s)"
            } else {
                Write-Verbose "No ni-package-manager packages found in the package list"
                Write-Verbose "Packages-nipkg section will not be created"
            }
            
            # Create the snapshot object
            $snapshot = @{
                type = $Type
                feeds = $feeds
                packages = $packages
            }
            
            # Only add packages-nipkg section if ni-package-manager packages were found
            if ($packagesNipkg.Count -gt 0) {
                $snapshot["packages-nipkg"] = $packagesNipkg
                Write-Verbose "Added packages-nipkg section with $($packagesNipkg.Count) package(s)"
            } else {
                Write-Verbose "Skipped packages-nipkg section (no ni-package-manager packages found)"
            }
            
            if ($packagesNipkg.Count -gt 0) {
                Write-Verbose "Snapshot object contains type '$Type', $($feeds.Count) feeds, $($packages.Count) packages, and $($packagesNipkg.Count) NIPKG packages with dependencies"
            } else {
                Write-Verbose "Snapshot object contains type '$Type', $($feeds.Count) feeds and $($packages.Count) packages"
            }
            
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
                $nipkgPackagesCount = if ($Snapshot."packages-nipkg") { $Snapshot."packages-nipkg".Count } else { 0 }
                $snapshotType = if ($Snapshot.type) { $Snapshot.type } else { "Unknown" }
                
                Write-Verbose "Exported snapshot contains type '$snapshotType', $feedsCount feeds, $packagesCount packages, and $nipkgPackagesCount NIPKG packages"
                
                # Return summary information
                return [PSCustomObject]@{
                    SnapshotPath = $OutputPath
                    Type = $snapshotType
                    FeedsCount = $feedsCount
                    PackagesCount = $packagesCount
                    NipkgPackagesCount = $nipkgPackagesCount
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
        - type: Snapshot type (Full, UserVisible, StoreProduct, or Unknown if not specified)
        - feeds: Array of feeds with name and uri properties
        - packages: Array of packages with name and version properties
        - packages-nipkg: Array of NIPKG packages with name and version properties (if present)
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
                type = if ($snapshotData.type) { $snapshotData.type } else { "Unknown" }
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
            
            # Process packages-nipkg if they exist
            if ($snapshotData."packages-nipkg") {
                Write-Verbose "Processing $($snapshotData.'packages-nipkg'.Count) NIPKG packages"
                $snapshot."packages-nipkg" = @()
                foreach ($package in $snapshotData."packages-nipkg") {
                    $snapshot."packages-nipkg" += [ordered]@{
                        name = $package.name
                        version = $package.version
                    }
                }
            }
            
            Write-Information "Snapshot imported successfully: $InputPath" -InformationAction Continue
            
            $nipkgPackagesCount = if ($snapshot."packages-nipkg") { $snapshot."packages-nipkg".Count } else { 0 }
            $snapshotType = $snapshot.type
            if ($nipkgPackagesCount -gt 0) {
                Write-Verbose "Imported snapshot contains type '$snapshotType', $($snapshot.feeds.Count) feeds, $($snapshot.packages.Count) packages, and $nipkgPackagesCount NIPKG packages"
            } else {
                Write-Verbose "Imported snapshot contains type '$snapshotType', $($snapshot.feeds.Count) feeds and $($snapshot.packages.Count) packages"
            }
            
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
        
        The function automatically detects and includes:
        - Standard feeds in the 'feeds' subdirectory
        - Special NIPKG feed in 'bin/ni-package-manager-packages' (for offline installers)
        
        Feed names are generated from folder names using ConvertTo-FeedName to ensure
        compatibility with feed naming requirements (dots are replaced with underscores).
        
        Duplicate packages (same name, different versions) are automatically removed by 
        selecting the highest version of each package before creating the snapshot.

    .PARAMETER InstallerDirectory
        Path to the installer directory containing the feeds subdirectory.

    .PARAMETER IncludeFeeds
        Whether to include feed information in the snapshot. Defaults to $true.

    .PARAMETER Type
        Specifies the type of snapshot to create. Valid values are:
        - Full: Include all packages
        - UserVisible: Include only packages where UserVisible is 'yes'
        - StoreProduct: Include only packages where StoreProduct is 'yes' (default behavior)

    .EXAMPLE
        $snapshot = New-NipkgSnapshotFromInstaller -InstallerDirectory "C:\Installers\ni-labview-2025-community-x86_25.1.3_offline"

    .EXAMPLE
        $snapshot = New-NipkgSnapshotFromInstaller -InstallerDirectory ".\installers\labview-2025" -IncludeFeeds $false

    .EXAMPLE
        # Create snapshot with only user-visible packages from installer
        $snapshot = New-NipkgSnapshotFromInstaller -InstallerDirectory ".\installers\labview-2025" -Type "UserVisible"

    .NOTES
        Returns a hashtable with:
        - feeds: Array of feeds with name and uri (if IncludeFeeds is true)
        - packages: Array of packages with name and version from all feeds
        
        Feed names are automatically converted using ConvertTo-FeedName to ensure compatibility
        (e.g., "ni-488.2" becomes "ni-488_2", "ni-vivado-2021.1-cg" becomes "ni-vivado-2021_1-cg").
        
        The function looks for:
        1. A 'feeds' subdirectory and scans all subdirectories for Packages files
        2. A special 'bin/ni-package-manager-packages' directory for NIPKG packages (offline installers)
        
        Duplicate packages are automatically removed by selecting the highest version of each package.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string]$InstallerDirectory,
        
        [Parameter()]
        [bool]$IncludeFeeds = $true,
        
        [Parameter()]
        [ValidateSet("Full", "UserVisible", "StoreProduct")]
        [string]$Type = "StoreProduct"
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

            # Check for special NIPKG feed in bin directory (for offline installers)
            $nipkgFeedDirectory = Join-Path -Path $InstallerDirectory -ChildPath "bin\ni-package-manager-packages"
            if (Test-Path -Path $nipkgFeedDirectory -PathType Container) {
                Write-Information "Found special NIPKG feed in bin directory" -InformationAction Continue
                Write-Verbose "Processing special NIPKG feed: $nipkgFeedDirectory"
                
                $nipkgPackagesFile = Join-Path -Path $nipkgFeedDirectory -ChildPath "Packages"
                if (Test-Path -Path $nipkgPackagesFile -PathType Leaf) {
                    try {
                        # Parse packages from the NIPKG feed
                        $nipkgPackages = Get-PackagesInfoFromPackagesFile -InputPath $nipkgPackagesFile
                        Write-Verbose "Found $($nipkgPackages.Count) packages in NIPKG feed"
                        
                        # Add packages to the combined collection
                        $allPackages += $nipkgPackages
                        
                        # Add feed information if requested
                        if ($IncludeFeeds) {
                            $nipkgFeedInfo = [PSCustomObject]@{
                                Name = "ni-package-manager-packages"
                                Path = $nipkgFeedDirectory
                            }
                            $allFeeds += $nipkgFeedInfo
                        }
                        
                        Write-Information "Successfully processed NIPKG feed with $($nipkgPackages.Count) packages" -InformationAction Continue
                    }
                    catch {
                        Write-Warning "Failed to parse packages from NIPKG feed: $($_.Exception.Message)"
                    }
                } else {
                    Write-Warning "No Packages file found in NIPKG feed directory: $nipkgFeedDirectory"
                }
            } else {
                Write-Verbose "No special NIPKG feed found in bin directory"
            }

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
                            $feedName = ConvertTo-FeedName -FolderName $feedDir.Name
                            $feedInfo = [PSCustomObject]@{
                                Name = $feedName
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

            # Remove duplicate packages by selecting highest version
            Write-Verbose "Removing duplicate packages by selecting highest versions"
            $uniquePackages = Remove-DuplicatePackagesByVersion -PackagesInfo $allPackages
            Write-Information "After duplicate removal: $($uniquePackages.Count) unique packages (removed $($allPackages.Count - $uniquePackages.Count) duplicates)" -InformationAction Continue

            $snapshot = New-NipkgSnapshot -FeedsInfo $allFeeds -PackagesInfo $uniquePackages -Type $Type
            
            Write-Verbose "Created snapshot with type '$Type', $($snapshot.feeds.Count) feeds and $($snapshot.packages.Count) packages"
            
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
        and installed packages. This function combines Get-FeedDefinitionsFromSystem, Get-PackagesInfo, 
        and New-NipkgSnapshot to create a complete system state snapshot.

    .PARAMETER PackageType
        Specifies whether to capture 'installed' or 'available' packages. Defaults to 'installed'.

    .PARAMETER NipkgCmdPath
        Path to the NIPKG command-line tool. Defaults to 'nipkg' if in PATH.

    .PARAMETER IncludeFeeds
        Whether to include current feed configuration in the snapshot. Defaults to $true.

    .PARAMETER Type
        Specifies the type of snapshot to create. Valid values are:
        - Full: Include all packages
        - UserVisible: Include only packages where UserVisible is 'yes'
        - StoreProduct: Include only packages where StoreProduct is 'yes' (default behavior)

    .EXAMPLE
        $snapshot = New-NipkgSnapshotFromSystem

    .EXAMPLE
        $snapshot = New-NipkgSnapshotFromSystem -PackageType "installed" -IncludeFeeds $true

    .EXAMPLE
        $snapshot = New-NipkgSnapshotFromSystem -PackageType "available" -NipkgCmdPath "C:\Program Files\NI\nipkg.exe"

    .EXAMPLE
        # Create snapshot with only user-visible packages from current system
        $snapshot = New-NipkgSnapshotFromSystem -Type "UserVisible"

    .NOTES
        Returns a hashtable with:
        - type: Snapshot type (Full, UserVisible, StoreProduct)
        - feeds: Array of current feeds with name and uri (if IncludeFeeds is true)
        - packages: Array of packages with name and version based on PackageType and Type filter
        
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
        [bool]$IncludeFeeds = $true,
        
        [Parameter()]
        [ValidateSet("Full", "UserVisible", "StoreProduct")]
        [string]$Type = "StoreProduct"
    )

    begin {
        Write-Verbose "Starting New-NipkgSnapshotFromSystem operation"
    }
    
    process {
        try {
            Write-Information "Creating NIPKG snapshot from current system state..." -InformationAction Continue
            Write-Verbose "Package type: $PackageType, Include feeds: $IncludeFeeds, Snapshot type: $Type"

            # Initialize collections
            $feedsInfo = @()
            $packagesInfo = @()

            # Get current feeds if requested
            if ($IncludeFeeds) {
                Write-Information "Retrieving current feed configuration..." -InformationAction Continue
                Write-Verbose "Getting feeds info from NIPKG command"
                
                try {
                    $feedsInfo = Get-FeedDefinitionsFromSystem -NipkgCmdPath $NipkgCmdPath -ExcludeLocalFeeds
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
            Write-Verbose "Creating snapshot with type '$Type', $($feedsInfo.Count) feeds and $($packagesInfo.Count) packages"
            
            $snapshot = New-NipkgSnapshot -FeedsInfo $feedsInfo -PackagesInfo $packagesInfo -Type $Type
            
            Write-Information "System snapshot created successfully" -InformationAction Continue
            Write-Verbose "Snapshot contains type '$($snapshot.type)', $($snapshot.feeds.Count) feeds and $($snapshot.packages.Count) packages"
            
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

    .PARAMETER SyncNipkgVersion
        Synchronize the NIPKG version with the version specified in the snapshot after processing 
        feeds and updating the package database. If the snapshot contains an 'ni-package-manager' 
        package, this will update the current NIPKG installation to match that version. This ensures 
        compatibility between the snapshot requirements and the package manager version. The sync 
        happens after feeds are added so that offline installer feeds are available for accessing 
        the required NIPKG version.

    .PARAMETER ExcludePackages
        Array of package names to exclude from installation. These packages will be skipped even 
        if they are present in the snapshot. Useful for avoiding problematic packages or when 
        certain packages should not be installed in specific environments. Package names should 
        match exactly as they appear in the snapshot.

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
        # Exclude specific packages from installation
        Apply-NipkgSnapshot -SnapshotPath "snapshot.json" -ExcludePackages @("problematic-package", "optional-package")

    .EXAMPLE
        # Complete workflow: clean slate approach
        Apply-NipkgSnapshot -SnapshotPath "snapshot.json" -RemoveExistingFeeds -RemoveUnlistedPackages -RemoveUnlistedFeeds -RemoveSnapshotFeeds

    .NOTES
        This function requires administrator privileges for feed addition and package installation.
        The operation can take significant time depending on the number of packages.
        
        PACKAGE DATABASE UPDATES:
        The function automatically runs 'nipkg update' before package installation to ensure
        the package database contains the latest information from all configured feeds. This
        happens regardless of whether feeds were added during this operation. If you see 
        "Missing packages" errors, verify that:
        1. All required feeds are accessible and contain the missing packages
        2. The 'nipkg update' command completed successfully (check the output)
        3. Network connectivity is available for online feeds
        
        By default, packages are installed using batch installation with hardcoded flags 
        (--allow-downgrade --allow-uninstall --install-also-upgrades) to give NIPKG maximum 
        flexibility in resolving dependencies. The --include-recommended flag is NOT used to 
        prevent automatic installation of dependencies that should be installed in the intended order.
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
        [switch]$SyncNipkgVersion,
        
        [Parameter()]
        [string[]]$ExcludePackages = @()
    )

    begin {
        Write-Verbose "Starting Apply-NipkgSnapshot operation"
    }
    
    process {
        try {
            $installSwitches = @{
                    NipkgCmdPath = $NipkgCmdPath
                    ForceLocked = $true
                    AcceptEulas = $true
                    Yes = $true
                    AllowDowngrade = $true
                    AllowUninstall = $true
                    InstallAlsoUpgrades = $true
                    VerboseOutput = $true
                    IncludeRecommended = $true
                }

            Write-Information "Importing NIPKG snapshot..."
            $snapshot = Import-NipkgSnapshotFromJson -InputPath $SnapshotPath
            $originalPackageCount = $snapshot.packages.Count    
            Write-Information "Snapshot contains $($snapshot.feeds.Count) feeds and $($snapshot.packages.Count) packages" -InformationAction Continue

            if($RemoveExistingFeeds) {
                Write-Information "Removing existing feeds..."
                Get-FeedDefinitionsFromSystem -NipkgCmdPath $NipkgCmdPath | Remove-Feeds -NipkgCmdPath $NipkgCmdPath
            }

            $snapshotFeedsAdded = @()
            if (-not $SkipFeeds -and $snapshot.feeds.Count -gt 0) {
                Write-Information "Adding feeds from snapshot..."
                $snapshotFeedsAdded = $snapshot.feeds | Add-Feeds -NipkgCmdPath $NipkgCmdPath
            }

            if (-not $SkipPackages -and $snapshot.packages.Count -gt 0) {
                Write-Information "Installing Packages..."
                Get-PackageDefinitionsFromSnapshot -Snapshot $snapshot | Install-Packages @installSwitches   
            }

            if ($RemoveSnapshotFeeds -and $snapshotFeedsAdded.Count -gt 0) {
                Write-Information "Removing feeds added by snapshot..."  
                $snapshotFeedsAdded | Remove-Feeds -NipkgCmdPath $NipkgCmdPath
            } 

            Write-Information "Snapshot application completed successfully"

            # Create simple result object focused on compliance
            $applyResult = [PSCustomObject]@{
                SnapshotPath = $SnapshotPath
                Success = $true
                ComplianceValidated = $false
                SystemCompliant = $null
                ComplianceSummary = "Compliance validation not requested"
            }

            # Phase 6: Validate compliance if requested
            if ($ValidateCompliance) {
                Write-Information "Phase 6: Validating system compliance with snapshot..." -InformationAction Continue
                
                try {
                    Test-NipkgSnapshotCompliance -SnapshotPath $SnapshotPath -NipkgCmdPath $NipkgCmdPath -ValidateFeeds (-not $SkipFeeds) -ValidatePackages (-not $SkipPackages) -AllowExtraFeeds $AllowExtraFeeds -AllowExtraPackages $AllowExtraPackages -FailOnNonCompliance:$FailOnNonCompliance
                    
                    # Add compliance information to the results
                    $applyResult.ComplianceValidated = $true
                    $applyResult.SystemCompliant = $complianceResult.OverallCompliant
                    $applyResult.ComplianceSummary = $complianceResult.Summary
                    $applyResult | Add-Member -MemberType NoteProperty -Name "ComplianceReport" -Value $complianceResult -Force
                    
                    if ($complianceResult.OverallCompliant) {
                        Write-Information "[OK] System is compliant with snapshot" -InformationAction Continue
                    } else {
                        Write-Warning "[ERROR] System is not fully compliant with snapshot"
                        Write-Warning "Compliance issues found: $($complianceResult.TotalIssues)"
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

    .PARAMETER Snapshot
        The imported snapshot object containing packages and their versions.

    .PARAMETER NipkgCmdPath
        Path to the current NIPKG command-line tool.

    .PARAMETER Force
        Force version alignment even if the current version is newer than snapshot version.

    .OUTPUTS
        PSCustomObject with:
        - VersionChanged: Boolean indicating if version was changed
        - OldVersion: Previous NIPKG version
        - NewVersion: New NIPKG version (if changed)
        - UpdatedPath: Updated path to NIPKG executable (in case it changed)

    .EXAMPLE
        $result = Sync-NipkgVersionWithSnapshot -Snapshot $snapshot -NipkgCmdPath $nipkgPath
        if ($result.VersionChanged) {
            Write-Host "NIPKG updated from $($result.OldVersion) to $($result.NewVersion)"
        }

    .NOTES
        This function looks for 'ni-package-manager' packages in the snapshot and
        attempts to align the current installation with the snapshot version.
        Requires administrative privileges for NIPKG installation/upgrade.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Snapshot,

        [Parameter(Mandatory = $true)]
        [string]$NipkgCmdPath,

        [Parameter()]
        [switch]$Force
    )

    begin {
        Write-Verbose "Starting NIPKG version synchronization with snapshot"
    }

    process {
        try {
            $result = [PSCustomObject]@{
                VersionChanged = $false
                OldVersion = $null
                NewVersion = $null
                UpdatedPath = $NipkgCmdPath
                Message = "No version change needed"
            }

            # Find NIPKG package in snapshot
            $nipkgPackageInSnapshot = $Snapshot.packages | Where-Object { 
                $_.name -match '^ni-package-manager$' -or $_.name -match '^ni-package-manager-core$'
            } | Select-Object -First 1

            if (-not $nipkgPackageInSnapshot) {
                Write-Verbose "No ni-package-manager package found in snapshot, skipping version alignment"
                $result.Message = "No NIPKG package found in snapshot"
                return $result
            }

            $snapshotNipkgVersion = $nipkgPackageInSnapshot.version
            Write-Verbose "Snapshot requires NIPKG version: $snapshotNipkgVersion"

            # Get current NIPKG version
            $currentNipkgVersion = $null
            try {
                $versionOutput = & $NipkgCmdPath --version 2>$null
                if ($LASTEXITCODE -eq 0 -and $versionOutput) {
                    # Parse version from output like "NI Package Manager 25.3.0"
                    if ($versionOutput -match "(\d+\.\d+\.\d+)") {
                        $currentNipkgVersion = $matches[1]
                    }
                }
            } catch {
                Write-Verbose "Failed to get current NIPKG version: $($_.Exception.Message)"
            }

            if (-not $currentNipkgVersion) {
                Write-Warning "Cannot determine current NIPKG version, skipping version alignment"
                $result.Message = "Unable to determine current NIPKG version"
                return $result
            }

            Write-Verbose "Current NIPKG version: $currentNipkgVersion"
            $result.OldVersion = $currentNipkgVersion

            # Compare versions
            $versionComparison = Compare-PackageVersions -Version1 $snapshotNipkgVersion -Version2 $currentNipkgVersion

            if ($versionComparison -eq 0) {
                Write-Information "NIPKG version already matches snapshot: $currentNipkgVersion" -InformationAction Continue
                $result.Message = "Version already matches"
                return $result
            }

            $versionAction = if ($versionComparison -gt 0) { "upgrade" } else { "downgrade" }
            
            if ($versionComparison -lt 0 -and -not $Force) {
                Write-Warning "Current NIPKG version ($currentNipkgVersion) is newer than snapshot version ($snapshotNipkgVersion)"
                Write-Information "Use -Force to downgrade NIPKG to snapshot version" -InformationAction Continue
                $result.Message = "Current version newer than snapshot (use -Force to downgrade)"
                return $result
            }

            # Perform version alignment
            Write-Information "NIPKG version mismatch detected - need to $versionAction from $currentNipkgVersion to $snapshotNipkgVersion" -InformationAction Continue
            
            try {
                # Check if we have the target NIPKG version available in feeds
                $availableNipkgPackages = @()
                try {
                    $feedPackages = Get-PackagesInfoFromNipkgCmd -NipkgCmdPath $NipkgCmdPath -IncludeDescription $false
                    $availableNipkgPackages = $feedPackages | Where-Object { 
                        $_.Name -match '^ni-package-manager' -and $_.Version -eq $snapshotNipkgVersion 
                    }
                } catch {
                    Write-Verbose "Failed to check available NIPKG packages: $($_.Exception.Message)"
                }

                if ($availableNipkgPackages.Count -eq 0) {
                    Write-Warning "Target NIPKG version $snapshotNipkgVersion not available in current feeds"
                    $result.Message = "Target version not available in feeds"
                    return $result
                }

                # Attempt to install/upgrade NIPKG to target version
                Write-Information "Attempting to $versionAction NIPKG to version $snapshotNipkgVersion..." -InformationAction Continue
                
                $packageSpec = "$($nipkgPackageInSnapshot.name)=$snapshotNipkgVersion"
                & $NipkgCmdPath install $packageSpec --accept-eulas -y --allow-downgrade --allow-uninstall

                if ($LASTEXITCODE -eq 0) {
                    Write-Information "Successfully ${versionAction}d NIPKG to version $snapshotNipkgVersion" -InformationAction Continue
                    $result.VersionChanged = $true
                    $result.NewVersion = $snapshotNipkgVersion
                    $result.Message = "Successfully ${versionAction}d NIPKG"
                    
                    # Verify the update worked
                    Start-Sleep -Seconds 2  # Give system time to update
                    try {
                        $newVersionOutput = & $NipkgCmdPath --version 2>$null
                        if ($newVersionOutput -match "(\d+\.\d+\.\d+)") {
                            $verifiedVersion = $matches[1]
                            if ($verifiedVersion -eq $snapshotNipkgVersion) {
                                Write-Verbose "NIPKG version update verified: $verifiedVersion"
                            } else {
                                Write-Warning "NIPKG version update may not have taken effect (expected: $snapshotNipkgVersion, got: $verifiedVersion)"
                            }
                        }
                    } catch {
                        Write-Verbose "Could not verify NIPKG version after update: $($_.Exception.Message)"
                    }
                } else {
                    $results.PackagesFailed++
                    Write-Warning "Failed to $versionAction NIPKG (exit code: $LASTEXITCODE)"
                }

            } catch {
                Write-Warning "Exception during NIPKG version alignment: $($_.Exception.Message)"
                $result.Message = "Exception during version alignment: $($_.Exception.Message)"
            }

            return $result

        } catch {
            Write-Error "Failed to synchronize NIPKG version with snapshot: $($_.Exception.Message)"
            throw
        }
    }
    
    end {
        Write-Verbose "Completed NIPKG version synchronization"
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
                    $currentFeeds = Get-FeedDefinitionsFromSystem -NipkgCmdPath $NipkgCmdPath
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
                            $complianceReport.ExtraFeeds += [PSCustomObject]@{
                                Name = $currentFeed.Name
                                Uri = $currentFeed.Path
                                Issue = "Extra feed not in snapshot"
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
                    # Get installed packages using the same Type filter as the original snapshot
                    $snapshotType = if ($snapshot.type) { $snapshot.type } else { "Full" }
                    Write-Verbose "Using snapshot type '$snapshotType' for compliance validation"
                    
                    # Create a system snapshot with the same Type to get filtered packages for comparison
                    $systemSnapshot = New-NipkgSnapshotFromSystem -PackageType "installed" -IncludeFeeds $false -Type $snapshotType -NipkgCmdPath $NipkgCmdPath
                    $installedPackages = $systemSnapshot.packages
                    
                    Write-Verbose "Found $($installedPackages.Count) currently installed packages matching snapshot type '$snapshotType'"
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
                    $installedLookup[$pkg.name] = $pkg.version
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
                        if (-not $snapshotPackageLookup.ContainsKey($installedPkg.name)) {
                            $complianceReport.ExtraPackages += [PSCustomObject]@{
                                Name = $installedPkg.name
                                Version = $installedPkg.version
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
        $orderedPackages = Get-PackageInstallationOrder -PackagesInfo $packages -AllowCircularDependencies

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
            $result = Invoke-TopologicalSort -DependencyGraph $DependencyGraph -PackageName $depName -SortedList $SortedList -VisitStack $VisitStack -AllowCircular $AllowCircularDependencies
            
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

function Sync-NipkgVersionWithSnapshot {
    <#
    .SYNOPSIS
        Installs packages from the packages-nipkg section in order.

    .DESCRIPTION
        Installs all packages from the packages-nipkg section of a snapshot in the correct order.
        This ensures that NIPKG-related packages and their dependencies are installed properly
        without version checking - simply installs all packages in the specified order.

    .PARAMETER Snapshot
        The snapshot object containing the packages-nipkg section with ordered packages.

    .PARAMETER NipkgCmdPath
        Path to the NIPKG command-line tool. Defaults to 'nipkg' if in PATH.

    .PARAMETER Force
        This parameter is retained for compatibility but is not used in the current implementation.

    .OUTPUTS
        PSCustomObject with:
        - PackagesInstalled: Number of packages successfully installed
        - PackagesFailed: Number of packages that failed to install
        - InstalledPackages: Array of successfully installed package names
        - FailedPackages: Array of failed package names with error details

    .EXAMPLE
        $snapshot = Import-NipkgSnapshotFromJson -InputPath "snapshot.json"
        $result = Sync-NipkgVersionWithSnapshot -Snapshot $snapshot -NipkgCmdPath "nipkg"
        Write-Host "Installed $($result.PackagesInstalled) packages successfully"

    .NOTES
        This function installs packages from the packages-nipkg section in the order they appear.
        No version checking is performed - all packages are installed with their specified versions.
        Requires administrative privileges for package installation.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory)]
        [PSCustomObject]$Snapshot,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$NipkgCmdPath = "nipkg",

        [Parameter()]
        [switch]$Force
    )

    begin {
        Write-Verbose "Starting Sync-NipkgVersionWithSnapshot operation"
    }
    
    process {
        try {
            $result = [PSCustomObject]@{
                PackagesInstalled = 0
                PackagesFailed = 0
                InstalledPackages = @()
                FailedPackages = @()
            }

            # Check if the snapshot has a packages-nipkg section
            if (-not $Snapshot."packages-nipkg" -or $Snapshot."packages-nipkg".Count -eq 0) {
                Write-Information "No packages-nipkg section found in snapshot or section is empty - no packages to install" -InformationAction Continue
                return $result
            }

            $packagesToInstall = $Snapshot."packages-nipkg"
            Write-Information "Installing $($packagesToInstall.Count) packages from packages-nipkg section in order..." -InformationAction Continue

            # Install packages in order
            foreach ($package in $packagesToInstall) {
                $packageName = $package.name
                $packageVersion = $package.version
                $packageSpec = "$packageName=$packageVersion"

                Write-Information "Installing package: $packageSpec" -InformationAction Continue

                if ($PSCmdlet.ShouldProcess($packageSpec, "Install NIPKG package")) {
                    try {
                        Write-Verbose "Executing: & $NipkgCmdPath install $packageSpec --accept-eulas -y --allow-downgrade --allow-uninstall --force-locked"
                        & $NipkgCmdPath install $packageSpec --accept-eulas -y --allow-downgrade --allow-uninstall

                        if ($LASTEXITCODE -eq 0) {
                            Write-Information "Successfully installed: $packageSpec" -InformationAction Continue
                            $result.PackagesInstalled++
                            $result.InstalledPackages += $packageSpec
                        }
                        else {
                            Write-Warning "Failed to install: $packageSpec (exit code: $LASTEXITCODE)"
                            $result.PackagesFailed++
                            $result.FailedPackages += [PSCustomObject]@{
                                Package = $packageSpec
                                ExitCode = $LASTEXITCODE
                                Error = "NIPKG install command failed"
                            }
                        }
                    }
                    catch {
                         Write-Warning "Exception installing: $packageSpec - $($_.Exception.Message)"
                        $result.PackagesFailed++
                        $result.FailedPackages += [PSCustomObject]@{
                            Package = $packageSpec
                            ExitCode = $null
                            Error = $_.Exception.Message
                        }
                    }
                }
            }

            # Summary
            Write-Information "Package installation completed:" -InformationAction Continue
            Write-Information "  Successfully installed: $($result.PackagesInstalled) packages" -InformationAction Continue
            if ($result.PackagesFailed -gt 0) {
                Write-Information "  Failed to install: $($result.PackagesFailed) packages" -InformationAction Continue
            }

            return $result
        }
        catch {
            $errorMessage = "Failed to install packages from packages-nipkg section. Error: $($_.Exception.Message)"
            Write-Error -Message $errorMessage -Category InvalidOperation
            throw
        }
    }
    
    end {
        Write-Verbose "Completed Sync-NipkgVersionWithSnapshot operation"
    }
}

function Resolve-PackageDependencies {
    <#
    .SYNOPSIS
        Resolves all dependencies for a given package name using provided package information.

    .DESCRIPTION
        Takes a package name and a collection of package information (as returned by 
        Get-PackagesInfoFromPackagesFile or similar functions) and recursively resolves 
        all dependencies for the specified package. Only uses the provided package 
        information and does not make external queries.

    .PARAMETER PackageName
        The name of the package for which to resolve dependencies.

    .PARAMETER PackagesInfo
        Array of package objects containing package information including dependencies.
        Typically obtained from Get-PackagesInfoFromPackagesFile, Get-PackagesInfoFromNipkgCmd,
        or similar functions.

    .PARAMETER IncludeDependencyTypes
        Array of dependency types to consider for resolution. Valid values are:
        'Depends', 'Recommends', 'Suggests', 'Enhances', 'Supplements'.
        Defaults to @('Depends', 'Recommends') for critical dependencies.

    .PARAMETER IncludeRootPackage
        Whether to include the root package in the returned dependency list.
        Defaults to $true.

    .PARAMETER AllowCircularDependencies
        Allow circular dependencies by breaking cycles when detected.
        If false, throws an error when circular dependencies are detected.
        Defaults to $true for practical real-world scenarios.

    .EXAMPLE
        # Get package info from a Packages file
        $packages = Get-PackagesInfoFromPackagesFile -InputPath "C:\feeds\Packages"
        
        # Resolve all dependencies for a specific package
        $dependencies = Resolve-PackageDependencies -PackageName "ni-labview-2025" -PackagesInfo $packages

    .EXAMPLE
        # Get package info from installer and resolve dependencies
        $snapshot = New-NipkgSnapshotFromInstaller -InstallerDirectory "C:\Installers\labview-2025"
        $allPackages = $snapshot.packages | ForEach-Object { 
            # Convert snapshot format back to package info format
            [PSCustomObject]@{
                Package = $_.name
                Version = $_.version
                # Note: Dependencies would need to be included in the package info
            }
        }
        $dependencies = Resolve-PackageDependencies -PackageName "my-package" -PackagesInfo $allPackages

    .EXAMPLE
        # Only resolve hard dependencies (Depends), exclude root package
        $dependencies = Resolve-PackageDependencies -PackageName "my-package" -PackagesInfo $packages -IncludeDependencyTypes @('Depends') -IncludeRootPackage $false

    .EXAMPLE
        # Strict mode - fail on circular dependencies
        $dependencies = Resolve-PackageDependencies -PackageName "my-package" -PackagesInfo $packages -AllowCircularDependencies $false

    .NOTES
        Returns an array of package objects representing all resolved dependencies.
        The returned packages are in dependency order (dependencies before dependents).
        
        The function performs recursive dependency resolution:
        1. Finds the specified package in the provided package info
        2. Extracts its dependencies based on the specified dependency types
        3. Recursively resolves dependencies of those dependencies
        4. Returns all unique dependencies in proper installation order
        
        Dependency strings are parsed to extract package names and version constraints.
        Only packages present in the provided PackagesInfo are considered.
        
        If a dependency is not found in PackagesInfo, it is silently skipped with a warning.
        This allows for partial dependency resolution when not all packages are available
        in the provided data set.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string]$PackageName,
        
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateNotNull()]
        [PSCustomObject[]]$PackagesInfo,
        
        [Parameter()]
        [ValidateSet('Depends', 'Recommends', 'Suggests', 'Enhances', 'Supplements')]
        [string[]]$IncludeDependencyTypes = @('Depends', 'Recommends'),
        
        [Parameter()]
        [bool]$IncludeRootPackage = $true,
        
        [Parameter()]
        [bool]$AllowCircularDependencies = $true
    )

    begin {
        Write-Verbose "Starting Resolve-PackageDependencies operation"
    }
    
    process {
        try {
            if (-not $PackagesInfo -or $PackagesInfo.Count -eq 0) {
                Write-Warning "No package information provided"
                return @()
            }

            Write-Verbose "Resolving dependencies for package: $PackageName"
            Write-Verbose "Including dependency types: $($IncludeDependencyTypes -join ', ')"
            Write-Verbose "Searching in $($PackagesInfo.Count) available packages"

            # Create a lookup table for packages by name
            $packageLookup = @{}
            foreach ($package in $PackagesInfo) {
                $packageLookup[$package.Package] = $package
            }

            # Check if the root package exists
            if (-not $packageLookup.ContainsKey($PackageName)) {
                throw "Package '$PackageName' not found in provided package information"
            }

            # Initialize tracking collections
            $resolvedPackages = @{}      # Track resolved packages to avoid duplicates
            $resolutionStack = @()       # Track current resolution path for circular dependency detection
            $allPackageNames = @($PackagesInfo | ForEach-Object { $_.Package })

            # Internal function to recursively resolve dependencies
            function Resolve-PackageRecursive {
                param (
                    [string]$CurrentPackageName,
                    [hashtable]$PackageLookup,
                    [hashtable]$ResolvedPackages,
                    [System.Collections.Generic.List[string]]$ResolutionStack,
                    [string[]]$AllPackageNames,
                    [string[]]$DependencyTypes,
                    [bool]$AllowCircular
                )

                Write-Verbose "Resolving dependencies for: $CurrentPackageName"

                # Check for circular dependency
                if ($ResolutionStack.Contains($CurrentPackageName)) {
                    $cyclePath = ($ResolutionStack + $CurrentPackageName) -join ' -> '
                    $errorMessage = "Circular dependency detected: $cyclePath"
                    
                    if ($AllowCircular) {
                        Write-Warning $errorMessage
                        return  # Break the cycle by returning early
                    } else {
                        throw $errorMessage
                    }
                }

                # Check if already resolved
                if ($ResolvedPackages.ContainsKey($CurrentPackageName)) {
                    Write-Verbose "Package '$CurrentPackageName' already resolved"
                    return
                }

                # Get the package information
                $currentPackage = $PackageLookup[$CurrentPackageName]
                if (-not $currentPackage) {
                    Write-Warning "Package '$CurrentPackageName' not found in package information - skipping"
                    return
                }

                # Add to resolution stack for circular dependency detection
                $null = $ResolutionStack.Add($CurrentPackageName)

                try {
                    # Extract dependencies for this package
                    $dependencies = @()
                    foreach ($depType in $DependencyTypes) {
                        if ($currentPackage.PSObject.Properties.Name -contains $depType -and $currentPackage.$depType) {
                            $depString = $currentPackage.$depType
                            $parsedDeps = Get-ParsedDependencies -DependencyString $depString -AvailablePackages $AllPackageNames
                            $dependencies += $parsedDeps
                        }
                    }

                    # Remove duplicates and sort
                    $dependencies = $dependencies | Sort-Object -Unique

                    Write-Verbose "Package '$CurrentPackageName' has dependencies: $($dependencies -join ', ')"

                    # Recursively resolve each dependency first
                    foreach ($dependency in $dependencies) {
                        if ($PackageLookup.ContainsKey($dependency)) {
                            $null = Resolve-PackageRecursive -CurrentPackageName $dependency -PackageLookup $PackageLookup -ResolvedPackages $ResolvedPackages -ResolutionStack $ResolutionStack -AllPackageNames $allPackageNames -DependencyTypes $DependencyTypes -AllowCircular $AllowCircularDependencies
                        } else {
                            Write-Warning "Dependency '$dependency' of package '$CurrentPackageName' not found in package information - skipping"
                        }
                    }

                    # Add current package to resolved list (after its dependencies)
                    $ResolvedPackages[$CurrentPackageName] = $currentPackage
                    Write-Verbose "Resolved package: $CurrentPackageName"

                } finally {
                    # Remove from resolution stack
                    $null = $ResolutionStack.Remove($CurrentPackageName)
                }
            }

            # Start recursive resolution
            $stackList = New-Object System.Collections.Generic.List[string]
            $null = Resolve-PackageRecursive -CurrentPackageName $PackageName -PackageLookup $packageLookup -ResolvedPackages $resolvedPackages -ResolutionStack $stackList -AllPackageNames $allPackageNames -DependencyTypes $IncludeDependencyTypes -AllowCircular $AllowCircularDependencies

            # Prepare result - create an ordered list of packages
            $result = [System.Collections.ArrayList]::new()

            # Add dependencies in resolution order (dependencies come first)
            foreach ($packageName in $resolvedPackages.Keys) {
                if ($IncludeRootPackage -or $packageName -ne $PackageName) {
                    $null = $result.Add($resolvedPackages[$packageName])
                }
            }

            Write-Information "Successfully resolved $($result.Count) dependencies for package '$PackageName'" -InformationAction Continue
            Write-Verbose "Resolved packages: $($result | ForEach-Object { $_.Package } | Join-String -Separator ', ')"

            # Return as array to ensure proper type
            return $result.ToArray()
        }
        catch {
            $errorMessage = "Failed to resolve dependencies for package '$PackageName'. Error: $($_.Exception.Message)"
            Write-Error -Message $errorMessage -Category InvalidOperation -TargetObject $PackageName
            throw
        }
    }
    
    end {
        Write-Verbose "Completed Resolve-PackageDependencies operation"
    }
}

function Remove-DuplicatePackagesByVersion {
    <#
    .SYNOPSIS
        Removes duplicate packages by selecting the highest version of each package.

    .DESCRIPTION
        Takes an array of package objects and removes duplicates based on the Package name,
        keeping only the package with the highest version for each unique package name.
        Uses the Compare-PackageVersions function for consistent version comparison logic.

    .PARAMETER PackagesInfo
        Array of PSCustomObject containing package information with Package and Version properties.

    .EXAMPLE
        $uniquePackages = Remove-DuplicatePackagesByVersion -PackagesInfo $allPackages

    .NOTES
        Returns an array of unique packages with the highest version for each package name.
        Preserves all other properties of the package objects.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [PSCustomObject[]]$PackagesInfo
    )

    begin {
        Write-Verbose "Starting Remove-DuplicatePackagesByVersion operation"
    }
    
    process {
        try {
            if ($PackagesInfo.Count -eq 0) {
                Write-Verbose "No packages provided, returning empty array"
                return @()
            }
            
            Write-Verbose "Processing $($PackagesInfo.Count) packages for duplicate removal"
            
            # Group packages by name
            $packageGroups = $PackagesInfo | Group-Object -Property Package
            
            $uniquePackages = @()
            
            foreach ($group in $packageGroups) {
                if ($group.Count -eq 1) {
                    # Only one version, add it directly
                    $uniquePackages += $group.Group[0]
                    Write-Verbose "Package '$($group.Name)': single version $($group.Group[0].Version)"
                } else {
                    # Multiple versions, select the highest
                    Write-Verbose "Package '$($group.Name)': found $($group.Count) versions"
                    
                    $highestVersionPackage = $group.Group[0]
                    
                    foreach ($package in $group.Group[1..($group.Count-1)]) {
                        # Use existing Compare-PackageVersions function for consistency
                        $comparisonResult = Compare-PackageVersions -Version1 $package.Version -Version2 $highestVersionPackage.Version
                        
                        if ($comparisonResult -gt 0) {
                            Write-Verbose "  Selected higher version: $($package.Version) > $($highestVersionPackage.Version)"
                            $highestVersionPackage = $package
                        }
                    }
                    
                    $uniquePackages += $highestVersionPackage
                    Write-Verbose "Package '$($group.Name)': selected version $($highestVersionPackage.Version) from $($group.Count) versions"
                }
            }
            
            Write-Verbose "Removed $($PackagesInfo.Count - $uniquePackages.Count) duplicate packages, returning $($uniquePackages.Count) unique packages"
            return $uniquePackages
        }
        catch {
            $errorMessage = "Failed to remove duplicate packages: $($_.Exception.Message)"
            Write-Error -Message $errorMessage -Category InvalidOperation
            throw
        }
    }
    
    end {
        Write-Verbose "Completed Remove-DuplicatePackagesByVersion operation"
    }
}

function ConvertTo-FeedName {
    <#
    .SYNOPSIS
        Converts a folder name to a valid feed name.

    .DESCRIPTION
        Transforms a folder name into a valid feed name by applying naming conventions.
        Currently replaces dots (.) with underscores (_) to ensure compatibility with
        feed naming requirements. This function can be extended in the future to apply
        additional transformations as needed.

    .PARAMETER FolderName
        The folder name to convert to a feed name.

    .EXAMPLE
        $feedName = ConvertTo-FeedName -FolderName "ni-software-2025.q1"
        # Returns: "ni-software-2025_q1"

    .EXAMPLE
        $feedName = ConvertTo-FeedName -FolderName "drivers.24.8"
        # Returns: "drivers_24_8"

    .NOTES
        Current transformations:
        - Replaces dots (.) with underscores (_)
        
        This function is designed to be easily extensible for future naming
        convention requirements.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [string]$FolderName
    )

    begin {
        Write-Verbose "Starting ConvertTo-FeedName operation"
    }
    
    process {
        try {
            Write-Verbose "Converting folder name '$FolderName' to feed name"
            
            # Apply naming transformations
            $feedName = $FolderName
            
            # Replace dots with underscores
            $feedName = $feedName -replace '\.', '-'
            
            Write-Verbose "Converted '$FolderName' to feed name '$feedName'"
            
            return $feedName
        }
        catch {
            $errorMessage = "Failed to convert folder name to feed name - FolderName: '$FolderName'. Error: $($_.Exception.Message)"
            Write-Error -Message $errorMessage -Category InvalidOperation
            throw
        }
    }
    
    end {
        Write-Verbose "Completed ConvertTo-FeedName operation"
    }
}

function Get-PackageDefinitionsFromSnapshot {
    <#
    .SYNOPSIS
        Converts snapshot packages section into package definitions for use with Install-Packages.

    .DESCRIPTION
        Takes a snapshot object and converts its packages section into an array of package 
        definitions with Package and Version properties that can be used with Install-Packages
        function for batch installation.

    .PARAMETER Snapshot
        Hashtable containing the snapshot data with packages section.

    .EXAMPLE
        $snapshot = Import-NipkgSnapshotFromJson -InputPath "snapshot.json"
        $packageDefinitions = Get-PackageDefinitionsFromSnapshot -Snapshot $snapshot
        Install-Packages -PackageDefinitions $packageDefinitions -AcceptEulas -Yes

    .EXAMPLE
        # Direct pipeline usage
        $snapshot | Get-PackageDefinitionsFromSnapshot | Install-Packages -AcceptEulas -Yes -AllowDowngrade

    .NOTES
        Returns an array of PSCustomObjects with Package and Version properties.
        This function is designed to be a bridge between snapshot format and Install-Packages function.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNull()]
        [hashtable]$Snapshot
    )

    begin {
        Write-Verbose "Starting Get-PackageDefinitionsFromSnapshot operation"
    }
    
    process {
        try {
            # Validate snapshot structure
            if (-not $Snapshot.packages) {
                Write-Warning "Snapshot does not contain a packages section"
                return @()
            }
            
            if ($Snapshot.packages.Count -eq 0) {
                Write-Verbose "Snapshot packages section is empty"
                return @()
            }
            
            Write-Verbose "Converting $($Snapshot.packages.Count) snapshot packages to package definitions"
            
            # Convert snapshot packages (name/version) to package definitions (Package/Version)
            $packageDefinitions = @()
            
            foreach ($snapshotPackage in $Snapshot.packages) {
                # Validate snapshot package structure
                if (-not $snapshotPackage.name) {
                    Write-Warning "Snapshot package missing 'name' property, skipping"
                    continue
                }
                
                if (-not $snapshotPackage.version) {
                    Write-Warning "Snapshot package '$($snapshotPackage.name)' missing 'version' property, skipping"
                    continue
                }
                
                # Create package definition for Install-Packages
                $packageDef = [PSCustomObject]@{
                    Package = $snapshotPackage.name
                    Version = $snapshotPackage.version
                }
                
                $packageDefinitions += $packageDef
                Write-Verbose "Converted: $($snapshotPackage.name) v$($snapshotPackage.version) -> Package: $($packageDef.Package), Version: $($packageDef.Version)"
            }
            
            Write-Verbose "Successfully converted $($packageDefinitions.Count) package definitions"
            return $packageDefinitions
        }
        catch {
            $errorMessage = "Failed to convert snapshot packages to package definitions. Error: $($_.Exception.Message)"
            Write-Error -Message $errorMessage -Category InvalidOperation -TargetObject $Snapshot
            throw
        }
    }
    
    end {
        Write-Verbose "Completed Get-PackageDefinitionsFromSnapshot operation"
    }
}

function Add-Feeds {
    <#
    .SYNOPSIS
        Adds feeds to the system, avoiding duplicates.

    .DESCRIPTION
        This function adds feeds to the system. It checks for existing feeds
        by comparing both name and URI to avoid duplicates. If a feed with the same name but different
        URI already exists, it will show a warning but still attempt to add the new feed.

        After adding feeds, it updates the package database to ensure the latest package information
        is available.

    .PARAMETER FeedDefinitions
        Array of feed objects containing 'name' and 'uri' properties to be added.

    .PARAMETER NipkgCmdPath
        Path to the NIPKG command-line tool. Defaults to 'nipkg' if in PATH.

    .OUTPUTS
        Returns an array of feeds that were successfully added to the system.

    .EXAMPLE
        $feeds = @(
            @{ name = "my-feed"; uri = "C:\feeds\my-feed" },
            @{ name = "online-feed"; uri = "https://example.com/feed" }
        )
        $addedFeeds = Add-Feeds -FeedDefinitions $feeds

    .EXAMPLE
        $snapshot = Import-NipkgSnapshotFromJson -InputPath "snapshot.json"
        $addedFeeds = Add-Feeds -FeedDefinitions $snapshot.feeds -NipkgCmdPath "C:\Program Files\NI\nipkg.exe"
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [object]$FeedDefinition,
        
        [Parameter()]
        [string]$NipkgCmdPath = 'nipkg'
    )

    begin {
        Write-Verbose "Starting Add-Feeds operation"
        $script:feedsAdded = @()
        
        # Get currently configured feeds for duplicate checking
        Write-Information "Retrieving currently configured feeds..." -InformationAction Continue
        try {
            $script:currentFeeds = Get-FeedDefinitionsFromSystem -NipkgCmdPath $NipkgCmdPath
            Write-Verbose "Found $($script:currentFeeds.Count) currently configured feeds"
        }
        catch {
            Write-Warning "Failed to get current feeds list: $($_.Exception.Message)"
            $script:currentFeeds = @()
        }
        
        # Create lookup table for current feeds (by name and path)
        $script:currentFeedsLookup = @{}
        foreach ($currentFeed in $script:currentFeeds) {
            # Create a key combining name and normalized path for comparison
            $normalizedPath = $currentFeed.Path -replace '\\', '/' -replace '/$', ''
            $lookupKey = "$($currentFeed.Name)|$normalizedPath"
            $script:currentFeedsLookup[$lookupKey] = $currentFeed
        }
    }
    
    process {
        # Process the individual feed definition
        $feed = $FeedDefinition
        
        # Validate feed definition
        if ([string]::IsNullOrWhiteSpace($feed.name)) {
            Write-Warning "Feed definition has null or empty name - skipping"
            return
        }
        
        if ([string]::IsNullOrWhiteSpace($feed.uri)) {
            Write-Warning "Feed definition has null or empty URI - skipping"
            return
        }
        
        # Normalize the feed URI for comparison
        $normalizedUri = $feed.uri -replace '\\', '/' -replace '/$', ''
        $feedLookupKey = "$($feed.name)|$normalizedUri"
        
        # Check if this feed already exists with the same name and URI
        if ($script:currentFeedsLookup.ContainsKey($feedLookupKey)) {
            Write-Verbose "Feed '$($feed.name)' already exists with URI '$($feed.uri)' - skipping"
            Write-Information "Skipping feed '$($feed.name)' - already configured" -InformationAction Continue
            
            # Still track it as an added feed in case we need to remove it later
            $script:feedsAdded += $feed
        }
        else {
            # Check if a feed with the same name but different URI exists
            $existingFeedWithSameName = $script:currentFeeds | Where-Object { $_.Name -eq $feed.name }
            if ($existingFeedWithSameName) {
                Write-Warning "Feed with name '$($feed.name)' already exists but with different URI: '$($existingFeedWithSameName.Path)' vs '$($feed.uri)'"
            }
            
            # Feed doesn't exist - add it
            try {
                Write-Verbose "Adding new feed: $($feed.name) -> $($feed.uri)"
                Write-Information "Adding feed: $($feed.name)" -InformationAction Continue
                
                & $NipkgCmdPath feed-add "$($feed.uri)" --name="$($feed.name)" 2>&1
                
                if ($LASTEXITCODE -eq 0) {
                    $script:feedsAdded += $feed
                    Write-Verbose "Successfully added feed: $($feed.name)"
                } else {
                    Write-Warning "Failed to add feed '$($feed.name)' (exit code: $LASTEXITCODE)"
                }
            }
            catch {
                Write-Warning "Failed to add feed '$($feed.name)': $($_.Exception.Message)"
            }
        }
    }
    
    end {
        if ($script:feedsAdded.Count -gt 0) {
            Write-Information "Updating package database to ensure latest package information..." -InformationAction Continue
            & $NipkgCmdPath update 2>&1
            
            if ($LASTEXITCODE -eq 0) {
                Write-Information "Package database updated successfully" -InformationAction Continue
            } else {
                Write-Warning "Package database update failed (exit code: $LASTEXITCODE)"
                Write-Warning "This may cause package installation failures due to missing package information"
            }
        }
        
        Write-Verbose "Completed Add-Feeds operation"
        return $script:feedsAdded
    }
}

Export-ModuleMember -Function `
        Add-Feeds `
    ,   Add-FeedDirectories `
    ,   Test-NipkgAvailability `
    ,   Get-NipkgCommandOutput `
    ,   ConvertFrom-NipkgOutput `
    ,   ConvertFrom-NipkgPackagesFile `
    ,   ConvertTo-PackageSpecifications `
    ,   Get-PackagesInfoFromNipkgCmd `
    ,   Get-PackagesInfoFromPackagesFile `
    ,   Get-PackageDefinitionsFromSnapshot `
    ,   Get-PackageInstallationOrder `
    ,   Get-DriverPackages `
    ,   Get-ProgrammingEnvironmentsPackages `
    ,   Get-UtilitiesPackages `
    ,   Get-ApplicationSoftwarePackages `
    ,   Get-FeedDefinitionsFromSystem `
    ,   Add-Feeds `
    ,   Remove-Feeds `
    ,   Install-Packages `
    ,   Install-NipkgManager `
    ,   New-NipkgSnapshot `
    ,   New-NipkgSnapshotFromInstaller `
    ,   New-NipkgSnapshotFromSystem `
    ,   Export-NipkgSnapshotToJson `
    ,   Import-NipkgSnapshotFromJson `
    ,   Apply-NipkgSnapshot `
    ,   Compare-PackageVersions `
    ,   Sync-NipkgVersionWithSnapshot `
    ,   Test-NipkgSnapshotCompliance `
    ,   Test-NipkgSnapshotDependencies `
    ,   Resolve-PackageDependencies `
    ,   Remove-DuplicatePackagesByVersion `
    ,   ConvertTo-FeedName