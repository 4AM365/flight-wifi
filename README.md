# flight-wifi

One-click "airplane wifi" mode for Windows — keeps your machine from tripping the
**throttle** and **boot** triggers on airline wifi (Southwest specifically, but it's generic).

It can't make a VPN *work* (airline wifi uses deep packet inspection to block VPNs), but it stops
your own machine from quietly trimming your bandwidth or getting you booted in the background:

- **Blocks bandwidth-hog apps** outbound (OneDrive, Dropbox, Google Drive, Steam, Zoom, Teams,
  Slack, Signal — whichever are installed).
- **Blocks VPN + BitTorrent ports** outbound, so a VPN client can't silently auto-reconnect and
  get your session dropped.
- **Stops running VPN clients** (Nord, Express, WireGuard, Proton, Mullvad, etc.).

All blocks live in a single Windows Firewall rule group (`FlightWifi`) that's created on `on` and
fully removed on `off`. Nothing is left behind.

## Use it

**Simplest:** double-click `flight-on.cmd` when you board, `flight-off.cmd` when you land.
(Each asks for admin — firewall changes require it.)

**Taskbar buttons:** run `Create-Shortcuts.ps1` once → two shortcuts land on your Desktop
(`Flight Wifi ON` / `OFF`, pre-set to run as admin). Right-click → *Pin to taskbar*.

**From a terminal:**
```powershell
.\flight-wifi.ps1 on       # board
.\flight-wifi.ps1 off      # land
.\flight-wifi.ps1 status   # see what's blocked / what VPN is running (no admin needed)
```

## Still on you

- **Don't open** Netflix / YouTube / a Zoom call in the browser — those are throttled by traffic
  shape, not by app, so a firewall rule can't catch the browser without breaking normal use.
- **Recommended:** mark the wifi as a **metered connection** (Settings → Network & internet →
  Wi-Fi → the network → *Metered connection: On*). That suppresses Windows Update, Store, and a lot
  of background sync that this script doesn't.

## Tweak the lists

Open `flight-wifi.ps1` and edit `$exeCandidates` (add your own hog apps), `$blockPorts`, or
`$vpnProcs`. Only exe paths that actually exist get a rule, so the list is safe to overstuff.

> Heads-up: airline throttle/boot behavior is **empirical, not a published spec**, and Southwest
> runs three different systems (legacy Anuvu, Viasat, Starlink) that behave differently. This
> targets the well-known triggers; it's belt-and-suspenders, not a guarantee.
