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
    <#
    .SYNOPSIS
        Retrieves information about configured NIPKG feeds.

    .DESCRIPTION
        Gets a list of all currently configured package feeds from NI Package Manager,
        including feed names and their associated paths.

    .PARAMETER NipkgCmdPath
        Path to the NIPKG command-line tool. Defaults to 'nipkg' if in PATH.

    .EXAMPLE
        Get-FeedsInfo

    .EXAMPLE
        Get-FeedsInfo -NipkgCmdPath "C:\Program Files\NI\nipkg.exe"

    .NOTES
        Returns PSCustomObject with Name and Path properties for each feed.
    #>
    [CmdletBinding()]
    param (
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$NipkgCmdPath = "nipkg" 
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
        $feeds = Get-FeedsInfo
        Remove-Feeds -FeedsInfo $feeds

    .EXAMPLE
        Remove-Feeds -FeedsInfo $feedsToRemove -NipkgCmdPath "C:\Program Files\NI\nipkg.exe"

    .NOTES
        Use Get-FeedsInfo to get the required FeedsInfo object.
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



function Get-PackagesInfo {
    <#
    .SYNOPSIS
        Retrieves package information from NI Package Manager.

    .DESCRIPTION
        Gets detailed information about either installed or available packages from NIPKG,
        parsing the output into structured PSCustomObject format.

    .PARAMETER Type
        Specifies whether to get 'installed' or 'available' packages.

    .PARAMETER NipkgCmdPath
        Path to the NIPKG command-line tool. Defaults to 'nipkg' if in PATH.

    .EXAMPLE
        Get-PackagesInfo -Type "installed"

    .EXAMPLE
        Get-PackagesInfo -Type "available" -NipkgCmdPath "C:\Program Files\NI\nipkg.exe"

    .NOTES
        Returns an array of PSCustomObjects with package properties parsed from NIPKG output.
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
    <#
    .SYNOPSIS
        Filters package information to return only driver packages.

    .DESCRIPTION
        Filters the provided package information to include only packages in the "Drivers" section.

    .PARAMETER PackagesInfo
        PSCustomObject array containing package information from Get-PackagesInfo.

    .EXAMPLE
        $packages = Get-PackagesInfo -Type "installed"
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
        PSCustomObject array containing package information from Get-PackagesInfo.

    .EXAMPLE
        $packages = Get-PackagesInfo -Type "available"
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
        PSCustomObject array containing package information from Get-PackagesInfo.

    .EXAMPLE
        $packages = Get-PackagesInfo -Type "installed"
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
        PSCustomObject array containing package information from Get-PackagesInfo.

    .EXAMPLE
        $packages = Get-PackagesInfo -Type "available"
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

function New-NipkgSnapshot {
    <#
    .SYNOPSIS
        Creates a snapshot object from provided NIPKG feeds and packages information.

    .DESCRIPTION
        Formats feeds and packages information from provided PSObjects into a structured object.
        This object can be serialized to JSON or used for other purposes.

    .PARAMETER FeedsInfo
        PSCustomObject containing feed information from Get-FeedsInfo.

    .PARAMETER PackagesInfo
        PSCustomObject containing package information from Get-PackagesInfo.

    .EXAMPLE
        $feeds = Get-FeedsInfo
        $packages = Get-PackagesInfo -Type "installed"
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
            foreach ($package in $PackagesInfo) {
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

Export-ModuleMember -Function `
        Add-FeedDirectories `
    ,   Get-PackagesInfo `
    ,   Get-DriverPackages `
    ,   Get-ProgrammingEnvironmentsPackages `
    ,   Get-UtilitiesPackages `
    ,   Get-ApplicationSoftwarePackages `
    ,   Get-FeedsInfo `
    ,   Remove-Feeds `
    ,   Install-NipkgManager `
    ,   New-NipkgSnapshot `
    ,   Export-NipkgSnapshotToJson `
    ,   Import-NipkgSnapshotFromJson