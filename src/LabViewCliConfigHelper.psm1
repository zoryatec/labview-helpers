#Requires -Version 5.1

<#
.SYNOPSIS
    LabVIEW CLI Configuration Management Module

.DESCRIPTION
    Provides comprehensive functions to manage LabVIEW CLI configuration files.
    Supports reading, writing, and maintaining LabVIEW CLI configuration with proper error handling.

.NOTES
    File Name      : LabViewCliConfigHelper.psm1
    Author         : LabVIEW Helpers Team
    Prerequisite   : PowerShell 5.1 or higher
    Copyright 2025 : LabVIEW Helpers
#>

# Private helper function for parameter validation
function Test-ConfigPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ConfigPath,
        
        [switch]$CreateIfMissing
    )
    
    if (-not (Test-Path -LiteralPath $ConfigPath)) {
        if ($CreateIfMissing) {
            $directory = Split-Path -Path $ConfigPath -Parent
            if ($directory -and -not (Test-Path -LiteralPath $directory)) {
                New-Item -Path $directory -ItemType Directory -Force | Out-Null
            }
            New-Item -Path $ConfigPath -ItemType File -Force | Out-Null
            Write-Verbose "Created config file: $ConfigPath"
        } else {
            throw "LabVIEW CLI config file not found: $ConfigPath"
        }
    }
}

