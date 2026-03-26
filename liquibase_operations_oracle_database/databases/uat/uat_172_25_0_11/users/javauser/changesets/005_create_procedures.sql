--liquibase formatted sql
-- ═══════════════════════════════════════════════════════════════════════════
-- 005 — Requirement 4: Stored Procedure Creation with Role Assignment
-- LABEL: dba,cicd — ONLY DBA can create/replace stored procedures and grant roles
-- A Developer does NOT have CREATE PROCEDURE privilege
-- ═══════════════════════════════════════════════════════════════════════════

--changeset platform-dev:005-create-usp-disbursal-process labels:dba,cicd splitStatements:false endDelimiter:/ runOnChange:false
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
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            p_status := 'FAILED'; p_message := 'Application not found: ' || p_application_id; RETURN;
    END;
    IF v_app_status != 'APPROVED' THEN
        p_status := 'FAILED'; p_message := 'Not APPROVED: ' || v_app_status; RETURN;
    END IF;
    IF p_disbursal_amt > v_max_amount THEN
        p_status := 'FAILED'; p_message := 'Exceeds approved amount'; RETURN;
    END IF;
    IF p_disbursal_mode NOT IN ('NEFT','RTGS','IMPS') THEN
        p_status := 'FAILED'; p_message := 'Invalid mode: ' || p_disbursal_mode; RETURN;
    END IF;
    UPDATE DL_LOAN_APPLICATION
    SET STATUS='DISBURSED', DISBURSAL_AMT=p_disbursal_amt, DISBURSAL_MODE=p_disbursal_mode,
        DISBURSAL_DATE=SYSTIMESTAMP, DISBURSED_BY=p_initiated_by, UPDATED_AT=SYSTIMESTAMP
    WHERE APPLICATION_ID = p_application_id;
    INSERT INTO DL_DISBURSAL_AUDIT (APPLICATION_ID, DISBURSAL_AMT, DISBURSAL_MODE, INITIATED_BY, CREATED_AT, STATUS)
    VALUES (p_application_id, p_disbursal_amt, p_disbursal_mode, p_initiated_by, SYSTIMESTAMP, 'SUCCESS');
    COMMIT;
    p_status := 'SUCCESS'; p_message := 'Disbursal processed: ' || p_application_id;
EXCEPTION
    WHEN OTHERS THEN ROLLBACK; p_status := 'ERROR'; p_message := 'Error: ' || SQLERRM;
END USP_DISBURSAL_PROCESS;
/
GRANT EXECUTE ON USP_DISBURSAL_PROCESS TO DL_APP_ROLE
/
--rollback DROP PROCEDURE USP_DISBURSAL_PROCESS;

--changeset platform-dev:005-create-usp-loan-eligibility labels:dba,cicd splitStatements:false endDelimiter:/ runOnChange:false
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
    IF v_is_active != 'Y' THEN
        p_is_eligible:='N'; p_max_amount:=0; p_reason:='Journey inactive'; RETURN;
    END IF;
    IF p_cibil_score < v_min_cibil THEN
        p_is_eligible:='N'; p_max_amount:=0; p_reason:='CIBIL '||p_cibil_score||' below '||v_min_cibil; RETURN;
    END IF;
    IF p_income < v_min_income THEN
        p_is_eligible:='N'; p_max_amount:=0; p_reason:='Income '||p_income||' below '||v_min_income; RETURN;
    END IF;
    p_max_amount := LEAST(p_income * 60, v_max_loan);
    p_is_eligible := 'Y';
    p_reason := 'Eligible. Max: INR ' || p_max_amount;
    INSERT INTO DL_ELIGIBILITY_LOG (APPLICANT_ID, JOURNEY_ID, PARTNER_ID, CIBIL_SCORE, INCOME, IS_ELIGIBLE, MAX_AMOUNT, CHECKED_AT)
    VALUES (p_applicant_id, p_journey_id, p_partner_id, p_cibil_score, p_income, p_is_eligible, p_max_amount, SYSTIMESTAMP);
    COMMIT;
EXCEPTION WHEN OTHERS THEN ROLLBACK; p_is_eligible:='N'; p_max_amount:=0; p_reason:='Error: '||SQLERRM;
END USP_LOAN_ELIGIBILITY;
/
GRANT EXECUTE ON USP_LOAN_ELIGIBILITY TO DL_APP_ROLE
/
--rollback DROP PROCEDURE USP_LOAN_ELIGIBILITY;

--changeset platform-dev:005-create-usp-repayment-schedule labels:dba,cicd splitStatements:false endDelimiter:/ runOnChange:false
CREATE OR REPLACE PROCEDURE USP_REPAYMENT_SCHEDULE (
    p_application_id  IN  VARCHAR2,
    p_loan_amount     IN  NUMBER,
    p_interest_rate   IN  NUMBER,
    p_tenure_months   IN  NUMBER,
    p_start_date      IN  DATE,
    p_status          OUT VARCHAR2,
    p_message         OUT VARCHAR2
)
AS
    v_emi            NUMBER;
    v_monthly_rate   NUMBER;
    v_balance        NUMBER;
    v_emi_date       DATE;
    v_interest_comp  NUMBER;
    v_principal_comp NUMBER;
BEGIN
    v_monthly_rate := (p_interest_rate / 100) / 12;
    v_emi := ROUND(p_loan_amount * v_monthly_rate * POWER(1+v_monthly_rate, p_tenure_months)
                   / (POWER(1+v_monthly_rate, p_tenure_months) - 1), 2);
    v_balance  := p_loan_amount;
    v_emi_date := p_start_date;
    FOR i IN 1..p_tenure_months LOOP
        v_interest_comp  := ROUND(v_balance * v_monthly_rate, 2);
        v_principal_comp := ROUND(v_emi - v_interest_comp, 2);
        v_balance        := ROUND(v_balance - v_principal_comp, 2);
        INSERT INTO DL_REPAYMENT_SCHEDULE
            (APPLICATION_ID, EMI_NUMBER, EMI_DATE, EMI_AMOUNT, PRINCIPAL_COMPONENT, INTEREST_COMPONENT, CLOSING_BALANCE, CREATED_AT)
        VALUES (p_application_id, i, v_emi_date, v_emi, v_principal_comp, v_interest_comp, GREATEST(v_balance,0), SYSTIMESTAMP);
        v_emi_date := ADD_MONTHS(v_emi_date, 1);
    END LOOP;
    COMMIT;
    p_status := 'SUCCESS'; p_message := 'Schedule created. EMI: INR ' || v_emi;
EXCEPTION WHEN OTHERS THEN ROLLBACK; p_status := 'ERROR'; p_message := 'Error: ' || SQLERRM;
END USP_REPAYMENT_SCHEDULE;
/
GRANT EXECUTE ON USP_REPAYMENT_SCHEDULE TO DL_APP_ROLE
/
GRANT EXECUTE ON USP_REPAYMENT_SCHEDULE TO DL_REPORTING_ROLE
/
--rollback DROP PROCEDURE USP_REPAYMENT_SCHEDULE;
