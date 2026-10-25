# fix-sideloadly.ps1
#
# Repariert Sideloadly, wenn es mit
#   "Der Prozedureinsprungpunkt PyInit_sideloadly_wrap wurde in der DLL
#    ...\Sideloadly\sideloadly.exe nicht gefunden"
# nicht mehr startet.
#
# Sideloadly ist ein Python-Programm. Die Meldung heisst, dass ein
# mitgeliefertes Hilfsmodul (sideloadly_wrap.pyd) nicht zur sideloadly.exe
# passt. Zwei Ursachen, und die zweite ist die, wegen der es WIEDERKOMMT:
#
#   1. Reste einer alten Version - der Installer ueberschreibt den Ordner,
#      loescht aber nicht.
#   2. Der Virenscanner. Windows Defender erkennt Sideloadly regelmaessig
#      falsch-positiv (es signiert fremde Apps) und nimmt die .pyd in
#      Quarantaene. Danach fehlt genau dieser Einsprungpunkt - nach JEDER
#      Neuinstallation wieder.
#
# Deshalb setzt dieses Skript ZUERST den Ausschluss und loescht DANN. Ohne
# den Ausschluss waere das Loeschen umsonst.
#
# Rechtsklick auf die Datei -> "Mit PowerShell ausfuehren" reicht NICHT,
# weil der Defender-Ausschluss Administratorrechte braucht. Stattdessen:
#   Startmenue -> "PowerShell" -> Rechtsklick -> Als Administrator ausfuehren
#   Set-ExecutionPolicy -Scope Process Bypass -Force
#   .\fix-sideloadly.ps1

#Requires -Version 5.1

$ErrorActionPreference = 'Stop'
$ordner = Join-Path $env:LOCALAPPDATA 'Sideloadly'

function Schritt($text) { Write-Host "`n==> $text" -ForegroundColor Cyan }
function Gut($text)     { Write-Host "    $text" -ForegroundColor Green }
function Warnung($text) { Write-Host "    $text" -ForegroundColor Yellow }

# --- 0. Administrator? -------------------------------------------------
$identitaet = [Security.Principal.WindowsIdentity]::GetCurrent()
$istAdmin = (New-Object Security.Principal.WindowsPrincipal $identitaet).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator
)
if (-not $istAdmin) {
    Write-Host "Dieses Skript braucht Administratorrechte." -ForegroundColor Red
    Write-Host "PowerShell schliessen, neu als Administrator oeffnen, nochmal starten."
    exit 1
}

# --- 1. Sideloadly beenden ---------------------------------------------
Schritt "Laufende Sideloadly-Prozesse beenden"
$laeuft = Get-Process -Name 'sideloadly' -ErrorAction SilentlyContinue
if ($laeuft) {
    $laeuft | Stop-Process -Force
    Start-Sleep -Seconds 2
    Gut "beendet"
} else {
    Gut "lief nicht"
}

# --- 2. Quarantaene ansehen --------------------------------------------
# Das ist der eigentliche Befund: Steht hier etwas mit Sideloadly, war es
# der Scanner - und dann ist Schritt 3 der Grund, warum es diesmal haelt.
Schritt "Defender-Quarantaene pruefen"
$mpCmd = Get-ChildItem 'C:\ProgramData\Microsoft\Windows Defender\Platform' -Directory -ErrorAction SilentlyContinue |
    Sort-Object Name -Descending |
    ForEach-Object { Join-Path $_.FullName 'MpCmdRun.exe' } |
    Where-Object { Test-Path $_ } |
    Select-Object -First 1
if (-not $mpCmd) { $mpCmd = Join-Path $env:ProgramFiles 'Windows Defender\MpCmdRun.exe' }

if (Test-Path $mpCmd) {
    $quarantaene = & $mpCmd -Restore -ListAll 2>&1 | Out-String
    if ($quarantaene -match '(?i)sideload') {
        Warnung "Der Scanner hat Sideloadly-Dateien in Quarantaene:"
        Write-Host $quarantaene
        Warnung "Stell sie in der Windows-Sicherheit unter Schutzverlauf wieder her,"
        Warnung "oder lass sie liegen - die Neuinstallation bringt sie ohnehin mit."
    } else {
        Gut "nichts mit Sideloadly in Quarantaene"
    }
} else {
    Warnung "MpCmdRun.exe nicht gefunden - Quarantaene bitte von Hand ansehen"
}

# --- 3. Ausschluss setzen ----------------------------------------------
# VOR dem Loeschen: Sonst frisst der Scanner die neue Installation wieder.
Schritt "Ordner vom Virenscanner ausnehmen"
try {
    $vorhanden = (Get-MpPreference).ExclusionPath
    if ($vorhanden -contains $ordner) {
        Gut "Ausschluss war schon gesetzt"
    } else {
        Add-MpPreference -ExclusionPath $ordner
        Gut "Ausschluss gesetzt: $ordner"
    }
} catch {
    Warnung "Ausschluss konnte nicht gesetzt werden: $($_.Exception.Message)"
    Warnung "Von Hand: Windows-Sicherheit -> Viren- & Bedrohungsschutz ->"
    Warnung "Einstellungen verwalten -> Ausschluesse -> Ordner -> $ordner"
}

# --- 4. Deinstallieren, falls eingetragen ------------------------------
Schritt "Eingetragene Installation suchen"
$pfade = @(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
    'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
)
$eintrag = Get-ItemProperty $pfade -ErrorAction SilentlyContinue |
    Where-Object { $_.DisplayName -like '*Sideloadly*' } |
    Select-Object -First 1

if ($eintrag -and $eintrag.UninstallString) {
    Warnung "Deinstallation wird geoeffnet - bitte durchklicken, dann hier weiter."
    Start-Process 'cmd.exe' -ArgumentList '/c', $eintrag.UninstallString -Wait
    Gut "Deinstallation beendet"
} else {
    Gut "kein Eintrag gefunden (dann reicht das Loeschen)"
}

# --- 5. Ordner wirklich loeschen ---------------------------------------
# Das ist der Punkt, an dem es beim letzten Mal gescheitert ist:
# Drueberinstallieren laesst die alten Dateien liegen.
Schritt "Ordner loeschen"
if (Test-Path $ordner) {
    Remove-Item $ordner -Recurse -Force
    if (Test-Path $ordner) {
        Warnung "Ordner liess sich nicht ganz loeschen - laeuft noch etwas?"
    } else {
        Gut "geloescht: $ordner"
    }
} else {
    Gut "war schon weg"
}

# --- 6. Download oeffnen -----------------------------------------------
Schritt "Fertig"
Write-Host "    Jetzt die 64-bit-Version neu laden und ALS ADMINISTRATOR installieren."
Write-Host "    Die Seite oeffnet sich gleich."
Start-Sleep -Seconds 2
Start-Process 'https://sideloadly.io'

Write-Host "`nWenn der Fehler ein drittes Mal kommt: AltStore/SideStore statt" -ForegroundColor Yellow
Write-Host "Sideloadly. Der AltServer signiert die App ueber WLAN automatisch nach," -ForegroundColor Yellow
Write-Host "bevor die 7 Tage ablaufen - dann entfaellt auch das Kabelsuchen." -ForegroundColor Yellow
