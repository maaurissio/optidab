<#
  KHRAM Optimizer - Script de instalacion y optimizacion post-formateo.

  Que hace:
  - Desactiva Windows Defender (rendimiento). Antes de correrlo, desactiva "Proteccion
    contra alteraciones" a mano en Seguridad de Windows, o Windows revierte el cambio solo.
  - Aplica tweaks de rendimiento/privacidad: notificaciones, Game Bar/DVR (dejando Game Mode
    activo), OneDrive, aceleracion del mouse, plan de energia "Rendimiento maximo", algoritmo
    de Nagle, extensiones/archivos ocultos, pausa de Windows Update y bloqueo de auto-encriptado
    de BitLocker.
  - En Windows 11 ademas desactiva Copilot, Recall, Click to Do, funciones de IA de Edge/
    Notepad/Paint, los widgets de la barra de tareas, y restaura el menu contextual clasico
    de Windows 10.
  - Pregunta que apps instalar (navegador, compresor, apps de gaming, reproductor) y las
    instala por winget.
  - Al terminar, descarga wall.png del repo y lo pone de fondo de pantalla.

  Inspirado en las tecnicas de Raphire/Win11Debloat y ChrisTitusTech/winutil.
#>

$ScriptUrl = "https://raw.githubusercontent.com/maaurissio/mis-scripts/refs/heads/main/install-apps.ps1"
$WallpaperUrl = "https://raw.githubusercontent.com/maaurissio/mis-scripts/refs/heads/main/wall.png"

# --- Banner ---
Write-Host @'
 ,ggg,        gg  ,ggg,        gg  ,ggggggggggg,              ,ggg,  ,ggg, ,ggg,_,ggg,
