#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NAMESPACE="idi1o0a010nx"
REGION="us-chicago-1"

put() {
  local bucket="$1" source="$2" object="$3"
  oci os object put \
    --namespace-name "$NAMESPACE" \
    --bucket-name "$bucket" \
    --region "$REGION" \
    --file "$ROOT/$source" \
    --name "$object" \
    --force
}

case "${1:-}" in
  inicio)
    put lab_lakehouse dados/lakehouse/bank_lab_5col.csv manual/bank.csv
    put lab_lakehouse dados/lakehouse/bank_lab_5col.parquet manual/bank.parquet
    put lab_lakehouse dados/lakehouse/bank_lab_5col.csv automatic/bank.csv
    put lab_lakehouse dados/lakehouse/bank_lab_5col.parquet automatic/bank.parquet
    put lab_lakehouse dados/lakehouse/bank_lab_5col_part_1.csv dynamic/csv/part_1.csv
    put lab_lakehouse dados/lakehouse/bank_lab_5col_part_1.parquet dynamic/parquet/part_1.parquet
    put lab_rag dados/rag/guia_campanha_bancaria.txt guia_campanha_bancaria.txt
    ;;
  segunda-parte)
    put lab_lakehouse dados/lakehouse/bank_lab_5col_part_2.csv dynamic/csv/part_2.csv
    put lab_lakehouse dados/lakehouse/bank_lab_5col_part_2.parquet dynamic/parquet/part_2.parquet
    ;;
  *)
    printf 'Uso: %s {inicio|segunda-parte}\n' "$0" >&2
    exit 2
    ;;
esac
