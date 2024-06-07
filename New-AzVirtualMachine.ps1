Clear-Host

Set-Item Env:\SuppressAzurePowerShellBreakingChangeWarnings "true"
#Connect to Azure
Connect-AzAccount -WarningAction SilentlyContinue | Out-Null

Write-Host "        ********************************************************************************" -ForegroundColor Red
Write-Host "         *******************     CREATE AZURE VIRTUAL MACHINES      *******************" -ForegroundColor Cyan
Write-Host "         ******************************************************************************" -ForegroundColor Red
Write-Host "         **                                                                          **" -ForegroundColor Cyan
Write-Host "         **     1. Configure settings for virtual machines                           **" -ForegroundColor Cyan
Write-Host "         **     2. Create Windows Server virtual machines                            **" -ForegroundColor Cyan
Write-Host "         **     3. Create Windows Client virtual machines                            **" -ForegroundColor Cyan
Write-Host "         **     4. Create Linux Server virtual machines                              **" -ForegroundColor Cyan
Write-Host "         **                                                                          **" -ForegroundColor Cyan
Write-Host "         **                                                                          **" -ForegroundColor Cyan
Write-Host "         ******************************************************************************" -ForegroundColor Red
Write-Host "        ********************************************************************************" -ForegroundColor Red
Write-Host

$sw = [Diagnostics.Stopwatch]::StartNew()

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
Write-Host
Write-Host -ForegroundColor Cyan "Subscription name: `"$((Get-AzSubscription | Where-Object {$_.Name -like "*$subName*"}).Name)`" will be use for your VMs deployment" 
Set-AzContext -SubscriptionId (Get-AzSubscription | Where-Object { $_.Name -like "*$subName*" }).Id | Out-Null


Write-Verbose "Getting available resource groups in $subName subscription"
$azRGs = @()
$azRGs += Get-AzVM | Select-Object -ExpandProperty ResourceGroupName -Unique

Write-Host -ForegroundColor Green "`nFor the $subName susbscription, the new virtual machines (s) can be deployed in the following available resource groups(s):"
$rgNumbers = @()
for ($i = 0; $i -lt $azRGs.Count; $i++) {
    "$($i+1). $($azRGs[$i])"
    $rgNumbers += $i + 1
}
Write-Host "$($azRGs.Count +1). New resource group"
$rgNumbers += $azRGs.Count + 1
Write-Host

$selectedRG = Read-Host "Select a resource group for your deployment"
while ($selectedRG -notin $rgNumbers) {
    Write-Host "Enter a correct resource group number. The number must be between 1 and $($azRGs.Count + 1)" -ForegroundColor Yellow
    $selectedRG = Read-Host "Select a resource group for your deployment"
}

Write-Host "################## Creating virtual machines ###################" -ForegroundColor Green
Write-Host

$azureVMs = @("Windows Servers VMs", "Windows Client VMs", "Linux VMs")
[int[]]$vmCount = @()
foreach ($azureVM in $azureVMs) {
    do {
        $count = Read-Host "Number of $azureVM to create"
        if ($count -notmatch "^[0-3]{1,1}$") {
            Write-Host "You can create up to three (3) $($azureVM) VMs; enter a number between 0 and 3" -ForegroundColor Yellow
        }

    } while ($count -notmatch "^[0-3]{1,1}$")
    $vmCount += $count
}

if ($vmCount[0] -ne 0 -or $vmCount[1] -ne 0) {
    $cred = Get-Credential -Message "Admin logon name for Windows VM"
    Write-Host
}

if ($vmCount[2] -ne 0) {
    $user = Read-Host "Admin logon name for Linux VM"
    Write-Host
    ssh-keygen -m PEM -t rsa -b 4096
    Write-Host
}

if ($vmCount[0] -eq 0 -and $vmCount[1] -eq 0 -and $vmCount[2] -eq 0) {
    Write-Host -ForegroundColor Yellow "No virtual machines to create, goodbye!"
    exit
}

