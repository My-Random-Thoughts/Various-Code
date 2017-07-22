Set-StrictMode    -Version 2
Remove-Variable * -ErrorAction SilentlyContinue
Clear-Host

#
#
# SET THESE VALUE ACCORDINGLY
#
    [string]$Form_Title  = 'ACME PowerShell Tools'
    [string]$Script_Path = 'C:\Scripts'
#
# SET THESE VALUE ACCORDINGLY
#
#

[Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms') | Out-Null
[Reflection.Assembly]::LoadWithPartialName('System.Data')          | Out-Null
[Reflection.Assembly]::LoadWithPartialName('System.Drawing')       | Out-Null
[System.Drawing.Font]$sysFont      = [System.Drawing.SystemFonts]::MessageBoxFont
[System.Drawing.Font]$sysFontTitle = New-Object 'System.Drawing.Font' ($sysFont.Name, 20, [System.Drawing.FontStyle]::Bold)
[System.Windows.Forms.Application]::EnableVisualStyles()
If ($Script_Path.EndsWith('\') -eq $false) { $Script_Path += '\' }

Function Display-MainForm
{
#region FORM STARTUP / SHUTDOWN
    $InitialFormWindowState        = New-Object 'System.Windows.Forms.FormWindowState'
    $MainFORM_StateCorrection_Load = { $MainForm.WindowState = $InitialFormWindowState }

    $MainFORM_Load = {
        ForEach ($control In $MainForm.Controls) { $control.Font = $sysFont }
        $lblTitle.Font = $sysFontTitle

        # Get Script List
        If ((Test-Path -Path $Script_Path) -eq $true)
        {
            [string[]]$scripts = (Get-ChildItem -Path $Script_Path -Filter '*.ps1') | Select-Object -ExpandProperty Name
            ForEach ($script In $scripts)
            {
                [string]$getContent = ((Get-Content -Path "$Script_Path$script" -TotalCount 50) -join "`n")
                        $regExD     = [RegEx]::Match($getContent, "DESCRIPTION:((?:.|\s)+?)(?:(?:[A-Z\- ]+:\n)|(?:#>))")
                [string]$scriptDesc = ($regExD.Groups[1].Value.Trim())

                $btnItem = New-Object 'System.Windows.Forms.Button'
                $btnItem.Size = '150,  50'
                $btnItem.Name = $script
                $btnItem.Text = $script.Replace('.ps1', '')
                $btnItem.Tag  = $scriptDesc
                $btnItem.Add_Click({Button_Click -SourceControl $this})
                $btnItem.Add_MouseHover({Button_Hover -SourceControl $this})
                $floPanel.Controls.Add($btnItem)
             }
        }
    }

    $MainFORM_FormClosing = [System.Windows.Forms.FormClosingEventHandler] {
        $quit = [System.Windows.Forms.MessageBox]::Show($MainFORM, 'Are you sure you want to exit this tool.?', " $Form_Title", 'YesNo', 'Question')
        If ($quit -eq 'No') { $_.Cancel = $True }
    }

    $Form_Cleanup_FormClosed = {
        $MainFORM.Remove_Load($MainFORM_Load)
        $MainFORM.Remove_Load($MainFORM_StateCorrection_Load)
        $MainFORM.Remove_FormClosing($MainFORM_FormClosing)
    }
#endregion
#region FORM Scripts
    Function Button_Hover ( [System.Windows.Forms.Button]$SourceControl )
    {
        $lblStatus.Text = $SourceControl.Tag.ToString()
    }

    Function Button_Click ( [System.Windows.Forms.Button]$SourceControl )
    {
        Start-Process -FilePath PowerShell.exe -ArgumentList ('{0}{1}.ps1' -f $Script_Path, $SourceControl.Text) -Wait
    }
#endregion
#region MAIN FORM
    $MainFORM                           = New-Object 'System.Windows.Forms.Form'
    $MainFORM.AutoScaleDimensions       = '6, 13'
    $MainFORM.AutoScaleMode             = 'None'
    $MainFORM.ClientSize                = '665, 372'    # 671, 400
    $MainFORM.FormBorderStyle           = 'FixedSingle'
    $MainFORM.MaximizeBox               = $False
    $MainFORM.StartPosition             = 'CenterScreen'
    $MainFORM.Text                      = " $Form_Title"
    $MainFORM.Icon                      = [System.Convert]::FromBase64String('
        AAABAAIAICAAAAEAIACoEAAAJgAAABAQAAABACAAaAQAAM4QAAAoAAAAIAAAAEAAAAABACAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
        AADytlEE8rZROPK2UWrytlGK8rZRmvK2UZrytlGJ8rZRaPK2UTbytlEDAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
        AADytlE08rZRnvK2UfDytlH/8rZR//K2Uf/ytlH/8rZR//K2Uf/ytlH/8rZR//K2Ue3ytlGa8rZRMAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
        AADytlEj8rZRs/K2Uf7ytlH/8rZR//K2Uf/ytlH/8rZR//K2Uf/ytlH/8rZR//K2Uf/ytlH/8rZR//K2Uf/ytlH+8rZRrfK2UR8AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
        AAAAAAAA8rZRZPK2UfXytlH/8rZR//K2Uf/ytlH/8rZR//K2Uf/ytlH/8rZR//K2Uf/ytlH/8rZR//K2Uf/ytlH/8rZR//K2Uf/ytlH/8rZR8vK2UVwAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
        AAAAAAAAAAAAAPK2UY3ytlH/8rZR//K2Uf/ytlH/8rZR//K2Uf/ytlH/8rZR//K2Uf/ytlH/8rZR//K2Uf/ytlH/8rZR//K2Uf/ytlH/8rZR//K2Uf/ytlH/8rZR/vK2UYMAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
        AAAAAAAAAAAAAAAAAADytlGM8rZR//K2Uf/ytlH/8rZR//K2Uf/ytlH/8rZR//K2Uf/ytlH/8rZR//K2Uf/ytlH/8rZR//K2Uf/ytlH/8rZR//K2Uf/ytlH/8rZR//K2Uf/ytlH/8rZR//K2UYEAAAAAAAAAAAAA
        AAAAAAAAAAAAAAAAAAAAAAAA8rZRYfK2Uf/ytlH/8rZR//K2Uf/ytlH/8rZR//K2Uf/ytlH/8rZR//K2Uf/ytlH/8rZR//K2Uf/ytlH/8rZR//K2Uf/ytlH/8rZR//K2Uf/ytlH/8rZR//K2Uf/ytlH/8rZR/vK2
        UVYAAAAAAAAAAAAAAAAAAAAAAAAAAPK2USHytlHz8rZR//K2Uf/ytlH/8rZR//K2Uf/ytlH/8rZR//K2Uf/ytlH/8rZR//K2Uf/ytlH/8rZR//K2Uf/ytlH/8rZR//K2Uf/ytlH/8rZR//K2Uf/ytlH/8rZR//K2
        Uf/ytlH/8rZR7/K2URoAAAAAAAAAAAAAAAAAAAAA8rZRrfK2Uf/ytlH/8rZR//K2Uf/ytlH/8rZR//K2Uf/ytlH/8rZR//XKgf/879n/9ch9//K2Uf/ytlH/8rZR//K2Uf/ytlH/8rZR//K2Uf/ytlH/8rZR//K2
        Uf/ytlH/8rZR//K2Uf/ytlH/8rZRowAAAAAAAAAAAAAAAPK2US7ytlH+8rZR//K2Uf/ytlH/8rZR//K2Uf/ytlH/8rZR//K2Uf/ytlH/+eC2///////77dT/8rZR//K2Uf/ytlH/8rZR//K2Uf/ytlH/8rZR//K2
        Uf/ytlH/8rZR//K2Uf/ytlH/8rZR//K2Uf/ytlH88rZRJQAAAAAAAAAA8rZRl/K2Uf/ytlH/8rZR//K2Uf/ytlH/8rZR//K2Uf/ytlH/8rlb//K2Uf/1yX////////7+/v/zv2f/8rZR//K2Uf/ytlH/8rZR//K2
        Uf/yuVv/8rZR//K2Uf/ytlH/8rZR//K2Uf/ytlH/8rZR//K2Uf/ytlGMAAAAAPK2UQLytlHq8rZR//K2Uf/ytlH/8rZR//K2Uf/ytlH/8rZS//rjvf/+/v7/9tGS//K2Uv/99+v///////jZp//ytlH/8rZR//K2
        Uf/ytlH/9cqC//7+/f/76cr/8rdV//K2Uf/ytlH/8rZR//K2Uf/ytlH/8rZR//K2UeEAAAAA8rZRL/K2Uf/ytlH/8rZR//K2Uf/ytlH/8rZR//K2Uv/65L7////////////305b/8rZR//jbq////////fXn//K2
        Uf/ytlH/8rZR//K2Uf/1y4b//v7+///////76sz/8rdV//K2Uf/ytlH/8rZR//K2Uf/ytlH/8rZR//K2USTytlFg8rZR//K2Uf/ytlH/8rZR//K2Uf/ytlL/+uS+////////////+d2v//K2Uf/ytlH/88Br//7+
        /v//////9cd7//K2Uf/ytlH/8rZR//K2Uf/31qD//v7+///////76sz/8rdV//K2Uf/ytlH/8rZR//K2Uf/ytlH/8rZRVfK2UX/ytlH/8rZR//K2Uf/ytlH/8rZS//rkvv////////////ndr//ytlH/8rZR//K2
        Uf/ytlH//PDY///////54rv/8rZR//K2Uf/ytlH/8rZR//K2Uf/31qD//v7+///////76sz/8rdV//K2Uf/ytlH/8rZR//K2Uf/ytlF18rZRjvK2Uf/ytlH/8rZR//K2Uv/65L7////////////53a//8rZR//K2
        Uf/ytlH/8rZR//K2Uf/30pf///////779f/ytlf/8rZR//K2Uf/ytlH/8rZR//K2Uf/31qD//v7+///////76sz/8rdV//K2Uf/ytlH/8rZR//K2UYTytlGN8rZR//K2Uf/ytlH/871i//326v///////vz6//TE
        dP/ytlH/8rZR//K2Uf/ytlH/8rZR//K6XP/+/Pn///////bPj//ytlH/8rZR//K2Uf/ytlH/8rZR//PAav/++/T///////768//0wW3/8rZR//K2Uf/ytlH/8rZRg/K2UXzytlH/8rZR//K2Uf/ytlH/879o//32
        6v///////vrz//TEdP/ytlH/8rZR//K2Uf/ytlH/8rZR//rmxP//////++zQ//K2Uf/ytlH/8rZR//K2Uf/zwGr//fft///////++vP/9MR0//K2Uf/ytlH/8rZR//K2Uf/ytlFx8rZRWvK2Uf/ytlH/8rZR//K2
        Uf/ytlH/879o//326v///////vrz//TEdP/ytlH/8rZR//K2Uf/ytlH/9cqD///////+/v3/871k//K2Uf/ytlH/88Bq//337f///////vrz//TEdP/ytlH/8rZR//K2Uf/ytlH/8rZR//K2UU/ytlEn8rZR//K2
        Uf/ytlH/8rZR//K2Uf/ytlH/879o//326v///////vrz//TDcv/ytlH/8rZR//K2Uf/ytlP//fju///////42KP/8rZR//O/aP/99+3///////768//0xHT/8rZR//K2Uf/ytlH/8rZR//K2Uf/ytlH/8rZRHAAA
        AADytlHh8rZR//K2Uf/ytlH/8rZR//K2Uf/ytlH/879o//326v//////+eG3//K2Uf/ytlH/8rZR//K2Uf/53a////////zz5P/ytlH/+Nml///////++vP/9MR0//K2Uf/ytlH/8rZR//K2Uf/ytlH/8rZR//K2
        UdYAAAAAAAAAAPK2UYnytlH/8rZR//K2Uf/ytlH/8rZR//K2Uf/ytlH/879n//jcrf/zvWf/8rZR//K2Uf/ytlH/8rZR//TCbv////////////TFd//zvGD/+Nys//TDcP/ytlH/8rZR//K2Uf/ytlH/8rZR//K2
        Uf/ytlH/8rZRfwAAAAAAAAAA8rZRIfK2UfvytlH/8rZR//K2Uf/ytlH/8rZR//K2Uf/ytlH/8rZR//K2Uf/ytlH/8rZR//K2Uf/ytlH/8rZR//zw3P//////+eG3//K2Uf/ytlH/8rZR//K2Uf/ytlH/8rZR//K2
        Uf/ytlH/8rZR//K2UffytlEZAAAAAAAAAAAAAAAA8rZRmvK2Uf/ytlH/8rZR//K2Uf/ytlH/8rZR//K2Uf/ytlH/8rZR//K2Uf/ytlH/8rZR//K2Uf/ytlH/99OW///////54br/8rZR//K2Uf/ytlH/8rZR//K2
        Uf/ytlH/8rZR//K2Uf/ytlH/8rZRjwAAAAAAAAAAAAAAAAAAAADytlEU8rZR6fK2Uf/ytlH/8rZR//K2Uf/ytlH/8rZR//K2Uf/ytlH/8rZR//K2Uf/ytlH/8rZR//K2Uf/ytlH/9MFt//K3VP/ytlH/8rZR//K2
        Uf/ytlH/8rZR//K2Uf/ytlH/8rZR//K2UePytlEPAAAAAAAAAAAAAAAAAAAAAAAAAADytlFI8rZR/PK2Uf/ytlH/8rZR//K2Uf/ytlH/8rZR//K2Uf/ytlH/8rZR//K2Uf/ytlH/8rZR//K2Uf/ytlH/8rZR//K2
        Uf/ytlH/8rZR//K2Uf/ytlH/8rZR//K2Uf/ytlH68rZRPwAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAADytlFs8rZR/vK2Uf/ytlH/8rZR//K2Uf/ytlH/8rZR//K2Uf/ytlH/8rZR//K2Uf/ytlH/8rZR//K2
        Uf/ytlH/8rZR//K2Uf/ytlH/8rZR//K2Uf/ytlH/8rZR/fK2UWEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAADytlFq8rZR/PK2Uf/ytlH/8rZR//K2Uf/ytlH/8rZR//K2Uf/ytlH/8rZR//K2
        Uf/ytlH/8rZR//K2Uf/ytlH/8rZR//K2Uf/ytlH/8rZR//K2UfrytlFgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAADytlFE8rZR5fK2Uf/ytlH/8rZR//K2Uf/ytlH/8rZR//K2
        Uf/ytlH/8rZR//K2Uf/ytlH/8rZR//K2Uf/ytlH/8rZR//K2Uf/ytlHh8rZRPQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAADytlEQ8rZRj/K2UffytlH/8rZR//K2
        Uf/ytlH/8rZR//K2Uf/ytlH/8rZR//K2Uf/ytlH/8rZR//K2Uf/ytlH28rZRivK2UQ0AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA8rZRGPK2
        UXvytlHR8rZR/vK2Uf/ytlH/8rZR//K2Uf/ytlH/8rZR//K2Uf7ytlHO8rZRd/K2URUAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
        AAAAAAAAAAAAAAAAAADytlEW8rZRR/K2UWfytlF28rZRdvK2UWbytlFF8rZRFAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAP/gB///gAH//gAAf/wAAD/4AAAf8AAAD+AA
        AAfAAAADwAAAA4AAAAGAAAABAAAAAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAgAAAAYAAAAGAAAABwAAAA8AAAAPgAAAH8AAAD/gAAB/8AAA//gAAf/+AAf//8A//KAAAABAAAAAgAAAAAQAgAAAA
        AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACddjQN6a9OZPK2UajytlHI8rZRyPK2UafrsE5ioXk2DAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAADrsE5f8rZR7PK2Uf/ytlH/8rZR//K2
        Uf/ytlH/8rZR//K2Uerusk9bAAAAAAAAAAAAAAAAAAAAAAAAAADytlGG8rZR//K2Uf/ytlH/8rZR//K2Uf/ytlH/8rZR//K2Uf/ytlH/8rZR/vK2UYEAAAAAAAAAAAAAAADrsE5d8rZR//K2Uf/ytlH/8rZR//K2
        Uf/ytlH/8rZR//K2Uf/ytlH/8rZR//K2Uf/ytlH+7rJPWAAAAACaczML8rZR6vK2Uf/ytlH/8rZR//K2Uf/65sT/9ch8//K2Uf/ytlH/8rZR//K2Uf/ytlH/8rZR//K2UeekezcJ561NYPK2Uf/ytlH/8rZR//TB
        bP/2z4//+d6v//rmw//ytlH/8rZR//bOiv/0w3D/8rZR//K2Uf/ytlH/7LFPW/K2UaPytlH/8rZR//TBbf/9+O7/+Nml//TCbv/+/fn/8rlb//K2Uf/31Z3//vry//TDcv/ytlH/8rZR//K2UZ7ytlHD8rZR//TB
        bf/9+O7/+Nys//K2Uf/ytlH//PDb//fTlv/ytlH/8rZR//jYo//++vL/9MNy//K2Uf/ytlG98rZRwfK2Uf/1yoH//vz4//bOi//ytlH/8rZR//fUmv/87tf/8rZR//K2Uf/1y4X//vz5//bNif/ytlH/8rZRvPK2
        UZ/ytlH/8rZR//XKgv/+/Pf/9syK//K2Uf/yu17//v36//PAav/1y4T//vz3//bOi//ytlH/8rZR//K2UZrmrU1a8rZR//K2Uf/ytlH/9cqC//nesv/ytlH/8rZR//rox//42qr/+Nys//bOiv/ytlH/8rZR//K2
        Uf/rsE5VmXMzCPK2UeTytlH/8rZR//K2Uf/ytlH/8rZR//K2Uf/1y4X//PDc//K2Uf/ytlH/8rZR//K2Uf/ytlHhono2BgAAAADrsE5R8rZR/vK2Uf/ytlH/8rZR//K2Uf/ytlH/8rZR//K5Wf/ytlH/8rZR//K2
        Uf/ytlH97rJPTAAAAAAAAAAAAAAAAPK2UXXytlH+8rZR//K2Uf/ytlH/8rZR//K2Uf/ytlH/8rZR//K2Uf/ytlH98rZRbwAAAAAAAAAAAAAAAAAAAAAAAAAA67BOTvK2UeHytlH/8rZR//K2Uf/ytlH/8rZR//K2
        Uf/ytlHf7bJPSwAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACbdDMG6a9OU/K2UZbytlG38rZRtvK2UZXqsE5RoHg1BQAAAAAAAAAAAAAAAAAAAADwDwAA4AcAAMADAACAAQAAAAAAAAAAAAAAAAAAAAAAAAAA
        AAAAAAAAAAAAAAAAAACAAQAAwAMAAOAHAADwDwAA')
    $MainFORM.Add_Load($MainFORM_Load)
    $MainFORM.Add_MouseHover({$lblStatus.Text = 'Ready.'})
    $MainFORM.Add_FormClosing($MainFORM_FormClosing)
    $MainFORM.SuspendLayout()
    
    $lblTitle                           = New-Object 'System.Windows.Forms.Label'
    $lblTitle.Location                  = ' 12,  12'
    $lblTitle.Size                      = '641,  35'
    $lblTitle.Text                      = $Form_Title
    $lblTitle.TextAlign                 = 'MiddleCenter'
    $lblTitle.Add_MouseHover({$lblStatus.Text = 'Ready.'})
    $MainFORM.Controls.Add($lblTitle)

    $lblStatus                          = New-Object 'System.Windows.Forms.Label'
    $lblStatus.Location                 = ' 12, 343'
    $lblStatus.Size                     = '641,  17'
    $lblStatus.Text                     = 'Ready.'
    $lblStatus.TextAlign                = 'BottomLeft'
    $lblStatus.Add_MouseHover({$lblStatus.Text = 'Ready.'})
    $MainFORM.Controls.Add($lblStatus)

    $floPanel                           = New-Object 'System.Windows.Forms.FlowLayoutPanel'
    $floPanel.Location                  = ' 12,  53'
    $floPanel.Size                      = '641, 284'
    $floPanel.AutoScroll                = $true
    $floPanel.FlowDirection             = 'LeftToRight'
    $floPanel.Add_MouseHover({$lblStatus.Text = 'Ready.'})
    $MainFORM.Controls.Add($floPanel)
#endregion
    $InitialFormWindowState = $MainFORM.WindowState
    $MainFORM.Add_Load($MainFORM_StateCorrection_Load)
    Return $MainFORM.ShowDialog()
}

Display-MainForm | Out-Null
