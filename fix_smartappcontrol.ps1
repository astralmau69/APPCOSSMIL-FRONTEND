# ── fix_smartappcontrol.ps1 ──────────────────────────────────────────────────
# Desactiva Smart App Control (SAC) que bloquea dart.exe / Flutter.
# EJECUTAR COMO ADMINISTRADOR (clic derecho → "Ejecutar con PowerShell" → Sí en UAC)
# ─────────────────────────────────────────────────────────────────────────────

if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "ERROR: Este script debe ejecutarse como Administrador." -ForegroundColor Red
    Write-Host "Clic derecho en el archivo > 'Ejecutar con PowerShell'" -ForegroundColor Yellow
    pause
    exit 1
}

Write-Host "Desactivando Smart App Control..." -ForegroundColor Cyan

# Desactivar SAC (0 = Off, 1 = Evaluation, 2 = On)
Set-ItemProperty `
    -Path  'HKLM:\SYSTEM\CurrentControlSet\Control\CI\Policy' `
    -Name  'VerifiedAndReputablePolicyState' `
    -Value 0 `
    -Type  DWord `
    -Force

$val = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\CI\Policy' -Name VerifiedAndReputablePolicyState).VerifiedAndReputablePolicyState
if ($val -eq 0) {
    Write-Host "Smart App Control DESACTIVADO correctamente." -ForegroundColor Green
} else {
    Write-Host "No se pudo cambiar (valor actual: $val). Usa el metodo UI." -ForegroundColor Red
}

# Agregar Flutter a exclusiones de Windows Defender
Write-Host "Agregando D:\flutter a exclusiones de Windows Defender..." -ForegroundColor Cyan
try {
    Add-MpPreference -ExclusionPath 'D:\flutter' -ErrorAction Stop
    Write-Host "Exclusion agregada." -ForegroundColor Green
} catch {
    Write-Host "No se pudo agregar exclusion: $_" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Listo. Reinicia PowerShell y ejecuta: flutter run" -ForegroundColor Green
pause
