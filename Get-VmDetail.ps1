Function __internal_AddMember {
<#
    Internal function - do not call directly
#>

    Param (
        $__getVirtualMachine
    )

    [object[]]$__iResults = @()

    ForEach ($eachVM In $__getVirtualMachine) {
        Write-Verbose -Message "Found: $($eachVM.Config.Name)"
        [void](Add-Member -InputObject $eachVM -MemberType 'NoteProperty' -Name 'SortName' -Value $($eachVM.Config.Name))
        $__iResults += $eachVM
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

    .PARAMETER VIServer
        Specifies one or more vSphere servers to connect to

    .EXAMPLE
        Get-VmDetail -Name 'SERVER00'
        Returns all VMs that contain the string 'SERVER00'

    .EXAMPLE
        Get-VmDetail -Note 'Demo Server' -VIServer viserver001
        Returns all VMs that have annotations containing the string shown

    .EXAMPLE
        'SERVER001', 'SERVER002', 'SERVER003' | Get-VmDetail -VIServer viserver001
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
        [hashtable]$CustomFilter
    )

    Begin {
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

        Switch ($PSCmdlet.ParameterSetName) {
            'byNote' {
                $getView = @(Get-View -Filter @{'Config.Annotation' = $Note} @getViewParameters)
                $iResults += (__internal_AddMember -__getVirtualMachine $getView)
            }

            'byCustom' {
                $getView = @(Get-View -Filter $CustomFilter @getViewParameters)
                $iResults += (__internal_AddMember -__getVirtualMachine $getView)
            }

            'byName' {
                ForEach ($vmName In $Name) {
                    $getView = @(Get-View -Filter @{'Config.Name' = $vmName} @getViewParameters)

                    If ($getView) {
                        $iResults += (__internal_AddMember -__getVirtualMachine $getView)
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
            [object[]]$tagList  = @()
            [object[]]$vmCustom = @()

            If ($($each.Guest.GuestState) -ne 'notFound') {
                # Using Id as it's more reliable incase more than one VM exists with the same name
                $vmIdent  = "$($each.Summary.Vm.Type)-$($each.Summary.Vm.Value)"
                $vmServer = $([uri]::New($($each.Client.ServiceUrl)).Host)
                $getVM    = (Get-VM -Id $vmIdent -Verbose:$false -Server $vmServer)


                # CLUSTER, TAGS, VMTOOLS
                $clName  = $($getVM.VMHost.Parent.Name)
                $tagList = @((Get-TagAssignment -Entity $getVM).Tag)
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
                $currFolder = (Get-Folder -Id $($getVM.FolderId) -Server $vmServer)
                [void]($tmpPath.Add($($currFolder.Name)))
                While ($currFolder) {
                    If ($currFolder.Parent.Type) {
                        $currFolder = (Get-Folder -Id $($currFolder.ParentId) -Server $vmServer)
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
                        $ipItem = [pscustomobject]@{
                            Network    = $guestNet.Network
                            MacAddress = $guestNet.MacAddress
                            IpAddress = @()
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


                # VIRTUAL DISKS
                ForEach ($virtualDisk In @($each.Config.Hardware.Device | Where-Object { $_ -is [VMware.Vim.VirtualDisk] })) {
                    $hwDisk += [pscustomobject]@{
                        Name   = $virtualDisk.DeviceInfo.Label
                        SizeGB = [System.Convert]::ToSingle(($virtualDisk.CapacityInBytes / 1GB).ToString('0.00'))
                    }
                }

                # OS REPORTED DISKS / PARTITIONS
                ForEach ($guestDisk In @($each.Guest.Disk)) {
                    $osDisk += [pscustomobject]@{
                        Path   = $guestDisk.DiskPath
                        SizeGB = [System.Convert]::ToSingle(($guestDisk.Capacity  / 1GB).ToString('0.00'))
                        FreeGB = [System.Convert]::ToSingle(($guestDisk.FreeSpace / 1GB).ToString('0.00'))
                    }
                }


                # CUSTOM ATTRIBUTES
                ForEach ($value In @($each.Value)) {
                    $vmCustom += [pscustomobject]@{
                        Attribute = $($each.AvailableField.Where({$_.Key -eq $($value.Key)}).Name)
                        Value     = $($value.Value)
                    }
                }


                # Check if VM is connected - 0: connected,  1: disconnected, 2: orphaned, 3: inaccessible, 4: invalid
                If ($each.Runtime.ConnectionState -ne 0) {
                    $conState = $($each.Runtime.ConnectionState)
                    $each.Config.Name += " ($conState)"
                }
            }

            $vmResult = [pscustomobject]@{
                Name            = [string] "$($each.Config.Name)".PadRight(20)
                Cluster         = [string]  $($clName)
                ConnectionState = [string]  $($conState)
                CustomAttribute = [object[]]$($vmCustom)
                DNSName         = [string]  $($each.Guest.HostName)
                Domain          = [string]  $($domain)
                Folder          = [string]  $($vmFolder)
                GuestDisk       = [object[]]$($osDisk)
                HardDisk        = [object[]]$($hwDisk)
                Id              = [string]  $($vmIdent)
                IpAddress       = [string] "$($each.Guest.IpAddress)".PadRight(15)
                MemoryGB        = [single]  $($each.Config.Hardware.MemoryMB / 1KB)
                NetworkAdapter  = [object[]]$($ipList)
                NumCPU          = [int]     $($each.Config.Hardware.NumCPU)
                OperatingSystem = [string]  $($each.Config.GuestFullName)
                PowerState      = [string] "$($each.Guest.GuestState)".PadRight(10)
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
