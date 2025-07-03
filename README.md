# LabViewHelpers PowerShell Module

[![PowerShell Gallery](https://img.shields.io/powershellgallery/v/LabViewHelpers)](https://www.powershellgallery.com/packages/LabViewHelpers)
[![PowerShell Gallery Downloads](https://img.shields.io/powershellgallery/dt/LabViewHelpers)](https://www.powershellgallery.com/packages/LabViewHelpers)
[![License](https://img.shields.io/github/license/zoryatec/labview-helpers)](LICENSE)

A PowerShell module for managing LabVIEW installations, configurations, and NI package management. Designed for CI/CD pipelines and automated deployments.

## Features

- **LabVIEW Configuration**: Manage LabVIEW.ini files
- **CLI Configuration**: Handle LabVIEW CLI settings
- **Installation Automation**: Automate LabVIEW installations
- **Package Management**: Manage NIPKG operations
- **CI/CD Ready**: Enterprise automation support

## Installation

```powershell
Install-Module -Name LabViewHelpers -Scope CurrentUser
```

## Functions

### LabViewConfigHelper

- `Set-ConfigValue` / `Get-ConfigValue` / `Remove-ConfigValue`
- `Get-AllConfigValues` / `Show-ConfigFile`

### LabViewCliConfigHelper

- `Set-LabVIEWCLIConfig` / `Get-LabVIEWCLIConfig` / `Remove-LabVIEWCLIConfig`
- `Initialize-LabVIEWCLIConfig` / `Show-LabVIEWCLIConfig`

### LabViewInstallationHelper

- `Install-LabView` / `Install-LabViewIso` / `Install-LabViewOffline`
- `Set-LabViewForCi` / `Expand-Iso`
- `Install-Chocolatey` / `Install-Gcd`

### NipkgHelper

- `Add-FeedDirectories` / `Remove-Feeds` / `Get-FeedsInfo`
- `Get-PackagesInfo` / `Install-NipkgManager`
- Package discovery: `Get-DriverPackages`, `Get-UtilitiesPackages`, etc.

## Requirements

- PowerShell 5.1+
- Windows OS
- Admin privileges for installations

## Usage

```powershell
Import-Module LabViewHelpers

# Configure LabVIEW
Set-ConfigValue -ConfigFile "C:\...\LabVIEW.ini" -Section "LabVIEW" -Key "server.tcp.enabled" -Value "true"

# Install from ISO
Install-LabViewIso -IsoPath "C:\Installers\labview.iso"

# Add package feeds
Add-FeedDirectories -FeedDirectories @("C:\Packages\Feed1", "C:\Packages\Feed2")
```

## License

MIT License - see [LICENSE](LICENSE) for details.

---

**Made by [Zoryatec](https://github.com/zoryatec)**
