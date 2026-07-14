<#
  Tweaks que solo aplican en Windows 11: Copilot, el servicio de IA, Recall,
  Click to Do, la IA de Edge/Notepad/Paint, los anuncios de Microsoft 365, el
  Drag Tray, los widgets y el menu contextual clasico.

  Recall, Click to Do y la IA de Edge/Notepad/Paint recien existen desde la build
  22621, asi que solo se aplican si $Global:KhramWin11AI esta en $true.
#>

function Invoke-Windows11Tweaks {
    Write-Log "`n===== Aplicando tweaks de Windows 11 =====" "Cyan"

    Invoke-Tweak -Name "Microsoft Copilot" -Actions {
        Set-Reg -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ShowCopilotButton" -Value 0
        Set-Reg -Path "HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot" -Name "TurnOffWindowsCopilot" -Value 1
        Set-Reg -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot" -Name "TurnOffWindowsCopilot" -Value 1
    }

    Invoke-Tweak -Name "Servicio de IA (WSAIFabricSvc)" -Actions {
        $svc = Get-Service -Name WSAIFabricSvc -ErrorAction Stop
        if ($svc.StartType -ne 'Disabled') {
            Set-Service -Name WSAIFabricSvc -StartupType Disabled -ErrorAction Stop
            $Global:KhramChanged = $true
        }
    }

    Invoke-Tweak -Name "Anuncios de Microsoft 365 en Configuracion" -Actions {
        Set-Reg -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" -Name "DisableConsumerAccountStateContent" -Value 1
    }

    Invoke-Tweak -Name "Drag Tray" -Actions {
        Set-Reg -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\CDP" -Name "DragTrayEnabled" -Value 0
    }

    if ($Global:KhramWin11AI) {
        Invoke-Tweak -Name "Windows Recall" -Actions {
            Set-Reg -Path "HKCU:\Software\Policies\Microsoft\Windows\WindowsAI" -Name "DisableAIDataAnalysis" -Value 1
            Set-Reg -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" -Name "DisableAIDataAnalysis" -Value 1
            Set-Reg -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" -Name "AllowRecallEnablement" -Value 0
            Set-Reg -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" -Name "TurnOffSavingSnapshots" -Value 1
        }

        Invoke-Tweak -Name "Click To Do" -Actions {
            Set-Reg -Path "HKCU:\Software\Policies\Microsoft\Windows\WindowsAI" -Name "DisableClickToDo" -Value 1
            Set-Reg -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" -Name "DisableClickToDo" -Value 1
        }

        Invoke-Tweak -Name "Funciones de IA de Microsoft Edge" -Actions {
            $edgePolicyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"
            foreach ($name in @("CopilotCDPPageContext", "CopilotPageContext", "HubsSidebarEnabled", "EdgeEntraCopilotPageContext", "EdgeHistoryAISearchEnabled", "ComposeInlineEnabled", "NewTabPageBingChatEnabled")) {
                Set-Reg -Path $edgePolicyPath -Name $name -Value 0
            }
        }

        Invoke-Tweak -Name "Funciones de IA de Notepad" -Actions {
            Set-Reg -Path "HKLM:\SOFTWARE\Policies\WindowsNotepad" -Name "DisableAIFeatures" -Value 1
        }

        Invoke-Tweak -Name "Funciones de IA de Paint" -Actions {
            $paintPolicyPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Paint"
            foreach ($name in @("DisableCocreator", "DisableGenerativeFill", "DisableImageCreator", "DisableGenerativeErase", "DisableRemoveBackground")) {
                Set-Reg -Path $paintPolicyPath -Name $name -Value 1
            }
        }
    }
    else {
        Write-Log "La build $Global:KhramBuild es anterior a 22621: se saltean Recall, Click to Do y la IA de Edge/Notepad/Paint porque no aplican en esta version." "Yellow"
    }

    Invoke-Tweak -Name "Widgets de la barra de tareas" -Actions {
        $widgetProcesses = Get-Process -Name "*Widget*" -ErrorAction SilentlyContinue
        if ($widgetProcesses) {
            $widgetProcesses | Stop-Process -Force -ErrorAction SilentlyContinue
            $Global:KhramChanged = $true
        }
        foreach ($pkgName in @("Microsoft.WidgetsPlatformRuntime", "MicrosoftWindows.Client.WebExperience")) {
            $pkg = Get-AppxPackage $pkgName -AllUsers -ErrorAction SilentlyContinue
            if ($pkg) {
                $pkg | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
                $Global:KhramChanged = $true
            }
        }
        Set-Reg -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarDa" -Value 0
    }

    Invoke-Tweak -Name "Menu contextual clasico de Windows 10" -Actions {
        $classicMenuPath = "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32"
        Set-Reg -Path $classicMenuPath -Name "(default)" -Value "" -Type String
    }
}
