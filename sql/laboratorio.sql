-- LABORATÓRIO MYSQL HEATWAVE | roteiro extraído do guia Word
-- Execute os blocos na ordem, aguardando o término das cargas e do treino.
-- Os comandos OCI CLI e os arquivos do Object Storage estão no README.
-- Mantenha a mesma conexão para variáveis @ e relatórios da sessão.

-- ========================================================================
-- 1.1 Ambiente e verificação inicial
-- ========================================================================

-- SQL OLAP-01 Confirmar servidor e opções da sessão
-- Seleciona airportdb e identifica a versão do servidor.
USE airportdb;

SELECT VERSION() AS versao, @@version_comment AS edicao;

SHOW VARIABLES LIKE 'use_secondary_engine';

SHOW GLOBAL STATUS LIKE 'rapid_ml_status';

SHOW GLOBAL STATUS LIKE 'rapid_lakehouse_health';

SHOW GLOBAL VARIABLES LIKE 'rapid_auto_vector_index_enabled';

-- SQL OLAP-02 Confirmar tabelas e cluster
-- Lista tabelas e nós.
SELECT table_name, engine, table_rows
FROM information_schema.tables
WHERE table_schema = 'airportdb'
ORDER BY table_name;

SELECT id, status, ml_status, cores,
       ROUND(memory_usage/1024/1024/1024,2) AS usado_gib,
       ROUND(memory_total/1024/1024/1024,2) AS total_gib
FROM performance_schema.rpd_nodes;

-- ========================================================================
-- 1.2 Onde estão os dados e os metadados
-- ========================================================================

-- SQL OLAP-03 Inventário completo do airportdb, inclusive tabelas fora do RAPID
-- Cruza todas as tabelas InnoDB com o inventário RAPID, inclusive as não carregadas.
SELECT b.table_name, b.engine, b.create_options,
       r.load_status, r.load_progress, r.nrows
FROM information_schema.tables AS b
LEFT JOIN performance_schema.rpd_table_id AS i
  ON i.schema_name = b.table_schema
 AND i.table_name = b.table_name
LEFT JOIN performance_schema.rpd_tables AS r ON r.id = i.id
WHERE b.table_schema = 'airportdb'
  AND b.table_type = 'BASE TABLE'
ORDER BY b.table_name;

-- SQL OLAP-04 Estado detalhado e capacidade do cluster
-- Detalha tabelas RAPID e memória dos nós.
SELECT i.table_name, r.load_status, r.load_progress,
       r.nrows, ROUND(r.size_bytes/1024/1024,1) AS mib,
       r.load_type, r.query_count, r.load_end_timestamp,
       r.stale_reason
FROM performance_schema.rpd_table_id AS i
JOIN performance_schema.rpd_tables AS r USING (id)
WHERE i.schema_name = 'airportdb'
ORDER BY i.table_name;

SELECT id, status, ml_status, cores,
       ROUND(memory_usage/1024/1024/1024,2) AS usado_gib,
       ROUND(memory_total/1024/1024/1024,2) AS total_gib
FROM performance_schema.rpd_nodes;

-- ========================================================================
-- 1.3 Entender os parâmetros de HEATWAVE_LOAD
-- ========================================================================

-- Assinatura de HEATWAVE_LOAD — referência, não execute
-- Mostra a assinatura da rotina, sem executá-la: input_list é um JSON_ARRAY que pode
-- escolher esquema, tabelas ou colunas; options é NULL ou JSON_OBJECT com as opções
-- desejadas.
-- CALL sys.HEATWAVE_LOAD(input_list, options);

-- ========================================================================
-- 1.4 Carregar airportdb e verificar o resultado
-- ========================================================================

-- SQL OLAP-05 Dry run e relatório, na mesma sessão SQL
-- Faz o dry run sem carregar dados e lê seu relatório na mesma conexão.
CALL sys.HEATWAVE_LOAD(
  JSON_ARRAY('airportdb'),
  JSON_OBJECT('mode','dryrun','output','normal')
);

SELECT id, stage, type, log
FROM sys.heatwave_autopilot_report
ORDER BY id;

-- SQL OLAP-06 Carregar todas as tabelas pendentes de airportdb
-- Carrega tabelas elegíveis pendentes de airportdb quando ainda não estiverem
-- disponíveis; booking pode demorar.
CALL sys.HEATWAVE_LOAD(
  JSON_ARRAY('airportdb'),
  JSON_OBJECT('mode','normal','output','normal')
);

SELECT id, stage, type, log
FROM sys.heatwave_autopilot_report
ORDER BY id;

-- SQL OLAP-07 Verificar todas as tabelas na memória do cluster
-- Mostra todas as tabelas do esquema.
SELECT b.table_name,
       COALESCE(r.load_status, 'SEM_ENTRADA_RAPID') AS estado,
       r.load_progress,
       r.nrows,
       ROUND(r.size_bytes / 1024 / 1024, 1) AS mib,
       r.load_end_timestamp
FROM information_schema.tables AS b
LEFT JOIN performance_schema.rpd_table_id AS i
  ON i.schema_name = b.table_schema
 AND i.table_name = b.table_name
LEFT JOIN performance_schema.rpd_tables AS r
  ON r.id = i.id
WHERE b.table_schema = 'airportdb'
  AND b.table_type = 'BASE TABLE'
ORDER BY r.load_progress, b.table_name;

-- ========================================================================
-- 1.5 Comparar consultas transacionais e analíticas
-- ========================================================================

-- SQL OLAP-08 Executar a agregação mensal no InnoDB
-- Agrega weatherdata por mês no InnoDB.
EXPLAIN SELECT /*+ SET_VAR(use_secondary_engine = OFF) */
       YEAR(log_date) AS ano,
       MONTH(log_date) AS mes,
       ROUND(AVG(temp), 2) AS temperatura_media,
       ROUND(AVG(humidity), 2) AS umidade_media
FROM airportdb.weatherdata
GROUP BY ano, mes
ORDER BY ano, mes
LIMIT 12;

SELECT /*+ SET_VAR(use_secondary_engine = OFF) */
       YEAR(log_date) AS ano,
       MONTH(log_date) AS mes,
       ROUND(AVG(temp), 2) AS temperatura_media,
       ROUND(AVG(humidity), 2) AS umidade_media
FROM airportdb.weatherdata
GROUP BY ano, mes
ORDER BY ano, mes
LIMIT 12;

-- SQL OLAP-09 Executar a mesma agregação no cluster analítico
-- Executa a mesma agregação exigindo RAPID; confirme Using secondary engine RAPID no
-- EXPLAIN.
EXPLAIN SELECT /*+ SET_VAR(use_secondary_engine = FORCED) */
       YEAR(log_date) AS ano,
       MONTH(log_date) AS mes,
       ROUND(AVG(temp), 2) AS temperatura_media,
       ROUND(AVG(humidity), 2) AS umidade_media
FROM airportdb.weatherdata
GROUP BY ano, mes
ORDER BY ano, mes
LIMIT 12;

SELECT /*+ SET_VAR(use_secondary_engine = FORCED) */
       YEAR(log_date) AS ano,
       MONTH(log_date) AS mes,
       ROUND(AVG(temp), 2) AS temperatura_media,
       ROUND(AVG(humidity), 2) AS umidade_media
