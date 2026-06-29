# build_release.ps1 — builds de release endurecidos para COSSMIL
# -----------------------------------------------------------------------------
# Móvil: --obfuscate ofusca el código Dart compilado (esconde client_secret,
#        endpoints y lógica al decompilar el APK). --split-debug-info guarda los
#        símbolos APARTE para poder des-ofuscar los stack traces de crashes.
# Web:   --csp genera salida sin eval/inline, compatible con la Content-Security
#        -Policy declarada en web/index.html.
#
# IMPORTANTE: archiva la carpeta de símbolos por cada versión publicada. Sin
# ella no podrás leer los reportes de error ofuscados de esa versión.
# -----------------------------------------------------------------------------
$ErrorActionPreference = 'Stop'

# Símbolos por versión (coincide con AppConfig.appVersion / pubspec).
$version = '1.0.3'
$symbols = "symbols/$version"
New-Item -ItemType Directory -Force -Path $symbols | Out-Null

Write-Host "==> Android APK (ofuscado)..." -ForegroundColor Cyan
flutter build apk --release --obfuscate --split-debug-info=$symbols

Write-Host "==> Android App Bundle (ofuscado)..." -ForegroundColor Cyan
flutter build appbundle --release --obfuscate --split-debug-info=$symbols

# iOS: solo compila en macOS. Descomenta si construyes en Mac.
# flutter build ipa --release --obfuscate --split-debug-info=$symbols

Write-Host "==> Web (modo CSP)..." -ForegroundColor Cyan
flutter build web --release --csp

# -- Inyectar la capa de seguridad SOLO en el artefacto de release web --------
# (No se pone en web/index.html porque rompería `flutter run` en debug.)
Write-Host "==> Inyectando CSP + seguridad en build/web/index.html..." -ForegroundColor Cyan
$full = (Resolve-Path "build/web/index.html").Path
$html = [System.IO.File]::ReadAllText($full)

$headInject = @"
  <meta http-equiv="Content-Security-Policy" content="default-src 'self'; script-src 'self' 'wasm-unsafe-eval' https://www.gstatic.com; style-src 'self' 'unsafe-inline'; img-src 'self' data: blob: https:; font-src 'self' data:; connect-src 'self' https://api.cossmil.mil.bo https://www.cossmil.mil.bo https://www.gstatic.com; worker-src 'self' blob:; object-src 'none'; base-uri 'self';">
  <meta name="referrer" content="no-referrer">
"@

$html = $html.Replace('</head>', "$headInject</head>")
$html = $html.Replace('</body>', "  <script src=""flutter_security.js""></script>`r`n</body>")

[System.IO.File]::WriteAllText($full, $html, (New-Object System.Text.UTF8Encoding($false)))

Write-Host ""
Write-Host "Listo." -ForegroundColor Green
Write-Host "Símbolos de des-ofuscación en: $symbols  (archívalos por release)" -ForegroundColor Yellow
Write-Host "Web endurecida en build/web (CSP + flutter_security.js inyectados)." -ForegroundColor Yellow
