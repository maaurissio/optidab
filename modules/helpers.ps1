<#
  Funciones compartidas: logging, escritura de registro con chequeo previo,
  el envoltorio de tweaks y los menus interactivos. Todos los demas modulos
  dependen de este, asi que se carga primero.
#>

# Escribe en consola con color y deja el mismo texto en el log del Escritorio.
function Write-Log {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    Write-Host $Message -ForegroundColor $Color
    if ($Global:KhramLog) {
        $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        Add-Content -Path $Global:KhramLog -Value "[$timestamp] $Message" -ErrorAction SilentlyContinue
    }
}

# Escribe un valor de registro solo si todavia no esta asi. Si tiene que escribir,
# marca $Global:KhramChanged para que Invoke-Tweak sepa que hubo un cambio real.
function Set-Reg {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)]$Value,
        [string]$Type = "DWord"
    )
    $exists = $false
    $current = $null
    if (Test-Path $Path) {
        $prop = Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue
        if ($null -ne $prop -and ($prop.PSObject.Properties.Name -contains $Name)) {
            $exists = $true
            $current = $prop.$Name
        }
    }
    if ($exists -and "$current" -eq "$Value") {
        return
    }
    if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
    Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type -Force
    $Global:KhramChanged = $true
}

# Corre un tweak y avisa si de verdad hizo falta cambiar algo o si ya estaba listo.
# El bloque $Actions puede setear $Global:KhramChanged y/o $Global:KhramNote para dar
# un mensaje mas preciso que el generico.
function Invoke-Tweak {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][scriptblock]$Actions
    )
    Write-Log "`nRevisando $Name..." "Cyan"
    $Global:KhramChanged = $false
    $Global:KhramNote = $null
    try {
        & $Actions
        if ($Global:KhramNote) {
            $noteColor = if ($Global:KhramChanged) { "Green" } else { "DarkGray" }
            Write-Log $Global:KhramNote $noteColor
        }
        elseif ($Global:KhramChanged) {
            Write-Log "$Name aplicado." "Green"
        }
        else {
            Write-Log "$Name ya estaba aplicado, sin cambios." "DarkGray"
        }
    }
    catch {
        Write-Log "No se pudo aplicar '$Name': $($_.Exception.Message)" "Yellow"
    }
}

# Pregunta S/N y devuelve $true si el usuario respondio que si.
function Read-YesNo {
    param([string]$Prompt)
    do {
        $r = Read-Host "$Prompt (S/N)"
    } while ($r -notmatch '^(?i:s|n)$')
    return ($r -match '^(?i:s)$')
}

# Muestra un menu numerado y devuelve el numero elegido (1-based).
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

# Imprime la tabla final de resultados de instalacion y el recordatorio de reinicio.
function Show-Summary {
    param([object[]]$Results)
    Write-Host "`n===== Resumen =====" -ForegroundColor Cyan
    if ($Results) {
        $Results | Format-Table -AutoSize
    }
    else {
        Write-Host "No se instalo ninguna app." -ForegroundColor DarkGray
    }
    Write-Log "Log guardado en: $Global:KhramLog" "DarkGray"
    Write-Host "IMPORTANTE: reinicia la PC para que Core Isolation (VBS), la pausa de Windows Update y los widgets queden aplicados del todo." -ForegroundColor Magenta
}
