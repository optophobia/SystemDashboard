<#
.SYNOPSIS
    Windows System Dashboard - Enterprise Edition (v3.0)

.DESCRIPTION
    WPF-based dashboard for system monitoring and compliance tracking.
    
    Displays:
    - WiFi and Ethernet IP addresses
    - Currently logged-in user
    - Last system reboot timestamp
    - Last Windows update installation date
    - Patch compliance aging (days since last update)
    - GxP validation status
    
    Features:
    - Toggle WiFi adapter on/off
    - Quick access to Windows Update settings
    - Quick access to User Management console
    - Comprehensive audit logging to CSV
    - Export audit log for review
    - Transparent floating UI mode
    - Always-on-top mode for persistent visibility
    - Optional compact corner widget mode

.PARAMETER WidgetMode
    When enabled, displays a smaller, draggable widget in the bottom-right corner.

.PARAMETER AlwaysOnTop
    Keeps the dashboard window above all other windows.

.PARAMETER TransparencyLevel
    Sets the window opacity (0.0 = invisible, 1.0 = opaque). Default: 0.92

.NOTES
    File Name      : SystemDashboard-Enterprise.ps1
    Author         : [Your Organization]
    Prerequisite   : PowerShell 5.1+, Administrator rights for WiFi toggle
    Version        : 3.0
    Date           : 2025-02-11
    
    Compliance     : Designed for GxP-regulated environments
    Audit Trail    : All user actions logged to CSV

.EXAMPLE
    .\SystemDashboard-Enterprise.ps1
    Launches the dashboard in standard mode.

.EXAMPLE
    .\SystemDashboard-Enterprise.ps1 -WidgetMode
    Launches as a compact corner widget.

.LINK
    Internal Documentation: https://yourcompany.com/docs/system-dashboard
#>

#Requires -Version 5.1

# ---------------------------
# ASSEMBLIES
# ---------------------------

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Windows.Forms

# ---------------------------
# PARAMETERS
# ---------------------------

[CmdletBinding()]
param(
    [Parameter(HelpMessage = "Launch in compact widget mode")]
    [switch]$WidgetMode,
    
    [Parameter(HelpMessage = "Keep window always on top")]
    [switch]$AlwaysOnTop = $true,
    
    [Parameter(HelpMessage = "Window transparency level (0.0-1.0)")]
    [ValidateRange(0.0, 1.0)]
    [double]$TransparencyLevel = 0.92
)

# ---------------------------
# CONFIGURATION
# ---------------------------

$script:Config = @{
    # Paths
    LogoPath              = "C:\Path\To\Your\Logo.png"
    GxPValidationMarker   = "C:\ProgramData\Company\Validation\Validated.flag"
    AuditLogPath          = "C:\ProgramData\Company\SystemDashboard\AuditLog.csv"
    
    # Window Settings
    WindowTitle           = "System Dashboard - Enterprise Edition"
    WindowHeight          = 480
    WindowWidth           = 420
    RefreshDelaySeconds   = 2
    
    # Widget Settings
    WidgetWidth           = 340
    WidgetHeight          = 280
    WidgetMarginRight     = 20
    WidgetMarginBottom    = 60
    
    # UI Behavior
    WidgetMode            = $WidgetMode.IsPresent
    AlwaysOnTop           = $AlwaysOnTop.IsPresent
    TransparencyLevel     = $TransparencyLevel
    
    # Compliance Thresholds
    PatchAgingWarningDays = 30
    PatchAgingCriticalDays= 60
}

# ---------------------------
# NETWORK INFORMATION FUNCTIONS
# ---------------------------

<#
.SYNOPSIS
    Retrieves the WiFi adapter's IPv4 address.
.OUTPUTS
    String. The IPv4 address or "Not Connected" if unavailable.
#>
function Get-WifiIPAddress {
    [CmdletBinding()]
    [OutputType([string])]
    param()
    
    try {
        $ip = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
            Where-Object { 
                $_.InterfaceAlias -match "Wi-?Fi" -and 
                $_.IPAddress -notlike "169.254.*" -and
                $_.IPAddress -notlike "127.*"
            } |
            Select-Object -ExpandProperty IPAddress -First 1
        
        return if ($ip) { $ip } else { "Not Connected" }
    }
    catch {
        Write-Warning "Failed to retrieve WiFi IP: $_"
        return "Error"
    }
}

