#!/usr/bin/env bash
# Construit l'archive iOS et l'IPA signé (TestFlight / App Store).
set -euo pipefail

cd "$(dirname "$0")/.."

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "La compilation iOS nécessite macOS et Xcode." >&2
  exit 1
fi

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "Xcode est introuvable. Installez Xcode depuis le Mac App Store." >&2
  exit 1
fi

if [[ ! -f tool/drive_defines.json ]]; then
  echo "Attention : tool/drive_defines.json est absent." >&2
  echo "L'IPA sera compilé SANS Google Drive (export local uniquement)." >&2
  echo "Voir README.md, section « Sauvegarde Google Drive »." >&2
  echo >&2
fi

ARGS=(
  build ipa
  --release
  --obfuscate
  --split-debug-info=build/symbols
)

if [[ -f tool/drive_defines.json ]]; then
  ARGS+=(--dart-define-from-file=tool/drive_defines.json)
fi

flutter "${ARGS[@]}"

echo
echo "IPA généré :"
ls -lh build/ios/ipa/*.ipa
