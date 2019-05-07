#Requires         -Version 4
Param (
    [string]$ManagementServer
)

Set-StrictMode    -Version 2
Remove-Variable * -Exclude ManagementServer -ErrorAction SilentlyContinue
Clear-Host

Write-Host ''
[string]$script:appName = ' SCOM Maintenance Mode Tool'
Write-Host "  Starting$script:appName..."

[Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms') | Out-Null
[Reflection.Assembly]::LoadWithPartialName('System.Data')          | Out-Null
[Reflection.Assembly]::LoadWithPartialName('System.Drawing')       | Out-Null
[System.Drawing.Font]$sysFont     = [System.Drawing.SystemFonts]::MessageBoxFont
[System.Drawing.Font]$sysFontBold = New-Object 'System.Drawing.Font' ($sysFont.Name, $sysFont.SizeInPoints, [System.Drawing.FontStyle]::Bold)
[System.Windows.Forms.Application]::EnableVisualStyles()
[System.Collections.ArrayList]$script:objectList = @()    # Holds all SCOM Server Objects
[boolean]$script:Verified = $false
[string] $script:GroupBy  = 'Domain Name'    # Default 'Group By' option

[System.Windows.Forms.TabPage]$script:tb1 = $null    # Holds
[System.Windows.Forms.TabPage]$script:tb2 = $null    # The
[System.Windows.Forms.TabPage]$script:tb3 = $null    # Tab
[System.Windows.Forms.TabPage]$script:tb4 = $null    # Pages

###################################################################################################
##                                                                                               ##
##   Functions                                                                                   ##
##                                                                                               ##
###################################################################################################
Function Write-Log ([string]$Message)
{
    Add-Content -Path 'SCOM-MaintenanceMode.Log' -Value $Message
}

Function Load-MaintenanceModeReasons
{
    # Maintenance Mode Reason (Planned And Unplanned)
    [hashtable]$script:mmReasonP = @{
        'Other'                             = [Microsoft.EnterpriseManagement.Monitoring.MaintenanceModeReason]::PlannedOther ;
        'Hardware: Maintenance'             = [Microsoft.EnterpriseManagement.Monitoring.MaintenanceModeReason]::PlannedHardwareMaintenance ;
        'Hardware: Installation'            = [Microsoft.EnterpriseManagement.Monitoring.MaintenanceModeReason]::PlannedHardwareInstallation ;
        'Operating System: Reconfiguration' = [Microsoft.EnterpriseManagement.Monitoring.MaintenanceModeReason]::PlannedOperatingSystemReconfiguration ;
        'Application: Maintenance'          = [Microsoft.EnterpriseManagement.Monitoring.MaintenanceModeReason]::PlannedApplicationMaintenance ;
        'Application: Installation'         = [Microsoft.EnterpriseManagement.Monitoring.MaintenanceModeReason]::ApplicationInstallation ;
        'Security Issue'                    = [Microsoft.EnterpriseManagement.Monitoring.MaintenanceModeReason]::SecurityIssue
    }

    [hashtable]$script:mmReasonU = @{
        'Other'                             = [Microsoft.EnterpriseManagement.Monitoring.MaintenanceModeReason]::UnplannedOther ;
        'Hardware: Maintenance'             = [Microsoft.EnterpriseManagement.Monitoring.MaintenanceModeReason]::UnplannedHardwareMaintenance ;
        'Hardware: Installation'            = [Microsoft.EnterpriseManagement.Monitoring.MaintenanceModeReason]::UnplannedHardwareInstallation ;
        'Operating System: Reconfiguration' = [Microsoft.EnterpriseManagement.Monitoring.MaintenanceModeReason]::UnplannedOperatingSystemReconfiguration ;
        'Application: Maintenance'          = [Microsoft.EnterpriseManagement.Monitoring.MaintenanceModeReason]::UnplannedApplicationMaintenance ;
        'Application: Unresponsive'         = [Microsoft.EnterpriseManagement.Monitoring.MaintenanceModeReason]::ApplicationUnresponsive ;
        'Application: Unstable'             = [Microsoft.EnterpriseManagement.Monitoring.MaintenanceModeReason]::ApplicationUnstable ;
        'Loss Of Network Connectivity'      = [Microsoft.EnterpriseManagement.Monitoring.MaintenanceModeReason]::LossOfNetworkConnectivity
    }
}

Function Update-ServerList
{
    $script:objectList.Clear()
    $objects = (Get-SCOMMonitoringObject -Class (Get-SCOMClass -DisplayName 'Computer') | Select-Object Id, DisplayName, HealthState, IsAvailable, InMaintenanceMode)

    ForEach ($item In $objects)
    {
        $lstItem = New-Object 'System.Windows.Forms.ListViewItem'
        $lstItem.Name       = $item.Id
        $lstItem.Text       = $item.DisplayName.Split('.')[0].ToLower()
        $lstItem.Checked    = $false

        Switch ($item.HealthState)
        {
            'Success'       { If ($item.IsAvailable -eq $True) { $lstItem.ImageIndex =  1 } Else { $lstItem.ImageIndex = 2 }; Break }
            'Warning'       {                                    $lstItem.ImageIndex =  3                                   ; Break }
            'Error'         {                                    $lstItem.ImageIndex =  4                                   ; Break }
            'Uninitialized' {                                    $lstItem.ImageIndex =  5                                   ; Break }
            Default         {                                    $lstItem.ImageIndex = -1                                           }
        }

        # SubItems[1] = Maintenance Mode
        If ($item.InMaintenanceMode -eq $True) { $lstItem.SubItems.Add('ICON|6') } Else { $lstItem.SubItems.Add('') }

        # SubItems[2] = Domain Name
        If ($item.DisplayName.Contains('.')) { $lstItem.SubItems.Add($item.DisplayName.SubString($lstItem.Text.Length).ToLower()) } Else { $lstItem.SubItems.Add(' No Domain') }

        $script:objectList.Add($lstItem)
        $lstItem = $null
    }
    $objects = $null
    If ($tab_Pages.SelectedTab -eq $script:tb4) { Search-ServerList -SearchString $txt_t4_01.Text }
}

Function Search-ServerList ([string]$SearchString)
{
    If ($SearchString.Length -eq      1) { Return }
    If ([string]::IsNullOrEmpty($script:objectList) -eq $True)
    {
        $lst_t4_01.Items.Clear()
        $lst_t4_01.ShowGroups = $False
		$lst_t4_01.CheckBoxes = $False
		$lst_t4_01.Items.Add("N", "", -1)
        $lst_t4_01.Items.Add("N", "Server list has not yet been retrieved.", -1)
        $lst_t4_01.Items.Add("N", "Click 'Update List' below...", -1)
        $lst_t4_01.Enabled = $False
        Return
    }

    Switch ($SearchString.ToLower())
    {
        '!s'    { $found = ($script:objectList | Where-Object { ($_.ImageIndex       -eq 1) -or ($_.ImageIndex -eq 2)  }); Break }
        '!w'    { $found = ($script:objectList | Where-Object {  $_.ImageIndex       -eq 3                             }); Break }
        '!e'    { $found = ($script:objectList | Where-Object {  $_.ImageIndex       -eq 4                             }); Break }
        '!u'    { $found = ($script:objectList | Where-Object {  $_.ImageIndex       -eq 5                             }); Break }
        '!m'    { $found = ($script:objectList | Where-Object {  $_.SubItems[1].Text -eq 'ICON|6'                      }); Break }
        '!c'    { $found = ($script:objectList | Where-Object {  $_.Checked          -eq $True                         }); Break }
        Default { $found = ($script:objectList | Where-Object {  $_.Text.ToLower()   -like "*$SearchString*".ToLower() })        }
    }

    $lst_t4_01.Items.Clear()
    If ([string]::IsNullOrEmpty($found) -eq $True)
    {
        $lst_t4_01.Enabled    = $False
        $lst_t4_01.ShowGroups = $False
		$lst_t4_01.CheckBoxes = $False
		$lst_t4_01.Items.Add("N", "", -1)
		$lst_t4_01.Items.Add("N", "No servers match your search query.", -1)
    }
    Else
    {
        $lst_t4_01.Enabled    = $True
        $lst_t4_01.ShowGroups = $True
		$lst_t4_01.CheckBoxes = $True
        $lst_t4_01.Items.AddRange($found)
    }

    $lbl_t4_02.Text = "$($lst_t4_01.Items.Count) Shown`r`n$($script:objectList.Count) Total"
    Group-SearchResults -ByType $script:GroupBy
}

Function Get-Reason ([string]$Reason, [boolean]$Planned)
{
    $return = New-Object 'Microsoft.EnterpriseManagement.Monitoring.MaintenanceModeReason'
    If ($Planned -eq $True) { $return = $script:mmReasonP[$Reason] } Else { $return = $script:mmReasonU[$Reason] }
    Return $return
}

Function Get-HealthStatus ([string]$Value)
{
    Switch ($Value)
    {
        '1'     { Return 'Success'       }    # Green Tick
        '2'     { Return 'Not Monitored' }    # GreyScale Tick
        '3'     { Return 'Warning'       }    # Yellow Triangle
        '4'     { Return 'Error'         }    # Red Cross
        '5'     { Return 'Uninitialized' }    # Hollow Circle
        Default { Return 'Unknown'       }    # Eh.?
    }
}

Function Group-SearchResults ([string]$ByType)
{
    If ($lst_t4_01.Items.Count   -eq   0) { Return }    # Empty List
    If ($lst_t4_01.Items[0].Name -eq 'N') { Return }    # No Search Results

    $Groups = New-Object 'System.Collections.ArrayList'
    $lst_t4_01.Groups.Clear()

    If ($ByType -ne 'None')
    {
        $lst_t4_01.ShowGroups = $True
        ForEach ($item In $lst_t4_01.Items)
        {
            Switch ($ByType)
            {
                'Domain Name'   { $Groups.Add($item.SubItems[2].Text); Break }
                'Health Status' { $Groups.Add((Get-HealthStatus -Value $item.ImageIndex)); Break }
            }
        }

        $Groups = $Groups | Select-Object -Unique | Sort-Object
        $Groups | ForEach { $lst_t4_01.Groups.Add($_, ($_.TrimStart('.'))) }

        ForEach ($item In $lst_t4_01.Items)
        {
            Switch ($ByType)
            {
                'Domain Name'   { $item.Group = $lst_t4_01.Groups[$item.SubItems[2].Text]; Break }
                'Health Status' { $item.Group = $lst_t4_01.Groups[(Get-HealthStatus -Value $item.ImageIndex)]; Break }
            }
        }
    }
    Else
    {
        $lst_t4_01.ShowGroups = $False
    }
} 

###################################################################################################
# Owner Draw ListView Sub Icons ###################################################################
$SubIcons_DrawColumnHeader = {
    [System.Windows.Forms.DrawListViewColumnHeaderEventArgs]$e = $_
    $e.DrawDefault = $True
    $e.DrawBackground()
    $e.DrawText()
}
$SubIcons_DrawSubItem = {
    [System.Windows.Forms.DrawListViewSubItemEventArgs]$e = $_

    If ($e.SubItem.Text.Length -le 5) {
        $e.DrawDefault = $True
    }
    Else
    {
        If ($e.SubItem.Text.Contains('|') -eq $True)
        {
            [System.Drawing.Image]$icon = ($imgList_Search.Images[$e.SubItem.Text.Split('|')[1] -as [int]])
            [int]$xPos = ($e.SubItem.Bounds.X + (($e.SubItem.Bounds.Width  / 2) -as [int]) - (($icon.Width  / 2) -as [int]))
            [int]$yPos = ($e.SubItem.Bounds.Y + (($e.SubItem.Bounds.Height / 2) -as [int]) - (($icon.Height / 2) -as [int]))
        }

        If ($e.Item.Selected -eq $true) {
            $r = New-Object 'System.Drawing.Rectangle'($e.Bounds.Left, $e.Bounds.Top, $e.Bounds.Width, $e.Bounds.Height)
            $e.Graphics.FillRectangle([System.Drawing.SystemBrushes]::Highlight, $r)
            $e.Item.ForeColor = [System.Drawing.SystemColors]::HighlightText
        }
        Else {
            $e.Item.ForeColor = [System.Drawing.SystemColors]::WindowText
        }

        Switch ($e.SubItem.Text.Substring(0,5).ToUpper())
        {
            'ICON|'
            {
                $e.DrawDefault = $false
                $r = New-Object 'System.Drawing.Rectangle'($xPos, $yPos, $icon.Width, $icon.Height)
                $e.Graphics.DrawImage($icon, $r)
            }

            Default { $e.DrawDefault = $True }
        }
    }
}

###################################################################################################
##                                                                                               ##
##   Main Form                                                                                   ##
##                                                                                               ##
###################################################################################################
#region Main Form
Function Display-MainForm
{
#region FORM STARTUP / SHUTDOWN
    $InitialFormWindowState        = New-Object 'System.Windows.Forms.FormWindowState'
    $MainFORM_StateCorrection_Load = { $MainForm.WindowState = $InitialFormWindowState }

    $MainFORM_Load = {
        # Change font to a nicer one
        Write-Log -Message ''
        Write-Log -Message "Welcome ($(Get-Date))"
        ForEach ($control In $MainForm.Controls)                                        { $control.Font = $sysFont }
        ForEach ($tab     In $tab_Pages.TabPages) { ForEach ($control In $tab.Controls) { $control.Font = $sysFont } }

        # Set some specific fonts
        $lbl_t0_01.Font = $sysFontBold
        $lbl_t2_01.Font = $sysFontBold
        $lbl_t2_02.Font = $sysFontBold
        $lbl_t2_03.Font = $sysFontBold

        $rad_t2_0x_CheckedChanged.Invoke()

        $script:tb1 = $tab_Page1; $tab_Pages.TabPages.Remove($tab_Page1)
        $script:tb2 = $tab_Page2; $tab_Pages.TabPages.Remove($tab_Page2)
        $script:tb3 = $tab_Page3; $tab_Pages.TabPages.Remove($tab_Page3)
        $script:tb4 = $tab_Page4; $tab_Pages.TabPages.Remove($tab_Page4)

        $txt_t0_01.Text = $ManagementServer
    }

    $MainFORM_FormClosing = [System.Windows.Forms.FormClosingEventHandler] {
        $quit = [System.Windows.Forms.MessageBox]::Show($MainFORM, 'Are you sure you want to exit this tool.?', $script:appName, 'YesNo', 'Question')
        If ($quit -eq 'No') { $_.Cancel = $True }
        Write-Log -Message 'Good-Bye.'
    }

    $Form_Cleanup_FormClosed = {
        $chk_t0_01.Remvoe_CheckedChanged($chk_t0_01_CheckedChanged)
        $btn_t0_01.Remove_Click($btn_t0_01_Click)

        $btn_t1_01.Remove_Click($btn_t1_01_Click)
        $btn_t1_02.Remove_Click($btn_t1_02_Click)
        $btn_t1_03.Remove_Click($btn_t1_03_Click)

        $chk_t2_01.Remove_CheckedChanged($chk_t2_01_CheckedChanged)
        $btn_t2_01.Remove_Click($btn_t2_01_Click)
        $btn_t2_03.Remove_Click($btn_t2_03_Click)
        $btn_t2_04.Remove_Click($btn_t2_04_Click)

        $btn_t3_01.Add_Click($btn_t3_01_Click)
        $btn_t3_02.Add_Click($btn_t3_02_Click)

        $txt_t4_01.Remove_TextChanged($txt_t4_01_TextChanged)
        $lnk_t4_01.Remove_LinkClicked($lnk_t4_01_LinkClicked)
        $lst_t4_01.Remove_MouseUp($lst_t4_01_MouseUp)
        $lst_t4_01.Remove_DrawSubItem($SubIcons_DrawSubItem)
        $lst_t4_01.Remove_DrawColumnHeader($SubIcons_DrawColumnHeader)
        $tsm_t4_sub_01.Remove_Click($tsm_t4_sub_0x_Click)
        $tsm_t4_sub_02.Remove_Click($tsm_t4_sub_0x_Click)
        $tsm_t4_sub_04.Remove_Click($tsm_t4_sub_0x_Click)
        $btn_t4_02.Remove_Click($btn_t4_02_Click)
        $btn_t4_03.Remove_Click($btn_t4_03_Click)

        $tab_Pages.Remove_SelectedIndexChanged($tab_Pages_SelectedIndexChanged)
        Try {
            $sysFont.Dispose()
            $sysFontBold.Dispose()
        } Catch {}

        $MainFORM.Remove_Load($MainFORM_Load)
        $MainFORM.Remove_Load($MainFORM_StateCorrection_Load)
        $MainFORM.Remove_FormClosing($MainFORM_FormClosing)
    }
#endregion
###################################################################################################
#region FORM Scripts
    #region MAIN FORM SCRIPTS
    $tab_Pages_SelectedIndexChanged = {
        If ($tab_Pages.SelectedTab -eq $script:tb4) { Search-ServerList -SearchString $txt_t4_01.Text }
    }
    #endregion
    #region TAB 0 SCRIPTS
    $chk_t0_01_CheckedChanged = {
        If ($chk_t0_01.Checked -eq $true)
        {
            $txt_t0_02.Text    = ('{0}\{1}' -f $env:UserDomain.ToLower(), $env:UserName.ToLower())
            $txt_t0_03.Text    = ''
            $txt_t0_02.Enabled = $False
            $txt_t0_03.Enabled = $false
        }
        Else
        {
            $txt_t0_02.Text    = ''
            $txt_t0_03.Text    = ''
            $txt_t0_02.Enabled = $True
            $txt_t0_03.Enabled = $True
        }
    }

    $btn_t0_01_Click = {
        $btn_t0_01.Enabled = $False
        $MainFORM.Cursor = 'WaitCursor'
        $btn_t0_01.Text  = 'Loading Module...'
        Write-Host '    Loading Operations Manager module - this could take a while'
        $btn_t0_01.Refresh()

        If ((Get-Module -ListAvailable -Name 'OperationsManager' -ErrorAction SilentlyContinue) -eq $null)
        {
            $MainFORM.Cursor   = 'Default'
            Write-Host '    Error: Operations Manager module not found'
            [System.Windows.Forms.MessageBox]::Show($MainFORM, "Operations Manager module was not found", 'Module', 'OK', 'Error')
            $btn_t0_01.Text    = 'Connect'
            $btn_t0_01.Enabled = $True
            Return
        }

        Import-Module -Name 'OperationsManager' -WarningAction SilentlyContinue | Out-Null
        [boolean]$errorCondition = $False

        $btn_t0_01.Text  = 'Connecting To Server...'
        Write-Host '    Connecting To Management Server'
        $btn_t0_01.Refresh()
        Try
        {
            If ($chk_t0_01.Checked -eq $True)
            {
                # TODO: Get current user credential object
                Write-Log -Message ('User {0}, Logging on to {1}' -f $env:UserName, $txt_t0_01.Text)
                $scomConnection = New-SCOMManagementGroupConnection -ComputerName $($txt_t0_01.Text) -PassThru
            }
            Else
            {
                [string]      $username = ($txt_t0_02.Text)
                [securestring]$password = ConvertTo-SecureString -String ($txt_t0_03.Text) -AsPlainText -Force
                [pscredential]$scomCred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $username, $password
                Write-Log -Message ('User {0}, Logging on to {1}' -f $txt_t0_02.Text, $txt_t0_01.Text)
                $scomConnection = New-SCOMManagementGroupConnection -ComputerName $($txt_t0_01.Text) -Credential $scomCred -PassThru
            }
        }
        Catch [System.Net.Sockets.SocketException]
        {
            [System.Windows.Forms.MessageBox]::Show($MainFORM, "Invalid server name, ensure this server exists and is reachable.", $script:appName, 'OK', 'Error')
            $errorCondition = $True
        }
        Catch
        {
            [System.Windows.Forms.MessageBox]::Show($MainFORM, $_.Exception.Message, $script:appName, 'OK', 'Error')      
            $errorCondition = $True
        }

        If ($errorCondition -eq $False)
        {
            $tab_Pages.TabPages.Add($script:tb1)    # Server Entry
            $tab_Pages.TabPages.Add($script:tb4)    # Search

            Load-MaintenanceModeReasons
            $chk_t2_01_CheckedChanged.Invoke()

            $tab_Page0.Enabled     = $False    # Welcome
            $tab_Pages.SelectedTab = $script:tb1

            Write-Host '    Connected'
            $MainFORM.Cursor   = 'Default'
            $btn_t0_01.Text    = 'Complete'
        }
        Else
        {
            Write-Host '   Error Connecting'
            $btn_t0_01.Text    = 'Connect'
            $btn_t0_01.Enabled = $True
        }
    }
    #endregion
    #region TAB 1 SCRIPTS
    $txt_t1_01_LostFocus = {
        [string[]]$list = @()
        $txt_t1_01.Text.Trim().Split("`n") | ForEach { If ($_.Trim().Length -gt 5) { $list += ($_.Trim()) } }
        $list = $list | Sort-Object | Select-Object -Unique | Where-Object { $_ }
        $txt_t1_01.Clear()
        If ([string]::IsNullOrEmpty($list) -eq $False) { $txt_t1_01.Text = [string]::Join("`r`n", $list) }
    }

    $txt_t1_01_TextChanged = {
        $script:Verified = $False
    }

    $btn_t1_01_Click = {    # Verify List
        $MainFORM.Cursor = 'WaitCursor'

        # Update object list if we need to
        If ($script:objectList.Count -eq 0) { Update-ServerList }
        ForEach ($item In (($txt_t1_01.Text).Split("`n")))
        {
            If ([string]::IsNullOrEmpty($item) -eq $False)
            {
                $found = ($script:objectList | Where-Object { "$($_.Text)$($_.SubItems[2].Text)" -like "$($item.Trim())*".ToLower() })
                If ([string]::IsNullOrEmpty($found) -eq $True)
                {
                    $txt_t1_01.Text = $txt_t1_01.Text.Replace($item, "X-$item")
                }
                Else
                {
                    If ($item -ne "$($found.Text)$($found.SubItems[2].Text)") {
                        $txt_t1_01.Text = $txt_t1_01.Text.Replace($item, "$($found.Text)$($found.SubItems[2].Text)`r`n".ToUpper())
                    }
                }
            }
        }
        $script:Verified = $True
        $MainFORM.Cursor = 'Default'
    }

    $btn_t1_02_Click = {    # Search SCOM
        $tab_Pages.SelectedTab = $script:tb4
    }

    $btn_t1_03_Click = {    # NEXT
        If ([string]::IsNullOrEmpty($txt_t1_01.Text) -eq $True) { Return }
        ForEach ($item In ($txt_t1_01.Text).Split("`n")) { If ($item.StartsWith('X-')) { Return } }
        If ($script:Verified -eq $False)
        {
            $btn_t1_01_Click.Invoke()
            ForEach ($item In ($txt_t1_01.Text).Split("`n")) { If ($item.StartsWith('X-')) { Return } }
            If ($script:Verified -eq $False)
            {
                [System.Windows.Forms.MessageBox]::Show($MainFORM, 'Could not verify the server list',$script:appName, 'OK', 'Warning') 
                Return
            }
        }

        If ($tab_Pages.TabPages.Contains($script:tb2) -eq $False) { $tab_Pages.TabPages.Insert(2, $script:tb2) }
        $tab_Pages.SelectedTab = $script:tb2
    }

    #endregion
    #region TAB 2 SCRIPTS
    $chk_t2_01_CheckedChanged = {
        $cmo_t2_01.Items.Clear()
        If ($chk_t2_01.Checked -eq $True) { $cmo_t2_01.Items.AddRange(($script:mmReasonP.Keys | Sort-Object)) }
        Else                              { $cmo_t2_01.Items.AddRange(($script:mmReasonU.Keys | Sort-Object)) }
        $cmo_t2_01.SelectedIndex = 0
    }

    $rad_t2_0x_CheckedChanged = {
        $nud_t2_01.Enabled = $rad_t2_01.Checked
        $dtp_t2_01.Enabled = $rad_t2_02.Checked
    }

    $btn_t2_03_Click = {
        If ($tab_Pages.TabPages.Contains($script:tb3) -eq $False) { $tab_Pages.TabPages.Insert(3, $script:tb3) }
        $tab_Pages.SelectedTab = $script:tb3

        ForEach ($item In ($txt_t1_01.Text.Trim().Split("`n")))
        {
            [System.Windows.Forms.ListViewItem]$found = ($script:objectList | Where-Object { "$($_.Text)$($_.SubItems[2].Text)".ToLower() -eq $item.ToLower().Trim() })
            If ([string]::IsNullOrEmpty($found) -eq $False)
            {
                $lvTemp = New-Object 'System.Windows.Forms.ListViewItem'
                $lvTemp.Name = $found.Name
                $lvTemp.Text = $found.Text
                $lvTemp.ImageIndex = 0
                $lvTemp.SubItems.Add($found.SubItems[1].Text)
                $lvTemp.SubItems.Add($found.SubItems[2].Text)
                $lvTemp.SubItems.Add('')
                $lst_t3_01.Items.Add($lvTemp)
                $lvTemp = $null
            }
        }

        ForEach ($item In $lst_t3_01.Items)
        {
            If ($item.SubItems[1].Text -eq 'ICON|6')
            {
                Try {
                    $StopMaintenance = (Get-SCOMClassInstance -Id $item.Name)
                    $StopMaintenance.StopMaintenanceMode(([DateTime]::Now.ToUniversalTime()))
                    $item.SubItems[3].Text = 'ICON|7'
                } Catch { $item.SubItems[3].Text = 'ICON|8' }
            }
        }
    }
    
    $btn_t2_04_Click = {
        If ([string]::IsNullOrEmpty($txt_t2_01.Text) -eq $True) { Return }
        If ($tab_Pages.TabPages.Contains($script:tb3) -eq $False) { $tab_Pages.TabPages.Insert(3, $script:tb3) }
        $tab_Pages.SelectedTab = $script:tb3

        ForEach ($item In ($txt_t1_01.Text.Trim().Split("`n")))
        {
            [System.Windows.Forms.ListViewItem]$found = ($script:objectList | Where-Object { "$($_.Text)$($_.SubItems[2].Text)".ToLower() -eq $item.ToLower().Trim() })
            If ([string]::IsNullOrEmpty($found) -eq $False)
            {
                $lvTemp = New-Object 'System.Windows.Forms.ListViewItem'
                $lvTemp.Name = $found.Name
                $lvTemp.Text = $found.Text
                $lvTemp.ImageIndex = 0
                $lvTemp.SubItems.Add($found.SubItems[1].Text)
                $lvTemp.SubItems.Add($found.SubItems[2].Text)
                $lvTemp.SubItems.Add('')
                $lst_t3_01.Items.Add($lvTemp)
                $lvTemp = $null
            }
        }

        ForEach ($item In $lst_t3_01.Items)
        {
            If ($item.SubItems[1].Text -eq 'ICON|6')
            {
                [boolean]$MaintenanceMode = $False
                Try {
                    # If already in maintenance mode, set new time/comment/reason
                    $MaintenanceModeEntry = (Get-SCOMMaintenanceMode -Instance $item.Name)
                    $MaintenanceMode      = (Set-SCOMMaintenanceMode -MaintenanceModeEntry $MaintenanceModeEntry -EndTime (Get-Date).AddMinutes($nud_t2_01.Text) -Comment $txt_t2_01.Text -PassThru `
                                                                     -Reason (Get-Reason -Reason $cmo_t2_01.Text -Planned $chk_t2_01.Checked)).InMaintenanceMode
                } Catch { $MaintenanceMode = $False; Write-Host $_ }
            }
            Else
            {
                Try {
                    # Start new maintenance mode
                    $MaintenanceModeEntry = (Get-SCOMClassInstance -Id $item.Name)
                    $MaintenanceMode      = (Start-SCOMMaintenanceMode -Instance $MaintenanceModeEntry -EndTime (Get-Date).AddMinutes($nud_t2_01.Text) -Comment $txt_t2_01.Text -PassThru `
                                                                       -Reason (Get-Reason -Reason $cmo_t2_01.Text -Planned $chk_t2_01.Checked)).InMaintenanceMode
                } Catch { $MaintenanceMode = $False; Write-Host $_ }
            }

            # Get result
            If ($MaintenanceMode -eq $True) { $item.SubItems[3].Text = 'ICON|7' } Else { $item.SubItems[3].Text = 'ICON|8' }
        }
    }
    #endregion
    #region TAB 3 SCRIPTS
    $btn_t3_01_Click = {
        # TODO: View Log File
    }

    $btn_t3_02_Click = {
        $MainFORM.Close()
    }
    #endregion
    #region TAB 4 SCRIPTS
    $txt_t4_01_TextChanged = { Search-ServerList -SearchString $txt_t4_01.Text }

    $lnk_t4_01_LinkClicked = {
        [System.Text.StringBuilder]$msg = ''
        $msg.AppendLine("SEARCH QUICK HELP GUIDE")
        $msg.AppendLine("The search field is not case-sensitive")
        $msg.AppendLine("")
        $msg.AppendLine("Filter on server status by using:")
        $msg.AppendLine("    !s`tSuccess")
        $msg.AppendLine("    !w`tWarning")
        $msg.AppendLine("    !e`tError")
        $msg.AppendLine("    !u`tUninitialized")
        $msg.AppendLine("    !m`tIn Maintenance")
        $msg.AppendLine("    !c`tCurrently Selected (Checked)")
        [System.Windows.Forms.MessageBox]::Show($MainFORM, $msg.ToString(), $script:appName, 'OK', 'Information')
    }

    $lst_t4_01_MouseUp = {
        [System.Windows.Forms.MouseEventArgs]$e = $_
        If ($e.Button -ne 'Right') { Return }
        $cms_t4_01.Show($lst_t4_01, $e.X, $e.Y)
    }

    Function tsm_t4_sub_0x_Click([object]$Sender)
    {
        $tsm_t4_sub_01.Checked = $False
        $tsm_t4_sub_02.Checked = $False
        $tsm_t4_sub_04.Checked = $False

        Switch ($Sender.Text)
        {
            'Domain Name'   { $tsm_t4_sub_01.Checked = $True; Break }
            'Health Status' { $tsm_t4_sub_02.Checked = $True; Break }
            'None'          { $tsm_t4_sub_04.Checked = $True; Break }
        }

        $script:GroupBy = $Sender.Text
        Group-SearchResults -ByType $Sender.Text
    }

    $btn_t4_02_Click = { $tab_Pages.SelectedTab = $script:tb1 }    # CANCEL
    $btn_t4_03_Click = {
        ForEach ($item In $script:objectList) { If ($item.Checked -eq $True) { $txt_t1_01.Text += "`r`n$($item.Text)`r`n" } }
        $txt_t1_01_LostFocus.Invoke()
        $tab_Pages.SelectedTab = $script:tb1
    }

    #endregion
#endregion
###################################################################################################
#region FORM ITEMS
    #region MAIN FORM
    $MainFORM                           = New-Object 'System.Windows.Forms.Form'
    $MainFORM.AutoScaleDimensions       = '6, 13'
    $MainFORM.AutoScaleMode             = 'None'
    $MainFORM.ClientSize                = '469, 422'    # 475 x 450
    $MainFORM.FormBorderStyle           = 'FixedSingle'
    $MainFORM.MaximizeBox               = $False
    $MainFORM.MinimizeBox               = $False
    $MainFORM.StartPosition             = 'CenterScreen'
    $MainFORM.Text                      = $script:appName
    $MainFORM.Icon                      = [System.Convert]::FromBase64String('
        AAABAAQAMDAAAAEAIACoJQAARgAAACAgAAABACAAqBAAAO4lAAAYGAAAAQAgAIgJAACWNgAAEBAAAAEAIABoBAAAHkAAACgAAAAwAAAAYAAAAAEAIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
        AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAJubmwJfX1+mUFBQ5kVF
        RvlCQkP9PDw9/zw8Pf9AQEH9RkZH91FRUeJYWFmuampqBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACAAAAAgAAAAIAAAACAAAAAgAAAAIAAAACAAA
        AAgAAAAIAAAACAAAAAgAAAAIAAAACAAAAAgAAAAIAAAACAAAAAgAAAAIAAAACAAAAAgAAAAIX19gu0lJSfhFRUb/ampq/5GRkf+tra3/tra2/6urq/+Xl5f/jo6O/25ubv9GRkb/QEBA+1BQUdAAAAAIAAAACAAA
        AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABAAAAAQAAAAGAAAABgAAAAYAAAAGAAAABgAAAAYAAAAGAAAABgAAAAYAAAAGAAAABgAAAAYAAAAGAAAABgAAAAYAAAAGAAAABgAAAAYAAAAGGtr
        a1tYWFjnT09Q/oWFhf/T09P/0dHR/9HR0f/Pz8//zc3N/8zMzP/IyMj/xcXF/8PDw//AwMD/gICA/0ZGR/5GRkb0W1tcbwAAABAAAAAIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAIAAAAEAAAABgAAAAhAAAAIQAA
        ACEAAAAhAAAAIQAAACEAAAAhAAAAIQAAACEAAAAhAAAAIQAAACEAAAAhAAAAIQAAACEAAAAhAAAAIQAAACEAAAAhaWlpfVxcXPB7e3v/1dXV/9nZ2f/Z2dn/2NjY/9nZ2f/Y2Nj/19fX/9XV1f/R0dH/z8/P/8nJ
        yf/FxcX/w8PD/7Ozs/9UVFX/QkJD+l1dXYcAAAAYAAAAEAAAAAAAAAAAAAAAAAAAAACESTlzjE051pRNOf+UTTn/lE05/5RNOf+UTTn/lE05/5RNOf+UTTn/lE05/5RNOf+UTTn/lE05/5RNOf+UTTn/lE05/5RN
        Of+UTTn/lE05/5RNOf+RXk//ZmBf/5SUlP/j4+P/4uLi/+Dg4P/i4uL/4+Pj/+Tk5P/k5OT/5OTk/+Pj4//f39//2dnZ/9TU1P/Pz8//yMjI/8PDw/+9vb3/YWFh/0RERPhjY2NfAAAAGAAAAAgAAAAAAAAAAJxd
        SsatdVr/tYJr/7WKc/+1inP/tYpz/7WKc/+1inP/tYpz/8aWhP/Gooz/xp6E/7WKc//GmoT/xqKM/86mjP/Gooz/vZJz/7WKc/+9lnv/xqKM/86mjP94c3D/jIyM/+rq6v/q6ur/dVxM/4t1Z//f3Nn/7u7u//Hx
        8f/x8fH/8fHx/+7u7v/r6+v/5+fn/+Li4v/Z2dn/0dHR/8nJyf/Dw8P/vb29/0xMTf9LS0vvAAAAIQAAABAAAAAAlE05c61xWv+tfWP/pXFa/5xhSv+cYUr/nGFK/5xlSv+tdVr/rXVa/6VpSv+cYUr/pW1S/615
        Wv+9inP/nGVK/5xhSv+teVr/rX1j/7WCa/+tdVr/nGFK/4t5cv9ycXH/7+/v//T09P+EbV7/vZ+Q/4ltXP+RfW7/6+jm//n5+f/5+fn/+fn5//b29v/29vb/8fHx/+vr6//m5ub/3Nzc/9HR0f/Jycn/w8PD/6mp
        qf9AQED+XFxcugAAABgAAAAAlE051q11Y/+cZUr/lFU5/5RVOf+cXUL/pW1a/6VtUv+UVUL/lFU5/6VtUv+lbVL/nF1C/5RVOf+tfWP/pW1S/6VxWv+UXUL/lFU5/5xlSv+lbVL/pXFb/21pZ//BwcH/////////
        //+DbF3/4Mi8/72fkP+JbVz/knxu/+/t6v///////Pz8//z8/P/8/Pz/+fn5//T09P/u7u7/5ubm/9zc3P/R0dH/yMjI/8PDw/9aWlr/SUlK9QwMDBkAAAAAlE05/61xWv+MSTH/lFlC/5xhSv+tcVr/jEkx/5RN
        Of+cYUr/nGFK/4xJMf+MSTH/nGFK/6VpUv+cYUr/jEkx/5RROf+lZVL/nGFK/4xNOf+MSTH/hGZb/3x8fP////////////////+zpJr/emFR/+DIvP+7m4z/h2lY/5V+cP/x7ev////////////8/Pz//Pz8//n5
        +f/29vb/7u7u/+bm5v/Z2dn/z8/P/8XFxf+vr6//RERE/2ZmZpcAAAAAlE05/7WCc/+UWUL/jEUx/4Q8Kf+laVL/lFlC/5RROf+EPCn/jEUx/5RZQv+UWUL/hEEp/5RVQv+UVUL/nFlC/5RROf+EPCn/hDwp/4Q8
        Kf+EPCn/d2pn/7Ozs///////////////////////0cjB/4htXv/gyLz/vJuK/4RnVf+QeWr/7+3q//////////////////z8/P/5+fn/9PT0/+3t7f/i4uL/1NTU/8nJyf/ExMT/UVFS/1RUVN4AAAAAlE05/5xl
        Uv97NCH/lFE5/5xdSv+MRTH/ezQh/4xFMf+UUUL/jEk5/3s0If+EOCn/lFE5/5RRQv+EOCn/ezQh/3s0If97NCH/ezQh/3s0If97NCH/dG9u/+Pj4////////////////////////////9fMx/+Ea1n/4Mi8/7OS
        gf+AYE7/jHRl/+/r6P/////////////////8/Pz/+fn5//Hx8f/n5+f/29vb/8/Pz//Hx8f/enp7/0tLS/QAAAAAlE05/7WCc/+UTTn/ezQh/4xJMf+MSTH/lE05/4Q8Kf97MCH/hDgp/5RNOf+MRTH/ezAh/3sw
        If97MCH/ezAh/3swIf97MCH/ezAh/3swIf97MCH/cXBw///////////////////////////////////////VzMT/e2JR/+DIvP+mhXX/blI+/35pWf/t6uf////////////8/Pz//Pz8//b29v/r6+v/39/f/9PT
        0//Jycn/oKCg/0RERfwAAAAAlE05/5xhUv97NCH/lEk5/5xdSv97NCH/ezAh/4xFMf+MSTn/hDwp/3swIf97MCH/ezAh/3swIf97MCH/ezAh/3swIf97MCH/ezAh/3swIf97MCH/cXFx////////////////////
        ////////////////////////0cjB/3BXRv/gyLz/lnln/2lNOv99Z1f/18/I/9XNyP/UzMX/4tzY//b29v/u7u7/4+Pj/9fX1//MzMz/tra2/z8/P/8AAAAAlE05/7V9c/+MSTn/ezAh/5RJOf+MSTn/jEkx/3s0
        If97MCH/ezAh/3swIf97MCH/ezAh/3swIf97MCH/ezAh/3swIf97MCH/ezAh/3swIf97MCH/eXl5/////////////////////////////////////////////////83EvP9pUD7/4Mi8/7KUhP92XEv/bFFA/2lP
        Pv9lSjj/a1E//6eXi//x8fH/5OTk/9jY2P/Pz8//vb29/0BAQP8AAAAAlE05/6VhUv+EPCn/lE05/5RNOf97MCH/ezAh/3swIf97MCH/ezAh/3swIf97MCH/ezAh/3swIf97MCH/ezAh/3swIf97MCH/ezAh/3sw
        If97MCH/hYSD///////////////////////////////////////////////////////LwLn/a1RC/+DIvP+4l4X/pIV1/5d7av+0lof/mntq/2BFM/+ejID/5ubm/9nZ2f/Q0ND/t7e3/05OTvsAAAAAlE05/7WC
        c/+USTn/ezAh/3swIf97MCH/ezAh/3swIf97MCH/ezAh/3swIf97MCH/ezAh/3swIf97MCH/ezAh/3swIf97MCH/ezAh/3swIf97MCH/ioWE//X19f//////////////////////////////////////////////
        ////////w7iv/4tuXP+9m4r/lnlp/3JWRf9YPi3/WkAu/0wyIv9VPCz/5OTk/9nZ2f/R0dH/oKCg/1dXV/AAAAAAlE05/6VlUv+ENCH/hDQh/4Q0If+ENCH/hDQh/4Q0If+ENCH/hEEx/4Q4Kf+ENCH/hDQh/4Q0
        If+ENCH/hDQh/4Q0If+ENCH/hDQh/4Q0If+ENCH/h3p2/93d3f//////////////////////////////////////////////////////4tvV/3xiUf/gyLz/ooV1/3NbS//r6Ob/7ejm/+fj4P/f29j/4+Pj/9nZ
        2f/U1NT/fX19/1lZWdwAAAAAlE05/61pWv+EOCn/hDgp/4Q4Kf+EOCn/hDgp/4Q4Kf+UWUr/nG1j/5RdUv+EOCn/hDgp/4Q4Kf+EOCn/hDgp/4Q4Kf+EOCn/hDgp/4Q4Kf+EOCn/iGZf/6ampv/+/v7/////////
        ////////////////////////////////////////4tvX/35lVP/gyLz/rZKF/4BoV/////////////n5+f/u7u7/4+Pj/9nZ2f/X19f/VVVV/19fX6QAAAAAlE05/61tWv+EPCn/hDwp/4Q8Kf+EPCn/hDwp/5Rd
        Uv+lcWP/5+Pn/72WlP+UWUr/hDwp/4Q8Kf+EPCn/hDwp/4Q8Kf+EPCn/hDwp/4Q8Kf+EPCn/hD0q/4qFhP/n5+f/////////////////////////////////////////////////5uDc/5F5Z//gyLz/x6+l/31n
        Vv+UhHn/mop+/5qKfv+3qZ//4uLi/9vb2/+VlZX/TU1N9A4ODhoAAAAAlE05/61xY/+MQTH/jEEx/4xBMf+MQTH/nGFS/6V1a//n5+f/7+vv/9bLzv+cYVL/jEEx/4xBMf+MQTH/jEEx/4xBMf+MQTH/jEEx/4xB
        Mf+MQTH/jEEx/4duaf+tra3//////////////////////////////////////////////////////72tof+OdGH/4Mi8/+DIvP/gyLz/dFZE/0YtHf+3p5//4uLi/9HR0/9SUlL+W1tbvgAAABgAAAAAlE05/7V1
        Y/+cYVL/nGVa/5xlWv+cZVr/pXVr/+/n5//v5+f/1r69/+/r7/+cZVr/jEUx/4xFMf+MRTH/jEUx/4xFMf+MRTH/jEUx/4xFMf+MRTH/jEUx/4xFMf+IgYD/8vLy////////////////////////////////////
        ///////////////////Et63/moNz/4pxXv+KcF7/p5aJ/8e8tP/q6ur/3d3d/3Jycv9gWFX+AAAAIQAAABgAAAAAlE05/7WGc/+1ioT/59vW/+fb1v/n29b/7+vv/+/r7/+teXP/rXVr/+/v7/+9koz/nF1S/5RJ
        Of+USTn/lEk5/5RJOf+USTn/lEk5/5RJOf+USTn/lEk5/5RJOf+YcGb/m5ub//z8/P////////////////////////////////////////////////////////////////////////////T09P/t7e3/kpKS/11a
        WP+JWk35AAAAIQAAABgAAAAAlE05/72Ke/+9mpT/7+/v/+/v7//v7+//7+fn/62Cc/+laVr/pWla/+/n5//ez87/pWla/5RNOf+UTTn/lE05/5RNOf+UTTn/lE05/5RNOf+UTTn/lE05/5xRQv+lcWP/uri6/5qX
        lv/5+fn///////////////////////////////////////////////////////////////////////Ly8v+RkZH/WlZV/6KDeP+UTTn3AAAAIQAAABgAAAAAlE05/72Cc/+lbWP/pW1j/6VtY/+lbWP/pW1j/6Vt
        Y/+cUUL/pW1j/97Hxv/37+//pW1j/5xRQv+cUUL/nFFC/5xVQv+lbWP/pW1j/6VtY/+lbWP/pW1j/6VtY/+9loz/9/P3/5Rxav+Gfnz/0M/P////////////////////////////////////////////////////
        ////////w8PD/3Jycv9oYWD/k2Fa/86ajP+UTTn3AAAAIQAAABgAAAAAlE05/72Gc/+cVUL/nFVC/5xVQv+cVUL/nFVC/5xVQv+cVUL/pWVS/7WGe//39/f/vY6E/6VlWv+cVUL/nFVC/6VtY//OrqX/9/P3//fz
        9//38/f/9+/v/7WGe//WtrX/9+/v/6VxY/+cVUL/g29q/4uIh//c3Nz//v7+////////////////////////////3d3d/6SkpP96enr/cGpo/4RrZP+lXUr/nFlK/86elP+UTTn3AAAAIQAAABgAAAAAlE05/72K
        e/+cWUr/nFlK/5xZSv+cWUr/nFlK/5xZSv+cWUr/nFlK/611a//38/f/3s/O/611a/+cWUr/nFlK/611a//n087/9/f3/+/j5//v4+f/9/P3//fz9//n19b/7+fn/611a/+cWUr/nFlK/5xZS/+Nd3T/kpCQ/4yM
        jP+Mi4v/g4OD/3x8fP+CgoL/hoGA/4x9eP+Xd23/rW1b/6VlUv+tcWP/pWFS/86ilP+UTTn3AAAAIQAAABgAAAAAlE05/72Oe/+lXUr/pV1K/6VdSv+lXUr/pV1K/6VdSv+lXUr/pV1K/611a//n09b/9/P3/611
        a/+lXUr/pV1K/611a//v5+f/59fW/611a/+tdWv/tYJz//fz9///+///59fW/611a/+lXUr/pV1K/6VdSv+tdWv/1r69///7//+teWv/rXVj/86yrf//9/f/rXVr/6VdSv+1dWP/pV1K/7V1Y/+lYVL/tXVr/86e
        lP+UTTn3AAAAIQAAABgAAAAAlE05/72Oe/+lXUr/pV1K/6VdSv+lXUr/pV1K/6VdSv+lXUr/pV1K/61tY/+9loz//////7WKe/+laVr/pV1K/615a///9/f/3sO9/615a/+lXUr/rXlr/7WCc///9/f/3sO9/615
        a/+lXUr/pV1K/6VdSv+lZVL/tX1z///7///Wvr3/rXlr/+fTzv/38+//rXlr/6VdSv+1eWv/pV1K/7V1Y/+lXUr/tXlr/86mlP+UTTn3AAAAIQAAABgAAAAAlE05/8aShP+lYVL/pWFS/6VhUv+lYVL/pWFS/6Vh
        Uv+lYVL/pWFS/6VhUv+teWv///v//+fPzv+teWv/pWFS/615a///////zqac/61xY/+lYVL/pWFS/615a/+1gnv/vZKM/61pWv+lYVL/pWFS/6VhUv+lYVL/rXlr/+/j5//38/f/rXlr//fr5//v397/rXlr/6Vh
        Uv+1eWv/pWFS/7V5a/+lYVL/tXlr/86qnP+UTTn3AAAAIQAAABgAAAAAlE05/8aahP+taVL/pWVS/6VlUv+lZVL/pWVS/6VlUv+lZVL/pWVS/6VlUv+tfXP/79/e//fz9/+tfXP/rW1a/72OhP//////tYp7/6Vp
        Wv+lZVL/pWVS/6VlUv+laVr/rW1j/6VlUv+lZVL/pWVS/6VlUv+lZVL/rXVr/8ainP//////vZaM///39//ex8b/rX1z/6VlUv+1fWv/rW1a/72Gc/+1eWP/zp6M/9aypf+UTTn3AAAAIQAAABgAAAAAlE05/86e
        hP+tbVL/rW1S/61tUv+tbVL/rW1S/61tUv+tbVL/rWlS/61pUv+tdWv/zqac//////+1hnv/rXlr/86yrf//////tX1z/6VlUv+lZVL/pWVS/6VlUv+lZVL/pWVS/61lUv+taVL/rWlS/61pUv+taVr/pWVS/7V9
        c///+/f/79/e///////OqqX/rXVr/7V9a//OmoT/zp6E/86ehP/OnoT/1rac/966rf+UTTn3AAAAIQAAABgAAAAAlE05/86ijP+1cVL/tXFS/7VxUv+1cVL/tXFS/7VxUv+1cVL/tXFS/7VxWv+taVr/tYJz////
        ///ey8b/tYJz/+fPxv//9/f/tYJz/61tWv+1eWP/tXlj/7V5Y/+1fWP/vYJr/72Ca/+9hmv/vYZr/72Ga/+9inP/rXFa/7WCc//nz87///////////+1inv/rW1a/72Oc//Glnv/1qqU/8aae//WqpT/1qqU/+fH
        tf+UTTn3AAAAIQAAABgAAAAAlE05/86ijP+1dVr/tXVa/7V1Wv+1dVr/tXVa/7V1Wv+1dVr/tXVa/7V1Wv+tbVr/tYJz/+/n5//37+//tYZz/+/n5//36+f/tYZz/61xWv+9gmP/vYJr/72Ga/+9hmv/vYZr/72K
        a/+9inP/vYpz/8aOc//GjnP/vYJr/615a/+9joT///////////+1gnP/rW1a/8aWe//Gmnv/1q6U/86ahP/euqX/zp6E/+fLtf+UTTn3AAAAIQAAABgAAAAAlE05/86mjP+1dVr/tXVa/7V1Wv+1dVr/tXVa/7V1
        Wv+1eVr/tXla/7V5Wv+1dWP/tYJz/9a6tf//////tYp7///39//n19b/tYZ7/7V5Y/+9hmv/vYZr/72Ga/+9imv/vYpz/72Oc//GjnP/xo5z/8aSc//GknP/xpJz/61xY/+1hnv/9+vv///39/+1hnv/tXVj/86a
        hP/OmoT/1q6c/86ehP/euqX/zqKM/+fLvf+UTTn3AAAAIQAAABgAAAAAlE05/86mlP+1eWP/tXlj/7V5Y/+1eWP/tXlj/7V5Y/+1fWP/tX1j/7V9Y/+1fWP/tXVj/72Ke///////3sO9///////ew73/tYZ7/7V9
        a/+9imv/vYpz/72Kc//GjnP/xo5z/8aSc//Gknv/xpJ7/8aWe//Glnv/xpZ7/7WCa/+1hnv/1rat/+/n5/+9jnv/tYJr/86ehP/OnoT/1rKc/9aqlP/etqX/zqaM/+fPvf+UTTn3AAAAIQAAABgAAAAAlE05/86q
        lP+1fWP/tX1j/7V9Y/+1fWP/vX1j/7V9Y/+9gmP/vYJj/72CY/+9gmv/tXVj/72Ke//36+//9+/v///////Oppz/tYJz/72Ga//GjnP/xo5z/8aOc//GknP/xpJ7/8aWe//Glnv/xpZ7/8aWe//Gmnv/xpqE/8aS
        e/+9hnP/vY57/9a2rf+9jnv/vYpz/86ijP/Oooz/1rKc/9aynP/Wspz/zqaM/+fPvf+UTTn3AAAAIQAAABgAAAAAlE05/9aqlP+1fWP/tX1j/7V9Y/+1gmP/vYJj/72CY/+9gmv/vYJr/72Ga/+9hmv/tX1r/72O
        e//ex73///////////+9joT/tXlr/72Oc//GjnP/xpJz/8aSe//Glnv/xpZ7/8aWe//Gmnv/xpp7/86ahP/OmoT/zp6E/86ehP/Glnv/vYpz/8aWhP+9jnP/xpqE/86mjP/Opoz/1rKc/9aynP/Wspz/1qqU/+fL
        vf+UTTn3AAAAIQAAABgAAAAAlE05/9aunP+9gmv/vYJr/72Ca/+9gmv/vYZr/72Ga/+9hmv/vYZr/72Ka/+9inP/vYZr/7WCa/+9koT///////////+9joT/tX1r/8aSe//Gknv/xpZ7/8aWe//Gmnv/xpp7/8aa
        hP/OmoT/zpqE/86ehP/OnoT/zqKE/86ijP/Oooz/zp6E/86ehP/OnoT/zqaM/86mjP/Opoz/1qqU/9aynP/WppT/1rKc/+fHtf+UTTn3AAAAIQAAABgAAAAAlE05/9aunP+9hmv/vYZr/72Ga/+9hmv/vYpr/72K
        a/+9inP/vYpz/72Oc//GjnP/xo5z/7V9a/+9koT/9/P3///39/+9koT/tYJz/8aWe//Glnv/xpp7/8aahP/OmoT/zp6E/86ehP/OnoT/zqKE/86ijP/Oooz/zqKM/86mjP/Opoz/zqaM/86mjP/Wpoz/1qaM/9aq
        lP/WqpT/1qqU/966pf/WqpT/3ral/+fHvf+UTTn3AAAAIQAAABgAAAAAlE05/9aunP+9imv/vYpr/72Kc/+9inP/vYpz/72Oc//GjnP/xo5z/8aOc//GjnP/xpJz/72Gc/+9koT/59PO//fn5/+9loT/vYZz/8aa
        e//GmoT/zpqE/86ehP/OnoT/zqKE/86ihP/Oooz/zqKM/86mjP/Opoz/zqaM/86mjP/Opoz/1qqU/9aqlP/WqpT/1qqU/9aqlP/WqpT/1qqU/966pf/WqpT/3rql/+fLvf+UTTn3AAAAIQAAABgAAAAAlE05/9ay
        pf+9inP/vY5z/72Oc/+9jnP/xo5z/8aSc//GknP/xpJ7/8aSe//Gknv/xpJ7/8aSe/+9jnv/xqKU/+fTzv/Gmoz/vY57/86ehP/OnoT/zp6E/86ijP/Oooz/zqKM/86mjP/Opoz/zqaM/86mjP/OppT/zqqU/9aq
        lP/WqpT/1qqU/9aulP/WrpT/1q6U/9aulP/WrpT/1q6U/966pf/WrpT/3rql/+fLvf+UTTn3AAAAIQAAABgAAAAAlE05/9a2pf/GjnP/xo5z/8aOc//GknP/xpJ7/8aSe//Gknv/xpJ7/8aWe//Glnv/xpp7/8aW
        e//Gknv/xpKE/8ailP/GloT/xpaE/86ihP/Oooz/zqKM/86ijP/Opoz/zqaM/86mjP/Wpoz/1qaU/9aqlP/WqpT/1qqU/9aqlP/WrpT/1q6U/9aulP/WrpT/1q6U/9aulP/WrpT/1q6U/96+rf/WrpT/3r6t/+fL
        vf+UTTn3AAAAIQAAABAAAAAAlE05/9aypf/Gknv/xpJ7/8aSe//Gknv/xpZ7/8aWe//Glnv/xpZ7/8aWe//GmoT/xpqE/86ahP/OmoT/xpaE/8aahP/GloT/zp6M/86ijP/Opoz/zqaM/86mjP/Opoz/1qaM/9aq
        lP/WqpT/1qqU/9aqlP/WrpT/1q6U/9aulP/WrpT/1q6U/9aulP/WrpT/1q6U/9aulP/WrpT/1q6U/96+rf/WrpT/3r6t/+fLvf+UTTnvAAAAGAAAAAgAAAAAlE051taunP/OnoT/xpJ7/8aWe//Glnv/xpZ7/8aW
        e//Glnv/xpqE/8aahP/OmoT/zp6E/86ehP/OnoT/zp6M/86ejP/Oooz/zqaM/86mjP/Opoz/zqaM/9aqlP/WqpT/1qqU/9aqlP/WqpT/1q6U/9aulP/WrpT/1q6c/9aynP/Wspz/1rKc/9aynP/Wspz/1rKc/9ay
        nP/Wspz/1rKc/96+rf/Wspz/58e1/966rf+MTTnOAAAAEAAAAAAAAAAAlE05c72Kc//Wspz/zqKM/8aahP/GmoT/xpqE/8aahP/GmoT/zp6E/86ehP/OnoT/zqKM/86ijP/Oooz/zqKM/86mjP/Opoz/zqaM/86m
        lP/WqpT/1qqU/9aqlP/WqpT/1q6U/9aulP/WrpT/1q6c/9aunP/Wspz/1rKc/9aynP/Wspz/1rKc/9aynP/Wspz/1rKc/9aynP/Wspz/1rKc/97Drf/evq3/59PG/72Gc/+ESTlrAAAAAAAAAAAAAAAAAAAAAJxZ
        SrW9hnP/zq6c/9a6rf/evq3/3r6t/96+rf/evrX/3r61/97Dtf/ew7X/3sO1/97Dtf/ew7X/3sO1/97Htf/ex7X/58e9/+fHvf/nx73/58u9/+fLvf/ny73/58u9/+fLvf/ny73/58u9/+fLvf/ny73/58+9/+fP
        vf/nz73/58+9/+fPvf/nz73/58+9/+fPvf/nz73/58+9/+fPxv/evq3/vYpz/5RVQq0AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACUTTljlE05xpRNOfeUTTn/lE05/5RNOf+UTTn/lE05/5RNOf+UTTn/lE05/5RN
        Of+UTTn/lE05/5RNOf+UTTn/lE05/5RNOf+UTTn/lE05/5RNOf+UTTn/lE05/5RNOf+UTTn/lE05/5RNOf+UTTn/lE05/5RNOf+UTTn/lE05/5RNOf+UTTn/lE05/5RNOf+UTTn/lE05/5RNOfeUTTnGlE05WgAA
        AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
        AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD////4AH8AAP4AAAAADwAA+AAAAAADAADgAAAAAAEAAOAA
        AAAAAAAAwAAAAAAAAACAAAAAAAAAAIAAAAAAAAAAgAAAAAAAAACAAAAAAAAAAIAAAAAAAAAAgAAAAAAAAACAAAAAAAAAAIAAAAAAAAAAgAAAAAAAAACAAAAAAAAAAIAAAAAAAAAAgAAAAAAAAACAAAAAAAAAAIAA
        AAAAAAAAgAAAAAAAAACAAAAAAAAAAIAAAAAAAAAAgAAAAAAAAACAAAAAAAAAAIAAAAAAAAAAgAAAAAAAAACAAAAAAAAAAIAAAAAAAAAAgAAAAAAAAACAAAAAAAAAAIAAAAAAAAAAgAAAAAAAAACAAAAAAAAAAIAA
        AAAAAAAAgAAAAAAAAACAAAAAAAAAAIAAAAAAAAAAgAAAAAAAAACAAAAAAAAAAIAAAAAAAAAAgAAAAAAAAACAAAAAAAAAAIAAAAAAAQAAgAAAAAADAADAAAAAAAcAAOAAAAAADwAA////////AAAoAAAAIAAAAEAA
        AAABACAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAEAAAADAAAAAwAAAAMAAAADAAAAAwAAAAMAAAADAAAAAwAAAAMAAAADAAAAAwAAAAMAAAADWFhYF1BQUE1WVlbSXV1d92Vl
        Zv5iYmP/Xl5e/F1dXfBOTk6jSkpLSwAAAAMAAAABAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAHAAAADQAAABMAAAATAAAAEwAAABMAAAATAAAAEwAAABMAAAATAAAAEwAAABMAAAATAAAAE1lZWTBVVVa2aGho9qen
        qP+3t7f/xMTE/8LCwv+2trb/q6ur/4mJif9VVVX0SEhJiEVFRSEAAAAEAAAAAAAAAAAAAAAAd0EyOHxBMF92PS1rdj0ta3Y9LWt2PS1rdj0ta3Y9LWt2PS1rdj0ta3Y9LWt2PS1rdj0ta3Y9LWtuVk9/bW1s27Ky
        sv/b29v/3Nzc/9zc3P/c3Nz/2tra/9XV1f/Pz8//x8fH/7y8vP9paWr+T09Pxzc3NyYAAAAIAAAAAJxdSlinb1fbqnVf+qp2YP+qdmD/qnZg/7J7Z/+1hW//rnpj/7WCbf+5h3D/s4Jr/6x3YP+xgGn/uYdw/4By
        bf+zs7P/zsjE/6OTiv/j4uH/7Ozs/+3t7f/r6+v/5eXl/9/f3//T09P/ycnJ/7W1tf9mZmb9SUlJiQAAABOUTTkxp2pV26VxV/+bYUj/nWFK/59nTv+lalH/pWpN/6BmTf+ka07/r3xj/59nTv+lcFP/qnVc/6du
        Vf+Lb2T/r6+v//f39/+bgnP/qo1+/6ORhf/o5eL/+/v7//n5+f/39/f/8PDw/+bm5v/Y2Nj/ycnJ/7i4uP9MTEzuRUVFVZRNOVClZlH6klQ7/5hbQ/+hY0z/mFdA/5ldRv+WWD//l1lA/55hSf+dY0v/mFlB/51h
        Sv+UWEH/k1xG/39ybP/x8fH//////6GNgP/CqJr/oIJy/6aShv/49/b//v7+//z8/P/5+fn/8fHx/+bm5v/T09P/x8fH/3l5ef5RUVKdlE05VaRqWP+NSzb/jUg0/5dYQv+PTTf/ikQy/4xLNv+NSzb/kE87/49M
        Of+NSTP/gTkm/4E5Jv99Sj3/qaal////////////9fPx/7ennf/EqZv/pYd2/6GNgP/r5+T///////7+/v/5+fn/8fHx/9/f3//Pz8//o6Oj/1ZWVu6UTTlVpGpY/4lCLv+NSjT/jEcx/4hBLf+EPC3/ikIw/4c/
        Lf+DOyv/fTIj/3sxIf97MSH/ezEh/3hGO//Kycn/////////////////9vTz/7Cekv/ApZf/jnBe/5WCdP/39vT///////z8/P/39/f/5ubm/9bW1v+3t7f/YGBh+5RNOVWfYVH/hD0s/5VPPv+BOij/hD0q/4U+
        Lf99MyP/ezAh/3swIf97MCH/ezAh/3swIf97MCH/eUc9/9HR0f//////////////////////9fPx/6qbkP+1nI3/kHRj/455a/+ypJr/s6Wb/9HJw//r6+v/29vb/8bGxv9oaGj/lE05VaNhUf+IQS//kUk2/4E4
        KP99NCP/ezAh/3swIf97MCH/ezAh/3swIf97MCH/ezAh/3swIf99S0H/1dXV////////////////////////////9PLw/6KQhP+8o5T/nH5t/4tvXv+Vd2f/fmVU/8jAu//d3d3/yMjI/29vb/2UTTlVpmpY/4k8
        LP9+MSH/fjEh/34xIf9+MyP/fjQl/34xIf9+MSH/fjEh/34xIf9+MSH/fjEh/4JMQP/Mycj/////////////////////////////////7uvp/56Ief+5m4v/gGRU/4p3a/+DcWX/o5eP/93d3f+9vb3/bW1t8ZRN
        OVWjX03/hDcm/4Q3Jv+ENyb/hDcm/5BTRP+QVUn/hDcm/4Q3Jv+ENyb/hDcm/4Q3Jv+ENyb/hUk8/6ifnf/////////////////////////////////18/H/n4x//861qP+LcmL/+ff3//X08//n5uX/3Nzc/6+v
        r/9fX1/PlE05VaVjUf+HPiz/hz4s/4hBL/+VW07/y7Kt/9G8vf+RUkL/hz4s/4c+LP+HPiz/hz4s/4c+LP+HPiz/iGhh/+Li4v////////////////////////////n49/+6qp//yLCj/66Xiv+jj4P/g3Bi/8W8
        tf/b29z/cXFx9URERFyUTTlVqGdV/5dXSf+XWUz/mmBU/8Wln//o3t//5Nrd/5dZS/+MRDH/jEQx/4xEMf+MRDH/jEQx/4xEMf+LTj3/tbKx//z8/P////////////////////////////Dt6v+ynpH/qpKC/6GJ
        ev+aiHz/29fW/6urrP9YU1LGKysrLJRNOVWsdGH/yKum/+ri3v/r5OP/4NPT/6pzaf/Yw7//uo+I/5hSQv+USjn/lEo5/5RKOf+USjn/lEo5/5ZLO/+fgnr/ycjI//7+/v//////////////////////////////
        //////////////f39/+0tLP/eG9s/4RQQrEAAAAblE05Va9yYf+zhX3/vpiS/76Xkf+vf3X/oV9R/8+wq//WvLj/nVlK/5lQP/+ZUT//n2JV/59iVf+fYlX/oWNX/8SmoP+wnpz/vbq5//X09P//////////////
        ///////////////////y8vL/sLCw/3lqaP+qgXb/i0g1sAAAABuUTTlVr3Rh/5xWRf+cVkX/nFZF/5xWRf+eWkj/rXZp/+fa2f+yfXT/nFZF/6RnW//hzsn/9fDz//Xv8v/awr7/5M/P/8Gbk/+WXE7/j3Ns/8rF
        xP/Z2dn/2NfX/9TU1P/Ozs7/qKSj/4R0cP+LamD/pWFQ/76JfP+LSDWwAAAAG5RNOVWvd2X/olxK/6JcSv+iXEr/olxK/6JcSv+pbWD/7eHk/8Oblf+iXEr/qW1g/+zh3//Rsq7/xp6Y/+ja2v/z6er/wZeR/6Jc
        Sv+iXEr/rImD/9DJyv+hfXP/rJON/8Szsf+ebWL/qm9f/61rWf+qaVv/xI+E/4tINbAAAAAblE05VbF5Z/+lXk3/pV5N/6VeTf+lXk3/pV5N/6llWP/Psqv/2cC5/6dpWf+qcGH/8uTi/7yNgf+nZVT/sHps/+DG
        w/+6iX3/pV5N/6VeTf+pbFz/4svK/9Czr//XurP/3ca//6hnV/+wcGH/sG5d/6pnV//GmIj/i0g1sAAAABuUTTlVtX9r/6llUv+lZFL/pWRS/6VkUv+lZFL/pWRS/8Wgmf/z5+n/rHVo/7N9cP/p29f/r3lr/6Vk
        Uv+naVj/rXRp/6ttXv+lZFL/pWRS/6hqWv/Hopz/5dbT/+XRzP/Rs6//qGxc/7F1ZP+1eWj/t3xp/8+ll/+LSDWwAAAAG5RNOVW7hG3/sG5S/7BuUv+wblL/sG5S/7BtUv+wbFT/tX9z/+zd2f+8kof/yaad/+bS
        z/+sb1//qmxY/6psWP+rbln/sW9a/7JzWv+yc1r/r3Be/7F3af/26+n/+/j4/72Qhv+0fWv/zZyE/82ehP/Sp4//3bqo/4tINbAAAAAblE05VbuGcP+1dFf/tXRX/7V0V/+1dFf/tXRX/7V0Wf+wc2L/38vG/9vE
        vf/awbn/48zE/7B3Yv+6f2X/uoFo/7uEaf+9hmv/vYlw/8GKcP+/h27/snxr/9zCvf//////sn1s/7yHbv/Ln4P/z6CH/9iumP/gvKb/i0g1sAAAABuUTTlVu4hy/7V2Xf+1dl3/tXZd/7V2Xf+1el3/tXpd/7V6
        Z//Fm5D/697a/+vb1//UuLL/tX5t/72HbP+9h27/wItv/8COc//Gj3b/xpJ2/8aTdv+3gGv/x6Ka//Xq6f+3hHT/xpB6/9GijP/SppD/2bKd/9+/rf+LSDWwAAAAG5RNOVW7inb/tXxj/7V8Y/+3fGP/t3xj/7qA
        Y/+6gGP/uX1n/7qDc//27O3/+vX0/8mhl/+5g2//w41x/8ONc//GkXX/xpN4/8aVe//Glnv/xpl9/8KRef++jX3/1riv/7yMd//HmIH/0aaQ/9awmv/Vr5n/38Gt/4tINbAAAAAblE05VcCMd/+4f2b/uH9m/7mC
        Zv+9g2b/vYNr/72Ga/+7hW3/uYdy/+LOxv//////uod8/7yIcv/GkXb/xpN5/8aXe//Gl33/yZp+/8ybgv/OnYT/zp+G/8eXfv/HloD/xZd9/8yjiv/RqZD/1rGb/9aumP/hwK7/i0g1sAAAABuUTTlVwI57/72F
        a/+9hWv/vYZr/72Ja/+9iXD/vYtw/8OMcv+6g23/0bSr//35+v+6i33/wI53/8aWe//GmX//y5uB/8udg//OnoT/zqCI/86hif/OpIv/zqSL/86jif/TpIr/06iQ/9Spkv/as53/2K2Z/+PBsv+LSDWwAAAAG5RN
        OVXAj33/vYpu/72Lcf++i3P/wI5z/8aPdP/Gj3b/xpB2/8KNdv/HoZT/6tbT/7+Sgf/FlXv/ypuE/86ehv/OoIf/zqOH/86jjP/OpYz/zqaP/9Cnj//SqJD/1quU/9arlP/Wq5T/1quU/9u1n//ZsJr/5MW1/4tI
        NbAAAAAblE05VcCSgf/DjXP/w45z/8SRdf/Gknj/xpJ5/8aUe//Glnv/xpZ7/8STgP/NqZ3/xZaF/8qcg//OoYn/zqKL/86ljP/Opoz/06aO/9Ookf/TqZT/1aqU/9atlP/WrpT/1q6U/9aulP/WrpT/27ij/9mz
        m//kxrf/i0g1sAAAABeUTTlQwZGA+siVff/Gk3v/xpR7/8aWe//Glnz/xpd+/8mahP/Mm4T/zJqF/8mah//KnIj/zqKM/86mjP/Qp47/0qeP/9apkv/WqpT/1quU/9aulf/Wr5f/1q+X/9avl//Wr5f/1q+X/9av
        l//buab/2rWf/+PEtf+LSjafAAAAC5RNOTG6hnHb0aaP/8iag//GmYH/xpmB/8iagv/LnYT/zp6G/86hif/OoYr/zqKM/86ljP/OppD/06mR/9Wqk//Wq5T/1q2U/9atlv/Wrpn/1rGa/9aynP/Wspz/1rKc/9ay
        nP/Wspz/1rKc/9u8p//fwbD/0qqa/4VKOF8AAAACAAAAAJxZSlC5hXLWwJWF98WYhv/FmIb/xZiM/8WbjP/FnIz/xZyM/8WcjP/FnYz/x56N/8uekf/Ln5H/y6GR/8uhkf/LoZH/y6GR/8uhkf/LopH/y6SR/8uk
        kf/LpJH/y6SR/8ukkf/LpJH/zKSW/cSWguCkaVWQAAAAAAAAAAAAAAAAAAAAAJRNOSyUTTlNlE05VZRNOVWUTTlVlE05VZRNOVWUTTlVlE05VZRNOVWUTTlVlE05VZRNOVWUTTlVlE05VZRNOVWUTTlVlE05VZRN
        OVWUTTlVlE05VZRNOVWUTTlVlE05VZRNOVWUTTlTlE05NpRNOQoAAAAAAAAAAPAAAAPgAAABwAAAAIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
        AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAIAAAAPAAAADKAAAABgAAAAwAAAAAQAgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAIAAAAEAAAABAAA
        AAQAAAAEAAAABAAAAAQAAAAEAAAABAAAAAQAAAAEU1NTbVdXV+NycnL9dnZ3/2trbP1XV1jkSEhIdAAAAAQAAAAAAAAAAAAAAAAAAAACAAAADgAAABsAAAAdAAAAHQAAAB0AAAAdAAAAHQAAAB0AAAAdAAAAHUBA
        QDRmZmbMoaGh/9XV1f/U1NT/0dHR/8vLy//ExMT/j4+P/0xMTNdFRUUuAAAABAAAAACfZE6Oo2tV9aVsVv+lbFb/qW9a/613Yf+pcFr/r3lj/6t0XP+nb1j/r3lj/39va//T09P/saWd/+Xk4//r6+v/6urq/+Pj
        4//Y2Nj/ycnJ/6ioqP9MTEzRAAAAFJRNOVKpclv/ml9G/55jTP+hZ07/o2hM/6FmTP+rdVr/oWlQ/6FqTv+pclj/jm1g/8jIyP+/s6z/uZ2O/6aUiP/4+Pf/+vr6//f39//t7e3/3Nzc/8nJyf+CgoL/SkpKeJRN
        OYChZVD/kE86/51fSP+STzn/klI8/5BROv+aXUj/lFE5/5JQPP+IRC//i4B8///////s6Ob/rZiL/7iai/+nk4f/+/v6//7+/v/5+fn/7e3t/9jY2P/AwMD/UlJS3ZRNOYCYWkj/jks1/4pEL/+IQS//iEEv/4hA
        Lf+EOiv/ezIh/3syIf97MiH/srCw////////////9fLx/62Yi/+ukID/mod5//v6+f/+/v7/9/f3/+Pj4//Nzc3/a2tr/JRNOYCWV0j/kEg3/4Q+K/+EPSv/fTMj/3swIf97MCH/ezAh/3swIf97MCH/urq6////
        //////////////Tx8P+ijX//pIl4/455a/+ejYH/u6+m/+rq6v/T09P/fX19/5RNOYCdWkr/iD8t/3swIf97MCH/ezAh/3swIf97MCH/ezAh/3swIf97MCH/wb+////////////////////////y7+7/ppGC/6yM
        e/+FaVn/aE07/6+lnv/V1dX/gICA+pRNOYCXTz7/hDYl/4Q2Jf+IPi3/jlFE/4Q2Jf+ENiX/hDYl/4Q2Jf+ENiX/pZmW////////////////////////////sJ+U/8Sqnf+3q6L/8/Hw/+Xk4//X19f/Y2Nj4JRN
        OYCbV0b/iD8t/4xHNf+xi4L/2szO/5BOPv+IPy3/iD8t/4g/Lf+IPy3/iFxS/+Xl5f//////////////////////zcG5/8WtoP+0n5L/fGZX/83Fwf+lpaX/S0tLeZRNOYCvemv/wqCY/8aoo//fzcz/2MPC/6Bm
        Wv+QRzX/kEc1/5BHNf+QRzX/kEc1/6ugnf/+/v7//////////////////////9fOyP/FuK//2NHM/9LS0v9uYFv9AAAAHZRNOYC3hXn/yq6p/8qsp/+lal3/xqGb/8iln/+YTz7/mFA+/51dTv+dXU7/n15Q/8Wt
        qP+roJ3/8/Pz////////////////////////////ysrK/3pqaP+mbl77AAAAHZRNOYCtcF//nFdG/5xXRv+cV0b/qW5h/+LS0P+jYlT/o2RX/+nb2P/z6+//59fW/+nZ2P+jZVf/kmpi/764uP/GxcX/v7+//7m4
        uP+QhYH/kmpe/6ViUv+xd2f7AAAAHZRNOYCxdmP/pV1K/6VdSv+lXUr/qWdZ/+fX1v+rcWP/qWpb/+3e3P+rcGP/xJyS//Hj4v+palv/pV1K/7eFe//gy8r/xJ2S/9S2r/+taln/rWlX/61rXf+xeGf7AAAAHZRN
        OYC4fmv/pWNS/6VjUv+lY1L/pWNS/9K0r//Orqn/r3Vn/+DMxf+naFj/p2lY/7F7cf+nZVT/pWNS/6ltX//r3t7/2Ly1/8qnof+tb1//sXNj/7d8a/+zfm77AAAAHZRNOYDAiG3/sW9S/7FvUv+xb1L/sW1U/7eC
        df/k1ND/xp+U/9q9t/+rbFj/rW9b/69yXf+1dl//tXhf/69yXv/Usqv/+/f3/7eGef/Cj3f/zqCG/9Sqkv+8iHb7AAAAHZRNOYDCjXP/tXVa/7V1Wv+1dlr/tXda/7N6af/v5OP/1ryz/9K0q/+3fWP/vYVr/72I
        bf+/jHH/xI5z/8SNcf+zgHP//fj5/7N7a//KmYD/0qWO/9atl/++jXr7AAAAHZRNOYDCknz/tXtj/7d7Y/+3fWP/uYBj/7d6Zf/cwLn/9ezr/8ackv+9h23/woxz/8aQdf/GlHn/xpV7/8aYff+7iHX/1riv/7uK
        df/OoIj/1rCa/9Stlv++j3z7AAAAHZRNOYDIloD/uYBn/7uDZ/+9hGn/vYZr/7uFbf/Dmor//////7mFeP/EkHf/xpR5/8aYe//ImYD/zJuC/86ehP/Mnob/yJeA/8ibgv/Opoz/1rCa/9atmP++jHr7AAAAHZRN
        OYDKm4T/vYht/72Jb/+/jHH/wo1z/8aPc/+7inr/9enp/7uMfP/GmH3/ypuC/86ehP/OoIb/zqOK/86kjP/Opoz/0qiQ/9aokP/WqpT/2rKd/9qxnf++jHz7AAAAHZRNOYDMoIz/wo5z/8SQdf/Gknf/xpN7/8aV
        e//Eknv/zqqf/8SVhP/OoIb/zqGK/86kjP/Qpoz/0qeQ/9KplP/Wq5T/1q2U/9aulP/WrpT/2rWf/9q1n/++jXz7AAAAG5RNOXXQpJD/xpN7/8aVe//Glnv/xpiA/8qbhP/OnIT/ypuI/8yfiv/OpYz/0KeO/9So
        kP/WqpT/1qyU/9aulv/WsJj/1rCY/9awmP/WsJj/2rej/9y5pf+8jHvvAAAADJRNOR29inbtzqmW/9Ksmf/SrJv/1q+d/9ayn//Ws6H/1rWh/9i3o//duKn/37up/9+8qf/fvan/372t/9/Arf/fwa3/38Gt/9/B
        rf/fwa3/4cWz/9i2pf+kaliGAAAAAAAAAACUTTkZlE05b5RNOYCUTTmAlE05gJRNOYCUTTmAlE05gJRNOYCUTTmAlE05gJRNOYCUTTmAlE05gJRNOYCUTTmAlE05gJRNOYCUTTmAlE05fpRNOUgAAAAAAAAAAOAA
        AwCAAAAAgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAEAgAADACgAAAAQAAAAIAAAAAEAIAAAAAAAAAAAAAAA
        AAAAAAAAAAAAAAAAAAAAAAAAAAAAAgAAAAkAAAALAAAACwAAAAsAAAALAAAACzw8PBJdXV6Eh4eH8pSUlP+Hh4j7ZGRkuEZGRysAAAABnF1KFp1mUZubZVG1nWdTtaBsV7WkcFu1nmpVtaJvWrWIgH3Wv7q3/+Li
        4f/j4+P/2tra/8jIyP93d3fwPDw8M6JiTZaaYEf/nWFJ/55iSf+eY0n/oWhP/6BnTv+Ra1v/5eXl/6qRg/+0opj/+vr6//f39//l5eX/x8fH/1xcXLegY1GqjEgz/49LNv+JQzH/ikUy/4U+LP9+NST/moB5////
        ///o4+D/tp2O/6yZjv/9/Pz/9/f3/9ra2v+FhYX6nlxLqo1GNP+BOSf/fjQl/3swIf97MCH/ezAh/6eOif///////////+Tg3P+pkYL/moJ0/6WShv/b2dj/mZmZ/6FfTKqENyb/gTQk/4dENf+BNCT/gTQk/4E0
        JP+ff3j/////////////////yLy1/6SJev+/ta7/0c7L/5GRke+iX02qj0s7/59pXP/aysn/j0s6/4lBLv+JQS7/iU4//+Xk5P///////////+nk4P+1npD/mIR3/8rGxf9cWlqRp2pXqsmrpf/OtK//vZGJ/7F+
        c/+XTTz/mlZH/5tXSP+3pKD/7Ovq/////////////////+bm5v+Ug3//dUI0ZqlsWaqfWUf/n1lH/6ZmV//StbH/o2FS/+XU0//fysj/1ru3/5piVP/IvLv/vq+r/7alof+abmL/tHhr/3g/LmWscF2qpmFP/6Vh
        T/+mY1L/2L66/6xzZP/Rsan/qWta/7yMgv+lYU//vpGH/9zFwP+/k4j/sXNj/72IeP94Py5lsXdhqrJxVf+ycVX/snBW/8ymnf/Pr6f/yaGV/7J2X/+1emL/uX5l/7R7aP/z6ef/uIRz/82ehf/as53/eD8uZbF6
        Zaq1eWD/tnlg/7h9YP+7hXT/8ebl/8OWif/Aim//w490/8aTeP/Bj3b/1LSs/8COev/SqJH/27ik/3g/LmW1fWmquoJo/7yFaP+9h27/vIdv/+ze2/+8inn/xpV6/8maf//MnYP/zqCI/8qdhf/Oooj/1a6X/923
        pP94Py5ltYBuqsCMcf/Cj3X/xpF3/8WSeP/RraH/xZaB/82fiP/Oo4n/0aaO/9Kokf/Vq5P/1q2U/9mym//evKj/eT8vZLV+a5bKmoP/xpd+/8iZgP/MnYb/zJ6I/82ijP/SqJD/1aqS/9aslv/WsJj/1rGZ/9ax
        mf/ZtqD/3Lmn/4NGNEOcWUoUtIBukbmGc6q5hnequYh3qrmJd6q8inqqvot7qr6Me6q+jHuqvo17qr6Oe6q+jnuqvo59qbJ8aGwAAAAAgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
        AAAAAAAAAAAAAAAAAAAAAAAAAAEAAA==')
    $MainFORM.Add_Load($MainFORM_Load)
    $MainFORM.Add_FormClosing($MainFORM_FormClosing)

    $imgList_Search                     = New-Object 'System.Windows.Forms.ImageList'
    $imgList_Search.TransparentColor    = 'Transparent'
    $imgList_Search_BinaryFomatter      = New-Object 'System.Runtime.Serialization.Formatters.Binary.BinaryFormatter'
    $imgList_Search_MemoryStream        = New-Object 'System.IO.MemoryStream' (,[byte[]][System.Convert]::FromBase64String('
        AAEAAAD/////AQAAAAAAAAAMAgAAAFdTeXN0ZW0uV2luZG93cy5Gb3JtcywgVmVyc2lvbj0yLjAuMC4wLCBDdWx0dXJlPW5ldXRyYWwsIFB1YmxpY0tleVRva2VuPWI3N2E1YzU2MTkzNGUwODkFAQAAACZTeXN0
        ZW0uV2luZG93cy5Gb3Jtcy5JbWFnZUxpc3RTdHJlYW1lcgEAAAAERGF0YQcCAgAAAAkDAAAADwMAAAB8HwAAAk1TRnQBSQFMAgEBCQEAAUABAAFAAQABEAEAARABAAT/ASEBAAj/AUIBTQE2BwABNgMAASgDAAFA
        AwABMAMAAQEBAAEgBgABMP8A/wAgAAIkASkBNwEqATEBeAHlAisBMwFJEAACKwEzAUkBQgFDAaIB5QIjASgBNdQAAiIBJwE1ASQBJgGSAe8BLQEwAeoB/wEmASkBgQH3AisBMgFKCAACKwExAUkBJgEpAYQB9wEt
        ATEB6gH/ASQBJgGSAe8CIgEnATXQAAEpATABegHkASoBLwHpAf8CAAHzAf8BEwEVAe0B/wEkASgBawH3AisBMQFKAisBMQFKASUBKAFsAfcBEwEVAe0B/wIAAfMB/wEtATEB6QH/AjsBjQHj0AABKwEsATUBSQEf
        ASYBngH3AQ0BEgHiAf8CAAHiAf8BEQEUAdwB/wEeASQBWwH4AR8BJgFaAfcBEQEUAdwB/wIAAeIB/wEPARMB4gH/ASMBJwGeAfcCLgE3AUnUAAIrATUBSQEaASMBnwH3AQsBEQHTAf8CAAHQAf8BDAESAcgB/wEM
        ARIByQH/AgAB0AH/AQsBEgHTAf8BGwEkAZ8B9wIrATUBSdwAAisBNgFJARcBIgGhAfcBCQERAcIB/wIAAbwB/wIAAbwB/wEJAREBwgH/ARgBIwGhAfcCKwE2AUngAAIrATYBSQEbASYBpAH3ATABNwHHAf8CLgHD
        Af8CMQHCAf8BMQE5AcIB/wEWASMBoQH3AisBNgFJ3AACKwE3AUkBHQEoAagB9wFAAUYBzAH/AjwByQH/AUgBTAHHAf8BSAFMAcgB/wI/AcoB/wFYAV4B0gH/ASMBLAGpAfcCKwE3AUnUAAIqATYBSAEhASsBrQH3
        AVQBWQHWAf8CUwHTAf8BXgFhAdQB/wEqATIBjwH4ASkBMQGQAfgBXAFfAdQB/wJTAdMB/wFaAV4B1wH/AS0BMwGvAfcCKgE2AUjQAAEXARkBlwHjAWMBbAHkAf8CagHmAf8BcgF1AeYB/wEvATYBrgH3AisBNQFK
        AisBNQFKAS4BNAGvAfcBbwFyAeYB/wJqAeYB/wF8AYMB5wH/ARcBGQGXAePQAAIiASkBNQElASoBrgHvAYIBiAHyAf8BMwE4AbsB9wIrATgBSQgAAisBOAFJATABNgG7AfcBhAGKAfIB/wEqAS4BrgHvAiIBKQE1
        1AACIgEpATUBQgFDAaoB4wIrATcBSBAAAisBNwFIAUMBRQGrAeQCIgEpATX/AP8A/wD/AKQAATIBOgE0AWIBNQFCATcBfgMFAQcsAAMDAQQBFgEVARYBHAFVAVQBVQGAAXMCcgG/AYUCgwHsAYUCgwHsAXMCcgG/
        AVUBVAFVAYABFgEVARYBHAMDAQQcAAMZASEDWAGPA3MB6AN0Af0DdQH9A3YB6QNZAY8DGQEhIAADHwEnA1sBhwOLAekDigH9A4cB/QOCAekDVQGHAx4BJyAAATEBOAEzAVwBHAGrAS8B/wEWAaIBKQH/ATABMwEw
        AVkoAAMDAQQDKgE5AW0CbAGtAZoBlgGiAfsBjgGKAbgB/wGAAXwBwgH/AYABfAHDAf8BjgGLAbkB/wGaAZYBowH7AW0CbAGtAyoBOQMDAQQTAAEBAy0BPgNmAb8DiQH/A7QB/wPIAf8DyAH/A7UB/wOOAf8DagHA
        Ay4BPgMBAQIUAAMvAT4DfwHMAa4BqwGoAf8DygH/A9oB/wPVAf8DuwH/A5kB/wNvAcwDLgE+GAABKAEqASgBQAEyAa0BRAH0AS0BtAFBAf8BJwGzATsB/wEtAXIBNgHSAw4BEyQAARYBFQEWARwBbQJsAa0BmgGW
        AakB+QFCAT8BsQH/ARoBGQGsAf8CDAGwAf8CDAG8Af8CGgGzAf8BQQE/AaoB/wGaAZcBsQH5AW0CbAGtARYBFQEWARwQAAMeASgDaQHNA5YB/gPiAf8D8AH/A+8B/wPtAf8D6gH/A9wB/wObAf4DbQHMAx4BKBAA
        Ax4BJgOGAcsBtQGnAaAB/gG8AawBoQH/AegB5QHjAf8D9QH/A/AB/wPpAf8D2AH/A6IB/gNzAcwDHgEnEAABJQEmASUBOQE/AaoBUQHqAUQBzwFaAf8BOwHFAVAB/wE3Ab0BTAH/ATIBvgFHAf8BNgFCATgBfCQA
        A1QBfwGbAZcBowH7AWgBZQG4Af8CmwHXAf8CfgG9Af8CCwGUAf8CDQGtAf8CjAHPAf8CpQHaAf8BPwE+AaQB/wGaAZYBowH7AVUBVAFVAYAQAANdAZUDkAH/A+gB/wP3Af8D9AH/A/IB/wPvAf8D7QH/A+wB/wPd
        Af8DkAH/A1wBlRAAA2QBiQGgAZcBkQH/Ac4BuwGwAf8BywGzAaYB/wG6AacBmgH/AegB4wHfAf8D/QH/A/gB/wPuAf8D2gH/A5oB/wNXAYkMAAEvATMBMAFRAUgBuAFaAe8BUwHhAWsB/wFHAcsBXQH8ATUBQAE2
        AWQBQwGTAU8BywFGAdABWwH/ATYBngFGAewDHgEtIAABcwJyAb8BlAGQAbkB/wE1ATQBugH/AoEBzwH/AtwB4AH/AoABtAH/AoABvQH/At8B4wH/AoUBzgH/AR0BHAGqAf8BjgGLAbgB/wFzAnIBvxAAA30B7AO/
        Af8D+QH/A/kB/wP3Af8D9AH/A/IB/wPvAf8D7QH/A+oB/wO1Af8DdQHqEAADogHuA+IB/wHcAdQBzwH/AcYBsgGlAf8BwQGpAZsB/wGwAZ4BkAH/AecB4QHdAf8B7wHsAekB/wH1AfQB8wH/A+sB/wPAAf8DhQHu
        DAABRwHJAVsB/wFYAeUBcQH/AU4BzgFiAfgBMwE6ATQBXQQAATEBOwEyAVIBSwHVAWIB/wFLAdoBYgH/AToBXQE/AawDAwEEHAABhQKDAewBkQGNAccB/wEXARYBuAH/AhwBtAH/AokBzgH/AtwB3wH/AtwB3wH/
        AnwBwwH/AhQBpwH/Ag4BtAH/AYEBfAHBAf8BhQKDAewQAAODAf4D1QH/A/0B/wP7Af8D+QH/A/cB/wPzAf8D8gH/A+8B/wPtAf8DxgH/A3cB/RAAA6YB/QP5Bf8B1QHMAcUB/wHBAawBnwH/AcQBrgGgAf8BqAGS
        AYQB/wGtAZgBiwH/AbgBpgGbAf8B5gHkAeIB/wPbAf8DigH9DAABQgFrAUcBlgFFAYYBTgHAASkBLAEpAUIMAAFGAYcBTwG4AVUB3wFsAf8BSAHOAV4B/gExATQBMQFaHAABhQKDAewBlwGTAckB/wI2AcsB/wIU
        AcAB/wJqAdIB/wLjAeQB/wLgAeIB/wJmAbQB/wIIAZMB/wEPAQ4BrwH/AYIBfQHAAf8BhQKDAewQAAOJAf4D1wH/A/4B/wP9Af8D+wH/A/kB/wP3Af8D9AH/A/IB/wPvAf8DxgH/A3cB/RAAA6gB/QP5Cf8B0AHH
        AcAB/wHIAbUBqgH/Ab0BpAGWAf8BqAGSAYMB/wGfAYoBegH/AbkBrAGjAf8D4AH/A40B/SQAAR4BIQEeASwBTQHGAWEB9AFXAeMBbwH/AT8BjAFMAdoDFQEdGAABcwJyAb8BogGdAb8B/wFVAVQB1gH/AoMB4gH/
        AucB+AH/AsUB6wH/AbgBtwHYAf8C3wHiAf8CZwG0Af8BMAEvAZsB/wGSAY4BtwH/AXMCcgG/EAADiwHrA8gB/wP8Af8D/gH/A/0B/wP7Af8D+QH/A/cB/wP0Af8D8AH/A7QB/wNzAekQAAOnAe4D5An/AfIB8AHu
        Af8BrgGbAY4B/wHKAbYBqwH/AcgBvQG1Af8B8wHwAe8B/wHtAesB6QH/A8wB/wOMAe4oAAE7AVMBPwF3AUsB1AFiAf8BUAHeAWcB/wE7AVQBPgGeAwEBAhQAA1QBfwGgAZ0BpgH7AYgBhQHeAf8C2gH2Af8C0AH2
        Af8CQQHUAf8BOgE7AcoB/wLJAeEB/wLVAeEB/wFuAWwBwQH/AZsBlwGjAfsBVQFUAVUBgBAAA2UBlAOmAf8D8AH/A/4B/wP+Af8D/QH/A/sB/wP5Af8D9wH/A+MB/wOJAf8DWAGREAADaAGKA8oB/wP9Bf8B+AH3
        AfYB/wG6AakBnAH/AeABzQHEAf8BzwG+AbUB/wGzAaQBmQH/AdQBzQHIAf8DrgH/A1wBiigAAwMBBAFAAYMBSgHAAUMByQFZAf8BPgHBAVIB/gEzATcBMwFgFAABFgEVARYBHAFsAmsBrAGiAZ4BsgH5AYYBhAHf
        Af8BZgFlAeEB/wFBAUAB2gH/ATwBOwHTAf8CUgHRAf8BdQFzAdMB/wGfAZsBrwH5AW0CbAGtARYBFQEWARwQAAMfAScDfwHMA7EB/gPvAf8D/AH/A/4B/wP9Af8D+QH/A+cB/wOWAf4DaAHLAx4BJxAAAx4BJgOT
        AcsD2AH+A/0F/wH2AfQB8wH/AcgBvAGzAf8BuwGrAZ4B/wHMAcEBuQH/A8IB/gOBAcsDHwEnLAABHAEeARwBKAFBAaYBUAHwAUMBwQFXAf8BNwGOAUMB5gEfASABHwEvEAADAwEEAykBOAFsAmsBrAGhAZ0BpwH7
        AaYBogHBAf8BngGZAc0B/wGZAZUBygH/AZsBlwG7Af8BnQGZAaQB+wFtAmwBrQMqATkDAwEEEwABAQMvAT0DeQG/A6QB/wPIAf8D2QH/A9YB/wO+Af8DjgH/A2cBwAMtAT4DAQECFAADMAE9A5MEzAH/A+QB/wP0
        Af8D9AH/A+AB/wPAAf8DggHMAy8BPjQAATUBQQE2AV8BQgGwAVEB/wFHAb0BWQH/AToBZwFAAcQDEAEWEAADAwEEARYBFQEWARwDVAF/AXMCcgG/AYUCgwHsAYUCgwHsAXMCcgG/A1QBfwEWARUBFgEcAwMBBBwA
        AxoBIQNiAY4DigHoA4oB/QOEAf0DfQHoA1oBjgMaASEgAAMeASYDZwGIA6UB6QOoAf0DpQH9A58B6QNjAYgDHwEnPAABPgFgAUIBmAE8AakBSwH/AT8BtQFQAf8BOQFLATsBkvAAAwYBCAE+AXIBRAGyATkBkwFE
        AegBMQE3ATIBWfQAAwIBAwMPART/ABUAAwMBBAMRARUDGQEfAxkBHwMZASADGQEgAxgBHwMYAR8DEQEVAwMBBNgAAxYBHAF0AnYBlQGyArYB7QGxAbYBtwH7AacBqQGqAf8BnAKfAf8BmwKeAfwBlwKZAewBZwJo
        AZIDFgEcHAABGQEaARkBIQFBAWUBSAGPATABmAFFAegBHgGlATsB/QEbAagBOQH9ASkBnwFDAekBPgFoAUYBjwEYARoBGQEhIAADGQEhA1gBjwNzAegDdAH9A3UB/QN2AekDWQGPAxkBIRgAASoBkAGnAdYBEgGa
        AbkB/wEQAZoBuwH/AQ8BmQG7Af8BDwGZAbsB/wEPAZQBtAH/AQ8BlAG0Af8BEAGaAbsB/wEQAZoBuwH/ARABmgG7Af8BEQGZAbkB/wEpAZABpwHXDAADAgEDAxQBGQEjAiQBLANPAWEBiwGMAY0CrQGwAbEB5wGr
        Aa4BrwH9AZoCnQH+AZYCmAHrAXsCfAGvAUQCRQFbAyEBKgMUARoDAgEDDwABAQEqAS8BKwI+AXsBSQG/AUYBrQFaAf8BgQHLAZEB/wGdAdYBqAH/AaEB3QGuAf8BfQHTAZAB/wE6AboBVQH/ATMBhwFFAcABKAEw
        ASoBPgMBAQITAAEBAy0BPgNmAb8DiQH/A7EB/wPBAf8DyAH/A7UB/wOOAf8DagHAAy4BPgMBAQIQAAEzAYoBnQHAAR8BwAHkAf0BGQHGAfAB/wEVAcQB8AH/ARQBwwHwAf8BDAF8AZwB/wEMAXwBmwH/ARcBxQHx
        Af8BGQHHAfEB/wEaAccB8QH/AR0BvgHiAf0BMwGKAZ0BwAwAAwwBDwFvAnIBjQGIAYsBjAGwAYsCjgG0AZYBmQGaAccBqgKvAesBrgGyAbMB/gGmAqsB/gGgAqUB7wGQApMBygGCAoQBtAF/AoEBsAFoAmkBkQMN
        AREMAAEdAR8BHgEoAT0BggFKAc0BXwG2AW8B/gHFAeABygH/AXUBwgGCAf8BRQG3AVcB/wHUAd4B1QH/AekB6wHpAf8BzQHlAdIB/wFNAcYBZwH+AS8BjQFCAcwBHQEgAR0BKBAAAx4BKANpAc0DlgH+A9YB/wOm
        Af8DjgH/A9oB/wPqAf8D3AH/A5sB/gNtAcwDHgEoEAABNgFOAVQBZwEnAakBxQHoASIBywHuAf8BIAHNAfMB/wEeAcsB8gH/AQ4BVAFjAf8BDwFUAWIB/wEiAc4B8wH/ASUB0QHzAf8BJAHMAe0B/wEoAaoBxQHp
        ATYBTwFUAWgMAAMXARwBtwG7AbwB8AGqAp0B/wGZAXoBewH/AZkCeQH/AZcBeAF5Af8BnQJ3Af8BqgGLAXcB/wGpAYoBdQH/AagBigF1Af8BqQGNAXQB/wGyAakBmgH/AaEBpAGiAfIDFwEdDAABSAFpAU8BlQFY
        AbEBagH/AeAB7wHjAf8BswHdAboB/wEbAasBMgH/ARABqAEoAf8BaQHBAXcB/wPqAf8D7AH/Ac4B5gHTAf8BOwG9AVcB/wE+AWwBRwGVEAADXQGVA5IB/wPpAf8DzQH/A3YB/wNwAf8DoQH/A+oB/wPsAf8D3QH/
        A5AB/wNcAZUQAAEaARwBHQEkAToBgAGOAawBKQHEAeAB+gEvAdgB8wH/AS8B2QH1Af8BIQGXAaoB/wEhAZcBqQH/ATEB2wH1Af8BMAHZAfMB/wEpAcQB4AH6AToBgAGOAa0BGgEcAR0BJAwAAxkBHwK+Ab8B/wGP
        AWcBXQH/AXMBJgESAf8BcgEiARIB/wFzASEBEgH/AYIBJAESAf8BoQFQARUB/wGuAWQBHAH/AbIBZwEbAf8BsAFoARkB/wG0AZYBagH/AqoBpgH/AhgBGQEfDAABQgGdAVUB7AGVAdQBogH/AfQB9gH0Af8BTAG5
        AV4B/wEiAa0BNwH/ASgBrgE9Af8BNwGyAUoB/wHKAd0BzQH/A+0B/wHoAesB6QH/AX0B0wGQAf8BKQGfAUEB6hAAA30B7AO+Af8D9QH/A5IB/wN5Af8DfAH/A4UB/wPWAf8D7QH/A+oB/wO1Af8DdQHqEAADCAEK
        ATUBSwFQAWIBMwGrAb8B4AE6Ad4B8AH/AUEB6AH4Af8BGwFmAW4B/wEaAWQBbQH/AT4B5QH4Af8BNwHbAfAB/wEyAaoBvwHgATUBTAFRAWMBCAIJAQsMAAMZAR8CvQG8Af8BjgFlAU8B/wF2ASgBAAH/AXcBHwEA
        Af8BgQEfAQAB/wGPASQBAAH/AbgBYgELAf8BzQGHAS4B/wHTAYsBLQH/Ac4BhwElAf8BwQGjAWsB/wKtAacB/wMZASAMAAE7AasBUwH+AbcB5gHBAf8D+AH/AXoBygGHAf8BkQHMAZoB/wGTAcoBnAH/ARkBqgEv
        Af8BiwHKAZUB/wPsAf8D7QH/AZ8B3AGsAf8BHQGoATsB/RAAA4MB/gPVAf8D+AH/A60B/wO2Af8DtgH/A3QB/wOzAf8D7AH/A+0B/wPGAf8DdwH9EAADAQECARsBHwEgAScBPAF9AYkBpgE4Ac4B4AH5AUkB7QH3
        Af8BEwE+AUAB/wERATwBPwH/AUUB6gH4Af8BNgHNAeEB+QE8AX0BigGnARwCIAEoAwEBAgwAAxkBHwG9Ab8BvAH/AZYBcwFRAf8BhAE4AQEB/wGFAScBAAH/AZQBKwEAAf8BpwE1AQAB/wHWAZIBPAH/AeUBrwFp
        Af8B6gGxAWUB/wHoAa8BXQH/AdIBuQGKAf8CsgGtAf8BGQIaASAMAAE9AbIBVwH+AbgB6QHCAf8D/gH/A/0B/wP7Af8D7QH/ASwBsAFBAf8BRwGzAVgB/wHSAeEB1AH/A+8B/wGhAdsBrQH/ASEBpwE9Af0QAAOJ
        Af4D1wH/A/4B/wP9Af8D+wH/A+0B/wOAAf8DjAH/A9sB/wPvAf8DxgH/A3cB/RQAAwcBCQExAUIBRgFWATgBoQGyAdMBRgHiAe8B/QEVAUIBRAH/ARUBQQFDAf8BRAHiAe8B/QE5AaMBtAHUATEBQwFHAVcDBwEJ
        EAADGQEfAr4BvAH/AZgBcgFSAf8BigE2AQMB/wGRASwBAAH/AagBNwEAAf8BvwFNAQAB/wHqAbcBcgH/AfEByAGPAf8B9AHKAYwB/wH0AckBhwH/AdoByAGiAf8BtQG2AbEB/wMZAR8MAAFKAawBYAHrAZwB4AGr
        Af8B/AH9AfwB/wP+Af8D/QH/A/sB/wGMAc0BlgH/ARkBqgEwAf8BogHPAakB/wHvAfEB7wH/AYQBzgGTAf8BLwGYAUUB6RAAA4sB6wPIAf8D/AH/A/4B/wP9Af8D+wH/A7UB/wN0Af8DvgH/A/AB/wO0Af8DcwHp
        GAABGAEaARsBIQE7AXEBfAGZATwBxwHYAfIBLgGOAZMB/wEtAY8BkwH/AT0BygHaAfIBPAFzAX4BmgEYARoBGwEhFAADGQEfAr0BuwH/AZYBaQFNAf8BkAEwAQAB/wGlATkBAAH/AcEBRgEAAf8B3QFuAQcB/wH3
        AdcBpwH/AfkB3AGuAf8B+QHeAa0B/wH3AdsBpwH/Ad0B0gGzAf8BtwG5AbUB/wMZAR8MAAFMAXIBVQGUAWQBywF6Af8B5wH4AeoF/wP+Af8D/QH/Ac4B6QHTAf8BMgGzAUcB/wFbAbwBagH/AdkB6gHcAf8BSgGu
        AV0B/wFBAWUBSQGREAADZQGUA6cB/wPxBf8D/gH/A/0B/wPfAf8DhAH/A5kB/wPjAf8DiwH/A1gBkRgAAwUBBwExAUEBRQFVATYBnwGxAdMBRgHkAfAB/QFJAecB8QH9ATkBowG0AdQBMQFCAUYBVgMFAQcUAAMZ
        AR8BvQG8AbsB/wGWAWIBSwH/AZgBLwEAAf8BsgFAAQAB/wHPAU4BAAH/AeoBigEgAf8B9wHhAa8B/wH3Ad4BpAH/AfYB3gGiAf8B8wHZAZcB/wHbAdABqwH/AbkBvAG3Af8DGgEgDAABHQEfAR4BJwFKAZoBXAHM
        AXgB1AGMAf4B5QH2AekB/wH8Av0B/wP+Af8D+wH/AfAB8gHxAf8B0wHkAdcB/wFfAbYBbwH+ATsBgQFIAcsBHAEfAR0BJxAAAx8BJwN/AcwDtAH+A/AB/wP8Af8D/gH/A/sB/wPxAf8D3gH/A5YB/gNoAcsDHgEn
        HAABFAEWARcBHAE6AXIBfgGcATUBxwHaAfYBOwHNAd0B9gE6AXQBgAGeARQBFgEXARwYAAMZAR8BvQK/Af8BmwF+AXMB/wGeAWUBSwH/Aa0BbgFMAf8BvgF5AU0B/wHMAZ8BZgH/AdEBxQGfAf8B0wHEAZcB/wHU
        AcQBlAH/AdMBwwGQAf8BzAHHAawB/wG5Ab0BugH/AxkBHw8AAQEBKgExASwBPQFMAZIBWwG/AWIByQF6Af8BnAHfAasB/wG5AeoBxAH/AbgB5wHCAf8BlgHUAaIB/wFTAa4BZQH/AUEBfAFMAcABKgEvASsBPgMB
        AQITAAEBAy8BPQN5Ab8DpgH/A8gB/wPZAf8D1gH/A74B/wOOAf8DZwHAAy0BPgMBAQIcAAMCAQMBLQE6AT0BSwExAZoBrwHVATQBngGxAdUBLQE6AT0BSwMCAQMYAAMRARUBmwGeAZ8BxAG+Ar8B/wG+AbwBuwH/
        AcABvQG7Af8BwgG/AbsB/wLEAb4B/wHEAcgBwwH/AcQByAHDAf8BxQHJAcMB/wHFAckBwwH/AcUBzAHJAf8BnAGgAaEB0QMTARgUAAEZARsBGQEhAUsBbgFTAY4BTAGrAWAB6AE/AbIBVwH9AT0BqwFTAf0BRQGb
        AVcB6AFIAWUBTQGOARkBGgEZASEgAAMaASEDYgGOA4oB6AOKAf0DhAH9A30B6ANaAY4DGgEhKAADCAEKASEBJgEnATABIQEmAScBMAMIAQocAAMBAQIDEQEVAxkBHwMZAR8DGQEfAxkBHwMZAR8DGQEfAxkBHwMZ
        AR8DGQEfAxkBHwMSARcDAgED/wDFAAFCAU0BPgcAAT4DAAEoAwABQAMAATADAAEBAQABAQUAAYABARYAA/8BAAL/BgAC/wYAAeMBxwYAAcEBgwYAAcABAwYAAcABAwYAAeABBwYAAfABDwYAAfABDwYAAeABBwYA
        AcABAwYAAcABAwYAAcEBgwYAAeMBxwYAAv8GAAL/BgAO/wH4Af8B4AEHAfABDwHwAQ8B8AH/AcABAwHAAQMB4AEHAeABfwHAAQMBwAEDAcABAwHAAX8BwAEDAcABAwHAAQMBgAE/AcABAwHAAQMBwAEDAYQBHwHA
        AQMBwAEDAcABAwGOAR8BwAEDAcABAwHAAQMB/gEPAcABAwHAAQMBwAEDAf8BBwHAAQMBwAEDAcABAwH/AQcBwAEDAcABAwHAAQMB/wGDAcABAwHAAQMB4AEHAf8BwQHgAQcB8AEPAfABDwH/AeEH/wHhB/8B8wj/
        AeABBwb/AeABBwHwAQ8B8AEPAcABAwGAAQEBwAEDAcABAwHAAQMBgAEBAcABAwHAAQMBwAEDAYABAQHAAQMBwAEDAcABAwGAAQEBwAEDAcABAwHAAQMBgAEBAcABAwHAAQMBwAEDAYABAQHAAQMBwAEDAeABBwGA
        AQEBwAEDAcABAwHwAQ8BgAEBAcABAwHAAQMB8AEPAYABAQHAAQMBwAEDAfgBHwGAAQEBwAEDAcABAwH4AR8BgAEBAfABDwHwAQ8B/AE/AYABAQ7/Cw=='))
    $imgList_Search.ImageStream         = $imgList_Search_BinaryFomatter.Deserialize($imgList_Search_MemoryStream)
    $imgList_Search_BinaryFomatter      = $null
    $imgList_Search_MemoryStream        = $null

    $tab_Pages                          = New-Object 'System.Windows.Forms.TabControl'
    $tab_Pages.Location                 = ' 12,  12'
    $tab_Pages.Size                     = '443, 396'
    $tab_Pages.Padding                  = ' 12,   6'
    $tab_Pages.SelectedIndex            = 0
    $tab_Pages.TabIndex                 = 0
    $tab_Pages.Add_SelectedIndexChanged($tab_Pages_SelectedIndexChanged)
    $MainFORM.Controls.Add($tab_Pages)

    $tab_Page0 = New-Object 'System.Windows.Forms.TabPage'('Welcome');     $tab_Pages.Controls.Add($tab_Page0)
    $tab_Page1 = New-Object 'System.Windows.Forms.TabPage'('Server List'); $tab_Pages.Controls.Add($tab_Page1)
    $tab_Page2 = New-Object 'System.Windows.Forms.TabPage'('Options');     $tab_Pages.Controls.Add($tab_Page2)
    $tab_Page3 = New-Object 'System.Windows.Forms.TabPage'('Results');     $tab_Pages.Controls.Add($tab_Page3)
    $tab_Page4 = New-Object 'System.Windows.Forms.TabPage'('Search');      $tab_Pages.Controls.Add($tab_Page4)
    #endregion
    #region TAB 0 - Introduction
    $lbl_t0_01                          = New-Object 'System.Windows.Forms.Label'
    $lbl_t0_01.Location                 = ' 12,  12'
    $lbl_t0_01.Size                     = '411,  21'
    $lbl_t0_01.Text                     = "Welcome to the $script:appName"
    $tab_Page0.Controls.Add($lbl_t0_01)

    $lbl_t0_02                          = New-Object 'System.Windows.Forms.label'
    $lbl_t0_02.Location                 = ' 12,  39'
    $lbl_t0_02.Size                     = '411,  42'
    $lbl_t0_02.Text                     = 'This tool will allow you to put any number of SCOM managed servers into maintenance mode quickly and easily.'
    $tab_Page0.Controls.Add($lbl_t0_02)

    $lbl_t0_03                          = New-Object 'System.Windows.Forms.label'
    $lbl_t0_03.Location                 = ' 12, 136'
    $lbl_t0_03.Size                     = ' 94,  23'
    $lbl_t0_03.Text                     = 'Server :'
    $lbl_t0_03.TextAlign                = 'MiddleLeft'
    $tab_Page0.Controls.Add($lbl_t0_03)

    $txt_t0_01                          = New-Object 'System.Windows.Forms.TextBox'
    $txt_t0_01.Location                 = '112, 136'
    $txt_t0_01.Size                     = '211,  23'
    $tab_Page0.Controls.Add($txt_t0_01)

    $lbl_t0_04                          = New-Object 'System.Windows.Forms.label'
    $lbl_t0_04.Location                 = ' 12, 168'
    $lbl_t0_04.Size                     = ' 94,  23'
    $lbl_t0_04.Text                     = 'Username :'
    $lbl_t0_04.TextAlign                = 'MiddleLeft'
    $tab_Page0.Controls.Add($lbl_t0_04)

    $txt_t0_02                          = New-Object 'System.Windows.Forms.TextBox'
    $txt_t0_02.Location                 = '112, 168'
    $txt_t0_02.Size                     = '211,  23'
    $tab_Page0.Controls.Add($txt_t0_02)

    $lbl_t0_05                          = New-Object 'System.Windows.Forms.label'
    $lbl_t0_05.Location                 = ' 12, 200'
    $lbl_t0_05.Size                     = ' 94,  23'
    $lbl_t0_05.Text                     = 'Password :'
    $lbl_t0_05.TextAlign                = 'MiddleLeft'
    $tab_Page0.Controls.Add($lbl_t0_05)

    $txt_t0_03                          = New-Object 'System.Windows.Forms.TextBox'
    $txt_t0_03.Location                 = '112, 200'
    $txt_t0_03.Size                     = '211,  23'
    $txt_t0_03.PasswordChar             = ([char]9679).ToString()    # TODO: Change for Blob symbol
    $tab_Page0.Controls.Add($txt_t0_03)

    $chk_t0_01                          = New-Object 'System.Windows.Forms.CheckBox'
    $chk_t0_01.Location                 = '112, 229'
    $chk_t0_01.Size                     = '211,  23'
    $chk_t0_01.Text                     = 'Use Windows Credentials'
    $chk_t0_01.Checked                  = $False
    $chk_t0_01.Add_CheckedChanged($chk_t0_01_CheckedChanged)
    $tab_Page0.Controls.Add($chk_t0_01)

    $btn_t0_01                          = New-Object 'System.Windows.Forms.Button'
    $btn_t0_01.Location                 = '112, 279'
    $btn_t0_01.Size                     = '211,  35'
    $btn_t0_01.Text                     = 'Connect'
    $btn_t0_01.Add_Click($btn_t0_01_Click)
    $tab_Page0.Controls.Add($btn_t0_01)

    $lbl_t0_06                          = New-Object 'System.Windows.Forms.label'
    $lbl_t0_06.Location                 = ' 12, 342'
    $lbl_t0_06.Size                     = '411,  21'
    $lbl_t0_06.Text                     = 'For any bugs or comments, email support@myrandomthoughts.co.uk'
    $lbl_t0_06.TextAlign                = 'BottomCenter'
    $lbl_t0_06.Enabled                  = $False
    $tab_Page0.Controls.Add($lbl_t0_06)
    #endregion
    #region TAB 1 - Server List
    $lbl_t1_01                          = New-Object 'System.Windows.Forms.Label'
    $lbl_t1_01.Location                 = ' 12,  12'
    $lbl_t1_01.Size                     = '411,  32'
    $lbl_t1_01.Text                     = 'In most cases the fully qualified server name will be required.  If in doubt, either select objects using the search function or click "Verify"'
    $tab_Page1.Controls.Add($lbl_t1_01)

    $txt_t1_01                          = New-Object 'System.Windows.Forms.TextBox'
    $txt_t1_01.Location                 = ' 12,  63'
    $txt_t1_01.Size                     = '411, 225'
    $txt_t1_01.Multiline                = $True
    $txt_t1_01.ScrollBars               = 'Vertical'
    $txt_t1_01.Add_LostFocus($txt_t1_01_LostFocus)
    $txt_t1_01.Add_TextChanged($txt_t1_01_TextChanged)
    $tab_Page1.Controls.Add($txt_t1_01)

    $btn_t1_01                          = New-Object 'System.Windows.Forms.Button'
    $btn_t1_01.Location                 = ' 12, 294'
    $btn_t1_01.Size                     = '125,  25'
    $btn_t1_01.Text                     = 'Verify List'
    $btn_t1_01.Add_Click($btn_t1_01_Click)
    $tab_Page1.Controls.Add($btn_t1_01)

    $btn_t1_02                          = New-Object 'System.Windows.Forms.Button'
    $btn_t1_02.Location                 = ' 12, 325'
    $btn_t1_02.Size                     = '125,  25'
    $btn_t1_02.Text                     = 'Search SCOM'
    $btn_t1_02.Add_Click($btn_t1_02_Click)
    $tab_Page1.Controls.Add($btn_t1_02)

    $btn_t1_03                          = New-Object 'System.Windows.Forms.Button'
    $btn_t1_03.Location                 = '298, 315'
    $btn_t1_03.Size                     = '125,  35'
    $btn_t1_03.Text                     = 'Next  >'
    $btn_t1_03.Add_Click($btn_t1_03_Click)
    $tab_Page1.Controls.Add($btn_t1_03)
    #endregion
    #region TAB 2 - Options
    $lbl_t2_01                          = New-Object 'System.Windows.Forms.Label'
    $lbl_t2_01.Location                 = ' 12,  12'
    $lbl_t2_01.Size                     = '315,  21'
    $lbl_t2_01.Text                     = 'Category'
    $lbl_t2_01.TextAlign                = 'MiddleLeft'
    $tab_Page2.Controls.Add($lbl_t2_01)

    $chk_t2_01                          = New-Object 'System.Windows.Forms.CheckBox'
    $chk_t2_01.Location                 = '333,  12'
    $chk_t2_01.Size                     = ' 90,  21'
    $chk_t2_01.Text                     = 'Planned'
    $chk_t2_01.Checked                  = $True
    $chk_t2_01.CheckAlign               = 'MiddleRight'
    $chk_t2_01.TextAlign                = 'MiddleRight'
    $chk_t2_01.Add_CheckedChanged($chk_t2_01_CheckedChanged)
    $tab_Page2.Controls.Add($chk_t2_01)

    $cmo_t2_01                          = New-Object 'System.Windows.Forms.ComboBox'
    $cmo_t2_01.Location                 = ' 12,  39'
    $cmo_t2_01.Size                     = '411,  23'
    $cmo_t2_01.DropDownStyle            = 'DropDownList'
    $tab_Page2.Controls.Add($cmo_t2_01)

    $lbl_t2_02                          = New-Object 'System.Windows.Forms.Label'
    $lbl_t2_02.Location                 = ' 12,  77'
    $lbl_t2_02.Size                     = '315,  21'
    $lbl_t2_02.Text                     = 'Comment'
    $lbl_t2_02.TextAlign                = 'MiddleLeft'
    $tab_Page2.Controls.Add($lbl_t2_02)

    $txt_t2_01                          = New-Object 'System.Windows.Forms.TextBox'
    $txt_t2_01.Location                 = ' 12, 104'
    $txt_t2_01.Size                     = '411,  90'
    $txt_t2_01.Multiline                = $True
    $tab_Page2.Controls.Add($txt_t2_01)

    $lbl_t2_03                          = New-Object 'System.Windows.Forms.Label'
    $lbl_t2_03.Location                 = ' 12, 209'
    $lbl_t2_03.Size                     = '315,  21'
    $lbl_t2_03.Text                     = 'Maintenance Duration'
    $lbl_t2_03.TextAlign                = 'MiddleLeft'
    $tab_Page2.Controls.Add($lbl_t2_03)

    $btn_t2_01                          = New-Object 'System.Windows.Forms.Button'
    $btn_t2_01.Location                 = '348, 234'
    $btn_t2_01.Size                     = ' 75,  25'
    $btn_t2_01.Text                     = 'Presets'
    $btn_t2_01.Add_Click({ $cms_t2_01.Show($btn_t2_01, $btn_t2_01.Width, 0) })
    $tab_Page2.Controls.Add($btn_t2_01)

    $cms_t2_01 = New-Object 'System.Windows.Forms.ContextMenuStrip'
    $tsm_t2_01 = New-Object 'System.Windows.Forms.ToolStripMenuItem';  $tsm_t2_01.Text = '1 Hour' ; $tsm_t2_01.Add_Click({ $nud_t2_01.Value =    '60' }); $cms_t2_01.Items.Add($tsm_t2_01)
    $tsm_t2_01 = New-Object 'System.Windows.Forms.ToolStripMenuItem';  $tsm_t2_01.Text = '2 Hours'; $tsm_t2_01.Add_Click({ $nud_t2_01.Value =   '120' }); $cms_t2_01.Items.Add($tsm_t2_01)
    $tsm_t2_01 = New-Object 'System.Windows.Forms.ToolStripMenuItem';  $tsm_t2_01.Text = '3 Hours'; $tsm_t2_01.Add_Click({ $nud_t2_01.Value =   '180' }); $cms_t2_01.Items.Add($tsm_t2_01)
    $tsm_t2_01 = New-Object 'System.Windows.Forms.ToolStripSeparator';                                                                                    $cms_t2_01.Items.Add($tsm_t2_01)
    $tsm_t2_01 = New-Object 'System.Windows.Forms.ToolStripMenuItem';  $tsm_t2_01.Text = '1 Day' ;  $tsm_t2_01.Add_Click({ $nud_t2_01.Value =  '1440' }); $cms_t2_01.Items.Add($tsm_t2_01)
    $tsm_t2_01 = New-Object 'System.Windows.Forms.ToolStripMenuItem';  $tsm_t2_01.Text = '2 Days';  $tsm_t2_01.Add_Click({ $nud_t2_01.Value =  '2880' }); $cms_t2_01.Items.Add($tsm_t2_01)
    $tsm_t2_01 = New-Object 'System.Windows.Forms.ToolStripSeparator';                                                                                    $cms_t2_01.Items.Add($tsm_t2_01)
    $tsm_t2_01 = New-Object 'System.Windows.Forms.ToolStripMenuItem';  $tsm_t2_01.Text = '1 Week' ; $tsm_t2_01.Add_Click({ $nud_t2_01.Value = '10080' }); $cms_t2_01.Items.Add($tsm_t2_01)
    $tsm_t2_01 = New-Object 'System.Windows.Forms.ToolStripMenuItem';  $tsm_t2_01.Text = '2 Weeks'; $tsm_t2_01.Add_Click({ $nud_t2_01.Value = '20160' }); $cms_t2_01.Items.Add($tsm_t2_01)

    $rad_t2_01                          = New-Object 'System.Windows.Forms.RadioButton'
    $rad_t2_01.Location                 = ' 12, 236'
    $rad_t2_01.Size                     = '150,  23'
    $rad_t2_01.Text                     = 'Number Of Minutes :'
    $rad_t2_01.Checked                  = $True
    $rad_t2_01.Add_CheckedChanged($rad_t2_0x_CheckedChanged)
    $tab_Page2.Controls.Add($rad_t2_01)

    $nud_t2_01                          = New-Object 'System.Windows.Forms.NumericUpDown'
    $nud_t2_01.Location                 = '168, 236'
    $nud_t2_01.Size                     = '100,  23'
    $nud_t2_01.Maximum                  = '1051200'    # 2 years in minutes
    $nud_t2_01.Minimum                  = '5'
    $nud_t2_01.Value                    = '30'
    $nud_t2_01.TextAlign                = 'Center'
    $nud_t2_01.ThousandsSeparator       = $False
    $nud_t2_01.Add_ValueChanged({ $dtp_t2_01.Value = ((Get-Date).AddMinutes($nud_t2_01.Text)) })
    $nud_t2_01.Add_KeyUp({
        If ($nud_t2_01.Value -gt $nud_t2_01.Maximum) { $nud_t2_01.Value = $nud_t2_01.Maximum }
        $dtp_t2_01.Value = (Get-Date).AddMinutes($nud_t2_01.Text) })
    $tab_Page2.Controls.Add($nud_t2_01)

    $rad_t2_02                          = New-Object 'System.Windows.Forms.RadioButton'
    $rad_t2_02.Location                 = ' 12, 265'
    $rad_t2_02.Size                     = '150,  23'
    $rad_t2_02.Text                     = 'Specific End Time :'
    $rad_t2_02.Add_CheckedChanged($rad_t2_0x_CheckedChanged)
    $tab_Page2.Controls.Add($rad_t2_02)

    $dtp_t2_01                          = New-Object 'System.Windows.Forms.DateTimePicker'
    $dtp_t2_01.Location                 = '168, 265'
    $dtp_t2_01.Size                     = '255,  23'
    $dtp_t2_01.CustomFormat             = '  dd MMMM yyyy      HH:mm:ss'
    $dtp_t2_01.Format                   = 'Custom'
    $tab_Page2.Controls.Add($dtp_t2_01)

    $btn_t2_02                          = New-Object 'System.Windows.Forms.Button'
    $btn_t2_02.Location                 = ' 12, 325'
    $btn_t2_02.Size                     = ' 75,  25'
    $btn_t2_02.Text                     = '<  Back'
    $btn_t2_02.Add_Click({ $tab_Pages.SelectedTab = $script:tb1 })
    $tab_Page2.Controls.Add($btn_t2_02)

    $btn_t2_03                          = New-Object 'System.Windows.Forms.Button'
    $btn_t2_03.Location                 = '158, 315'
    $btn_t2_03.Size                     = '125,  35'
    $btn_t2_03.Text                     = 'Stop'
    $btn_t2_03.Add_Click($btn_t2_03_Click)
    $tab_Page2.Controls.Add($btn_t2_03)

    $btn_t2_04                          = New-Object 'System.Windows.Forms.Button'
    $btn_t2_04.Location                 = '298, 315'
    $btn_t2_04.Size                     = '125,  35'
    $btn_t2_04.Text                     = 'Start / Update'
    $btn_t2_04.Add_Click($btn_t2_04_Click)
    $tab_Page2.Controls.Add($btn_t2_04)
    #endregion
    #region TAB 3 - Results
    $lst_t3_01                          = New-Object 'System.Windows.Forms.ListView'
    $lst_t3_01.Location                 = ' 12,  12'
    $lst_t3_01.Size                     = '411, 298'
    $lst_t3_01.CheckBoxes               = $False
    $lst_t3_01.HeaderStyle              = 'Nonclickable'
    $lst_t3_01.LabelEdit                = $False
    $lst_t3_01.FullRowSelect            = $True
    $lst_t3_01.SmallImageList           = $imgList_Search
    $lst_t3_01.View                     = 'Details'
    $lst_t3_01_col_01                   = New-Object 'System.Windows.Forms.ColumnHeader'
    $lst_t3_01_col_01.Text              = 'Server Name'
    $lst_t3_01_col_01.Width             = (($lst_t3_01.Width - 16) - ([System.Windows.Forms.SystemInformation]::VerticalScrollBarWidth + 4))
    $lst_t3_01.Columns.Add($lst_t3_01_col_01)
    $lst_t3_01_col_02                   = New-Object 'System.Windows.Forms.ColumnHeader'
    $lst_t3_01_col_02.Text              = ''     # Current Maintenance Mode State
    $lst_t3_01_col_02.Width             = '0'    # Hidden
    $lst_t3_01.Columns.Add($lst_t3_01_col_02)
    $lst_t3_01_col_03                   = New-Object 'System.Windows.Forms.ColumnHeader'
    $lst_t3_01_col_03.Text              = ''     # Domain Name (if any)
    $lst_t3_01_col_03.Width             = '0'    # Hidden
    $lst_t3_01.Columns.Add($lst_t3_01_col_03)
    $lst_t3_01_col_04                   = New-Object 'System.Windows.Forms.ColumnHeader'
    $lst_t3_01_col_04.Text              = 'State'    # Maintenance Mode Progress
    $lst_t3_01_col_04.Width             = '16'
    $lst_t3_01_col_04.TextAlign         = 'Center'
    $lst_t3_01.Columns.Add($lst_t3_01_col_04)
    $lst_t3_01.OwnerDraw                = $True
    $lst_t3_01.Add_DrawSubItem($SubIcons_DrawSubItem)
    $lst_t3_01.Add_DrawColumnHeader($SubIcons_DrawColumnHeader)
    $tab_Page3.Controls.Add($lst_t3_01)

    $btn_t3_01                          = New-Object 'System.Windows.Forms.Button'
    $btn_t3_01.Location                 = ' 12, 325'
    $btn_t3_01.Size                     = '125,  25'
    $btn_t3_01.Text                     = 'View Log File'
    $btn_t3_01.Add_Click($btn_t3_01_Click)
    $tab_Page3.Controls.Add($btn_t3_01)

    $btn_t3_02                          = New-Object 'System.Windows.Forms.Button'
    $btn_t3_02.Location                 = '348, 325'
    $btn_t3_02.Size                     = ' 75,  25'
    $btn_t3_02.Text                     = 'Close'
    $btn_t3_02.Add_Click($btn_t3_02_Click)
    $tab_Page3.Controls.Add($btn_t3_02)
    #endregion
    #region TAB 4 - Search
    $lbl_t4_01                          = New-Object 'System.Windows.Forms.Label'
    $lbl_t4_01.Location                 = ' 12,  12'
    $lbl_t4_01.Size                     = '100,  23'
    $lbl_t4_01.Text                     = 'Search List :'
    $lbl_t4_01.TextAlign                = 'MiddleLeft'
    $tab_Page4.Controls.Add($lbl_t4_01)

    $txt_t4_01                          = New-Object 'System.Windows.Forms.TextBox'
    $txt_t4_01.Location                 = '118,  12'
    $txt_t4_01.Size                     = '305,  23'
    $txt_t4_01.Add_TextChanged($txt_t4_01_TextChanged)
    $tab_Page4.Controls.Add($txt_t4_01)
    
    $lnk_t4_01                          = New-Object 'System.Windows.Forms.LinkLabel'
    $lnk_t4_01.Location                 = '118,  35'
    $lnk_t4_01.Size                     = '305,  17'
    $lnk_t4_01.Text                     = 'Search Filtering'
    $lnk_t4_01.Add_LinkClicked($lnk_t4_01_LinkClicked)
    $tab_Page4.Controls.Add($lnk_t4_01)

    $lst_t4_01                          = New-Object 'System.Windows.Forms.ListView'
    $lst_t4_01.Location                 = ' 12,  58'
    $lst_t4_01.Size                     = '411, 252'
    $lst_t4_01.CheckBoxes               = $True
    $lst_t4_01.HeaderStyle              = 'None'
    $lst_t4_01.LabelEdit                = $False
    $lst_t4_01.FullRowSelect            = $True
    $lst_t4_01.MultiSelect              = $False
    $lst_t4_01.SmallImageList           = $imgList_Search
    $lst_t4_01.View                     = 'Details'
    $lst_t4_01_col_01                   = New-Object 'System.Windows.Forms.ColumnHeader'
    $lst_t4_01_col_01.Text              = ''
    $lst_t4_01_col_01.Width             = (($lst_t4_01.Width - 16) - ([System.Windows.Forms.SystemInformation]::VerticalScrollBarWidth + 4))
    $lst_t4_01.Columns.Add($lst_t4_01_col_01)
    $lst_t4_01_col_02                   = New-Object 'System.Windows.Forms.ColumnHeader'
    $lst_t4_01_col_02.Text              = ''
    $lst_t4_01_col_02.Width             = '16'
    $lst_t4_01_col_02.TextAlign         = 'Center'
    $lst_t4_01.Columns.Add($lst_t4_01_col_02)
    $lst_t4_01_col_03                   = New-Object 'System.Windows.Forms.ColumnHeader'
    $lst_t4_01_col_03.Text              = ''     # Domain Name (if any)
    $lst_t4_01_col_03.Width             = '0'    # Hidden
    $lst_t4_01.Columns.Add($lst_t4_01_col_03)
    $lst_t4_01.OwnerDraw                = $True
    $lst_t4_01.Add_DrawSubItem($SubIcons_DrawSubItem)
    $lst_t4_01.Add_DrawColumnHeader($SubIcons_DrawColumnHeader)
    $lst_t4_01.Add_MouseUp($lst_t4_01_MouseUp)
    $tab_Page4.Controls.Add($lst_t4_01)

    $cms_t4_01 = New-Object 'System.Windows.Forms.ContextMenuStrip'
    $tsm_t4_01 = New-Object 'System.Windows.Forms.ToolStripMenuItem'
    $tsm_t4_01.Text = 'Group By'
    $tsm_t4_01.Image = $imgList_Search.Images[0]
    $tsm_t4_sub_01 = New-Object 'System.Windows.Forms.ToolStripMenuItem'; $tsm_t4_sub_01.Text = 'Domain Name'  ; $tsm_t4_sub_01.Add_Click({tsm_t4_sub_0x_Click -Sender $this}); $tsm_t4_sub_01.Checked = $True
    $tsm_t4_sub_02 = New-Object 'System.Windows.Forms.ToolStripMenuItem'; $tsm_t4_sub_02.Text = 'Health Status'; $tsm_t4_sub_02.Add_Click({tsm_t4_sub_0x_Click -Sender $this})
    $tsm_t4_sub_03 = New-Object 'System.Windows.Forms.ToolStripSeparator'
    $tsm_t4_sub_04 = New-Object 'System.Windows.Forms.ToolStripMenuItem'; $tsm_t4_sub_04.Text = 'None'         ; $tsm_t4_sub_04.Add_Click({tsm_t4_sub_0x_Click -Sender $this})
    $tsm_t4_01.DropDownItems.AddRange(@($tsm_t4_sub_01, $tsm_t4_sub_02, $tsm_t4_sub_03, $tsm_t4_sub_04))
    $cms_t4_01.Items.Add($tsm_t4_01)

    $btn_t4_01                          = New-Object 'System.Windows.Forms.Button'
    $btn_t4_01.Location                 = ' 12, 325'
    $btn_t4_01.Size                     = '125,  25'
    $btn_t4_01.Text                     = 'Update List'
    $btn_t4_01.Add_Click({$MainFORM.Cursor = 'WaitCursor'; Update-ServerList; $MainFORM.Cursor = 'Default'})
    $tab_Page4.Controls.Add($btn_t4_01)

    $lbl_t4_02                          = New-Object 'System.Windows.Forms.Label'
    $lbl_t4_02.Location                 = '143, 316'
    $lbl_t4_02.Size                     = '109,  43'
    $lbl_t4_02.Text                     = "0 Shown`r`n0 Total"
    $lbl_t4_02.TextAlign                = 'MiddleCenter'
    $tab_Page4.Controls.Add($lbl_t4_02)

    $btn_t4_02                          = New-Object 'System.Windows.Forms.Button'
    $btn_t4_02.Location                 = '258, 325'
    $btn_t4_02.Size                     = ' 75,  25'
    $btn_t4_02.Text                     = 'Cancel'
    $btn_t4_02.Add_Click($btn_t4_02_Click)
    $tab_Page4.Controls.Add($btn_t4_02)

    $btn_t4_03                          = New-Object 'System.Windows.Forms.Button'
    $btn_t4_03.Location                 = '348, 325'
    $btn_t4_03.Size                     = ' 75,  25'
    $btn_t4_03.Text                     = 'Select'
    $btn_t4_03.Add_Click($btn_t4_03_Click)
    $tab_Page4.Controls.Add($btn_t4_03)
    #endregion
#endregion
###################################################################################################
    $InitialFormWindowState = $MainFORM.WindowState
    $MainFORM.Add_Load($MainFORM_StateCorrection_Load)
    Return $MainFORM.ShowDialog()
}
###################################################################################################
Display-MainForm | Out-Null
Write-Host '  Goodbye.!'
Write-Host ''
