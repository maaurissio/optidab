<#
  Apaga la Xbox Game Bar y la grabacion Game DVR, pero deja el Game Mode prendido.
#>

function Invoke-GamingTweaks {
    Invoke-Tweak -Name "Xbox Game Bar / Game DVR" -Actions {
        Set-Reg -Path "HKCU:\System\GameConfigStore" -Name "GameDVR_Enabled" -Value 0
        Set-Reg -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" -Name "AppCaptureEnabled" -Value 0
        Set-Reg -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR" -Name "AllowGameDVR" -Value 0
        Set-Reg -Path "HKCU:\Software\Microsoft\GameBar" -Name "UseNexusForGameBarEnabled" -Value 0

        # Frena los popups ms-gamebar que aparecen al conectar un control o abrir un juego.
        foreach ($protocol in @("ms-gamebar", "ms-gamebarservices")) {
            $protoPath = "Registry::HKEY_CLASSES_ROOT\$protocol"
            Set-Reg -Path $protoPath -Name "(default)" -Value "URL: $protocol" -Type String
            Set-Reg -Path $protoPath -Name "URL Protocol" -Value "" -Type String
            Set-Reg -Path $protoPath -Name "NoOpenWith" -Value "" -Type String
            Set-Reg -Path "$protoPath\shell\open\command" -Name "(default)" -Value "$env:SystemRoot\System32\systray.exe" -Type String
        }

        # El Game Mode queda prendido a proposito.
        Set-Reg -Path "HKCU:\Software\Microsoft\GameBar" -Name "AutoGameModeEnabled" -Value 1
    }
}