# Private helper function for value formatting
function Format-ConfigValue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Value
    )
    
    # Don't quote boolean values, numbers, or already quoted strings
    if ($Value -eq "TRUE" -or $Value -eq "FALSE" -or 
        $Value -match '^\d+$' -or $Value -match '^-?\d+(\.\d+)?$' -or 
        $Value -match '^".*"$') {
        return $Value
    }
    
    # Quote other values if they contain spaces
    if ($Value -match '\s') {
        return "`"$Value`""
    }
    
    return $Value
}

function Set-LabVIEWCLIConfig {
    <#
    .SYNOPSIS
        Sets a configuration value in LabVIEW CLI configuration file.

    .DESCRIPTION
        Updates or creates a configuration key-value pair in the [LabVIEWCLI] section 
        of the specified configuration file.

    .PARAMETER ConfigPath
        Path to the LabVIEW CLI configuration file.

    .PARAMETER Key
        Configuration key name.

    .PARAMETER Value
        Configuration value to set.

    .PARAMETER CreateIfNotExists
        Creates the configuration file if it doesn't exist.

    .EXAMPLE
        Set-LabVIEWCLIConfig -ConfigPath "C:\config.ini" -Key "DefaultPortNumber" -Value "3364"

    .EXAMPLE
        Set-LabVIEWCLIConfig -ConfigPath "C:\config.ini" -Key "ValidateLabVIEWLicense" -Value "FALSE" -CreateIfNotExists

    .NOTES
        Function supports automatic value quoting based on data type.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string]$ConfigPath,
        
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string]$Key,
        
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [AllowEmptyString()]
        [string]$Value,
        
        [Parameter()]
        [switch]$CreateIfNotExists
    )
    
    begin {
        Write-Verbose "Starting Set-LabVIEWCLIConfig operation"
    }
    
    process {
        try {
            # Validate and prepare config file
            Test-ConfigPath -ConfigPath $ConfigPath -CreateIfMissing:$CreateIfNotExists
    
            # Read the file content
            $content = @(Get-Content -LiteralPath $ConfigPath -ErrorAction SilentlyContinue)
            if ($null -eq $content -or $content.Count -eq 0) { 
                $content = @() 
            }
            
            $sectionFound = $false
            $keyFound = $false
            $newContent = [System.Collections.ArrayList]::new()
            
            # Process each line
            for ($i = 0; $i -lt $content.Count; $i++) {
                $line = $content[$i]
                
                # Check if we found the [LabVIEWCLI] section
                if ($line -match "^\[LabVIEWCLI\]$") {
                    $sectionFound = $true
                    $null = $newContent.Add($line)
                    continue
                }
                
                # Check if we're in the LabVIEWCLI section and found the key
                if ($sectionFound -and $line -match "^$([regex]::Escape($Key))\s*=") {
                    $keyFound = $true
                    # Handle quoted values
                    if ($Value -match '^".*"$' -or $Value -eq "TRUE" -or $Value -eq "FALSE" -or $Value -match '^\d+$' -or $Value -match '^-?\d+$') {
                        $null = $newContent.Add("$Key = $Value")
                    } else {
                        $null = $newContent.Add("$Key = `"$Value`"")
                    }
                    Write-Verbose "Updated: $Key = $Value"
                    continue
                }
                
                # Check if we hit a new section (and we were in LabVIEWCLI section)
                if ($sectionFound -and $line -match "^\[.+\]$" -and $line -notmatch "^\[LabVIEWCLI\]$") {
                    # We've moved to a new section, add the key if not found
                    if (-not $keyFound) {
                        if ($Value -match '^".*"$' -or $Value -eq "TRUE" -or $Value -eq "FALSE" -or $Value -match '^\d+$' -or $Value -match '^-?\d+$') {
                            $null = $newContent.Add("$Key = $Value")
                        } else {
                            $null = $newContent.Add("$Key = `"$Value`"")
                        }
                        Write-Verbose "Added: $Key = $Value"
                        $keyFound = $true
                    }
                    $sectionFound = $false
                }
                
                $null = $newContent.Add($line)
            }
            
            # If LabVIEWCLI section was found but key wasn't, add it at the end of the section
            if ($sectionFound -and -not $keyFound) {
                if ($Value -match '^".*"$' -or $Value -eq "TRUE" -or $Value -eq "FALSE" -or $Value -match '^\d+$' -or $Value -match '^-?\d+$') {
                    $null = $newContent.Add("$Key = $Value")
                } else {
                    $null = $newContent.Add("$Key = `"$Value`"")
                }
                Write-Verbose "Added: $Key = $Value"
                $keyFound = $true
            }
            
            # If LabVIEWCLI section wasn't found, add it with the key
            if (-not $sectionFound) {
                if ($newContent.Count -gt 0) {
                    $null = $newContent.Add("")
                }
                $null = $newContent.Add("[LabVIEWCLI]")
                if ($Value -match '^".*"$' -or $Value -eq "TRUE" -or $Value -eq "FALSE" -or $Value -match '^\d+$' -or $Value -match '^-?\d+$') {
                    $null = $newContent.Add("$Key = $Value")
                } else {
                    $null = $newContent.Add("$Key = `"$Value`"")
                }
                Write-Verbose "Added new [LabVIEWCLI] section with $Key = $Value"
            }
            
            # Write back to file
            $newContent.ToArray() | Set-Content -LiteralPath $ConfigPath -Encoding UTF8
            Write-Verbose "LabVIEW CLI config file updated: $ConfigPath"
        }
        catch {
            Write-Error "Failed to set LabVIEW CLI config value $Key in $ConfigPath`: $_"
            throw
        }
    }
    
    end {
        Write-Verbose "Completed Set-LabVIEWCLIConfig operation"
    }
}

function Get-LabVIEWCLIConfig {
    <#
    .SYNOPSIS
        Retrieves a configuration value from LabVIEW CLI configuration file.

    .DESCRIPTION
        Reads a specific configuration key from the [LabVIEWCLI] section of the specified configuration file.

    .PARAMETER ConfigPath
        Path to the LabVIEW CLI configuration file.

    .PARAMETER Key
        Configuration key name to retrieve.

    .EXAMPLE
        Get-LabVIEWCLIConfig -ConfigPath "C:\config.ini" -Key "DefaultPortNumber"

    .EXAMPLE
        $timeout = Get-LabVIEWCLIConfig -ConfigPath "C:\LabVIEWCLI.ini" -Key "OpenAppReferenceTimeoutInSecond"

    .NOTES
        Returns $null if the key is not found in the configuration file.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string]$ConfigPath,
        
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string]$Key
    )
    
    if (-not (Test-Path -LiteralPath $ConfigPath)) {
        throw "LabVIEW CLI config file not found: $ConfigPath"
    }
    
    $content = @(Get-Content -LiteralPath $ConfigPath)
    $inLabVIEWCLISection = $false
    
    foreach ($line in $content) {
        # Check if we found the [LabVIEWCLI] section
        if ($line -match "^\[LabVIEWCLI\]$") {
            $inLabVIEWCLISection = $true
            continue
        }
        
        # Check if we hit a new section
        if ($line -match "^\[.+\]$") {
            $inLabVIEWCLISection = $false
            continue
        }
        
        # If we're in the LabVIEWCLI section, look for the key
        if ($inLabVIEWCLISection -and $line -match "^$([regex]::Escape($Key))\s*=\s*(.*)$") {
            $value = $matches[1].Trim()
            # Remove quotes if present
            if ($value -match '^"(.*)"$') {
                return $matches[1]
            }
            return $value
        }
    }
    
    return $null
}

