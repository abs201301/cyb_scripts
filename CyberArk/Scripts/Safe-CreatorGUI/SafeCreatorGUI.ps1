function Create-Safe {

    $safeName = "${DeviceType}_${Environment}_${ApplicationID}_${Role}"
    $sRole = "${GPrefix}_${safeName}_Standard"
    $mRole = "${GPrefix}_${safeName}_SafeManager"

    # Create safe
	If ($DeviceType -eq "REP") {
		$token = Add-PASSafe -SafeName $safeName -Description "Created by SafeCreator for CMDB App-ID: ${ApplicationID}" -NumberOfVersionsRetention 7 -AutoPurgeEnabled $true -ErrorAction Stop
	} Else {
		$token = Add-PASSafe -SafeName $safeName -Description "Created by SafeCreator for CMDB App-ID: ${ApplicationID}" -ManagingCPM PasswordManager -NumberOfVersionsRetention 7 -AutoPurgeEnabled $true -ErrorAction Stop
	}
	Add-Content -Path $logpath -Value ((Get-Date -Format "yyyy/MM/dd HH:mm") + " Created ${safeName} safe")
    
    # Create safe Groups
	$null = New-QADGroup -ParentContainer $Container -Name $sRole -SamAccountName $sRole -DisplayName $sRole -Description "Permits Standard access to CyberArk safe: ${safeName} assigned to privileged accounts for App ID: ${ApplicationID}" -ManagedBy $PrimaryOwner -SecondaryOwner $SecondaryOwner -ObjectAttributes @{"extensionAttribute4"="Read-write";"extensionAttribute5"="${ApplicationID}";"extensionAttribute8"="Highly Confidential";"extensionAttribute2"="PROD";"extensionAttribute1"="Application Access";"extensionAttribute7"="";"extensionAttribute9"="High";"extensionAttribute6"="${SRMNumber}"}
	$null = New-QADGroup -ParentContainer $Container -Name $mRole -SamAccountName $mRole -DisplayName $mRole -Description "Permits SafeManager access to CyberArk safe: ${safeName} assigned to privileged accounts for App ID: ${ApplicationID} with accountability to approve account access requests within CyberArk" -ManagedBy $PrimaryOwner -SecondaryOwner $SecondaryOwner -ObjectAttributes @{"extensionAttribute4"="Read-write";"extensionAttribute5"="${ApplicationID}";"extensionAttribute8"="Highly Confidential";"extensionAttribute2"="PROD";"extensionAttribute1"="Application Access";"extensionAttribute7"="";"extensionAttribute9"="High";"extensionAttribute6"="${SRMNumber}"}

	Add-Content -Path $logpath -Value ((Get-Date -Format "yyyy/MM/dd HH:mm") + " AD group: $sRole is created")
	Add-Content -Path $logpath -Value ((Get-Date -Format "yyyy/MM/dd HH:mm") + " AD group: $mRole is created")


    # Assign safeAdmin role
    $token = $SafeAdminRole | Add-PASSafeMember -SafeName $safeName -MemberName "SafeAdmin" -SearchIn Vault -ErrorAction Stop
	Add-Content -Path $logpath -Value ((Get-Date -Format "yyyy/MM/dd HH:mm") + " Added the User safeadmin via Vault users mapping")

    # Assign Admins role
	$token = $cAdminsRole | Add-PASSafeMember -SafeName $safeName -MemberName "Vault Admins" -SearchIn Vault -ErrorAction Stop
	Add-Content -Path $logpath -Value ((Get-Date -Format "yyyy/MM/dd HH:mm") + " Added the Admin Role via vault group Vault Admins")
	
	Start-Sleep -Seconds 15
    # Assign Standard role
	$token = $StandardRole | Add-PASSafeMember -SafeName $safeName -MemberName $sRole -SearchIn $domainName -ErrorAction Stop
	Add-Content -Path $logpath -Value ((Get-Date -Format "yyyy/MM/dd HH:mm") + " Added the Standard Role via AD group $sRole")

    # Assign safeManager role
	$token = $SafeManagerRole | Add-PASSafeMember -SafeName $safeName -MemberName $mRole -SearchIn $domainName -ErrorAction Stop
	Add-Content -Path $logpath -Value ((Get-Date -Format "yyyy/MM/dd HH:mm") + " Added the Manager Role via AD group $mRole")
    
    # Assign PVWA Reports role
    $token = Add-PASGroupMember -groupId 17 -memberId $mRole
    Add-Content -Path $logpath -Value ((Get-Date -Format "yyyy/MM/dd HH:mm") + " AD group: $mRole is added to PVWAMonitor")
	
	# Remove API users from safe
	$token = Remove-PASSafeMember -SafeName $safeName -MemberName $UserName -ErrorAction Stop

	Add-Content -Path $logpath -Value ((Get-Date -Format "yyyy/MM/dd HH:mm") + " Removed API User from safe")

}

