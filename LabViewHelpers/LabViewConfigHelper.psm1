#Requires -Version 5.1

<#
.SYNOPSIS
    LabVIEW Configuration Management Module

.DESCRIPTION
    Provides comprehensive functions to manage LabVIEW configuration files (INI format).
    Supports reading, writing, and maintaining multi-section configuration files with proper error handling.

.NOTES
    File Name      : LabViewConfigHelper.psm1
    Author         : LabVIEW Helpers Team
    Prerequisite   : PowerShell 5.1 or higher
    Copyright 2025 : LabVIEW Helpers
#>

function Set-ConfigValue {
    <#
    .SYNOPSIS
        Sets a configuration value in an INI-style configuration file.

    .DESCRIPTION
        Updates or creates a configuration key-value pair in the specified section
        of the configuration file.

    .PARAMETER ConfigPath
        Path to the configuration file.

    .PARAMETER Section
        Configuration section name.

    .PARAMETER Key
        Configuration key name.

    .PARAMETER Value
        Configuration value to set.

    .PARAMETER CreateIfNotExists
        Creates the configuration file if it doesn't exist.

    .EXAMPLE
        Set-ConfigValue -ConfigPath "C:\LabVIEW.ini" -Section "LabVIEW" -Key "server.tcp.enabled" -Value "True"

    .EXAMPLE
        Set-ConfigValue -ConfigPath "C:\config.ini" -Section "Settings" -Key "timeout" -Value "30" -CreateIfNotExists

    .NOTES
        Supports multi-section INI file format with proper section handling.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string]$ConfigPath,
        
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string]$Section,
        
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
        Write-Verbose "Starting Set-ConfigValue operation"
    }
    
    process {
        try {
            # Check if file exists
            if (-not (Test-Path -LiteralPath $ConfigPath)) {
                if ($CreateIfNotExists) {
                    $directory = Split-Path -Path $ConfigPath -Parent
                    if ($directory -and -not (Test-Path -LiteralPath $directory)) {
                        New-Item -Path $directory -ItemType Directory -Force | Out-Null
                    }
                    New-Item -Path $ConfigPath -ItemType File -Force | Out-Null
                    Write-Verbose "Created config file: $ConfigPath"
                } else {
                    throw "Config file not found: $ConfigPath"
                }
            }
    
            # Read the file content - handle both PowerShell versions
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
                
                # Check if we found the section
                if ($line -match "^\[$([regex]::Escape($Section))\]$") {
                    $sectionFound = $true
                    $null = $newContent.Add($line)
                    continue
                }
                
                # Check if we're in the right section and found the key
                if ($sectionFound -and $line -match "^$([regex]::Escape($Key))=") {
                    $keyFound = $true
                    $null = $newContent.Add("$Key=$Value")
                    Write-Verbose "Updated: [$Section] $Key = $Value"
                    continue
                }
                
                # Check if we hit a new section (and we were in our target section)
                if ($sectionFound -and $line -match "^\[.+\]$" -and $line -notmatch "^\[$([regex]::Escape($Section))\]$") {
                    # We've moved to a new section, add the key if not found
                    if (-not $keyFound) {
                        $null = $newContent.Add("$Key=$Value")
                        Write-Verbose "Added: [$Section] $Key = $Value"
                        $keyFound = $true
                    }
                    $sectionFound = $false
                }
                
                $null = $newContent.Add($line)
            }
            
            # If section was found but key wasn't, add it at the end of the section
            if ($sectionFound -and -not $keyFound) {
                $null = $newContent.Add("$Key=$Value")
                Write-Verbose "Added: [$Section] $Key = $Value"
                $keyFound = $true
            }
            
            # If section wasn't found, add it with the key
            if (-not $sectionFound) {
                $null = $newContent.Add("")
                $null = $newContent.Add("[$Section]")
                $null = $newContent.Add("$Key=$Value")
                Write-Verbose "Added new section: [$Section] with $Key = $Value"
            }
            
            # Write back to file - ensure consistent encoding
            $newContent.ToArray() | Set-Content -LiteralPath $ConfigPath -Encoding UTF8
            Write-Verbose "Config file updated: $ConfigPath"
        }
        catch {
            Write-Error "Failed to set config value [$Section] $Key in $ConfigPath`: $_"
            throw
        }
    }
    
    end {
        Write-Verbose "Completed Set-ConfigValue operation"
    }
}

