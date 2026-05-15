Write-Host "=== ENTERPRISE VPS CLEAN + HIDDEN APPS SETUP ===" -ForegroundColor Cyan

# =========================
# 1. Disable CMD
# =========================
New-Item -Path "HKCU:\Software\Policies\Microsoft\Windows\System" -Force | Out-Null
Set-ItemProperty -Path "HKCU:\Software\Policies\Microsoft\Windows\System" `
-Name DisableCMD -Value 1

# =========================
# 2. Disable RUN (Win + R)
# =========================
New-Item -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Force | Out-Null
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" `
-Name NoRun -Value 1

# =========================
# 3. Disable Task Manager
# =========================
New-Item -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\System" -Force | Out-Null
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\System" `
-Name DisableTaskMgr -Value 1

# =========================
# 4. Disable Registry Tools
# =========================
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\System" `
-Name DisableRegistryTools -Value 1 -Type DWord

# =========================
# 5. Block system tools (execution restriction layer)
# =========================
New-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" `
-Name DisallowRun -Value 1 -PropertyType DWord -Force | Out-Null

New-Item -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer\DisallowRun" -Force | Out-Null

$blockedApps = @(
"cmd.exe",
"powershell.exe",
"pwsh.exe",
"wt.exe",
"WindowsTerminal.exe",
"regedit.exe",
"taskmgr.exe",
"control.exe",
"mmc.exe",
"msconfig.exe"
)

$i = 1
foreach ($app in $blockedApps) {
    New-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer\DisallowRun" `
    -Name $i -Value $app -PropertyType String -Force | Out-Null
    $i++
}

# =========================
# 6. File Explorer lockdown
# =========================

# Hide drives
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" `
-Name NoDrives -Value 3 -Type DWord

Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" `
-Name NoViewOnDrive -Value 3 -Type DWord

# Disable Control Panel access
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" `
-Name NoControlPanel -Value 1 -Type DWord

# =========================
# 7. Remove UI shortcuts (clean “Installed Apps feel”)
# =========================

# Remove Desktop shortcuts
Remove-Item "$env:Public\Desktop\*.lnk" -Force -ErrorAction SilentlyContinue
Remove-Item "$env:USERPROFILE\Desktop\*.lnk" -Force -ErrorAction SilentlyContinue

# Clean Start Menu shortcuts (basic)
$startMenus = @(
"$env:ProgramData\Microsoft\Windows\Start Menu\Programs",
"$env:USERPROFILE\AppData\Roaming\Microsoft\Windows\Start Menu\Programs"
)

foreach ($path in $startMenus) {
    Get-ChildItem $path -Recurse -Filter "*.lnk" -ErrorAction SilentlyContinue |
    Remove-Item -Force -ErrorAction SilentlyContinue
}

# =========================
# 8. OPTIONAL: Reduce Search visibility
# =========================
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" `
-Name SearchboxTaskbarMode -Value 0

# =========================
# 9. IMPORTANT NOTE
# =========================
Write-Host "WARNING: This script does NOT hide Installed Apps list completely." -ForegroundColor Yellow
Write-Host "Real control requires AppLocker or WDAC (enterprise level)." -ForegroundColor Yellow

# =========================
# DONE
# =========================
Write-Host "=== ENTERPRISE VPS CLEAN MODE APPLIED ===" -ForegroundColor Green
Write-Host "RESTART SYSTEM REQUIRED." -ForegroundColor Yellow
