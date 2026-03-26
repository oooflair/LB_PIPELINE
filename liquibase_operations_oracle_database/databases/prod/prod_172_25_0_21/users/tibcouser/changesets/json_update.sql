-- liquibase formatted sql

-- changeset muleuser:json_update_1004 labels="json-update"
-- comment: This changeset updates JSON config for partner

UPDATE DL_PARTNER_CONFIG
SET
    CONFIG_JSON = '{"key":"value","env":"uat","feature":"enabled"}',
    UPDATED_BY = 'muleuser',
    UPDATED_AT = SYSTIMESTAMP
WHERE PARTNER_ID = 9999;

-- rollback
UPDATE DL_PARTNER_CONFIG
SET
    CONFIG_JSON = NULL,
    UPDATED_BY = 'rollback_user',
    UPDATED_AT = SYSTIMESTAMP
WHERE PARTNER_ID = 9999;