if ($selectedRG -eq ($azRGs.Count + 1)) {
    $resourceGroup = Read-Host "Provide a name for your new resource group"
    while ($resourceGroup -eq "") {
        Write-Host "You must enter a name for your new resource group" -ForegroundColor Yellow
        $resourceGroup = Read-Host "Provide a name for your new resource group" 
    }
    $resourceGroup = $resourceGroup + (Get-Random -Minimum 10000 -Maximum 99999) + "-RG"
    $location = Read-Host "Provide a location for your deployment (e.g. West US, East US, etc.)"
    $locations = @("eastus", "eastus2", "westus", "westus2", "east us", "east us 2", "west us", "west us 2")
    while ($locations -notcontains $location.ToLower()) {
        Write-Host "You must enter a valid location" -ForegroundColor Yellow
        $location = Read-Host "Provide a location for your deployment (e.g. West US, East US, etc.)"
    }
    # COMMON SETTINGS
    Write-Host -ForegroundColor Yellow "`nAll resources will be created in the following resource group: `"$resourceGroup`" in the `"$location`" region"
    Write-Host
    Write-Host "`n####### Configuration settings for Windows and Linux VMs ########" -ForegroundColor Green
    Write-Host

    #Create a resourcegroup
    Write-Host "Creating a resource group" -ForegroundColor Cyan
    New-AzResourceGroup -Name $resourceGroup -Location $location | Out-Null

    # Create an inbound network security group rule for port 80
    Write-Host "Creating an inbound network security group rule for port 80" -ForegroundColor Cyan
    $nsgRuleWeb = New-AzNetworkSecurityRuleConfig -Name HTTPNetworkSecurityGroupRule  -Protocol Tcp `
        -Direction Inbound -Priority 1001 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * `
        -DestinationPortRange 80 -Access Allow
    # Create an inbound network security group rule for port 443
    Write-Host "Creating an inbound network security group rule for port 443" -ForegroundColor Cyan
    $nsgRuleWebSecure = New-AzNetworkSecurityRuleConfig -Name HTTPSNetworkSecurityGroupRule  -Protocol Tcp `
        -Direction Inbound -Priority 1002 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * `
        -DestinationPortRange 443 -Access Allow
    # Create a network security group
    Write-Host "Creating a network security group" -ForegroundColor Cyan
    $nsg = New-AzNetworkSecurityGroup -ResourceGroupName $resourceGroup -Location $location `
        -Name "LabNetworkSecurityGroup" -SecurityRules $nsgRuleWeb, $nsgRuleWebSecure

    # Create a subnet configuration
    Write-Host "Creating a subnet configuration" -ForegroundColor Cyan
    $subnetConfig = New-AzVirtualNetworkSubnetConfig -Name LabSubnet -AddressPrefix 10.0.1.0/24 -NetworkSecurityGroupId $nsg.Id -WarningAction SilentlyContinue

    # Create a virtual network
    Write-Host "Creating a virtual network" -ForegroundColor Cyan
    $vnet = New-AzVirtualNetwork -ResourceGroupName $resourceGroup -Location $location `
        -Name LabVnet -AddressPrefix 10.0.0.0/16 -Subnet $subnetConfig -DnsServer 10.0.1.4
    Write-Host
}
else {
    $resourceGroup = $azRGs[$selectedRG - 1]
    $location = (Get-AzResourceGroup -Name $resourceGroup).Location
    $vnet = Get-AzVirtualNetwork -ResourceGroupName $resourceGroup
    Write-Host -ForegroundColor Yellow "`nAll resources will be created in the following resource group: `"$resourceGroup`" in the `"$location`" region"
}

