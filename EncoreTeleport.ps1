# Encore Teleport v5.0 - desktop companion app for the "Encore Teleport" and "Skill Saver" Borderlands 4 mods.
# Lists every saved Moxxi's Big Encore machine (and teleporter) by boss, grouped by map, and
# teleports you there. Dark mode, one column - all other data stays in the saved file and is shown
# as a tooltip when you hover over a boss.
#
# v4.1: search box, pinned favorites, checklist of main-world bosses not found yet, cross-map
#       queue (pick a boss on another map, travel there, the teleport starts by itself), dark
#       rename dialog (Cancel no longer deletes your own name), keyboard shortcuts.
# v5.0: second page "Skills" (Skill Saver mod v1.1+): save the current skill setup under a name,
#       load it again, overwrite, rename, delete, and reset the skill tree - no keybinds needed.
# v4.5: shows the mod's next-step hint (e.g. "use the teleporter in front of you") - mod v3.22+.
# v4.4: bosses on other maps: mod v3.19+ fast-travels there by itself (queue bar says so).
# v4.3: boss arena exits ("Bossexit / ...") are hidden; group count fixed for single entries.
# v4.2: map names come from the game (zone display name saved by mod v3.15+), region in tooltip.
#
# Keys (Bosses page):  type = search   Enter = teleport   Backspace = go back   F2 = rename
#                     Ctrl+D = favorite on/off   Ctrl+Up/Down = move favorite   Ctrl+N = nearest   Esc = clear search
# v5.8: Pin -> Favorite. FAVORITES are a fixed-order list (places 1-5 get the mod's favorite keys);
#       the list is written to sdk_mods/EncoreTeleport_favorites.json for the Encore Teleport mod v3.25+.
# Keys (Skills page):  Enter = load   F2 = rename   Del = delete   Ctrl+S = save new
# Ctrl+Tab switches between the pages.
#
# Runs on Windows PowerShell 5.1 (built into Windows) - nothing to install.

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

try {
    Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public static class EtDark {
    [DllImport("dwmapi.dll")] static extern int DwmSetWindowAttribute(IntPtr h, int attr, ref int val, int size);
    [DllImport("uxtheme.dll", CharSet = CharSet.Unicode)] static extern int SetWindowTheme(IntPtr h, string app, string id);
    public static void TitleBar(IntPtr h) { int on = 1; if (DwmSetWindowAttribute(h, 20, ref on, 4) != 0) DwmSetWindowAttribute(h, 19, ref on, 4); }
    public static void Theme(IntPtr h) { SetWindowTheme(h, "DarkMode_Explorer", null); }
}
"@
} catch { }

$AppVersion   = '5.12'
$StationsName = 'EncoreTeleport_stations.json'
$StatusName   = 'EncoreTeleport_status.json'
$CommandName  = 'EncoreTeleport_command.json'
$SettingsDir  = Join-Path $env:APPDATA 'EncoreTeleport'
$SettingsFile = Join-Path $SettingsDir 'settings.json'
$MainWorld    = 'World_P'
$SkStatusName  = 'SkillSaver_status.json'
$SkCommandName = 'SkillSaver_command.json'
$SkSkipFiles   = @('SkillSaver_status.json', 'SkillSaver_command.json', 'SkillSaver_gear_now.json', 'SkillSaver_undo.json', 'SkillSaver_app.json')

# ---------------- colors (dark mode) ----------------
function Rgb([int]$r, [int]$g, [int]$b) { return [System.Drawing.Color]::FromArgb($r, $g, $b) }
$C = @{
    Bg      = Rgb 30 30 30
    List    = Rgb 37 37 38
    Group   = Rgb 48 48 52
    Input   = Rgb 45 45 48
    Fg      = Rgb 230 230 230
    Dim     = Rgb 150 150 150
    Other   = Rgb 135 135 135
    Missing = Rgb 105 105 105
    Accent  = Rgb 235 185 85
    Pin     = Rgb 120 180 240
    Ok      = Rgb 110 200 120
    Bad     = Rgb 235 105 105
    Warn    = Rgb 235 160 70
    Btn     = Rgb 58 58 62
    BtnEdge = Rgb 80 80 86
}

# Friendly names for the internal map names (anything else: "_P" removed, "_" -> space)
$MapNames = @{
    'World_P'     = 'Kairos (main world)'
    'Elpis_P'     = 'Elpis'
    'Harmonica_P' = 'Providence Island'
}
$script:GameMapNames = @{}   # world -> display name read from the game by the mod ("mapname")
function Get-MapName([string]$w) {
    if ([string]::IsNullOrEmpty($w)) { return '(unknown map)' }
    if ($MapNames.ContainsKey($w)) { return $MapNames[$w] }
    if ($script:GameMapNames.ContainsKey($w)) { return $script:GameMapNames[$w] }
    return (($w -replace '_P$', '') -replace '_', ' ')
}

# ---------------- main-world boss checklist ----------------
# From community boss lists - not official and possibly incomplete. Keys are matched (lower case,
# letters/digits only) against the name, boss and encounter of every saved entry.
$KnownBosses = @(
    @{ N = 'Splashzone';                         K = @('splashzone', 'psychoglidepack'); H = 'Main mission: Recruitment Drive (Riptide Grotto, Fadefields)' }
    @{ N = 'Voraxis';                            K = @('voraxis');                       H = 'Coastal Bonescape' }
    @{ N = 'Horace';                             K = @('horace');                        H = 'Hungering Plain' }
    @{ N = 'Sidney Pointylegs';                  K = @('sidney', 'pointylegs');          H = 'Hungering Plain' }
    @{ N = 'Mimicron';                           K = @('mimicron');                      H = "Order bunker Tipping Point (Idolator's Noose)" }
    @{ N = 'Fractis';                            K = @('fractis');                       H = 'Order bunker The Crawlcroft (Grindstone of the Worthy)' }
    @{ N = 'Core Observer';                      K = @('coreobserver');                  H = 'Order bunker Blacklime (The Howl)' }
    @{ N = 'The Divisioner';                     K = @('divisioner');                    H = 'Order bunker The Wireworks (The Low Leys)' }
    @{ N = 'Directive-0';                        K = @('directive');                     H = 'Order bunker Ironwall Resolve (Terminus District)' }
    @{ N = 'Callous Harbinger of Annihilating Death'; K = @('callous');                 H = "Order bunker Craven's Nook (Heart of the Mountain)" }
    @{ N = 'Genone';                             K = @('genone');                        H = 'Side mission: Fault Hunting (The Yawning Yard, Carcadia Burn)' }
    @{ N = 'Bango & Pango';                      K = @('pango', 'bango');                H = 'Ripper drill site (Lopside)' }
    @{ N = 'The Battle Wagon';                   K = @('battlewagon');                   H = 'Ripper drill site (Stoneblood Forest)' }
    @{ N = 'Foundry Freaks (Sal, Hank & Frank)'; K = @('foundry', 'furnace', 'welder');  H = 'Pitter Stain ripper drill site (Fadefields)' }
    @{ N = 'The Backhive';                       K = @('backhive');                      H = 'Abandoned auger mine (Dissected Plateau)' }
    @{ N = 'Skull Orchid';                       K = @('orchid');                        H = 'Abandoned auger mine (Grindstone of the Worthy)' }
    @{ N = 'Rocken Roller';                      K = @('rockenroller', 'rockandroll');   H = 'Abandoned auger mine (Ruined Sumplands)' }
    @{ N = 'Bramblesong';                        K = @('bramblesong');                   H = 'Abandoned auger mine (Stoneblood Forest)' }
    @{ N = 'Shadowpelt';                         K = @('shadowpelt', 'stealthcat');      H = 'Abandoned auger mine (Cuspid Climb)' }
    @{ N = 'Axemaul';                            K = @('axemaul');                       H = 'Carcadia District' }
    @{ N = 'Vile Prototype';                     K = @('vileprototype');                 H = 'Windspear' }
    @{ N = 'Vile Ted & Experiments';             K = @('vileted');                       H = 'Side mission: Below the Surface (Dominion)' }
    @{ N = 'The Oppressor';                      K = @('oppressor');                     H = 'Dissected Plateau' }
    @{ N = 'Bio-Bulkhead';                       K = @('bulkhead');                      H = 'Dissected Plateau' }
    @{ N = 'Driller Hole';                       K = @('drillerhole', 'drillerboss');    H = 'Tonnage Peel' }
    @{ N = 'Sludgemaw';                          K = @('sludgemaw');                     H = 'Side mission: All Charged Up (Watershed Gate, Fadefields)' }
    @{ N = 'Leader Willem';                      K = @('willem');                        H = "Side mission: The Mole's Gambit (The Excrucible, Carcadia Burn)" }
    @{ N = 'Skyspanner Kratch';                  K = @('kratch', 'skyspanner');          H = 'Cuspid Climb' }
    @{ N = 'Arjay';                              K = @('arjay');                         H = 'Main mission: Secrets of the Vault (Upper Dominion)' }
)
function Get-Norm([string]$t) { if (-not $t) { return '' }; return ($t.ToLower() -replace '[^a-z0-9]', '') }

# ---------------- settings (sdk_mods folder + pinned favorites) ----------------
$script:Favorites = New-Object System.Collections.Generic.List[string]

function Save-Settings {
    try {
        if (-not (Test-Path -LiteralPath $SettingsDir)) { New-Item -ItemType Directory -Path $SettingsDir | Out-Null }
        @{ sdk_mods = $script:SdkMods; favorites = @($script:Favorites) } | ConvertTo-Json | Set-Content -LiteralPath $SettingsFile -Encoding UTF8
    } catch { }
    # the Encore Teleport mod reads the favorites (in this order) for its favorite keys
    if ($script:SdkMods) {
        try {
            $json = '{"favorites": ' + (ConvertTo-Json -InputObject @($script:Favorites) -Compress) + '}'
            [System.IO.File]::WriteAllText((Join-Path $script:SdkMods 'EncoreTeleport_favorites.json'), $json, (New-Object System.Text.UTF8Encoding($false)))
        } catch { }
    }
}

function Read-SettingsFile {
    if (-not (Test-Path -LiteralPath $SettingsFile)) { return $null }
    try { return (Get-Content -LiteralPath $SettingsFile -Raw | ConvertFrom-Json) } catch { return $null }
}

# ---------------- sdk_mods folder ----------------
function Test-SdkMods([string]$dir) {
    if ([string]::IsNullOrWhiteSpace($dir)) { return $false }
    if (-not (Test-Path -LiteralPath $dir -PathType Container)) { return $false }
    if (Test-Path -LiteralPath (Join-Path $dir $StationsName)) { return $true }
    return ((Split-Path -Leaf $dir) -ieq 'sdk_mods')
}

