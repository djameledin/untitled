# Allow script execution
Set-ExecutionPolicy Bypass -Scope Process -Force

# Add Win32 API functions
Add-Type @"
using System;
using System.Runtime.InteropServices;

public class NativeWallpaper {
    [DllImport("user32.dll", CharSet=CharSet.Auto, SetLastError=true)]
    public static extern bool SystemParametersInfo(uint uAction, uint uParam, string lpvParam, uint fuWinIni);
    
    public static bool SetWallpaper(string path) {
        return SystemParametersInfo(0x0014, 0, path, 0x0001 | 0x0002);
    }
}

public class Win32 {
    [DllImport("user32.dll")]
    public static extern int GetWindowLong(IntPtr h, int i);
    
    [DllImport("user32.dll")]
    public static extern int SetWindowLong(IntPtr h, int i, int v);
    
    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr h, int n);
}
"@

# Settings
$WallpaperUrl = "https://raw.githubusercontent.com/djameledin/untitled/refs/heads/main/default.jpg"
$WallpaperPath = "C:\Users\Public\Pictures\wallpaper.jpg"
$DarkMode = $false
$SW_HIDE = 0
$excluded = @("Recycle Bin.lnk")
$tempFolder = "C:\Temp\DesktopShortcuts"

# Create temporary folder if it doesn't exist
if (-not (Test-Path $tempFolder)) { New-Item $tempFolder -ItemType Directory | Out-Null }

# Hide specific processes windows (hosted-compute-agent and Tailscale)
$processesToHide = @("hosted-compute-agent", "tailscale-ipn")
foreach ($procName in $processesToHide) {
    $procs = Get-Process -Name $procName -ErrorAction SilentlyContinue
    foreach ($p in $procs) {
        if ($p.MainWindowHandle -ne [IntPtr]::Zero -and ($p.MainWindowTitle -ne "" -or $procName -eq "hosted-compute-agent")) {
            $style = [Win32]::GetWindowLong($p.MainWindowHandle, -20)
            [Win32]::SetWindowLong($p.MainWindowHandle, -20, ($style -bor 0x80 -band -bnot 0x40000)) | Out-Null
            [Win32]::ShowWindow($p.MainWindowHandle, $SW_HIDE) | Out-Null
        }
    }
}

# Move desktop icons for all users to temporary folder
$desktopFiles = Get-ChildItem "C:\Users\*" -Directory | ForEach-Object {
    $d = Join-Path $_.FullName "Desktop"
    if (Test-Path $d) { Get-ChildItem $d -File -ErrorAction SilentlyContinue }
} | Where-Object { $excluded -notcontains $_.Name }

if ($desktopFiles) { Move-Item $desktopFiles.FullName $tempFolder -Force }

# Download wallpaper if not exists
if (-not (Test-Path $WallpaperPath)) {
    Invoke-WebRequest -Uri $WallpaperUrl -OutFile $WallpaperPath -UseBasicParsing -ErrorAction Stop
}

# Set wallpaper
[NativeWallpaper]::SetWallpaper($WallpaperPath) | Out-Null

# Set light/dark mode
$val = if ($DarkMode) { 0 } else { 1 }
$p = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"
Set-ItemProperty $p "AppsUseLightTheme" $val | Out-Null
Set-ItemProperty $p "SystemUsesLightTheme" $val | Out-Null

# Restart Explorer to apply changes
Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
Start-Process explorer.exe
Start-Sleep -Seconds 3

# Close any remaining Explorer windows
$shell = New-Object -ComObject Shell.Application
$shell.Windows() | Where-Object { $_.Name -in @("File Explorer", "Windows Explorer") } | ForEach-Object { $_.Quit() }
