<#
  Prepara el entorno: arma la ruta del log, detecta si es Windows 10 u 11 y
  chequea que winget este disponible.
#>

# Deja listo el log y las variables de version que usan los demas modulos.
function Initialize-Environment {
    $Global:KhramLog = Join-Path ([Environment]::GetFolderPath('Desktop')) "KHRAM-Optimizacion-$(Get-Date -Format yyyyMMdd-HHmmss).log"
    Write-Log "Log de esta ejecucion: $Global:KhramLog" "DarkGray"

    $Global:KhramBuild = [int](Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').CurrentBuildNumber
    $Global:KhramWin11 = $Global:KhramBuild -ge 22000
    # Recall, Click to Do y la IA de Edge/Notepad/Paint recien existen desde la build 22621.
    $Global:KhramWin11AI = $Global:KhramBuild -ge 22621

    $nombre = if ($Global:KhramWin11) { 'Windows 11' } else { 'Windows 10' }
    Write-Log "Sistema detectado: $nombre (build $Global:KhramBuild)" "Cyan"
}

# Corta la ejecucion si no hay winget, porque sin el no se puede instalar nada.
function Assert-Winget {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Log "winget no esta disponible. Actualiza 'App Installer' desde la Microsoft Store e intenta de nuevo." "Red"
        exit 1
    }
}