FROM airportdb.weatherdata
GROUP BY ano, mes
ORDER BY ano, mes
LIMIT 12;

-- SQL OLAP-10 Observar a escolha automática com ON
-- Repete a agregação com ON, deixando o otimizador escolher o mecanismo.
EXPLAIN SELECT /*+ SET_VAR(use_secondary_engine = ON) */
       YEAR(log_date) AS ano,
       MONTH(log_date) AS mes,
       ROUND(AVG(temp), 2) AS temperatura_media,
       ROUND(AVG(humidity), 2) AS umidade_media
FROM airportdb.weatherdata
GROUP BY ano, mes
ORDER BY ano, mes
LIMIT 12;

SELECT /*+ SET_VAR(use_secondary_engine = ON) */
       YEAR(log_date) AS ano,
       MONTH(log_date) AS mes,
       ROUND(AVG(temp), 2) AS temperatura_media,
       ROUND(AVG(humidity), 2) AS umidade_media
FROM airportdb.weatherdata
GROUP BY ano, mes
ORDER BY ano, mes
LIMIT 12;

-- SQL OLAP-11 Busca de uma reserva pela chave no InnoDB
-- Busca uma reserva por booking_id no InnoDB, caso típico de acesso pontual por índice.
SET SESSION use_secondary_engine=OFF;

EXPLAIN SELECT booking_id, flight_id, passenger_id, price
FROM airportdb.booking WHERE booking_id=1000;

SELECT booking_id, flight_id, passenger_id, price
FROM airportdb.booking WHERE booking_id=1000;

SET SESSION use_secondary_engine=ON;

-- SQL OLAP-12 Agregação grande no RAPID e no InnoDB
-- Compara a mesma agregação de booking em RAPID e InnoDB.
SET SESSION use_secondary_engine=FORCED;

EXPLAIN SELECT flight_id, COUNT(*) AS bookings,
       ROUND(AVG(price),2) AS avg_price
FROM airportdb.booking
WHERE booking_id BETWEEN 1 AND 5000000
GROUP BY flight_id ORDER BY bookings DESC, flight_id LIMIT 10;

SELECT flight_id, COUNT(*) AS bookings,
       ROUND(AVG(price),2) AS avg_price
FROM airportdb.booking
WHERE booking_id BETWEEN 1 AND 5000000
GROUP BY flight_id ORDER BY bookings DESC, flight_id LIMIT 10;

SET SESSION use_secondary_engine=OFF;

SELECT flight_id, COUNT(*) AS bookings,
       ROUND(AVG(price),2) AS avg_price
FROM airportdb.booking
WHERE booking_id BETWEEN 1 AND 5000000
GROUP BY flight_id ORDER BY bookings DESC, flight_id LIMIT 10;

SET SESSION use_secondary_engine=ON;

-- ========================================================================
-- 1.6 Acompanhar a carga e confirmar o resultado
-- ========================================================================

-- SQL OLAP-13 Progresso global da carga
-- Mostra rapid_load_progress como progresso global.
SELECT variable_value AS progresso_global_pct
FROM performance_schema.global_status
WHERE variable_name = 'rapid_load_progress';

-- SQL OLAP-14 Relatório resumido da última chamada automática
-- Resume e detalha o último HEATWAVE_LOAD/UNLOAD desta conexão: stage é a fase, type a
-- categoria e log o conteúdo.
SELECT stage, type, COUNT(*) AS mensagens
FROM sys.heatwave_autopilot_report
GROUP BY stage, type
ORDER BY stage, type;

SELECT id, stage, type, log
FROM sys.heatwave_autopilot_report
WHERE type IN ('error','warn','sql')
ORDER BY id;

-- ========================================================================
-- 1.7 Uma tabela completa: descarregar, carregar e conferir
-- ========================================================================

-- SQL OLAP-15 Descarregar apenas airline e ler o relatório
-- Descarrega apenas airline do RAPID; db_name/tables limitam o alvo e mode=normal
-- executa.
CALL sys.HEATWAVE_UNLOAD(
  JSON_ARRAY(JSON_OBJECT(
    'db_name','airportdb',
    'tables',JSON_ARRAY('airline')
  )),
  JSON_OBJECT('mode','normal','output','normal')
);

SELECT id, stage, type, log
FROM sys.heatwave_autopilot_report
ORDER BY id;

-- SQL OLAP-16 Carregar somente airline e ler o relatório
-- Recarrega somente airline; db_name/tables definem o alvo e mode=normal executa.
CALL sys.HEATWAVE_LOAD(
  JSON_ARRAY(JSON_OBJECT(
    'db_name','airportdb',
    'tables',JSON_ARRAY('airline')
  )),
  JSON_OBJECT('mode','normal','output','normal')
);

SELECT id, stage, type, log
FROM sys.heatwave_autopilot_report
ORDER BY id;

-- ========================================================================
-- 1.8 O mesmo ciclo com ALTER TABLE e recarga individual
-- ========================================================================

-- SQL OLAP-17 Descarregar airline com ALTER TABLE
-- Descarrega airline com SECONDARY_UNLOAD sem apagar as linhas InnoDB.
ALTER TABLE airportdb.airline SECONDARY_UNLOAD;

SHOW WARNINGS;

-- SQL OLAP-18 Conferir a definição depois da descarga
-- Lê create_options após a descarga para saber se airline ainda tem
-- SECONDARY_ENGINE=RAPID.
SELECT table_name, create_options
FROM information_schema.tables
WHERE table_schema='airportdb' AND table_name='airline';

-- SQL OLAP-19 Definir RAPID se a opção estiver ausente
-- Define RAPID como mecanismo secundário de airline somente se create_options não o
-- mostrar.
ALTER TABLE airportdb.airline SECONDARY_ENGINE=RAPID;

SHOW WARNINGS;

-- SQL OLAP-20 Recarregar airline com ALTER TABLE
-- Recarrega somente airline com SECONDARY_LOAD após SECONDARY_UNLOAD;
-- HEATWAVE_RELOAD(NULL) tem escopo global.
ALTER TABLE airportdb.airline SECONDARY_LOAD;

SHOW WARNINGS;

SELECT i.table_name, r.load_status, r.load_progress, r.nrows
FROM performance_schema.rpd_table_id AS i
JOIN performance_schema.rpd_tables AS r USING (id)
WHERE i.schema_name='airportdb' AND i.table_name='airline';

-- ========================================================================
-- 1.9 Carregar somente algumas colunas e restaurar a tabela
-- ========================================================================

-- SQL OLAP-21 Descarregar airline antes de mudar a seleção
-- Descarrega airline antes de mudar as colunas incluídas no RAPID.
ALTER TABLE airportdb.airline SECONDARY_UNLOAD;

SHOW WARNINGS;

-- SQL OLAP-22 Carregar três colunas de airline
-- Carrega apenas airline_id, iata e base_airport no RAPID.
CALL sys.HEATWAVE_LOAD(
  JSON_ARRAY(JSON_OBJECT(
    'db_name','airportdb',
    'tables',JSON_ARRAY(JSON_OBJECT(
      'table_name','airline',
      'columns',JSON_ARRAY('airline_id','iata','base_airport')
    ))
  )),
  JSON_OBJECT('mode','normal','output','normal')
);

