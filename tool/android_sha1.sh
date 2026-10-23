#!/usr/bin/env bash
# Affiche les empreintes SHA-1 des clés Android au format Google Cloud.
set -euo pipefail

cd "$(dirname "$0")/.."

print_sha1() {
  local label="$1"
  local keystore="$2"
  local alias="$3"
  local password="$4"

  if [[ ! -f "$keystore" ]]; then
    return
  fi

  printf '%s : ' "$label"
  keytool -exportcert -keystore "$keystore" -alias "$alias" \
    -storepass "$password" 2>/dev/null \
    | openssl sha1 -binary \
    | od -An -tx1 -v | tr -d ' \n' | tr 'a-f' 'A-F' \
    | sed 's/../&:/g; s/:$//'
  printf '\n'
}

if [[ -f android/key.properties ]]; then
  store="$(sed -n 's/^storeFile=//p' android/key.properties | head -1)"
  alias="$(sed -n 's/^keyAlias=//p' android/key.properties | head -1)"
  password="$(sed -n 's/^storePassword=//p' android/key.properties | head -1)"

  if [[ -n "$store" && "$store" != /* ]]; then
    store="android/$store"
  fi

  print_sha1 "Release" "$store" "${alias:-upload}" "$password"
fi

print_sha1 "Debug" "$HOME/.android/debug.keystore" "androiddebugkey" "android"
