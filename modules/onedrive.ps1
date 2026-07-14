<#
  Saca OneDrive si esta instalado: lo desinstala con su propio uninstaller y limpia
  las carpetas y el servicio de sync que deja atras. Si no esta, no hace nada.
#>

function Remove-OneDriveApp {
    Invoke-Tweak -Name "Eliminacion de OneDrive" -Actions {
        $oneDriveSetup = @(
            "$env:SystemRoot\SysWOW64\OneDriveSetup.exe",
            "$env:SystemRoot\System32\OneDriveSetup.exe"
        ) | Where-Object { Test-Path $_ } | Select-Object -First 1

        if (-not $oneDriveSetup) {
            $Global:KhramNote = "OneDrive no esta instalado, no hay nada que sacar."
            return
        }

        $oneDriveFolder = if ($env:OneDrive) { $env:OneDrive } else { "$env:USERPROFILE\OneDrive" }

        # Le negamos permiso de borrado a la carpeta para que el uninstaller no se lleve
        # los archivos del usuario, y se lo devolvemos al final.
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
        $Global:KhramChanged = $true
        $Global:KhramNote = "OneDrive eliminado."
    }
}
