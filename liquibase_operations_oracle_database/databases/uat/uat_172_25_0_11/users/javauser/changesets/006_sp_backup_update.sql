--liquibase formatted sql
-- ═══════════════════════════════════════════════════════════════════════════
-- 006 — Requirements 5 + 6: SP Backup + SP Update
-- LABEL: dba,cicd — ONLY DBA can replace SPs and read DBMS_METADATA
-- DBMS_METADATA.GET_DDL and CREATE OR REPLACE PROCEDURE require DBA privilege
-- ═══════════════════════════════════════════════════════════════════════════

--changeset platform-dev:006-backup-all-sps-pre-deploy labels:dba,cicd endDelimiter:/ splitStatements:false runAlways:true
-- Req 6: Backup ALL stored procedures before every deployment (runAlways=true)
DECLARE
    v_ddl CLOB;
BEGIN
    FOR sp IN (SELECT object_name FROM user_objects WHERE object_type='PROCEDURE' ORDER BY object_name) LOOP
        BEGIN
            v_ddl := DBMS_METADATA.GET_DDL('PROCEDURE', sp.object_name);
            INSERT INTO SP_BACKUP_LOG (PROC_NAME, PROC_DEFINITION, BACKED_UP_AT, DEPLOYMENT_TAG, NOTES)
            VALUES (sp.object_name, v_ddl, SYSTIMESTAMP, 'PRE-DEPLOY-ALL', 'Auto full SP backup');
        EXCEPTION
            WHEN OTHERS THEN
                INSERT INTO SP_BACKUP_LOG (PROC_NAME, PROC_DEFINITION, BACKED_UP_AT, DEPLOYMENT_TAG, NOTES)
                VALUES (sp.object_name, 'DDL_FAILED:' || SQLERRM, SYSTIMESTAMP, 'PRE-DEPLOY-ALL', 'Backup error');
        END;
    END LOOP;
    COMMIT;
END;
/
--rollback SELECT 'Backup log rows are audit-only, no rollback required' FROM DUAL;

--changeset platform-dev:006-backup-usp-disbursal-before-update labels:dba,cicd endDelimiter:/ splitStatements:false runAlways:true
-- Req 5 Step A: Individual backup of USP_DISBURSAL_PROCESS before replacement
DECLARE
    v_count NUMBER;
    v_ddl   CLOB;
BEGIN
    SELECT COUNT(*) INTO v_count FROM user_objects WHERE object_name='USP_DISBURSAL_PROCESS' AND object_type='PROCEDURE';
    IF v_count > 0 THEN
        v_ddl := DBMS_METADATA.GET_DDL('PROCEDURE', 'USP_DISBURSAL_PROCESS');
        INSERT INTO SP_BACKUP_LOG (PROC_NAME, PROC_DEFINITION, BACKED_UP_AT, DEPLOYMENT_TAG, NOTES)
        VALUES ('USP_DISBURSAL_PROCESS', v_ddl, SYSTIMESTAMP, 'CH123982828', 'Pre-update individual backup');
        COMMIT;
    END IF;
END;
/
--rollback SELECT 'Backup log rows are audit-only, no rollback required' FROM DUAL;

--changeset platform-dev:006-update-usp-disbursal-process labels:dba,cicd endDelimiter:/ splitStatements:false runOnChange:true
-- Req 5 Step B: Replace USP_DISBURSAL_PROCESS — runs when SQL body below changes (runOnChange)
CREATE OR REPLACE PROCEDURE USP_DISBURSAL_PROCESS (
    p_application_id  IN  VARCHAR2,
    p_disbursal_amt   IN  NUMBER,
    p_disbursal_mode  IN  VARCHAR2,
    p_initiated_by    IN  VARCHAR2,
    p_status          OUT VARCHAR2,
    p_message         OUT VARCHAR2
)
AS
    v_app_status  VARCHAR2(50);
    v_max_amount  NUMBER;
BEGIN
    BEGIN
        SELECT STATUS, LOAN_AMOUNT INTO v_app_status, v_max_amount
        FROM DL_LOAN_APPLICATION WHERE APPLICATION_ID = p_application_id FOR UPDATE;
    EXCEPTION WHEN NO_DATA_FOUND THEN p_status:='FAILED'; p_message:='Not found:'||p_application_id; RETURN;
    END;
    IF v_app_status != 'APPROVED' THEN p_status:='FAILED'; p_message:='Not APPROVED:'||v_app_status; RETURN; END IF;
    IF p_disbursal_amt > v_max_amount THEN p_status:='FAILED'; p_message:='Exceeds approved'; RETURN; END IF;
    IF p_disbursal_mode NOT IN ('NEFT','RTGS','IMPS') THEN p_status:='FAILED'; p_message:='Invalid mode'; RETURN; END IF;
    UPDATE DL_LOAN_APPLICATION
    SET STATUS='DISBURSED', DISBURSAL_AMT=p_disbursal_amt, DISBURSAL_MODE=p_disbursal_mode,
        DISBURSAL_DATE=SYSTIMESTAMP, DISBURSED_BY=p_initiated_by, UPDATED_AT=SYSTIMESTAMP
    WHERE APPLICATION_ID = p_application_id;
    INSERT INTO DL_DISBURSAL_AUDIT (APPLICATION_ID, DISBURSAL_AMT, DISBURSAL_MODE, INITIATED_BY, CREATED_AT, STATUS)
    VALUES (p_application_id, p_disbursal_amt, p_disbursal_mode, p_initiated_by, SYSTIMESTAMP, 'SUCCESS');
    COMMIT;
    p_status:='SUCCESS'; p_message:='Disbursal processed:'||p_application_id;
