$ErrorActionPreference = 'Stop'

$packageName = 'WindowsTerminalDev'
$myTerminalKey = 'HKCU:\Software\MyTerminal'
$installRoot = Join-Path $env:LOCALAPPDATA 'Programs\MyTerminal'
$appxSource = Join-Path $PSScriptRoot 'AppX'
$appxTarget = Join-Path $installRoot 'AppX'
$binDir = Join-Path $env:LOCALAPPDATA 'myterminal-bin'
$wtCmd = Join-Path $binDir 'wt.cmd'
$startMenuDir = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\MyTerminal'
$uninstallScript = Join-Path $installRoot 'uninstall-user.ps1'

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
        Write-Host 'Restarting Explorer to load the File Explorer context menu...'
        $explorerProcesses | Stop-Process -Force
        Start-Sleep -Seconds 2
    }

    if (-not (Get-Process explorer -ErrorAction SilentlyContinue)) {
        Start-Process explorer.exe
    }
}

if (-not (Test-Path (Join-Path $appxSource 'AppxManifest.xml'))) {
    throw "AppXManifest was not found under $appxSource"
}

New-Item -Path $myTerminalKey -Force | Out-Null

$startupKey = 'HKCU:\Console\%%Startup'
New-Item -Path $startupKey -Force | Out-Null
$currentStartup = Get-ItemProperty -Path $startupKey -ErrorAction SilentlyContinue
if ($currentStartup) {
    if ($currentStartup.DelegationConsole) {
        Set-ItemProperty -Path $myTerminalKey -Name PreviousDelegationConsole -Value $currentStartup.DelegationConsole
    }
    if ($currentStartup.DelegationTerminal) {
        Set-ItemProperty -Path $myTerminalKey -Name PreviousDelegationTerminal -Value $currentStartup.DelegationTerminal
    }
}

Get-Process WindowsTerminal -ErrorAction SilentlyContinue |
    Where-Object { $_.Path -like '*CascadiaPackage*' -or $_.Path -like '*WindowsTerminalDev*' -or $_.Path -like (Join-Path $installRoot '*') } |
    Stop-Process -Force

$oldPackage = Get-AppxPackage -Name $packageName
if ($oldPackage) {
    Remove-AppxPackage -Package $oldPackage.PackageFullName
}

New-Item -ItemType Directory -Path $installRoot -Force | Out-Null
Remove-Item -LiteralPath $appxTarget -Recurse -Force -ErrorAction SilentlyContinue
Copy-Item -Path $appxSource -Destination $appxTarget -Recurse -Force

Add-AppxPackage `
    -Path (Join-Path $appxTarget 'AppxManifest.xml') `
    -Register `
    -ForceUpdateFromAnyVersion `
    -ForceApplicationShutdown

$installedPackage = Get-AppxPackage -Name $packageName
if (-not $installedPackage) {
    throw "$packageName was not registered."
}

$installedManifest = Join-Path $installedPackage.InstallLocation 'AppxManifest.xml'
$installedManifestText = [System.IO.File]::ReadAllText($installedManifest, [System.Text.Encoding]::UTF8)
if ($installedManifestText -notmatch 'windows\.fileExplorerContextMenus' -or
    $installedManifestText -notmatch 'OpenTerminalDev') {
    throw "$packageName was registered, but the File Explorer context menu extension is missing from the registered manifest."
}

if (-not (Test-Path (Join-Path $installedPackage.InstallLocation 'WindowsTerminalShellExt.dll'))) {
    throw "$packageName was registered, but WindowsTerminalShellExt.dll is missing."
}

Set-ItemProperty -Path $startupKey -Name DelegationConsole -Value '{1F9F2BF5-5BC3-4F17-B0E6-912413F1F451}'
Set-ItemProperty -Path $startupKey -Name DelegationTerminal -Value '{051F34EE-C1FD-4B19-AF75-9BA54648434C}'

New-Item -ItemType Directory -Path $binDir -Force | Out-Null
[System.IO.File]::WriteAllText(
    $wtCmd,
    "@echo off`r`nwtd.exe %*`r`n",
    [System.Text.UTF8Encoding]::new($false))

$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
$pathParts = @()
if (-not [string]::IsNullOrWhiteSpace($userPath)) {
    $pathParts = $userPath -split ';' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
}
$normalizedBinDir = [System.IO.Path]::GetFullPath($binDir).TrimEnd('\')
$filteredPathParts = $pathParts | Where-Object {
    try { [System.IO.Path]::GetFullPath($_).TrimEnd('\') -ine $normalizedBinDir } catch { $_ -ine $binDir }
}
[Environment]::SetEnvironmentVariable('Path', (@($binDir) + $filteredPathParts -join ';'), 'User')

Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'uninstall-user.ps1') -Destination $uninstallScript -Force

Remove-Item -LiteralPath $startMenuDir -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path $startMenuDir -Force | Out-Null

$shell = New-Object -ComObject WScript.Shell
$wtdPath = Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps\wtd.exe'
$iconPath = Join-Path $appxTarget 'WindowsTerminal.exe'

$launcher = $shell.CreateShortcut((Join-Path $startMenuDir 'Terminal Dev.lnk'))
$launcher.TargetPath = $wtdPath
$launcher.WorkingDirectory = $env:USERPROFILE
if (Test-Path $iconPath) { $launcher.IconLocation = "$iconPath,0" }
$launcher.Description = 'Launch Terminal Dev'
$launcher.Save()

$uninstaller = $shell.CreateShortcut((Join-Path $startMenuDir 'Uninstall MyTerminal.lnk'))
$uninstaller.TargetPath = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
$uninstaller.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$uninstallScript`""
$uninstaller.WorkingDirectory = $env:TEMP
if (Test-Path $iconPath) { $uninstaller.IconLocation = "$iconPath,0" }
$uninstaller.Description = 'Uninstall MyTerminal for current user'
$uninstaller.Save()

Invoke-ShellRefresh
Restart-Explorer

Write-Host 'MyTerminal was installed for the current user.'
Write-Host "Installed AppX layout: $($installedPackage.InstallLocation)"
Write-Host "Start Menu folder: $startMenuDir"
Write-Host 'Open a new terminal window before testing wt PATH changes.'
Write-Host 'Explorer was restarted to load Open in Terminal (&Dev).'
