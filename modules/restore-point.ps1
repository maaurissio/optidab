<#
  Crea un punto de restauracion antes de tocar nada, si el usuario lo pidio.
#>

function New-KhramRestorePoint {
    Write-Log "`nCreando punto de restauracion..." "Cyan"
    try {
        $srPath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore'
        $rpSession = (Get-ItemProperty -Path $srPath -Name RPSessionInterval -ErrorAction SilentlyContinue).RPSessionInterval
        if (-not $rpSession) {
            Write-Log "La proteccion del sistema estaba apagada, activandola..." "Yellow"
            Enable-ComputerRestore -Drive $env:SystemDrive
        }

        # Windows solo deja crear un punto cada 24hs. Si ya hay uno reciente, no insistimos.
        $recentRestorePoint = Get-ComputerRestorePoint -ErrorAction SilentlyContinue | Where-Object {
            (Get-Date) - [System.Management.ManagementDateTimeConverter]::ToDateTime($_.CreationTime) -le (New-TimeSpan -Hours 24)
        }

        if ($recentRestorePoint) {
            Write-Log "Ya hay un punto de restauracion de hace menos de 24hs, no se crea otro." "Yellow"
        }
        else {
            Checkpoint-Computer -Description "KHRAM Optimizer" -RestorePointType MODIFY_SETTINGS
            Write-Log "Punto de restauracion creado." "Green"
        }
    }
    catch {
        Write-Log "No se pudo crear el punto de restauracion: $($_.Exception.Message)" "Yellow"
    }
}
