#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Demo script for the RemoveSnapshotFeeds functionality in Apply-NipkgSnapshot.

.DESCRIPTION
    This script demonstrates the practical usage of the RemoveSnapshotFeeds switch 
    parameter. This feature is useful when you want to:
    
    1. Install packages from specific feeds
    2. Remove those feeds after installation to keep the system clean
    3. Avoid polluting the system with temporary or one-time feeds
    
    Use cases:
    - Installing packages from development/test feeds without keeping them
    - Applying snapshots from different environments without permanent feed changes
    - Installing packages and then cleaning up the feed configuration

.NOTES
    This script should be run from the test/manual directory.
    Requires: LabViewHelpers module, NIPKG command available
#>

# Ensure we're running from the correct directory
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$moduleDir = Split-Path -Parent (Split-Path -Parent $scriptDir)
$modulePath = Join-Path $moduleDir "LabViewHelpers"

Write-Host "=== Demo: RemoveSnapshotFeeds Functionality ===" -ForegroundColor Green
Write-Host "This demo shows how to use the new RemoveSnapshotFeeds parameter." -ForegroundColor White

# Import the module
try {
    Import-Module $modulePath -Force
    Write-Host "✓ LabViewHelpers module imported successfully" -ForegroundColor Green
} catch {
    Write-Host "✗ Failed to import LabViewHelpers module: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host "`n=== Scenario 1: Clean Installation ===" -ForegroundColor Cyan
Write-Host "You want to install packages from a snapshot but don't want to keep the feeds afterwards."
Write-Host "This keeps your system clean and avoids feed pollution."

Write-Host "`nCommand:" -ForegroundColor Yellow
Write-Host "Apply-NipkgSnapshot -SnapshotPath 'my-snapshot.json' -RemoveSnapshotFeeds" -ForegroundColor White

Write-Host "`nThis will:"
Write-Host "  1. Add feeds from the snapshot"
Write-Host "  2. Update the package database"
Write-Host "  3. Install packages from the snapshot"
Write-Host "  4. Remove the snapshot feeds (cleanup)"

Write-Host "`n=== Scenario 2: Complete System Reset ===" -ForegroundColor Cyan
Write-Host "You want to completely replace the current feeds with those from a snapshot,"
Write-Host "install packages, and then remove all feeds for a clean state."

Write-Host "`nCommand:" -ForegroundColor Yellow
Write-Host "Apply-NipkgSnapshot -SnapshotPath 'snapshot.json' -RemoveExistingFeeds -RemoveSnapshotFeeds" -ForegroundColor White

Write-Host "`nThis will:"
Write-Host "  1. Remove all existing feeds from the system"
Write-Host "  2. Add feeds from the snapshot"
Write-Host "  3. Update the package database"
Write-Host "  4. Install packages from the snapshot"
Write-Host "  5. Remove the snapshot feeds (system ends with no feeds)"

Write-Host "`n=== Scenario 3: Development Environment Setup ===" -ForegroundColor Cyan
Write-Host "You're setting up a development environment and want to install packages"
Write-Host "from development feeds without keeping those feeds permanently."

Write-Host "`nCommand:" -ForegroundColor Yellow
Write-Host "Apply-NipkgSnapshot -SnapshotPath 'dev-snapshot.json' -RemoveSnapshotFeeds -Force" -ForegroundColor White

Write-Host "`nThis will:"
Write-Host "  1. Add development feeds temporarily"
Write-Host "  2. Install development packages (with force if needed)"
Write-Host "  3. Remove development feeds afterwards"
Write-Host "  4. Leave system with packages installed but no dev feeds"

Write-Host "`n=== Scenario 4: Testing with Skip Options ===" -ForegroundColor Cyan
Write-Host "You want to test the feed management without installing packages."

Write-Host "`nCommand for feeds only:" -ForegroundColor Yellow
Write-Host "Apply-NipkgSnapshot -SnapshotPath 'snapshot.json' -RemoveSnapshotFeeds -SkipPackages" -ForegroundColor White

Write-Host "`nThis will:"
Write-Host "  1. Add feeds from the snapshot"
Write-Host "  2. Skip package installation"
Write-Host "  3. Remove the snapshot feeds immediately"
Write-Host "  4. Useful for testing feed configuration"

Write-Host "`n=== Benefits of RemoveSnapshotFeeds ===" -ForegroundColor Green
Write-Host "✓ Keeps your system clean after package installation"
Write-Host "✓ Prevents accumulation of temporary or one-time feeds"
Write-Host "✓ Useful for CI/CD scenarios where feeds are environment-specific"
Write-Host "✓ Allows installation from multiple snapshots without feed conflicts"
Write-Host "✓ Maintains security by not leaving development feeds on production systems"

Write-Host "`n=== Real-World Examples ===" -ForegroundColor Magenta

Write-Host "`nExample 1: Installing from a vendor snapshot" -ForegroundColor Yellow
$example1 = @"
# Get packages from vendor, but don't keep their feeds
Apply-NipkgSnapshot -SnapshotPath 'vendor-packages.json' -RemoveSnapshotFeeds

# Result: Packages installed, vendor feeds removed
"@
Write-Host $example1 -ForegroundColor White

Write-Host "`nExample 2: Environment migration" -ForegroundColor Yellow
$example2 = @"
# Migrate from dev to prod: remove all feeds, apply prod snapshot, clean up
Apply-NipkgSnapshot -SnapshotPath 'prod-snapshot.json' -RemoveExistingFeeds -RemoveSnapshotFeeds

# Result: Clean system with only prod packages, no feeds
"@
Write-Host $example2 -ForegroundColor White

Write-Host "`nExample 3: Automated build environment" -ForegroundColor Yellow
$example3 = @"
# Set up build environment from snapshot, then clean up
Apply-NipkgSnapshot -SnapshotPath 'build-tools.json' -RemoveSnapshotFeeds -Force

# Continue with build process...
# System has build tools installed but no leftover feeds
"@
Write-Host $example3 -ForegroundColor White

Write-Host "`n=== Important Notes ===" -ForegroundColor Red
Write-Host "⚠ Feed removal happens AFTER package installation"
Write-Host "⚠ If package installation fails, feeds may still be removed"
Write-Host "⚠ Use -WhatIf to preview actions before executing"
Write-Host "⚠ Requires administrator privileges for feed operations"

Write-Host "`n=== Testing Your Setup ===" -ForegroundColor Cyan
Write-Host "To test this functionality safely, use -WhatIf:"

$testCommand = @"
Apply-NipkgSnapshot -SnapshotPath 'your-snapshot.json' -RemoveSnapshotFeeds -WhatIf
"@
Write-Host $testCommand -ForegroundColor White

Write-Host "`nThis will show you what would happen without making actual changes."

Write-Host "`n=== Next Steps ===" -ForegroundColor Green
Write-Host "1. Create or obtain a snapshot file"
Write-Host "2. Test with -WhatIf first"
Write-Host "3. Run the actual command when ready"
Write-Host "4. Verify the results with Get-FeedsInfoFromNipkgCmd"

Write-Host "`n=== Demo Complete ===" -ForegroundColor Green
Write-Host "The RemoveSnapshotFeeds functionality is now available in Apply-NipkgSnapshot!"
Write-Host "Use it to keep your NIPKG system clean and organized." -ForegroundColor White
