#!/usr/bin/env bash
set -euo pipefail

# Uploads a file to uploader.sh and prints the resulting URL.
# Usage:
#   scripts/upload_uploader_sh.sh <file_path>
# Optional env:
#   UPLOADER_ENDPOINT (default: https://uploader.sh)

if [[ $# -lt 1 ]]; then
  echo "Uso: $0 <caminho_do_arquivo>" >&2
  exit 1
fi

FILE_PATH="$1"
ENDPOINT="${UPLOADER_ENDPOINT:-https://uploader.sh}"

if [[ ! -f "$FILE_PATH" ]]; then
  echo "Arquivo nao encontrado: $FILE_PATH" >&2
  exit 1
fi

# -sS: quiet with error details, -L: follow redirects
RESPONSE="$(curl -sSL "$ENDPOINT" -T "$FILE_PATH")"

URL="$(printf '%s\n' "$RESPONSE" | grep -Eo 'https?://[^[:space:]]+' | head -n 1 || true)"

if [[ -z "$URL" ]]; then
  echo "Nao foi possivel extrair URL do upload. Resposta bruta:" >&2
  printf '%s\n' "$RESPONSE" >&2
  exit 2
fi

printf '%s\n' "$URL"
