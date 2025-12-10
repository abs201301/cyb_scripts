Add-Type -AssemblyName PresentationCore,PresentationFramework,WindowsBase
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName Microsoft.VisualBasic

# =================== Helper functions used through out the program ===================

function Load-CredStore {
   if (!(Test-Path $CredStorePath)) { return [pscustomobject]@{ creds = @() } }
   $data = Get-Content $CredStorePath -Raw | ConvertFrom-Json
   if (-not $data.creds) { $data | Add-Member -Name creds -Value @() -MemberType NoteProperty -Force }
   if ($data.creds -isnot [System.Array]) { $data.creds = @($data.creds) }
   return $data
}

function Save-CredStore($store) {
   if ($store.creds -isnot [System.Array]) { $store.creds = @($store.creds) }
   $store | ConvertTo-Json -Depth 5 | Set-Content -Path $CredStorePath -Encoding UTF8
}

function Add-Credential {
   # XAML layout for popup window
   $xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
       xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
       Title="Add Credential"
       SizeToContent="WidthAndHeight"
       WindowStartupLocation="CenterOwner"
       ResizeMode="NoResize"
       WindowStyle="ToolWindow">
<Grid Margin="10">
<Grid.RowDefinitions>
<RowDefinition Height="Auto"/>
<RowDefinition Height="Auto"/>
<RowDefinition Height="Auto"/>
<RowDefinition Height="Auto"/>
</Grid.RowDefinitions>
<Grid.ColumnDefinitions>
<ColumnDefinition Width="Auto"/>
<ColumnDefinition Width="200"/>
</Grid.ColumnDefinitions>
<!-- Name -->
<TextBlock Text="Name:" Margin="0,5" VerticalAlignment="Center"/>
<TextBox x:Name="TxtName" Grid.Column="1" Margin="5"/>
<!-- Username -->
<TextBlock Text="Username:" Grid.Row="1" Margin="0,5" VerticalAlignment="Center"/>
<TextBox x:Name="TxtUser" Grid.Row="1" Grid.Column="1" Margin="5"/>
<!-- Password -->
<TextBlock Text="Password:" Grid.Row="2" Margin="0,5" VerticalAlignment="Center"/>
<PasswordBox x:Name="TxtPass" Grid.Row="2" Grid.Column="1" Margin="5"/>
<!-- Buttons -->
<StackPanel Grid.Row="3" Grid.ColumnSpan="2" Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,10,0,0">
<Button x:Name="BtnOK" Width="70" Margin="5">OK</Button>
<Button x:Name="BtnCancel" Width="70" Margin="5">Cancel</Button>
</StackPanel>
</Grid>
</Window>
"@
   $reader = New-Object System.Xml.XmlNodeReader ([xml]$xaml)
   $window = [Windows.Markup.XamlReader]::Load($reader)
   $txtName = $window.FindName("TxtName")
   $txtUser = $window.FindName("TxtUser")
   $txtPass = $window.FindName("TxtPass")
   $btnOK   = $window.FindName("BtnOK")
   $btnCancel = $window.FindName("BtnCancel")
   $result = $null
   $btnOK.Add_Click({
       if ([string]::IsNullOrWhiteSpace($txtName.Text)) {
           [System.Windows.MessageBox]::Show("Name cannot be empty.","Error",[System.Windows.MessageBoxButton]::OK,[System.Windows.MessageBoxImage]::Error) | Out-Null
           return
       }
       $window.Tag  = [pscustomobject]@{
           Name     = $txtName.Text
           Username = $txtUser.Text
           Password = $txtPass.Password
       }
       $window.DialogResult = $true
       $window.Close()
   })
   $btnCancel.Add_Click({
       $window.DialogResult = $false
       $window.Close()
   })
   $window.ShowDialog() | Out-Null
   return $window.Tag
}

function Get-Password {
  param([string]$CredName)
  if (-not (Test-Path $CredStorePath)) { return $null }
  try {
      $store = Get-Content -Raw -Path $CredStorePath | ConvertFrom-Json
  } catch { return $null }
  if (-not $store.creds) { return $null }
  $entry = $store.creds | Where-Object { $_.name -eq $CredName } | Select-Object -First 1
  if (-not $entry) { return $null }
  return $entry.secret
}

