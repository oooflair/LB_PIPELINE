-- liquibase formatted sql

-- changeset tibcouser:create_sp_1002 labels="create-sp" endDelimiter:/
-- comment: This changeset running to create a stored procedure
CREATE OR REPLACE PROCEDURE sample_procedure_tibcouser AS
BEGIN
   DBMS_OUTPUT.PUT_LINE('Executed sample procedure for tibcouser');
END;
/

-- rollback DROP PROCEDURE sample_procedure_tibcouser;
