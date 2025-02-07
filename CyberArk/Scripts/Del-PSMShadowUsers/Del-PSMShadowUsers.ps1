
########################################################
#   Main Script starts here
#   Deletes PSM Shadow users and their profile
#   Abhishek Singh
########################################################

$logpath = ".\Del-PSMShadowUsers.log"

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
if (!(Test-Path $logpath -Type Leaf)) {New-Item -Path $logpath -Type File}
Add-Content -Path $logpath -Value ((Get-Date -Format "yyyy/MM/dd HH:mm") + " Deletion Started")

try{
    $profiles = Get-WmiObject Win32_UserProfile | Where-Object { $_.LocalPath -match '\\Users\\PSM-' -and -not $_.Special }
    foreach ($profile in $profiles) {
        $userProfilePath = $profile.LocalPath
        $sid = $profile.SID
        $userName = $userProfilePath -replace 'C:\\Users\\', ''
        Add-Content -Path $logpath -Value ((Get-Date -Format "yyyy/MM/dd HH:mm") + " Deleting profile for: $userName")
        $profile.Delete()
        if (Test-Path $userProfilePath) {
            Remove-Item -Path $userProfilePath -Recurse -Force -ErrorAction SilentlyContinue
        }
        $regPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\$sid"
        if (Test-Path $regPath) {
            Remove-Item -Path $regPath -Recurse -Force -ErrorAction SilentlyContinue
        }
        if (Get-LocalUser -Name $userName -ErrorAction SilentlyContinue) {
            Add-Content -Path $logpath -Value ((Get-Date -Format "yyyy/MM/dd HH:mm") + " Removing user account: $userName")
            Remove-LocalUser -Name $userName -ErrorAction SilentlyContinue
        }
        Add-Content -Path $logpath -Value ((Get-Date -Format "yyyy/MM/dd HH:mm") + " Profile and user deleted: $userName")
    }
} catch {
  Add-Content -Path $logpath -Value ((Get-Date -Format "yyyy/MM/dd HH:mm") + " An exception has occurred!")
  Add-Content -Path $logpath -Value ((Get-Date -Format "yyyy/MM/dd HH:mm") + " Exception Type: $($_.Exception.GetType().FullName)")
  Add-Content -Path $logpath -Value ((Get-Date -Format "yyyy/MM/dd HH:mm") + " Exception Message: $($_.Exception.Message)")
} finally {
  Add-Content -Path $logpath -Value ((Get-Date -Format "yyyy/MM/dd HH:mm") + " Deletion Completed")
}
