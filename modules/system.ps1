<#
  Ajustes de rendimiento y sistema que valen para Windows 10 y 11: mouse, energia,
  red, actualizaciones, BitLocker, Teclas especiales, Storage Sense, inicio rapido,
  Modern Standby y mostrar archivos ocultos.
#>

function Invoke-SystemTweaks {
    # Aceleracion del mouse ("Mejorar precision del puntero").
    Invoke-Tweak -Name "Aceleracion del mouse" -Actions {
        Set-Reg -Path "HKCU:\Control Panel\Mouse" -Name "MouseSpeed" -Value "0" -Type String
        Set-Reg -Path "HKCU:\Control Panel\Mouse" -Name "MouseThreshold1" -Value "0" -Type String
        Set-Reg -Path "HKCU:\Control Panel\Mouse" -Name "MouseThreshold2" -Value "0" -Type String

        if (-not ("Win32.Mouse" -as [type])) {
            Add-Type -Namespace Win32 -Name Mouse -MemberDefinition @"
            [DllImport("user32.dll", SetLastError = true)]
            public static extern bool SystemParametersInfo(uint uiAction, uint uiParam, int[] pvParam, uint fWinIni);
"@
        }
        # SPI_SETMOUSE = 0x0004, aplica el cambio al toque sin cerrar sesion.
        [Win32.Mouse]::SystemParametersInfo(0x0004, 0, @(0, 0, 0), 0) | Out-Null
    }

    Invoke-Tweak -Name "Plan de energia 'Rendimiento maximo'" -Actions {
        $activeScheme = (powercfg -getactivescheme) -join " "
        if ($activeScheme -match "Rendimiento m.ximo|Ultimate Performance") {
            return
        }

        # Si el plan ya existe lo reusamos; si no, lo duplicamos del esquema oculto de Windows.
        $existingPlan = (powercfg -list) | Select-String -Pattern "([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}).*(Rendimiento m.ximo|Ultimate Performance)"
        if ($existingPlan) {
            $planGuid = $existingPlan.Matches[0].Groups[1].Value
        }
        else {
            $dupOutput = powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61
            $planGuid = [regex]::Match(($dupOutput -join " "), "([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})").Value
        }
        if (-not $planGuid) { throw "No se pudo obtener el GUID del plan." }
        powercfg -setactive $planGuid
        $Global:KhramChanged = $true
    }

    Invoke-Tweak -Name "Algoritmo de Nagle" -Actions {
        $interfacesPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces"
        Get-ChildItem -Path $interfacesPath -ErrorAction Stop | ForEach-Object {
            $tcpAck = (Get-ItemProperty -Path $_.PsPath -Name "TcpAckFrequency" -ErrorAction SilentlyContinue).TcpAckFrequency
            $tcpNoDelay = (Get-ItemProperty -Path $_.PsPath -Name "TCPNoDelay" -ErrorAction SilentlyContinue).TCPNoDelay
            if ($tcpAck -ne 1 -or $tcpNoDelay -ne 1) {
                Set-ItemProperty -Path $_.PsPath -Name "TcpAckFrequency" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
                Set-ItemProperty -Path $_.PsPath -Name "TCPNoDelay" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
                $Global:KhramChanged = $true
            }
        }
    }

    # Pausa de Windows Update: es el mismo mecanismo del boton "Pausar" de Configuracion.
    # 35 dias es el maximo que deja Windows. No es permanente.
    Invoke-Tweak -Name "Pausa de Windows Update" -Actions {
        $wuSettingsPath = "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings"
        $currentExpiry = (Get-ItemProperty -Path $wuSettingsPath -Name "PauseUpdatesExpiryTime" -ErrorAction SilentlyContinue).PauseUpdatesExpiryTime
        $stillPaused = $false
        if ($currentExpiry) {
            try { $stillPaused = ([datetime]$currentExpiry) -gt (Get-Date) } catch { $stillPaused = $false }
        }

        if ($stillPaused) {
            $Global:KhramNote = "Windows Update ya estaba pausado hasta el $currentExpiry."
        }
        else {
            $pauseStart = Get-Date -Format "yyyy-MM-dd"
            $pauseExpiry = (Get-Date).AddDays(35).ToString("yyyy-MM-dd")
            Set-Reg -Path $wuSettingsPath -Name "PauseUpdatesStartTime" -Value $pauseStart -Type String
            Set-Reg -Path $wuSettingsPath -Name "PauseUpdatesExpiryTime" -Value $pauseExpiry -Type String
            $Global:KhramChanged = $true
            $Global:KhramNote = "Windows Update pausado hasta el $pauseExpiry."
        }
        Set-Reg -Path $wuSettingsPath -Name "IsContinuousInnovationOptedIn" -Value 0
    }

    # BitLocker: bloquea el auto-encriptado. Los discos que ya estan encriptados no se tocan.
    Invoke-Tweak -Name "Auto-encriptado de BitLocker" -Actions {
        Set-Reg -Path "HKLM:\SYSTEM\CurrentControlSet\Control\BitLocker" -Name "PreventDeviceEncryption" -Value 1
    }

    Invoke-Tweak -Name "Atajo de Teclas especiales (5x Shift)" -Actions {
        Set-Reg -Path "HKCU:\Control Panel\Accessibility\StickyKeys" -Name "Flags" -Value "506" -Type String
    }

    Invoke-Tweak -Name "Storage Sense" -Actions {
        Set-Reg -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy" -Name "01" -Value 0
    }

    # Apaga el inicio rapido para que el "Apagar" sea un apagado completo.
    Invoke-Tweak -Name "Inicio rapido (Fast Startup)" -Actions {
        Set-Reg -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power" -Name "HiberbootEnabled" -Value 0
    }

    Invoke-Tweak -Name "Red durante Modern Standby" -Actions {
        $modernStandbyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Power\PowerSettings\f15576e8-98b7-4186-b944-eafa664402d9"
        Set-Reg -Path $modernStandbyPath -Name "ACSettingIndex" -Value 0
        Set-Reg -Path $modernStandbyPath -Name "DCSettingIndex" -Value 0
    }

    Invoke-Tweak -Name "Extensiones y archivos ocultos" -Actions {
        $advancedPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
        Set-Reg -Path $advancedPath -Name "HideFileExt" -Value 0
        Set-Reg -Path $advancedPath -Name "Hidden" -Value 1
    }
}
