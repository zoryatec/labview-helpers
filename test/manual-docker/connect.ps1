# Start or create LabVIEW container
$container = "labview-dev-container"
$image = "labview-dev-image"

# Try to start existing container, if it fails then create new one
docker start $container 2>$null
if ($LASTEXITCODE -ne 0) {
    docker run -d --name $container --isolation=process -v "${PWD}:C:\workspace" $image
}

# Show status and connect with PowerShell
docker ps --filter "name=$container"
Write-Host "Connecting to container with PowerShell..."
docker exec -it $container powershell