function Create-RDPFile {
 param(
     [string]$RdpPath,
     [string]$FullAddress,
     [int]$Port,
     [string]$Username,
     [string]$AltShell,
     [string]$PasswordBlob
 )
 if (-not $RdpPath) { throw "RdpPath required" }
 $blob = $null
 if ($PasswordBlob) {
     $blob = ($PasswordBlob -replace '\s+', '').Trim('"','''')
     if ($blob.Length -lt 16) { Write-Host "Warning: password blob is short ($($blob.Length) chars)" -ForegroundColor Yellow }
 }
 $lines = New-Object System.Collections.Generic.List[string]
 $lines += "full address:s:$FullAddress"
 $lines += "server port:i:$Port"
 $lines += "username:s:$Username"
 if ($AltShell) { $lines += "alternate shell:s:$AltShell" }
 if ($Config.ScreenModeFull) {
    $lines += "screen mode id:i:2"
    $lines += "desktopwidth:i:$($Config.DefaultWidth)"
    $lines += "desktopheight:i:$($Config.DefaultHeight)"
 } else {
    $lines += "screen mode id:i:1"
    $lines += "desktopwidth:i:$($Config.DefaultWidth)"
    $lines += "desktopheight:i:$($Config.DefaultHeight)"
 }
 if ($blob) {
     $lines += "password 51:b:$blob"
     $lines += "prompt for credentials:i:0"
 } else { $lines += "prompt for credentials:i:1" }
 $lines += "enablecredsspsupport:i:$([int]$Config.EnableCredSSP)"
 $lines += "redirectclipboard:i:1"
 $lines += "redirectdrives:i:1"
 $lines += "redirectcomports:i:0"
 $lines += "redirectsmartcards:i:0"
 $lines += "drivestoredirect:s:"
 $lines += "authentication level:i:1"
 $lines += "use multimon:i:0"
 $lines += "span monitors:i:0"
 $encoding = [System.Text.Encoding]::ASCII
 $fs = [System.IO.File]::Open($RdpPath, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
 try {
     $sw = New-Object System.IO.StreamWriter($fs, $encoding)
     foreach ($l in $lines) { $sw.WriteLine($l) }
     $sw.Flush(); $sw.Close()
 } finally { if ($sw) { $sw.Dispose() }; if ($fs) { $fs.Dispose() } }
}

function Delete-RDPFile {
  param([string]$RdpPath)
  if (-not (Test-Path $RdpPath)) { return }
  try {
      Start-Job -ScriptBlock {
          param($file)
          Start-Sleep -Seconds 10
          if (Test-Path $file) { Remove-Item -Path $file -Force -ErrorAction SilentlyContinue }
      } -ArgumentList $RdpPath | Out-Null
  } catch { Write-Warning "Failed to schedule deletion of $RdpPath" }
}

function Launch-PSMSession {
  param(
       [string]$hostName,
       [string]$target,
       [string]$account,
       [string]$connComponent
  )
  $storeDir = Join-Path $ScriptDir "rdp_store"
  if (-not (Test-Path $storeDir)) { New-Item -Path $storeDir -ItemType Directory | Out-Null }
  $rdpPath = Join-Path $storeDir ("PSM-$hostName.rdp")
  $alt = "psm /u $account /a $target /c $connComponent"
  $credName = $ComboCred.SelectedItem
  $blob = Get-Password -CredName $credName
  Create-RDPFile -RdpPath $rdpPath -FullAddress $Config.PSMAddress -Port $Config.PSMPort -Username $username -AltShell $alt -PasswordBlob $blob
  Start-Process -FilePath "mstsc.exe" -ArgumentList "`"$rdpPath`""
  Delete-RDPFile -RdpPath $rdpPath
}

function New-TreeNode {
   param($text, $tagObj)
   $stack = New-Object System.Windows.Controls.StackPanel
   $stack.Orientation = 'Horizontal'
   $chk = New-Object System.Windows.Controls.CheckBox
   $chk.Margin = [System.Windows.Thickness]::new(0,0,6,0)
   $chk.Tag = $tagObj
   $lbl = New-Object System.Windows.Controls.TextBlock
   $lbl.Text = $text
   $lbl.VerticalAlignment = 'Center'
   $stack.Children.Add($chk) | Out-Null
   $stack.Children.Add($lbl) | Out-Null
   $tvi = New-Object System.Windows.Controls.TreeViewItem
   $tvi.Header = $stack
   $tvi.Tag = $tagObj
   $chk.Add_Checked({
       Propagate-CheckedState $tvi $true
       Update-ParentState $tvi
   })
   $chk.Add_Unchecked({
       Propagate-CheckedState $tvi $false
       Update-ParentState $tvi
   })
   return $tvi
}
function Propagate-CheckedState {
   param($treeItem, [bool]$state)
   $header = $treeItem.Header
   if ($header -and $header.Children.Count -gt 0) {
       $cb = $header.Children[0]
       if ($cb -is [System.Windows.Controls.CheckBox]) { $cb.IsChecked = $state }
   }
   foreach ($child in $treeItem.Items) {
       Propagate-CheckedState $child $state
   }
}
function Update-ParentState {
   param($treeItem)
   $parent = $treeItem.Parent
   while ($parent -and ($parent -isnot [System.Windows.Controls.TreeView])) {
       $anyChecked = $false; $anyUnchecked = $false
       foreach ($c in $parent.Items) {
           $h = $c.Header
           if ($h -and $h.Children.Count -gt 0) {
               $cb = $h.Children[0]
               if ($cb.IsChecked) { $anyChecked = $true } else { $anyUnchecked = $true }
           }
       }
       $ph = $parent.Header
       if ($ph -and $ph.Children.Count -gt 0) {
           $pcb = $ph.Children[0]
           if ($anyChecked) { $pcb.IsChecked = $true } else { $pcb.IsChecked = $false }
       }
       $parent = $parent.Parent
   }
}

function Populate-Tree {
   $Tree.Items.Clear()
   $groups = $Servers | Group-Object -Property category
   foreach ($g in $groups) {
       $catItem = New-TreeNode -text $g.Name -tagObj $null
       $comps = $g.Group | Group-Object -Property component
       foreach ($c in $comps) {
           $compItem = New-TreeNode -text $c.Name -tagObj $null
           foreach ($p in $c.Group) {
               $leaf = New-TreeNode -text $p.name -tagObj $p
               $compItem.Items.Add($leaf) | Out-Null
           }
           $catItem.Items.Add($compItem) | Out-Null
       }
       $Tree.Items.Add($catItem) | Out-Null
       $catItem.IsExpanded = $true
   }
   $LblStatus.Content = "Loaded $($Tree.Items.Count) categories."
}

function Populate-CredCombo {
   $ComboCred.Items.Clear()
   $store = Load-CredStore
   if ($null -eq $store.creds) { $store.creds = @() }
   if ($store.creds -is [System.Management.Automation.PSCustomObject]) {
       $store.creds = ,$store.creds
   }
   foreach ($c in $store.creds) {
       if ($null -ne $c -and $c.name) {
           $ComboCred.Items.Add($c.name) | Out-Null
       }
   }
   if ($ComboCred.Items.Count -gt 0) {
       if ($null -eq $ComboCred.SelectedItem) { $ComboCred.SelectedIndex = 0 }
   }
}

####################################################################################
## Main script starts here - script will terminate if any errors are encountered
## Developed by: © Abhishek Singh
## Description:
##   - Uses servers.json and creds.json in script folder
##   - Generates .rdp files with embedded DPAPI blob for credentials
##   - Launches mstsc.exe for selected hosts
##   - Deletes RDP file using Start-Job
####################################################################################

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$jsonPath = Join-Path $ScriptDir 'servers.json'
$CredStorePath = Join-Path $ScriptDir 'creds.json'
$username = (whoami) -split '\\' | Select-Object -Last 1
if (-not (Test-Path $jsonPath)) {
   [System.Windows.MessageBox]::Show("servers.json not found in script folder: $ScriptDir","Missing file",[System.Windows.MessageBoxButton]::OK,[System.Windows.MessageBoxImage]::Error)
   throw "servers.json missing"
}

$jsonData = Get-Content -Raw -Path $jsonPath | ConvertFrom-Json
$Config = $jsonData.Config
$Servers = $jsonData.Servers

[xml]$xaml = Get-Content (Join-Path $ScriptDir 'Window.xaml')
$reader = New-Object System.Xml.XmlNodeReader $xaml
$Window = [Windows.Markup.XamlReader]::Load($reader)
$Tree        = $Window.FindName("TreeServers")
$ComboComp   = $Window.FindName("ComboComp")
$ComboCred   = $Window.FindName("ComboCred")
$BtnAddCred  = $Window.FindName("BtnAddCred")
$BtnRemoveCred = $Window.FindName("BtnRemoveCred")
$BtnCheckAll = $Window.FindName("BtnCheckAll")
$BtnUncheckAll = $Window.FindName("BtnUncheckAll")
$BtnReload   = $Window.FindName("BtnReload")
$BtnLaunch   = $Window.FindName("BtnLaunch")
$BtnClose    = $Window.FindName("BtnClose")
$LblStatus   = $Window.FindName("LblStatus")

$ComboComp.Items.Clear()
foreach ($cc in $Config.ConnectionComponents) {
   $ComboComp.Items.Add($cc) | Out-Null
}
if ($Config.DefaultComponent) { $ComboComp.SelectedItem = $Config.DefaultComponent } elseif ($ComboComp.Items.Count -gt 0) { $ComboComp.SelectedIndex = 0 }

Populate-Tree
Populate-CredCombo

$BtnAddCred.Add_Click({
   $cred = Add-Credential
   if (-not $cred) { return }
   $store = Load-CredStore
   if (-not $store.creds) { $store.creds = @() }
   if ($store.creds | Where-Object { $_.name -and ($_.name -ieq $cred.Name) }) {
       [System.Windows.MessageBox]::Show("A credential named '$($cred.Name)' already exists.","Duplicate",[System.Windows.MessageBoxButton]::OK,[System.Windows.MessageBoxImage]::Warning) | Out-Null
       return
   }
   try {
       $secure = ConvertTo-SecureString -String $cred.Password -AsPlainText -Force
       $enc = $secure | ConvertFrom-SecureString
   } catch {
       [System.Windows.MessageBox]::Show("Failed to encrypt password: $($_.Exception.Message)","Error",[System.Windows.MessageBoxButton]::OK,[System.Windows.MessageBoxImage]::Error) | Out-Null
       return
   }
   if ($null -eq $store.creds) { $store.creds = @() }
   $store.creds += [pscustomobject]@{
       name = $cred.Name
       user = $cred.Username
       secret = $enc
   }
   Save-CredStore $store
   Populate-CredCombo
   $ComboCred.SelectedItem = $cred.Name
   [System.Windows.MessageBox]::Show("Credential saved successfully.","Success",[System.Windows.MessageBoxButton]::OK,[System.Windows.MessageBoxImage]::Information) | Out-Null
})

$BtnRemoveCred.Add_Click({
 $sel = $ComboCred.SelectedItem
 if (-not $sel) { return }
 if ([System.Windows.MessageBox]::Show("Remove credential '$sel' ?","Confirm",[System.Windows.MessageBoxButton]::YesNo,[System.Windows.MessageBoxImage]::Question) -eq [System.Windows.MessageBoxResult]::Yes) {
     $store = Load-CredStore
     $store.creds = $store.creds | Where-Object { $_.name -ne $sel }
     Save-CredStore $store
     Populate-CredCombo
 }
})

$BtnCheckAll.Add_Click({ foreach ($t in $Tree.Items) { Propagate-CheckedState $t $true }})
$BtnUncheckAll.Add_Click({ foreach ($t in $Tree.Items) { Propagate-CheckedState $t $false }})
$BtnReload.Add_Click({
  try {
      $jsonData = Get-Content -Raw -Path $jsonPath | ConvertFrom-Json
      $Config = $jsonData.Config
      $Servers = $jsonData.Servers
      Populate-Tree
      $LblStatus.Content = "Reloaded."
  } catch { [System.Windows.MessageBox]::Show("Failed to reload JSON: $($_.Exception.Message)") }
})

$BtnClose.Add_Click({ $Window.Close() })
$BtnLaunch.Add_Click({
   $connComponent = $ComboComp.SelectedItem
   $credName = $ComboCred.SelectedItem
   if (-not $connComponent -or -not $credName) { [System.Windows.MessageBox]::Show("Select component and credential."); return }
   $selected = @()
   foreach ($cat in $Tree.Items) {
       foreach ($comp in $cat.Items) {
           foreach ($leaf in $comp.Items) {
               $h = $leaf.Header
               if ($h -and $h.Children.Count -gt 0) {
                   $cb = $h.Children[0]
                   if ($cb.IsChecked -and $leaf.Tag) { $selected += $leaf.Tag }
               }
           }
       }
   }
   if (-not $selected) { [System.Windows.MessageBox]::Show("No hosts selected."); return }
   foreach ($p in $selected) {
       Launch-PSMSession -hostName $p.name -target $p.target -account $p.targetAccount -connComponent $connComponent
       Start-Sleep -Milliseconds 200
   }
   $LblStatus.Content = "Launched $($selected.Count) session(s)."
})

$Window.Add_SourceInitialized({ $null })
[void]$Window.ShowDialog()
