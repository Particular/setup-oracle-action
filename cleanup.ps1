param (
    [string]$OracleContainerName
)

if ($Env:RUNNER_OS -eq "Windows") 
{
    Write-Output "Cleaning external container instances"
    $ignore = az container delete --resource-group GitHubActions-RG --name $OracleContainerName --yes
}