SELECT id, stage, type, log
FROM sys.heatwave_autopilot_report
ORDER BY id;

-- SQL OLAP-23 Confirmar as colunas selecionadas e a carga
-- Mostra quais colunas de airline entraram no RAPID: SIM para airline_id, iata e
-- base_airport; NAO para airlinename marcada NOT SECONDARY.
SELECT column_name AS coluna,
       CASE
         WHEN extra LIKE '%NOT SECONDARY%' THEN 'NAO'
         ELSE 'SIM'
       END AS incluida_na_carga_heatwave
FROM information_schema.columns
WHERE table_schema='airportdb' AND table_name='airline'
ORDER BY ordinal_position;

SELECT i.table_name, r.load_status, r.load_progress, r.nrows
FROM performance_schema.rpd_table_id AS i
JOIN performance_schema.rpd_tables AS r USING (id)
WHERE i.schema_name='airportdb' AND i.table_name='airline';

-- SQL OLAP-24 Conferir o plano no RAPID
-- Força o plano da agregação por iata no RAPID e restaura ON.
SET SESSION use_secondary_engine=FORCED;

EXPLAIN SELECT iata, COUNT(*) AS total
FROM airportdb.airline GROUP BY iata;

SET SESSION use_secondary_engine=ON;

-- SQL OLAP-25 Restaurar airlinename e as quatro colunas
-- Descarrega airline, retira NOT SECONDARY de airlinename e recarrega as quatro
-- colunas.
ALTER TABLE airportdb.airline SECONDARY_UNLOAD;

SHOW WARNINGS;

ALTER TABLE airportdb.airline
  MODIFY airlinename VARCHAR(30) CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci DEFAULT NULL;

SHOW WARNINGS;

ALTER TABLE airportdb.airline SECONDARY_LOAD;

SHOW WARNINGS;

-- ========================================================================
-- 1.10 Tabelas e colunas que não entram na memória
-- ========================================================================

-- SQL OLAP-26 Conferir mecanismo e chave primária das tabelas
-- Faz uma triagem de carga: engine mostra InnoDB e tem_pk indica chave primária.
SELECT t.table_name, t.engine,
       CASE WHEN EXISTS (
         SELECT 1 FROM information_schema.table_constraints AS k
         WHERE k.table_schema=t.table_schema
           AND k.table_name=t.table_name
           AND k.constraint_type='PRIMARY KEY'
       ) THEN 'SIM' ELSE 'NAO' END AS tem_pk
FROM information_schema.tables AS t
WHERE t.table_schema='airportdb'
  AND t.table_type='BASE TABLE'
ORDER BY t.table_name;

-- SQL OLAP-27 Encontrar colunas que pedem revisão
-- Lista colunas que pedem avaliação: table_name/column_name identificam o campo,
-- column_type mostra o tipo e extra pode indicar NOT SECONDARY.
SELECT table_name, column_name, column_type, extra
FROM information_schema.columns
WHERE table_schema='airportdb'
  AND data_type IN (
    'tinyblob','blob','mediumblob','longblob','varbinary',
    'bit','set','geometry','point','linestring','polygon',
    'multipoint','multilinestring','multipolygon',
    'geometrycollection'
  )
ORDER BY table_name, ordinal_position;

-- SQL OLAP-28 Criar e preencher a tabela de prática
-- Cria a tabela de prática com chave id, texto categoria e coluna espacial POINT;
-- insere duas linhas.
CREATE TABLE IF NOT EXISTS workshop_hw26.unsupported_demo_pratica (
  id INT PRIMARY KEY,
  categoria VARCHAR(20) NOT NULL,
  geolocalizacao POINT NOT NULL
) ENGINE=InnoDB;

INSERT IGNORE INTO workshop_hw26.unsupported_demo_pratica
  (id, categoria, geolocalizacao)
VALUES
  (1, 'A', ST_GeomFromText('POINT(1 1)')),
  (2, 'B', ST_GeomFromText('POINT(2 2)'));

-- SQL OLAP-29 Reiniciar somente se a tabela já estiver carregada
-- Use apenas ao repetir a prática: SECONDARY_UNLOAD retira a tabela do RAPID e MODIFY
-- remove NOT SECONDARY da coluna espacial.
ALTER TABLE workshop_hw26.unsupported_demo_pratica SECONDARY_UNLOAD;

ALTER TABLE workshop_hw26.unsupported_demo_pratica
  MODIFY geolocalizacao POINT NOT NULL;

-- SQL OLAP-30 Guided Load exclui POINT e carrega o restante
-- Executa Guided Load, padrão desde MySQL 8.2.0: marca a coluna POINT incompatível como
-- NOT SECONDARY e carrega as demais.
ALTER TABLE workshop_hw26.unsupported_demo_pratica SECONDARY_LOAD;

SHOW WARNINGS;

-- SQL OLAP-31 Conferir a coluna excluída e o estado final
-- Confere o resultado do Guided Load: extra deve marcar geolocalizacao como NOT
-- SECONDARY; load_status deve ser AVAIL_RPDGSTABSTATE, load_progress 100 e nrows 2.
SELECT c.column_name, c.column_type, c.extra,
       r.load_status, r.load_progress, r.nrows
FROM information_schema.columns AS c
LEFT JOIN performance_schema.rpd_table_id AS i
  ON i.schema_name=c.table_schema AND i.table_name=c.table_name
LEFT JOIN performance_schema.rpd_tables AS r ON r.id=i.id
WHERE c.table_schema='workshop_hw26'
  AND c.table_name='unsupported_demo_pratica'
ORDER BY c.ordinal_position;

-- SQL OLAP-32 Preparar a comparação das políticas
-- Descarrega a tabela de prática e retira NOT SECONDARY da coluna espacial para
-- comparar políticas de dry run.
ALTER TABLE workshop_hw26.unsupported_demo_pratica SECONDARY_UNLOAD;

ALTER TABLE workshop_hw26.unsupported_demo_pratica
  MODIFY geolocalizacao POINT NOT NULL;

-- SQL OLAP-33 Política padrão mantém a tabela no plano
-- Planeja sem carregar com a política padrão: a coluna POINT tende a ser marcada NOT
-- SECONDARY e a tabela permanece no plano.
CALL sys.HEATWAVE_LOAD(
  JSON_ARRAY(JSON_OBJECT(
    'db_name','workshop_hw26',
    'tables',JSON_ARRAY('unsupported_demo_pratica')
  )),
  JSON_OBJECT('mode','dryrun','output','normal')
);

SELECT stage, type, log
FROM sys.heatwave_autopilot_report
WHERE type IN ('error','warn','sql')
ORDER BY id;

-- SQL OLAP-34 Política alternativa exclui a tabela do plano
-- Compara a política not_disable_unsupported_columns em dry run: com POINT ainda
-- incompatível, ela deve excluir a tabela do plano.
CALL sys.HEATWAVE_LOAD(
  JSON_ARRAY(JSON_OBJECT(
    'db_name','workshop_hw26',
    'tables',JSON_ARRAY('unsupported_demo_pratica')
  )),
  JSON_OBJECT('mode','dryrun',
              'policy','not_disable_unsupported_columns',
              'output','normal')
);

