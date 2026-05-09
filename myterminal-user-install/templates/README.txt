MyTerminal current-user installer

Run install.bat to install for the current Windows user.

What it does:
- Copies AppX to %LOCALAPPDATA%\Programs\MyTerminal\AppX
- Registers WindowsTerminalDev for the current user
- Backs up the current default terminal delegation under HKCU:\Software\MyTerminal
- Sets WindowsTerminalDev as the current user's default terminal
- Creates %LOCALAPPDATA%\myterminal-bin\wt.cmd and puts that folder first in the user PATH
- Creates Start Menu entries under the current user's Start Menu:
  - MyTerminal\Terminal Dev
  - MyTerminal\Uninstall MyTerminal
- Registers the File Explorer folder context menu entry:
  - Open in Terminal (&Dev)
- Restarts Explorer so the context menu appears immediately.

Uninstall:
- Use Start Menu -> MyTerminal -> Uninstall MyTerminal.
- The uninstaller removes the AppX registration, restores the previous default terminal if it was backed up, removes the wt wrapper and user PATH entry, removes Start Menu entries, and deletes %LOCALAPPDATA%\Programs\MyTerminal including uninstall-user.ps1.

Troubleshooting File Explorer context menu:
- Run diagnose-user.ps1 from this folder.
- install.bat restarts Explorer automatically. If all checks are OK but Open in Terminal (&Dev) is still missing, restart Explorer again:
  powershell.exe -NoProfile -Command "Stop-Process -Name explorer -Force"
- The context menu comes from AppxManifest.xml + WindowsTerminalShellExt.dll. It is not controlled by wt.cmd or the user PATH.

Note:
- Loose AppX registration may require Windows Developer Mode on the target machine.
