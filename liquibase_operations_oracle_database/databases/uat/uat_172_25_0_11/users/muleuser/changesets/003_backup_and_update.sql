--liquibase formatted sql
-- ═══════════════════════════════════════════════════════════════════════════
-- 003 — Requirement 2: Backup Before Data Update
-- LABEL: developer,cicd — Developer can run data backup+update operations
-- ═══════════════════════════════════════════════════════════════════════════

--changeset platform-dev:003-backup-partner-status-1001 labels:developer,cicd splitStatements:false endDelimiter:;
INSERT INTO DL_DATA_UPDATE_BKP
    (TABLE_NAME, ROW_KEY, COLUMN_NAME, OLD_VALUE, BACKED_UP_AT, DEPLOYMENT_TAG)
SELECT 'DL_PARTNER_CONFIG', TO_CHAR(PARTNER_ID), 'STATUS', STATUS, SYSTIMESTAMP, 'CH123982828'
FROM DL_PARTNER_CONFIG WHERE PARTNER_ID = 1001;
--rollback DELETE FROM DL_DATA_UPDATE_BKP WHERE TABLE_NAME='DL_PARTNER_CONFIG' AND ROW_KEY='1001' AND DEPLOYMENT_TAG='CH123982828';

--changeset platform-dev:003-update-partner-status-1001 labels:developer,cicd splitStatements:false endDelimiter:;
UPDATE DL_PARTNER_CONFIG
SET STATUS='ACTIVE', UPDATED_BY='lb-deploy', UPDATED_AT=SYSTIMESTAMP
WHERE PARTNER_ID = 1001;
--rollback UPDATE DL_PARTNER_CONFIG pc SET pc.STATUS = (SELECT bkp.OLD_VALUE FROM DL_DATA_UPDATE_BKP bkp WHERE bkp.TABLE_NAME='DL_PARTNER_CONFIG' AND bkp.ROW_KEY='1001' AND bkp.COLUMN_NAME='STATUS' AND bkp.DEPLOYMENT_TAG='CH123982828' AND ROWNUM=1) WHERE pc.PARTNER_ID=1001;

--changeset platform-dev:003-backup-gold-partner-limits labels:developer,cicd splitStatements:false endDelimiter:;
INSERT INTO DL_DATA_UPDATE_BKP
    (TABLE_NAME, ROW_KEY, COLUMN_NAME, OLD_VALUE, BACKED_UP_AT, DEPLOYMENT_TAG)
SELECT 'DL_PARTNER_CONFIG', TO_CHAR(PARTNER_ID), 'CREDIT_LIMIT', TO_CHAR(CREDIT_LIMIT), SYSTIMESTAMP, 'CH123982828-LIMITS'
FROM DL_PARTNER_CONFIG WHERE JOURNEY_TYPE = 'GOLD';
--rollback DELETE FROM DL_DATA_UPDATE_BKP WHERE DEPLOYMENT_TAG='CH123982828-LIMITS';

--changeset platform-dev:003-update-gold-partner-limits labels:developer,cicd splitStatements:false endDelimiter:;
UPDATE DL_PARTNER_CONFIG
SET CREDIT_LIMIT=CREDIT_LIMIT * 1.20, UPDATED_BY='lb-deploy', UPDATED_AT=SYSTIMESTAMP
WHERE JOURNEY_TYPE = 'GOLD';
--rollback UPDATE DL_PARTNER_CONFIG pc SET pc.CREDIT_LIMIT = (SELECT TO_NUMBER(bkp.OLD_VALUE) FROM DL_DATA_UPDATE_BKP bkp WHERE bkp.TABLE_NAME='DL_PARTNER_CONFIG' AND bkp.ROW_KEY=TO_CHAR(pc.PARTNER_ID) AND bkp.COLUMN_NAME='CREDIT_LIMIT' AND bkp.DEPLOYMENT_TAG='CH123982828-LIMITS' AND ROWNUM=1) WHERE pc.JOURNEY_TYPE='GOLD';
