param (
    [string]$ContainerName,
    [string]$ConnectionStringName,
    [string]$InitScript = "",
    [string]$RegistryLoginServer = "index.docker.io",
    [string]$RegistryUser,
    [string]$RegistryPass
)

$dockerImage = "gvenzl/oracle-free:23-slim"
$oraclePassword = "Welcome1"
$ipAddress = "127.0.0.1"
$port = 1521
$runnerOs = $Env:RUNNER_OS ?? "Linux"

if (-not $Env:WSL_TOOLS_MODULE_PATH) {
    throw "This action requires Particular/setup-wsl-action to run first."
}
Import-Module $Env:WSL_TOOLS_MODULE_PATH -Force

if ($runnerOs -eq "Linux") {
    Write-Output "Running Oracle in container $($ContainerName) using Docker"

    docker run --name "$($ContainerName)" -d -p "$($port):$($port)" -e ORACLE_PASSWORD=$oraclePassword $dockerImage

    $testConnectionCommand = "docker exec ""$($ContainerName)"" sqlplus system/$($oraclePassword)@$($ipAddress):$($port)/FREEPDB1"
}
elseif ($runnerOs -eq "Windows") {
    Write-Output "Running Oracle in container $($ContainerName) using WSL"

    $wslDistribution = $Env:WSL_DISTRIBUTION
    $ipAddress = $Env:WSL_IP

    if (-not $ipAddress) {
        throw "WSL_IP is not set. Run Particular/setup-wsl-action before this action."
    }
    Write-Output "WSL address: $ipAddress"

    if ($registryUser -and $registryPass) {
        Write-Output "::add-mask::$registryPass"
        Write-Output "Logging in to $RegistryLoginServer inside WSL"
        $registryPass | wsl.exe --distribution $wslDistribution --user root -- bash -c "docker login --username '$RegistryUser' --password-stdin '$RegistryLoginServer'"
        if ($LASTEXITCODE -ne 0) {
            throw "Docker registry login inside WSL failed with exit code $LASTEXITCODE"
        }
    }
    else {
        Write-Output "Using anonymous credentials"
    }

    Write-Output "::group::Starting Oracle container"
    Invoke-Wsl -Distribution $wslDistribution -CheckExitCode -Command "docker run --name $ContainerName --detach --restart unless-stopped --publish ${port}:${port} -e ORACLE_PASSWORD='$oraclePassword' $dockerImage"
    Invoke-Wsl -Distribution $wslDistribution -Command "docker ps --filter name=$ContainerName"
    Write-Output "::endgroup::"

    $testConnectionCommand = "docker exec $ContainerName sqlplus system/$oraclePassword@localhost:$port/FREEPDB1"
}
else {
    Write-Output "$runnerOs not supported"
    exit 1
}

Write-Output "::group::Testing connection"

$tries = 0

do {
    $tries++
    Write-Output "Testing connection $($tries)/50..."
    if ($runnerOs -eq "Windows") {
        $testConnectionOutput = Invoke-Wsl -Distribution $wslDistribution -Command $testConnectionCommand
    }
    else {
        $testConnectionOutput = Invoke-Expression $testConnectionCommand
    }
    if ([regex]::Matches($testConnectionOutput, 'Connected to:')) {
        Write-Output "Connection successful"
        break
    }
    else {
        Write-Output "No connection, retrying..."
        Write-Output $testConnectionOutput
        Start-Sleep -s 5
    }
} until ($tries -ge 50)

if ($tries -ge 50) {
    Write-Output "Failed to connect after 50 attempts"
    exit 1
}

Write-Output "::endgroup::"

"$($ConnectionStringName)=User Id=system;Password=$($oraclePassword);Data Source=$($ipAddress):$($port)/FREEPDB1;" >> $Env:GITHUB_ENV

if ($InitScript) {
    Write-Output "::group::Running init script $InitScript"

    if ($runnerOs -eq "Windows") {
        $wslInitScript = ConvertTo-WslPath (Resolve-Path $InitScript).Path
        Invoke-Wsl -Distribution $wslDistribution -CheckExitCode -Command "docker cp '$wslInitScript' ${ContainerName}:/tmp/init.sql"
        Invoke-Wsl -Distribution $wslDistribution -CheckExitCode -Command "docker exec $ContainerName sqlplus system/$oraclePassword@localhost:$port/FREEPDB1 @/tmp/init.sql"
    }
    else {
        Get-Content $InitScript | docker exec -i $ContainerName sqlplus system/$oraclePassword@${ipAddress}:${port}/FREEPDB1
    }
    if (-not $?) {
        Write-Output "Init script $InitScript failed"
        exit 1
    }

    Write-Output "::endgroup::"
}