# WINDOWS SERVERS VIRTUAL MACHINES
if ($vmCount[0] -ne 0) {
    Write-Host "`nCreating Windows Server vitual machine(s)" -ForegroundColor Green
    for ($i = 0; $i -lt $vmCount[0]; $i++) {
        $server = ("AZ-WSRV" + $(Get-Random -Minimum 1000 -Maximum 10000)).ToUpper() # + ([char]($i + 97))).ToUpper()
        $privateIP = "10.0.1." + ($i + 4)

        #$ServerPIP = $server + "PublicIP"
        $pip = New-AzPublicIpAddress -ResourceGroupName $resourceGroup -Location $location `
            -AllocationMethod Static -IdleTimeoutInMinutes 4 -Name $Server"-PIP" -WarningAction SilentlyContinue
    
        # Create a virtual network card and associate with public IP address and NSG
        $nic = New-AzNetworkInterface -Name $server"Nic" -ResourceGroupName $resourceGroup -Location $location `
            -SubnetId $vnet.Subnets[0].Id -PublicIpAddressId $pip.Id `
            -PrivateIpAddress $privateIP -DnsServer 10.0.1.4, 8.8.8.8
        $nic.IpConfigurations[0].PrivateIpAllocationMethod = 'Static'

        # Create a virtual machine configuration
        $OSDiskName = $server + "OsDisk"
        $OSDiskCaching = "ReadWrite"
        $OSCreateOption = "FromImage"
        $serverVmConfig = New-AzVMConfig -VMName $server -VMSize Standard_D2S_v5 | `
            Set-AzVMOperatingSystem -Windows -ComputerName $server -Credential $cred | `
            Set-AzVMSourceImage -PublisherName MicrosoftWindowsServer -Offer WindowsServer `
            -Skus "2022-Datacenter" -Version latest | Add-AzVMNetworkInterface -Id $nic.Id
        $serverVmConfig = Set-AzVMOSDisk -VM $serverVmConfig -Name $OSDiskName -Caching $OSDiskCaching -CreateOption $OSCreateOption -Windows
        Write-Host "Creating a virtual machine: $server" -ForegroundColor Cyan
        New-AzVM -ResourceGroupName $resourceGroup -Location $location -VM $serverVmConfig -WarningAction SilentlyContinue -AsJob | Out-Null
    }
}
Write-Host

