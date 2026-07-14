<#
  Instala las apps que eligio el usuario via winget
#>

# Arma la lista de apps segun las respuestas, corre winget y devuelve los resultados.
function Install-SelectedApps {
    param([Parameter(Mandatory)]$Config)

    $catalog = @{
        Chrome   = @{ Name = "Google Chrome"; Id = "Google.Chrome" }
        Brave    = @{ Name = "Brave"; Id = "Brave.Brave" }
        Firefox  = @{ Name = "Mozilla Firefox"; Id = "Mozilla.Firefox" }
        WinRAR   = @{ Name = "WinRAR"; Id = "RARLab.WinRAR" }
        NanaZip  = @{ Name = "NanaZip"; Id = "M2Team.NanaZip" }
        Discord  = @{ Name = "Discord"; Id = "Discord.Discord" }
        Steam    = @{ Name = "Steam"; Id = "Valve.Steam" }
        Epic     = @{ Name = "Epic Games Launcher"; Id = "EpicGames.EpicGamesLauncher" }
        MoviesTV = @{ Name = "Peliculas y TV"; Id = "9WZDNCRFJ3PZ"; Source = "msstore" }
        VLC      = @{ Name = "VLC media player"; Id = "VideoLAN.VLC" }
    }

    $apps = @()
    switch ($Config.Browser) {
        1 { $apps += $catalog.Chrome }
        2 { $apps += $catalog.Brave }
        3 { $apps += $catalog.Firefox }
    }
    switch ($Config.Compressor) {
        1 { $apps += $catalog.WinRAR }
        2 { $apps += $catalog.NanaZip }
    }
    if ($Config.GamingApps) {
        $apps += $catalog.Discord
        $apps += $catalog.Steam
        $apps += $catalog.Epic
    }
    switch ($Config.Player) {
        1 { $apps += $catalog.MoviesTV }
        2 { $apps += $catalog.VLC }
    }

    $results = @()
    foreach ($app in $apps) {
        Write-Log "`nInstalando $($app.Name)..." "Cyan"

        $wingetArgs = @("install", "--id", $app.Id, "-e", "--silent", "--accept-package-agreements", "--accept-source-agreements")
        if ($app.Source) { $wingetArgs += @("--source", $app.Source) }

        $output = & winget @wingetArgs 2>&1
        $exitCode = $LASTEXITCODE

        # -1978335189 (0x8A15002B) = APPINSTALLER_CLI_ERROR_UPDATE_NOT_APPLICABLE: ya esta al dia
        if ($exitCode -eq 0) {
            Write-Log "$($app.Name) instalado." "Green"
            $status = "Instalado"
        }
        elseif ($exitCode -eq -1978335189 -or $output -match "already installed|no upgrade found|no applicable update") {
            Write-Log "$($app.Name) ya estaba instalado." "Yellow"
            $status = "Ya estaba instalado"
        }
        else {
            Write-Log "Fallo al instalar $($app.Name) (codigo $exitCode)." "Red"
            $status = "Fallo (codigo $exitCode)"
        }

        $results += [PSCustomObject]@{ App = $app.Name; Estado = $status }
    }

    if ($Config.Browser -eq 2 -and $Config.BraveDebloat) {
        Invoke-BraveDebloat
    }

    return $results
}

# Apaga por politica la IA, la Wallet, Rewards, Talk, News y la VPN de Brave
function Invoke-BraveDebloat {
    Invoke-Tweak -Name "Debloat de Brave" -Actions {
        $bravePolicyPath = "HKLM:\Software\Policies\BraveSoftware\Brave"
        Set-Reg -Path $bravePolicyPath -Name "BraveVPNDisabled" -Value 1
        Set-Reg -Path $bravePolicyPath -Name "BraveWalletDisabled" -Value 1
        Set-Reg -Path $bravePolicyPath -Name "BraveAIChatEnabled" -Value 0
        Set-Reg -Path $bravePolicyPath -Name "BraveRewardsDisabled" -Value 1
        Set-Reg -Path $bravePolicyPath -Name "BraveTalkDisabled" -Value 1
        Set-Reg -Path $bravePolicyPath -Name "BraveNewsDisabled" -Value 1
    }
}
