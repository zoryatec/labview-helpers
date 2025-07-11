#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Demonstrates the ConvertTo-FeedName function and its integration with Add-FeedDirectories.

.DESCRIPTION
    This script shows how the ConvertTo-FeedName function automatically converts folder names
    to valid feed names when using Add-FeedDirectories, ensuring compatibility with NIPKG
    feed naming requirements.
#>

# Import the module
$ModulePath = Join-Path $PSScriptRoot "..\..\LabViewHelpers\NipkgHelper.psm1"
if (Test-Path $ModulePath) {
    Import-Module $ModulePath -Force
    Write-Host "✓ Imported NipkgHelper module" -ForegroundColor Green
} else {
    Write-Error "Module not found: $ModulePath"
    exit 1
}

Write-Host "`n=== ConvertTo-FeedName Integration Demo ===" -ForegroundColor Cyan

Write-Host "`n--- Problem Solved ---" -ForegroundColor Yellow

Write-Host "`nThe problem:" -ForegroundColor White
Write-Host "• Folder names often contain dots (e.g., 'ni-software-2025.q1')" -ForegroundColor Red
Write-Host "• NIPKG feed names may have issues with certain characters" -ForegroundColor Red
Write-Host "• Need consistent, predictable feed naming" -ForegroundColor Red

Write-Host "`nThe solution:" -ForegroundColor White
Write-Host "• ConvertTo-FeedName function converts folder names to valid feed names" -ForegroundColor Green
Write-Host "• Integrated into Add-FeedDirectories for automatic conversion" -ForegroundColor Green
Write-Host "• Easily extensible for future requirements" -ForegroundColor Green

# Example 1: Manual conversion
Write-Host "`n--- Example 1: Manual Feed Name Conversion ---" -ForegroundColor Yellow

$folderNames = @(
    "ni-software-2025.q1",
    "drivers.24.8.stable",
    "labview.community.2025",
    "test.feeds.development"
)

Write-Host "`nManual conversion examples:" -ForegroundColor White
foreach ($folder in $folderNames) {
    $feedName = ConvertTo-FeedName -FolderName $folder
    Write-Host "  Folder: '$folder'" -ForegroundColor Gray
    Write-Host "  Feed:   '$feedName'" -ForegroundColor Green
    Write-Host ""
}

# Example 2: Integration with Add-FeedDirectories
Write-Host "`n--- Example 2: Integration with Add-FeedDirectories ---" -ForegroundColor Yellow

Write-Host "`nBefore integration:" -ForegroundColor White
Write-Host "Add-FeedDirectories would use folder names directly:" -ForegroundColor Gray
Write-Host "  nipkg feed-add 'C:\\feeds\\ni-software-2025.q1' --name='ni-software-2025.q1'" -ForegroundColor Red

Write-Host "`nAfter integration:" -ForegroundColor White
Write-Host "Add-FeedDirectories now uses ConvertTo-FeedName:" -ForegroundColor Gray
Write-Host "  nipkg feed-add 'C:\\feeds\\ni-software-2025.q1' --name='ni-software-2025_q1'" -ForegroundColor Green

Write-Host "`nThe integration is automatic and transparent:" -ForegroundColor White
Write-Host "• No changes needed to existing Add-FeedDirectories calls" -ForegroundColor Cyan
Write-Host "• Feed names are automatically cleaned up" -ForegroundColor Cyan
Write-Host "• Verbose logging shows the conversion process" -ForegroundColor Cyan

# Example 3: Extensibility demonstration
Write-Host "`n--- Example 3: Future Extensibility ---" -ForegroundColor Yellow

Write-Host "`nCurrent transformations:" -ForegroundColor White
Write-Host "• Replace dots (.) with underscores (_)" -ForegroundColor Green

Write-Host "`nEasy to extend for future requirements:" -ForegroundColor White
Write-Host "• Replace spaces with hyphens" -ForegroundColor Cyan
Write-Host "• Remove special characters" -ForegroundColor Cyan
Write-Host "• Apply case transformations" -ForegroundColor Cyan
Write-Host "• Add prefixes or suffixes" -ForegroundColor Cyan
Write-Host "• Validate against naming patterns" -ForegroundColor Cyan

