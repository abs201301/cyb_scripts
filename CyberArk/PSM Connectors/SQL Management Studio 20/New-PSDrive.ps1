# Function to return drives mapped by CyberArk
Function Get-CyberArkMappedDrives {
   $MappedDrives = @{}
   $Output = net use | Select-String "\\\\tsclient\\"
   foreach ($Line in $Output) {
       if ($Line -match "(\w:)\s+\\\\tsclient\\(\w)") {
           $MappedDrives[$Matches[2].ToUpper()] = $Matches[1]
       }
   }
   Write-Log "Detected CyberArk Mapped Drives: $($MappedDrives | Out-String)"
   return $MappedDrives
}

# Function to Get All Redirected Drives
Function Get-RedirectedDrives {
   $RedirectedDrives = @()
   $DriveLetters = [char[]](65..90)
   foreach ($Drive in $DriveLetters) {
       $Path = "\\tsclient\$Drive"
       if (Test-Path $Path) {
           $RedirectedDrives += [string]$Drive
       }
   }
   Write-Log "Redirected Drives Detected: $($RedirectedDrives -join ', ')"
   return $RedirectedDrives
}

# Function to Find Available Drive Letter (Reverse Order: Z to E, mimics what CyberArk does)
Function Get-AvailableDriveLetter {
   $AvailableLetters = [char[]](90..69)
   foreach ($Letter in $AvailableLetters) {
       if (!(Test-Path "$Letter`:")) {
           return [string]$Letter
       }
   }
   return $null
}

# Function to Map drives missed by CyberArk
Function Map-Drive {
   param ($Drive)
   if ($CyberArkDrives.ContainsKey($Drive)) {
       Write-Log "Drive $Drive is already mapped by CyberArk as $($CyberArkDrives[$Drive]). Skipping..."
       return
   }
   # Find an available drive letter
   $Letter = Get-AvailableDriveLetter
   if (-not $Letter) {
       Write-Log "ERROR: No available drive letters to map $Drive."
       return
   }
   $RemotePath = "\\tsclient\$Drive"
   $Label = "$Drive drive on $ClientName"
   Write-Log "Attempting to map $RemotePath to $Letter`:"
   $Attempt = 1
   While ($Attempt -le $MaxRetries) {
       if (!(Test-Path "$Letter`:")) {
           New-PSDrive -Name $Letter -PSProvider FileSystem -Root $RemotePath -Persist -ErrorAction SilentlyContinue
       }
       if (Test-Path "$Letter`:\") {
           Write-Log "Successfully mapped $RemotePath to $Letter`:"
           powershell -command "(New-Object -ComObject Shell.Application).NameSpace('$Letter`:').Self.Name = '$Label'"
           return
       }
       Write-Log "Attempt ${Attempt}: Failed to map $RemotePath to $Letter`:. Retrying..."
       Start-Sleep -Seconds $RetryDelay
       $Attempt++
   }
   Write-Log "ERROR: Could not map $RemotePath to $Letter`:"
}


################################################
## Main script starts here
## Maps local drives to Remote CyberArk session
## Abhishek Singh
################################################


$LogFile = ".\DriveMapping.Log"
$MaxRetries = 5
$RetryDelay = 2

# Create log file and start logging
New-Item -ItemType File -Path $LogFile -Force | Out-Null
Function Write-Log { Param ($Message) $Message | Out-File -FilePath $LogFile -Append }
Write-Log "========== Drive Mapping Script Started =========="

# Get the client machine name (source system)
$ClientName = $env:COMPUTERNAME

# Get CyberArk's existing drive mappings
$CyberArkDrives = Get-CyberArkMappedDrives

# Get all redirected drives and map them if necessary
$RedirectedDrives = Get-RedirectedDrives
foreach ($Drive in $RedirectedDrives) {
   Map-Drive -Drive $Drive
}

Write-Log "========== Drive Mapping Script Completed =========="
# Return log content for AutoIt
Get-Content -Path $LogFile
