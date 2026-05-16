Set-ExecutionPolicy Bypass -Scope Process -Force

if (
    -not (
        [Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
    ).IsInRole(
        [Security.Principal.WindowsBuiltInRole] "Administrator"
    )
) {
    exit
}

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

$regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer"

if (-not (Test-Path $regPath)) {
    New-Item -Path $regPath -Force | Out-Null
}

$CDriveValue = 4

Set-ItemProperty -Path $regPath -Name "NoDrives" -Value $CDriveValue -Type DWord
Set-ItemProperty -Path $regPath -Name "NoViewOnDrive" -Value $CDriveValue -Type DWord
Set-ItemProperty -Path $regPath -Name "NoRun" -Value 1 -Type DWord

$Targets = @(
    "D:\DATALOSS_WARNING_README.txt",
    "D:\CollectGuestLogsTemp"
)

foreach ($Item in $Targets) {
    if (Test-Path $Item) {
        Remove-Item $Item -Recurse -Force -ErrorAction SilentlyContinue
    }
}

if (Test-Path "D:\a") {
    attrib +h +s "D:\a"
}

$Folders = @{
    "Desktop"   = "D:\Desktop"
    "Personal"  = "D:\Documents"
    "{374DE290-123F-4565-9164-39C4925E467B}" = "D:\Downloads"
    "My Pictures" = "D:\Pictures"
    "My Video" = "D:\Videos"
    "My Music" = "D:\Music"
}

foreach ($Key in $Folders.Keys) {
    $Path = $Folders[$Key]

    New-Item -ItemType Directory -Path $Path -Force | Out-Null

    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders" -Name $Key -Value $Path
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders" -Name $Key -Value $Path
}

Move-Item "$HOME\Desktop\*" "D:\Desktop" -Force -ErrorAction SilentlyContinue
Move-Item "$HOME\Documents\*" "D:\Documents" -Force -ErrorAction SilentlyContinue
Move-Item "$HOME\Downloads\*" "D:\Downloads" -Force -ErrorAction SilentlyContinue
Move-Item "$HOME\Pictures\*" "D:\Pictures" -Force -ErrorAction SilentlyContinue
Move-Item "$HOME\Videos\*" "D:\Videos" -Force -ErrorAction SilentlyContinue
Move-Item "$HOME\Music\*" "D:\Music" -Force -ErrorAction SilentlyContinue

$desktopFiles = Get-ChildItem "C:\Users\*" -Directory | ForEach-Object {
    $d = Join-Path $_.FullName "Desktop"
    if (Test-Path $d) {
        Get-ChildItem $d -File -ErrorAction SilentlyContinue
    }
}

if ($desktopFiles) {
    $desktopFiles | Remove-Item -Force -ErrorAction SilentlyContinue
}

$WallpaperUrl = "https://raw.githubusercontent.com/djameledin/untitled/refs/heads/main/default.jpg"
$WallpaperPath = "C:\Users\Public\Pictures\wallpaper.jpg"

if (-not (Test-Path $WallpaperPath)) {
    Invoke-WebRequest -Uri $WallpaperUrl -OutFile $WallpaperPath -UseBasicParsing -ErrorAction SilentlyContinue
}

if (Test-Path $WallpaperPath) {
    [NativeWallpaper]::SetWallpaper($WallpaperPath) | Out-Null
}

$p = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"

Set-ItemProperty $p "AppsUseLightTheme" 1
Set-ItemProperty $p "SystemUsesLightTheme" 1

Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
Start-Process explorer.exe

Start-Sleep -Seconds 3

$shell = New-Object -ComObject Shell.Application
$shell.Windows() | Where-Object { $_.Name -in @("File Explorer", "Windows Explorer") } | ForEach-Object { $_.Quit() }
