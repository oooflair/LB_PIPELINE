--liquibase formatted sql
-- ═══════════════════════════════════════════════════════════════════════════
-- 002 — Requirement 1: Bulk Data Insert
-- LABEL: developer,cicd — Developers can run this (data only, no DDL/SP)
-- ═══════════════════════════════════════════════════════════════════════════

--changeset platform-dev:002-bulk-insert-partner-config labels:developer,cicd splitStatements:true endDelimiter:;
-- Req 1: Bulk insert partner configuration records
INSERT INTO DL_PARTNER_CONFIG
    (PARTNER_ID, PARTNER_CODE, PARTNER_NAME, JOURNEY_TYPE, STATUS, CONFIG_JSON, CREATED_BY, CREATED_AT)
VALUES
    (1001, 'HDFC-DL', 'HDFC Bank Digital Lending', 'GOLD', 'ACTIVE',
     '{"maxLoanAmount":5000000,"minCibilScore":750,"interestRateMin":10.5,"interestRateMax":18.0,"tenure":{"min":12,"max":60},"processingFee":1.0,"allowPrepayment":true}',
     'lb-deploy', SYSDATE);

INSERT INTO DL_PARTNER_CONFIG
    (PARTNER_ID, PARTNER_CODE, PARTNER_NAME, JOURNEY_TYPE, STATUS, CONFIG_JSON, CREATED_BY, CREATED_AT)
VALUES
    (1002, 'AXIS-DL', 'Axis Bank Digital Lending', 'SILVER', 'ACTIVE',
     '{"maxLoanAmount":2000000,"minCibilScore":700,"interestRateMin":12.0,"interestRateMax":22.0,"tenure":{"min":6,"max":36},"processingFee":1.5,"allowPrepayment":true}',
     'lb-deploy', SYSDATE);

INSERT INTO DL_PARTNER_CONFIG
    (PARTNER_ID, PARTNER_CODE, PARTNER_NAME, JOURNEY_TYPE, STATUS, CONFIG_JSON, CREATED_BY, CREATED_AT)
VALUES
    (1003, 'ICICI-DL', 'ICICI Bank Digital Lending', 'GOLD', 'ACTIVE',
     '{"maxLoanAmount":7500000,"minCibilScore":760,"interestRateMin":9.5,"interestRateMax":16.5,"tenure":{"min":12,"max":84},"processingFee":0.75,"allowPrepayment":false}',
     'lb-deploy', SYSDATE);

INSERT INTO DL_PARTNER_CONFIG
    (PARTNER_ID, PARTNER_CODE, PARTNER_NAME, JOURNEY_TYPE, STATUS, CONFIG_JSON, CREATED_BY, CREATED_AT)
VALUES
    (1004, 'BAJAJ-DL', 'Bajaj Finserv Digital Lending', 'SILVER', 'PENDING',
     '{"maxLoanAmount":1000000,"minCibilScore":680,"interestRateMin":14.0,"interestRateMax":26.0,"tenure":{"min":3,"max":24},"processingFee":2.0,"allowPrepayment":true}',
     'lb-deploy', SYSDATE);

INSERT INTO DL_PARTNER_CONFIG
    (PARTNER_ID, PARTNER_CODE, PARTNER_NAME, JOURNEY_TYPE, STATUS, CONFIG_JSON, CREATED_BY, CREATED_AT)
VALUES
    (1005, 'KOTAK-DL', 'Kotak Mahindra Digital Lending', 'GOLD', 'ACTIVE',
     '{"maxLoanAmount":3000000,"minCibilScore":740,"interestRateMin":11.0,"interestRateMax":19.5,"tenure":{"min":12,"max":60},"processingFee":1.25,"allowPrepayment":true}',
     'lb-deploy', SYSDATE);

--rollback DELETE FROM DL_PARTNER_CONFIG WHERE PARTNER_ID IN (1001,1002,1003,1004,1005);

--changeset platform-dev:002-bulk-insert-journey-master labels:developer,cicd splitStatements:true endDelimiter:;
-- Req 1: Bulk insert journey master records
INSERT INTO DL_JOURNEY_MASTER
    (JOURNEY_ID, JOURNEY_NAME, PRODUCT_TYPE, CONFIG_JSON, IS_ACTIVE, CREATED_AT)
VALUES
    ('JRN001', 'Personal Loan Instant', 'PERSONAL_LOAN',
     '{"eligibility":{"minAge":21,"maxAge":60,"minIncome":25000},"documentation":{"panRequired":true,"aadharRequired":true,"bankStatementsMonths":3},"disbursalMode":"NEFT","maxTurnaroundHours":24,"bureau":["CIBIL","EXPERIAN"]}',
     'Y', SYSDATE);

INSERT INTO DL_JOURNEY_MASTER
    (JOURNEY_ID, JOURNEY_NAME, PRODUCT_TYPE, CONFIG_JSON, IS_ACTIVE, CREATED_AT)
VALUES
    ('JRN002', 'Home Loan Express', 'HOME_LOAN',
     '{"eligibility":{"minAge":25,"maxAge":70,"minIncome":50000},"documentation":{"panRequired":true,"aadharRequired":true,"propertyDocRequired":true,"bankStatementsMonths":6},"disbursalMode":"RTGS","maxTurnaroundHours":72,"bureau":["CIBIL","CRIF"]}',
     'Y', SYSDATE);

INSERT INTO DL_JOURNEY_MASTER
    (JOURNEY_ID, JOURNEY_NAME, PRODUCT_TYPE, CONFIG_JSON, IS_ACTIVE, CREATED_AT)
VALUES
    ('JRN003', 'Business Loan Fast Track', 'BUSINESS_LOAN',
     '{"eligibility":{"minAge":23,"maxAge":65,"minRevenue":500000,"gstRequired":true},"documentation":{"panRequired":true,"gstCertRequired":true,"itrYears":2,"bankStatementsMonths":6},"disbursalMode":"NEFT","maxTurnaroundHours":48,"bureau":["CIBIL"]}',
     'Y', SYSDATE);

--rollback DELETE FROM DL_JOURNEY_MASTER WHERE JOURNEY_ID IN ('JRN001','JRN002','JRN003');
