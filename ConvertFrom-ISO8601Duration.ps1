Function ConvertFrom-ISO8601Duration {
<#
    .SYNOPSIS
        Convert an ISO8601 duration into a human-readable string

    .DESCRIPTION
        Convert an ISO8601 duration into a human-readable string

    .PARAMETER InputValue
        String ISO8601 value

    .EXAMPLE
        ConvertFrom-ISO8601Duration -InputValue 'P2DT12H30S'
        Returns a time span object

    .EXAMPLE
        ConvertFrom-ISO8601Duration -InputValue 'PT2H3M4S' -AsString
        Returns '2 hours 3 minutes 4 seconds'

    .NOTES
        For additional information please see my GitHub wiki page

    .LINK
        https://github.com/My-Random-Thoughts
#>

    Param (
        [Parameter(Mandatory = $true, ValueFromPipeline)]
        [string]$InputValue,

        [switch]$AsString
    )

    Begin {
        [string]  $return     = ''
        [string[]]$properties = @('days', 'hours', 'minutes', 'seconds')
    }

    Process {
        [timespan]$timeSpan   = ([System.Xml.XmlConvert]::ToTimeSpan($InputValue))

        If (-not $AsString.IsPresent) {
            Return $timeSpan
        }

        ForEach ($prop In $properties) {
            If ($timeSpan.$prop -eq 1) { $return += "$($timeSpan.$prop) $($prop.TrimEnd('s')), " }
            If ($timeSpan.$prop -gt 1) { $return += "$($timeSpan.$prop) $($prop), "              }
        }

        Return $return.TrimEnd(', ')
    }

    End {
    }
}
