#Requires -Version 5.1

<#
.SYNOPSIS
    LabVIEW Helper Modules - Comprehensive PowerShell utilities for LabVIEW management

.DESCRIPTION
    This module provides a comprehensive set of PowerShell utilities for managing LabVIEW installations,
    configurations, and NI package management. It combines multiple specialized modules:
    
    - LabViewConfigHelper: Manage LabVIEW.ini configuration files
    - LabViewCliConfigHelper: Manage LabVIEW CLI configuration
    - LabViewInstallationHelper: Automate LabVIEW installation processes  
    - NipkgHelper: Manage NI Package Manager operations

.NOTES
    Author: Zoryatec
    Version: 1.0.0
    PowerShell: 5.1+
    
.LINK
    https://github.com/zoryatec/labview-helpers
#>

# Get the directory where this module is located
$ModuleRoot = $PSScriptRoot

Write-Verbose "Loading LabVIEW Helper Modules from: $ModuleRoot"

# Import all nested modules
$NestedModules = @(
    'LabViewConfigHelper.psm1',
    'LabViewCliConfigHelper.psm1',
    'LabViewInstallationHelper.psm1',
    'NipkgHelper.psm1'
)

foreach ($Module in $NestedModules) {
    $ModulePath = Join-Path -Path $ModuleRoot -ChildPath $Module
    
    if (Test-Path -Path $ModulePath) {
        Write-Verbose "Importing nested module: $Module"
        try {
            Import-Module -Name $ModulePath -Force -Global
        }
        catch {
            Write-Error "Failed to import module '$Module': $($_.Exception.Message)"
        }
    }
    else {
        Write-Warning "Nested module not found: $ModulePath"
    }
}

# Module initialization message
Write-Verbose "LabVIEW Helper Modules loaded successfully"

# Export all functions (they're already exported by individual modules)
# The manifest file controls which functions are exported to users
