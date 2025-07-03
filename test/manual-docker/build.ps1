
$workingDir = $PSScriptRoot
Remove-Item -Path "$workingDir\LabViewHelpers" -Recurse -Force -ErrorAction SilentlyContinue
Copy-Item -Path "$workingDir\..\..\LabViewHelpers" -Destination "$workingDir\LabViewHelpers" -Recurse -Force

docker build -t labview-dev-image -f $workingDir\Dockerfile $workingDir