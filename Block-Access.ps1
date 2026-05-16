# =============================================
# سكريبت منع وصول المستخدمين من المجلدات
# =============================================

# التحقق من صلاحيات Administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")

if (-not $isAdmin) {
    Write-Host "❌ يجب تشغيل السكريبت كـ Administrator" -ForegroundColor Red
    exit 1
}

Write-Host "`n╔════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║     منع وصول المستخدمين من المجلدات    ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════╝" -ForegroundColor Cyan

$user = Read-Host "`nأدخل اسم المستخدم (مثال: StandardUser أو DOMAIN\Username)"
$folder = Read-Host "أدخل مسار المجلد (مثال: C:\SensitiveData)"

if (-not (Test-Path $folder)) {
    Write-Host "`n❌ المجلد غير موجود: $folder" -ForegroundColor Red
    exit 1
}

# إضافة اسم الحاسوب إذا لم يتم إدخال Domain
if ($user -notmatch "\\") {
    $user = "$env:COMPUTERNAME\$user"
}

try {
    Write-Host "`n⏳ جاري منع الوصول..." -ForegroundColor Yellow
    
    # منع الوصول من المجلد والمجلدات الفرعية
    & icacls $folder /remove "`"$user`"" /t /c /q
    
    Write-Host "✓ تم منع وصول $user من $folder بنجاح" -ForegroundColor Green
    Write-Host "`n✓ تم تطبيق المنع على جميع المجلدات الفرعية أيضاً" -ForegroundColor Green
}
catch {
    Write-Host "`n❌ حدث خطأ: $_" -ForegroundColor Red
    exit 1
}

Write-Host "`n════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "انتهى!" -ForegroundColor Cyan
Write-Host "════════════════════════════════════════`n" -ForegroundColor Cyan
