$ErrorActionPreference = 'Stop'

$selfPid = $PID
$packageName = 'WindowsTerminalDev'
$myTerminalKey = 'HKCU:\Software\MyTerminal'
$startupKey = 'HKCU:\Console\%%Startup'
$fallbackConsole = '{2EACA947-7F5F-4CFA-BA87-8F7FBEEFBE69}'
$fallbackTerminal = '{E12CFF52-A866-4C77-9A90-F570A7AA2C6B}'
$binDir = Join-Path $env:LOCALAPPDATA 'myterminal-bin'
$startMenuDir = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\MyTerminal'
$installRoot = Join-Path $env:LOCALAPPDATA 'Programs\MyTerminal'

function Invoke-ShellRefresh {
    Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class ShellRefresh {
    [DllImport("shell32.dll")]
    public static extern void SHChangeNotify(int eventId, uint flags, IntPtr item1, IntPtr item2);

    [DllImport("user32.dll", SetLastError=true, CharSet=CharSet.Auto)]
    public static extern IntPtr SendMessageTimeout(IntPtr hWnd, int Msg, IntPtr wParam, string lParam, int fuFlags, int uTimeout, out IntPtr lpdwResult);
}
"@
    [ShellRefresh]::SHChangeNotify(0x08000000, 0x0000, [IntPtr]::Zero, [IntPtr]::Zero)
    $result = [IntPtr]::Zero
    [ShellRefresh]::SendMessageTimeout([IntPtr]0xffff, 0x001A, [IntPtr]::Zero, 'Environment', 0x0002, 5000, [ref]$result) | Out-Null
}

function Restart-Explorer {
    $explorerProcesses = Get-Process explorer -ErrorAction SilentlyContinue
    if ($explorerProcesses) {
        Write-Host 'Restarting Explorer to unload the File Explorer context menu...'
        $explorerProcesses | Stop-Process -Force
        Start-Sleep -Seconds 2
    }

    if (-not (Get-Process explorer -ErrorAction SilentlyContinue)) {
        Start-Process explorer.exe
    }
}

Set-Location -Path $env:TEMP

Get-Process WindowsTerminal -ErrorAction SilentlyContinue |
    Where-Object { $_.Path -like '*CascadiaPackage*' -or $_.Path -like '*WindowsTerminalDev*' -or $_.Path -like (Join-Path $installRoot '*') } |
    Stop-Process -Force

$pkg = Get-AppxPackage -Name $packageName
if ($pkg) {
    Remove-AppxPackage -Package $pkg.PackageFullName
}

$previousConsole = $null
$previousTerminal = $null
$backup = Get-ItemProperty -Path $myTerminalKey -ErrorAction SilentlyContinue
if ($backup) {
    $previousConsole = $backup.PreviousDelegationConsole
    $previousTerminal = $backup.PreviousDelegationTerminal
}
if ([string]::IsNullOrWhiteSpace($previousConsole)) { $previousConsole = $fallbackConsole }
if ([string]::IsNullOrWhiteSpace($previousTerminal)) { $previousTerminal = $fallbackTerminal }

New-Item -Path $startupKey -Force | Out-Null
Set-ItemProperty -Path $startupKey -Name DelegationConsole -Value $previousConsole
Set-ItemProperty -Path $startupKey -Name DelegationTerminal -Value $previousTerminal

Remove-Item -Path (Join-Path $binDir 'wt.cmd') -Force -ErrorAction SilentlyContinue

$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
if ($userPath) {
    $normalizedBinDir = [System.IO.Path]::GetFullPath($binDir).TrimEnd('\')
    $parts = $userPath -split ';' | Where-Object {
        if ([string]::IsNullOrWhiteSpace($_)) { return $false }
        try { [System.IO.Path]::GetFullPath($_).TrimEnd('\') -ine $normalizedBinDir } catch { $_ -ine $binDir }
    }
    [Environment]::SetEnvironmentVariable('Path', ($parts -join ';'), 'User')
}

Remove-Item -Path $startMenuDir -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path $myTerminalKey -Recurse -Force -ErrorAction SilentlyContinue

Invoke-ShellRefresh
Restart-Explorer

$cleanupScript = Join-Path $env:TEMP ('myterminal-cleanup-' + [guid]::NewGuid().ToString('N') + '.ps1')
$cleanupBody = @"
`$ErrorActionPreference = 'SilentlyContinue'
Wait-Process -Id $selfPid -Timeout 30
Start-Sleep -Milliseconds 500
Remove-Item -LiteralPath '$startMenuDir' -Recurse -Force
Remove-Item -LiteralPath '$binDir' -Recurse -Force
Remove-Item -LiteralPath '$installRoot' -Recurse -Force
Remove-Item -LiteralPath `$PSCommandPath -Force
"@
[System.IO.File]::WriteAllText($cleanupScript, $cleanupBody, [System.Text.UTF8Encoding]::new($false))

Start-Process -FilePath "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" `
    -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $cleanupScript) `
    -WindowStyle Hidden

Write-Host 'MyTerminal has been uninstalled for the current user. Cleanup will finish after this window closes.'
Start-Sleep -Seconds 2