function Find-SdkMods($saved) {
    $c = New-Object System.Collections.Generic.List[string]
    $c.Add($PSScriptRoot)
    if ($saved -and $saved.sdk_mods) { $c.Add([string]$saved.sdk_mods) }
    foreach ($drive in [System.IO.DriveInfo]::GetDrives()) {
        if ($drive.DriveType -ne 'Fixed') { continue }
        $r = $drive.RootDirectory.FullName
        $c.Add((Join-Path $r 'SteamLibrary\steamapps\common\Borderlands 4\sdk_mods'))
        $c.Add((Join-Path $r 'Program Files (x86)\Steam\steamapps\common\Borderlands 4\sdk_mods'))
        $c.Add((Join-Path $r 'Steam\steamapps\common\Borderlands 4\sdk_mods'))
        $c.Add((Join-Path $r 'Program Files\Epic Games\Borderlands4\sdk_mods'))
    }
    foreach ($d in $c) { if (Test-SdkMods $d) { return $d } }
    return $null
}

function Select-SdkMods {
    $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
    $dlg.Description = 'Select the "sdk_mods" folder inside your Borderlands 4 installation'
    if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        if (Test-SdkMods $dlg.SelectedPath) { return $dlg.SelectedPath }
        [System.Windows.Forms.MessageBox]::Show('That is not the sdk_mods folder.', 'Encore Teleport') | Out-Null
    }
    return $null
}

$saved = Read-SettingsFile
if ($saved -and $saved.favorites) { foreach ($f in @($saved.favorites)) { if ($f) { $script:Favorites.Add([string]$f) } } }
$script:SdkMods = Find-SdkMods $saved
if (-not $script:SdkMods) { $script:SdkMods = Select-SdkMods }
if (-not $script:SdkMods) { exit }
$favFile = Join-Path $script:SdkMods 'EncoreTeleport_favorites.json'
if (Test-Path -LiteralPath $favFile) {
    try {
        $fj = [System.IO.File]::ReadAllText($favFile) | ConvertFrom-Json
        if ($fj -and $null -ne $fj.favorites) {
            $script:Favorites.Clear()
            foreach ($f in @($fj.favorites)) { if ($f -and -not $script:Favorites.Contains([string]$f)) { $script:Favorites.Add([string]$f) } }
        }
    } catch { }
}
Save-Settings

# ---------------- data ----------------
$script:Stations      = @{}
$script:StationsStamp = [datetime]::MinValue
$script:Status        = $null
$script:CmdId         = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
$script:LastSig       = ''
$script:Filter        = ''
$script:LastDiag      = ''
$script:Mode          = 'boss'      # 'boss' | 'skills'
$script:SkStatus      = $null
$script:SkSaves       = @()
$script:SkSig         = ''
$script:SkLastMsg     = ''


function Read-Json([string]$path) {
    for ($i = 0; $i -lt 3; $i++) {
        try {
            # full sharing so the game can always replace the file while we read it
            $fs = [System.IO.File]::Open($path, 'Open', 'Read', 'ReadWrite, Delete')
            try {
                $sr = New-Object System.IO.StreamReader($fs, [System.Text.Encoding]::UTF8)
                $text = $sr.ReadToEnd()
                $sr.Close()
            } finally { $fs.Dispose() }
            return ($text | ConvertFrom-Json)
        } catch { Start-Sleep -Milliseconds 50 }
    }
    return $null
}

function Update-Data {
    $script:Status = $null
    $st = Join-Path $script:SdkMods $StatusName
    if (Test-Path -LiteralPath $st) {
        $s = Read-Json $st
        $now = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds() / 1000.0
        if ($s -and ($now - [double]$s.time) -lt 5) { $script:Status = $s }
    }
    $sf = Join-Path $script:SdkMods $StationsName
    if (-not (Test-Path -LiteralPath $sf)) { $script:Stations = @{}; return }
    $stamp = (Get-Item -LiteralPath $sf).LastWriteTimeUtc
    $countDiffers = $script:Status -and ($null -ne $script:Status.total) -and ([int]$script:Status.total -ne $script:Stations.Count)
    if ($stamp -ne $script:StationsStamp -or $countDiffers) {
        $data = Read-Json $sf
        if ($data) {
            $map = @{}
            if ($data.stations) { foreach ($p in $data.stations.PSObject.Properties) { $map[$p.Name] = $p.Value } }
            $script:Stations = $map
            $script:StationsStamp = $stamp
            # favorites whose entry no longer exists (removed) are dropped, so the key places stay right
            if ($map.Count) {
                $gone = @($script:Favorites | Where-Object { -not $map.ContainsKey($_) })
                if ($gone.Count) { foreach ($g in $gone) { [void]$script:Favorites.Remove($g) }; Save-Settings; $script:LastSig = '' }
            }
            $names = @{}
            foreach ($v in $map.Values) { if ($v.mapname -and $v.world) { $names[[string]$v.world] = [string]$v.mapname } }
            $script:GameMapNames = $names
        }
    }
}

function Send-Command([string]$action, [string]$key = '', [string]$label = '', $extra = $null) {
    if (-not $script:Status) {
        [System.Windows.Forms.MessageBox]::Show('The game is not running or the Encore Teleport mod is disabled.', 'Encore Teleport') | Out-Null
        return $false
    }
    $script:CmdId++
    $msg = @{ id = $script:CmdId; action = $action; key = $key; label = $label }
    if ($extra) { foreach ($k in $extra.Keys) { $msg[$k] = $extra[$k] } }
    $json = $msg | ConvertTo-Json -Compress
    $target = Join-Path $script:SdkMods $CommandName
    $tmp = $target + '.tmp'
    [System.IO.File]::WriteAllText($tmp, $json, (New-Object System.Text.UTF8Encoding($false)))
    Move-Item -LiteralPath $tmp -Destination $target -Force
    $lblInfo.Text = "Command sent: $action"
    return $true
}

# ---------------- Skill Saver data ----------------
$CharNames = @{ 'corpohacker' = 'Loveless'; 'darksiren' = 'Vex'; 'exosoldier' = 'Rafa'; 'paladin' = 'Amon'; 'gravitar' = 'Harlowe'; 'robodealer' = 'C4SH' }
function Get-CharName([string]$cls) {
    if (-not $cls) { return '?' }
    $l = $cls.ToLower()
    foreach ($k in $CharNames.Keys) { if ($l.Contains($k)) { return $CharNames[$k] } }
    return (($cls -replace '^BPChar_', '') -replace '_C$', '')
}

# character key from the skill tree names (old saves only have "OakCharacter")
function Get-CharKey($d) {
    $c = ([string]$d.character).ToLower()
    foreach ($k in $CharNames.Keys) { if ($c.Contains($k)) { return $k } }
    foreach ($g in @($d.graphs)) {
        $n = ([string]$g.name).ToLower()
        if ($n -notmatch 'action_?skill|_mods_') { continue }
        if ($n.Contains('corpohacker')) { return 'corpohacker' }
        if ($n.Contains('darksiren')) { return 'darksiren' }
        if ($n.Contains('_exo_')) { return 'exosoldier' }
        if ($n.Contains('_grav_')) { return 'gravitar' }
        if ($n.Contains('paladin')) { return 'paladin' }
        if ($n.Contains('_robo_')) { return 'robodealer' }
    }
    return [string]$d.character
}

function Update-SkillData {
    $script:SkStatus = $null
    $st = Join-Path $script:SdkMods $SkStatusName
    if (Test-Path -LiteralPath $st) {
        $s = Read-Json $st
        $now = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds() / 1000.0
        if ($s -and ($now - [double]$s.time) -lt 5) { $script:SkStatus = $s }
    }
    # parsed saves are cached per file and only re-read when the file changed
    if (-not $script:SkCache) { $script:SkCache = @{} }
    $seen = @{}
    $saves = @(foreach ($f in @(Get-ChildItem -LiteralPath $script:SdkMods -Filter 'SkillSaver_*.json' -File -ErrorAction SilentlyContinue)) {
        if ($SkSkipFiles -contains $f.Name) { continue }
        $seen[$f.FullName] = $true
        $stamp = "$($f.LastWriteTimeUtc.Ticks)|$($f.Length)"
        $c = $script:SkCache[$f.FullName]
        if ($c -and $c.Stamp -eq $stamp) { if ($c.Obj) { $c.Obj }; continue }
        $obj = $null
        $d = Read-Json $f.FullName
        if ($d -and $d.graphs) {
            $id = $f.BaseName.Substring('SkillSaver_'.Length)
            $name = if ($d.name) { [string]$d.name } elseif ($id -match '^slot(\d)$') { "Slot $($Matches[1])" } else { $id }
            $pts = if ($null -ne $d.points) { [int]$d.points } else {
                $sum = 0; foreach ($g in @($d.graphs)) { if ($g.kind -eq 'points') { foreach ($n in @($g.nodes)) { $sum += [int]$n.spent } } }; $sum }
            $obj = [pscustomobject]@{ Id = $id; Name = $name; Saved = [string]$d.saved; Char = (Get-CharKey $d); Points = $pts
                           Choices = $d.choices; File = $f.FullName; Key = ($id -match '^slot\d$')
                           Gear = @($d.gear | Where-Object { $_ }); Spec = @($d.spec | Where-Object { $_ }); Notes = [string]$d.notes; Loadout = $d.loadout }
        }
        $script:SkCache[$f.FullName] = @{ Stamp = $stamp; Obj = $obj }
        if ($obj) { $obj }
    })
    foreach ($k in @($script:SkCache.Keys)) { if (-not $seen.ContainsKey($k)) { $script:SkCache.Remove($k) } }   # deleted files
    $script:SkSaves = $saves
    # undo point written by the mod before every load
    $script:SkUndo = $null
    $uf = Join-Path $script:SdkMods 'SkillSaver_undo.json'
    if (Test-Path -LiteralPath $uf) {
        $u = Read-Json $uf
        if ($u -and $u.graphs) { $script:SkUndo = [pscustomobject]@{ Name = [string]$u.name; Of = [string]$u.undo_of; Saved = [string]$u.saved } }
    }
    # live gear (serials) for the gear check
    $script:GearNow = $null
    $gf = Join-Path $script:SdkMods 'SkillSaver_gear_now.json'
    if ($script:SkStatus -and (Test-Path -LiteralPath $gf)) {
        $gn = Read-Json $gf
        $now = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds() / 1000.0
        if ($gn -and ($now - [double]$gn.time) -lt 30) {
            $eq = @{}; foreach ($p in $gn.equipped.PSObject.Properties) { $eq[[string]$p.Value] = $true }
            $bag = @{}; foreach ($x in @($gn.backpack)) { $bag[[string]$x] = $true }
            $script:GearNow = @{ Equipped = $eq; Bag = $bag }
        }
    }
}

