Function ConvertTo-ISO8601Duration {
<#
    .SYNOPSIS
        Convert a timespan into a ISO8601 duration

    .DESCRIPTION
        Convert a timespan into a ISO8601 duration

    .PARAMETER Duration
        Object to convert.  Can either be a timespan object or a natural text string.  See examples.

    .PARAMETER MinimumDuration
        Minimum duration validation check

    .PARAMETER MaximumDuration
        Maximum duration validation check

    .EXAMPLE
        ConvertTo-ISO8601Duration -Duration ([timespan]::New(3, 10, 30, 0, 0))
        Returns 'P3DT10H30M'

    .EXAMPLE
        ConvertTo-ISO8601Duration -Duration (New-TimeSpan -Days 2 -Hours 10 -Minutes 30)
        Returns 'P2DT10H30M'

    .EXAMPLE
        ConvertTo-ISO8601Duration -Duration (New-TimeSpan -Start '2020-01-01 13:00' -End '2020-01-02 14:30')
        Returns 'P1DT1H30M'

    .EXAMPLE
        ConvertTo-ISO8601Duration -Duration '2 days, 12 hours, 30 seconds'
        Returns 'P2DT12H30S'

    .EXAMPLE
        ConvertTo-ISO8601Duration -Duration '1 day 2 hours 3 minutes 4 seconds'
        Returns 'P1DT2H3M4S'

    .NOTES
        For additional information please see my GitHub wiki page

    .LINK
        https://github.com/My-Random-Thoughts
#>

    Param (
        [Parameter(Mandatory = $true, ValueFromPipeline)]
        [object]$Duration,

        [timespan]$MinimumDuration = 0,

        [timespan]$MaximumDuration = ([timespan]::MaxValue)
    )

    Begin {
        $timeRegex = '^(?:(?<Days>1 day|(?:[2-9]|[1-9][0-9][0-9]?) days),? ?)?' +
                      '(?:(?<Hours>1 hour|(?:[2-9]|[1-9][0-9][0-9]?) hours),? ?)?' +
                      '(?:(?<Minutes>1 minute|(?:[2-9]|[1-9][0-9][0-9]?) minutes),? ?)?' +
                      '(?:(?<Seconds>1 second|(?:[2-9]|[1-9][0-9][0-9]?) seconds))?$'
    }

    Process {
        If ($Duration -is [string]) {
            If ($Duration -notmatch $timeRegex) { Throw "Invalid duration enered: $Duration" }

            $tsProperties = @{}
            ForEach ($key In $Matches.Keys) {
                If ($key -ne '0') { $tsProperties += @{ $key = ($Matches.$key -split ' ')[0] } }
            }
            $Duration = (New-TimeSpan @tsProperties)
        }

        If ($Duration -isnot [timespan]) {
            Throw "Invalid duration enered: $Duration"
        }

        If (($Duration.TotalMilliseconds -gt $MaximumDuration.TotalMilliseconds) -or ($Duration.TotalMilliseconds -lt $MinimumDuration.TotalMilliseconds)) {
            Throw "Duration '$($Duration.TotalMilliseconds)' was outside the permitted range: $($MinimumDuration.TotalMilliseconds) - $($MaximumDuration.TotalMilliseconds)"
        }

        Return ([System.Xml.XmlConvert]::ToString($Duration))
    }

    End {
    }
}
