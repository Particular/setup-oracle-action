param (
    [string]$ContainerName,
    [string]$StorageName
)

if ($Env:RUNNER_OS -eq "Windows") 
{
    Write-Output "Deleting Azure container $ContainerName"
    az container delete --resource-group GitHubActions-RG --name $ContainerName --yes | Out-Null

    Write-Output "Deleting Azure storage account $StorageName"
    az storage account delete --resource-group GitHubActions-RG --name $StorageName --yes | Out-Null
}
