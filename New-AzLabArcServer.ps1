# https://learn.microsoft.com/en-us/azure/azure-arc/servers/onboard-group-policy-powershell
# Run the script in PowerShell as administrator
function New-AzLabArcServer {

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
    Write-Host "Creating a resource group" -ForegroundColor Yellow
    New-AzResourceGroup -Name $resourceGroup -Location $location | Out-Null

    # 4. Create a remote share
    Write-Host "Creating a remote share" -ForegroundColor Yellow
    $DomainName = (Get-ADDomain).DNSRoot
    $path = "$env:HOMEDRIVE\AzureArc"
    If (!(Test-Path -PathType container $path)) {
        New-Item -Path $path -ItemType Directory | Out-Null
        $parameters = @{
            Name         = "AzureArc"
            Path         = "$($path)"
            FullAccess   = "$env:USERDOMAIN\$env:USERNAME", "$DomainName\Domain Admins"
            ChangeAccess = "$DomainName\Domain Users", "$DomainName\Domain Computers", "$DomainName\Domain Controllers"
        }
        New-SmbShare @parameters | Out-Null
    }
    $RemoteShare = (Get-SmbShare | Where-Object { $_.Name -eq "AzureArc" }).Name


    Write-Host "Downloading the Azure Connected Machine Agent and the Arc enabled servers group policy" -ForegroundColor Yellow
    Invoke-WebRequest -Uri "https://aka.ms/AzureConnectedMachineAgent" -OutFile "$path\AzureConnectedMachineAgent.msi"
    Invoke-WebRequest -Uri "https://github.com/Azure/ArcEnabledServersGroupPolicy/releases/download/1.0.5/ArcEnabledServersGroupPolicy_v1.0.5.zip" -OutFile "$path\ArcEnabledServersGroupPolicy_v1.0.5.zip"

    Write-Host "Extracting the Arc enabled servers group policy from the archive file" -ForegroundColor Yellow
    Expand-Archive -LiteralPath "$($path)\ArcEnabledServersGroupPolicy_v1.0.5.zip" -DestinationPath $path
    Set-Location -Path "$($path)\ArcEnabledServersGroupPolicy_v1.0.5"

    $date = Get-Date
    Write-Host "Creating a service principal" -ForegroundColor Yellow
    $ArcServerOnboardingDetail = New-Item -ItemType File -Path "$path\ArcServerOnboarding.txt"
    "------------------------------------------------------------------------------" | Out-File -FilePath $ArcServerOnboardingDetail -Append
    "`nService principal creation date: $date`nSecret expiration date: $($date.AddDays(7))" | Out-File -FilePath $ArcServerOnboardingDetail -Append
    $ServicePrincipal = New-AzADServicePrincipal -EndDate $date.AddDays(7) -DisplayName "Arc Server Onboarding Account - Windows" -Role "Azure Connected Machine Onboarding" -Scope "/subscriptions/$subId/resourceGroups/$resourceGroup"
    $ServicePrincipal | Format-Table AppId, @{ Name = "Secret"; Expression = { $_.PasswordCredentials.SecretText } } | Out-File -FilePath $ArcServerOnboardingDetail -Append
    "`n------------------------------------------------------------------------------" | Out-File -FilePath $ArcServerOnboardingDetail -Append
    $AppId = $ServicePrincipal.AppId
    $Secret = $ServicePrincipal.PasswordCredentials.SecretText

    $DC = Get-ADDomainController
    $DomainFQDN = $DC.Domain
    $ReportServerFQDN = $DC.HostName
    $TenantId = $subs[$subRank - 1].TenantId

    .\DeployGPO.ps1 -DomainFQDN $DomainFQDN `
        -ReportServerFQDN $ReportServerFQDN `
        -ArcRemoteShare $RemoteShare `
        -ServicePrincipalSecret $Secret `
        -ServicePrincipalClientId $AppId `
        -SubscriptionId $subId `
        -ResourceGroup $resourceGroup `
        -Location $Location `
        -TenantId $TenantId


    #$OUs = (Get-ADOrganizationalUnit -Filter 'Name -eq "Arc Servers" -Or Name -eq "Domain Controllers"').DistinguishedName
    #$OUs = (Get-ADOrganizationalUnit -Filter 'Name -eq "OU1" -Or Name -eq "OU2"').DistinguishedName
    #$OUs = @
    $GPOName = (Get-GPO -All -Domain $DomainFQDN | Where-Object { $_.DisplayName -Like "*MSFT*" }).DisplayName  
    Write-Host "`nLinking the GPO to the $OUs Organizational Unit" -ForegroundColor Yellow
    foreach ($OU in $OUs) {
        New-GPLink -Name "$GPOName" -Target "$OU" -LinkEnabled Yes | Out-Null
    }

    Write-Host -ForegroundColor Yellow "The AppId and Secret have been saved to $ArcServerOnboardingDetail"
    Write-Host
}
New-AzLabArcServer


