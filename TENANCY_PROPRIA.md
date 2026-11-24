# Reproduzir o laboratório em uma tenancy OCI própria

Este caminho prepara **seus próprios recursos** e conserva o [Word original](docs/Laboratorio_MySQL_HeatWave.docx) como guia de leitura. Use o SQL gerado para sua tenancy ao copiar os comandos que contêm URIs `oci://`. Nenhum comando deste repositório cria políticas IAM ou DB Systems automaticamente.

## 1. Prepare o DB System e o cluster

Na Console OCI, escolha a região e o compartimento de trabalho, uma VCN com subnet adequada e crie um [DB System MySQL HeatWave](https://docs.oracle.com/en-us/iaas/mysql-database/doc/creating-db-system.html). Configure uma versão compatível com os comandos do Word e um shape que aceite HeatWave. Habilite o [cluster HeatWave](https://docs.oracle.com/en-us/iaas/mysql-database/doc/adding-heatwave-cluster.html) e **MySQL HeatWave Lakehouse**. Confira que o DB System e o cluster ficaram ativos antes de importar dados.

Para completar os quatro módulos, confira também os [requisitos de AutoML](https://dev.mysql.com/doc/heatwave/en/mys-hwaml-prereqs.html) e [GenAI](https://dev.mysql.com/doc/heatwave/en/mys-hw-genai-requirements.html) para a versão, shape e número de nós escolhidos. GenAI com `VECTOR_STORE_LOAD` requer Lakehouse habilitado, acesso do DB System ao Object Storage e privilégios da rotina. O guia usa uma conexão MySQL clássica para essa carga vetorial; veja [privilégios de GenAI](https://dev.mysql.com/doc/heatwave/en/mys-hw-genai-privileges.html) e [ingestão do vector store](https://dev.mysql.com/doc/heatwave/en/mys-hw-genai-vector-store-load.html).

Conecte-se ao DB System por VPN ou por uma instância Compute com acesso à rede do banco. Anote o endereço e o usuário administrador **fora do repositório**.

## 2. Importe o AirportDB no MySQL

O repositório não inclui o dump do AirportDB. Baixe o arquivo oficial e importe com MySQL Shell, conforme o [Quickstart AirportDB](https://dev.mysql.com/doc/heatwave/en/mys-hw-airportdb-quickstart.html). O download tem aproximadamente 640 MB.

```bash
curl -LO https://downloads.mysql.com/docs/airport-db.tar.gz
tar -xzf airport-db.tar.gz
export MYSQL_USER='admin'                 # troque pelo usuário do seu DB System
export MYSQL_HOST='SEU_HOST_MYSQL'        # troque pelo endereço acessível do DB System
mysqlsh "${MYSQL_USER}@${MYSQL_HOST}"
```

No prompt do MySQL Shell, selecione JavaScript e carregue a pasta extraída:

```text
\js
util.loadDump("airport-db", {threads: 16, deferTableIndexes: "all", ignoreVersion: true})
```

Confira a importação antes do módulo OLAP:

```sql
SELECT VERSION() AS versao;
SELECT COUNT(*) AS linhas_airline FROM airportdb.airline;
```

## 3. Dê ao DB System acesso aos buckets

Para Lakehouse e para a ingestão vetorial por URI `oci://`, **o DB System**, não apenas o usuário do OCI CLI, precisa ler os objetos. Um administrador da tenancy deve configurar um dynamic group que inclua o DB System e as políticas de leitura dos buckets e objetos no compartimento escolhido. A regra abaixo inclui todos os DB Systems do compartimento informado; ajuste o escopo à sua tenancy:

```text
ALL{resource.type='mysqldbsystem', resource.compartment.id='<ocid-do-compartimento-do-db>'}
```

As políticas de leitura correspondentes seguem o exemplo oficial:

```text
Allow dynamic-group <grupo-do-db-system> to read buckets in compartment <compartimento>
Allow dynamic-group <grupo-do-db-system> to read objects in compartment <compartimento>
```

Adapte o escopo do grupo, o compartimento e, se aplicável, o domínio de identidade. Esse passo é descrito em [Resource Principals do MySQL HeatWave](https://docs.oracle.com/en-us/iaas/mysql-database/doc/resource-principals.html). O script abaixo **não altera IAM**. Para um usuário MySQL diferente do administrador, confira também os [privilégios de GenAI](https://dev.mysql.com/doc/heatwave/en/mys-hw-genai-privileges.html).

## 4. Crie buckets privados e envie os arquivos

Instale e configure o [OCI CLI](https://docs.oracle.com/en-us/iaas/Content/API/SDKDocs/cliinstall.htm). Sua identidade OCI precisa poder criar buckets no compartimento e enviar objetos. Na raiz deste repositório, informe sua região e o OCID do compartimento:

```bash
export OCI_REGION='us-chicago-1'                   # troque pela sua região
export OCI_COMPARTMENT_OCID='ocid1.compartment...' # troque pelo seu OCID
export OCI_PROFILE='DEFAULT'                       # opcional; seu perfil do OCI CLI

# Opcional: use outros nomes se já houver buckets com os nomes padrão.
export LAKE_BUCKET='lab_lakehouse'
export RAG_BUCKET='lab_rag'

oci os ns get --region "$OCI_REGION" --query data --raw-output
bash scripts/tenancy_propria.sh criar-buckets
bash scripts/tenancy_propria.sh inicio
bash scripts/tenancy_propria.sh verificar
```

O script obtém **o namespace da sua tenancy**, cria buckets `NoPublicAccess` se não existirem e envia os arquivos iniciais. Os destinos são `manual/`, `automatic/`, `dynamic/csv/part_1.csv`, `dynamic/parquet/part_1.parquet` e o TXT do RAG. Ele não apaga objetos existentes. O formato de criação do bucket e upload segue a [referência OCI para buckets](https://docs.oracle.com/en-us/iaas/tools/oci-cli/latest/oci_cli_docs/cmdref/os/bucket/create.html) e [objetos](https://docs.oracle.com/en-us/iaas/tools/oci-cli/latest/oci_cli_docs/cmdref/os/object/put.html).

**Guarde a segunda parte da carga dinâmica para o momento indicado no Word.** Depois de carregar e consultar a primeira parte, execute:

```bash
bash scripts/tenancy_propria.sh segunda-parte
bash scripts/tenancy_propria.sh verificar
```

Se `part_2` já existir nos prefixos `dynamic/` de uma tentativa anterior, remova esses objetos antes de começar a demonstração da primeira parte; o script não os remove.

## 5. Gere o SQL da sua tenancy

Obtenha o namespace retornado por `oci os ns get` e gere **uma nova cópia local** do roteiro. O Word e o SQL original não são alterados:

```bash
export OCI_NAMESPACE="$(oci os ns get --region "$OCI_REGION" --query data --raw-output)"

python3 scripts/gerar_sql_tenancy.py \
  --namespace "$OCI_NAMESPACE" \
  --lake-bucket "$LAKE_BUCKET" \
  --rag-bucket "$RAG_BUCKET" \
  --mysql-user admin
```

O resultado fica em `sql/laboratorio_tenancy.sql`. O gerador troca os URIs dos dois buckets e o catálogo `ML_SCHEMA_<usuario>`, além de criar o schema auxiliar `workshop_hw26` usado nos exemplos OLAP. Os schemas MySQL `lab_lakehouse` e `lab_rag` continuam com esses nomes; os **nomes dos buckets podem ser diferentes**. Se seu usuário MySQL não for `admin`, informe-o em `--mysql-user`.

Abra o SQL gerado no MySQL Workbench, DBeaver ou outro cliente MySQL e siga o [Word](docs/Laboratorio_MySQL_HeatWave.docx), executando um bloco por vez. Use a mesma conexão para variáveis `@` e relatórios de sessão. Aguarde a carga do AirportDB, o treino do modelo e a vetorização terminarem antes de passar aos comandos seguintes.

## 6. Confira as etapas

- **OLAP:** as tabelas do `airportdb` aparecem em `performance_schema.rpd_tables` com o estado esperado após a carga.
- **Lakehouse:** as tabelas CSV e Parquet retornam as mesmas contagens e agregações no roteiro SQL.
- **Machine Learning:** o modelo treinado aparece no catálogo do usuário MySQL; as previsões por linha e em lote são consultáveis.
- **Vetorização:** a tarefa chega a `COMPLETED`, a tabela `lab_rag.guia_campanha_vetores` tem segmentos e o RAG responde usando esse vector store.

Se uma etapa não funcionar, confira primeiro versão e recursos habilitados, conectividade do DB System, localização dos objetos e permissões do principal de recurso. O [guia HeatWave](https://dev.mysql.com/doc/heatwave/en/) explica as rotinas; este caminho de tenancy própria é uma preparação reproduzível, **não um teste executado em todos os ambientes possíveis**.
