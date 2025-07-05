# NipkgHelper Function Tests

This directory contains individual test scripts for specific functions in the NipkgHelper module.

## Test Files

### Test-PackageInstallationOrder.ps1

Tests the `Get-PackageInstallationOrder` function which sorts packages into correct installation order based on dependencies.

**Features tested:**
- Basic dependency ordering from real NIPKG Packages files
- Different dependency types (Depends, Recommends, Suggests, etc.)
- Synthetic test data for edge cases
- Error handling and edge cases
- Performance and output validation

### Test-CircularDependencies.ps1

Tests the circular dependency handling capabilities of the `Get-PackageInstallationOrder` function.

**Features tested:**
- Simple circular dependencies (A→B→A)
- Real-world NI Vision package circular dependencies
- Complex dependency chains with cycles
- Updated `New-NipkgSnapshot` function with circular dependency handling

### New-NipkgSnapshotFromSystemTests.ps1

Tests the `New-NipkgSnapshotFromSystem` function which creates snapshots from the current system state.

**Features tested:**
- System snapshot creation with installed packages
- NIPKG availability checking
- Snapshot export to JSON
- Error handling and reporting

### Test-FeedFiltering.ps1

Tests the updated `Get-FeedsInfoFromNipkgCmd` function with feed filtering capabilities.

**Features tested:**
- Retrieving all feeds (default behavior)
- Filtering to exclude local feeds (online only)
- Filtering to exclude online feeds (local only)
- Parameter validation for invalid combinations
- Feed type detection logic (local vs online)

**Requirements:**
- LabViewHelpers module must be importable
- A NIPKG Packages file in `../test-temp/Packages` for real-world testing

**Usage:**
```powershell
# Run from the NipkgHelperTests directory
cd test\manual\NipkgHelperTests
.\Test-PackageInstallationOrder.ps1
```

## Adding New Tests

When adding new test files for NipkgHelper functions:

1. Create a new `.ps1` file with the naming pattern `Test-<FunctionName>.ps1`
2. Import the LabViewHelpers module at the beginning
3. Include comprehensive test scenarios:
   - Basic functionality
   - Edge cases
   - Error handling
   - Performance validation
4. Use consistent output formatting (Green for success, Red for errors, Yellow for warnings)
5. Include usage examples in the output
6. Update this README with information about the new test

## Running All Tests

To run all tests in this directory:

```powershell
cd test\manual\NipkgHelperTests
Get-ChildItem -Filter "Test-*.ps1" | ForEach-Object { 
    Write-Host "Running $($_.Name)..." -ForegroundColor Cyan
    & $_.FullName 
    Write-Host ""
}
```

## Test Data

Most tests expect test data to be available in the `../test-temp/` directory:
- `Packages` - A NIPKG Packages file for testing package parsing functions
- Other test files as needed

You can copy test data from:
- NIPKG feed directories (`feeds/*/Packages`)
- LabVIEW installer directories (`feeds/*/Packages`)
- Create synthetic test data for specific scenarios
