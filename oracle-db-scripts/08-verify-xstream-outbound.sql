-- =============================================================================
-- Verify XStream Outbound Server Configuration
-- Run as SYSDBA - connect to CDB (not PDB)
-- sqlplus sys/pwd@//host:1521/DB0312_r8n_phx... as sysdba
-- =============================================================================
--
-- CRITICAL: If ALL queries return "no rows selected", the XStream outbound
-- server was NEVER CREATED. This is the root cause of "only REGIONS topic".
-- Fix: Run 06-create-outbound-ordermgmt.sql as c##xstrmadmin (connect to CDB).
--
-- Expected correct configuration:
-- 1. Outbound: SERVER_NAME=XOUT, CONNECT_USER=C##CFLTUSER, CAPTURE_NAME=CONFLUENT_XOUT1
-- 2. Capture: STATUS=ENABLED
-- 3. XStream service: network_name used as database.service.name in connector
-- =============================================================================

PROMPT === 1. All XStream Outbound Servers ===
SELECT SERVER_NAME, CONNECT_USER, CAPTURE_NAME, QUEUE_OWNER, QUEUE_NAME, STATUS
FROM DBA_XSTREAM_OUTBOUND;

PROMPT
PROMPT === 2. Capture Process (confluent_xout1) ===
SELECT CAPTURE_NAME, QUEUE_OWNER, QUEUE_NAME, STATUS, START_SCN, SOURCE_DATABASE
FROM DBA_CAPTURE
WHERE CAPTURE_NAME = 'CONFLUENT_XOUT1';

PROMPT
PROMPT === 3. Capture Rule Sets (DBA_CAPTURE_PARAMETERS for table rules) ===
SELECT CAPTURE_NAME, PARAMETER, VALUE
FROM DBA_CAPTURE_PARAMETERS
WHERE CAPTURE_NAME = 'CONFLUENT_XOUT1'
  AND PARAMETER IN ('TABLE_RULES', 'SCHEMA_RULES')
ORDER BY PARAMETER;

PROMPT
PROMPT === 4. XStream Capture (V$XSTREAM_CAPTURE - Oracle 19c) ===
SELECT CAPTURE_NAME, STATE, STARTUP_TIME
FROM V$XSTREAM_CAPTURE
WHERE CAPTURE_NAME = 'CONFLUENT_XOUT1';

PROMPT
PROMPT === 5. XStream Service for RAC (use network_name in connector) ===
SELECT inst_id, service_id, name, network_name
FROM gv$SERVICES
WHERE UPPER(NAME) LIKE '%XOUT%' OR UPPER(NETWORK_NAME) LIKE '%XOUT%';

PROMPT
PROMPT === 6. Apply Process (xout) ===
SELECT APPLY_NAME, QUEUE_OWNER, QUEUE_NAME, STATUS
FROM DBA_APPLY
WHERE APPLY_NAME = 'XOUT';

PROMPT
PROMPT === 7. Current container (must be CDB$ROOT to see XStream) ===
SELECT SYS_CONTEXT('USERENV','CON_NAME') AS CONTAINER FROM DUAL;
