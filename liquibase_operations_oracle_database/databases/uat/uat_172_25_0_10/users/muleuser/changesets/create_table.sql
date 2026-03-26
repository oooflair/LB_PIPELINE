-- liquibase formatted sql

-- changeset muleuser:create_table_1001 labels="ddl-create"
-- comment: This changeset creates DL_PARTNER_CONFIG table

CREATE TABLE DL_PARTNER_CONFIG (
    PARTNER_ID        NUMBER PRIMARY KEY,
    PARTNER_CODE      VARCHAR2(50)   NOT NULL,
    PARTNER_NAME      VARCHAR2(100)  NOT NULL,
    PARTNER_TYPE      VARCHAR2(50),
    STATUS            VARCHAR2(20)   DEFAULT 'ACTIVE',
    API_URL           VARCHAR2(255),
    TIMEOUT_SECONDS   NUMBER         DEFAULT 30,
    RETRY_COUNT       NUMBER         DEFAULT 3,
    CONFIG_JSON       CLOB,
    CREATED_BY        VARCHAR2(50)   DEFAULT USER,
    CREATED_AT        TIMESTAMP      DEFAULT SYSTIMESTAMP,
    UPDATED_BY        VARCHAR2(50),
    UPDATED_AT        TIMESTAMP
)

-- rollback DRO TABLE DL_PARTNER_CONFIG;