SELECT stage, type, log
FROM sys.heatwave_autopilot_report
WHERE type IN ('error','warn','sql')
ORDER BY id;

-- SQL OLAP-35 Falha esperada sem a preparação automática
-- Desliga Guided Load e tenta carregar a coluna POINT, produzindo erro esperado de
-- incompatibilidade (possivelmente 3877).
ALTER TABLE workshop_hw26.unsupported_demo_pratica
  SECONDARY_LOAD GUIDED OFF;

-- SQL OLAP-36 Excluir manualmente POINT e carregar
-- Marca geolocalizacao como NOT SECONDARY e carrega as colunas compatíveis.
ALTER TABLE workshop_hw26.unsupported_demo_pratica
  MODIFY geolocalizacao POINT NOT NULL NOT SECONDARY;

ALTER TABLE workshop_hw26.unsupported_demo_pratica
  SECONDARY_LOAD GUIDED OFF;

SHOW WARNINGS;

-- SQL OLAP-37 Confirmar o resultado manual
-- Confirma a carga manual: load_status deve indicar AVAIL_RPDGSTABSTATE, load_progress
-- 100 e nrows 2.
SELECT i.table_name, r.load_status, r.load_progress, r.nrows
FROM performance_schema.rpd_table_id AS i
JOIN performance_schema.rpd_tables AS r USING (id)
WHERE i.schema_name='workshop_hw26'
  AND i.table_name='unsupported_demo_pratica';

-- ========================================================================
-- 1.11 Selecionar várias tabelas e configurar HEATWAVE_LOAD
-- ========================================================================

-- SQL OLAP-38 Dry run de três tabelas relacionadas
-- Faz dry run somente de airline, airport e flight; tables limita os alvos e
-- stage/type/log detalham o plano.
CALL sys.HEATWAVE_LOAD(
  JSON_ARRAY(JSON_OBJECT(
    'db_name','airportdb',
    'tables',JSON_ARRAY('airline','airport','flight')
  )),
  JSON_OBJECT('mode','dryrun','output','normal')
);

SELECT id, stage, type, log
FROM sys.heatwave_autopilot_report
ORDER BY id;

-- SQL OLAP-39 Carregar as três tabelas selecionadas
-- Carrega apenas airline, airport e flight quando houver pendências.
CALL sys.HEATWAVE_LOAD(
  JSON_ARRAY(JSON_OBJECT(
    'db_name','airportdb',
    'tables',JSON_ARRAY('airline','airport','flight')
  )),
  JSON_OBJECT('mode','normal','output','normal')
);

SELECT id, stage, type, log
FROM sys.heatwave_autopilot_report
ORDER BY id;

-- SQL OLAP-40 Excluir duas tabelas de um dry run de esquema
-- Planeja a carga do esquema excluindo flight_log e airport_reachable via
-- exclude_tables.
CALL sys.HEATWAVE_LOAD(
  JSON_ARRAY(JSON_OBJECT(
    'db_name','airportdb',
    'exclude_tables',JSON_ARRAY('flight_log','airport_reachable')
  )),
  JSON_OBJECT('mode','dryrun','output','normal')
);

SELECT id, stage, type, log
FROM sys.heatwave_autopilot_report
ORDER BY id;

-- SQL OLAP-41 Ajuda instalada no próprio servidor
-- Pede ao servidor a sintaxe de HEATWAVE_LOAD reconhecida nesta versão, usando
-- output=help.
CALL sys.HEATWAVE_LOAD(
  JSON_ARRAY(),
  JSON_OBJECT('output','help')
);

-- SQL OLAP-42 Sintaxe da recarga global, somente referência
-- Mostra HEATWAVE_RELOAD(NULL) como referência: ela aceita opções globais, sem filtro
-- por tabela, e pode recarregar todas as tabelas do usuário no DB System.
-- CALL sys.HEATWAVE_RELOAD(NULL);

-- ========================================================================
-- 1.12 Propagação de mudanças após a carga
-- ========================================================================

-- SQL OLAP-43 Recriar uma tabela pequena e inserir linhas
-- Recria somente a tabela de prática e insere três linhas com id, category e amount.
DROP TABLE IF EXISTS workshop_hw26.change_demo_pratica;

CREATE TABLE workshop_hw26.change_demo_pratica (
  id INT PRIMARY KEY,
  category VARCHAR(20) NOT NULL,
  amount DECIMAL(10,2) NOT NULL
) ENGINE=InnoDB;

INSERT INTO workshop_hw26.change_demo_pratica
  (id, category, amount)
VALUES (1,'A',10.00), (2,'A',15.00), (3,'B',30.00);

-- SQL OLAP-44 Definir RAPID e carregar a tabela pequena
-- Configura RAPID e carrega a tabela pequena.
ALTER TABLE workshop_hw26.change_demo_pratica SECONDARY_ENGINE=RAPID;

ALTER TABLE workshop_hw26.change_demo_pratica SECONDARY_LOAD;

SHOW WARNINGS;

-- SQL OLAP-45 Alterar no InnoDB e ler no RAPID
-- Insere mais 20,00 na categoria A, força RAPID para a soma e restaura ON.
INSERT IGNORE INTO workshop_hw26.change_demo_pratica
  (id, category, amount) VALUES (4,'A',20.00);

SET SESSION use_secondary_engine=FORCED;

EXPLAIN SELECT category, SUM(amount) AS total
FROM workshop_hw26.change_demo_pratica GROUP BY category;

SELECT category, SUM(amount) AS total
FROM workshop_hw26.change_demo_pratica GROUP BY category;

SET SESSION use_secondary_engine=ON;

-- ========================================================================
-- 1.13 Consultar o Advisor
-- ========================================================================

-- SQL OLAP-46 Recomendações e insights sem aplicar DDL
-- Pede insights do Advisor sobre airportdb sem aplicar DDL.
CALL sys.HEATWAVE_ADVISOR(
  JSON_OBJECT('target_schema',JSON_ARRAY('airportdb'),
              'query_insights',true,
              'output','normal')
);

SELECT id, stage, type, log
FROM sys.heatwave_autopilot_report
WHERE type IN ('error','warn','sql')
ORDER BY id LIMIT 100;

-- ========================================================================
-- 1.14 Limitações de consultas OLAP e diagnóstico de offload
-- ========================================================================

-- SQL OLAP-47 Conferir sessão e plano da consulta direta
-- Mostra versão, autocommit e política de offload da sessão; o EXPLAIN revela o
-- mecanismo da consulta direta agrupada por flight_id.
SELECT VERSION() AS version,
       @@autocommit AS autocommit,
       @@use_secondary_engine AS use_secondary_engine;

EXPLAIN FORMAT=TRADITIONAL
SELECT flight_id, COUNT(*) AS bookings
FROM airportdb.booking
WHERE booking_id BETWEEN 1 AND 5000000
GROUP BY flight_id ORDER BY bookings DESC, flight_id LIMIT 10;

-- SQL OLAP-48 Criar e executar a procedure de comparação
-- Recria somente a procedure de prática e executa sua consulta agrupada por flight_id.
DROP PROCEDURE IF EXISTS workshop_hw26.olap_offload_proc_airportdb;

CREATE PROCEDURE
  workshop_hw26.olap_offload_proc_airportdb()
