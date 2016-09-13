<#
.Synopsis
   Manage KeePass database from within PowerShell
.DESCRIPTION
   Using Add, Edit, Get or Remove options, you can manage an exiting KeePass database
.EXAMPLE
   Manage-KeePass -DatabaseLocation [path\to\database.kdbx] -DatabasePassword 'Password' -Title 'Server01' -Action Add -Group 'File Servers' -Username 'Administrator' -Password 'Passw0rd!'
   Add a new entry to an existing database
.EXAMPLE
   Manage-KeePass -DatabaseLocation [path\to\database.kdbx] -DatabasePassword 'Password' -Title 'Server01' -Action Edit -Username 'Administrator' -NewUsername 'Admin1'
   Edit an existing entry to change the stored username
.EXAMPLE
   Manage-KeePass -DatabaseLocation [path\to\database.kdbx] -DatabasePassword 'Password' -Title 'Server01' -Action Edit -Password 'Passw0rd!' -NewPassword 'MySecurePassw0rd'
   Edit an existing entry to change the stored password
.EXAMPLE
   Manage-KeePass -DatabaseLocation [path\to\database.kdbx] -DatabasePassword 'Password' -Title 'Server01' -Action Get
   Return the stored username and password for an existing entry
.EXAMPLE
   Manage-KeePass -DatabaseLocation [path\to\database.kdbx] -DatabasePassword 'Password' -Title 'Server01' -Action Remove -Username 'Admin1' -Password 'MySecurePassw0rd'
   Delete an existing entry from the database
#>

