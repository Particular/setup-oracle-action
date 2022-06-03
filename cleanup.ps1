param (
    [string]$OracleContainerName
)

$ignore = az container delete --resource-group GitHubActions-RG --name $OracleContainerName --yes