function Send-SkillCommand([string]$action, [string]$slot = '', [string]$name = '') {
    if (-not $script:SkStatus) {
        [System.Windows.Forms.MessageBox]::Show('The game is not running or the Skill Saver mod (v1.1+) is disabled.', 'Skill Saver') | Out-Null
        return $false
    }
    $script:CmdId++
    $json = @{ id = $script:CmdId; action = $action; slot = $slot; name = $name } | ConvertTo-Json -Compress
    $target = Join-Path $script:SdkMods $SkCommandName
    $tmp = $target + '.tmp'
    [System.IO.File]::WriteAllText($tmp, $json, (New-Object System.Text.UTF8Encoding($false)))
    Move-Item -LiteralPath $tmp -Destination $target -Force
    $lblInfo.Text = "Command sent: $action"
    return $true
}

function Get-AutoName($s) {
    if ($s.boss) { return [string]$s.boss }
    if ($s.encounter) { return [string]$s.encounter }
    return '(boss unknown)'
}

# The game shows a different text on some machines than the boss name (key: letters/digits only, lower case)
$BossAliases = @{
    'psychoglidepack' = 'Splashzone'     # Recruitment Drive - the machine's own text is "Psycho Glide Pack"
}

function Get-Name($s) {
    $n = if ($s.label) { [string]$s.label } else { Get-AutoName $s }
    if (-not $s.label) { $a = $BossAliases[(Get-Norm $n)]; if ($a) { $n = $a } }
    if ($s.kind -eq 'travel') { $n += '  -  Teleporter' }
    return $n
}

function Get-Dist($s) {
    if (-not $script:Status -or $null -eq $script:Status.x -or $s.world -ne $script:Status.world) { return $null }
    $dx = [double]$s.x - [double]$script:Status.x
    $dy = [double]$s.y - [double]$script:Status.y
    $dz = [double]$s.z - [double]$script:Status.z
    return [math]::Sqrt($dx * $dx + $dy * $dy + $dz * $dz) / 100.0
}

function Get-Tip($s, $d) {
    $lines = @()
    if ($s.label -and $s.boss) { $lines += "Boss: $($s.boss)" }
    if ($s.region) { $lines += "Region: $($s.region)" }
    if ($s.encounter) { $lines += "Encounter: $($s.encounter)" }
    $lines += "Map: $(Get-MapName ([string]$s.world))"
    if ($null -ne $d) { $lines += ('Distance: {0:N0} m' -f $d) }
    if ($null -ne $s.sx) { $lines += 'Standing spot saved' }
    return ($lines -join "`r`n")
}

function Test-Filter([string[]]$texts) {
    if (-not $script:Filter) { return $true }
    foreach ($t in $texts) { if ($t -and $t.ToLower().Contains($script:Filter)) { return $true } }
    return $false
}

# ---------------- UI ----------------
$form = New-Object System.Windows.Forms.Form
$form.Text = "Encore Teleport $AppVersion"
$form.Size = New-Object System.Drawing.Size(470, 680)
$form.MinimumSize = New-Object System.Drawing.Size(380, 360)
$form.StartPosition = 'CenterScreen'
$form.TopMost = $true
$form.KeyPreview = $true
$form.BackColor = $C.Bg
$form.ForeColor = $C.Fg
$form.Font = New-Object System.Drawing.Font('Segoe UI', 9)
$form.Add_HandleCreated({ try { [EtDark]::TitleBar($form.Handle) } catch { } })

$tips = New-Object System.Windows.Forms.ToolTip

function New-DarkButton([string]$text, [int]$width) {
    $b = New-Object System.Windows.Forms.Button
    $b.Text = $text; $b.Width = $width; $b.Height = 30
    $b.FlatStyle = 'Flat'
    $b.BackColor = $C.Btn
    $b.ForeColor = $C.Fg
    $b.FlatAppearance.BorderColor = $C.BtnEdge
    $b.FlatAppearance.MouseOverBackColor = (Rgb 72 72 78)
    $b.FlatAppearance.MouseDownBackColor = (Rgb 90 90 96)
    $b.UseVisualStyleBackColor = $false
    $b.TabStop = $false
    return $b
}

$lblStatus = New-Object System.Windows.Forms.Label
$lblStatus.Dock = 'Top'
$lblStatus.Height = 30
$lblStatus.TextAlign = 'MiddleLeft'
$lblStatus.AutoEllipsis = $true
$lblStatus.Padding = New-Object System.Windows.Forms.Padding(10, 0, 0, 0)
$lblStatus.Font = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)

# queue bar (only visible while a cross-map teleport is queued)
$queueBar = New-Object System.Windows.Forms.Panel
$queueBar.Dock = 'Top'
$queueBar.Height = 34
$queueBar.BackColor = (Rgb 40 52 70)
$queueBar.Visible = $false
$lblQueue = New-Object System.Windows.Forms.Label
$lblQueue.Dock = 'Fill'
$lblQueue.TextAlign = 'MiddleLeft'
$lblQueue.AutoEllipsis = $true
$lblQueue.Padding = New-Object System.Windows.Forms.Padding(10, 0, 0, 0)
$lblQueue.ForeColor = $C.Pin
$btnUnqueue = New-DarkButton 'Cancel' 70
$btnUnqueue.Dock = 'Right'
$queueBar.Controls.Add($lblQueue)
$queueBar.Controls.Add($btnUnqueue)

# search
$searchBar = New-Object System.Windows.Forms.Panel
$searchBar.Dock = 'Top'
$searchBar.Height = 34
$searchBar.Padding = New-Object System.Windows.Forms.Padding(10, 5, 10, 5)
$lblSearch = New-Object System.Windows.Forms.Label
$lblSearch.Text = 'Search'
$lblSearch.Dock = 'Left'
$lblSearch.Width = 52
$lblSearch.TextAlign = 'MiddleLeft'
$lblSearch.ForeColor = $C.Dim
$txtSearch = New-Object System.Windows.Forms.TextBox
$txtSearch.Dock = 'Fill'
$txtSearch.BorderStyle = 'FixedSingle'
$txtSearch.BackColor = $C.Input
$txtSearch.ForeColor = $C.Fg
$txtSearch.Font = New-Object System.Drawing.Font('Segoe UI', 10)
$searchBar.Controls.Add($txtSearch)
$searchBar.Controls.Add($lblSearch)

$list = New-Object System.Windows.Forms.ListView
$list.Dock = 'Fill'
$list.View = 'Details'
$list.HeaderStyle = 'None'
$list.FullRowSelect = $true
$list.MultiSelect = $false
$list.HideSelection = $false
$list.ShowItemToolTips = $true
$list.BorderStyle = 'None'
$list.BackColor = $C.List
$list.ForeColor = $C.Fg
$list.Font = New-Object System.Drawing.Font('Segoe UI', 10.5)
[void]$list.Columns.Add('Boss', 400)
$rowHeight = New-Object System.Windows.Forms.ImageList
$rowHeight.ImageSize = New-Object System.Drawing.Size(1, 26)   # taller rows
$list.SmallImageList = $rowHeight
$list.Add_HandleCreated({ try { [EtDark]::Theme($list.Handle) } catch { } })
$list.Add_Resize({ if ($list.Columns.Count) { $list.Columns[0].Width = [math]::Max(100, $list.ClientSize.Width - 2) } })
$fontGroup   = New-Object System.Drawing.Font('Segoe UI', 9.5, [System.Drawing.FontStyle]::Bold)
$fontMissing = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Italic)

$panel = New-Object System.Windows.Forms.FlowLayoutPanel
$panel.Dock = 'Bottom'
$panel.AutoSize = $true
$panel.AutoSizeMode = 'GrowAndShrink'
$panel.WrapContents = $true
$panel.Padding = New-Object System.Windows.Forms.Padding(6, 7, 6, 6)
$panel.BackColor = $C.Bg
$btnGo      = New-DarkButton 'Teleport' 80
$btnNearest = New-DarkButton 'Nearest' 70
$btnBack    = New-DarkButton 'Go back' 70
$btnPin     = New-DarkButton 'Favorite' 80
$btnFavUp   = New-DarkButton ([string][char]0x25B2) 30
$btnFavDown = New-DarkButton ([string][char]0x25BC) 30
$btnRename  = New-DarkButton 'Rename...' 78
$btnFolder  = New-DarkButton 'Folder...' 70
$btnKeys    = New-DarkButton 'Keys...' 62
$btnGo.ForeColor = $C.Accent
$btnPin.ForeColor = $C.Pin
foreach ($b in @($btnGo, $btnNearest, $btnBack, $btnPin, $btnFavUp, $btnFavDown, $btnRename, $btnKeys, $btnFolder)) { $panel.Controls.Add($b) }
$tips.SetToolTip($btnGo, 'Teleport to the selected boss (Enter). On another map the mod fast-travels there first (mod v3.19+).')
$tips.SetToolTip($btnNearest, 'Nearest Encore machine on this map (Ctrl+N)')
$tips.SetToolTip($btnBack, 'Back to where you were before the last teleport (Backspace)')
$tips.SetToolTip($btnPin, 'Add / remove the selected boss as favorite (Ctrl+D). Places 1-5 can be reached in game with the favorite keys.')
$tips.SetToolTip($btnFavUp, 'Move the selected favorite one place up (Ctrl+Up)')
$tips.SetToolTip($btnFavDown, 'Move the selected favorite one place down (Ctrl+Down)')
$tips.SetToolTip($btnRename, 'Own name for the selected boss (F2)')
$tips.SetToolTip($btnFolder, 'Choose the sdk_mods folder')
$tips.SetToolTip($btnKeys, 'Change the in-game keys for favorites 1-5 (the game must be running)')

$lblInfo = New-Object System.Windows.Forms.Label
$lblInfo.Dock = 'Bottom'
$lblInfo.Height = 20
$lblInfo.AutoEllipsis = $true
$lblInfo.Padding = New-Object System.Windows.Forms.Padding(10, 0, 0, 0)
$lblInfo.ForeColor = $C.Dim
$lblInfo.Text = 'Type to search  |  Enter teleport  |  Backspace back  |  F2 rename  |  Ctrl+D favorite'

# ---------------- page switch + Skills page ----------------
$modeBar = New-Object System.Windows.Forms.FlowLayoutPanel
$modeBar.Dock = 'Top'
$modeBar.Height = 38
$modeBar.Padding = New-Object System.Windows.Forms.Padding(6, 4, 6, 2)
$modeBar.BackColor = $C.Bg
$btnModeBoss   = New-DarkButton 'Bosses' 90
$btnModeSkills = New-DarkButton 'Skills' 90
$modeBar.Controls.Add($btnModeBoss)
$modeBar.Controls.Add($btnModeSkills)
$tips.SetToolTip($btnModeBoss, 'Encore machines and teleporters (Ctrl+Tab)')
$tips.SetToolTip($btnModeSkills, 'Saved skill setups and skill tree reset - needs the Skill Saver mod v1.1+ (Ctrl+Tab)')

