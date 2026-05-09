Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force

# Elevate to admin if not already
$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell -Verb RunAs -ArgumentList $PSCommandPath
    exit
}

# Add .NET classes in a separate scriptblock
$addTypeScript = {
    Add-Type @"
using System;
using System.Runtime.InteropServices;

public class NativeWallpaper {
    [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    public static extern bool SystemParametersInfo(
        uint uAction,
        uint uParam,
        string lpvParam,
        uint fuWinIni
    );
    public static bool SetWallpaper(string path) {
        return SystemParametersInfo(0x0014, 0, path, 0x0001 | 0x0002);
    }
}

public class Win32 {
    [DllImport("user32.dll")] public static extern int GetWindowLong(IntPtr h, int i);
    [DllImport("user32.dll")] public static extern int SetWindowLong(IntPtr h, int i, int v);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int n);
}
"@
}
. $addTypeScript

# Configuration
$ComputerName  = "CloudPC"
$WallpaperUrl  = "https://wallpapers.ispazio.net/wp-content/uploads/2023/08/macos-sonoma-desktop.jpg"
$WallpaperPath = "C:\Users\Public\Pictures\wallpaper.jpg"
$OEMModel      = "Virtual Machine"
$DarkMode      = $true

# ── Logger ──────────────────────────────────────────────────────────────────
function Write-Info    ([string]$m) { Write-Host "[INFO]  $m" -ForegroundColor Cyan }
function Write-Success ([string]$m) { Write-Host "[OK]    $m" -ForegroundColor Green }
function Write-Warn    ([string]$m) { Write-Host "[WARN]  $m" -ForegroundColor Yellow }
function Write-Err     ([string]$m) { Write-Host "[ERROR] $m" -ForegroundColor Red }

# ── Registry ─────────────────────────────────────────────────────────────────
function Set-RegistryValue ([string]$path, [string]$name, $value) {
    try {
        if (-not (Test-Path $path)) { New-Item -Path $path -Force | Out-Null }
        Set-ItemProperty -Path $path -Name $name -Value $value -Force
    } catch {
        Write-Err "Registry failed '$name': $_"
    }
}

# ── Theme ────────────────────────────────────────────────────────────────────
function Set-Theme ([bool]$dark) {
    $val = if ($dark) { 0 } else { 1 }
    $p   = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"
    Set-RegistryValue $p "AppsUseLightTheme"    $val
    Set-RegistryValue $p "SystemUsesLightTheme" $val
    $label = if ($dark) { "Dark" } else { "Light" }
    Write-Success "$label theme applied."
}

# ── Wallpaper ────────────────────────────────────────────────────────────────
function Get-Wallpaper ([string]$url, [string]$path) {
    if (Test-Path $path) { return $true }
    try {
        Invoke-WebRequest -Uri $url -OutFile $path -UseBasicParsing -ErrorAction Stop
        return $true
    } catch {
        Write-Err "Wallpaper download failed: $_"
        return $false
    }
}

function Set-Wallpaper ([string]$url, [string]$path) {
    if (Get-Wallpaper $url $path) {
        $ok = [NativeWallpaper]::SetWallpaper($path)
        if ($ok) { Write-Success "Wallpaper applied." }
        else     { Write-Warn "Failed to apply wallpaper." }
    } else {
        Write-Warn "Wallpaper skipped."
    }
}

# ── Desktop Cleaner ───────────────────────────────────────────────────────────
function Clear-Desktop {
    $excluded = @("desktop.ini", "This PC.lnk", "Recycle Bin.lnk")
    Get-ChildItem "C:\Users" -Directory | ForEach-Object {
        $d = Join-Path $_.FullName "Desktop"
        if (Test-Path $d) {
            Get-ChildItem $d -File -ErrorAction SilentlyContinue |
                Where-Object { $excluded -notcontains $_.Name } |
                ForEach-Object { Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue }
        }
    }
    Write-Success "Desktop cleaned."
}

# ── Explorer ──────────────────────────────────────────────────────────────────
function Restart-Explorer {
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    Start-Process explorer.exe
    Write-Success "Explorer restarted."
}

function Close-ExplorerWindows {
    try {
        $shell = New-Object -ComObject Shell.Application
        $shell.Windows() |
            Where-Object { $_.Name -in @("File Explorer", "Windows Explorer") } |
            ForEach-Object { $_.Quit() }
    } catch {
        Write-Warn "Could not close Explorer: $_"
    }
}

# ── Computer Name ─────────────────────────────────────────────────────────────
function Set-PCName ([string]$name) {
    Set-RegistryValue "HKLM:\SYSTEM\CurrentControlSet\Control\ComputerName\ComputerName"       "ComputerName" $name
    Set-RegistryValue "HKLM:\SYSTEM\CurrentControlSet\Control\ComputerName\ActiveComputerName" "ComputerName" $name
    Set-RegistryValue "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"               "Hostname"     $name
    Write-Warn "Restart required for name change."
}

function Set-OEMModel ([string]$model) {
    Set-RegistryValue "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\OEMInformation" "Model" $model
}

# ── Console Hider ─────────────────────────────────────────────────────────────
function Hide-Console {
    Get-Process hosted-compute-agent -ErrorAction SilentlyContinue | ForEach-Object {
        $h = $_.MainWindowHandle
        if ($h -ne [IntPtr]::Zero) {
            $style = [Win32]::GetWindowLong($h, -20)
            [Win32]::SetWindowLong($h, -20, ($style -bor 0x80 -band -bnot 0x40000))
            [Win32]::ShowWindow($h, 0) | Out-Null
        }
    }
}

# ── Main ──────────────────────────────────────────────────────────────────────
Hide-Console
Set-Theme $DarkMode
Set-Wallpaper $WallpaperUrl $WallpaperPath
Clear-Desktop
Set-PCName $ComputerName
Set-OEMModel $OEMModel
Restart-Explorer
Start-Sleep -Seconds 3
Close-ExplorerWindows
