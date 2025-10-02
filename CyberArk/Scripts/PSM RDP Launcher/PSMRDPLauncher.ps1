Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName Microsoft.VisualBasic

# ---------------- Populate helpers ----------------
function Populate-Tree {
   $tree.Nodes.Clear()
   $groups = $Servers | Group-Object -Property category
   foreach ($g in $groups) {
       $catNode = New-Object System.Windows.Forms.TreeNode($g.Name)
       $tree.Nodes.Add($catNode) | Out-Null
       $comps = $g.Group | Group-Object -Property component
       foreach ($c in $comps) {
           $compNode = New-Object System.Windows.Forms.TreeNode($c.Name)
           $catNode.Nodes.Add($compNode) | Out-Null
           foreach ($p in $c.Group) {
               $leaf = New-Object System.Windows.Forms.TreeNode($p.name)
               $leaf.Tag = $p
               $compNode.Nodes.Add($leaf) | Out-Null
           }
       }
       $catNode.Expand()
   }
   $lblStatus.Text = "Loaded $($tree.GetNodeCount($true)) nodes."
}
function Populate-CredCombo {
   $comboCred.Items.Clear()
   $store = Load-CredStore
   foreach ($c in $store.creds) { $comboCred.Items.Add($c.name) }
   if ($comboCred.Items.Count -gt 0) { $comboCred.SelectedIndex = 0 }
}