$skillList = New-Object System.Windows.Forms.ListView
$skillList.Dock = 'Fill'
$skillList.View = 'Details'
$skillList.HeaderStyle = 'None'
$skillList.FullRowSelect = $true
$skillList.MultiSelect = $false
$skillList.HideSelection = $false
$skillList.ShowItemToolTips = $true
$skillList.BorderStyle = 'None'
$skillList.BackColor = $C.List
$skillList.ForeColor = $C.Fg
$skillList.Font = New-Object System.Drawing.Font('Segoe UI', 10.5)
$skillList.Visible = $false
[void]$skillList.Columns.Add('Build', 400)
$skillList.SmallImageList = $rowHeight
$skillList.Add_HandleCreated({ try { [EtDark]::Theme($skillList.Handle) } catch { } })
$skillList.Add_Resize({ if ($skillList.Columns.Count) { $skillList.Columns[0].Width = [math]::Max(100, $skillList.ClientSize.Width - 2) } })

$skPanel = New-Object System.Windows.Forms.FlowLayoutPanel
$skPanel.Dock = 'Bottom'
$skPanel.AutoSize = $true
$skPanel.AutoSizeMode = 'GrowAndShrink'
$skPanel.WrapContents = $true
$skPanel.Padding = New-Object System.Windows.Forms.Padding(6, 7, 6, 6)
$skPanel.BackColor = $C.Bg
$skPanel.Visible = $false
$btnSkLoad   = New-DarkButton 'Load' 66
$btnSkNew    = New-DarkButton 'Save new...' 86
$btnSkOver   = New-DarkButton 'Overwrite' 76
$btnSkRename = New-DarkButton 'Rename...' 78
$btnSkDelete = New-DarkButton 'Delete' 60
$btnSkReset  = New-DarkButton 'Reset tree' 80
$btnSkGear   = New-DarkButton 'Gear...' 66
$btnSkUndo   = New-DarkButton 'Undo load' 80
$btnSkLoad.ForeColor = $C.Accent
$btnSkNew.ForeColor = $C.Ok
$btnSkDelete.ForeColor = $C.Bad
$btnSkReset.ForeColor = $C.Warn
foreach ($b in @($btnSkLoad, $btnSkUndo, $btnSkNew, $btnSkOver, $btnSkRename, $btnSkGear, $btnSkDelete, $btnSkReset)) { $skPanel.Controls.Add($b) }
$tips.SetToolTip($btnSkUndo, 'Go back to the skill setup you had before the last Load')
$tips.SetToolTip($btnSkGear, 'Type the real gear names and notes for the selected build (text only - gear is not equipped)')

$skDetail = New-Object System.Windows.Forms.TextBox
$skDetail.Dock = 'Bottom'
$skDetail.Height = 210
$skDetail.Multiline = $true
$skDetail.ReadOnly = $true
$skDetail.WordWrap = $false
$skDetail.ScrollBars = 'Both'
$skDetail.BorderStyle = 'None'
$skDetail.BackColor = $C.Input
$skDetail.ForeColor = $C.Fg
$skDetail.Font = New-Object System.Drawing.Font('Consolas', 9.5)
$skDetail.TabStop = $false
$skDetail.Visible = $false
$skDetail.Add_HandleCreated({ try { [EtDark]::Theme($skDetail.Handle) } catch { } })
$tips.SetToolTip($btnSkLoad, 'Load the selected build: resets the tree, then applies all points and choices (Enter)')
$tips.SetToolTip($btnSkNew, 'Save the current skill setup under a new name (Ctrl+S)')
$tips.SetToolTip($btnSkOver, 'Replace the selected save with the current skill setup (keeps the name)')
$tips.SetToolTip($btnSkRename, 'Rename the selected save (F2)')
$tips.SetToolTip($btnSkDelete, 'Delete the selected save (Del)')
$tips.SetToolTip($btnSkReset, 'Reset the skill tree anywhere (like Respec Anywhere) - points only, choices stay')

# dock order: added last = outermost
$form.Controls.Add($list)
$form.Controls.Add($skillList)
$form.Controls.Add($searchBar)
$form.Controls.Add($queueBar)
$form.Controls.Add($panel)
$form.Controls.Add($skDetail)
$form.Controls.Add($skPanel)
$form.Controls.Add($lblInfo)
$form.Controls.Add($modeBar)
$form.Controls.Add($lblStatus)

# ---------------- dark rename dialog ----------------
# returns @{ Action = 'ok' | 'auto' | 'remove' | 'cancel'; Text = '...' }
function Show-RenameDialog([string]$current, [string]$auto) {
    $d = New-Object System.Windows.Forms.Form
    $d.Text = 'Rename'
    $d.FormBorderStyle = 'FixedDialog'
    $d.StartPosition = 'CenterParent'
    $d.ClientSize = New-Object System.Drawing.Size(420, 128)
    $d.MaximizeBox = $false; $d.MinimizeBox = $false; $d.ShowInTaskbar = $false
    $d.TopMost = $true
    $d.BackColor = $C.Bg; $d.ForeColor = $C.Fg
    $d.Font = New-Object System.Drawing.Font('Segoe UI', 9)
    $d.Add_HandleCreated({ try { [EtDark]::TitleBar($d.Handle) } catch { } })

    $l = New-Object System.Windows.Forms.Label
    $l.Text = "Own name   (automatic name: $auto)"
    $l.AutoEllipsis = $true
    $l.SetBounds(12, 10, 396, 20)
    $l.ForeColor = $C.Dim
    $tb = New-Object System.Windows.Forms.TextBox
    $tb.SetBounds(12, 34, 396, 26)
    $tb.BorderStyle = 'FixedSingle'
    $tb.BackColor = $C.Input; $tb.ForeColor = $C.Fg
    $tb.Font = New-Object System.Drawing.Font('Segoe UI', 10)
    $tb.Text = $current

    $bOk = New-DarkButton 'OK' 80;               $bOk.SetBounds(12, 82, 80, 30);  $bOk.DialogResult = 'OK'
    $bAuto = New-DarkButton 'Automatic name' 120; $bAuto.SetBounds(98, 82, 120, 30); $bAuto.DialogResult = 'Retry'
    $bDel = New-DarkButton 'Remove' 80;          $bDel.SetBounds(224, 82, 80, 30); $bDel.DialogResult = 'Abort'; $bDel.ForeColor = $C.Bad
    $bCancel = New-DarkButton 'Cancel' 98;       $bCancel.SetBounds(310, 82, 98, 30); $bCancel.DialogResult = 'Cancel'
    $bOk.ForeColor = $C.Accent
    $d.Controls.AddRange(@($l, $tb, $bOk, $bAuto, $bDel, $bCancel))
    $d.AcceptButton = $bOk
    $d.CancelButton = $bCancel
    $d.Add_Shown({ $tb.SelectAll(); $tb.Focus() })

    $r = $d.ShowDialog($form)
    $text = $tb.Text.Trim()
    $d.Dispose()
    switch ($r) {
        'OK'    { return @{ Action = 'ok'; Text = $text } }
        'Retry' { return @{ Action = 'auto'; Text = '' } }
        'Abort' { return @{ Action = 'remove'; Text = '' } }
        default { return @{ Action = 'cancel'; Text = '' } }
    }
}

# ---------------- dark name dialog (Skills page) ----------------
function Show-NameDialog([string]$title, [string]$current) {
    $d = New-Object System.Windows.Forms.Form
    $d.Text = $title
    $d.FormBorderStyle = 'FixedDialog'
    $d.StartPosition = 'CenterParent'
    $d.ClientSize = New-Object System.Drawing.Size(380, 110)
    $d.MaximizeBox = $false; $d.MinimizeBox = $false; $d.ShowInTaskbar = $false
    $d.TopMost = $true
    $d.BackColor = $C.Bg; $d.ForeColor = $C.Fg
    $d.Font = New-Object System.Drawing.Font('Segoe UI', 9)
    $d.Add_HandleCreated({ try { [EtDark]::TitleBar($d.Handle) } catch { } })
    $l = New-Object System.Windows.Forms.Label
    $l.Text = 'Name of the build'
    $l.SetBounds(12, 10, 356, 20)
    $l.ForeColor = $C.Dim
    $tb = New-Object System.Windows.Forms.TextBox
    $tb.SetBounds(12, 34, 356, 26)
    $tb.BorderStyle = 'FixedSingle'
    $tb.BackColor = $C.Input; $tb.ForeColor = $C.Fg
    $tb.Font = New-Object System.Drawing.Font('Segoe UI', 10)
    $tb.Text = $current
    $bOk = New-DarkButton 'OK' 80;         $bOk.SetBounds(196, 70, 80, 30);     $bOk.DialogResult = 'OK'; $bOk.ForeColor = $C.Accent
    $bCancel = New-DarkButton 'Cancel' 86; $bCancel.SetBounds(282, 70, 86, 30); $bCancel.DialogResult = 'Cancel'
    $d.Controls.AddRange(@($l, $tb, $bOk, $bCancel))
    $d.AcceptButton = $bOk
    $d.CancelButton = $bCancel
    $d.Add_Shown({ $tb.SelectAll(); $tb.Focus() })
    $form.TopMost = $false
    $r = $d.ShowDialog($form)
    $form.TopMost = $true
    $text = $tb.Text.Trim()
    $d.Dispose()
    if ($r -eq 'OK' -and $text) { return $text }
    return $null
}

function Ask-YesNo([string]$text) {
    $form.TopMost = $false
    $r = [System.Windows.Forms.MessageBox]::Show($text, 'Skill Saver', 'YesNo', 'Question')
    $form.TopMost = $true
    return ($r -eq 'Yes')
}

