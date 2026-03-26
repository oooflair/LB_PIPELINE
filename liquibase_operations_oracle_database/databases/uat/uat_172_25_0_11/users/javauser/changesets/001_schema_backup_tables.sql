--liquibase formatted sql
-- ═══════════════════════════════════════════════════════════════════════════
-- 001 — Schema: Backup & Audit Tables (Oracle DDL)
-- LABEL: dba — only DBA/CI-CD can create tables (requires DDL privilege)
-- ═══════════════════════════════════════════════════════════════════════════

--changeset platform-dev:001-create-sp-backup-log labels:dba,cicd endDelimiter:/ splitStatements:false
DECLARE
    v_count NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_count FROM user_tables WHERE table_name = 'SP_BACKUP_LOG';
    IF v_count = 0 THEN
        EXECUTE IMMEDIATE '
            CREATE TABLE SP_BACKUP_LOG (
                ID               NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
                PROC_NAME        VARCHAR2(255)  NOT NULL,
                PROC_DEFINITION  CLOB           NOT NULL,
                BACKED_UP_AT     TIMESTAMP      DEFAULT SYSTIMESTAMP NOT NULL,
                DEPLOYMENT_TAG   VARCHAR2(200),
                NOTES            VARCHAR2(500)
            )
        ';
    END IF;
END;
/
--rollback DROP TABLE SP_BACKUP_LOG PURGE

--changeset platform-dev:001-create-json-config-bkp labels:dba,cicd endDelimiter:/ splitStatements:false
DECLARE
    v_count NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_count FROM user_tables WHERE table_name = 'DL_CONFIG_JSON_BKP';
    IF v_count = 0 THEN
        EXECUTE IMMEDIATE '
            CREATE TABLE DL_CONFIG_JSON_BKP (
                ID               NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
                JOURNEY_ID       VARCHAR2(100)  NOT NULL,
                CONFIG_JSON      CLOB,
                BACKED_UP_AT     TIMESTAMP      DEFAULT SYSTIMESTAMP NOT NULL,
                DEPLOYMENT_TAG   VARCHAR2(200)
            )
        ';
    END IF;
END;
/
--rollback DROP TABLE DL_CONFIG_JSON_BKP PURGE

--changeset platform-dev:001-create-data-update-bkp labels:dba,cicd endDelimiter:/ splitStatements:false
DECLARE
    v_count NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_count FROM user_tables WHERE table_name = 'DL_DATA_UPDATE_BKP';
    IF v_count = 0 THEN
        EXECUTE IMMEDIATE '
            CREATE TABLE DL_DATA_UPDATE_BKP (
                ID               NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
                TABLE_NAME       VARCHAR2(200)  NOT NULL,
                ROW_KEY          VARCHAR2(200),
                COLUMN_NAME      VARCHAR2(200),
                OLD_VALUE        CLOB,
                BACKED_UP_AT     TIMESTAMP      DEFAULT SYSTIMESTAMP NOT NULL,
                DEPLOYMENT_TAG   VARCHAR2(200)
            )
        ';
    END IF;
END;
/
--rollback DROP TABLE DL_DATA_UPDATE_BKP PURGE