function Get-ConfigValue {
    <#
    .SYNOPSIS
        Retrieves a configuration value from an INI-style configuration file.

    .DESCRIPTION
        Reads a configuration key from the specified section of the configuration file.

    .PARAMETER ConfigPath
        Path to the configuration file.

    .PARAMETER Section
        Configuration section name.

    .PARAMETER Key
        Configuration key name.

    .EXAMPLE
        Get-ConfigValue -ConfigPath "C:\LabVIEW.ini" -Section "LabVIEW" -Key "server.tcp.enabled"

    .NOTES
        Returns $null if the key is not found.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string]$ConfigPath,
        
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string]$Section,
        
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string]$Key
    )
    
    begin {
        Write-Verbose "Starting Get-ConfigValue operation"
    }
    
    process {
        try {
            if (-not (Test-Path -LiteralPath $ConfigPath)) {
                throw "Config file not found: $ConfigPath"
            }
            
            $content = @(Get-Content -LiteralPath $ConfigPath)
            $inSection = $false
            
            foreach ($line in $content) {
                # Check if we found the section
                if ($line -match "^\[$([regex]::Escape($Section))\]$") {
                    $inSection = $true
                    continue
                }
                
                # Check if we hit a new section
                if ($line -match "^\[.+\]$") {
                    $inSection = $false
                    continue
                }
                
                # If we're in the right section, look for the key
                if ($inSection -and $line -match "^$([regex]::Escape($Key))=(.*)$") {
                    Write-Verbose "Found value for [$Section] $Key"
                    return $matches[1]
                }
            }
            
            Write-Verbose "Key not found: [$Section] $Key"
            return $null
        }
        catch {
            Write-Error "Failed to get config value [$Section] $Key from $ConfigPath`: $_"
            throw
        }
    }
    
    end {
        Write-Verbose "Completed Get-ConfigValue operation"
    }
}

function Remove-ConfigValue {
    <#
    .SYNOPSIS
        Removes a configuration value from an INI-style configuration file.

    .DESCRIPTION
        Deletes a configuration key from the specified section of the configuration file.

    .PARAMETER ConfigPath
        Path to the configuration file.

    .PARAMETER Section
        Configuration section name.

    .PARAMETER Key
        Configuration key name to remove.

    .EXAMPLE
        Remove-ConfigValue -ConfigPath "C:\LabVIEW.ini" -Section "LabVIEW" -Key "server.tcp.enabled"

    .NOTES
        Displays a warning if the key is not found.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string]$ConfigPath,
        
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string]$Section,
        
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string]$Key
    )
    
    begin {
        Write-Verbose "Starting Remove-ConfigValue operation"
    }
    
    process {
        try {
            if (-not (Test-Path -LiteralPath $ConfigPath)) {
                throw "Config file not found: $ConfigPath"
            }
            
            $content = @(Get-Content -LiteralPath $ConfigPath)
            $newContent = [System.Collections.ArrayList]::new()
            $inSection = $false
            $removed = $false
            
            foreach ($line in $content) {
                # Check if we found the section
                if ($line -match "^\[$([regex]::Escape($Section))\]$") {
                    $inSection = $true
                    $null = $newContent.Add($line)
                    continue
                }
                
                # Check if we hit a new section
                if ($line -match "^\[.+\]$") {
                    $inSection = $false
                    $null = $newContent.Add($line)
                    continue
                }
                
                # If we're in the right section and found the key, skip it
                if ($inSection -and $line -match "^$([regex]::Escape($Key))=") {
                    $removed = $true
                    Write-Verbose "Removed: [$Section] $Key"
                    continue
                }
                
                $null = $newContent.Add($line)
            }
            
            if ($removed) {
                $newContent.ToArray() | Set-Content -LiteralPath $ConfigPath -Encoding UTF8
                Write-Verbose "Config file updated: $ConfigPath"
            } else {
                Write-Warning "Key not found: [$Section] $Key"
            }
        }
        catch {
            Write-Error "Failed to remove config value [$Section] $Key from $ConfigPath`: $_"
            throw
        }
    }
    
    end {
        Write-Verbose "Completed Remove-ConfigValue operation"
    }
}

