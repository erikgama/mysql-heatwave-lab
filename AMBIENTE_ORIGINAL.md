# Executar no ambiente da demonstração

Este caminho corresponde **exatamente ao guia Word**. Ele usa o esquema `airportdb` já preparado, um DB System com cluster HeatWave e os buckets existentes `lab_lakehouse` e `lab_rag`, no compartimento `gama`, região `us-chicago-1`, namespace `idi1o0a010nx`.

1. Abra o [Word](docs/Laboratorio_MySQL_HeatWave.docx) e use o [SQL original](sql/laboratorio.sql) como apoio para copiar os comandos.
2. Confirme na Console OCI que os objetos abaixo estão nos dois buckets. O acesso ao GitHub **não** concede acesso a esses buckets.
3. Siga a ordem do Word: OLAP → Lakehouse → Machine Learning → Vetorização e RAG. Execute cada bloco separadamente e aguarde as operações assíncronas terminarem.

| Arquivo local | Objeto no bucket |
| --- | --- |
| `dados/lakehouse/bank_lab_5col.csv` | `lab_lakehouse/manual/bank.csv` e `lab_lakehouse/automatic/bank.csv` |
| `dados/lakehouse/bank_lab_5col.parquet` | `lab_lakehouse/manual/bank.parquet` e `lab_lakehouse/automatic/bank.parquet` |
| `dados/lakehouse/bank_lab_5col_part_1.csv` | `lab_lakehouse/dynamic/csv/part_1.csv` |
| `dados/lakehouse/bank_lab_5col_part_2.csv` | `lab_lakehouse/dynamic/csv/part_2.csv` |
| `dados/lakehouse/bank_lab_5col_part_1.parquet` | `lab_lakehouse/dynamic/parquet/part_1.parquet` |
| `dados/lakehouse/bank_lab_5col_part_2.parquet` | `lab_lakehouse/dynamic/parquet/part_2.parquet` |
| `dados/rag/guia_campanha_bancaria.txt` | `lab_rag/guia_campanha_bancaria.txt` |

Se os arquivos precisarem ser reenviados **nesse ambiente**, o script [enviar_objetos.sh](scripts/enviar_objetos.sh) usa os nomes fixos da demo:

```bash
bash scripts/enviar_objetos.sh inicio
# Após consultar a primeira parte da carga dinâmica:
bash scripts/enviar_objetos.sh segunda-parte
```

O script não cria buckets, não altera políticas e não remove `part_2` de execuções anteriores. Antes de demonstrar a primeira parte da carga dinâmica, confirme que `dynamic/csv/part_2.csv` e `dynamic/parquet/part_2.parquet` ainda não estão presentes.
