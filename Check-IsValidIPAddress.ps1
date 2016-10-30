Function Check-IsValidIPAddress([string]$IPAddress)
{
    [boolean]$Octets = (($IPAddress.Split(".") | Measure-Object).Count -eq 4)
    [boolean]$Valid  =  ($IPAddress -as [ipaddress]) -as [boolean]
    Return  ($Valid -and $Octets)
}

Check-IsValidIPAddress -IPAddress '1.2.3.4'