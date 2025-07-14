# ==============================================================================
# AZURE ARC & MICROSOFT DEFENDER FOR ENDPOINT PREREQUISITES CHECKER
# ==============================================================================
#
# SCRIPT DESCRIPTION:
# This script performs comprehensive prerequisites validation for Azure Arc 
# onboarding and Microsoft Defender for Endpoint (MDE) integration across 
# multiple devices in your environment.
#
# WHAT THIS SCRIPT DOES:
# • Reads a list of device names from a user-specified file
# • Connects to each device remotely (or checks locally if it's the current machine)
# • Performs the following checks on each device:
#   - PowerShell version compatibility (requires 5.0+)
#   - Azure PowerShell (Az) module availability
#   - Azure Arc Connected Machine Agent installation status
#   - Network connectivity to Azure management endpoints
#   - PowerShell execution policy configuration
#   - Microsoft Defender for Endpoint service status
#   - MDE extension installation status
#   - Operating system version compatibility
# • Authenticates to Azure (once) and validates resource provider registrations
# • Offers to register unregistered Azure resource providers during execution
# • Generates detailed logs for each device
# • Provides a comprehensive summary with actionable remediation guidance
#
# REQUIREMENTS:
# • PowerShell 5.1 or later on the machine running this script
# • Administrative privileges recommended
# • Network access to target devices (for remote checks)
# • WinRM enabled on target devices (for remote PowerShell)
# • Internet connectivity for Azure authentication and endpoint testing
#
# WHAT DATA IS COLLECTED:
# • Device connectivity status
# • Software installation status (PowerShell, Azure modules, Arc agent, MDE)
# • Network connectivity test results
# • Operating system version information
# • Service status information
# • Azure authentication and subscription details
#
# DATA HANDLING:
# • All data is processed locally on your machine
# • Log files are created locally (AzureArc_MDE_Checks_<DeviceName>.log)
# • Azure credentials are handled by the official Azure PowerShell module
# • No data is transmitted to third parties
#
# ACTIONS PERFORMED:
# • Read-only checks on remote devices (no system modifications)
# • Azure authentication (requires user consent)
# • Network connectivity tests
# • File and service existence checks
# • May automatically install Azure PowerShell module if missing (with user notification)
# • May register Azure resource providers if user consents (requires appropriate permissions)
#
# IMPORTANT NOTES:
# • This script does NOT make changes to target devices
# • This script does NOT install software on target devices
# • Azure login will open a browser window for authentication
# • Remote PowerShell sessions will be established to target devices
# • Script execution may take several minutes depending on device count
#
# ==============================================================================

Clear-Host

# User Consent and Confirmation
Write-Host "╔════════════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║                    AZURE ARC & MDE PREREQUISITES CHECKER                       ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""
Write-Host "🔍 SCRIPT OVERVIEW:" -ForegroundColor Yellow
Write-Host "   This script will check prerequisites for Azure Arc and Microsoft Defender" -ForegroundColor White
Write-Host "   for Endpoint across multiple devices in your environment." -ForegroundColor White
Write-Host ""
Write-Host "📋 ACTIONS TO BE PERFORMED:" -ForegroundColor Yellow
Write-Host "   • Connect to devices specified in your device list file" -ForegroundColor White
Write-Host "   • Check software prerequisites (PowerShell, Azure modules, Arc agent)" -ForegroundColor White
Write-Host "   • Test network connectivity to Azure endpoints" -ForegroundColor White
Write-Host "   • Validate Microsoft Defender for Endpoint configuration" -ForegroundColor White
Write-Host "   • Authenticate to Azure (will open browser for login)" -ForegroundColor White
Write-Host "   • Check Azure resource provider registrations (with option to register)" -ForegroundColor White
Write-Host "   • Generate detailed reports and remediation guidance" -ForegroundColor White
Write-Host ""
Write-Host "⚠️  IMPORTANT CONSIDERATIONS:" -ForegroundColor Red
Write-Host "   • Remote PowerShell sessions will be established to target devices" -ForegroundColor White
Write-Host "   • Azure authentication will be required (browser-based login)" -ForegroundColor White
Write-Host "   • Script may install Azure PowerShell module if missing" -ForegroundColor White
Write-Host "   • Log files will be created on this local machine" -ForegroundColor White
Write-Host "   • No modifications will be made to target devices" -ForegroundColor White
Write-Host ""
Write-Host "🛡️  DATA & PRIVACY:" -ForegroundColor Green
Write-Host "   • All data processing occurs locally on your machine" -ForegroundColor White
Write-Host "   • No data is transmitted to third parties" -ForegroundColor White
Write-Host "   • Azure credentials are handled by official Microsoft modules" -ForegroundColor White
Write-Host ""
Write-Host "⚖️  DISCLAIMER & LIABILITY:" -ForegroundColor Magenta
Write-Host "   • This script is provided 'AS IS' without warranty of any kind" -ForegroundColor White
Write-Host "   • The author is not liable for any damages, data loss, or other" -ForegroundColor White
Write-Host "     consequences that may result from running this script" -ForegroundColor White
Write-Host "   • You assume full responsibility for testing and validating" -ForegroundColor White
Write-Host "     this script in your environment before production use" -ForegroundColor White
Write-Host "   • Use at your own risk and discretion" -ForegroundColor White
Write-Host ""


do {
    Write-Host "══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    $consent = Read-Host "Do you consent to proceed with this prerequisites check? (Y/N)"
    Write-Host "══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan

    switch ($consent.ToUpper()) {
        'Y' { 
            Write-Host "✅ Proceeding with prerequisites check..." -ForegroundColor Green
            break 
        }
        'N' { 
            Write-Host "`n❌ Script execution cancelled by user." -ForegroundColor Red
            Write-Host "No actions have been performed. Exiting...`n" -ForegroundColor Gray
            exit 0 
        }
        default { 
            Write-Host "Please enter 'Y' to proceed or 'N' to cancel." -ForegroundColor Yellow 
        }
    }
} while ($consent.ToUpper() -ne 'Y' -and $consent.ToUpper() -ne 'N')

Write-Host ""
Write-Host "🚀 Initializing Azure Arc & MDE Prerequisites Checker..." -ForegroundColor Cyan
Write-Host ""

<#
.SYNOPSIS
    Checks prerequisites for Azure Arc onboarding and Microsoft Defender for Endpoint (MDE) integration for multiple devices.

.DESCRIPTION
    This script performs the following checks for each device listed in a user-specified file:
    - PowerShell version
    - Az module presence and automatic installation
    - Azure login (local machine only)
    - Azure Arc agent installation
    - Network connectivity to Azure
    - Execution policy
    - MDE service and extension
    - OS version compatibility
    - Azure Resource Provider registration (once after successful Azure login)

.NOTES
    Author: Copilot
    Date: 2025-07-13
    Log File: AzureArc_MDE_Checks_<DeviceName>.log
    Device List: User-specified file path
#>

$allResults = @{}
$azureLoginCompleted = $false
$resourceProvidersChecked = $false
$resourceProvidersRegistered = $false
$unregisteredProviders = @()
$deviceOSVersions = @{}

function Test-Prerequisites {
    param (
        [string]$DeviceName,
        [string]$Check,
        [string]$Result,
        [string]$Details,
        [string]$LogFile
    )
    $entry = [PSCustomObject]@{
        Device    = $DeviceName
        Check     = $Check
        Result    = $Result
        Details   = $Details
    }
    if (-not $script:allResults[$DeviceName]) {
        $script:allResults[$DeviceName] = @()
    }
    $script:allResults[$DeviceName] += $entry
    "$Check`t$Result`t$Details" | Out-File -FilePath $LogFile -Append
    
    # Provide immediate feedback with color coding
    $color = switch ($Result) {
        "OK" { "Green" }
        "Warning" { "Yellow" }
        "Error" { "Red" }
        "Info" { "Cyan" }
        default { "White" }
    }
    Write-Host "    [$Result] $Check - $Details" -ForegroundColor $color
}

function Write-Step {
    param([string]$Message, [string]$DeviceName = "")
    if ($DeviceName) {
        Write-Host "`n🔍 [$DeviceName] $Message..." -ForegroundColor Cyan
    } else {
        Write-Host "`n🔍 $Message..." -ForegroundColor Cyan
    }
}

