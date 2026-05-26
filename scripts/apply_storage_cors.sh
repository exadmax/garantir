#!/usr/bin/env bash
set -euo pipefail

BUCKET="${1:-omegabackend-88ebc.firebasestorage.app}"
CORS_FILE="${2:-storage.cors.json}"

if [[ ! -f "$CORS_FILE" ]]; then
  echo "Arquivo de CORS nao encontrado: $CORS_FILE"
  echo "Execute no diretorio raiz do projeto ou informe o caminho correto no 2o argumento."
  exit 1
fi

if command -v gcloud >/dev/null 2>&1; then
  echo "Aplicando CORS com gcloud em gs://$BUCKET"
  gcloud storage buckets update "gs://$BUCKET" --cors-file="$CORS_FILE"
  echo "CORS aplicado com sucesso."
  exit 0
fi

if command -v gsutil >/dev/null 2>&1; then
  echo "Aplicando CORS com gsutil em gs://$BUCKET"
  gsutil cors set "$CORS_FILE" "gs://$BUCKET"
  echo "CORS aplicado com sucesso."
  exit 0
fi

echo "Nem gcloud nem gsutil estao disponiveis no PATH."
echo "Instale um deles e rode novamente:"
echo "  bash scripts/apply_storage_cors.sh $BUCKET"
exit 1
