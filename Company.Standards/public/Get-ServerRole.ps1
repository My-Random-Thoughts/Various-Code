Function Get-ServerRole {
    Param (
        [switch]$RegexOnly
    )

    $Data = @(
        [pscustomobject]@{ Name = 'APP'; DisplayName = 'Application Server' }
        [pscustomobject]@{ Name = 'BLD'; DisplayName = 'Build Server' }
        [pscustomobject]@{ Name = 'DCS'; DisplayName = 'Domain Controller Server' }
        [pscustomobject]@{ Name = 'DEV'; DisplayName = 'Development Server' }
        [pscustomobject]@{ Name = 'FIL'; DisplayName = 'File Store Server' }
        [pscustomobject]@{ Name = 'SCO'; DisplayName = 'System Center Operations Manager Server' }
        [pscustomobject]@{ Name = 'SQL'; DisplayName = 'SQL Server' }
        [pscustomobject]@{ Name = 'WEB'; DisplayName = 'Web Front Edd Server' }
    )

    If ($RegexOnly.IsPresent) {
        Return "(?<Role>$($Data.Name -join '|'))"
    }

    Return $Data
}
