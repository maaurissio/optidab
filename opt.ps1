<#

  Optimizer - instalacion y optimizacion (idealmente post-formateo) para Windows 10 y 11.

#>

$RepoBase     = "https://raw.githubusercontent.com/maaurissio/optidab/refs/heads/main"
$ScriptUrl    = "$RepoBase/opt.ps1"
$WallpaperUrl = "$RepoBase/wall.png"

# --- Banner ---
$Banner = @'
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

'@
Write-Host $Banner -ForegroundColor Magenta

# Auto-elevacion a administrador
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Se requiere administrador, relanzando elevado..." -ForegroundColor Yellow
    Start-Process powershell -Verb RunAs -ArgumentList @(
        "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command",
        "irm $ScriptUrl | iex"
    )
    exit
}

# Cargador de modulos
function Get-PartCode {
    param([string]$RelativePath)
    $localPath = if ($PSScriptRoot) { Join-Path $PSScriptRoot $RelativePath } else { "" }
    if ($localPath -and (Test-Path $localPath)) {
        return (Get-Content -Raw -Path $localPath)
    }
    $url = "$RepoBase/$($RelativePath -replace '\\', '/')"
    return (Invoke-WebRequest -Uri $url -UseBasicParsing).Content
}

$modules = @(
    "modules/helpers.ps1",
    "modules/environment.ps1",
    "modules/config.ps1",
    "modules/restore-point.ps1",
    "modules/security-off.ps1",
    "modules/privacy.ps1",
    "modules/gaming.ps1",
    "modules/onedrive.ps1",
    "modules/system.ps1",
    "modules/windows11.ps1",
    "modules/apps.ps1",
    "modules/wallpaper.ps1"
)
foreach ($module in $modules) {
    . ([scriptblock]::Create((Get-PartCode $module)))
}

# ===================== FLUJO PRINCIPAL =====================
Initialize-Environment

# Todas las preguntas primero, antes de tocar el sistema
$config = Read-UserChoices

# Ya con las respuestas, limpiamos la consola para que el output de los tweaks quede
# separado y prolijo, y volvemos a mostrar el banner.
Clear-Host
Write-Host $Banner -ForegroundColor Magenta
Write-Log "`n===== Aplicando optimizaciones =====" "Cyan"

if ($config.RestorePoint) {
    New-KhramRestorePoint
}

Assert-Winget
Assert-TamperProtectionOff

# Seguridad y rendimiento (Windows 10 y 11)
Disable-WindowsDefender
Disable-CoreIsolation
Hide-SecurityUi
Invoke-PrivacyTweaks
Invoke-GamingTweaks
Remove-OneDriveApp
Invoke-SystemTweaks

# Tweaks exclusivos de Windows 11
if ($Global:KhramWin11) {
    Invoke-Windows11Tweaks
}
else {
    Write-Log "`nWindows 10 detectado: se saltean los tweaks exclusivos de Windows 11 (Copilot, Recall, widgets, etc.)." "Yellow"
}

# Reinicia el Explorador para que se apliquen los cambios visuales (archivos ocultos,
# widgets, menu contextual).
Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
Start-Process explorer

# Instalacion de apps y fondo de pantalla
$results = Install-SelectedApps -Config $config
Set-KhramWallpaper -WallpaperUrl $WallpaperUrl

Show-Summary -Results $results
