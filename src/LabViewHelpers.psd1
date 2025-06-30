@{
    # Module manifest for LabVIEW Helper Modules
    # Generated on: June 30, 2025
    
    # Module Information
    RootModule = 'LabViewHelpers.psm1'
    ModuleVersion = '1.0.0'
    
    # Supported PowerShell version
    PowerShellVersion = '5.1'
    
    # ID used to uniquely identify this module
    GUID = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890'
    
    # Author and company information
    Author = 'Zoryatec'
    CompanyName = 'Zoryatec'
    Copyright = '(c) 2025 Zoryatec. All rights reserved.'
    
    # Description of this module
    Description = 'A comprehensive PowerShell module for managing LabVIEW installations, configurations, and NI package management. Includes utilities for LabVIEW.ini configuration, CLI configuration, installation automation, and NIPKG operations.'
    
    # Nested modules that are imported as part of this module
    NestedModules = @(
        'LabViewConfigHelper.psm1',
        'LabViewCliConfigHelper.psm1',
        'LabViewInstallationHelper.psm1',
        'NipkgHelper.psm1'
    )
    
    # Functions to export from this module
    FunctionsToExport = @(
        # LabViewConfigHelper functions
        'Set-ConfigValue',
        'Get-ConfigValue', 
        'Remove-ConfigValue',
        'Get-AllConfigValues',
        'Show-ConfigFile',
        
        # LabViewCliConfigHelper functions
        'Set-LabVIEWCLIConfig',
        'Get-LabVIEWCLIConfig',
        'Remove-LabVIEWCLIConfig', 
        'Get-AllLabVIEWCLIConfig',
        'Show-LabVIEWCLIConfig',
        'Initialize-LabVIEWCLIConfig',
        
        # LabViewInstallationHelper functions
        'Install-LabViewOffline',
        'Install-Chocolatey',
        'Install-ChocolateyPackage7zip',
        'Install-Gcd',
        'Install-LabView',
        'Expand-Iso',
        'Install-LabViewIso',
        'Set-LabViewForCi',
        
        # NipkgHelper functions
        'Add-FeedDirectories',
        'Get-PackagesInfo',
        'Get-DriverPackages',
        'Get-ProgrammingEnvironmentsPackages',
        'Get-UtilitiesPackages',
        'Get-ApplicationSoftwarePackages',
        'Get-FeedsInfo',
        'Remove-Feeds',
        'Install-NipkgManager'
    )
    
    # Cmdlets to export from this module
    CmdletsToExport = @()
    
    # Variables to export from this module
    VariablesToExport = @()
    
    # Aliases to export from this module
    AliasesToExport = @()
    
    # Minimum version of Microsoft .NET Framework required by this module
    DotNetFrameworkVersion = '4.5'
    
    # Minimum version of the common language runtime (CLR) required by this module
    CLRVersion = '4.0'
    
    # Processor architecture (None, X86, Amd64) required by this module
    ProcessorArchitecture = 'None'
    
    # Modules that must be imported into the global environment prior to importing this module
    RequiredModules = @()
    
    # Assemblies that must be loaded prior to importing this module
    RequiredAssemblies = @()
    
    # Script files (.ps1) that are run in the caller's environment prior to importing this module
    ScriptsToProcess = @()
    
    # Type files (.ps1xml) to be loaded when importing this module
    TypesToProcess = @()
    
    # Format files (.ps1xml) to be loaded when importing this module
    FormatsToProcess = @()
    
    # List of all files packaged with this module
    FileList = @(
        'LabViewHelpers.psd1',
        'LabViewHelpers.psm1',
        'LabViewConfigHelper.psm1',
        'LabViewCliConfigHelper.psm1',
        'LabViewInstallationHelper.psm1',
        'NipkgHelper.psm1'
    )
    
    # Private data to pass to the module specified in RootModule/ModuleToProcess
    PrivateData = @{
        PSData = @{
            # Tags applied to this module to aid in module discovery
            Tags = @(
                'LabVIEW', 
                'NationalInstruments', 
                'NI',
                'Configuration',
                'Installation', 
                'NIPKG',
                'Automation',
                'Testing',
                'CI/CD',
                'DevOps'
            )
            
            # A URL to the license for this module
            LicenseUri = 'https://github.com/zoryatec/labview-helpers/blob/main/LICENSE'
            
            # A URL to the main website for this project
            ProjectUri = 'https://github.com/zoryatec/labview-helpers'
            
            # A URL to an icon representing this module
            IconUri = ''
            
            # Release notes for this module
            ReleaseNotes = @'
## Version 1.0.0
- Initial release of LabVIEW Helper Modules
- LabViewConfigHelper: Manage LabVIEW.ini configuration files
- LabViewCliConfigHelper: Manage LabVIEW CLI configuration 
- LabViewInstallationHelper: Automate LabVIEW installation processes
- NipkgHelper: Manage NI Package Manager operations
- Full support for CI/CD pipelines and automated deployments
'@
            
            # Flag to indicate whether the module requires explicit user acceptance
            RequireLicenseAcceptance = $false
            
            # External dependent modules of this module
            ExternalModuleDependencies = @()
        }
    }
    
    # HelpInfo URI of this module
    HelpInfoURI = 'https://github.com/zoryatec/labview-helpers/help'
    
    # Default prefix for commands exported from this module
    DefaultCommandPrefix = ''
}
