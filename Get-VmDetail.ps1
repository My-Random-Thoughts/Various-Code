Function __internal_AddMember {
<#
    Internal function - do not call directly
#>

    Param (
        [object[]]$__getVirtualMachine,

        [string]$__outputPath
    )

    [object[]]$__iResults = @()

    ForEach ($eachVM In $__getVirtualMachine) {
        [void](Add-Member -InputObject $eachVM -MemberType 'NoteProperty' -Name 'SortName' -Value $($eachVM.Config.Name))
        $__iResults += $eachVM

        If (-not [string]::IsNullOrEmpty($__outputPath)) {
            $invalidChars = [System.IO.Path]::GetInvalidFileNameChars() -join ''
            $cleanName = ($($eachVM.Config.Name) -replace $('[{0}]' -f [RegEx]::Escape($invalidChars)))
            ($eachVM | ConvertTo-Xml -Depth 5).Save("$__outputPath\$cleanName.xml")
        }
    }

    Return $__iResults
}

Function Get-VmDetail {
<#
    .SYNOPSIS
        Short description

    .DESCRIPTION
        Long description

    .PARAMETER Name
        Specifies one or more VM names

    .PARAMETER Note
        Specifies the regex of VM notes/annotations

    .PARAMETER CustomFilter
        Specifies a custom filter to use for Get-View

    .PARAMETER OutputPath
        Specifies the path to output an XML file containing the Get-View data

    .EXAMPLE
        Get-VmDetail -Name 'SERVER00'
        Returns all VMs that contain the string 'SERVER00'

    .EXAMPLE
        Get-VmDetail -Note 'Demo Server'
        Returns all VMs that have annotations containing the string shown

    .EXAMPLE
        'SERVER001', 'SERVER002', 'SERVER003' | Get-VmDetail
        Returns details for the VMs that contains the strings shown

    .NOTES
        For additional information please see my GitHub wiki page

    .LINK
        https://github.com/My-Random-Thoughts
#>

    [CmdletBinding(DefaultParameterSetName = 'byName')]
    Param (
        [Parameter(Mandatory, ParameterSetName = 'byName', ValueFromPipeline, ValueFromRemainingArguments)]
        [string[]]$Name,

        [Parameter(Mandatory, ParameterSetName = 'byNote')]
        [string]$Note,

        [Parameter(Mandatory, ParameterSetName = 'byCustom', DontShow)]
        [hashtable]$CustomFilter,

        [string]$OutputPath
    )

    Begin {
        If (-not [string]::IsNullOrEmpty($OutputPath)) {
            If (-not (Test-Path -Path $OutputPath)) { Throw 'Output path specified does not exist' }
            $OutputPath = $OutputPath.TrimEnd('\').TrimEnd('/')
        }

        [object[]]$iResults = @()
        $NotFoundTemplate = @{
            SortName = ''
            Config = @{
                Annotation = '* Virtual machine not found *'
                Name = ''
                Hardware = @{
                    NumCPU = 0
                    MemoryMB = 0
                }
            }
            Guest = @{
                GuestState = 'notFound'
            }
        }
    }

    Process {
        $getView = $null
        $getViewParameters = @{
            Verbose  = $false
            ViewType = 'VirtualMachine'
        }

        Write-Verbose -Message 'Searching vCenter...'
        Switch ($PSCmdlet.ParameterSetName) {
            'byNote' {
                $getView = @(Get-View -Filter @{'Config.Annotation' = $Note} @getViewParameters)
                $iResults += (__internal_AddMember -__getVirtualMachine $getView -__outputPath $OutputPath)
            }

            'byCustom' {
                $getView = @(Get-View -Filter $CustomFilter @getViewParameters)
                $iResults += (__internal_AddMember -__getVirtualMachine $getView -__outputPath $OutputPath)
            }

            'byName' {
                ForEach ($vmName In $Name) {
                    $getView = @(Get-View -Filter @{'Config.Name' = $vmName} @getViewParameters)

                    If ($getView) {
                        $iResults += (__internal_AddMember -__getVirtualMachine $getView -__outputPath $OutputPath)
                    }
                    Else {
                        # The ONLY reliable way of cloning an object without linking...
                        $NotFound = ($NotFoundTemplate | ConvertTo-Json -Depth 5 -Compress | ConvertFrom-Json)
                        $NotFound.SortName = $vmName
                        $NotFound.Config.Name = $vmName
                        $iResults += $NotFound
                    }
                }
            }
        }
        Write-Verbose -Message "Search complete.  Items found: $($iResults.Count)"
    }

    End {
        ForEach ($each In ($iResults | Sort-Object -Property SortName)) {
            [string]  $clName   = ''
            [string]  $conState = ''
            [string]  $domain   = ''
            [string]  $vmFolder = ''
            [string]  $vmIdent  = ''
            [string]  $vmTools  = ''
            [object[]]$ipList   = @()
            [object[]]$hwDisk   = @()
            [object[]]$osDisk   = @()
            [object[]]$ctrlList = @()
            [object[]]$scsiList = @()
            [object[]]$tagList  = @()
            [object[]]$vmCustom = @()

            $getVM = $null

            If ($($each.Guest.GuestState) -ne 'notFound') {
                # Using Id as it's more reliable incase more than one VM exists with the same name
                $vmIdent  = "$($each.Summary.Vm.Type)-$($each.Summary.Vm.Value)"
                $vmServer =  $([uri]::New($($each.Client.ServiceUrl)).Host)

                $getVMParameters = @{
                    Server      =  $vmServer
                    Verbose     =  $false
                    ErrorAction = 'SilentlyContinue'
                }

                If ($each.Config.Template -eq $true) {
                    $getVM = (Get-Template -Id $vmIdent @getVMParameters)
                }
                Else {
                    $getVM = (Get-VM -Id $vmIdent @getVMParameters)
                }

                If (-not $getVM) {
                    $getVM = (Get-VM -Name $($each.Config.Name) @getVMParameters)
                }

                # CLUSTER, TAGS, VMTOOLS
                $clName  = $($getVM.VMHost.Parent.Name)
                $tagList = @((Get-TagAssignment -Entity $getVM -Verbose:$false).Tag)    # <--- This takes about 2 seconds
                $vmTools = ('{0}, version:{1} ({2})' -f  $each.Guest.ToolsRunningStatus, $each.Guest.ToolsVersion, $each.Guest.ToolsVersionStatus)
                $vmTools = $vmTools.Replace('guestTools', '')


                # DOMAIN / WORKGORUP
                If ($each.Guest.IpStack.Count -gt 0) {
                    If ($each.Guest.IpStack[0].DnsConfig.DomainName) {
                        $domain = $(($each.Guest.IpStack[0].DnsConfig.DomainName).ToLower())
                    }
                    Else {
                        $domain = 'not set'
                    }
                }
                ElseIf ($each.Guest.HostName) {
                    If ($each.Guest.HostName -eq $each.Config.Name) {
                        $domain = 'workgroup'
                    }
                    Else {
                        $domain = $(($each.Guest.HostName).Replace($each.Config.Name, ''))
                    }
                }
                Else {
                    $domain = 'unknown'
                }


                # FOLDER LOCATION
                [System.Collections.ArrayList]$tmpPath = @()
                $currFolder = (Get-Folder -Id $($getVM.FolderId) -Server $vmServer -Verbose:$false)
                [void]($tmpPath.Add($($currFolder.Name)))
                While ($currFolder) {
                    If ($currFolder.Parent.Type) {
                        $currFolder = (Get-Folder -Id $($currFolder.ParentId) -Server $vmServer -Verbose:$false)
                        [void]($tmpPath.Insert(0, $currFolder.Name))
                    }
                    Else {
                        [void]($tmpPath.Insert(0, $currFolder.Parent.Name))
                        Break
                    }
                }
                $vmFolder = "$(($tmpPath -join '\') -replace '\\vm', '')\"


                # IP ADDRESS
                If ($($each.Guest.Net.Count) -gt 0) {
                    ForEach ($guestNet In @($each.Guest.Net)) {

                        [string]$hardwareType = 'Unknown'
                        $hardwareType = ($each.Config.Hardware.Device.ForEach({
                            If ($_.MacAddress -eq $guestNet.MacAddress) {
                                Return $_.GetType().ToString().Replace('VMware.Vim.Virtual', '')
                            }
                        }))

                        $ipItem = [pscustomobject]@{
                            Network      = $guestNet.Network
                            MacAddress   = $guestNet.MacAddress
                            HardwareType = $hardwareType
                            IpAddress    = @()
                            Connected    = $guestNet.Connected
                        }

                        ForEach ($ipAddress In ($guestNet.IpAddress)) {
                            $ipItem.IpAddress += $ipAddress
                        }

                        $ipList += $ipItem
                    }
                }
                Else {
                    $ipList = $each.Guest.IpAddress
                }


                # VIRTUAL SCSI ADAPTERS
                $scsiController = (Get-ScsiController -VM $getVM -Verbose:$false)
                ForEach ($adpt In $scsiController) {
                    $scsiList += [pscustomobject]@{
                        Name    =      $($adpt.Name)
                        Type    =      $($adpt.ExtensionData.DeviceInfo.Summary)
                        Key     = [int]$($adpt.Key)
                        Sharing =      $($adpt.BusSharingMode)
                    }
                }


                # OTHER CONTROLLERS (Exclude SCSI from above)
                ForEach ($otherCtrlr In @($each.Config.Hardware.Device | Where-Object { ($_.BusNumber -ge 0) -and ($_.Key -notin $($scsiList.Key)) })) {
                    $label   = $($otherCtrlr.DeviceInfo.Label)
                    $summary = $($otherCtrlr.DeviceInfo.Summary)
                    If ($summary -ne $label) { $label += " ($summary)" }

                    $ctrlList += [pscustomobject]@{
                        Name   =      $($label)
                        Key    = [int]$($otherCtrlr.Key)
#                        Device = $($otherCtrlr.Device)    # List of connected devices
                    }
                }


                # VIRTUAL DISKS
                ForEach ($virtualDisk In @($each.Config.Hardware.Device | Where-Object { $_ -is [VMware.Vim.VirtualDisk] })) {
                    $ctrlLabel = ($each.Config.Hardware.Device | Where-Object { $_.Key -eq $($virtualDisk.ControllerKey) }).DeviceInfo.Label
                    $hwDisk += [pscustomobject]@{
                        Name       =  $($virtualDisk.DeviceInfo.Label)
                        SizeGB     =  [single][System.Convert]::ToSingle(($virtualDisk.CapacityInBytes / 1GB).ToString('0.00'))
                        DiskMode   =  $($virtualDisk.Backing.DiskMode)
                        Thin       =  $($virtualDisk.Backing.ThinProvisioned)
                        Controller = "$($ctrlLabel):$($virtualDisk.UnitNumber)"
                        FileName   =  $($virtualDisk.Backing.FileName)
                    }
                }


                # OS REPORTED DISKS / PARTITIONS
                ForEach ($guestDisk In @($each.Guest.Disk | Sort-Object -Property 'DiskPath')) {
                    $osDisk += [pscustomobject]@{
                        Path        = $guestDisk.DiskPath
                        SizeGB      = [single][System.Convert]::ToSingle($guestDisk.Capacity  / 1GB).ToString('0.00')
                        FreeGB      = [single][System.Convert]::ToSingle($guestDisk.FreeSpace / 1GB).ToString('0.00')
                        PercentFree = [single][System.Convert]::ToSingle((100 / $guestDisk.Capacity) * $guestDisk.FreeSpace).ToString('0.00')
                    }
                }


                # CUSTOM ATTRIBUTES
                ForEach ($value In @($each.Value)) {
                    $vmCustom += [pscustomobject]@{
                        Attribute = $($each.AvailableField.Where({$_.Key -eq $($value.Key)}).Name)
                        Value     = $($value.Value)
                    }
                }
            }

            $vmResult = [pscustomobject]@{
                Name            = [string]  $($each.Config.Name).PadRight(20)
                Cluster         = [string]  $($clName)
                ConnectionState = [string]  $($each.Runtime.ConnectionState)    # 0: connected,  1: disconnected, 2: orphaned, 3: inaccessible, 4: invalid
                CustomAttribute = [object[]]$($vmCustom)
                DNSName         = [string]  $($each.Guest.HostName)
                Domain          = [string]  $($domain)
                Folder          = [string]  $($vmFolder)
                GuestDisk       = [object[]]$($osDisk)
                HardDisk        = [object[]]$($hwDisk)
                Id              = [string]  $($vmIdent)
                IpAddress       = [string] "$($each.Guest.IpAddress)".PadRight(15)    # xxx.xxx.xxx.xxx
                MemoryGB        = [single]  $($each.Config.Hardware.MemoryMB / 1KB)
                NetworkAdapter  = [object[]]$($ipList)
                NumCPU          = [int]     $($each.Config.Hardware.NumCPU)
                OperatingSystem = [string]  $($each.Config.GuestFullName)
                OtherController = [object[]]$($ctrlList)
                PowerState      = [string] "$($each.Guest.GuestState)".PadRight(10)    # 'running' or 'notRunning' or 'notFound'
                SCSIAdapter     = [object[]]$($scsiList)
                Tag             = [object[]]$($tagList)
                Version         = [string]  $($each.Config.Version)
                VMwareTools     = [string]  $($vmTools)
                Notes           = [string]  $($each.Config.Annotation -replace '\n', ' ')
            }

            $defaultSet   = @('Name', 'NumCPU', 'MemoryGB', 'Notes')    # Keep to a maximum of 4 properties for a default of table view
            $propertySet  = (New-Object -TypeName 'System.Management.Automation.PSPropertySet'('DefaultDisplayPropertySet', [string[]]$defaultSet))
            $PSMemberInfo = [System.Management.Automation.PSMemberInfo[]]@($propertySet)
            [void](Add-Member -InputObject $vmResult -MemberType 'MemberSet' -Name 'PSStandardMembers' -Value $PSMemberInfo)

            Write-Output $vmResult
        }
    }
}