function Write-ProgressStep {
    param([string]$Activity, [int]$Step, [int]$Total)
    # Guard against division by zero and invalid values
    if ($Total -le 0) {
        Write-Progress -Activity $Activity -Status "Initializing..." -PercentComplete 0
        return
    }
    
    # Ensure step doesn't exceed total and is not negative
    $adjustedStep = [Math]::Max(0, [Math]::Min($Step, $Total))
    $percent = [math]::Round(($adjustedStep / $Total) * 100)
    Write-Progress -Activity $Activity -Status "Step $adjustedStep of $Total" -PercentComplete $percent
}

function Test-DeviceConnectivity {
    param([string]$DeviceName)
    try {
        $result = Test-Connection -ComputerName $DeviceName -Count 1 -Quiet -ErrorAction SilentlyContinue
        return $result
    } catch {
        return $false
    }
}

function Get-DeviceOSVersion {
    param([string]$DeviceName, [System.Management.Automation.Runspaces.PSSession]$Session = $null)
    try {
        if ($Session) {
            $osVersion = Invoke-Command -Session $Session -ScriptBlock { 
                (Get-CimInstance Win32_OperatingSystem).Caption 
            }
        } else {
            $osVersion = (Get-CimInstance Win32_OperatingSystem).Caption
        }
        
        # Extract a shorter version for display while preserving key identifiers
        $shortVersion = $osVersion
        
        # Handle Windows Server versions - preserve "Windows Server"
        if ($osVersion -match "Microsoft Windows Server (\d{4})") {
            $year = $matches[1]
            $shortVersion = "Windows Server $year"
        }
        # Handle Windows 11 client versions - preserve "Windows 11"
        elseif ($osVersion -match "Microsoft Windows 11") {
            $shortVersion = "Windows 11"
        }
        # Handle Windows 10 client versions - preserve "Windows 10"
        elseif ($osVersion -match "Microsoft Windows 10") {
            $shortVersion = "Windows 10"
        }
        # Handle other Windows versions - remove Microsoft prefix but keep Windows
        else {
            $shortVersion = $osVersion -replace "Microsoft ", "" -replace " Standard", "" -replace " Datacenter", "" -replace " Enterprise", "" -replace " Pro", "" -replace " Essentials", ""
        }
        
        return $shortVersion
    } catch {
        return "Unknown OS"
    }
}

