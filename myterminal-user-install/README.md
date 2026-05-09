# MyTerminal user install package generator

This folder generates `dist\MyTerminalUserInstall` from a built loose AppX layout.

Default input:

```powershell
src\cascadia\CascadiaPackage\bin\x64\Debug\AppX
```

Default output:

```powershell
dist\MyTerminalUserInstall
```

Usage from the repository root:

```powershell
.\myterminal-user-install\generate.bat
```

Or directly with PowerShell:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\myterminal-user-install\generate.ps1
```

To use a different AppX source or output folder:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\myterminal-user-install\generate.ps1 `
  -AppxSource .\src\cascadia\CascadiaPackage\bin\x64\Debug\AppX `
  -OutputPath .\dist\MyTerminalUserInstall
```

The output folder is cleared and recreated on each run. Build the Terminal package first so the AppX source folder exists.