function Create-RecordingSafe {

    $recSafe = "PSMRec_$ApplicationID"
    $aRole = "${GPrefix}_${recSafe}_SafeAuditor"

    # Create recording safe
    $token = Add-PASSafe -SafeName $recSafe -Description "Recording safe for CMDB App-ID: ${ApplicationID}" -NumberOfDaysRetention 90 -AutoPurgeEnabled $true -ErrorAction Stop
	Add-Content -Path $logpath -Value ((Get-Date -Format "yyyy/MM/dd HH:mm") + " Created recording safe: $recSafe")

    # Create Auditor group
    $null = New-QADGroup -ParentContainer $Container -Name $aRole -SamAccountName $aRole -DisplayName $aRole -Description "Permits SafeAuditor access to CyberArk safe: ${recSafe} to view the session recordings of privileged accounts for App ID: ${ApplicationID}" -ManagedBy $PrimaryOwner -SecondaryOwner $SecondaryOwner -ObjectAttributes @{"extensionAttribute4"="Read-write";"extensionAttribute5"="${ApplicationID}";"extensionAttribute8"="Highly Confidential";"extensionAttribute2"="PROD";"extensionAttribute1"="Application Access";"extensionAttribute7"="";"extensionAttribute9"="High";"extensionAttribute6"="${SRMNumber}"}
	Add-Content -Path $logpath -Value ((Get-Date -Format "yyyy/MM/dd HH:mm") + " AD group: $aRole is created")

    # Assign safeAdmin role
    $token = $SafeAdminRole | Add-PASSafeMember -SafeName $recSafe -MemberName "SafeAdmin" -SearchIn Vault -ErrorAction Stop
	Add-Content -Path $logpath -Value ((Get-Date -Format "yyyy/MM/dd HH:mm") + " Added the User safeadmin")

    # Assign Admins Role
	$token = $cAdminsRole | Add-PASSafeMember -SafeName $recSafe -MemberName "Vault Admins" -SearchIn Vault -ErrorAction Stop
	Add-Content -Path $logpath -Value ((Get-Date -Format "yyyy/MM/dd HH:mm") + " Added the Admin Role via Vault group Vault Admins")
	
	Start-Sleep -Seconds 15
    # Assign Auditor role
	$token = $AuditorRole | Add-PASSafeMember -SafeName $recSafe -MemberName $aRole -SearchIn $domainName -ErrorAction Stop
	Add-Content -Path $logpath -Value ((Get-Date -Format "yyyy/MM/dd HH:mm") + " Added the Auditor Role via AD group $aRole")
	
	# Remove API users from safe
	$token = Remove-PASSafeMember -SafeName $recSafe -MemberName $UserName -ErrorAction Stop

	Add-Content -Path $logpath -Value ((Get-Date -Format "yyyy/MM/dd HH:mm") + " Removed API User from safe")
}

###################################################################################
## Main script starts here - Script will terminate if any errors are encountered ##
## Created: Oct 2024
## Abhishek Singh
###################################################################################
Import-Module psPAS
$ErrorActionPreference = "stop"
Add-Type -AssemblyName System.Web
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Variables used for safe creation

$PVWA = "<PVWAFQDN>"
$logpath = ".\SafeCreator.log"
$domainName = "<ADDomain>"
$apiuser = "<Domain>\<APIUser>"
$PVWAString = "https://" + $PVWA

# Variables used for group creation

$Container = "<AD-OU>"
$GPrefix = "<AnyPrefix for AD group>"
$QuestADServer = "<QuestADProxyServer>"

# Variables used by AAM-CP.

$appID  = '<AppID>'
$APIsafe  = '<Safe where your API user sits>'
$Object  = '<ObjectName of APIUser>'
$UserName = '<APIUserName>'
$CLIPath = "C:\Program Files\CyberArk\ApplicationPasswordSdk\CLIPasswordSDK64.exe"

# Roles

$StandardRole = [PSCustomObject]@{

  UseAccounts			= $true
  ListAccounts          = $true
  RetrieveAccounts	= $true
  InitiateCPMAccountManagementOperations = $true
  UnlockAccounts		= $true
  ViewAuditLog      	= $true
  ViewSafeMembers = $true
}


