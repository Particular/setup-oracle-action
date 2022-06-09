param (
    [string]$oracleContainerName = "psw-oracle-1",
    [string]$connectionStringName = "OracleConnectionString",
    [string]$tagName = "setup-oracle-action"
)

$dockerImage = "gvenzl/oracle-xe:21-slim"
$oraclePassword = "Welcome1"
$ip = "127.0.0.1"
$connectionPort = 1521
$runnerOs = $Env:RUNNER_OS ?? "Linux"
$resourceGroup = "GitHubActions-RG"
$healthCheckCommand = ""

Write-Output "::add-mask::$ip"

if ($runnerOs -eq "Linux") {
    Write-Output "Running Oracle using Docker"
    docker run --name "$($oracleContainerName)" -d -p "$($connectionPort):$($connectionPort)" -e ORACLE_PASSWORD=$oraclePassword $dockerImage

    $healthCheckCommand = "docker exec ""$($oracleContainerName)"" ./healthcheck.sh XEPDB1"
}
elseif ($runnerOs -eq "Windows") {
    $hostInfo = curl -H Metadata:true "169.254.169.254/metadata/instance?api-version=2017-08-01" | ConvertFrom-Json
    $region = $hostInfo.compute.location
    $runnerOsTag = "RunnerOS=$($runnerOs)"
    $packageTag = "Package=$tagName"
    
    Write-Output "Running Oracle container $oracleContainerName in $region (This can take a while.)"
    
    $jsonResult = az container create --image $dockerImage --name $oracleContainerName --location $region --dns-name-label $oracleContainerName --resource-group $resourceGroup --cpu 4 --memory 16 --ports $connectionPort --ip-address public --environment-variables ORACLE_PASSWORD=$oraclePassword
    
    if (!$jsonResult) {
        Write-Output "Failed to create Oracle container"
        exit 1;
    }
    
    $details = $jsonResult | ConvertFrom-Json
    
    if (!$details.ipAddress) {
        Write-Output "Failed to create Oracle container $oracleContainerName in $region"
        Write-Output $jsonResult
        exit 1;
    }
    
    $ip = $details.ipAddress.ip
    
    Write-Output "Tagging container image"
    
    $dateTag = "Created=$(Get-Date -Format "yyyy-MM-dd")"
    az tag create --resource-id $details.id --tags $packageTag $runnerOsTag $dateTag | Out-Null

    $healthCheckCommand = "az container exec --name ""$($oracleContainerName)"" --resource-group $resourceGroup --exec-command ""./healthcheck.sh XEPDB1"""
}
else {
    Write-Output "$runnerOs not supported"
    exit 1
}

$healthCheckCommand += ';$?'
for ($i = 0; $i -lt 50; $i++) {
    Write-Output "Checking for Oracle connectivity $($i+1)/50..."
    $Success = Invoke-Expression $healthCheckCommand
    if ($Success) {
        Write-Output "Connection successful"
        break;
    }
    sleep 5
}

"$($connectionStringName)=User Id=system;Password=$($oraclePassword);Data Source=$($ip):$($connectionPort)/XEPDB1;" >> $Env:GITHUB_ENV
