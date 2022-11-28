param (
    [string]$ContainerName,
    [string]$StorageName
)
$resourceGroup = $Env:RESOURCE_GROUP_OVERRIDE ?? "GitHubActions-RG"
$runnerOs = $Env:RUNNER_OS ?? "Linux"

if ($runnerOs -eq "Linux") {
    Write-Output "Killing Docker container $ContainerName"
    docker kill $ContainerName

    Write-Output "Removing Docker container $ContainerName"
    docker rm $ContainerName
}
elseif ($runnerOs -eq "Windows") {
    Write-Output "Deleting Azure container $ContainerName"
    az container delete --resource-group $resourceGroup --name $ContainerName --yes | Out-Null

    Write-Output "Deleting Azure storage account $StorageName"
    az storage account delete --resource-group $resourceGroup --name $StorageName --yes | Out-Null
}
else {
    Write-Output "$runnerOs not supported"
    exit 1
}
