# Quick test to debug import issue
param(
    [string]$ModulePath = "..\..\LabViewHelpers\NipkgHelper.psm1"
)

Import-Module $ModulePath -Force

$exportPath = "test-temp\final-test-export.json"
if (Test-Path $exportPath) {
    $importedSnapshot = Import-NipkgSnapshotFromJson -InputPath $exportPath
    
    Write-Host "Imported snapshot type: $($importedSnapshot.GetType().Name)"
    Write-Host "Properties:"
    $importedSnapshot.PSObject.Properties | ForEach-Object {
        Write-Host "  $($_.Name): $($_.Value.GetType().Name) (Count: $($_.Value.Count))"
    }
    
    Write-Host "`nChecking packages-nipkg specifically:"
    Write-Host "Has packages-nipkg property: $($importedSnapshot.PSObject.Properties.Name -contains 'packages-nipkg')"
    Write-Host "packages-nipkg value: $($importedSnapshot.'packages-nipkg')"
    Write-Host "packages-nipkg count: $($importedSnapshot.'packages-nipkg'.Count)"
    
    if ($importedSnapshot."packages-nipkg") {
        Write-Host "packages-nipkg contents:"
        $importedSnapshot."packages-nipkg" | ForEach-Object {
            Write-Host "  - $($_.name): $($_.version)"
        }
    }
} else {
    Write-Host "Export file not found: $exportPath"
}
