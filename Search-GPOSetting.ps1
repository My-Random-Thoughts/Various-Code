#Requires -Module GroupPolicy

Function Search-GPOSetting {
<#
    .SYNOPSIS
        Searches all GPOs for a specific setting

    .DESCRIPTION
        Search all GPOs in a domain for a specific setting and return its value

    .PARAMETER SearchConfiguration
        Option to search the User, Computer or both group policy configuration settings

    .PARAMETER Extension
        The Group Policy extension type of the setting.  Value is one of the following: Auditing, Dot3Svc, DriveMaps, Files, FolderOptions, FolderRedirection, Folders, IE, ControlPanel/Internet, Lugs, nrpt, PowerOptions, PublicKey, RegionalOptions, Registry, ScheduledTasks, Scripts, Security, Shortcuts, SoftwareInstallation, SoftwareRestriction, SRPV2, StartMenu, WindowsFirewall, WLanSvc.  Not supported values include: ControlPanel/Internet, Windows/Registry.  Wildcard value '*' is supported to search all extensions.

    .PARAMETER Where
        The property of the setting you are searching for.

    .PARAMETER Is
        The name of the setting you are searching for.

    .PARAMETER Return
        The property value to return.  Wildcard value '*' is supported to return the first available property result

    .PARAMETER UseCache
        Load GPO settings from a cache.  The first time this is used it will generate a GPO cache which consists of exported XML files stored in the $env:Temp folder.  The next time this is used it will check this folder for an exported XML and if one exists it will be used.  Search time is reduced by a significant amount, depending on network and disk speeds.

    .PARAMETER DomainName
        The domain to search.  Will search your current domain by default.

    .EXAMPLE
        Search-GPOSetting -SearchConfiguration Computer -Extension Security -Where 'Name' -Is 'LockoutDuration' -Return 'SettingNumber'
        Search all computer settings for security GPO settings for the name LockoutDuration and return the setting number value

    .EXAMPLE
        Search-GPOSetting -SearchConfiguration Computer -Extension Security -Where 'KeyName' -Is 'MACHINE\Software\Microsoft\Windows\CurrentVersion\Policies\System\InactivityTimeoutSecs' -Return 'SettingNumber' -UseCache
        Search all computer settings for the security settings for the registry key name shown and return its settings value

    .EXAMPLE
        Search-GPOSetting -SearchConfiguration Both -Extension Registry -Where 'Name' -Is 'SHA-256' -Return 'State' -UseCache
        Search all configuration settings for the registry settings for the setting SHA-265 and return its state (enabled or disabled)

    .EXAMPLE
        Search-GPOSetting -SearchConfiguration User -Extension Registry -Where 'Name' -Is 'Home page URL' -Return 'Value' -UseCache
        Search all user settings for the registry value 'Home page URL' and return its value

    .EXAMPLE
        Search-GPOSetting -SearchConfiguration Both -Extension * -Where 'Value' -Is 'https://www.consoto.com' -Return 'Name' -UseCache

    .OUTPUTS
        PSCustomObject
        Returns GPO Display Name, Specified Where string, and result stored in specified Return string
        Extra fields are available, including Configuration location (Computer/User) and Extension where the object was found

    .NOTES
        Based off original script at: https://deployhappiness.com/searching-gpos-for-that-specific-setting/
#>

    Param (
        [Parameter(Mandatory=$true)]
        [ValidateSet('Computer', 'User', 'Both')]
        [string]$SearchConfiguration,

        [Parameter(Mandatory=$true)]    # Not sure this is a complete list:
        [ValidateSet('Auditing','Dot3Svc','DriveMaps','Files','FolderOptions','FolderRedirection','Folders','IE','Internet',
                     'Lugs','nrpt','PowerOptions','PublicKey','RegionalOptions','Registry','ScheduledTasks','Scripts','Security',
                     'Shortcuts','SoftwareInstallation','SoftwareRestriction','SRPV2','StartMenu','WindowsFirewall','WLanSvc','*')]
        [string]$Extension,

        [Parameter(Mandatory=$true)]
        [string]$Where,

        [Parameter(Mandatory=$true)]
        [string]$Is,

        [Parameter(Mandatory=$true)]
        [string]$Return,

        [switch]$UseCache,

        [string]$DomainName = [System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain()
    )

    $allGPOsInDomain = (Get-GPO -All -Domain $DomainName)

    Switch ($SearchConfiguration) {
        'Computer' { $QueryString = 'gp:Computer/gp:ExtensionData/gp:Extension' }
        'User'     { $QueryString =     'gp:User/gp:ExtensionData/gp:Extension' }
        Default    { $QueryString =        'gp:*/gp:ExtensionData/gp:Extension' }
    }

    [int]$progressCount = 0
    [string]$folderName = "$env:Temp\GPOSearchCache"

    If (($UseCache.IsPresent) -and (-not (Test-Path -Path $folderName))) {
        Write-Verbose -Message "Cache folder does not exist, creating one at $folderName"
        New-Item -Path $folderName -ItemType Directory -Force | Out-Null
    }

    ForEach ($GPO In ($allGPOsInDomain | Sort-Object -Property DisplayName)) {
        Write-Progress -Activity 'Searching GPOs' -Status "$($GPO.Id): $($GPO.DisplayName)" -PercentComplete ((100 / $allGPOsInDomain.Count) * $progressCount++)

        [string]$fileName = "$folderName\$($GPO.Id).xml"
        If ($UseCache.IsPresent) {
            If (-not (Test-Path -Path $fileName)) {
                Get-GPOReport -Guid $GPO.Id -ReportType xml -Domain $GPO.DomainName | Out-File -FilePath $fileName -Force
            }

            $xmlDoc = New-Object -TypeName 'System.Xml.XmlDocument'
            $xmlDoc.Load($fileName)
        }
        Else {
            $xmlDoc = [xml](Get-GPOReport -Guid $GPO.Id -ReportType xml -Domain $GPO.DomainName)
        }

        $gpSetting       = 'http://www.microsoft.com/GroupPolicy/Settings/'
        $xmlNameSpaceMgr = New-Object System.Xml.XmlNamespaceManager($xmlDoc.NameTable)
        $xmlNameSpaceMgr.AddNamespace('',    'http://www.microsoft.com/GroupPolicy/Settings')
        $xmlNameSpaceMgr.AddNamespace('gp',  'http://www.microsoft.com/GroupPolicy/Settings')
        $xmlNameSpaceMgr.AddNamespace('xsi', 'http://www.w3.org/2001/XMLSchema-instance')
        $xmlNameSpaceMgr.AddNamespace('xsd', 'http://www.w3.org/2001/XMLSchema')

        $extensionNodes = $xmlDoc.DocumentElement.SelectNodes($QueryString, $XmlNameSpaceMgr)

        ForEach ($extensionNode In $extensionNodes) {

            $nodeParams = @{
                Nodes  = $extensionNode.ChildNodes
                Found  = $false
                Where  = $Where
                Is     = $Is
                Return = $Return
                Configuration = $($extensionNode.ParentNode.ParentNode.Name)                
            }

            If ($Extension -eq '*') {
                If (($extensionNode.Attributes.Item(0)).Value -match "$gpSetting.*") {
                    $foundExt = (($extensionNode.Attributes.Item(0)).Value).Replace($gpSetting, '')
                    internalProcessNodes @nodeParams -Extension $foundExt
                }
            }
            Else {
                If ([string]::Compare(($extensionNode.Attributes.Item(0)).Value, "$gpSetting$Extension", $true) -eq 0) {
                    internalProcessNodes @nodeParams -Extension $Extension
                }
            }
        }
    }
}

Function internalProcessNodes {
<#
    .SYNOPSIS
        Internal function only - Not to be called directly

    .DESCRIPTION
        Internal function only - Not to be called directly

    .PARAMETER Nodes
        List of XML nodes to search

    .PARAMETER Found
        Boolean value to specify if the GPO setting has been found or not

    .PARAMETER Where
        The property of the setting you are searching for.

    .PARAMETER Is
        The name of the setting you are searching for.

    .PARAMETER Return
        The property value to return.  Wildcard value '*' is supported to return the first available property result

    .PARAMETER Extension
        The Group Policy extension type of the setting.  Value is one of the following: Auditing, Dot3Svc, DriveMaps, Files, FolderOptions, FolderRedirection, Folders, IE, ControlPanel/Internet, Lugs, nrpt, PowerOptions, PublicKey, RegionalOptions, Registry, ScheduledTasks, Scripts, Security, Shortcuts, SoftwareInstallation, SoftwareRestriction, SRPV2, StartMenu, WindowsFirewall, WLanSvc.  Not supported values include: ControlPanel/Internet, Windows/Registry.  Wildcard value '*' is supported to search all extensions.

    .PARAMETER Configuration
        Option to search the User, Computer or both group policy configuration settings

    .EXAMPLE
        #

    .NOTES
        internalProcessNodes
#>

    Param (
        [object]$Nodes,
        [boolean]$Found,
        [string]$Where,
        [string]$Is,
        [string]$Return,
        [string]$Extension,
        [string]$Configuration
    )

    [string]$property = $Where
    If ($Found) { $property = $Return }

    # Set default object property display
    $defaultSet         = @('GroupPolicy', $Where, $Return)
    $defaultPropertySet = New-Object System.Management.Automation.PSPropertySet('DefaultDisplayPropertySet', [string[]]$defaultSet)
    $PSMemberInfo       = [System.Management.Automation.PSMemberInfo[]]@($defaultPropertySet)

    ForEach ($node in $nodes) {
        $foundValue = $null
        If ($Found -and ($Return -eq '*')) {
            # If looking for more than one value, don't return the $Where value, select the next available property
            $lookingFor = (Get-Member -InputObject $node -MemberType Property | Where-Object -FilterScript { $_.Name -ne $Where } | Select-Object -First 1)
            $Return = $($lookingFor.Name)
        }
        Else {
            $lookingFor = (Get-Member -InputObject $node -Name $property -MemberType Property | Select-Object -First 1)
        }

        If (-not [string]::IsNullOrEmpty($lookingFor)) {
            $foundValue = $node.($lookingFor.Name)
        }
        Else {
            If (-not [string]::IsNullOrEmpty($node.Attributes)) {
                If (-not [string]::IsNullOrEmpty($lookingFor)) {
                    $foundValue = $node.Attributes.GetNamedItem($property)
                }
            }
        }

        If (-not [string]::IsNullOrEmpty($lookingFor)) {
            If (-not $Found) {
                If ([string]::Compare($foundValue, $Is, $true) -eq 0 ) {
                    # Replace $Is with $foundValue for correct letter case of actual setting
                    internalProcessNodes -Nodes $node -Found $true -Where $Where -Is $foundValue -Return $Return -Extension $Extension -Configuration $Configuration
                }
            }
            Else {
                $outputResult = [pscustomobject][ordered]@{
                    GroupPolicy   = $($GPO.DisplayName)
                    Configuration = $Configuration
                    Extension     = $Extension
                    $Where        = $Is
                    $Return       = $foundValue
                }
                $outputResult.PSObject.TypeNames.Insert(0, 'GPOSearch.Output')
                $outputResult | Add-Member -MemberType MemberSet -Name PSStandardMembers -Value $PSMemberInfo
                Return $outputResult
            }
        }

        If (-not [string]::IsNullOrEmpty($node.InnerXml)) {
            internalProcessNodes -Nodes $node.ChildNodes -Found $Found -Where $Where -Is $Is -Return $Return -Extension $Extension -Configuration $Configuration
        }
    }
}
