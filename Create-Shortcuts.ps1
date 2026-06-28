<#
  Create-Shortcuts.ps1  -  one-time setup. Drops two shortcuts on your Desktop:
    "Flight Wifi ON"  and  "Flight Wifi OFF"
  Each is pre-flagged to run as administrator. After running this, right-click a shortcut and
  choose "Pin to taskbar" (or drag it onto the taskbar) to get your one-click taskbar buttons.
#>

$here    = Split-Path -Parent $MyInvocation.MyCommand.Path
$desktop = [Environment]::GetFolderPath('Desktop')
$shell   = New-Object -ComObject WScript.Shell

function New-AdminShortcut {
    param($LinkPath, $Target, $IconRef, $Desc)

    $sc = $shell.CreateShortcut($LinkPath)
    $sc.TargetPath       = $Target
    $sc.WorkingDirectory = Split-Path -Parent $Target
    $sc.IconLocation     = $IconRef
    $sc.Description       = $Desc
    $sc.Save()

    # flip the "Run as administrator" bit (byte 0x15, bit 0x20) in the .lnk
    $bytes = [IO.File]::ReadAllBytes($LinkPath)
    $bytes[0x15] = $bytes[0x15] -bor 0x20
    [IO.File]::WriteAllBytes($LinkPath, $bytes)
}

New-AdminShortcut -LinkPath (Join-Path $desktop 'Flight Wifi ON.lnk') `
    -Target (Join-Path $here 'flight-on.cmd') `
    -IconRef "$env:SystemRoot\System32\imageres.dll,109" `
    -Desc 'Block bandwidth hogs + VPN/torrent ports for airline wifi'

New-AdminShortcut -LinkPath (Join-Path $desktop 'Flight Wifi OFF.lnk') `
    -Target (Join-Path $here 'flight-off.cmd') `
    -IconRef "$env:SystemRoot\System32\imageres.dll,101" `
    -Desc 'Remove all airline-wifi blocks'

Write-Host "Created 'Flight Wifi ON' and 'Flight Wifi OFF' on your Desktop." -ForegroundColor Green
Write-Host "Right-click each -> 'Pin to taskbar' (or drag onto the taskbar) for one-click buttons." -ForegroundColor DarkGray
