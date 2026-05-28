Add-Type @"
using System; using System.Runtime.InteropServices;
public class NativeWallpaper {
    [DllImport("user32.dll", CharSet=CharSet.Auto, SetLastError=true)] public static extern bool SystemParametersInfo(uint uAction, uint uParam, string lpvParam, uint fuWinIni);
    public static bool SetWallpaper(string path) { return SystemParametersInfo(0x0014, 0, path, 0x0001 | 0x0002); }
}
"@
$WallpaperUrl, $WallpaperPath, $p = "https://github.com/djameledin/untitled/raw/refs/heads/main/Windows-365-Link-Dark-3840x2560.png", "C:\Users\Public\Pictures\wallpaper.png", "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"
$startMenus = @("$env:ProgramData\Microsoft\Windows\Start Menu\Programs", "$env:USERPROFILE\AppData\Roaming\Microsoft\Windows\Start Menu\Programs")
$TargetsToClean = @(
    "Anaconda (Miniconda)", "Azure Cosmos DB Emulator", "CMake", "Git", "ImageMagick*", "Inno Setup 6", "LLVM", "Maintenance", "Microsoft Azure", "MySQL", "Node.js", "OpenSSL", "PostgreSQL 17", "PowerShell", "Python 3.10", "Python 3.11", "Python 3.12", "Python 3.13", "Python 3.14", "R", "Rtools 4.5", "ServiceFabricLocalClusterManager", "Startup", "Strawberry Perl*", "Visual Studio 2022", "Accessories", "Windows Kits", "Windows PowerShell", "System Tools", "Administrative Tools", "WiX Toolset*", "7-Zip", "Accessibility",
    "Firefox.lnk", "Google Chrome.lnk", "Firefox Private Browsing.lnk", "Blend for Visual Studio 2022.lnk", "Microsoft Web Platform Installer.lnk", "Server Manager.lnk", "Tailscale.lnk", "Visual Studio 2022.lnk", "Visual Studio Installer.lnk", "Windows Admin Center Setup.lnk", "WSL Settings.lnk", "WSL.lnk", "Unity Hub.lnk", "Paint.lnk", "Snipping Tool.lnk", "Notepad.lnk", "Calculator.lnk", "Administrative Tools.lnk"
)
if (-not (Test-Path $WallpaperPath)) { Invoke-WebRequest -Uri $WallpaperUrl -OutFile $WallpaperPath -UseBasicParsing -ErrorAction SilentlyContinue }
if (Test-Path $WallpaperPath) { [NativeWallpaper]::SetWallpaper($WallpaperPath) | Out-Null }
Remove-Item "$env:Public\Desktop\*.lnk", "$env:USERPROFILE\Desktop\*.lnk" -Force -ErrorAction SilentlyContinue
foreach ($path in $startMenus) {
    if (Test-Path $path) {
        foreach ($target in $TargetsToClean) {
            $fullPath = Join-Path $path $target
            if (Test-Path $fullPath) { Remove-Item $fullPath -Recurse -Force -ErrorAction SilentlyContinue }
            Get-ChildItem $path -Recurse -Filter $target -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
if (-not (Test-Path $p)) { New-Item -Path $p -Force | Out-Null }
Set-ItemProperty -Path $p -Name "AppsUseLightTheme" -Value 0 -Force
Set-ItemProperty -Path $p -Name "SystemUsesLightTheme" -Value 0 -Force
Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
