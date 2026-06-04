Set-ExecutionPolicy Bypass -Scope Process -Force
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")) { Write-Error "CRITICAL: Run as administrator!"; exit }

Add-Type @"
using System; using System.Runtime.InteropServices;
public class Win32 {
    [DllImport("user32.dll")] public static extern int GetWindowLong(IntPtr h, int i);
    [DllImport("user32.dll")] public static extern int SetWindowLong(IntPtr h, int i, int v);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int n);
}
"@

$SW_HIDE = 0
$processesToHide = @("hosted-compute-agent", "tailscale-ipn")
$regPath, $sysPath = "HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer", "HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\System"
$Folders = @{ "Desktop"="D:\Desktop"; "Personal"="D:\Documents"; "{374DE290-123F-4565-9164-39C4925E467B}"="D:\Downloads"; "My Pictures"="D:\Pictures"; "My Video"="D:\Videos"; "My Music"="D:\Music" }
$SettingsPath = "$env:LOCALAPPDATA\Packages\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe\LocalState\settings.json"
$WindowsCalculator = "https://apps.microsoft.com/detail/9wzdncrfhvn5?hl=en-US&gl=US"; $WindowsNotepad = "https://apps.microsoft.com/detail/9msmlrh6lzf3?hl=en-US&gl=US"; $MicrosoftStickyNotes = "https://apps.microsoft.com/detail/9nblggh4qghw?hl=en-US&gl=US"; $SnippingTool = "https://apps.microsoft.com/detail/9mz95kl8mr0l?hl=en-US&gl=US"; $WindowsClock = "https://apps.microsoft.com/detail/9wzdncrfj3pr?hl=en-US&gl=US"
$AppUrls = @($WindowsCalculator, $WindowsNotepad, $MicrosoftStickyNotes, $SnippingTool, $WindowsClock)
$edge = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"

$SettingsPath = "$env:LOCALAPPDATA\Packages\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe\LocalState\settings.json"

if (Test-Path $SettingsPath) {
    try {
        $settings = Get-Content $SettingsPath -Raw | ConvertFrom-Json
        if (-not $settings.visual) { $settings | Add-Member -MemberType NoteProperty -Name "visual" -Value @{} }
        if (-not $settings.visual.network) { $settings.visual | Add-Member -MemberType NoteProperty -Name "network" -Value @{} }
        $settings.visual.network.downloader = "do"
        $settings | ConvertTo-Json -Depth 10 | Set-Content $SettingsPath -Encoding UTF8
    } catch {
        '{"visual":{"network":{"downloader":"do"}}}' | Set-Content $SettingsPath -Encoding UTF8
    }
}

$jobs = @()

foreach ($url in $AppUrls) {
    if ($url -match "detail/([a-zA-Z0-9]{12})") {
        $appId = $Matches[1].ToUpper()
        $jobs += Start-Job -ScriptBlock {
            param($id)
            winget install --id $id --source msstore `
                --accept-source-agreements `
                --accept-package-agreements `
                --silent `
                --disable-interactivity
            Get-AppxPackage -allusers Microsoft.Windows.StartMenuExperienceHost | Reset-AppxPackage
        } -ArgumentList $appId
    }
}

if (Test-Path "D:\a") { attrib +h +s "D:\a" }

foreach ($Key in $Folders.Keys) {
    $Path = $Folders[$Key]
    if (-not (Test-Path $Path)) { New-Item -ItemType Directory -Path $Path -Force | Out-Null }
    $uShell, $shell = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders", "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders"
    if (Test-Path $uShell) { Set-ItemProperty -Path $uShell -Name $Key -Value $Path -Force }
    if (Test-Path $shell) { Set-ItemProperty -Path $shell -Name $Key -Value $Path -Force }
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
if (!(Test-Path $edge)) { New-Item -Path $edge -Force | Out-Null }
Set-ItemProperty -Path $edge -Name "HideFirstRunExperience" -Value 1 -Type DWord

if (-not (Test-Path $regPath)) { New-Item -Path $regPath -Force | Out-Null }
if (-not (Test-Path $sysPath)) { New-Item -Path $sysPath -Force | Out-Null }
Set-ItemProperty -Path $regPath -Name "NoDrives" -Value 4 -Type DWord -Force
Set-ItemProperty -Path $regPath -Name "NoViewOnDrive" -Value 4 -Type DWord -Force

Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