function Remove-LabVIEWCLIConfig {
    <#
    .SYNOPSIS
        Removes a configuration key from LabVIEW CLI configuration file.

    .DESCRIPTION
        Deletes a specific configuration key from the [LabVIEWCLI] section of the specified configuration file.

    .PARAMETER ConfigPath
        Path to the LabVIEW CLI configuration file.

    .PARAMETER Key
        Configuration key name to remove.

    .EXAMPLE
        Remove-LabVIEWCLIConfig -ConfigPath "C:\config.ini" -Key "PingDelay"

    .EXAMPLE
        Remove-LabVIEWCLIConfig -ConfigPath "C:\LabVIEWCLI.ini" -Key "OldSetting"

    .NOTES
        Displays a warning if the key is not found in the configuration file.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string]$ConfigPath,
        
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string]$Key
    )
    
    if (-not (Test-Path -LiteralPath $ConfigPath)) {
        throw "LabVIEW CLI config file not found: $ConfigPath"
    }
    
    $content = @(Get-Content -LiteralPath $ConfigPath)
    $newContent = [System.Collections.ArrayList]::new()
    $inLabVIEWCLISection = $false
    $removed = $false
    
    foreach ($line in $content) {
        # Check if we found the [LabVIEWCLI] section
        if ($line -match "^\[LabVIEWCLI\]$") {
            $inLabVIEWCLISection = $true
            $null = $newContent.Add($line)
            continue
        }
        
        # Check if we hit a new section
        if ($line -match "^\[.+\]$") {
            $inLabVIEWCLISection = $false
            $null = $newContent.Add($line)
            continue
        }
        
        # If we're in the LabVIEWCLI section and found the key, skip it
        if ($inLabVIEWCLISection -and $line -match "^$([regex]::Escape($Key))\s*=") {
            $removed = $true
            Write-Host "[OK] Removed: $Key" -ForegroundColor Yellow
            continue
        }
        
        $null = $newContent.Add($line)
    }
    
    if ($removed) {
        $newContent.ToArray() | Set-Content -LiteralPath $ConfigPath -Encoding UTF8
        Write-Host "[SAVED] LabVIEW CLI config file updated: $ConfigPath" -ForegroundColor Cyan
    } else {
        Write-Host "[WARNING] Key not found: $Key" -ForegroundColor Yellow
    }
}

function Get-AllLabVIEWCLIConfig {
    <#
    .SYNOPSIS
        Retrieves all configuration values from LabVIEW CLI configuration file.

    .DESCRIPTION
        Reads all configuration key-value pairs from the [LabVIEWCLI] section of the specified configuration file.

    .PARAMETER ConfigPath
        Path to the LabVIEW CLI configuration file.

    .EXAMPLE
        Get-AllLabVIEWCLIConfig -ConfigPath "C:\config.ini"

    .EXAMPLE
        $allConfig = Get-AllLabVIEWCLIConfig -ConfigPath "C:\LabVIEWCLI.ini"

    .NOTES
        Returns a hashtable with all key-value pairs from the LabVIEWCLI section.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string]$ConfigPath
    )
    
    if (-not (Test-Path -LiteralPath $ConfigPath)) {
        throw "LabVIEW CLI config file not found: $ConfigPath"
    }
    
    $content = @(Get-Content -LiteralPath $ConfigPath)
    $result = @{}
    $inLabVIEWCLISection = $false
    
    foreach ($line in $content) {
        # Check if we found the [LabVIEWCLI] section
        if ($line -match "^\[LabVIEWCLI\]$") {
            $inLabVIEWCLISection = $true
            continue
        }
        
        # Check if we hit a new section
        if ($line -match "^\[.+\]$") {
            $inLabVIEWCLISection = $false
            continue
        }
        
        # If we're in the LabVIEWCLI section, parse key-value pairs
        if ($inLabVIEWCLISection -and $line -match "^([^=]+)=(.*)$") {
            $key = $matches[1].Trim()
            $value = $matches[2].Trim()
            
            # Remove quotes if present
            if ($value -match '^"(.*)"$') {
                $value = $matches[1]
            }
            
            $result[$key] = $value
        }
    }
    
    return $result
}

