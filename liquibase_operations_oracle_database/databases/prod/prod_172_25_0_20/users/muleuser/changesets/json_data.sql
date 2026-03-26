-- liquibase formatted sql

-- changeset muleuser:json_update_1003 labels="json-update"
-- comment: This changeset running to update json
UPDATE DL_PARTNER_CONFIG SET CONFIG_JSON = '{"key":"value"}' WHERE PARTNER_ID = 9999;

-- rollback UPDATE DL_PARTNER_CONFIG SET CONFIG_JSON = NULL WHERE PARTNER_ID = 9999;
