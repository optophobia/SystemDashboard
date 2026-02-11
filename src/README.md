# System Dashboard – Enterprise Edition

## What This Tool Does

System Dashboard is a PowerShell-based desktop monitoring tool that displays:

- WiFi IP address
- Ethernet IP address
- Logged-in user
- Last reboot time
- Last Windows Update date
- Patch compliance aging (days since last update)
- Audit log export (CSV)

It is designed for enterprise and regulated environments.

---

## How To Run

Open PowerShell and run:

powershell -ExecutionPolicy Bypass -File .\src\SystemDashboard.ps1

---

## Installation (Optional Startup Install)

From Administrator PowerShell:

cd installer
.\Install-SystemDashboard.ps1

---

## Version

Current Version: 3.0.0
