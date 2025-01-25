# Windows 10 Steam Deck Optimizer - PowerShell Script
# Scriptet vil blive erstattet med det fulde PowerShell-script
Add-Type -AssemblyName System.Windows.Forms

# Tjek for administratorrettigheder
If (-Not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Start-Process PowerShell -ArgumentList ("-NoProfile -ExecutionPolicy Bypass -File `"" + $MyInvocation.MyCommand.Path + "`"") -Verb RunAs
    Exit
}

# Logfil
$logFile = "$env:USERPROFILE\Desktop\SteamDeckOptimizer.log"

Function Write-Log {
    param ([string]$message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp - $message" | Out-File -Append -FilePath $logFile
}

Function Safe-Run {
    param ([ScriptBlock]$command, [string]$message)
    Try {
        & $command
        Write-Log "$message - SUCCESS"
    } Catch {
        Write-Log "$message - ERROR: $_"
    }
}

# Backup Funktion
Function Backup-Settings {
    Write-Log "Starter backup af nuværende indstillinger..."
    powercfg /getactivescheme | Out-File "$env:USERPROFILE\Desktop\SteamDeckOptimizer_Backup.txt" -Append
    Get-Service | Select-Object Name, Status, StartType | Out-File "$env:USERPROFILE\Desktop\SteamDeckOptimizer_Backup.txt" -Append
    Write-Log "Backup færdig"
    Write-Host "✅ Backup gemt på din Desktop."
}

# Kritiske systemtjek
Function System-Check {
    Write-Host "🔍 Udfører system-tjek..."
    Write-Log "Starter system-tjek..."

    $pendingUpdates = (Get-WmiObject -Query "SELECT * FROM Win32_ReliabilityRecords WHERE EventType = 19" | Measure-Object).Count
    If ($pendingUpdates -gt 0) {
        Write-Host "⚠️ Windows opdateringer kører! Prøv igen senere."
        Write-Log "Systemopdatering fundet, afbryder optimering."
        Start-Sleep 3
        Show-Menu
    }

    # Kritiske tjenester check
    $criticalServices = @("WinDefend", "wuauserv", "Spooler", "LanmanWorkstation")
    foreach ($service in $criticalServices) {
        $status = Get-Service -Name $service -ErrorAction SilentlyContinue
        If ($status.Status -ne "Running") {
            Write-Host "⚠️ Kritisk tjeneste '$service' er stoppet. Genstarter den nu..."
            Start-Service -Name $service
            Write-Log "Genstartede kritisk tjeneste: $service"
        }
    }
    Write-Host "✅ Systemet er sikkert at optimere."
}

# Aktiver Steam Gaming Mode
Function Activate-GamingMode {
    System-Check
    Write-Host "🕹️ Aktiverer Steam Gaming Mode..."
    Backup-Settings

    # Start Steam i Big Picture Mode
    Safe-Run { 
        $startupPath = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\steam_bigpicture.lnk"
        $wshShell = New-Object -ComObject WScript.Shell
        $shortcut = $wshShell.CreateShortcut($startupPath)
        $shortcut.TargetPath = "C:\Program Files (x86)\Steam\steam.exe"
        $shortcut.Arguments = "-tenfoot"
        $shortcut.Save()
    } "Tilføjede Steam Big Picture til opstart"

    # Aktiver "Ultimate Performance" strømplan
    Safe-Run { powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 } "Aktiverede Ultimativ Ydeevne"

    # Deaktiver unødvendige tjenester
    $services = @("SysMain", "DiagTrack", "WSearch", "XboxGipSvc", "XboxNetApiSvc", "wisvc", "TabletInputService", "wuauserv")
    foreach ($service in $services) {
        If (Get-Service -Name $service -ErrorAction SilentlyContinue) {
            Safe-Run { Stop-Service -Name $service -Force -ErrorAction SilentlyContinue } "Stoppede tjeneste: $service"
            Safe-Run { Set-Service -Name $service -StartupType Disabled } "Deaktiverede tjeneste: $service"
        }
    }

    Write-Host "✅ Steam Gaming Mode aktiveret!"
    Prompt-Restart
}

# Gendan Originale Indstillinger
Function Restore-OriginalSettings {
    Write-Host "🔄 Gendanner originale indstillinger..."
    Safe-Run { powercfg -restoredefaultschemes } "Gendannede strømplaner"

    # Gendan tjenester
    $services = @("SysMain", "DiagTrack", "WSearch", "XboxGipSvc", "XboxNetApiSvc", "wisvc", "TabletInputService", "wuauserv")
    foreach ($service in $services) {
        If (Get-Service -Name $service -ErrorAction SilentlyContinue) {
            Safe-Run { Set-Service -Name $service -StartupType Automatic } "Gendannede tjeneste: $service"
            Safe-Run { Start-Service -Name $service } "Startede tjeneste: $service"
        }
    }

    Write-Host "✅ Windows er nu tilbage til originalindstillingerne!"
    Prompt-Restart
}

# Genstartsprompt
Function Prompt-Restart {
    $response = Read-Host "🔄 Ændringer kræver en genstart. Vil du genstarte nu? (y/n)"
    If ($response -match "^[Yy]$") {
        Restart-Computer -Force
    } Else {
        Write-Host "🚀 Husk at genstarte senere for at anvende alle ændringer!"
    }
}

# Hovedmenu
Function Show-Menu {
    Clear-Host
    Write-Host "=========================================="
    Write-Host "     Windows 10 Steam Gaming Optimizer    "
    Write-Host "=========================================="
    Write-Host "1. 🕹️ Aktivér Steam Gaming Mode"
    Write-Host "2. 🔄 Gendan Originale Indstillinger"
    Write-Host "3. 📋 Se Nuværende Indstillinger"
    Write-Host "4. ❌ Afslut Program"
    Write-Host "=========================================="

    Do {
        $choice = Read-Host "Vælg en mulighed (1-4)"
        If ($choice -match "^[1-4]$") {
            Switch ($choice) {
                1 { Activate-GamingMode }
                2 { Restore-OriginalSettings }
                3 { Show-CurrentStatus }
                4 { Exit }
            }
        } Else {
            Write-Host "⚠️ Ugyldigt valg! Indtast et tal mellem 1 og 4." -ForegroundColor Red
        }
    } Until ($choice -match "^[1-4]$")
}

# Start menuen
Show-Menu
