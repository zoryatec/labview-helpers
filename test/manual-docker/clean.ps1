# Clean up LabVIEW container
$container = "labview-dev-container"

Write-Host "Cleaning up container: $container"
docker stop $container 2>$null
docker rm $container 2>$null
Write-Host "Done."