SELECT flight_id, COUNT(*) AS bookings
FROM airportdb.booking
WHERE booking_id BETWEEN 1 AND 5000000
GROUP BY flight_id ORDER BY bookings DESC, flight_id LIMIT 10;

CALL workshop_hw26.olap_offload_proc_airportdb();

-- SQL OLAP-49 Confirmar o SELECT interno no histórico do HeatWave
-- Procura o SELECT interno nas estatísticas RAPID: query_id identifica o registro,
-- sql_text a consulta, rapid_exec_ms a duração e nodes os nós associados.
SELECT q.query_id,
       LEFT(q.query_text,100) AS sql_text,
       JSON_EXTRACT(q.qexec_text,'$**.rpdExec.msec') AS rapid_exec_ms,
       COUNT(e.node_id) AS nodes
FROM performance_schema.rpd_query_stats AS q
LEFT JOIN performance_schema.rpd_exec_stats AS e
  ON e.query_id=q.query_id
WHERE q.connection_id=CONNECTION_ID()
GROUP BY q.query_id,q.query_text,q.qexec_text
ORDER BY q.query_id DESC LIMIT 5;

-- SQL OLAP-50 Ativar diagnóstico apenas nesta sessão
-- Ativa FORCED e optimizer_trace apenas nesta sessão para diagnosticar a coluna
-- geolocalizacao excluída do RAPID.
SET SESSION optimizer_trace='enabled=on';

SET SESSION use_secondary_engine=FORCED;

-- SQL OLAP-51 Testar a coluna não carregada, erro esperado
-- Tenta usar no RAPID a coluna POINT geolocalizacao, que ficou NOT SECONDARY.
EXPLAIN FORMAT=TRADITIONAL
SELECT id, geolocalizacao
FROM workshop_hw26.unsupported_demo_pratica;

-- SQL OLAP-52 Ler o motivo e restaurar a sessão
-- Lê o trace imediatamente após o teste e restaura a sessão.
SELECT LEFT(query,180) AS sql_text,
       trace->'$**.Rapid_Offload_Fails' AS rapid_fail,
       trace->'$**.secondary_engine_not_used' AS not_used
FROM information_schema.optimizer_trace;

SET SESSION use_secondary_engine=ON,
            optimizer_trace='enabled=off';

-- ========================================================================
-- 2.1 Preparar os arquivos e o bucket
-- ========================================================================

-- SQL LAKE-01 Preparar o esquema do laboratório
-- Cria o esquema das seis tabelas externas; IF NOT EXISTS permite repetir o comando.
CREATE SCHEMA IF NOT EXISTS lab_lakehouse;

-- ========================================================================
-- 2.2 Criar e carregar manualmente o CSV
-- ========================================================================

-- SQL LAKE-02 Criar a tabela CSV
-- Define a tabela externa CSV e o objeto no Object Storage.
CREATE EXTERNAL TABLE lab_lakehouse.campanha_manual_csv (
  age BIGINT, job LONGTEXT, marital LONGTEXT,
  balance BIGINT, y LONGTEXT
)
FILE_FORMAT = (FORMAT csv HEADER ON)
FILES = (URI 'oci://lab_lakehouse@idi1o0a010nx/manual/bank.csv');

-- SQL LAKE-03 Carregar e acompanhar o CSV manual
-- Carrega o CSV manual no RAPID e acompanha a carga.
ALTER TABLE lab_lakehouse.campanha_manual_csv SECONDARY_LOAD;

SELECT i.table_name, r.load_status, r.load_progress, r.nrows
FROM performance_schema.rpd_table_id AS i
JOIN performance_schema.rpd_tables AS r USING (id)
WHERE i.schema_name='lab_lakehouse'
  AND i.table_name='campanha_manual_csv';

-- SQL LAKE-04 Consultar o CSV manual
-- Conta linhas, soma saldos, conta adesões e mostra dez exemplos do CSV.
SELECT COUNT(*) AS linhas, SUM(balance) AS saldo_total,
       SUM(y='yes') AS adesoes
FROM lab_lakehouse.campanha_manual_csv;

SELECT age, job, marital, balance, y
FROM lab_lakehouse.campanha_manual_csv LIMIT 10;

-- ========================================================================
-- 2.3 Criar e carregar manualmente o Parquet
-- ========================================================================

-- SQL LAKE-05 Criar a tabela Parquet
-- Declara a tabela externa Parquet com cinco colunas.
CREATE EXTERNAL TABLE lab_lakehouse.campanha_manual_parquet (
  age BIGINT, job LONGTEXT, marital LONGTEXT,
  balance BIGINT, y LONGTEXT
)
FILE_FORMAT = (FORMAT parquet)
FILES = (URI 'oci://lab_lakehouse@idi1o0a010nx/manual/bank.parquet');

-- SQL LAKE-06 Carregar e acompanhar o Parquet manual
-- Carrega o Parquet manual e acompanha seu estado.
ALTER TABLE lab_lakehouse.campanha_manual_parquet SECONDARY_LOAD;

SELECT i.table_name, r.load_status, r.load_progress, r.nrows
FROM performance_schema.rpd_table_id AS i
JOIN performance_schema.rpd_tables AS r USING (id)
WHERE i.schema_name='lab_lakehouse'
  AND i.table_name='campanha_manual_parquet';

-- SQL LAKE-07 Consultar o Parquet manual
-- Conta e mostra uma amostra do Parquet.
SELECT COUNT(*) AS linhas, SUM(balance) AS saldo_total,
       SUM(y='yes') AS adesoes
FROM lab_lakehouse.campanha_manual_parquet;

SELECT age, job, marital, balance, y
FROM lab_lakehouse.campanha_manual_parquet LIMIT 10;

-- ========================================================================
-- 2.4 Carregar dinamicamente o CSV por prefixo
-- ========================================================================

-- SQL LAKE-08 Preparar o prefixo CSV
-- Monta o JSON da carga dinâmica CSV: db_name/table_name identificam o destino, dialect
-- descreve o formato e file.uri terminado em / seleciona o prefixo de objetos.
SET @lake_dynamic_csv = JSON_ARRAY(JSON_OBJECT(
  'db_name','lab_lakehouse',
  'tables',JSON_ARRAY(JSON_OBJECT(
    'table_name','campanha_dinamica_csv',
    'engine_attribute',JSON_OBJECT(
      'dialect',JSON_OBJECT('format','csv','has_header',true,
                            'field_delimiter',','),
      'file',JSON_ARRAY(JSON_OBJECT(
        'uri','oci://lab_lakehouse@idi1o0a010nx/dynamic/csv/'
      ))
    )
  ))
));

-- SQL LAKE-09 Validar e carregar a primeira partição CSV
-- Faz dry run, depois cria e carrega o CSV da primeira partição.
CALL sys.HEATWAVE_LOAD(@lake_dynamic_csv,
  JSON_OBJECT('mode','dryrun','output','normal'));

CALL sys.HEATWAVE_LOAD(@lake_dynamic_csv,
  JSON_OBJECT('mode','normal','output','normal'));

SELECT COUNT(*) AS linhas_antes
FROM lab_lakehouse.campanha_dinamica_csv;