EXCEPTION WHEN OTHERS THEN ROLLBACK; p_status:='ERROR'; p_message:='Error:'||SQLERRM;
END USP_DISBURSAL_PROCESS;
/
GRANT EXECUTE ON USP_DISBURSAL_PROCESS TO DL_APP_ROLE
/
--rollback DECLARE v_ddl CLOB; BEGIN SELECT PROC_DEFINITION INTO v_ddl FROM (SELECT PROC_DEFINITION FROM SP_BACKUP_LOG WHERE PROC_NAME='USP_DISBURSAL_PROCESS' ORDER BY BACKED_UP_AT DESC) WHERE ROWNUM=1; EXECUTE IMMEDIATE v_ddl; EXECUTE IMMEDIATE 'GRANT EXECUTE ON USP_DISBURSAL_PROCESS TO DL_APP_ROLE'; END;

--changeset platform-dev:006-backup-usp-loan-eligibility-before-update labels:dba,cicd endDelimiter:/ splitStatements:false runAlways:true
-- Req 5 Step A: Individual backup of USP_LOAN_ELIGIBILITY before replacement
DECLARE
    v_count NUMBER;
    v_ddl   CLOB;
BEGIN
    SELECT COUNT(*) INTO v_count FROM user_objects WHERE object_name='USP_LOAN_ELIGIBILITY' AND object_type='PROCEDURE';
    IF v_count > 0 THEN
        v_ddl := DBMS_METADATA.GET_DDL('PROCEDURE', 'USP_LOAN_ELIGIBILITY');
        INSERT INTO SP_BACKUP_LOG (PROC_NAME, PROC_DEFINITION, BACKED_UP_AT, DEPLOYMENT_TAG, NOTES)
        VALUES ('USP_LOAN_ELIGIBILITY', v_ddl, SYSTIMESTAMP, 'CH123982828', 'Pre-update individual backup');
        COMMIT;
    END IF;
END;
/
--rollback SELECT 'Backup log rows are audit-only, no rollback required' FROM DUAL;

--changeset platform-dev:006-update-usp-loan-eligibility labels:dba,cicd endDelimiter:/ splitStatements:false runOnChange:true
-- Req 5 Step B: Replace USP_LOAN_ELIGIBILITY — edit body below to trigger runOnChange
CREATE OR REPLACE PROCEDURE USP_LOAN_ELIGIBILITY (
    p_applicant_id    IN  VARCHAR2,
    p_journey_id      IN  VARCHAR2,
    p_partner_id      IN  NUMBER,
    p_income          IN  NUMBER,
    p_cibil_score     IN  NUMBER,
    p_is_eligible     OUT VARCHAR2,
    p_max_amount      OUT NUMBER,
    p_reason          OUT VARCHAR2
)
AS
    v_is_active  VARCHAR2(1);
    v_min_cibil  NUMBER := 700;
    v_max_loan   NUMBER := 5000000;
    v_min_income NUMBER := 25000;
BEGIN
    SELECT IS_ACTIVE INTO v_is_active FROM DL_JOURNEY_MASTER WHERE JOURNEY_ID = p_journey_id;
    IF v_is_active!='Y' THEN p_is_eligible:='N'; p_max_amount:=0; p_reason:='Journey inactive'; RETURN; END IF;
    IF p_cibil_score < v_min_cibil THEN p_is_eligible:='N'; p_max_amount:=0; p_reason:='CIBIL too low'; RETURN; END IF;
    IF p_income < v_min_income THEN p_is_eligible:='N'; p_max_amount:=0; p_reason:='Income too low'; RETURN; END IF;
    p_max_amount := LEAST(p_income * 60, v_max_loan);
    p_is_eligible := 'Y'; p_reason := 'Eligible. Max: INR ' || p_max_amount;
    INSERT INTO DL_ELIGIBILITY_LOG (APPLICANT_ID, JOURNEY_ID, PARTNER_ID, CIBIL_SCORE, INCOME, IS_ELIGIBLE, MAX_AMOUNT, CHECKED_AT)
    VALUES (p_applicant_id, p_journey_id, p_partner_id, p_cibil_score, p_income, p_is_eligible, p_max_amount, SYSTIMESTAMP);
    COMMIT;
EXCEPTION WHEN OTHERS THEN ROLLBACK; p_is_eligible:='N'; p_max_amount:=0; p_reason:='Error:'||SQLERRM;
END USP_LOAN_ELIGIBILITY;
/
GRANT EXECUTE ON USP_LOAN_ELIGIBILITY TO DL_APP_ROLE
/
--rollback DECLARE v_ddl CLOB; BEGIN SELECT PROC_DEFINITION INTO v_ddl FROM (SELECT PROC_DEFINITION FROM SP_BACKUP_LOG WHERE PROC_NAME='USP_LOAN_ELIGIBILITY' ORDER BY BACKED_UP_AT DESC) WHERE ROWNUM=1; EXECUTE IMMEDIATE v_ddl; EXECUTE IMMEDIATE 'GRANT EXECUTE ON USP_LOAN_ELIGIBILITY TO DL_APP_ROLE'; END;