<#
.SYNOPSIS
    Retrieves the Ethernet adapter's IPv4 address.
.OUTPUTS
    String. The IPv4 address or "Not Connected" if unavailable.
#>
function Get-EthernetIPAddress {
    [CmdletBinding()]
    [OutputType([string])]
    param()
    
    try {
        $ip = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
            Where-Object { 
                $_.InterfaceAlias -match "Ethernet" -and 
                $_.IPAddress -notlike "169.254.*" -and
                $_.IPAddress -notlike "127.*"
            } |
            Select-Object -ExpandProperty IPAddress -First 1
        
        return if ($ip) { $ip } else { "Not Connected" }
    }
    catch {
        Write-Warning "Failed to retrieve Ethernet IP: $_"
        return "Error"
    }
}

# ---------------------------
# SYSTEM INFORMATION FUNCTIONS
# ---------------------------

<#
.SYNOPSIS
    Retrieves the last system boot time.
.OUTPUTS
    DateTime. The last boot time.
#>
function Get-LastRebootTime {
    [CmdletBinding()]
    [OutputType([DateTime])]
    param()
    
    try {
        $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
        return $os.LastBootUpTime
    }
    catch {
        Write-Warning "Failed to retrieve last reboot time: $_"
        return Get-Date
    }
}

<#
.SYNOPSIS
    Retrieves the most recent Windows update installation date.
.OUTPUTS
    String. Formatted date string or "Unknown" if unavailable.
#>
function Get-LastUpdateDate {
    [CmdletBinding()]
    [OutputType([string])]
    param()
    
    try {
        $update = Get-HotFix -ErrorAction SilentlyContinue | 
            Where-Object { $null -ne $_.InstalledOn } |
            Sort-Object InstalledOn -Descending | 
            Select-Object -First 1
        
        if ($update) { 
            return $update.InstalledOn.ToString("yyyy-MM-dd HH:mm") 
        }
        else { 
            return "Unknown" 
        }
    }
    catch {
        Write-Warning "Failed to retrieve last update date: $_"
        return "Unknown"
    }
}

<#
.SYNOPSIS
    Calculates days since last Windows update (patch aging).
.OUTPUTS
    String. Number of days or "Unknown" if unavailable.
#>
function Get-PatchComplianceAging {
    [CmdletBinding()]
    [OutputType([string])]
    param()
    
    try {
        $update = Get-HotFix -ErrorAction SilentlyContinue | 
            Where-Object { $null -ne $_.InstalledOn } |
            Sort-Object InstalledOn -Descending | 
            Select-Object -First 1
        
        if (-not $update) { 
            return "Unknown" 
        }
        
        $days = [Math]::Floor((New-TimeSpan -Start $update.InstalledOn -End (Get-Date)).TotalDays)
        
        # Return with status indicator
        if ($days -ge $script:Config.PatchAgingCriticalDays) {
            return "$days days (CRITICAL)"
        }
        elseif ($days -ge $script:Config.PatchAgingWarningDays) {
            return "$days days (WARNING)"
        }
        else {
            return "$days days (OK)"
        }
    }
    catch {
        Write-Warning "Failed to calculate patch aging: $_"
        return "Unknown"
    }
}

<#
.SYNOPSIS
    Checks GxP validation status by looking for marker file.
.OUTPUTS
    String. "Validated", "Not Validated", or "Unknown".
#>
function Get-GxPValidationStatus {
    [CmdletBinding()]
    [OutputType([string])]
    param()
    
    try {
        if (Test-Path -Path $script:Config.GxPValidationMarker -ErrorAction SilentlyContinue) {
            # Read validation date if file contains it
            $validationDate = Get-Content -Path $script:Config.GxPValidationMarker -ErrorAction SilentlyContinue -TotalCount 1
            if ($validationDate -and $validationDate -match '\d{4}-\d{2}-\d{2}') {
                return "Validated ($validationDate)"
            }
            return "Validated"
        }
        else {
            return "Not Validated"
        }
    }
    catch {
        Write-Warning "Failed to check GxP validation status: $_"
        return "Unknown"
    }
}

# ---------------------------
# AUDIT LOGGING FUNCTIONS
# ---------------------------

<#
.SYNOPSIS
    Writes an audit entry to the CSV log file.
.PARAMETER Action
    Description of the action performed.
.PARAMETER Result
    Outcome of the action (Success, Failed, etc.).
