# Get public and private function definition files.
$public  = @( Get-ChildItem -Path $PSScriptRoot\public\*.ps1  -ErrorAction SilentlyContinue )
$private = @( Get-ChildItem -Path $PSScriptRoot\private\*.ps1 -ErrorAction SilentlyContinue )

# Dot source the files
ForEach ($import in @($public + $private)) {
    Try {
        # Lightweight alternative to dotsourcing a function script
        . ([ScriptBlock]::Create([System.Io.File]::ReadAllText($import)))
    }
    Catch {
        Write-Error -Message "Failed to import function $($import.fullname): $_"
    }
}

Export-ModuleMember -Function $public.Basename