# ---------------- Skills page ----------------
function Update-SkillsView {
    $cur = if ($script:SkStatus) { [string]$script:SkStatus.character } else { '' }
    $saves = @($script:SkSaves | Sort-Object @{ Expression = { $_.Saved }; Descending = $true })
    $entries = New-Object System.Collections.Generic.List[object]
    if ($saves.Count) {
        $entries.Add([pscustomobject]@{ Type = 'H'; Text = ('  SAVED BUILDS  ({0})' -f $saves.Count) })
        foreach ($v in $saves) { $entries.Add([pscustomobject]@{ Type = 'S'; V = $v }) }
    }
    if (-not $entries.Count) {
        $entries.Add([pscustomobject]@{ Type = 'H'; Text = '  No saved builds yet - click "Save new..."' })
    }
    $sig = $cur + '|' + (($entries | ForEach-Object { $x = $_; if ($x.Type -eq 'H') { "#$($x.Text)" } else { "$($x.V.Id)=$($x.V.Name)=$($x.V.Saved)" } }) -join ';')
    if ($sig -ne $script:SkSig -or $skillList.Items.Count -ne $entries.Count) {
        $script:SkSig = $sig
        $sel = if ($skillList.SelectedItems.Count) { $skillList.SelectedItems[0].Tag } else { $null }
        $skillList.BeginUpdate()
        $skillList.Items.Clear()
        foreach ($e in $entries) {
            if ($e.Type -eq 'H') {
                $it = New-Object System.Windows.Forms.ListViewItem($e.Text)
                $it.Font = $fontGroup; $it.ForeColor = $C.Accent; $it.BackColor = $C.Group; $it.Tag = $null
            } else {
                $v = $e.V
                $it = New-Object System.Windows.Forms.ListViewItem(('      {0}      {1} pts' -f $v.Name, $v.Points))
                $it.Tag = $v.Id
                if ($cur -and $v.Char -and $v.Char -ne $cur) { $it.ForeColor = $C.Other }
                $tip = "Saved: $($v.Saved)`r`nCharacter: $(Get-CharName $v.Char)`r`nSkill points: $($v.Points)"
                if ($null -ne $v.Choices) { $tip += "`r`nAction skill / augment / capstone / specialization choices: $($v.Choices)" }
                if ($cur -and $v.Char -and $v.Char -ne $cur) { $tip += "`r`n(other character - can not be loaded on this one)" }
                if ($v.Gear.Count) { $tip += "`r`nGear and specialization: see the box below" }
                $it.ToolTipText = $tip
                if ($v.Id -eq $sel) { $it.Selected = $true }
            }
            [void]$skillList.Items.Add($it)
        }
        $skillList.EndUpdate()
    }
    $st = $script:SkStatus
    if ($st) {
        $who = if ($st.character) { Get-CharName ([string]$st.character) } else { 'no character' }
        $pts = if ($null -ne $st.points) { "   |   $($st.points) points spent" } else { '' }
        $lblStatus.Text = "Skill Saver connected   |   $who$pts"
        $lblStatus.ForeColor = $C.Ok
        if ($st.msg -and [string]$st.msg -ne $script:SkLastMsg) { $script:SkLastMsg = [string]$st.msg; $lblInfo.Text = [string]$st.msg }
    } else {
        $lblStatus.Text = 'Game not running or Skill Saver mod (v1.1+) disabled'
        $lblStatus.ForeColor = $C.Bad
    }
}

$MarkWorn = [string][char]0x2713   # check mark
$MarkBag  = [string][char]0x25CB   # circle
$MarkMiss = [string][char]0x2717   # cross
$SkGearSlots = @('Weapon 1', 'Weapon 2', 'Weapon 3', 'Weapon 4', 'Shield', 'Ordnance', 'Repkit', 'Enhancement', 'Class Mod')

function Get-GearName($g) {
    if ($null -ne $g.title) {
        # v1.8+ saves: name only, element only for weapons and ordnance
        $n = if ($g.name) { [string]$g.name } elseif ($g.title) { [string]$g.title } else { '-' }
        if ($g.element -and ([string]$g.slot -match '^(Weapon|Ordnance)')) { $n += "  ($($g.element))" }
        return $n
    }
    if ($g.name -and $g.auto -and [string]$g.name -ne [string]$g.auto) { return "$($g.name)  ($($g.auto))" }
    if ($g.name) { return [string]$g.name }
    if ($g.auto) { return [string]$g.auto }
    return '-'
}

function Get-SkillDetailText($v) {
    if (-not $v) { return 'Select a build to see its specialization and gear.' }
    $nl = "`r`n"
    $t = ''
    $lo = $v.Loadout
    if ($lo) {
        $t += "ACTION SKILL$nl"
        $t += ('  {0,-12} {1}' -f 'Action Skill', $(if ($lo.action_skill) { [string]$lo.action_skill } else { '-' })) + $nl
        $aug = @($lo.augments | Where-Object { $_ }); $cap = @($lo.capstones | Where-Object { $_ })
        $t += ('  {0,-12} {1}' -f 'Augment', $(if ($aug.Count) { $aug -join ', ' } else { '-' })) + $nl
        $t += ('  {0,-12} {1}' -f 'Capstone', $(if ($cap.Count) { $cap -join ', ' } else { '-' })) + $nl + $nl
    }
    $t += "SPECIALIZATION$nl"
    if ($v.Spec.Count) {
        foreach ($sp in $v.Spec) {
            if ($sp.name) {
                $line = '  {0,-12} {1}' -f [string]$sp.tree, [string]$sp.name
            } else {
                $line = '  {0,-12} Skill {1}' -f [string]$sp.tree, [string]$sp.skill
                if ($sp.hint) { $line += "  - $($sp.hint)" }
            }
            $t += $line + $nl
        }
    } elseif ($null -eq $v.Gear -or -not $v.Gear.Count) {
        $t += "  (not in this save - saved before Skill Saver v1.3, use Overwrite)$nl"
    } else {
        $t += "  (no specialization skills equipped)$nl"
    }
    $gn = $script:GearNow
    $hdr = 'GEAR'
    if ($gn) { $hdr += ('      {0} worn   {1} backpack   {2} not found' -f $MarkWorn, $MarkBag, $MarkMiss) }
    $t += "$nl" + $hdr + $nl
    if ($v.Gear.Count) {
        foreach ($g in $v.Gear) {
            if (-not $g.auto -and -not $g.name -and -not $g.title) { continue }   # empty slot
            $mark = ' '
            if ($gn -and $g.serial) {
                $sr = [string]$g.serial
                $mark = if ($gn.Equipped.ContainsKey($sr)) { $MarkWorn } elseif ($gn.Bag.ContainsKey($sr)) { $MarkBag } else { $MarkMiss }
            }
            $t += ('{0} {1,-12} {2}' -f $mark, [string]$g.slot, (Get-GearName $g)) + $nl
        }
        $fw = [ordered]@{}
        foreach ($g in $v.Gear) {
            if ($g.firmware) {
                $k = [string]$g.firmware
                if (-not $fw.Contains($k)) { $fw[$k] = New-Object System.Collections.Generic.List[string] }
                $fw[$k].Add([string]$g.slot)
            }
        }
        if ($fw.Count) {
            $t += "$nl" + "FIRMWARE$nl"
            foreach ($k in $fw.Keys) { $t += ('  {0,-15} {1}x  {2}' -f $k, $fw[$k].Count, ($fw[$k] -join ', ')) + $nl }
        }
    } else {
        $t += "  (not in this save - use Overwrite, or type it with Gear...)$nl"
    }
    if ($v.Notes) { $t += "$nl" + "NOTES$nl  " + ($v.Notes -replace "`r?`n", "$nl  ") + $nl }
    return $t
}

function Update-SkillDetail {
    $v = $null
    if ($skillList.SelectedItems.Count -and $null -ne $skillList.SelectedItems[0].Tag) {
        $id = [string]$skillList.SelectedItems[0].Tag
        foreach ($x in $script:SkSaves) { if ($x.Id -eq $id) { $v = $x } }
    }
    $t = Get-SkillDetailText $v
    if ($skDetail.Text -ne $t) { $skDetail.Text = $t }
}

function Show-GearDialog($v) {
    $d = New-Object System.Windows.Forms.Form
    $d.Text = "Gear - $($v.Name)"
    $d.FormBorderStyle = 'Sizable'
    $d.StartPosition = 'CenterParent'
    $d.ClientSize = New-Object System.Drawing.Size(460, 330)
    $d.MinimumSize = New-Object System.Drawing.Size(360, 280)
    $d.MaximizeBox = $false; $d.MinimizeBox = $false; $d.ShowInTaskbar = $false
    $d.TopMost = $true
    $d.BackColor = $C.Bg; $d.ForeColor = $C.Fg
    $d.Font = New-Object System.Drawing.Font('Segoe UI', 9)
    $d.Add_HandleCreated({ try { [EtDark]::TitleBar($d.Handle) } catch { } })
    $l = New-Object System.Windows.Forms.Label
    $l.Text = "One line per slot: 'Slot = item name'. Empty = automatic name.`r`nEverything after 'Notes =' (also the following lines) is saved as notes."
    $l.SetBounds(12, 8, 436, 34)
    $l.Anchor = 'Top, Left, Right'
    $l.ForeColor = $C.Dim
    $tb = New-Object System.Windows.Forms.TextBox
    $tb.Multiline = $true; $tb.AcceptsReturn = $true; $tb.ScrollBars = 'Vertical'
    $tb.SetBounds(12, 46, 436, 236)
    $tb.Anchor = 'Top, Bottom, Left, Right'
    $tb.BorderStyle = 'FixedSingle'
    $tb.BackColor = $C.Input; $tb.ForeColor = $C.Fg
    $tb.Font = New-Object System.Drawing.Font('Consolas', 10)
    $byslot = @{}
    foreach ($g in $v.Gear) { $byslot[[string]$g.slot] = $g }
    $lines = foreach ($sl in $SkGearSlots) {
        $g = $byslot[$sl]
        $val = if ($g) { if ($g.name) { [string]$g.name } else { [string]$g.auto } } else { '' }
        '{0} = {1}' -f $sl, $val
    }
    $tb.Text = (@($lines) -join "`r`n") + "`r`nNotes = " + ($v.Notes -replace "`r?`n", "`r`n")
    $bOk = New-DarkButton 'Save' 80;       $bOk.SetBounds(276, 290, 80, 30);     $bOk.DialogResult = 'OK'; $bOk.ForeColor = $C.Accent
    $bCancel = New-DarkButton 'Cancel' 86; $bCancel.SetBounds(362, 290, 86, 30); $bCancel.DialogResult = 'Cancel'
    $bOk.Anchor = 'Bottom, Right'; $bCancel.Anchor = 'Bottom, Right'
    $d.Controls.AddRange(@($l, $tb, $bOk, $bCancel))
    $d.CancelButton = $bCancel
    $d.Add_Shown({ $tb.SelectionStart = 0; $tb.SelectionLength = 0; $tb.Focus() })
    $form.TopMost = $false
    $r = $d.ShowDialog($form)
    $form.TopMost = $true
    $text = $tb.Text
    $d.Dispose()
    if ($r -ne 'OK') { return $null }
    return $text
}

