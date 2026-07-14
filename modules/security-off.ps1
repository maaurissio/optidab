<#
  Apaga Windows Defender, Core Isolation (VBS) y esconde lo que queda de Seguridad
  de Windows. Todo esto es a cambio de rendimiento.
#>

# Si la Proteccion contra alteraciones sigue prendida, Windows revierte solo el paso
# de Defender. Microsoft la bloquea a proposito para que no se apague por script, asi
# que cortamos aca y abrimos Seguridad de Windows para que la apagues a mano.
function Assert-TamperProtectionOff {
    $defenderStatus = Get-MpComputerStatus -ErrorAction SilentlyContinue
    if ($defenderStatus -and $defenderStatus.IsTamperProtected) {
        Write-Log "`nLa Proteccion contra alteraciones esta ACTIVADA." "Red"
        Write-Log "Abriendo Seguridad de Windows para que la apagues..." "Yellow"
        Start-Process "windowsdefender://threatsettings"
        Write-Log "Anda a 'Proteccion contra alteraciones', apagala y volve a correr el script." "Yellow"
        exit 1
    }
}

function Disable-WindowsDefender {
    Invoke-Tweak -Name "Proteccion en tiempo real de Defender" -Actions {
        $prefs = Get-MpPreference -ErrorAction SilentlyContinue
        if (-not $prefs -or -not $prefs.DisableRealtimeMonitoring) {
            Set-MpPreference -DisableRealtimeMonitoring $true -DisableBehaviorMonitoring $true `
                -DisableIOAVProtection $true -DisableScriptScanning $true -DisableArchiveScanning $true `
                -MAPSReporting Disabled -SubmitSamplesConsent NeverSend -ErrorAction Stop
            $Global:KhramChanged = $true
        }
    }

    Invoke-Tweak -Name "Politica DisableAntiSpyware de Defender" -Actions {
        Set-Reg -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender" -Name "DisableAntiSpyware" -Value 1
    }

    Invoke-Tweak -Name "Tareas programadas de Defender" -Actions {
        $tasks = Get-ScheduledTask -TaskPath "\Microsoft\Windows\Windows Defender\" -ErrorAction Stop
        $enabledTasks = $tasks | Where-Object { $_.State -ne 'Disabled' }
        if ($enabledTasks) {
            $enabledTasks | Disable-ScheduledTask -ErrorAction SilentlyContinue | Out-Null
            $Global:KhramChanged = $true
        }
    }

    Invoke-Tweak -Name "Servicio WinDefend" -Actions {
        $svc = Get-Service -Name WinDefend -ErrorAction Stop
        if ($svc.StartType -ne 'Disabled') {
            Set-Service -Name WinDefend -StartupType Disabled -ErrorAction Stop
            $Global:KhramChanged = $true
        }
    }
}

# OJO: Core Isolation recien se apaga despues de reiniciar, a diferencia del resto.
function Disable-CoreIsolation {
    Invoke-Tweak -Name "Core Isolation (VBS)" -Actions {
        $hvciPath = "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity"
        Set-Reg -Path $hvciPath -Name "Enabled" -Value 0
        Set-Reg -Path "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard" -Name "EnableVirtualizationBasedSecurity" -Value 0
    }
}

function Hide-SecurityUi {
    Invoke-Tweak -Name "Icono de bandeja de Seguridad de Windows" -Actions {
        $existing = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" -Name "SecurityHealth" -ErrorAction SilentlyContinue
        if ($existing) {
            Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" -Name "SecurityHealth" -ErrorAction Stop
            $Global:KhramChanged = $true
        }
    }

    Invoke-Tweak -Name "Seccion 'Control de aplicaciones y navegador'" -Actions {
        $abcPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender Security Center\App and Browser protection"
        Set-Reg -Path $abcPath -Name "UILockdown" -Value 1
    }
}
