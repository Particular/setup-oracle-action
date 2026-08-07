param (
    [string]$ContainerName
)

if (-not $Env:WSL_TOOLS_MODULE_PATH) {
    throw "This action requires Particular/setup-wsl-action to run first."
}
Import-Module $Env:WSL_TOOLS_MODULE_PATH -Force

$runnerOs = $Env:RUNNER_OS ?? "Linux"

if ($runnerOs -eq "Linux") {
    Write-Output "Killing Docker container $ContainerName"
    docker kill $ContainerName

    Write-Output "Removing Docker container $ContainerName"
    docker rm $ContainerName
}
elseif ($runnerOs -eq "Windows") {
    Write-Output "Removing WSL Docker container $ContainerName"
    Invoke-Wsl -Command "docker rm --force ${ContainerName} 2>/dev/null || true"
}
else {
    Write-Output "$runnerOs not supported"
    exit 1
}
