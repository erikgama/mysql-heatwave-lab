#!/usr/bin/env python3
"""Gera uma cópia do SQL com URIs do Object Storage de outra tenancy."""

import argparse
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "sql" / "laboratorio.sql"


def identifier(value, label):
    if not re.fullmatch(r"[A-Za-z0-9_.-]+", value):
        raise argparse.ArgumentTypeError(f"{label} contém caracteres inválidos")
    return value


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--namespace", required=True)
    parser.add_argument("--lake-bucket", default="lab_lakehouse")
    parser.add_argument("--rag-bucket", default="lab_rag")
    parser.add_argument("--mysql-user", default="admin")
    parser.add_argument("--output", default="sql/laboratorio_tenancy.sql")
    args = parser.parse_args()

    namespace = identifier(args.namespace, "namespace")
    lake_bucket = identifier(args.lake_bucket, "bucket Lakehouse")
    rag_bucket = identifier(args.rag_bucket, "bucket RAG")
    if not re.fullmatch(r"[A-Za-z0-9_]+", args.mysql_user):
        parser.error("--mysql-user deve conter apenas letras, números e _")

    sql = SOURCE.read_text(encoding="utf-8")
    old_lake = "oci://lab_lakehouse@idi1o0a010nx/"
    old_rag = "oci://lab_rag@idi1o0a010nx/"
    if old_lake not in sql or old_rag not in sql:
        parser.error("o SQL de origem não contém os URIs esperados")
    sql = sql.replace(old_lake, f"oci://{lake_bucket}@{namespace}/")
    sql = sql.replace(old_rag, f"oci://{rag_bucket}@{namespace}/")
    sql = sql.replace("ML_SCHEMA_admin", f"ML_SCHEMA_{args.mysql_user}")
    sql = sql.replace(
        "USE airportdb;",
        "-- Schema auxiliar para as demonstrações de OLAP.\n"
        "CREATE SCHEMA IF NOT EXISTS workshop_hw26;\n\nUSE airportdb;",
        1,
    )
    sql = (
        "-- Cópia adaptada para tenancy própria. Use o Word para as explicações.\n"
        f"-- Object Storage: {lake_bucket}@{namespace} e {rag_bucket}@{namespace}.\n"
        "-- Os schemas MySQL continuam lab_lakehouse e lab_rag.\n\n"
        + sql
    )
    target = Path(args.output).expanduser().resolve()
    if target == SOURCE.resolve():
        parser.error("o destino não pode sobrescrever sql/laboratorio.sql")
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(sql, encoding="utf-8")
    print(target)


if __name__ == "__main__":
    main()
