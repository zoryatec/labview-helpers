# Manual Test Scripts

This directory contains manual test and demonstration scripts for the LabViewHelpers module.

## Test Scripts

### `test-comprehensive.ps1`
Comprehensive test suite that validates all module functionality including:
- Module import and function exports
- New functions (New-NipkgSnapshotFromSystem)
- Renamed functions (Get-PackagesInfoFromNipkgCmd)
- New parameters (RemoveExistingFeeds in Apply-NipkgSnapshot)
- Help documentation

### `test-removeexistingfeeds.ps1`
Specific test for the new RemoveExistingFeeds parameter in Apply-NipkgSnapshot function.

## Demo Scripts

### `demo-removeexistingfeeds.ps1`
Interactive demonstration of the RemoveExistingFeeds functionality, including:
- Usage examples
- Operation flow explanation
- Return object documentation
- Use cases and scenarios

## Running Tests

All test scripts are located in this directory and should be run from here:

```powershell
# Change to the test/manual directory
Set-Location "c:\Projects\_Repos\labview-helpers\test\manual"

# Use the test runner
.\run-tests.ps1                    # Run all tests
.\run-tests.ps1 -TestName comprehensive     # Run comprehensive test only
.\run-tests.ps1 -TestName removeexistingfeeds  # Run RemoveExistingFeeds test only
.\run-tests.ps1 -TestName demo              # Run demo script only

# Or run individual tests directly
.\test-comprehensive.ps1
.\test-removeexistingfeeds.ps1
.\demo-removeexistingfeeds.ps1
```

### Test Runner

The `run-tests.ps1` script provides a convenient way to run all tests or specific test categories from the test/manual directory.

## Module Path Resolution

All test scripts automatically resolve the module path relative to their location:
- Script location: `test/manual/`
- Module location: `../../LabViewHelpers/LabViewHelpers.psd1`

This allows the tests to work correctly regardless of the current working directory when executed from within the test/manual folder.

## Test Data

The `test-data/` subdirectory contains sample data files used by various tests.
The `test-temp/` subdirectory is used for temporary files during testing.
