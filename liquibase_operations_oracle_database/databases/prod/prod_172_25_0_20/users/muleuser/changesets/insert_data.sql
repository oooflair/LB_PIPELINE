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
    1001,
    'HDFC001',
    'HDFC Bank',
    'BANK',
    'ACTIVE',
    'https://api.hdfc.example.com',
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
    1002,
    'ICICI001',
    'ICICI Bank',
    'BANK',
    'ACTIVE',
    'https://api.icici.example.com',
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
    9999,
    'TEST9999',
    'Test Partner',
    'NBFC',
    'INACTIVE',
    'https://api.test.example.com',
    40,
    5,
    'muleuser'
);

-- rollback DELETE FROM DL_PARTNER_CONFIG WHERE PARTNER_ID IN (1001,1002,9999);