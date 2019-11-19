#Requires       -Version 4
Set-StrictMode  -Version 2
Remove-Variable -Name * -ErrorAction SilentlyContinue
Clear-Host

[Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms') | Out-Null
[Reflection.Assembly]::LoadWithPartialName('System.Data')          | Out-Null
[Reflection.Assembly]::LoadWithPartialName('System.Drawing')       | Out-Null
[System.Drawing.Font]$sysFont = [System.Drawing.SystemFonts]::MessageBoxFont
[System.Windows.Forms.Application]::EnableVisualStyles()

###################################################################################################
#                                                                                                 #
#  Required Section For Adding Colours To The Tab Control                                         #
#                                                                                                 #
###################################################################################################
[hashtable]$TabCol = @{
    0 = [System.Drawing.Color]::Aqua
    1 = [System.Drawing.Color]::SeaGreen
    2 = [System.Drawing.Color]::CadetBlue
}

Function SetTabHeader {
    Param(
        $Page,
        $Colour
    )

    Write-Host 'SetTabHeader'
    $TabCol[$Page] = $Colour
    $tabControl1.Invalidate()
}

$TabColours_DrawItem = {
    [System.Windows.Forms.DrawItemEventArgs]$e = $_
    [System.Drawing.Brush]$br = New-Object -TypeName 'System.Drawing.SolidBrush' ($TabCol[$e.Index])

    $e.Graphics.FillRectangle($br, $e.Bounds)
    [System.Drawing.SizeF]$sz = $e.Graphics.MeasureString($tabControl1.TabPages[$e.Index].Text, $e.Font)
    $e.Graphics.DrawString($tabControl1.TabPages[$e.Index].Text, $e.Font, [System.Drawing.SystemBrushes]::ControlText, $e.Bounds.Left + ($e.Bounds.Width - $sz.Width) / 2, $e.Bounds.Top + ($e.Bounds.Height - $sz.Height) /2 + 1)

    [System.Drawing.Rectangle]$rect = $e.Bounds
    $rect.Offset(0, 1)
    $rect.Inflate(0, -1)
    $e.Graphics.DrawRectangle([System.Drawing.SystemBrushes]::WindowFrame, $rect)
    $e.DrawFocusRectangle()

    $br.Dispose()
}

###################################################################################################
#                                                                                                 #
#  Display Main GUI Form                                                                          #
#                                                                                                 #
###################################################################################################
Function Display-MainForm
{
#region FORM STARTUP / SHUTDOWN
    $InitialFormWindowState        = New-Object 'System.Windows.Forms.FormWindowState'
    $MainFORM_StateCorrection_Load = { $MainForm.WindowState = $InitialFormWindowState }

    $MainFORM_Load = {
        ForEach ($control In $MainForm.Controls) { $control.Font = $sysFont }
    }

    $Form_Cleanup_FormClosed = {
        $tabControl1.Remove_DrawItem($TabColours_DrawItem)

        $MainFORM.Remove_Load($MainFORM_Load)
        $MainFORM.Remove_Load($MainFORM_StateCorrection_Load)
        $MainFORM.Remove_FormClosing($MainFORM_FormClosing)
    }
#endregion
###################################################################################################
#region FORM Scripts


#endregion
###################################################################################################
#region MAIN FORM
    #
    $MainFORM                           = New-Object 'System.Windows.Forms.Form'
    $MainFORM.AutoScaleDimensions       = '6, 13'
    $MainFORM.AutoScaleMode             = 'None'
    $MainFORM.ClientSize                = '644, 272'
    $MainFORM.FormBorderStyle           = 'FixedSingle'
    $MainFORM.MaximizeBox               = $False
    $MainFORM.MinimizeBox               = $False
    $MainFORM.StartPosition             = 'CenterScreen'
    $MainFORM.Text                      = 'Multi-Coloured Tab Control'
    $MainFORM.Add_Load($MainFORM_Load)
    $MainFORM.Add_Shown($MainFORM_Shown)
    $MainFORM.Add_FormClosing($MainFORM_FormClosing)
    $MainFORM.SuspendLayout()
    #

    # Define Tab Control
    $tabControl1                      = New-Object 'System.Windows.Forms.TabControl'
    # Add OwnerDraw Code
    $tabControl1.DrawMode             = [System.Windows.Forms.TabDrawMode]::OwnerDrawFixed
    $tabControl1.Add_DrawItem($TabColours_DrawItem)
    # Set Tab control properties
    $tabControl1.Location             = ' 12,  12'
    $tabControl1.Size                 = '620, 208'
    $tabControl1.Padding              = ' 12,   6'
    # Add control to the main form
    $MainFORM.Controls.Add($tabControl1)

    # Define Tabpage 1
    $tabPage1 = New-Object 'System.Windows.Forms.TabPage'
    $tabPage1.Text = 'Tab 1'
    $tabPage1.BackColor = [System.Drawing.SystemColors]::Window
    $tabControl1.TabPages.Add($tabPage1)

    # Define Tabpage 2
    $tabPage2 = New-Object 'System.Windows.Forms.TabPage'
    $tabPage2.Text = 'Tab 2'
    $tabPage2.BackColor = [System.Drawing.SystemColors]::Window
    $tabControl1.TabPages.Add($tabPage2)

    # Define Tabpage 3
    $tabPage3 = New-Object 'System.Windows.Forms.TabPage'
    $tabPage3.Text = 'Tab 3'
    $tabPage3.BackColor = [System.Drawing.SystemColors]::Window
    $tabControl1.TabPages.Add($tabPage3)

    #
    $btn_Close                          = New-Object 'System.Windows.Forms.Button'
    $btn_Close.Location                 = '557, 235'
    $btn_Close.Size                     = ' 75,  25'
    $btn_Close.Text                     = 'Close'
    $btn_Close.DialogResult             = [System.Windows.Forms.DialogResult]::Cancel    # Use this instead of a 'Click' event
    $MainFORM.CancelButton              = $btn_Close
    $MainFORM.Controls.Add($btn_Close)
    #
#endregion
###################################################################################################
    $InitialFormWindowState = $MainFORM.WindowState
    $MainFORM.Add_Load($MainFORM_StateCorrection_Load)
    $MainFORM.ShowDialog() | Out-Null
}

Display-MainForm | Out-Null
