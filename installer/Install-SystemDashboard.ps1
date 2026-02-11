#Requires -RunAsAdministrator

$InstallPath = "C:\Program Files\SystemDashboard"
$StartupPath = "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Startup"
$SourceScript = Join-Path $PSScriptRoot "..\src\SystemDashboard.ps1"

Write-Host "Installing System Dashboard..."

if (-not (Test-Path $InstallPath)) {
    New-Item -ItemType Directory -Path $InstallPath -Force | Out-Null
}

Copy-Item $SourceScript -Destination $InstallPath -Force
Unblock-File "$InstallPath\SystemDashboard.ps1"

$WScriptShell = New-Object -ComObject WScript.Shell
$Shortcut = $WScriptShell.CreateShortcut("$StartupPath\SystemDashboard.lnk")
$Shortcut.TargetPath = "powershell.exe"
$Shortcut.Arguments = "-ExecutionPolicy Bypass -File `"$InstallPath\SystemDashboard.ps1`""
$Shortcut.WorkingDirectory = $InstallPath
$Shortcut.Save()

Write-Host "Installation Complete."