.PARAMETER Details
    Optional additional details about the action.
#>
function Write-AuditLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Action,
        
        [Parameter(Mandatory)]
        [ValidateSet('Success', 'Failed', 'Warning', 'Info')]
        [string]$Result,
        
        [Parameter()]
        [string]$Details = ''
    )

    try {
        # Ensure audit directory exists
        $auditDir = Split-Path -Path $script:Config.AuditLogPath -Parent
        if (-not (Test-Path -Path $auditDir)) {
            New-Item -ItemType Directory -Path $auditDir -Force -ErrorAction Stop | Out-Null
            Write-Verbose "Created audit log directory: $auditDir"
        }

        # Create audit entry
        $entry = [PSCustomObject]@{
            Timestamp   = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
            User        = $env:USERNAME
            Domain      = $env:USERDOMAIN
            Machine     = $env:COMPUTERNAME
            Action      = $Action
            Result      = $Result
            Details     = $Details
            ProcessID   = $PID
        }

        # Write to CSV (create with headers if new file)
        if (-not (Test-Path -Path $script:Config.AuditLogPath)) {
            $entry | Export-Csv -Path $script:Config.AuditLogPath -NoTypeInformation -ErrorAction Stop
            Write-Verbose "Created new audit log: $($script:Config.AuditLogPath)"
        }
        else {
            $entry | Export-Csv -Path $script:Config.AuditLogPath -NoTypeInformation -Append -ErrorAction Stop
        }
        
        Write-Verbose "Audit logged: $Action - $Result"
    }
    catch {
        Write-Warning "Failed to write audit log: $_"
        # Don't throw - audit failure shouldn't break the application
    }
}

# ---------------------------
# UI UPDATE FUNCTIONS
# ---------------------------

<#
.SYNOPSIS
    Refreshes all dashboard data displays.
.DESCRIPTION
    Updates all TextBlock controls with current system information.
    Logs the refresh action to the audit trail.
#>
function Update-DashboardData {
    [CmdletBinding()]
    param()
    
    try {
        $script:UI.WifiIP.Text     = "WiFi IP: $(Get-WifiIPAddress)"
        $script:UI.EthernetIP.Text = "Ethernet IP: $(Get-EthernetIPAddress)"
        $script:UI.LoggedUser.Text = "User: $env:USERNAME"
        $script:UI.LastReboot.Text = "Last Reboot: $((Get-LastRebootTime).ToString('yyyy-MM-dd HH:mm:ss'))"
        $script:UI.LastUpdate.Text = "Last Update: $(Get-LastUpdateDate)"
        
        $patchAging = Get-PatchComplianceAging
        $script:UI.PatchAging.Text = "Patch Age: $patchAging"
        
        # Color-code patch aging
        if ($patchAging -like "*CRITICAL*") {
            $script:UI.PatchAging.Foreground = "Red"
        }
        elseif ($patchAging -like "*WARNING*") {
            $script:UI.PatchAging.Foreground = "Orange"
        }
        else {
            $script:UI.PatchAging.Foreground = "LightGreen"
        }
        
        $script:UI.GxPStatus.Text = "GxP Status: $(Get-GxPValidationStatus)"
        
        Write-AuditLog -Action "Dashboard Data Refreshed" -Result "Success"
        Write-Verbose "Dashboard data updated successfully"
    }
    catch {
        Write-Error "Failed to update dashboard data: $_"
        Write-AuditLog -Action "Dashboard Data Refresh" -Result "Failed" -Details $_.Exception.Message
        
        [System.Windows.MessageBox]::Show(
            "Error updating dashboard data. Check logs for details.",
            "Update Error",
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Error
        )
    }
}

# ---------------------------
# NETWORK MANAGEMENT FUNCTIONS
# ---------------------------

<#
.SYNOPSIS
    Toggles the WiFi adapter on or off.
.DESCRIPTION
    Enables the WiFi adapter if disabled, or disables it if enabled.
    Requires administrative privileges. Logs action to audit trail.
