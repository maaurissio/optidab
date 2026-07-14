<#
  Privacidad y contenido sugerido: notificaciones, telemetria, tips/sugerencias,
  ubicacion, Find My Device y los anuncios de Edge. Vale para Windows 10 y 11.
#>

function Invoke-PrivacyTweaks {
    # Notificaciones: se apagan por registro, sin tocar el servicio.
    Invoke-Tweak -Name "Notificaciones (toast)" -Actions {
        Set-Reg -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\PushNotifications" -Name "ToastEnabled" -Value 0
    }

    Invoke-Tweak -Name "Telemetria, historial de actividad y publicidad dirigida" -Actions {
        Set-Reg -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo" -Name "Enabled" -Value 0
        Set-Reg -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy" -Name "TailoredExperiencesWithDiagnosticDataEnabled" -Value 0
        Set-Reg -Path "HKCU:\Software\Microsoft\Speech_OneCore\Settings\OnlineSpeechPrivacy" -Name "HasAccepted" -Value 0
        Set-Reg -Path "HKCU:\Software\Microsoft\Input\TIPC" -Name "Enabled" -Value 0
        Set-Reg -Path "HKCU:\Software\Microsoft\InputPersonalization" -Name "RestrictImplicitInkCollection" -Value 1
        Set-Reg -Path "HKCU:\Software\Microsoft\InputPersonalization" -Name "RestrictImplicitTextCollection" -Value 1
        Set-Reg -Path "HKCU:\Software\Microsoft\InputPersonalization\TrainedDataStore" -Name "HarvestContacts" -Value 0
        Set-Reg -Path "HKCU:\Software\Microsoft\Personalization\Settings" -Name "AcceptedPrivacyPolicy" -Value 0
        Set-Reg -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" -Name "AllowTelemetry" -Value 0
        Set-Reg -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "Start_TrackProgs" -Value 0
        Set-Reg -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "PublishUserActivities" -Value 0
        Set-Reg -Path "HKCU:\SOFTWARE\Microsoft\Siuf\Rules" -Name "NumberOfSIUFInPeriod" -Value 0
        Set-Reg -Path "HKLM:\SOFTWARE\Policies\Microsoft\Edge" -Name "PersonalizationReportingEnabled" -Value 0
        Set-Reg -Path "HKLM:\SOFTWARE\Policies\Microsoft\Edge" -Name "DiagnosticData" -Value 0
    }

    Invoke-Tweak -Name "Tips, sugerencias y anuncios de Windows" -Actions {
        $cdmPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
        foreach ($name in @("SubscribedContent-310093Enabled", "SubscribedContent-338388Enabled", "SystemPaneSuggestionsEnabled", "SubscribedContent-338389Enabled", "SoftLandingEnabled", "SubscribedContent-338393Enabled", "SubscribedContent-353694Enabled", "SubscribedContent-353696Enabled", "SubscribedContent-353698Enabled", "SilentInstalledAppsEnabled", "SubscribedContent-338387Enabled", "RotatingLockScreenOverlayEnabled")) {
            Set-Reg -Path $cdmPath -Name $name -Value 0
        }
        Set-Reg -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "Start_IrisRecommendations" -Value 0
        Set-Reg -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ShowSyncProviderNotifications" -Value 0
        Set-Reg -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "Start_AccountNotifications" -Value 0
        Set-Reg -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\SystemSettings\AccountNotifications" -Name "EnableAccountNotifications" -Value 0
        Set-Reg -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\UserProfileEngagement" -Name "ScoobeSystemSettingEnabled" -Value 0
        Set-Reg -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings\Windows.SystemToast.Suggested" -Name "Enabled" -Value 0
        Set-Reg -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Mobility" -Name "OptedIn" -Value 0
        Set-Reg -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Notifications\Settings\Windows.SystemToast.BackupReminder" -Name "Enabled" -Value 0
    }

    Invoke-Tweak -Name "Servicios de ubicacion y Find My Device" -Actions {
        Set-Reg -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors" -Name "DisableLocation" -Value 1
        Set-Reg -Path "HKLM:\SOFTWARE\Policies\Microsoft\FindMyDevice" -Name "AllowFindMyDevice" -Value 0
    }

    Invoke-Tweak -Name "Anuncios y sugerencias de Microsoft Edge" -Actions {
        $edgeAdsPath = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"
        Set-Reg -Path $edgeAdsPath -Name "NewTabPageContentEnabled" -Value 0
        Set-Reg -Path $edgeAdsPath -Name "NewTabPageHideDefaultTopSites" -Value 1
        Set-Reg -Path $edgeAdsPath -Name "EdgeShoppingAssistantEnabled" -Value 0
        Set-Reg -Path $edgeAdsPath -Name "TabServicesEnabled" -Value 0
        Set-Reg -Path $edgeAdsPath -Name "AlternateErrorPagesEnabled" -Value 0
        Set-Reg -Path $edgeAdsPath -Name "UserFeedbackAllowed" -Value 0
        Set-Reg -Path $edgeAdsPath -Name "ShowRecommendationsEnabled" -Value 0
        Set-Reg -Path $edgeAdsPath -Name "WalletDonationEnabled" -Value 0
        Set-Reg -Path $edgeAdsPath -Name "HideFirstRunExperience" -Value 0
        Set-Reg -Path $edgeAdsPath -Name "DefaultBrowserSettingEnabled" -Value 0
        Set-Reg -Path $edgeAdsPath -Name "DefaultBrowserSettingsCampaignEnabled" -Value 0
        Set-Reg -Path $edgeAdsPath -Name "SpotlightExperiencesAndRecommendationsEnabled" -Value 0
        Set-Reg -Path $edgeAdsPath -Name "ShowAcrobatSubscriptionButton" -Value 0
    }
}