function Show-LabVIEWCLIConfig {
    <#
    .SYNOPSIS
        Displays all LabVIEW CLI configuration values in a formatted output.

    .DESCRIPTION
        Shows all configuration key-value pairs from the [LabVIEWCLI] section in a readable format
        with color-coded output.

    .PARAMETER ConfigPath
        Path to the LabVIEW CLI configuration file.

    .EXAMPLE
        Show-LabVIEWCLIConfig -ConfigPath "C:\config.ini"

    .EXAMPLE
        Show-LabVIEWCLIConfig -ConfigPath "C:\LabVIEWCLI.ini"

    .NOTES
        Displays configuration in a user-friendly format with sorted keys.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string]$ConfigPath
    )
    
    if (-not (Test-Path -LiteralPath $ConfigPath)) {
        throw "LabVIEW CLI config file not found: $ConfigPath"
    }
    
    $allValues = Get-AllLabVIEWCLIConfig -ConfigPath $ConfigPath
    
    Write-Host "LabVIEW CLI Configuration File: $ConfigPath" -ForegroundColor Yellow
    Write-Host ("-" * 60) -ForegroundColor Gray
    Write-Host "[LabVIEWCLI]" -ForegroundColor Cyan
    
    foreach ($key in $allValues.Keys | Sort-Object) {
        $value = $allValues[$key]
        Write-Host "  $key = $value" -ForegroundColor White
    }
    Write-Host ""
}

function Initialize-LabVIEWCLIConfig {
    <#
    .SYNOPSIS
        Creates a LabVIEW CLI configuration file with default values.

    .DESCRIPTION
        Initializes a new LabVIEW CLI configuration file with standard default settings,
        including timeout values, port configuration, and license validation settings.

    .PARAMETER ConfigPath
        Path where the LabVIEW CLI configuration file should be created.

    .PARAMETER Force
        Overwrites an existing configuration file if present.

    .EXAMPLE
        Initialize-LabVIEWCLIConfig -ConfigPath "C:\config.ini"

    .EXAMPLE
        Initialize-LabVIEWCLIConfig -ConfigPath "C:\LabVIEWCLI.ini" -Force

    .NOTES
        Creates a [LabVIEWCLI] section with commonly used default values.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string]$ConfigPath,
        
        [Parameter()]
        [switch]$Force
    )
    
    if ((Test-Path -LiteralPath $ConfigPath) -and -not $Force) {
        Write-Host "[WARNING] Config file already exists: $ConfigPath" -ForegroundColor Yellow
        Write-Host "Use -Force to overwrite" -ForegroundColor Yellow
        return
    }
    
    $defaultConfig = @"
[LabVIEWCLI]
OpenAppReferenceTimeoutInSecond = 120    
AfterLaunchOpenAppReferenceTimeoutInSecond = 300    
UDCInstallID = "16e7cd52-35d6-4890-a1c9-a914e1682be7"
DefaultPortNumber = 3363
AppendToLogFile = FALSE
AppExitTimeout = 10000
DefaultLabVIEWPath = ""
DeleteLabVIEWCLILogFile = FALSE
PingDelay = -1
PingTimeout = 10000
IndividualOpenAppRefTimeout = 20
ValidateLabVIEWLicense = TRUE
"@
    
    Set-Content -LiteralPath $ConfigPath -Value $defaultConfig -Encoding UTF8
    Write-Host "[OK] Created LabVIEW CLI config file with defaults: $ConfigPath" -ForegroundColor Green
}

# Export all functions
Export-ModuleMember -Function Set-LabVIEWCLIConfig, Get-LabVIEWCLIConfig, Remove-LabVIEWCLIConfig, Get-AllLabVIEWCLIConfig, Show-LabVIEWCLIConfig, Initialize-LabVIEWCLIConfig
