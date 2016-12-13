Remove-Variable * -ErrorAction SilentlyContinue
Clear-Host

[Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms')      | Out-Null
[Reflection.Assembly]::LoadWithPartialName('System.Data')               | Out-Null
[Reflection.Assembly]::LoadWithPartialName('System.Drawing')            | Out-Null
[System.Drawing.Font]$sysFont       =                                   [System.Drawing.SystemFonts]::MessageBoxFont
[System.Drawing.Font]$sysFontBold   = New-Object 'System.Drawing.Font' ([System.Drawing.SystemFonts]::MessageBoxFont.Name, [System.Drawing.SystemFonts]::MessageBoxFont.SizeInPoints, [System.Drawing.FontStyle]::Bold)
[System.Drawing.Font]$sysFontItalic = New-Object 'System.Drawing.Font' ([System.Drawing.SystemFonts]::MessageBoxFont.Name, [System.Drawing.SystemFonts]::MessageBoxFont.SizeInPoints, [System.Drawing.FontStyle]::Italic)

Function PasswordGeneratorFORM
{
#region Form Scripts
    [string]$pass_upper   = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
    [string]$pass_lower   = 'abcdefghijklmnopqrstuvwxyz'
    [string]$pass_digits  = '0123456789'
    [string]$pass_special = '~!@#$%^&*_-+=`|\(){}[]:;"<>,.?/'
    [string]$pass_exclude = '!Ili10O,.'
    [Reflection.Assembly]::LoadWithPartialName("System.Web") | Out-Null 

    $passgenForm_Load = {
        ForEach ($control In $passgenForm.Controls) { $control.Font = $sysFont }
        $nud_SpecLength.Maximum = ($nud_PassLength.Value / 2)
        $opt_Characters_CheckedChanged.Invoke()
    }

    $opt_Characters_CheckedChanged = {
        $chk_Upper.Enabled      = $opt_Characters.Checked
        $chk_Lower.Enabled      = $opt_Characters.Checked
        $chk_Digits.Enabled     = $opt_Characters.Checked
        $chk_Special.Enabled    = $opt_Characters.Checked
        $chk_Exclude.Enabled    = $opt_Characters.Checked
        $lbl_AlsoExc.Enabled    = $opt_Characters.Checked
        $txt_AlsoExc.Enabled    = $opt_Characters.Checked

        $lbl_SpecLength.Enabled = (-not $opt_Characters.Checked)
        $nud_SpecLength.Enabled = (-not $opt_Characters.Checked)
        $lnk_LinkLabel.Enabled  = (-not $opt_Characters.Checked)
    }

    $tab_Pages_SelectedIndexChanged = {
        If ($tab_Pages.SelectedIndex -eq 0) { Return }

        [System.Text.StringBuilder]$passwordList = ''
        If ($opt_Characters.Checked -eq $true)
        {
            [string]$pass_toUse = ''
            If ($chk_Upper.Checked   -eq $True) { $pass_toUse += $pass_upper   }
            If ($chk_Lower.Checked   -eq $True) { $pass_toUse += $pass_lower   }
            If ($chk_Digits.Checked  -eq $True) { $pass_toUse += $pass_digits  }
            If ($chk_Special.Checked -eq $True) { $pass_toUse += $pass_special }
            If ($pass_toUse.Length -eq 0) { Return }

            If ($chk_Exclude.Checked -eq $True)                        { ForEach ($char In $pass_exclude.ToCharArray())     { $pass_toUse = $pass_toUse.Replace($char.ToString(), '') } }
            If ([string]::IsNullOrEmpty($txt_AlsoExc.Text) -eq $False) { ForEach ($char In $txt_AlsoExc.Text.ToCharArray()) { $pass_toUse = $pass_toUse.Replace($char.ToString(), '') } }

            $txt_Passwords.Text = ''
            For ($j = 0; $j -le 100; $j++)
            {
                [string]$newPassword = ''
                $newPassword = ((Get-Random -InputObject ($pass_toUse.ToCharArray()) -Count ($nud_PassLength.Value)) -join '')
                $passwordList.AppendLine($newPassword)
            }
        }
        Else
        {
            $txt_Passwords.Text = ''
            For ($j = 0; $j -le 100; $j++)
            {
                [string]$newPassword = [System.Web.Security.Membership]::GeneratePassword($nud_PassLength.Value, $nud_SpecLength.Value)
                $passwordList.AppendLine($newPassword)
            }
        }
        $txt_Passwords.Text = $passwordList.ToString()
    }

    $nud_PassLength_ValueChanged    = { $nud_SpecLength.Maximum = ($nud_PassLength.Value / 2) }

    $passgenForm_Cleanup_FormClosed = {
        $tab_Pages.Remove_SelectedIndexChanged($tab_Pages_SelectedIndexChanged)
        $passgenForm.Remove_Load($passgenForm_Load)
        $btn_Close.Remove_Click($btn_Close_Click)
        $opt_Microsoft.Remove_CheckedChanged($opt_Microsoft_CheckedChanged)
        $lnk_LinkLabel.Remove_LinkClicked($lnk_LinkLabel_LinkClicked)
        $nud_PassLength.Remove_ValueChanged($nud_PassLength_ValueChanged)
        $opt_Characters.Remove_CheckedChanged($opt_Characters_CheckedChanged)
        $passgenForm.Remove_FormClosed($passgenForm_Cleanup_FormClosed)
    }
#endregion
#region Form Controls
    $passgenForm    = New-Object 'System.Windows.Forms.Form'
    $tab_Pages      = New-Object 'System.Windows.Forms.TabControl'
    $tab_Page1      = New-Object 'System.Windows.Forms.TabPage'
    $tab_Page2      = New-Object 'System.Windows.Forms.TabPage'
    $lbl_PassLength = New-Object 'System.Windows.Forms.Label'
    $nud_PassLength = New-Object 'System.Windows.Forms.NumericUpDown'
    $opt_Characters = New-Object 'System.Windows.Forms.RadioButton'
    $chk_Upper      = New-Object 'System.Windows.Forms.CheckBox'
    $chk_Lower      = New-Object 'System.Windows.Forms.CheckBox'
    $chk_Digits     = New-Object 'System.Windows.Forms.CheckBox'
    $chk_Special    = New-Object 'System.Windows.Forms.CheckBox'
    $chk_Exclude    = New-Object 'System.Windows.Forms.CheckBox'
    $lbl_AlsoExc    = New-Object 'System.Windows.Forms.Label'
    $txt_AlsoExc    = New-Object 'System.Windows.Forms.TextBox'
    $opt_Microsoft  = New-Object 'System.Windows.Forms.RadioButton'
    $lbl_SpecLength = New-Object 'System.Windows.Forms.Label'
    $nud_SpecLength = New-Object 'System.Windows.Forms.NumericUpDown'
    $lnk_LinkLabel  = New-Object 'System.Windows.Forms.LinkLabel'
    $txt_Passwords  = New-Object 'System.Windows.Forms.TextBox'
    $btn_Close      = New-Object 'System.Windows.Forms.Button'

    $passgenForm.SuspendLayout()
    $tab_Pages.SuspendLayout()
    $tab_Page1.SuspendLayout()
    $tab_Page2.SuspendLayout()

    $passgenForm.FormBorderStyle     = 'FixedDialog'
    $passgenForm.MaximizeBox         = $False
    $passgenForm.MinimizeBox         = $False
    $passgenForm.Text                = ' Password Generator'
    $passgenForm.ShowInTaskbar       = $false
    $passgenForm.AutoScaleDimensions = '6, 13'
    $passgenForm.AutoScaleMode       = 'Font'
    $passgenForm.ClientSize          = '394, 422'    # 400 x 450
    $passgenForm.StartPosition       = 'CenterScreen'
    $passgenForm.Add_Load($passgenForm_Load)
    $passgenForm.Add_FormClosed($passgenForm_Cleanup_FormClosed)

    $tab_Pages.Location              = '12, 12'
    $tab_Pages.SelectedIndex         = 0
    $tab_Pages.Size                  = '370, 358'
    $tab_Pages.TabIndex              = 0
    $tab_Pages.Padding               = '12, 6'
    $tab_Pages.Add_SelectedIndexChanged($tab_Pages_SelectedIndexChanged)
    $passgenForm.Controls.Add($tab_Pages)

    $tab_Page1.Text                  = 'Settings'
    $tab_Page1.TabIndex              = 0
    $tab_Page1.BackColor             = 'Control'
    $tab_Pages.Controls.Add($tab_Page1)

    $tab_Page2.Text                  = 'Passwords'
    $tab_Page2.TabIndex              = 0
    $tab_Page2.BackColor             = 'Control'
    $tab_Pages.Controls.Add($tab_Page2)

    $lbl_PassLength.Location         = '  9,   9'
    $lbl_PassLength.Size             = '277,  20'
    $lbl_PassLength.Text             = 'Generated Password Length'
    $lbl_PassLength.TextAlign        = 'MiddleLeft'
    $tab_Page1.Controls.Add($lbl_PassLength)

    $nud_PassLength.Location         = '292,   9'
    $nud_PassLength.Size             = ' 61,  20'
    $nud_PassLength.Maximum          = '128'
    $nud_PassLength.Minimum          = '16'
    $nud_PassLength.TextAlign        = 'Right'
    $nud_PassLength.Value            = '32'
    $nud_PassLength.Add_ValueChanged($nud_PassLength_ValueChanged)
    $tab_Page1.Controls.Add($nud_PassLength)

    $opt_Characters.Location         = '  9,  50'
    $opt_Characters.Size             = '344,  20'
    $opt_Characters.Checked          = $true
    $opt_Characters.Text             = 'Generate Passwords Using Character Sets'
    $opt_Characters.Add_CheckedChanged($opt_Characters_CheckedChanged)
    $tab_Page1.Controls.Add($opt_Characters)

    $chk_Upper.Location              = ' 30,  76'
    $chk_Upper.Size                  = '323,  17'
    $chk_Upper.Checked               = $True
    $chk_Upper.Text                  = 'Upper-case (A, B, C, ...)'
    $tab_Page1.Controls.Add($chk_Upper)

    $chk_Lower.Location              = ' 30,  96'
    $chk_Lower.Size                  = '323,  17'
    $chk_Lower.Checked               = $True
    $chk_Lower.Text                  = 'Lower-case (a, b, c, ...)'
    $tab_Page1.Controls.Add($chk_Lower)

    $chk_Digits.Location             = ' 30, 116'
    $chk_Digits.Size                 = '323,  17'
    $chk_Digits.Checked              = $True
    $chk_Digits.Text                 = 'Numbers (1, 2, 3, ...)'
    $tab_Page1.Controls.Add($chk_Digits)

    $chk_Special.Location            = ' 30, 136'
    $chk_Special.Size                = '323, 17'
    $chk_Special.Checked             = $True
    $chk_Special.Text                = 'Symbols ($, %, &&, ...)'
    $tab_Page1.Controls.Add($chk_Special)

    $chk_Exclude.Location            = ' 30, 168'
    $chk_Exclude.Size                = '323, 17'
    $chk_Exclude.Checked             = $True
    $chk_Exclude.Text                = 'Exclude Charaters That Look Similar (Il1, O0)'
    $tab_Page1.Controls.Add($chk_Exclude)

    $lbl_AlsoExc.Location            = ' 30, 191'
    $lbl_AlsoExc.Size                = '103,  20'
    $lbl_AlsoExc.Text                = 'Also Exclude :'
    $lbl_AlsoExc.TextAlign           = 'MiddleLeft'
    $tab_Page1.Controls.Add($lbl_AlsoExc)

    $txt_AlsoExc.Location            = '139, 191'
    $txt_AlsoExc.Size                = '214,  20'
    $tab_Page1.Controls.Add($txt_AlsoExc)

    $opt_Microsoft.Location          = '  9, 232'
    $opt_Microsoft.Size              = '344,  20'
    $opt_Microsoft.Checked           = $false
    $opt_Microsoft.Text              = 'Generate Microsoft Secure Passwords'
    $opt_Microsoft.Add_CheckedChanged($opt_Microsoft_CheckedChanged)
    $tab_Page1.Controls.Add($opt_Microsoft)

    $lbl_SpecLength.Location         = ' 30, 258'
    $lbl_SpecLength.Size             = '256,  20'
    $lbl_SpecLength.Text             = 'Minimum Number Of Special Characters :'
    $lbl_SpecLength.TextAlign        = 'MiddleLeft'
    $tab_Page1.Controls.Add($lbl_SpecLength)

    $nud_SpecLength.Location         = '292, 258'
    $nud_SpecLength.Size             = ' 61,  20'
    $nud_SpecLength.Maximum          = '128'
    $nud_SpecLength.Minimum          = '4'
    $nud_SpecLength.TextAlign        = 'Right'
    $nud_SpecLength.Value            = '8'
    $tab_Page1.Controls.Add($nud_SpecLength)

    $lnk_LinkLabel.Location          = ' 30, 284'
    $lnk_LinkLabel.Size              = '323,  40'
    $lnk_LinkLabel.Text              = 'https://msdn.microsoft.com/en-us/library/system.web.security.membership.generatepassword.aspx'
    $lnk_LinkLabel.TextAlign         = 'TopLeft'
    $lnk_LinkLabel.UseCompatibleTextRendering = $false
    $lnk_LinkLabel.Add_LinkClicked({ Start-Process -FilePath $($lnk_LinkLabel.Text) })
    $tab_Page1.Controls.Add($lnk_LinkLabel)

    $txt_Passwords.Location          = '  9,   9'
    $txt_Passwords.Size              = '344, 308'
    $txt_Passwords.Text              = ''
    $txt_Passwords.ScrollBars        = 'Both'
    $txt_Passwords.Multiline         = $True
    $txt_Passwords.WordWrap          = $False
    $tab_Page2.Controls.Add($txt_Passwords)

    $btn_Close.Location              = '307, 385'
    $btn_Close.Size                  = ' 75,  25'
    $btn_Close.Text                  = 'Close'
    $btn_Close.TabIndex              = '97'
    $passgenForm.CancelButton        = $btn_Close
    $passgenForm.Controls.Add($btn_Close)

    $tab_Page1.ResumeLayout()
    $tab_Page2.ResumeLayout()
    $tab_Pages.ResumeLayout()
    $passgenForm.ResumeLayout()

#endregion
#region Show Form And Return Value
    ForEach ($control In $passgenForm.Controls) { $control.Font = $sysFont }
    $txt_Passwords.Font  = New-Object 'System.Drawing.Font' ('Consolas', [System.Drawing.SystemFonts]::MessageBoxFont.SizeInPoints, [System.Drawing.FontStyle]::Regular)
    $lbl_PassLength.Font = $sysFontBold
    $opt_Characters.Font = $sysFontBold 
    $opt_Microsoft.Font  = $sysFontBold
    $passgenForm.ShowDialog()
#endregion
}

PasswordGeneratorFORM | Out-Null
