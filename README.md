![Version](https://img.shields.io/badge/version-3.0.0-blue)
![Platform](https://img.shields.io/badge/platform-Windows-lightgrey)
![PowerShell](https://img.shields.io/badge/powershell-5.1+-blue)

# System Dashboard Enterprise

Enterprise Windows System Monitoring & Compliance Dashboard  
Designed for regulated (GxP) environments.

---

## Overview

System Dashboard Enterprise is a PowerShell-based WPF application that provides:

- WiFi and Ethernet IP address visibility
- Logged-in user identification
- Last system reboot timestamp
- Last Windows Update installation date
- Patch compliance aging (days since last update)
- GxP validation status indicator
- Audit log export (CSV)
- WiFi adapter management
- Quick access to Windows Update & User Management
- Always-on-top compact widget mode
- Transparent floating widget mode

---

## Version

Current Version: **v3.0.0**

---

## Requirements

- Windows 10 / 11
- PowerShell 5.1+
- Administrator rights (for WiFi toggle)
- .NET Framework (default in Windows)

---

## Installation

### Option 1 – Manual
1. Download the repository
2. Extract contents
3. Run:

```powershell
.\SystemDashboard-Enterprise-v3.ps1
