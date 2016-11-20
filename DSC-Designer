Remove-Variable * -ErrorAction SilentlyContinue
Clear-Host

[Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms')      | Out-Null
[Reflection.Assembly]::LoadWithPartialName('System.Data')               | Out-Null
[Reflection.Assembly]::LoadWithPartialName('System.Drawing')            | Out-Null
[System.Drawing.Font]$sysFont       =                                   [System.Drawing.SystemFonts]::MessageBoxFont
[System.Drawing.Font]$codeFont      = New-Object 'System.Drawing.Font' ('Consolas',                                        [System.Drawing.SystemFonts]::MessageBoxFont.SizeInPoints, [System.Drawing.FontStyle]::Regular)
[System.Drawing.Font]$sysFontBold   = New-Object 'System.Drawing.Font' ([System.Drawing.SystemFonts]::MessageBoxFont.Name, [System.Drawing.SystemFonts]::MessageBoxFont.SizeInPoints, [System.Drawing.FontStyle]::Bold)

###################################################################################################
##                                                                                               ##
##   Various Required Scripts                                                                    ##
##                                                                                               ##
###################################################################################################

Function Save-File ( [string]$InitialDirectory, [string]$Title )
{
    [string]$return = ''
    $filename = New-Object 'System.Windows.Forms.SaveFileDialog'
    $filename.InitialDirectory = $InitialDirectory
    $filename.Title            = $Title
    $filename.Filter           = 'Configuration Files (*.*)|*.*|All Files|*.*'
    If ([threading.thread]::CurrentThread.GetApartmentState() -ne 'STA') { $filename.ShowHelp = $true }    # Workaround for MTA issues not showing dialog box
    If ($filename.ShowDialog($Main_Form) -eq [System.Windows.Forms.DialogResult]::OK) { [string[]]$return = ($filename.FileNames | Sort-Object) }
    Try { $filename.Dispose() } Catch {}
    Return $return
}

Function Clear-CheckBoxes
{
    ForEach ($control In ($FlowPanel.Controls)) { If ($control -is [System.Windows.Forms.CheckBox]) { $control.Checked = $false } }
}

Function Clear-AllConfig
{
    Clear-CheckBoxes
}

Function Export-Configuration
{
    Try
    {
        Invoke-Expression -Command $($txt_Configuration.Text) -ErrorAction Stop
    }
    Catch
    {
        Write-Warning 'Failed executing configuration'
    }

    [string]$fileName = Save-File -InitialDirectory '' -Title 'Save the configuration file...'
    If ([string]::IsNullOrEmpty($fileName) -eq $false)
    {
        $txt_Configuration.Text | Out-File -FilePath $fileName -Force
        [System.Windows.Forms.MessageBox]::Show($MainForm, "DSC resource created at $fileName", 'DSC Designer', 'OK', 'Information')
    }
    Else
    {
        Write-Host 'Empty filename'
        Write-Host $fileName
    }
}

Function yGet-DSCResources
{
    $Runspace   = [RunspaceFactory]::CreateRunspace()
    $PowerShell = [PowerShell]::Create()
    $PowerShell.Runspace = $Runspace
    $Runspace.Open()
    $PowerShell.AddScript( { Get-DscResource } ) | Out-Null

    If ($AsyncObject.IsCompleted -eq ($true)) { Write-Host 'Completed' } Else { Write-Host 'Waiting for DSC resources...'; Start-Sleep -Milliseconds 100 }
    $AsyncObject = $PowerShell.BeginInvoke()
    $Data = $PowerShell.EndInvoke($AsyncObject)
    $Resources = ($Data | Sort-Object -Property Name)

    ForEach ($Item In $Resources)
    {
        $chk_DSCName = New-Object 'System.Windows.Forms.CheckBox'
        $chk_DSCName.Name       = $($Item.Name).Trim()
        $chk_DSCName.Text       = $($Item.Name).Trim()
        $chk_DSCName.Margin     = '3, 1, 3, 1'
        $chk_DSCName.Padding    = '3, 0, 0, 0'
        $chk_DSCName.Size       = "$($btn_FlowRemoveAll.Width), 17"
        $chk_DSCName.Add_CheckedChanged(
        {
            If ($this.Checked -eq $true)
            {
                $tab_NewTab = New-Object 'System.Windows.Forms.TabPage'
	            $tab_NewTab.UseVisualStyleBackColor = $True
	            $tab_NewTab.Name        = $($this.Name).Trim()
	            $tab_NewTab.Text        = $($this.Name).Trim()
                $TabPanel.TabPages.Add($tab_NewTab)
                $TabPanel.SelectedIndex = ($TabPanel.TabCount - 1)

                $txt_TextBox = New-Object 'System.Windows.Forms.TextBox'
                $txt_TextBox.Dock       = 'Fill'
                $txt_TextBox.Font       = $codeFont
                $txt_TextBox.Multiline  = $true
                $txt_TextBox.Text       = ((Get-DscResource -Name $($this.Name) -Syntax).Split("`r`n") -join "`r`n")
                $txt_TextBox.Add_TextChanged(
                {
                    $txt_Configuration.Text = @"
configuration $($txt_ConfigName.Text) {

    $(ForEach ($page In $TabPanel.TabPages) { Write-Output $page.Tag.Text })
}
"@
                })
                $tab_NewTab.Tag = $txt_TextBox

                $tab_NewTab.Controls.Add($txt_TextBox)
            }
            Else
            {
                $TabPanel.TabPages.RemoveByKey($this.Name)
            }
        })
        $FlowPanel.Controls.Add($chk_DSCName)
    }
}


###################################################################################################
##                                                                                               ##
##   Main Form                                                                                   ##
##                                                                                               ##
###################################################################################################

Function Show-MainForm
{
#region FORM ITEMS
    [System.Windows.Forms.Application]::EnableVisualStyles()
    $MainForm          = New-Object 'System.Windows.Forms.Form'
    $FlowPanel         = New-Object 'System.Windows.Forms.FlowLayoutPanel'
    $TabPanel          = New-Object 'System.Windows.Forms.TabControl'
    $btn_FlowRemoveAll = New-Object 'System.Windows.Forms.Button'

    $lbl_ConfigName    = New-Object 'System.Windows.Forms.Label'
    $txt_ConfigName    = New-Object 'System.Windows.Forms.TextBox'
    $btn_Clear         = New-Object 'System.Windows.Forms.Button'
    $btn_Export        = New-Object 'System.Windows.Forms.Button'
    $txt_Configuration = New-Object 'System.Windows.Forms.TextBox'
#endregion
#region FORM STARTUP and SHUTDOWN
    $InitialFormWindowState        = New-Object 'System.Windows.Forms.FormWindowState'
    $MainForm_StateCorrection_Load = { $MainForm.WindowState = $InitialFormWindowState }
    $MainForm_Load                 = {
        ForEach ($control In $Main_Form.Controls) { $control.Font = $sysFont }
        yGet-DSCResources
    }

    $MainForm_FormClosing          = [System.Windows.Forms.FormClosingEventHandler] {
        $quit = [System.Windows.Forms.MessageBox]::Show($Main_Form, 'Are you sure you want to exit this form.?', ' Quit', 'YesNo', 'Question')
        If ($quit -eq 'No') { $_.Cancel = $True }
    }

    $MainForm_Cleanup_FormClosed   = {
        $MainForm.Remove_Load($MainForm_Load)
        $MainForm.Remove_Load($MainForm_StateCorrection_Load)
        $MainForm.Remove_FormClosing($MainForm_FormClosing)
        $MainForm.Remove_FormClosed($MainForm_Cleanup_FormClosed)
    }

    $MainForm.SuspendLayout()
#endregion
#region FORM ITEMS
    $MainForm.FormBorderStyle  = 'Sizable'
    $MainForm.MaximizeBox      = $True
    $MainForm.MinimizeBox      = $True
    $MainForm.ControlBox       = $True
    $MainForm.Text             = 'PSC Designer'
    $MainForm.ShowInTaskbar    = $True
    $MainForm.Size             = '600, 525'
    $MainForm.StartPosition    = 'CenterParent'
    $MainForm.Add_FormClosed($MainForm_Cleanup_FormClosed)
    $MainForm.Add_Load($MainForm_Load)
    $MainForm.Add_FormClosing($MainForm_FormClosing)

    $FlowPanel.Anchor          = 'Top, Bottom, Left'
    $FlowPanel.AutoScroll      = $true
    $FlowPanel.BorderStyle     = 'FixedSingle'
    $FlowPanel.Location        = ' 12,  12'
    $FlowPanel.Size            = '200, 252'
    $MainForm.Controls.Add($FlowPanel)

    $TabPanel.Anchor           = 'Top, Bottom, Left, Right'
    $TabPanel.Location         = '218,  12'
    $TabPanel.Size             = '362, 252'
    $TabPanel.Padding          = ' 12,   6'
    $MainForm.Controls.Add($TabPanel)

    $btn_FlowRemoveAll.Location    = '  3,   3'
    $btn_FlowRemoveAll.Size        = '174,  25'
    $btn_FlowRemoveAll.Text        = 'Remove All'
    $btn_FlowRemoveAll.add_Click( { Clear-CheckBoxes } )
    $FlowPanel.Controls.Add($btn_FlowRemoveAll)

    $lbl_ConfigName.Anchor    = 'Bottom, Left'
    $lbl_ConfigName.Location  = ' 12, 279' 
    $lbl_ConfigName.Size      = '125,  25'
    $lbl_ConfigName.Text      = 'Configuration Name'
    $lbl_ConfigName.TextAlign = 'MiddleLeft'
    $MainForm.Controls.Add($lbl_ConfigName)

    $txt_ConfigName.Anchor    = 'Bottom, Left, Right'
    $txt_ConfigName.Location  = '143, 279'
    $txt_ConfigName.Size      = '275,  20'
    $txt_ConfigName.Text      = 'Sample Config'
    $MainForm.Controls.Add($txt_ConfigName)

    $btn_Export.Anchor        = 'Bottom, Right'
    $btn_Export.Location      = '424, 279'
    $btn_Export.Size          = ' 75,  25'
    $btn_Export.Text          = 'Export'
    $btn_Export.Add_Click( { Export-Configuration } )
    $MainForm.Controls.Add($btn_Export)

    $btn_Clear.Anchor         = 'Bottom, Right'
    $btn_Clear.Location       = '505, 279'
    $btn_Clear.Size           = ' 75,  25'
    $btn_Clear.Text           = 'Clear All'
    $btn_Clear.Add_Click({ Clear-AllConfig })
    $MainForm.Controls.Add($btn_Clear)

    $txt_Configuration.Anchor    = 'Bottom, Left, Right'
    $txt_Configuration.Location  = ' 12, 310'
    $txt_Configuration.Size      = '568, 173'
    $txt_Configuration.Multiline = $True
    $MainForm.Controls.Add($txt_Configuration)
#endregion
    $MainForm.ResumeLayout()
    $InitialFormWindowState = $MainForm.WindowState
    $MainForm.Add_Load($MainForm_StateCorrection_Load)
    $MainForm.Add_FormClosed($MainForm_Cleanup_FormClosed)
    Return $MainForm.ShowDialog()
}

Show-MainForm | Out-Null