function Invoke-SkGear {
    $v = Get-SelectedSave
    if (-not $v) { return }
    $text = Show-GearDialog $v
    if ($null -eq $text) { return }
    try {
        $d = [System.IO.File]::ReadAllText($v.File) | ConvertFrom-Json
        $byslot = @{}
        foreach ($g in @($d.gear | Where-Object { $_ })) { $byslot[[string]$g.slot] = $g }
        $notes = $null
        foreach ($line in ($text -split "`r?`n")) {
            if ($null -ne $notes) { $notes += "`r`n" + $line; continue }
            if ($line -match '^\s*([^=]+?)\s*=\s*(.*)$') {
                $key = $Matches[1]; $val = $Matches[2].Trim()
                if ($key -eq 'Notes') { $notes = $val; continue }
                $sl = $SkGearSlots | Where-Object { $_ -eq $key } | Select-Object -First 1
                if (-not $sl) { continue }
                if (-not $byslot.ContainsKey($sl)) { $byslot[$sl] = [pscustomobject]@{ slot = $sl; auto = ''; name = '' } }
                $g = $byslot[$sl]
                $nv = if ($val -eq [string]$g.auto) { '' } else { $val }
                $g | Add-Member -NotePropertyName 'name' -NotePropertyValue $nv -Force
            }
        }
        $gear = @(foreach ($sl in $SkGearSlots) { if ($byslot.ContainsKey($sl)) { $byslot[$sl] } })
        $d | Add-Member -NotePropertyName 'gear' -NotePropertyValue $gear -Force
        $nt = if ($null -ne $notes) { $notes.Trim() } else { '' }
        $d | Add-Member -NotePropertyName 'notes' -NotePropertyValue $nt -Force
        [System.IO.File]::WriteAllText($v.File, ($d | ConvertTo-Json -Depth 20), (New-Object System.Text.UTF8Encoding($false)))
        $lblInfo.Text = "Gear notes saved for '$($v.Name)'."
    } catch { [System.Windows.Forms.MessageBox]::Show("Saving failed: $($_.Exception.Message)", 'Skill Saver') | Out-Null }
    Update-SkillData; Update-SkillsView; Update-SkillDetail
}

function Get-SelectedSave {
    if (-not $skillList.SelectedItems.Count -or $null -eq $skillList.SelectedItems[0].Tag) {
        [System.Windows.Forms.MessageBox]::Show('Select a saved build in the list first.', 'Skill Saver') | Out-Null
        return $null
    }
    $id = [string]$skillList.SelectedItems[0].Tag
    foreach ($v in $script:SkSaves) { if ($v.Id -eq $id) { return $v } }
    return $null
}

function Invoke-SkLoad {
    $v = Get-SelectedSave
    if (-not $v) { return }
    if ($script:SkStatus -and $v.Char -and $script:SkStatus.character -and $v.Char -ne [string]$script:SkStatus.character) {
        [System.Windows.Forms.MessageBox]::Show("'$($v.Name)' was saved on $(Get-CharName $v.Char) - it can not be loaded on this character.", 'Skill Saver') | Out-Null
        return
    }
    if (Ask-YesNo "Load '$($v.Name)'?`r`nYour current skill tree is reset first.") { [void](Send-SkillCommand 'load' $v.Id) }
}

function Invoke-SkNew {
    if (-not $script:SkStatus) { [void](Send-SkillCommand 'save'); return }
    $name = Show-NameDialog 'Save new build' ''
    if (-not $name) { return }
    $id = 's' + (Get-Date -Format 'yyyyMMdd_HHmmss')
    [void](Send-SkillCommand 'save' $id $name)
}

function Invoke-SkOverwrite {
    $v = Get-SelectedSave
    if (-not $v) { return }
    if (Ask-YesNo "Replace '$($v.Name)' with your current skill setup?") { [void](Send-SkillCommand 'save' $v.Id $v.Name) }
}

function Invoke-SkRename {
    $v = Get-SelectedSave
    if (-not $v) { return }
    $name = Show-NameDialog 'Rename build' $v.Name
    if (-not $name -or $name -eq $v.Name) { return }
    try {
        $text = [System.IO.File]::ReadAllText($v.File)
        $d = $text | ConvertFrom-Json
        $d | Add-Member -NotePropertyName 'name' -NotePropertyValue $name -Force
        [System.IO.File]::WriteAllText($v.File, ($d | ConvertTo-Json -Depth 20), (New-Object System.Text.UTF8Encoding($false)))
        $lblInfo.Text = "Renamed to '$name'."
    } catch { [System.Windows.Forms.MessageBox]::Show("Rename failed: $($_.Exception.Message)", 'Skill Saver') | Out-Null }
    Update-SkillData; Update-SkillsView
}

function Invoke-SkDelete {
    $v = Get-SelectedSave
    if (-not $v) { return }
    if (Ask-YesNo "Delete '$($v.Name)'? This can not be undone.") {
        try { Remove-Item -LiteralPath $v.File -Force; $lblInfo.Text = "Deleted '$($v.Name)'." } catch { }
        Update-SkillData; Update-SkillsView
    }
}

function Invoke-SkUndo {
    if (-not $script:SkUndo) {
        [System.Windows.Forms.MessageBox]::Show('Nothing to undo yet - the undo point is written on every Load.', 'Skill Saver') | Out-Null
        return
    }
    $of = if ($script:SkUndo.Of) { " (before '$($script:SkUndo.Of)' was loaded)" } else { '' }
    if (Ask-YesNo "Restore the skill setup from $($script:SkUndo.Saved)$of?") { [void](Send-SkillCommand 'load' 'undo') }
}

function Invoke-SkReset {
    if (Ask-YesNo "Reset the skill tree now?`r`nAll skill points become free again (action skill and augment choices stay).") { [void](Send-SkillCommand 'reset') }
}

function Set-Mode([string]$m) {
    $script:Mode = $m
    $boss = ($m -eq 'boss')
    $list.Visible = $boss; $searchBar.Visible = $boss; $panel.Visible = $boss
    if (-not $boss) { $queueBar.Visible = $false }
    $skillList.Visible = -not $boss; $skPanel.Visible = -not $boss; $skDetail.Visible = -not $boss
    $btnModeBoss.ForeColor = if ($boss) { $C.Accent } else { $C.Dim }
    $btnModeSkills.ForeColor = if ($boss) { $C.Dim } else { $C.Accent }
    $script:LastDiag = ''
    if ($boss) {
        $lblInfo.Text = 'Type to search  |  Enter teleport  |  Backspace back  |  F2 rename  |  Ctrl+D favorite'
        $tips.SetToolTip($lblStatus, '')
        Update-Data; Update-List; $list.Focus()
    } else {
        $lblInfo.Text = 'Enter load  |  Ctrl+S save new  |  F2 rename  |  Del delete'
        $tips.SetToolTip($lblStatus, "Folder: $($script:SdkMods)")
        $script:SkSig = ''
        Update-SkillData; Update-SkillsView; Update-SkillDetail; $skillList.Focus()
    }
}

# ---------------- list ----------------
function Update-List {
    $world = if ($script:Status) { [string]$script:Status.world } else { $null }

    $rows = @(foreach ($k in $script:Stations.Keys) {
        $s = $script:Stations[$k]
        # boss arena exits saved by older mod versions (removed from the file by mod v3.16 on game start)
        if (-not $s.label -and $s.kind -ne 'travel' -and ("$($s.encounter) $($s.name)" -match 'exit')) { continue }
        $n = Get-Name $s
        if (-not (Test-Filter @($n, [string]$s.boss, [string]$s.encounter, [string]$s.region, (Get-MapName ([string]$s.world))))) { continue }
        [pscustomobject]@{ Key = $k; S = $s; D = (Get-Dist $s); W = [string]$s.world; N = $n; Pin = $script:Favorites.Contains($k) }
    })
    $byDist = @{ Expression = { if ($null -eq $_.D) { [double]::MaxValue } else { $_.D } } }

    $entries = New-Object System.Collections.Generic.List[object]
    # 1) favorites - fixed order, places 1-5 have the mod's favorite keys
    $pinned = @($rows | Where-Object { $_.Pin } | Sort-Object @{ Expression = { $script:Favorites.IndexOf($_.Key) } })
    if ($pinned.Count) {
        $entries.Add([pscustomobject]@{ Type = 'H'; Text = ('  FAVORITES  ({0})' -f $pinned.Count); Color = $C.Pin })
        $keys = if ($script:Status -and $script:Status.fav_keys) { @($script:Status.fav_keys) } else { @('F5', 'F6', 'F7', 'F8', 'F9') }
        foreach ($r in $pinned) {
            $i = $script:Favorites.IndexOf($r.Key)
            $slot = if ($i -ge 0 -and $i -lt 5) { $k = [string]$keys[$i]; if (-not $k) { $k = '-' }; ('{0} [{1}]' -f ($i + 1), $k) } else { '' }
            $entries.Add([pscustomobject]@{ Type = 'S'; R = $r; ShowMap = $true; Slot = $slot })
        }
    }
    # 2) current map first (by distance), then every other map (by name)
    $rest = @($rows | Where-Object { -not $_.Pin })
    $maps = @($rest | ForEach-Object { $_.W } | Sort-Object -Unique)
    $maps = @(@($maps | Where-Object { $_ -eq $world }) + @($maps | Where-Object { $_ -ne $world } | Sort-Object { Get-MapName $_ }))
    foreach ($m in $maps) {
        $inMap = @($rest | Where-Object { $_.W -eq $m })
        # (wrapped in @() - an if-expression unrolls a one-element array, which then has no .Count)
        $inMap = @(if ($m -eq $world) { $inMap | Sort-Object $byDist } else { $inMap | Sort-Object N })
        $here = if ($m -eq $world) { '   -   you are here' } else { '' }
        $entries.Add([pscustomobject]@{ Type = 'H'; Text = ('  {0}  ({1}){2}' -f (Get-MapName $m).ToUpper(), $inMap.Count, $here); Color = $C.Accent })
        foreach ($r in $inMap) { $entries.Add([pscustomobject]@{ Type = 'S'; R = $r; ShowMap = $false }) }
    }
    # 3) main-world bosses not found yet
    $hay = (@(foreach ($s in $script:Stations.Values) { (Get-Norm ([string]$s.label)) + '|' + (Get-Norm ([string]$s.boss)) + '|' + (Get-Norm ([string]$s.encounter)) }) -join '#')
    $missing = @(foreach ($b in $KnownBosses) {
        $found = $false
        foreach ($k in $b.K) { if ($hay.Contains($k)) { $found = $true; break } }
        if (-not $found -and (Test-Filter @($b.N, $b.H))) { $b }
    })
    if ($missing.Count) {
        $entries.Add([pscustomobject]@{ Type = 'H'; Text = ('  NOT FOUND YET - {0}  ({1})' -f (Get-MapName $MainWorld).ToUpper(), $missing.Count); Color = $C.Dim })
        foreach ($b in $missing) { $entries.Add([pscustomobject]@{ Type = 'M'; B = $b }) }
    }

    # rebuild only when something visible changes (keeps the scroll position steady); tooltips always refresh
    # (inside a switch block $_ is the switch value, so the entry is copied to $x first)
    $sig = $world + '|' + (($entries | ForEach-Object {
        $x = $_
        switch ($x.Type) { 'H' { "#$($x.Text)" } 'S' { "$($x.R.Key)=$($x.R.N)=$($x.Slot)" } 'M' { "?$($x.B.N)" } }
    }) -join ';')
    if ($sig -ne $script:LastSig -or $list.Items.Count -ne $entries.Count) {
        $script:LastSig = $sig
        $sel = if ($list.SelectedItems.Count) { $list.SelectedItems[0].Tag } else { $null }
        $top = if ($list.TopItem) { $list.TopItem.Index } else { 0 }
        $list.BeginUpdate()
        $list.Items.Clear()
        foreach ($e in $entries) {
            switch ($e.Type) {
                'H' {
                    $it = New-Object System.Windows.Forms.ListViewItem($e.Text)
                    $it.Font = $fontGroup; $it.ForeColor = $e.Color; $it.BackColor = $C.Group; $it.Tag = $null
                }
                'S' {
                    $r = $e.R
                    $txt = if ($e.Slot) { ('  {0,-8}' -f $e.Slot) + $r.N } else { '      ' + $r.N }
                    if ($e.ShowMap -and $r.W -ne $world) { $txt += "   ($(Get-MapName $r.W))" }
                    $it = New-Object System.Windows.Forms.ListViewItem($txt)
                    $it.Tag = $r.Key
                    if ($world -and $r.W -ne $world) { $it.ForeColor = $C.Other }
                    if ($r.Key -eq $sel) { $it.Selected = $true }
                }
                'M' {
                    $it = New-Object System.Windows.Forms.ListViewItem(('      ' + $e.B.N))
                    $it.Font = $fontMissing; $it.ForeColor = $C.Missing; $it.Tag = $null
                }
            }
            [void]$list.Items.Add($it)
        }
        if ($top -gt 0 -and $top -lt $list.Items.Count) { try { $list.TopItem = $list.Items[$top] } catch { } }
        $list.EndUpdate()
    }
    $i = 0
    foreach ($e in $entries) {
        if ($e.Type -eq 'S') { $list.Items[$i].ToolTipText = (Get-Tip $e.R.S $e.R.D) }
        elseif ($e.Type -eq 'M') { $list.Items[$i].ToolTipText = "Not found yet: $($e.B.H)`r`n(from a community boss list - may be incomplete)" }
        $i++
    }

    # status line + queue bar
    $st = $script:Status
    $total = $script:Stations.Count
    if ($st) {
        $busy = if ($st.busy) { '   |   teleporting...' } else { '' }
        $lblStatus.Text = "Connected   |   $(Get-MapName $world)   |   $total saved$busy"
        $lblStatus.ForeColor = $C.Ok
        $diag = "Mod v$($st.version)   |   Encore machines loaded near you: $($st.encore_loaded)   |   Interactive objects loaded: $($st.io_loaded)"
        if ($st.last_error) {
            $lblStatus.Text += '   |   error (hover)'
            $lblStatus.ForeColor = $C.Warn
            $diag += "`r`nLast error: $($st.last_error)"
        }
        if ($st.last_used) { $diag += "`r`nLast used object: $($st.last_used)" }
        if ($diag -ne $script:LastDiag) { $script:LastDiag = $diag; $tips.SetToolTip($lblStatus, $diag) }
        $pend = [string]$st.pending
        if ($null -eq $st.pending -and $st.version) {
            # mod older than v3.12: no queue support
            $pend = ''
        }
        if ($pend) {
            $ps = $script:Stations[$pend]
            $where = if ($ps) { Get-MapName ([string]$ps.world) } else { 'its map' }
            if ($st.hint) {
                $lblQueue.Text = [string]$st.hint
            } elseif ($st.travelling) {
                $lblQueue.Text = "Travelling to $where for $($st.pending_name) ...  the teleport follows after loading."
            } else {
                $lblQueue.Text = "Queued: $($st.pending_name)  -  travel to $where, the teleport starts by itself."
            }
            $queueBar.Visible = $true
        } else {
            $queueBar.Visible = $false
        }
    } else {
        $lblStatus.Text = "Game not running or mod disabled   |   $total saved"
        $lblStatus.ForeColor = $C.Bad
        $diag = "Folder: $($script:SdkMods)"
        if ($diag -ne $script:LastDiag) { $script:LastDiag = $diag; $tips.SetToolTip($lblStatus, $diag) }
        $queueBar.Visible = $false
    }
    $btnBack.Enabled = [bool]($st -and $st.back)
    $sk = if ($list.SelectedItems.Count) { [string]$list.SelectedItems[0].Tag } else { '' }
    $btnPin.Text = if ($sk -and $script:Favorites.Contains($sk)) { 'Unfavorite' } else { 'Favorite' }
}

