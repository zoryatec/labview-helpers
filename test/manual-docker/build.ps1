
$workingDir = $PSScriptRoot
Remove-Item -Path "$workingDir\src" -Recurse -Force -ErrorAction SilentlyContinue
Copy-Item -Path "$workingDir\..\..\src" -Destination "$workingDir\src" -Recurse -Force

docker build -t labview-dev-image -f $workingDir\Dockerfile $workingDir