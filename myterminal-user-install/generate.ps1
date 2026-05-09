[CmdletBinding()]
param(
    [string]$AppxSource,
    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'

$scriptRoot = Split-Path -Parent $PSCommandPath
$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $scriptRoot '..'))
$templateRoot = Join-Path $scriptRoot 'templates'

if ([string]::IsNullOrWhiteSpace($AppxSource)) {
    $AppxSource = Join-Path $repoRoot 'src\cascadia\CascadiaPackage\bin\x64\Debug\AppX'
}
if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $OutputPath = Join-Path $repoRoot 'dist\MyTerminalUserInstall'
}

function ConvertTo-FullPath {
    param([Parameter(Mandatory)][string]$Path)

    if ([System.IO.Path]::IsPathRooted($Path)) {
        return [System.IO.Path]::GetFullPath($Path)
    }

    return [System.IO.Path]::GetFullPath((Join-Path $repoRoot $Path))
}

function Assert-RequiredFile {
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][string]$RelativePath
    )

    $path = Join-Path $Root $RelativePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Required file was not found: $path"
    }
}

function Assert-SafeOutputPath {
    param(
        [Parameter(Mandatory)][string]$ResolvedOutputPath,
        [Parameter(Mandatory)][string]$ResolvedRepoRoot,
        [Parameter(Mandatory)][string]$ResolvedAppxSource
    )

    $output = $ResolvedOutputPath.TrimEnd('\')
    $repo = $ResolvedRepoRoot.TrimEnd('\')
    $source = $ResolvedAppxSource.TrimEnd('\')
    $root = [System.IO.Path]::GetPathRoot($output).TrimEnd('\')

    if ([string]::IsNullOrWhiteSpace($output) -or $output -ieq $root) {
        throw "Refusing to clear an unsafe output path: $ResolvedOutputPath"
    }
    if ($output -ieq $repo) {
        throw "Refusing to use the repository root as output: $ResolvedOutputPath"
    }
    if ($output -ieq $source -or $output.StartsWith($source + '\', [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to put output inside the AppX source: $ResolvedOutputPath"
    }
}

$appxSourceFull = ConvertTo-FullPath $AppxSource
$outputFull = ConvertTo-FullPath $OutputPath
$repoRootFull = ConvertTo-FullPath $repoRoot

if (-not (Test-Path -LiteralPath $templateRoot -PathType Container)) {
    throw "Template folder was not found: $templateRoot"
}
if (-not (Test-Path -LiteralPath $appxSourceFull -PathType Container)) {
    throw "AppX source folder was not found: $appxSourceFull"
}

Assert-SafeOutputPath -ResolvedOutputPath $outputFull -ResolvedRepoRoot $repoRootFull -ResolvedAppxSource $appxSourceFull

$requiredAppxFiles = @(
    'AppxManifest.xml',
    'WindowsTerminal.exe',
    'wtd.exe',
    'OpenConsole.exe',
    'WindowsTerminalShellExt.dll',
    'TerminalApp.dll',
    'resources.pri'
)
foreach ($required in $requiredAppxFiles) {
    Assert-RequiredFile -Root $appxSourceFull -RelativePath $required
}

$requiredTemplates = @(
    'install.bat',
    'install-user.ps1',
    'uninstall-user.ps1',
    'diagnose-user.ps1',
    'README.txt'
)
foreach ($required in $requiredTemplates) {
    Assert-RequiredFile -Root $templateRoot -RelativePath $required
}

if (Test-Path -LiteralPath $outputFull) {
    Remove-Item -LiteralPath $outputFull -Recurse -Force
}

New-Item -ItemType Directory -Path $outputFull -Force | Out-Null

Get-ChildItem -LiteralPath $templateRoot -Force | ForEach-Object {
    Copy-Item -LiteralPath $_.FullName -Destination $outputFull -Recurse -Force
}

$outputAppx = Join-Path $outputFull 'AppX'
New-Item -ItemType Directory -Path $outputAppx -Force | Out-Null
Get-ChildItem -LiteralPath $appxSourceFull -Force | ForEach-Object {
    Copy-Item -LiteralPath $_.FullName -Destination $outputAppx -Recurse -Force
}

foreach ($required in $requiredTemplates) {
    Assert-RequiredFile -Root $outputFull -RelativePath $required
}
foreach ($required in $requiredAppxFiles) {
    Assert-RequiredFile -Root $outputAppx -RelativePath $required
}

Write-Host 'MyTerminal user install folder was generated.'
Write-Host "Source AppX: $appxSourceFull"
Write-Host "Output: $outputFull"
Write-Host 'Run install.bat from the output folder on the target machine.'
