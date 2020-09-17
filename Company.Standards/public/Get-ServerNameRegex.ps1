Function Get-ServerNameRegex {

    Return ('^{0}{1}{2}{3}{4}$' -f `
        (Get-Datacenter      -RegexOnly), `
        (Get-Environment     -RegexOnly), `
        (Get-OperatingSystem -RegexOnly), `
        (Get-ServerRole      -RegexOnly), `
        (Get-NumericId)
    )
}