#>
function Toggle-WifiAdapter {
    [CmdletBinding()]
    param()
    
    try {
        $adapter = Get-NetAdapter -ErrorAction Stop | 
            Where-Object { $_.Name -match "Wi-?Fi" } |
            Select-Object -First 1
        
        if (-not $adapter) {
            [System.Windows.MessageBox]::Show(
                "WiFi adapter not found on this system.",
                "WiFi Not Found",
                [System.Windows.MessageBoxButton]::OK,
                [System.Windows.MessageBoxImage]::Warning
            )
            Write-AuditLog -Action "Toggle WiFi Adapter" -Result "Failed" -Details "Adapter not found"
            return
        }

        $previousState = $adapter.Status
        
        if ($adapter.Status -eq "Up") {
            Disable-NetAdapter -Name $adapter.Name -Confirm:$false -ErrorAction Stop
            $newState = "Disabled"
            Write-Verbose "WiFi adapter disabled: $($adapter.Name)"
        }
        else {
            Enable-NetAdapter -Name $adapter.Name -Confirm:$false -ErrorAction Stop
            $newState = "Enabled"
            Write-Verbose "WiFi adapter enabled: $($adapter.Name)"
        }

        # Wait for adapter state change
        Start-Sleep -Seconds $script:Config.RefreshDelaySeconds
        Update-DashboardData
        
        Write-AuditLog -Action "Toggle WiFi Adapter" -Result "Success" `
            -Details "Changed from $previousState to $newState"
        
        [System.Windows.MessageBox]::Show(
            "WiFi adapter has been $newState.",
            "WiFi Toggle",
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Information
        )
    }
    catch [System.UnauthorizedAccessException] {
        Write-Warning "Access denied toggling WiFi adapter"
        Write-AuditLog -Action "Toggle WiFi Adapter" -Result "Failed" -Details "Access Denied"
        
        [System.Windows.MessageBox]::Show(
            "Administrative privileges required to toggle WiFi adapter.`n`nPlease run PowerShell as Administrator.",
            "Access Denied",
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Error
        )
    }
    catch {
        Write-Error "Failed to toggle WiFi adapter: $_"
        Write-AuditLog -Action "Toggle WiFi Adapter" -Result "Failed" -Details $_.Exception.Message
        
        [System.Windows.MessageBox]::Show(
            "Failed to toggle WiFi adapter:`n`n$($_.Exception.Message)",
            "WiFi Toggle Error",
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Error
        )
    }
}

# ---------------------------
# UI HELPER FUNCTIONS
# ---------------------------

<#
.SYNOPSIS
    Loads and displays the company logo.
.PARAMETER ImageControl
    The WPF Image control to populate.
#>
function Set-LogoImage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Windows.Controls.Image]$ImageControl
    )
    
    if (-not (Test-Path -Path $script:Config.LogoPath)) {
        Write-Warning "Logo file not found at: $($script:Config.LogoPath)"
        return
    }
    
    try {
        $bitmap = New-Object System.Windows.Media.Imaging.BitmapImage
        $bitmap.BeginInit()
        $bitmap.CacheOption = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
        $bitmap.UriSource = New-Object System.Uri($script:Config.LogoPath)
        $bitmap.EndInit()
        $bitmap.Freeze()
        
        $ImageControl.Source = $bitmap
        Write-Verbose "Logo loaded successfully from: $($script:Config.LogoPath)"
    }
    catch {
        Write-Warning "Failed to load logo image: $_"
    }
}

<#
.SYNOPSIS
    Opens Windows Update settings.
#>
function Open-WindowsUpdate {
    [CmdletBinding()]
    param()
    
    try {
        Start-Process -FilePath "control.exe" -ArgumentList "/name Microsoft.WindowsUpdate" -ErrorAction Stop
        Write-AuditLog -Action "Open Windows Update" -Result "Success"
    }
    catch {
        Write-Error "Failed to open Windows Update: $_"
        Write-AuditLog -Action "Open Windows Update" -Result "Failed" -Details $_.Exception.Message
    }
}

<#
.SYNOPSIS
    Opens Local Users and Groups management console.
#>
function Open-UserManagement {
    [CmdletBinding()]
    param()
    
    try {
        Start-Process -FilePath "lusrmgr.msc" -ErrorAction Stop
        Write-AuditLog -Action "Open User Management" -Result "Success"
    }
    catch {
        Write-Error "Failed to open User Management: $_"
        Write-AuditLog -Action "Open User Management" -Result "Failed" -Details $_.Exception.Message
        
        [System.Windows.MessageBox]::Show(
            "Failed to open User Management. This feature may not be available on Windows Home edition.",
            "User Management Error",
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Error
        )
    }
}

<#
.SYNOPSIS
    Opens the audit log CSV file for review.
#>
function Export-AuditLogFile {
    [CmdletBinding()]
    param()
    
    try {
        if (Test-Path -Path $script:Config.AuditLogPath) {
            Start-Process -FilePath $script:Config.AuditLogPath -ErrorAction Stop
            Write-AuditLog -Action "Export Audit Log" -Result "Success" -Details "Opened CSV file"
        }
        else {
            [System.Windows.MessageBox]::Show(
                "Audit log file does not exist yet.`n`nPath: $($script:Config.AuditLogPath)",
                "No Audit Log",
                [System.Windows.MessageBoxButton]::OK,
                [System.Windows.MessageBoxImage]::Information
            )
            Write-AuditLog -Action "Export Audit Log" -Result "Warning" -Details "File not found"
        }
    }
    catch {
        Write-Error "Failed to open audit log: $_"
        Write-AuditLog -Action "Export Audit Log" -Result "Failed" -Details $_.Exception.Message
    }
}

# ---------------------------
# XAML UI DEFINITION
# ---------------------------

[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        Title="$($script:Config.WindowTitle)"
        Height="$($script:Config.WindowHeight)"
        Width="$($script:Config.WindowWidth)"
        WindowStartupLocation="CenterScreen"
        ResizeMode="NoResize"
        Background="#CC1E1E1E"
        Foreground="White"
        AllowsTransparency="True"
        WindowStyle="None"
        BorderBrush="#3F3F3F"
        BorderThickness="1">

    <Window.Resources>
        <!-- Button Style -->
        <Style TargetType="Button">
            <Setter Property="Background" Value="#2D2D2D"/>
            <Setter Property="Foreground" Value="White"/>
            <Setter Property="BorderBrush" Value="#3F3F3F"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding" Value="8,4"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="FontSize" Value="12"/>
            <Style.Triggers>
                <Trigger Property="IsMouseOver" Value="True">
                    <Setter Property="Background" Value="#3F3F3F"/>
                </Trigger>
            </Style.Triggers>
        </Style>
        
        <!-- TextBlock Style -->
        <Style TargetType="TextBlock">
            <Setter Property="FontSize" Value="12"/>
            <Setter Property="FontFamily" Value="Consolas, Courier New"/>
        </Style>
    </Window.Resources>

    <Grid Margin="15">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <!-- Header with Logo and Close Button -->
        <Grid Grid.Row="0">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="Auto"/>
            </Grid.ColumnDefinitions>
            
            <Image Name="LogoImage" 
                   Grid.Column="0"
                   Height="50" 
                   HorizontalAlignment="Left" 
                   Margin="0,0,0,10"/>
            
            <Button Name="btnClose" 
                    Grid.Column="1"
                    Content="✕" 
                    Width="30" 
                    Height="30"
                    FontSize="16"
                    FontWeight="Bold"
                    VerticalAlignment="Top"
                    ToolTip="Close Dashboard"/>
        </Grid>

        <!-- System Information Section -->
        <StackPanel Grid.Row="1" Margin="0,5,0,10">
            <TextBlock Name="wifiIP" Margin="0,2"/>
            <TextBlock Name="ethIP" Margin="0,2"/>
            <TextBlock Name="loggedUser" Margin="0,2"/>
            <TextBlock Name="lastReboot" Margin="0,2"/>
            <TextBlock Name="lastUpdate" Margin="0,2"/>
            <TextBlock Name="PatchAging" Margin="0,2" FontWeight="Bold"/>
            <TextBlock Name="GxPStatus" Margin="0,2" FontWeight="Bold"/>
        </StackPanel>

        <!-- Separator -->
        <Separator Grid.Row="2" 
                   Background="#3F3F3F" 
                   Margin="0,5"
                   VerticalAlignment="Top"/>

        <!-- Action Buttons Section -->
        <StackPanel Grid.Row="3" Margin="0,10,0,0">
            <Button Name="btnWifiToggle" 
                    Content="Toggle WiFi" 
                    Margin="0,3"/>
            <Button Name="btnUpdates" 
                    Content="Windows Updates" 
                    Margin="0,3"/>
            <Button Name="btnUsers" 
                    Content="User Management" 
                    Margin="0,3"/>
            <Button Name="btnRefresh" 
                    Content="🔄 Refresh Data" 
                    Margin="0,3"/>
            <Button Name="btnExportAudit" 
                    Content="📋 Export Audit Log" 
                    Margin="0,3"/>
        </StackPanel>
    </Grid>
</Window>
"@

# ---------------------------
# MAIN INITIALIZATION
# ---------------------------

try {
    Write-Verbose "Initializing System Dashboard..."
    
    # Parse XAML and create window
    $reader = New-Object System.Xml.XmlNodeReader $xaml
    $window = [Windows.Markup.XamlReader]::Load($reader)
    
    # Store UI element references
    $script:UI = @{
        Window      = $window
        WifiIP      = $window.FindName("wifiIP")
        EthernetIP  = $window.FindName("ethIP")
        LoggedUser  = $window.FindName("loggedUser")
        LastReboot  = $window.FindName("lastReboot")
        LastUpdate  = $window.FindName("lastUpdate")
        PatchAging  = $window.FindName("PatchAging")
        GxPStatus   = $window.FindName("GxPStatus")
        Logo        = $window.FindName("LogoImage")
    }
    
    # Get button references
    $btnWifiToggle  = $window.FindName("btnWifiToggle")
    $btnUpdates     = $window.FindName("btnUpdates")
    $btnUsers       = $window.FindName("btnUsers")
    $btnRefresh     = $window.FindName("btnRefresh")
    $btnExportAudit = $window.FindName("btnExportAudit")
    $btnClose       = $window.FindName("btnClose")
    
    # ---------------------------
    # EVENT HANDLERS
    # ---------------------------
    
    $btnWifiToggle.Add_Click({
        Toggle-WifiAdapter
    })
    
    $btnUpdates.Add_Click({
        Open-WindowsUpdate
    })
    
    $btnUsers.Add_Click({
        Open-UserManagement
    })
    
    $btnRefresh.Add_Click({
        Update-DashboardData
    })
    
    $btnExportAudit.Add_Click({
        Export-AuditLogFile
    })
    
    $btnClose.Add_Click({
        Write-AuditLog -Action "Dashboard Closed" -Result "Info" -Details "User closed dashboard"
        $window.Close()
    })
    
    # ---------------------------
    # WIDGET MODE CONFIGURATION
    # ---------------------------
    
    if ($script:Config.WidgetMode) {
        Write-Verbose "Configuring widget mode..."
        
        # Resize for widget mode
        $window.Width = $script:Config.WidgetWidth
        $window.Height = $script:Config.WidgetHeight
        
        # Enable dragging
        $window.Add_MouseLeftButtonDown({
            try {
                $window.DragMove()
            }
            catch {
                # Ignore drag errors (can occur if window is already being dragged)
            }
        })
        
        # Position in bottom-right corner
        $screenWidth  = [System.Windows.SystemParameters]::PrimaryScreenWidth
        $screenHeight = [System.Windows.SystemParameters]::PrimaryScreenHeight
        
        $window.Left = $screenWidth - $window.Width - $script:Config.WidgetMarginRight
        $window.Top  = $screenHeight - $window.Height - $script:Config.WidgetMarginBottom
        
        Write-AuditLog -Action "Dashboard Launched" -Result "Info" -Details "Widget Mode"
    }
    else {
        Write-AuditLog -Action "Dashboard Launched" -Result "Info" -Details "Standard Mode"
    }
    
    # ---------------------------
    # WINDOW BEHAVIOR SETTINGS
    # ---------------------------
    
    $window.Topmost = $script:Config.AlwaysOnTop
    $window.Opacity = $script:Config.TransparencyLevel
    
    # ---------------------------
    # LOAD LOGO AND INITIAL DATA
    # ---------------------------
    
    Set-LogoImage -ImageControl $script:UI.Logo
    Update-DashboardData
    
    Write-Verbose "Dashboard initialization complete"
    
    # ---------------------------
    # DISPLAY WINDOW
    # ---------------------------
    
    [void]$window.ShowDialog()
    
    Write-Verbose "Dashboard closed"
}
catch {
    Write-Error "Failed to initialize dashboard: $_"
    Write-AuditLog -Action "Dashboard Launch" -Result "Failed" -Details $_.Exception.Message
    
    [System.Windows.MessageBox]::Show(
        "Failed to initialize dashboard:`n`n$($_.Exception.Message)`n`nCheck logs for details.",
        "Initialization Error",
        [System.Windows.MessageBoxButton]::OK,
        [System.Windows.MessageBoxImage]::Error
    )
    exit 1
}