# ---------------- actions ----------------
function Get-SelectedKey([bool]$quiet = $false) {
    if (-not $list.SelectedItems.Count -or $null -eq $list.SelectedItems[0].Tag) {
        if (-not $quiet) { [System.Windows.Forms.MessageBox]::Show('Select a boss in the list first.', 'Encore Teleport') | Out-Null }
        return $null
    }
    return [string]$list.SelectedItems[0].Tag
}

function Invoke-Teleport([string]$key = '') {
    if (-not $key) { $key = Get-SelectedKey }
    if (-not $key) { return }
    $s = $script:Stations[$key]
    if (-not $s) { return }
    if ($script:Status -and $s.world -ne $script:Status.world) {
        if ($null -eq $script:Status.pending) {
            [System.Windows.Forms.MessageBox]::Show("$(Get-Name $s) is on another map: $(Get-MapName ([string]$s.world)).`r`nUpdate the mod to v3.12 or newer to queue it.", 'Encore Teleport') | Out-Null
            return
        }
        if (Send-Command 'queue' $key) { $lblInfo.Text = "$(Get-Name $s): travelling to $(Get-MapName ([string]$s.world)) ..." }
        return
    }
    [void](Send-Command 'teleport' $key)
}

function Invoke-Rename {
    $key = Get-SelectedKey
    if (-not $key) { return }
    $s = $script:Stations[$key]
    $form.TopMost = $false
    $res = Show-RenameDialog ([string]$s.label) (Get-AutoName $s)
    $form.TopMost = $true
    switch ($res.Action) {
        'ok' {
            if ($res.Text -eq '-') { $res.Action = 'remove' }
            elseif ($res.Text -ne [string]$s.label) { [void](Send-Command 'rename' $key $res.Text) }
        }
        'auto' { if ($s.label) { [void](Send-Command 'rename' $key '') } }
    }
    if ($res.Action -eq 'remove') {
        $form.TopMost = $false
        $ok = [System.Windows.Forms.MessageBox]::Show("Remove '$(Get-Name $s)' from the list?`r`nIt is saved again the next time you come near it.", 'Encore Teleport', 'YesNo', 'Question')
        $form.TopMost = $true
        if ($ok -eq 'Yes') {
            if (Send-Command 'rename' $key '-') { [void]$script:Favorites.Remove($key); Save-Settings }
        }
    }
}

function Invoke-Pin {
    $key = Get-SelectedKey
    if (-not $key) { return }
    if ($script:Favorites.Contains($key)) { [void]$script:Favorites.Remove($key); $lblInfo.Text = 'Removed from favorites.' }
    else {
        $script:Favorites.Add($key)
        $n = $script:Favorites.Count
        $lblInfo.Text = if ($n -le 5) { "Added as favorite $n - reachable in game with favorite key $n." } else { "Added as favorite $n (only places 1-5 have keys - move it up)." }
    }
    Save-Settings
    $script:LastSig = ''
    Update-List
}

# ---------------- favorite keys dialog ----------------
# WinForms key -> Unreal key name (the names the SDK uses for keybinds)
function Convert-ToUeKey([System.Windows.Forms.Keys]$k) {
    $n = [string]$k
    if ($n -match '^[A-Z]$') { return $n }
    if ($n -match '^F([1-9]|1[0-2])$') { return $n }
    $digits = @('Zero', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine')
    if ($n -match '^D(\d)$') { return $digits[[int]$Matches[1]] }
    if ($n -match '^NumPad(\d)$') { return 'NumPad' + $digits[[int]$Matches[1]] }
    $map = @{
        'Insert' = 'Insert'; 'Home' = 'Home'; 'End' = 'End'; 'PageUp' = 'PageUp'; 'Next' = 'PageDown'; 'PageDown' = 'PageDown'
        'Up' = 'Up'; 'Down' = 'Down'; 'Left' = 'Left'; 'Right' = 'Right'
        'Add' = 'Add'; 'Subtract' = 'Subtract'; 'Multiply' = 'Multiply'; 'Divide' = 'Divide'; 'Decimal' = 'Decimal'
        'OemMinus' = 'Hyphen'; 'Oemplus' = 'Equals'; 'Oemcomma' = 'Comma'; 'OemPeriod' = 'Period'
        'Oem1' = 'Semicolon'; 'OemSemicolon' = 'Semicolon'; 'Oem2' = 'Slash'; 'OemQuestion' = 'Slash'
        'Oem3' = 'Tilde'; 'Oemtilde' = 'Tilde'; 'Oem4' = 'LeftBracket'; 'OemOpenBrackets' = 'LeftBracket'
        'Oem6' = 'RightBracket'; 'OemCloseBrackets' = 'RightBracket'; 'Oem5' = 'Backslash'; 'OemPipe' = 'Backslash'
        'Oem7' = 'Apostrophe'; 'OemQuotes' = 'Apostrophe'; 'Pause' = 'Pause'
    }
    if ($map.ContainsKey($n)) { return $map[$n] }
    return $null
}

function Show-KeysDialog {
    if (-not $script:Status) {
        [System.Windows.Forms.MessageBox]::Show('Start the game first - the keys are stored by the Encore Teleport mod.', 'Encore Teleport') | Out-Null
        return
    }
    $cur = if ($script:Status.fav_keys) { @($script:Status.fav_keys) } else { @('F5', 'F6', 'F7', 'F8', 'F9') }
    $d = New-Object System.Windows.Forms.Form
    $d.Text = 'Favorite keys'
    $d.FormBorderStyle = 'FixedDialog'
    $d.StartPosition = 'CenterParent'
    $d.ClientSize = New-Object System.Drawing.Size(430, 300)
    $d.MaximizeBox = $false; $d.MinimizeBox = $false; $d.ShowInTaskbar = $false
    $d.TopMost = $true
    $d.BackColor = $C.Bg; $d.ForeColor = $C.Fg
    $d.Font = New-Object System.Drawing.Font('Segoe UI', 9)
    $d.Add_HandleCreated({ try { [EtDark]::TitleBar($d.Handle) } catch { } })
    $hint = New-Object System.Windows.Forms.Label
    $hint.Text = 'Click a box and press the new key.  Esc / Delete = no key.  Avoid F11 (window mode) and keys the game uses.'
    $hint.SetBounds(12, 8, 406, 34)
    $hint.ForeColor = $C.Dim
    $d.Controls.Add($hint)
    $boxes = @()
    for ($i = 0; $i -lt 5; $i++) {
        $fav = if ($i -lt $script:Favorites.Count -and $script:Stations.ContainsKey($script:Favorites[$i])) { Get-Name $script:Stations[$script:Favorites[$i]] } else { '(empty)' }
        $l = New-Object System.Windows.Forms.Label
        $l.Text = ('Favorite {0}   {1}' -f ($i + 1), $fav)
        $l.SetBounds(12, 52 + $i * 38, 270, 26)
        $l.TextAlign = 'MiddleLeft'
        $l.AutoEllipsis = $true
        $tb = New-Object System.Windows.Forms.TextBox
        $tb.SetBounds(290, 52 + $i * 38, 128, 26)
        $tb.ReadOnly = $true
        $tb.BorderStyle = 'FixedSingle'
        $tb.BackColor = $C.Input; $tb.ForeColor = $C.Accent
        $tb.Font = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)
        $tb.TextAlign = 'Center'
        $tb.Text = if ($i -lt $cur.Count -and $cur[$i]) { [string]$cur[$i] } else { '-' }
        $tb.ShortcutsEnabled = $false
        $tb.Add_KeyDown({ param($sender, $e)
            $e.Handled = $true; $e.SuppressKeyPress = $true
            if ($e.KeyCode -eq 'Escape' -or $e.KeyCode -eq 'Delete' -or $e.KeyCode -eq 'Back') { $sender.Text = '-'; return }
            if ($e.KeyCode -eq 'Tab') { return }
            $ue = Convert-ToUeKey $e.KeyCode
            if ($ue) { $sender.Text = $ue } else { [System.Media.SystemSounds]::Beep.Play() }
        })
        $d.Controls.Add($l); $d.Controls.Add($tb)
        $boxes += $tb
    }
    $bDef = New-DarkButton 'Defaults' 80;   $bDef.SetBounds(12, 252, 80, 30)
    $bOk = New-DarkButton 'Save' 80;        $bOk.SetBounds(246, 252, 80, 30); $bOk.ForeColor = $C.Accent
    $bCancel = New-DarkButton 'Cancel' 86;  $bCancel.SetBounds(332, 252, 86, 30); $bCancel.DialogResult = 'Cancel'
    $bDef.Add_Click({ $def = @('F5', 'F6', 'F7', 'F8', 'F9'); for ($j = 0; $j -lt 5; $j++) { $boxes[$j].Text = $def[$j] } })
    $bOk.Add_Click({
        $vals = @($boxes | ForEach-Object { if ($_.Text -eq '-') { '' } else { $_.Text } })
        $dupe = @($vals | Where-Object { $_ } | Group-Object | Where-Object { $_.Count -gt 1 })
        if ($dupe.Count) {
            [System.Windows.Forms.MessageBox]::Show("The key $($dupe[0].Name) is used twice.", 'Favorite keys') | Out-Null
            return
        }
        $d.Tag = $vals
        $d.DialogResult = 'OK'
    })
    $d.Controls.AddRange(@($bDef, $bOk, $bCancel))
    $d.CancelButton = $bCancel
    $form.TopMost = $false
    $r = $d.ShowDialog($form)
    $form.TopMost = $true
    $vals = $d.Tag
    $d.Dispose()
    if ($r -ne 'OK' -or -not $vals) { return }
    if (Send-Command 'setkeys' '' '' @{ keys = @($vals) }) {
        $lblInfo.Text = 'Favorite keys sent to the game: ' + (($vals | ForEach-Object { if ($_) { $_ } else { '-' } }) -join ', ')
        $script:LastSig = ''
    }
}

