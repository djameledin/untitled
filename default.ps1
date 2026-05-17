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

$WallpaperUrl, $WallpaperPath, $SW_HIDE = "https://raw.githubusercontent.com/djameledin/untitled/refs/heads/main/default.jpg", "C:\Users\Public\Pictures\wallpaper.jpg", 0
$Targets, $processesToHide = @("D:\DATALOSS_WARNING_README.txt", "D:\CollectGuestLogsTemp"), @("hosted-compute-agent", "tailscale-ipn")
$regPath, $sysPath, $p = "HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer", "HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\System", "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"
$startMenus = @("$env:ProgramData\Microsoft\Windows\Start Menu\Programs", "$env:USERPROFILE\AppData\Roaming\Microsoft\Windows\Start Menu\Programs")

New-Item -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Force | Out-Null
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" `
-Name NoRun -Value 1

if (-not (Test-Path $WallpaperPath)) { Invoke-WebRequest -Uri $WallpaperUrl -OutFile $WallpaperPath -UseBasicParsing -ErrorAction SilentlyContinue }
if (Test-Path $WallpaperPath) { [NativeWallpaper]::SetWallpaper($WallpaperPath) | Out-Null }

foreach ($Item in $Targets) { if (Test-Path $Item) { Remove-Item $Item -Recurse -Force -ErrorAction SilentlyContinue } }
if (Test-Path "D:\a") { attrib +h +s "D:\a" }

$Folders = @{ "Desktop"="D:\Desktop"; "Personal"="D:\Documents"; "{374DE290-123F-4565-9164-39C4925E467B}"="D:\Downloads"; "My Pictures"="D:\Pictures"; "My Video"="D:\Videos"; "My Music"="D:\Music" }
foreach ($Key in $Folders.Keys) {
    $Path = $Folders[$Key]
    if (-not (Test-Path $Path)) { New-Item -ItemType Directory -Path $Path -Force | Out-Null }
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders" -Name $Key -Value $Path -Force
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders" -Name $Key -Value $Path -Force
}

Remove-Item "$env:Public\Desktop\*.lnk" -Force -ErrorAction SilentlyContinue
Remove-Item "$env:USERPROFILE\Desktop\*.lnk" -Force -ErrorAction SilentlyContinue
foreach ($path in $startMenus) { Get-ChildItem $path -Recurse -Filter "*.lnk" -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue }

Move-Item "$HOME\Desktop\*" "D:\Desktop" -Force -ErrorAction SilentlyContinue
Move-Item "$HOME\Documents\*" "D:\Documents" -Force -ErrorAction SilentlyContinue
Move-Item "$HOME\Downloads\*" "D:\Downloads" -Force -ErrorAction SilentlyContinue
Move-Item "$HOME\Pictures\*" "D:\Pictures" -Force -ErrorAction SilentlyContinue
Move-Item "$HOME\Videos\*" "D:\Videos" -Force -ErrorAction SilentlyContinue
Move-Item "$HOME\Music\*" "D:\Music" -Force -ErrorAction SilentlyContinue

foreach ($procName in $processesToHide) {
    $procs = Get-Process -Name $procName -ErrorAction SilentlyContinue
    foreach ($pr in $procs) {
        if ($pr.MainWindowHandle -ne [IntPtr]::Zero -and $pr.MainWindowTitle -ne "") {
            $style = [Win32]::GetWindowLong($pr.MainWindowHandle, -20)
            [Win32]::SetWindowLong($pr.MainWindowHandle, -20, ($style -bor 0x80 -band -bnot 0x40000)) | Out-Null
            [Win32]::ShowWindow($pr.MainWindowHandle, $SW_HIDE) | Out-Null
        }
    }
}

if (-not (Test-Path $p)) { New-Item -Path $p -Force | Out-Null }
Set-ItemProperty $p "AppsUseLightTheme" 1 -Force
Set-ItemProperty $p "SystemUsesLightTheme" 1 -Force

if (-not (Test-Path $regPath)) { New-Item -Path $regPath -Force | Out-Null }
if (-not (Test-Path $sysPath)) { New-Item -Path $sysPath -Force | Out-Null }
Set-ItemProperty -Path $regPath -Name "NoDrives" -Value 4 -Type DWord -Force
Set-ItemProperty -Path $regPath -Name "NoViewOnDrive" -Value 4 -Type DWord -Force
Set-ItemProperty -Path $sysPath -Name "DisableCMD" -Value 1 -Type DWord -Force
Set-ItemProperty -Path $sysPath -Name "DisableRegistryTools" -Value 1 -Type DWord -Force

Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
Start-Sleep 3
Get-Process -Name explorer -ErrorAction SilentlyContinue | ForEach-Object { Stop-Process -Id $_.Id -Force }