-- SQL LAKE-10 Atualizar e conferir o CSV dinâmico
-- Atualiza a tabela CSV lendo novos objetos do prefixo.
CALL sys.HEATWAVE_LOAD(
  JSON_ARRAY(JSON_OBJECT('db_name','lab_lakehouse',
    'tables',JSON_ARRAY('campanha_dinamica_csv'))),
  JSON_OBJECT('mode','normal','refresh_external_tables',true,
              'output','normal')
);

SELECT COUNT(*) AS linhas, SUM(balance) AS saldo_total,
       SUM(y='yes') AS adesoes
FROM lab_lakehouse.campanha_dinamica_csv;

-- ========================================================================
-- 2.5 Carregar dinamicamente o Parquet por prefixo
-- ========================================================================

-- SQL LAKE-11 Preparar o prefixo Parquet
-- Prepara a tabela dinâmica Parquet: dialect.format seleciona o leitor e o URI
-- terminado em / aponta para o prefixo, não para um arquivo único.
SET @lake_dynamic_parquet = JSON_ARRAY(JSON_OBJECT(
  'db_name','lab_lakehouse',
  'tables',JSON_ARRAY(JSON_OBJECT(
    'table_name','campanha_dinamica_parquet',
    'engine_attribute',JSON_OBJECT(
      'dialect',JSON_OBJECT('format','parquet'),
      'file',JSON_ARRAY(JSON_OBJECT(
        'uri','oci://lab_lakehouse@idi1o0a010nx/dynamic/parquet/'
      ))
    )
  ))
));

-- SQL LAKE-12 Validar e carregar a primeira partição Parquet
-- Faz dry run, cria/carrega a tabela Parquet e conta a primeira partição.
CALL sys.HEATWAVE_LOAD(@lake_dynamic_parquet,
  JSON_OBJECT('mode','dryrun','output','normal'));

CALL sys.HEATWAVE_LOAD(@lake_dynamic_parquet,
  JSON_OBJECT('mode','normal','output','normal'));

SELECT COUNT(*) AS linhas_antes
FROM lab_lakehouse.campanha_dinamica_parquet;

-- SQL LAKE-13 Atualizar e conferir o Parquet dinâmico
-- Atualiza o Parquet com a segunda partição e consulta os agregados.
CALL sys.HEATWAVE_LOAD(
  JSON_ARRAY(JSON_OBJECT('db_name','lab_lakehouse',
    'tables',JSON_ARRAY('campanha_dinamica_parquet'))),
  JSON_OBJECT('mode','normal','refresh_external_tables',true,
              'output','normal')
);

SELECT COUNT(*) AS linhas, SUM(balance) AS saldo_total,
       SUM(y='yes') AS adesoes
FROM lab_lakehouse.campanha_dinamica_parquet;

-- ========================================================================
-- 2.6 Criar e carregar automaticamente o CSV
-- ========================================================================

-- SQL LAKE-14 Preparar o CSV para inferência automática
-- Identifica um arquivo CSV específico para inferência automática e a tabela de
-- destino.
SET @lake_auto_csv = JSON_ARRAY(JSON_OBJECT(
  'db_name','lab_lakehouse',
  'tables',JSON_ARRAY(JSON_OBJECT(
    'table_name','campanha_automatica_csv',
    'engine_attribute',JSON_OBJECT(
      'dialect',JSON_OBJECT('format','csv','has_header',true,
                            'field_delimiter',','),
      'file',JSON_ARRAY(JSON_OBJECT(
        'uri','oci://lab_lakehouse@idi1o0a010nx/automatic/bank.csv'
      ))
    )
  ))
));

-- SQL LAKE-15 Fazer dry run e carregar o CSV automático
-- Faz dry run sem criar tabela, depois infere, cria e carrega o CSV.
CALL sys.HEATWAVE_LOAD(@lake_auto_csv,
  JSON_OBJECT('mode','dryrun','output','normal'));

CALL sys.HEATWAVE_LOAD(@lake_auto_csv,
  JSON_OBJECT('mode','normal','output','normal'));

SELECT COUNT(*) AS linhas
FROM lab_lakehouse.campanha_automatica_csv;

SELECT age, job, marital, balance, y
FROM lab_lakehouse.campanha_automatica_csv LIMIT 10;

-- ========================================================================
-- 2.7 Criar e carregar automaticamente o Parquet
-- ========================================================================

-- SQL LAKE-16 Preparar o Parquet para inferência automática
-- Aponta para um Parquet individual para inferir colunas e tipos.
SET @lake_auto_parquet = JSON_ARRAY(JSON_OBJECT(
  'db_name','lab_lakehouse',
  'tables',JSON_ARRAY(JSON_OBJECT(
    'table_name','campanha_automatica_parquet',
    'engine_attribute',JSON_OBJECT(
      'dialect',JSON_OBJECT('format','parquet'),
      'file',JSON_ARRAY(JSON_OBJECT(
        'uri','oci://lab_lakehouse@idi1o0a010nx/automatic/bank.parquet'
      ))
    )
  ))
));

-- SQL LAKE-17 Fazer dry run e carregar o Parquet automático
-- Valida a inferência por dry run, cria/carrega o Parquet e consulta os dados.
CALL sys.HEATWAVE_LOAD(@lake_auto_parquet,
  JSON_OBJECT('mode','dryrun','output','normal'));

CALL sys.HEATWAVE_LOAD(@lake_auto_parquet,
  JSON_OBJECT('mode','normal','output','normal'));

SELECT COUNT(*) AS linhas
FROM lab_lakehouse.campanha_automatica_parquet;

SELECT age, job, marital, balance, y
FROM lab_lakehouse.campanha_automatica_parquet LIMIT 10;

-- ========================================================================
-- 2.8 Confirmar status, equivalência e execução no RAPID
-- ========================================================================

-- SQL LAKE-18 Verificar as seis tabelas
-- Mostra as seis tabelas SQL, inclusive sem registro RAPID.
SELECT b.table_name, b.engine,
       COALESCE(r.load_status,'SEM_CARGA') AS estado,
       r.load_progress, r.nrows
FROM information_schema.tables AS b
LEFT JOIN performance_schema.rpd_table_id AS i
  ON i.schema_name=b.table_schema AND i.table_name=b.table_name
LEFT JOIN performance_schema.rpd_tables AS r ON r.id=i.id
WHERE b.table_schema='lab_lakehouse' AND b.table_type='BASE TABLE'
ORDER BY b.table_name;

-- SQL LAKE-19 Comparar os seis caminhos
-- Compara linhas, saldos e adesões dos seis caminhos de carga.
SELECT 'manual_csv' AS caminho,COUNT(*) AS linhas,
  SUM(balance) AS saldo_total,SUM(y='yes') AS adesoes
FROM lab_lakehouse.campanha_manual_csv
UNION ALL SELECT 'manual_parquet',COUNT(*),SUM(balance),SUM(y='yes')
FROM lab_lakehouse.campanha_manual_parquet
UNION ALL SELECT 'dinamica_csv',COUNT(*),SUM(balance),SUM(y='yes')
FROM lab_lakehouse.campanha_dinamica_csv
UNION ALL SELECT 'dinamica_parquet',COUNT(*),SUM(balance),SUM(y='yes')
FROM lab_lakehouse.campanha_dinamica_parquet
UNION ALL SELECT 'automatica_csv',COUNT(*),SUM(balance),SUM(y='yes')
FROM lab_lakehouse.campanha_automatica_csv
UNION ALL SELECT 'automatica_parquet',COUNT(*),SUM(balance),SUM(y='yes')
FROM lab_lakehouse.campanha_automatica_parquet;

