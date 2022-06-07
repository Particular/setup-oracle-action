param (
    [string]$oracleContainerName,
    [string]$connectionStringName,
    [string]$tagName
)

$dockerImage = "gvenzl/oracle-xe:21-slim"
$oraclePassword = "Welcome1"
$ip = "127.0.0.1"
$port = 1521

Write-Output "::add-mask::$ip"

Write-Output $Env:RUNNER_OS
if ($Env:RUNNER_OS -eq "Linux") {
    Write-Output "Running Oracle using Docker"
    docker run --name $oracleContainerName -d -p $port:1521 -e ORACLE_PASSWORD=$oraclePassword $dockerImage

    for ($i = 0; $i -lt 24; $i++) {
        ## 2 minute timeout
        Write-Output "Checking for Oracle connectivity $($i+1)/24..."
        docker exec $oracleContainerName ./healthcheck.sh
        if ($?) {
            Write-Output "Connection successful"
            break;
        }
        sleep 5
    }
}
elseif ($Env:RUNNER_OS -eq "Windows") {
    $hostInfo = curl -H Metadata:true "169.254.169.254/metadata/instance?api-version=2017-08-01" | ConvertFrom-Json
    $region = $hostInfo.compute.location
    $runnerOsTag = "RunnerOS=$($Env:RUNNER_OS)"
    $packageTag = "Package=$tagName"
    
    Write-Output "Running Oracle container $oracleContainerName in $region (This can take a while.)"
    
    $jsonResult = az container create --image $dockerImage --name $oracleContainerName --location $region --dns-name-label $oracleContainerName --resource-group GitHubActions-RG --cpu 4 --memory 16 --ports $port --ip-address public --environment-variables ORACLE_PASSWORD=$oraclePassword
    
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
    
    $tcpClient = New-Object Net.Sockets.TcpClient
    $tries = 0
    
    do {
        $tries++
        try {
            $tcpClient.Connect($ip, 1521)
            Write-Output "Connection to $oracleContainerName successful"
        }
        catch {
            Write-Output "No response, retrying $($tries)/50..."
            Start-Sleep -m 5000
        }
    } until (($tcpClient.Connected -eq "True") -or ($tries -ge 50))
    
    if ($tcpClient.Connected -ne "True") {
        Write-Output "Failed to connect after 50 attempts";
        $tcpClient.Close()
        exit 1
    }
    else {
        $tcpClient.Close()
    }
}
else {
    Write-Output "$Env:RUNNER_OS not supported"
    exit 1
}

"$connectionStringName=$ip:1521" >> $Env:GITHUB_ENV