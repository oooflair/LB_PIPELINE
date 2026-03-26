--liquibase formatted sql
-- ═══════════════════════════════════════════════════════════════════════════
-- 004 — Requirement 3: Insert or Update JSON Configuration
-- LABEL: developer,cicd — Developer can run JSON config upsert operations
-- ═══════════════════════════════════════════════════════════════════════════

--changeset platform-dev:004-backup-json-JRN001 labels:developer,cicd splitStatements:false endDelimiter:;
INSERT INTO DL_CONFIG_JSON_BKP (JOURNEY_ID, CONFIG_JSON, BACKED_UP_AT, DEPLOYMENT_TAG)
SELECT JOURNEY_ID, CONFIG_JSON, SYSTIMESTAMP, 'CH123982828'
FROM DL_JOURNEY_MASTER WHERE JOURNEY_ID = 'JRN001';
--rollback DELETE FROM DL_CONFIG_JSON_BKP WHERE JOURNEY_ID='JRN001' AND DEPLOYMENT_TAG='CH123982828';

--changeset platform-dev:004-backup-json-JRN002 labels:developer,cicd splitStatements:false endDelimiter:;
INSERT INTO DL_CONFIG_JSON_BKP (JOURNEY_ID, CONFIG_JSON, BACKED_UP_AT, DEPLOYMENT_TAG)
SELECT JOURNEY_ID, CONFIG_JSON, SYSTIMESTAMP, 'CH123982828'
FROM DL_JOURNEY_MASTER WHERE JOURNEY_ID = 'JRN002';
--rollback DELETE FROM DL_CONFIG_JSON_BKP WHERE JOURNEY_ID='JRN002' AND DEPLOYMENT_TAG='CH123982828';

--changeset platform-dev:004-backup-json-JRN003 labels:developer,cicd splitStatements:false endDelimiter:;
INSERT INTO DL_CONFIG_JSON_BKP (JOURNEY_ID, CONFIG_JSON, BACKED_UP_AT, DEPLOYMENT_TAG)
SELECT JOURNEY_ID, CONFIG_JSON, SYSTIMESTAMP, 'CH123982828'
FROM DL_JOURNEY_MASTER WHERE JOURNEY_ID = 'JRN003';
--rollback DELETE FROM DL_CONFIG_JSON_BKP WHERE JOURNEY_ID='JRN003' AND DEPLOYMENT_TAG='CH123982828';

--changeset platform-dev:004-upsert-journey-json-config labels:developer,cicd splitStatements:false endDelimiter:;
-- Req 3: Oracle MERGE — INSERT new journeys, UPDATE JSON if already exists
MERGE INTO DL_JOURNEY_MASTER tgt
USING (
    SELECT 'JRN001' AS JOURNEY_ID, 'Personal Loan Instant' AS JOURNEY_NAME, 'PERSONAL_LOAN' AS PRODUCT_TYPE,
           '{"eligibility":{"minAge":21,"maxAge":60,"minIncome":30000},"documentation":{"panRequired":true,"aadharRequired":true,"bankStatementsMonths":3},"disbursalMode":"NEFT","maxTurnaroundHours":12,"bureau":["CIBIL","EXPERIAN"]}' AS CONFIG_JSON, 'Y' AS IS_ACTIVE FROM DUAL
    UNION ALL
    SELECT 'JRN002', 'Home Loan Express', 'HOME_LOAN',
           '{"eligibility":{"minAge":25,"maxAge":70,"minIncome":60000},"documentation":{"panRequired":true,"aadharRequired":true,"propertyDocRequired":true,"bankStatementsMonths":6},"disbursalMode":"RTGS","maxTurnaroundHours":48,"bureau":["CIBIL","CRIF"]}',
           'Y' FROM DUAL
    UNION ALL
    SELECT 'JRN003', 'Business Loan Fast Track', 'BUSINESS_LOAN',
           '{"eligibility":{"minAge":23,"maxAge":65,"minRevenue":600000,"gstRequired":true},"documentation":{"panRequired":true,"gstCertRequired":true,"itrYears":2,"bankStatementsMonths":6},"disbursalMode":"NEFT","maxTurnaroundHours":36,"bureau":["CIBIL"]}',
           'Y' FROM DUAL
) src ON (tgt.JOURNEY_ID = src.JOURNEY_ID)
WHEN MATCHED THEN
    UPDATE SET tgt.JOURNEY_NAME=src.JOURNEY_NAME, tgt.CONFIG_JSON=src.CONFIG_JSON, tgt.IS_ACTIVE=src.IS_ACTIVE
WHEN NOT MATCHED THEN
    INSERT (JOURNEY_ID, JOURNEY_NAME, PRODUCT_TYPE, CONFIG_JSON, IS_ACTIVE, CREATED_AT)
    VALUES (src.JOURNEY_ID, src.JOURNEY_NAME, src.PRODUCT_TYPE, src.CONFIG_JSON, src.IS_ACTIVE, SYSDATE);
--rollback MERGE INTO DL_JOURNEY_MASTER jm USING (SELECT JOURNEY_ID, CONFIG_JSON FROM DL_CONFIG_JSON_BKP WHERE DEPLOYMENT_TAG='CH123982828') bkp ON (jm.JOURNEY_ID=bkp.JOURNEY_ID) WHEN MATCHED THEN UPDATE SET jm.CONFIG_JSON=bkp.CONFIG_JSON;
