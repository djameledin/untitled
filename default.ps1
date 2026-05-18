Set-ExecutionPolicy Bypass -Scope Process -Force
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")) { Write-Error "CRITICAL: Run as administrator!"; exit }

Add-Type @"
using System; using System.Runtime.InteropServices;
public class NativeWallpaper {
    [DllImport("user32.dll", CharSet=CharSet.Auto, SetLastError=true)] public static extern bool SystemParametersInfo(uint uAction, uint uParam, string lpvParam, uint fuWinIni);
    public static bool SetWallpaper(string path) { return SystemParametersInfo(0x0014, 0, path, 0x0001 | 0x0002); }
}
public class Win32 {
    [DllImport("user32.dll")] public static extern int GetWindowLong(IntPtr h, int i);
    [DllImport("user32.dll")] public static extern int SetWindowLong(IntPtr h, int i, int v);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int n);
}
"@

$WallpaperUrl, $WallpaperPath, $SW_HIDE = "https://raw.githubusercontent.com/djameledin/untitled/refs/heads/main/wallpaper.jpg", "C:\Users\Public\Pictures\wallpaper.jpg", 0
$Targets = @("D:\DATALOSS_WARNING_README.txt", "D:\CollectGuestLogsTemp")
$processesToHide = @("hosted-compute-agent", "tailscale-ipn")
$regPath, $sysPath, $p = "HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer", "HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\System", "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"
$startMenus = @("$env:ProgramData\Microsoft\Windows\Start Menu\Programs", "$env:USERPROFILE\AppData\Roaming\Microsoft\Windows\Start Menu\Programs")
$Exceptions = @("Microsoft Edge.lnk")

$Folders = @{ "Desktop"="D:\Desktop"; "Personal"="D:\Documents"; "{374DE290-123F-4565-9164-39C4925E467B}"="D:\Downloads"; "My Pictures"="D:\Pictures"; "My Video"="D:\Videos"; "My Music"="D:\Music" }

if (-not (Test-Path $WallpaperPath)) { Invoke-WebRequest -Uri $WallpaperUrl -OutFile $WallpaperPath -UseBasicParsing -ErrorAction SilentlyContinue }
if (Test-Path $WallpaperPath) { [NativeWallpaper]::SetWallpaper($WallpaperPath) | Out-Null }

foreach ($Item in $Targets) { if (Test-Path $Item) { Remove-Item $Item -Recurse -Force -ErrorAction SilentlyContinue } }
if (Test-Path "D:\a") { attrib +h +s "D:\a" }

foreach ($Key in $Folders.Keys) {
    $Path = $Folders[$Key]
    if (-not (Test-Path $Path)) { New-Item -ItemType Directory -Path $Path -Force | Out-Null }
    $uShell, $shell = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders", "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders"
    if (Test-Path $uShell) { Set-ItemProperty -Path $uShell -Name $Key -Value $Path -Force }
    if (Test-Path $shell) { Set-ItemProperty -Path $shell -Name $Key -Value $Path -Force }
}

Remove-Item "$env:Public\Desktop\*.lnk", "$env:USERPROFILE\Desktop\*.lnk" -Force -ErrorAction SilentlyContinue

foreach ($path in $startMenus) { 
    Get-ChildItem $path -Recurse -Filter "*.lnk" -ErrorAction SilentlyContinue | ForEach-Object {
        $item, $shouldDelete = $_, $true
        foreach ($exception in $Exceptions) { if ($item.FullName -like "*\$exception*") { $shouldDelete = $false; break } }
        if ($shouldDelete) { Remove-Item $item.FullName -Force -ErrorAction SilentlyContinue }
    }
}

foreach ($procName in $processesToHide) {
    foreach ($pr in (Get-Process -Name $procName -ErrorAction SilentlyContinue)) {
        if ($pr.MainWindowHandle -ne [IntPtr]::Zero -and $pr.MainWindowTitle -ne "") {
            $style = [Win32]::GetWindowLong($pr.MainWindowHandle, -20)
            [Win32]::SetWindowLong($pr.MainWindowHandle, -20, ($style -bor 0x80 -band -bnot 0x40000)) | Out-Null
            [Win32]::ShowWindow($pr.MainWindowHandle, $SW_HIDE) | Out-Null
        }
    }
}

if (-not (Test-Path $p)) { New-Item -Path $p -Force | Out-Null }
Set-ItemProperty -Path $p -Name "AppsUseLightTheme" -Value 1 -Force
Set-ItemProperty -Path $p -Name "SystemUsesLightTheme" -Value 1 -Force

if (-not (Test-Path $regPath)) { New-Item -Path $regPath -Force | Out-Null }
if (-not (Test-Path $sysPath)) { New-Item -Path $sysPath -Force | Out-Null }
Set-ItemProperty -Path $regPath -Name "NoDrives" -Value 4 -Type DWord -Force
Set-ItemProperty -Path $regPath -Name "NoViewOnDrive" -Value 4 -Type DWord -Force

Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
