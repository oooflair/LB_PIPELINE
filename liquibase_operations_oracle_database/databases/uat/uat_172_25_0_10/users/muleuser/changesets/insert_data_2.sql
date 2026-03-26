-- liquibase formatted sql

-- changeset muleuser:insert_data_1002 labels="dml-insert"
-- comment: This changeset inserts initial partner data

INSERT INTO DL_PARTNER_CONFIG (
    PARTNER_ID,
    PARTNER_CODE,
    PARTNER_NAME,
    PARTNER_TYPE,
    STATUS,
    API_URL,
    TIMEOUT_SECONDS,
    RETRY_COUNT,
    CREATED_BY
) VALUES (
    1015,
    'HDFC001',
    'test Bank',
    'BANK',
    'ACTIVE',
    'https://api.test.example.com',
    30,
    3,
    'muleuser'
);

INSERT INTO DL_PARTNER_CONFIG (
    PARTNER_ID,
    PARTNER_CODE,
    PARTNER_NAME,
    PARTNER_TYPE,
    STATUS,
    API_URL,
    TIMEOUT_SECONDS,
    RETRY_COUNT,
    CREATED_BY
) VALUES (
    1016,
    'activy',
    'noc Bank',
    'BANK',
    'ACTIVE',
    'https://api.noc.example.com',
    25,
    2,
    'muleuser'
);

INSERT INTO DL_PARTNER_CONFIG (
    PARTNER_ID,
    PARTNER_CODE,
    PARTNER_NAME,
    PARTNER_TYPE,
    STATUS,
    API_URL,
    TIMEOUT_SECONDS,
    RETRY_COUNT,
    CREATED_BY
) VALUES (
    7871,
    'TEST9999',
    'Test Partner',
    'NBFC',
    'INACTIVE',
    'https://api.test.example.com',
    40,
    5,
    'muleuser'
);

-- rollback DELETE FROM DL_PARTNER_CONFIG WHERE PARTNER_ID IN (1015,1016,7871);