-- SQL LAKE-20 Verificar o plano e agregar no Parquet
-- Mostra o plano da agregação por job no Parquet, executa a consulta e restaura a
-- sessão.
SET SESSION use_secondary_engine=FORCED;

EXPLAIN SELECT job,COUNT(*) AS clientes,SUM(y='yes') AS adesoes
FROM lab_lakehouse.campanha_manual_parquet GROUP BY job;

SELECT job,COUNT(*) AS clientes,SUM(y='yes') AS adesoes
FROM lab_lakehouse.campanha_manual_parquet GROUP BY job;

SET SESSION use_secondary_engine=ON;

-- ========================================================================
-- 2.9 Preparar uma nova execução
-- ========================================================================

-- SQL LAKE-21 Remover as seis tabelas do laboratório
-- Remove apenas as seis tabelas externas deste roteiro; IF EXISTS permite repetir a
-- limpeza.
DROP TABLE IF EXISTS lab_lakehouse.campanha_manual_csv;

DROP TABLE IF EXISTS lab_lakehouse.campanha_manual_parquet;

DROP TABLE IF EXISTS lab_lakehouse.campanha_dinamica_csv;

DROP TABLE IF EXISTS lab_lakehouse.campanha_dinamica_parquet;

DROP TABLE IF EXISTS lab_lakehouse.campanha_automatica_csv;

DROP TABLE IF EXISTS lab_lakehouse.campanha_automatica_parquet;

-- ========================================================================
-- 3.1 Preparar e conhecer as bases de treino e teste
-- ========================================================================

-- SQL ML-01 Limpar a execução anterior e criar a amostra
-- Cria o esquema, remove somente as quatro tabelas da prática anterior e prepara a
-- amostra determinística.
CREATE SCHEMA IF NOT EXISTS laboratorio_clima;

DROP TABLE IF EXISTS laboratorio_clima.previsoes_clima;

DROP TABLE IF EXISTS laboratorio_clima.clima_teste;

DROP TABLE IF EXISTS laboratorio_clima.clima_treino;

DROP TABLE IF EXISTS laboratorio_clima.leituras_climaticas;

SET SESSION use_secondary_engine = OFF;

CREATE TABLE laboratorio_clima.leituras_climaticas AS
SELECT log_date, time, station, temp, humidity,
       airpressure, wind, winddirection,
       CAST(weather AS CHAR(32)) AS weather_label
FROM airportdb.weatherdata
WHERE weather IS NOT NULL
  AND MOD(TO_DAYS(log_date)*24 + HOUR(time) + station, 401) = 0;

SET SESSION use_secondary_engine = ON;

-- SQL ML-02 Separar os dados de treino e teste
-- Divide cada medição em treino ou teste pelo mesmo cálculo CRC32.
CREATE TABLE laboratorio_clima.clima_treino AS
SELECT temp, humidity, airpressure, wind,
       winddirection, weather_label
FROM laboratorio_clima.leituras_climaticas
WHERE MOD(CRC32(CONCAT(log_date,' ',time,' ',station)),5) <> 0;

CREATE TABLE laboratorio_clima.clima_teste AS
SELECT temp, humidity, airpressure, wind,
       winddirection, weather_label
FROM laboratorio_clima.leituras_climaticas
WHERE MOD(CRC32(CONCAT(log_date,' ',time,' ',station)),5) = 0;

-- SQL ML-03 Conferir a base de treino
-- Conta as linhas de treino e mostra a frequência por weather_label.
SELECT COUNT(*) AS linhas_treino
FROM laboratorio_clima.clima_treino;

SELECT weather_label, COUNT(*) AS linhas
FROM laboratorio_clima.clima_treino
GROUP BY weather_label
ORDER BY linhas DESC;

-- SQL ML-04 Conferir a base de teste
-- Conta as linhas reservadas para teste e mostra as classes presentes.
SELECT COUNT(*) AS linhas_teste
FROM laboratorio_clima.clima_teste;

SELECT weather_label, COUNT(*) AS linhas
FROM laboratorio_clima.clima_teste
GROUP BY weather_label
ORDER BY linhas DESC;

-- ========================================================================
-- 3.2 Treinar o modelo e carregá-lo
-- ========================================================================

-- SQL ML-05 Verificar AutoML e definir o identificador
-- Confere rapid_ml_status=ON e cria um model_handle único na sessão.
SHOW GLOBAL STATUS LIKE 'rapid_ml_status';

SET @modelo_clima = CONCAT(
  'modelo_clima_',
  DATE_FORMAT(NOW(), '%Y%m%d_%H%i%s')
);

SELECT @modelo_clima AS model_handle;

-- SQL ML-06 Treinar o classificador
-- Treina um classificador com clima_treino, usando weather_label como alvo e
-- @modelo_clima como identificador.
CALL sys.ML_TRAIN(
  'laboratorio_clima.clima_treino',
  'weather_label',
  JSON_OBJECT('task', 'classification'),
  @modelo_clima
);

-- SQL ML-07 Confirmar o modelo treinado no catálogo
-- Localiza o modelo recém-treinado: model_handle deve corresponder ao criado,
-- train_table_name a clima_treino, model_type ao algoritmo e estado a Ready antes da
-- carga.
SELECT model_id, model_handle, model_type, train_table_name,
       JSON_UNQUOTE(JSON_EXTRACT(model_metadata, '$.status')) AS estado
FROM ML_SCHEMA_admin.MODEL_CATALOG
WHERE model_handle = @modelo_clima;

-- SQL ML-08 Carregar o modelo para uso
-- Carrega o modelo já treinado em memória para previsão; NULL usa opções padrão.
CALL sys.ML_MODEL_LOAD(@modelo_clima, NULL);

-- ========================================================================
-- 3.3 Prever uma linha e depois a tabela inteira
-- ========================================================================

-- SQL ML-09 Previsão de uma medição
-- Prevê uma medição: Prediction traz a classe e ml_results.probabilities as
-- probabilidades por classe.
SELECT JSON_PRETTY(sys.ML_PREDICT_ROW(
  JSON_OBJECT(
    'temp', 12, 'humidity', 92, 'airpressure', 1007,
    'wind', 3.2, 'winddirection', 180
  ),
  @modelo_clima,
  NULL
)) AS previsao;

-- SQL ML-10 Previsão em lote na base de teste
-- Remove apenas a tabela anterior de previsões e aplica o modelo a todas as linhas de
-- clima_teste.
DROP TABLE IF EXISTS laboratorio_clima.previsoes_clima;

CALL sys.ML_PREDICT_TABLE(
  'laboratorio_clima.clima_teste',
  @modelo_clima,
  'laboratorio_clima.previsoes_clima',
  NULL
);

-- ========================================================================
-- 3.4 Ver os resultados e medir os acertos
-- ========================================================================

