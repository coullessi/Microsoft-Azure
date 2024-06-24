Clear-Host

# 1. CONNECT TO AZURE
Write-Host "Connecting to Azure..." -ForegroundColor Yellow
Connect-AzAccount -WarningAction SilentlyContinue | Out-Null
$subs = @()
$subs += Get-AzSubscription
if ($subs.Count -eq 0) {
    Write-Host "No subscription found. Exiting..." -ForegroundColor Yellow
    break
}
else {
    Write-Host -ForegroundColor Green "`nAvailable subscription(s)"
    $subRanks = @()
    for ($i = 0; $i -lt $subs.Count; $i++) {
        "$($i+1). $($subs[$i].Name)" #(ID: $($subs[$i].Id), Tenant ID: $($subs[$i].TenantId))"
        $subscriptionID = $($subs[$i].Id)
        $tenantID = $($subs[$i].TenantId)
        $subRanks += $i + 1
    }
}
Write-Host
$subRank = Read-Host "Select a subscription"
while ($subRank -notin $subRanks) {
    Write-Host "Enter a valid number. The number must be between 1 and $($subRanks.Count)" -ForegroundColor Yellow
    $subRank = Read-Host "Select a subscription"
}

$subName = $subs[$subRank - 1].Name
$subId = $subs[$subRank - 1].Id
Write-Host
Write-Host -ForegroundColor Cyan "Subscription name: `"$subName`" will be use for your deployment" 
Set-AzContext -SubscriptionId $subId | Out-Null

# 2. Register resource providers
Write-Host "Registering resource providers" -ForegroundColor Yellow
Register-AzResourceProvider -ProviderNamespace Microsoft.HybridCompute | Out-Null
Register-AzResourceProvider -ProviderNamespace Microsoft.GuestConfiguration | Out-Null
Register-AzResourceProvider -ProviderNamespace Microsoft.HybridConnectivity | Out-Null
Register-AzResourceProvider -ProviderNamespace Microsoft.AzureArcData | Out-Null


$resourceGroup = Read-Host "Provide a resourcegroup name for your deployment"
while ($resourceGroup -eq "") {
    Write-Host "You must enter a name for your new resource group" -ForegroundColor Yellow
    $resourceGroup = Read-Host "Provide a name for your new resource group" 
}
$resourceGroup = $resourceGroup #+ (Get-Random -Minimum 100000 -Maximum 1000000)
$location = Read-Host "Provide a location for your deployment (e.g. West US, WestUS, East US,EastUS2, etc.)"
$locations = @("eastus", "eastus2", "westus", "westus2", "east us", "east us 2", "west us", "west us 2")
while ($locations -notcontains $location.ToLower()) {
    Write-Host "You must enter a valid location" -ForegroundColor Yellow
    $location = Read-Host "Provide a location for your deployment (e.g. West US, WestUS, East US,EastUS2, etc.)"
}
# 3. Create a resource group
Write-Host "`nCreating a resource group" -ForegroundColor Yellow
New-AzResourceGroup -Name $resourceGroup -Location $location | Out-Null



Write-Host "Creating a service principal" -ForegroundColor Yellow
$ArcServerOnboardingDetailFile = "ServicePrincipal.txt"
if (!(Test-Path -Path $ArcServerOnboardingDetailFile)) {
    New-Item -ItemType File -Path $ArcServerOnboardingDetailFile -Force
}
$date = Get-Date
"`n##################################################################" | Out-File -FilePath $ArcServerOnboardingDetailFile -Append
"Service principal creation date: $date`nSecret expiration date: $($date.AddDays(7))" | Out-File -FilePath $ArcServerOnboardingDetailFile -Append
"------------------------------------------------------------------" | Out-File -FilePath $ArcServerOnboardingDetailFile -Append
#$ServicePrincipal = New-AzADServicePrincipal -EndDate $date.AddDays(7) -DisplayName "Arc server onboarding account for Linux - $(Get-Random -Maximum 1000)" -Role "Azure Connected Machine Onboarding" -Scope "/subscriptions/$subId/resourceGroups/$resourceGroup"
$ServicePrincipal = New-AzADServicePrincipal -EndDate $date.AddDays(7) -DisplayName "Arc Server Onboarding Account - Linux Server" -Role "Azure Connected Machine Onboarding" -Scope "/subscriptions/$subId/resourceGroups/$resourceGroup"
#$ServicePrincipal | Format-Table AppId, @{ Name = "Secret"; Expression = { $_.PasswordCredentials.SecretText } }

Write-Host -ForegroundColor Yellow "----------------------------------------------------------------------------"
Write-Host -ForegroundColor Green "Service principal creation date: $date`nSecret expiration date: $($date.AddDays(7))"
Write-Host -ForegroundColor Green "Update the playbook with the following details"
Write-Host -ForegroundColor Yellow "----------------------------------------------------------------------------"
Write-Host "`tServicePrincipalId: $($ServicePrincipal.AppId)"
Write-Host "`tServicePrincipalSecret: $($ServicePrincipal.PasswordCredentials.SecretText)"
Write-Host "`tResourceGroup: $resourceGroup"
Write-Host "`tTenantId: $tenantId"
Write-Host "`tSubscriptionId: $subscriptionId"
Write-Host "`tLocation: $location"
Write-Host -ForegroundColor Yellow "----------------------------------------------------------------------------"

#"App ID: $($ServicePrincipal.AppId)`n------------------------------------------------------------------" | Out-File -FilePath $ArcServerOnboardingDetailFile -Append
#"Secret: $($ServicePrincipal.PasswordCredentials.SecretText)`n------------------------------------------------------------------`n" | Out-File -FilePath $ArcServerOnboardingDetailFile -Append
"ServicePrincipalId: $($ServicePrincipal.AppId)`n------------------------------------------------------------------" | Out-File -FilePath $ArcServerOnboardingDetailFile -Append
"ServicePrincipalSecret: $($ServicePrincipal.PasswordCredentials.SecretText)`n------------------------------------------------------------------" | Out-File -FilePath $ArcServerOnboardingDetailFile -Append
"ResourceGroup: $resourceGroup`n------------------------------------------------------------------" | Out-File -FilePath $ArcServerOnboardingDetailFile -Append
"TenantId: $tenantId`n------------------------------------------------------------------" | Out-File -FilePath $ArcServerOnboardingDetailFile -Append
"SubscriptionId: $subscriptionId`n------------------------------------------------------------------" | Out-File -FilePath $ArcServerOnboardingDetailFile -Append
"Location: $location`n------------------------------------------------------------------" | Out-File -FilePath $ArcServerOnboardingDetailFile -Append

Write-Host -ForegroundColor Yellow "`nThe AppId and Secret have been saved to $ArcServerOnboardingDetailFile"
Write-Host