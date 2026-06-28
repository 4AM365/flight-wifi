<#
  flight-wifi.ps1  -  "airplane wifi" mode for staying under Southwest's throttle/boot triggers.

  Southwest (and most airline wifi) will THROTTLE sustained high-bandwidth traffic and will
  BOOT you for VPNs / firewall-evasion. You can't make a VPN work by filtering, but you CAN stop
  your own machine from quietly tripping the triggers in the background (cloud sync, OS/app
  updates, an auto-reconnecting VPN client, P2P). This script does that by creating a named
  Windows Firewall rule group ("FlightWifi") of OUTBOUND BLOCK rules, and tearing it down again.

  Usage:
    .\flight-wifi.ps1 on        # board: block the hogs + kill auto-reconnecting VPN clients
    .\flight-wifi.ps1 off       # landed: remove all the blocks
    .\flight-wifi.ps1 status    # show what's currently blocked / what's running

  It self-elevates (firewall changes need admin); just double-click flight-on.cmd / flight-off.cmd.

  NOTE: This is empirical, not a published Southwest spec. Streaming video and video calls are
  still on you to not open in the browser. Marking the wifi as a "metered connection" in Windows
  Settings is a good extra suppressor this script can't reliably set.
#>

param(
    [ValidateSet('on', 'off', 'status')]
    [string]$Action = 'status'
)

$Group = 'FlightWifi'

# --- self-elevate (only the actions that change the firewall need admin) ----
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (($Action -ne 'status') -and (-not $isAdmin)) {
    Write-Host "Requesting administrator rights..." -ForegroundColor Yellow
    $psExe = (Get-Process -Id $PID).Path   # the powershell/pwsh host we're running under
    Start-Process -FilePath $psExe -Verb RunAs -ArgumentList @(
        '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"", $Action
    )
    return
}

# --- what we block ---------------------------------------------------------
# Bandwidth-hog executables. Only paths that actually exist get a rule (so this is safe on any
# machine). Add your own offenders to this list as needed.
$exeCandidates = @(
    "$env:LOCALAPPDATA\Microsoft\OneDrive\OneDrive.exe"
    "$env:ProgramFiles\Microsoft OneDrive\OneDrive.exe"
    "$env:LOCALAPPDATA\Dropbox\Client\Dropbox.exe"
    "${env:ProgramFiles(x86)}\Dropbox\Client\Dropbox.exe"
    "$env:APPDATA\Zoom\bin\Zoom.exe"
    "$env:LOCALAPPDATA\Microsoft\Teams\current\Teams.exe"
    "${env:ProgramFiles(x86)}\Steam\steam.exe"
    "$env:LOCALAPPDATA\slack\slack.exe"
    "$env:LOCALAPPDATA\Programs\signal-desktop\Signal.exe"
)
# wildcard resolves (versioned install dirs)
$exeCandidates += (Get-ChildItem "$env:ProgramFiles\Google\Drive File Stream\*\GoogleDriveFS.exe" -ErrorAction SilentlyContinue).FullName
$exeCandidates += (Get-ChildItem "$env:LOCALAPPDATA\Google\DriveFS\*\GoogleDriveFS.exe" -ErrorAction SilentlyContinue).FullName

# Port-based blocks (catch ANY process, e.g. an auto-reconnecting VPN or a torrent client).
# VPN ports: blocking these stops a VPN client from silently re-establishing and getting you booted.
$blockPorts = @(
    @{ Name = 'VPN-IKE/IPsec';   Proto = 'UDP'; Ports = '500,4500' }
    @{ Name = 'VPN-OpenVPN';     Proto = 'UDP'; Ports = '1194' }
    @{ Name = 'VPN-OpenVPN-TCP'; Proto = 'TCP'; Ports = '1194' }
    @{ Name = 'VPN-WireGuard';   Proto = 'UDP'; Ports = '51820' }
    @{ Name = 'VPN-L2TP';        Proto = 'UDP'; Ports = '1701' }
    @{ Name = 'VPN-PPTP';        Proto = 'TCP'; Ports = '1723' }
    @{ Name = 'P2P-BitTorrent';  Proto = 'TCP'; Ports = '6881-6889' }
    @{ Name = 'P2P-BitTorrent';  Proto = 'UDP'; Ports = '6881-6889' }
)

