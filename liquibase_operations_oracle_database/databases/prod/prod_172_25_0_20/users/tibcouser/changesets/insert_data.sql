-- liquibase formatted sql

-- changeset tibcouser:insert_data_1001 labels="insert-data"
-- comment: This changeset running to insert mapping data
INSERT INTO DL_PARTNER_CONFIG (PARTNER_ID, PARTNER_CODE, PARTNER_NAME, STATUS) VALUES (9999, 'SAMPLE', 'Sample Partner', 'ACTIVE');

-- rollback DELETE FROM DL_PARTNER_CONFIG WHERE PARTNER_ID = 9999;
