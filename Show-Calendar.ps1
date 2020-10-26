Function Show-Calendar {

    [CmdletBinding(DefaultParameterSetName = 'dateTime')]
    Param(
        [Parameter(ParameterSetName = 'dateTime')]
        [datetime]$Start = (Get-Date -Day 1),

        [Parameter(ParameterSetName = 'monthYear', Mandatory)]
        [int]$Month,

        [Parameter(ParameterSetName = 'monthYear')]
        [int]$Year = ((Get-Date).Year),

        [datetime]$HighlightDate,

        [System.Management.Automation.Host.Coordinates]$Position
    )

    Begin {
        # Colour Defaults
        [System.ConsoleColor]$TitleColour     = 'Yellow'    # Month Year
        [System.ConsoleColor]$DayOfWeekColour = 'White'     # Mo Tu We ...
        [System.ConsoleColor]$DateColour      = 'Gray'      # 1 2 3 4 ...
        [System.ConsoleColor]$TodayColour     = 'Green'     # 
        [System.ConsoleColor]$HighlightColour = 'Cyan'      # 


        If ($Position) { $originalCursorPosition = $Host.UI.RawUI.CursorPosition }
        Else           { $Position               = $Host.UI.RawUI.CursorPosition }

        If ($PSCmdlet.ParameterSetName -eq 'monthYear') {
            $Start = (Get-Date -Day 1 -Month $Month -Year $Year)
        }

        If ($Start.Day -ne 1) {
            $Start = $Start.AddDays(-($Start.Day - 1))
        }

        [string]  $gridPadding    = '  '
        $currCulture = [System.Globalization.CultureInfo]::CurrentCulture
        [datetime]$currentDate    = (Get-Date)
        [datetime]$calDay         = $Start
        [string]  $title          = $Start.ToString('MMMM yyyy')
        [string[]]$abbreviated    = (($currCulture.DateTimeFormat.ShortestDayNames) * 2)
        [int]     $firstDayOfWeek = $currCulture.DateTimeFormat.FirstDayOfWeek.value__
        [int]     $max            = $currCulture.DateTimeFormat.Calendar.GetDaysInMonth($start.Year, $start.Month)
        [datetime]$end            = (Get-Date -Year $start.Year -Month $start.Month -Day $max)
        [object[]]$day            = @(@(), @(), @(), @(), @(), @(), @())
        [string]  $dayCounter     = '01234560123456'
        [string]  $dayHead        = ''

        # Pad start of month if required
        While ($calDay.DayOfWeek.value__ -ne $firstDayOfWeek) {
            $calDay = $calDay.AddDays(-1)
        }

        For ($i = 0; $i -lt 7; $i++) {
            $dayHead += $abbreviated[$i + $firstDayOfWeek] + $gridPadding
        }
    }

    Process {
        While ($calDay.Date -le $end.Date) {
            [string]$cDay = $($calDay.Day)
            If (($calDay.Month -lt $start.Month) -or (($calDay.Year -lt $start.Year))) { $cDay = ' ' }
            $day[($calDay.DayOfWeek.value__)] += $cDay
            $calDay = $calDay.AddDays(1)
        }

        $completeMonth = [pscustomobject]@{}
        For ($i = 0; $i -le 6; $i++) {
            Add-Member -InputObject $completeMonth `
                -MemberType NoteProperty `
                -Name   "Day$($dayCounter.Substring($i + $firstDayOfWeek, 1))" `
                -Value $day[$($dayCounter.Substring($i + $firstDayOfWeek, 1))]
        }

        [string[]]$dayOfWeek    = $completeMonth.psObject.Properties.Name
        [int]     $numRows      = (($day | ForEach-Object -Process { ($_ | Measure-Object -Maximum).Count }) | Measure-Object -Maximum).Maximum
        [string]  $titlePadding = ' ' * (((14 + ($gridPadding.Length * 6)) - $title.Length) / 1)    # Change to '2' for centered

        $host.UI.RawUI.CursorPosition = $Position; Write-Host $titlePadding$title -ForegroundColor $TitleColour;     $Position.Y++
        $host.UI.RawUI.CursorPosition = $Position; Write-Host $dayHead            -ForegroundColor $DayOfWeekColour; $Position.Y++

        For ($i = 0; $i -lt $numRows; $i++) {
            $host.UI.RawUI.CursorPosition = $Position
            For ($j = 0; $j -lt $dayOfWeek.Count; $j++ ) {
                [string]$value = ($completeMonth.$($dayOfWeek[$j])[$i])
                $fgColour = $DateColour

                # Is HIGHLIGHT
                If (($HighlightDate.Day   -eq $value      ) -and
                    ($HighlightDate.Month -eq $Start.Month) -and
                    ($HighlightDate.Year  -eq $Start.Year )) { $fgColour = $HighlightColour }

                # Is TODAY
                If (($currentDate.Day   -eq $value      ) -and
                    ($currentDate.Month -eq $Start.Month) -and
                    ($currentDate.Year  -eq $start.Year )) { $fgColour = $TodayColour }

                Write-Host "$($value.PadLeft(2, ' '))$gridPadding" -ForegroundColor $fgColour -NoNewline
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
    $position = $Host.UI.RawUI.CursorPosition
    $position.X = 1
    $position.Y++

    1..12 | ForEach-Object {
        Show-Calendar -Month $_ -Position $position
        $position.X += 32
        If (($_ % 5) -eq 0) { $position.X = 1; $position.Y += 9 }
    }

    If ($position.X -gt 10) { $position.Y += 9 }
    $Host.UI.RawUI.CursorPosition = $position
    Write-Host ''
}
