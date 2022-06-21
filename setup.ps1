param (
    [string]$ContainerName,
    [string]$StorageName,
    [string]$ConnectionStringName,
    [string]$Tag,
    [string]$InitScript = ""
)

$dockerImage = "gvenzl/oracle-xe:21-slim"
$oraclePassword = "Welcome1"
$ipAddress = "127.0.0.1"
$port = 1521
$runnerOs = $Env:RUNNER_OS ?? "Linux"
$resourceGroup = $Env:RESOURCE_GROUP_OVERRIDE ?? "GitHubActions-RG"
$testConnectionCommand = ""
$runInitScriptCommand = ""

if ($runnerOs -eq "Linux") {
    Write-Output "Running Oracle in container $($ContainerName) using Docker"

    docker run --name "$($ContainerName)" -d -p "$($port):$($port)" -e ORACLE_PASSWORD=$oraclePassword $dockerImage

    $testConnectionCommand = "docker exec ""$($ContainerName)"" sqlplus system/$($oraclePassword)@$($ipAddress):$($port)/XEPDB1"

    if ($InitScript) {
        $runInitScriptCommand = "Get-Content $($InitScript) | docker exec -i ""$($ContainerName)"" sqlplus system/$($oraclePassword)@$($ipAddress):$($port)/XEPDB1"
    }
}
elseif ($runnerOs -eq "Windows") {
    Write-Output "Running Oracle in container $($ContainerName) using Azure"

    if ($Env:REGION_OVERRIDE) {
        $region = $Env:REGION_OVERRIDE
    }
    else {
        $hostInfo = curl -H Metadata:true "169.254.169.254/metadata/instance?api-version=2017-08-01" | ConvertFrom-Json
        $region = $hostInfo.compute.location
    }

    $runnerOsTag = "RunnerOS=$($runnerOs)"
    $packageTag = "Package=$Tag"
    $dateTag = "Created=$(Get-Date -Format "yyyy-MM-dd")"
    $mountPath = "/mnt/scripts";

    Write-Output "Creating storage account $StorageName in $region (this can take a while)"
    $storageAccountDetails = az storage account create --name $StorageName --location $region --resource-group $resourceGroup --sku Standard_LRS | ConvertFrom-Json
    $storageAccountId = $storageAccountDetails.id

    Write-Output "Getting the storage account key"
    $storageAccountKeyDetails = az storage account keys list --account-name $StorageName --resource-group $resourceGroup | ConvertFrom-Json
    $storageAccountKey = $storageAccountKeyDetails[0].value
    Write-Output "::add-mask::$storageAccountKey"

    Write-Output "Tagging the storage account"
    az tag create --resource-id $storageAccountId --tags $packageTag $runnerOsTag $dateTag | Out-Null

    Write-Output "Creating the file share"
    az storage share create --account-name $StorageName --name $StorageName --account-key $storageAccountKey | Out-Null
    
    Write-Output "Creating container $ContainerName in $region (this can take a while)"
    $containerJson = az container create --image $dockerImage --name $ContainerName --location $region --resource-group $resourceGroup --cpu 4 --memory 8 --ports $port --ip-address public --environment-variables ORACLE_PASSWORD=$oraclePassword --azure-file-volume-share-name $StorageName --azure-file-volume-account-name $StorageName --azure-file-volume-account-key $storageAccountKey --azure-file-volume-mount-path $mountPath
    
    if (!$containerJson) {
        Write-Output "Failed to create container $ContainerName in $region"
        exit 1;
    }
    
    $containerDetails = $containerJson | ConvertFrom-Json
    
    if (!$containerDetails.ipAddress) {
        Write-Output "Failed to create container $ContainerName in $region"
        Write-Output $containerJson
        exit 1;
    }

    $ipAddress = $containerDetails.ipAddress.ip
    Write-Output "::add-mask::$ipAddress"

    Write-Output "Tagging the container"
    az tag create --resource-id $containerDetails.id --tags $packageTag $runnerOsTag $dateTag | Out-Null

    $testConnectionScriptFileName = "test-connection.sh";

    # create the test connection script
    # in Azure Containers, the exit command must piped to SQL Plus to make the command exit
    "exit | sqlplus system/$($oraclePassword)@$($ipAddress):$($port)/XEPDB1" | Out-File -FilePath $testConnectionScriptFileName -NoNewline
    
    Write-Output "Uploading the test connection script"
    az storage file upload --account-name $StorageName --path $testConnectionScriptFileName --share-name $StorageName --source $testConnectionScriptFileName --account-key $storageAccountKey
    
    $testConnectionCommand = "az container exec --name ""$($ContainerName)"" --resource-group $resourceGroup --exec-command ""bash $($mountPath)/$($testConnectionScriptFileName)"""

    if ($InitScript) {
        $initScriptFileName = [System.IO.Path]::GetFileName($InitScript)
        $runInitScriptFilename = "run-init-script.sh";

        # create the script to run the init script
        "sqlplus system/$($oraclePassword)@localhost:$($port)/XEPDB1 @$($mountPath)/$($initScriptFileName)" | Out-File -FilePath $runInitScriptFilename -NoNewline

        Write-Output "Uploading the init script"
        az storage file upload --account-name $StorageName --path $initScriptFileName --share-name $StorageName --source $InitScript --account-key $storageAccountKey

        Write-Output "Uploading the script to run the init script"
        az storage file upload --account-name $StorageName --path $runInitScriptFilename --share-name $StorageName --source $runInitScriptFilename --account-key $storageAccountKey

        $runInitScriptCommand = "az container exec --name ""$($ContainerName)"" --resource-group $resourceGroup --exec-command ""bash $($mountPath)/$($runInitScriptFilename)"""
    }
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
    $testConnectionOutput = Invoke-Expression $testConnectionCommand
    if ([regex]::Matches($testConnectionOutput, 'Connected to:')) {
        Write-Output "Connection successful"
        break;
    }
    else {
        Write-Output "No connection, retrying..."
        Write-Output $testConnectionOutput
        Start-Sleep -s 5
    }
} until ($tries -ge 50)

if ($tries -ge 50) {
    Write-Output "Failed to connect after 50 attempts";
    exit 1
}

Write-Output "::endgroup::"

# write the connection string to the specified environment variable
"$($ConnectionStringName)=User Id=system;Password=$($oraclePassword);Data Source=$($ipAddress):$($port)/XEPDB1;" >> $Env:GITHUB_ENV

if ($InitScript) {
    Write-Output "::group::Running init script $InitScript"

    $runInitScriptCommand = $runInitScriptCommand + '; $scriptExecutionSuccess=$?'
    
    Invoke-Expression $runInitScriptCommand
    if (-not $scriptExecutionSuccess) {
        Write-Output "Init script $InitScript failed"
        exit 1
    }

    Write-Output "::endgroup::"
}
