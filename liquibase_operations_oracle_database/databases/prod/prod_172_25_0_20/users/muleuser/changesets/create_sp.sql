-- liquibase formatted sql

-- changeset muleuser:create_sp_1002 labels="create-sp" endDelimiter:/
-- comment: This changeset running to create a stored procedure
CREATE OR REPLACE PROCEDURE sample_procedure_muleuser AS
BEGIN
   DBMS_OUTPUT.PUT_LINE('Executed sample procedure for muleuser');
END;
/

-- rollback DROP PROCEDURE sample_procedure_muleuser;
