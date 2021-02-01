Function Get-ResourceString {
    Param (
        [Parameter(Mandatory=$true)]
        [string]$ResourceString
    )

    [string[]]$info = $ResourceString -split ','
    [string]$code = @'
        [DllImport("user32.dll",   CharSet = CharSet.Unicode, EntryPoint = "LoadStringW", CallingConvention = CallingConvention.Winapi)] public static extern int LoadString(IntPtr hModule, int resourceID, StringBuilder resourceValue, int len);
        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, EntryPoint = "LoadLibraryExW")] public static extern IntPtr LoadLibraryEx(string lpFileName, IntPtr hFile, uint dwFlags);
        [DllImport("kernel32.dll")] public static extern int FreeLibrary(IntPtr hModule);
'@

    $helper = (Add-Type -MemberDefinition $code -Name 'ResourceStrings' -Namespace 'Win32API' -PassThru -UsingNamespace 'System.Text')
    $file   = [System.Environment]::ExpandEnvironmentVariables(($info[0] -replace '@',''))
    $id     = [System.Math]::Abs($info[1])

    [System.IntPtr]$hMod = $helper::LoadLibraryEx($file, [IntPtr]::Zero, 3)

    If($hMod -ne [System.IntPtr]::Zero) {
        $sb = New-Object System.Text.StringBuilder(1024)
        If ($helper::LoadString($hMod, $id, $sb, $sb.Capacity) -ne 0) { Return $sb.ToString() }
        [void]$helper::FreeLibrary($hMod);
    }
}
