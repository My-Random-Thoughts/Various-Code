Function Get-HostsFile {
<#
    .SYNOPSIS
        Split out the windows HOST file and converts it into a custom object

    .DESCRIPTION
        Split out the windows HOST file and converts it into a custom object

    .PARAMETER InputFile
        Use an alternative file instead of the default

    .EXAMPLE
        Get-HostsFile

    .NOTES
        For additional information please see my GitHub wiki page

    .LINK
        https://github.com/My-Random-Thoughts
#>

    Param (
        $InputFile = "$env:SystemRoot\System32\drivers\etc\hosts"
    )

    ForEach ($line In (Get-Content -Path $InputFile)) {
        If ((-not $line.Trim()) -or ($line.StartsWith('#'))) { Continue }
        [string[]]$entry = ($line.Split(' ').Trim())

        $result = [pscustomobject]@{
            IpAddress = $entry[0].Trim()        
            Hostname  = @()
            Comment   = ''
        }

        # Do not start from 0, this should always be the IP address
        For ($i = 1; $i -lt $entry.Count; $i++) {
            If (-not $entry[$i].Trim()) { Continue }

            If ($entry[$i].Trim() -ne '#') {
                $result.Hostname += $entry[$i].Trim()
            }
            Else {
                $result.Comment = ($entry[$($i + 1)..$($entry.Count - 1)] -join ' ').Trim()
                Break
            }
        }

        Write-Output $result
    }
}
