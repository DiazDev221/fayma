#!/usr/bin/env bash
# Construit des APK release allégés : un fichier par architecture CPU.
set -euo pipefail

cd "$(dirname "$0")/.."

if [[ ! -f tool/drive_defines.json ]]; then
  echo "Attention : tool/drive_defines.json est absent." >&2
  echo "L'APK sera compilé SANS Google Drive (export local uniquement)." >&2
  echo "Voir README.md, section « Sauvegarde Google Drive »." >&2
  echo >&2
fi

ARGS=(
  build apk
  --release
  --split-per-abi
  --obfuscate
  --split-debug-info=build/symbols
)

if [[ -f tool/drive_defines.json ]]; then
  ARGS+=(--dart-define-from-file=tool/drive_defines.json)
fi

flutter "${ARGS[@]}"

echo
echo "APK générés :"
ls -lh build/app/outputs/flutter-apk/*.apk
