Function Show-Calendar {
<#
    .SYNOPSIS
        Display a small monthly calendar.

    .DESCRIPTION
        Displays the specified month in calendar view with the current date highlighed.  An optional date can also be highlighed.  The view can also be positioned in the console window.

    .PARAMETER Date
        The month and year to display in DateTime format.  If not specified the current month and year is used.

    .PARAMETER Month
        The month to display, 1 - 12.

    .PARAMETER Year
        The year to display.  Defaults to current year.

    .PARAMETER HighlightDate
        Specifies a particular date to highlight.

    .PARAMETER Position
        Specified the host coordinates to display the calendar.  Does not work with ISE or VSCode.

    .EXAMPLE
        Show-Calendar

    .EXAMPLE
        Show-Calendar -Date (Get-Date -Date '01-2000')

    .EXAMPLE
        Show-Calendar -Month 01 -Year 2000

    .EXAMPLE
        Show-Calendar -Position ([System.Management.Automation.Host.Coordinates]::New(20, 10))

    .NOTES
        For additional information please see my GitHub wiki page
        Based originally on https://github.com/jdhitsolutions/PSCalendar

    .LINK
        https://github.com/My-Random-Thoughts
#>

    [CmdletBinding(DefaultParameterSetName = 'dateTime')]
    Param(
        [Parameter(ParameterSetName = 'dateTime')]
        [datetime]$Date = (Get-Date -Day 1).Date,

        [Parameter(ParameterSetName = 'monthYear', Mandatory)]
        [ValidateRange(1, 12)]
        [int]$Month,

        [Parameter(ParameterSetName = 'monthYear')]
        [int]$Year = ((Get-Date).Year),

        [datetime[]]$HighlightDate,

        [System.Management.Automation.Host.Coordinates]$Position
    )

    Begin {
        # Colour Defaults
        [System.ConsoleColor]$TitleColour     = 'Yellow'    # January 2000
        [System.ConsoleColor]$DayOfWeekColour = 'White'     # Mo Tu We Th Fr Sa Su
        [System.ConsoleColor]$DateColour      = 'Gray'      # 1 2 3 4 ...
        [System.ConsoleColor]$TodayColour     = 'Green'     # 1
        [System.ConsoleColor]$HighlightColour = 'Cyan'      # 1

        If ($PSCmdlet.ParameterSetName -eq 'monthYear') {
            $Date = ((Get-Date -Day 1 -Month $Month -Year $Year).Date)
        }

        # Ensure we starting at the 1st of the month
        If ($Date.Day -ne 1) { $Date = $Date.AddDays(-($Date.Day - 1)) }

        $currCulture = [System.Globalization.CultureInfo]::CurrentCulture
        [datetime]$currentDate    = ((Get-Date).Date)
        [datetime]$calDay         = $Date
        [string]  $title          = $Date.ToString('MMMM yyyy')
        [string[]]$shortDayNames  = (($currCulture.DateTimeFormat.ShortestDayNames) * 2)
        [int]     $firstDayOfWeek = $currCulture.DateTimeFormat.FirstDayOfWeek.value__
        [datetime]$endOfMonth     = (Get-Date -Year $Date.Year -Month $Date.Month -Day $($currCulture.DateTimeFormat.Calendar.GetDaysInMonth($Date.Year, $Date.Month)))
        [object[]]$dayArray       = @(@(), @(), @(), @(), @(), @(), @())
        [string]  $dayCounter     = '01234560123456'
        [string]  $dayHeader      = ''

        For ($i = 0; $i -lt 7; $i++) {
            # Ensure day names are always two characters long
            $dayHeader += ($shortDayNames[$i + $firstDayOfWeek]).Substring(0, 2).PadLeft(2) + '  '
        }

        # Pad start of month if required
        While ($calDay.DayOfWeek.value__ -ne $firstDayOfWeek) {
            $calDay = $calDay.AddDays(-1)
        }

        If ($Position) { $originalCursorPosition = $Host.UI.RawUI.CursorPosition }
        Else           { $Position               = $Host.UI.RawUI.CursorPosition }
    }

    Process {
        While ($calDay.Date -le $endOfMonth.Date) {
            [string]$cDay = $($calDay.Day)
            If (($calDay.Month -lt $Date.Month) -or (($calDay.Year -lt $Date.Year))) { $cDay = ' ' }
            $dayArray[($calDay.DayOfWeek.value__)] += $cDay
            $calDay = $calDay.AddDays(1)
        }

        $completeMonth = [pscustomobject]@{}
        For ($i = 0; $i -le 6; $i++) {
            Add-Member -InputObject $completeMonth `
                -MemberType NoteProperty `
                -Name "Day$($dayCounter.Substring($i + $firstDayOfWeek, 1))" `
                -Value $dayArray[$($dayCounter.Substring($i + $firstDayOfWeek, 1))]
        }

        [string[]]$dayOfWeek    = $completeMonth.psObject.Properties.Name
        [int]     $numRows      = (($dayArray | ForEach-Object -Process { ($_ | Measure-Object -Maximum).Count }) | Measure-Object -Maximum).Maximum
        [string]  $titlePadding = ' ' * (((14 + (2 * 6)) - $title.Length) / 1)    # Change to '2' for centered

        $host.UI.RawUI.CursorPosition = $Position; Write-Host $titlePadding$title -ForegroundColor $TitleColour;     $Position.Y++
        $host.UI.RawUI.CursorPosition = $Position; Write-Host $dayHeader          -ForegroundColor $DayOfWeekColour; $Position.Y++

        For ($i = 0; $i -lt $numRows; $i++) {
            $host.UI.RawUI.CursorPosition = $Position
            For ($j = 0; $j -lt $dayOfWeek.Count; $j++ ) {
                [string]$value = ($completeMonth.$($dayOfWeek[$j])[$i])
                $fgColour = $DateColour

                If ($value.Trim()) {
                    # Is HIGHLIGHT
                    If (($HighlightDate) -contains (Get-Date -Day $value -Month $Date.Month -Year $Date.Year).Date) {
                        $fgColour = $HighlightColour
                    }

                    # Is TODAY
                    If (($currentDate.Day   -eq $value      ) -and
                        ($currentDate.Month -eq $Date.Month) -and
                        ($currentDate.Year  -eq $Date.Year )) { $fgColour = $TodayColour }
                }

                Write-Host "$($value.PadLeft(2, ' '))  " -ForegroundColor $fgColour -NoNewline
            }

            $Position.Y++
            Write-Host ''
        }

        If ($originalCursorPosition) { $host.UI.RawUI.CursorPosition = $originalCursorPosition }
    }

    End {
    }
}

Function Show-FullCalendar {
<#
    .SYNOPSIS
        Displays the full 12 monthly calendar in a grid.

    .DESCRIPTION
        Displays the full 12 monthly calendar in a grid.

    .PARAMETER Columns
        Specifies the number of columns to display.  Default is 4, which will have a display size of 124x26

    .EXAMPLE
        Show-FullCalendar

    .EXAMPLE
        Show-FullCalendar -Columns 2

    .NOTES
        For additional information please see my GitHub wiki page

    .LINK
        https://github.com/My-Random-Thoughts
#>

    Param (
        [int]$Columns = 4
    )

    $position = $Host.UI.RawUI.CursorPosition
    $position.X = 1
    $position.Y++

    1..12 | ForEach-Object {
        Show-Calendar -Month $_ -Position $position
        $position.X += 32
        If (($_ % $Columns) -eq 0) { $position.X = 1; $position.Y += 9 }
    }

    If ($position.X -gt 10) { $position.Y += 9 }
    $Host.UI.RawUI.CursorPosition = $position
}
