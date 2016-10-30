# $ComponentBasedServicing = (Get-ChildItem    'HKLM:SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\').Name.Split("\") -contains "RebootPending"
# $WindowsUpdate           = (Get-ChildItem    'HKLM:SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\').Name.Split("\") -contains "RebootRequired"
# $PendingFileRename       = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\').PendingFileRenameOperations.Length -gt 0
# $ActiveComputerName      = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\ComputerName\ActiveComputerName').ComputerName
# $PendingComputerName     = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\ComputerName\ComputerName').ComputerName
# $PendingComputerRename   = ($ActiveComputerName -ne $PendingComputerName)

Function Check-RebootPending
{
    Param ([string]$ComputerName)
    Try {
        [boolean]$rebootRequired = $false
        $reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $ComputerName)

        Try {
        # Check for CBS reboots...
            $regKey = $reg.OpenSubKey('SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing')
            If ($regKey) { ForEach ($regVal In $regKey) { If ($regVal -contains 'RebootPending') { $rebootRequired = $true } } }
            Try { $regKey.Close() } Catch { }
        } Catch { }

        Try {
        # Check for Windows update reboots...
            $regKey = $reg.OpenSubKey('SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update')
            If ($regKey) { ForEach ($regVal In $regKey) { If ($regVal -contains 'RebootRequired') { $rebootRequired = $true } } }
            Try { $regKey.Close() } Catch { }
        } Catch { }

        Try {
        # Check for session manager updates...
            $regKey = $reg.OpenSubKey('SYSTEM\CurrentControlSet\Control\Session Manager')
            If ($regKey.GetValue('PendingFileRenameOperations') -ne $null)
            {
                ForEach ($item In $regKey.GetValue('PendingFileRenameOperations'))
                # Ignore any VMware drag and drop entries
                { If (($item -ne '') -and ($item -notlike '*VMwareDnD*')) { $rebootRequired = $true; Break } }
            }
            Try { $regKey.Close() } Catch { }
        } Catch { }

        Try {
        # Check for computer rename updates...
            $regKey1 = $reg.OpenSubKey('SYSTEM\CurrentControlSet\Control\ComputerName\ComputerName\')
            $regKey2 = $reg.OpenSubKey('SYSTEM\CurrentControlSet\Control\ComputerName\ActiveComputerName\')
            If ($regKey1.GetValue('ComputerName') -ne $regKey2.GetValue('ComputerName')) { $rebootRequired = $true }
            Try { $regKey1.Close(); $regKey2.Close() } Catch { }
        } Catch { }

        $reg.Close()
    } Catch { }
    Return $rebootRequired
}

Write-Host 'Reboot Pending:' (Check-RebootPending -ComputerName $ComputerName)