#region OU selection
Clear-Host
Write-Host "Getting the list of organizational units in the domain..." -ForegroundColor Yellow
$OUs = @()
$arcServerOUs = @()
$OUs += Get-ADOrganizationalUnit -Filter *

$OUs | Format-Table Name, DistinguishedName -AutoSize

$adDomain = (Get-ADDomain).DNSRoot
if ($OUs.Count -eq 0) {
    Write-Host "No organizational units found. Exiting..." -ForegroundColor Yellow
    break
}
else {
    Write-Host -ForegroundColor Green "`nList of organizational units in the domain '$adDomain'"
    $ouNumbers = @()
    for ($i = 0; $i -lt $OUs.Count; $i++) {
        "$($i+1). $($OUs[$i])"
        $ouNumbers += $i + 1
    }
}

do {
    $ouNumber = Read-Host "`nSelect an organizational unit, e.g. 1, 2, 3, etc."
    while ($ouNumber -notin $ouNumbers) {
        Write-Host "Enter a correct number. The number must be between 1 and $($ouNumbers.Count)" -ForegroundColor Yellow
        $ouNumber = Read-Host "Select an organizational unit, e.g. 1, 2, 3, etc."
    }
    $arcServerOUs += $OUs[$ouNumber]
    
    # $arcServerOUs += $arcServerOUs
    #$arcServerOUs | Format-Table Name, DistinguishedName -AutoSize

    # TODO: cycle though and remove the OU the selected from the list
    $OUs = $OUs | Where-Object { $_.DistinguishedName -ne $OU.DistinguishedName }
    # Clear-Host
    Write-Host "`nRemainng organizational units in the domain '$adDomain' to select from." -ForegroundColor Yellow
    $OUs | Format-Table Name, DistinguishedName -AutoSize
    $choice = Read-Host "Would you like to select another organizational unit to link the GPO to (Yes=Y / No=N)?"
    $choice = $choice.Trim('o', 'e', 's').ToUpper()
    while ($choice -notin "Y", "N") {
        Write-Host "Enter a correct answer. The answer must be Y or N" -ForegroundColor Yellow
        $choice = Read-Host "Would you like to select another organizational unit to link the GPO to (Yes=Y / No=N)?"
    }
    if ($choice -eq "N") {
        Write-Host $arcServerOUs | Format-Table Name, DistinguishedName -AutoSize
    }
    else {
        continue
    }
} while ($choice -eq "Y")

# TODO: create a function for user choice
# TODO: create a function for cycling though the list of OUs
function Get-UserChoice {
    param (
        [string]$Message,
        [string]$Prompt
    )
    Write-Host $Message -ForegroundColor Yellow
    $choice = Read-Host $Prompt
    return $choice
}

function Get-OU {
    param (
        [string]$Message,
        [string]$Prompt
    )
    Write-Host $Message -ForegroundColor Yellow
    $OUs = @()
    $OUs += Get-ADOrganizationalUnit -Filter *
    $OUs | Format-Table Name, DistinguishedName -AutoSize
    $ouNumbers = @()
    for ($i = 0; $i -lt $OUs.Count; $i++) {
        "$($i+1). $($OUs[$i])"
        $ouNumbers += $i + 1
    }
    $ouNumber = Read-Host $Prompt
    while ($ouNumber -notin $ouNumbers) {
        Write-Host "Enter a correct number. The number must be between 1 and $($ouNumbers.Count)" -ForegroundColor Yellow
        $ouNumber = Read-Host $Prompt
    }
    return $OUs[$ouNumber - 1]
}
#endregion