Set-StrictMode  -Version 2
Remove-Variable -Name * -ErrorAction SilentlyContinue
Clear-Host

[string]$script:appName = ' Copy-VMGuestFileGUI'
Write-Host "  Starting$script:appName..."

[Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms') | Out-Null
[Reflection.Assembly]::LoadWithPartialName('System.Data')          | Out-Null
[Reflection.Assembly]::LoadWithPartialName('System.Drawing')       | Out-Null
[System.Drawing.Font]$sysFont = [System.Drawing.SystemFonts]::MessageBoxFont
[System.Drawing.Font]$sysFontBold = New-Object 'System.Drawing.Font' ($sysFont.Name, $sysFont.SizeInPoints, [System.Drawing.FontStyle]::Bold)
[System.Windows.Forms.Application]::EnableVisualStyles()
[pscredential]$script:credential = $null

###################################################################################################
##                                                                                               ##
##   Various Required Scripts                                                                    ##
##                                                                                               ##
###################################################################################################
Function Get-Folder ( [string]$Description, [string]$InitialDirectory, [boolean]$ShowNewFolderButton )
{
    [string]$return = ''
    If ([threading.thread]::CurrentThread.GetApartmentState() -eq 'STA')
    {
        $FolderBrowser = New-Object 'System.Windows.Forms.FolderBrowserDialog'
        $FolderBrowser.RootFolder          = 'MyComputer'
        $FolderBrowser.Description         = $Description
        $FolderBrowser.ShowNewFolderButton = $ShowNewFolderButton
        If ([string]::IsNullOrEmpty($InitialDirectory) -eq $False) { $FolderBrowser.SelectedPath = $InitialDirectory }
        If ($FolderBrowser.ShowDialog($MainForm) -eq [System.Windows.Forms.DialogResult]::OK) { $return = $($FolderBrowser.SelectedPath) }
        Try { $FolderBrowser.Dispose() } Catch {}
    }
    Else
    {
        # Workaround for MTA not showing the dialog box.
        # Initial Directory is not possible when using the COM Object
        $Description  += "`nUnable to automatically select correct folder."
        $comObject     = New-Object -ComObject 'Shell.Application'
        $FolderBrowser = $comObject.BrowseForFolder(0, $Description, 512, '')    # 512 = No 'New Folder' button, '' = Initial folder (Desktop)
        If ([string]::IsNullOrEmpty($FolderBrowser) -eq $False) { $return = $($FolderBrowser.Self.Path) } Else { $return = '' }
        [System.Runtime.Interopservices.Marshal]::ReleaseComObject($comObject) | Out-Null    # Dispose COM object
    }
    Return $return
}

###################################################################################################
##                                                                                               ##
##   Main Form                                                                                   ##
##                                                                                               ##
###################################################################################################
Function Display-MainForm
{
#region FORM STARTUP / SHUTDOWN
    $InitialFormWindowState        = New-Object 'System.Windows.Forms.FormWindowState'
    $MainFORM_StateCorrection_Load = { $MainForm.WindowState = $InitialFormWindowState }

    $MainFORM_Load = {
        # Change font to a nicer one
        ForEach ($control In $MainForm.Controls)  { $control.Font = $sysFont }
        ForEach ($tab     In $tab_Pages.TabPages) { ForEach ($control In $tab.Controls) { $control.Font = $sysFont } }

        $lbl_t0_01.Font    = $sysFontBold
        $lbl_t1_02.Font    = $sysFontBold
        #$tab_Page1.Enabled = $False
    }

    $Form_Cleanup_FormClosed = {
        $chk_t0_01.Remove_CheckedChanged($chk_t0_01_CheckedChanged)
        $btn_t0_01.Remove_Click($btn_t0_01_Click)

        $btn_t1_01.Remove_Click($btn_t1_01_Click)
        $btn_t1_02.Remove_Click($btn_t1_02_Click)
        $btn_t1_03.Remove_Click($btn_t1_03_Click)
        $btn_t1_04.Remove_Click($btn_t1_04_Click)

        $MainFORM.Remove_Load($MainFORM_Load)
        $MainFORM.Remove_Load($MainFORM_StateCorrection_Load)
    }
#endregion
###################################################################################################
#region FORM Scripts
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
        If  ([string]::IsNullOrEmpty($txt_t0_01.Text) -eq $True) { Return }
        If  ([string]::IsNullOrEmpty($txt_t0_02.Text) -eq $True) { Return }
        If (([string]::IsNullOrEmpty($txt_t0_03.Text) -eq $True) -and ($chk_t0_01.Checked -eq $False)) { Return }

        $MainFORM.Cursor   = 'WaitCursor'
        Write-Host '    Loading PowerCLI Module'
        $btn_t0_01.Text    = 'Loading Module...'
        $btn_t0_01.Enabled = $False
        $btn_t0_01.Refresh()

        If     ((Get-Module -ListAvailable -Name 'VMware.VimAutomation.Core')                               -ne $null) { Import-Module 'VMware.VimAutomation.Core' | Out-Null }
        ElseIf ((Get-PSSnapin -Registered  -Name 'VMware.VimAutomation.Core' -ErrorAction SilentlyContinue) -ne $null) { Add-PsSnapin  'VMware.VimAutomation.Core' | Out-Null }
        Else { Throw 'PowerCLI module/snapin not found' }
        [boolean]$errorCondition = $False

        $btn_t0_01.Text  = 'Connecting To Server...'
        Write-Host '    Connecting To vCenter Server'
        $btn_t0_01.Refresh()
        Try
        {
            If ($chk_t0_01.Checked -eq $True)
            {
                Connect-VIServer -Server ($txt_t0_01.Text) -WarningAction SilentlyContinue -WarningVariable null -ErrorAction Stop
            }
            Else
            {
                [string]      $username   = ($txt_t0_02.Text)
                [securestring]$password   = ConvertTo-SecureString -String ($txt_t0_03.Text) -AsPlainText -Force
                [pscredential]$credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $username, $password
                Connect-VIServer -Server ($txt_t0_01.Text) -Credential $credential -WarningAction SilentlyContinue -WarningVariable null -ErrorAction Stop
            }
        }
        Catch
        {
            $errorCondition = $True
            [System.Windows.Forms.MessageBox]::Show($MainFORM, $_.Exception.Message, $script:appName, 'OK', 'Error')      
        }

        $MainFORM.Cursor   = 'Default'
        If ($errorCondition -eq $False)
        {
            $tab_Page0.Enabled       = $False
            $tab_Page1.Enabled       = $True
            $tab_Pages.SelectedIndex = 1

            Write-Host '    Connected'
            $btn_t0_01.Text = 'Complete'
        }
        Else
        {
            Write-Host '    Error Connecting' -ForegroundColor Red
            $btn_t0_01.Text    = 'Connect'
            $btn_t0_01.Enabled = $True
        }
    }
    #endregion
    #region TAB 1 SCRIPTS
        $btn_t1_01_Click = {
            $btn_t1_01.Enabled = $False
            $MainFORM.Cursor   = 'WaitCursor'
            Start-Sleep -Milliseconds 125
            If ($lbl_t1_02.Text -eq 'Local To Guest') { $lbl_t1_02.Text = 'Guest To Local'; $btn_t1_02.Top  = $txt_t1_02.Top }
            Else                                      { $lbl_t1_02.Text = 'Local To Guest'; $btn_t1_02.Top  = $txt_t1_01.Top }
            Start-Sleep -Milliseconds 125
            $MainFORM.Cursor   = 'Default'
            $btn_t1_01.Enabled = $True
        }

        $btn_t1_02_Click = {
            [string]$selectedFolder = Get-Folder -Description 'Select the folders you want to copy' -InitialDirectory '' -ShowNewFolderButton $False
            If ($lbl_t1_02.Text -eq 'Local To Guest') { $txt_t1_01.Text = $selectedFolder } Else { $txt_t1_02.Text = $selectedFolder }
        }

        $btn_t1_03_Click = {
            $script:credential = (Get-Credential -Message 'Enter the username password for the guest virtual machine.')
            $lbl_t1_07.Text = $script:credential.UserName.ToLower()
        }

        $btn_t1_04_Click = {
            If  ([string]::IsNullOrEmpty($txt_t1_01.Text) -eq $True)     { Return }
            If  ([string]::IsNullOrEmpty($txt_t1_02.Text) -eq $True)     { Return }
            If  ([string]::IsNullOrEmpty($txt_t1_03.Text) -eq $True)     { Return }
            If                          ($lbl_t1_07.Text  -eq '...\...') { Return }

            If ($lbl_t1_02.Text -eq 'Local To Guest')
            {
                Copy-VMGuestFile -Source ($txt_t1_01.Text) -Destination ($txt_t1_02.Text) -Force:($chk_t1_01.Checked) -VM ($txt_t1_03.Text) `
                                 -GuestCredential $script:credential -LocalToGuest -Verbose
            }
            Else
            {
                Copy-VMGuestFile -Source ($txt_t1_01.Text) -Destination ($txt_t1_02.Text) -Force:($chk_t1_01.Checked) -VM ($txt_t1_03.Text) `
                                 -GuestCredential $script:credential -GuestToLocal -Verbose
            }
        }

    #endregion
#endregion
###################################################################################################
#region FORM ITEMS
    #region MAIN FORM
    $MainFORM                           = New-Object 'System.Windows.Forms.Form'
    $MainFORM.AutoScaleDimensions       = '6, 13'
    $MainFORM.AutoScaleMode             = 'None'
    $MainFORM.ClientSize                = '524, 379'
    $MainFORM.FormBorderStyle           = 'FixedSingle'
    $MainFORM.MaximizeBox               = $False
    $MainFORM.MinimizeBox               = $False
    $MainFORM.ShowIcon                  = $False
    $MainFORM.StartPosition             = 'CenterScreen'
    $MainFORM.Text                      = $script:appName
    $MainFORM.Add_Load($MainFORM_Load)
    $MainFORM.SuspendLayout()

    $tab_Pages                          = New-Object 'System.Windows.Forms.TabControl'
    $tab_Pages.Location                 = ' 12,  12'
    $tab_Pages.Size                     = '500, 355'
    $tab_Pages.Padding                  = ' 12,   6'
    $tab_Pages.SelectedIndex            = 0
    $tab_Pages.TabIndex                 = 0
    $MainFORM.Controls.Add($tab_Pages)

    $tab_Page0 = New-Object 'System.Windows.Forms.TabPage'('vCenter Login');      $tab_Pages.Controls.Add($tab_Page0)
    $tab_Page1 = New-Object 'System.Windows.Forms.TabPage'('Command Parameters'); $tab_Pages.Controls.Add($tab_Page1)
    #endregion
    #region TAB 0
    $lbl_t0_01                          = New-Object 'System.Windows.Forms.Label'
    $lbl_t0_01.Location                 = ' 12,  12'
    $lbl_t0_01.Size                     = '468,  21'
    $lbl_t0_01.Text                     = "Welcome to the$script:appName"
    $tab_Page0.Controls.Add($lbl_t0_01)

    $lbl_t0_02                          = New-Object 'System.Windows.Forms.label'
    $lbl_t0_02.Location                 = ' 12,  39'
    $lbl_t0_02.Size                     = '468,  42'
    $lbl_t0_02.Text                     = 'This tool will allow you to copy files in and out of virtual machines using the built in PowerCLI command "Copy-VMGuestFile".'
    $tab_Page0.Controls.Add($lbl_t0_02)

    $lbl_t0_03                          = New-Object 'System.Windows.Forms.label'
    $lbl_t0_03.Location                 = ' 12,  96'
    $lbl_t0_03.Size                     = ' 94,  23'
    $lbl_t0_03.Text                     = 'vCenter :'
    $lbl_t0_03.TextAlign                = 'MiddleRight'
    $tab_Page0.Controls.Add($lbl_t0_03)

    $txt_t0_01                          = New-Object 'System.Windows.Forms.TextBox'
    $txt_t0_01.Location                 = '112,  96'
    $txt_t0_01.Size                     = '268,  23'
    $tab_Page0.Controls.Add($txt_t0_01)

    $lbl_t0_04                          = New-Object 'System.Windows.Forms.label'
    $lbl_t0_04.Location                 = ' 12, 134'
    $lbl_t0_04.Size                     = ' 94,  23'
    $lbl_t0_04.Text                     = 'Username :'
    $lbl_t0_04.TextAlign                = 'MiddleRight'
    $tab_Page0.Controls.Add($lbl_t0_04)

    $txt_t0_02                          = New-Object 'System.Windows.Forms.TextBox'
    $txt_t0_02.Location                 = '112, 134'
    $txt_t0_02.Size                     = '268,  23'
    $tab_Page0.Controls.Add($txt_t0_02)

    $lbl_t0_05                          = New-Object 'System.Windows.Forms.label'
    $lbl_t0_05.Location                 = ' 12, 172'
    $lbl_t0_05.Size                     = ' 94,  23'
    $lbl_t0_05.Text                     = 'Password :'
    $lbl_t0_05.TextAlign                = 'MiddleRight'
    $tab_Page0.Controls.Add($lbl_t0_05)

    $txt_t0_03                          = New-Object 'System.Windows.Forms.TextBox'
    $txt_t0_03.Location                 = '112, 172'
    $txt_t0_03.Size                     = '268,  23'
    $txt_t0_03.PasswordChar             = ([char]9679).ToString()
    $tab_Page0.Controls.Add($txt_t0_03)

    $chk_t0_01                          = New-Object 'System.Windows.Forms.CheckBox'
    $chk_t0_01.Location                 = '112, 198'
    $chk_t0_01.Size                     = '268,  23'
    $chk_t0_01.Text                     = 'Use Windows Credentials'
    $chk_t0_01.Checked                  = $False
    $chk_t0_01.Add_CheckedChanged($chk_t0_01_CheckedChanged)
    $tab_Page0.Controls.Add($chk_t0_01)

    $btn_t0_01                          = New-Object 'System.Windows.Forms.Button'
    $btn_t0_01.Location                 = '112, 265'
    $btn_t0_01.Size                     = '268,  35'
    $btn_t0_01.Text                     = 'Connect'
    $btn_t0_01.Add_Click($btn_t0_01_Click)
    $tab_Page0.Controls.Add($btn_t0_01)
    #endregion
    #region TAB 1
    $lbl_t1_01                          = New-Object 'System.Windows.Forms.Label'
    $lbl_t1_01.Location                 = ' 12,  12'
    $lbl_t1_01.Size                     = '125,  25'
    $lbl_t1_01.Text                     = 'Copy Direction'
    $lbl_t1_01.TextAlign                = 'MiddleLeft'
    $tab_Page1.Controls.Add($lbl_t1_01)

    $btn_t1_01                          = New-Object 'System.Windows.Forms.Button'
    $btn_t1_01.Location                 = '143,  12'
    $btn_t1_01.Size                     = ' 75,  25'
    $btn_t1_01.Text                     = 'Change'
    $btn_t1_01.Add_Click($btn_t1_01_Click)
    $tab_Page1.Controls.Add($btn_t1_01)

    $lbl_t1_02                          = New-Object 'System.Windows.Forms.Label'
    $lbl_t1_02.Location                 = '224,  12'
    $lbl_t1_02.Size                     = '256,  25'
    $lbl_t1_02.Text                     = 'Local To Guest'
    $lbl_t1_02.TextAlign                = 'MiddleLeft'
    $tab_Page1.Controls.Add($lbl_t1_02)

    $lbl_t1_b1                          = New-Object 'System.Windows.Forms.Label'
    $lbl_t1_b1.Location                 = ' 12,  52'
    $lbl_t1_b1.Size                     = '468,   1'
    $lbl_t1_b1.BorderStyle              = 'FixedSingle'
    $tab_Page1.Controls.Add($lbl_t1_b1)

    $lbl_t1_03                          = New-Object 'System.Windows.Forms.Label'
    $lbl_t1_03.Location                 = ' 12,  68'
    $lbl_t1_03.Size                     = '125,  25'
    $lbl_t1_03.Text                     = 'Source Folder :'
    $lbl_t1_03.TextAlign                = 'MiddleLeft'
    $tab_Page1.Controls.Add($lbl_t1_03)

    $txt_t1_01                          = New-Object 'System.Windows.Forms.TextBox'
    $txt_t1_01.Location                 = '143,  68'
    $txt_t1_01.Size                     = '306,  23'
    $tab_Page1.Controls.Add($txt_t1_01)

    $btn_t1_02                          = New-Object 'System.Windows.Forms.Button'
    $btn_t1_02.Location                 = '455,  68'
    $btn_t1_02.Size                     = ' 25,  25'
    $btn_t1_02.Text                     = '...'
    $btn_t1_02.Add_Click($btn_t1_02_Click)
    $tab_Page1.Controls.Add($btn_t1_02)

    $lbl_t1_04                          = New-Object 'System.Windows.Forms.Label'
    $lbl_t1_04.Location                 = ' 12, 106'
    $lbl_t1_04.Size                     = '125,  25'
    $lbl_t1_04.Text                     = 'Destination Folder :'
    $lbl_t1_04.TextAlign                = 'MiddleLeft'
    $tab_Page1.Controls.Add($lbl_t1_04)

    $txt_t1_02                          = New-Object 'System.Windows.Forms.TextBox'
    $txt_t1_02.Location                 = '143, 106'
    $txt_t1_02.Size                     = '306,  23'
    $tab_Page1.Controls.Add($txt_t1_02)

    $chk_t1_01                          = New-Object 'System.Windows.Forms.CheckBox'
    $chk_t1_01.Location                 = '143, 132'
    $chk_t1_01.Size                     = '306,  17'
    $chk_t1_01.Text                     = 'Create Destination Folder'
    $chk_t1_01.Checked                  = $True
    $tab_Page1.Controls.Add($chk_t1_01)

    $lbl_t1_b2                          = New-Object 'System.Windows.Forms.Label'
    $lbl_t1_b2.Location                 = ' 12, 164'
    $lbl_t1_b2.Size                     = '468,   1'
    $lbl_t1_b2.BorderStyle              = 'FixedSingle'
    $tab_Page1.Controls.Add($lbl_t1_b2)

    $lbl_t1_05                          = New-Object 'System.Windows.Forms.Label'
    $lbl_t1_05.Location                 = ' 12, 180'
    $lbl_t1_05.Size                     = '125,  25'
    $lbl_t1_05.Text                     = 'Virtual Machine :'
    $lbl_t1_05.TextAlign                = 'MiddleLeft'
    $tab_Page1.Controls.Add($lbl_t1_05)

    $txt_t1_03                          = New-Object 'System.Windows.Forms.TextBox'
    $txt_t1_03.Location                 = '143, 180'
    $txt_t1_03.Size                     = '337, 23'
    $tab_Page1.Controls.Add($txt_t1_03)

    $lbl_t1_06                          = New-Object 'System.Windows.Forms.Label'
    $lbl_t1_06.Location                 = ' 12, 218'
    $lbl_t1_06.Size                     = '125,  25'
    $lbl_t1_06.Text                     = 'Credentials'
    $lbl_t1_06.TextAlign                = 'MiddleLeft'
    $tab_Page1.Controls.Add($lbl_t1_06)

    $btn_t1_03                          = New-Object 'System.Windows.Forms.Button'
    $btn_t1_03.Location                 = '143, 218'
    $btn_t1_03.Size                     = ' 75,  25'
    $btn_t1_03.Text                     = 'Set'
    $btn_t1_03.Add_Click($btn_t1_03_Click)
    $tab_Page1.Controls.Add($btn_t1_03)

    $lbl_t1_07                          = New-Object 'System.Windows.Forms.Label'
    $lbl_t1_07.Location                 = '224, 218'
    $lbl_t1_07.Size                     = '258,  25'
    $lbl_t1_07.Text                     = '...\...'
    $lbl_t1_07.TextAlign                = 'MiddleLeft'
    $tab_Page1.Controls.Add($lbl_t1_07)

    $lbl_t1_b3                          = New-Object 'System.Windows.Forms.Label'
    $lbl_t1_b3.Location                 = ' 12, 258'
    $lbl_t1_b3.Size                     = '468,   1'
    $lbl_t1_b3.BorderStyle              = 'FixedSingle'
    $tab_Page1.Controls.Add($lbl_t1_b3)

    $lbl_t1_08                          = New-Object 'System.Windows.Forms.Label'
    $lbl_t1_08.Location                 = ' 12, 275'
    $lbl_t1_08.Size                     = '330,  35'
    $lbl_t1_08.Text                     = 'See console window for copy progress.'
    $lbl_t1_08.TextAlign                = 'MiddleLeft'
    $tab_Page1.Controls.Add($lbl_t1_08)

    $btn_t1_04                          = New-Object 'System.Windows.Forms.Button'
    $btn_t1_04.Location                 = '355, 274'
    $btn_t1_04.Size                     = '125,  35'
    $btn_t1_04.Text                     = 'Start'
    $btn_t1_04.Add_Click($btn_t1_04_Click)
    $tab_Page1.Controls.Add($btn_t1_04)
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
