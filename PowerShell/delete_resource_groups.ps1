# Login
Login-AzureRmAccount 

# Get a list of all Azure subscript that the user can access
$allSubs = Get-AzureRmSubscription 

$allSubs | Sort-Object SubscriptionName | Format-Table -Property SubscriptionName, SubscriptionId, State


$theSub = "09bdd24f-995d-4329-b227-7e553a5c5fa0" # Read-Host "Enter the subscriptionId you want to clean"

Write-Host "You selected the following subscription. (it will be display 15 sec.)" -ForegroundColor Cyan
Get-AzureRmSubscription -SubscriptionId $theSub | Select-AzureRmSubscription 

#Get all the resources groups

$allRG = Get-AzureRmResourceGroup


foreach ( $g in $allRG){

    Write-Host $g.ResourceGroupName -ForegroundColor Yellow 
    Write-Host "------------------------------------------------------`n" -ForegroundColor Yellow 
    $allResources = Find-AzureRmResource -ResourceGroupNameContains $g.ResourceGroupName

    if($allResources){
        $allResources | Format-Table -Property Name, ResourceName
    }
    else{
         Write-Host "-- empty--`n"
    } 
    Write-Host "`n`n------------------------------------------------------" -ForegroundColor Yellow 
}


$lastValidation = Read-Host "Do you wish to delete ALL the resouces previously listed? (YES/ NO)"

if($lastValidation.ToLower().Equals("yes")){

    foreach ( $g in $allRG){

        Write-Host "Deleting " $g.ResourceGroupName 
        Remove-AzureRmResourceGroup -Name $g.ResourceGroupName -Verbose

    }
}
else{
     Write-Host "Aborted. Nothing was deleted." -ForegroundColor Cyan
}