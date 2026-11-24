# Laboratório prático de MySQL HeatWave

Este repositório reúne o guia Word, um roteiro SQL e os arquivos CSV, Parquet e TXT usados nos módulos **OLAP, Lakehouse, Machine Learning e vetorização com RAG**.

## Escolha seu caminho

| Situação | Comece aqui | O que será usado |
| --- | --- | --- |
| Você tem acesso ao ambiente da demonstração | [Executar no ambiente original](AMBIENTE_ORIGINAL.md) | O Word e o SQL originais, com os buckets e o namespace da demo. |
| Você quer reproduzir o laboratório na sua tenancy OCI | [Preparar uma tenancy própria](TENANCY_PROPRIA.md) | Seus DB System, cluster, buckets, namespace e uma cópia do SQL com URIs adaptados. |

O [Word](docs/Laboratorio_MySQL_HeatWave.docx) é o guia principal e permanece **inalterado** nos dois caminhos. Quem usar outra tenancy deve gerar um SQL adaptado, sem editar o Word.

## Material do laboratório

| Arquivo | Uso |
| --- | --- |
| [Guia completo em Word](docs/Laboratorio_MySQL_HeatWave.docx) | Objetivo, sequência, comandos e explicações de cada módulo. |
| [Roteiro SQL original](sql/laboratorio.sql) | Blocos SQL extraídos do Word, prontos para abrir em um cliente MySQL. |
| [Guia de apresentação do RAG](docs/Guia_Campanha_Bancaria.docx) | Perguntas e contexto do documento vetorizado. |
| [Dados Lakehouse](dados/lakehouse) | CSV e Parquet de cinco campos; duas partes para a carga por prefixo. |
| [Documento TXT do RAG](dados/rag/guia_campanha_bancaria.txt) | Conteúdo em português enviado ao Object Storage. |

O SQL original pode ser refeito com `python3 scripts/extrair_sql.py`. Execute os comandos **por bloco e na ordem do Word**; alguns demonstram erros esperados ou removem objetos de prática. Para acompanhar uma carga, abra uma segunda conexão. Mantenha a conexão principal para as variáveis `@` e o relatório do Autopilot.

Os dados Lakehouse derivam da amostra pública [Bank Marketing da UCI](https://archive.ics.uci.edu/dataset/222/bank+marketing). Cada arquivo completo tem 4.521 linhas e os campos `age`, `job`, `marital`, `balance` e `y`. As duas partes têm 2.260 e 2.261 linhas.

## Escopo da publicação

O repositório GitHub é público; **os buckets OCI não são públicos**. O GitHub distribui os arquivos, enquanto cada participante prepara suas próprias permissões e recursos OCI. Não inclua credenciais, chaves privadas, configuração do OCI CLI ou logs de conexão em commits.
