#########################################################
# Script to create Azure resources for SparkTwitter POC #
#########################################################

$token ="sparktwitter"
$subscriptionID = "09bdd24f-995d-4329-b227-7e553a5c5fa0"        # Provide your Subscription Name

$resourceGroupName = $token + "rg"      # Provide a Resource Group name
$clusterName = $token
$defaultStorageAccountName = $token + "store"   # Provide a Storage account name
$defaultStorageContainerName = $token + "container"
$location = "East US 2"     # Change the location if needed
$clusterNodes = 2          # The number of nodes in the HDInsight cluster
$dataLakeStoreName = $token + "lakestore" # Provide Data Lake store name

# Sign in to Azure
Login-AzureRmAccount

# Select the subscription to use if you have multiple subscriptions
Select-AzureRmSubscription -SubscriptionId $subscriptionID
<#
# Create an Azure Resource Group
New-AzureRmResourceGroup -Name $resourceGroupName -Location $location

# Create an Azure Storage account and container used as the default storage
New-AzureRmStorageAccount `
    -ResourceGroupName $resourceGroupName `
    -StorageAccountName $defaultStorageAccountName `
    -Location $location `
    -Type Standard_LRS

#>
$defaultStorageAccountKey = (Get-AzureRmStorageAccountKey -Name $defaultStorageAccountName -ResourceGroupName $resourceGroupName)[0].Value

<#
$destContext = New-AzureStorageContext -StorageAccountName $defaultStorageAccountName -StorageAccountKey $defaultStorageAccountKey

New-AzureStorageContainer -Name $defaultStorageContainerName -Context $destContext

#######################################################
#Create a new Azure Event Hub to use for Twitter data #
#######################################################

New-AzureRmResourceGroupDeployment -ResourceGroupName $resourceGroupName -TemplateFile https://raw.githubusercontent.com/azure/azure-quickstart-templates/master/201-event-hubs-create-event-hub-and-consumer-group/azuredeploy.json

##########################
# Create Data Lake store #
##########################

# Register for Azure Data Lake Store
Register-AzureRmResourceProvider -ProviderNamespace "Microsoft.DataLakeStore"
#>
<# Set up data lake store
New-AzureRmDataLakeStoreAccount -ResourceGroupName $resourceGroupName -Name $dataLakeStoreName -Location "East US 2"
Test-AzureRmDataLakeStoreAccount -Name $dataLakeStoreName
#>
$myrootdir = "/" # specify root directory
<#
New-AzureRmDataLakeStoreItem -Folder -AccountName $dataLakeStoreName -Path $myrootdir/twitterdata # Create new folder in data lake store
Get-AzureRmDataLakeStoreChildItem -AccountName $dataLakeStoreName -Path $myrootdir # Verify successfully created
#>
# Create self-signed certificate

$certificateFileDir = "C:\\Users\ethandubois\Documents\SparkTwitter\Certificates"

cd $certificateFileDir

& "C:\Program Files (x86)\Windows Kits\10\bin\x64\makecert.exe" -sv mykey.pvk -n "cn=HDI-ADL-SP" CertFile.cer -r -len 2048

& "C:\Program Files (x86)\Windows Kits\10\bin\x64\pvk2pfx.exe" -pvk mykey.pvk -spc CertFile.cer -pfx CertFile.pfx -po "password1"

# Create Azure AD/Service principal

$certificateFilePath = "$certificateFileDir\CertFile.pfx"

$password = Read-Host –Prompt "Enter the password" # This is the password you specified for the .pfx file

$certificatePFX = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($certificateFilePath, $password)

$rawCertificateData = $certificatePFX.GetRawCertData()

$credential = [System.Convert]::ToBase64String($rawCertificateData)

$application = New-AzureRmADApplication `
    -DisplayName "SparkTwitter" `
    -HomePage "https://sparktwitter.ethandubois.com" `
    -IdentifierUris "https://sparktwitter.ethandubois.com" `
    -CertValue $credential  `
    -StartDate $certificatePFX.NotBefore  `
    -EndDate $certificatePFX.NotAfter

$application = Get-AzureRmADApplication -IdentifierUri "https://sparktwitter.ethandubois.com"

$applicationId = $application.ApplicationId

$servicePrincipal = New-AzureRmADServicePrincipal -ApplicationId $applicationId

$objectId = $servicePrincipal.Id

Set-AzureRmDataLakeStoreItemAclEntry -AccountName $dataLakeStoreName -Path / -AceType User -Id $objectId -Permissions All

################################################################################
# Create Stream Analytics Job to send data from event hub into data lake store #
################################################################################

# Note: Apparently Microsoft doesn't know how to write documentation that makes any sense ever. 
# Log into Azure Portal and create Stream analytics job manually
# See: https://docs.microsoft.com/en-us/azure/stream-analytics/stream-analytics-create-a-job

# PS C:\>New-AzureRmStreamAnalyticsJob -ResourceGroupName $resourceGroupName -Name "SparkTwitter-SAJob" -File "C:\Users\ethandubois\Documents\SparkTwitter\StreamAnalytics\SAJobDefinition.json"

# PS C:\>New-AzureRmStreamAnalyticsInput -ResourceGroupName $resourceGroupName -Name "EventHubSource" -JobName "SparkTwitter-SAJob" -File "C:\SAJobInput.json"

# Note: currently, Azure Data Lake store output is not supported for New-AzureRmStreamAnalyticsOutput because of authorization
# Need to log into Azure portal and configure the output to data lake store manually 
# PS C:\>New-AzureRmStreamAnalyticsOutput -ResourceGroupName $resourceGroupName -File "C:\Output.json" -JobName "SparkTwitter-SAJob" -Name "Output"


###################################
# Create cluster with ApacheSpark #
###################################

$httpCredentials = Get-Credential -Message "Enter Cluster user credentials" -UserName "admin"
$sshCredentials = Get-Credential -Message "Enter SSH user credentials"

# The location of the HDInsight cluster must be in the same data center as the Storage account.
$location = Get-AzureRmStorageAccount -ResourceGroupName $resourceGroupName -StorageAccountName $defaultStorageAccountName | %{$_.Location}


$tenantID = (Get-AzureRmContext).Tenant.TenantId

# Create a cluster with Spark installed 
# using Data Lake tenant/certificate
New-AzureRmHDInsightCluster `
        -ResourceGroupName $resourceGroupName `
        -ClusterName $clusterName `
        -Location $location `
        -ClusterSizeInNodes $clusterNodes `
        -HttpCredential $httpCredentials `
        -SshCredential $sshCredentials `
        -ClusterType Spark `
        -OSType Linux `
        -DefaultStorageContainer $defaultStorageContainerName `
        -DefaultStorageAccountKey $defaultStorageAccountKey `
        -DefaultStorageAccountName "$defaultStorageAccountName.blob.core.windows.net" `
        -ObjectID $objectId `
        -AadTenantId $tenantID `
        -CertificateFilePath $certificateFilePath `
        -CertificatePassword "password1"


# example spark submit 
#spark-submit --master yarn-cluster --class "com.microsoft.spark.streaming.examples.workloads.EventhubsEventCount" wasbs:///spark-streaming-data-persistence-examples.jar
#Note: need to add all the necessary arguments required by the main method of the class - see java code