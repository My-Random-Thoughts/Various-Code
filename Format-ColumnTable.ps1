Function Format-ColumnTable {
<#
    .SYNOPSIS
        Formats the output as a table.

    .DESCRIPTION
        The Format-ColumnTable cmdlet formats the outout of a command as a table with the selected property shown in columns.  It will only show one property.

    .PARAMETER InputObject
        Specifies the objects to format.  Enter a variable that contains the objects, or type a command or expression that gets the objects.

    .PARAMETER ColumnCount
        Sepcifies the number of columns to wrap the output too.  The default is as many will fit in the current windows width

    .EXAMPLE
        Get-Service | Format-ColumnTable
        Returns the list of services, selects just the Name property and displays them.

    .EXAMPLE
        Format-ColumnTable -InputObject @(Get-Service | Select-Object -ExpandProperty Name) -ColumnCount 3
        As above, but formats the output into three columns.

    .NOTES
        For additional information please see my GitHub wiki page

    .LINK
        https://github.com/My-Random-Thoughts
#>

    Param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [string[]]$InputObject,

        [int]$ColumnCount = -1,

        [Parameter(DontShow)]
        [switch]$Padded
    )

    Begin {
        [string]$padding = ''
        If ($Padded.IsPresent) { $padding = '  ' }
        [int]$width  = ($Host.UI.RawUI.BufferSize.Width)
        [int]$rowCnt = 0
        [int]$colCnt = 0
        [string[]]$allObjects = @()
        [string]  $lineOutput = $padding
    }

    Process {
        If ($MyInvocation.ExpectingInput) {    # Pipeline input, add each object to $allObjects
            $inputItem = $_
            Switch ($true) {
                { $inputItem      -is [string] } { $allObjects += $inputItem     ; Break }
                { $inputItem.Name -is [string] } { $allObjects += $inputItem.Name; Break }
                Default                          { $allObjects += $inputItem     ; Break }
            }
        }
        Else {
            $allObjects = $InputObject    # Non-Pipeline input
        }
    }

    End {
        $allObjects = ($allObjects | Sort-Object)

        [int]$length    = (($allObjects | Measure-Object -Maximum -Property Length).Maximum)
        [int]$numOfCols = ($width / ($length + 5 + ($padding.Length)))

        If ($ColumnCount -gt 0) { $numOfCols = $ColumnCount }
        [int]$numOfRows = [math]::Ceiling(($allObjects.Count) / $numOfCols)
        If ($Padded.IsPresent) { Write-Output '' }

        Do {
            If ($colCnt -eq $numOfCols) {
                Write-Output $lineOutput
                $lineOutput = $padding
                $rowCnt++
                $colCnt = 0 
            }
    
            [int]$index = (($colCnt * $numOfRows) + $rowCnt)
    
            If (($index -lt $allObjects.Count) -and ($rowCnt -lt $numOfRows)) {
                $lineOutput += "$(($allObjects[$index]).PadRight($length))  "
            }
    
            $colCnt++
        } Until (($rowCnt -eq $numOfRows) -and ($colCnt -eq $numOfCols))
        If ($Padded.IsPresent) { Write-Output '' }
    }
}
