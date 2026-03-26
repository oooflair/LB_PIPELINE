-- liquibase formatted sql

-- changeset muleuser:update_data_1003 labels="dml-update"
-- comment: This changeset updates partner config values

UPDATE DL_PARTNER_CONFIG
SET
    STATUS = 'ACTIVE',
    UPDATED_BY = 'muleuser',
    UPDATED_AT = SYSTIMESTAMP
WHERE PARTNER_ID = 9999;

UPDATE DL_PARTNER_CONFIG
SET
    TIMEOUT_SECONDS = 45,
    RETRY_COUNT = 4,
    UPDATED_BY = 'muleuser',
    UPDATED_AT = SYSTIMESTAMP
WHERE PARTNER_ID = 1001;

-- rollback
UPDATE DL_PARTNER_CONFIG
SET
    STATUS = 'INACTIVE',
    UPDATED_BY = 'rollback_user',
    UPDATED_AT = SYSTIMESTAMP
WHERE PARTNER_ID = 9999;

UPDATE DL_PARTNER_CONFIG
SET
    TIMEOUT_SECONDS = 30,
    RETRY_COUNT = 3,
    UPDATED_BY = 'rollback_user',
    UPDATED_AT = SYSTIMESTAMP
WHERE PARTNER_ID = 1001;