$SafeManagerRole = [PSCustomObject]@{

  UseAccounts			= $true
  ListAccounts         	= $true
  RetrieveAccounts	= $true
  UpdateAccountContent	= $true
  DeleteAccounts	= $true
  UnlockAccounts	= $true
  InitiateCPMAccountManagementOperations = $true
  requestsAuthorizationLevel1 		 = $true
  ViewAuditLog          = $true
  ViewSafeMembers       = $true
}

$AuditorRole = [PSCustomObject]@{

  UseAccounts		= $false
  ListAccounts         	= $true
  RetrieveAccounts	= $true
  UpdateAccountContent	= $false
  DeleteAccounts	= $false
  UnlockAccounts	= $false
  InitiateCPMAccountManagementOperations = $false
  requestsAuthorizationLevel1 		 = $false
  ViewAuditLog          = $true
  ViewSafeMembers       = $false
}


$cAdminsRole = [PSCustomObject]@{

  UseAccounts			= $false 
  RetrieveAccounts	= $false 
  ListAccounts			= $true
  AddAccounts			= $true 
  UpdateAccountContent		= $false 
  UpdateAccountProperties	= $true 
  InitiateCPMAccountManagementOperations = $true 
  SpecifyNextAccountContent	= $false
  RenameAccounts	= $true			
  DeleteAccounts		= $false 
  UnlockAccounts		= $true 
  ManageSafe			= $true 
  ManageSafeMembers		= $true 
  BackupSafe			= $false 
  ViewAuditLog		= $true 
  ViewSafeMembers			= $true		
  AccessWithoutConfirmation	= $false 
  CreateFolders		= $false 
  DeleteFolders		= $false 
  MoveAccountsAndFolders	= $true
}


$SafeAdminRole = [PSCustomObject]@{

  UseAccounts		= $true 
  RetrieveAccounts	= $true 
  ListAccounts		= $true
  AddAccounts		= $true 
  UpdateAccountContent	= $true 
  UpdateAccountProperties	= $true 
  InitiateCPMAccountManagementOperations = $true 
  SpecifyNextAccountContent	= $true
  RenameAccounts		= $true			
  DeleteAccounts		= $true 
  UnlockAccounts		= $true 
  ManageSafe		= $true 
  ManageSafeMembers	= $true 
  BackupSafe		= $true 
  ViewAuditLog		= $true 
  ViewSafeMembers	= $true		
  AccessWithoutConfirmation	= $true 
  CreateFolders		= $true 
  DeleteFolders		= $true 
  MoveAccountsAndFolders	= $true
}

# User Input
Write-Host "===============================" -ForegroundColor Yellow
Write-Host "CyberArk Safe Management" -ForegroundColor Yellow
Write-Host "===============================" -ForegroundColor Yellow
Write-Host ""

# Retrieve API credentials using CP
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$response = & $CLIPath GetPassword /p AppDescs.AppID=$appID /p Query=”Safe=$APIsafe;Folder=Root;Object=$Object” /o Password
$securePassword = ConvertTo-SecureString $response -AsPlainText -Force
$apiCredentials = New-Object System.Management.Automation.PSCredential($UserName, $securePassword)
 
#Create log file if needed and start logging
if (!(Test-Path $logpath -Type Leaf)) {New-Item -Path $logpath -Type File}

# Create the form
$form = New-Object System.Windows.Forms.Form
$form.Text = "CyberArk Safe Creator"
$form.Size = New-Object System.Drawing.Size(700, 550)
$form.StartPosition = "CenterScreen"

# Create Label and TextBox for App ID
$labelAppId = New-Object System.Windows.Forms.Label
$labelAppId.Text = "CMDB App ID"
$labelAppId.Location = New-Object System.Drawing.Point(20, 20)
$labelAppId.Size = New-Object System.Drawing.Size(120, 20)
$form.Controls.Add($labelAppId)

$textBoxAppId = New-Object System.Windows.Forms.TextBox
$textBoxAppId.Location = New-Object System.Drawing.Point(150, 20)
$textBoxAppId.Size = New-Object System.Drawing.Size(220, 20)
$form.Controls.Add($textBoxAppId)

# Create Label and TextBox for ticket number
$labelTicketId = New-Object System.Windows.Forms.Label
$labelTicketId.Text = "Ticket Number"
$labelTicketId.Location = New-Object System.Drawing.Point(20, 60)
$labelTicketId.Size = New-Object System.Drawing.Size(120, 20)
$form.Controls.Add($labelTicketId)

