<#
  Todo lo que se le pregunta al usuario al inicio: la pantalla opcional de "que hace
  esto", el punto de restauracion y que apps instalar. Nada de esto toca el sistema;
  solo junta las respuestas en un objeto para usarlas despues.
#>

# Resumen que se muestra si el usuario escribe 1 en la pregunta de arranque.
function Show-ScriptInfo {
    Write-Host @'

Esto es lo que hace el script:

  - Apaga Windows Defender y Core Isolation (VBS) para ganar rendimiento.
  - Corta notificaciones, telemetria, historial de actividad, tips, sugerencias,
    ubicacion, Find My Device y los anuncios de Windows y Edge.
  - Apaga la Xbox Game Bar y la grabacion Game DVR, pero deja el Game Mode prendido.
  - Si tienes OneDrive instalado, lo saca.
  - Apaga la aceleracion del mouse, pone el plan de energia "Rendimiento maximo" y
    desactiva el algoritmo de Nagle.
  - Pausa Windows Update 35 dias y bloquea el auto-encriptado de BitLocker. Los discos
    que ya estan encriptados no se tocan, si no esto demoraria hasta horas.
  - Apaga el atajo de Teclas especiales, Storage Sense, el inicio rapido y la red
    durante Modern Standby.
  - En Windows 11 tambien saca Copilot, el servicio de IA, Recall, Click to Do, la IA
    de Edge/Notepad/Paint, los anuncios de Microsoft 365 y el Drag Tray. Oculta los
    widgets y vuelve al menu contextual clasico de Windows 10.
  - Te pregunta que navegador, compresor, apps de gaming y reproductor instalar. Si no
    quieres algo, eliges "Ninguno".
  - Al final te cambia al meo fondo de pantalla.

Antes de tocar cada cosa revisa si ya estaba hecha. Si ya estaba, lo dice y sigue de
largo sin volver a cambiar nada. Solo aplica lo que falte.

'@ -ForegroundColor White
    Read-Host "Presiona Enter para continuar"
}

# Junta todas las respuestas del usuario y las devuelve en un objeto.
function Read-UserChoices {
    Write-Host "`n===== Configuracion =====" -ForegroundColor Cyan

    $readInfo = Read-Host "`n¿Que hace este script? Escribe 1 para leer un resumen, o 0 para seguir de una"
    if ($readInfo -eq "1") {
        Show-ScriptInfo
    }

    $wantsRestorePoint = Read-YesNo "`n¿Crear un punto de restauracion del sistema antes de continuar?"

    $browserChoice = Read-MenuChoice "Navegador a instalar:" @("Chrome", "Brave", "Firefox", "Ninguno")
    $wantsBraveDebloat = $false
    if ($browserChoice -eq 2) {
        $wantsBraveDebloat = Read-YesNo "¿Aplicar debloat de Brave? (apaga por politica la IA (Leo), la Wallet cripto, Rewards, Talk y News de Brave; no afecta navegar normal)"
    }

    $compressorChoice = Read-MenuChoice "Compresor de archivos a instalar:" @("WinRAR", "NanaZip", "Ninguno")

    $wantsGamingApps = Read-YesNo "`n¿Instalar Discord, Steam y Epic Games Launcher?"

    $playerChoice = Read-MenuChoice "Reproductor multimedia a instalar:" @("Peliculas y TV", "VLC", "Ninguno")

    return [PSCustomObject]@{
        RestorePoint = $wantsRestorePoint
        Browser      = $browserChoice
        BraveDebloat = $wantsBraveDebloat
        Compressor   = $compressorChoice
        GamingApps   = $wantsGamingApps
        Player       = $playerChoice
    }
}
