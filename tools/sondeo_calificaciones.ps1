<#
.SYNOPSIS
  Muestra lo que devuelven de verdad los endpoints de calificacion.

.DESCRIPTION
  Pide el token con una cuenta real y consulta:
    - /api/programacion/calificaciones-pendientes/{idper}
    - /api/programacion/historial-citas/{idper}/1/20
  De cada respuesta imprime las claves del sobre, cuantos items trae, las
  claves de un item y todos los campos que parezcan un estado de calificacion.
  Sirve para ver COMO se llama el campo nuevo y que forma tiene lo pendiente,
  sin tener que adivinarlo desde el codigo.

  La salida completa queda en un .txt al lado del script.

.NOTES
  La contraseña no se escribe en el archivo ni queda en el historial de la
  consola: se pide de forma oculta si no se pasa por parametro.

  OJO: la salida contiene datos personales y medicos de la cuenta que use
  (nombres, cedula, citas). Revisela antes de compartirla.

.EXAMPLE
  .\tools\sondeo_calificaciones.ps1 -Usuario 010325AQJ -Idper 5179
#>
param(
  [string]$Usuario = '010325AQJ',
  [int]$Idper = 5179,
  [string]$BaseUrl = 'https://api.cossmil.mil.bo',
  [System.Security.SecureString]$Password
)

$ErrorActionPreference = 'Stop'

# Windows PowerShell 5.1 negocia TLS 1.0 por defecto y el servidor lo rechaza.
try {
  [Net.ServicePointManager]::SecurityProtocol =
    [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13
} catch {
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
}

if (-not $Password) {
  $Password = Read-Host -AsSecureString "Contraseña de $Usuario"
}
$planaPwd = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
  [Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password))

$salida = Join-Path $PSScriptRoot 'sondeo_calificaciones.txt'
$lineas = New-Object System.Collections.Generic.List[string]
function Anotar([string]$texto) {
  Write-Host $texto
  $lineas.Add($texto)
}

# clientId:clientSecret de la app (ApiConstants), no del usuario.
$basic = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes('frontendapp:12345'))

Anotar "== 1. token =="
try {
  $tok = Invoke-RestMethod -Method Post -Uri "$BaseUrl/api/security/oauth/token" `
    -Headers @{ Authorization = "Basic $basic" } `
    -ContentType 'application/x-www-form-urlencoded' `
    -Body @{ grant_type = 'password'; username = $Usuario; password = $planaPwd }
} catch {
  Anotar "No se pudo obtener el token: $($_.Exception.Message)"
  $lineas | Set-Content -Path $salida -Encoding UTF8
  exit 1
}
if (-not $tok.access_token) {
  Anotar "La respuesta no trae access_token."
  $lineas | Set-Content -Path $salida -Encoding UTF8
  exit 1
}
Anotar "token OK ($($tok.access_token.Length) chars)"

function Sondear([string]$etiqueta, [string]$ruta) {
  Anotar ''
  Anotar "== $etiqueta =="
  Anotar "GET $ruta"
  try {
    $resp = Invoke-RestMethod -Method Get -Uri "$BaseUrl$ruta" `
      -Headers @{ Authorization = "Bearer $($tok.access_token)" }
  } catch {
    Anotar "Fallo: $($_.Exception.Message)"
    return
  }

  Anotar "claves del sobre: $(($resp.PSObject.Properties.Name) -join ', ')"
  $datos = if ($null -ne $resp.data) { $resp.data } else { $resp }
  $items = @($datos)

  if ($items.Count -eq 0 -or $null -eq $items[0]) {
    Anotar 'items: 0 (vacio)'
    Anotar ($resp | ConvertTo-Json -Depth 8)
    return
  }

  Anotar "items: $($items.Count)"
  Anotar "claves del item: $((($items[0].PSObject.Properties.Name) | Sort-Object) -join ', ')"
  Anotar 'primer item completo:'
  Anotar ($items[0] | ConvertTo-Json -Depth 8)

  Anotar '--- campos de calificacion por item ---'
  foreach ($it in ($items | Select-Object -First 12)) {
    $marcados = @{}
    foreach ($p in $it.PSObject.Properties) {
      if ($p.Name -match '(?i)calif' -or
          $p.Name -match '(?i)^(velo|estado|conf)$') {
        $marcados[$p.Name] = $p.Value
      }
    }
    Anotar (($marcados.GetEnumerator() |
      ForEach-Object { "$($_.Key)=$($_.Value)" }) -join '  ')
  }
}

Sondear '2. calificaciones pendientes' "/api/programacion/calificaciones-pendientes/$Idper"
Sondear '3. historial de citas (aca esta el campo nuevo)' "/api/programacion/historial-citas/$Idper/1/20"

$lineas | Set-Content -Path $salida -Encoding UTF8
Write-Host ''
Write-Host "Salida guardada en: $salida"
