
param(
    [switch]$gallery
)

$workingDir = $PSScriptRoot

if ($gallery) {
    Write-Host "Building with LabViewHelpers from PowerShell Gallery..."
    $dockerFilePath = "$PSScriptRoot\DockerfileFromGallery"
    docker build -t labview-dev-image -f $dockerFilePath $workingDir --no-cache
} else {
    Write-Host "Building with LabViewHelpers from local source..."

    $dockerFilePath = "$PSScriptRoot\DockerfileFromSource"

    Remove-Item -Path "$workingDir\LabViewHelpers" -Recurse -Force -ErrorAction SilentlyContinue
    Copy-Item -Path "$workingDir\..\..\LabViewHelpers" -Destination "$workingDir\LabViewHelpers" -Recurse -Force

    docker build -t labview-dev-image -f $dockerFilePath $workingDir --no-cache
}
