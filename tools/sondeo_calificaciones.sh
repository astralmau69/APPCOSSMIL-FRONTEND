#!/usr/bin/env bash
# Igual que sondeo_calificaciones.ps1, para Linux/macOS o Git Bash.
#
# La contraseña NO va en este archivo: se lee del entorno o se pide oculta.
#   COSSMIL_PASS='...' bash tools/sondeo_calificaciones.sh
#
# OJO: la salida contiene datos personales y médicos de la cuenta que use
# (nombres, cédula, citas). Revísela antes de compartirla.
set -uo pipefail

BASE="${COSSMIL_BASE:-https://api.cossmil.mil.bo}"
USUARIO="${COSSMIL_USER:-010325AQJ}"
IDPER="${COSSMIL_IDPER:-5179}"
PASS="${COSSMIL_PASS:-}"
SALIDA="$(dirname "$0")/sondeo_calificaciones.txt"

if [ -z "$PASS" ]; then
  read -rsp "Contraseña de $USUARIO: " PASS; echo
fi

# clientId:clientSecret de la app (ApiConstants), no del usuario.
BASIC=$(printf 'frontendapp:12345' | base64 | tr -d '\n')

{
  echo "== 1. token =="
  TOKEN_JSON=$(curl -sS --max-time 40 -X POST "$BASE/api/security/oauth/token" \
    -H "Authorization: Basic $BASIC" \
    -H 'Content-Type: application/x-www-form-urlencoded' \
    --data-urlencode 'grant_type=password' \
    --data-urlencode "username=$USUARIO" \
    --data-urlencode "password=$PASS") || { echo "sin red (curl $?)"; exit 1; }

  TOKEN=$(printf '%s' "$TOKEN_JSON" \
    | python3 -c 'import json,sys; print(json.load(sys.stdin).get("access_token",""))' 2>/dev/null)
  if [ -z "$TOKEN" ]; then
    echo "La respuesta no trae access_token:"
    printf '%s\n' "$TOKEN_JSON" | head -c 600
    exit 1
  fi
  echo "token OK (${#TOKEN} chars)"

  sondear () {
    echo; echo "== $1 =="; echo "GET $2"
    curl -sS --max-time 40 -H "Authorization: Bearer $TOKEN" "$BASE$2" | python3 -c '
import json, sys
raw = sys.stdin.read()
try:
    b = json.loads(raw)
except Exception:
    print("(no es JSON)"); print(raw[:800]); raise SystemExit
print("claves del sobre:", list(b) if isinstance(b, dict) else type(b).__name__)
d = b.get("data") if isinstance(b, dict) else b
if not isinstance(d, list):
    print(json.dumps(b, indent=2, ensure_ascii=False)[:1500]); raise SystemExit
print("items:", len(d))
if not d:
    raise SystemExit
print("claves del item:", ", ".join(sorted(d[0])))
print("primer item completo:")
print(json.dumps(d[0], indent=2, ensure_ascii=False))
print("--- campos de calificacion por item ---")
for it in d[:12]:
    print({k: v for k, v in it.items()
           if "calif" in k.lower() or k.lower() in ("velo", "estado", "conf")})
'
  }

  sondear "2. calificaciones pendientes" "/api/programacion/calificaciones-pendientes/$IDPER"
  sondear "3. historial de citas (aca esta el campo nuevo)" "/api/programacion/historial-citas/$IDPER/1/20"
} 2>&1 | tee "$SALIDA"

echo
echo "Salida guardada en: $SALIDA"
