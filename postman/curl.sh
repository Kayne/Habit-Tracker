#!/usr/bin/env bash
# =============================================================
# End-to-end flow przez curl. Uruchom: bash postman/curl.sh
# Wymaga jq (brew install jq / apt install jq).
# =============================================================
set -euo pipefail

AUTH=http://localhost:8001
HABITS=http://localhost:8002
EMAIL="marcin_$(date +%s)@example.com"
PASSWORD="SuperSecret123"

echo "==> 1) Register"
curl -sS -X POST "$AUTH/auth/register" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$EMAIL\",\"password\":\"$PASSWORD\",\"display_name\":\"Marcin\"}" | jq .

echo "==> 2) Login"
TOKEN=$(curl -sS -X POST "$AUTH/auth/login" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$EMAIL\",\"password\":\"$PASSWORD\"}" | jq -r .access_token)
echo "TOKEN=${TOKEN:0:20}..."

echo "==> 3) /auth/me"
curl -sS "$AUTH/auth/me" -H "Authorization: Bearer $TOKEN" | jq .

echo "==> 4) Create habit"
HID=$(curl -sS -X POST "$HABITS/habits" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name":"Bieganie","description":"5 km rano","target_per_week":4}' | jq -r .id)
echo "HABIT_ID=$HID"

echo "==> 5) Log today"
curl -sS -X POST "$HABITS/habits/$HID/logs" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"note":"Rano, 6 km"}' | jq .

echo "==> 6) Stats"
curl -sS "$HABITS/habits/$HID/stats" -H "Authorization: Bearer $TOKEN" | jq .

echo "==> 7) Negatywna ścieżka: brak tokenu"
curl -sS -w "\nHTTP %{http_code}\n" "$HABITS/habits" || true

echo "OK"
