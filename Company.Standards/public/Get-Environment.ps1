Function Get-Environment {
    Param (
        [switch]$RegexOnly
    )

    $Data = @(
        [pscustomobject]@{ Name = 'CT'; DisplayName = 'Client Test' }
        [pscustomobject]@{ Name = 'DR'; DisplayName = 'Disaster Recovery' }
        [pscustomobject]@{ Name = 'DV'; DisplayName = 'Development' }
        [pscustomobject]@{ Name = 'LV'; DisplayName = 'Live' }
        [pscustomobject]@{ Name = 'PP'; DisplayName = 'Pre-Production' }
        [pscustomobject]@{ Name = 'PR'; DisplayName = 'Pre-Production Disaster Recovery' }
    )

    If ($RegexOnly.IsPresent) {
        Return "(?<Environment>$($Data.Name -join '|'))"
    }

    Return $Data
}
