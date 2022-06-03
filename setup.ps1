param (
    [string]$hostname,
    [string]$connectionStringName,
    [string]$tagName
)

$hostInfo = curl -H Metadata:true "169.254.169.254/metadata/instance?api-version=2017-08-01" | ConvertFrom-Json
$region = $hostInfo.compute.location
$runnerOsTag = "RunnerOS=$($Env:RUNNER_OS)"
$packageTag = "Package=$tagName"

echo "::set-output name=hostname::$hostname"
echo "Creating Oracle container $hostname in $region (This can take a while.)"

$jsonResult = az container create --image gvenzl/oracle-xe:21 --name $hostname --location $region --dns-name-label $hostname --resource-group GitHubActions-RG --cpu 4 --memory 16 --ports 1521 5500 --ip-address public --environment-variables ORACLE_PASSWORD=Welcome1

if (!$jsonResult) {
    Write-Output "Failed to create Oracle container"
    exit 1;
}

$details = $jsonResult | ConvertFrom-Json

if (!$details.ipAddress) {
    Write-Output "Failed to create Oracle container $hostname in $region"
    Write-Output $jsonResult
    exit 1;
}

$ip=$details.ipAddress.ip

echo "::add-mask::$ip"
echo "Tagging container image"

$dateTag = "Created=$(Get-Date -Format "yyyy-MM-dd")"
$ignore = az tag create --resource-id $details.id --tags $packageTag $runnerOsTag $dateTag

echo "$connectionStringName=$ip:1521" | Out-File -FilePath $Env:GITHUB_ENV -Encoding utf-8 -Append

$uri = "http://" + $ip + ":15672/api/health/checks/virtual-hosts"
$tcpClient = New-Object Net.Sockets.TcpClient
$tries = 0

do {
    $tries++
    try
    {
        $tcpClient.Connect($ip, 1521)
        echo "Connection to $hostname successful"
    } catch 
    {
        Write-Output "No response, retrying..."
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