function Get-AllConfigValues {
    <#
    .SYNOPSIS
        Retrieves all configuration values from an INI-style configuration file.

    .DESCRIPTION
        Reads all configuration keys and values from the entire file or a specific section.

    .PARAMETER ConfigPath
        Path to the configuration file.

    .PARAMETER Section
        Optional. Configuration section name. If not specified, returns all sections.

    .EXAMPLE
        Get-AllConfigValues -ConfigPath "C:\LabVIEW.ini"

    .EXAMPLE
        Get-AllConfigValues -ConfigPath "C:\LabVIEW.ini" -Section "LabVIEW"

    .NOTES
        Returns a hashtable with sections as keys and nested hashtables for key-value pairs.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string]$ConfigPath,
        
        [Parameter(ValueFromPipelineByPropertyName)]
        [string]$Section = $null
    )
    
    begin {
        Write-Verbose "Starting Get-AllConfigValues operation"
    }
    
    process {
        try {
            if (-not (Test-Path -LiteralPath $ConfigPath)) {
                throw "Config file not found: $ConfigPath"
            }
            
            $content = @(Get-Content -LiteralPath $ConfigPath)
            $result = @{}
            $currentSection = $null
            
            foreach ($line in $content) {
                # Check for section headers
                if ($line -match "^\[(.+)\]$") {
                    $currentSection = $matches[1]
                    continue
                }
                
                # Check for key-value pairs
                if ($line -match "^([^=]+)=(.*)$") {
                    $key = $matches[1]
                    $value = $matches[2]
                    
                    if ($Section -eq $null -or $currentSection -eq $Section) {
                        if (-not $result.ContainsKey($currentSection)) {
                            $result[$currentSection] = @{}
                        }
                        $result[$currentSection][$key] = $value
                    }
                }
            }
            
            Write-Verbose "Retrieved configuration values from $ConfigPath"
            return $result
        }
        catch {
            Write-Error "Failed to get all config values from $ConfigPath`: $_"
            throw
        }
    }
    
    end {
        Write-Verbose "Completed Get-AllConfigValues operation"
    }
}

function Show-ConfigFile {
    <#
    .SYNOPSIS
        Displays the contents of an INI-style configuration file.

    .DESCRIPTION
        Shows all configuration sections, keys, and values in a formatted output.

    .PARAMETER ConfigPath
        Path to the configuration file.

    .PARAMETER Section
        Optional. Configuration section name. If not specified, shows all sections.

    .EXAMPLE
        Show-ConfigFile -ConfigPath "C:\LabVIEW.ini"

    .EXAMPLE
        Show-ConfigFile -ConfigPath "C:\LabVIEW.ini" -Section "LabVIEW"

    .NOTES
        Displays configuration in a readable format with color coding.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string]$ConfigPath,
        
        [Parameter(ValueFromPipelineByPropertyName)]
        [string]$Section = $null
    )
    
    begin {
        Write-Verbose "Starting Show-ConfigFile operation"
    }
    
    process {
        try {
            if (-not (Test-Path -LiteralPath $ConfigPath)) {
                throw "Config file not found: $ConfigPath"
            }
            
            $allValues = Get-AllConfigValues -ConfigPath $ConfigPath -Section $Section
            
            Write-Host "Configuration File: $ConfigPath" -ForegroundColor Yellow
            Write-Host ("-" * 60) -ForegroundColor Gray
            
            foreach ($sectionName in $allValues.Keys) {
                Write-Host "[$sectionName]" -ForegroundColor Cyan
                foreach ($key in $allValues[$sectionName].Keys) {
                    $value = $allValues[$sectionName][$key]
                    Write-Host "  $key = $value" -ForegroundColor White
                }
                Write-Host ""
            }
            
            Write-Verbose "Displayed configuration from $ConfigPath"
        }
        catch {
            Write-Error "Failed to show config file $ConfigPath`: $_"
            throw
        }
    }
    
    end {
        Write-Verbose "Completed Show-ConfigFile operation"
    }
}

# Export all functions
Export-ModuleMember -Function Set-ConfigValue, Get-ConfigValue, Remove-ConfigValue, Get-AllConfigValues, Show-ConfigFile