Function __internalAdd-HTMLCode {
<#
    Internal function used by Send-ToPrinter
    Do not call this function directly
#>

    Param (
        [Parameter(Mandatory)]
        [string]$TokenName,

        [Parameter(Mandatory)]
        [string]$CodeBlock
    )

    Begin {
        $tokenColours = @{
            'NewLine'            = '#000000'
            'Indentation'        = '#000000'
            'LineContinuation'   = '#000000'    # Back-Tick

            # ISE Light Colour Scheme
            'Attribute'          = '#00bfff'
            'Command'            = '#0000ff'
            'CommandArgument'    = '#8a2be2'
            'CommandParameter'   = '#000080'
            'Comment'            = '#00cc00'
            'GroupEnd'           = '#000000'
            'GroupStart'         = '#000000'
            'Keyword'            = '#00008b'
            'LoopLabel'          = '#00008b'
            'Member'             = '#000000'
            'Number'             = '#800080'
            'Operator'           = '#a9a9a9'
            'StatementSeparator' = '#000000'
            'String'             = '#8b0000'
            'Type'               = '#008080'
            'Variable'           = '#ff4500'
        }
    }

    Process {
        $htmlColour = $tokenColours[$TokenName].ToString()

        If (($TokenName -eq 'NewLine') -or ($TokenName -eq 'LineContinuation')) {
            If ($TokenName -eq 'LineContinuation') {
                [void]$codeBuilder.Append("<span style='color:$htmlColour'>``</span>")    # Note the double tick
            }
            [void]$codeBuilder.Append('<br/>')
    	}
        Else {
            $CodeBlock = [System.Web.HttpUtility]::HtmlEncode($CodeBlock)
            $CodeBlock = $CodeBlock.Replace(' ', '&nbsp;')
            [string[]]$multiLines = ($CodeBlock -split "`r`n")

            $span = " style='color:$htmlColour'"
            If ($TokenName -eq 'Indentation') { $span = '' }

            ForEach ($line In $multiLines) {
                [void]$codeBuilder.Append("<span$span>$line</span><br/>")
            }

            [void]$codeBuilder.Remove($codeBuilder.Length - 5, 5)    # Remove final <br/> from multi-line addition
        }
    }

    End {
    }
}

Function __internalConvertTo-HtmlPage {
<#
    Internal function used by Send-ToPrinter
    Do not call this function directly
#>

    Param (
        [parameter(Mandatory)]
        [string]$Code,

        [parameter(Mandatory)]
        [string]$Title
    )

    $header = @"
<!doctype html public `"-//w3c//dtd html 4.0 Transitional//EN`">
<html><head>
    <title>$Title</title>
    <style>
        body, table    { margin:  0px; border:  0px; border-collapse: collapse; font-family: Consolas, Lucida Console; font-size: 10pt; }
        tr:first-child, tr:last-child  { line-height: 5px; }
        td             { padding: 1px 9px 0px 9px; white-space: nowrap; }
        td:first-child { background: #e8e8e8; color: #909090; border-right: 1px solid #909090; text-align: right; }
        td:last-child  { background: #ffffff; }
    </style>
</head>
<body>
    <table>
    <tr><td>&nbsp;</td><td></td></tr>

"@
    $footer = @"

    <tr><td>&nbsp;</td><td></td></tr>
    </table>
</body>
</html>
"@

    $html = New-Object -TypeName 'System.Text.StringBuilder'
    [string[]]$codeSplit = ($Code -split '<br/>')

    [void]$html.AppendLine($header)

    0..($codeSplit.Count) | ForEach-Object -Process {
        [void]$html.AppendLine("<tr><td>$($_ + 1)</td><td>$($codeSplit[$_])</td></tr>")
    }

    [void]$html.AppendLine($footer)
    Return $html
}

Function Send-ToPrinter {
<#
    .SYNOPSIS
        Send the specified script to a printer via a HTML file and browser

    .DESCRIPTION
        Converts the specified script into a colour formatted HTML file with line numbers and displays it in a browser window, where it can be printed.
        Can also be used from within the ISE if added to the Add-Ons menu with the following code:
            $psISE.CurrentPowerShellTab.AddOnsMenu.Submenus.Add('Send To Printer', { Send-ToPrinter }, 'Alt+Shift+P') | Out-Null

        Colours are set to the ISE default theme and can be changed within the __internalAdd-HTMLCode function
        Taken from the original script at: https://unlockpowershell.wordpress.com/2011/12/30/print-from-powershells-integrated-scripting-environment

    .PARAMETER InputFile
        The name of the file to load for printing

    .EXAMPLE
        Send-ToPrinter -InputFile .\Untitled1.ps1

    .NOTES
        For additional information please see my GitHub wiki page

    .LINK
        https://github.com/My-Random-Thoughts
#>

    Param (
        [System.IO.FileInfo]$InputFile
    )

    Begin {
        If ($psISE) {
            $inputText = $psISE.CurrentFile.Editor.Text
        }
        ElseIf ($InputFile) {
            If (-not (Test-Path -Path $InputFile)) { Throw 'Input file not found' }
            $inputText = (Get-Content -Path $InputFile) -join "`r`n"
        }
        Else {
            Throw 'Input file not specified'
        }

        [int]$tokenPosition = 0
        $parseErrors = $null

        $codeBuilder = New-Object -TypeName 'System.Text.StringBuilder'
    }

    Process {
        $parseTokens = [System.Management.Automation.PSParser]::Tokenize($inputText, [ref]$parseErrors)
        If ($parseErrors) { Throw $parseErrors[0] }

        ForEach ($token in $parseTokens) {
            If ($tokenPosition -lt $token.Start) {
                # Add indentation
                $codeBlock = $inputText.Substring($tokenPosition, ($token.Start - $tokenPosition))
                __internalAdd-HTMLCode -TokenName 'Indentation' -CodeBlock $codeBlock
            }

            $codeBlock = $inputText.Substring($token.Start, $token.Length)
            $tokenName = $token.Type.ToString()
            __internalAdd-HTMLCode -TokenName $tokenName -CodeBlock $codeBlock

            $tokenPosition = ($token.Start + $token.Length)
        }

        If ($psISE) { $title = $psISE.CurrentFile.DisplayName } Else { $title = $InputFile.Name }
        $path = "$($env:temp)\$title.toPrinter.html"

        (__internalConvertTo-HtmlPage -Code $($codeBuilder.ToString()) -Title $title).ToString() | Out-File -FilePath $path -Encoding ascii
        Invoke-Item -Path $path
    }

    End {
    }
}
