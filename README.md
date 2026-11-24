# Laboratório prático de MySQL HeatWave

Material para executar os módulos de cluster analítico, Lakehouse, Machine Learning e vetorização com RAG. Comece pelo [guia completo em Word](docs/Laboratorio_MySQL_HeatWave.docx). O [roteiro SQL](sql/laboratorio.sql) reúne os comandos do mesmo guia para abrir no MySQL Workbench, DBeaver ou outro cliente MySQL.

## Comece por aqui

1. Abra o Word e siga os módulos na ordem: **OLAP → Lakehouse → Machine Learning → Vetorização e RAG**.
2. Execute cada bloco SQL separadamente. Aguarde as cargas e o treinamento terminarem antes de avançar. Algumas chamadas são demonstrações de erro esperado; leia a explicação no Word antes de executá-las.
3. Para acompanhar uma carga em andamento, use outra conexão SQL. Mantenha a conexão principal para as variáveis `@` e o relatório do Autopilot.
4. Confira os arquivos dos buckets na Console OCI, região `us-chicago-1`, compartimento `gama`. Use [os comandos de envio](#arquivos-do-object-storage) se for preparar um novo ambiente.

O ambiente precisa de um DB System MySQL HeatWave com cluster analítico, o esquema `airportdb` com dados, recursos de AutoML e GenAI habilitados para os módulos correspondentes, e acesso aos buckets `lab_lakehouse` e `lab_rag`. O guia mostra as consultas de cada etapa.

## Arquivos

| Caminho | Finalidade |
| --- | --- |
| [docs/Laboratorio_MySQL_HeatWave.docx](docs/Laboratorio_MySQL_HeatWave.docx) | Guia principal, com contexto, comandos e explicações. |
| [sql/laboratorio.sql](sql/laboratorio.sql) | Comandos SQL extraídos da versão do Word acima, na mesma sequência. |
| [docs/Guia_Campanha_Bancaria.docx](docs/Guia_Campanha_Bancaria.docx) | Apoio para apresentar o conteúdo consultado pelo RAG. |
| [dados/lakehouse](dados/lakehouse) | CSV e Parquet de cinco colunas, incluindo duas partes para carga por prefixo. |
| [dados/rag/guia_campanha_bancaria.txt](dados/rag/guia_campanha_bancaria.txt) | Documento em português enviado ao bucket e vetorizado. |

O roteiro SQL é gerado diretamente do Word por `python3 scripts/extrair_sql.py`. Os blocos de OCI CLI ficam fora do `.sql` porque devem rodar no terminal. A assinatura ilustrativa de `HEATWAVE_LOAD` permanece comentada para não ser executada por engano.

## Arquivos do Object Storage

Os dois buckets usam o namespace `idi1o0a010nx`. Confira a existência dos buckets e os objetos na Console OCI antes do laboratório. O script [enviar_objetos.sh](scripts/enviar_objetos.sh) usa a configuração local do OCI CLI; ele não cria buckets nem altera políticas.

| Arquivo no repositório | Bucket e nome do objeto |
| --- | --- |
| `dados/lakehouse/bank_lab_5col.csv` | `lab_lakehouse/manual/bank.csv` e `lab_lakehouse/automatic/bank.csv` |
| `dados/lakehouse/bank_lab_5col.parquet` | `lab_lakehouse/manual/bank.parquet` e `lab_lakehouse/automatic/bank.parquet` |
| `dados/lakehouse/bank_lab_5col_part_1.csv` | `lab_lakehouse/dynamic/csv/part_1.csv` |
| `dados/lakehouse/bank_lab_5col_part_2.csv` | `lab_lakehouse/dynamic/csv/part_2.csv` |
| `dados/lakehouse/bank_lab_5col_part_1.parquet` | `lab_lakehouse/dynamic/parquet/part_1.parquet` |
| `dados/lakehouse/bank_lab_5col_part_2.parquet` | `lab_lakehouse/dynamic/parquet/part_2.parquet` |
| `dados/rag/guia_campanha_bancaria.txt` | `lab_rag/guia_campanha_bancaria.txt` |

```bash
# Na raiz do repositório: envie os arquivos iniciais.
bash scripts/enviar_objetos.sh inicio

# Após carregar a primeira parte dinâmica e verificar o resultado:
bash scripts/enviar_objetos.sh segunda-parte
```

Se `part_2.csv` ou `part_2.parquet` já estiver no prefixo `dynamic/` de uma execução anterior, remova esses objetos antes de iniciar a demonstração da primeira parte. O script não remove objetos automaticamente.

Os CSV e Parquet do exercício Lakehouse contêm **4.521 linhas** e os campos `age`, `job`, `marital`, `balance` e `y`. A primeira parte tem 2.260 linhas e a segunda, 2.261. Os arquivos derivam da amostra pública [Bank Marketing da UCI](https://archive.ics.uci.edu/dataset/222/bank+marketing); os dados originais e os campos têm sua descrição nessa página.

## Segurança e escopo

Este repositório é **privado** e contém material marcado como interno no Word. Não inclua senha, chave privada, arquivo `.oci/config`, token ou log de conexão em commits. Os nomes de buckets e recursos são específicos deste ambiente; ao repetir o laboratório em outro tenancy, ajuste os URIs e pré-requisitos descritos no guia.
