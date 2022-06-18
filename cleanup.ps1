param (
    [string]$OracleContainerName,
    [string]$StorageContainerName
)

if ($Env:RUNNER_OS -eq "Windows") 
{
    Write-Output "Cleaning external container instances"
    az container delete --resource-group GitHubActions-RG --name $OracleContainerName --yes | Out-Null
    az storage account delete --resource-group GitHubActions-RG --name $StorageContainerName --yes | Out-Null
}