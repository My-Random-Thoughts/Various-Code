Function Remove-ObsoleteModule {
    [CmdletBinding(SupportsShouldProcess)]
    Param (
        [Parameter(ParameterSetName = 'byName')]
        [string]$Name,

        [Parameter(ParameterSetName = 'Exclude')]
        [string[]]$Exclude
    )

    Begin {
        [int]$mCnt = 0

        Import-Module -Name 'PackageManagement' -Verbose:$false
        If ([string]::IsNullOrEmpty($Name)) {
            $moduleList = Get-InstalledModule -Verbose:$false
        }
        Else {
            $moduleList = Get-InstalledModule -Verbose:$false -Name $Name
        }
    }

    Process {
        ForEach ($module in $moduleList) {
            If ($moduleList.Count -gt 1) {
                Write-Progress -Activity 'Checking Module Versions...' -Status $($module.Name) -PercentComplete ((100 / $moduleList.Count) * $mCnt++)
            }

            If ($Exclude -contains $($module.Name)) {
                Write-Verbose -Message "Skipping requested module: $($module.Name)"
                Continue
            }

            [object[]]$specificModule = (Get-InstalledModule -Name $($module.name) -AllVersions -Verbose:$false | Sort-Object -Property Version)
            [object]  $latestVersion  = $specificModule[-1]

            Write-Verbose -Message "Found $($specificModule.Count) version(s) for $($module.Name)"

            ForEach ($specific in $specificModule) {
                If ($specific.Version -eq $latestVersion.Version) { Continue }

                If ($PSCmdlet.ShouldProcess($($specific.Name), "Uninstall version '$($specific.version)'")) {
                    Write-Output -InputObject "Uninstalling version '$($specific.version)' of $($specific.Name)"
                    $specific | Uninstall-Module -force
                }
            }
        }
    }

    End {
    }
}
