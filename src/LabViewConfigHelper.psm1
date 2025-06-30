#Requires -Version 5.1

function Set-ConfigValue {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ConfigPath,
        
        [Parameter(Mandatory = $true)]
        [string]$Section,
        
        [Parameter(Mandatory = $true)]
        [string]$Key,
        
        [Parameter(Mandatory = $true)]
        [string]$Value,
        
        [switch]$CreateIfNotExists
    )
    
    # Check if file exists
    if (-not (Test-Path -LiteralPath $ConfigPath)) {
        if ($CreateIfNotExists) {
            $null = New-Item -Path $ConfigPath -ItemType File -Force
            Write-Host "[OK] Created new config file: $ConfigPath" -ForegroundColor Green
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
            Write-Host "[OK] Updated: [$Section] $Key = $Value" -ForegroundColor Green
            continue
        }
        
        # Check if we hit a new section (and we were in our target section)
        if ($sectionFound -and $line -match "^\[.+\]$" -and $line -notmatch "^\[$([regex]::Escape($Section))\]$") {
            # We've moved to a new section, add the key if not found
            if (-not $keyFound) {
                $null = $newContent.Add("$Key=$Value")
                Write-Host "[OK] Added: [$Section] $Key = $Value" -ForegroundColor Green
                $keyFound = $true
            }
            $sectionFound = $false
        }
          $null = $newContent.Add($line)
    }
    
    # If section was found but key wasn't, add it at the end of the section
    if ($sectionFound -and -not $keyFound) {
        $null = $newContent.Add("$Key=$Value")
        Write-Host "[OK] Added: [$Section] $Key = $Value" -ForegroundColor Green
        $keyFound = $true
    }
    
    # If section wasn't found, add it with the key
    if (-not $sectionFound) {
        $null = $newContent.Add("")
        $null = $newContent.Add("[$Section]")
        $null = $newContent.Add("$Key=$Value")
        Write-Host "[OK] Added new section: [$Section] with $Key = $Value" -ForegroundColor Green
    }    # Write back to file - ensure consistent encoding
    $newContent.ToArray() | Set-Content -LiteralPath $ConfigPath -Encoding UTF8
    Write-Host "[SAVED] Config file updated: $ConfigPath" -ForegroundColor Cyan
}

function Get-ConfigValue {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ConfigPath,
        
        [Parameter(Mandatory = $true)]
        [string]$Section,
        
        [Parameter(Mandatory = $true)]        [string]$Key
    )
    
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
            return $matches[1]
        }
    }
    
    return $null
}

function Remove-ConfigValue {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ConfigPath,
        
        [Parameter(Mandatory = $true)]
        [string]$Section,
        
        [Parameter(Mandatory = $true)]
        [string]$Key
    )
    
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
            Write-Host "[OK] Removed: [$Section] $Key" -ForegroundColor Yellow
            continue
        }
        
        $null = $newContent.Add($line)
    }
    
    if ($removed) {        $newContent.ToArray() | Set-Content -LiteralPath $ConfigPath -Encoding UTF8
        Write-Host "[SAVED] Config file updated: $ConfigPath" -ForegroundColor Cyan
    } else {
        Write-Host "[WARNING] Key not found: [$Section] $Key" -ForegroundColor Yellow
    }
}

function Get-AllConfigValues {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ConfigPath,
        
        [string]$Section = $null
    )
    
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
    
    return $result
}

function Show-ConfigFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ConfigPath
    )
    
    if (-not (Test-Path -LiteralPath $ConfigPath)) {
        throw "Config file not found: $ConfigPath"
    }
      $allValues = Get-AllConfigValues -ConfigPath $ConfigPath -Section "LabVIEW"
    
    Write-Host "Configuration File: $ConfigPath" -ForegroundColor Yellow
    Write-Host ("-" * 60) -ForegroundColor Gray
    
    foreach ($section in $allValues.Keys) {
        Write-Host "[$section]" -ForegroundColor Cyan
        foreach ($key in $allValues[$section].Keys) {
            $value = $allValues[$section][$key]
            Write-Host "  $key = $value" -ForegroundColor White
        }
        Write-Host ""
    }
}

# Export all functions
Export-ModuleMember -Function Set-ConfigValue, Get-ConfigValue, Remove-ConfigValue, Get-AllConfigValues, Show-ConfigFile