Set-ExecutionPolicy Bypass -Scope Process -Force
if(-not(([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator"))){exit}

Add-Type @"
using System;
using System.Runtime.InteropServices;
public class NativeWallpaper{
    [DllImport("user32.dll", CharSet=CharSet.Auto, SetLastError=true)]
    public static bool SystemParametersInfo(uint uAction,uint uParam,string lpvParam,uint fuWinIni){
        return SystemParametersInfo(uAction,uParam,lpvParam,fuWinIni);
    }
}
"@

$regPath="HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer"
if(-not(Test-Path $regPath)){New-Item -Path $regPath -Force|Out-Null}
Set-ItemProperty -Path $regPath -Name "NoRun" -Value 1
$CDriveValue=4
Set-ItemProperty -Path $regPath -Name "NoDrives" -Value $CDriveValue -Type DWord
Set-ItemProperty -Path $regPath -Name "NoViewOnDrive" -Value $CDriveValue -Type DWord

$Folders=@{
    "Desktop"="D:\Desktop"
    "Documents"="D:\Documents"
    "Downloads"="D:\Downloads"
    "Pictures"="D:\Pictures"
    "Videos"="D:\Videos"
    "Music"="D:\Music"
}

foreach($Key in $Folders.Keys){
    $Path=$Folders[$Key]
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders" -Name $Key -Value $Path
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders" -Name $Key -Value $Path
}

$desktopFiles=Get-ChildItem "C:\Users\*" -Directory | ForEach-Object{
    $d=Join-Path $_.FullName "Desktop"
    if(Test-Path $d){Get-ChildItem $d -File -ErrorAction SilentlyContinue}
}
if($desktopFiles){$desktopFiles|Remove-Item -Force -ErrorAction SilentlyContinue}

$WallpaperUrl="https://raw.githubusercontent.com/djameledin/untitled/refs/heads/main/default.jpg"
$WallpaperPath="C:\Users\Public\Pictures\wallpaper.jpg"
if(-not(Test-Path $WallpaperPath)){Invoke-WebRequest -Uri $WallpaperUrl -OutFile $WallpaperPath -UseBasicParsing -ErrorAction SilentlyContinue}
if(Test-Path $WallpaperPath){[NativeWallpaper]::SetWallpaper($WallpaperPath)|Out-Null}

$p="HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"
Set-ItemProperty $p "AppsUseLightTheme" 1
Set-ItemProperty $p "SystemUsesLightTheme" 1

Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
Start-Process explorer.exe
Start-Sleep -Seconds 3

$Apps=@(
    @{Name="Windows Calculator";ID="9WZDNCRFHVN5"},
    @{Name="Windows Notepad";ID="9MSMLRH6LZF3"},
    @{Name="Microsoft Sticky Notes";ID="9NBLGGH4QGHW"},
    @{Name="Snipping Tool";ID="9MZ95KL8MR0L"},
    @{Name="Paint";ID="9PCFS5B6T72H"},
    @{Name="Windows Clock";ID="9WZDNCRFJ3PR"}
)

function Install-App($AppId,$AppName){
    try{
        $installed=(winget list --id $AppId --source msstore | Select-String $AppId) -ne $null
    } catch { $installed=$false }
    if(-not $installed){
        Write-Host "Installing $AppName..."
        try {winget install --id $AppId --source msstore --accept-source-agreements --accept-package-agreements -h}catch{Write-Warning "Failed to install $AppName. Retry later."}
    } else {Write-Host "$AppName is already installed."}
}

foreach($app in $Apps){Install-App $app.ID $app.Name}

Write-Host "System setup complete."
