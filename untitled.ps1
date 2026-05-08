$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell -Verb RunAs -ArgumentList $PSCommandPath; exit
}

Add-Type @"
using System.Runtime.InteropServices;
public class NativeWallpaper {
    [DllImport("user32.dll")] public static extern bool SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
}
public class Win32 {
    [DllImport("user32.dll")] public static extern int  GetWindowLong(IntPtr h, int i);
    [DllImport("user32.dll")] public static extern int  SetWindowLong(IntPtr h, int i, int v);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int n);
}
"@

class Logger {
    static [void] Info([string]$m)    { Write-Host "[INFO]  $m" -ForegroundColor Cyan    }
    static [void] Success([string]$m) { Write-Host "[OK]    $m" -ForegroundColor Green   }
    static [void] Warn([string]$m)    { Write-Host "[WARN]  $m" -ForegroundColor Yellow  }
    static [void] Error([string]$m)   { Write-Host "[ERROR] $m" -ForegroundColor Red     }
}

class RegistryManager {
    [void] Set([string]$path, [string]$name, $value) {
        try {
            if (-not (Test-Path $path)) { New-Item -Path $path -Force | Out-Null }
            Set-ItemProperty -Path $path -Name $name -Value $value -Force
        } catch { [Logger]::Error("Registry failed '$name': $_") }
    }
}

class ThemeManager {
    hidden [RegistryManager]$_r
    ThemeManager([RegistryManager]$r) { $this._r = $r }
    hidden [void] SetTheme([int]$val) {
        $p = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"
        $this._r.Set($p, "AppsUseLightTheme",    $val)
        $this._r.Set($p, "SystemUsesLightTheme", $val)
    }
    [void] ApplyLight() { $this.SetTheme(1); [Logger]::Success("Light theme applied.") }
    [void] ApplyDark()  { $this.SetTheme(0); [Logger]::Success("Dark theme applied.")  }
}

class WallpaperManager {
    hidden [string]$_url, $_path
    WallpaperManager([string]$url, [string]$path) { $this._url = $url; $this._path = $path }
    hidden [bool] Download() {
        if (Test-Path $this._path) { return $true }
        try { Invoke-WebRequest -Uri $this._url -OutFile $this._path -ErrorAction Stop; return $true }
        catch { [Logger]::Error("Wallpaper download failed: $_"); return $false }
    }
    [void] Apply() {
        if ($this.Download()) { [NativeWallpaper]::SystemParametersInfo(20, 0, $this._path, 3) | Out-Null; [Logger]::Success("Wallpaper applied.") }
        else { [Logger]::Warn("Wallpaper skipped.") }
    }
}

class DesktopCleaner {
    hidden [string[]]$_excluded = @("desktop.ini", "This PC.lnk", "Recycle Bin.lnk")
    [void] Clean() {
        Get-ChildItem "C:\Users" -Directory | ForEach-Object {
            $d = Join-Path $_.FullName "Desktop"
            if (Test-Path $d) {
                Get-ChildItem $d -File -ErrorAction SilentlyContinue |
                    Where-Object { $this._excluded -notcontains $_.Name } |
                    ForEach-Object { Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue }
            }
        }
        [Logger]::Success("Desktop cleaned.")
    }
}

class ExplorerManager {
    [void] Restart() {
        Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
        Start-Process explorer.exe
        [Logger]::Success("Explorer restarted.")
    }
    [void] CloseWindows() {
        try {
            $s = New-Object -ComObject Shell.Application
            $s.Windows() | Where-Object { $_.Name -in @("File Explorer","Windows Explorer") } | ForEach-Object { $_.Quit() }
        } catch { [Logger]::Warn("Could not close Explorer: $_") }
    }
}

class ComputerConfigurator {
    hidden [RegistryManager]$_r
    ComputerConfigurator([RegistryManager]$r) { $this._r = $r }
    [void] SetName([string]$n) {
        $this._r.Set("HKLM:\SYSTEM\CurrentControlSet\Control\ComputerName\ComputerName",       "ComputerName", $n)
        $this._r.Set("HKLM:\SYSTEM\CurrentControlSet\Control\ComputerName\ActiveComputerName", "ComputerName", $n)
        $this._r.Set("HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters",               "Hostname",     $n)
        [Logger]::Warn("Restart required for name change.")
    }
    [void] SetOEM([string]$m) {
        $this._r.Set("HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\OEMInformation", "Model", $m)
    }
}

class ConsoleHider {
    [void] Hide() {
        Get-Process hosted-compute-agent -ErrorAction SilentlyContinue | ForEach-Object {
            $h = $_.MainWindowHandle
            if ($h -ne [IntPtr]::Zero) {
                $s = [Win32]::GetWindowLong($h, -20)
                [Win32]::SetWindowLong($h, -20, ($s -bor 0x80 -band -bnot 0x40000))
                [Win32]::ShowWindow($h, 0) | Out-Null
            }
        }
    }
}

class CloudPCSetup {
    hidden [RegistryManager]      $reg
    hidden [ConsoleHider]         $console
    hidden [ThemeManager]         $theme
    hidden [WallpaperManager]     $wallpaper
    hidden [DesktopCleaner]       $cleaner
    hidden [ComputerConfigurator] $computer
    hidden [ExplorerManager]      $explorer

    CloudPCSetup([hashtable]$c) {
        $this.reg       = [RegistryManager]::new()
        $this.console   = [ConsoleHider]::new()
        $this.theme     = [ThemeManager]::new($this.reg)
        $this.wallpaper = [WallpaperManager]::new($c.WallpaperUrl, $c.WallpaperPath)
        $this.cleaner   = [DesktopCleaner]::new()
        $this.computer  = [ComputerConfigurator]::new($this.reg)
        $this.explorer  = [ExplorerManager]::new()
    }

    [void] Run([hashtable]$c) {
        $this.console.Hide()
        if ($c.DarkMode) { $this.theme.ApplyDark() } else { $this.theme.ApplyLight() }
        $this.wallpaper.Apply()
        $this.cleaner.Clean()
        $this.computer.SetName($c.ComputerName)
        $this.computer.SetOEM($c.OEMModel)
        $this.explorer.Restart()
        Start-Sleep -Seconds 3
        $this.explorer.CloseWindows()
        [Logger]::Success("=== Setup Complete ===")
    }
}

$config = @{
    ComputerName  = "CloudPC"
    WallpaperUrl  = "https://wallpapers.ispazio.net/wp-content/uploads/2023/08/macos-sonoma-desktop.jpg"
    WallpaperPath = "C:\Users\Public\Pictures\wallpaper.jpg"
    OEMModel      = "Virtual Machine"
    DarkMode      = $true
}

[CloudPCSetup]::new($config).Run($config)
