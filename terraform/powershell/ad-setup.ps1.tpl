# Enable error handling and logging
$ErrorActionPreference = "Continue"
$WarningPreference = "Continue"
$LogPath = "C:\Logs\ad-setup.log"
$ErrorLogPath = "C:\Logs\ad-setup-error.log"
$ContinuationScriptPath = "C:\Logs\ad-setup-continuation.ps1"

# Create logs directory
New-Item -ItemType Directory -Path "C:\Logs" -Force | Out-Null

# Add timestamp logging function
function Log-Message {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp - $Message" | Out-File -FilePath $LogPath -Append
    Write-Host "$timestamp - $Message"
}

function Log-Error {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp - ERROR: $Message" | Out-File -FilePath $ErrorLogPath -Append
    Write-Host "ERROR: $Message" -ForegroundColor Red
}

Log-Message "=========================================="
Log-Message "Starting Active Directory Setup Script - Phase 1"
Log-Message "=========================================="

# Terraform injected variables
$domainName  = "${domain_name}"
$netbiosName = "${netbios_name}"
$plainPass   = "${ad_password}"

Log-Message "Configuration: Domain=$domainName, NetBIOS=$netbiosName"

try {
    # Disable Network Level Authentication for RDP
    Log-Message "Step 0: Disabling Network Level Authentication for RDP..."
    try {
        $regPath = "HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp"
        Set-ItemProperty -Path $regPath -Name "SecurityLayer" -Value 0 -ErrorAction Stop
        Log-Message "Network Level Authentication disabled successfully"
    } catch {
        Log-Message "Warning: Could not disable NLA, but continuing: $_"
    }
    
    # Install AD Domain Services
    Log-Message "Step 1: Installing AD Domain Services..."
    $installResult = Install-WindowsFeature AD-Domain-Services -IncludeManagementTools
    Log-Message "AD Domain Services installation result: $($installResult.RestartNeeded)"
    
    $secpasswd = ConvertTo-SecureString $plainPass -AsPlainText -Force
    
    # Install new AD Forest
    Log-Message "Step 2: Installing AD Forest for $domainName..."
    Install-ADDSForest `
        -DomainName $domainName `
        -DomainNetbiosName $netbiosName `
        -SafeModeAdministratorPassword $secpasswd `
        -NoRebootOnCompletion `
        -Force:$true -ErrorAction Stop
    
    Log-Message "AD Forest installation completed successfully"
    
    # Create continuation script for after reboot
    Log-Message "Step 3: Creating continuation script to run after reboot..."
    
    $continueDomainName = $domainName
    $continueDcPath = "DC=" + ($continueDomainName -replace "\.",",DC=")
    
    $continuationScript = @"
# Continuation script after AD Forest reboot
`$ErrorActionPreference = "Continue"
`$LogPath = "C:\Logs\ad-setup.log"
`$ErrorLogPath = "C:\Logs\ad-setup-error.log"

function Log-Message {
    param([string]`$Message)
    `$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "`$timestamp - `$Message" | Out-File -FilePath `$LogPath -Append
    Write-Host "`$timestamp - `$Message"
}

function Log-Error {
    param([string]`$Message)
    `$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "`$timestamp - ERROR: `$Message" | Out-File -FilePath `$ErrorLogPath -Append
    Write-Host "ERROR: `$Message" -ForegroundColor Red
}

Log-Message "=========================================="
Log-Message "Starting Active Directory Setup Script - Phase 2 (After Reboot)"
Log-Message "=========================================="

try {
    Log-Message "Phase 2: Waiting for AD Web Services to start..."
    Start-Sleep -Seconds 60
    
    Log-Message "Ensuring Network Level Authentication is disabled..."
    try {
        `$regPath = "HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp"
        Set-ItemProperty -Path `$regPath -Name "SecurityLayer" -Value 0 -ErrorAction Stop
        Log-Message "Network Level Authentication disabled"
    } catch {
        Log-Message "Warning: Could not disable NLA: `$_"
    }
    
    Log-Message "Attempting to start Active Directory Web Services..."
    try {
        `$adwsService = Get-Service -Name "ADWS" -ErrorAction Stop
        if (`$adwsService.Status -ne "Running") {
            Log-Message "ADWS service is not running. Starting it now..."
            Start-Service -Name "ADWS" -ErrorAction Stop
            Log-Message "ADWS service started successfully"
        } else {
            Log-Message "ADWS service is already running"
        }
    } catch {
        Log-Error "Failed to manage ADWS service: `$_"
    }
    
    Log-Message "Waiting for AD Web Services to become fully responsive (up to 5 minutes)..."
    `$maxRetries = 30
    `$retryCount = 0
    `$adwsReady = `$false
    
    while (`$retryCount -lt `$maxRetries -and -not `$adwsReady) {
        try {
            `$rootDSE = Get-ADRootDSE -ErrorAction Stop
            `$domain = Get-ADDomain -ErrorAction Stop
            Log-Message "AD Web Services is fully online. Domain: `$(`$domain.Name), Root DSE: `$(`$rootDSE.defaultNamingContext)"
            `$adwsReady = `$true
        } catch {
            `$retryCount++
            Log-Message "AD Web Services not fully responsive yet (attempt `$retryCount/`$maxRetries). Waiting 10 seconds..."
            Start-Sleep -Seconds 10
        }
    }
    
    if (-not `$adwsReady) {
        throw "AD Web Services did not become responsive within 5 minutes. Cannot proceed with AD object creation."
    }
    
    Log-Message "Phase 2: Creating Organizational Units..."
    `$dcPath = "$continueDcPath"
    Log-Message "DC Path: `$dcPath"
    
    New-ADOrganizationalUnit -Name "SuperHeroes" -Path `$dcPath -ProtectedFromAccidentalDeletion `$false -ErrorAction Stop
    Log-Message "Created OU: SuperHeroes"
    
    New-ADOrganizationalUnit -Name "SuperGroups" -Path `$dcPath -ProtectedFromAccidentalDeletion `$false -ErrorAction Stop
    Log-Message "Created OU: SuperGroups"
    
    Log-Message "Phase 2: Creating Security Groups..."
    `$groups = @("Avengers","XMen","Guardians","Fantastic4","Defenders")
    foreach (`$grp in `$groups) {
        New-ADGroup -Name `$grp -GroupScope Global -Path ("OU=SuperGroups," + `$dcPath) -ErrorAction Stop
        Log-Message "Created Group: `$grp"
    }
    
    Log-Message "Phase 2: Creating User Accounts..."
    `$users = @(
        @{Name="Tony Stark"; Sam="tonystark"; Email="tonystark@$continueDomainName"},
        @{Name="Steve Rogers"; Sam="steverogers"; Email="steverogers@$continueDomainName"},
        @{Name="Bruce Banner"; Sam="brucebanner"; Email="brucebanner@$continueDomainName"},
        @{Name="Peter Parker"; Sam="peterparker"; Email="peterparker@$continueDomainName"},
        @{Name="Natasha Romanoff"; Sam="natasha"; Email="natasha@$continueDomainName"}
    )
    
    `$UserPassword = ConvertTo-SecureString "Welcome123!" -AsPlainText -Force
    
    foreach (`$user in `$users) {
        New-ADUser -Name `$user.Name -SamAccountName `$user.Sam -UserPrincipalName `$user.Email -AccountPassword `$UserPassword -Enabled `$true -Path ("OU=SuperHeroes," + `$dcPath) -ErrorAction Stop
        Log-Message "Created User: `$(`$user.Name) (`$(`$user.Sam))"
    }
    
    Log-Message "Phase 2: Assigning Users to Groups..."
    for (`$i=0; `$i -lt `$users.Count; `$i++) {
        `$userSam = `$users[`$i].Sam
        `$groupName = `$groups[`$i]
        Add-ADGroupMember -Identity `$groupName -Members `$userSam -ErrorAction Stop
        Log-Message "Added `$userSam to `$groupName"
    }
    
    Log-Message "=========================================="
    Log-Message "Active Directory Setup Completed Successfully!"
    Log-Message "=========================================="
    
    # Clean up scheduled task
    Unregister-ScheduledTask -TaskName "AD-Setup-Phase2" -Confirm:`$false -ErrorAction SilentlyContinue
    Log-Message "Cleaned up scheduled task"
    
} catch {
    Log-Error "Exception occurred: `$(`$_.Exception.Message)"
    Log-Error "Stack trace: `$(`$_.Exception.StackTrace)"
    Log-Error "Phase 2 failed. Review error log for details."
    exit 1
}
"@

    # Write continuation script to file
    Set-Content -Path $ContinuationScriptPath -Value $continuationScript -ErrorAction Stop
    Log-Message "Continuation script created at $ContinuationScriptPath"
    
    # Register scheduled task to run after reboot
    Log-Message "Registering scheduled task to run Phase 2 after reboot..."
    $action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$ContinuationScriptPath`""
    $trigger = New-ScheduledTaskTrigger -AtStartup
    $principal = New-ScheduledTaskPrincipal -UserID "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
    Register-ScheduledTask -TaskName "AD-Setup-Phase2" -Action $action -Trigger $trigger -Principal $principal -Force -ErrorAction Stop
    Log-Message "Scheduled task registered successfully"
    
    Log-Message "=========================================="
    Log-Message "Phase 1 completed. Server will restart now."
    Log-Message "Phase 2 will continue automatically after reboot."
    Log-Message "=========================================="
    
    # Restart the server
    Log-Message "Initiating server restart..."
    Start-Sleep -Seconds 5
    Restart-Computer -Force
    
} catch {
    Log-Error "Exception occurred in Phase 1: $($_.Exception.Message)"
    Log-Error "Stack trace: $($_.Exception.StackTrace)"
    Log-Error "Phase 1 failed. Review error log for details."
    exit 1
}