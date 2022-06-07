param (
    [string]$OracleContainerName
)

if ($Env:RUNNER_OS -eq "Windows") 
{
    $ignore = az container delete --resource-group GitHubActions-RG --name $OracleContainerName --yes
}