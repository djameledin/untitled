Set-ExecutionPolicy Bypass -Scope Process -Force
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")) { Write-Error "CRITICAL: Run as administrator!"; exit }
$CurrentUserSID = ([Security.Principal.WindowsIdentity]::GetCurrent()).User.Value
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\AppIDSvc" -Name "Start" -Value 2
Start-Service -Name "AppIDSvc" -ErrorAction SilentlyContinue
$PolicyFile = Join-Path $env:TEMP "AppLockerPolicy.xml"
$XmlTemplate = @"
<AppLockerPolicy Version="1">
  <RuleCollection Type="Exe" EnforcementMode="Enabled">
    <FilePublisherRule Id="6c44dec4-0d85-4ef5-96c2-47f981447055" Name="Microsoft Corporation Signed" Description="Allows Microsoft Corporation" UserOrGroupSid="$CurrentUserSID" Action="Allow">
      <Conditions><FilePublisherCondition PublisherName="O=MICROSOFT CORPORATION, L=REDMOND, S=WASHINGTON, C=US" ProductName="*" BinaryName="*"><BinaryVersionRange LowSection="*" HighSection="*" /></FilePublisherCondition></Conditions>
    </FilePublisherRule>
    <FilePublisherRule Id="7c44dec4-0d85-4ef5-96c2-47f981447056" Name="Microsoft Windows Signed" Description="Allows Microsoft Windows" UserOrGroupSid="$CurrentUserSID" Action="Allow">
      <Conditions><FilePublisherCondition PublisherName="O=MICROSOFT WINDOWS, L=REDMOND, S=WASHINGTON, C=US" ProductName="*" BinaryName="*"><BinaryVersionRange LowSection="*" HighSection="*" /></FilePublisherCondition></Conditions>
    </FilePublisherRule>
    <FilePublisherRule Id="8c44dec4-0d85-4ef5-96c2-47f981447057" Name="Microsoft Azure Signed" Description="Allows Microsoft Azure" UserOrGroupSid="$CurrentUserSID" Action="Allow">
      <Conditions><FilePublisherCondition PublisherName="O=MICROSOFT AZURE, L=REDMOND, S=WASHINGTON, C=US" ProductName="*" BinaryName="*"><BinaryVersionRange LowSection="*" HighSection="*" /></FilePublisherCondition></Conditions>
    </FilePublisherRule>
  </RuleCollection>
  <RuleCollection Type="Msi" EnforcementMode="Enabled">
    <FilePublisherRule Id="92a2a0bf-8869-45e0-b6f7-c3761899127d" Name="Microsoft Corporation MSI" Description="Allows Microsoft Corporation MSI" UserOrGroupSid="$CurrentUserSID" Action="Allow">
      <Conditions><FilePublisherCondition PublisherName="O=MICROSOFT CORPORATION, L=REDMOND, S=WASHINGTON, C=US" ProductName="*" BinaryName="*"><BinaryVersionRange LowSection="*" HighSection="*" /></FilePublisherCondition></Conditions>
    </FilePublisherRule>
  </RuleCollection>
  <RuleCollection Type="Script" EnforcementMode="Enabled">
    <FilePublisherRule Id="11cf746d-2c70-4fc7-bf84-75488eb44cfc" Name="Microsoft Corporation Scripts" Description="Allows Microsoft Corporation Scripts" UserOrGroupSid="$CurrentUserSID" Action="Allow">
      <Conditions><FilePublisherCondition PublisherName="O=MICROSOFT CORPORATION, L=REDMOND, S=WASHINGTON, C=US" ProductName="*" BinaryName="*"><BinaryVersionRange LowSection="*" HighSection="*" /></FilePublisherCondition></Conditions>
    </FilePublisherRule>
  </RuleCollection>
</AppLockerPolicy>
"@
$XmlTemplate | Out-File -FilePath $PolicyFile -Encoding utf8
Set-AppLockerPolicy -XmlPolicy $PolicyFile -Merge
Remove-Item -Path $PolicyFile -Force
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
$WallpaperUrl, $WallpaperPath, $SW_HIDE = "https://raw.githubusercontent.com/djameledin/untitled/refs/heads/main/wallpaper.png", "C:\Users\Public\Pictures\wallpaper.jpg", 0
$Targets = @("D:\DATALOSS_WARNING_README.txt", "D:\CollectGuestLogsTemp")
$processesToHide = @("hosted-compute-agent", "tailscale-ipn")
$regPath, $p = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer", "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"
$startMenus = @("$env:USERPROFILE\AppData\Roaming\Microsoft\Windows\Start Menu\Programs")
$Exceptions = @("Microsoft Edge.lnk", "Tailscale.lnk", "Windows PowerShell", "Azure Arc Setup.lnk")
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
Remove-Item "$env:USERPROFILE\Desktop\*.lnk" -Force -ErrorAction SilentlyContinue
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
Set-ItemProperty -Path $regPath -Name "NoDrives" -Value 4 -Type DWord -Force
Set-ItemProperty -Path $regPath -Name "NoViewOnDrive" -Value 4 -Type DWord -Force
gpupdate /force
Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
