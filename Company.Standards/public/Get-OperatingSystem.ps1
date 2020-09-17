Function Get-OperatingSystem {
<#

#>

    Param (
        [switch]$RegexOnly
    )

    $Data = @(
        [pscustomobject]@{ Name = 'APL'; DisplayName = 'Appliance' }
        [pscustomobject]@{ Name = 'DOS'; DisplayName = 'MS-DOS'    }
        [pscustomobject]@{ Name = 'LNX'; DisplayName = 'Linux'     }
        [pscustomobject]@{ Name = 'NET'; DisplayName = 'NetApp'    }
        [pscustomobject]@{ Name = 'WIN'; DisplayName = 'Windows'   }
    )

    If ($RegexOnly.IsPresent) {
        Return "(?<OS>$($Data.Name -join '|'))"
    }

    Return $Data
}