# WINDOWS CLIENT VIRTUAL MACHINES
if ($vmCount[1] -ne 0) {
    Write-Host "Creating Windows client vitual machine(s)" -ForegroundColor Green
    for ($i = 1; $i -le $vmCount[1]; $i++) {
        $pc = ("AZ-WCLT" + $(Get-Random -Minimum 1000 -Maximum 10000)).ToUpper() # + ([char]($i + 96))).ToUpper()

        #Create a public IP address in an availability zone and specify a DNS name
        $pip = New-AzPublicIpAddress -ResourceGroupName $resourceGroup -Location $location `
            -AllocationMethod Static -IdleTimeoutInMinutes 4 -Name $pc"-PIP" -WarningAction SilentlyContinue
    
        # Create a virtual network card and associate with public IP address and NSG
        $nic = New-AzNetworkInterface -Name $pc"Nic" -ResourceGroupName $resourceGroup -Location $location `
            -SubnetId $vnet.Subnets[0].Id -PublicIpAddressId $pip.Id -DnsServer 10.0.1.4, 8.8.8.8

        # Create a virtual machine configuration
        $OSDiskName = $pc + "OsDisk"
        $OSDiskCaching = "ReadWrite"
        $OSCreateOption = "FromImage"
        $pcVmConfig = New-AzVMConfig -VMName $pc -VMSize Standard_D2s_v5 | `
            Set-AzVMOperatingSystem -Windows -ComputerName $pc -Credential $cred | `
            Set-AzVMSourceImage -PublisherName MicrosoftWindowsDesktop -Offer "windows-11" `
            -Skus "win11-21h2-ent" -Version Latest | Add-AzVMNetworkInterface -Id $nic.Id
        $pcVmConfig = Set-AzVMOSDisk -VM $pcVmConfig -Name $OSDiskName -Caching $OSDiskCaching -CreateOption $OSCreateOption -Windows
        Write-Host "Creating a virtual machine: $pc" -ForegroundColor Cyan
        New-AzVM -ResourceGroupName $resourceGroup -Location $location -VM $pcVmConfig -WarningAction SilentlyContinue -AsJob | Out-Null
    }
}
Write-Host

# LINUX VIRTUAL MACHINES
Write-Host "Creating Linux vitual machine(s)" -ForegroundColor Green

if ($vmCount[2] -ne 0) {
    for ($i = 1; $i -le $vmCount[2]; $i++) {
        $vmName = ("AZ-LSRV" + $(Get-Random -Minimum 1000 -Maximum 10000)).ToUpper() # + ([char]($i + 96))).ToUpper()
        # $vmName = "AZ-LINUX" #+ ([char]($i + 96))
        # Create a public IP address and specify a DNS name
        $linuxVMPIP = New-AzPublicIpAddress `
            -ResourceGroupName $resourceGroup `
            -Location $location `
            -AllocationMethod Static `
            -IdleTimeoutInMinutes 4 `
            -Name "$vmName-PIP" -WarningAction SilentlyContinue

        # Create a virtual network card and associate with public IP address and NSG
        $linuxVMNic = New-AzNetworkInterface `
            -Name "$vmName-NIC" `
            -ResourceGroupName $resourceGroup `
            -Location $location `
            -SubnetId $vnet.Subnets[0].Id `
            -PublicIpAddressId $linuxVMPIP.Id `
            -DnsServer 10.0.1.4, 8.8.8.8

        # Define a credential object
        $securePassword = ConvertTo-SecureString ' ' -AsPlainText -Force
        $cred = New-Object System.Management.Automation.PSCredential ($user, $securePassword)

        # Create a virtual machine configuration
        $LinuxVMConfig = New-AzVMConfig `
            -VMName $vmName `
            -VMSize "Standard_D2S_v5" | `
            Set-AzVMOperatingSystem `
            -Linux `
            -ComputerName $vmName `
            -Credential $cred `
            -DisablePasswordAuthentication | `
            Set-AzVMSourceImage `
            -PublisherName "Canonical" `
            -Offer "0001-com-ubuntu-server-jammy" `
            -Skus "22_04-lts-gen2" `
            -Version "latest" | `
            Add-AzVMNetworkInterface `
            -Id $linuxVMNic.Id
  
        $OSDiskName = $vmName + "-OsDisk"
        $OSDiskCaching = "ReadWrite"
        $OSCreateOption = "FromImage"
        $LinuxVMConfig = Set-AzVMOSDisk -VM $LinuxVMConfig -Name $OSDiskName -Caching $OSDiskCaching -CreateOption $OSCreateOption -Linux
        
        #Configure the SSH key
        $sshPublicKey = Get-Content ~/.ssh/id_rsa.pub
        Add-AzVMSshPublicKey `
            -VM $linuxVMConfig `
            -KeyData $sshPublicKey `
            -Path "/home/$user/.ssh/authorized_keys" | Out-Null
        
        Write-Host "Creating a virtual machine: $vmName" -ForegroundColor Cyan
        New-AzVM -ResourceGroupName $resourceGroup -Location $location -VM $linuxVMConfig -WarningAction SilentlyContinue -AsJob | Out-Null
    }
}


if ($vmCount[0] -eq 0 -and $vmCount[1] -eq 0 -and $vmCount[2] -eq 0) {
    Write-Host -ForegroundColor Yellow "No virtual machines to create, goodbye!"
}
else {
    Write-Host
    Write-Host
    Write-Host "Virtual machines successfully submitted for creation." -ForegroundColor Green

    $sw.Stop()
    $time = $sw.Elapsed.Hours.ToString() + " hour(s) - "
    $time += $sw.Elapsed.Minutes.ToString() + " minute(s) - "
    $time += $sw.Elapsed.Seconds.ToString() + " second(s)"
    Write-Host "Time elapsed: $time"

    #Getting public IP address
    Write-Host
    Write-Host
    Write-Host
    Write-Host "Getting public IP address for remote connection" -ForegroundColor Cyan
    Get-AzPublicIpAddress -ResourceGroupName $resourceGroup | Select-Object Name, IPAddress | Format-Table

    Write-Host
    Write-Host
    Write-Host "You can now connect to your deployed virtual machines, but before you do, enable just-in-time access." -ForegroundColor Green
    Write-Host "No management port (SSH - TCP port 22 or RDP - TCP port 3389) is currently opened!" -ForegroundColor Green
    Write-Host "Connect to VMs" -ForegroundColor Green
    Write-Host "Windows VM: mstsc /v:PublicIPAddress" -ForegroundColor Cyan
    Write-Host "Linux VM: ssh user@PublicIPAddress" -ForegroundColor Cyan
    Write-Host
    Write-Host
}
