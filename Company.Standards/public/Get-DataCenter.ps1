Function Get-DataCenter {
    Param (
        [switch]$RegexOnly
    )

    $Data = @(
        [pscustomobject]@{ Name = 'DC1'; DisplayName = 'London';        Address = '123 Any Street, London' }
        [pscustomobject]@{ Name = 'DC2'; DisplayName = 'New York';      Address = '42nd 1st Street, New York' }
        [pscustomobject]@{ Name = 'DC3'; DisplayName = 'Tokyo';         Address = '...' }
        [pscustomobject]@{ Name = 'AZ1'; DisplayName = 'Azure UK East'; Address = 'Cloud Based' }
        [pscustomobject]@{ Name = 'AZ2'; DisplayName = 'Azure UK West'; Address = 'Cloud Based' }
    )

    If ($RegexOnly.IsPresent) {
        Return "(?<Location>$($Data.Name -join '|'))"
    }

    Return $Data
}