function Move-Favorite([int]$dir) {
    $key = Get-SelectedKey
    if (-not $key -or -not $script:Favorites.Contains($key)) { $lblInfo.Text = 'Select a favorite first.'; return }
    $i = $script:Favorites.IndexOf($key)
    $j = $i + $dir
    if ($j -lt 0 -or $j -ge $script:Favorites.Count) { return }
    $script:Favorites[$i] = $script:Favorites[$j]
    $script:Favorites[$j] = $key
    Save-Settings
    $script:LastSig = ''
    Update-List
    $lblInfo.Text = "Favorite moved to place $($j + 1)."
}

function Select-FirstBoss {
    foreach ($it in $list.Items) {
        if ($null -ne $it.Tag) { $it.Selected = $true; $it.Focused = $true; $it.EnsureVisible(); return [string]$it.Tag }
    }
    return $null
}

# ---------------- events ----------------
# map headers and "not found yet" entries can not be selected
$list.Add_ItemSelectionChanged({ param($sender, $e)
    if ($e.IsSelected -and $null -eq $e.Item.Tag) { $e.Item.Selected = $false }
    $k = if ($list.SelectedItems.Count) { [string]$list.SelectedItems[0].Tag } else { '' }
    $btnPin.Text = if ($k -and $script:Favorites.Contains($k)) { 'Unfavorite' } else { 'Favorite' }
})
$list.Add_DoubleClick({ if ($list.SelectedItems.Count -and $null -ne $list.SelectedItems[0].Tag) { Invoke-Teleport } })
# typing while the list has focus goes to the search box
$list.Add_KeyPress({ param($sender, $e)
    if ([char]::IsLetterOrDigit($e.KeyChar) -or $e.KeyChar -eq ' ') {
        $txtSearch.Focus(); $txtSearch.AppendText([string]$e.KeyChar); $e.Handled = $true
    }
})
$txtSearch.Add_TextChanged({
    $script:Filter = $txtSearch.Text.Trim().ToLower()
    Update-List
})

$form.Add_KeyDown({ param($sender, $e)
    if ($e.Control -and $e.KeyCode -eq 'Tab') {
        if ($script:Mode -eq 'boss') { Set-Mode 'skills' } else { Set-Mode 'boss' }
        $e.Handled = $true; $e.SuppressKeyPress = $true; return
    }
    if ($script:Mode -eq 'skills') {
        $handled = $true
        if ($e.Control -and $e.KeyCode -eq 'S') { Invoke-SkNew }
        elseif ($e.KeyCode -eq 'Enter') { Invoke-SkLoad }
        elseif ($e.KeyCode -eq 'F2') { Invoke-SkRename }
        elseif ($e.KeyCode -eq 'Delete') { Invoke-SkDelete }
        else { $handled = $false }
        if ($handled) { $e.Handled = $true; $e.SuppressKeyPress = $true }
        return
    }
    $inSearch = $txtSearch.Focused
    $handled = $true
    if ($e.Control -and $e.KeyCode -eq 'D') { Invoke-Pin }
    elseif ($e.Control -and $e.KeyCode -eq 'Up') { Move-Favorite -1 }
    elseif ($e.Control -and $e.KeyCode -eq 'Down') { Move-Favorite 1 }
    elseif ($e.Control -and $e.KeyCode -eq 'N') { [void](Send-Command 'nearest') }
    elseif ($e.Control -and $e.KeyCode -eq 'F') { $txtSearch.Focus(); $txtSearch.SelectAll() }
    elseif ($e.KeyCode -eq 'F2') { Invoke-Rename }
    elseif ($e.KeyCode -eq 'Escape') { $txtSearch.Clear(); $list.Focus() }
    elseif ($e.KeyCode -eq 'Enter') {
        $k = Get-SelectedKey $true
        if (-not $k -and $inSearch) { $k = Select-FirstBoss }
        if ($k) { Invoke-Teleport $k }
    }
    elseif ($e.KeyCode -eq 'Down' -and $inSearch) { $list.Focus(); if (-not $list.SelectedItems.Count) { [void](Select-FirstBoss) } }
    elseif ($e.KeyCode -eq 'Back' -and -not $inSearch) { if ($script:Status -and $script:Status.back) { [void](Send-Command 'back') } }
    else { $handled = $false }
    if ($handled) { $e.Handled = $true; $e.SuppressKeyPress = $true }
})

$skillList.Add_ItemSelectionChanged({ param($sender, $e) if ($e.IsSelected -and $null -eq $e.Item.Tag) { $e.Item.Selected = $false }; Update-SkillDetail })
$skillList.Add_DoubleClick({ if ($skillList.SelectedItems.Count -and $null -ne $skillList.SelectedItems[0].Tag) { Invoke-SkLoad } })
$btnModeBoss.Add_Click({ Set-Mode 'boss' })
$btnModeSkills.Add_Click({ Set-Mode 'skills' })
$btnSkLoad.Add_Click({ Invoke-SkLoad })
$btnSkNew.Add_Click({ Invoke-SkNew })
$btnSkOver.Add_Click({ Invoke-SkOverwrite })
$btnSkRename.Add_Click({ Invoke-SkRename })
$btnSkDelete.Add_Click({ Invoke-SkDelete })
$btnSkReset.Add_Click({ Invoke-SkReset })
$btnSkGear.Add_Click({ Invoke-SkGear })
$btnSkUndo.Add_Click({ Invoke-SkUndo })

$btnGo.Add_Click({ Invoke-Teleport })
$btnNearest.Add_Click({ [void](Send-Command 'nearest') })
$btnBack.Add_Click({ [void](Send-Command 'back') })
$btnPin.Add_Click({ Invoke-Pin })
$btnFavUp.Add_Click({ Move-Favorite -1 })
$btnFavDown.Add_Click({ Move-Favorite 1 })
$btnRename.Add_Click({ Invoke-Rename })
$btnUnqueue.Add_Click({ [void](Send-Command 'unqueue') })
$btnKeys.Add_Click({ Show-KeysDialog })
$btnFolder.Add_Click({
    $d = Select-SdkMods
    if ($d) {
        $script:SdkMods = $d
        Save-Settings
        $script:StationsStamp = [datetime]::MinValue
        $script:LastSig = ''
        Update-Data; Update-List
    }
})

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 1000
$timer.Add_Tick({
    if ($form.WindowState -eq 'Minimized') { return }   # nothing to show - no work
    if ($script:Mode -eq 'boss') { Update-Data; Update-List } else {
        # heartbeat: the mod only scans the backpack for the gear check while this page is open
        $now = [DateTime]::UtcNow
        if (-not $script:HeartbeatAt -or ($now - $script:HeartbeatAt).TotalSeconds -ge 5) {
            $script:HeartbeatAt = $now
            try { [System.IO.File]::WriteAllText((Join-Path $script:SdkMods 'SkillSaver_app.json'), '{"page":"skills"}') } catch { }
        }
        Update-SkillData; Update-SkillsView; Update-SkillDetail
    }
})
$form.Add_Shown({
    Update-Data; Update-List
    $list.Columns[0].Width = [math]::Max(100, $list.ClientSize.Width - 2)
    $skillList.Columns[0].Width = [math]::Max(100, $skillList.ClientSize.Width - 2)
    Set-Mode 'boss'
    $timer.Start()
})
$form.Add_FormClosed({ $timer.Stop() })
[void]$form.ShowDialog()