$textBoxTicketId = New-Object System.Windows.Forms.TextBox
$textBoxTicketId.Location = New-Object System.Drawing.Point(150, 60)
$textBoxTicketId.Size = New-Object System.Drawing.Size(220, 20)
$form.Controls.Add($textBoxTicketId)

# Create Label and TextBox for primary owner
$labelpOwnerId = New-Object System.Windows.Forms.Label
$labelpOwnerId.Text = "Primary Owner"
$labelpOwnerId.Location = New-Object System.Drawing.Point(20, 100)
$labelpOwnerId.Size = New-Object System.Drawing.Size(120, 20)
$form.Controls.Add($labelpOwnerId)

$textBoxpOwnerId = New-Object System.Windows.Forms.TextBox
$textBoxpOwnerId.Location = New-Object System.Drawing.Point(150, 100)
$textBoxpOwnerId.Size = New-Object System.Drawing.Size(220, 20)
$form.Controls.Add($textBoxpOwnerId)

# Create Label and TextBox for secondary owner
$labelsOwnerId = New-Object System.Windows.Forms.Label
$labelsOwnerId.Text = "Secondary Owner"
$labelsOwnerId.Location = New-Object System.Drawing.Point(20, 140)
$labelsOwnerId.Size = New-Object System.Drawing.Size(120, 20)
$form.Controls.Add($labelsOwnerId)

$textBoxsOwnerId = New-Object System.Windows.Forms.TextBox
$textBoxsOwnerId.Location = New-Object System.Drawing.Point(150, 140)
$textBoxsOwnerId.Size = New-Object System.Drawing.Size(220, 20)
$form.Controls.Add($textBoxsOwnerId)

# Create Label and ComboBox for DeviceType
$labelDeviceType = New-Object System.Windows.Forms.Label
$labelDeviceType.Text = "Device Type"
$labelDeviceType.Location = New-Object System.Drawing.Point(20, 180)
$labelDeviceType.Size = New-Object System.Drawing.Size(120, 20)
$form.Controls.Add($labelDeviceType)

$comboBoxDeviceType = New-Object System.Windows.Forms.ComboBox
$comboBoxDeviceType.Location = New-Object System.Drawing.Point(150, 180)
$comboBoxDeviceType.Size = New-Object System.Drawing.Size(220, 20)
$comboBoxDeviceType.Items.AddRange(@("WIN", "LNX", "WEB","ORA","SQL","FW","NW","SEC", "REP", "ILO", "IDR", "APP", "GRP", "AAD", "AWS"))
$comboBoxDeviceType.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDown
$form.Controls.Add($comboBoxDeviceType)

# Create Label and ComboBox for Environment
$labelEnvironment = New-Object System.Windows.Forms.Label
$labelEnvironment.Text = "Environment"
$labelEnvironment.Location = New-Object System.Drawing.Point(20, 220)
$labelEnvironment.Size = New-Object System.Drawing.Size(120, 20)
$form.Controls.Add($labelEnvironment)

$comboBoxEnvironment = New-Object System.Windows.Forms.ComboBox
$comboBoxEnvironment.Location = New-Object System.Drawing.Point(150, 220)
$comboBoxEnvironment.Size = New-Object System.Drawing.Size(220, 20)
$comboBoxEnvironment.Items.AddRange(@("Prod", "Non-Prod"))
$form.Controls.Add($comboBoxEnvironment)

# Create Label and ComboBox for Role
$labelRole = New-Object System.Windows.Forms.Label
$labelRole.Text = "Role"
$labelRole.Location = New-Object System.Drawing.Point(20, 260)
$labelRole.Size = New-Object System.Drawing.Size(120, 20)
$form.Controls.Add($labelRole)

$comboBoxRole = New-Object System.Windows.Forms.ComboBox
$comboBoxRole.Location = New-Object System.Drawing.Point(150, 260)
$comboBoxRole.Size = New-Object System.Drawing.Size(220, 20)
$comboBoxRole.Items.AddRange(@("ADM", "OPR", "APS", "RW","RO","SVC", "DEV"))
$comboBoxRole.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDown
$form.Controls.Add($comboBoxRole)

# Create checkbox for Recording safe
$checkBoxRecordingSafe = New-Object System.Windows.Forms.CheckBox
$checkBoxRecordingSafe.Text = "Do you need a recording safe ?"
$checkBoxRecordingSafe.Location = New-Object System.Drawing.Point(20, 300)
$checkBoxRecordingSafe.Size = New-Object System.Drawing.Size(220, 20)
$form.Controls.Add($checkBoxRecordingSafe)

