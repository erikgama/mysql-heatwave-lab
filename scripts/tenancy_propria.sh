#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
: "${OCI_REGION:?Defina OCI_REGION, por exemplo us-chicago-1}"

LAKE_BUCKET="${LAKE_BUCKET:-lab_lakehouse}"
RAG_BUCKET="${RAG_BUCKET:-lab_rag}"
OCI_ARGS=(--region "$OCI_REGION")
if [[ -n "${OCI_PROFILE:-}" ]]; then
  OCI_ARGS+=(--profile "$OCI_PROFILE")
fi

command -v oci >/dev/null || { echo 'OCI CLI não encontrado.' >&2; exit 1; }
NAMESPACE="$(oci os ns get "${OCI_ARGS[@]}" --query data --raw-output)"
[[ -n "$NAMESPACE" && "$NAMESPACE" != null ]] || {
  echo 'Não foi possível obter o namespace do Object Storage.' >&2
  exit 1
}

create_bucket() {
  local name="$1" compartment="$2" actual
  if actual="$(oci os bucket get --namespace-name "$NAMESPACE" \
      --bucket-name "$name" "${OCI_ARGS[@]}" \
      --query 'data."compartment-id"' --raw-output 2>/dev/null)"; then
    [[ "$actual" == "$compartment" ]] || {
      echo "Bucket $name já existe em outro compartimento: $actual" >&2
      exit 1
    }
    echo "Bucket já existe: $name"
  else
    oci os bucket create --namespace-name "$NAMESPACE" \
      --compartment-id "$compartment" --name "$name" \
      --public-access-type NoPublicAccess "${OCI_ARGS[@]}" >/dev/null
    echo "Bucket privado criado: $name"
  fi
}

require_bucket() {
  oci os bucket get --namespace-name "$NAMESPACE" \
    --bucket-name "$1" "${OCI_ARGS[@]}" >/dev/null
}

put() {
  local bucket="$1" source="$2" object="$3"
  [[ -f "$ROOT/$source" ]] || { echo "Arquivo ausente: $source" >&2; exit 1; }
  oci os object put --namespace-name "$NAMESPACE" \
    --bucket-name "$bucket" --file "$ROOT/$source" \
    --name "$object" --force "${OCI_ARGS[@]}" >/dev/null
  echo "$bucket/$object"
}

case "${1:-}" in
  criar-buckets)
    : "${OCI_COMPARTMENT_OCID:?Defina OCI_COMPARTMENT_OCID}"
    create_bucket "$LAKE_BUCKET" "$OCI_COMPARTMENT_OCID"
    create_bucket "$RAG_BUCKET" "$OCI_COMPARTMENT_OCID"
    ;;
  inicio)
    require_bucket "$LAKE_BUCKET"
    require_bucket "$RAG_BUCKET"
    put "$LAKE_BUCKET" dados/lakehouse/bank_lab_5col.csv manual/bank.csv
    put "$LAKE_BUCKET" dados/lakehouse/bank_lab_5col.parquet manual/bank.parquet
    put "$LAKE_BUCKET" dados/lakehouse/bank_lab_5col.csv automatic/bank.csv
    put "$LAKE_BUCKET" dados/lakehouse/bank_lab_5col.parquet automatic/bank.parquet
    put "$LAKE_BUCKET" dados/lakehouse/bank_lab_5col_part_1.csv dynamic/csv/part_1.csv
    put "$LAKE_BUCKET" dados/lakehouse/bank_lab_5col_part_1.parquet dynamic/parquet/part_1.parquet
    put "$RAG_BUCKET" dados/rag/guia_campanha_bancaria.txt guia_campanha_bancaria.txt
    ;;
  segunda-parte)
    require_bucket "$LAKE_BUCKET"
    put "$LAKE_BUCKET" dados/lakehouse/bank_lab_5col_part_2.csv dynamic/csv/part_2.csv
    put "$LAKE_BUCKET" dados/lakehouse/bank_lab_5col_part_2.parquet dynamic/parquet/part_2.parquet
    ;;
  verificar)
    for bucket in "$LAKE_BUCKET" "$RAG_BUCKET"; do
      echo "Objetos em $bucket:"
      oci os object list --namespace-name "$NAMESPACE" \
        --bucket-name "$bucket" "${OCI_ARGS[@]}" \
        --query 'data.objects[].name' --output table
    done
    ;;
  *)
    echo "Uso: $0 {criar-buckets|inicio|segunda-parte|verificar}" >&2
    exit 2
    ;;
esac

echo "Namespace: $NAMESPACE | Região: $OCI_REGION"