-- SQL ML-11 Ver exemplos e contar previsões do lote
-- Compara classe_real com classe_prevista e mostra probabilidades por classe.
SELECT weather_label AS classe_real,
       Prediction AS classe_prevista,
       JSON_EXTRACT(ml_results, '$.probabilities') AS probabilidades
FROM laboratorio_clima.previsoes_clima
ORDER BY RAND()
LIMIT 10;

SELECT COUNT(*) AS linhas_previstas
FROM laboratorio_clima.previsoes_clima;

-- SQL ML-12 Medir a acurácia no conjunto de teste
-- ML_SCORE compara previsões ao weather_label conhecido e grava a acurácia em
-- @acuracia.
CALL sys.ML_SCORE(
  'laboratorio_clima.clima_teste',
  'weather_label',
  @modelo_clima,
  'accuracy',
  @acuracia,
  NULL
);

SELECT @acuracia AS acuracia;

-- ========================================================================
-- 3.5 Entender quais variáveis pesam mais
-- ========================================================================

-- SQL ML-13 Ver as colunas mais importantes
-- Mostra no JSON a importância global das colunas para este modelo.
SELECT JSON_PRETTY(JSON_EXTRACT(
  model_explanation, '$.permutation_importance'
)) AS importancia_global
FROM ML_SCHEMA_admin.MODEL_CATALOG
WHERE model_handle = @modelo_clima;

-- ========================================================================
-- 3.6 Descarregar e excluir o modelo do exercício
-- ========================================================================

-- SQL ML-14 Descarregar e excluir o modelo
-- Se não precisar mais do modelo, ML_MODEL_UNLOAD o retira da memória e DELETE o remove
-- do catálogo.
CALL sys.ML_MODEL_UNLOAD(@modelo_clima);

DELETE FROM ML_SCHEMA_admin.MODEL_CATALOG
WHERE model_handle = @modelo_clima
  AND train_table_name = 'laboratorio_clima.clima_treino';

SELECT ROW_COUNT() AS modelos_excluidos;

COMMIT;

SELECT COUNT(*) AS modelos_restantes
FROM ML_SCHEMA_admin.MODEL_CATALOG
WHERE model_handle = @modelo_clima;

-- ========================================================================
-- 4.1 Segmentar e carregar o documento
-- ========================================================================

-- SQL RAG-01 Criar o schema da demonstração
-- Cria o esquema da demonstração; IF NOT EXISTS evita erro se já existir.
CREATE SCHEMA IF NOT EXISTS lab_rag;

-- SQL RAG-02 Vetorizar o guia e criar a tabela
-- Inicia a vetorização assíncrona do TXT em português e cria
-- lab_rag.guia_campanha_vetores.
CALL sys.VECTOR_STORE_LOAD(
  'oci://lab_rag@idi1o0a010nx/guia_campanha_bancaria.txt',
  JSON_OBJECT(
    'schema_name','lab_rag',
    'table_name','guia_campanha_vetores',
    'language','pt',
    'formats',JSON_ARRAY('txt'),
    'embed_model_id','multilingual-e5-small',
    'description','Guia em português da campanha bancária',
    'task_name','Carga do guia da campanha bancária',
    'chunking',JSON_OBJECT('split_by','paragraph','max',160,
                           'by','words','overlap',20)
  )
);

-- SQL RAG-03 Acompanhar a tarefa de vetorização
-- Acompanha a tarefa: SCHEDULED espera, RUNNING processa, COMPLETED/100 conclui, ERROR
-- falha e CANCELLED interrompe.
SELECT JSON_PRETTY(mysql_tasks.task_status_list('GenAI_Load',0,5))
  AS tarefas_recentes;

SET @id_tarefa = JSON_UNQUOTE(JSON_EXTRACT(
  mysql_tasks.task_status_list('GenAI_Load',0,1),
  '$[0].id'
));

SELECT JSON_PRETTY(mysql_tasks.task_status_brief(@id_tarefa))
  AS status_da_tarefa;

-- SQL RAG-04 Ver a tabela e os segmentos
-- Mostra as colunas e conta os segmentos da tabela vetorial.
DESCRIBE lab_rag.guia_campanha_vetores;

SELECT COUNT(*) AS segmentos,
       MIN(CHAR_LENGTH(segment)) AS menor_tamanho,
       MAX(CHAR_LENGTH(segment)) AS maior_tamanho
FROM lab_rag.guia_campanha_vetores;

SELECT segment_number,LEFT(segment,300) AS trecho,
       VECTOR_DIM(segment_embedding) AS dimensoes
FROM lab_rag.guia_campanha_vetores
ORDER BY segment_number LIMIT 5;

-- ========================================================================
-- 4.2 Gerar um vetor e recuperar os trechos
-- ========================================================================

-- SQL RAG-05 Gerar o vetor da pergunta
-- Gera o embedding da pergunta em português e mostra sua dimensão.
SET @vetor_pergunta = sys.ML_EMBED_ROW(
  'O que significa pdays igual a menos um?',
  JSON_OBJECT('model_id','multilingual-e5-small')
);

SELECT VECTOR_DIM(@vetor_pergunta) AS dimensoes;

-- SQL RAG-06 Encontrar os trechos mais próximos
-- Ordena cinco trechos do guia por distância cosseno à pergunta.
SELECT segment_number,LEFT(segment,300) AS trecho,
       ROUND(DISTANCE(segment_embedding,@vetor_pergunta,'COSINE'),4)
         AS distancia
FROM lab_rag.guia_campanha_vetores
ORDER BY distancia LIMIT 5;

-- ========================================================================
-- 4.3 Responder com RAG e conferir as fontes
-- ========================================================================

-- SQL RAG-07 Listar os LLMs de geração disponíveis
-- Lista LLMs de geração disponíveis no HeatWave, excluindo modelos somente de
-- embeddings.
SELECT provider, model_id, default_model
FROM sys.ML_SUPPORTED_LLMS
WHERE provider = 'HeatWave'
  AND JSON_CONTAINS(capabilities, JSON_QUOTE('GENERATION'))
ORDER BY default_model DESC, model_id;

-- SQL RAG-08 Perguntar ao guia e mostrar a resposta
-- Pergunta em português ao guia e devolve resposta com até três citações.
SET @opcoes_rag = JSON_OBJECT(
  'vector_store',JSON_ARRAY('lab_rag.guia_campanha_vetores'),
  'n_citations',3,
  'model_options',JSON_OBJECT('language','pt')
);

SET @pergunta_rag =
  'Responda em português: o que representa y e quantos clientes aderiram na amostra?';

CALL sys.ML_RAG(@pergunta_rag,@rag_resposta,@opcoes_rag);

SELECT JSON_PRETTY(@rag_resposta) AS resposta_e_fontes;

-- SQL RAG-09 Chamada direta ao RAG com a tabela vetorial
-- Consulta diretamente a tabela vetorial já criada, sem gerar vetores novamente.
CALL sys.ML_RAG(
  'O que representa y e quantos clientes aderiram na amostra?',
  @resposta_rag,
  JSON_OBJECT(
    'vector_store', JSON_ARRAY('lab_rag.guia_campanha_vetores'),
    'model_options', JSON_OBJECT('language', 'pt')
  )
);

SELECT JSON_PRETTY(@resposta_rag) AS resultado;