# Create checkbox for approvals
$checkBoxApprovals = New-Object System.Windows.Forms.CheckBox
$checkBoxApprovals.Text = "Have you obtained necessary approvals ?"
$checkBoxApprovals.Location = New-Object System.Drawing.Point(20, 340)
$checkBoxApprovals.Size = New-Object System.Drawing.Size(260, 20)
$form.Controls.Add($checkBoxApprovals)

# Create a Submit button
$submitButton = New-Object System.Windows.Forms.Button
$submitButton.Text = "Submit"
$submitButton.Location = New-Object System.Drawing.Point(150, 400)
$form.Controls.Add($submitButton)

# Declare the variables to hold user input
$ApplicationID  = ""
$PrimaryOwner = ""
$SecondaryOwner = ""
$SRMNumber = ""
$deviceType = ""
$Environment = ""
$Role = ""

$formSubmitted = $false

# Event handler for button click
$submitButton.Add_Click({
    # Capture values from TextBox and ComboBoxes
    $script:ApplicationID = $textBoxAppId.Text
    $script:PrimaryOwner = $textBoxpOwnerId.Text
	$script:SecondaryOwner = $textBoxsOwnerId.Text
	$script:SRMNumber = $textBoxTicketId.Text
	$script:deviceType = $comboBoxDeviceType.Text

	If ($checkBoxRecordingSafe.Checked) {
        $script:RecordingSafe = "Yes"
        }
	If ($comboBoxEnvironment.SelectedItem -eq "Prod") {
		$script:Environment = "P"
		}
	ElseIf ($comboBoxEnvironment.SelectedItem -eq "Non-Prod") {
		$script:Environment = "NP"
		}
	$script:Role = $comboBoxRole.Text
    
    # Validate the inputs
    if (-not $checkBoxApprovals.Checked -or -not $script:ApplicationID -or -not $script:PrimaryOwner -or -not $script:SecondaryOwner -or -not $script:SRMNumber -or -not $script:deviceType -or -not $script:Environment -or -not $script:Role) {
        [System.Windows.Forms.MessageBox]::Show("Please fill out all fields before submitting.")
    } else {
        # Close the form after submission
		$script:formSubmitted = $true
        $form.Close()
	}
})

# Handle the form closing event
$form.add_FormClosing({
		If (-not $script:formSubmitted -and $_.CloseReason -eq [System.Windows.Forms.CloseReason]::UserClosing) {
			Return
		}
})

# Display the form and wait for user interaction
try {
	[void] $form.ShowDialog()
	} catch {
		Write-Host "Form was closed abruptly. Aborting the script"
		Add-Content -Path $logpath -Value ((Get-Date -Format "yyyy/MM/dd HH:mm") + " Form was closed abruptly. Aborting the script")
	}

If ($formSubmitted) {

	try {

        # Connect to Quest ARS
	    $null = Connect-QADService $QuestADServer -Proxy -ConnectionAccount $apiuser -ConnectionPassword $securePassword
	    Add-Content -Path $logpath -Value ((Get-Date -Format "yyyy/MM/dd HH:mm") + " Connected to AD")
		
	    # Create API session to CyberArk
		$token = New-PASSession -Credential $apiCredentials -BaseURI $PVWAString -type LDAP -concurrentSession $true -ErrorAction Stop
		Add-Content -Path $logpath -Value ((Get-Date -Format "yyyy/MM/dd HH:mm") + " Securely logged into CyberArk Web Services")

        # Create Safe and groups
        Create-Safe
	
        # Check for Recording safe and create if requested
        If ($RecordingSafe -eq "Yes") {
            Create-RecordingSafe
        }
	} catch {
		Add-Content -Path $logpath -Value ((Get-Date -Format "yyyy/MM/dd HH:mm") + " An exception has occurred!")
		Add-Content -Path $logpath -Value ((Get-Date -Format "yyyy/MM/dd HH:mm") + " Exception Type: $($_.Exception.GetType().FullName)")
		Add-Content -Path $logpath -Value ((Get-Date -Format "yyyy/MM/dd HH:mm") + " Exception Message: $($_.Exception.Message)")
		Exit
	}

	# Logout :: Close API session - run this to cleanup even if errors were encountered
	finally {
	Close-PASSession
	Add-Content -Path $logpath -Value ((Get-Date -Format "yyyy/MM/dd HH:mm") + " Safe creation and permission assignment finished")
	}

	Write-Host "Script complete!" -ForegroundColor Green

} else {
		Write-Host "No input supplied by user"
		Add-Content -Path $logpath -Value ((Get-Date -Format "yyyy/MM/dd HH:mm") + " No input supplied by user")
}