function Install-AzModule {
    Write-Host "`n🔽 Installing Az PowerShell module..." -ForegroundColor Yellow
    try {
        # Check if running as administrator
        $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
        
        if ($isAdmin) {
            Install-Module -Name Az -Repository PSGallery -Force -AllowClobber -Scope AllUsers
            Write-Host "✅ Az module installed successfully for all users" -ForegroundColor Green
        } else {
            Install-Module -Name Az -Repository PSGallery -Force -AllowClobber -Scope CurrentUser
            Write-Host "✅ Az module installed successfully for current user" -ForegroundColor Green
        }
        return $true
    } catch {
        Write-Host "❌ Failed to install Az module: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Test-AzureLogin {
    Write-Step "Checking and performing Azure authentication"
    
    # Suppress warnings globally for Azure operations
    $OriginalWarningPreference = $WarningPreference
    $WarningPreference = 'SilentlyContinue'
    
    try {
        # Check if Az module is available
        $azModule = Get-Module -ListAvailable -Name Az
        if (-not $azModule) {
            Write-Host "    Az module not found. Attempting installation..." -ForegroundColor Yellow
            $installSuccess = Install-AzModule
            if (-not $installSuccess) {
                Write-Host "    ❌ Cannot proceed without Az module" -ForegroundColor Red
                return $false
            }
            # Re-check after installation
            $azModule = Get-Module -ListAvailable -Name Az
        }
        
        Write-Host "    ✅ Az module is available" -ForegroundColor Green
        
        # Check current Azure context
        try {
            $context = Get-AzContext -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
            if ($context) {
                Write-Host "    ✅ Already logged in to Azure as $($context.Account.Id)" -ForegroundColor Green
                Write-Host "    📋 Subscription: $($context.Subscription.Name)" -ForegroundColor Gray
                $script:azureLoginCompleted = $true
                return $true
            } else {
                Write-Host "    🔑 Not logged in to Azure. Initiating login..." -ForegroundColor Yellow
                
                # Suppress all Azure PowerShell output streams during login
                $originalVerbosePreference = $VerbosePreference
                $originalInformationPreference = $InformationPreference
                $VerbosePreference = 'SilentlyContinue'
                $InformationPreference = 'SilentlyContinue'
                
                try {
                    # Attempt Azure login with all output suppressed
                    $loginResult = Connect-AzAccount -ErrorAction SilentlyContinue -WarningAction SilentlyContinue -InformationAction SilentlyContinue -Verbose:$false
                } finally {
                    # Restore original preferences
                    $VerbosePreference = $originalVerbosePreference
                    $InformationPreference = $originalInformationPreference
                }
                if ($loginResult) {
                    $newContext = Get-AzContext -WarningAction SilentlyContinue
                    Write-Host "    ✅ Successfully logged in to Azure as $($newContext.Account.Id)" -ForegroundColor Green
                    Write-Host "    📋 Subscription: $($newContext.Subscription.Name)" -ForegroundColor Gray
                    $script:azureLoginCompleted = $true
                    return $true
                } else {
                    Write-Host "    ❌ Azure login failed" -ForegroundColor Red
                    return $false
                }
            }
        } catch {
            Write-Host "    ❌ Error during Azure authentication: $($_.Exception.Message)" -ForegroundColor Red
            return $false
        }
    }
    finally {
        # Restore original warning preference
        $WarningPreference = $OriginalWarningPreference
    }
}

function Register-AzureResourceProvider {
    param(
        [string]$ProviderNamespace
    )
    
    # Suppress warnings for registration operations
    $OriginalWarningPreference = $WarningPreference
    $WarningPreference = 'SilentlyContinue'
    
    try {
        Write-Host "    🔄 Registering $ProviderNamespace..." -ForegroundColor Yellow
        
        # Show initial progress
        Write-Progress -Activity "Registering $ProviderNamespace" -Status "Starting registration..." -PercentComplete 0
        
        try {
            Register-AzResourceProvider -ProviderNamespace $ProviderNamespace -ErrorAction Stop -WarningAction SilentlyContinue | Out-Null
        
        # Optimized wait for registration to complete (faster polling)
        $timeout = 90 # Reduced timeout
        $timer = 0
        $interval = 5  # Much faster polling interval
        $maxChecks = 18  # Allow more checks with faster interval
        $checkCount = 0
        
        # Initial quick check after 3 seconds (some providers register very quickly)
        Start-Sleep -Seconds 3
        $timer += 3
        Write-Progress -Activity "Registering $ProviderNamespace" -Status "Checking initial status..." -PercentComplete 10
        
        do {
            $checkCount++
            
            $provider = Get-AzResourceProvider -ProviderNamespace $ProviderNamespace -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
            $status = $provider.RegistrationState
            
            if ($status -eq "Registered") {
                # Complete progress and show success
                Write-Progress -Activity "Registering $ProviderNamespace" -Status "Registration completed!" -PercentComplete 100
                Start-Sleep -Seconds 1  # Brief pause to show completion
                Write-Progress -Activity "Registering $ProviderNamespace" -Completed
                Write-Host "    ✅ $ProviderNamespace : Successfully registered" -ForegroundColor Green
                $script:resourceProvidersRegistered = $true
                return $true
            } elseif ($status -eq "Registering") {
                # Show streamlined progress with enhanced status
                $percentComplete = [math]::Min(90, ($timer / $timeout) * 100)
                Write-Progress -Activity "Registering $ProviderNamespace" -Status "Registration in progress..." -PercentComplete $percentComplete
            } else {
                # Update progress with current status
                $percentComplete = [math]::Min(90, ($timer / $timeout) * 100)
                Write-Progress -Activity "Registering $ProviderNamespace" -Status "Status: $status" -PercentComplete $percentComplete
            }
            
            # Only sleep if we're continuing the loop
            if ($timer -lt $timeout -and $status -ne "Registered" -and $checkCount -lt $maxChecks) {
                Start-Sleep -Seconds $interval
                $timer += $interval
            }
            
        } while ($timer -lt $timeout -and $status -ne "Registered" -and $checkCount -lt $maxChecks)
        
        if ($status -ne "Registered") {
            # Complete progress and show final status
            Write-Progress -Activity "Registering $ProviderNamespace" -Completed
            Write-Host "    ⚠️  $ProviderNamespace : Registration pending (may complete in background)" -ForegroundColor Yellow
            Write-Host "      Registration often continues after script completion" -ForegroundColor Gray
            return $false
        }
        
        return $true
        
    } catch {
        Write-Progress -Activity "Registering $ProviderNamespace" -Completed
        Write-Host "    ❌ $ProviderNamespace : Registration failed - $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
    }
    finally {
        # Restore original warning preference
        $WarningPreference = $OriginalWarningPreference
    }
}

function Register-AzureResourceProvidersParallel {
    param(
        [string[]]$ProviderNamespaces
    )
    
    Write-Host "    🚀 Initiating parallel registration of $($ProviderNamespaces.Count) resource providers..." -ForegroundColor Cyan
    
    # Start all registrations simultaneously (fire-and-forget approach)
    foreach ($provider in $ProviderNamespaces) {
        try {
            Write-Host "    🔄 Starting registration: $provider" -ForegroundColor Yellow
            Register-AzResourceProvider -ProviderNamespace $provider -ErrorAction SilentlyContinue -WarningAction SilentlyContinue | Out-Null
        } catch {
            Write-Host "    ⚠️  Failed to start registration for $provider`: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
    
    Write-Host "    ⏱️  All registrations initiated. Monitoring progress (up to 60 seconds)..." -ForegroundColor Cyan
    
    # Monitor progress with optimized polling
    $timeout = 60  # Reduced overall timeout for parallel operations
    $interval = 3   # Very fast polling for parallel monitoring
    $timer = 0
    $completed = @()
    $lastStatusUpdate = 0
    $lastCompletedCount = 0  # Initialize this variable
    
    # Show initial progress bar
    Write-Progress -Activity "Registering Resource Providers" -Status "Initializing registration for $($ProviderNamespaces.Count) providers..." -PercentComplete 0
    
    # Give initial registrations a moment to start
    Start-Sleep -Seconds 2
    $timer += 2
    
    do {
        $timer += $interval
        
        # Check status of all providers
        $stillPending = @()
        foreach ($provider in $ProviderNamespaces) {
            if ($provider -notin $completed) {
                try {
                    $providerStatus = Get-AzResourceProvider -ProviderNamespace $provider -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
                    if ($providerStatus.RegistrationState -eq "Registered") {
                        $completed += $provider
                        Write-Host "    ✅ $provider : Registered" -ForegroundColor Green
                    } else {
                        $stillPending += $provider
                    }
                } catch {
                    $stillPending += $provider
                }
            }
        }
        
        # Update progress more frequently for better user experience
        if (($timer - $lastStatusUpdate) -ge 3 -or $completed.Count -ne $lastCompletedCount) {
            $percentComplete = [math]::Round(($completed.Count / $ProviderNamespaces.Count) * 100)
            $remaining = $ProviderNamespaces.Count - $completed.Count
            $statusMessage = if ($completed.Count -eq 0) {
                "Registration in progress... ($timer s elapsed)"
            } else {
                "$($completed.Count)/$($ProviderNamespaces.Count) completed, $remaining pending ($timer s elapsed)"
            }
            Write-Progress -Activity "Registering Resource Providers" -Status $statusMessage -PercentComplete $percentComplete
            $lastStatusUpdate = $timer
            $lastCompletedCount = $completed.Count
        }
        
        # Break if all are completed
        if ($completed.Count -eq $ProviderNamespaces.Count) {
            Write-Progress -Activity "Registering Resource Providers" -Status "All providers registered successfully!" -PercentComplete 100
            Start-Sleep -Seconds 1  # Brief pause to show completion
            break
        }
        
        Start-Sleep -Seconds $interval
        
    } while ($timer -lt $timeout)
    
    Write-Progress -Activity "Registering Resource Providers" -Completed
    
    # Final status report
    $successful = $completed.Count
    $pending = $ProviderNamespaces.Count - $successful
    
    if ($successful -eq $ProviderNamespaces.Count) {
        Write-Host "    ✅ All $successful resource providers registered successfully!" -ForegroundColor Green
        $script:resourceProvidersRegistered = $true
        return $true
    } elseif ($successful -gt 0) {
        Write-Host "    ⚠️  $successful/$($ProviderNamespaces.Count) providers registered, $pending still pending" -ForegroundColor Yellow
        Write-Host "    💡 Remaining registrations will continue in the background" -ForegroundColor Gray
        if ($pending -gt 0) {
            $stillPendingList = $ProviderNamespaces | Where-Object { $_ -notin $completed }
            Write-Host "    📋 Pending: $($stillPendingList -join ', ')" -ForegroundColor Gray
        }
        $script:resourceProvidersRegistered = $true
        return $false
    } else {
        Write-Host "    ❌ No providers completed registration within timeout period" -ForegroundColor Red
        Write-Host "    💡 Registrations may still be in progress. Check Azure portal" -ForegroundColor Gray
        return $false
    }
}

function Test-AzureResourceProviders {
    if (-not $script:azureLoginCompleted -or $script:resourceProvidersChecked) {
        return
    }
    
    # Suppress warnings for resource provider operations
    $OriginalWarningPreference = $WarningPreference
    $WarningPreference = 'SilentlyContinue'
    
    try {
        Write-Step "Checking Azure Resource Provider registrations"
        $providers = @(
            "Microsoft.HybridCompute",
            "Microsoft.GuestConfiguration", 
            "Microsoft.AzureArcData",
            "Microsoft.HybridConnectivity"
        )
        
        $unregisteredProviders = @()
        
        # Show progress while checking providers
        Write-Progress -Activity "Checking Resource Providers" -Status "Initializing..." -PercentComplete 0
        
        for ($i = 0; $i -lt $providers.Count; $i++) {
            $provider = $providers[$i]
            $percentComplete = [math]::Round((($i + 1) / $providers.Count) * 100)
            Write-Progress -Activity "Checking Resource Providers" -Status "Checking $provider... ($($i + 1)/$($providers.Count))" -PercentComplete $percentComplete
            
            try {
                $resourceProvider = Get-AzResourceProvider -ProviderNamespace $provider -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
                if ($resourceProvider) {
                    $status = $resourceProvider.RegistrationState
                    if ($status -eq "Registered") {
                        Write-Host "    ✅ $provider : Registered" -ForegroundColor Green
                    } else {
                        Write-Host "    ⚠️  $provider : Not registered" -ForegroundColor Yellow
                        $unregisteredProviders += $provider
                    }
                } else {
                    Write-Host "    ❌ $provider : Provider not found" -ForegroundColor Red
                    $unregisteredProviders += $provider
                }
            } catch {
                Write-Host "    ❌ $provider : Error checking registration - $($_.Exception.Message)" -ForegroundColor Red
                $unregisteredProviders += $provider
            }
        }
        
        Write-Progress -Activity "Checking Resource Providers" -Completed
    
    # Offer to register unregistered providers
    if ($unregisteredProviders.Count -gt 0) {
        Write-Host "`n⚠️  Found $($unregisteredProviders.Count) unregistered resource provider(s)" -ForegroundColor Yellow
        Write-Host "   Unregistered providers: $($unregisteredProviders -join ', ')" -ForegroundColor Gray
        Write-Host "`n💡 These resource providers are required for Azure Arc functionality:" -ForegroundColor Cyan
        Write-Host "   • Microsoft.HybridCompute     - Core Azure Arc agent functionality" -ForegroundColor Gray
        Write-Host "   • Microsoft.GuestConfiguration - Guest configuration policies" -ForegroundColor Gray
        Write-Host "   • Microsoft.AzureArcData      - Azure Arc data services" -ForegroundColor Gray
        Write-Host "   • Microsoft.HybridConnectivity - Hybrid connectivity features" -ForegroundColor Gray
        
        Write-Host "`n🔧 Registration Options:" -ForegroundColor Cyan
        Write-Host "   A - Register ALL unregistered providers automatically" -ForegroundColor Green
        Write-Host "   S - Select specific providers to register" -ForegroundColor Yellow
        Write-Host "   N - Skip registration (you can register manually later)" -ForegroundColor Gray
        
        $registrationAttempted = $false
        
        do {
            $choice = Read-Host "`nWould you like to register resource providers? (A/S/N)"
            switch ($choice.ToUpper()) {
                'A' {
                    Write-Host "`n� Registering all unregistered providers in parallel..." -ForegroundColor Green
                    $registrationAttempted = $true
                    
                    # Use new parallel registration function
                    $parallelSuccess = Register-AzureResourceProvidersParallel -ProviderNamespaces $unregisteredProviders
                    
                    if ($parallelSuccess) {
                        Write-Host "`n✅ All resource providers registered successfully!" -ForegroundColor Green
                    } else {
                        Write-Host "`n⚠️  Some providers may still be completing registration" -ForegroundColor Yellow
                        Write-Host "   Check Azure portal for final status" -ForegroundColor Gray
                    }
                    break
                }
                'S' {
                    Write-Host "`n📋 Select providers to register:" -ForegroundColor Cyan
                    for ($i = 0; $i -lt $unregisteredProviders.Count; $i++) {
                        Write-Host "   $($i + 1). $($unregisteredProviders[$i])" -ForegroundColor Gray
                    }
                    
                    do {
                        $selection = Read-Host "`nEnter provider numbers to register (e.g., 1,3 or 'all' for all)"
                        if ($selection.ToLower() -eq 'all') {
                            $selectedProviders = $unregisteredProviders
                            break
                        } else {
                            try {
                                $indices = $selection.Split(',') | ForEach-Object { [int]$_.Trim() - 1 }
                                $selectedProviders = @()
                                foreach ($index in $indices) {
                                    if ($index -ge 0 -and $index -lt $unregisteredProviders.Count) {
                                        $selectedProviders += $unregisteredProviders[$index]
                                    } else {
                                        throw "Invalid selection"
                                    }
                                }
                                break
                            } catch {
                                Write-Host "   ❌ Invalid selection. Please enter valid numbers (1-$($unregisteredProviders.Count)) separated by commas" -ForegroundColor Red
                            }
                        }
                    } while ($true)
                    
                    Write-Host "`n� Registering selected providers..." -ForegroundColor Green
                    $registrationAttempted = $true
                    
                    # Use parallel registration for multiple providers, single registration for one provider
                    if ($selectedProviders.Count -gt 1) {
                        $parallelSuccess = Register-AzureResourceProvidersParallel -ProviderNamespaces $selectedProviders
                        
                        if ($parallelSuccess) {
                            Write-Host "`n✅ All selected resource providers registered successfully!" -ForegroundColor Green
                        } else {
                            Write-Host "`n⚠️  Some selected providers may still be completing registration" -ForegroundColor Yellow
                        }
                    } else {
                        # Single provider - use individual registration for more detailed feedback
                        $success = Register-AzureResourceProvider -ProviderNamespace $selectedProviders[0]
                        if ($success) {
                            Write-Host "`n✅ Resource provider registered successfully!" -ForegroundColor Green
                        } else {
                            Write-Host "`n⚠️  Provider registration may still be in progress" -ForegroundColor Yellow
                        }
                    }
                    break
                }
                'N' {
                    Write-Host "`n⏭️  Skipping resource provider registration" -ForegroundColor Gray
                    Write-Host "   💡 You can register providers manually using:" -ForegroundColor Gray
                    Write-Host "      Register-AzResourceProvider -ProviderNamespace <ProviderName>" -ForegroundColor Gray
                    Write-Host "   📋 Or use the Azure portal: Home > Subscriptions > Resource providers" -ForegroundColor Gray
                    break
                }
                default {
                    Write-Host "   Please enter 'A' for all, 'S' for selective, or 'N' to skip." -ForegroundColor Yellow
                }
            }
        } while ($choice.ToUpper() -notin @('A', 'S', 'N'))
        
        # Re-check registration status after any registration attempts
        if ($registrationAttempted) {
            Write-Host "`n🔍 Re-checking resource provider registration status..." -ForegroundColor Cyan
            $stillUnregistered = @()
            
            # Show progress during re-checking
            Write-Progress -Activity "Re-checking Resource Providers" -Status "Initializing..." -PercentComplete 0
            
            for ($i = 0; $i -lt $providers.Count; $i++) {
                $provider = $providers[$i]
                $percentComplete = [math]::Round((($i + 1) / $providers.Count) * 100)
                Write-Progress -Activity "Re-checking Resource Providers" -Status "Re-checking $provider... ($($i + 1)/$($providers.Count))" -PercentComplete $percentComplete
                
                try {
                    $resourceProvider = Get-AzResourceProvider -ProviderNamespace $provider -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
                    if ($resourceProvider -and $resourceProvider.RegistrationState -eq "Registered") {
                        Write-Host "    ✅ $provider : Confirmed registered" -ForegroundColor Green
                    } else {
                        Write-Host "    ⚠️  $provider : Still not registered" -ForegroundColor Yellow
                        $stillUnregistered += $provider
                    }
                } catch {
                    Write-Host "    ❌ $provider : Error re-checking - $($_.Exception.Message)" -ForegroundColor Red
                    $stillUnregistered += $provider
                }
            }
            
            Write-Progress -Activity "Re-checking Resource Providers" -Completed
            
            # Store the current unregistered providers for later use in status reporting
            $script:unregisteredProviders = $stillUnregistered
            
            # Only mark as checked if all providers are now registered
            if ($stillUnregistered.Count -eq 0) {
                Write-Host "`n✅ All resource providers are now registered!" -ForegroundColor Green
                $script:resourceProvidersChecked = $true
            } else {
                Write-Host "`n⚠️  $($stillUnregistered.Count) resource provider(s) still need attention: $($stillUnregistered -join ', ')" -ForegroundColor Yellow
                Write-Host "   Resource provider check will remain incomplete until all are registered." -ForegroundColor Gray
                # Do NOT set $script:resourceProvidersChecked = $true here
            }
        } else {
            # User chose to skip - mark as checked but store unregistered providers for status reporting
            $script:unregisteredProviders = $unregisteredProviders
            Write-Host "`n📝 Resource provider check marked as completed (user chose to skip registration)" -ForegroundColor Gray
            Write-Host "   Note: Unregistered providers may cause issues during Azure Arc onboarding" -ForegroundColor Yellow
            $script:resourceProvidersChecked = $true
        }
        
    } else {
        Write-Host "`n✅ All required resource providers are registered!" -ForegroundColor Green
        $script:unregisteredProviders = @()  # No unregistered providers
        $script:resourceProvidersChecked = $true
    }
    }
    finally {
        # Restore original warning preference
        $WarningPreference = $OriginalWarningPreference
    }
}

function Invoke-DeviceCheck {
    param(
        [string]$DeviceName,
        [string]$LogFile
    )
    
    # First get OS version for header display
    $osVersion = "Unknown OS"
    $session = $null
    try {
        # Test device connectivity first
        $isReachable = Test-DeviceConnectivity -DeviceName $DeviceName
        if ($isReachable) {
            # Establish session if needed for OS version check
            if ($DeviceName -ne $env:COMPUTERNAME -and $DeviceName -ne "localhost") {
                $session = New-PSSession -ComputerName $DeviceName -ErrorAction SilentlyContinue
            }
            $osVersion = Get-DeviceOSVersion -DeviceName $DeviceName -Session $session
            $script:deviceOSVersions[$DeviceName] = $osVersion
        }
    } catch {
        $osVersion = "Unknown OS"
    }
    
    #Write-Host "`n=================================================" -ForegroundColor Yellow
    Write-Host "`n🖥️  CHECKING DEVICE: $DeviceName [$osVersion]" -ForegroundColor Yellow
    Write-Host "────────────────────────────────────────────────────────────────────────" -ForegroundColor Yellow
    
    # Clear previous log for this device
    if (Test-Path $LogFile) { 
        Remove-Item $LogFile 
    }
    "Device: $DeviceName - Prerequisites Check Started at $(Get-Date)" | Out-File -FilePath $LogFile
    
    # Test device connectivity (may have been done above, but ensure proper logging)
    Write-Step "Testing device connectivity" $DeviceName
    if (-not $isReachable) {
        $isReachable = Test-DeviceConnectivity -DeviceName $DeviceName
    }
    
    if (-not $isReachable) {
        Test-Prerequisites $DeviceName "Device Connectivity" "Error" "Device is not reachable" $LogFile
        Write-Host "    Skipping remaining checks for unreachable device" -ForegroundColor Red
        return
    } else {
        Test-Prerequisites $DeviceName "Device Connectivity" "OK" "Device is reachable" $LogFile
    }
    
    # Calculate total steps (reduced by 4 since resource provider checks are done once)
    $totalSteps = 8  # PowerShell, Az module, Arc agent, Network, Execution policy, MDE service, MDE extension, OS version
    $currentStep = 0
    
    # For remote devices, we'll use Invoke-Command for most checks
    try {
        if ($DeviceName -ne $env:COMPUTERNAME -and $DeviceName -ne "localhost") {
            if (-not $session) {
                Write-Step "Establishing remote session" $DeviceName
                $session = New-PSSession -ComputerName $DeviceName -ErrorAction Stop
                Write-Host "    Remote session established" -ForegroundColor Green
            } else {
                Write-Host "    Using existing remote session" -ForegroundColor Green
            }
        }
        
        # PowerShell version
        $currentStep++
        Write-ProgressStep "Prerequisites Check - $DeviceName" $currentStep $totalSteps
        Write-Step "Checking PowerShell version" $DeviceName
        try {
            if ($session) {
                $psVersion = Invoke-Command -Session $session -ScriptBlock { $PSVersionTable.PSVersion }
            } else {
                $psVersion = $PSVersionTable.PSVersion
            }
            
            if ($psVersion.Major -lt 5) {
                Test-Prerequisites $DeviceName "PowerShell Version" "Warning" "Version $psVersion. Requires 5.0 or higher." $LogFile
            } else {
                Test-Prerequisites $DeviceName "PowerShell Version" "OK" "Version $psVersion" $LogFile
            }
        } catch {
            Test-Prerequisites $DeviceName "PowerShell Version" "Error" $_.Exception.Message $LogFile
        }
        
        # Az module check (remote devices only)
        $currentStep++
        Write-ProgressStep "Prerequisites Check - $DeviceName" $currentStep $totalSteps
        if ($session) {
            Write-Step "Checking Az PowerShell module" $DeviceName
            try {
                $azModule = Invoke-Command -Session $session -ScriptBlock { Get-Module -ListAvailable -Name Az }
                
                if (-not $azModule) {
                    Test-Prerequisites $DeviceName "Az Module" "Warning" "Az module not found on remote device" $LogFile
                } else {
                    Test-Prerequisites $DeviceName "Az Module" "OK" "Az module is installed on remote device" $LogFile
                }
            } catch {
                Test-Prerequisites $DeviceName "Az Module" "Error" $_.Exception.Message $LogFile
            }
        } else {
            Test-Prerequisites $DeviceName "Az Module" "Info" "Checked during Azure login process" $LogFile
        }
        
        # Azure Arc agent
        $currentStep++
        Write-ProgressStep "Prerequisites Check - $DeviceName" $currentStep $totalSteps
        Write-Step "Checking Azure Arc agent installation" $DeviceName
        try {
            $arcAgentPath = "C:\Program Files\AzureConnectedMachineAgent"
            if ($session) {
                $arcAgentExists = Invoke-Command -Session $session -ScriptBlock { 
                    param($path) 
                    Test-Path $path 
                } -ArgumentList $arcAgentPath
            } else {
                $arcAgentExists = Test-Path $arcAgentPath
            }
            
            if ($arcAgentExists) {
                Test-Prerequisites $DeviceName "Azure Arc Agent" "OK" "Agent is installed." $LogFile
            } else {
                Test-Prerequisites $DeviceName "Azure Arc Agent" "Warning" "Agent not found." $LogFile
            }
        } catch {
            Test-Prerequisites $DeviceName "Azure Arc Agent" "Error" $_.Exception.Message $LogFile
        }
        
        # Network connectivity
        $currentStep++
        Write-ProgressStep "Prerequisites Check - $DeviceName" $currentStep $totalSteps
        Write-Step "Testing network connectivity to Azure" $DeviceName
        try {
            if ($session) {
                $networkTest = Invoke-Command -Session $session -ScriptBlock { 
                    Test-NetConnection -ComputerName "management.azure.com" -Port 443 
                }
            } else {
                $networkTest = Test-NetConnection -ComputerName "management.azure.com" -Port 443
            }
            
            if ($networkTest.TcpTestSucceeded) {
                Test-Prerequisites $DeviceName "Network Connectivity" "OK" "Can reach management.azure.com" $LogFile
            } else {
                Test-Prerequisites $DeviceName "Network Connectivity" "Warning" "Cannot reach management.azure.com" $LogFile
            }
        } catch {
            Test-Prerequisites $DeviceName "Network Connectivity" "Error" $_.Exception.Message $LogFile
        }
        
        # Execution policy
        $currentStep++
        Write-ProgressStep "Prerequisites Check - $DeviceName" $currentStep $totalSteps
        Write-Step "Checking PowerShell execution policy" $DeviceName
        try {
            if ($session) {
                $policy = Invoke-Command -Session $session -ScriptBlock { Get-ExecutionPolicy }
            } else {
                $policy = Get-ExecutionPolicy
            }
            
            if ($policy -eq "RemoteSigned" -or $policy -eq "Unrestricted") {
                Test-Prerequisites $DeviceName "Execution Policy" "OK" $policy $LogFile
            } else {
                Test-Prerequisites $DeviceName "Execution Policy" "Warning" $policy $LogFile
            }
        } catch {
            Test-Prerequisites $DeviceName "Execution Policy" "Error" $_.Exception.Message $LogFile
        }
        
        # MDE service
        $currentStep++
        Write-ProgressStep "Prerequisites Check - $DeviceName" $currentStep $totalSteps
        Write-Step "Checking Microsoft Defender for Endpoint service" $DeviceName
        try {
            if ($session) {
                $mdeService = Invoke-Command -Session $session -ScriptBlock { 
                    Get-Service -Name "Sense" -ErrorAction SilentlyContinue 
                }
            } else {
                $mdeService = Get-Service -Name "Sense" -ErrorAction SilentlyContinue
            }
            
            if ($mdeService -and $mdeService.Status -eq "Running") {
                Test-Prerequisites $DeviceName "MDE Service" "OK" "Service is running." $LogFile
            } else {
                Test-Prerequisites $DeviceName "MDE Service" "Warning" "Service not found or not running." $LogFile
            }
        } catch {
            Test-Prerequisites $DeviceName "MDE Service" "Error" $_.Exception.Message $LogFile
        }
        
        # MDE extension
        $currentStep++
        Write-ProgressStep "Prerequisites Check - $DeviceName" $currentStep $totalSteps
        Write-Step "Checking MDE extension installation" $DeviceName
        try {
            $extPath = "C:\Packages\Plugins\Microsoft.Azure.AzureDefenderForServers\MDE.Windows"
            if ($session) {
                $extExists = Invoke-Command -Session $session -ScriptBlock { 
                    param($path) 
                    Test-Path $path 
                } -ArgumentList $extPath
            } else {
                $extExists = Test-Path $extPath
            }
            
            if ($extExists) {
                Test-Prerequisites $DeviceName "MDE Extension" "OK" "Extension is present." $LogFile
            } else {
                Test-Prerequisites $DeviceName "MDE Extension" "Info" "Extension not found." $LogFile
            }
        } catch {
            Test-Prerequisites $DeviceName "MDE Extension" "Error" $_.Exception.Message $LogFile
        }
        
        # OS version
        $currentStep++
        Write-ProgressStep "Prerequisites Check - $DeviceName" $currentStep $totalSteps
        Write-Step "Checking operating system compatibility" $DeviceName
        try {
            if ($session) {
                $osVersion = Invoke-Command -Session $session -ScriptBlock { 
                    (Get-CimInstance Win32_OperatingSystem).Caption 
                }
            } else {
                $osVersion = (Get-CimInstance Win32_OperatingSystem).Caption
            }
            
            $supported = @(
                "Microsoft Windows 11 Pro",
                "Microsoft Windows 11 Enterprise",
                "Microsoft Windows 10 Pro", 
                "Microsoft Windows 10 Enterprise",
                "Microsoft Windows Server 2025 Standard",
                "Microsoft Windows Server 2025 Datacenter",
                "Microsoft Windows Server 2022 Standard",
                "Microsoft Windows Server 2019 Datacenter",
                "Microsoft Windows Server 2016 Essentials",
                "Microsoft Windows Server 2012 R2 Standard",
                "Microsoft Windows Server 2008 R2 Enterprise"
            )
            
            if ($supported -contains $osVersion) {
                Test-Prerequisites $DeviceName "OS Version" "OK" $osVersion $LogFile
            } else {
                Test-Prerequisites $DeviceName "OS Version" "Warning" "$osVersion may not be supported." $LogFile
            }
        } catch {
            Test-Prerequisites $DeviceName "OS Version" "Error" $_.Exception.Message $LogFile
        }
        
    } finally {
        if ($session) {
            Remove-PSSession $session -ErrorAction SilentlyContinue
            Write-Host "    Remote session closed" -ForegroundColor Gray
        }
    }
    
    # Complete progress for this device
    Write-Progress "Prerequisites Check - $DeviceName" -Completed
}

function Get-DeviceListFile {
    do {
        Write-Host "`n📂 Please provide the path to the file containing device names:" -ForegroundColor Cyan
        Write-Host "   (Full path example:    C:\Demo\ArcDevice.txt)" -ForegroundColor Gray
        Write-Host "   (Relative path example: .\devices\ArcDevice.txt)" -ForegroundColor Gray
        Write-Host "   (Press Enter for default: ArcDevice.txt)" -ForegroundColor Gray
        $filePath = Read-Host "`nFile path"
        
        # Use default if empty
        if ([string]::IsNullOrWhiteSpace($filePath)) {
            $filePath = "ArcDevice.txt"
        }
        
        # Check if file extension is .txt (required for all paths)
        if (-not ($filePath -match "\.txt$")) {
            Write-Host "❌ File extension must be .txt (e.g., C:\Demo\ArcDevice.txt or .\devices\ArcDevice.txt)" -ForegroundColor Red
            continue
        }
        
        # Check if file exists
        if (Test-Path $filePath) {
            return $filePath
        } else {
            Write-Host "❌ File not found: $filePath" -ForegroundColor Red
            $createFile = Read-Host "Would you like to create a sample file? (y/n)"
            if ($createFile -eq 'y' -or $createFile -eq 'Y') {
                try {
                    @"
vm-wsx
vm-wsy
vm-wsz
vm-wcx
vm-wcz
"@ | Out-File -FilePath $filePath -Encoding UTF8
                    Write-Host "✅ Sample file created: $filePath" -ForegroundColor Green
                    Write-Host "Please update it with your actual device names and run the script again." -ForegroundColor Yellow
                    return $null
                } catch {
                    Write-Host "❌ Error creating file: $($_.Exception.Message)" -ForegroundColor Red
                }
            }
        }
    } while ($true)
}

# Main script execution

Write-Host "──────────────────────────────────────────────────────────────" -ForegroundColor Cyan
Write-Host "BEGIN: Multi-Device Azure Arc and MDC/MDE Prerequisites Checks" -ForegroundColor Cyan
Write-Host "──────────────────────────────────────────────────────────────" -ForegroundColor Cyan

# Get device list file from user
$deviceListFile = Get-DeviceListFile
if (-not $deviceListFile) {
    exit 1
}

# Read device list
$devices = Get-Content $deviceListFile | Where-Object { $_.Trim() -ne "" }
if ($devices.Count -eq 0) {
    Write-Host "❌ No devices found in '$deviceListFile'!" -ForegroundColor Red
    exit 1
}

Write-Host "`n📋 Found $($devices.Count) devices to check:" -ForegroundColor Green
$devices | ForEach-Object { Write-Host "  • $_" -ForegroundColor Gray }

# Perform Azure login once (only on local machine)
$azureLoginSuccess = Test-AzureLogin

# Check Azure Resource Providers once after successful login
if ($azureLoginSuccess) {
    Test-AzureResourceProviders
}

# Process each device
foreach ($device in $devices) {
    $logFile = "AzureArc_MDE_Checks_$device.log"
    Invoke-DeviceCheck -DeviceName $device -LogFile $logFile
}

# Display consolidated results for all devices
#Write-Host("`n=================================================") -ForegroundColor Cyan
Write-Host "`n`n📊 CONSOLIDATED RESULTS - ALL DEVICES" -ForegroundColor Cyan
Write-Host "────────────────────────────────────────────────────────────────────────" -ForegroundColor Cyan

$consolidatedResults = @()
foreach ($deviceName in $allResults.Keys) {
    $consolidatedResults += $allResults[$deviceName]
}

if ($consolidatedResults.Count -gt 0) {
    $consolidatedResults | Format-Table -Property Device, Check, Result, Details -AutoSize
    
    # Overall summary
    $totalChecks = $consolidatedResults.Count
    $okCount = ($consolidatedResults | Where-Object { $_.Result -eq "OK" }).Count
    $warningCount = ($consolidatedResults | Where-Object { $_.Result -eq "Warning" }).Count
    $errorCount = ($consolidatedResults | Where-Object { $_.Result -eq "Error" }).Count
    $infoCount = ($consolidatedResults | Where-Object { $_.Result -eq "Info" }).Count
    
    #Write-Host "=============================" -ForegroundColor Cyan
    Write-Host "📋 OVERALL SUMMARY" -ForegroundColor Cyan
    Write-Host "────────────────────────────────────────────────────────────────────────" -ForegroundColor Cyan
    Write-Host "Devices Checked:`t$($devices.Count)" -ForegroundColor White
    Write-Host "Total Checks:`t`t$totalChecks" -ForegroundColor White
    Write-Host "✅ OK:`t`t`t$okCount" -ForegroundColor Green
    Write-Host "⚠️  Warnings:`t`t$warningCount" -ForegroundColor Yellow
    Write-Host "❌ Errors:`t`t$errorCount" -ForegroundColor Red
    Write-Host "ℹ️  Info:`t`t$infoCount" -ForegroundColor Blue
    Write-Host "Azure Login:`t`t$(if ($azureLoginSuccess) { '✅ Success' } else { '❌ Failed' })" -ForegroundColor $(if ($azureLoginSuccess) { 'Green' } else { 'Red' })
    Write-Host "Resource Providers:`t$(if ($resourceProvidersChecked) { '✅ Checked' } else { '⚠️ Skipped' })" -ForegroundColor $(if ($resourceProvidersChecked) { 'Green' } else { 'Yellow' })
    Write-Host "────────────────────────────────────────────────────────────────────────" -ForegroundColor Cyan
    
    # Device-specific summaries
    Write-Host "`n📊 Per-Device Summary:" -ForegroundColor Cyan
    foreach ($deviceName in $allResults.Keys | Sort-Object) {
        $deviceResults = $allResults[$deviceName]
        $deviceOk = ($deviceResults | Where-Object { $_.Result -eq "OK" }).Count
        $deviceWarnings = ($deviceResults | Where-Object { $_.Result -eq "Warning" }).Count
        $deviceErrors = ($deviceResults | Where-Object { $_.Result -eq "Error" }).Count
        
        $status = if ($deviceErrors -gt 0) { "❌" } elseif ($deviceWarnings -gt 0) { "⚠️" } else { "✅" }
        Write-Host "  $status $deviceName : OK($deviceOk) Warnings($deviceWarnings) Errors($deviceErrors)" -ForegroundColor White
    }
    
    # Detailed Issues per Device
    Write-Host "`n`n🔍 DETAILED ISSUES TO ADDRESS PER DEVICE" -ForegroundColor Yellow
    Write-Host "────────────────────────────────────────────────────────────────────────" -ForegroundColor Yellow
    
    $hasAnyIssues = $false
    foreach ($deviceName in $allResults.Keys | Sort-Object) {
        $deviceResults = $allResults[$deviceName]
        $deviceWarnings = $deviceResults | Where-Object { $_.Result -eq "Warning" }
        $deviceErrors = $deviceResults | Where-Object { $_.Result -eq "Error" }
        
        if ($deviceWarnings.Count -gt 0 -or $deviceErrors.Count -gt 0) {
            $hasAnyIssues = $true
            $osVersion = if ($script:deviceOSVersions[$deviceName]) { $script:deviceOSVersions[$deviceName] } else { "Unknown OS" }
            Write-Host "`n`n🖥️  DEVICE: $deviceName [$osVersion]" -ForegroundColor Cyan
            Write-Host "========================================================================" -ForegroundColor Gray

            # Display Critical Errors first
            if ($deviceErrors.Count -gt 0) {
                Write-Host "❌ CRITICAL ERRORS (Must Fix):" -ForegroundColor Red
                foreach ($deviceError in $deviceErrors) {
                    Write-Host "   • $($deviceError.Check): $($deviceError.Details)" -ForegroundColor Red
                    
                    # Provide specific remediation guidance
                    switch ($deviceError.Check) {
                        "Device Connectivity" {
                            Write-Host "     💡 Action Required:" -ForegroundColor DarkGray
                            Write-Host "        - Verify device is powered on and network accessible" -ForegroundColor Gray
                            Write-Host "        - Enable WinRM: winrm quickconfig" -ForegroundColor Gray
                            Write-Host "        - Check Windows Firewall settings for remote management" -ForegroundColor Gray
                        }
                        "PowerShell Version" {
                            Write-Host "     💡 Action Required:" -ForegroundColor DarkGray
                            Write-Host "        - Download and install PowerShell 5.1 or later" -ForegroundColor Gray
                            Write-Host "        - Or install PowerShell 7: https://github.com/PowerShell/PowerShell/releases" -ForegroundColor Gray
                        }
                        "Az Module" {
                            Write-Host "     💡 Action Required:" -ForegroundColor DarkGray
                            Write-Host "        - Install Azure PowerShell: Install-Module -Name Az -Scope CurrentUser" -ForegroundColor Gray
                            Write-Host "        - Or as admin: Install-Module -Name Az -Scope AllUsers" -ForegroundColor Gray
                        }
                        "Azure Arc Agent" {
                            Write-Host "     💡 Action Required:" -ForegroundColor DarkGray
                            Write-Host "        - Download agent from Azure portal > Azure Arc > Servers" -ForegroundColor Gray
                            Write-Host "        - Install: msiexec /i AzureConnectedMachineAgent.msi /quiet" -ForegroundColor Gray
                        }
                        "Network Connectivity" {
                            Write-Host "     💡 Action Required:" -ForegroundColor DarkGray
                            Write-Host "        - Check internet connectivity and DNS resolution" -ForegroundColor Gray
                            Write-Host "        - Verify firewall allows HTTPS (443) to *.azure.com" -ForegroundColor Gray
                            Write-Host "        - Configure proxy if required" -ForegroundColor Gray
                        }
                        "Execution Policy" {
                            Write-Host "     💡 Action Required:" -ForegroundColor DarkGray
                            Write-Host "        - Set policy: Set-ExecutionPolicy RemoteSigned -Scope CurrentUser" -ForegroundColor Gray
                            Write-Host "        - Or as admin: Set-ExecutionPolicy RemoteSigned" -ForegroundColor Gray
                        }
                        "MDE Service" {
                            Write-Host "     💡 Action Required:" -ForegroundColor DarkGray
                            Write-Host "        - Install Microsoft Defender for Endpoint from Microsoft 365 Defender portal" -ForegroundColor Gray
                            Write-Host "        - Start service: Start-Service -Name Sense" -ForegroundColor Gray
                        }
                        "MDE Extension" {
                            Write-Host "     💡 Action Required:" -ForegroundColor DarkGray
                            Write-Host "        - Install via Azure portal or PowerShell after Arc onboarding" -ForegroundColor Gray
                            Write-Host "        - Ensure Microsoft Defender for Cloud is enabled" -ForegroundColor Gray
                        }
                        "OS Version" {
                            Write-Host "     💡 Action Required:" -ForegroundColor DarkGray
                            Write-Host "        - Verify OS version is supported by Azure Arc" -ForegroundColor Gray
                            Write-Host "        - Consider OS upgrade if version is not supported" -ForegroundColor Gray
                        }
                        default {
                            Write-Host "     💡 Action Required:" -ForegroundColor DarkGray
                            Write-Host "        - Review error details and consult Azure Arc documentation" -ForegroundColor Gray
                            Write-Host "        - Check Azure Arc troubleshooting guide" -ForegroundColor Gray
                        }
                    }
                }
                Write-Host ""
            }
            
            # Display Warnings
            if ($deviceWarnings.Count -gt 0) {
                Write-Host "⚠️  WARNINGS (Recommended to Address):" -ForegroundColor Yellow
                foreach ($warning in $deviceWarnings) {
                    Write-Host "   • $($warning.Check): $($warning.Details)" -ForegroundColor Yellow
                    
                    # Provide specific recommendations
                    switch ($warning.Check) {
                        "PowerShell Version" {
                            Write-Host "     💡 Recommendation:" -ForegroundColor DarkGray
                            Write-Host "        - Consider upgrading to PowerShell 7.x for enhanced Azure features" -ForegroundColor Gray
                            Write-Host "        - PowerShell 7 offers better cross-platform support" -ForegroundColor Gray
                        }
                        "Az Module" {
                            Write-Host "     💡 Recommendation:" -ForegroundColor DarkGray
                            Write-Host "        - Install Az module on device for local Azure operations" -ForegroundColor Gray
                            Write-Host "        - Enables local Azure CLI and PowerShell commands" -ForegroundColor Gray
                        }
                        "Azure Arc Agent" {
                            Write-Host "     💡 Recommendation:" -ForegroundColor DarkGray
                            Write-Host "        - Install Azure Connected Machine agent before Arc onboarding" -ForegroundColor Gray
                            Write-Host "        - Agent required for Azure Arc-enabled servers functionality" -ForegroundColor Gray
                        }
                        "Network Connectivity" {
                            Write-Host "     💡 Recommendation:" -ForegroundColor DarkGray
                            Write-Host "        - Test connectivity: Test-NetConnection management.azure.com -Port 443" -ForegroundColor Gray
                            Write-Host "        - Ensure stable internet connection for Azure services" -ForegroundColor Gray
                        }
                        "Execution Policy" {
                            Write-Host "     💡 Recommendation:" -ForegroundColor DarkGray
                            Write-Host "        - Current policy may limit script execution capabilities" -ForegroundColor Gray
                            Write-Host "        - Consider setting to RemoteSigned for Azure operations" -ForegroundColor Gray
                        }
                        "MDE Service" {
                            Write-Host "     💡 Recommendation:" -ForegroundColor DarkGray
                            Write-Host "        - Install MDE for enhanced security monitoring" -ForegroundColor Gray
                            Write-Host "        - Integrates with Azure Defender for Cloud" -ForegroundColor Gray
                        }
                        "MDE Extension" {
                            Write-Host "     💡 Recommendation:" -ForegroundColor DarkGray
                            Write-Host "        - Extension will be available after Arc onboarding" -ForegroundColor Gray
                            Write-Host "        - Provides automated MDE deployment capabilities" -ForegroundColor Gray
                        }
                        "OS Version" {
                            Write-Host "     💡 Recommendation:" -ForegroundColor DarkGray
                            Write-Host "        - Verify compatibility with latest Azure Arc features" -ForegroundColor Gray
                            Write-Host "        - Check Azure Arc supported operating systems documentation" -ForegroundColor Gray
                        }
                        default {
                            Write-Host "     💡 Recommendation:" -ForegroundColor DarkGray
                            Write-Host "        - Review warning for potential optimization opportunities" -ForegroundColor Gray
                            Write-Host "        - Consider addressing for optimal Azure Arc experience" -ForegroundColor Gray
                        }
                    }
                }
                Write-Host ""
            }
            
            # Show action priority for this device
            if ($deviceErrors.Count -gt 0) {
                Write-Host "🎯 Priority for $deviceName`: Fix $($deviceErrors.Count) critical error(s) before proceeding" -ForegroundColor Red
            } elseif ($deviceWarnings.Count -gt 0) {
                Write-Host "🎯 Priority for $deviceName`: Address $($deviceWarnings.Count) warning(s) for optimal setup" -ForegroundColor Yellow
            }
        } else {
            # Device has no issues
            $osVersion = if ($script:deviceOSVersions[$deviceName]) { $script:deviceOSVersions[$deviceName] } else { "Unknown OS" }
            Write-Host "`n`n🖥️  DEVICE: $deviceName [$osVersion]" -ForegroundColor Green
            Write-Host "────────────────────────────────────────────────────────────────────────" -ForegroundColor Green
            Write-Host "✅ No issues found - Ready for Azure Arc onboarding!" -ForegroundColor Green
        }
    }
    
    if (-not $hasAnyIssues) {
        Write-Host "`n🎉 EXCELLENT! No warnings or errors found across all devices!" -ForegroundColor Green
        Write-Host "All systems are fully ready for Azure Arc onboarding and MDE integration." -ForegroundColor Green
    }
    
    # Cross-Device Priority Summary
    if ($hasAnyIssues) {
        Write-Host "`n`n📋 CROSS-DEVICE PRIORITY SUMMARY" -ForegroundColor Magenta
        Write-Host "────────────────────────────────────────────────────────────────────────" -ForegroundColor Magenta
        
        # Critical errors summary
        $criticalErrors = $consolidatedResults | Where-Object { $_.Result -eq "Error" }
        if ($criticalErrors.Count -gt 0) {
            Write-Host "`n🔥 CRITICAL ISSUES (Must Fix Before Arc Onboarding):" -ForegroundColor Red
            $errorGroups = $criticalErrors | Group-Object -Property Check | Sort-Object Name
            foreach ($group in $errorGroups) {
                $affectedDevices = ($group.Group | Select-Object -Property Device -Unique).Device -join ", "
                Write-Host "   • $($group.Name)" -ForegroundColor Red
                Write-Host "     Affected devices: $affectedDevices" -ForegroundColor Gray
                Write-Host "     Impact: Blocks Azure Arc onboarding process" -ForegroundColor Gray
                Write-Host ""
            }
        }
        
        # High priority warnings
        $highPriorityWarnings = $consolidatedResults | Where-Object { 
            $_.Result -eq "Warning" -and 
            ($_.Check -eq "Azure Arc Agent" -or $_.Check -eq "Network Connectivity" -or $_.Check -eq "PowerShell Version")
        }
        if ($highPriorityWarnings.Count -gt 0) {
            Write-Host "⚠️  HIGH PRIORITY RECOMMENDATIONS:" -ForegroundColor Yellow
            $warningGroups = $highPriorityWarnings | Group-Object -Property Check | Sort-Object Name
            foreach ($group in $warningGroups) {
                $affectedDevices = ($group.Group | Select-Object -Property Device -Unique).Device -join ", "
                Write-Host "   • $($group.Name)" -ForegroundColor Yellow
                Write-Host "     Affected devices: $affectedDevices" -ForegroundColor Gray
                Write-Host "     Impact: May affect Azure Arc functionality or performance" -ForegroundColor Gray
                Write-Host ""
            }
        }
        
        # Azure configuration status
        Write-Host "🔧 AZURE CONFIGURATION STATUS:" -ForegroundColor Cyan
        if ($azureLoginSuccess) {
            Write-Host "   ✅ Azure Authentication: Successfully completed" -ForegroundColor Green
        } else {
            Write-Host "   ❌ Azure Authentication: Failed - required for resource provider checks" -ForegroundColor Red
        }
        
        if ($resourceProvidersChecked) {
            if ($script:unregisteredProviders.Count -eq 0) {
                Write-Host "   ✅ Resource Providers: All required providers are registered" -ForegroundColor Green
                if ($resourceProvidersRegistered) {
                    Write-Host "   🔧 Resource Provider Registration: New providers were registered during this session" -ForegroundColor Blue
                }
            } else {
                Write-Host "   ⚠️  Resource Providers: $($script:unregisteredProviders.Count) provider(s) still need registration" -ForegroundColor Yellow
                Write-Host "      Unregistered: $($script:unregisteredProviders -join ', ')" -ForegroundColor Gray
                if ($resourceProvidersRegistered) {
                    Write-Host "   🔧 Some providers were registered this session, but registration incomplete" -ForegroundColor Yellow
                }
            }
        } else {
            if ($azureLoginSuccess) {
                Write-Host "   ⚠️  Resource Providers: Check incomplete - some providers may not be registered" -ForegroundColor Yellow
            } else {
                Write-Host "   ⚠️  Resource Providers: Not checked - Azure login required" -ForegroundColor Yellow
            }
        }
        
        # Next steps recommendation
        Write-Host "`n🎯 RECOMMENDED NEXT STEPS:" -ForegroundColor Magenta
        Write-Host "`t1. Address all critical errors first (red items above)" -ForegroundColor White
        Write-Host "`t2. Resolve high-priority warnings for optimal experience" -ForegroundColor White
        Write-Host "`t3. Ensure Azure authentication is completed" -ForegroundColor White
        if ($resourceProvidersRegistered) {
            Write-Host "`t4. Resource providers registered - ready for Arc onboarding" -ForegroundColor White
        } else {
            Write-Host "`t4. Verify Azure resource providers are registered (script can assist)" -ForegroundColor White
        }
        Write-Host "`t5. Re-run this script to validate fixes" -ForegroundColor White
        Write-Host "`t6. Proceed with Azure Arc onboarding process" -ForegroundColor White
    }
    
    Write-Host "`n📁 Individual device logs saved as: AzureArc_MDE_Checks_<DeviceName>.log" -ForegroundColor Gray
    
    # Final status determination
    # Use the stored unregistered providers information instead of re-checking
    $allProvidersRegistered = ($azureLoginSuccess -and $script:unregisteredProviders.Count -eq 0)
    
    if ($errorCount -eq 0 -and $warningCount -eq 0 -and $azureLoginSuccess -and $resourceProvidersChecked -and $allProvidersRegistered) {
        Write-Host "`n🚀 ALL SYSTEMS GO! All prerequisites passed for all devices!" -ForegroundColor Green
        Write-Host "   Systems are fully ready for Azure Arc and MDE integration." -ForegroundColor Green
    } elseif ($errorCount -eq 0 -and $azureLoginSuccess -and $allProvidersRegistered) {
        Write-Host "`n⚠️  READY WITH MINOR ITEMS: Prerequisites check completed with warnings only." -ForegroundColor Yellow
        Write-Host "   You can proceed with Azure Arc onboarding, but addressing warnings is recommended." -ForegroundColor Yellow
    } elseif ($errorCount -eq 0 -and $azureLoginSuccess -and -not $allProvidersRegistered) {
        Write-Host "`n⚠️  PARTIALLY READY: Device checks passed but resource provider registration incomplete." -ForegroundColor Yellow
        Write-Host "   Please register all required Azure resource providers before Arc onboarding." -ForegroundColor Yellow
        if ($script:unregisteredProviders.Count -gt 0) {
            Write-Host "   Missing providers: $($script:unregisteredProviders -join ', ')" -ForegroundColor Gray
        }
    } else {
        Write-Host "`n❌ NOT READY: Prerequisites check completed with critical errors." -ForegroundColor Red
        Write-Host "   Please resolve all critical errors before proceeding with Azure Arc onboarding." -ForegroundColor Red
    }
} else {
    Write-Host "❌ No results collected. Please check device connectivity and permissions." -ForegroundColor Red
}

Write-Host
Write-Host "────────────────────────────────────────────────────────────" -ForegroundColor Cyan
Write-Host "END: Multi-Device Azure Arc and MDC/MDE Prerequisites Checks" -ForegroundColor Cyan
Write-Host "────────────────────────────────────────────────────────────" -ForegroundColor Cyan
Write-Host