# VPN client processes to stop on "on" (best-effort; names are matched without .exe).
$vpnProcs = @(
    'nordvpn', 'nordvpn-service', 'expressvpn', 'expressvpnd', 'wireguard', 'openvpn',
    'openvpnconnect', 'mullvad', 'mullvad-daemon', 'protonvpn', 'ProtonVPN.Client',
    'surfshark', 'pia-client', 'TunnelBear', 'WindscribeService'
)

# --- helpers ---------------------------------------------------------------
function Remove-FlightRules {
    $existing = Get-NetFirewallRule -Group $Group -ErrorAction SilentlyContinue
    if ($existing) { $existing | Remove-NetFirewallRule }
}

function Show-Status {
    $rules = Get-NetFirewallRule -Group $Group -ErrorAction SilentlyContinue
    if ($rules) {
        Write-Host "FlightWifi mode is ON - $($rules.Count) block rule(s) active:" -ForegroundColor Cyan
        $rules | Sort-Object DisplayName | ForEach-Object { Write-Host "   - $($_.DisplayName)" }
    } else {
        Write-Host "FlightWifi mode is OFF - no blocks active." -ForegroundColor Green
    }
    $running = Get-Process -Name $vpnProcs -ErrorAction SilentlyContinue | Select-Object -Expand Name -Unique
    if ($running) {
        Write-Host "`n  VPN clients currently running (will get you booted in-flight): $($running -join ', ')" -ForegroundColor Yellow
    }
}

# --- actions ---------------------------------------------------------------
switch ($Action) {

    'on' {
        Remove-FlightRules   # idempotent: clear any stale rules first

        $exes = $exeCandidates | Where-Object { $_ -and (Test-Path $_) } | Sort-Object -Unique
        foreach ($exe in $exes) {
            $name = [IO.Path]::GetFileNameWithoutExtension($exe)
            New-NetFirewallRule -DisplayName "FlightWifi block $name" -Group $Group `
                -Direction Outbound -Action Block -Program $exe -Profile Any | Out-Null
        }

        foreach ($p in $blockPorts) {
            New-NetFirewallRule -DisplayName "FlightWifi block $($p.Name) $($p.Proto)" -Group $Group `
                -Direction Outbound -Action Block -Protocol $p.Proto -RemotePort $p.Ports -Profile Any | Out-Null
        }

        # stop auto-reconnecting VPN clients
        $killed = @()
        foreach ($proc in (Get-Process -Name $vpnProcs -ErrorAction SilentlyContinue)) {
            try { Stop-Process -Id $proc.Id -Force -ErrorAction Stop; $killed += $proc.Name } catch {}
        }

        Write-Host "Airplane-wifi mode ON." -ForegroundColor Cyan
        Write-Host "  Blocked $($exes.Count) hog app(s) + $($blockPorts.Count) port rule(s) outbound."
        if ($killed) { Write-Host "  Stopped VPN client(s): $(( $killed | Sort-Object -Unique) -join ', ')" }
        Write-Host "`n  Still on you: don't open Netflix/YouTube/Zoom in the browser, and (optional but" -ForegroundColor DarkGray
        Write-Host "  recommended) set this wifi as a 'metered connection' in Settings > Network." -ForegroundColor DarkGray
        Write-Host "  Run '.\flight-wifi.ps1 off' (or flight-off.cmd) when you land." -ForegroundColor DarkGray
    }

    'off' {
        Remove-FlightRules
        Write-Host "Airplane-wifi mode OFF - all FlightWifi blocks removed." -ForegroundColor Green
        Write-Host "  (VPN clients were stopped, not uninstalled - relaunch yours manually if you use one.)" -ForegroundColor DarkGray
    }

    'status' { Show-Status }
}