dP""Y8b       dP dP""Y8b       88 dP"""88""""""Y8,           dP""8I dP""Y8dP""Y88P""Y8b
Yb, `88      d8' Yb, `88       88 Yb,  88      `8b          dP   88 Yb, `88'  `88'  `88
 `"  88    ,dP'   `"  88       88  `"  88      ,8P         dP    88  `"  88    88    88
     88aaad8"         88aaaaaaa88      88aaaad8P"         ,8'    88      88    88    88
     88""""Yb,        88"""""""88      88""""Yb,          d88888888      88    88    88
     88     "8b       88       88      88     "8b   __   ,8"     88      88    88    88
     88      `8i      88       88      88      `8i dP"  ,8P      Y8      88    88    88
     88       Yb,     88       Y8,     88       Yb,Yb,_,dP       `8b,    88    88    Y8,
     88        Y8     88       `Y8     88        Y8 "Y8P"         `Y8    88    88    `Y8

'@ -ForegroundColor Magenta

# --- Auto-elevacion a administrador (un solo UAC al inicio, no uno por app) ---
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Se requiere administrador, relanzando elevado..." -ForegroundColor Yellow
    Start-Process powershell -Verb RunAs -ArgumentList @(
        "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command",
        "irm $ScriptUrl | iex"
    )
    exit
}

# --- Logging ---
$LogFile = Join-Path ([Environment]::GetFolderPath('Desktop')) "KHRAM-Optimizacion-$(Get-Date -Format yyyyMMdd-HHmmss).log"

function Write-Log {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    Write-Host $Message -ForegroundColor $Color
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    Add-Content -Path $LogFile -Value "[$timestamp] $Message" -ErrorAction SilentlyContinue
}

function Set-Reg {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)]$Value,
        [string]$Type = "DWord"
    )
    if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
    Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type -Force
}

Write-Log "Log de esta ejecucion: $LogFile" "DarkGray"

# --- Deteccion de sistema operativo ---
$buildNumber = [int](Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').CurrentBuildNumber
$isWin11 = $buildNumber -ge 22000
$isWin11AI = $buildNumber -ge 22621
Write-Log "Sistema detectado: $(if ($isWin11) { 'Windows 11' } else { 'Windows 10' }) (build $buildNumber)" "Cyan"

# --- Helpers de menu interactivo ---
function Read-YesNo {
    param([string]$Prompt)
    do {
        $r = Read-Host "$Prompt (S/N)"
    } while ($r -notmatch '^(?i:s|n)$')
    return ($r -match '^(?i:s)$')
}

function Read-MenuChoice {
    param(
        [string]$Title,
        [string[]]$Options
    )
    Write-Host "`n$Title" -ForegroundColor Cyan
    for ($i = 0; $i -lt $Options.Count; $i++) {
        Write-Host "  $($i + 1)) $($Options[$i])"
    }
    do {
        $raw = Read-Host "Elige una opcion (1-$($Options.Count))"
        $choice = 0
        $valid = [int]::TryParse($raw, [ref]$choice) -and $choice -ge 1 -and $choice -le $Options.Count
        if (-not $valid) { Write-Host "Opcion invalida." -ForegroundColor Yellow }
    } while (-not $valid)
    return $choice
}

# ===================== PREGUNTAS INICIALES =====================
Write-Host "`n===== Configuracion =====" -ForegroundColor Cyan

$wantsRestorePoint = Read-YesNo "`n¿Crear un punto de restauracion del sistema antes de continuar?"

$browserChoice = Read-MenuChoice "Navegador a instalar:" @("Chrome", "Brave", "Firefox", "Ninguno")
$wantsBraveDebloat = $false
if ($browserChoice -eq 2) {
    $wantsBraveDebloat = Read-YesNo "¿Aplicar debloat de Brave? (desactiva por politica la IA (Leo), Wallet cripto, Rewards, Talk y News de Brave; no afecta la navegacion normal)"
}

$compressorChoice = Read-MenuChoice "Compresor de archivos a instalar:" @("WinRAR", "NanaZip", "Ninguno")

$wantsGamingApps = Read-YesNo "`n¿Instalar Discord, Steam y Epic Games Launcher?"

$playerChoice = Read-MenuChoice "Reproductor multimedia a instalar:" @("Peliculas y TV", "VLC", "Ninguno")

# ===================== PUNTO DE RESTAURACION =====================
if ($wantsRestorePoint) {
    Write-Log "`nCreando punto de restauracion..." "Cyan"
    try {
        $srPath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore'
        $rpSession = (Get-ItemProperty -Path $srPath -Name RPSessionInterval -ErrorAction SilentlyContinue).RPSessionInterval
        if (-not $rpSession) {
            Write-Log "Proteccion del sistema estaba apagada, activandola..." "Yellow"
            Enable-ComputerRestore -Drive $env:SystemDrive
        }

        $recentRestorePoint = Get-ComputerRestorePoint -ErrorAction SilentlyContinue | Where-Object {
            (Get-Date) - [System.Management.ManagementDateTimeConverter]::ToDateTime($_.CreationTime) -le (New-TimeSpan -Hours 24)
        }

        if ($recentRestorePoint) {
            Write-Log "Ya existe un punto de restauracion reciente (menos de 24hs), se omite la creacion." "Yellow"
        }
        else {
            Checkpoint-Computer -Description "KHRAM Optimizer" -RestorePointType MODIFY_SETTINGS
            Write-Log "Punto de restauracion creado correctamente." "Green"
        }
    }
    catch {
        Write-Log "No se pudo crear el punto de restauracion: $($_.Exception.Message)" "Yellow"
    }
}

# --- Chequeo de winget ---
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Log "winget no esta disponible. Actualiza 'App Installer' desde la Microsoft Store e intenta de nuevo." "Red"
    exit 1
}

# --- Chequeo de Proteccion contra alteraciones (Tamper Protection) ---
# Microsoft bloquea a proposito que esto se desactive por script. Si sigue activada,
# Windows revierte solo el paso de Defender, asi que cortamos aca y abrimos Seguridad
# de Windows para que la desactives a mano. Si Defender ya no esta instalado, se salta esto.
$defenderStatus = Get-MpComputerStatus -ErrorAction SilentlyContinue
if ($defenderStatus -and $defenderStatus.IsTamperProtected) {
    Write-Log "`nProteccion contra alteraciones esta ACTIVADA." "Red"
    Write-Log "Abriendo Seguridad de Windows para que la desactives..." "Yellow"
    Start-Process "windowsdefender://threatsettings"
    Write-Log "Ve a 'Proteccion contra alteraciones' y apagala, despues vuelve a correr el script." "Yellow"
    exit 1
}

# --- Desactivar Windows Defender (rendimiento) ---
Write-Log "`nDesactivando Windows Defender..." "Cyan"

try {
    Set-MpPreference -DisableRealtimeMonitoring $true -DisableBehaviorMonitoring $true `
        -DisableIOAVProtection $true -DisableScriptScanning $true -DisableArchiveScanning $true `
        -MAPSReporting Disabled -SubmitSamplesConsent NeverSend -ErrorAction Stop
    Write-Log "Proteccion en tiempo real desactivada." "Green"
}
catch {
    Write-Log "No se pudo aplicar Set-MpPreference: $($_.Exception.Message)" "Yellow"
}

try {
    $policyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender"
    if (-not (Test-Path $policyPath)) { New-Item -Path $policyPath -Force | Out-Null }
    Set-ItemProperty -Path $policyPath -Name "DisableAntiSpyware" -Value 1 -Type DWord -Force -ErrorAction Stop
    Write-Log "Politica DisableAntiSpyware aplicada." "Green"
}
catch {
    Write-Log "No se pudo escribir la politica de registro: $($_.Exception.Message)" "Yellow"
}

try {
    Get-ScheduledTask -TaskPath "\Microsoft\Windows\Windows Defender\" -ErrorAction Stop |
        Disable-ScheduledTask -ErrorAction SilentlyContinue | Out-Null
    Write-Log "Tareas programadas de Defender desactivadas." "Green"
}
catch {
    Write-Log "No se pudieron desactivar las tareas programadas: $($_.Exception.Message)" "Yellow"
}

try {
    Set-Service -Name WinDefend -StartupType Disabled -ErrorAction Stop
    Write-Log "Servicio WinDefend deshabilitado." "Green"
}
catch {
    Write-Log "No se pudo deshabilitar el servicio WinDefend (normal si Tamper Protection sigue activo)." "Yellow"
}

# --- Desactivar Core Isolation / Memory Integrity (VBS + HVCI) ---
# IMPORTANTE: esto necesita reiniciar la PC para aplicarse (a diferencia de los demas tweaks).
Write-Log "`nDesactivando Core Isolation (VBS)..." "Cyan"
try {
    $hvciPath = "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity"
    Set-Reg -Path $hvciPath -Name "Enabled" -Value 0
    Set-Reg -Path "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard" -Name "EnableVirtualizationBasedSecurity" -Value 0
    Write-Log "Core Isolation (VBS) desactivado. Se aplica recien despues de reiniciar." "Green"
}
catch {
    Write-Log "No se pudo desactivar Core Isolation: $($_.Exception.Message)" "Yellow"
}

# --- Quitar el icono de Seguridad de Windows de la bandeja del sistema ---
Write-Log "`nQuitando icono de Seguridad de Windows de la bandeja..." "Cyan"
try {
    Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" -Name "SecurityHealth" -ErrorAction Stop
    Write-Log "Icono de bandeja de Seguridad de Windows desactivado." "Green"
}
catch {
    Write-Log "El icono de bandeja ya estaba desactivado o no se pudo quitar." "Yellow"
}

# --- Ocultar seccion "Control de aplicaciones y navegador" en Seguridad de Windows ---
Write-Log "`nOcultando 'Control de aplicaciones y navegador'..." "Cyan"
try {
    $abcPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender Security Center\App and Browser protection"
    Set-Reg -Path $abcPath -Name "UILockdown" -Value 1
    Write-Log "Seccion ocultada." "Green"
}
catch {
    Write-Log "No se pudo ocultar la seccion: $($_.Exception.Message)" "Yellow"
}

# --- Desactivar notificaciones (solo apagarlas, sin tocar el servicio) ---
Write-Log "`nDesactivando notificaciones..." "Cyan"
try {
    Set-Reg -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\PushNotifications" -Name "ToastEnabled" -Value 0
    Write-Log "Notificaciones (toast) desactivadas." "Green"
}
catch {
    Write-Log "No se pudieron desactivar las notificaciones: $($_.Exception.Message)" "Yellow"
}

# --- Desactivar Xbox Game Bar / Game DVR (dejando Game Mode activo) ---
Write-Log "`nDesactivando Xbox Game Bar / Game DVR..." "Cyan"
try {
    Set-Reg -Path "HKCU:\System\GameConfigStore" -Name "GameDVR_Enabled" -Value 0
    Set-Reg -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" -Name "AppCaptureEnabled" -Value 0
    Set-Reg -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR" -Name "AllowGameDVR" -Value 0
    Set-Reg -Path "HKCU:\Software\Microsoft\GameBar" -Name "UseNexusForGameBarEnabled" -Value 0

    # Bloquea los popups ms-gamebar al conectar un control o abrir un juego
    foreach ($protocol in @("ms-gamebar", "ms-gamebarservices")) {
        $protoPath = "Registry::HKEY_CLASSES_ROOT\$protocol"
        Set-Reg -Path $protoPath -Name "(default)" -Value "URL: $protocol" -Type String
        Set-Reg -Path $protoPath -Name "URL Protocol" -Value "" -Type String
        Set-Reg -Path $protoPath -Name "NoOpenWith" -Value "" -Type String
        Set-Reg -Path "$protoPath\shell\open\command" -Name "(default)" -Value "$env:SystemRoot\System32\systray.exe" -Type String
    }

    # Game Mode se deja explicitamente activo
    Set-Reg -Path "HKCU:\Software\Microsoft\GameBar" -Name "AutoGameModeEnabled" -Value 1
    Write-Log "Game Bar / Game DVR desactivado. Game Mode se dejo activo a proposito." "Green"
}
catch {
    Write-Log "No se pudo desactivar Game DVR: $($_.Exception.Message)" "Yellow"
}

# --- Eliminar OneDrive (si esta instalado) ---
Write-Log "`nBuscando OneDrive..." "Cyan"
try {
    $oneDriveSetup = @(
        "$env:SystemRoot\SysWOW64\OneDriveSetup.exe",
        "$env:SystemRoot\System32\OneDriveSetup.exe"
    ) | Where-Object { Test-Path $_ } | Select-Object -First 1

    if (-not $oneDriveSetup) {
        Write-Log "OneDrive no esta instalado, se omite." "Yellow"
    }
    else {
        Write-Log "Desinstalando OneDrive..." "Cyan"
        $oneDriveFolder = if ($env:OneDrive) { $env:OneDrive } else { "$env:USERPROFILE\OneDrive" }

        if (Test-Path $oneDriveFolder) {
            icacls $oneDriveFolder /deny "Administrators:(D,DC)" | Out-Null
        }

        Start-Process $oneDriveSetup -ArgumentList "/uninstall" -Wait -ErrorAction SilentlyContinue
        Stop-Process -Name FileCoAuth -Force -ErrorAction SilentlyContinue

        Remove-Item "$env:LocalAppData\Microsoft\OneDrive" -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item "$env:ProgramData\Microsoft OneDrive" -Recurse -Force -ErrorAction SilentlyContinue

        if (Test-Path $oneDriveFolder) {
            icacls $oneDriveFolder /grant "Administrators:(D,DC)" | Out-Null
            if (-not (Get-ChildItem -Path $oneDriveFolder -ErrorAction SilentlyContinue)) {
                Remove-Item -Path $oneDriveFolder -Recurse -Force -ErrorAction SilentlyContinue
                [Environment]::SetEnvironmentVariable('OneDrive', $null, 'User')
            }
        }

        Set-Service -Name OneSyncSvc -StartupType Disabled -ErrorAction SilentlyContinue
        Write-Log "OneDrive eliminado." "Green"
    }
}
catch {
    Write-Log "No se pudo eliminar OneDrive por completo: $($_.Exception.Message)" "Yellow"
}

# --- Desactivar aceleracion del mouse ("Mejorar precision del puntero") ---
Write-Log "`nDesactivando aceleracion del mouse..." "Cyan"
try {
    Set-ItemProperty -Path "HKCU:\Control Panel\Mouse" -Name "MouseSpeed" -Value "0" -Type String -Force -ErrorAction Stop
    Set-ItemProperty -Path "HKCU:\Control Panel\Mouse" -Name "MouseThreshold1" -Value "0" -Type String -Force -ErrorAction Stop
    Set-ItemProperty -Path "HKCU:\Control Panel\Mouse" -Name "MouseThreshold2" -Value "0" -Type String -Force -ErrorAction Stop

    if (-not ("Win32.Mouse" -as [type])) {
        Add-Type -Namespace Win32 -Name Mouse -MemberDefinition @"
            [DllImport("user32.dll", SetLastError = true)]
            public static extern bool SystemParametersInfo(uint uiAction, uint uiParam, int[] pvParam, uint fWinIni);
"@
    }
    # SPI_SETMOUSE = 0x0004, aplica el cambio de inmediato sin cerrar sesion
    [Win32.Mouse]::SystemParametersInfo(0x0004, 0, @(0, 0, 0), 0) | Out-Null

    Write-Log "Aceleracion del mouse desactivada." "Green"
}
catch {
    Write-Log "No se pudo desactivar la aceleracion del mouse: $($_.Exception.Message)" "Yellow"
}

# --- Plan de energia "Rendimiento maximo" (Ultimate Performance) ---
Write-Log "`nActivando plan de energia 'Rendimiento maximo'..." "Cyan"
try {
    $dupOutput = powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61
    $planGuid = [regex]::Match(($dupOutput -join " "), "([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})").Value
    if (-not $planGuid) { throw "No se pudo obtener el GUID del plan nuevo." }
    powercfg -setactive $planGuid
    Write-Log "Plan de energia 'Rendimiento maximo' activado." "Green"
}
catch {
    Write-Log "No se pudo activar el plan de rendimiento maximo: $($_.Exception.Message)" "Yellow"
}

# --- Desactivar algoritmo de Nagle (menor latencia de red) ---
Write-Log "`nDesactivando algoritmo de Nagle..." "Cyan"
try {
    $interfacesPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces"
    Get-ChildItem -Path $interfacesPath -ErrorAction Stop | ForEach-Object {
        Set-ItemProperty -Path $_.PsPath -Name "TcpAckFrequency" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $_.PsPath -Name "TCPNoDelay" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
    }
    Write-Log "Algoritmo de Nagle desactivado en todas las interfaces de red." "Green"
}
catch {
    Write-Log "No se pudo desactivar el algoritmo de Nagle: $($_.Exception.Message)" "Yellow"
}

# --- Pausar Windows Update (rendimiento, no permanente) ---
Write-Log "`nPausando Windows Update..." "Cyan"
try {
    $wuSettingsPath = "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings"
    $pauseStart = Get-Date -Format "yyyy-MM-dd"
    $pauseExpiry = (Get-Date).AddDays(35).ToString("yyyy-MM-dd")
    Set-Reg -Path $wuSettingsPath -Name "PauseUpdatesStartTime" -Value $pauseStart -Type String
    Set-Reg -Path $wuSettingsPath -Name "PauseUpdatesExpiryTime" -Value $pauseExpiry -Type String
    Set-Reg -Path $wuSettingsPath -Name "IsContinuousInnovationOptedIn" -Value 0
    Write-Log "Windows Update pausado hasta el $pauseExpiry." "Green"
}
catch {
    Write-Log "No se pudo pausar Windows Update: $($_.Exception.Message)" "Yellow"
}

# --- BitLocker: bloquear auto-encriptado (no desencripta discos ya encriptados) ---
Write-Log "`nBloqueando auto-encriptado de BitLocker..." "Cyan"
try {
    Set-Reg -Path "HKLM:\SYSTEM\CurrentControlSet\Control\BitLocker" -Name "PreventDeviceEncryption" -Value 1
    Write-Log "Auto-encriptado de BitLocker bloqueado (discos ya encriptados no se ven afectados)." "Green"
}
catch {
    Write-Log "No se pudo bloquear el auto-encriptado de BitLocker: $($_.Exception.Message)" "Yellow"
}

# --- Mostrar extensiones de archivo y archivos ocultos ---
Write-Log "`nMostrando extensiones de archivo y archivos ocultos..." "Cyan"
try {
    $advancedPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    Set-ItemProperty -Path $advancedPath -Name "HideFileExt" -Value 0 -Type DWord -Force -ErrorAction Stop
    Set-ItemProperty -Path $advancedPath -Name "Hidden" -Value 1 -Type DWord -Force -ErrorAction Stop
    Write-Log "Extensiones y archivos ocultos configurados para mostrarse." "Green"
}
catch {
    Write-Log "No se pudo aplicar la configuracion del Explorador: $($_.Exception.Message)" "Yellow"
}

# ===================== TWEAKS SOLO WINDOWS 11 =====================
if ($isWin11) {
    Write-Log "`n===== Aplicando tweaks de Windows 11 =====" "Cyan"

    # --- Copilot ---
    try {
        Set-Reg -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ShowCopilotButton" -Value 0
        Set-Reg -Path "HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot" -Name "TurnOffWindowsCopilot" -Value 1
        Set-Reg -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot" -Name "TurnOffWindowsCopilot" -Value 1
        Write-Log "Microsoft Copilot desactivado." "Green"
    }
    catch {
        Write-Log "No se pudo desactivar Copilot: $($_.Exception.Message)" "Yellow"
    }

    if ($isWin11AI) {
        # --- Recall ---
        try {
            Set-Reg -Path "HKCU:\Software\Policies\Microsoft\Windows\WindowsAI" -Name "DisableAIDataAnalysis" -Value 1
            Set-Reg -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" -Name "DisableAIDataAnalysis" -Value 1
            Set-Reg -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" -Name "AllowRecallEnablement" -Value 0
            Set-Reg -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" -Name "TurnOffSavingSnapshots" -Value 1
            Write-Log "Windows Recall desactivado." "Green"
        }
        catch {
            Write-Log "No se pudo desactivar Recall: $($_.Exception.Message)" "Yellow"
        }

        # --- Click to Do ---
        try {
            Set-Reg -Path "HKCU:\Software\Policies\Microsoft\Windows\WindowsAI" -Name "DisableClickToDo" -Value 1
            Set-Reg -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" -Name "DisableClickToDo" -Value 1
            Write-Log "Click To Do desactivado." "Green"
        }
        catch {
            Write-Log "No se pudo desactivar Click To Do: $($_.Exception.Message)" "Yellow"
        }

        # --- Edge AI ---
        try {
            $edgePolicyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"
            foreach ($name in @("CopilotCDPPageContext", "CopilotPageContext", "HubsSidebarEnabled", "EdgeEntraCopilotPageContext", "EdgeHistoryAISearchEnabled", "ComposeInlineEnabled", "NewTabPageBingChatEnabled")) {
                Set-Reg -Path $edgePolicyPath -Name $name -Value 0
            }
            Write-Log "Funciones de IA de Microsoft Edge desactivadas." "Green"
        }
        catch {
            Write-Log "No se pudieron desactivar las funciones de IA de Edge: $($_.Exception.Message)" "Yellow"
        }

        # --- Notepad AI ---
        try {
            Set-Reg -Path "HKLM:\SOFTWARE\Policies\WindowsNotepad" -Name "DisableAIFeatures" -Value 1
            Write-Log "Funciones de IA de Notepad desactivadas." "Green"
        }
        catch {
            Write-Log "No se pudieron desactivar las funciones de IA de Notepad: $($_.Exception.Message)" "Yellow"
        }

        # --- Paint AI ---
        try {
            $paintPolicyPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Paint"
            foreach ($name in @("DisableCocreator", "DisableGenerativeFill", "DisableImageCreator", "DisableGenerativeErase", "DisableRemoveBackground")) {
                Set-Reg -Path $paintPolicyPath -Name $name -Value 1
            }
            Write-Log "Funciones de IA de Paint desactivadas." "Green"
        }
        catch {
            Write-Log "No se pudieron desactivar las funciones de IA de Paint: $($_.Exception.Message)" "Yellow"
        }
    }
    else {
        Write-Log "Build $buildNumber es anterior a 22621: se omiten Recall/Click to Do/IA de Edge-Notepad-Paint (no aplican en esta version)." "Yellow"
    }

    # --- Widgets ---
    try {
        Get-Process -Name "*Widget*" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
        Get-AppxPackage "Microsoft.WidgetsPlatformRuntime" -AllUsers -ErrorAction SilentlyContinue | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
        Get-AppxPackage "MicrosoftWindows.Client.WebExperience" -AllUsers -ErrorAction SilentlyContinue | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
        Set-Reg -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarDa" -Value 0
        Write-Log "Widgets de la barra de tareas desactivados." "Green"
    }
    catch {
        Write-Log "No se pudieron desactivar los widgets: $($_.Exception.Message)" "Yellow"
    }

    # --- Menu contextual clasico de Windows 10 ---
    try {
        $classicMenuPath = "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32"
        Set-Reg -Path $classicMenuPath -Name "(default)" -Value "" -Type String
        Write-Log "Menu contextual clasico de Windows 10 activado." "Green"
    }
    catch {
        Write-Log "No se pudo activar el menu contextual clasico: $($_.Exception.Message)" "Yellow"
    }
}
else {
    Write-Log "`nWindows 10 detectado: se omiten los tweaks exclusivos de Windows 11 (Copilot, Recall, widgets, etc.)." "Yellow"
}

# --- Reiniciar el Explorador para aplicar los cambios visuales (archivos ocultos, widgets, menu contextual) ---
Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
Start-Process explorer

# ===================== LISTA DE APPS A INSTALAR =====================
$appCatalog = @{
    Chrome   = @{ Name = "Google Chrome"; Id = "Google.Chrome" }
    Brave    = @{ Name = "Brave"; Id = "Brave.Brave" }
    Firefox  = @{ Name = "Mozilla Firefox"; Id = "Mozilla.Firefox" }
    WinRAR   = @{ Name = "WinRAR"; Id = "RARLab.WinRAR" }
    NanaZip  = @{ Name = "NanaZip"; Id = "M2Team.NanaZip" }
    Discord  = @{ Name = "Discord"; Id = "Discord.Discord" }
    Steam    = @{ Name = "Steam"; Id = "Valve.Steam" }
    Epic     = @{ Name = "Epic Games Launcher"; Id = "EpicGames.EpicGamesLauncher" }
    MoviesTV = @{ Name = "Peliculas y TV"; Id = "9WZDNCRFJ3PZ"; Source = "msstore" }
    VLC      = @{ Name = "VLC media player"; Id = "VideoLAN.VLC" }
}

$apps = @()

switch ($browserChoice) {
    1 { $apps += $appCatalog.Chrome }
    2 { $apps += $appCatalog.Brave }
    3 { $apps += $appCatalog.Firefox }
}

switch ($compressorChoice) {
    1 { $apps += $appCatalog.WinRAR }
    2 { $apps += $appCatalog.NanaZip }
}

if ($wantsGamingApps) {
    $apps += $appCatalog.Discord
    $apps += $appCatalog.Steam
    $apps += $appCatalog.Epic
}

switch ($playerChoice) {
    1 { $apps += $appCatalog.MoviesTV }
    2 { $apps += $appCatalog.VLC }
}

$results = @()

foreach ($app in $apps) {
    Write-Log "`nInstalando $($app.Name)..." "Cyan"

    $wingetArgs = @("install", "--id", $app.Id, "-e", "--silent", "--accept-package-agreements", "--accept-source-agreements")
    if ($app.Source) { $wingetArgs += @("--source", $app.Source) }

    $output = & winget @wingetArgs 2>&1
    $exitCode = $LASTEXITCODE

    # -1978335189 (0x8A15002B) = APPINSTALLER_CLI_ERROR_UPDATE_NOT_APPLICABLE: ya instalado y al dia.
    if ($exitCode -eq 0) {
        Write-Log "$($app.Name) instalado correctamente." "Green"
        $status = "Instalado"
    }
    elseif ($exitCode -eq -1978335189 -or $output -match "already installed|no upgrade found|no applicable update") {
        Write-Log "$($app.Name) ya estaba instalado." "Yellow"
        $status = "Ya estaba instalado"
    }
    else {
        Write-Log "Fallo al instalar $($app.Name) (codigo $exitCode)." "Red"
        $status = "Fallo (codigo $exitCode)"
    }

    $results += [PSCustomObject]@{ App = $app.Name; Estado = $status }
}

# --- Debloat de Brave (si se pidio) ---
if ($browserChoice -eq 2 -and $wantsBraveDebloat) {
    Write-Log "`nAplicando debloat de Brave..." "Cyan"
    try {
        $bravePolicyPath = "HKLM:\Software\Policies\BraveSoftware\Brave"
        Set-Reg -Path $bravePolicyPath -Name "BraveVPNDisabled" -Value 1
        Set-Reg -Path $bravePolicyPath -Name "BraveWalletDisabled" -Value 1
        Set-Reg -Path $bravePolicyPath -Name "BraveAIChatEnabled" -Value 0
        Set-Reg -Path $bravePolicyPath -Name "BraveRewardsDisabled" -Value 1
        Set-Reg -Path $bravePolicyPath -Name "BraveTalkDisabled" -Value 1
        Set-Reg -Path $bravePolicyPath -Name "BraveNewsDisabled" -Value 1
        Write-Log "Debloat de Brave aplicado (IA, Wallet, Rewards, Talk y News desactivados)." "Green"
    }
    catch {
        Write-Log "No se pudo aplicar el debloat de Brave: $($_.Exception.Message)" "Yellow"
    }
}

# --- Cambiar fondo de pantalla ---
Write-Log "`nDescargando y aplicando fondo de pantalla..." "Cyan"
try {
    $wallpaperPath = Join-Path $env:LOCALAPPDATA "KHRAM\wall.png"
    New-Item -Path (Split-Path $wallpaperPath) -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null
    Invoke-WebRequest -Uri $WallpaperUrl -OutFile $wallpaperPath -UseBasicParsing

    Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "WallpaperStyle" -Value "10" -Type String -Force
    Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "TileWallpaper" -Value "0" -Type String -Force

    if (-not ("Win32.Wallpaper" -as [type])) {
        Add-Type -Namespace Win32 -Name Wallpaper -MemberDefinition @"
            [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
            public static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
"@
    }
    # SPI_SETDESKWALLPAPER = 0x0014, SPIF_UPDATEINIFILE | SPIF_SENDCHANGE = 0x03
    [Win32.Wallpaper]::SystemParametersInfo(0x0014, 0, $wallpaperPath, 0x03) | Out-Null
    Write-Log "Fondo de pantalla actualizado." "Green"
}
catch {
    Write-Log "No se pudo cambiar el fondo de pantalla: $($_.Exception.Message)" "Yellow"
}

Write-Host "`n===== Resumen =====" -ForegroundColor Cyan
$results | Format-Table -AutoSize

Write-Log "Log guardado en: $LogFile" "DarkGray"
Write-Host "IMPORTANTE: reinicia la PC para que Core Isolation (VBS), la pausa de Windows Update y los widgets queden aplicados del todo." -ForegroundColor Magenta