# --------------------------- Credential helpers ---------------------------
function Load-CredStore {
   if (-not (Test-Path $CredStorePath)) { return @{ creds = @() } }
   try { return Get-Content -Path $CredStorePath -Raw | ConvertFrom-Json } catch { return @{ creds = @() } }
}
function Save-CredStore { param($o) ; $o | ConvertTo-Json -Depth 4 | Set-Content -Path $CredStorePath -Encoding UTF8 }
function Get-OrCreateCredential {
   param([string]$Name, [string]$User, [switch]$Force)
   $store = Load-CredStore
   if (-not $store.creds) { $store.creds = @() }
   $entry = $store.creds | Where-Object { $_.name -eq $Name } | Select-Object -First 1
   if ($Force -or -not $entry) {
       $sec = Read-Host -Prompt "Enter password for $User" -AsSecureString
       if (-not $sec) { throw "No password entered." }
       $enc = $sec | ConvertFrom-SecureString
       $new = [PSCustomObject]@{ name = $Name; user = $User; secret = $enc }
       $store.creds = $store.creds | Where-Object { $_.name -ne $Name }
       $store.creds += $new
       Save-CredStore $store
       $entry = $new
       Write-Host "Saved credential '$Name'."
   }
   return $entry
}
function Get-CredPlain {
   param([string]$encString)
   if (-not $encString) { return $null }
   $sec = $encString | ConvertTo-SecureString
   $ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)
   try { return [Runtime.InteropServices.Marshal]::PtrToStringAuto($ptr) } finally { if ($ptr) { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr) } }
}
function Get-Password {
   param(
        [string]$CredName
   )
   if (-not (Test-Path $CredStorePath)) { return $null }
   try {
       $store = Get-Content -Raw -Path $CredStorePath | ConvertFrom-Json
   } catch { return $null }
   if (-not $store.creds) { return $null }
   $entry = $store.creds | Where-Object { $_.name -eq $CredName } | Select-Object -First 1
   if (-not $entry) { return $null }
   return $entry.secret
}
# --------------------------- PSM RDP file ---------------------------
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
  # Write-Host "Wrote RDP file: $RdpPath" -ForegroundColor Green
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
   $credName = $comboCred.SelectedItem
   $blob = Get-Password -CredName $credName
   Create-RDPFile -RdpPath $rdpPath -FullAddress $Config.PSMAddress -Port $Config.PSMPort -Username $Config.LANID -AltShell $alt -PasswordBlob $blob
   Start-Process -FilePath "mstsc.exe" -ArgumentList "`"$rdpPath`""
   Delete-RDPFile -RdpPath $rdpPath
}

function Delete-RDPFile {
   param([string]$RdpPath)
   if (-not (Test-Path $RdpPath)) { return }
   try {
       # Start-Job to delete asynchronously
       Start-Job -ScriptBlock {
           param($file)
           Start-Sleep -Seconds 10   # give mstsc time to read file
           if (Test-Path $file) { Remove-Item -Path $file -Force -ErrorAction SilentlyContinue }
       } -ArgumentList $RdpPath | Out-Null
   } catch { Write-Warning "Failed to schedule deletion of $RdpPath" }
}

####################################################################################
## Main script starts here - script will terminate if any errors are encountered
## Developed by: © Abhishek Singh (adapted)
## Description:
##   - Uses servers.json and creds.json in script folder
##   - Generates .rdp files with embedded DPAPI blob for credentials
##   - Launches mstsc.exe for selected hosts
####################################################################################

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$jsonPath = Join-Path $ScriptDir 'servers.json'
$CredStorePath = Join-Path $ScriptDir 'creds.json'

if (-not (Test-Path $jsonPath)) {
   [System.Windows.Forms.MessageBox]::Show("servers.json not found in script folder: $ScriptDir","Missing file",[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Error)
   throw "servers.json missing"
}

# --------------------------- Load json data ---------------------------
$jsonData = Get-Content -Raw -Path $jsonPath | ConvertFrom-Json
$Config = $jsonData.Config
$Servers = $jsonData.Servers
# --------------------------- Build GUI form ---------------------------
$form = New-Object System.Windows.Forms.Form
$form.Text = "PSM RDP Launcher"
$form.Size = New-Object Drawing.Size(880,700)
$form.StartPosition = "CenterScreen"

# Top panel
$panelTop = New-Object System.Windows.Forms.Panel
$panelTop.Location = New-Object System.Drawing.Point(8,8)
$panelTop.Size = New-Object System.Drawing.Size(860,80)
$form.Controls.Add($panelTop)
$lblComp = New-Object System.Windows.Forms.Label
$lblComp.Text = "Connection component:"
$lblComp.Location = New-Object System.Drawing.Point(4,8)
$lblComp.Size = New-Object System.Drawing.Size(140,20)
$panelTop.Controls.Add($lblComp)
$comboComp = New-Object System.Windows.Forms.ComboBox
$comboComp.Location = New-Object System.Drawing.Point(150,6)
$comboComp.Size = New-Object System.Drawing.Size(200,22)
$comboComp.DropDownStyle = 'DropDownList'
$Config.ConnectionComponents | ForEach-Object { $comboComp.Items.Add($_) }
$comboComp.SelectedItem = $Config.DefaultComponent
$panelTop.Controls.Add($comboComp)
$lblCred = New-Object System.Windows.Forms.Label
$lblCred.Text = "Credential:"
$lblCred.Location = New-Object System.Drawing.Point(370,8)
$lblCred.Size = New-Object System.Drawing.Size(70,20)
$panelTop.Controls.Add($lblCred)
$comboCred = New-Object System.Windows.Forms.ComboBox
$comboCred.Location = New-Object System.Drawing.Point(445,6)
$comboCred.Size = New-Object System.Drawing.Size(220,22)
$comboCred.DropDownStyle = 'DropDownList'
$panelTop.Controls.Add($comboCred)
$btnAddCred = New-Object System.Windows.Forms.Button
$btnAddCred.Text = "Add Cred"
$btnAddCred.Location = New-Object System.Drawing.Point(675,4)
$btnAddCred.Size = New-Object System.Drawing.Size(80,24)
$panelTop.Controls.Add($btnAddCred)
$btnRemoveCred = New-Object System.Windows.Forms.Button
$btnRemoveCred.Text = "Remove"
$btnRemoveCred.Location = New-Object System.Drawing.Point(760,4)
$btnRemoveCred.Size = New-Object System.Drawing.Size(80,24)
$panelTop.Controls.Add($btnRemoveCred)

# TreeView
$tree = New-Object System.Windows.Forms.TreeView
$tree.Location = New-Object System.Drawing.Point(8,96)
$tree.Size = New-Object System.Drawing.Size(860,480)
$tree.CheckBoxes = $true
$form.Controls.Add($tree)

# Bottom panel
$panelBottom = New-Object System.Windows.Forms.Panel
$panelBottom.Location = New-Object System.Drawing.Point(8,580)
$panelBottom.Size = New-Object System.Drawing.Size(860,80)
$form.Controls.Add($panelBottom)
$btnCheckAll = New-Object System.Windows.Forms.Button
$btnCheckAll.Text = "Check All"
$btnCheckAll.Location = New-Object System.Drawing.Point(0,8); $btnCheckAll.Size = New-Object System.Drawing.Size(100,28)
$panelBottom.Controls.Add($btnCheckAll)
$btnUncheck = New-Object System.Windows.Forms.Button
$btnUncheck.Text = "Uncheck All"
$btnUncheck.Location = New-Object System.Drawing.Point(110,8); $btnUncheck.Size = New-Object System.Drawing.Size(100,28)
$panelBottom.Controls.Add($btnUncheck)
$btnReload = New-Object System.Windows.Forms.Button
$btnReload.Text = "Reload JSON"
$btnReload.Location = New-Object System.Drawing.Point(220,8); $btnReload.Size = New-Object System.Drawing.Size(100,28)
$panelBottom.Controls.Add($btnReload)
$btnLaunch = New-Object System.Windows.Forms.Button
$btnLaunch.Text = "OK - Launch Selected"
$btnLaunch.Location = New-Object System.Drawing.Point(420,8); $btnLaunch.Size = New-Object System.Drawing.Size(150,32)
$panelBottom.Controls.Add($btnLaunch)
$btnClose = New-Object System.Windows.Forms.Button
$btnClose.Text = "Close"
$btnClose.Location = New-Object System.Drawing.Point(580,8); $btnClose.Size = New-Object System.Drawing.Size(100,32)
$panelBottom.Controls.Add($btnClose)
$lblStatus = New-Object System.Windows.Forms.Label
$lblStatus.Text = ""
$lblStatus.Location = New-Object System.Drawing.Point(0,46); $lblStatus.Size = New-Object System.Drawing.Size(780,28)
$panelBottom.Controls.Add($lblStatus)

Populate-Tree
Populate-CredCombo

# ---------------- Event handlers ----------------
$btnAddCred.Add_Click({
  $credName = [Microsoft.VisualBasic.Interaction]::InputBox("Credential name (friendly):","Add Credential",$Config.LANID)
  if (-not $credName) { return }
  $user = [Microsoft.VisualBasic.Interaction]::InputBox("Username (domain\user or UPN):","Add Credential",$Config.LANID)
  if (-not $user) { return }
  try { Get-OrCreateCredential -Name $credName -User $user -Force; Populate-CredCombo } catch { [System.Windows.Forms.MessageBox]::Show("Failed to save credential: $($_.Exception.Message)") }
})
$btnRemoveCred.Add_Click({
  $sel = $comboCred.SelectedItem
  if (-not $sel) { return }
  if ([System.Windows.Forms.MessageBox]::Show("Remove credential '$sel' ?","Confirm",[System.Windows.Forms.MessageBoxButtons]::YesNo,[System.Windows.Forms.MessageBoxIcon]::Question) -eq [System.Windows.Forms.DialogResult]::Yes) {
      $store = Load-CredStore
      $store.creds = $store.creds | Where-Object { $_.name -ne $sel }
      Save-CredStore $store
      Populate-CredCombo
  }
})
$tree.Add_AfterCheck({
   param($s,$e)
   if ($e.Action -ne [System.Windows.Forms.TreeViewAction]::Unknown) {
       foreach ($child in $e.Node.Nodes) { $child.Checked = $e.Node.Checked }
       $parent = $e.Node.Parent
       while ($parent) { if ($e.Node.Checked) { $parent.Checked = $true }; $parent = $parent.Parent }
   }
})
$btnCheckAll.Add_Click({
   foreach ($n in $tree.Nodes) { $n.Checked = $true; foreach ($c in $n.Nodes) { $c.Checked = $true; foreach ($leaf in $c.Nodes) { $leaf.Checked = $true } } }
})
$btnUncheck.Add_Click({
   foreach ($n in $tree.Nodes) { $n.Checked = $false; foreach ($c in $n.Nodes) { $c.Checked = $false; foreach ($leaf in $c.Nodes) { $leaf.Checked = $false } } }
})
$btnReload.Add_Click({
   try {
       $jsonData = Get-Content -Raw -Path $jsonPath | ConvertFrom-Json
       $Config = $jsonData.Config
       $Servers = $jsonData.Servers
       Populate-Tree
       $lblStatus.Text = "Reloaded."
   } catch { [System.Windows.Forms.MessageBox]::Show("Failed to reload JSON: $($_.Exception.Message)") }
})
$btnClose.Add_Click({ $form.Close() })

# ---------------- Launch handler ----------------
$btnLaunch.Add_Click({
   $connComponent = $comboComp.SelectedItem
   $credName = $comboCred.SelectedItem
   if (-not $connComponent -or -not $credName) { [System.Windows.Forms.MessageBox]::Show("Select component and credential."); return }
   $selected = @()
   foreach ($cat in $tree.Nodes) {
       foreach ($comp in $cat.Nodes) {
           foreach ($leaf in $comp.Nodes) {
               if ($leaf.Checked -and $leaf.Tag) { $selected += $leaf.Tag }
           }
       }
   }
   if (-not $selected) { [System.Windows.Forms.MessageBox]::Show("No hosts selected."); return }
   foreach ($p in $selected) {
       Launch-PSMSession -hostName $p.name -target $p.target -account $p.targetAccount -connComponent $connComponent
       Start-Sleep -Milliseconds 200
   }
   $lblStatus.Text = "Launched $($selected.Count) session(s)."
})

# Display GUI
$form.Add_Shown({ $form.Activate() })
[void]$form.ShowDialog()
