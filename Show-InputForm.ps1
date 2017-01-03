<#
.SYNOPSIS
    PowerShell GUI form for data input

.DESCRIPTION
    Multiple use GUI for asking for a variety of input types that can also perform simple validation.
    Input type includes:
        Simple text box
        List of check boxes
        List of text boxes
        Dropdown selection
        Large multiline text box

    Validation can be enabled for checking input is in one of the following formats:
        Alphabetic (Letters A-Z only)
        Numerical
        Integer
        Decimal
        URL (only http(s):// , (s)ftp(s)://)
        Email Address
        IPv4
        IPv6

    The 'list of text boxes' input type will also validate for duplicated entries

.PARAMETER Type
    The type of input form to show
    One of the following: 'Simple', 'Password', 'Check', 'Option', 'List', 'Multi' or 'Large'

.PARAMETER Title
    The window title for the input form

.PARAMETER Description
    Long description text of what the user is expected to enter into the form

.PARAMETER Validation
    One of the following: 'None', 'AZ', 'Numeric', 'Integer', 'Decimal', 'Symbol', 'URL', 'Email', 'IPv4' or 'IPv6'
    Can only be used with the following types: 'Simple', 'Password' and 'List'

.PARAMETER InputList
    One or more entries for the 'Check', 'Option' or 'List' input types

.PARAMETER CurrentValue
    One or more entries that are pre-selected for the 'Check' type, already filled in for the 'List' type.
    Use a single entry for the pre-selected 'Option' type

.PARAMETER EnableKeePass
    Allows the use of asking for a KeePass password database entry and field name
    Can only be used with the following types: 'Simple', 'Password', 'Multi' and 'Large'

.INPUTS
    None

.OUTPUTS
    System.String or System.String[]
    Return value depends on input form Type
    Will return '!!-CANCELLED-!!' if the form is cancelled

.EXAMPLE
    Show-InputForm -Type 'Simple' -Title 'Input Form' -Description 'Enter your name'
    Simple input box with no validation.

.EXAMPLE
    Show-InputForm -Type 'Simple' -Title 'Numerical Input' -Description 'Enter correct threshold value' -Validation 'Integer' -CurrentValue '32'
    Simple input box, prepopulated with a value of 32.  Accepts only integer numbers.

.EXAMPLE
    Show-InputForm -Type 'Check' -Title 'CheckBox List' -Description 'Select one or more options from the list below' -InputList ('Black','Blue','Cyan','Green','Red','Yellow','White') -CurrentValue ('Blue','Green')
    A list of multi-selectable check boxes, with 'Blue' and 'Green' automatically ticked.

.EXAMPLE
    Show-InputForm -Type 'Option' -Title 'Option List' -Description 'Select your favourite colour' -InputList ('Black','Blue','Cyan','Green','Red','Yellow','White')
    A single drop down list populated with colours, none are pre-selected.

.EXAMPLE
    Show-InputForm -Type 'List' -Title 'Multiple Items' -Description 'Enter all the addresses you want to send an email to' -Validation 'Email' -CurrentValue ('someone@example.com','support@myrandomthoughts.co.uk')
    A list of simple text boxes allowing for multiple text entries, all with email address validation.  Two addresses have already been added.

.EXAMPLE
    Show-InputForm -Type 'Large' -Title 'Larger Text' -Description 'Enter your public certificate below'
    Simple multi-line input box that does not keep line breaks.
    Use -Type 'Multi' for line break support

.LINK
    http://myrandomthoughts.co.uk

.LINK
    support@myrandomthoughts.co.uk
#>
Function Show-InputForm
{
    Param
    (
        [parameter(Mandatory=$true )] [ValidateSet('Simple', 'Password', 'Check', 'Option', 'List', 'Multi', 'Large')]
                                        [string]  $Type,
        [parameter(Mandatory=$true )]   [string]  $Title,
        [parameter(Mandatory=$true )]   [string]  $Description,
        [parameter(Mandatory=$false)] [ValidateSet('None', 'AZ', 'Numeric', 'Integer', 'Decimal', 'Symbol', 'URL', 'Email', 'IPv4', 'IPv6')]
                                        [string]  $Validation = 'None',
        [parameter(Mandatory=$false)]   [string[]]$InputList,
        [parameter(Mandatory=$false)]   [string[]]$CurrentValue,
        [parameter(Mandatory=$false)]   [boolean] $EnableKeePass = $false
    )

    [Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms') | Out-Null
    [Reflection.Assembly]::LoadWithPartialName('System.Data')          | Out-Null
    [Reflection.Assembly]::LoadWithPartialName('System.Drawing')       | Out-Null
    [System.Drawing.Font]$sysFont = [System.Drawing.SystemFonts]::MessageBoxFont
    [System.Windows.Forms.Application]::EnableVisualStyles()

#region Form Scripts
    $ChkButton_Click = {
        If ($ChkButton.Text -eq 'Check All') { $ChkButton.Text = 'Check None'; [boolean]$checked = $true } Else { $ChkButton.Text = 'Check All'; [boolean]$checked = $False }
        ForEach ($Control In $frm_Main.Controls) { If ($control -is [System.Windows.Forms.CheckBox]) { $control.Checked = $checked } }
    }

    $AddButton_Click = { AddButton_Click -BoxNumber (($frm_Main.Controls.Count - 5) / 2) -Value '' -Override $false -Type 'TEXT' }
    Function AddButton_Click ( [int]$BoxNumber, [string]$Value, [boolean]$Override, [string]$Type )
    {
        If ($Type -eq 'TEXT')
        {
            ForEach ($control In $frm_Main.Controls) {
                If ($control -is [System.Windows.Forms.TextBox]) {
                    [System.Windows.Forms.TextBox]$isEmtpy = $null
                    If ([string]::IsNullOrEmpty($control.Text) -eq $True) { $isEmtpy = $control; Break }
                }
            }

            If ($Override -eq $true) { $isEmtpy = $null } 
            If ($isEmtpy -ne $null)
            {
                $isEmtpy.Select()
                $isEmtpy.Text = $Value
                Return
            }
        }

        # Increase form size, move buttons down, add new field
        $numberOfTextBoxes++
        $frm_Main.ClientSize        = "394, $(147 + ($BoxNumber * 26))"
        $btn_Accept.Location        = "307, $(110 + ($BoxNumber * 26))"
        $btn_Cancel.Location        = "220, $(110 + ($BoxNumber * 26))"

        If ($Type -eq 'TEXT')
        {
            $AddButton.Location     = " 39, $(110 + ($BoxNumber * 26))"

            # Add new counter label
            $labelCounter           = New-Object 'System.Windows.Forms.Label'
            $labelCounter.Location  = " 12, $(75 + ($BoxNumber * 26))"
            $labelCounter.Size      = ' 21,   20'
            $labelCounter.Font      = $sysFont
            $labelCounter.Text      = "$($BoxNumber + 1):"
            $labelCounter.TextAlign = 'MiddleRight'
            $frm_Main.Controls.Add($labelCounter)

            # Add new text box and select it for focus
            $textBox                = New-Object 'System.Windows.Forms.TextBox'
            $textBox.Location       = " 39, $(75 + ($BoxNumber * 26))"
            $textBox.Size           = '343,   20'
            $textBox.Font           = $sysFont
            $textBox.Name           = "textBox$BoxNumber"
            $textBox.Text           = $Value.Trim()
            $frm_Main.Controls.Add($textBox)
            $frm_Main.Controls["textbox$BoxNumber"].Select()
        }
        ElseIf ($Type -eq 'CHECK')
        {
            # Add new check box
            $chkBox                = New-Object 'System.Windows.Forms.CheckBox'
            $chkBox.Location       = " 12, $(75 + ($BoxNumber * 26))"
            $chkBox.Size           = '370,   20'
            $chkBox.Font           = $sysFont
            $chkBox.Name           = "chkBox$BoxNumber"
            $chkBox.Text           = $Value
            $chkBox.TextAlign      = 'MiddleLeft'
            $frm_Main.Controls.Add($chkBox)
            $frm_Main.Controls["chkbox$BoxNumber"].Select()
        }
    }

    $kp_comboBox_SelectedIndexChanged = {
        Try {
            If ($kp_comboBox.SelectedIndex -eq ($kp_comboBox.Items.Count - 1)) { $kp_CustomField.Enabled = $True;  $kp_CustomField.Text = ''                        }
            Else                                                               { $kp_CustomField.Enabled = $False; $kp_CustomField.Text = $kp_comboBox.SelectedItem }
        } Catch {}
    }

    $KeePassButton_Click = { Change-Form -ChangeTo ($KeePassButton.Text) }
    Function Change-Form ( [string]$ChangeTo )
    {
        If ($ChangeTo -eq 'KeePass')    # Change to KeePass mode
        {
            # Hide Fields
            $textBox.Visible          = $False
            $pic_InvalidValue.Visible = $False

            # Show Fields
            $kp_textBox.Visible       = $True
            $kp_EntryLabel.Visible    = $True
            $kp_FieldLabel.Visible    = $True
            $kp_comboBox.Visible      = $True
            $kp_CustomField.Visible   = $True
            $kp_comboBox_SelectedIndexChanged.Invoke()
            $kp_textBox.Select()

            # Resize form
            $frm_Main.ClientSize      = "394, $(147 + 62)"
            $btn_Accept.Location      = "307, $(110 + 62)"    # 62 comes from
            $btn_Cancel.Location      = "220, $(110 + 62)"    # VB.net IDE
            $KeePassButton.Location   = " 12, $(110 + 62)"    #
            $KeePassButton.Text       = 'Simple'
            $KeePassButton.TabIndex   = '199'
        }
        ElseIf (($Type -eq 'Multi') -or ($Type -eq 'Large'))
        {
            # Hide Fields
            $kp_textBox.Visible       = $False
            $kp_EntryLabel.Visible    = $False
            $kp_FieldLabel.Visible    = $False
            $kp_comboBox.Visible      = $False
            $kp_CustomField.Visible   = $False
            $pic_InvalidValue.Visible = $False

            # Show Fields
            $textBox.Visible          = $True
            $textBox.Select()

            # Resize form
            $frm_Main.ClientSize      = "394, $(147 + 104)"
            $btn_Accept.Location      = "307, $(110 + 104)"
            $btn_Cancel.Location      = "220, $(110 + 104)"
            $KeePassButton.Location   = " 12, $(110 + 104)"
            $KeePassButton.Text       = 'KeePass'
            $KeePassButton.TabIndex   = '199'
        }
        Else
        {
            # Hide Fields
            $kp_textBox.Visible       = $False
            $kp_EntryLabel.Visible    = $False
            $kp_FieldLabel.Visible    = $False
            $kp_comboBox.Visible      = $False
            $kp_CustomField.Visible   = $False
            $pic_InvalidValue.Visible = $False

            # Show Fields
            $textBox.Visible          = $True
            $textBox.Select()

            # Resize form
            $frm_Main.ClientSize      = '394, 147'
            $btn_Accept.Location      = '307, 110'
            $btn_Cancel.Location      = '220, 110'
            $KeePassButton.Location   = ' 12, 110'
            $KeePassButton.Text       = 'KeePass'
            $KeePassButton.TabIndex   = '199'
        }
    }

    # Start form validation and make sure everything entered is correct
    $btn_Accept_Click = {
        [string[]]$currentValues  = @('')
        [boolean] $ValidatedInput = $true

        ForEach ($Control In $frm_Main.Controls)
        {
             If (($Control -is [System.Windows.Forms.TextBox]) -and ($Control.Visible -eq $true))
            {
                $Control.BackColor = 'Window'
                If (($Type -eq 'LIST') -and ($Control.Text.Contains(';') -eq $true))
                {
                    [string[]]$ControlText = ($Control.Text).Split(';')
                    $Control.Text = ''    # Remove current data so that it can be used as a landing control for the split data
                    ForEach ($item In $ControlText) { AddButton_Click -BoxNumber (($frm_Main.Controls.Count - 5) / 2) -Value $item -Override $false -Type 'TEXT' }
                }
            }
        }

        # Reset Control Loop for any new fields that may have been added
        ForEach ($Control In $frm_Main.Controls)
        {
            If (($Control -is [System.Windows.Forms.TextBox]) -and ($Control.Visible -eq $true))
            {
                $ValidatedInput = $(ValidateInputBox -Control $Control)
                $pic_InvalidValue.Image = $img_Input.Images[0]
                $pic_InvalidValue.Tag   = 'Validation failed for current value'
                $ToolTip.SetToolTip($pic_InvalidValue, $pic_InvalidValue.Tag)

                If ($ValidatedInput -eq $true)
                {
                    Try { If ($kp_comboBox.Visible -eq $true) { $currentValues = '' } } Catch { }    # Skip duplication check if using KeePass
                    If (($Type -eq 'LIST') -and (([string]::IsNullOrEmpty($Control.Text) -eq $false) -and ($currentValues -contains ($Control.text))))
                    {
                        $ValidatedInput = $false
                        $pic_InvalidValue.Image = $img_Input.Images[1]
                        $pic_InvalidValue.Tag   = 'Duplicated value found'
                        $ToolTip.SetToolTip($pic_InvalidValue, $pic_InvalidValue.Tag)
                        $Control.BackColor = 'Info'
                    }
                    Else { $currentValues += $Control.Text }
                }

                If ($ValidatedInput -eq $false)
                {
                    $pic_InvalidValue.Location = "331, $([math]::Round(($Control.Height -16) / 2) + $Control.Top)"    # 331 = $($($Control.Left) + $($Control.Width) - (48 + 3))
                    $pic_InvalidValue.Visible  = $true
                    $Control.Focus()
                    $Control.SelectAll()
                    $ToolTip.Show($pic_InvalidValue.Tag, $pic_InvalidValue, 36, 12, 2500)
                    $Control.BackColor = 'Info'
                    Break
                }
            }
        }

        $currentValues = $null
        If ($ValidatedInput -eq $true) { $frm_Main.DialogResult = [System.Windows.Forms.DialogResult]::OK }
    }

    Function ValidateInputBox ([System.Windows.Forms.Control]$Control)
    {
        $Control.Text = ($Control.Text.Trim())
        [boolean]$ValidateResult = $false
        [string] $StringToCheck  = $($Control.Text)

        # Ignore ValidateAgainst if KeePass is used
        Try { If ($kp_comboBox.Visible -eq $true) { Return (-not [string]::IsNullOrEmpty($StringToCheck)) } } Catch { }

        # Ignore for MULTI and LARGE fields
        If (($Type -eq 'LARGE') -or ($Type -eq 'MULTI')) { Return $true }

        # Ignore control if empty
        If ([string]::IsNullOrEmpty($StringToCheck) -eq $true) { Return $true }

        # Validate
        Switch ($Validation)
        {
            'AZ'      { $ValidateResult = ($StringToCheck -match "^[A-Za-z]+$");            Break }    # Letters only (A-Za-z)
            'Numeric' { $ValidateResult = ($StringToCheck -match '^(-)?([\d]+)?\.?[\d]+$'); Break }    # Both integer and decimal numbers
            'Integer' { $ValidateResult = ($StringToCheck -match '^(-)?[\d]+$');            Break }    # Integer numbers only
            'Decimal' { $ValidateResult = ($StringToCheck -match '^(-)?[\d]+\.[\d]+$');     Break }    # Decimal numbers only
            'Symbol'  { $ValidateResult = ($StringToCheck -match '^[^A-Za-z0-9]+$');        Break }    # Any symbol (not numbers or letters)
            'URL'     {                                                                                # URL
                [url]    $url       = ''
                [boolean]$ValidURL1 = ($StringToCheck -match '^(ht|(s)?f|)tp(s)?:\/\/')    # http(s):// or (s)ftp(s)://
                [boolean]$ValidURL2 = ([System.Uri]::TryCreate($StringToCheck, [System.UriKind]::Absolute, [ref]$url))
                $ValidateResult     = ($ValidURL1 -and $ValidURL2)
                Break
            }
            'Email'   {                                                                                # email@address.validation
                Try   { $ValidateResult = (($StringToCheck -as [System.Net.Mail.MailAddress]).Address -eq $StringToCheck) }
                Catch { $ValidateResult =   $false }
                Break
            }
            'IPv4'    {                                                                                # IPv4 address (1.2.3.4)
                [boolean]$Octets  = (($StringToCheck.Split('.') | Measure-Object).Count -eq 4)
                [boolean]$ValidIP =  ($StringToCheck -as [ipaddress]) -as [boolean]
                $ValidateResult   =  ($ValidIP -and $Octets)
                Break
            }
            'IPv6'    {                                                                                # IPv6 address (REGEX from 'https://www.powershellgallery.com/packages/IPv6Regex/1.1.1')
                [string]$IPv6 = @"
                    ^((([0-9a-f]{1,4}:){7}([0-9a-f]{1,4}|:))|(([0-9a-f]{1,4}:){6}(:[0-9a-f]{1,4}|((25[0-5]|2[0-4]\d|1\d\d|[1-9]?[0-9])\.){3}(25[0-5]|2[0-4]\d|1\d\d|[1-9]?[0-9])|:))|(([0-9a-f]
                    {1,4}:){5}(((:[0-9a-f]{1,4}){1,2})|:((25[0-5]|2[0-4]\d|1\d\d|[1-9]?[0-9])\.){3}(25[0-5]|2[0-4]\d|1\d\d|[1-9]?[0-9])|:))|(([0-9a-f]{1,4}:){4}(((:[0-9a-f]{1,4}){1,3})|((:[0-9a-f]
                    {1,4})?:((25[0-5]|2[0-4]\d|1\d\d|[1-9]?[0-9])\.){3}(25[0-5]|2[0-4]\d|1\d\d|[1-9]?[0-9]))|:))|(([0-9a-f]{1,4}:){3}(((:[0-9a-f]{1,4}){1,4})|((:[0-9a-f]{1,4}){0,2}:((25[0-5]|
                    2[0-4]\d|1\d\d|[1-9]?[0-9])\.){3}(25[0-5]|2[0-4]\d|1\d\d|[1-9]?[0-9]))|:))|(([0-9a-f]{1,4}:){2}(((:[0-9a-f]{1,4}){1,5})|((:[0-9a-f]{1,4}){0,3}:((25[0-5]|2[0-4]\d|1\d\d|[1-9]
                    ?[0-9])\.){3}(25[0-5]|2[0-4]\d|1\d\d|[1-9]?[0-9]))|:))|(([0-9a-f]{1,4}:){1}(((:[0-9a-f]{1,4}){1,6})|((:[0-9a-f]{1,4}){0,4}:((25[0-5]|2[0-4]\d|1\d\d|[1-9]?[0-9])\.){3}(25[0-5]|
                    2[0-4]\d|1\d\d|[1-9]?[0-9]))|:))|(:(((:[0-9a-f]{1,4}){1,7})|((:[0-9a-f]{1,4}){0,5}:((25[0-5]|2[0-4]\d|1\d\d|[1-9]?[0-9])\.){3}(25[0-5]|2[0-4]\d|1\d\d|[1-9]?[0-9]))|:)))$
"@
                $ValidateResult = ($StringToCheck -match $IPv6)
                Break
            }
            Default   {                                                                                # No Validation
                $ValidateResult = $true
            }
        }
        Return $ValidateResult
    }

    $frm_Main_Cleanup_FormClosed = {
        Try {
            $btn_Accept.Remove_Click($btn_Accept_Click)
            $AddButton.Remove_Click($AddButton_Click)
            $KeePassButton.Remove_Click($KeePassButton_Click)
        } Catch {}
        $frm_Main.Remove_FormClosed($frm_Main_Cleanup_FormClosed)
    }
#endregion
#region Input Form Controls
    [System.Windows.Forms.Application]::EnableVisualStyles()
    $frm_Main = New-Object 'System.Windows.Forms.Form'
    $frm_Main.FormBorderStyle      = 'FixedDialog'
    $frm_Main.MaximizeBox          = $False
    $frm_Main.MinimizeBox          = $False
    $frm_Main.ControlBox           = $False
    $frm_Main.Text                 = " $Title"
    $frm_Main.ShowInTaskbar        = $True
    $frm_Main.AutoScaleDimensions  = '6, 13'
    $frm_Main.AutoScaleMode        = 'Font'
    $frm_Main.ClientSize           = '394, 147'    # 400 x 175
    $frm_Main.StartPosition        = 'CenterScreen'

    $ToolTip                       = New-Object 'System.Windows.Forms.ToolTip'

    # 48x16 Image List for INVALID and DUPLICATE error message icons
    $img_Input                     = New-Object 'System.Windows.Forms.ImageList'
	$img_Input.TransparentColor    = 'Transparent'
	$img_Input_binaryFomatter      = New-Object 'System.Runtime.Serialization.Formatters.Binary.BinaryFormatter'
	$img_Input_MemoryStream        = New-Object 'System.IO.MemoryStream' (,[byte[]][System.Convert]::FromBase64String('
        AAEAAAD/////AQAAAAAAAAAMAgAAAFdTeXN0ZW0uV2luZG93cy5Gb3JtcywgVmVyc2lvbj00LjAuMC4wLCBDdWx0dXJlPW5ldXRyYWwsIFB1YmxpY0tleVRva2VuPWI3N2E1YzU2MTkzNGUwODkFAQAAACZTeXN0ZW0uV2luZG93cy5Gb3Jtcy5JbWFnZUxpc3RTdHJlYW1lcgEAAAAERGF0YQcCAgAAAAkD
        AAAADwMAAADkCgAAAk1TRnQBSQFMAgEBAgEAAQgBAAEIAQABMAEAARABAAT/ASEBAAj/AUIBTQE2BwABNgMAASgDAAHAAwABEAMAAQEBAAEgBgABMP8A/wD/AP8AGgADNAFxAzQBiP8A/wD6AAMyAZkDKwG2/wD/APoAAzIBmQMrAbb/AP8ANgADNAGPAzUBeQQAAy0BUAMvAaoEAAM1AXkDNQGBCAADEQEX
        AywBswwAAyMBNgMqAboDMwFqAygBvwMcASgDDgESAygBvwMcASgDDgESAygBvwMcASgEAAMxAV0DKgG6AzMBZwMoAb8YAAMtAbEDKAG/AysBuAMxAVsMAAM1AX4DKAG/AzEBowMRARYEAAMyAZkDKQG8AzIBmQMwAaYDCAEKBAADMQGiAy8BVwQAAzEBogMvAVcEAAMaASUDLQGvAy0BsgMNBBEBFgMvAaoD
        NAGIAzEBogMvAVcEAAMxAV4DMwGaCAADHwEuAysBtQMvAaoDFwEg/wDFAAMoAb8DMQGjBAADNAFsAxQB4wQAAzEBowMuAa0IAAMxAVsDAAH/AxwBKQgAAyAB0AMrAbUDNQGDAwAB/wMjATUDEgEYAwAB/wMjATUDEgEYAwAB/wMjATUDCwEOAwQB+gM0AY8DLwGsAwAB/xgAAw8B7AM0AZEDNAF1AwIB/AMy
        AWIEAAMrAUkDBAH6AywBTAMdAdYDNAGNBAADMgGZAwsB8AMtAVADBgH4AzMBaQQAAxsB2AM0AXUEAAMbAdgDNAF1BAADKQG7Ax8B0QMqAUcDDQERAzQBkAMUAeUDLwFVAwIB/AM0AXUEAAM1AX4DIQHNCAADGAHeAzQBkgMzAZcDLAG0/wDFAAMoAb8DMQGjBAADNAFsAxQB4wQAAzEBowMuAa0IAAMyAZ4D
        EAHrAzMBawgAAwQB+gMzAWkDGAEiAwAB/wMjATUDEgEYAwAB/wMjATUDEgEYAwAB/wMjATUDIQExAwAB/wMiATMDMQFfAwAB/xgAAw8B7AM0AWwEAAMtAbIDJgHCBAADNAFsAxQB4wQAAzEBowMuAa0EAAMyAZkDJAHGBAADIwHJAzMBmAQAAxsB2AM0AXUEAAMbAdgDNAF1BAADCAH1AzQBcAgAAyoBugMv
        AaoEAAMUAeMDNAF1BAADNQF+AyEBzQQAAxUBHQMAAf8DIwE1AyMBNgMvAaz/AMUAAygBvwMxAaMEAAM0AWwDFAHjBAADMQGjAy4BrQgAAxQB5AM0AY0DLQGwBAADBwEJAwAB/wMwAVoDEgEYAwAB/wMjATUDEgEYAwAB/wMjATUDEgEYAwAB/wMjATUDIwE1AwAB/wMbAScDLAFNAwAB/xgAAw8B7AM0AWwE
        AAM1AXcDDAHvBAADNAFsAxQB4wQAAzEBowMuAa0EAAMyAZkDKwG4BAADKwG2AzEBowQAAxsB2AM0AXUEAAMbAdgDNAF1AwcBCQMAAf8DMgFiCAADIwHKAzIBmwQAAxsB2AM0AXUEAAM1AX4DIQHNBAADHwEuAwAB/wMzAZYDNQF+AzUBfv8AxQADKAG/AzEBowQAAzQBbAMUAeMEAAMxAaMDLgGtBAADGwEm
        AwgB9QMfAS0DDQHuCAIDAAH/AzEBXQMSARgDAAH/AyMBNQMSARgDAAH/AyMBNQMSARgDAAH/AyMBNQMiATMDAAH/Ax4BLAMtAVADAAH/GAADDwHsAzQBbAQAAzMBZwMAAf8EAgM0AWwDFAHjBAADMQGjAy4BrQQAAzIBmQMrAbgEAAMpAb0DMgGgBAADGwHYAzQBdQQAAxsB2AM0AXUDBQEGAwIB/AMyAWUI
        AAMmAcIDMgGeBAADGwHYAzQBdQQAAzUBfgMhAc0EAAMbAScDAAH/AzMBlgMwAaYDBAH6/wDFAAMoAb8DMQGjBAADNAFsAw8B7AQAAy8BqAMuAa0EAAMzAWsDJgHEBAIDCwHxAyEBMgQAAxIB5wM1AXsDIgE0AwAB/wMjATUDEgEYAwAB/wMjATUDEgEYAwAB/wMjATUDFwEgAwAB/wMrAUkDMwFpAwAB/xgA
        Aw8B7AM0AWwEAAMyAWIDAAH/AwcBCQM0AWwDFAHjBAADMQGjAy4BrQQAAzIBmQMeAdQEAAMXAd8DNAGHBAADGwHYAzQBdQQAAxsB2AM0AXUEAAMYAd4DMgGZCAADMAGnAykBvAQCAwsB8QM0AXUEAAM1AX4DIQHNBAADBAEFAwgB9QMnAT0DMQFdAxgB3f8AxQADKAG/AzEBowQAAzQBbAMLAfEDJwHAAwQB
        +gM1AYAEAAMtAbIDNAGQBAADKAG+AzQBdgQAAzQBlAMKAfIDKQG9AwAB/wMjATUDEgEYAwAB/wMjATUDEgEYAwAB/wMjATUEAAMiAcsDFAHlAyUBxQMAAf8YAAMPAewDNAFsBAADNAFsAwQB+gQAAzQBbAMUAeMEAAMxAaMDLgGtBAADMgGZAxcB3wMjAcoDAgH8AyMBNgQAAxsB2AM0AXUEAAMbAdgDNAF1
        BAADMgFhAwIB/AMkAcgDGQEjAy4BVAMAAf8DJgHEAxAB6wM0AXUDKAFBAxcB3wMKAfIDNQF5BAADNQGBAykBuwMjAcoDNAF0/wDFAAMoAb8DMQGjBAADEwEaAyQBNwMTARoDJQE6CAADIwE1AxMBGgQAAxsBJwMbAScIAAMnAT4DDwETAycBPgMJAQwDEgEYAwAB/wMjATUDBAEFAycBPgMJAQwEAAMIAQoD
        JgE8AywBTQMAAf8YAAMPAewDNAFsBAADNQGJAxgB3QQAAxMBGgMkATcEAAMbAScDHQEqBAADGgElAx0BKgMYASIDGwEnCAADGwHYAzQBdQQAAyMBNQMVARwIAAMbAScDHwEuCAADHwEuAxUBHAMjATUDFQEcAxABFQMxAZ8DGwHaAxsBJwgAAx8BLgMdASr/AMkAAygBvwMxAaNIAAMSARgDAAH/AyMBNQQA
        AyEBMhAAAywBTQMAAf8YAAMPAewDNAFsAwgBCgMaAdkDMgGZNAADGwHYAzQBdQQAAxoBJQMJAQwsAAM1AX4DIQHN/wDdAAMoAb8DMQGjSAADEgEYAwAB/wMjATUDEgEYAwAB/wMjATUMAAMsAU0DAAH/GAADDwHsAxsB2gMUAeUDHQHVAxIBGDQAAxsB2AM0AXUEAAMbAdgDNAF1/wD/ABIAAx8BLgMbASdI
        AAMOARIDKAG/AxwBKAQAAyEBMhAAAyUBOQMoAb8YAAMlAToDJwE+AyUBOjwAAzEBogMvAVcEAAMaASUDCQEM/wD/AP8A/wDUAAFCAU0BPgcAAT4DAAEoAwABwAMAARADAAEBAQABAQUAAYABARYAA/8BAAz/DAAI/wGfA/8MAAj/AZ8D/wwACP8BnwP/DAAC/wEkAc4BAAEhAfgBcAGCAUgBAgFhDAAC/wEk
        AcYBAAEBAfgBIAGCAUgBAgFhDAAC/wEkAcYBAAEBAfkBJAGSAUkBkgFBDAAC/wEkAcQBAAEBAfkBJAGSAUEBkgFBDAAC/wEkAYABAAEBAfkBBAGSAUEBkgFBDAAC/wEkAYIBAAEBAfkBBAGSAUkBggFBDAAC/wEgAZIBAAEhAfkBJAGCAUgBAAEhDAAC/wEhAZMBAAEhAfkBJAGGAUwBwAEzDAAC/wE/Af8B
        8QF5AfgBPwH+AU8B/gF/DAAC/wE/Af8B8AE5AfgBPwH+AU8C/wwAAv8BPwH/AfEBeQH4Af8B/gFPAv8MAAz/DAAL'))
	$img_Input.ImageStream         = $img_Input_binaryFomatter.Deserialize($img_Input_MemoryStream)
	$img_Input_binaryFomatter      = $null
	$img_Input_MemoryStream        = $null

    $pic_InvalidValue              = New-Object 'System.Windows.Forms.PictureBox'
    $pic_InvalidValue.BackColor    = 'Info'
    $pic_InvalidValue.Location     = '  0,   0'
    $pic_InvalidValue.Size         = ' 48,  16'
    $pic_InvalidValue.Visible      = $false
    $pic_InvalidValue.TabStop      = $False
    $pic_InvalidValue.BringToFront()
    $frm_Main.Controls.Add($pic_InvalidValue)

    $lbl_Description               = New-Object 'System.Windows.Forms.Label'
    $lbl_Description.Location      = ' 12,  12'
    $lbl_Description.Size          = '370,  48'
    $lbl_Description.Font          = $sysFont
    $lbl_Description.Text          = $($Description.Trim())
    $frm_Main.Controls.Add($lbl_Description)

    If ($Validation -ne 'None')
    {
        $lbl_Validation            = New-Object 'System.Windows.Forms.Label'
        $lbl_Validation.Location   = '212,  60'
        $lbl_Validation.Size       = '170,  15'
        $lbl_Validation.Font       = $sysFont
        $lbl_Validation.Text       = "Validation: $Validation"
        $lbl_Validation.TextAlign  = 'BottomRight'
        $frm_Main.Controls.Add($lbl_Validation)
    }

    $btn_Accept                    = New-Object 'System.Windows.Forms.Button'
    $btn_Accept.Location           = '307, 110'
    $btn_Accept.Size               = ' 75,  25'
    $btn_Accept.Font               = $sysFont
    $btn_Accept.Text               = 'OK'
    $btn_Accept.TabIndex           = '97'
    $btn_Accept.Add_Click($btn_Accept_Click)
    If (($Type -ne 'MULTI') -and ($Type -ne 'LARGE')) { $frm_Main.AcceptButton = $btn_Accept }
    $frm_Main.Controls.Add($btn_Accept)

    $btn_Cancel                    = New-Object 'System.Windows.Forms.Button'
    $btn_Cancel.Location           = '220, 110'
    $btn_Cancel.Size               = ' 75,  25'
    $btn_Cancel.Font               = $sysFont
    $btn_Cancel.Text               = 'Cancel'
    $btn_Cancel.TabIndex           = '98'
    $btn_Cancel.DialogResult       = [System.Windows.Forms.DialogResult]::Cancel
    $frm_Main.CancelButton         = $btn_Cancel
    $frm_Main.Controls.Add($btn_Cancel)
    $frm_Main.Add_FormClosed($frm_Main_Cleanup_FormClosed)
#endregion
#region Input Form Controls Part 2
    Switch ($Type)
    {
        'LIST' {
            # List of text boxes
            [int]$itemCount = ($CurrentValue.Count)
            If ($itemCount -ge 5) { [int]$numberOfTextBoxes = $itemCount + 1 } Else { [int]$numberOfTextBoxes = 5 }
            $numberOfTextBoxes--    # Count from zero

            # Add 'Add' button
            $AddButton              = New-Object 'System.Windows.Forms.Button'
            $AddButton.Location     = " 39, $(110 + ($numberOfTextBoxes * 26))"
            $AddButton.Size         = ' 75,   25'
            $AddButton.Font         = $sysFont
            $AddButton.Text         = 'Add'
            $AddButton.Add_Click($AddButton_Click)
            $frm_Main.Controls.Add($AddButton)

            # Add initial textboxes
            For ($i = 0; $i -le $numberOfTextBoxes; $i++) { AddButton_Click -BoxNumber $i -Value ($CurrentValue[$i]) -Override $true -Type 'TEXT' }
            $frm_Main.Controls['textbox0'].Select()
            Break
        }

        'CHECK' {
            # Add 'Check All' button
            $ChkButton              = New-Object 'System.Windows.Forms.Button'
            $ChkButton.Location     = " 12, $(110 + (($InputList.Count -1) * 26))"
            $ChkButton.Size         = '125,   25'
            $ChkButton.Font         = $sysFont
            $ChkButton.Text         = 'Check All'
            $ChkButton.Add_Click($ChkButton_Click)
            $frm_Main.Controls.Add($ChkButton)

            # Add initial textboxes
            [int]$i = 0
            ForEach ($item In $InputList)
            {
                AddButton_Click -BoxNumber $i -Value ($item.Trim()) -Override $true -Type 'CHECK'
                If ([string]::IsNullOrEmpty($CurrentValue) -eq $false) { If ($CurrentValue.Contains($item.Trim())) { $frm_Main.Controls["chkBox$i"].Checked = $true } }
                $i++
            }
            Break
        }

        'OPTION' {
            # Drop down selection list
            $comboBox               = New-Object 'System.Windows.Forms.ComboBox'
            $comboBox.Location      = ' 12,  75'
            $comboBox.Size          = '370,  21'
            $comboBox.Font          = $sysFont
            $comboBox.DropDownStyle = 'DropDownList'
            $frm_Main.Controls.Add($comboBox)
            $comboBox.Items.AddRange(($InputList.Trim())) | Out-Null
            $frm_Main.Add_Shown({$comboBox.Select()})
            If ([string]::IsNullOrEmpty($CurrentValue) -eq $false) { $comboBox.SelectedItem = $CurrentValue[0] } Else { $comboBox.SelectedIndex = -1 }
            Break
        }

        {($_ -eq 'MULTI') -or ($_ -eq 'LARGE')} {
            # Multi-line text entry
            $textBox                = New-Object 'System.Windows.Forms.TextBox'
            $textBox.Location       = ' 12,  75'
            $textBox.Size           = '370, 124'
            $textBox.Font           = $sysFont
            $textBox.Multiline      = $True
            $textBox.ScrollBars     = 'Vertical'
            $frm_Main.Controls.Add($textBox)
            $frm_Main.Add_Shown({$textBox.Select()})
            $textBox.Select()

            # Add KeePass entry button
            $KeePassButton          = New-Object 'System.Windows.Forms.Button'
            $KeePassButton.Location = " 12, $(110 + 104)"    #
            $KeePassButton.Size     = ' 75,   25'
            $KeePassButton.Font     = $sysFont
            $KeePassButton.Text     = 'KeePass'
            $KeePassButton.TabIndex = '99'
            $KeePassButton.Visible  = $EnableKeePass
            $KeePassButton.Add_Click($KeePassButton_Click)
            $frm_Main.Controls.Add($KeePassButton)

            # Resize form
            $frm_Main.Height       += 104                    # 
            $btn_Accept.Location    = "307, $(110 + 104)"    # 104 comes from 4 x 26
            $btn_Cancel.Location    = "220, $(110 + 104)"    #
            Break
        }

        {($_ -eq 'SIMPLE') -or ($_ -eq 'PASSWORD')} {
            # Add default text box
            $textBox                = New-Object 'System.Windows.Forms.TextBox'
            $textBox.Location       = ' 12,  75'
            $textBox.Size           = '370,  20'
            $textBox.Font           = $sysFont
            If ($Type -eq 'PASSWORD') { $textBox.PasswordChar = 'o' }
            $frm_Main.Controls.Add($textBox)
            $textBox.Select()

            # Add KeePass entry button
            $KeePassButton          = New-Object 'System.Windows.Forms.Button'
            $KeePassButton.Location = ' 12, 110'
            $KeePassButton.Size     = ' 75,  25'
            $KeePassButton.Font     = $sysFont
            $KeePassButton.Text     = 'KeePass'
            $KeePassButton.TabIndex = '199'
            $KeePassButton.Visible  = $EnableKeePass
            $KeePassButton.Add_Click($KeePassButton_Click)
            $frm_Main.Controls.Add($KeePassButton)
            Break
        }
        Default { Write-Warning "Invalid Input Form Type: $Type" }
    }

    If (('SIMPLE', 'PASSWORD', 'MULTI', 'LARGE') -contains $Type)
    {
        # ### KEEPASS FIELDS ###
        # Add KeePass Field
        $kp_textBox                = New-Object 'System.Windows.Forms.TextBox'
        $kp_textBox.Location       = ' 69,  75'
        $kp_textBox.Size           = '313,  20'
        $kp_textBox.Font           = $sysFont
        $kp_textBox.Visible        = $False
        $frm_Main.Controls.Add($kp_textBox)
        $kp_textBox.Select()

        # Add KeePass label
        $kp_EntryLabel             = New-Object 'System.Windows.Forms.Label'
        $kp_EntryLabel.Location    = ' 12,  75'
        $kp_EntryLabel.Size        = ' 51,  20'
        $kp_EntryLabel.Font        = $sysFont
        $kp_EntryLabel.Text        = 'Entry :'
        $kp_EntryLabel.TextAlign   = 'MiddleRight'
        $kp_EntryLabel.Visible     = $False
        $frm_Main.Controls.Add($kp_EntryLabel)

        # All KeePass label
        $kp_FieldLabel             = New-Object 'System.Windows.Forms.Label'
        $kp_FieldLabel.Location    = ' 12, 110'
        $kp_FieldLabel.Size        = ' 51,  20'
        $kp_FieldLabel.Font        = $sysFont
        $kp_FieldLabel.Text        = 'Field :'
        $kp_FieldLabel.TextAlign   = 'MiddleRight'
        $kp_FieldLabel.Visible     = $False
        $frm_Main.Controls.Add($kp_FieldLabel)

        # Add KeePass dropdown list
        $kp_comboBox               = New-Object 'System.Windows.Forms.ComboBox'
        $kp_comboBox.Location      = ' 69, 110'
        $kp_comboBox.Size          = '313,  21'
        $kp_comboBox.Font          = $sysFont
        $kp_comboBox.DropDownStyle = 'DropDownList'
        $kp_comboBox.Visible       = $False
        $kp_comboBox.Add_SelectedIndexChanged($kp_comboBox_SelectedIndexChanged)
        $kp_comboBox.Items.Clear()
        $kp_comboBox.Items.AddRange(@('UserName', 'Password', 'URL', 'Notes', '*Custom Field*'))
        $frm_Main.Controls.Add($kp_comboBox)
        $kp_comboBox.SelectedItem = 'UserName'

        # Add KeePass text field
        $kp_CustomField            = New-Object 'System.Windows.Forms.TextBox'
        $kp_CustomField.Location   = ' 69, 137'
        $kp_CustomField.Size       = '313,  20'
        $kp_CustomField.Font       = $sysFont
        $kp_CustomField.Enabled    = $False
        $kp_CustomField.Visible    = $False
        $frm_Main.Controls.Add($kp_CustomField)

        If ([string]::IsNullOrEmpty($CurrentValue) -eq $false)
        {
            If (($CurrentValue[0].StartsWith('UseKeePass|') -eq $True) -and ($EnableKeePass -eq $true))
            {
                Change-Form -ChangeTo 'KeePass' | Out-Null
                $kp_textBox.Text          = (($CurrentValue[0].Split('|')[1]).Trim())
                $kp_comboBox.SelectedItem = '*Custom Field*'                             # Select 'Custom' as the default
                $kp_comboBox.SelectedItem = (($CurrentValue[0].Split('|')[2]).Trim())
                $kp_CustomField.Text      = (($CurrentValue[0].Split('|')[2]).Trim())
            }
            Else
            {
                Change-Form -ChangeTo 'Simple' | Out-Null
                $textBox.Text = (($CurrentValue.Trim()) -join "`r`n")
            }
        }
        Else
        {
            Change-Form -ChangeTo 'Simple' | Out-Null
        }
    }
#endregion
#region Show Form And Return Value
    ForEach ($control In $frm_Main.Controls) { $control.Font = $sysFont; Try { $control.FlatStyle = 'Standard' } Catch {} }
    $result = $frm_Main.ShowDialog($MainForm)

    If ($result -eq [System.Windows.Forms.DialogResult]::OK)
    {
        If (([string]::IsNullOrEmpty($(Get-Variable -Name KeePassButton -ErrorAction SilentlyContinue)) -eq $False) -and ($KeePassButton.Text -eq 'Simple'))
        {
            Return "UseKeePass|$($kp_textBox.Text)|$($kp_CustomField.Text)"
        }
        Else
        {
            Switch ($Type)
            {
                'LIST'   {
                    [string[]]$return = @()
                    ForEach ($control In $frm_Main.Controls) { If ($control -is [System.Windows.Forms.TextBox]) {
                        If ([string]::IsNullOrEmpty($control.Text) -eq $false) { $return += ($($control.Text.Trim())) } }
                    } Return $return
                }
                'CHECK'  {
                    [string[]]$return = @()
                    ForEach ($Control In $frm_Main.Controls) { If ($control -is [System.Windows.Forms.CheckBox]) {
                        If ($control.Checked -eq $true) { $return += ($($control.Text.Trim())) } }
                    } Return $return
                }
                'LARGE'  {
                    Do { [string]$return = $($textBox.Text.Trim()).Replace("`r`n", ' ') }
                    While ( $return.IndexOf("`r`n") -gt -1 ); Return ($return.Trim("`r`n"))
                }
                {($_ -eq 'SIMPLE') -or ($_ -eq 'PASSWORD')} {
                    Do { [string]$return = $($textBox.Text.Trim()).Replace("`r`n", ' ') }
                    While ( $return.IndexOf("`r`n") -gt -1 ); Return ($return.Trim("`r`n"))
                }
                'MULTI'  { Return $($textBox.Text.Trim()) }
                'OPTION' { Return $($comboBox.SelectedItem) }
                Default  { Return "Invalid return type: $Type" }
            }
        }
    }
    ElseIf ($result -eq [System.Windows.Forms.DialogResult]::Cancel) { Return '!!-CANCELLED-!!' }
#endregion
}
