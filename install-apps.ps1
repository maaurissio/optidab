<#
  Script de instalacion post-formateo.
  Uso despues de formatear (PowerShell, sin nada mas instalado):
    irm https://raw.githubusercontent.com/<usuario>/<repo>/main/install-apps.ps1 | iex

  Publicacion:
    1. Sube este archivo a un repo de GitHub.
    2. Reemplaza $ScriptUrl abajo con la raw URL real del archivo y vuelve a subirlo
       (se usa solo para la auto-elevacion a administrador).

  Nota: este script tambien desactiva Windows Defender (rendimiento). Antes de correrlo,
  desactiva "Proteccion contra alteraciones" a mano en Seguridad de Windows, o Windows
  revierte el cambio solo. Ver comentario en esa seccion mas abajo.

  Tambien aplica tweaks de rendimiento/comodidad: desactiva Core Isolation (VBS/HVCI,
  requiere reiniciar), quita el icono de bandeja de Seguridad de Windows, oculta la seccion
  "Control de aplicaciones y navegador", desactiva aceleracion del mouse, activa el plan de
  energia "Rendimiento maximo", desactiva Xbox Game Bar / Game DVR, desactiva el algoritmo
  de Nagle (latencia de red), y muestra extensiones/archivos ocultos.
#>

$ScriptUrl = "https://raw.githubusercontent.com/<usuario>/<repo>/main/install-apps.ps1"

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

# --- Chequeo de winget ---
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Host "winget no esta disponible. Actualiza 'App Installer' desde la Microsoft Store e intenta de nuevo." -ForegroundColor Red
    exit 1
}

# --- Chequeo de Proteccion contra alteraciones (Tamper Protection) ---
# Microsoft bloquea a proposito que esto se desactive por script. Si sigue activada,
# Windows revierte solo el paso de Defender, asi que cortamos aca y abrimos Seguridad
# de Windows para que la desactives a mano. Si Defender ya no esta instalado, se salta esto.
$defenderStatus = Get-MpComputerStatus -ErrorAction SilentlyContinue
if ($defenderStatus -and $defenderStatus.IsTamperProtected) {
    Write-Host "`nProteccion contra alteraciones esta ACTIVADA." -ForegroundColor Red
    Write-Host "Abriendo Seguridad de Windows para que la desactives..." -ForegroundColor Yellow
    Start-Process "windowsdefender://threatsettings"
    Write-Host "Ve a 'Proteccion contra alteraciones' y apagala, despues vuelve a correr el script." -ForegroundColor Yellow
    exit 1
}

# --- Desactivar Windows Defender (rendimiento) ---
Write-Host "`nDesactivando Windows Defender..." -ForegroundColor Cyan

try {
    Set-MpPreference -DisableRealtimeMonitoring $true -DisableBehaviorMonitoring $true `
        -DisableIOAVProtection $true -DisableScriptScanning $true -DisableArchiveScanning $true `
        -MAPSReporting Disabled -SubmitSamplesConsent NeverSend -ErrorAction Stop
    Write-Host "Proteccion en tiempo real desactivada." -ForegroundColor Green
}
catch {
    Write-Host "No se pudo aplicar Set-MpPreference: $($_.Exception.Message)" -ForegroundColor Yellow
}

try {
    $policyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender"
    if (-not (Test-Path $policyPath)) { New-Item -Path $policyPath -Force | Out-Null }
    Set-ItemProperty -Path $policyPath -Name "DisableAntiSpyware" -Value 1 -Type DWord -Force -ErrorAction Stop
    Write-Host "Politica DisableAntiSpyware aplicada." -ForegroundColor Green
}
catch {
    Write-Host "No se pudo escribir la politica de registro: $($_.Exception.Message)" -ForegroundColor Yellow
}

try {
    Get-ScheduledTask -TaskPath "\Microsoft\Windows\Windows Defender\" -ErrorAction Stop |
        Disable-ScheduledTask -ErrorAction SilentlyContinue | Out-Null
    Write-Host "Tareas programadas de Defender desactivadas." -ForegroundColor Green
}
catch {
    Write-Host "No se pudieron desactivar las tareas programadas: $($_.Exception.Message)" -ForegroundColor Yellow
}

