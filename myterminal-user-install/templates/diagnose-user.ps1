$ErrorActionPreference = 'Continue'

$packageName = 'WindowsTerminalDev'
$shellExtClsid = '{52065414-E077-47EC-A3AC-1CC5455E1B54}'
$expectedInstallRoot = Join-Path $env:LOCALAPPDATA 'Programs\MyTerminal\AppX'

function Write-Check {
    param(
        [string]$Name,
        [bool]$Ok,
        [string]$Detail = ''
    )

    $status = if ($Ok) { 'OK' } else { 'FAIL' }
    if ([string]::IsNullOrWhiteSpace($Detail)) {
        Write-Host ("[{0}] {1}" -f $status, $Name)
    } else {
        Write-Host ("[{0}] {1}: {2}" -f $status, $Name, $Detail)
    }
}

$os = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
Write-Host "OS: $($os.ProductName) $($os.DisplayVersion) build $($os.CurrentBuild).$($os.UBR)"
Write-Host "Expected user install root: $expectedInstallRoot"

$pkg = Get-AppxPackage -Name $packageName -ErrorAction SilentlyContinue
Write-Check 'WindowsTerminalDev package registered' ($null -ne $pkg) $(if ($pkg) { $pkg.PackageFullName } else { '' })
if (-not $pkg) {
    Write-Host ''
    Write-Host 'Install did not register WindowsTerminalDev. Run install.bat again and copy any error output.'
    exit 1
}

Write-Host "InstallLocation: $($pkg.InstallLocation)"
Write-Check 'Installed from user package folder' ($pkg.InstallLocation -ieq $expectedInstallRoot)

$manifest = Join-Path $pkg.InstallLocation 'AppxManifest.xml'
Write-Check 'Registered AppxManifest.xml exists' (Test-Path $manifest) $manifest

$manifestText = ''
if (Test-Path $manifest) {
    $manifestText = [System.IO.File]::ReadAllText($manifest, [System.Text.Encoding]::UTF8)
}
Write-Check 'Manifest has fileExplorerContextMenus' ($manifestText -match 'windows\.fileExplorerContextMenus')
Write-Check 'Manifest has OpenTerminalDev verb' ($manifestText -match 'OpenTerminalDev')
Write-Check 'Manifest has shell extension COM class' ($manifestText -match [regex]::Escape($shellExtClsid.Trim('{}')))

$shellExt = Join-Path $pkg.InstallLocation 'WindowsTerminalShellExt.dll'
Write-Check 'WindowsTerminalShellExt.dll exists' (Test-Path $shellExt) $shellExt

$classIndex = "HKLM:\Software\Classes\PackagedCom\ClassIndex\$shellExtClsid"
$packageClass = "HKLM:\Software\Classes\PackagedCom\Package\$($pkg.PackageFullName)\Class\$shellExtClsid"
Write-Check 'Packaged COM class index exists' (Test-Path $classIndex) $classIndex
Write-Check 'Packaged COM package class exists' (Test-Path $packageClass) $packageClass

$wtd = Get-Command wtd.exe -ErrorAction SilentlyContinue
Write-Check 'wtd.exe execution alias resolves' ($null -ne $wtd) $(if ($wtd) { $wtd.Source } else { '' })

Write-Host ''
Write-Host 'If all checks are OK but File Explorer still does not show Open in Terminal (&Dev), restart Explorer:'
Write-Host '  Stop-Process -Name explorer -Force'
Write-Host 'Explorer will restart automatically. You can also sign out and back in.'