Function Manage-KeePass
{
    Param(
        [Parameter(Mandatory=$false)]                                         [string]$DatabaseLocation,
        [Parameter(Mandatory=$false)]                                         [string]$DatabasePassword,
        [Parameter(Mandatory=$true)]                                          [string]$Title,
        [Parameter(Mandatory=$true)][ValidateSet('Add','Edit','Get','Remove')][string]$Action
    )

    # 
    # KeePass Scripting Documentation
    #     http://keepass.info/help/v2_dev/scr_sc_index.html
    # 

    DynamicParam {
        $Dictionary = New-Object -TypeName System.Management.Automation.RuntimeDefinedParameterDictionary

        If ($Action -eq 'Add')
        {
            # Folder
            $ParamAttr = New-Object -TypeName System.Management.Automation.ParameterAttribute; $ParamAttr.Mandatory = $True
            $AttributeCollection = New-Object 'Collections.ObjectModel.Collection[System.Attribute]'
            $AttributeCollection.Add($ParamAttr)
            $Parameter  = New-Object -TypeName System.Management.Automation.RuntimeDefinedParameter -ArgumentList @('Group', [string], $AttributeCollection)
            $Dictionary.Add('Group', $Parameter)
        }
        If (($Action -eq 'Add') -or ($Action -eq 'Remove')) {
            # Username
            $ParamAttr = New-Object -TypeName System.Management.Automation.ParameterAttribute; $ParamAttr.Mandatory = $True
            $AttributeCollection = New-Object 'Collections.ObjectModel.Collection[System.Attribute]'
            $AttributeCollection.Add($ParamAttr)
            $Parameter  = New-Object -TypeName System.Management.Automation.RuntimeDefinedParameter -ArgumentList @('Username', [string], $AttributeCollection)
            $Dictionary.Add('Username', $Parameter)
            # Password
            $ParamAttr = New-Object -TypeName System.Management.Automation.ParameterAttribute; $ParamAttr.Mandatory = $True
            $AttributeCollection = New-Object 'Collections.ObjectModel.Collection[System.Attribute]'
            $AttributeCollection.Add($ParamAttr)
            $Parameter  = New-Object -TypeName System.Management.Automation.RuntimeDefinedParameter -ArgumentList @('Password', [string], $AttributeCollection)
            $Dictionary.Add('Password', $Parameter)
        }
        If (($Action -eq 'Get') -or ($Action -eq 'Edit'))
        {
            # Username
            $ParamAttr = New-Object -TypeName System.Management.Automation.ParameterAttribute; $ParamAttr.Mandatory = $True; $ParamAttr.ParameterSetName = 'UN'
            $AttributeCollection = New-Object 'Collections.ObjectModel.Collection[System.Attribute]'
            $AttributeCollection.Add($ParamAttr)
            $Parameter  = New-Object -TypeName System.Management.Automation.RuntimeDefinedParameter -ArgumentList @('Username', [string], $AttributeCollection)
            $Dictionary.Add('Username', $Parameter)
            # Password
            $ParamAttr = New-Object -TypeName System.Management.Automation.ParameterAttribute; $ParamAttr.Mandatory = $True; $ParamAttr.ParameterSetName = 'PW'
            $AttributeCollection = New-Object 'Collections.ObjectModel.Collection[System.Attribute]'
            $AttributeCollection.Add($ParamAttr)
            $Parameter  = New-Object -TypeName System.Management.Automation.RuntimeDefinedParameter -ArgumentList @('Password', [string], $AttributeCollection)
            $Dictionary.Add('Password', $Parameter)
        }

        If ($Action -eq 'Edit')
        {
            # NewUsername
            $ParamAttr = New-Object -TypeName System.Management.Automation.ParameterAttribute; $ParamAttr.Mandatory = $True; $ParamAttr.ParameterSetName = 'UN'
            $AttributeCollection = New-Object 'Collections.ObjectModel.Collection[System.Attribute]'
            $AttributeCollection.Add($ParamAttr)
            $Parameter  = New-Object -TypeName System.Management.Automation.RuntimeDefinedParameter -ArgumentList @('NewUsername', [string], $AttributeCollection)
            $Dictionary.Add('NewUsername', $Parameter)
            # NewPassword
            $ParamAttr = New-Object -TypeName System.Management.Automation.ParameterAttribute; $ParamAttr.Mandatory = $True; $ParamAttr.ParameterSetName = 'PW'
            $AttributeCollection = New-Object 'Collections.ObjectModel.Collection[System.Attribute]'
            $AttributeCollection.Add($ParamAttr)
            $Parameter  = New-Object -TypeName System.Management.Automation.RuntimeDefinedParameter -ArgumentList @('NewPassword', [string], $AttributeCollection)
            $Dictionary.Add('NewPassword', $Parameter)
        }

        Return $Dictionary
    }

    Begin {
        Try
        {
            [Reflection.Assembly]::LoadWithPartialName("System.Web") | Out-Null 
            [string]$kpScript = 'C:\Program Files (x86)\KeePass Password Safe 2'
            [string]$kpPassed = 'OK: Operation completed successfully.'
            [string]$returnResult = ''
            If ((Test-Path -Path "$kpScript\KPScript.exe") -eq $false) { Throw 'KeePass Scripting Engine Not Found' }
        }
        Catch
        {
            Write-Host $_.Exception.Message -ForegroundColor Red
            $Host.SetShouldExit(1)
            Exit
        }
    }

    Process {

        Function GenerateUserName { Return ('User-' + ([guid]::NewGuid().Guid).Split('-')[0]) }
        Function GeneratePassword { Return [System.Web.Security.Membership]::GeneratePassword(32, 8) }

        # #############################################################################################

        Function Add-KeePassEntry
        {
            Param
            (
                [parameter(Mandatory=$true )][string]$Title,
                [parameter(Mandatory=$true )][string]$Group,
                [parameter(Mandatory=$false)][string]$UserName,
                [parameter(Mandatory=$false)][string]$Password
            )

            If ($UserName -eq 'RANDOM') { $UserName = (GenerateUserName) }
            If ($Password -eq 'RANDOM') { $Password = (GeneratePassword) }

            [string]$exists = Get-KeePassEntry -Title $Title -FieldName Title -DoesEntryExist $true
            If ($exists -eq $kpPassed) { Return 'This entry already exists' }

            [string]  $Command = "&'$kpScript\KPScript.exe' -c:AddEntry ```"$DatabaseLocation```" -pw:```"$DatabasePassword```" -Title:```"$Title```" -GroupName:```"$Group```" -UserName:```"$UserName```" -Password:`'$Password`'  "
            [string[]]$result  = Invoke-Expression -Command $Command

            If ($result[0] -ne $kpPassed) { Return $result } Else { Return 0 }
        }

        Function Edit-KeePassEntry
        {
            Param
            (
                [parameter(Mandatory=$true)                            ][string]$Title,
                [parameter(Mandatory=$true,ParameterSetName="UserName")][string]$NewUserName,
                [parameter(Mandatory=$true,ParameterSetName="Password")][string]$NewPassword
            )

            If ([string]::IsNullOrEmpty($NewUserName) -eq $true)
            {
                # Change PASSWORD
                [string]$exists = Get-KeePassEntry -Title $Title -FieldName UserName -DoesEntryExist $true
                If ($exists -eq $kpPassed)
                {
                    If ($NewPassword -eq 'RANDOM') { $NewPassword = (GeneratePassword) }
                    [string]$Command = "&'$kpScript\KPScript.exe' -c:EditEntry ```"$DatabaseLocation```" -pw:```"$DatabasePassword```" -ref-Title:```"$Title```" -set-Password:```'$newPassword```'  "
                } Else { Return $exists }
            }
            Else
            {
                # Change USERNAME
                [string]$exists = Get-KeePassEntry -Title $Title -FieldName UserName -DoesEntryExist $true
                If ($exists -eq $kpPassed)
                {
                    If ($NewUserName -eq 'RANDOM') { $NewUserName = (GenerateUserName) }
                    [string]$Command = "&'$kpScript\KPScript.exe' -c:EditEntry ```"$DatabaseLocation```" -pw:```"$DatabasePassword```" -ref-Title:```"$Title```" -set-UserName:```"$newUserName```"  "
                } Else { Return $exists }
            }

            [string[]]$result = Invoke-Expression -Command $command
            If ($result[0] -ne $kpPassed) { Return $result } Else {  Return 0 }
        }

        Function Get-KeePassEntry
        {
            Param
            (
                [parameter(Mandatory=$true )][string] $Title,
                [parameter(Mandatory=$true )][string] $FieldName,
                [parameter(Mandatory=$false)][boolean]$DoesEntryExist
            )

            [string[]]$result2 = $null
            [string]  $Command = "&'$kpScript\KPScript.exe' -c:GetEntryString ```"$DatabaseLocation```" -pw:```"$DatabasePassword```" -ref-Title:```"$Title```" -Field:```"$FieldName```" -FailIfNotExists -FailIfNoEntry"
            [string[]]$result  = Invoke-Expression -Command $Command

            If (($result[0].StartsWith('E: ')) -eq $true) { Return $result }

            If ($DoesEntryExist -eq $true) { Return $result[-1] }
            $result | ForEach { If ($_ -ne $kpPassed) { $result2 += $_ } }
            Return $result2
        }

        Function Remove-KeePassEntry
        {
            Param
            (
                [parameter(Mandatory=$true)][string]$Title,
                [parameter(Mandatory=$true)][string]$UserName,
                [parameter(Mandatory=$true)][string]$Password
            )

            [string]$exists = Get-KeePassEntry -Title $Title -FieldName UserName -DoesEntryExist $true
            If ($exists -eq $kpPassed)
            {
                If (((Get-KeePassEntry -Title $Title -FieldName UserName) -eq $UserName) -and ((Get-KeePassEntry -Title $Title -FieldName Password) -eq $Password))
                {
                    [string]  $Command = "&'$kpScript\KPScript.exe' -c:DeleteEntry ```"$DatabaseLocation```" -pw:```"$DatabasePassword```" -ref-Title:```"$Title```" -ref-UserName:```"$UserName```" -ref-Password:`'$Password`'  "
                    [string[]]$result  = Invoke-Expression -Command $Command
                    If ($result[0] -ne $kpPassed) { Return $result } Else {  Return 0 }
                }
                Else { Return 'Not Found' }
            }
            Else { Return 'Not Found' }
        }

        # #############################################################################################

        Switch ($Action)
        {
            'Add'    {
                Add-KeePassEntry -Title ($Title) -Group ($PSBoundParameters.Group) -UserName ($PSBoundParameters.Username) -Password ($PSBoundParameters.Password)
                Break
            }

            'Edit'   {
                If     ([string]::IsNullOrEmpty($PSBoundParameters.Username) -eq $false) { Edit-KeePassEntry -Title ($Title) -NewUserName ($PSBoundParameters.NewUsername) }
                ElseIf ([string]::IsNullOrEmpty($PSBoundParameters.Password) -eq $false) { Edit-KeePassEntry -Title ($Title) -NewPassword ($PSBoundParameters.NewPassword) }
                Else                                                                     { Return  'Invalid Edit Details'                                                  }
                Break
            }

            'Get' {
                Get-KeePassEntry -Title ($Title) -FieldName 'UserName'
                Get-KeePassEntry -Title ($Title) -FieldName 'Password'
            }

            'Remove' {
                Remove-KeePassEntry -Title ($Title) -UserName ($PSBoundParameters.UserName) -Password ($PSBoundParameters.Password)
                Break
            }

            Default {
                Return 'Invalid Action specified'
            }
        }
    }
}