try {
    Set-Service -Name WinDefend -StartupType Disabled -ErrorAction Stop
    Write-Host "Servicio WinDefend deshabilitado." -ForegroundColor Green
}
catch {
    Write-Host "No se pudo deshabilitar el servicio WinDefend (normal si Tamper Protection sigue activo)." -ForegroundColor Yellow
}

# --- Desactivar Core Isolation / Memory Integrity (VBS + HVCI) ---
# IMPORTANTE: esto necesita reiniciar la PC para aplicarse (a diferencia de los demas tweaks).
# Reduce protecciones contra ciertos exploits de kernel/hypervisor a cambio de rendimiento.
Write-Host "`nDesactivando Core Isolation (VBS)..." -ForegroundColor Cyan
try {
    $hvciPath = "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity"
    if (-not (Test-Path $hvciPath)) { New-Item -Path $hvciPath -Force | Out-Null }
    Set-ItemProperty -Path $hvciPath -Name "Enabled" -Value 0 -Type DWord -Force -ErrorAction Stop
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard" -Name "EnableVirtualizationBasedSecurity" -Value 0 -Type DWord -Force -ErrorAction Stop
    Write-Host "Core Isolation (VBS) desactivado. Se aplica recien despues de reiniciar." -ForegroundColor Green
}
catch {
    Write-Host "No se pudo desactivar Core Isolation: $($_.Exception.Message)" -ForegroundColor Yellow
}

# --- Quitar el icono de Seguridad de Windows de la bandeja del sistema ---
Write-Host "`nQuitando icono de Seguridad de Windows de la bandeja..." -ForegroundColor Cyan
try {
    Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" -Name "SecurityHealth" -ErrorAction Stop
    Write-Host "Icono de bandeja de Seguridad de Windows desactivado." -ForegroundColor Green
}
catch {
    Write-Host "El icono de bandeja ya estaba desactivado o no se pudo quitar." -ForegroundColor Yellow
}

# --- Ocultar seccion "Control de aplicaciones y navegador" en Seguridad de Windows ---
Write-Host "`nOcultando 'Control de aplicaciones y navegador'..." -ForegroundColor Cyan
try {
    $abcPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender Security Center\App and Browser protection"
    if (-not (Test-Path $abcPath)) { New-Item -Path $abcPath -Force | Out-Null }
    Set-ItemProperty -Path $abcPath -Name "UILockdown" -Value 1 -Type DWord -Force -ErrorAction Stop
    Write-Host "Seccion ocultada." -ForegroundColor Green
}
catch {
    Write-Host "No se pudo ocultar la seccion: $($_.Exception.Message)" -ForegroundColor Yellow
}

# --- Desactivar aceleracion del mouse ("Mejorar precision del puntero") ---
Write-Host "`nDesactivando aceleracion del mouse..." -ForegroundColor Cyan
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

    Write-Host "Aceleracion del mouse desactivada." -ForegroundColor Green
}
catch {
    Write-Host "No se pudo desactivar la aceleracion del mouse: $($_.Exception.Message)" -ForegroundColor Yellow
}

# --- Plan de energia "Rendimiento maximo" (Ultimate Performance) ---
Write-Host "`nActivando plan de energia 'Rendimiento maximo'..." -ForegroundColor Cyan
try {
    $dupOutput = powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61
    $planGuid = [regex]::Match(($dupOutput -join " "), "([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})").Value
    if (-not $planGuid) { throw "No se pudo obtener el GUID del plan nuevo." }
    powercfg -setactive $planGuid
    Write-Host "Plan de energia 'Rendimiento maximo' activado." -ForegroundColor Green
}
catch {
    Write-Host "No se pudo activar el plan de rendimiento maximo: $($_.Exception.Message)" -ForegroundColor Yellow
}

