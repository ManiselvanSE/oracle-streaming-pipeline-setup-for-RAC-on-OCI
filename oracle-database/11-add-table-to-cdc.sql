-- =============================================================================
-- Oracle XStream CDC - Add New Table to Existing Outbound
-- Run as: sqlplus c##xstrmadmin/<pwd>@//host:1521/DB0312... as sysdba @11-add-table-to-cdc.sql "ORDERMGMT.NEW_ORDERS"
-- =============================================================================
-- Prerequisites (run as SYSDBA in PDB first):
--   1. ALTER SESSION SET CONTAINER = XSTRPDB;
--   2. ALTER TABLE schema.table ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS;
--   3. GRANT SELECT ON schema.table TO c##cfltuser;
-- After this script: Update connector table.include.list and restart connector
-- =============================================================================

SET SERVEROUTPUT ON

DECLARE
  v_table VARCHAR2(128) := '&1';
  v_qo VARCHAR2(128);
  v_qn VARCHAR2(128);
BEGIN
  IF v_table IS NULL OR LENGTH(TRIM(v_table)) = 0 THEN
    RAISE_APPLICATION_ERROR(-20001, 'Usage: @11-add-table-to-cdc.sql "SCHEMA.TABLE"');
  END IF;

  SELECT queue_owner, queue_name INTO v_qo, v_qn
  FROM dba_capture WHERE capture_name = 'CONFLUENT_XOUT1';

  DBMS_OUTPUT.PUT_LINE('Adding table: ' || v_table);
  DBMS_OUTPUT.PUT_LINE('Queue: ' || v_qo || '.' || v_qn);

  -- Add to capture
  DBMS_XSTREAM_ADM.ADD_TABLE_RULES(
    table_name             => v_table,
    streams_type           => 'capture',
    streams_name           => 'confluent_xout1',
    queue_name             => v_qo || '.' || v_qn,
    include_dml            => TRUE,
    include_ddl            => FALSE,
    source_container_name  => 'XSTRPDB');
  DBMS_OUTPUT.PUT_LINE('Added to capture.');

  -- Add to apply (outbound)
  DBMS_XSTREAM_ADM.ADD_TABLE_RULES(
    table_name             => v_table,
    streams_type           => 'apply',
    streams_name           => 'xout',
    queue_name             => v_qo || '.' || v_qn,
    include_dml            => TRUE,
    include_ddl            => FALSE,
    source_container_name  => 'XSTRPDB');
  DBMS_OUTPUT.PUT_LINE('Added to outbound.');

  COMMIT;
  DBMS_OUTPUT.PUT_LINE('Done. Update connector table.include.list and restart connector.');
END;
/
