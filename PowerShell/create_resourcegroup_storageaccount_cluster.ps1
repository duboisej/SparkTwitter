$token ="fluffybunniez"
$subscriptionID = "09bdd24f-995d-4329-b227-7e553a5c5fa0"        # Provide your Subscription Name

$resourceGroupName = $token + "rg"      # Provide a Resource Group name
$clusterName = $token
$defaultStorageAccountName = $token + "store"   # Provide a Storage account name
$defaultStorageContainerName = $token + "container"
$location = "East US 2"     # Change the location if needed
$clusterNodes = 1           # The number of nodes in the HDInsight cluster
$dataLakeStoreName = $token + "lakestore" # Provie Data Lake store name

# Sign in to Azure
Login-AzureRmAccount

# Select the subscription to use if you have multiple subscriptions
Select-AzureRmSubscription -SubscriptionId $subscriptionID

# Register for Azure Data Lake Store
 Register-AzureRmResourceProvider -ProviderNamespace "Microsoft.DataLakeStore"

# Create an Azure Resource Group
New-AzureRmResourceGroup -Name $resourceGroupName -Location $location

# Create an Azure Storage account and container used as the default storage
New-AzureRmStorageAccount `
    -ResourceGroupName $resourceGroupName `
    -StorageAccountName $defaultStorageAccountName `
    -Location $location `
    -Type Standard_LRS
$defaultStorageAccountKey = (Get-AzureRmStorageAccountKey -Name $defaultStorageAccountName -ResourceGroupName $resourceGroupName)[0].Value
$destContext = New-AzureStorageContext -StorageAccountName $defaultStorageAccountName -StorageAccountKey $defaultStorageAccountKey
New-AzureStorageContainer -Name $defaultStorageContainerName -Context $destContext

# Create an Azure Data Lake store account and new folder
New-AzureRmDataLakeStoreAccount -ResourceGroupName $resourceGroupName -Name $dataLakeStoreName -Location "East US 2"
Test-AzureRmDataLakeStoreAccount -Name $dataLakeStoreName
$myrootdir = "/" # specify root directory
New-AzureRmDataLakeStoreItem -Folder -AccountName $dataLakeStoreName -Path $myrootdir/twitterdata # Create new folder in data lake store
Get-AzureRmDataLakeStoreChildItem -AccountName $dataLakeStoreName -Path $myrootdir # Verify successfully created

#Create a new Azure Event Hub to use for Twitter data

New-AzureRmResourceGroupDeployment -ResourceGroupName $resourceGroupName -TemplateFile https://raw.githubusercontent.com/azure/azure-quickstart-templates/master/201-event-hubs-create-event-hub-and-consumer-group/azuredeploy.json

# Create an HDInsight cluster
$credentials = Get-Credential -Message "Enter Cluster user credentials" -UserName "admin"
$sshCredentials = Get-Credential -Message "Enter SSH user credentials"

# The location of the HDInsight cluster must be in the same data center as the Storage account.
$location = Get-AzureRmStorageAccount -ResourceGroupName $resourceGroupName -StorageAccountName $defaultStorageAccountName | %{$_.Location}

New-AzureRmHDInsightCluster `
    -ClusterName $clusterName `
    -ResourceGroupName $resourceGroupName `
    -HttpCredential $credentials `
    -Location $location `
    -DefaultStorageAccountName "$defaultStorageAccountName.blob.core.windows.net" `
    -DefaultStorageAccountKey $defaultStorageAccountKey `
    -DefaultStorageContainer $defaultStorageContainerName  `
    -ClusterSizeInNodes $clusterNodes `
    -ClusterType Hadoop `
    -OSType Linux `
    -Version "3.4" `
    -SshCredential $sshCredentials