# --- Desactivar Xbox Game Bar / Game DVR ---
Write-Host "`nDesactivando Xbox Game Bar / Game DVR..." -ForegroundColor Cyan
try {
    if (-not (Test-Path "HKCU:\System\GameConfigStore")) { New-Item -Path "HKCU:\System\GameConfigStore" -Force | Out-Null }
    Set-ItemProperty -Path "HKCU:\System\GameConfigStore" -Name "GameDVR_Enabled" -Value 0 -Type DWord -Force -ErrorAction Stop

    $gameDvrPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR"
    if (-not (Test-Path $gameDvrPath)) { New-Item -Path $gameDvrPath -Force | Out-Null }
    Set-ItemProperty -Path $gameDvrPath -Name "AppCaptureEnabled" -Value 0 -Type DWord -Force -ErrorAction Stop

    $gameDvrPolicyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR"
    if (-not (Test-Path $gameDvrPolicyPath)) { New-Item -Path $gameDvrPolicyPath -Force | Out-Null }
    Set-ItemProperty -Path $gameDvrPolicyPath -Name "AllowGameDVR" -Value 0 -Type DWord -Force -ErrorAction Stop

    Write-Host "Xbox Game Bar / Game DVR desactivado." -ForegroundColor Green
}
catch {
    Write-Host "No se pudo desactivar Game DVR: $($_.Exception.Message)" -ForegroundColor Yellow
}

# --- Desactivar algoritmo de Nagle (menor latencia de red) ---
Write-Host "`nDesactivando algoritmo de Nagle..." -ForegroundColor Cyan
try {
    $interfacesPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces"
    Get-ChildItem -Path $interfacesPath -ErrorAction Stop | ForEach-Object {
        Set-ItemProperty -Path $_.PsPath -Name "TcpAckFrequency" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $_.PsPath -Name "TCPNoDelay" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
    }
    Write-Host "Algoritmo de Nagle desactivado en todas las interfaces de red." -ForegroundColor Green
}
catch {
    Write-Host "No se pudo desactivar el algoritmo de Nagle: $($_.Exception.Message)" -ForegroundColor Yellow
}

# --- Mostrar extensiones de archivo y archivos ocultos ---
Write-Host "`nMostrando extensiones de archivo y archivos ocultos..." -ForegroundColor Cyan
try {
    $advancedPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    Set-ItemProperty -Path $advancedPath -Name "HideFileExt" -Value 0 -Type DWord -Force -ErrorAction Stop
    Set-ItemProperty -Path $advancedPath -Name "Hidden" -Value 1 -Type DWord -Force -ErrorAction Stop
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    Start-Process explorer
    Write-Host "Extensiones y archivos ocultos visibles." -ForegroundColor Green
}
catch {
    Write-Host "No se pudo aplicar la configuracion del Explorador: $($_.Exception.Message)" -ForegroundColor Yellow
}

# --- Lista de apps a instalar ---
$apps = @(
    @{ Name = "Discord";              Id = "Discord.Discord" }
    @{ Name = "Steam";                Id = "Valve.Steam" }
    @{ Name = "Brave";                Id = "Brave.Brave" }
    @{ Name = "Epic Games Launcher";  Id = "EpicGames.EpicGamesLauncher" }
    @{ Name = "NanaZip";              Id = "M2Team.NanaZip" }
    @{ Name = "VLC media player";     Id = "VideoLAN.VLC" }
    @{ Name = "Logitech G HUB";       Id = "Logitech.GHUB" }
)

$results = @()

foreach ($app in $apps) {
    Write-Host "`nInstalando $($app.Name)..." -ForegroundColor Cyan

    $output = winget install --id $app.Id -e --silent --accept-package-agreements --accept-source-agreements 2>&1
    $exitCode = $LASTEXITCODE

    # -1978335189 (0x8A15002B) = APPINSTALLER_CLI_ERROR_UPDATE_NOT_APPLICABLE: ya instalado y al dia.
    if ($exitCode -eq 0) {
        Write-Host "$($app.Name) instalado correctamente." -ForegroundColor Green
        $status = "Instalado"
    }
    elseif ($exitCode -eq -1978335189 -or $output -match "already installed|no upgrade found|no applicable update") {
        Write-Host "$($app.Name) ya estaba instalado." -ForegroundColor Yellow
        $status = "Ya estaba instalado"
    }
    else {
        Write-Host "Fallo al instalar $($app.Name) (codigo $exitCode)." -ForegroundColor Red
        $status = "Fallo (codigo $exitCode)"
    }

    $results += [PSCustomObject]@{ App = $app.Name; Estado = $status }
}

Write-Host "`n===== Resumen =====" -ForegroundColor Cyan
$results | Format-Table -AutoSize

Write-Host "IMPORTANTE: reinicia la PC para que Core Isolation (VBS) quede desactivado." -ForegroundColor Magenta