Write-Host "`nExample future enhancement:" -ForegroundColor White
Write-Host "# Replace dots with underscores" -ForegroundColor Gray
Write-Host "`$feedName = `$feedName -replace '\\.', '_'" -ForegroundColor Gray
Write-Host "# Replace spaces with hyphens" -ForegroundColor Gray
Write-Host "`$feedName = `$feedName -replace ' ', '-'" -ForegroundColor Gray
Write-Host "# Convert to lowercase" -ForegroundColor Gray
Write-Host "`$feedName = `$feedName.ToLower()" -ForegroundColor Gray

# Example 4: Real-world scenarios
Write-Host "`n--- Example 4: Real-world Scenarios ---" -ForegroundColor Yellow

$scenarios = @(
    @{ 
        Scenario = "LabVIEW Installer"
        Folder = "ni-labview-2025.community.x86"
        Feed = "ni-labview-2025_community_x86"
        Description = "Community edition installer feed"
    },
    @{ 
        Scenario = "Driver Package"
        Folder = "ni-daqmx.24.8.stable"
        Feed = "ni-daqmx_24_8_stable"
        Description = "Stable DAQmx driver release"
    },
    @{ 
        Scenario = "Development Feed"
        Folder = "custom.packages.dev.v1.2"
        Feed = "custom_packages_dev_v1_2"
        Description = "Custom development packages"
    },
    @{ 
        Scenario = "Quarterly Release"
        Folder = "ni-software.2025.q1.final"
        Feed = "ni-software_2025_q1_final"
        Description = "Q1 2025 software release"
    }
)

Write-Host "`nReal-world transformation examples:" -ForegroundColor White
foreach ($scenario in $scenarios) {
    Write-Host ""
    Write-Host "Scenario: $($scenario.Scenario)" -ForegroundColor Yellow
    Write-Host "  Description: $($scenario.Description)" -ForegroundColor Gray
    Write-Host "  Folder name: '$($scenario.Folder)'" -ForegroundColor White
    Write-Host "  Feed name:   '$($scenario.Feed)'" -ForegroundColor Green
    
    # Verify the conversion
    $actualFeed = ConvertTo-FeedName -FolderName $scenario.Folder
    if ($actualFeed -eq $scenario.Feed) {
        Write-Host "  ✓ Conversion verified" -ForegroundColor Green
    } else {
        Write-Host "  ✗ Conversion mismatch: expected '$($scenario.Feed)', got '$actualFeed'" -ForegroundColor Red
    }
}

# Example 5: Usage patterns
Write-Host "`n--- Example 5: Usage Patterns ---" -ForegroundColor Yellow

Write-Host "`nCommon usage patterns:" -ForegroundColor White

Write-Host "`n1. Automatic with Add-FeedDirectories:" -ForegroundColor Cyan
Write-Host "   Add-FeedDirectories -FeedsDirectory 'C:\\Installers\\feeds'" -ForegroundColor Gray
Write-Host "   # Feed names automatically converted from folder names" -ForegroundColor Gray

Write-Host "`n2. Manual conversion for custom scenarios:" -ForegroundColor Cyan
Write-Host "   `$feedName = ConvertTo-FeedName -FolderName `$folderName" -ForegroundColor Gray
Write-Host "   & nipkg feed-add `$path --name=`$feedName" -ForegroundColor Gray

Write-Host "`n3. Batch conversion for validation:" -ForegroundColor Cyan
Write-Host "   `$folders | ConvertTo-FeedName | ForEach-Object { Write-Host `$_ }" -ForegroundColor Gray

Write-Host "`n4. Verbose mode for troubleshooting:" -ForegroundColor Cyan
Write-Host "   ConvertTo-FeedName -FolderName 'problematic.name' -Verbose" -ForegroundColor Gray

Write-Host "`n=== Demo Complete ===" -ForegroundColor Cyan
Write-Host "ConvertTo-FeedName provides reliable, extensible folder-to-feed name conversion!" -ForegroundColor Green
Write-Host "Integrated seamlessly with Add-FeedDirectories for automatic operation." -ForegroundColor Green
