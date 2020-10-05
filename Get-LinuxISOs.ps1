Remove-Variable -Name * -ErrorAction SilentlyContinue
Clear-Host

$baseUrls  = @(
    @{ Title = 'Ubuntu';    Version = '\d{2}\.\d{2}(\.{\d{1,}})?'; FileName = '*desktop-amd64.iso';   Url = 'http://www.mirrorservice.org/sites/releases.ubuntu.com/' }
    @{ Title = 'Debian';    Version = '\d{2}\.\d{1}\.\d{1}';       FileName = '*-amd64-dvd-1.iso';    Url = 'http://www.mirrorservice.org/sites/cdimage.debian.org/debian-cd/current/amd64/iso-dvd/' }
    @{ Title = 'LinuxMint'; Version = '\d{2}';                     FileName = '*-cinnamon-64bit.iso'; Url = 'http://www.mirrorservice.org/sites/www.linuxmint.com/pub/linuxmint.com/stable/' }
    @{ Title = 'OpenSuse';  Version = '\d{2}\.\d{1}';              FileName = '*-dvd-x86_64.iso';     Url = 'http://www.mirrorservice.org/sites/download.opensuse.org/distribution/openSUSE-stable/iso/' }
)

ForEach ($base In $baseUrls) {
    $verFolder = @{href=''}
    Write-Host "$($base.Title):" -ForegroundColor Cyan -NoNewline
    $releases = (Invoke-WebRequest -UseBasicParsing -Uri $($base.Url))
    $direct   = ($releases.links | Where-Object { $_.href.Trim('/') -like $($base.FileName) })

    If (-not $direct) {
        $verFolder = ($releases.links | Where-Object { $_.href.Trim('/') -match $($base.version) } | Sort-Object -Property 'href' | Select-Object -Last 1)
        $subFolder = (Invoke-WebRequest -UseBasicParsing -Uri "$($base.Url)$($verFolder.href)")
        $direct    = ($subFolder.links | Where-Object { $_.href.Trim('/') -like  $($base.FileName) })
    }

    # $($base.Url)$($verFolder.href)
    Write-Host " $($direct.href)" -ForegroundColor Green
    Invoke-WebRequest -Uri "$($base.Url)$($verFolder.href)$($direct.href)" -OutFile "C:\My Stuff\Media\ISOs\Linux\$($direct.href)"
}

