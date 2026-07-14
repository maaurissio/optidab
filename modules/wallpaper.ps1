<#
  Descarga wall.png del repo y lo pone de fondo de pantalla. Si ya es ese fondo,
  no lo vuelve a bajar.
#>

function Set-KhramWallpaper {
    param([Parameter(Mandatory)][string]$WallpaperUrl)

    Invoke-Tweak -Name "Fondo de pantalla" -Actions {
        $wallpaperPath = Join-Path $env:LOCALAPPDATA "KHRAM\wall.png"
        $currentWallpaper = (Get-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "Wallpaper" -ErrorAction SilentlyContinue).Wallpaper

        if ($currentWallpaper -eq $wallpaperPath -and (Test-Path $wallpaperPath)) {
            $Global:KhramNote = "El fondo ya era $wallpaperPath, no se volvio a descargar."
            return
        }

        New-Item -Path (Split-Path $wallpaperPath) -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null
        Invoke-WebRequest -Uri $WallpaperUrl -OutFile $wallpaperPath -UseBasicParsing

        Set-Reg -Path "HKCU:\Control Panel\Desktop" -Name "WallpaperStyle" -Value "10" -Type String
        Set-Reg -Path "HKCU:\Control Panel\Desktop" -Name "TileWallpaper" -Value "0" -Type String

        if (-not ("Win32.Wallpaper" -as [type])) {
            Add-Type -Namespace Win32 -Name Wallpaper -MemberDefinition @"
            [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
            public static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
"@
        }
        # SPI_SETDESKWALLPAPER = 0x0014, SPIF_UPDATEINIFILE | SPIF_SENDCHANGE = 0x03
        [Win32.Wallpaper]::SystemParametersInfo(0x0014, 0, $wallpaperPath, 0x03) | Out-Null
        $Global:KhramChanged = $true
    }
}
