param (
    [string]$OracleContainerName = "psw-oracle-1",
    [string]$StorageContainerName = "psworacle1",
    [string]$ConnectionStringName = "OracleConnectionString",
    [string]$TagName = "setup-oracle-action",
    [string]$InitScript = $null
)

$dockerImage = "gvenzl/oracle-xe:21-slim"
$oraclePassword = "Welcome1"
$ipAddress = "127.0.0.1"
$connectionPort = 1521
$runnerOs = $Env:RUNNER_OS ?? "Linux"
$resourceGroup = "GitHubActions-RG"
$healthCheckCommand = ""
$scriptExecutionCommand = ""

Write-Output "::add-mask::$ipAddress"

if ($runnerOs -eq "Linux") {
    Write-Output "Running Oracle using Docker"
    docker run --name "$($OracleContainerName)" -d -p "$($connectionPort):$($connectionPort)" -e ORACLE_PASSWORD=$oraclePassword $dockerImage

    $healthCheckCommand = "docker exec ""$($OracleContainerName)"" sqlplus system/$($oraclePassword)@$($ipAddress):$($connectionPort)/XEPDB1"
    $scriptExecutionCommand = "Get-Content $($InitScript) | docker exec -i ""$($OracleContainerName)"" sqlplus system/$($oraclePassword)@$($ipAddress):$($connectionPort)/XEPDB1"
}
elseif ($runnerOs -eq "Windows") {
    $hostInfo = curl -H Metadata:true "169.254.169.254/metadata/instance?api-version=2017-08-01" | ConvertFrom-Json
    $region = $hostInfo.compute.location
    $runnerOsTag = "RunnerOS=$($runnerOs)"
    $packageTag = "Package=$TagName"
    $dateTag = "Created=$(Get-Date -Format "yyyy-MM-dd")"
    $mountPath = "/mnt/scripts";

    Write-Output "Creating a storage account (This can take a while.)"
    $storageAccountDetails = az storage account create --name $StorageContainerName --location $region --resource-group $resourceGroup --sku Standard_LRS | ConvertFrom-Json

    Write-Output "Getting the storage account key"
    $storageAccountKeyDetails = az storage account keys list --account-name $StorageContainerName --resource-group $resourceGroup | ConvertFrom-Json
    $storageAccountKey = $storageAccountKeyDetails[0].value
    Write-Output "::add-mask::$storageAccountKey"

    Write-Output "Tagging the storage account"
    az tag create --resource-id $storageAccountDetails.id --tags $packageTag $runnerOsTag $dateTag | Out-Null

    Write-Output "Creating the file share"
    az storage share create --account-name $StorageContainerName --name $StorageContainerName --account-key $storageAccountKey | Out-Null

    if ($InitScript) {
        $initScriptDestinationFileName = [System.IO.Path]::GetFileName($InitScript)
        $initScriptRunScriptDestinationFileName = "runInitScript.sh";
        "sqlplus system/$($oraclePassword)@localhost:$($connectionPort)/XEPDB1 @$($mountPath)/$($initScriptDestinationFileName)" | Out-File -FilePath $initScriptRunScriptDestinationFileName -NoNewline

        Write-Output "Uploading the init script"
        az storage file upload --account-name $StorageContainerName --path $initScriptDestinationFileName --share-name $StorageContainerName --source $InitScript --account-key $storageAccountKey
        Write-Output "Uploading the init script run script"
        az storage file upload --account-name $StorageContainerName --path $initScriptRunScriptDestinationFileName --share-name $StorageContainerName --source $initScriptRunScriptDestinationFileName --account-key $storageAccountKey
    }
    
    Write-Output "Running Oracle container $OracleContainerName in $region (This can take a while.)"
    
    $oracleContainerDetails = az container create --image $dockerImage --name $OracleContainerName --location $region --resource-group $resourceGroup --cpu 4 --memory 8 --ports $connectionPort --ip-address public --environment-variables ORACLE_PASSWORD=$oraclePassword --azure-file-volume-share-name $StorageContainerName --azure-file-volume-account-name $StorageContainerName --azure-file-volume-account-key $storageAccountKey --azure-file-volume-mount-path $mountPath
    
    if (!$oracleContainerDetails) {
        Write-Output "Failed to create Oracle container $OracleContainerName in $region"
        exit 1;
    }
    
    $details = $oracleContainerDetails | ConvertFrom-Json
    
    if (!$details.ipAddress) {
        Write-Output "Failed to create Oracle container $OracleContainerName in $region"
        Write-Output $oracleContainerDetails
        exit 1;
    }
    
    $ipAddress = $details.ipAddress.ip

    $healtCheckScriptFileName = "healthcheck.sh";
    # Exit is required to make sure sqlplus doesn't keep on running with az container exec
    "exit | sqlplus system/$($oraclePassword)@$($ipAddress):$($connectionPort)/XEPDB1" | Out-File -FilePath $healtCheckScriptFileName -NoNewline
    
    Write-Output "Uploading the healthcheck script"
    az storage file upload --account-name $StorageContainerName --path $healtCheckScriptFileName --share-name $StorageContainerName --source $healtCheckScriptFileName --account-key $storageAccountKey
    
    Write-Output "Tagging Oracle container image"
        
    az tag create --resource-id $details.id --tags $packageTag $runnerOsTag $dateTag | Out-Null

    $scriptExecutionCommand = "az container exec --name ""$($OracleContainerName)"" --resource-group $resourceGroup --exec-command ""bash $($mountPath)/$($initScriptRunScriptDestinationFileName)"""
    $healthCheckCommand = "az container exec --name ""$($OracleContainerName)"" --resource-group $resourceGroup --exec-command ""bash $($mountPath)/$($healtCheckScriptFileName)"""
}
else {
    Write-Output "$runnerOs not supported"
    exit 1
}

Write-Output "::group::Connectivity"

$tries = 0

do {
    $tries++
    Write-Output "Checking for connectivity $($tries)/50..."
    $healthCheckOutput = Invoke-Expression $healthCheckCommand
    if ([regex]::Matches($healthCheckOutput, 'Connected to:')) {
        Write-Output "Connection successful"
        break;
    }
    else {
        Write-Output "No connection, retrying..."
        Write-Output $healthCheckOutput
        Start-Sleep -s 5
    }
} until ($tries -ge 50)

if ($tries -ge 50) {
    Write-Output "Failed to connect after 50 attempts";
    exit 1
}

Write-Output "::endgroup::"

"$($ConnectionStringName)=User Id=system;Password=$($oraclePassword);Data Source=$($ipAddress):$($connectionPort)/XEPDB1;" >> $Env:GITHUB_ENV

if ($InitScript) {
    
    Write-Output "::group::Init Script"

    $scriptExecutionCommand = $scriptExecutionCommand + '; $scriptExecutionSuccess=$?'
    Write-Output "Executing script $InitScript against the database"
    Invoke-Expression $scriptExecutionCommand
    if (-not $scriptExecutionSuccess) {
        Write-Output "Script execution of $InitScript did not successfully complete"
        exit 1
    }

    Write-Output "::endgroup::"
}
