# Type Parameter Implementation Summary

## Overview
The NI Package Manager (NIPKG) Helper module has been enhanced with a new **Type** parameter that provides flexible package filtering for snapshots. This feature allows users to create targeted snapshots based on package characteristics.

## New Type Parameter Values

### Full (Default)
- **Description**: Includes all packages (existing behavior)
- **Filter**: No filtering applied
- **Use Case**: Complete system backup/restoration

### UserVisible
- **Description**: Includes only packages where `UserVisible = 'yes'`
- **Filter**: `Where-Object {$_.UserVisible -eq 'yes'}`
- **Use Case**: End-user software inventory, visible applications

### StoreProduct
- **Description**: Includes only packages where `StoreProduct = 'yes'`
- **Filter**: `Where-Object {$_.StoreProduct -eq 'yes'}`
- **Use Case**: Commercial software licensing/tracking, products available for purchase

## Updated Functions

### 1. New-Snapshot
- **Added**: `[string]$Type = "Full"` parameter with ValidateSet
- **Enhanced**: Filtering logic for UserVisible and StoreProduct types
- **Enhanced**: Type field included in snapshot object output
- **Enhanced**: Verbose output includes type information

```powershell
# Examples
$snapshot = New-Snapshot -FeedsInfo $feeds -PackagesInfo $packages -Type "Full"
$snapshot = New-Snapshot -FeedsInfo $feeds -PackagesInfo $packages -Type "UserVisible"
$snapshot = New-Snapshot -FeedsInfo $feeds -PackagesInfo $packages -Type "StoreProduct"
```

### 2. New-SnapshotFromInstallerDirectory
- **Added**: `[string]$Type = "Full"` parameter with ValidateSet
- **Enhanced**: Passes Type parameter through to New-Snapshot
- **Enhanced**: Documentation updated with Type parameter examples

```powershell
# Examples
$snapshot = New-SnapshotFromInstallerDirectory -InstallerDirectory "C:\Installer" -Type "UserVisible"
$snapshot = New-SnapshotFromInstallerDirectory -InstallerDirectory "C:\Installer" -Type "StoreProduct"
```

### 3. New-SnapshotFromSystem
- **Added**: `[string]$Type = "Full"` parameter with ValidateSet
- **Enhanced**: Passes Type parameter through to New-Snapshot
- **Enhanced**: Documentation updated with Type parameter examples

```powershell
# Examples
$snapshot = New-SnapshotFromSystem -PackageType "installed" -Type "UserVisible"
$snapshot = New-SnapshotFromSystem -PackageType "available" -Type "StoreProduct"
```

### 4. Export-NipkgSnapshotToJson
- **Enhanced**: Includes type in exported JSON structure
- **Enhanced**: Type field included in summary output
- **Enhanced**: Verbose output includes type information

### 5. Import-NipkgSnapshotFromJson
- **Enhanced**: Reads and preserves type field from JSON
- **Enhanced**: Type field included in returned snapshot object
- **Enhanced**: Verbose output includes type information

## Snapshot Object Structure

The snapshot object now includes a `type` field:

```json
{
  "type": "UserVisible",
  "feeds": [
    {
      "name": "feed-name",
      "uri": "feed-path"
    }
  ],
  "packages": [
    {
      "name": "package-name",
      "version": "package-version"
    }
  ],
  "packages-nipkg": [
    {
      "name": "nipkg-package-name",
      "version": "nipkg-package-version"
    }
  ]
}
```

## Backward Compatibility

- **Full compatibility**: All existing code continues to work unchanged
- **Default behavior**: Type defaults to "Full" (existing behavior)
- **Import compatibility**: Snapshots without type field are treated as "Unknown" type

## Testing

Comprehensive tests have been created and verified:

1. **test-type-parameter.ps1**: Basic functionality testing
2. **test-comprehensive-type.ps1**: Realistic scenario testing
3. **demo-type-parameter.ps1**: Usage demonstration

All tests pass successfully, confirming:
- ✅ Type parameter filtering works correctly
- ✅ Type preservation through export/import
- ✅ Parameter validation with ValidateSet
- ✅ Backward compatibility maintained
- ✅ Integration with existing dependency resolution

## Real-World Usage Examples

### Software Audit
```powershell
# Create snapshot of only user-visible software
$userSoftware = New-SnapshotFromSystem -Type "UserVisible"
Export-NipkgSnapshotToJson -Snapshot $userSoftware -OutputPath "user-software-audit.json"
```

### License Compliance
```powershell
# Create snapshot of only commercial products
$commercialSoftware = New-SnapshotFromSystem -Type "StoreProduct"
Export-NipkgSnapshotToJson -Snapshot $commercialSoftware -OutputPath "license-inventory.json"
```

### Complete System Backup
```powershell
# Create complete system snapshot (default behavior)
$fullBackup = New-SnapshotFromSystem -Type "Full"
Export-NipkgSnapshotToJson -Snapshot $fullBackup -OutputPath "full-system-backup.json"
```

### Installer Analysis
```powershell
# Analyze only user-visible packages in an installer
$installerAnalysis = New-SnapshotFromInstallerDirectory -InstallerDirectory "C:\Installers\LabVIEW-2025" -Type "UserVisible"
Export-NipkgSnapshotToJson -Snapshot $installerAnalysis -OutputPath "installer-user-packages.json"
```

## Implementation Notes

- Type filtering is applied after package ordering and before creating the final package list
- The `ni-package-manager` package special handling is preserved and works with all Type values
- Circular dependency handling remains unchanged
- All existing verbose output and error handling is maintained
- Type validation uses PowerShell's ValidateSet attribute for parameter safety

The Type parameter enhancement provides powerful filtering capabilities while maintaining full backward compatibility and integration with the existing NIPKG Helper architecture.
